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
var scale_mode: bool = false
var _grid: AStarGrid2D
# 10k: kleiner Straßen-Wegpunktgraph (~600 Knoten) plus lokale Anbindungen.
# A* auf diesem Graphen ist der primäre Pfad; das Tile-A* bleibt Fallback.
var _scale_graph: AStar2D
var _scale_points: Array = []
var _scale_anchor_node: Dictionary = {}
var _cache: Dictionary = {}
# Deterministische FIFO-Eviction über eine Einfüge-Warteschlange (O(1)
# amortisiert). Bei 10k und 32k+ Pfaden wäre ein LRU-Scan pro Miss zu teuer.
# Der Cache ist abgeleitet und nicht im Save.
var _evict_queue: PackedInt64Array = PackedInt64Array()
var _evict_head: int = 0

var total_requests: int = 0
var cache_hits: int = 0
var cache_misses: int = 0
var recalculations: int = 0
var prewarm_recalculations: int = 0
var deferred_total: int = 0
var frame_begins: int = 0
var graph_paths: int = 0
var grid_fallbacks: int = 0
var prewarm_graph: int = 0
var prewarm_grid: int = 0
var frame_lookups: int = 0
var frame_recalcs: int = 0
var frame_deferred: int = 0
var max_lookups_per_frame: int = 0
var max_recalcs_per_frame: int = 0
var last_deferred: bool = false
# Deterministische Warteschlange über Frames: Deferrals werden reihum auf ein
# 32-Frame-Fenster verteilt, statt im nächsten Frame alle gleichzeitig
# zurückzukommen. Das verhindert 1000-fache Retry-Wellen.
const DEFER_WINDOW: int = 32
var defer_window: int = 1
var defer_cursor: int = 0
var last_defer_frames: int = 1


func _init(p_world: WorldMap, p_map_version: int = 1,
		p_cache_capacity: int = 512, p_lookup_budget: int = 50,
		p_recalc_budget: int = 2, p_defer_window: int = 1) -> void:
	world = p_world
	size = p_world.size
	map_version = p_map_version
	cache_capacity = maxi(8, p_cache_capacity)
	lookup_budget = maxi(1, p_lookup_budget)
	recalc_budget = maxi(1, p_recalc_budget)
	defer_window = maxi(1, p_defer_window)
	scale_mode = p_world.profile == SimConfig.PROFILE_SCALE
	if scale_mode:
		_build_scale_grid()
	else:
		_build_grid()


func _build_grid() -> void:
	# Direkter Array-Zugriff statt 4 Mio. Methodenaufrufe bei 2048x2048.
	var total: int = size * size
	walkable.resize(total)
	var occupied: PackedByteArray = world.occupied
	for idx in total:
		walkable[idx] = 0 if occupied[idx] != 0 else 1
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, size, size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for building in world.buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			if y < 0 or y >= size:
				continue
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if x >= 0 and x < size:
					_grid.set_point_solid(Vector2i(x, y), true)
	var road: PackedByteArray = world.road
	for idx in total:
		if road[idx] != 0 and walkable[idx] != 0:
			_grid.set_point_weight_scale(Vector2i(idx % size, idx / size), 0.7)


## 10k-Profil: A* läuft auf dem Straßennetz plus kurzen, deterministischen
## Anbindungen zu Feldern/Brunnen/Platz. Dadurch bleibt die Suche klein und
## die Stadtblockade wird nicht als 4-Mio.-Tile-Maze expandiert.
func _build_scale_grid() -> void:
	var total: int = size * size
	walkable = world.road.duplicate()
	walkable.resize(total)
	_grid = AStarGrid2D.new()
	# Nur der bebaute/begehbare Bereich ist Teil des A*-Grids; das reduziert
	# die Punktzahl von 4,2 Mio. auf ~1,34 Mio. und die Suchkosten deutlich.
	_grid.region = Rect2i(140, 140, 1600, 840)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	# Felder liegen östlich der Zugangsstraße x=1108; jede Feldmitte erhält
	# einen geraden Arbeitskorridor zur Straße.
	for point in world.scale_field_points():
		var fx: int = int(floor(point.x))
		var fy: int = int(floor(point.y))
		if fx >= 0 and fx < size and fy >= 0 and fy < size:
			_carve_line(fx, fy, 1108, fy)
	for anchor in world.scale_path_anchors():
		_carve_anchor(anchor)
	var occupied: PackedByteArray = world.occupied
	var road: PackedByteArray = world.road
	for y in range(140, 980):
		for x in range(140, 1740):
			var idx2: int = y * size + x
			if walkable[idx2] != 0:
				if road[idx2] != 0:
					_grid.set_point_weight_scale(Vector2i(x, y), 0.7)
				continue
			# Straßen und Anbindungen bleiben begehbar; alles andere blockiert.
			if occupied[idx2] != 0 or road[idx2] == 0:
				_grid.set_point_solid(Vector2i(x, y), true)
	_build_scale_graph()


