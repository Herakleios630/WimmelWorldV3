class_name PathFinder
extends RefCounted

## Lokaler A* auf der Tile-Karte (AStarGrid2D) mit deterministischen
## Tie-Breaks der Engine, Straßen-Gewichtung und LRU-Pfad-Cache. Der Cache ist
## abgeleitet und wird nie gespeichert.
##
## Pro festem Sim-Frame (path_frame_ticks, G2-Default 80 Ticks = 1/60 s bei
## 50x) gelten harte Budgets:
## - höchstens path_lookup_budget Pfadanfragen,
## - höchstens path_recalc_budget echte A*-Neuberechnungen.
## Überschuss wird vom DecisionSystem deterministisch auf den nächsten Frame
## vertagt; es werden keine Events übersprungen.

const MAX_CACHE_ORDER: int = 8192

var world: WorldMap
var size: int = 0
var map_version: int = 1
var cache_capacity: int = 512
var lookup_budget: int = 50
var recalc_budget: int = 2

var walkable: PackedByteArray = PackedByteArray()
var _grid: AStarGrid2D
var _cache: Dictionary = {}
var _cache_order: PackedInt64Array = PackedInt64Array()

var total_requests: int = 0
var cache_hits: int = 0
var cache_misses: int = 0
var recalculations: int = 0
var prewarm_recalculations: int = 0
var deferred_total: int = 0
var frame_lookups: int = 0
var frame_recalcs: int = 0
var frame_deferred: int = 0
var max_lookups_per_frame: int = 0
var max_recalcs_per_frame: int = 0
var last_deferred: bool = false


func _init(p_world: WorldMap, p_map_version: int = 1,
		p_cache_capacity: int = 512, p_lookup_budget: int = 50,
		p_recalc_budget: int = 2) -> void:
	world = p_world
	size = p_world.size
	map_version = p_map_version
	cache_capacity = maxi(8, p_cache_capacity)
	lookup_budget = maxi(1, p_lookup_budget)
	recalc_budget = maxi(1, p_recalc_budget)
	_build_grid()


func _build_grid() -> void:
	walkable.resize(size * size)
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, size, size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for y in size:
		for x in size:
			var idx: int = y * size + x
			var blocked: bool = world.is_blocked_tile(x, y)
			walkable[idx] = 0 if blocked else 1
			var tile: Vector2i = Vector2i(x, y)
			if blocked:
				_grid.set_point_solid(tile, true)
			elif world.is_road_tile(x, y):
				_grid.set_point_weight_scale(tile, 0.7)


func begin_frame() -> void:
	if frame_lookups > max_lookups_per_frame:
		max_lookups_per_frame = frame_lookups
	if frame_recalcs > max_recalcs_per_frame:
		max_recalcs_per_frame = frame_recalcs
	frame_lookups = 0
	frame_recalcs = 0
	frame_deferred = 0
	last_deferred = false


func end_frame() -> void:
	if frame_lookups > max_lookups_per_frame:
		max_lookups_per_frame = frame_lookups
	if frame_recalcs > max_recalcs_per_frame:
		max_recalcs_per_frame = frame_recalcs


## Rückgabe ist eine Polylinie in Tile-Koordinaten. Leer + last_deferred
## bedeutet: Budget erschöpft, im nächsten Frame erneut versuchen.
func request_path(start_point: Vector2, goal_point: Vector2) -> PackedVector2Array:
	last_deferred = false
	total_requests += 1
	if frame_lookups >= lookup_budget:
		frame_deferred += 1
		deferred_total += 1
		last_deferred = true
		return PackedVector2Array()
	frame_lookups += 1
	var start_tile: Vector2i = _tile_for_point(start_point)
	var goal_tile: Vector2i = _tile_for_point(goal_point)
	if start_tile.x < 0 or goal_tile.x < 0:
		return PackedVector2Array()
	var start_idx: int = start_tile.y * size + start_tile.x
	var goal_idx: int = goal_tile.y * size + goal_tile.x
	var key: int = _cache_key(start_idx, goal_idx)
	if _cache.has(key):
		cache_hits += 1
		_touch(key)
		return _materialize(_cache[key] as PackedVector2Array, start_point, goal_point)
	if frame_recalcs >= recalc_budget:
		frame_deferred += 1
		deferred_total += 1
		last_deferred = true
		return PackedVector2Array()
	frame_recalcs += 1
	recalculations += 1
	cache_misses += 1
	var tile_path: PackedVector2Array = _astar(start_idx, goal_idx)
	if tile_path.is_empty():
		return PackedVector2Array()
	_store(key, tile_path)
	return _materialize(tile_path, start_point, goal_point)


