class_name WorldMap
extends RefCounted

## Deterministische Welt.
##
## G1-Default (PROFILE_G1): 128x128-Weiler mit 7 Gebäuden und kleinem
## Waypoint-Graphen; unverändert gegenüber G1a/G1b.
##
## G2 (PROFILE_G2): 384x384-Bauerschaft mit 24 Häusern, 4 Feldern,
## Kornspeicher, Brunnen, Werkstatt, Scheune und einem Tile-Wegnetz. Die
## Pfadfindung läuft über PathFinder/A*, nicht über den G1-Waypoint-Graphen.
##
## G3 (PROFILE_G3): 768x768-Kleinstadt mit 224 Häusern, 40 Feldern, drei
## Werkstätten, Kornspeicher, Brunnen, Scheune, Wegen und einem deterministischen
## Chunk-Index. Der Chunk-Index ist abgeleitet und nur für Materialisierung/
## Darstellung; die Simulation bleibt kameraunabhängig.
##
## SCALE (PROFILE_SCALE): 2048x2048-Stadt mit 2.000 Häusern, 200 Feldern,
## drei Werkstätten, Kornspeicher, Brunnen, Scheune und Wegen. Alle Indizes
## sind deterministisch aus dem Layout abgeleitet.

const SIZE: int = SimConfig.MAP_SIZE
const IDX_EMPTY: int = -1

const B_HOUSE_H1: int = 1
const B_HOUSE_H2: int = 2
const B_HOUSE_H3: int = 3
const B_GRANARY: int = 4
const B_WELL: int = 5
const B_WORKSHOP: int = 6
const B_FIELD: int = 7

var profile: int = SimConfig.PROFILE_G1
var size: int = SimConfig.MAP_SIZE

var occupied: PackedByteArray = PackedByteArray()
var road: PackedByteArray = PackedByteArray()
var buildings: Array = []
var nodes: Array = []
var adjacency: Array = []
var decor_trees: PackedVector2Array = PackedVector2Array()

var field_work_point: Vector2 = Vector2.ZERO
var plaza_point: Vector2 = Vector2.ZERO

const CHUNK_SIZE: int = 32

var _house_ids: PackedInt32Array = PackedInt32Array()
var _field_ids: PackedInt32Array = PackedInt32Array()
var _field_work_points: PackedVector2Array = PackedVector2Array()
var _workshop_ids: PackedInt32Array = PackedInt32Array()
var _granary_id: int = B_GRANARY
var _well_id: int = B_WELL
var _workshop_id: int = B_WORKSHOP
var _barn_id: int = -1
var _road_rects: Array = []
var _building_by_id: Dictionary = {}
var _field_work_by_id: Dictionary = {}
var _chunk_by_tile: PackedInt32Array = PackedInt32Array()

# Abgeleiteter Chunk-Index (nicht im Save): 1 = Chunk enthält Siedlungs-/
## Wege-/Feldmaterial. Die Simulation liest keine Kamera/Sichtbarkeit.
var chunk_size: int = CHUNK_SIZE
var chunk_count_x: int = 0
var chunk_count_y: int = 0
var chunk_active: PackedByteArray = PackedByteArray()


func _init(seed_value: int = 1, p_profile: int = SimConfig.PROFILE_G1,
		p_size: int = -1) -> void:
	profile = p_profile
	if p_size > 0:
		size = p_size
	elif profile == SimConfig.PROFILE_SCALE:
		size = SimConfig.MAP_SIZE_SCALE
	elif profile == SimConfig.PROFILE_CIVIC:
		size = SimConfig.MAP_SIZE_SCALE
	elif profile == SimConfig.PROFILE_G3:
		size = SimConfig.MAP_SIZE_G3
	elif profile == SimConfig.PROFILE_G2:
		size = SimConfig.MAP_SIZE_G2
	else:
		size = SimConfig.MAP_SIZE
	occupied.resize(size * size)
	road.resize(size * size)
	if profile == SimConfig.PROFILE_SCALE \
			or profile == SimConfig.PROFILE_CIVIC:
		_build_scale_settlement()
	elif profile == SimConfig.PROFILE_G3:
		_build_g3_settlement()
	elif profile == SimConfig.PROFILE_G2:
		_build_g2_settlement()
	else:
		_build_buildings()
		_build_roads()
		_build_graph()
	_rebuild_lookup_indices()
	_build_chunk_index()
	_scatter_decor(seed_value)


