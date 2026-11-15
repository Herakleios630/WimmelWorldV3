extends Node2D

## G4c-P2.1b View: komponiert das kompakte Ringdorf aus Kenney-RPG-Tiles.
## House-Rows und Farmsteads sind echte 16x16-Prefabs. Reine Anzeige.
## 100 Lauf-Agenten sind Demo-Viewer (kein Sim-Eingriff).

const EdgeTiles = preload("res://tests/g4c_p2/edge_tiles.gd")
const TILE: int = 16
const RP_PITCH: int = 17
const BASE_PITCH: int = 64
const FIGURE_SCALE: float = 1.2

const RP_GRASS_A: Vector2i = Vector2i(5, 1)
const RP_GRASS_B: Vector2i = Vector2i(5, 0)
const RP_DIRT: Vector2i = Vector2i(6, 1)
const RP_SAND: Vector2i = Vector2i(8, 1)
const RP_WATER: Vector2i = Vector2i(1, 1)
const RP_COBBLE: Vector2i = Vector2i(9, 0)
const RP_FLOWER: Vector2i = Vector2i(0, 9)
const RP_TREE: Array = [Vector2i(13, 10), Vector2i(13, 9), Vector2i(13, 11)]

const WALL_CELLS: Array = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(13, 3)]
const ROOF_CELLS: Array = [Vector2i(1, 7), Vector2i(6, 7), Vector2i(10, 7)]
const BASE_DOOR: Vector2i = Vector2i(10, 12)
const BASE_BIG_DOOR: Vector2i = Vector2i(14, 10)
const BASE_WINDOW: Vector2i = Vector2i(12, 12)
const BASE_CHIMNEY: Vector2i = Vector2i(13, 4)
const BASE_SACK: Vector2i = Vector2i(9, 12)
const BASE_BARREL: Vector2i = Vector2i(9, 10)
const BASE_TREE: Array = [Vector2i(0, 10), Vector2i(2, 10), Vector2i(4, 10)]

const CHAR_CELLS: Array = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(0, 6), Vector2i(1, 6),
	Vector2i(0, 7), Vector2i(1, 7), Vector2i(0, 8), Vector2i(1, 8),
	Vector2i(0, 9), Vector2i(1, 9), Vector2i(0, 10), Vector2i(1, 10)]
const CHAR_TINTS: Array = [
	Color(1, 1, 1), Color(1.0, 0.92, 0.82), Color(0.88, 0.94, 1.0),
	Color(1.0, 0.88, 0.88), Color(0.94, 1.0, 0.88)]
const FIELD_COLORS: Array = [
	Color(0.40, 0.31, 0.20), Color(0.46, 0.33, 0.21),
	Color(0.52, 0.40, 0.24), Color(0.38, 0.45, 0.24),
	Color(0.58, 0.53, 0.24), Color(0.50, 0.40, 0.20)]
const CROP_COLORS: Array = [
	Color(0.36, 0.28, 0.17), Color(0.42, 0.31, 0.18),
	Color(0.48, 0.37, 0.20), Color(0.34, 0.44, 0.20),
	Color(0.64, 0.57, 0.24), Color(0.60, 0.48, 0.21)]

var layout: Dictionary
var view_state: ViewState
var night_factor: float = 0.0
var season_index: int = 0
var hover_id: int = 0
var walkers: Array = []
var rng: RandomNumberGenerator
var _time: float = 0.0

var _rp_img: Image
var _ch_img: Image
var _base_img: Image
var _rp_tex: Texture2D
var _ch_tex: Texture2D
var _base_tex: Texture2D
var _grass_tex: Texture2D
var _dirt_tex: Texture2D
var _cobble_tex: Texture2D
var _water_tex: Texture2D
var _sand_tex: Texture2D
var _dirt_edges: Array = []
var _cobble_edges: Array = []
var _sand_edges: Array = []
var _water_edges: Array = []
var _house_tex: Dictionary = {}
var _civic_tex: Dictionary = {}
var _row_tex: Dictionary = {}
var _farm_tex: Dictionary = {}
var _barn_tex: Texture2D
var _base16_cache: Dictionary = {}
var _walkable: Dictionary = {}
var _plaza_set: Dictionary = {}
var _water_set: Dictionary = {}
var _shore_set: Dictionary = {}
var _shore_water_set: Dictionary = {}
var _grass_avg: Color = Color(0.45, 0.50, 0.34)
var _font: Font


func configure(p_layout: Dictionary, p_view_state: ViewState, seed_value: int) -> void:
	layout = p_layout
	view_state = p_view_state
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	_walkable = layout["roads"]
	_plaza_set = layout["plaza"]
	for t in (layout["pond"] as Dictionary).get("water", []):
		_water_set[t] = true
	for t in (layout["pond"] as Dictionary).get("shore", []):
		_shore_set[t] = true
		_shore_water_set[t] = true
	for t in (layout["pond"] as Dictionary).get("water", []):
		_shore_water_set[t] = true
	_build_assets()
	_build_houses()
	_build_prefabs()
	_build_walkers()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for w in walkers:
		w["t"] += delta * float(w["speed"])
		if float(w["t"]) >= 1.0:
			w["t"] = 0.0
			w["from"] = w["to"]
			w["to"] = _next_tile(w["from"], w["to"])
			if rng.randf() < 0.05:
				w["pause"] = rng.randf_range(0.4, 2.2)
		if float(w["pause"]) > 0.0:
			w["pause"] = maxf(0.0, float(w["pause"]) - delta)
	queue_redraw()


func _next_tile(from: Vector2i, current: Vector2i) -> Vector2i:
	var options: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = current + d
		if not _walkable.has(n):
			continue
		if n == from and rng.randf() < 0.75:
			continue
		options.append(n)
	if options.is_empty():
		return current
	return options[rng.randi_range(0, options.size() - 1)]


func _build_walkers() -> void:
	var keys: Array = _walkable.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y)
	for i in 100:
		var start: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var target: Vector2i = _next_tile(start, start)
		walkers.append({
			"id": i + 1,
			"from": start,
			"to": target,
			"t": rng.randf(),
			"speed": rng.randf_range(0.85, 1.7),
			"pause": 0.0,
			"cell": i % CHAR_CELLS.size(),
			"tint": i % CHAR_TINTS.size(),
		})


func walker_tile(w: Dictionary) -> Vector2:
	var a: Vector2 = Vector2(w["from"]) + Vector2(0.5, 0.85)
	var b: Vector2 = Vector2(w["to"]) + Vector2(0.5, 0.85)
	return a.lerp(b, clampf(float(w["t"]), 0.0, 1.0))


