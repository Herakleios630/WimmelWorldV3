class_name DemoMain
extends Node2D

## Sichtbare G1a-Demo. Treibt nur die Simulationszeit über Wall-Clock-Delta;
## Kamera/Auswahl/Sichtbarkeit bleiben reine View-Werte.

var sim: Simulation
var view_state: ViewState
var world_view: WorldView
var camera: GameCamera
var hud: Hud
var chronicle_hud: ChronicleHud

var _sim_accumulator: float = 0.0
var _last_load_message: String = ""


func _ready() -> void:
	sim = Simulation.create()
	view_state = ViewState.new()
	view_state.speed = 1
	view_state.camera_position = Vector2(64, 64)
	view_state.zoom = 1.6
	world_view = WorldView.new()
	add_child(world_view)
	world_view.configure(sim, view_state)
	camera = GameCamera.new()
	add_child(camera)
	camera.configure(view_state, sim)
	camera.enabled = true
	camera.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.configure(view_state)
	hud.speed_changed.connect(_on_speed_changed)
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.save_requested.connect(_on_save)
	hud.load_requested.connect(_on_load)
	chronicle_hud = ChronicleHud.new()
	add_child(chronicle_hud)
	chronicle_hud.configure(sim, view_state)
	_update_day_night()
	hud.show_status("G1b läuft. F: Follow · T: Familie · C: Chronik", 6.0)


func _process(delta: float) -> void:
	if not view_state.paused:
		var rate: float = float(SimConfig.TICKS_PER_DAY) / float(SimConfig.REAL_SECONDS_PER_DAY_AT_1X)
		_sim_accumulator += delta * rate * float(view_state.speed)
		var steps: int = int(floor(_sim_accumulator))
		if steps > 0:
			sim.advance_to(sim.clock.now + steps)
			_sim_accumulator -= float(steps)
	world_view.queue_redraw()
	_update_day_night()
	hud.refresh(sim)
	chronicle_hud.refresh(sim)


func _update_day_night() -> void:
	var hour: float = float(sim.clock.second_of_day()) / 3600.0
	var color: Color
	if hour < 5.0 or hour >= 21.5:
		color = Color(0.38, 0.44, 0.68)
	elif hour < 7.0:
		color = Color(0.38, 0.44, 0.68).lerp(Color(1.0, 0.86, 0.70), (hour - 5.0) / 2.0)
	elif hour < 17.5:
		color = Color(1.0, 0.98, 0.92)
	elif hour < 19.5:
		color = Color(1.0, 0.98, 0.92).lerp(Color(1.0, 0.72, 0.52), (hour - 17.5) / 2.0)
	else:
		color = Color(1.0, 0.72, 0.52).lerp(Color(0.38, 0.44, 0.68), (hour - 19.5) / 2.0)
	var season: int = (sim.day_index() / 30) % 4
	var tint: Color = [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 0.94),
		Color(1.0, 0.95, 0.88), Color(0.92, 0.96, 1.0)][season]
	world_view.modulate = Color(color.r * tint.r, color.g * tint.g, color.b * tint.b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_at(get_global_mouse_position())
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_SPACE:
			_on_pause_toggled(not view_state.paused)
		elif key == KEY_1:
			_on_speed_changed(1)
		elif key == KEY_2:
			_on_speed_changed(10)
		elif key == KEY_3:
			_on_speed_changed(50)
		elif key == KEY_F5:
			_on_save()
		elif key == KEY_F9:
			_on_load()


func _select_at(world_pixel_pos: Vector2) -> void:
	var tile_pos: Vector2 = world_pixel_pos / float(SimConfig.PIXELS_PER_TILE)
	var best_row: int = -1
	var best_dist: float = 1.2
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var d: float = sim.current_position(row).distance_to(tile_pos)
		if d < best_dist:
			best_dist = d
			best_row = row
	if best_row < 0:
		view_state.selected_agent_id = 0
		view_state.follow_agent_id = 0
		return
	view_state.selected_agent_id = sim.store.ids[best_row]
	if view_state.follow_enabled:
		view_state.follow_agent_id = view_state.selected_agent_id
	camera.focus_on_tile(sim.current_position(best_row))


func _on_speed_changed(speed: int) -> void:
	view_state.speed = speed
	view_state.paused = false
	hud.show_status("Speed: %dx" % speed, 2.0)


func _on_pause_toggled(paused: bool) -> void:
	view_state.paused = paused
	_sim_accumulator = 0.0
	hud.show_status("Pausiert" if paused else "Weiter", 2.0)


func _on_save() -> void:
	var info: Dictionary = sim.save_to(SimSave.default_path())
	if info.get("ok", false):
		hud.show_status("Gespeichert: %d Bytes in %.2f ms" % [
			int(info["bytes"]), float(info["save_ms"])])
	else:
		hud.show_status("Speichern fehlgeschlagen: " + str(info.get("error", "?")), 6.0)


func _on_load() -> void:
	var loaded: Dictionary = Simulation.load_from(SimSave.default_path())
	if not loaded.get("ok", false):
		hud.show_status("Laden fehlgeschlagen: " + str(loaded.get("error", "?")), 6.0)
		return
	sim = loaded["sim"]
	_sim_accumulator = 0.0
	world_view.configure(sim, view_state)
	camera.sim = sim
	if view_state.selected_agent_id > 0 and sim.store.row_for_id(view_state.selected_agent_id) < 0:
		view_state.selected_agent_id = 0
	if not FollowModel.has_target(sim, view_state.follow_agent_id):
		view_state.follow_enabled = false
		view_state.follow_agent_id = 0
	chronicle_hud.configure(sim, view_state)
	hud.show_status("Geladen: %s" % sim.clock.time_string(), 4.0)
