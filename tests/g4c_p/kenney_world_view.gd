extends Node2D

## G4c-P-Pretest-Ansicht. Rein darstellend: liest Simulation/ViewState und
## zeichnet Kenney-Gelaende, komponierte Gebaeude, Felder und Figuren.
## Der bestehende src/view/world_view.gd bleibt fuer die Gates unveraendert.
##
## Render-LOD ist rein visuell: weit draussen werden Strassen/Felder flach
## gezeichnet, Figuren/Gebaeude bleiben sichtbar. Es werden keine Agenten
## gefiltert, keine Events uebersprungen und keine Simulationszeit gekuerzt.

const TILE_PX: int = 16
const RP_PITCH: int = 17
const CH_PITCH: int = 17
const BASE_PITCH: int = 64

const RP_GRASS: Array = [Vector2i(5, 1), Vector2i(5, 0)]
const RP_GRASS_PLAIN: Vector2i = Vector2i(5, 1)
const RP_DIRT: Vector2i = Vector2i(6, 1)
const RP_SAND: Vector2i = Vector2i(8, 1)
const RP_WATER: Vector2i = Vector2i(1, 1)
const RP_COBBLE: Vector2i = Vector2i(9, 0)
const RP_FLOWERS: Array = [Vector2i(0, 9), Vector2i(1, 9), Vector2i(3, 8)]
const RP_TREES: Array = [Vector2i(13, 10), Vector2i(13, 9), Vector2i(13, 11)]

const BASE_GRASS: Vector2i = Vector2i(1, 1)
const BASE_DIRT: Vector2i = Vector2i(6, 1)
const BASE_WATER: Vector2i = Vector2i(11, 1)
const BASE_SAND: Vector2i = Vector2i(6, 0)
const BASE_TREES: Array = [Vector2i(0, 10), Vector2i(2, 10),
	Vector2i(4, 10), Vector2i(1, 9), Vector2i(3, 9)]

const BASE_WALL_CREAM: Vector2i = Vector2i(3, 3)
const BASE_WALL_BRICK: Vector2i = Vector2i(4, 3)
const BASE_WALL_STONE: Vector2i = Vector2i(13, 3)
const BASE_ROOF_BROWN: Vector2i = Vector2i(1, 7)
const BASE_ROOF_CREAM: Vector2i = Vector2i(6, 7)
const BASE_ROOF_GRAY: Vector2i = Vector2i(10, 7)
const BASE_ROOF_DARK: Vector2i = Vector2i(9, 7)
const BASE_DOOR: Vector2i = Vector2i(10, 12)
const BASE_BIG_DOOR: Vector2i = Vector2i(14, 10)
const BASE_WINDOW: Vector2i = Vector2i(12, 12)
const BASE_SACK: Vector2i = Vector2i(9, 12)
const BASE_BARREL: Vector2i = Vector2i(9, 10)
const BASE_CHIMNEY: Vector2i = Vector2i(13, 4)

## 12 vollstaendige Figuren aus roguelikeChar (Spalten 0/1, Zeilen 5..10).
const CHAR_VARIANTS: Array = [Vector2i(0, 5), Vector2i(1, 5),
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7), Vector2i(1, 7),
	Vector2i(0, 8), Vector2i(1, 8), Vector2i(0, 9), Vector2i(1, 9),
	Vector2i(0, 10), Vector2i(1, 10)]

const AGENT_COLORS: Array = [
	Color(0.95, 0.78, 0.45), Color(0.86, 0.55, 0.42),
	Color(0.55, 0.78, 0.92), Color(0.95, 0.62, 0.78),
	Color(0.65, 0.85, 0.55), Color(0.92, 0.85, 0.50),
	Color(0.65, 0.62, 0.92), Color(0.80, 0.72, 0.60),
	Color(0.55, 0.72, 0.50), Color(0.95, 0.55, 0.48),
]

const ACT_COLORS: Array = [
	Color(0.70, 0.70, 0.70), Color(0.55, 0.65, 0.80),
	Color(0.95, 0.78, 0.30), Color(0.95, 0.55, 0.30),
	Color(0.45, 0.55, 0.85), Color(0.90, 0.55, 0.75),
	Color(0.40, 0.78, 0.75), Color(0.55, 0.85, 0.45),
	Color(0.45, 0.80, 0.90),
]
const ACT_GLYPHS: Array = ["i", ">", "W", "E", "Z", "S", "L", "P", "H"]
const ACT_NAMES: Array = ["untätig", "unterwegs", "Arbeit", "essen",
	"schlafen", "sozial", "lernen", "spielen", "Hygiene"]

const FIELD_COLORS: Array = [
	Color(0.40, 0.30, 0.20), Color(0.33, 0.24, 0.16),
	Color(0.46, 0.34, 0.22), Color(0.50, 0.38, 0.24),
	Color(0.38, 0.52, 0.24), Color(0.30, 0.54, 0.22),
	Color(0.78, 0.66, 0.22), Color(0.62, 0.50, 0.18),
]
const FIELD_STAGE_DE: Array = ["Brache", "Pflügen", "gepflügt", "Säen",
	"gesät", "wächst", "reif", "Ernte"]

