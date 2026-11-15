extends RefCounted

## G4c-P2.1a: port-basierter, deterministischer Siedlungsgenerator.
## Reines Layout/View-Modul; keine Simulation, kein Save, keine Balance.
## Segmente kommen aus segments.json; Prefabs werden in world_view_p2.gd
## aus Kenney-RPG-Tiles komponiert.

const WORLD_SIZE: int = 384
const SEGMENTS_PATH: String = "res://tests/g4c_p2/segments.json"

const LANE_BASES: Array = [96, 126, 156, 238, 268, 298]
const FIELD_RECTS: Array = [
	Rect2i(38, 148, 10, 8), Rect2i(38, 202, 10, 8),
	Rect2i(38, 256, 10, 8), Rect2i(318, 150, 10, 8),
	Rect2i(318, 212, 10, 8), Rect2i(152, 330, 10, 8),
]
const CIVIC: Array = [
	{"kind": "barn", "rect": Rect2i(166, 188, 9, 7), "roof": "warm_brown"},
	{"kind": "workshop", "rect": Rect2i(202, 190, 8, 7), "roof": "slate"},
	{"kind": "granary", "rect": Rect2i(170, 204, 6, 5), "roof": "warm_ochre"},
]

var segments: Dictionary = {}
var rng: RandomNumberGenerator
var layout: Dictionary


func generate(seed_value: int = 421337) -> Dictionary:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	_load_segments()
	layout = {
		"version": 1,
		"seed": seed_value,
		"size": WORLD_SIZE,
		"meters_per_tile": 1.5,
		"day_length": 120,
		"roads": {},
		"plaza": {},
		"plaza_rect": Rect2i(183, 186, 18, 14),
		"houses": [],
		"fields": [],
		"civic": [],
		"pond": {},
		"orchard": Rect2i(62, 86, 18, 12),
		"trees": [],
		"props": [],
		"gates": [],
		"wall_plan": [],
	}
	_occupy_rect(layout["plaza_rect"], false)
	_stamp_plaza(layout["plaza_rect"])
	_stamp_vertical_avenue()
	_stamp_lanes()
	_place_houses()
	_place_fields()
	_place_civic()
	_place_pond()
	_place_orchard()
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


