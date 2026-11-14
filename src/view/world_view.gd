class_name WorldView
extends Node2D

## Programmer-Art-Ansicht des Weilers. Liest ausschließlich Simulation und
## ViewState. Kein Schreibzugriff auf Sim-Daten.

const TILE_PX: int = SimConfig.PIXELS_PER_TILE

var sim: Simulation
var view_state: ViewState
var _terrain_texture: ImageTexture
var _terrain_seed: int = -1
var _terrain_world_size: int = -1
var _font: Font
var _agent_markers: MultiMeshInstance2D
var _agent_multimesh: MultiMesh
var _marker_frame: int = 0
var _marker_colors_primed: int = 0
var _marker_state: PackedByteArray = PackedByteArray()

const AGENT_COLORS: Array = [
	Color(0.95, 0.78, 0.45), Color(0.86, 0.55, 0.42), Color(0.55, 0.78, 0.92),
	Color(0.95, 0.62, 0.78), Color(0.65, 0.85, 0.55), Color(0.92, 0.85, 0.50),
	Color(0.65, 0.62, 0.92), Color(0.80, 0.72, 0.60), Color(0.55, 0.72, 0.50),
	Color(0.95, 0.55, 0.48),
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font
	_build_agent_markers()


func configure(p_sim: Simulation, p_view_state: ViewState) -> void:
	sim = p_sim
	view_state = p_view_state
	if sim != null and (_terrain_seed != sim.config.seed
			or _terrain_world_size != sim.world.size):
		_build_terrain()
	if sim != null and sim.config.is_scale():
		_ensure_marker_capacity(sim.store.count)
	queue_redraw()


## Ein Draw-Call für die 10k-Marker. Die Aktualisierung ist reine Darstellung
## und wird auf jedem zweiten Frame ausgeführt; die Simulation bleibt
## kameraunabhängig und unverändert.
func _build_agent_markers() -> void:
	_agent_multimesh = MultiMesh.new()
	_agent_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_agent_multimesh.use_colors = true
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(6, 6)
	_agent_multimesh.mesh = quad
	_agent_markers = MultiMeshInstance2D.new()
	_agent_markers.multimesh = _agent_multimesh
	_agent_markers.visible = false
	add_child(_agent_markers)


func _ensure_marker_capacity(count: int) -> void:
	if _agent_multimesh == null:
		return
	if _agent_multimesh.instance_count < count:
		_agent_multimesh.instance_count = count
		_agent_multimesh.visible_instance_count = 0
	if _marker_colors_primed < count:
		for row in range(_marker_colors_primed, count):
			_agent_multimesh.set_instance_color(row,
				AGENT_COLORS[row % AGENT_COLORS.size()])
			_agent_multimesh.set_instance_transform_2d(row,
				Transform2D(0.0, Vector2(-10000, -10000)))
		_marker_colors_primed = count
	if _marker_state.size() < count:
		var old: int = _marker_state.size()
		_marker_state.resize(count)
		for i in range(old, count):
			_marker_state[i] = 0


func _build_terrain_scale() -> void:
	var size: int = sim.world.size
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.42, 0.55, 0.32))
	for rect in sim.world._road_rects:
		var r: Rect2i = rect
		_fill_clipped(img, r, Color(0.55, 0.46, 0.33))
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field != null:
			_fill_clipped(img, field.rect, Color(0.58, 0.62, 0.30))
	for building in sim.world.buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			continue
		_fill_clipped(img, b.rect, Color(0.30, 0.26, 0.22))
	_terrain_texture = ImageTexture.create_from_image(img)
	_terrain_seed = sim.config.seed
	_terrain_world_size = size


func _fill_clipped(img: Image, rect: Rect2i, color: Color) -> void:
	var x0: int = clampi(rect.position.x, 0, img.get_width())
	var y0: int = clampi(rect.position.y, 0, img.get_height())
	var x1: int = clampi(rect.position.x + rect.size.x, 0, img.get_width())
	var y1: int = clampi(rect.position.y + rect.size.y, 0, img.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)


