extends RefCounted

## G4c-P2.1b: kompakter Oval-/Ring-Kern mit echten 16x16-House-Rows und
## Farmstead-Prefabs. Reines Layout/View-Modul; keine Simulation, kein Save,
## keine Balance. Segmente kommen aus segments.json; Prefabs werden in
## world_view_p2.gd aus Kenney-RPG-Tiles komponiert.

const WORLD_SIZE: int = 176
const CENTER: Vector2i = Vector2i(88, 88)
const SEGMENTS_PATH: String = "res://tests/g4c_p2/segments.json"

## 8 versetzte House-Rows mit je 3 Haeusern -> 24 Haeuser. Die Hoehen/Abstaende
## sind bewusst unregelmaessig; die Reihen bleiben an Ring/Gassen angebunden.
## Acht kurze Hauscluster (je 3 Haeuser) rund um den Platz. Kein Oval-Ring;
## die Cluster werden ueber radiale Wege angebunden.
const ROW_SLOTS: Array = [
	{"x": 80, "y": 50, "wall": 0},
	{"x": 112, "y": 58, "wall": 1},
	{"x": 128, "y": 84, "wall": 2},
	{"x": 112, "y": 110, "wall": 0},
	{"x": 80, "y": 120, "wall": 1},
	{"x": 48, "y": 110, "wall": 2},
	{"x": 32, "y": 84, "wall": 0},
	{"x": 48, "y": 58, "wall": 1},
]

const FARMSTEAD_RECTS: Array = [
	Rect2i(60, 16, 16, 16), Rect2i(142, 50, 16, 16),
	Rect2i(56, 138, 16, 16),
]

## 6 Feldparzellen, je 2 an einem Hof (0/1 -> Hof 0, 2/3 -> Hof 1, 4/5 -> Hof 2).
const FIELD_RECTS: Array = [
	Rect2i(42, 20, 10, 8), Rect2i(42, 30, 10, 8),
	Rect2i(148, 74, 10, 8), Rect2i(148, 86, 10, 8),
	Rect2i(78, 140, 10, 8), Rect2i(78, 150, 10, 8),
]

const ORCHARD_RECTS: Array = [
	Rect2i(18, 52, 12, 12), Rect2i(142, 100, 12, 12),
	Rect2i(112, 18, 10, 10),
]

const CIVIC: Array = [
	{"kind": "workshop", "rect": Rect2i(71, 81, 8, 6), "roof": "slate"},
	{"kind": "granary", "rect": Rect2i(97, 81, 7, 5), "roof": "warm_ochre"},
]

var segments: Dictionary = {}
var rng: RandomNumberGenerator
var layout: Dictionary


func generate(seed_value: int = 421337) -> Dictionary:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	_load_segments()
	layout = {
		"version": 2,
		"seed": seed_value,
		"size": WORLD_SIZE,
		"meters_per_tile": 1.5,
		"day_length": 120,
		"roads": {},
		"plaza": {},
		"plaza_rect": Rect2i(81, 83, 14, 10),
		"houses": [],
		"house_rows": [],
		"fields": [],
		"farmsteads": [],
		"civic": [],
		"pond": {},
		"orchards": [],
		"orchard": Rect2i(-1, -1, 0, 0),
		"trees": [],
		"props": [],
		"gates": [],
		"wall_plan": [],
	}
	_stamp_plaza()
	_place_civic()
	_place_house_rows()
	_stamp_cluster_paths()
	_stamp_farm_roads()
	_place_fields()
	_place_farmsteads()
	_place_pond()
	_place_orchards()
	_scatter_trees()
	_place_props()
	_add_wall_plan()
	layout["walkable_count"] = (layout["roads"] as Dictionary).size()
	return layout


func _load_segments() -> void:
	var text: String = FileAccess.get_file_as_string(SEGMENTS_PATH)
	var data = JSON.parse_string(text)
	if data == null or not data.has("segments"):
		push_error("segments.json unlesbar: %s" % SEGMENTS_PATH)
		return
	segments = {"version": int(data.get("version", 1)), "by_id": {}}
	for s in data["segments"]:
		segments["by_id"][s["id"]] = s
	layout["segments_version"] = segments["version"]