func _build_assets() -> void:
	_rp_tex = load("res://assets/kenney/roguelike-rpg-pack/roguelikeSheet_transparent.png")
	_ch_tex = load("res://assets/kenney/roguelike-characters/roguelikeChar_transparent.png")
	_base_tex = load("res://assets/kenney/rpg-base/RPGpack_sheet.png")
	_rp_img = _rp_tex.get_image()
	_ch_img = _ch_tex.get_image()
	_base_img = _base_tex.get_image()
	_grass_tex = _make_grass()
	_dirt_tex = _make_pattern(RP_DIRT, 2, 2)
	_cobble_tex = _make_pattern(RP_COBBLE, 2, 2)
	_water_tex = _make_pattern(RP_WATER, 2, 2)
	_sand_tex = _make_pattern(RP_SAND, 2, 2)
	_dirt_edges = EdgeTiles.build(_dirt_tex, 4, 4)
	_cobble_edges = EdgeTiles.build(_cobble_tex, 4, 5)
	_sand_edges = EdgeTiles.build(_sand_tex, 3, 4)
	_water_edges = EdgeTiles.build(_water_tex, 4, 5)


func _make_pattern(cell: Vector2i, w: int, h: int) -> Texture2D:
	var img: Image = Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			_blit_pack(img, cell, x * TILE, y * TILE)
	return ImageTexture.create_from_image(img)


func _make_grass() -> Texture2D:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var variants: Array = [RP_GRASS_A, RP_GRASS_B, RP_GRASS_A, RP_GRASS_B]
	for y in 4:
		for x in 4:
			_blit_pack(img, variants[(x + y * 3) % variants.size()],
				x * TILE, y * TILE)
	# Entsaettigtes Gras: dezente Grau-/Olivnote, feine Koernung statt Flaeche.
	var sum: Color = Color(0, 0, 0)
	for y in 64:
		for x in 64:
			var c: Color = img.get_pixel(x, y)
			var k: int = (x * 73856093 ^ y * 19349663) & 0x7fffffff
			var d: float = 1.0 - (float(k % 29) / 29.0) * 0.075
			var nc: Color = Color((c.r * 0.58 + 0.085) * d,
				(c.g * 0.635 + 0.085) * d, (c.b * 0.50 + 0.075) * d, 1.0)
			var luma: float = nc.r * 0.30 + nc.g * 0.59 + nc.b * 0.11
			nc = nc.lerp(Color(luma * 0.95, luma, luma * 0.90), 0.14)
			img.set_pixel(x, y, nc)
			sum += nc
	_grass_avg = Color(sum.r / 4096.0, sum.g / 4096.0, sum.b / 4096.0)
	for i in 9:
		var px: int = (i * 29) % 60 + 2
		var py: int = (i * 47) % 60 + 2
		img.set_pixel(px, py, Color(0.84, 0.80, 0.46) if i % 2 == 0
			else Color(0.72, 0.50, 0.40))
	# Weiche Moos-/Schattenflecken brechen die grosse Wiesenflaeche auf.
	for i in 14:
		var bx: int = (i * 37 + 11) % 58 + 2
		var by: int = (i * 53 + 7) % 58 + 2
		for yy in range(by, mini(64, by + 4)):
			for xx in range(bx, mini(64, bx + 5)):
				var pc: Color = img.get_pixel(xx, yy)
				img.set_pixel(xx, yy, Color(pc.r * 0.93, pc.g * 0.94,
					pc.b * 0.90, 1.0))
	return ImageTexture.create_from_image(img)


func _build_houses() -> void:
	var data_text: String = FileAccess.get_file_as_string(
		"res://tests/g4c_p2/segments.json")
	var data = JSON.parse_string(data_text)
	var variants: Array = data.get("house_variants", []) if data != null else []
	for i in variants.size():
		var v: Dictionary = variants[i]
		var size_arr: Array = v.get("size", [7, 6])
		var wall_names: Array = ["cream", "brick", "stone"]
		var roof_names: Array = ["warm_brown", "warm_ochre", "slate"]
		var wall_i: int = maxi(0, wall_names.find(str(v.get("wall", "cream"))))
		var roof_i: int = maxi(0, roof_names.find(str(v.get("roof", "warm_brown"))))
		_house_tex[i] = _compose_house(int(size_arr[0]), int(size_arr[1]),
			wall_i, roof_i, bool(v.get("chimney", false)),
			int(v.get("windows", 2)), BASE_DOOR)
	for c in layout["civic"]:
		var kind: String = c["kind"]
		var rect: Rect2i = c["rect"]
		var roof_i: int = 0
		if str(c.get("roof", "")) == "slate":
			roof_i = 2
		elif str(c.get("roof", "")) == "warm_ochre":
			roof_i = 1
		_civic_tex[kind] = _compose_house(rect.size.x, rect.size.y,
			1 if kind != "granary" else 0, roof_i, true, 2,
			BASE_BIG_DOOR)