static func create_for_config(config: SimConfig) -> WorldMap:
	return WorldMap.new(config.seed, config.profile, config.world_size)


func _build_buildings() -> void:
	buildings.append(Building.new(B_HOUSE_H1, Building.KIND_HOUSE, "Haus Arnd",
		Rect2i(44, 52, 7, 7), Vector2i(47, 59)))
	buildings.append(Building.new(B_HOUSE_H2, Building.KIND_HOUSE, "Haus Bodo",
		Rect2i(72, 52, 7, 7), Vector2i(75, 59)))
	buildings.append(Building.new(B_HOUSE_H3, Building.KIND_HOUSE, "Haus Gustav",
		Rect2i(44, 70, 7, 7), Vector2i(47, 69)))
	buildings.append(Building.new(B_GRANARY, Building.KIND_GRANARY, "Kornspeicher",
		Rect2i(72, 70, 7, 7), Vector2i(75, 69)))
	buildings.append(Building.new(B_WELL, Building.KIND_WELL, "Brunnen",
		Rect2i(67, 67, 2, 2), Vector2i(66, 68)))
	buildings.append(Building.new(B_WORKSHOP, Building.KIND_WORKSHOP, "Scheune/Werkstatt",
		Rect2i(54, 78, 6, 6), Vector2i(56, 77)))
	buildings.append(Building.new(B_FIELD, Building.KIND_FIELD, "Feld",
		Rect2i(92, 56, 15, 15), Vector2i(91, 64)))
	for building in buildings:
		var b: Building = building
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if b.kind != Building.KIND_FIELD:
					occupied[_idx(x, y)] = 1
	_house_ids = PackedInt32Array([B_HOUSE_H1, B_HOUSE_H2, B_HOUSE_H3])
	_field_ids = PackedInt32Array([B_FIELD])
	_field_work_points = PackedVector2Array([Vector2(99.0, 63.5)])
	field_work_point = Vector2(99.0, 63.5)
	plaza_point = Vector2(64.5, 68.5)