func _stamp_plaza(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var t: Vector2i = Vector2i(x, y)
			layout["plaza"][t] = true
			layout["roads"][t] = 2


func _stamp_road(t: Vector2i, kind: int = 1) -> void:
	if t.x < 2 or t.y < 2 or t.x >= WORLD_SIZE - 2 or t.y >= WORLD_SIZE - 2:
		return
	if (layout["plaza"] as Dictionary).has(t):
		return
	layout["roads"][t] = kind


func _stamp_vertical_avenue() -> void:
	for y in range(58, 334):
		var x: int = 192 + int(round(sin(float(y) * 0.045) * 5.0
			+ sin(float(y) * 0.013 + 1.7) * 7.0))
		_stamp_road(Vector2i(x, y))
		_stamp_road(Vector2i(x + 1, y))


func _stamp_lanes() -> void:
	var lanes: Array = []
	for li in LANE_BASES.size():
		var base_y: int = LANE_BASES[li]
		var phase: float = float(li) * 1.31 + 0.4
		var phase2: float = float(li) * 0.77
		var ys: Dictionary = {}
		for x in range(132, 254):
			var y: int = base_y + int(round(sin(float(x - 132) * 0.055
				+ phase) * 3.0 + sin(float(x) * 0.11 + phase2) * 1.4))
			ys[x] = y
			_stamp_road(Vector2i(x, y))
			_stamp_road(Vector2i(x, y + 1))
		lanes.append({"index": li, "base_y": base_y, "ys": ys,
			"x0": 132, "x1": 253})
	layout["lanes"] = lanes


func _place_houses() -> void:
	var variants: Array = [
		[6, 6], [7, 6], [6, 7], [8, 7], [7, 7],
		[8, 8], [6, 6], [6, 6], [8, 7]]
	var lanes: Array = layout["lanes"]
	for lane in lanes:
		var ys: Dictionary = lane["ys"]
		var placed: int = 0
		var x: int = 140
		while x < 246 and placed < 4:
			var vi: int = int((int(lane["index"]) * 4 + placed
				+ int(rng.randi_range(0, 1))) % variants.size())
			var wh: Array = variants[vi]
			var w: int = int(wh[0])
			var h: int = int(wh[1])
			var cx: int = x + w / 2
			var lane_y: int = int(ys.get(clampi(cx, 132, 253), lane["base_y"]))
			var rect: Rect2i = Rect2i(cx - w / 2, lane_y - h, w, h)
			var door_tile: Vector2i = Vector2i(rect.position.x + w / 2,
				lane_y - 1)
			var flat: bool = true
			for dx in range(-w / 2, w / 2 + 1):
				var ly: int = int(ys.get(clampi(cx + dx, 132, 253), lane_y))
				if absi(ly - lane_y) > 1:
					flat = false
			var garden_side: int = 1 if rng.randf() < 0.55 else -1
			var garden: Rect2i = Rect2i(
				rect.position.x + (w + 1 if garden_side > 0 else -5),
				rect.position.y + 2, 4, 4)
			if flat and _rect_free(rect, 0) and _rect_free(garden, 0) \
					and _is_road(Vector2i(rect.position.x + w / 2, lane_y)) \
					and _is_road(Vector2i(rect.position.x + w / 2, lane_y + 1)):
				_occupy_rect(rect, true)
				_occupy_rect(garden, true)
				(layout["houses"] as Array).append({
					"rect": rect,
					"variant": vi,
					"door": door_tile,
					"lane": int(lane["index"]),
					"garden": garden,
					"garden_side": garden_side,
					"fence": rng.randf() < 0.8,
				})
				placed += 1
			x += w + int(rng.randi_range(5, 11))
	# Restliche Häuser als kleine Nachbarschaft südlich des Platzes.
	var spare_rects: Array = [
		Rect2i(150, 212, 6, 6), Rect2i(158, 214, 6, 6),
		Rect2i(214, 210, 7, 6), Rect2i(222, 212, 6, 7),
		Rect2i(132, 212, 7, 6), Rect2i(232, 212, 7, 6),
		Rect2i(132, 240, 6, 6), Rect2i(232, 244, 7, 6),
		Rect2i(148, 260, 7, 6), Rect2i(232, 278, 6, 6),
		Rect2i(132, 282, 6, 6), Rect2i(216, 294, 6, 6),
	]
	for r in spare_rects:
		if (layout["houses"] as Array).size() >= 24:
			break
		var rr: Rect2i = r
		if _rect_free(rr, 0):
			_occupy_rect(rr, true)
			var door: Vector2i = Vector2i(rr.position.x + rr.size.x / 2,
				rr.position.y + rr.size.y)
			var spare_garden: Rect2i = Rect2i(rr.position.x + rr.size.x + 1,
				rr.position.y + 2, 3, 3)
			if _rect_free(spare_garden, 0):
				_occupy_rect(spare_garden, true)
			else:
				spare_garden = Rect2i(-1, -1, 0, 0)
			(layout["houses"] as Array).append({
				"rect": rr,
				"variant": int(rng.randi_range(0, 8)),
				"door": door,
				"lane": -1,
				"garden": spare_garden,
				"garden_side": 1,
				"fence": true,
			})


func _place_fields() -> void:
	for i in FIELD_RECTS.size():
		var rect: Rect2i = FIELD_RECTS[i]
		if not _rect_free(rect, 1):
			continue
		_occupy_rect(rect, true)
		(layout["fields"] as Array).append({
			"rect": rect,
			"index": i,
			"stage": [3, 4, 5, 2, 4, 3][i],
			"hedge": i % 2 == 0,
			"fence": i % 2 == 1,
		})


func _place_civic() -> void:
	for c in CIVIC:
		var rect: Rect2i = c["rect"]
		if not _rect_free(rect, 0):
			continue
		_occupy_rect(rect, true)
		(layout["civic"] as Array).append({
			"kind": c["kind"], "rect": rect, "roof": c["roof"]})


func _place_pond() -> void:
	var center := Vector2(304.0, 82.0)
	var rx: float = 15.0
	var ry: float = 9.0
	var water: Array = []
	var shore: Array = []
	for y in range(68, 98):
		for x in range(284, 326):
			var dx: float = (float(x) - center.x) / rx
			var dy: float = (float(y) - center.y) / ry
			var d: float = dx * dx + dy * dy
			if d <= 1.0:
				water.append(Vector2i(x, y))
			elif d <= 1.42:
				shore.append(Vector2i(x, y))
	layout["pond"] = {"center": center, "water": water, "shore": shore}
	for t in water:
		(layout["roads"] as Dictionary).erase(t)
		_occupy_rect(Rect2i(t.x, t.y, 1, 1), true)


func _place_orchard() -> void:
	var rect: Rect2i = layout["orchard"]
	if not _rect_free(rect, 1):
		layout["orchard"] = Rect2i(-1, -1, 0, 0)
		return
	_occupy_rect(rect, true)
	var trees: Array = []
	for gy in range(2, rect.size.y - 1, 3):
		for gx in range(2, rect.size.x - 1, 3):
			trees.append(Vector2i(rect.position.x + gx,
				rect.position.y + gy))
	layout["orchard_trees"] = trees


func _scatter_trees() -> void:
	var placed: int = 0
	var tries: int = 0
	while placed < 320 and tries < 2400:
		tries += 1
		var t: Vector2i = Vector2i(rng.randi_range(8, WORLD_SIZE - 9),
			rng.randi_range(8, WORLD_SIZE - 9))
		if _is_walkable(t) or _is_occupied(t):
			continue
		if t.distance_to(Vector2(192, 193)) < 24.0:
			continue
		if _near_rect(t, layout["plaza_rect"], 2):
			continue
		_occupy_rect(Rect2i(t.x, t.y, 1, 1), true)
		(layout["trees"] as Array).append({
			"tile": t, "variant": (t.x * 7 + t.y * 13) % 3,
			"fruit": false})
		placed += 1
	for t in layout.get("orchard_trees", []):
		(layout["trees"] as Array).append({
			"tile": t, "variant": (t.x + t.y) % 3, "fruit": true})


func _place_props() -> void:
	var props: Array = [
		{"kind": "market", "tile": Vector2i(186, 187)},
		{"kind": "market", "tile": Vector2i(196, 187)},
		{"kind": "bench", "tile": Vector2i(187, 197)},
		{"kind": "bench", "tile": Vector2i(197, 198)},
		{"kind": "bench", "tile": Vector2i(184, 192)},
		{"kind": "barrel", "tile": Vector2i(201, 197)},
		{"kind": "barrel", "tile": Vector2i(202, 198)},
		{"kind": "cart", "tile": Vector2i(200, 203)},
		{"kind": "woodpile", "tile": Vector2i(201, 205)},
		{"kind": "well", "tile": Vector2i(191, 192)},
		{"kind": "sack", "tile": Vector2i(172, 210)},
		{"kind": "sack", "tile": Vector2i(173, 210)},
		{"kind": "laundry", "tile": Vector2i(208, 206)},
	]
	for p in props:
		(layout["props"] as Array).append(p)


func _add_wall_plan() -> void:
	# Nur Planung: Wall/Gate/Tower-Segmente fuer spaetere Siedlungstypen.
	layout["wall_plan"] = [
		{"segment": "wall_stone", "side": "n", "y": 20},
		{"segment": "wall_stone", "side": "s", "y": 364},
		{"segment": "gate_wood", "side": "n", "x": 192},
		{"segment": "gate_wood", "side": "s", "x": 192},
		{"segment": "tower", "side": "nw", "tile": Vector2i(18, 18)},
		{"segment": "tower", "side": "se", "tile": Vector2i(366, 366)},
	]


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


func _is_road(t: Vector2i) -> bool:
	return int((layout["roads"] as Dictionary).get(t, 0)) == 1


func _is_walkable(t: Vector2i) -> bool:
	if (layout["roads"] as Dictionary).has(t):
		return true
	return false


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
		"fields": (layout["fields"] as Array).size(),
		"roads": (layout["roads"] as Dictionary).size(),
		"trees": (layout["trees"] as Array).size(),
		"civic": (layout["civic"] as Array).size(),
		"walkable": layout.get("walkable_count", 0),
	}