func _build_prefabs() -> void:
	_barn_tex = _compose_house(7, 6, 2, 0, false, 0, BASE_BIG_DOOR)
	# House-Rows: 3 Haeuser je 16x16-Prefab, gemeinsam als ein Bild komponiert.
	for ri in (layout["house_rows"] as Array).size():
		var row: Dictionary = layout["house_rows"][ri]
		var row_rect: Rect2i = row["rect"]
		var img: Image = Image.create(16 * TILE, 16 * TILE, false,
			Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for h in row["houses"]:
			var h_rect: Rect2i = h["rect"]
			var tex: Texture2D = _house_tex.get(int(h["variant"]))
			if tex == null:
				continue
			_blit_tex_img(img, tex,
				(h_rect.position.x - row_rect.position.x) * TILE,
				(h_rect.position.y - row_rect.position.y) * TILE)
		_row_tex[ri] = ImageTexture.create_from_image(img)
	# Farmsteads: Haus + Scheune als 16x16-Prefab.
	for fi in (layout["farmsteads"] as Array).size():
		var fs: Dictionary = layout["farmsteads"][fi]
		var img2: Image = Image.create(16 * TILE, 16 * TILE, false,
			Image.FORMAT_RGBA8)
		img2.fill(Color(0, 0, 0, 0))
		var house_tex: Texture2D = _house_tex.get(int(fs["variant"]))
		if house_tex != null:
			var hl: Vector2i = fs["house_local"]
			_blit_tex_img(img2, house_tex, hl.x * TILE, hl.y * TILE)
		if _barn_tex != null:
			var bl: Vector2i = fs["barn_local"]
			_blit_tex_img(img2, _barn_tex, bl.x * TILE, bl.y * TILE)
		_farm_tex[fi] = ImageTexture.create_from_image(img2)


func _blit_tex_img(dst: Image, tex: Texture2D, dx: int, dy: int) -> void:
	var src: Image = tex.get_image()
	for y in src.get_height():
		for x in src.get_width():
			if dy + y < 0 or dx + x < 0:
				continue
			if dy + y >= dst.get_height() or dx + x >= dst.get_width():
				continue
			var c: Color = src.get_pixel(x, y)
			if c.a > 0.01:
				dst.set_pixel(dx + x, dy + y, c)


func _compose_house(w: int, h: int, wall_i: int, roof_i: int,
		chimney: bool, windows: int, door_cell: Vector2i) -> Texture2D:
	var img: Image = Image.create(w * TILE, h * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var roof_rows: int = maxi(3, h - 3)
	var wall_cell: Vector2i = WALL_CELLS[clampi(wall_i, 0, 2)]
	var roof_cell: Vector2i = ROOF_CELLS[clampi(roof_i, 0, 2)]
	for y in h:
		for x in w:
			_blit_base(img, roof_cell if y < roof_rows else wall_cell,
				x * TILE, y * TILE, TILE, TILE)
	# Waermere Daecher: dezenter Rot-/Gelbstich ueber der Dachzone.
	for yy in roof_rows * TILE:
		for xx in w * TILE:
			var rc: Color = img.get_pixel(xx, yy)
			if rc.a > 0.01:
				img.set_pixel(xx, yy, Color(minf(1.0, rc.r * 1.07 + 0.02),
					rc.g * 0.99, rc.b * 0.90, rc.a))
	# Traufe, First, Ortgang: lesbare Hauskanten.
	img.fill_rect(Rect2i(0, roof_rows * TILE - 3, w * TILE, 3),
		Color(0.22, 0.14, 0.09, 1))
	img.fill_rect(Rect2i(0, 3, w * TILE, 2), Color(0.95, 0.84, 0.66, 1))
	img.fill_rect(Rect2i(0, 0, 2, roof_rows * TILE), Color(0.30, 0.20, 0.13))
	img.fill_rect(Rect2i(w * TILE - 2, 0, 2, roof_rows * TILE),
		Color(0.30, 0.20, 0.13))
	# Dach-Horizontalziegel.
	for yy in range(12, roof_rows * TILE - 8, 14):
		img.fill_rect(Rect2i(2, yy, w * TILE - 4, 1),
			Color(0.92, 0.80, 0.62, 0.35))
	# 1-Tile-Tuer mittig unten, mit Schwelle.
	var dx: int = (w * TILE - TILE) / 2
	var dy: int = h * TILE - TILE
	_blit_base(img, door_cell, dx, dy, TILE, TILE)
	img.fill_rect(Rect2i(dx, h * TILE - 3, TILE, 3), Color(0.24, 0.18, 0.12))
	# Fenster in der Wandzone, 1 Tile, mit Rahmen.
	var wall_top: int = roof_rows * TILE
	var slots: Array = []
	if windows >= 2:
		slots = [TILE + 2, w * TILE - TILE * 2]
	if windows >= 4:
		slots = [TILE + 2, w * TILE / 2 - TILE / 2,
			w * TILE - TILE * 2]
	for sx in slots:
		var wy: int = wall_top
		img.fill_rect(Rect2i(int(sx) - 1, wy - 1, TILE + 2, TILE + 2),
			Color(0.30, 0.22, 0.14))
		_blit_base(img, BASE_WINDOW, int(sx), wy, TILE, TILE)
		img.fill_rect(Rect2i(int(sx) + 4, wy + 4, 8, 8),
			Color(0.86, 0.88, 0.72, 0.55))
	if chimney:
		_blit_base(img, BASE_CHIMNEY, w * TILE - TILE * 3, 0, TILE, TILE)
		img.fill_rect(Rect2i(w * TILE - TILE * 3, 0, TILE, 3),
			Color(0.14, 0.12, 0.10))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if layout.is_empty() or view_state == null:
		return
	var vis: Rect2 = _visible_tiles()
	_draw_ground(vis)
	_draw_pond(vis)
	_draw_roads(vis)
	_draw_road_detail(vis)
	_draw_plaza(vis)
	_draw_fields(vis)
	_draw_farm_yards(vis)
	_draw_orchard(vis)
	_draw_objects(vis)


func _visible_tiles() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var z: float = maxf(0.05, view_state.zoom)
	var half: Vector2 = vp * 0.5 / (z * float(TILE))
	return Rect2(view_state.camera_position - half - Vector2(4, 4),
		half * 2.0 + Vector2(8, 8))


func _world_rect() -> Rect2:
	var size: int = int(layout["size"])
	return Rect2(0, 0, size * TILE, size * TILE)


func _tile_rect(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE)


func _draw_ground(vis: Rect2) -> void:
	var r: Rect2 = _tile_rect(Rect2i(Vector2i(vis.position.floor()),
		Vector2i(vis.size.ceil()))).intersection(_world_rect())
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	draw_texture_rect(_grass_tex, r, true)
	# Grasbueschel/Moosflecken brechen die flaechige Wiese auf.
	var x0: int = maxi(0, int(vis.position.x))
	var y0: int = maxi(0, int(vis.position.y))
	var x1: int = mini(int(layout["size"]), int(vis.end.x) + 1)
	var y1: int = mini(int(layout["size"]), int(vis.end.y) + 1)
	for gy in range(y0, y1, 2):
		for gx in range(x0, x1, 2):
			var h: int = (gx * 73856093 + gy * 19349663) & 1023
			if h % 7 != 0:
				continue
			var px: float = float(gx * TILE) + float(h % 13)
			var py: float = float(gy * TILE) + float((h / 13) % 13)
			draw_line(Vector2(px, py), Vector2(px - 1.5, py - 4),
				Color(0.30, 0.42, 0.20, 0.55), 1.0)
			draw_line(Vector2(px + 2, py), Vector2(px + 3, py - 3.5),
				Color(0.24, 0.36, 0.16, 0.50), 1.0)
			if h % 5 == 0:
				draw_circle(Vector2(px + 1, py + 1), 2.2,
					Color(0.36, 0.46, 0.24, 0.20))
	draw_rect(_world_rect(), Color(0.08, 0.12, 0.08, 0.85), false, 3.0)


func _mask4(tile: Vector2i, tiles: Dictionary) -> int:
	var m: int = 0
	if tiles.has(tile + Vector2i(0, -1)):
		m |= 1
	if tiles.has(tile + Vector2i(1, 0)):
		m |= 2
	if tiles.has(tile + Vector2i(0, 1)):
		m |= 4
	if tiles.has(tile + Vector2i(-1, 0)):
		m |= 8
	return m


func _draw_roads(vis: Rect2) -> void:
	if _dirt_edges.is_empty():
		return
	for key in _walkable.keys():
		var t: Vector2i = key
		if _plaza_set.has(t) or not vis.has_point(Vector2(t)):
			continue
		var m: int = _mask4(t, _walkable)
		draw_texture_rect(_dirt_edges[m],
			Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), false,
			Color(0.72, 0.60, 0.44))


func _draw_road_run(xa: int, xb: int, y: int) -> void:
	if xb <= xa:
		return
	var r: Rect2 = Rect2(Vector2(xa * TILE, y * TILE), Vector2((xb - xa) * TILE, TILE))
	# Dunklerer, waermerer Wegton; Kanten kommen aus der weichen Uebergangsschicht.
	draw_texture_rect(_dirt_tex, r, true, Color(0.72, 0.60, 0.44))


func _draw_road_detail(vis: Rect2) -> void:
	var roads: Dictionary = _walkable
	var rut: Color = Color(0.26, 0.19, 0.11, 0.20)
	for key in roads.keys():
		var t: Vector2i = key
		if not vis.has_point(Vector2(t)) or _plaza_set.has(t):
			continue
		var p: Vector2 = Vector2(t) * TILE
		var ew: bool = roads.has(t + Vector2i(-1, 0)) or roads.has(t + Vector2i(1, 0))
		var ns: bool = roads.has(t + Vector2i(0, -1)) or roads.has(t + Vector2i(0, 1))
		if ew and not ns:
			draw_line(p + Vector2(0, 5.5), p + Vector2(TILE, 5.5), rut, 1.0)
			draw_line(p + Vector2(0, 10.5), p + Vector2(TILE, 10.5), rut, 1.0)
		elif ns and not ew:
			draw_line(p + Vector2(5.5, 0), p + Vector2(5.5, TILE), rut, 1.0)
			draw_line(p + Vector2(10.5, 0), p + Vector2(10.5, TILE), rut, 1.0)
		var h: int = (t.x * 73856093 ^ t.y * 19349663) & 0x7fffffff
		if h % 5 == 0:
			var pebble: Vector2 = p + Vector2(3 + h % 10, 3 + (h / 11) % 10)
			draw_circle(pebble, 1.4, Color(0.55, 0.46, 0.34, 0.75))


## Weiche, gerundete Uebergangskante: breite transparente Grasnaht plus
## Eckenrundung an konvexen Kanten. 4-Bit-Nachbarschaft statt harter Rect-Kanten.
func _soften_shape(tiles: Dictionary, vis: Rect2, radius: float,
		skip_plaza: bool, roads_block: bool = false) -> void:
	var soft: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.42)
	var hard: Color = Color(_grass_avg.r * 0.97, _grass_avg.g * 1.01,
		_grass_avg.b * 0.95, 0.86)
	var nw: Vector2i = Vector2i(0, -1)
	var sw: Vector2i = Vector2i(0, 1)
	var ww: Vector2i = Vector2i(-1, 0)
	var ew: Vector2i = Vector2i(1, 0)
	for key in tiles.keys():
		var tile: Vector2i = key
		if not vis.grow(1).has_point(Vector2(tile)):
			continue
		if skip_plaza and _plaza_set.has(tile):
			continue
		var p: Vector2 = Vector2(tile) * TILE
		var n: bool = not tiles.has(tile + nw)
		var s: bool = not tiles.has(tile + sw)
		var w: bool = not tiles.has(tile + ww)
		var e: bool = not tiles.has(tile + ew)
		if roads_block:
			# Wegdurchlaesse am Platzrand offen halten, nicht mit Gras zunaehen.
			n = n and not _walkable.has(tile + nw)
			s = s and not _walkable.has(tile + sw)
			w = w and not _walkable.has(tile + ww)
			e = e and not _walkable.has(tile + ew)
		if n:
			draw_line(p + Vector2(-0.5, 0.5), p + Vector2(TILE + 0.5, 0.5), soft, 5.0)
		if s:
			draw_line(p + Vector2(-0.5, TILE - 0.5),
				p + Vector2(TILE + 0.5, TILE - 0.5), soft, 5.0)
		if w:
			draw_line(p + Vector2(0.5, -0.5), p + Vector2(0.5, TILE + 0.5), soft, 5.0)
		if e:
			draw_line(p + Vector2(TILE - 0.5, -0.5),
				p + Vector2(TILE - 0.5, TILE + 0.5), soft, 5.0)
		if n and w:
			draw_circle(p, radius, hard)
		if n and e:
			draw_circle(p + Vector2(TILE, 0), radius, hard)
		if s and w:
			draw_circle(p + Vector2(0, TILE), radius, hard)
		if s and e:
			draw_circle(p + Vector2(TILE, TILE), radius, hard)


