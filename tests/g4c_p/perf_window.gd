extends Node

## Sichtbare 100-Agenten-Performance: 6 s Closeup (1,8x) und 6 s Überblick
## (0,30x) bei 300x Sim-Speed, VSync aus. Kein Gate.
## Aufruf:
##   godot --path V3 --resolution 1600x900 res://tests/g4c_p/perf_window.tscn

const OUT: String = "res://bench/results/g4c_p_perf_view.json"
const PHASE_SECONDS: float = 6.0

var demo: Node2D
var sim: Simulation
var phase: int = 0
var phase_elapsed: float = 0.0
var last_us: int = 0
var samples: Array = []
var results: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var packed: PackedScene = load("res://tests/g4c_p/demo.tscn")
	demo = packed.instantiate()
	add_child(demo)
	await get_tree().process_frame
	sim = demo.sim
	demo.view_state.paused = false
	demo.view_state.speed = 300
	demo.camera.focus_tile(Vector2(290.0, 150.0), 1.8)
	last_us = Time.get_ticks_usec()
	phase_elapsed = 0.0


func _process(delta: float) -> void:
	if demo == null:
		return
	var now: int = Time.get_ticks_usec()
	var dt_us: int = now - last_us
	last_us = now
	phase_elapsed += delta
	samples.append(dt_us)
	if phase_elapsed >= PHASE_SECONDS:
		_finish_phase()
		if phase == 0:
			phase = 1
			phase_elapsed = 0.0
			samples = []
			demo.camera.focus_tile(Vector2(192.0, 190.0), 0.30)
		else:
			_write_and_quit()


func _finish_phase() -> void:
	var warm: int = mini(30, samples.size() / 4)
	var measure: Array = samples.slice(warm)
	measure.sort()
	var total_us: float = 0.0
	for v in measure:
		total_us += float(v)
	var p50: float = float(measure[int(measure.size() * 0.50)]) / 1000.0
	var p95: float = float(measure[int(measure.size() * 0.95)]) / 1000.0
	var p99: float = float(measure[int(measure.size() * 0.99)]) / 1000.0
	var max_ms: float = float(measure[measure.size() - 1]) / 1000.0
	var avg: float = total_us / float(measure.size()) / 1000.0
	var key: String = "closeup" if phase == 0 else "overview"
	results[key] = {
		"frames": measure.size(),
		"frame_ms_avg": avg,
		"frame_ms_p50": p50,
		"frame_ms_p95": p95,
		"frame_ms_p99": p99,
		"frame_ms_max": max_ms,
		"fps_avg": 1000.0 / maxf(0.001, avg),
		"zoom": demo.view_state.zoom,
		"sim_day": sim.day_index(),
		"alive": sim.count_alive(),
		"draw_calls": Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
	print("G4C_P_VIEW_PERF %s %s" % [key, JSON.stringify(results[key])])


func _write_and_quit() -> void:
	results["profile"] = "g4c_pre"
	results["seed"] = sim.config.seed
	results["world_tiles"] = sim.world.size
	results["agents"] = sim.store.count
	results["speed"] = demo.view_state.speed
	results["resolution"] = [
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://bench/results"))
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "  "))
		file.close()
	print("G4C_P_VIEW_PERF_JSON " + ProjectSettings.globalize_path(OUT))
	get_tree().quit(0)


func _exit_tree() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
