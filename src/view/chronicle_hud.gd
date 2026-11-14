class_name ChronicleHud
extends CanvasLayer

## G1b-Beobachtungs-UI: Story of the Day, Alerts, Chronik-Panel mit Filtern
## und Familienbaum. Alle Werte sind reine View-Inputs/Reads.

var sim: Simulation
var view_state: ViewState

var _root: Control
var _story_panel: PanelContainer
var _chronicle_panel: PanelContainer
var _alert_panel: PanelContainer
var _family_panel: PanelContainer
var _family_view: FamilyTreeView
var _story_label: RichTextLabel
var _alert_label: RichTextLabel
var _chronicle_list: RichTextLabel
var _follow_button: Button
var _family_button: Button
var _chronicle_button: Button
var _agent_filter: OptionButton
var _household_filter: OptionButton
var _importance_filter: OptionButton
var _range_filter: OptionButton
var _last_refresh_ms: int = 0
var _built: bool = false


func configure(p_sim: Simulation, p_view_state: ViewState) -> void:
	sim = p_sim
	view_state = p_view_state
	if not _built:
		_build()
		_built = true
	_populate_agent_filter()
	refresh(sim, true)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Story of the Day
	_story_panel = _make_panel()
	_anchor_right_panel(_story_panel, 400.0, 172.0)
	_root.add_child(_story_panel)
	var story_box: VBoxContainer = _panel_body(_story_panel)
	var story_title_row: HBoxContainer = HBoxContainer.new()
	story_title_row.add_theme_constant_override("separation", 6)
	story_box.add_child(story_title_row)
	var story_title: Label = Label.new()
	story_title.text = "Story of the Day"
	story_title.add_theme_font_size_override("font_size", 17)
	story_title_row.add_child(story_title)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_title_row.add_child(spacer)
	_follow_button = Button.new()
	_follow_button.text = "Follow F"
	_follow_button.pressed.connect(_toggle_follow)
	story_title_row.add_child(_follow_button)
	_family_button = Button.new()
	_family_button.text = "Baum T"
	_family_button.pressed.connect(_toggle_family)
	story_title_row.add_child(_family_button)
	_chronicle_button = Button.new()
	_chronicle_button.text = "Chronik C"
	_chronicle_button.pressed.connect(_toggle_chronicle)
	story_title_row.add_child(_chronicle_button)
	_story_label = RichTextLabel.new()
	_story_label.bbcode_enabled = true
	_story_label.fit_content = false
	_story_label.scroll_active = false
	_story_label.custom_minimum_size = Vector2(392, 120)
	story_box.add_child(_story_label)

	# Chronik-Panel mit Filtern
	_chronicle_panel = _make_panel()
	_anchor_right_panel(_chronicle_panel, 578.0, 360.0)
	_root.add_child(_chronicle_panel)
	var chronicle_box: VBoxContainer = _panel_body(_chronicle_panel)
	var chronicle_title: Label = Label.new()
	chronicle_title.text = "Chronik (kuratiert)"
	chronicle_title.add_theme_font_size_override("font_size", 17)
	chronicle_box.add_child(chronicle_title)
	var filters: HBoxContainer = HBoxContainer.new()
	filters.add_theme_constant_override("separation", 5)
	chronicle_box.add_child(filters)
	_agent_filter = OptionButton.new()
	_agent_filter.custom_minimum_size.x = 150
	_agent_filter.item_selected.connect(_on_filter_changed)
	filters.add_child(_agent_filter)
	_household_filter = OptionButton.new()
	_household_filter.custom_minimum_size.x = 100
	_household_filter.add_item("Alle Haushalte", 0)
	for h in [1, 2, 3]:
		_household_filter.add_item("H%d" % h, h)
	_household_filter.item_selected.connect(_on_filter_changed)
	filters.add_child(_household_filter)
	var filters2: HBoxContainer = HBoxContainer.new()
	filters2.add_theme_constant_override("separation", 5)
	chronicle_box.add_child(filters2)
	_importance_filter = OptionButton.new()
	_importance_filter.custom_minimum_size.x = 150
	_importance_filter.add_item("Alle Wichtigkeiten", 0)
	_importance_filter.add_item("Notabel+", 1)
	_importance_filter.add_item("Major+", 2)
	_importance_filter.add_item("Historisch", 3)
	_importance_filter.item_selected.connect(_on_filter_changed)
	filters2.add_child(_importance_filter)
	_range_filter = OptionButton.new()
	_range_filter.custom_minimum_size.x = 100
	_range_filter.add_item("Heute", 0)
	_range_filter.add_item("7 Tage", 7)
	_range_filter.add_item("Gesamt", -1)
	_range_filter.item_selected.connect(_on_filter_changed)
	filters2.add_child(_range_filter)
	if view_state != null:
		for i in _range_filter.item_count:
			if _range_filter.get_item_id(i) == view_state.chronicle_filter_days:
				_range_filter.select(i)
				break
		for i in _importance_filter.item_count:
			if _importance_filter.get_item_id(i) == view_state.chronicle_filter_importance:
				_importance_filter.select(i)
				break
	_chronicle_list = RichTextLabel.new()
	_chronicle_list.bbcode_enabled = true
	_chronicle_list.fit_content = false
	_chronicle_list.scroll_active = true
	_chronicle_list.custom_minimum_size = Vector2(392, 230)
	chronicle_box.add_child(_chronicle_list)

	# Alerts links unter dem Inspector
	_alert_panel = _make_panel()
	_alert_panel.position = Vector2(12, 608)
	_alert_panel.size = Vector2(310, 250)
	_root.add_child(_alert_panel)
	var alert_box: VBoxContainer = _panel_body(_alert_panel)
	var alert_title: Label = Label.new()
	alert_title.text = "Alerts (nur major+)"
	alert_title.add_theme_font_size_override("font_size", 16)
	alert_box.add_child(alert_title)
	_alert_label = RichTextLabel.new()
	_alert_label.bbcode_enabled = true
	_alert_label.fit_content = false
	_alert_label.scroll_active = false
	_alert_label.custom_minimum_size = Vector2(286, 200)
	alert_box.add_child(_alert_label)

	# Familienbaum, zunächst verborgen.
	_family_panel = _make_panel()
	_family_panel.position = Vector2(360, 110)
	_family_panel.size = Vector2(790, 500)
	_family_panel.visible = false
	_root.add_child(_family_panel)
	var family_box: VBoxContainer = _panel_body(_family_panel)
	var family_title: Label = Label.new()
	family_title.text = "Familienbaum · mindestens 3 Generationen, Tote als historische Knoten"
	family_title.add_theme_font_size_override("font_size", 15)
	family_box.add_child(family_title)
	_family_view = FamilyTreeView.new()
	family_box.add_child(_family_view)