func _draw_plaza(vis: Rect2) -> void:
	var plaza: Dictionary = layout["plaza"]
	var bounds: Rect2i = layout["plaza_rect"]
	if not vis.intersects(bounds) or _cobble_edges.is_empty():
		return
	for t in plaza.keys():
		var tile: Vector2i = t
		if not vis.has_point(Vector2(tile)):
			continue
		var tint: float = float((tile.x * 7 + tile.y * 13) % 5) * 0.012
		var m: int = _mask4(tile, _plaza_set)
		draw_texture_rect(_cobble_edges[m],
			Rect2(Vector2(tile) * TILE, Vector2(TILE, TILE)), false,
			Color(0.78 - tint, 0.73 - tint, 0.63 - tint))
	# Vereinzelte Pflastersteine.
	for t in plaza.keys():
		var tile2: Vector2i = t
		if not vis.has_point(Vector2(tile2)):
			continue
		for i in 2:
			var px: float = float(tile2.x * TILE) + float((i * 5 + tile2.y) % 10)
			var py: float = float(tile2.y * TILE) + float((i * 7 + tile2.x) % 10)
			draw_rect(Rect2(px, py, 4, 3), Color(0.56, 0.52, 0.43, 0.75))


func _draw_pond(vis: Rect2) -> void:
	var pond: Dictionary = layout["pond"]
	if _sand_edges.is_empty() or _water_edges.is_empty():
		return
	for t in pond.get("shore", []):
		if vis.has_point(Vector2(t)):
			var ms: int = _mask4(t, _shore_water_set)
			draw_texture_rect(_sand_edges[ms],
				Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), false,
				Color(0.86, 0.78, 0.62))
	for t in pond.get("water", []):
		if vis.has_point(Vector2(t)):
			# Sandbasis unter dem Wasser; die Wasser-Kante deckt die Mitte ab.
			draw_texture_rect(_sand_tex,
				Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), true,
				Color(0.86, 0.78, 0.62))
			var mw: int = _mask4(t, _water_set)
			draw_texture_rect(_water_edges[mw],
				Rect2(Vector2(t) * TILE, Vector2(TILE, TILE)), false,
				Color(0.64, 0.75, 0.79))
	# Schilf an der Wasserlinie.
	for t in pond.get("water", []):
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not _water_set.has(t + d):
				var p2: Vector2 = Vector2(t) * TILE
				draw_line(p2 + Vector2(0, 6), p2 + Vector2(TILE, 6),
					Color(0.20, 0.34, 0.28, 0.55), 1.5)
	for t in pond.get("shore", []):
		if (int(t.x) * 7 + int(t.y) * 11) % 13 == 0:
			var p3: Vector2 = Vector2(t) * TILE + Vector2(6, 13)
			draw_line(p3, p3 + Vector2(1, -7), Color(0.30, 0.45, 0.20), 1.0)


