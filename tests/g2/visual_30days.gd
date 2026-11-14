extends Node2D

## Sichtbarer 30-Sim-Tage-Lauf bei 50x (ca. 9 reale Minuten) für UI/Chronik.
## Schreibt Screenshots und res://bench/results/g2_30days_result.json.
## godot --path V3 res://tests/g2/visual_30days.tscn

const RESULT_DIR: String = "res://bench/results"
const CAPTURE_DAYS: Array = [1, 15, 30]

var sim: Simulation
var view_state: ViewState
var world_view: WorldView
var camera: GameCamera
var hud: Hud
var chronicle_hud: ChronicleHud

var _elapsed: float = 0.0
var _phase: float = 0.0
var _last_tick: int = 0
var _sim_accumulator: float = 0.0
var _start_sim_time: int = 0
var _target_sim_time: int = 0
var _events: int = 0
var _frame_samples: PackedFloat64Array = PackedFloat64Array()
var _captured: Dictionary = {}
var _done: bool = false
var _finishing: bool = false
var _finish_at: float = 0.0
var _screenshots: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("G2_30DAYS requires a window; do not use --headless")
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	sim = Simulation.create(SimConfig.g2(1337))
	_start_sim_time = sim.clock.now
	_target_sim_time = _start_sim_time + 30 * SimConfig.TICKS_PER_DAY
	view_state = ViewState.new()
	view_state.speed = 50
	view_state.paused = false
	view_state.camera_position = Vector2(192, 192)
	view_state.zoom = 0.75
	view_state.chronicle_visible = true
	var selected: int = 1
	for row in sim.store.count:
		if sim.store.role[row] == AgentStore.ROLE_ADULT:
			selected = sim.store.ids[row]
			break
	view_state.selected_agent_id = selected
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
	chronicle_hud = ChronicleHud.new()
	add_child(chronicle_hud)
	chronicle_hud.configure(sim, view_state)
	_last_tick = Time.get_ticks_usec()
	print("G2_30DAYS start agents=%d target=%d" % [sim.store.count, _target_sim_time])


func _process(delta: float) -> void:
	if _done:
		return
	var now_usec: int = Time.get_ticks_usec()
	var frame_ms: float = float(now_usec - _last_tick) / 1000.0
	_last_tick = now_usec
	_elapsed += delta
	_phase += delta
	var rate: float = float(SimConfig.TICKS_PER_DAY) \
		/ float(SimConfig.REAL_SECONDS_PER_DAY_AT_1X)
	_sim_accumulator += delta * rate * 50.0
	var steps: int = int(floor(_sim_accumulator))
	if steps > 0:
		var remaining: int = _target_sim_time - sim.clock.now
		if remaining > 0:
			steps = mini(steps, remaining)
			_events += sim.advance_to(sim.clock.now + steps)
			_sim_accumulator -= float(steps)
	view_state.zoom = clampf(0.70 + 0.25 * sin(_phase * 0.12), 0.45, 1.2)
	camera.zoom = Vector2(view_state.zoom, view_state.zoom)
	var center: Vector2 = Vector2(192, 192) * SimConfig.PIXELS_PER_TILE
	camera.position = center + Vector2(sin(_phase * 0.13) * 1500.0,
		cos(_phase * 0.11) * 900.0) / view_state.zoom
	view_state.camera_position = camera.position / SimConfig.PIXELS_PER_TILE
	world_view.modulate = _day_night_tint()
	world_view.queue_redraw()
	hud.refresh(sim)
	chronicle_hud.refresh(sim)
	if _elapsed > 5.0:
		_frame_samples.append(frame_ms)
	_check_capture()
	if not _finishing and (sim.clock.now >= _target_sim_time or _elapsed > 660.0):
		_finishing = true
		_finish_at = _elapsed + 2.0
	elif _finishing and _elapsed >= _finish_at:
		_finish()


func _check_capture() -> void:
	var day: int = sim.clock.day_index()
	for target_day in CAPTURE_DAYS:
		if day >= target_day and not _captured.has(target_day):
			_captured[target_day] = true
			var path: String = RESULT_DIR + "/g2_30days_day%02d.png" % target_day
			_screenshots.append(path)
			_capture(path)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	if image != null:
		image.save_png(ProjectSettings.globalize_path(path))
		print("G2_30DAYS capture %s at %s" % [path, sim.clock.time_string()])


func _day_night_tint() -> Color:
	var hour: float = float(sim.clock.second_of_day()) / 3600.0
	if hour < 5.0 or hour >= 21.5:
		return Color(0.38, 0.44, 0.68)
	if hour < 7.0:
		return Color(0.38, 0.44, 0.68).lerp(Color(1.0, 0.86, 0.70),
			(hour - 5.0) / 2.0)
	if hour < 17.5:
		return Color(1.0, 0.98, 0.92)
	if hour < 19.5:
		return Color(1.0, 0.98, 0.92).lerp(Color(1.0, 0.72, 0.52),
			(hour - 17.5) / 2.0)
	return Color(1.0, 0.72, 0.52).lerp(Color(0.38, 0.44, 0.68),
		(hour - 19.5) / 2.0)


func _finish() -> void:
	_done = true
	var sim_days: float = float(sim.clock.now - _start_sim_time) \
		/ float(SimConfig.TICKS_PER_DAY)
	var p95: float = G2TestUtil.percentile(_frame_samples, 0.95)
	var result: Dictionary = {
		"ok": sim_days >= 29.5 and _screenshots.size() >= 3,
		"agents": sim.store.count,
		"alive": sim.count_alive(),
		"sim_days": sim_days,
		"events": _events,
		"fps_avg": float(_frame_samples.size()) / maxf(1.0, _elapsed),
		"frame_p95_ms": p95,
		"nav": sim.navigation_stats(),
		"batch": sim.batch_stats(),
		"screenshots": _screenshots,
		"godot": Engine.get_version_info().get("string", "?"),
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	var f: FileAccess = FileAccess.open(RESULT_DIR + "/g2_30days_result.json",
		FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	print("G2_30DAYS_RESULT " + JSON.stringify(result))
	if result["ok"]:
		print("G2_30DAYS_OK")
		get_tree().quit(0)
	else:
		print("G2_30DAYS_FAILED")
		get_tree().quit(1)
