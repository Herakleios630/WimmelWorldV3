extends Node2D

## G4c-P-Pretest-Demo: 100 Agenten, 24 Haushalte, 4 saisonale Felder.
## Reine sichtbare Demo; keine Wirtschaft/Politik/Chronik-Politur, kein 10k,
## keine G4c-Abnahme. Die Simulation laeuft unveraendert im Hintergrund.

const KenneyWorldViewScript = preload("res://tests/g4c_p/kenney_world_view.gd")
const PretestCameraScript = preload("res://tests/g4c_p/pretest_camera.gd")

const SPEEDS: Array = [1, 10, 60, 300, 1200, 3600]
const SEASON_TINT: Array = [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 0.94),
	Color(1.0, 0.95, 0.88), Color(0.92, 0.96, 1.0)]
const ROLE_NAMES: Array = ["Kind", "Jugendlich", "Erwachsen", "Alt"]

var sim: Simulation
var view_state: ViewState
var world_view: Node2D
var camera: Camera2D

var _sim_accumulator: float = 0.0
var _hud_root: Control
var _hud_layer: CanvasLayer
var _top_panel: Panel
var _inspector_panel: Panel
var _bottom_panel: Panel
var _title_label: Label
var _clock_label: Label
var _stats_label: Label
var _field_label: Label
var _hover_label: Label
var _inspector_title: Label
var _inspector_body: Label
var _inspector_needs: Label
var _status_label: Label
var _hud_timer: float = 0.0
var _status_text: String = ""
var _status_until: float = 0.0
var _hover_id: int = 0
var screenshot_mode: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.13, 0.10))
	sim = Simulation.create(SimConfig.g4c_pre())
	view_state = ViewState.new()
	view_state.speed = 10
	view_state.camera_position = Vector2(196.0, 165.0)
	view_state.zoom = 1.45
	world_view = KenneyWorldViewScript.new()
	add_child(world_view)
	world_view.configure(sim, view_state)
	camera = PretestCameraScript.new()
	add_child(camera)
	camera.configure(view_state, sim.world.size)
	camera.make_current()
	_build_hud()
	_update_day_night()
	_refresh_hud(true)
	_show_status("G4c-P-Pretest: Tag 1, Frühling, 100 Agenten.", 6.0)


func _process(delta: float) -> void:
	if not view_state.paused:
		var rate: float = float(SimConfig.TICKS_PER_DAY) \
			/ float(SimConfig.REAL_SECONDS_PER_DAY_AT_1X)
		_sim_accumulator += delta * rate * float(view_state.speed)
		var steps: int = int(floor(_sim_accumulator))
		if steps > 0:
			sim.advance_to(sim.clock.now + steps)
			_sim_accumulator -= float(steps)
	_update_day_night()
	if not screenshot_mode:
		_update_hover()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		_refresh_hud(false)
	if _status_text != "" and Time.get_ticks_msec() * 0.001 > _status_until:
		_status_text = ""
		_status_label.text = ""
	world_view.queue_redraw()


func _update_day_night() -> void:
	var hour: float = float(sim.clock.second_of_day()) / 3600.0
	var color: Color
	if hour < 5.0 or hour >= 21.5:
		color = Color(0.38, 0.44, 0.68)
	elif hour < 7.0:
		color = Color(0.38, 0.44, 0.68).lerp(Color(1.0, 0.86, 0.70),
			(hour - 5.0) / 2.0)
	elif hour < 17.5:
		color = Color(1.0, 0.98, 0.92)
	elif hour < 19.5:
		color = Color(1.0, 0.98, 0.92).lerp(Color(1.0, 0.72, 0.52),
			(hour - 17.5) / 2.0)
	else:
		color = Color(1.0, 0.72, 0.52).lerp(Color(0.38, 0.44, 0.68),
			(hour - 19.5) / 2.0)
	var season: int = sim.config.season_index_for_day(sim.day_index())
	var tint: Color = SEASON_TINT[season]
	world_view.modulate = Color(color.r * tint.r, color.g * tint.g,
		color.b * tint.b)
	var night: float = 0.0
	if hour < 5.0 or hour >= 22.0:
		night = 1.0
	elif hour < 7.0:
		night = 1.0 - (hour - 5.0) / 2.0
	elif hour >= 18.0:
		night = (hour - 18.0) / 4.0
	world_view.night_factor = night


