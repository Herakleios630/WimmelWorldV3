extends Node2D

## G2 visueller Benchmark: 100 Agenten @50x, 5-Minuten-Messfenster.
## Schreibt res://bench/results/g2_visual_runN.json und g2_visual_result.json.
## godot --path V3 res://tests/g2/bench_visual.tscn -- --run=1

const WARMUP_S: float = 30.0
const MEASURE_S: float = 300.0
const RESULT_DIR: String = "res://bench/results"

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
var _measuring: bool = false
var _done: bool = false
var _frame_samples: PackedFloat64Array = PackedFloat64Array()
var _sim_samples: PackedFloat64Array = PackedFloat64Array()
var _render_samples: PackedFloat64Array = PackedFloat64Array()
var _draw_samples: PackedInt32Array = PackedInt32Array()
var _events: int = 0
var _start_sim_time: int = 0
var _run_id: int = 1
var _warmup_s: float = WARMUP_S
var _measure_s: float = MEASURE_S


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("G2_BENCH_VISUAL requires a window; do not use --headless")
		get_tree().quit(2)
		return
	_run_id = _parse_run_id()
	_parse_duration()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	sim = Simulation.create(SimConfig.g2(1337))
	_start_sim_time = sim.clock.now
	view_state = ViewState.new()
	view_state.speed = 50
	view_state.paused = false
	view_state.camera_position = Vector2(192, 192)
	view_state.zoom = 0.8
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
	print("G2_BENCH_VISUAL run=%d agents=%d speed=50 vsync=off window=%s" % [
		_run_id, sim.store.count, str(DisplayServer.window_get_size())])


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
	var sim_ms: float = 0.0
	if steps > 0:
		var t0: int = Time.get_ticks_usec()
		_events += sim.advance_to(sim.clock.now + steps)
		sim_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_sim_accumulator -= float(steps)
	# Kamerafahrt über die 384er-Karte.
	view_state.zoom = clampf(0.65 + 0.45 * sin(_phase * 0.17), 0.45, 1.5)
	camera.zoom = Vector2(view_state.zoom, view_state.zoom)
	var center: Vector2 = Vector2(192, 192) * SimConfig.PIXELS_PER_TILE
	camera.position = center + Vector2(sin(_phase * 0.21) * 1600.0,
		cos(_phase * 0.18) * 1100.0) / view_state.zoom
	view_state.camera_position = camera.position / SimConfig.PIXELS_PER_TILE
	world_view.modulate = _day_night_tint()
	world_view.queue_redraw()
	hud.refresh(sim)
	chronicle_hud.refresh(sim)
	# Konservative Render-Obergrenze: Frame minus gemessene Sim-Zeit. Sie
	# enthält Render, UI, Engine und Idle und ist damit strikter als der
	# eigentliche Render-Slice.
	var render_ms: float = maxf(0.0, frame_ms - sim_ms)
	if _elapsed >= _warmup_s and not _measuring:
		_measuring = true
		print("G2_BENCH_VISUAL measure_start run=%d" % _run_id)
	if _measuring:
		_frame_samples.append(frame_ms)
		_sim_samples.append(sim_ms)
		_render_samples.append(render_ms)
		_draw_samples.append(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if _elapsed >= _warmup_s + _measure_s:
			_finish()


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
	var p50: float = G2TestUtil.percentile(_frame_samples, 0.50)
	var p95: float = G2TestUtil.percentile(_frame_samples, 0.95)
	var p99: float = G2TestUtil.percentile(_frame_samples, 0.99)
	var max_ms: float = G2TestUtil.percentile(_frame_samples, 1.0)
	var sim_p95: float = G2TestUtil.percentile(_sim_samples, 0.95)
	var render_p95: float = G2TestUtil.percentile(_render_samples, 0.95)
	var fps_avg: float = float(_frame_samples.size()) / _measure_s
	var sim_days: float = float(sim.clock.now - _start_sim_time) \
		/ float(SimConfig.TICKS_PER_DAY)
	var draw_avg: float = 0.0
	var draw_max: int = 0
	for d in _draw_samples:
		draw_avg += float(d)
		if d > draw_max:
			draw_max = d
	if _draw_samples.size() > 0:
		draw_avg /= float(_draw_samples.size())
	var nav: Dictionary = sim.navigation_stats()
	var batch: Dictionary = sim.batch_stats()
	var result: Dictionary = {
		"ok": p95 <= 16.0 and p99 <= 20.0 and sim_p95 <= 6.0
			and render_p95 <= 6.0 and fps_avg >= 55.0 and sim_days >= 15.5,
		"run": _run_id,
		"agents": sim.store.count,
		"speed": 50,
		"frames": _frame_samples.size(),
		"frame_p50_ms": p50,
		"frame_p95_ms": p95,
		"frame_p99_ms": p99,
		"frame_max_ms": max_ms,
		"sim_p50_ms": G2TestUtil.percentile(_sim_samples, 0.50),
		"sim_p95_ms": sim_p95,
		"sim_p99_ms": G2TestUtil.percentile(_sim_samples, 0.99),
		"sim_max_ms": G2TestUtil.percentile(_sim_samples, 1.0),
		"render_p50_ms": G2TestUtil.percentile(_render_samples, 0.50),
		"render_p95_ms": render_p95,
		"render_p99_ms": G2TestUtil.percentile(_render_samples, 0.99),
		"fps_avg": fps_avg,
		"sim_days": sim_days,
		"events": _events,
		"events_per_frame": float(_events) / maxf(1.0, float(_frame_samples.size())),
		"draw_calls_avg": draw_avg,
		"draw_calls_max": draw_max,
		"nav": nav,
		"batch": batch,
		"vsync": "disabled",
		"window": str(DisplayServer.window_get_size()),
		"godot": Engine.get_version_info().get("string", "?"),
		"timestamp": Time.get_datetime_string_from_system(true),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	var file_name: String = "g2_visual_run%d.json" % _run_id
	_write_json(RESULT_DIR + "/" + file_name, result)
	_write_json(RESULT_DIR + "/g2_visual_result.json", result)
	print("G2_VISUAL_RESULT " + JSON.stringify(result))
	if result["ok"]:
		print("G2_VISUAL_OK")
		get_tree().quit(0)
	else:
		print("G2_VISUAL_FAILED")
		get_tree().quit(1)


func _write_json(path: String, data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "  "))
		f.close()


func _parse_run_id() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):
			return maxi(0, int(arg.substr(6)))
	return 1


func _parse_duration() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--warmup="):
			_warmup_s = maxf(1.0, float(arg.substr(9)))
		elif arg.begins_with("--measure="):
			_measure_s = maxf(2.0, float(arg.substr(10)))