func _draw_fields(vis: Rect2) -> void:
	for f in layout["fields"]:
		var rect: Rect2i = f["rect"]
		if not vis.intersects(rect):
			continue
		var r: Rect2 = _tile_rect(rect)
		var stage: int = int(f["stage"])
		var soil: Color = FIELD_COLORS[stage]
		draw_rect(r, soil)
		# Feuchte/Erde als unregelmaessige Flecken, keine flache Flaeche.
		for i in 10:
			var fx: float = r.position.x + 4.0 + fmod(float(i) * 23.0, r.size.x - 8.0)
			var fy: float = r.position.y + 4.0 + fmod(float(i) * 17.0, r.size.y - 8.0)
			draw_rect(Rect2(fx, fy, 5, 3),
				Color(soil.r * 0.82, soil.g * 0.78, soil.b * 0.74, 0.55))
		# Furchen und Crop-Reihen.
		var rows: int = rect.size.y * 2
		for i in rows:
			var yy: float = r.position.y + float(i) * 8.0 + 2.0
			if i % 2 == 0:
				draw_rect(Rect2(r.position.x + 4, yy, r.size.x - 8, 2),
					Color(0.28, 0.20, 0.11, 0.55))
			else:
				draw_rect(Rect2(r.position.x + 4, yy, r.size.x - 8, 3),
					CROP_COLORS[stage])
		if stage == 4:
			for i in 30:
				var fx: float = r.position.x + 6.0 + fmod(float(i) * 19.0, r.size.x - 12.0)
				var fy: float = r.position.y + 6.0 + fmod(float(i) * 13.0, r.size.y - 12.0)
				draw_rect(Rect2(fx, fy, 2, 4), Color(0.80, 0.72, 0.30))
		# Weicher Ackerrain statt harter Rechteckkontur.
		draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)),
			Color(0.24, 0.18, 0.10, 0.45), false, 1.5)
		# Grasnaht entlang der Feldkanten und gerundete Ecken zuletzt.
		var edge: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.48)
		draw_line(r.position + Vector2(0, 1.0),
			Vector2(r.end.x, r.position.y + 1.0), edge, 3.0)
		draw_line(Vector2(r.position.x, r.end.y - 1.0),
			r.end - Vector2(0, 1.0), edge, 3.0)
		draw_line(r.position + Vector2(1.0, 0),
			Vector2(r.position.x + 1.0, r.end.y), edge, 3.0)
		draw_line(Vector2(r.end.x - 1.0, r.position.y),
			r.end - Vector2(1.0, 0), edge, 3.0)
		var gr: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.95)
		for corner in [r.position, Vector2(r.end.x, r.position.y),
				Vector2(r.position.x, r.end.y), r.end]:
			draw_circle(corner, 8.0, gr)
		if bool(f.get("hedge", false)):
			_draw_hedge(rect)
		if bool(f.get("fence", false)):
			_draw_fence(rect, 4)


func _draw_hedge(rect: Rect2i) -> void:
	var r: Rect2 = _tile_rect(rect)
	var n: int = int(maxf(rect.size.x, rect.size.y))
	for i in n * 2:
		var t: float = float(i) / float(n * 2 - 1)
		var px: float = r.position.x + t * r.size.x
		var py: float = r.position.y - 3.0
		draw_circle(Vector2(px, py), 4.0, Color(0.22, 0.36, 0.18))
		draw_circle(Vector2(px, r.end.y + 3.0), 4.0, Color(0.22, 0.36, 0.18))
		var py2: float = r.position.y + t * r.size.y
		draw_circle(Vector2(r.position.x - 3.0, py2), 4.0, Color(0.22, 0.36, 0.18))
		draw_circle(Vector2(r.end.x + 3.0, py2), 4.0, Color(0.22, 0.36, 0.18))


func _draw_fence(rect: Rect2i, gap: int) -> void:
	var r: Rect2 = _tile_rect(rect)
	var step: float = 8.0
	var x: float = r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y - 2), Vector2(x, r.position.y - 8),
			Color(0.42, 0.30, 0.17), 1.5)
		draw_line(Vector2(x, r.end.y + 2), Vector2(x, r.end.y + 8),
			Color(0.42, 0.30, 0.17), 1.5)
		x += step
	var y: float = r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x - 2, y), Vector2(r.position.x - 8, y),
			Color(0.42, 0.30, 0.17), 1.5)
		draw_line(Vector2(r.end.x + 2, y), Vector2(r.end.x + 8, y),
			Color(0.42, 0.30, 0.17), 1.5)
		y += step