func _build_terrain() -> void:
	if sim.config.is_scale():
		_build_terrain_scale()
		return
	var size: int = sim.world.size
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var field_tiles: PackedByteArray = PackedByteArray()
	field_tiles.resize(size * size)
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field == null:
			continue
		for y in range(field.rect.position.y, field.rect.position.y + field.rect.size.y):
			for x in range(field.rect.position.x, field.rect.position.x + field.rect.size.x):
				if x >= 0 and x < size and y >= 0 and y < size:
					field_tiles[y * size + x] = 1
	for y in size:
		for x in size:
			var c: Color
			if sim.world.is_road_tile(x, y):
				c = Color(0.55, 0.46, 0.33)
				if (x + y) % 7 == 0:
					c = c.darkened(0.06)
			elif field_tiles[y * size + x] != 0:
				c = Color(0.58, 0.62, 0.30)
				if y % 3 == 0:
					c = c.darkened(0.10)
			else:
				var noise: int = absi((x * 73856093) ^ (y * 19349663) ^ (sim.config.seed * 83492791))
				var shade: float = float(noise % 7) / 130.0
				c = Color(0.42 + shade, 0.55 + shade, 0.32 + shade * 0.6)
			if sim.world.is_blocked_tile(x, y):
				c = Color(0.30, 0.26, 0.22)
			img.set_pixel(x, y, c)
	_terrain_texture = ImageTexture.create_from_image(img)
	_terrain_seed = sim.config.seed
	_terrain_world_size = size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture,
			Rect2(0, 0, sim.world.size * TILE_PX, sim.world.size * TILE_PX), false)
	# 10k-Fern-LOD: Die Terrain-Textur enthält Straßen/Felder/Häuser bereits.
	# Bei weitem Zoom sparen wir die tausenden Per-Gebäude-Draw-Kommandos.
	if sim.config.is_scale() and view_state != null and view_state.zoom < 0.62:
		if view_state.agents_visible:
			_draw_agents()
		return
	_draw_field_details()
	_draw_buildings()
	_draw_trees()
	if view_state == null or view_state.agents_visible:
		_draw_agents()


func _tile_rect(rect: Rect2i) -> Rect2:
	return Rect2(rect.position.x * TILE_PX, rect.position.y * TILE_PX,
		rect.size.x * TILE_PX, rect.size.y * TILE_PX)


func _far_detail() -> bool:
	return sim != null and (sim.config.is_g3() or sim.config.is_scale()) \
		and view_state != null and view_state.zoom < 0.85


func _draw_field_details() -> void:
	var visible: Rect2 = _visible_tiles()
	var far_detail: bool = _far_detail()
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field == null or not visible.intersects(field.rect):
			continue
		var r: Rect2 = _tile_rect(field.rect)
		draw_rect(r, Color(0.30, 0.36, 0.14), false, 2.0)
		if far_detail:
			continue
		for i in range(1, field.rect.size.y, 3):
			var y: float = r.position.y + i * TILE_PX
			draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y),
				Color(0.42, 0.46, 0.20), 1.0)
		# Ein paar sichtbare Reihen.
		for i in range(2, field.rect.size.x, 4):
			var x: float = r.position.x + i * TILE_PX
			draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4),
				Color(0.46, 0.50, 0.22, 0.7), 1.0)


func _visible_tiles() -> Rect2:
	if view_state == null:
		return Rect2(0, 0, sim.world.size, sim.world.size)
	var viewport: Vector2 = get_viewport_rect().size
	var z: float = maxf(0.15, view_state.zoom)
	var half: Vector2 = viewport * 0.5 / (z * float(TILE_PX))
	return Rect2(view_state.camera_position - half - Vector2(4, 4),
		half * 2.0 + Vector2(8, 8))