## Füllt den abgeleiteten Cache vor, ohne das Frame-Budget zu belasten. Wird
## beim Aufbau und nach einem Load aus demselben autoritativen Zustand
## aufgerufen; der Cache bleibt damit eine reine, reproduzierbare Beschleunigung.
func prewarm(start_point: Vector2, goal_point: Vector2) -> void:
	var start_tile: Vector2i = _tile_for_point(start_point)
	var goal_tile: Vector2i = _tile_for_point(goal_point)
	if start_tile.x < 0 or goal_tile.x < 0:
		return
	var start_idx: int = start_tile.y * size + start_tile.x
	var goal_idx: int = goal_tile.y * size + goal_tile.x
	var key: int = _cache_key(start_idx, goal_idx)
	if _cache.has(key):
		return
	var tile_path: PackedVector2Array = _astar(start_idx, goal_idx)
	if tile_path.is_empty():
		return
	_store(key, tile_path)
	prewarm_recalculations += 1


## Konventionelle Cache-Hit-Rate: Hits unter den tatsächlich konsultierten
## Pfadanfragen. Budget-Vertagungen sind keine Cache-Misses.
func cache_hit_rate() -> float:
	var consulted: int = cache_hits + cache_misses
	if consulted <= 0:
		return 0.0
	return float(cache_hits) / float(consulted)


func request_hit_rate() -> float:
	if total_requests <= 0:
		return 0.0
	return float(cache_hits) / float(total_requests)


func cache_size() -> int:
	return _cache.size()


func invalidate() -> void:
	_cache.clear()
	_cache_order.clear()


func set_map_version(version: int) -> void:
	if version == map_version:
		return
	map_version = version
	invalidate()


func stats() -> Dictionary:
	return {
		"requests": total_requests,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"cache_size": _cache.size(),
		"cache_hit_rate": cache_hit_rate(),
		"request_hit_rate": request_hit_rate(),
		"recalculations": recalculations,
		"prewarm_recalculations": prewarm_recalculations,
		"deferred": deferred_total,
		"max_lookups_per_frame": max_lookups_per_frame,
		"max_recalcs_per_frame": max_recalcs_per_frame,
		"map_version": map_version,
	}


func _cache_key(start_idx: int, goal_idx: int) -> int:
	return (map_version * 1099511627776) + (start_idx * 1048576) + goal_idx


func _touch(key: int) -> void:
	var out: PackedInt64Array = PackedInt64Array()
	for existing in _cache_order:
		if existing != key:
			out.append(existing)
	out.append(key)
	_cache_order = out


func _store(key: int, path: PackedVector2Array) -> void:
	if _cache.size() >= cache_capacity:
		if _cache_order.size() > 0:
			var evict: int = _cache_order[0]
			_cache.erase(evict)
			var out: PackedInt64Array = PackedInt64Array()
			for i in range(1, _cache_order.size()):
				out.append(_cache_order[i])
			_cache_order = out
	_cache[key] = path
	_cache_order.append(key)
	if _cache_order.size() > MAX_CACHE_ORDER:
		var trim: PackedInt64Array = PackedInt64Array()
		for i in range(_cache_order.size() - MAX_CACHE_ORDER, _cache_order.size()):
			trim.append(_cache_order[i])
		_cache_order = trim


func _materialize(tile_path: PackedVector2Array, start_point: Vector2,
		goal_point: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(start_point)
	for p in tile_path:
		if out[out.size() - 1].distance_to(p) > 0.01:
			out.append(p)
	if out[out.size() - 1].distance_to(goal_point) > 0.01:
		out.append(goal_point)
	if out.is_empty():
		out.append(start_point)
		out.append(goal_point)
	return out


func _tile_for_point(point: Vector2) -> Vector2i:
	var tx: int = int(floor(point.x))
	var ty: int = int(floor(point.y))
	if tx < 0 or tx >= size or ty < 0 or ty >= size:
		return Vector2i(-1, -1)
	if walkable[ty * size + tx] != 0:
		return Vector2i(tx, ty)
	for radius in range(1, 5):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var nx: int = tx + dx
				var ny: int = ty + dy
				if nx < 0 or nx >= size or ny < 0 or ny >= size:
					continue
				if walkable[ny * size + nx] != 0:
					return Vector2i(nx, ny)
	return Vector2i(-1, -1)


func _astar(start_idx: int, goal_idx: int) -> PackedVector2Array:
	var from_tile: Vector2i = Vector2i(start_idx % size, start_idx / size)
	var goal_tile: Vector2i = Vector2i(goal_idx % size, goal_idx / size)
	var ids = _grid.get_id_path(from_tile, goal_tile)
	var path: PackedVector2Array = PackedVector2Array()
	for value in ids:
		var tile: Vector2i = Vector2i(value)
		path.append(Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5))
	if path.is_empty():
		return PackedVector2Array()
	return _compress(path)


func _compress(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var out: PackedVector2Array = PackedVector2Array()
	out.append(points[0])
	for i in range(1, points.size() - 1):
		var a: Vector2 = out[out.size() - 1]
		var b: Vector2 = points[i]
		var c: Vector2 = points[i + 1]
		var cross: float = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
		if absf(cross) > 0.001:
			out.append(b)
	out.append(points[points.size() - 1])
	return out