func _build_g2_settlement() -> void:
	# 24 Häuser in 6 Spalten x 4 Reihen. Jede Tür liegt auf einer Querstraße.
	var house_names: Array = [
		"Haus Albrecht", "Haus Berta", "Haus Caspar", "Haus Dietrich",
		"Haus Emil", "Haus Frida", "Haus Gerhard", "Haus Hedwig",
		"Haus Jakob", "Haus Ida", "Haus Konrad", "Haus Lena",
		"Haus Lorenz", "Haus Magdalena", "Haus Nikolaus", "Haus Ottilie",
		"Haus Peter", "Haus Rosa", "Haus Simon", "Haus Sophia",
		"Haus Thomas", "Haus Theresa", "Haus Ulrich", "Haus Verena",
	]
	var next_id: int = 1
	for row in 4:
		for col in 6:
			var x: int = 96 + col * 28
			var y: int = 96 + row * 44
			var name: String = house_names[row * 6 + col]
			buildings.append(Building.new(next_id, Building.KIND_HOUSE, name,
				Rect2i(x, y, 8, 8), Vector2i(x + 4, y + 8)))
			_house_ids.append(next_id)
			next_id += 1
	_granary_id = next_id
	buildings.append(Building.new(_granary_id, Building.KIND_GRANARY,
		"Kornspeicher", Rect2i(256, 96, 12, 10), Vector2i(262, 106)))
	next_id += 1
	_well_id = next_id
	buildings.append(Building.new(_well_id, Building.KIND_WELL, "Brunnen",
		Rect2i(184, 160, 4, 4), Vector2i(186, 164)))
	next_id += 1
	_workshop_id = next_id
	buildings.append(Building.new(_workshop_id, Building.KIND_WORKSHOP,
		"Werkstatt", Rect2i(256, 150, 12, 10), Vector2i(262, 160)))
	next_id += 1
	_barn_id = next_id
	buildings.append(Building.new(_barn_id, Building.KIND_BARN, "Scheune",
		Rect2i(256, 230, 14, 12), Vector2i(263, 242)))
	next_id += 1
	for field_idx in 4:
		var fy: int = 96 + field_idx * 36
		var fid: int = next_id
		next_id += 1
		buildings.append(Building.new(fid, Building.KIND_FIELD,
			"Feld %d" % (field_idx + 1), Rect2i(292, fy, 28, 28),
			Vector2i(291, fy + 14)))
		_field_ids.append(fid)
		_field_work_points.append(Vector2(306.0, float(fy) + 14.0))
	for building in buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				occupied[_idx(x, y)] = 1
	# Straßen: vier Querstraßen, fünf Längsstraßen, Feldzugang und Zufahrten.
	for row in 4:
		_road_rect(Rect2i(88, 96 + row * 44 + 8, 196, 3))
	for col in 5:
		_road_rect(Rect2i(110 + col * 28, 100, 3, 144))
	_road_rect(Rect2i(284, 96, 3, 148))
	_road_rect(Rect2i(252, 100, 3, 146))
	_road_rect(Rect2i(252, 160, 22, 3))
	_road_rect(Rect2i(252, 242, 22, 3))
	_road_rect(Rect2i(166, 164, 34, 3))
	# Startzustände der vier Felder sind gestaffelt, damit nicht alle Felder
	# am selben Tag denselben Arbeitsschritt anfordern.
	var day_ticks: int = SimConfig.TICKS_PER_DAY
	var field0: Building = building_by_id(_field_ids[0])
	var field1: Building = building_by_id(_field_ids[1])
	var field2: Building = building_by_id(_field_ids[2])
	var field3: Building = building_by_id(_field_ids[3])
	if field0 != null:
		field0.field_stage = Building.FIELD_FALLOW
	if field1 != null:
		field1.field_stage = Building.FIELD_GROWING
		field1.field_growth_end = 2 * day_ticks
		field1.field_growth_gen = 1
	if field2 != null:
		field2.field_stage = Building.FIELD_GROWING
		field2.field_growth_end = 3 * day_ticks
		field2.field_growth_gen = 1
	if field3 != null:
		field3.field_stage = Building.FIELD_RIPE
	field_work_point = _field_work_points[0]
	plaza_point = Vector2(196.5, 165.5)


func _build_g3_settlement() -> void:
	# 224 Wohnhäuser in 14 Spalten x 16 Reihen. Jede Tür liegt auf einer
	# Querstraße; zwischen den Spalten verlaufen Längsstraßen.
	var next_id: int = 1
	for row in 16:
		for col in 14:
			var x: int = 64 + col * 40
			var y: int = 64 + row * 32
			buildings.append(Building.new(next_id, Building.KIND_HOUSE,
				"Haus %d" % next_id, Rect2i(x, y, 8, 8),
				Vector2i(x + 4, y + 8)))
			_house_ids.append(next_id)
			next_id += 1
	for row in 16:
		_road_rect(Rect2i(48, 64 + row * 32 + 8, 560, 3))
	for col in 15:
		_road_rect(Rect2i(48 + col * 40, 64, 3, 492))
	# Feldzugang und öffentlicher Bereich östlich der Häuser.
	_road_rect(Rect2i(608, 64, 12, 304))
	# 40 Felder in 5 Spalten x 8 Reihen (je 24x24 Tiles, 4 Tiles Abstand).
	for f_row in 8:
		for f_col in 5:
			var fx: int = 620 + f_col * 28
			var fy: int = 64 + f_row * 28
			var fid: int = next_id
			next_id += 1
			buildings.append(Building.new(fid, Building.KIND_FIELD,
				"Feld %d" % (f_row * 5 + f_col + 1),
				Rect2i(fx, fy, 24, 24), Vector2i(fx - 1, fy + 12)))
			_field_ids.append(fid)
			_field_work_points.append(Vector2(float(fx) + 12.5,
				float(fy) + 12.5))
	_granary_id = next_id
	buildings.append(Building.new(_granary_id, Building.KIND_GRANARY,
		"Kornspeicher", Rect2i(620, 300, 18, 12), Vector2i(629, 312)))
	next_id += 1
	_barn_id = next_id
	buildings.append(Building.new(_barn_id, Building.KIND_BARN, "Scheune",
		Rect2i(620, 320, 16, 12), Vector2i(628, 332)))
	next_id += 1
	_well_id = next_id
	buildings.append(Building.new(_well_id, Building.KIND_WELL, "Brunnen",
		Rect2i(620, 360, 4, 4), Vector2i(620, 364)))
	next_id += 1
	for w in 3:
		var wid: int = next_id
		next_id += 1
		_workshop_ids.append(wid)
		buildings.append(Building.new(wid, Building.KIND_WORKSHOP,
			"Werkstatt %d" % (w + 1),
			Rect2i(620 + w * 20, 340, 12, 10),
			Vector2i(626 + w * 20, 350)))
	_workshop_id = _workshop_ids[0]
	for building in buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if x >= 0 and x < size and y >= 0 and y < size:
					occupied[_idx(x, y)] = 1
	# Öffentliche Zugangswege zu Kornspeicher, Scheune, Werkstätten, Brunnen.
	_road_rect(Rect2i(608, 312, 96, 3))
	_road_rect(Rect2i(608, 332, 96, 3))
	_road_rect(Rect2i(608, 350, 96, 3))
	_road_rect(Rect2i(608, 364, 72, 3))
	field_work_point = _field_work_points[0]
	plaza_point = Vector2(700.5, 375.5)