var sim: Simulation
var view_state: ViewState
var terrain_mode: int = 0
var character_mode: int = 0
var debug_scale_sort: bool = false
var night_factor: float = 0.0
var hover_agent_id: int = 0

var _rp_img: Image
var _ch_img: Image
var _base_img: Image
var _rp_tex: Texture2D
var _ch_tex: Texture2D
var _base_tex: Texture2D

var _grass_tex: Texture2D
var _road_tex: Texture2D
var _field_tex: Array = []
var _building_tex: Dictionary = {}
var _building_style: Dictionary = {}
var _pack_tile_cache: Dictionary = {}
var _base_tile_cache: Dictionary = {}
var _base16_cache: Dictionary = {}
var _font: Font
var _time: float = 0.0
var _last_pos: Dictionary = {}
var _moving: Dictionary = {}
var _prev_configure_key: String = ""


func configure(p_sim: Simulation, p_view_state: ViewState) -> void:
	sim = p_sim
	view_state = p_view_state
	_ensure_assets()
	_rebuild_terrain_textures()
	_rebuild_building_textures()
	_prev_configure_key = "%d:%d" % [sim.config.seed, sim.config.profile]
	queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_font = ThemeDB.fallback_font
	_ensure_assets()


func _ensure_assets() -> void:
	if _rp_img == null:
		_rp_img = Image.load_from_file(
			"res://assets/kenney/roguelike-rpg-pack/roguelikeSheet_transparent.png")
		_rp_tex = ImageTexture.create_from_image(_rp_img)
	if _ch_img == null:
		_ch_img = Image.load_from_file(
			"res://assets/kenney/roguelike-characters/roguelikeChar_transparent.png")
		_ch_tex = ImageTexture.create_from_image(_ch_img)
	if _base_img == null:
		_base_img = Image.load_from_file(
			"res://assets/kenney/rpg-base/RPGpack_sheet.png")
		_base_tex = ImageTexture.create_from_image(_base_img)


func set_terrain_mode(mode: int) -> void:
	terrain_mode = clampi(mode, 0, 1)
	_rebuild_terrain_textures()
	queue_redraw()


func set_character_mode(mode: int) -> void:
	character_mode = clampi(mode, 0, 1)
	queue_redraw()


func terrain_label() -> String:
	return "RPG Pack" if terrain_mode == 0 else "RPG Base (16 px)"


func character_label() -> String:
	return "Kenney-Figuren" if character_mode == 0 else "Vektor-Figuren"


func activity_name(act: int) -> String:
	return str(ACT_NAMES[act]) if act >= 0 and act < ACT_NAMES.size() else "?"


func field_stage_label(stage: int) -> String:
	if stage < 0 or stage >= FIELD_STAGE_DE.size():
		return "?"
	return str(FIELD_STAGE_DE[stage])


func _process(delta: float) -> void:
	_time += delta
	if sim == null:
		return
	# Bewegungs-Bob/Facing ist reine Darstellung, kein Sim-Zustand.
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var pos: Vector2 = sim.current_position(row)
		var prev: Vector2 = _last_pos.get(row, pos)
		_moving[row] = pos.distance_squared_to(prev) > 0.000001
		_last_pos[row] = pos
	queue_redraw()


func _draw() -> void:
	if sim == null or view_state == null:
		return
	_ensure_assets()
	var visible_tiles: Rect2 = _visible_tiles()
	_draw_ground(visible_tiles)
	_draw_pond(visible_tiles)
	_draw_roads(visible_tiles)
	_draw_fields(visible_tiles)
	_draw_sorted_objects(visible_tiles)
	if debug_scale_sort:
		_draw_debug(visible_tiles)


func _visible_tiles() -> Rect2:
	var vp: Vector2 = get_viewport_rect().size
	var z: float = maxf(0.05, view_state.zoom)
	var half: Vector2 = vp * 0.5 / (z * float(TILE_PX))
	return Rect2(view_state.camera_position - half - Vector2(3, 3),
		half * 2.0 + Vector2(6, 6))


func _world_rect() -> Rect2:
	return Rect2(0, 0, sim.world.size * TILE_PX, sim.world.size * TILE_PX)


func _draw_ground(visible_tiles: Rect2) -> void:
	var r: Rect2 = _tile_rect(visible_tiles).intersection(_world_rect())
	if r.size.x <= 0 or r.size.y <= 0:
		return
	draw_texture_rect(_grass_tex, r, true)
	draw_rect(_world_rect(), Color(0.10, 0.14, 0.10, 0.9), false,
		maxf(1.0, 2.0 / maxf(0.1, view_state.zoom)))


