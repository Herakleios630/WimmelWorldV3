extends Node2D

## Sichtbarer G1b-Jahreslauf: 10 Agenten, 1 Sim-Jahr bei 50x (9 min).
## Schreibt bench/results/g1b_year_result.json sowie Screenshots der ersten
## Geburt und des ersten Todes. Kein Headless-Lauf.
## godot --path V3 res://tests/g1b/visual_year.tscn

const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")
const RESULT_PATH: String = "res://bench/results/g1b_year_result.json"
const WARMUP_S: float = 5.0

var sim: Simulation
var view_state: ViewState
var world_view: WorldView
var camera: GameCamera
var hud: Hud

var _start_sim_time: int = 0
var _start_real_ms: int = 0
var _last_tick_ms: int = 0
var _elapsed: float = 0.0
var _phase: float = 0.0
var _sim_accumulator: float = 0.0
var _samples: PackedFloat64Array = PackedFloat64Array()
var _draw_samples: PackedInt32Array = PackedInt32Array()
var _events: int = 0
var _done: bool = false
var _hud_timer: float = 0.0

var _chronicle_index: int = 0
var _births_seen: int = 0
var _deaths_seen: int = 0
var _birth_day: int = -1
var _death_day: int = -1
var _capture_kind: String = ""
var _capture_wait: int = 0
var _capture_pending: String = ""
var _capture_done: Dictionary = {"birth": false, "death": false}
var _capture_frames: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("VISUAL_YEAR requires a window; do not use --headless")
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var config: SimConfig = SimConfig.new()
	config.seed = FeaturedSeed.FEATURED_SEED
	sim = Simulation.create(config)
	_start_sim_time = sim.clock.now
	_start_real_ms = Time.get_ticks_msec()
	view_state = ViewState.new()
	view_state.speed = 50
	view_state.paused = false
	view_state.camera_position = Vector2(64, 64)
	view_state.zoom = 1.4
	world_view = WorldView.new()
	add_child(world_view)
	world_view.configure(sim, view_state)
	camera = GameCamera.new()
	add_child(camera)
	camera.configure(view_state)
	camera.enabled = true
	camera.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.configure(view_state)
	_last_tick_ms = Time.get_ticks_usec()
	print("VISUAL_YEAR start seed=%d agents=%d speed=50 vsync=off window=%s target_days=30" % [
		FeaturedSeed.FEATURED_SEED, sim.store.count, str(DisplayServer.window_get_size())])


func _process(delta: float) -> void:
	if _done:
		return
	if _capture_frames > 0:
		_capture_frames -= 1
		_capture_wait -= 1
		if _capture_wait <= 0 and _capture_kind != "":
			_save_capture(_capture_kind)
			_capture_kind = ""
			if _capture_pending != "":
				_capture_kind = _capture_pending
				_capture_pending = ""
				_capture_wait = 12
				_capture_frames = 24
		world_view.queue_redraw()
		hud.refresh(sim)
		return
	var now_usec: int = Time.get_ticks_usec()
	var frame_ms: float = float(now_usec - _last_tick_ms) / 1000.0
	_last_tick_ms = now_usec
	_elapsed += delta
	_phase += delta
	var rate: float = float(SimConfig.TICKS_PER_DAY) / float(SimConfig.REAL_SECONDS_PER_DAY_AT_1X)
	_sim_accumulator += delta * rate * 50.0
	var steps: int = int(floor(_sim_accumulator))
	if steps > 0:
		_events += sim.advance_to(sim.clock.now + steps)
		_sim_accumulator -= float(steps)
		_scan_events()
	view_state.zoom = clampf(1.15 + 0.45 * sin(_phase * 0.21), 0.7, 2.0)
	camera.zoom = Vector2(view_state.zoom, view_state.zoom)
	var center: Vector2 = Vector2(64, 64) * SimConfig.PIXELS_PER_TILE
	camera.position = center + Vector2(sin(_phase * 0.31) * 260.0,
		cos(_phase * 0.27) * 180.0) / view_state.zoom
	view_state.camera_position = camera.position / SimConfig.PIXELS_PER_TILE
	world_view.queue_redraw()
	_update_day_night()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		hud.refresh(sim)
	if _elapsed >= WARMUP_S:
		_samples.append(frame_ms)
		_draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var target: int = _start_sim_time + 30 * SimConfig.TICKS_PER_DAY
	if sim.clock.now >= target:
		_finish()