## 10k-Stadt: 2.000 Häuser in 40x50, 200 Felder in 20x10, drei Werkstätten,
## Kornspeicher, Scheune und Brunnen. Jede Haustür liegt auf einer Querstraße.
func _build_scale_settlement() -> void:
	var next_id: int = 1
	for row in 50:
		for col in 40:
			var x: int = 160 + col * 16
			var y: int = 160 + row * 16
			buildings.append(Building.new(next_id, Building.KIND_HOUSE,
				"Haus %d" % next_id, Rect2i(x, y, 8, 8),
				Vector2i(x + 4, y + 8)))
			_house_ids.append(next_id)
			next_id += 1
	for row in 50:
		_road_rect(Rect2i(152, 160 + row * 16 + 8, 648, 3))
	for col in 10:
		_road_rect(Rect2i(157 + col * 64, 152, 3, 800))
	# 200 Felder in 20 Spalten x 10 Reihen (24x24 Tiles, 6 Tiles Abstand).
	for f_row in 10:
		for f_col in 20:
			var fx: int = 1120 + f_col * 30
			var fy: int = 200 + f_row * 30
			var fid: int = next_id
			next_id += 1
			buildings.append(Building.new(fid, Building.KIND_FIELD,
				"Feld %d" % (f_row * 20 + f_col + 1),
				Rect2i(fx, fy, 24, 24), Vector2i(fx - 1, fy + 12)))
			_field_ids.append(fid)
			_field_work_points.append(Vector2(float(fx) + 12.5,
				float(fy) + 12.5))
	_granary_id = next_id
	buildings.append(Building.new(_granary_id, Building.KIND_GRANARY,
		"Kornspeicher", Rect2i(1120, 560, 24, 16), Vector2i(1132, 576)))
	next_id += 1
	_barn_id = next_id
	buildings.append(Building.new(_barn_id, Building.KIND_BARN, "Scheune",
		Rect2i(1150, 560, 20, 14), Vector2i(1160, 574)))
	next_id += 1
	_well_id = next_id
	buildings.append(Building.new(_well_id, Building.KIND_WELL, "Brunnen",
		Rect2i(1120, 600, 4, 4), Vector2i(1120, 604)))
	next_id += 1
	for w in 3:
		var wid: int = next_id
		next_id += 1
		_workshop_ids.append(wid)
		buildings.append(Building.new(wid, Building.KIND_WORKSHOP,
			"Werkstatt %d" % (w + 1),
			Rect2i(1130 + w * 30, 620, 14, 10),
			Vector2i(1137 + w * 30, 630)))
	_workshop_id = _workshop_ids[0]
	for building in buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if x >= 0 and x < size and y >= 0 and y < size:
					occupied[_idx(x, y)] = 1
	# Wege zwischen Stadt, Feldern und Versorgungsgebäuden.
	_road_rect(Rect2i(733, 560, 387, 3))
	_road_rect(Rect2i(1108, 200, 3, 460))
	_road_rect(Rect2i(1100, 576, 260, 3))
	_road_rect(Rect2i(1100, 604, 260, 3))
	_road_rect(Rect2i(1100, 630, 260, 3))
	field_work_point = _field_work_points[0]
	plaza_point = Vector2(1102.5, 612.5)