func _update_hover() -> void:
	var world_px: Vector2 = get_global_mouse_position()
	var tile: Vector2 = world_px / 16.0
	var best_id: int = 0
	var best_d: float = 1.05
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var d: float = sim.current_position(row).distance_to(tile)
		if d < best_d:
			best_d = d
			best_id = sim.store.ids[row]
	_hover_id = best_id
	world_view.hover_agent_id = best_id


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_at(get_global_mouse_position() / 16.0)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_SPACE:
			view_state.paused = not view_state.paused
			_sim_accumulator = 0.0
			_show_status("Pausiert" if view_state.paused else "Weiter", 2.0)
		elif key >= KEY_1 and key <= KEY_6:
			view_state.speed = int(SPEEDS[key - KEY_1])
			view_state.paused = false
			_sim_accumulator = 0.0
			_show_status("Speed: %dx" % view_state.speed, 2.0)
		elif key == KEY_T:
			world_view.set_terrain_mode(1 - world_view.terrain_mode)
			_show_status("Terrain: " + world_view.terrain_label(), 2.5)
		elif key == KEY_C:
			world_view.set_character_mode(1 - world_view.character_mode)
			_show_status("Figuren: " + world_view.character_label(), 2.5)
		elif key == KEY_V:
			world_view.debug_scale_sort = not world_view.debug_scale_sort
			_show_status("Scale/Y-Sort-Debug: %s" % (
				"an" if world_view.debug_scale_sort else "aus"), 2.5)
		elif key == KEY_R:
			camera.focus_tile(Vector2(196.0, 165.0), 1.45)
			_show_status("Kamera: Dorfmitte", 2.0)
		elif key == KEY_F12:
			_capture_manual()


func _select_at(tile: Vector2) -> void:
	var best_row: int = -1
	var best_d: float = 1.05
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var d: float = sim.current_position(row).distance_to(tile)
		if d < best_d:
			best_d = d
			best_row = row
	if best_row < 0:
		view_state.selected_agent_id = 0
		_show_status("Auswahl aufgehoben", 1.5)
		return
	view_state.selected_agent_id = sim.store.ids[best_row]
	_show_status("Ausgewählt: %s" % _agent_name(best_row), 2.0)
	_refresh_hud(true)


func _agent_name(row: int) -> String:
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records,
		sim.store.ids[row])
	return rec.name if rec != null else "A%d" % sim.store.ids[row]


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud_layer = layer
	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud_root)

	_top_panel = _make_panel(Vector2(12, 12), Vector2(660, 190))
	_title_label = _make_label(_top_panel, Vector2(12, 8), 15,
		Color(1.0, 0.90, 0.55))
	_clock_label = _make_label(_top_panel, Vector2(12, 32), 14,
		Color(1, 1, 1))
	_stats_label = _make_label(_top_panel, Vector2(12, 54), 13,
		Color(0.88, 0.94, 1.0))
	_field_label = _make_label(_top_panel, Vector2(12, 96), 13,
		Color(0.80, 0.92, 0.72))
	_hover_label = _make_label(_top_panel, Vector2(12, 120), 12,
		Color(0.85, 0.85, 0.85))
	_status_label = _make_label(_top_panel, Vector2(12, 152), 12,
		Color(1.0, 0.78, 0.45))
	_title_label.text = "G4c-P · Kenney-Pretest · 100 Agenten · 24 Haushalte · 4 Felder"
	_top_panel.resized.connect(func() -> void: _layout_hud())
	_title_label.size = Vector2(636, 22)
	_clock_label.size = Vector2(636, 20)
	_stats_label.size = Vector2(636, 40)
	_field_label.size = Vector2(636, 22)
	_hover_label.size = Vector2(636, 20)
	_status_label.size = Vector2(636, 20)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_field_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_inspector_panel = _make_panel(Vector2(0, 12), Vector2(372, 330))
	_inspector_title = _make_label(_inspector_panel, Vector2(12, 8), 15,
		Color(1.0, 0.88, 0.55))
	_inspector_title.text = "Inspector"
	_inspector_title.size = Vector2(348, 22)
	_inspector_body = _make_label(_inspector_panel, Vector2(12, 34), 13,
		Color(1, 1, 1))
	_inspector_body.size = Vector2(348, 128)
	_inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_needs = _make_label(_inspector_panel, Vector2(12, 168), 13,
		Color(0.85, 0.95, 1.0))
	_inspector_needs.size = Vector2(348, 152)

	_bottom_panel = _make_panel(Vector2(12, 0), Vector2(760, 72))
	var help: Label = _make_label(_bottom_panel, Vector2(12, 8), 12,
		Color(0.85, 0.88, 0.92))
	help.size = Vector2(736, 56)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Space Pause · 1-6 Speed (1/10/60/300/1200/3600x) · " \
		+ "Mausrad Zoom · Mittelklick Pan · Linksklick Auswahl\n" \
		+ "T Terrain RPG Pack ↔ RPG Base · C Kenney ↔ Vektor-Figuren · " \
		+ "V Scale/Y-Sort-Debug · R Dorfmitte · F12 Screenshot"
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