func _scan_events() -> void:
	var chronicle: Array = sim.logs.chronicle_events
	while _chronicle_index < chronicle.size():
		var event: SimEvent = chronicle[_chronicle_index]
		_chronicle_index += 1
		if event.type == SimEvent.T_BIRTH:
			_births_seen += 1
			if _birth_day < 0:
				_birth_day = event.time / SimConfig.TICKS_PER_DAY
			if not _capture_done["birth"]:
				_request_capture("birth")
		elif event.type == SimEvent.T_DEATH:
			_deaths_seen += 1
			if _death_day < 0:
				_death_day = event.time / SimConfig.TICKS_PER_DAY
			if not _capture_done["death"]:
				_request_capture("death")


func _request_capture(kind: String) -> void:
	if _capture_crossed():
		_capture_pending = kind
		return
	_capture_kind = kind
	_capture_wait = 12
	_capture_frames = 24


func _capture_crossed() -> bool:
	return _capture_kind != ""


func _save_capture(kind: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://bench/results"))
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "res://bench/results/g1b_year_%s.png" % kind
	var err: int = img.save_png(path)
	_capture_done[kind] = true
	print("VISUAL_YEAR_CAPTURE kind=%s day=%d err=%d path=%s" % [
		kind, sim.clock.day_index(), err, path])


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


func _finish() -> void:
	_done = true
	_samples.sort()
	var p50: float = _percentile(_samples, 0.50)
	var p95: float = _percentile(_samples, 0.95)
	var p99: float = _percentile(_samples, 0.99)
	var max_frame: float = _samples[_samples.size() - 1] if _samples.size() > 0 else 0.0
	var measure_s: float = maxf(0.001, _elapsed - WARMUP_S)
	var fps_avg: float = float(_samples.size()) / measure_s
	var sim_days: float = float(sim.clock.now - _start_sim_time) / float(SimConfig.TICKS_PER_DAY)
	var draw_avg: float = 0.0
	var draw_max: int = 0
	for d in _draw_samples:
		draw_avg += float(d)
		if d > draw_max:
			draw_max = d
	if _draw_samples.size() > 0:
		draw_avg /= float(_draw_samples.size())
	var alive: int = sim.count_alive()
	var result: Dictionary = {
		"ok": p95 <= 16.0 and fps_avg >= 55.0 and sim_days >= 29.5
			and _births_seen >= 1 and _deaths_seen >= 1 and alive >= 5,
		"seed": FeaturedSeed.FEATURED_SEED,
		"agents": 10,
		"final_count": sim.store.count,
		"alive": alive,
		"births": _births_seen,
		"deaths": _deaths_seen,
		"first_birth_day": _birth_day,
		"first_death_day": _death_day,
		"speed": 50,
		"sim_days": sim_days,
		"elapsed_s": _elapsed,
		"frames": _samples.size(),
		"frame_p50_ms": p50,
		"frame_p95_ms": p95,
		"frame_p99_ms": p99,
		"frame_max_ms": max_frame,
		"fps_avg": fps_avg,
		"events": _events,
		"draw_calls_avg": draw_avg,
		"draw_calls_max": draw_max,
		"grain": sim.grain,
		"vsync": "disabled",
		"window": str(DisplayServer.window_get_size()),
		"godot": Engine.get_version_info().get("string", "?"),
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://bench/results"))
	var f: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(result, "  "))
		f.close()
	print("G1B_VISUAL_YEAR_RESULT " + JSON.stringify(result))
	if result["ok"]:
		print("G1B_VISUAL_YEAR_OK")
		get_tree().quit(0)
	else:
		print("G1B_VISUAL_YEAR_FAILED")
		get_tree().quit(1)


func _percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var idx: int = int(round(float(values.size() - 1) * p))
	return values[idx]
