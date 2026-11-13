class_name SpikePathGrid
extends RefCounted

## Wegwerf-Grid + lokaler A* für G0.5.
##
## Kein Weltmodell, keine Gebäude, keine Chunks: nur Walkability, lokale Pfade
## und ein Cache-Schlüssel (start, goal) — ohne Map-/Building-Version, weil es
## hier nur um Kosten/Hit-Rate geht.
##
## 4-Nachbar-A* mit Manhattan-Heuristik, binärer Heap über Packed-Arrays,
## Stamp-Arrays statt Neu-Allokation pro Pfad. Expansions-Limit verhindert
## unbegrenzte Läufe auf dichten 512²-Grids.

var size: int = 0
var total: int = 0
var blocked: PackedByteArray = PackedByteArray()
var cache: Dictionary = {}
var cache_enabled: bool = true
var max_expansions: int = 20000

var cache_hits: int = 0
var cache_misses: int = 0
var expansions: int = 0
var failures: int = 0
var paths_found: int = 0

var _g: PackedInt32Array = PackedInt32Array()
var _came: PackedInt32Array = PackedInt32Array()
var _stamp: PackedInt32Array = PackedInt32Array()
var _closed: PackedInt32Array = PackedInt32Array()
var _gen: int = 0
var _hf: PackedInt32Array = PackedInt32Array()
var _hn: PackedInt32Array = PackedInt32Array()
var _hsize: int = 0


func build(grid_size: int, seed_value: int, blocked_percent: int = 10) -> void:
	size = grid_size
	total = grid_size * grid_size
	blocked.resize(total)
	_g.resize(total)
	_came.resize(total)
	_stamp.resize(total)
	_closed.resize(total)
	_stamp.fill(0)
	_closed.fill(0)
	_g.fill(0)
	_came.fill(-1)
	var rng: SpikeRng = SpikeRng.new(seed_value)
	for i in total:
		blocked[i] = 1 if rng.next_range(100) < blocked_percent else 0


func reset_stats() -> void:
	cache_hits = 0
	cache_misses = 0
	expansions = 0
	failures = 0
	paths_found = 0


func clear_cache() -> void:
	cache.clear()


func is_walkable(node: int) -> bool:
	return blocked[node] == 0


## Liefert Pfad als Knotenindizes (start..goal) oder leer bei Blockade/Limit.
func find_path(start: int, goal: int) -> PackedInt32Array:
	if cache_enabled:
		var key: int = start * total + goal
		var hit: Variant = cache.get(key)
		if hit != null:
			cache_hits += 1
			return hit
	cache_misses += 1
	var path: PackedInt32Array = _astar(start, goal)
	if cache_enabled and path.size() > 0:
		cache[start * total + goal] = path
	return path


func _astar(start: int, goal: int) -> PackedInt32Array:
	if start == goal:
		return PackedInt32Array([start])
	if blocked[start] != 0 or blocked[goal] != 0:
		failures += 1
		return PackedInt32Array()
	_gen += 1
	var gen: int = _gen
	_hsize = 0
	var gx: int = goal % size
	var gy: int = goal / size
	_stamp[start] = gen
	_g[start] = 0
	_came[start] = -1
	var sx: int = start % size
	var sy: int = start / size
	_heap_push(abs(sx - gx) + abs(sy - gy), start)
	var found: bool = false
	var steps: int = 0
	while _hsize > 0:
		var node: int = _heap_pop()
		if _closed[node] == gen:
			continue
		_closed[node] = gen
		steps += 1
		if node == goal:
			found = true
			break
		if steps > max_expansions:
			break
		expansions += 1
		var x: int = node % size
		var y: int = node / size
		var ng: int = _g[node] + 1
		if x > 0:
			_relax(node - 1, ng, gen, gx, gy, node)
		if x + 1 < size:
			_relax(node + 1, ng, gen, gx, gy, node)
		if y > 0:
			_relax(node - size, ng, gen, gx, gy, node)
		if y + 1 < size:
			_relax(node + size, ng, gen, gx, gy, node)
	if not found:
		failures += 1
		return PackedInt32Array()
	paths_found += 1
	var rev: PackedInt32Array = PackedInt32Array()
	var cur: int = goal
	while cur != -1:
		rev.append(cur)
		cur = _came[cur]
	var n: int = rev.size()
	var path: PackedInt32Array = PackedInt32Array()
	path.resize(n)
	for i in n:
		path[i] = rev[n - 1 - i]
	return path


func _relax(nbr: int, ng: int, gen: int, gx: int, gy: int, from_node: int) -> void:
	if blocked[nbr] != 0:
		return
	if _stamp[nbr] == gen and ng >= _g[nbr]:
		return
	_stamp[nbr] = gen
	_g[nbr] = ng
	_came[nbr] = from_node
	var x: int = nbr % size
	var y: int = nbr / size
	_heap_push(ng + abs(x - gx) + abs(y - gy), nbr)


func _heap_push(f: int, node: int) -> void:
	var i: int = _hsize
	_hf.append(f)
	_hn.append(node)
	_hsize = i + 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		if _hf[parent] < f:
			break
		_hf[i] = _hf[parent]
		_hn[i] = _hn[parent]
		i = parent
	_hf[i] = f
	_hn[i] = node


func _heap_pop() -> int:
	var top: int = _hn[0]
	var n: int = _hsize - 1
	_hsize = n
	if n == 0:
		_hf.resize(0)
		_hn.resize(0)
		return top
	var lf: int = _hf[n]
	var ln: int = _hn[n]
	_hf.resize(n)
	_hn.resize(n)
	var i: int = 0
	var half: int = n >> 1
	while i < half:
		var child: int = (i << 1) + 1
		var right: int = child + 1
		if right < n and _hf[right] < _hf[child]:
			child = right
		if lf < _hf[child]:
			break
		_hf[i] = _hf[child]
		_hn[i] = _hn[child]
		i = child
	_hf[i] = lf
	_hn[i] = ln
	return top