func _make_panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var p: Panel = Panel.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.065, 0.09, 0.86)
	sb.border_color = Color(0.40, 0.38, 0.30, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = panel_size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_root.add_child(p)
	return p


func _make_label(parent: Control, pos: Vector2, font_size: int,
		color: Color) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _layout_hud() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if _inspector_panel != null:
		_inspector_panel.position = Vector2(vp.x - 384.0, 12.0)
	if _bottom_panel != null:
		_bottom_panel.position = Vector2(12.0, vp.y - 84.0)
		_bottom_panel.size = Vector2(minf(900.0, vp.x - 24.0), 72.0)


func _refresh_hud(force: bool) -> void:
	if _clock_label == null:
		return
	var day: int = sim.day_index() + 1
	var season: int = sim.config.season_index_for_day(sim.day_index())
	var season_name: String = sim.config.season_name_for_day(sim.day_index())
	var year: int = sim.config.year_of_day(sim.day_index()) + 1
	var sod: int = sim.clock.second_of_day()
	var clock_text: String = "%02d:%02d" % [sod / 3600, (sod % 3600) / 60]
	_clock_label.text = "Tag %d · Jahr %d · %s · %s%s · %dx" % [
		day, year, season_name, clock_text,
		" · PAUSE" if view_state.paused else "", view_state.speed]
	var alive: int = sim.count_alive()
	var fields: String = _fields_summary()
	var fps: float = Engine.get_frames_per_second()
	var frame_ms: float = Performance.get_monitor(
		Performance.TIME_PROCESS) * 1000.0
	var line1: String = "Agenten %d/%d · Haushalte %d · Gebäude %d · " \
		% [alive, sim.store.count, sim.households.size(),
			sim.world.buildings.size()]
	line1 += "Grain %d/%d · Ernten %d · Saatgut %d" \
		% [sim.grain, sim.config.granary_capacity,
			sim.harvests_completed, sim.grain_seed_used]
	var line2: String
	if screenshot_mode:
		line2 = "Zoom %.2fx · %s · %s · Screenshot (Performance: Report)" \
			% [view_state.zoom, world_view.terrain_label(),
				world_view.character_label()]
	else:
		line2 = "Zoom %.2fx · %s · %s · FPS %.0f · Frame %.1f ms" \
			% [view_state.zoom, world_view.terrain_label(),
				world_view.character_label(), fps, frame_ms]
	_stats_label.text = line1 + "\n" + line2
	_field_label.text = "Felder: %s" % fields
	if _hover_id > 0:
		var row: int = sim.store.row_for_id(_hover_id)
		if row >= 0:
			_hover_label.text = "Hover: %s · %s" % [_agent_name(row),
				world_view.activity_name(sim.store.activity[row])]
		else:
			_hover_label.text = ""
	else:
		_hover_label.text = ""
	_refresh_inspector()
	if screenshot_mode:
		_status_label.text = ""
	elif not force and _status_text != "":
		_status_label.text = _status_text


func _fields_summary() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field == null:
			continue
		parts.append("%s %s" % [field.name,
			world_view.field_stage_label(field.field_stage)])
	return " · ".join(parts)


func _refresh_inspector() -> void:
	var id: int = view_state.selected_agent_id
	if id <= 0:
		_inspector_title.text = "Inspector · keine Auswahl"
		_inspector_body.text = "Linksklick auf eine Figur wählt sie aus.\n" \
			+ "Namen erscheinen bei Hover und ab Zoom 1,9x."
		_inspector_needs.text = ""
		return
	var row: int = sim.store.row_for_id(id)
	if row < 0 or sim.store.alive[row] == 0:
		view_state.selected_agent_id = 0
		_inspector_title.text = "Inspector · keine Auswahl"
		_inspector_body.text = "Die gewählte Figur lebt nicht mehr."
		_inspector_needs.text = ""
		return
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, id)
	var home: Building = sim.world.building_by_id(sim.store.home_id[row])
	var job_kind: int = sim.store.job_kind[row]
	var job_text: String = "Haushalt"
	if job_kind == AgentStore.JOB_FIELD:
		job_text = "Feldarbeit"
	elif job_kind == AgentStore.JOB_WORKSHOP:
		var job_building: Building = sim.world.building_by_id(
			sim.store.job_id[row]) if sim.store.job_id[row] > 0 else null
		job_text = job_building.name if job_building != null else "Werkstatt"
	var pos: Vector2 = sim.current_position(row)
	_inspector_title.text = "Inspector · %s (#%d)" % [_agent_name(row), id]
	var role: int = sim.store.role[row]
	var act: int = sim.store.activity[row]
	_inspector_body.text = "Alter %d · %s · %s\n" \
		% [sim.store.age_years[row],
			str(ROLE_NAMES[role]) if role >= 0 and role < ROLE_NAMES.size() \
				else "?", world_view.activity_name(act)] \
		+ "Haushalt %d · Zuhause %s\n" \
		% [sim.store.household_id[row],
			home.name if home != null else "?"] \
		+ "Arbeit %s\n" \
		% [job_text] \
		+ "Position %.1f / %.1f · %s" \
		% [pos.x, pos.y, world_view.character_label()]
	_inspector_needs.text = _needs_text(row)