func _stamp_plaza() -> void:
	var rect: Rect2i = layout["plaza_rect"]
	var cx: float = float(rect.position.x) + float(rect.size.x) * 0.5
	var cy: float = float(rect.position.y) + float(rect.size.y) * 0.5
	var rx: float = float(rect.size.x) * 0.5
	var ry: float = float(rect.size.y) * 0.5
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var dx: float = (float(x) - cx) / rx
			var dy: float = (float(y) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var t: Vector2i = Vector2i(x, y)
				layout["plaza"][t] = true
				layout["roads"][t] = 2


func _stamp_cluster_paths() -> void:
	var plaza: Rect2i = layout["plaza_rect"]
	var pc: Vector2 = Vector2(plaza.position) + Vector2(plaza.size) * 0.5
	for ri in (layout["house_rows"] as Array).size():
		var row: Dictionary = layout["house_rows"][ri]
		var rr: Rect2i = row["rect"]
		var target: Vector2 = Vector2(
			clampf(pc.x, float(rr.position.x), float(rr.position.x + rr.size.x - 1)),
			clampf(pc.y, float(rr.position.y), float(rr.position.y + rr.size.y - 1)))
		var start: Vector2 = Vector2(
			clampf(target.x, float(plaza.position.x),
				float(plaza.position.x + plaza.size.x - 1)),
			clampf(target.y, float(plaza.position.y),
				float(plaza.position.y + plaza.size.y - 1)))
		_stamp_wavy_path(start, target, ri)


func _stamp_wavy_path(a: Vector2, b: Vector2, salt: int) -> void:
	var dist: float = a.distance_to(b)
	if dist < 0.1:
		return
	var steps: int = maxi(2, int(dist))
	var dir: Vector2 = (b - a).normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var p: Vector2 = a.lerp(b, t) \
			+ perp * sin(t * PI * 2.6 + float(salt) * 0.73) * 1.4
		var tile: Vector2i = Vector2i(int(round(p.x)), int(round(p.y)))
		_stamp_road(tile)
		var side: Vector2i = tile + Vector2i(0, 1)
		if not _is_occupied(side):
			_stamp_road(side)


func _stamp_road(t: Vector2i, kind: int = 1) -> void:
	if t.x < 3 or t.y < 3 or t.x >= WORLD_SIZE - 3 or t.y >= WORLD_SIZE - 3:
		return
	if (layout["plaza"] as Dictionary).has(t):
		return
	if _is_occupied(t):
		return
	layout["roads"][t] = kind


func _stamp_ring_road() -> void:
	var rx: float = 54.0
	var ry: float = 46.0
	for y in range(CENTER.y - 54, CENTER.y + 55):
		for x in range(CENTER.x - 62, CENTER.x + 63):
			var dx: float = float(x - CENTER.x)
			var dy: float = float(y - CENTER.y)
			var a: float = atan2(dy, dx)
			var wob: float = sin(a * 3.0 + 1.3) * 2.4 + sin(a * 5.0 + 0.7) * 1.2
			var d: float = sqrt((dx / (rx + wob)) * (dx / (rx + wob))
				+ (dy / (ry + wob)) * (dy / (ry + wob)))
			# Drei unregelmaessige Luecken brechen den perfekten Oval-Ring auf.
			var gap: bool = (a > 0.55 and a < 0.85) \
				or (a > 2.45 and a < 2.75) \
				or (a > -2.55 and a < -2.25)
			if not gap and d >= 0.975 and d <= 1.026:
				_stamp_road(Vector2i(x, y))


func _stamp_cross_streets() -> void:
	for y in range(40, 137):
		var x: int = 88 + int(round(sin(float(y) * 0.09) * 1.4
			+ sin(float(y) * 0.031 + 1.0) * 1.2))
		_stamp_road(Vector2i(x, y))
		_stamp_road(Vector2i(x + 1, y))
	for x in range(40, 137):
		var y: int = 88 + int(round(sin(float(x) * 0.08 + 2.1) * 1.4))
		_stamp_road(Vector2i(x, y))
		_stamp_road(Vector2i(x, y + 1))


func _stamp_lanes() -> void:
	var lanes: Array = [
		{"base": 77, "x0": 44, "x1": 132},
		{"base": 98, "x0": 44, "x1": 132},
		{"base": 121, "x0": 44, "x1": 132},
	]
	for lane in lanes:
		var base_y: int = int(lane["base"])
		for x in range(int(lane["x0"]), int(lane["x1"]) + 1):
			var wob: float = sin(float(x) * 0.11 + float(base_y) * 0.07) * 1.2
			var y: int = base_y + int(round(wob))
			_stamp_road(Vector2i(x, y))
			_stamp_road(Vector2i(x, y + 1))
	layout["lanes"] = lanes


func _stamp_farm_roads() -> void:
	# Nordhof -> Ring.
	for y in range(32, 47):
		_stamp_road(Vector2i(67, y))
		_stamp_road(Vector2i(68, y))
	# Osthof -> Ring und Feldzufahrt.
	for x in range(129, 142):
		_stamp_road(Vector2i(x, 57))
		_stamp_road(Vector2i(x, 58))
	for y in range(66, 95):
		_stamp_road(Vector2i(145, y))
		_stamp_road(Vector2i(146, y))
	# Suedhof -> Ring.
	for y in range(129, 138):
		_stamp_road(Vector2i(64, y))
		_stamp_road(Vector2i(65, y))
	# Teichstich.
	for x in range(28, 37):
		_stamp_road(Vector2i(x, 95))
		_stamp_road(Vector2i(x, 96))
	# Feldzufahrten.
	for x in range(52, 60):
		_stamp_road(Vector2i(x, 24))
		_stamp_road(Vector2i(x, 34))
	for x in range(72, 78):
		_stamp_road(Vector2i(x, 144))
		_stamp_road(Vector2i(x, 154))


func _place_house_rows() -> void:
	for ri in ROW_SLOTS.size():
		var slot: Dictionary = ROW_SLOTS[ri]
		var row_rect: Rect2i = Rect2i(int(slot["x"]), int(slot["y"]), 16, 16)
		if not _rect_free(row_rect, 0):
			continue
		_occupy_rect(row_rect, true)
		var wall: int = int(slot["wall"])
		var count: int = int(slot.get("count", 3))
		var houses: Array = []
		var doors: Array = []
		for hi in count:
			var variant: int = wall * 3 + (ri + hi) % 3
			var wh: Array = _house_size(variant)
			var h_rect: Rect2i = Rect2i(row_rect.position.x + hi * 5,
				row_rect.position.y, int(wh[0]), int(wh[1]))
			var door: Vector2i = Vector2i(h_rect.position.x + h_rect.size.x / 2,
				h_rect.position.y + h_rect.size.y - 1)
			houses.append({"rect": h_rect, "variant": variant,
				"door": door, "row": ri})
			doors.append(door)
			(layout["houses"] as Array).append({
				"rect": h_rect, "variant": variant, "door": door,
				"lane": -1, "row": ri, "garden": Rect2i(-1, -1, 0, 0),
				"garden_side": 0, "fence": false,
			})
		var garden: Rect2i = Rect2i(row_rect.position.x + 1,
			row_rect.position.y + 9, 14, 5)
		(layout["house_rows"] as Array).append({
			"rect": row_rect, "houses": houses, "doors": doors,
			"garden": garden, "wall": wall,
			"fence": true,
		})


func _place_fields() -> void:
	for i in FIELD_RECTS.size():
		var rect: Rect2i = FIELD_RECTS[i]
		if not _rect_free(rect, 0):
			continue
		_occupy_rect(rect, true)
		(layout["fields"] as Array).append({
			"rect": rect,
			"index": i,
			"farm": i / 2,
			"stage": [3, 4, 5, 2, 4, 3][i],
			"hedge": i % 3 != 1,
			"fence": i % 3 == 1,
		})


func _place_civic() -> void:
	for c in CIVIC:
		var rect: Rect2i = c["rect"]
		if not _rect_free(rect, 0):
			continue
		_occupy_rect(rect, true)
		(layout["civic"] as Array).append({
			"kind": c["kind"], "rect": rect, "roof": c["roof"]})


func _place_farmsteads() -> void:
	for i in FARMSTEAD_RECTS.size():
		var rect: Rect2i = FARMSTEAD_RECTS[i]
		if not _rect_free(rect, 0):
			continue
		_occupy_rect(rect, true)
		var house_local: Vector2i = Vector2i(9, 1)
		var barn_local: Vector2i = Vector2i(1, 2)
		var house_rect: Rect2i = Rect2i(rect.position + house_local, Vector2i(6, 7))
		var barn_rect: Rect2i = Rect2i(rect.position + barn_local, Vector2i(7, 6))
		var yard: Rect2i = Rect2i(rect.position + Vector2i(2, 9), Vector2i(12, 6))
		var variant: int = 9 + i % 3
		_occupy_rect(house_rect, true)
		_occupy_rect(barn_rect, true)
		(layout["farmsteads"] as Array).append({
			"index": i, "rect": rect, "variant": variant,
			"house_local": house_local, "barn_local": barn_local,
			"house_rect": house_rect, "barn_rect": barn_rect,
			"yard": yard, "fence": true,
		})
		var yard_x: int = yard.position.x
		var yard_y: int = yard.position.y
		(layout["props"] as Array).append({"kind": "cart",
			"tile": Vector2i(yard_x + 2, yard_y + 3)})
		(layout["props"] as Array).append({"kind": "barrel",
			"tile": Vector2i(yard_x + 7, yard_y + 2)})
		(layout["props"] as Array).append({"kind": "woodpile",
			"tile": Vector2i(yard_x + 9, yard_y + 3)})


func _place_pond() -> void:
	var center := Vector2(18.0, 96.0)
	var rx: float = 10.0
	var ry: float = 7.0
	var water: Array = []
	var shore: Array = []
	for y in range(86, 107):
		for x in range(5, 32):
			var dx: float = (float(x) - center.x) / rx
			var dy: float = (float(y) - center.y) / ry
			var d: float = dx * dx + dy * dy
			if d <= 1.0:
				water.append(Vector2i(x, y))
			elif d <= 1.38:
				shore.append(Vector2i(x, y))
	layout["pond"] = {"center": center, "water": water, "shore": shore}
	for t in water:
		(layout["roads"] as Dictionary).erase(t)
		_occupy_rect(Rect2i(t.x, t.y, 1, 1), true)


func _place_orchards() -> void:
	for i in ORCHARD_RECTS.size():
		var rect: Rect2i = ORCHARD_RECTS[i]
		if not _rect_free(rect, 1):
			continue
		_occupy_rect(rect, true)
		var trees: Array = []
		for gy in range(2, rect.size.y - 1, 3):
			for gx in range(2, rect.size.x - 1, 3):
				var t: Vector2i = rect.position + Vector2i(gx, gy)
				(layout["trees"] as Array).append({
					"tile": t, "variant": (t.x + t.y) % 3, "fruit": true})
				trees.append(t)
		(layout["orchards"] as Array).append({
			"rect": rect, "trees": trees, "index": i})


func _scatter_trees() -> void:
	# Geclusterte Waeldchen/Hecken statt gleichmaessiger Punkte.
	var clusters: Array = [
		{"c": Vector2(14.0, 22.0), "r": 8.0, "n": 26},
		{"c": Vector2(30.0, 132.0), "r": 9.0, "n": 28},
		{"c": Vector2(156.0, 30.0), "r": 8.0, "n": 24},
		{"c": Vector2(154.0, 140.0), "r": 9.0, "n": 28},
		{"c": Vector2(100.0, 162.0), "r": 7.0, "n": 18},
		{"c": Vector2(38.0, 74.0), "r": 5.0, "n": 10},
	]
	for cluster in clusters:
		var c: Vector2 = cluster["c"]
		var radius: float = cluster["r"]
		var placed: int = 0
		var tries: int = 0
		while placed < int(cluster["n"]) and tries < 260:
			tries += 1
			var ang: float = rng.randf_range(0.0, TAU)
			var rad: float = radius * sqrt(rng.randf()) * rng.randf_range(0.55, 1.0)
			var t: Vector2i = Vector2i(int(round(c.x + cos(ang) * rad)),
				int(round(c.y + sin(ang) * rad)))
			if not _tree_spot_free(t):
				continue
			_occupy_rect(Rect2i(t.x, t.y, 1, 1), true)
			(layout["trees"] as Array).append({
				"tile": t, "variant": (t.x * 7 + t.y * 13) % 3,
				"fruit": false})
			placed += 1
	# Einzelbaeume an Gassen und Platzrändern.
	var lane_trees: Array = [
		Vector2i(45, 79), Vector2i(47, 100), Vector2i(129, 79),
		Vector2i(131, 100), Vector2i(55, 47), Vector2i(121, 47),
		Vector2i(55, 129), Vector2i(121, 129), Vector2i(77, 79),
		Vector2i(99, 79),
	]
	for t in lane_trees:
		if _tree_spot_free(t):
			_occupy_rect(Rect2i(t.x, t.y, 1, 1), true)
			(layout["trees"] as Array).append({
				"tile": t, "variant": (t.x + t.y * 3) % 3, "fruit": false})


func _tree_spot_free(t: Vector2i) -> bool:
	if t.x < 6 or t.y < 6 or t.x >= WORLD_SIZE - 6 or t.y >= WORLD_SIZE - 6:
		return false
	if _is_walkable(t) or _is_occupied(t):
		return false
	if _near_rect(t, layout["plaza_rect"], 1):
		return false
	return true


func _place_props() -> void:
	var props: Array = [
		{"kind": "well", "tile": Vector2i(88, 88)},
		{"kind": "market", "tile": Vector2i(83, 86)},
		{"kind": "market", "tile": Vector2i(91, 86)},
		{"kind": "bench", "tile": Vector2i(84, 92)},
		{"kind": "bench", "tile": Vector2i(92, 92)},
		{"kind": "bench", "tile": Vector2i(88, 93)},
		{"kind": "barrel", "tile": Vector2i(68, 85)},
		{"kind": "barrel", "tile": Vector2i(104, 85)},
		{"kind": "cart", "tile": Vector2i(68, 94)},
		{"kind": "woodpile", "tile": Vector2i(104, 93)},
		{"kind": "laundry", "tile": Vector2i(105, 91)},
		{"kind": "sack", "tile": Vector2i(69, 85)},
		{"kind": "sack", "tile": Vector2i(70, 85)},
	]
	for p in props:
		(layout["props"] as Array).append(p)


func _add_wall_plan() -> void:
	# Nur Planung: Wall/Gate/Tower-Segmente fuer spaetere Siedlungstypen.
	layout["wall_plan"] = [
		{"segment": "wall_stone", "side": "n", "y": 8},
		{"segment": "wall_stone", "side": "s", "y": 168},
		{"segment": "gate_wood", "side": "n", "x": 88},
		{"segment": "gate_wood", "side": "s", "x": 88},
		{"segment": "tower", "side": "nw", "tile": Vector2i(10, 10)},
		{"segment": "tower", "side": "se", "tile": Vector2i(166, 166)},
	]


func _house_size(variant: int) -> Array:
	var variants: Array = house_variants()
	if variant >= 0 and variant < variants.size():
		var size: Array = variants[variant].get("size", [5, 6])
		return [int(size[0]), int(size[1])]
	return [5, 6]


func _rect_free(rect: Rect2i, margin: int) -> bool:
	if rect.position.x - margin < 4 or rect.position.y - margin < 4:
		return false
	if rect.position.x + rect.size.x + margin > WORLD_SIZE - 4:
		return false
	if rect.position.y + rect.size.y + margin > WORLD_SIZE - 4:
		return false
	for y in range(rect.position.y - margin,
			rect.position.y + rect.size.y + margin):
		for x in range(rect.position.x - margin,
				rect.position.x + rect.size.x + margin):
			var t: Vector2i = Vector2i(x, y)
			if _is_walkable(t) or _is_occupied(t):
				return false
	return true


func _occupy_rect(rect: Rect2i, mark: bool) -> void:
	if not layout.has("occupied"):
		layout["occupied"] = {}
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			(layout["occupied"] as Dictionary)[Vector2i(x, y)] = mark


func _is_occupied(t: Vector2i) -> bool:
	return (layout.get("occupied", {}) as Dictionary).has(t)


func _is_walkable(t: Vector2i) -> bool:
	return (layout["roads"] as Dictionary).has(t)


func _near_rect(t: Vector2i, rect: Rect2i, margin: int) -> bool:
	return t.x >= rect.position.x - margin and t.y >= rect.position.y - margin \
		and t.x < rect.position.x + rect.size.x + margin \
		and t.y < rect.position.y + rect.size.y + margin


func house_variants() -> Array:
	var text: String = FileAccess.get_file_as_string(SEGMENTS_PATH)
	var data = JSON.parse_string(text)
	if data == null:
		return []
	return data.get("house_variants", [])


func summary() -> Dictionary:
	return {
		"houses": (layout["houses"] as Array).size(),
		"rows": (layout["house_rows"] as Array).size(),
		"farmsteads": (layout["farmsteads"] as Array).size(),
		"fields": (layout["fields"] as Array).size(),
		"roads": (layout["roads"] as Dictionary).size(),
		"trees": (layout["trees"] as Array).size(),
		"orchards": (layout["orchards"] as Array).size(),
		"civic": (layout["civic"] as Array).size(),
		"walkable": layout.get("walkable_count", 0),
	}