func _build_scale_graph() -> void:
	_scale_graph = AStar2D.new()
	_scale_points.clear()
	_scale_anchor_node.clear()
	var node_by_tile: Dictionary = {}
	# Straßenraster: 11 Längsstraßen x 50 Querstraßen.
	for c in 11:
		var x: int = 157 + c * 64
		for r in 50:
			var y: int = 168 + r * 16
			_add_scale_node(node_by_tile, x, y)
	for c in 11:
		for r in 49:
			_connect_scale_tiles(node_by_tile, 157 + c * 64, 168 + r * 16,
				157 + c * 64, 168 + (r + 1) * 16)
	for r in 50:
		for c in 10:
			_connect_scale_tiles(node_by_tile, 157 + c * 64, 168 + r * 16,
				157 + (c + 1) * 64, 168 + r * 16)
	# Verbindung Stadt <-> Feldzugang auf y=560.
	for x in [733, 797, 1108]:
		_add_scale_node(node_by_tile, x, 560)
	_connect_scale_tiles(node_by_tile, 733, 560, 797, 560)
	_connect_scale_tiles(node_by_tile, 797, 560, 1108, 560)
	_connect_scale_tiles(node_by_tile, 733, 552, 733, 560)
	_connect_scale_tiles(node_by_tile, 733, 560, 733, 568)
	_connect_scale_tiles(node_by_tile, 797, 552, 797, 560)
	_connect_scale_tiles(node_by_tile, 797, 560, 797, 568)
	# Feldzugang x=1108 und Support-Stichstraßen.
	var access_ys: Array = [560, 576, 604, 630]
	for r in 10:
		access_ys.append(212 + r * 30)
	access_ys.sort()
	for y_v in access_ys:
		_add_scale_node(node_by_tile, 1108, y_v)
	for i in range(1, access_ys.size()):
		_connect_scale_tiles(node_by_tile, 1108, access_ys[i - 1],
			1108, access_ys[i])
	for y_v in [576, 604, 630]:
		_add_scale_node(node_by_tile, 1360, y_v)
		_connect_scale_tiles(node_by_tile, 1108, y_v, 1360, y_v)
	# Alle Gebäudetüren/Feldpunkte/öffentlichen Punkte an den nächsten Knoten.
	for building in world.buildings:
		var b: Building = building
		_register_scale_anchor(node_by_tile, b.door_point)
	# Felder werden explizit an ihren Zugangsport x=1108 angebunden; der
	# euklidisch nächste Knoten wäre für weit östliche Felder ein Support-Knoten.
	for point in world.scale_field_points():
		var fy: int = int(floor(point.y))
		var port_key: int = fy * size + 1108
		if node_by_tile.has(port_key):
			var id: int = int(node_by_tile[port_key])
			if _line_walkable(point, _scale_points[id]):
				_scale_anchor_node[_anchor_key(point)] = id
	_register_scale_anchor_public(world.plaza_point)
	var well: Vector2 = world.door_point(world.well_id())
	for i in 3:
		_register_scale_anchor_public(
			world.clamp_point(well + Vector2(float(i - 1) * 0.8, 0.0)))
	for dx in 5:
		for dy in 2:
			_register_scale_anchor_public(world.clamp_point(
				world.plaza_point + Vector2(float(dx - 2) * 1.0,
					float(dy) * 1.5)))


func _add_scale_node(node_by_tile: Dictionary, x: int, y: int) -> int:
	var key: int = y * size + x
	if node_by_tile.has(key):
		return int(node_by_tile[key])
	var id: int = _scale_points.size()
	node_by_tile[key] = id
	_scale_points.append(Vector2(float(x) + 0.5, float(y) + 0.5))
	_scale_graph.add_point(id, _scale_points[id])
	return id


func _connect_scale_tiles(node_by_tile: Dictionary, ax: int, ay: int,
		bx: int, by: int) -> void:
	var a: int = _add_scale_node(node_by_tile, ax, ay)
	var b: int = _add_scale_node(node_by_tile, bx, by)
	if a != b:
		_scale_graph.connect_points(a, b)