func _needs_text(row: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var values: Array = [
		["Hunger", sim.store.hunger[row]],
		["Energie", sim.store.energy[row]],
		["Sozial", sim.store.social[row]],
		["Hygiene", sim.store.hygiene[row]],
		["Freude", sim.store.fun[row]],
		["Gesundheit", sim.store.health[row]],
	]
	for item in values:
		var label: String = str(item[0])
		var v: float = clampf(float(item[1]), 0.0, 100.0)
		var filled: int = int(round(v / 10.0))
		lines.append("%-11s %s %3d" % [label, "#".repeat(filled)
			+ ".".repeat(10 - filled), int(round(v))])
	return "\n".join(lines)


func set_hud_visible(value: bool) -> void:
	if _hud_layer != null:
		_hud_layer.visible = value


func _show_status(text: String, seconds: float) -> void:
	_status_text = text
	_status_until = Time.get_ticks_msec() * 0.001 + seconds
	_status_label.text = text


func _capture_manual() -> void:
	var dir: String = ProjectSettings.globalize_path("res://bench/results")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp: String = "day%03d_%s" % [sim.day_index() + 1,
		sim.clock.time_string().replace(":", "")]
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = dir.path_join("g4c_p_manual_%s_%dx.png" % [stamp,
		world_view.terrain_mode])
	var err: Error = img.save_png(path)
	_show_status("Screenshot: %s" % path if err == OK else "Screenshot-Fehler %d" % err, 5.0)