func _populate_agent_filter() -> void:
	_agent_filter.clear()
	_agent_filter.add_item("Alle Agenten", 0)
	if sim == null:
		return
	for record in sim.records:
		var rec: AgentRecord = record
		_agent_filter.add_item("%s (A%d)" % [rec.name, rec.id], rec.id)
	if view_state != null and view_state.chronicle_filter_agent_id > 0:
		for i in _agent_filter.item_count:
			if _agent_filter.get_item_id(i) == view_state.chronicle_filter_agent_id:
				_agent_filter.select(i)
				break


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.09, 0.90)
	style.border_color = Color(0.42, 0.40, 0.32, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _panel_body(panel: PanelContainer) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	return box


func _anchor_right_panel(panel: PanelContainer, top: float, height: float) -> void:
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -432.0
	panel.offset_right = -12.0
	panel.offset_top = top
	panel.offset_bottom = top + height


func refresh(p_sim: Simulation, force: bool = false) -> void:
	if view_state == null:
		return
	if p_sim != null:
		sim = p_sim
	if sim == null or not _built:
		return
	var now_ms: int = Time.get_ticks_msec()
	if not force and now_ms - _last_refresh_ms < 250:
		return
	_last_refresh_ms = now_ms
	_follow_button.text = "Follow an" if view_state.follow_enabled else "Follow F"
	_chronicle_panel.visible = view_state.chronicle_visible
	_family_panel.visible = view_state.family_tree_visible
	_refresh_story()
	_refresh_alerts()
	if view_state.chronicle_visible:
		_refresh_chronicle()
	if view_state.family_tree_visible:
		_refresh_family()


func _refresh_story() -> void:
	var day: int = sim.clock.day_index()
	var focus: int = view_state.follow_agent_id
	if focus <= 0:
		focus = view_state.selected_agent_id
	var entries: Array = StoryOfDay.for_day(sim.chronicle, sim, day, focus)
	if entries.is_empty():
		_story_label.text = "[color=#9a9a90]Keine major/historic Geschichte an diesem Tag.[/color]"
		return
	var lines: PackedStringArray = PackedStringArray()
	for entry in entries:
		var color: String = "#ff9b6b" if int(entry["importance"]) >= SimEvent.IMPORTANCE_MAJOR \
			else "#ffd479"
		lines.append("[color=#8fb8ff]%s[/color] [color=%s]%s[/color]" % [
			str(entry["time_text"]), color, str(entry["text"])])
	_story_label.text = "\n".join(lines)


func _refresh_alerts() -> void:
	var day: int = sim.clock.day_index()
	var alerts: Array = AlertModel.for_day(sim.chronicle, sim, day)
	if alerts.is_empty():
		_alert_label.text = "[color=#9a9a90]Keine Alerts (major/historic).[/color]"
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[color=#9a9a90]%d Alert(s) heute · Limit %d[/color]" % [
		alerts.size(), sim.config.chronicle_alert_max_per_day])
	for i in mini(7, alerts.size()):
		var alert: Dictionary = alerts[i]
		lines.append("[color=#ff9b6b]%s[/color] %s" % [
			str(alert["time_text"]), str(alert["text"])])
	_alert_label.text = "\n".join(lines)