func _draw_pond(visible_tiles: Rect2) -> void:
	for water in sim.world.water_rects:
		var rect: Rect2i = water
		if not visible_tiles.intersects(rect):
			continue
		var r: Rect2 = _tile_rect(rect)
		# Sandufer einen Tile breit.
		draw_texture_rect(_terrain_tile_texture(RP_SAND, BASE_SAND),
			Rect2(r.position - Vector2(TILE_PX, TILE_PX),
				r.size + Vector2(TILE_PX * 2, TILE_PX * 2)), true)
		if view_state.zoom < 0.45:
			draw_rect(Rect2(r.position - Vector2(TILE_PX, TILE_PX),
				r.size + Vector2(TILE_PX * 2, TILE_PX * 2)),
				Color(0.66, 0.56, 0.36))
			draw_rect(r, Color(0.30, 0.60, 0.78))
		else:
			draw_texture_rect(_terrain_tile_texture(RP_SAND, BASE_SAND),
				Rect2(r.position - Vector2(TILE_PX, TILE_PX),
					r.size + Vector2(TILE_PX * 2, TILE_PX * 2)), true)
			draw_texture_rect(_terrain_tile_texture(RP_WATER, BASE_WATER), r, true)
		draw_rect(r, Color(0.16, 0.30, 0.38), false,
			maxf(1.0, 2.0 / view_state.zoom))


func _draw_roads(visible_tiles: Rect2) -> void:
	for road_rect in sim.world._road_rects:
		var rect: Rect2i = road_rect
		if not visible_tiles.intersects(rect):
			continue
		var r: Rect2 = _tile_rect(rect)
		if view_state.zoom < 0.40:
			draw_rect(r, Color(0.46, 0.36, 0.24))
		else:
			draw_texture_rect(_road_tex, r, true)
	# Kleiner Dorfplatz direkt um den Brunnen (Kopfsteinpflaster).
	var well: Building = sim.world.building_by_id(sim.world._well_id)
	if well != null:
		var wc: Vector2 = Vector2(well.rect.get_center()) * TILE_PX
		var plaza: Rect2 = Rect2(wc - Vector2(TILE_PX * 4, TILE_PX * 3),
			Vector2(TILE_PX * 8, TILE_PX * 6))
		if visible_tiles.intersects(Rect2(plaza.position / float(TILE_PX),
				plaza.size / float(TILE_PX))):
			if view_state.zoom < 0.55:
				draw_rect(plaza, Color(0.56, 0.56, 0.50))
			else:
				draw_texture_rect(_terrain_tile_texture(RP_COBBLE,
					BASE_DIRT), plaza, true)
			draw_rect(plaza, Color(0.24, 0.22, 0.18), false,
				maxf(1.0, 1.5 / view_state.zoom))


func _draw_fields(visible_tiles: Rect2) -> void:
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field == null or not visible_tiles.intersects(field.rect):
			continue
		var r: Rect2 = _tile_rect(field.rect)
		var stage: int = field.field_stage
		if view_state.zoom < 0.38:
			draw_rect(r, FIELD_COLORS[stage])
			draw_rect(r, Color(0.18, 0.14, 0.08), false, 2.0)
		else:
			draw_texture_rect(_field_tex[stage], r, true)
			draw_rect(r, Color(0.20, 0.16, 0.10), false,
				maxf(1.0, 2.0 / view_state.zoom))
			var inset: float = 6.0
			draw_rect(Rect2(r.position + Vector2(inset, inset),
				r.size - Vector2(inset * 2, inset * 2)),
				Color(0.14, 0.12, 0.08, 0.55), false,
				maxf(1.0, 1.0 / view_state.zoom))
		var label: String = "%s · %s" % [field.name,
			field_stage_label(stage)]
		var font_size: int = 13
		var fs: float = float(font_size) / maxf(0.22, view_state.zoom)
		if fs > 5.0 and fs < 60.0:
			var size: Vector2 = _font.get_string_size(label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs))
			var pos: Vector2 = r.position + Vector2(
				r.size.x * 0.5 - size.x * 0.5, r.size.y - 8.0)
			draw_rect(Rect2(pos - Vector2(3, size.y - 2), size + Vector2(6, 4)),
				Color(0.06, 0.05, 0.04, 0.72))
			draw_string(_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(fs), Color(1.0, 0.95, 0.82))


func _draw_sorted_objects(visible_tiles: Rect2) -> void:
	var drawables: Array = []
	for building in sim.world.buildings:
		var b: Building = building
		if not visible_tiles.intersects(b.rect):
			continue
		if b.kind == Building.KIND_FIELD:
			continue
		drawables.append({
			"y": float(b.rect.position.y + b.rect.size.y) * TILE_PX,
			"kind": 0,
			"ref": b,
		})
	for p in sim.world.decor_trees:
		if not visible_tiles.has_point(p):
			continue
		drawables.append({"y": p.y * TILE_PX + 7.0, "kind": 1, "ref": p})
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var pos: Vector2 = sim.current_position(row)
		if not visible_tiles.has_point(pos):
			continue
		var vpos: Vector2 = _agent_visual_pos(row, pos)
		drawables.append({"y": vpos.y + 6.0, "kind": 3, "ref": row})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a["y"]) - float(b["y"])) < 0.001:
			return int(a["kind"]) < int(b["kind"])
		return float(a["y"]) < float(b["y"]))
	for d in drawables:
		match int(d["kind"]):
			0:
				_draw_building(d["ref"])
			1:
				_draw_tree(d["ref"])
			3:
				_draw_agent(int(d["ref"]))
	_draw_agent_overlays(visible_tiles)


