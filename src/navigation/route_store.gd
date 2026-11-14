class_name RouteStore
extends RefCounted

## Routen als Polylinien. Agenten halten nur route_id (SoA, keine Per-Agent-
## Dictionaries). Routen sind kurz und werden nicht gecacht.

var routes: Array = []
## Abgeleitete Länge je Route; vermeidet Polyline-Summen pro Marker-Frame.
var lengths: PackedFloat64Array = PackedFloat64Array()


func create(points: PackedVector2Array) -> int:
	var id: int = routes.size()
	routes.append(points)
	lengths.append(WorldMap.polyline_length(points))
	return id


func get_points(route_id: int) -> PackedVector2Array:
	if route_id < 0 or route_id >= routes.size():
		return PackedVector2Array()
	return routes[route_id]


func length(route_id: int) -> float:
	if route_id < 0 or route_id >= lengths.size():
		return 0.0
	return lengths[route_id]


func clear() -> void:
	routes.clear()
	lengths.clear()


## Entfernt nicht mehr referenzierte Routen (abgeleitete Geometrie) und
## remappt die route_id der Agenten. Deterministisch, ohne Event-/RNG-Effekt.
func compact(store: AgentStore) -> void:
	var used: PackedByteArray = PackedByteArray()
	used.resize(routes.size())
	for i in used.size():
		used[i] = 0
	for row in store.count:
		var rid: int = store.route_id[row]
		if rid >= 0 and rid < routes.size():
			used[rid] = 1
	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(routes.size())
	for i in mapping.size():
		mapping[i] = -1
	var kept: Array = []
	var kept_lengths: PackedFloat64Array = PackedFloat64Array()
	for i in routes.size():
		if used[i] == 0:
			continue
		mapping[i] = kept.size()
		kept.append(routes[i])
		kept_lengths.append(lengths[i] if i < lengths.size() else 0.0)
	routes = kept
	lengths = kept_lengths
	for row in store.count:
		var rid2: int = store.route_id[row]
		if rid2 >= 0 and rid2 < mapping.size():
			store.route_id[row] = mapping[rid2]


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, routes.size())
	for route in routes:
		var pts: PackedVector2Array = route
		h = HashUtil.mix(h, pts.size())
		for p in pts:
			h = HashUtil.mix_f64(h, p.x)
			h = HashUtil.mix_f64(h, p.y)
	return h