func _refresh_chronicle() -> void:
	var filters: Dictionary = {}
	var day: int = sim.clock.day_index()
	if view_state.chronicle_filter_agent_id > 0:
		filters["agent_id"] = view_state.chronicle_filter_agent_id
	if view_state.chronicle_filter_household_id > 0:
		filters["household_id"] = view_state.chronicle_filter_household_id
	if view_state.chronicle_filter_importance > 0:
		filters["importance_min"] = view_state.chronicle_filter_importance
	if view_state.chronicle_filter_days >= 0:
		filters["from_time"] = (day - view_state.chronicle_filter_days) \
			* SimConfig.TICKS_PER_DAY
	var entries: Array = ChroniclePanelModel.query(sim, filters, 18)
	if entries.is_empty():
		_chronicle_list.text = "[color=#9a9a90]Keine Einträge für diesen Filter.[/color]"
		return
	var lines: PackedStringArray = PackedStringArray()
	for entry in entries:
		var importance: int = int(entry["importance"])
		var color: String = "#ff9b6b" if importance >= SimEvent.IMPORTANCE_MAJOR \
			else ("#ffd479" if importance == SimEvent.IMPORTANCE_NOTABLE else "#cfcfcf")
		lines.append("[color=#8fb8ff]%s[/color] [color=%s]%s[/color] [color=#7f8078]%s[/color]" % [
			str(entry["time_text"]), color, str(entry["text"]),
			str(entry["category"])])
	_chronicle_list.text = "\n".join(lines)


func _refresh_family() -> void:
	_family_view.configure(FamilyTreeModel.build(sim))


func _on_filter_changed(_index: int) -> void:
	if _agent_filter.selected >= 0:
		view_state.chronicle_filter_agent_id = _agent_filter.get_item_id(_agent_filter.selected)
	if _household_filter.selected >= 0:
		view_state.chronicle_filter_household_id = _household_filter.get_item_id(_household_filter.selected)
	if _importance_filter.selected >= 0:
		view_state.chronicle_filter_importance = _importance_filter.get_item_id(_importance_filter.selected)
	if _range_filter.selected >= 0:
		view_state.chronicle_filter_days = _range_filter.get_item_id(_range_filter.selected)
	refresh(sim, true)


func _toggle_follow() -> void:
	if sim == null:
		return
	if view_state.follow_enabled:
		view_state.follow_enabled = false
		refresh(sim, true)
		return
	var target: int = FollowModel.pick_default_target(sim,
		view_state.selected_agent_id)
	if target <= 0:
		return
	view_state.follow_agent_id = target
	view_state.selected_agent_id = target
	view_state.follow_enabled = true
	refresh(sim, true)


func _toggle_family() -> void:
	view_state.family_tree_visible = not view_state.family_tree_visible
	refresh(sim, true)


func _toggle_chronicle() -> void:
	view_state.chronicle_visible = not view_state.chronicle_visible
	refresh(sim, true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F:
			_toggle_follow()
		KEY_T:
			_toggle_family()
		KEY_C:
			_toggle_chronicle()