func _rebuild_lookup_indices() -> void:
	_building_by_id.clear()
	_field_work_by_id.clear()
	for building in buildings:
		var b: Building = building
		_building_by_id[b.id] = b
	for i in _field_ids.size():
		_field_work_by_id[_field_ids[i]] = _field_work_points[i]


## Leitet den Chunk-Index aus dem autoritativen Siedlungszustand ab. Chunks
## mit Gebäuden, Wegen oder Feldern gelten als materialisiert; die Auswahl ist
## deterministisch und hängt nicht von der Kamera ab. Die Markierung erfolgt
## über Rechteckbereiche, damit die 2048er-Welt nicht 4 Mio. Tiles scannen muss.
func _build_chunk_index() -> void:
	chunk_count_x = int(ceil(float(size) / float(chunk_size)))
	chunk_count_y = chunk_count_x
	chunk_active.resize(chunk_count_x * chunk_count_y)
	chunk_active.fill(0)
	for rect in _road_rects:
		_mark_rect_chunks(rect as Rect2i)
	for building in buildings:
		_mark_rect_chunks((building as Building).rect)


func _mark_rect_chunks(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var x0: int = clampi(rect.position.x, 0, size - 1)
	var y0: int = clampi(rect.position.y, 0, size - 1)
	var x1: int = clampi(rect.position.x + rect.size.x - 1, 0, size - 1)
	var y1: int = clampi(rect.position.y + rect.size.y - 1, 0, size - 1)
	var cx0: int = x0 / chunk_size
	var cy0: int = y0 / chunk_size
	var cx1: int = x1 / chunk_size
	var cy1: int = y1 / chunk_size
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			chunk_active[cy * chunk_count_x + cx] = 1


func _mark_chunk(x: int, y: int) -> void:
	if x < 0 or x >= size or y < 0 or y >= size:
		return
	var cx: int = x / chunk_size
	var cy: int = y / chunk_size
	chunk_active[cy * chunk_count_x + cx] = 1


func chunk_for_tile(x: int, y: int) -> int:
	if x < 0 or x >= size or y < 0 or y >= size:
		return -1
	return (y / chunk_size) * chunk_count_x + (x / chunk_size)


func is_chunk_active(chunk_index: int) -> bool:
	return chunk_index >= 0 and chunk_index < chunk_active.size() \
		and chunk_active[chunk_index] != 0


func materialized_chunk_count() -> int:
	var n: int = 0
	for value in chunk_active:
		if value != 0:
			n += 1
	return n


func chunk_state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, chunk_size)
	h = HashUtil.mix(h, chunk_count_x)
	h = HashUtil.mix(h, size)
	for value in chunk_active:
		h = HashUtil.mix(h, value)
	return h


func _build_roads() -> void:
	_road_rect(Rect2i(40, 62, 52, 5))
	_road_rect(Rect2i(62, 48, 5, 41))
	_road_rect(Rect2i(47, 59, 1, 3))
	_road_rect(Rect2i(75, 59, 1, 3))
	_road_rect(Rect2i(47, 67, 1, 3))
	_road_rect(Rect2i(75, 67, 1, 3))
	_road_rect(Rect2i(56, 66, 1, 12))
	_road_rect(Rect2i(56, 77, 9, 1))


func _road_rect(rect: Rect2i) -> void:
	_road_rects.append(rect)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < size and y >= 0 and y < size:
				road[_idx(x, y)] = 1


func _build_graph() -> void:
	nodes.clear()
	adjacency.clear()
	var positions: Array = [
		Vector2(40.5, 64.5), Vector2(47.5, 64.5), Vector2(56.5, 64.5),
		Vector2(64.5, 64.5), Vector2(75.5, 64.5), Vector2(91.5, 64.5),
		Vector2(64.5, 48.5), Vector2(64.5, 88.5), Vector2(47.5, 59.5),
		Vector2(75.5, 59.5), Vector2(47.5, 69.5), Vector2(75.5, 69.5),
		Vector2(56.5, 77.5), Vector2(64.5, 68.5), Vector2(64.5, 77.5),
	]
	for p in positions:
		nodes.append(p)
		adjacency.append(PackedInt32Array())
	_edge(0, 1); _edge(1, 2); _edge(2, 3); _edge(3, 4); _edge(4, 5)
	_edge(3, 6); _edge(3, 13); _edge(13, 14); _edge(14, 7); _edge(13, 7)
	_edge(1, 8); _edge(4, 9); _edge(1, 10); _edge(4, 11)
	_edge(14, 12)