## Reiner Anzeige-Offset gegen exakte Stapelung an gemeinsamen Arbeits-/Tuer-
## punkten. Die Simulationspositionen bleiben unveraendert; alle Agenten
## werden gezeichnet, keiner wird gefiltert.
func _agent_visual_pos(row: int, pos: Vector2) -> Vector2:
	var base: Vector2 = pos * TILE_PX
	if bool(_moving.get(row, false)):
		return base
	var id: int = sim.store.ids[row]
	var angle: float = float(id) * 2.39996323
	var radius: float = 0.16 + 0.50 * float(posmod(id * 37, 7)) / 6.0
	return base + Vector2(cos(angle), sin(angle)) * radius * TILE_PX


func _draw_building(building: Building) -> void:
	var key: int = building.id
	var tex: Texture2D = _building_tex.get(key)
	if tex == null:
		tex = _building_tex.get(-int(building.kind))
	if tex == null:
		return
	var r: Rect2 = _tile_rect(building.rect)
	draw_rect(Rect2(r.position + Vector2(4, 5), r.size),
		Color(0.05, 0.05, 0.04, 0.28))
	draw_texture_rect(tex, r, false)
	if night_factor > 0.08 and building.kind != Building.KIND_FIELD:
		var warm: Color = Color(1.0, 0.82, 0.38, 0.85 * night_factor)
		var h_tiles: int = building.rect.size.y
		var w_tiles: int = building.rect.size.x
		var wy: float = r.position.y + float(maxi(1, h_tiles - 2)) * TILE_PX
		for fx in [0.26, 0.74]:
			draw_rect(Rect2(Vector2(r.position.x + r.size.x * float(fx),
				wy), Vector2(5, 4)), warm)
		draw_rect(Rect2(Vector2(r.position.x + r.size.x * 0.5,
			r.end.y - TILE_PX * 1.4), Vector2(4, 3)),
			Color(1.0, 0.72, 0.34, 0.8 * night_factor))
	if debug_scale_sort:
		draw_line(Vector2(r.position.x - 4, r.end.y),
			Vector2(r.end.x + 4, r.end.y), Color(1, 0.2, 0.2, 0.8), 1.0)


func _draw_tree(p: Vector2) -> void:
	var px: Vector2 = p * TILE_PX
	var base: Vector2 = px + Vector2(0, 8)
	var size: float = 18.0 if terrain_mode == 0 else 24.0
	var variant: int = int(absf(p.x * 13.0 + p.y * 7.0)) % 3
	if terrain_mode == 0:
		var cell: Vector2i = RP_TREES[variant]
		draw_texture_rect_region(_rp_tex,
			Rect2(base - Vector2(size * 0.5, size), Vector2(size, size)),
			Rect2(cell.x * RP_PITCH, cell.y * RP_PITCH, 16, 16))
	else:
		var bcell: Vector2i = BASE_TREES[variant]
		draw_texture_rect_region(_base_tex,
			Rect2(base - Vector2(size * 0.5, size), Vector2(size, size)),
			Rect2(bcell.x * BASE_PITCH, bcell.y * BASE_PITCH, 64, 64))