func _register_scale_anchor(node_by_tile: Dictionary, point: Vector2) -> void:
	var key: int = _anchor_key(point)
	if _scale_anchor_node.has(key):
		return
	var best_id: int = -1
	var best_d: float = 1e30
	for id in _scale_points.size():
		var d: float = (_scale_points[id] as Vector2).distance_squared_to(point)
		if d < best_d - 0.0001:
			best_d = d
			best_id = id
	if best_id < 0:
		return
	# Nur gerade, begehbare Anbindungen sind als Anker zulässig; sonst Fallback.
	if not _line_walkable(point, _scale_points[best_id]):
		return
	_scale_anchor_node[key] = best_id


## Öffentliche Punkte (Platz/Brunnen) liegen auf offener Fläche; ihre kurze
## Anbindung muss nur Gebäude meiden, nicht zwingend Straßentiles sein.
func _register_scale_anchor_public(point: Vector2) -> void:
	var key: int = _anchor_key(point)
	if _scale_anchor_node.has(key):
		return
	var candidates: Array = []
	for id in _scale_points.size():
		candidates.append([(_scale_points[id] as Vector2).distance_squared_to(point), id])
	candidates.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for entry in candidates:
		var id: int = int(entry[1])
		if _line_building_clear(point, _scale_points[id]):
			_scale_anchor_node[key] = id
			return


func _line_building_clear(a: Vector2, b: Vector2) -> bool:
	var dx: int = absi(int(floor(b.x)) - int(floor(a.x)))
	var dy: int = absi(int(floor(b.y)) - int(floor(a.y)))
	var steps: int = maxi(dx, dy)
	for i in range(steps + 1):
		var t: float = 0.0 if steps == 0 else float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		var tx: int = int(floor(p.x))
		var ty: int = int(floor(p.y))
		if tx < 0 or tx >= size or ty < 0 or ty >= size:
			return false
		if world.is_blocked_tile(tx, ty):
			return false
	return true


func _register_scale_anchor_scan(_node_by_tile: Dictionary, point: Vector2) -> void:
	var key: int = _anchor_key(point)
	if _scale_anchor_node.has(key):
		return
	var candidates: Array = []
	for id in _scale_points.size():
		candidates.append([(_scale_points[id] as Vector2).distance_squared_to(point), id])
	candidates.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	for entry in candidates:
		var id: int = int(entry[1])
		if _line_walkable(point, _scale_points[id]):
			_scale_anchor_node[key] = id
			return


func _anchor_key(point: Vector2) -> int:
	return int(round(point.x * 100.0)) * 1000000 \
		+ int(round(point.y * 100.0))


func _line_walkable(a: Vector2, b: Vector2) -> bool:
	var dx: int = absi(int(floor(b.x)) - int(floor(a.x)))
	var dy: int = absi(int(floor(b.y)) - int(floor(a.y)))
	var steps: int = maxi(dx, dy)
	if steps == 0:
		return not world.is_blocked_tile(int(floor(a.x)), int(floor(a.y)))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t)
		var tx: int = int(floor(p.x))
		var ty: int = int(floor(p.y))
		if tx < 0 or tx >= size or ty < 0 or ty >= size:
			return false
		if walkable[ty * size + tx] == 0:
			return false
	return true


func _carve_anchor(point: Vector2) -> void:
	var tx: int = int(floor(point.x))
	var ty: int = int(floor(point.y))
	if tx < 0 or tx >= size or ty < 0 or ty >= size:
		return
	if world.is_blocked_tile(tx, ty):
		return
	var road_tile: Vector2i = _nearest_road_tile(tx, ty, 48)
	if road_tile.x < 0:
		return
	_carve_line(tx, ty, road_tile.x, road_tile.y)