func _draw_farm_yards(vis: Rect2) -> void:
	for fs in layout["farmsteads"]:
		var yard: Rect2i = fs["yard"]
		if not vis.intersects(yard):
			continue
		var r: Rect2 = _tile_rect(yard)
		draw_texture_rect(_dirt_tex, r, true, Color(0.78, 0.67, 0.51))
		# Stroh, Pfuetzen und Trittspuren statt einer braunen Flaeche.
		for i in 6:
			var sx: float = r.position.x + 6.0 + fmod(float(i) * 23.0,
				r.size.x - 12.0)
			var sy: float = r.position.y + 5.0 + fmod(float(i) * 17.0,
				r.size.y - 10.0)
			if i % 2 == 0:
				draw_rect(Rect2(sx, sy, 9, 4), Color(0.72, 0.58, 0.30, 0.75))
				draw_line(Vector2(sx, sy + 1), Vector2(sx + 9, sy + 1),
					Color(0.54, 0.40, 0.20, 0.8), 1.0)
				draw_line(Vector2(sx + 2, sy), Vector2(sx + 4, sy + 4),
					Color(0.82, 0.70, 0.40, 0.7), 1.0)
			else:
				draw_circle(Vector2(sx + 3, sy + 2), 3.0,
					Color(0.34, 0.28, 0.20, 0.55))
		var edge: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.45)
		draw_line(r.position + Vector2(0, 1.0),
			Vector2(r.end.x, r.position.y + 1.0), edge, 3.0)
		draw_line(Vector2(r.position.x, r.end.y - 1.0),
			r.end - Vector2(0, 1.0), edge, 3.0)
		draw_line(r.position + Vector2(1.0, 0),
			Vector2(r.position.x + 1.0, r.end.y), edge, 3.0)
		draw_line(Vector2(r.end.x - 1.0, r.position.y),
			r.end - Vector2(1.0, 0), edge, 3.0)
		var gr: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.90)
		for corner in [r.position, Vector2(r.end.x, r.position.y),
				Vector2(r.position.x, r.end.y), r.end]:
			draw_circle(corner, 7.0, gr)
		# Hofzaun an den Seiten und mit Durchlass zur Hofzufahrt.
		var fy: float = r.end.y + 2.0
		var x: float = r.position.x
		while x <= r.end.x:
			if absf(x - (r.position.x + r.size.x * 0.45)) > 9.0:
				draw_line(Vector2(x, fy), Vector2(x, fy - 7),
					Color(0.44, 0.31, 0.18), 1.5)
			x += 9.0
		draw_line(Vector2(r.position.x, fy - 4), Vector2(r.end.x, fy - 4),
			Color(0.38, 0.26, 0.14), 1.0)
		var y: float = r.position.y
		while y <= r.end.y:
			draw_line(Vector2(r.position.x - 2, y),
				Vector2(r.position.x - 8, y), Color(0.44, 0.31, 0.18), 1.2)
			draw_line(Vector2(r.end.x + 2, y),
				Vector2(r.end.x + 8, y), Color(0.44, 0.31, 0.18), 1.2)
			y += 9.0


func _draw_orchard(vis: Rect2) -> void:
	for o in layout["orchards"]:
		var rect: Rect2i = o["rect"]
		if not vis.intersects(rect):
			continue
		var r: Rect2 = _tile_rect(rect)
		draw_rect(r, Color(0.34, 0.42, 0.25, 0.55))
		draw_rect(r, Color(0.26, 0.34, 0.18, 0.65), false, 2.0)
		_draw_fence(rect, 10)


func _draw_objects(vis: Rect2) -> void:
	var drawables: Array = []
	for i in (layout["house_rows"] as Array).size():
		var row: Dictionary = layout["house_rows"][i]
		var row_rect: Rect2i = row["rect"]
		if vis.intersects(row_rect):
			drawables.append({"y": float(row_rect.position.y
				+ row_rect.size.y) * TILE, "kind": 5, "ref": i})
	for i in (layout["farmsteads"] as Array).size():
		var fs: Dictionary = layout["farmsteads"][i]
		var fs_rect: Rect2i = fs["rect"]
		if vis.intersects(fs_rect):
			drawables.append({"y": float(fs_rect.position.y + 9) * TILE,
				"kind": 6, "ref": i})
	for c in layout["civic"]:
		var rect2: Rect2i = c["rect"]
		if vis.intersects(rect2):
			drawables.append({"y": float(rect2.position.y + rect2.size.y) * TILE,
				"kind": 1, "ref": c})
	for t in layout["trees"]:
		var tile: Vector2i = t["tile"]
		if vis.has_point(Vector2(tile)):
			drawables.append({"y": float(tile.y) * TILE + 10.0,
				"kind": 2, "ref": t})
	for p in layout["props"]:
		var pt: Vector2i = p["tile"]
		if vis.has_point(Vector2(pt)) or vis.grow(2).has_point(Vector2(pt)):
			drawables.append({"y": float(pt.y) * TILE + 12.0,
				"kind": 3, "ref": p})
	for w in walkers:
		var wp: Vector2 = walker_tile(w) * TILE
		if vis.has_point(wp / TILE):
			drawables.append({"y": wp.y, "kind": 4, "ref": w})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["y"]) - float(b["y"])) < 0.01:
			return int(a["kind"]) < int(b["kind"])
		return float(a["y"]) < float(b["y"]))
	for d in drawables:
		match int(d["kind"]):
			1:
				_draw_civic(d["ref"])
			2:
				_draw_tree(d["ref"])
			3:
				_draw_prop(d["ref"])
			4:
				_draw_walker(d["ref"])
			5:
				_draw_row(int(d["ref"]))
			6:
				_draw_farmstead(int(d["ref"]))


func _draw_row(ri: int) -> void:
	var row: Dictionary = layout["house_rows"][ri]
	var tex: Texture2D = _row_tex.get(ri)
	if tex == null:
		return
	var row_rect: Rect2i = row["rect"]
	var r: Rect2 = _tile_rect(row_rect)
	var garden: Rect2i = row["garden"]
	if garden.size.x > 0:
		_draw_garden(garden)
	for h in row["houses"]:
		var hr: Rect2 = _tile_rect(h["rect"])
		for si in 5:
			var sx: float = hr.position.x + 5.0 + float(si) * (hr.size.x - 10.0) / 4.0
			draw_circle(Vector2(sx, hr.end.y - 2.0), 8.0,
				Color(0.05, 0.05, 0.04, 0.16))
	draw_texture_rect(tex, r, false)
	_draw_row_fence(row)
	for h in row["houses"]:
		var h_rect: Rect2i = h["rect"]
		_draw_window_glow(_tile_rect(h_rect), h_rect, night_factor)


