class_name WorldView
extends Node2D

## Programmer-Art-Ansicht des Weilers. Liest ausschließlich Simulation und
## ViewState. Kein Schreibzugriff auf Sim-Daten.

const TILE_PX: int = SimConfig.PIXELS_PER_TILE

var sim: Simulation
var view_state: ViewState
var _terrain_texture: ImageTexture
var _terrain_seed: int = -1
var _font: Font

const AGENT_COLORS: Array = [
	Color(0.95, 0.78, 0.45), Color(0.86, 0.55, 0.42), Color(0.55, 0.78, 0.92),
	Color(0.95, 0.62, 0.78), Color(0.65, 0.85, 0.55), Color(0.92, 0.85, 0.50),
	Color(0.65, 0.62, 0.92), Color(0.80, 0.72, 0.60), Color(0.55, 0.72, 0.50),
	Color(0.95, 0.55, 0.48),
]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = ThemeDB.fallback_font


func configure(p_sim: Simulation, p_view_state: ViewState) -> void:
	sim = p_sim
	view_state = p_view_state
	if sim != null and _terrain_seed != sim.config.seed:
		_build_terrain()
	queue_redraw()


func _build_terrain() -> void:
	var size: int = WorldMap.SIZE
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var field: Building = sim.world.building_by_id(WorldMap.B_FIELD)
	for y in size:
		for x in size:
			var c: Color
			if sim.world.is_road_tile(x, y):
				c = Color(0.55, 0.46, 0.33)
				if (x + y) % 7 == 0:
					c = c.darkened(0.06)
			elif field != null and field.has_tile(x, y):
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


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture,
			Rect2(0, 0, WorldMap.SIZE * TILE_PX, WorldMap.SIZE * TILE_PX), false)
	_draw_field_details()
	_draw_buildings()
	_draw_trees()
	if view_state == null or view_state.agents_visible:
		_draw_agents()


func _tile_rect(rect: Rect2i) -> Rect2:
	return Rect2(rect.position.x * TILE_PX, rect.position.y * TILE_PX,
		rect.size.x * TILE_PX, rect.size.y * TILE_PX)


func _draw_field_details() -> void:
	var field: Building = sim.world.building_by_id(WorldMap.B_FIELD)
	if field == null:
		return
	var r: Rect2 = _tile_rect(field.rect)
	draw_rect(r, Color(0.30, 0.36, 0.14), false, 2.0)
	for i in range(1, field.rect.size.y, 3):
		var y: float = r.position.y + i * TILE_PX
		draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y),
			Color(0.42, 0.46, 0.20), 1.0)
	# Ein paar sichtbare Reihen.
	for i in range(2, field.rect.size.x, 4):
		var x: float = r.position.x + i * TILE_PX
		draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 4),
			Color(0.46, 0.50, 0.22, 0.7), 1.0)


func _draw_buildings() -> void:
	for building in sim.world.buildings:
		var b: Building = building
		var r: Rect2 = _tile_rect(b.rect)
		match b.kind:
			Building.KIND_FIELD:
				continue
			Building.KIND_HOUSE:
				draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25))
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
			Building.KIND_WORKSHOP:
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
	for p in sim.world.decor_trees:
		var px: Vector2 = p * TILE_PX
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


func _draw_agents() -> void:
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var pos: Vector2 = sim.current_position(row) * TILE_PX
		var color: Color = AGENT_COLORS[row % AGENT_COLORS.size()]
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
		if marker != "":
			draw_string(_font, pos + Vector2(7, -5), marker,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.78))
		var rec: AgentRecord = AgentRecords.record_by_id(sim.records, sim.store.ids[row])
		var selected: bool = view_state != null \
			and view_state.selected_agent_id == sim.store.ids[row]
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