func _nearest_road_tile(tx: int, ty: int, max_radius: int) -> Vector2i:
	for radius in range(0, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if radius > 0 and absi(dx) != radius and absi(dy) != radius:
					continue
				var nx: int = tx + dx
				var ny: int = ty + dy
				if nx < 0 or nx >= size or ny < 0 or ny >= size:
					continue
				if world.road[ny * size + nx] != 0:
					return Vector2i(nx, ny)
	return Vector2i(-1, -1)


func _carve_line(x0: int, y0: int, x1: int, y1: int) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	var x: int = x0
	var y: int = y0
	while true:
		if x >= 0 and x < size and y >= 0 and y < size:
			if not world.is_blocked_tile(x, y):
				walkable[y * size + x] = 1
		if x == x1 and y == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


func begin_frame() -> void:
	frame_begins += 1
	if frame_lookups > max_lookups_per_frame:
		max_lookups_per_frame = frame_lookups
	if frame_recalcs > max_recalcs_per_frame:
		max_recalcs_per_frame = frame_recalcs
	frame_lookups = 0
	frame_recalcs = 0
	frame_deferred = 0
	last_deferred = false
	last_defer_frames = 1


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
		_mark_deferred()
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
		return _materialize(_cache[key] as PackedVector2Array, start_point, goal_point)
	if scale_mode:
		var graph_path: PackedVector2Array = _scale_graph_path(start_point, goal_point)
		if not graph_path.is_empty():
			graph_paths += 1
			recalculations += 1
			cache_misses += 1
			_store(key, graph_path)
			return _materialize(graph_path, start_point, goal_point)
		grid_fallbacks += 1
	if frame_recalcs >= recalc_budget:
		_mark_deferred()
		return PackedVector2Array()
	frame_recalcs += 1
	recalculations += 1
	cache_misses += 1
	var tile_path: PackedVector2Array = _astar(start_idx, goal_idx)
	if tile_path.is_empty():
		return PackedVector2Array()
	_store(key, tile_path)
	return _materialize(tile_path, start_point, goal_point)


## A* auf dem kleinen Straßen-Wegpunktgraph. Die lokalen Endstücke
## (Tür/Feldmitte -> Wegpunkt) sind gerade und begehbar; _materialize fügt
## Start/Ziel wieder exakt ein.
func _scale_graph_path(start_point: Vector2, goal_point: Vector2) -> PackedVector2Array:
	if _scale_graph == null:
		return PackedVector2Array()
	var a: int = int(_scale_anchor_node.get(_anchor_key(start_point), -1))
	var b: int = int(_scale_anchor_node.get(_anchor_key(goal_point), -1))
	if a < 0 or b < 0:
		return PackedVector2Array()
	var ids: PackedInt64Array = _scale_graph.get_id_path(a, b)
	if ids.is_empty():
		return PackedVector2Array()
	var out: PackedVector2Array = PackedVector2Array()
	for id in ids:
		out.append(_scale_points[int(id)])
	if out.is_empty():
		return PackedVector2Array()
	return _compress(out)


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
	var tile_path: PackedVector2Array
	if scale_mode:
		tile_path = _scale_graph_path(start_point, goal_point)
		if tile_path.is_empty():
			prewarm_grid += 1
			tile_path = _astar(start_idx, goal_idx)
		else:
			prewarm_graph += 1
	else:
		tile_path = _astar(start_idx, goal_idx)
	if tile_path.is_empty():
		return
	_store(key, tile_path)
	prewarm_recalculations += 1


## Konventionelle Cache-Hit-Rate: Hits unter den tatsächlich konsultierten
## Pfadanfragen. Budget-Vertagungen sind keine Cache-Misses.
func _mark_deferred() -> void:
	frame_deferred += 1
	deferred_total += 1
	last_deferred = true
	if defer_window > 1:
		last_defer_frames = 1 + (defer_cursor % defer_window)
		defer_cursor += 1
	else:
		last_defer_frames = 1


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
	_evict_queue.clear()
	_evict_head = 0


## Setzt nur die abgeleitete Laufzeitwarteschlange zurück. Der Cache wird
## anschließend deterministisch neu aufgebaut; autoritativer Zustand bleibt
## unberührt. Wird vor Save und nach Load genutzt, damit die Fortsetzung nicht
## von der Cache-Historie abhängt.
func reset_defer_runtime() -> void:
	defer_cursor = 0
	last_deferred = false
	last_defer_frames = 1
	frame_lookups = 0
	frame_recalcs = 0
	frame_deferred = 0


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
		"frame_begins": frame_begins,
		"graph_paths": graph_paths,
		"grid_fallbacks": grid_fallbacks,
		"prewarm_graph": prewarm_graph,
		"prewarm_grid": prewarm_grid,
		"max_lookups_per_frame": max_lookups_per_frame,
		"max_recalcs_per_frame": max_recalcs_per_frame,
		"map_version": map_version,
	}


func _cache_key(start_idx: int, goal_idx: int) -> int:
	return (map_version * 1099511627776) + (start_idx * 1048576) + goal_idx


func _store(key: int, path: PackedVector2Array) -> void:
	if _cache.has(key):
		_cache[key] = path
		return
	if _cache.size() >= cache_capacity:
		_evict_one()
	_cache[key] = path
	_evict_queue.append(key)


func _evict_one() -> void:
	while _evict_head < _evict_queue.size():
		var key: int = _evict_queue[_evict_head]
		_evict_head += 1
		if _cache.has(key):
			_cache.erase(key)
			return
	# Warteschlange verbraucht (nur bei invalidate/Reinsert möglich): Neustart.
	_evict_queue.clear()
	_evict_head = 0


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