func _edge(a: int, b: int) -> void:
	var a_neigh: PackedInt32Array = adjacency[a]
	a_neigh.append(b)
	a_neigh.sort()
	adjacency[a] = a_neigh
	var b_neigh: PackedInt32Array = adjacency[b]
	b_neigh.append(a)
	b_neigh.sort()
	adjacency[b] = b_neigh


func _scatter_decor(seed_value: int) -> void:
	var rng: RngStream = RngStream.new(seed_value * 17 + 31)
	var target_count: int = 180
	var guard_max: int = 4000
	if profile == SimConfig.PROFILE_G2:
		target_count = 260
		guard_max = 12000
	elif profile == SimConfig.PROFILE_G3:
		target_count = 700
		guard_max = 40000
	elif profile == SimConfig.PROFILE_SCALE \
			or profile == SimConfig.PROFILE_CIVIC:
		target_count = 1200
		guard_max = 120000
	var placed: int = 0
	var guard: int = 0
	while placed < target_count and guard < guard_max:
		guard += 1
		var x: int = 2 + rng.next_range(size - 4)
		var y: int = 2 + rng.next_range(size - 4)
		if road[_idx(x, y)] != 0 or occupied[_idx(x, y)] != 0:
			continue
		if profile == SimConfig.PROFILE_G2:
			if x >= 80 and x <= 326 and y >= 86 and y <= 250:
				continue
		elif profile == SimConfig.PROFILE_G3:
			# Bebaute Siedlungsfläche freihalten; Bäume nur am Rand.
			if x >= 40 and x <= 760 and y >= 40 and y <= 570:
				continue
		elif profile == SimConfig.PROFILE_SCALE \
				or profile == SimConfig.PROFILE_CIVIC:
			if x >= 100 and x <= 1900 and y >= 100 and y <= 800:
				continue
		else:
			if x >= 38 and x <= 108 and y >= 50 and y <= 90:
				continue
		decor_trees.append(Vector2(x + 0.5, y + 0.5))
		placed += 1


func _idx(x: int, y: int) -> int:
	return y * size + x


func building_by_id(building_id: int) -> Building:
	return _building_by_id.get(building_id, null) as Building


func building_name(building_id: int) -> String:
	var b: Building = building_by_id(building_id)
	return b.name if b != null else "?"


func door_point(building_id: int) -> Vector2:
	var b: Building = building_by_id(building_id)
	return b.door_point if b != null else Vector2.ZERO


func is_inside(tile_x: int, tile_y: int) -> bool:
	return tile_x >= 0 and tile_x < size and tile_y >= 0 and tile_y < size


func is_blocked_tile(tile_x: int, tile_y: int) -> bool:
	if not is_inside(tile_x, tile_y):
		return true
	return occupied[_idx(tile_x, tile_y)] != 0


func is_road_tile(tile_x: int, tile_y: int) -> bool:
	if not is_inside(tile_x, tile_y):
		return false
	return road[_idx(tile_x, tile_y)] != 0


func is_point_walkable(point: Vector2) -> bool:
	var tx: int = int(floor(point.x))
	var ty: int = int(floor(point.y))
	return not is_blocked_tile(tx, ty)


func clamp_point(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.5, float(size) - 0.5),
		clampf(point.y, 0.5, float(size) - 0.5))


func nearest_node(point: Vector2) -> int:
	var best: int = 0
	var best_d: float = 1e30
	for i in nodes.size():
		var d: float = (nodes[i] as Vector2).distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	return best