func _draw_row_fence(row: Dictionary) -> void:
	var garden: Rect2i = row["garden"]
	if garden.size.x <= 0:
		return
	var r: Rect2 = _tile_rect(garden)
	var fy: float = r.end.y + 1.0
	var doors: Array = row["doors"]
	var x: float = r.position.x
	while x <= r.end.x:
		var gate: bool = false
		for door in doors:
			if absf(x - (float(door.x) + 0.5) * TILE) <= 11.0:
				gate = true
		if not gate:
			draw_line(Vector2(x, fy), Vector2(x, fy - 7),
				Color(0.45, 0.31, 0.17), 1.5)
		x += 8.0
	draw_line(Vector2(r.position.x, fy - 4), Vector2(r.end.x, fy - 4),
		Color(0.38, 0.26, 0.14), 1.0)
	for sx in [r.position.x, r.end.x]:
		draw_line(Vector2(sx, r.position.y), Vector2(sx, fy),
			Color(0.40, 0.28, 0.15), 1.0)


func _draw_farmstead(fi: int) -> void:
	var fs: Dictionary = layout["farmsteads"][fi]
	var rect: Rect2i = fs["rect"]
	var tex: Texture2D = _farm_tex.get(fi)
	if tex == null:
		return
	var h_rect: Rect2i = fs["house_rect"]
	for si in 4:
		var hrr: Rect2 = _tile_rect(h_rect)
		draw_circle(Vector2(hrr.position.x + 6.0 + float(si)
			* (hrr.size.x - 12.0) / 3.0, hrr.end.y - 2.0), 8.0,
			Color(0.05, 0.05, 0.04, 0.16))
	draw_texture_rect(tex, _tile_rect(rect), false)
	_draw_window_glow(_tile_rect(h_rect), h_rect, night_factor * 0.8)
	# Scheunentor-Rahmen als lesbares Farm-Detail.
	var b_rect: Rect2i = fs["barn_rect"]
	var br: Rect2 = _tile_rect(b_rect)
	draw_rect(Rect2(br.position.x + br.size.x * 0.35,
		br.position.y + br.size.y * 0.62, br.size.x * 0.30,
		br.size.y * 0.34), Color(0.30, 0.20, 0.12, 0.85), false, 2.0)


func _draw_garden(garden: Rect2i) -> void:
	var r: Rect2 = _tile_rect(garden)
	draw_rect(r, Color(0.35, 0.28, 0.18))
	var rows: int = garden.size.y * 2
	for i in rows:
		draw_rect(Rect2(r.position.x + 3,
			r.position.y + float(i) * 8.0 + 3.0, r.size.x - 6, 4),
			Color(0.30, 0.44, 0.21))
		draw_rect(Rect2(r.position.x + 3,
			r.position.y + float(i) * 8.0 + 6.0, r.size.x - 6, 1),
			Color(0.22, 0.34, 0.15))
	for i in 16:
		var px: float = r.position.x + 4.0 + fmod(float(i) * 13.0, r.size.x - 8.0)
		var py: float = r.position.y + 4.0 + fmod(float(i) * 9.0, r.size.y - 8.0)
		draw_circle(Vector2(px, py), 2.0,
			Color(0.46, 0.60, 0.28) if i % 3 != 0 else Color(0.82, 0.64, 0.28))
	# Gartenzaun an den Seiten.
	var fy: float = r.end.y + 2.0
	var x: float = r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, fy), Vector2(x, fy - 6),
			Color(0.42, 0.30, 0.17), 1.2)
		x += 8.0
	var gr: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.85)
	for corner in [Vector2(r.position.x, r.end.y), r.end]:
		draw_circle(corner, 5.0, gr)
	var edge: Color = Color(_grass_avg.r, _grass_avg.g, _grass_avg.b, 0.40)
	draw_line(Vector2(r.position.x, r.end.y - 1.0),
		Vector2(r.end.x, r.end.y - 1.0), edge, 3.0)


func _draw_window_glow(r: Rect2, rect: Rect2i, nf: float) -> void:
	if nf <= 0.06:
		return
	var warm: Color = Color(1.0, 0.80, 0.36, 0.85 * nf)
	var wall_y: float = r.position.y + float(rect.size.y - 3) * TILE
	for fx in [0.22, 0.72]:
		draw_rect(Rect2(r.position.x + r.size.x * float(fx), wall_y,
			5, 5), warm)
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 2,
		r.end.y - 14, 4, 5), Color(1.0, 0.70, 0.30, 0.85 * nf))


func _draw_civic(c: Dictionary) -> void:
	var rect: Rect2i = c["rect"]
	var r: Rect2 = _tile_rect(rect)
	var tex: Texture2D = _civic_tex.get(str(c["kind"]))
	if tex == null:
		return
	draw_rect(Rect2(r.position + Vector2(5, 6), r.size),
		Color(0.05, 0.05, 0.04, 0.28))
	draw_texture_rect(tex, r, false)
	_draw_window_glow(r, rect, night_factor * 0.7)
	if str(c["kind"]) == "granary":
		for i in 3:
			_blit_prop(r.position + Vector2(6 + i * 12, r.size.y - 10),
				BASE_SACK, 10)
	elif str(c["kind"]) == "barn":
		draw_rect(Rect2(r.position.x + r.size.x * 0.36,
			r.end.y - 12, r.size.x * 0.28, 10), Color(0.34, 0.22, 0.12, 0.9))


func _draw_tree(t: Dictionary) -> void:
	var tile: Vector2i = t["tile"]
	var p: Vector2 = Vector2(tile) * TILE + Vector2(8, 14)
	var base_tex: Texture2D = _base_tex
	var cell: Vector2i = BASE_TREE[int(t["variant"]) % BASE_TREE.size()]
	var size: float = 34.0
	draw_circle(p + Vector2(1, -10), 7.0, Color(0.06, 0.10, 0.05, 0.22))
	draw_texture_rect_region(base_tex,
		Rect2(p - Vector2(size * 0.5, size), Vector2(size, size)),
		Rect2(cell.x * BASE_PITCH, cell.y * BASE_PITCH, BASE_PITCH, BASE_PITCH))
	if bool(t.get("fruit", false)):
		for i in 4:
			var a: float = float(i) * 1.57 + float(tile.x) * 0.3
			draw_circle(p + Vector2(cos(a) * 7.0, -9.0 + sin(a) * 6.0),
				1.8, Color(0.82, 0.28, 0.20))