func _draw_agent(row: int) -> void:
	var id: int = sim.store.ids[row]
	var true_pos: Vector2 = sim.current_position(row)
	var pos: Vector2 = _agent_visual_pos(row, true_pos)
	var role: int = sim.store.role[row]
	var moving: bool = bool(_moving.get(row, false))
	var phase: float = float(id % 17) * 0.71
	var bob: float = 0.0
	if moving:
		bob = sin(_time * 9.0 + phase) * 1.2
	else:
		bob = sin(_time * 2.0 + phase) * 0.45
	var scale: float = 0.78 if role == AgentStore.ROLE_CHILD else 1.0
	if role == AgentStore.ROLE_OLD:
		scale = 0.94
	# Schatten
	draw_set_transform(pos + Vector2(0, 3), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 5.2 * scale, Color(0, 0, 0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if character_mode == 0:
		var variant: Vector2i = CHAR_VARIANTS[
			int(absf(float(id) * 7.0)) % CHAR_VARIANTS.size()]
		var w: float = 16.0 * scale
		var h: float = 16.0 * scale
		var dest: Rect2 = Rect2(pos.x - w * 0.5, pos.y - h + 3.0 + bob,
			w, h)
		draw_texture_rect_region(_ch_tex, dest,
			Rect2(variant.x * CH_PITCH, variant.y * CH_PITCH, 16, 16))
	else:
		_draw_vector_agent(row, pos + Vector2(0, bob), scale)
	if debug_scale_sort:
		draw_line(pos + Vector2(-7, 6), pos + Vector2(7, 6),
			Color(0.2, 1.0, 0.4, 0.9), 1.0)


## Ringe, Aktivitaetsmarker und Namen werden nach allen Sprites gezeichnet,
## damit die Auswahl nicht unter gestapelten Figuren verschwindet.
func _draw_agent_overlays(visible_tiles: Rect2) -> void:
	var zoom: float = view_state.zoom
	var labels: Array = []
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var true_pos: Vector2 = sim.current_position(row)
		if not visible_tiles.has_point(true_pos):
			continue
		var id: int = sim.store.ids[row]
		var pos: Vector2 = _agent_visual_pos(row, true_pos)
		var selected: bool = id == view_state.selected_agent_id
		var hovered: bool = id == hover_agent_id
		var act: int = sim.store.activity[row]
		if zoom < 0.62:
			var r: float = clampf(2.4 / zoom, 2.0, 6.0)
			var dot: Color = ACT_COLORS[act] if act >= 0 \
				and act < ACT_COLORS.size() else Color.WHITE
			draw_circle(pos + Vector2(0, -2), r, dot)
			draw_arc(pos + Vector2(0, -2), r, 0.0, TAU, 10,
				Color(0.06, 0.05, 0.04, 0.85), 0.8)
			if selected:
				draw_arc(pos + Vector2(0, -2), r + 1.6, 0.0, TAU, 16,
					Color(1.0, 0.92, 0.35), 1.0)
			continue
		if selected:
			draw_arc(pos + Vector2(0, -2), 9.5, 0.0, TAU, 24,
				Color(1.0, 0.92, 0.35), 1.6)
		elif hovered:
			draw_arc(pos + Vector2(0, -2), 10.5, 0.0, TAU, 24,
				Color(1.0, 1.0, 1.0, 0.8), 1.2)
		if (zoom >= 1.8 or selected or hovered) and act >= 0 \
				and act < ACT_COLORS.size():
			var col: Color = ACT_COLORS[act]
			var mpos: Vector2 = pos + Vector2(7, -15)
			draw_circle(mpos, 4.6, Color(0.05, 0.05, 0.06, 0.82))
			draw_arc(mpos, 4.6, 0.0, TAU, 12, col, 1.0)
			draw_string(_font, mpos + Vector2(-2.6, 2.6),
				str(ACT_GLYPHS[act]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7,
				col.lightened(0.35))
		if selected or hovered or zoom >= 1.9:
			labels.append({"pos": pos, "id": id, "selected": selected,
				"hovered": hovered})
	labels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["selected"]) != bool(b["selected"]):
			return not bool(a["selected"])
		if bool(a["hovered"]) != bool(b["hovered"]):
			return not bool(a["hovered"])
		return float(a["pos"].y) < float(b["pos"].y))
	for entry in labels:
		var pos2: Vector2 = entry["pos"]
		var id2: int = int(entry["id"])
		var selected2: bool = bool(entry["selected"])
		var rec: AgentRecord = AgentRecords.record_by_id(sim.records, id2)
		var label: String = rec.name if rec != null else "A%d" % id2
		if selected2:
			label += " (%d)" % id2
		var fs: int = 9
		var size: Vector2 = _font.get_string_size(label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var lp: Vector2 = pos2 + Vector2(-size.x * 0.5, -18)
		draw_rect(Rect2(lp - Vector2(2, fs - 1), size + Vector2(4, 3)),
			Color(0.05, 0.04, 0.03, 0.62))
		draw_string(_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 0.96, 0.82) if selected2
				else Color(1, 1, 1, 0.92))


func _draw_vector_agent(row: int, pos: Vector2, scale: float) -> void:
	var color: Color = AGENT_COLORS[row % AGENT_COLORS.size()]
	draw_rect(Rect2(pos + Vector2(-3.4, -7) * scale,
		Vector2(6.8, 10) * scale), color.darkened(0.18))
	draw_circle(pos + Vector2(0, -9.2) * scale, 3.6 * scale,
		color.lightened(0.12))
	draw_arc(pos + Vector2(0, -9.2) * scale, 3.6 * scale, 0.0, TAU, 12,
		Color(0.18, 0.13, 0.09), 0.9)


func _draw_debug(visible_tiles: Rect2) -> void:
	var z: float = maxf(0.05, view_state.zoom)
	var gcol: Color = Color(1, 1, 1, 0.10)
	var x0: int = int(floor(visible_tiles.position.x))
	var y0: int = int(floor(visible_tiles.position.y))
	var x1: int = int(ceil(visible_tiles.end.x))
	var y1: int = int(ceil(visible_tiles.end.y))
	if z >= 1.0:
		for x in range(x0, x1 + 1):
			draw_line(Vector2(x * TILE_PX, y0 * TILE_PX),
				Vector2(x * TILE_PX, y1 * TILE_PX), gcol, 1.0 / z)
		for y in range(y0, y1 + 1):
			draw_line(Vector2(x0 * TILE_PX, y * TILE_PX),
				Vector2(x1 * TILE_PX, y * TILE_PX), gcol, 1.0 / z)
	# Massstab: 10 Tiles = 15 m, bildschirmkonstant.
	var vp: Vector2 = get_viewport_rect().size
	var half: Vector2 = vp * 0.5 / z
	var origin: Vector2 = view_state.camera_position * TILE_PX - half \
		+ Vector2(20.0, vp.y - 34.0)
	var bar: float = 10.0 * TILE_PX
	draw_line(origin, origin + Vector2(bar, 0), Color(1, 1, 1, 0.9), 2.0 / z)
	draw_line(origin + Vector2(0, -4), origin + Vector2(0, 4),
		Color(1, 1, 1, 0.9), 1.0 / z)
	draw_line(origin + Vector2(bar, -4), origin + Vector2(bar, 4),
		Color(1, 1, 1, 0.9), 1.0 / z)
	var fs: int = int(11.0 / z)
	if fs >= 5 and fs <= 64:
		draw_string(_font, origin + Vector2(0, -8.0 / z),
			"10 Tiles = 15 m", HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.9))