## G1-Waypoint-Route (Dijkstra, kleine Knotenzahl). G2 nutzt PathFinder.
func find_route(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	if nodes.is_empty():
		var fallback: PackedVector2Array = PackedVector2Array()
		fallback.append(clamp_point(from_point))
		fallback.append(clamp_point(to_point))
		return fallback
	var start_node: int = nearest_node(from_point)
	var goal_node: int = nearest_node(to_point)
	var n: int = nodes.size()
	var dist: PackedFloat64Array = PackedFloat64Array()
	var prev: PackedInt32Array = PackedInt32Array()
	var visited: PackedByteArray = PackedByteArray()
	dist.resize(n); prev.resize(n); visited.resize(n)
	for i in n:
		dist[i] = 1e30
		prev[i] = -1
		visited[i] = 0
	dist[start_node] = 0.0
	for _step in n:
		var u: int = -1
		var best_d: float = 1e30
		for i in n:
			if visited[i] == 0 and dist[i] < best_d:
				best_d = dist[i]
				u = i
		if u < 0:
			break
		if u == goal_node:
			break
		visited[u] = 1
		var neigh: PackedInt32Array = adjacency[u]
		for v in neigh:
			if visited[v] != 0:
				continue
			var w: float = (nodes[u] as Vector2).distance_to(nodes[v])
			var nd: float = dist[u] + w
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	var node_path: PackedInt32Array = PackedInt32Array()
	if dist[goal_node] >= 1e29:
		node_path.append(start_node)
		node_path.append(goal_node)
	else:
		var cur: int = goal_node
		while cur >= 0:
			node_path.append(cur)
			if cur == start_node:
				break
			cur = prev[cur]
		node_path.reverse()
	var points: PackedVector2Array = PackedVector2Array()
	points.append(clamp_point(from_point))
	for node_idx in node_path:
		var p: Vector2 = nodes[node_idx]
		if points[points.size() - 1].distance_to(p) > 0.01:
			points.append(p)
	var end_point: Vector2 = clamp_point(to_point)
	if points[points.size() - 1].distance_to(end_point) > 0.01:
		points.append(end_point)
	return points


static func polyline_length(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


static func point_on_polyline(points: PackedVector2Array, distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if distance <= 0.0:
		return points[0]
	var remaining: float = distance
	for i in range(1, points.size()):
		var seg: float = points[i - 1].distance_to(points[i])
		if remaining <= seg or i == points.size() - 1:
			var t: float = 0.0 if seg <= 0.0 else clampf(remaining / seg, 0.0, 1.0)
			return points[i - 1].lerp(points[i], t)
		remaining -= seg
	return points[points.size() - 1]


func graph_reachable(start_node: int, goal_node: int) -> bool:
	if start_node == goal_node:
		return true
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(nodes.size())
	var queue: PackedInt32Array = PackedInt32Array()
	queue.append(start_node)
	visited[start_node] = 1
	var head: int = 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		for v in adjacency[u]:
			if visited[v] == 0:
				visited[v] = 1
				queue.append(v)
	return visited[goal_node] != 0


func house_ids() -> PackedInt32Array:
	return _house_ids.duplicate()


func field_ids() -> PackedInt32Array:
	return _field_ids.duplicate()


func field_work_point_for(field_id: int) -> Vector2:
	var point = _field_work_by_id.get(field_id, field_work_point)
	return point


func granary_id() -> int:
	return _granary_id


func well_id() -> int:
	return _well_id


func workshop_id() -> int:
	return _workshop_id


func workshop_ids() -> PackedInt32Array:
	return _workshop_ids.duplicate()


func workshop_id_for_row(row: int) -> int:
	if _workshop_ids.is_empty():
		return _workshop_id
	return _workshop_ids[row % _workshop_ids.size()]


func barn_id() -> int:
	return _barn_id


## Alle Off-Road-Ziele des 10k-Profils, die für A* an die Straßen
## angebunden werden müssen. Reine Geometrie, deterministisch, nicht im Save.
func scale_field_points() -> PackedVector2Array:
	return _field_work_points.duplicate()


func scale_path_anchors() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for wid in _workshop_ids:
		out.append(door_point(wid))
	out.append(door_point(_well_id))
	for i in 3:
		out.append(clamp_point(door_point(_well_id) + Vector2(
			float(i - 1) * 0.8, 0.0)))
	for dx in 5:
		for dy in 2:
			out.append(clamp_point(plaza_point + Vector2(
				float(dx - 2) * 1.0, float(dy) * 1.5)))
	return out


func workplace_ids() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.append_array(_field_ids)
	out.append(_workshop_id)
	out.append(_granary_id)
	out.append(_well_id)
	return out