func _draw_buildings() -> void:
	var visible: Rect2 = _visible_tiles()
	var far_detail: bool = _far_detail()
	for building in sim.world.buildings:
		var b: Building = building
		if not visible.intersects(b.rect):
			continue
		var r: Rect2 = _tile_rect(b.rect)
		match b.kind:
			Building.KIND_FIELD:
				continue
			Building.KIND_HOUSE:
				draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25))
				if far_detail:
					draw_rect(r, Color(0.62, 0.48, 0.34))
					draw_rect(r, Color(0.28, 0.20, 0.14), false, 2.0)
					continue
				draw_rect(r, Color(0.62, 0.48, 0.34))
				draw_rect(r, Color(0.28, 0.20, 0.14), false, 2.0)
				var roof_h: float = r.size.y * 0.42
				var roof: PackedVector2Array = PackedVector2Array([
					r.position + Vector2(-3, roof_h),
					r.position + Vector2(r.size.x * 0.5, -4),
					r.position + Vector2(r.size.x + 3, roof_h),
					r.position + Vector2(r.size.x + 3, roof_h + 8),
					r.position + Vector2(-3, roof_h + 8),
				])
				draw_colored_polygon(roof, Color(0.62, 0.25, 0.20))
				draw_rect(Rect2(r.position + Vector2(r.size.x * 0.4, r.size.y - 14),
					Vector2(12, 14)), Color(0.35, 0.22, 0.14))
				draw_rect(Rect2(r.position + Vector2(8, r.size.y * 0.55),
					Vector2(7, 7)), Color(0.92, 0.82, 0.55))
				draw_rect(Rect2(r.position + Vector2(r.size.x - 15, r.size.y * 0.55),
					Vector2(7, 7)), Color(0.92, 0.82, 0.55))
			Building.KIND_GRANARY:
				draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25))
				draw_rect(r, Color(0.70, 0.60, 0.40))
				draw_rect(r, Color(0.30, 0.24, 0.16), false, 2.0)
				draw_circle(r.position + Vector2(r.size.x * 0.35, r.size.y * 0.45),
					r.size.x * 0.22, Color(0.78, 0.66, 0.42))
				draw_circle(r.position + Vector2(r.size.x * 0.35, r.size.y * 0.45),
					r.size.x * 0.22, Color(0.36, 0.28, 0.18), false, 2.0)
			Building.KIND_WELL:
				draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.25))
				draw_circle(r.get_center(), r.size.x * 0.45, Color(0.55, 0.55, 0.58))
				draw_circle(r.get_center(), r.size.x * 0.32, Color(0.16, 0.30, 0.45))
				draw_circle(r.get_center(), r.size.x * 0.45, Color(0.32, 0.30, 0.28), false, 2.0)
			Building.KIND_WORKSHOP, Building.KIND_BARN:
				draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25))
				draw_rect(r, Color(0.50, 0.40, 0.30))
				draw_rect(r, Color(0.22, 0.17, 0.12), false, 2.0)
				var roof2: PackedVector2Array = PackedVector2Array([
					r.position + Vector2(-2, r.size.y * 0.35),
					r.position + Vector2(r.size.x * 0.5, -2),
					r.position + Vector2(r.size.x + 2, r.size.y * 0.35),
				])
				draw_colored_polygon(roof2, Color(0.38, 0.28, 0.20))
				draw_rect(Rect2(r.position + Vector2(r.size.x * 0.42, r.size.y - 16),
					Vector2(16, 16)), Color(0.24, 0.16, 0.10))
		draw_rect(Rect2(r.position + Vector2(-2, -2), r.size + Vector2(4, 4)),
			Color(0.18, 0.14, 0.10, 0.7), false, 1.0)


func _draw_trees() -> void:
	var visible: Rect2 = _visible_tiles()
	var far_detail: bool = _far_detail()
	for p in sim.world.decor_trees:
		if not visible.has_point(p):
			continue
		var px: Vector2 = p * TILE_PX
		if far_detail:
			draw_circle(px + Vector2(0, -5), 6.0, Color(0.24, 0.43, 0.21))
			continue
		draw_rect(Rect2(px + Vector2(-2, -2), Vector2(4, 8)), Color(0.35, 0.24, 0.14))
		draw_circle(px + Vector2(0, -6), 8.0, Color(0.22, 0.42, 0.20))
		draw_circle(px + Vector2(3, -9), 4.5, Color(0.26, 0.48, 0.24))


## Kurzes, lesbares Feldlabel: zwei Namensbuchstaben plus stabile ID
## ("Ar1", "Cl3"). Selektierte Agenten zeigen den vollen Namen. Nie auf einen
## einzelnen Aktivitätsbuchstaben wie "A" verkürzt.
static func field_label(rec: AgentRecord, agent_id: int, selected: bool = false) -> String:
	if rec == null:
		return "A%d" % agent_id
	if selected:
		return "%s %d" % [rec.name, agent_id]
	return "%s%d" % [rec.name.substr(0, 2), agent_id]


func _update_agent_markers(visible: Rect2) -> void:
	if _agent_multimesh == null:
		return
	_marker_frame += 1
	var groups: int = 3 if sim.config.is_scale() else 2
	var group: int = _marker_frame % groups
	_ensure_marker_capacity(sim.store.count)
	_agent_multimesh.visible_instance_count = sim.store.count
	for row in range(group, sim.store.count, groups):
		if sim.store.alive[row] == 0:
			_hide_marker(row)
			continue
		var settled: Vector2 = Vector2(sim.store.pos_x[row], sim.store.pos_y[row])
		var candidate: Vector2 = settled
		var rid: int = sim.store.route_id[row]
		if rid >= 0:
			var a: Vector2 = Vector2(sim.store.travel_start_x[row],
				sim.store.travel_start_y[row])
			var b: Vector2 = Vector2(sim.store.travel_end_x[row],
				sim.store.travel_end_y[row])
			if not _segment_bbox_touches(visible, a, b):
				_hide_marker(row)
				continue
			candidate = sim.current_position(row)
		if not visible.has_point(candidate):
			_hide_marker(row)
			continue
		var pos: Vector2 = candidate * TILE_PX
		_agent_multimesh.set_instance_transform_2d(row,
			Transform2D(0.0, pos + Vector2(0, -4)))
		_marker_state[row] = 1


