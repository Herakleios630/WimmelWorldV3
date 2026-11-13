class_name RouteStore
extends RefCounted

## Routen als Polylinien. Agenten halten nur route_id (SoA, keine Per-Agent-
## Dictionaries). Routen sind kurz und werden nicht gecacht.

var routes: Array = []


func create(points: PackedVector2Array) -> int:
	var id: int = routes.size()
	routes.append(points)
	return id


func get_points(route_id: int) -> PackedVector2Array:
	if route_id < 0 or route_id >= routes.size():
		return PackedVector2Array()
	return routes[route_id]


func length(route_id: int) -> float:
	return WorldMap.polyline_length(get_points(route_id))


func clear() -> void:
	routes.clear()


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