func _draw_prop(p: Dictionary) -> void:
	var tile: Vector2i = p["tile"]
	var base: Vector2 = Vector2(tile) * TILE + Vector2(8, 14)
	match str(p["kind"]):
		"market":
			draw_rect(Rect2(base - Vector2(14, 20), Vector2(28, 14)),
				Color(0.72, 0.31, 0.24))
			draw_rect(Rect2(base - Vector2(14, 20), Vector2(28, 4)),
				Color(0.92, 0.86, 0.70))
			draw_line(base + Vector2(-12, -6), base + Vector2(-12, 8),
				Color(0.38, 0.25, 0.14), 2.0)
			draw_line(base + Vector2(12, -6), base + Vector2(12, 8),
				Color(0.38, 0.25, 0.14), 2.0)
			for i in 3:
				draw_circle(base + Vector2(-8 + i * 8, 1), 2.6,
					Color(0.86, 0.70, 0.28))
		"bench":
			draw_rect(Rect2(base - Vector2(10, 8), Vector2(20, 4)),
				Color(0.50, 0.34, 0.18))
			draw_rect(Rect2(base + Vector2(-8, -4), Vector2(2, 6)),
				Color(0.34, 0.24, 0.13))
			draw_rect(Rect2(base + Vector2(6, -4), Vector2(2, 6)),
				Color(0.34, 0.24, 0.13))
		"barrel":
			draw_circle(base + Vector2(0, -4), 5.0, Color(0.46, 0.30, 0.15))
			draw_line(base + Vector2(-5, -4), base + Vector2(5, -4),
				Color(0.24, 0.18, 0.10), 1.0)
		"cart":
			draw_rect(Rect2(base - Vector2(12, 12), Vector2(24, 10)),
				Color(0.48, 0.32, 0.17))
			draw_circle(base + Vector2(-9, 0), 5.0, Color(0.30, 0.22, 0.12))
			draw_circle(base + Vector2(9, 0), 5.0, Color(0.30, 0.22, 0.12))
			draw_line(base + Vector2(-9, 0), base + Vector2(-16, 5),
				Color(0.36, 0.24, 0.12), 2.0)
		"woodpile":
			for i in 5:
				draw_circle(base + Vector2(-8 + i * 4, -2), 2.2,
					Color(0.52, 0.36, 0.20))
				draw_circle(base + Vector2(-6 + i * 4, -6), 2.2,
					Color(0.58, 0.40, 0.22))
		"laundry":
			draw_line(base + Vector2(-10, -14), base + Vector2(10, -14),
				Color(0.55, 0.50, 0.40), 1.0)
			draw_rect(Rect2(base + Vector2(-7, -13), Vector2(6, 8)),
				Color(0.90, 0.88, 0.78))
			draw_rect(Rect2(base + Vector2(1, -13), Vector2(6, 8)),
				Color(0.72, 0.82, 0.88))
		"well":
			draw_circle(base + Vector2(0, -12), 20.0, Color(0.60, 0.59, 0.52))
			draw_circle(base + Vector2(0, -12), 15.0, Color(0.16, 0.30, 0.36))
			draw_circle(base + Vector2(0, -12), 18.5, Color(0.40, 0.39, 0.34),
				false, 1.5)
			draw_line(base + Vector2(-18, -22), base + Vector2(-18, -4),
				Color(0.40, 0.27, 0.15), 2.0)
			draw_line(base + Vector2(18, -22), base + Vector2(18, -4),
				Color(0.40, 0.27, 0.15), 2.0)
			draw_line(base + Vector2(-18, -22), base + Vector2(18, -22),
				Color(0.46, 0.31, 0.17), 2.0)
		_:
			_blit_prop(base - Vector2(8, 12), BASE_SACK, 12)


func _blit_prop(pos: Vector2, cell: Vector2i, size: int) -> void:
	draw_texture_rect_region(_base_tex, Rect2(pos, Vector2(size, size)),
		Rect2(cell.x * BASE_PITCH, cell.y * BASE_PITCH, BASE_PITCH, BASE_PITCH))


func _draw_walker(w: Dictionary) -> void:
	var pos: Vector2 = walker_tile(w) * TILE
	var cell: Vector2i = CHAR_CELLS[int(w["cell"]) % CHAR_CELLS.size()]
	var moving: bool = float(w["pause"]) <= 0.0
	var bob: float = 0.0
	if moving:
		bob = absf(sin(_time * 8.0 + float(w["id"]) * 0.7)) * -1.4
	draw_circle(pos + Vector2(0, 1), 5.2, Color(0.05, 0.08, 0.04, 0.30))
	var size: float = 16.0 * FIGURE_SCALE
	var dest: Rect2 = Rect2(pos + Vector2(-size * 0.5, -size + 4.0 + bob),
		Vector2(size, size))
	var tint: Color = CHAR_TINTS[int(w["tint"]) % CHAR_TINTS.size()]
	draw_texture_rect_region(_ch_tex, dest,
		Rect2(cell.x * RP_PITCH, cell.y * RP_PITCH, 16, 16), tint)
	if int(w["id"]) == hover_id:
		draw_arc(pos + Vector2(0, -5), 11.0, 0.0, TAU, 24,
			Color(1.0, 0.92, 0.55), 2.0)


func _blit_pack(dst: Image, cell: Vector2i, dx: int, dy: int) -> void:
	var src: Image = _rp_img
	var sx: int = cell.x * RP_PITCH
	var sy: int = cell.y * RP_PITCH
	for y in 16:
		for x in 16:
			dst.set_pixel(dx + x, dy + y, src.get_pixel(sx + x, sy + y))


func _blit_base(dst: Image, cell: Vector2i, dx: int, dy: int,
		w: int, h: int) -> void:
	var key: String = "%d,%d,%d,%d" % [cell.x, cell.y, w, h]
	var tile: Image = _base16_cache.get(key)
	if tile == null:
		tile = _base_img.get_region(Rect2i(cell.x * BASE_PITCH,
			cell.y * BASE_PITCH, BASE_PITCH, BASE_PITCH)).duplicate()
		tile.resize(w, h, Image.INTERPOLATE_NEAREST)
		_base16_cache[key] = tile
	var src: Image = tile
	for y in mini(h, src.get_height()):
		for x in mini(w, src.get_width()):
			dst.set_pixel(dx + x, dy + y, src.get_pixel(x, y))