func _tile_rect(rect: Rect2i) -> Rect2:
	return Rect2(rect.position.x * TILE_PX, rect.position.y * TILE_PX,
		rect.size.x * TILE_PX, rect.size.y * TILE_PX)


func _terrain_tile_texture(pack_cell: Vector2i, base_cell: Vector2i) -> Texture2D:
	if terrain_mode == 0:
		return _pack_tile_tex(pack_cell)
	return _base_tile_tex(base_cell)


func _pack_tile_tex(cell: Vector2i) -> Texture2D:
	var key: String = "p%d_%d" % [cell.x, cell.y]
	if _pack_tile_cache.has(key):
		return _pack_tile_cache[key]
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = _rp_tex
	atlas.region = Rect2(cell.x * RP_PITCH, cell.y * RP_PITCH, 16, 16)
	_pack_tile_cache[key] = atlas
	return atlas


func _base_tile_tex(cell: Vector2i) -> Texture2D:
	var key: String = "b%d_%d" % [cell.x, cell.y]
	if _base_tile_cache.has(key):
		return _base_tile_cache[key]
	var img: Image = _base_img.get_region(
		Rect2i(cell.x * BASE_PITCH, cell.y * BASE_PITCH, 64, 64)).duplicate()
	img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_base_tile_cache[key] = tex
	return tex


func _base16(cell: Vector2i) -> Image:
	var key: String = "b16_%d_%d" % [cell.x, cell.y]
	if _base16_cache.has(key):
		return _base16_cache[key]
	var img: Image = _base_img.get_region(
		Rect2i(cell.x * BASE_PITCH, cell.y * BASE_PITCH, 64, 64)).duplicate()
	img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	_base16_cache[key] = img
	return img


func _rebuild_terrain_textures() -> void:
	_ensure_assets()
	_grass_tex = _make_grass_texture()
	_road_tex = _make_road_texture()
	_field_tex = _make_field_textures()