func _hide_marker(row: int) -> void:
	if row < _marker_state.size() and _marker_state[row] == 0:
		return
	_agent_multimesh.set_instance_transform_2d(row,
		Transform2D(0.0, Vector2(-10000, -10000)))
	if row < _marker_state.size():
		_marker_state[row] = 0


func _segment_bbox_touches(rect: Rect2, a: Vector2, b: Vector2) -> bool:
	var r: Rect2 = Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(b.x - a.x), absf(b.y - a.y)))
	return rect.intersects(r)


func _draw_agents() -> void:
	var visible: Rect2 = _visible_tiles()
	# Render-LOD ist rein darstellend und nie Simulationszustand. Bei 1k und
	# weitem Zoom zeichnen wir Marker; Labels nur nah/selektiert/gefolgt.
	var g3: bool = sim.config.is_g3()
	var zoom: float = view_state.zoom if view_state != null else 1.0
	var far_markers: bool = (g3 or sim.config.is_scale()) and zoom < 1.05
	if sim.config.is_scale() and far_markers:
		_update_agent_markers(visible)
		if _agent_markers != null:
			_agent_markers.visible = true
		return
	if _agent_markers != null:
		_agent_markers.visible = false
	var show_labels: bool = (not g3) or zoom >= 1.25
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var tile_pos: Vector2 = Vector2(sim.store.pos_x[row], sim.store.pos_y[row])
		var rid: int = sim.store.route_id[row]
		if rid >= 0:
			var a: Vector2 = Vector2(sim.store.travel_start_x[row],
				sim.store.travel_start_y[row])
			var b: Vector2 = Vector2(sim.store.travel_end_x[row],
				sim.store.travel_end_y[row])
			if not _segment_bbox_touches(visible, a, b):
				continue
			tile_pos = sim.current_position(row)
		if not visible.has_point(tile_pos):
			continue
		var pos: Vector2 = tile_pos * TILE_PX
		var color: Color = AGENT_COLORS[row % AGENT_COLORS.size()]
		var selected_row: bool = view_state != null \
			and view_state.selected_agent_id == sim.store.ids[row]
		var followed: bool = view_state != null and view_state.follow_enabled \
			and view_state.follow_agent_id == sim.store.ids[row]
		if far_markers and not selected_row and not followed:
			draw_circle(pos + Vector2(0, -4), 3.0, color)
			continue
		var act: int = sim.store.activity[row]
		# Schatten
		draw_set_transform(pos + Vector2(0, 5), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Körper und Kopf (ca. 19-20 px gesamt)
		draw_rect(Rect2(pos + Vector2(-4, -8), Vector2(8, 12)), color.darkened(0.18))
		draw_circle(pos + Vector2(0, -11), 4.2, color.lightened(0.12))
		draw_arc(pos + Vector2(0, -11), 4.2, 0.0, TAU, 12, Color(0.20, 0.14, 0.10), 1.0)
		# Aktivitätsmarker (kurz, aber nicht mit dem Agentenlabel verwechselbar).
		var marker: String = ""
		match act:
			AgentStore.ACT_SLEEP: marker = "z"
			AgentStore.ACT_WORK: marker = "Ar"
			AgentStore.ACT_EAT: marker = "Es"
			AgentStore.ACT_TRAVEL: marker = ">"
			AgentStore.ACT_SOCIAL: marker = "So"
			AgentStore.ACT_LEARN: marker = "Le"
			AgentStore.ACT_PLAY: marker = "Sp"
		if marker != "" and not (g3 and far_markers and not selected_row):
			draw_string(_font, pos + Vector2(7, -5), marker,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.78))
		var selected: bool = selected_row
		if show_labels or selected:
			var rec: AgentRecord = AgentRecords.record_by_id(sim.records,
				sim.store.ids[row])
			var label: String = field_label(rec, sim.store.ids[row], selected)
			var label_size: int = 11 if selected else 10
			var label_color: Color = Color(1.0, 0.95, 0.7) if selected else Color(1, 1, 1, 0.92)
			var label_width: float = _font.get_string_size(label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			# Nachbarn im selben Haus/Werkstatt-Cluster liegen teils nur 1,2-1,4
			# Tiles auseinander; gestaffelte Label-Höhen halten die kurzen Labels
			# lesbar (maximal drei Stufen pro Cluster).
			var label_y: float = -22.0 - float(row % 3) * 11.0
			var label_pos: Vector2 = pos + Vector2(-label_width * 0.5, label_y)
			draw_string(_font, label_pos + Vector2(1, 1), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(0.05, 0.04, 0.03, 0.65))
			draw_string(_font, label_pos, label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)
		if selected:
			draw_arc(pos, 15.0, 0.0, TAU, 24, Color(1.0, 0.92, 0.35), 2.0)
