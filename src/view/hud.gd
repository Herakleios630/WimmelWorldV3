class_name Hud
extends CanvasLayer

## G1a-HUD: Zeit/Speed, Inspector, Event-Log, Tag/Nacht-Anzeige, Speichern/Laden.
## Liest nur View-Models; schreibt nie Simulation.

signal speed_changed(speed: int)
signal pause_toggled(paused: bool)
signal save_requested
signal load_requested

var view_state: ViewState
var _time_label: Label
var _grain_label: Label
var _status_label: Label
var _inspector_title: Label
var _inspector_body: RichTextLabel
var _event_log: RichTextLabel
var _pause_button: Button
var _speed_buttons: Dictionary = {}
var _need_bars: Dictionary = {}
var _need_values: Dictionary = {}
var _last_refresh_ms: int = 0
var _status_until_ms: int = 0


func configure(p_view_state: ViewState) -> void:
	view_state = p_view_state
	_build()
	refresh(null)


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Top-Leiste
	var top: PanelContainer = PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 48
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top)
	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_top", 6)
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top.add_child(top_margin)
	var top_box: HBoxContainer = HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 14)
	top_margin.add_child(top_box)
	_time_label = Label.new()
	_time_label.custom_minimum_size.x = 260
	_time_label.add_theme_font_size_override("font_size", 20)
	top_box.add_child(_time_label)
	_grain_label = Label.new()
	_grain_label.custom_minimum_size.x = 470
	_grain_label.add_theme_font_size_override("font_size", 16)
	top_box.add_child(_grain_label)
	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.custom_minimum_size.x = 84
	_pause_button.pressed.connect(_on_pause)
	top_box.add_child(_pause_button)
	for speed in [1, 10, 50]:
		var b: Button = Button.new()
		b.text = "%dx" % speed
		b.custom_minimum_size.x = 58
		b.pressed.connect(_on_speed.bind(speed))
		top_box.add_child(b)
		_speed_buttons[speed] = b
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_box.add_child(spacer)
	var save_button: Button = Button.new()
	save_button.text = "Speichern (F5)"
	save_button.pressed.connect(func(): save_requested.emit())
	top_box.add_child(save_button)
	var load_button: Button = Button.new()
	load_button.text = "Laden (F9)"
	load_button.pressed.connect(func(): load_requested.emit())
	top_box.add_child(load_button)

	# Inspector links
	var inspector: PanelContainer = PanelContainer.new()
	inspector.position = Vector2(12, 60)
	inspector.size = Vector2(310, 540)
	inspector.custom_minimum_size = Vector2(310, 500)
	inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(inspector)
	var inspector_margin: MarginContainer = MarginContainer.new()
	inspector_margin.add_theme_constant_override("margin_left", 10)
	inspector_margin.add_theme_constant_override("margin_right", 10)
	inspector_margin.add_theme_constant_override("margin_top", 8)
	inspector_margin.add_theme_constant_override("margin_bottom", 8)
	inspector.add_child(inspector_margin)
	var inspector_box: VBoxContainer = VBoxContainer.new()
	inspector_box.add_theme_constant_override("separation", 5)
	inspector_margin.add_child(inspector_box)
	_inspector_title = Label.new()
	_inspector_title.text = "Inspector"
	_inspector_title.add_theme_font_size_override("font_size", 18)
	inspector_box.add_child(_inspector_title)
	_inspector_body = RichTextLabel.new()
	_inspector_body.bbcode_enabled = true
	_inspector_body.fit_content = false
	_inspector_body.custom_minimum_size = Vector2(290, 128)
	_inspector_body.scroll_active = false
	inspector_box.add_child(_inspector_body)
	for need in range(NeedsModel.NEED_COUNT):
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		label.text = NeedsModel.need_name(need)
		label.custom_minimum_size.x = 76
		row.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(160, 18)
		var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.15, 0.15, 0.14, 0.9)
		bar_bg.corner_radius_top_left = 3
		bar_bg.corner_radius_top_right = 3
		bar_bg.corner_radius_bottom_left = 3
		bar_bg.corner_radius_bottom_right = 3
		var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
		bar_fill.bg_color = [Color(0.88, 0.48, 0.28), Color(0.36, 0.62, 0.92),
			Color(0.48, 0.78, 0.48), Color(0.42, 0.78, 0.82),
			Color(0.86, 0.70, 0.34), Color(0.88, 0.42, 0.52)][need]
		bar_fill.corner_radius_top_left = 3
		bar_fill.corner_radius_top_right = 3
		bar_fill.corner_radius_bottom_left = 3
		bar_fill.corner_radius_bottom_right = 3
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(bar)
		var value_label: Label = Label.new()
		value_label.custom_minimum_size.x = 46
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		inspector_box.add_child(row)
		_need_bars[need] = bar
		_need_values[need] = value_label

	# Event-Log rechts
	var log_panel: PanelContainer = PanelContainer.new()
	log_panel.anchor_left = 1.0
	log_panel.anchor_right = 1.0
	log_panel.offset_left = -432.0
	log_panel.offset_right = -12.0
	log_panel.offset_top = 60.0
	log_panel.offset_bottom = 390.0
	log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(log_panel)
	var log_margin: MarginContainer = MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 10)
	log_margin.add_theme_constant_override("margin_right", 10)
	log_margin.add_theme_constant_override("margin_top", 8)
	log_margin.add_theme_constant_override("margin_bottom", 8)
	log_panel.add_child(log_margin)
	var log_box: VBoxContainer = VBoxContainer.new()
	log_margin.add_child(log_box)
	var log_title: Label = Label.new()
	log_title.text = "Event-Log (Roh, Debug)"
	log_title.add_theme_font_size_override("font_size", 17)
	log_box.add_child(log_title)
	_event_log = RichTextLabel.new()
	_event_log.bbcode_enabled = true
	_event_log.fit_content = false
	_event_log.scroll_active = false
	_event_log.custom_minimum_size = Vector2(400, 285)
	log_box.add_child(_event_log)

	# Statuszeile
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_label.offset_top = -54
	_status_label.offset_bottom = -26
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_status_label)
	var hint: Label = Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -28
	hint.offset_bottom = -4
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "Linksklick: Agent wählen · WASD/Pfeile: Kamera · Mausrad: Zoom · Leertaste: Pause · 1/2/3: Speed · F5/F9: Save/Load"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.85, 0.85, 0.8, 0.8)
	root.add_child(hint)