func _make_grass_texture() -> Texture2D:
	var n: int = 32
	var img: Image = Image.create(n * TILE_PX, n * TILE_PX, false,
		Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var h: int = (x * 73856093) ^ (y * 19349663)
			var cell: Vector2i
			if terrain_mode == 0:
				cell = RP_GRASS[posmod(h, RP_GRASS.size())]
				if h % 97 == 0:
					cell = RP_FLOWERS[posmod(h, RP_FLOWERS.size())]
				_blit_pack(img, cell, x * TILE_PX, y * TILE_PX)
			else:
				var bcell: Vector2i = BASE_GRASS
				_blit_base(img, bcell, x * TILE_PX, y * TILE_PX, 16, 16)
				if h % 211 == 0:
					var fcell: Vector2i = RP_FLOWERS[posmod(h, RP_FLOWERS.size())]
					var f: Image = _pack_region(fcell)
					img.blend_rect(f, Rect2i(0, 0, 16, 16),
						Vector2i(x * TILE_PX, y * TILE_PX))
	return ImageTexture.create_from_image(img)


func _make_road_texture() -> Texture2D:
	var img: Image = Image.create(3 * TILE_PX, 3 * TILE_PX, false,
		Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 3:
		for x in 3:
			if terrain_mode == 0:
				var cell: Vector2i = RP_DIRT
				if (x + y) % 2 == 0:
					cell = Vector2i(6, 0)
				_blit_pack(img, cell, x * TILE_PX, y * TILE_PX)
			else:
				_blit_base(img, BASE_DIRT, x * TILE_PX, y * TILE_PX,
					16, 16)
	return ImageTexture.create_from_image(img)


func _make_field_textures() -> Array:
	var out: Array = []
	for stage in Building.FIELD_STAGE_COUNT:
		var img: Image = Image.create(2 * TILE_PX, 2 * TILE_PX, false,
			Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in 2:
			for x in 2:
				if terrain_mode == 0:
					_blit_pack(img, RP_DIRT, x * TILE_PX, y * TILE_PX)
				else:
					_blit_base(img, BASE_DIRT, x * TILE_PX, y * TILE_PX,
						16, 16)
		_paint_field(img, stage)
		out.append(ImageTexture.create_from_image(img))
	return out


func _paint_field(img: Image, stage: int) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var dark: Color = Color(0.22, 0.15, 0.09, 1)
	var light: Color = Color(0.55, 0.42, 0.26, 1)
	match stage:
		Building.FIELD_FALLOW:
			for y in range(4, h, 8):
				_fill(img, 2, y, w - 4, 1, dark)
		Building.FIELD_PLOWING:
			for y in range(3, h, 8):
				_fill(img, 2, y, w - 4, 2, Color(0.28, 0.19, 0.11, 1))
				_fill(img, 3, y + 2, w - 6, 1, light)
		Building.FIELD_PLOWED:
			for y in range(3, h, 8):
				_fill(img, 2, y, w - 4, 3, Color(0.40, 0.28, 0.17, 1))
				_fill(img, 4, y + 1, w - 8, 1, Color(0.56, 0.42, 0.26, 1))
		Building.FIELD_SOWING:
			for y in range(4, h, 6):
				for x in range(3, w, 5):
					_set_px(img, x, y, Color(0.82, 0.72, 0.45, 1))
					_set_px(img, x + 1, y, Color(0.70, 0.60, 0.34, 1))
		Building.FIELD_SOWN:
			for y in range(4, h, 6):
				for x in range(3, w, 5):
					_set_px(img, x, y, Color(0.35, 0.55, 0.25, 1))
		Building.FIELD_GROWING:
			for y in range(6, h, 8):
				_fill(img, 2, y + 2, w - 4, 2, Color(0.30, 0.22, 0.13, 1))
				for x in range(4, w, 6):
					_fill(img, x, y - 1, 2, 4, Color(0.30, 0.62, 0.25, 1))
					_set_px(img, x, y - 2, Color(0.46, 0.78, 0.34, 1))
					_set_px(img, x + 1, y - 2, Color(0.38, 0.70, 0.30, 1))
		Building.FIELD_RIPE:
			for y in range(6, h, 8):
				_fill(img, 2, y + 2, w - 4, 2, Color(0.34, 0.24, 0.12, 1))
				for x in range(4, w, 6):
					_fill(img, x, y - 3, 1, 5, Color(0.95, 0.80, 0.30, 1))
					_set_px(img, x + 1, y - 2, Color(0.82, 0.64, 0.20, 1))
					_set_px(img, x, y - 4, Color(0.99, 0.90, 0.48, 1))
		Building.FIELD_HARVESTING:
			for y in range(5, h, 7):
				_fill(img, 2, y, w - 4, 2, Color(0.66, 0.52, 0.20, 1))
				for x in range(3, w, 4):
					_fill(img, x, y - 2, 1, 2, Color(0.86, 0.72, 0.28, 1))
					_set_px(img, x, y - 3, Color(0.95, 0.82, 0.40, 1))


func _set_px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var r: Rect2i = Rect2i(x, y, w, h).intersection(
		Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	img.fill_rect(r, color)


func _blit_pack(dst: Image, cell: Vector2i, dx: int, dy: int) -> void:
	dst.blit_rect(_rp_img, Rect2i(cell.x * RP_PITCH, cell.y * RP_PITCH,
		16, 16), Vector2i(dx, dy))


func _blit_base(dst: Image, cell: Vector2i, dx: int, dy: int,
		w: int, h: int) -> void:
	if w == 16 and h == 16:
		dst.blit_rect(_base16(cell), Rect2i(0, 0, 16, 16),
			Vector2i(dx, dy))
		return
	var img: Image = _base_img.get_region(
		Rect2i(cell.x * BASE_PITCH, cell.y * BASE_PITCH, 64, 64)).duplicate()
	if w != 64 or h != 64:
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
	dst.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(dx, dy))


func _pack_region(cell: Vector2i) -> Image:
	return _rp_img.get_region(Rect2i(cell.x * RP_PITCH, cell.y * RP_PITCH,
		16, 16)).duplicate()


func _rebuild_building_textures() -> void:
	_ensure_assets()
	_building_tex.clear()
	_building_style.clear()
	for building in sim.world.buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		var tex: Texture2D
		match b.kind:
			Building.KIND_HOUSE:
				var v: int = b.id % 3
				tex = _compose_building(b.rect.size.x, b.rect.size.y,
					[Vector2i(1, 7), Vector2i(6, 7), Vector2i(10, 7)][v],
					[Vector2i(3, 3), Vector2i(4, 3), Vector2i(13, 3)][v],
					BASE_DOOR, BASE_WINDOW, false, 0)
			Building.KIND_WORKSHOP:
				tex = _compose_building(b.rect.size.x, b.rect.size.y,
					BASE_ROOF_DARK, BASE_WALL_BRICK, BASE_BIG_DOOR,
					BASE_WINDOW, true, 2)
			Building.KIND_GRANARY:
				tex = _compose_building(b.rect.size.x, b.rect.size.y,
					BASE_ROOF_BROWN, BASE_WALL_CREAM, BASE_BIG_DOOR,
					BASE_WINDOW, false, 2)
			Building.KIND_BARN:
				tex = _compose_building(b.rect.size.x, b.rect.size.y,
					BASE_ROOF_BROWN, BASE_WALL_BRICK, BASE_BIG_DOOR,
					Vector2i(-1, -1), false, 1)
			_:
				tex = _compose_building(b.rect.size.x, b.rect.size.y,
					BASE_ROOF_GRAY, BASE_WALL_STONE, BASE_DOOR,
					BASE_WINDOW, false, 0)
		_building_tex[b.id] = tex
	if sim.world.building_by_id(sim.world._well_id) != null:
		var well: Building = sim.world.building_by_id(sim.world._well_id)
		_building_tex[well.id] = _compose_well(well.rect.size.x,
			well.rect.size.y)


func _compose_building(w_tiles: int, h_tiles: int, roof: Vector2i,
		wall: Vector2i, door: Vector2i, window: Vector2i,
		chimney: bool, sacks: int) -> Texture2D:
	var img: Image = Image.create(w_tiles * TILE_PX, h_tiles * TILE_PX,
		false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var roof_rows: int = maxi(2, h_tiles - 3)
	for y in h_tiles:
		for x in w_tiles:
			var cell: Vector2i = roof if y < roof_rows else wall
			_blit_base(img, cell, x * TILE_PX, y * TILE_PX, 16, 16)
	# Traufe/Ridge: opake dunkle bzw. helle Linien, damit kein Gras durchblutet.
	var eave_y: int = roof_rows * TILE_PX
	img.fill_rect(Rect2i(0, eave_y - 3, w_tiles * TILE_PX, 3),
		Color(0.24, 0.16, 0.10, 1))
	img.fill_rect(Rect2i(0, 2, w_tiles * TILE_PX, 2),
		Color(0.93, 0.83, 0.66, 1))
	img.fill_rect(Rect2i(0, 0, 2, roof_rows * TILE_PX),
		Color(0.30, 0.21, 0.14, 1))
	img.fill_rect(Rect2i(w_tiles * TILE_PX - 2, 0, 2,
		roof_rows * TILE_PX), Color(0.30, 0.21, 0.14, 1))
	# Firstziegel/Querlinien, dezent.
	for yy in range(10, roof_rows * TILE_PX - 6, 18):
		img.fill_rect(Rect2i(2, yy, w_tiles * TILE_PX - 4, 1),
			Color(0.78, 0.66, 0.52, 0.55))
	# Tur + Fenster.
	if door.x >= 0:
		var dw: int = 32 if w_tiles >= 6 else 16
		var dh: int = 32 if h_tiles >= 6 else 16
		var dx: int = (w_tiles * TILE_PX - dw) / 2
		var dy: int = h_tiles * TILE_PX - dh
		_blit_base(img, door, dx, dy, dw, dh)
	if window.x >= 0:
		var wy: int = eave_y + 4
		var wx1: int = TILE_PX + 2
		var wx2: int = w_tiles * TILE_PX - TILE_PX * 2
		_blit_base(img, window, wx1, wy, 16, 16)
		_blit_base(img, window, wx2, wy, 16, 16)
	if chimney:
		_blit_base(img, BASE_CHIMNEY, w_tiles * TILE_PX - TILE_PX * 3,
			0, 16, TILE_PX * 2)
		img.fill_rect(Rect2i(w_tiles * TILE_PX - TILE_PX * 3, 0,
			TILE_PX, 3), Color(0.16, 0.14, 0.12, 1))
	for i in sacks:
		var sx: int = 4 + i * 14
		_blit_base(img, BASE_SACK, sx, h_tiles * TILE_PX - 16, 16, 16)
	return ImageTexture.create_from_image(img)


func _compose_well(w_tiles: int, h_tiles: int) -> Texture2D:
	var size_px: int = mini(w_tiles, h_tiles) * TILE_PX
	var img: Image = Image.create(size_px, size_px, false,
		Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(size_px * 0.5, size_px * 0.5)
	var outer: float = size_px * 0.46
	var inner: float = size_px * 0.30
	var stone: Image = _base_img.get_region(
		Rect2i(13 * BASE_PITCH, 4 * BASE_PITCH, 64, 64)).duplicate()
	stone.resize(size_px, size_px, Image.INTERPOLATE_NEAREST)
	var water: Image = _base_img.get_region(
		Rect2i(11 * BASE_PITCH, 1 * BASE_PITCH, 64, 64)).duplicate()
	water.resize(size_px, size_px, Image.INTERPOLATE_NEAREST)
	for y in size_px:
		for x in size_px:
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= inner:
				_set_px(img, x, y, water.get_pixel(x, y))
			elif d <= outer:
				_set_px(img, x, y, stone.get_pixel(x, y))
			elif d <= outer + 1.0:
				_set_px(img, x, y, Color(0.18, 0.16, 0.12, 1))
	# Zwei Holzbalken als Brunnenrahmen.
	img.fill_rect(Rect2i(int(center.x) - 1, 2, 2, size_px - 4),
		Color(0.40, 0.27, 0.15, 1))
	img.fill_rect(Rect2i(2, int(center.y) - 1, size_px - 4, 2),
		Color(0.40, 0.27, 0.15, 1))
	return ImageTexture.create_from_image(img)
