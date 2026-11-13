extends Node2D

## Visueller G1a-Benchmark: 10 Agenten @50x, 60 s Messfenster, VSync aus.
## Schreibt res://bench/results/g1a_visual_result.json.
## godot --path V3 res://tests/g1a/bench_visual.tscn
## (nicht --headless: Dummy-Renderer liefert keine gültigen Frame-Zeiten)

const WARMUP_S: float = 6.0
const MEASURE_S: float = 60.0
const RESULT_PATH: String = "res://bench/results/g1a_visual_result.json"

var sim: Simulation
var view_state: ViewState
var world_view: WorldView
var camera: GameCamera
var hud: Hud

var _phase: float = 0.0
var _elapsed: float = 0.0
var _last_tick: int = 0
var _samples: PackedFloat64Array = PackedFloat64Array()
var _draw_samples: PackedInt32Array = PackedInt32Array()
var _events: int = 0
var _start_sim_time: int = 0
var _sim_accumulator: float = 0.0
var _measuring: bool = false
var _done: bool = false
var _hud_timer: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("BENCH_VISUAL requires a window; do not use --headless")
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	sim = Simulation.create()
	_start_sim_time = sim.clock.now
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
	_last_tick = Time.get_ticks_usec()
	print("BENCH_VISUAL start agents=%d speed=50 vsync=off window=%s" % [
		sim.store.count, str(DisplayServer.window_get_size())])


func _process(delta: float) -> void:
	if _done:
		return
	var now_usec: int = Time.get_ticks_usec()
	var frame_ms: float = float(now_usec - _last_tick) / 1000.0
	_last_tick = now_usec
	_elapsed += delta
	_phase += delta
	# Sim-Zeit wie die Demo, aber mit 50x.
	var rate: float = float(SimConfig.TICKS_PER_DAY) / float(SimConfig.REAL_SECONDS_PER_DAY_AT_1X)
	_sim_accumulator += delta * rate * 50.0
	var steps: int = int(floor(_sim_accumulator))
	if steps > 0:
		_events += sim.advance_to(sim.clock.now + steps)
		_sim_accumulator -= float(steps)
	# Kamerafahrt: pan + zoom.
	view_state.zoom = clampf(1.1 + 0.55 * sin(_phase * 0.23), 0.6, 2.2)
	camera.zoom = Vector2(view_state.zoom, view_state.zoom)
	var center: Vector2 = Vector2(64, 64) * SimConfig.PIXELS_PER_TILE
	camera.position = center + Vector2(sin(_phase * 0.37) * 300.0,
		cos(_phase * 0.29) * 220.0) / view_state.zoom
	view_state.camera_position = camera.position / SimConfig.PIXELS_PER_TILE
	world_view.queue_redraw()
	_update_day_night()
	_hud_timer += delta
	if _hud_timer >= 0.1:
		_hud_timer = 0.0
		hud.refresh(sim)
	if _elapsed >= WARMUP_S and not _measuring:
		_measuring = true
		_samples.clear()
		_draw_samples.clear()
		print("BENCH_VISUAL measure_start")
	if _measuring:
		_samples.append(frame_ms)
		_draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if _elapsed >= WARMUP_S + MEASURE_S:
			_finish()


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
	world_view.modulate = color


func _finish() -> void:
	_done = true
	_samples.sort()
	var p50: float = _percentile(_samples, 0.50)
	var p95: float = _percentile(_samples, 0.95)
	var p99: float = _percentile(_samples, 0.99)
	var max_frame: float = _samples[_samples.size() - 1] if _samples.size() > 0 else 0.0
	var fps_avg: float = float(_samples.size()) / MEASURE_S
	var sim_days: float = float(sim.clock.now - _start_sim_time) / float(SimConfig.TICKS_PER_DAY)
	var draw_avg: float = 0.0
	var draw_max: int = 0
	for d in _draw_samples:
		draw_avg += float(d)
		if d > draw_max:
			draw_max = d
	if _draw_samples.size() > 0:
		draw_avg /= float(_draw_samples.size())
	var result: Dictionary = {
		"ok": p95 <= 16.0 and fps_avg >= 55.0 and sim_days > 0.5,
		"agents": sim.store.count,
		"speed": 50,
		"frames": _samples.size(),
		"frame_p50_ms": p50,
		"frame_p95_ms": p95,
		"frame_p99_ms": p99,
		"frame_max_ms": max_frame,
		"fps_avg": fps_avg,
		"sim_days": sim_days,
		"events": _events,
		"events_per_frame": float(_events) / maxf(1.0, float(_samples.size())),
		"draw_calls_avg": draw_avg,
		"draw_calls_max": draw_max,
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
	print("G1A_VISUAL_RESULT " + JSON.stringify(result))
	if result["ok"]:
		print("G1A_VISUAL_OK")
		get_tree().quit(0)
	else:
		print("G1A_VISUAL_FAILED")
		get_tree().quit(1)


func _percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var idx: int = int(round(float(values.size() - 1) * p))
	return values[idx]