func _on_pause() -> void:
	pause_toggled.emit(not view_state.paused)


func _on_speed(speed: int) -> void:
	speed_changed.emit(speed)


func refresh(sim: Simulation) -> void:
	if view_state == null:
		return
	_pause_button.text = "Weiter" if view_state.paused else "Pause"
	for speed in _speed_buttons:
		var b: Button = _speed_buttons[speed]
		b.modulate = Color(1.0, 0.9, 0.55) if (speed == view_state.speed and not view_state.paused) else Color.WHITE
	if sim == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_refresh_ms < 100:
		return
	_last_refresh_ms = now_ms
	_time_label.text = "%s · %s   %dx" % [sim.clock.time_string(),
		_season_name(sim.clock.day_index()), view_state.speed]
	var field: Building = sim.world.building_by_id(WorldMap.B_FIELD)
	var stage_text: String = Building.field_stage_name(field.field_stage) if field != null else "?"
	_grain_label.text = "Grain: %d (+%d geerntet) · Feld: %s · Jahr %d" % [
		sim.grain, sim.grain_harvested, stage_text, sim.year_index + 1]
	if view_state.selected_agent_id > 0:
		var info: Dictionary = InspectorModel.for_agent(sim, view_state.selected_agent_id)
		if info.is_empty():
			_inspector_title.text = "Inspector"
			_inspector_body.text = "Kein Agent ausgewählt."
		else:
			var pos: Vector2 = info["position"]
			_inspector_title.text = "%s (A%d)" % [str(info["name"]), int(info["id"])]
			var bio: PackedStringArray = info.get("biography", PackedStringArray())
			var bio_lines: PackedStringArray = PackedStringArray()
			for i in mini(3, bio.size()):
				bio_lines.append(bio[i])
			_inspector_body.text = "%d Jahre · %s · Haushalt %d · %s\n%s · %s\nAktivität: %s · Position: %.1f, %.1f\n[color=#c9c2a8]%s[/color]" % [
				int(info["age"]), str(info["role_name"]), int(info["household_id"]),
				str(info.get("status_line", "")), str(info["home_name"]),
				str(info["job_name"]), str(info["activity_name"]),
				pos.x, pos.y, "\n".join(bio_lines)]
			for need in range(NeedsModel.NEED_COUNT):
				var value: float = _need_value_from_info(info, need)
				(_need_bars[need] as ProgressBar).value = value
				(_need_values[need] as Label).text = "%.0f" % value
	else:
		_inspector_title.text = "Inspector"
		_inspector_body.text = "Kein Agent ausgewählt.\nLinksklick auf eine Figur."
		for need in _need_bars:
			(_need_bars[need] as ProgressBar).value = 0.0
			(_need_values[need] as Label).text = "-"
	_refresh_event_log(sim)
	if now_ms >= _status_until_ms and _status_label.text != "":
		_status_label.text = ""
	if now_ms < _status_until_ms:
		return


func _refresh_event_log(sim: Simulation) -> void:
	var entries: Array = EventLogModel.recent(sim, 9)
	var lines: PackedStringArray = PackedStringArray()
	for entry in entries:
		var importance: int = int(entry["importance"])
		var color: String = "#cfcfcf"
		if importance == SimEvent.IMPORTANCE_NOTABLE:
			color = "#ffd479"
		elif importance >= SimEvent.IMPORTANCE_MAJOR:
			color = "#ff9b6b"
		var who: String = str(entry["agent_name"])
		lines.append("[color=#8fb8ff]%s[/color] [color=%s]%s[/color] %s" % [
			str(entry["time_text"]), color, who, str(entry["text"])])
	_event_log.text = "\n".join(lines)


func _need_value_from_info(info: Dictionary, need: int) -> float:
	match need:
		NeedsModel.NEED_HUNGER:
			return float(info.get("hunger", 0.0))
		NeedsModel.NEED_ENERGY:
			return float(info.get("energy", 0.0))
		NeedsModel.NEED_SOCIAL:
			return float(info.get("social", 0.0))
		NeedsModel.NEED_HYGIENE:
			return float(info.get("hygiene", 0.0))
		NeedsModel.NEED_FUN:
			return float(info.get("fun", 0.0))
		NeedsModel.NEED_HEALTH:
			return float(info.get("health", 0.0))
	return 0.0


func _season_name(day: int) -> String:
	var season: int = (day % SimConfig.YEAR_DAYS) * SimConfig.SEASONS / SimConfig.YEAR_DAYS
	return ["Frühling", "Sommer", "Herbst", "Winter"][season]


func show_status(message: String, seconds: float = 4.0) -> void:
	_status_label.text = message
	_status_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
