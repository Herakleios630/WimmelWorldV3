extends Node

## B-spike benchmark: 100k, detail 1k/5k, 150x/200x, 3 runs each.
## Writes res://bench/results/g3_b_spike_results.json.
## godot --headless --path V3 res://tests/g3/bench_b.tscn

const WARMUP_DAYS: float = 1.0
const MEASURE_DAYS: float = 3.0
const RUNS: int = 3
const SCENARIOS: Array = [
	[1000, 150],
	[5000, 150],
	[1000, 200],
	[5000, 200],
]


func _ready() -> void:
	var t_start: int = Time.get_ticks_usec()
	var combined: Dictionary = {
		"ok": true,
		"generated": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().get("string", "?"),
		"platform": OS.get_name(),
		"warmup_days": WARMUP_DAYS,
		"measure_days": MEASURE_DAYS,
		"runs": RUNS,
		"fps": BConfig.FPS,
		"config": {
			"population": BConfig.DEFAULT_POPULATION,
			"settlements": BConfig.DEFAULT_SETTLEMENTS,
			"cohorts": BConfig.DEFAULT_SETTLEMENTS * BConfig.COHORTS_PER_SETTLEMENT,
			"speed_base_seconds_per_day": BConfig.BASE_SECONDS_PER_DAY_AT_1X,
		},
		"scenarios": [],
	}
	for spec in SCENARIOS:
		var detail: int = spec[0]
		var speed: int = spec[1]
		var scenario: Dictionary = {
			"detail": detail,
			"speed": speed,
			"runs": [],
		}
		for run_idx in RUNS:
			var before_mem: int = OS.get_static_memory_usage()
			var sim: BSim = BSim.create(BConfig.make(detail, speed, G3TestUtil.SEED))
			sim.measure_costs = false
			G3TestUtil.advance_frames(sim, WARMUP_DAYS, false)
			sim.metrics.reset()
			sim.measure_costs = true
			var frame_info: Dictionary = G3TestUtil.advance_frames(sim, MEASURE_DAYS, true)
			var stats: Dictionary = sim.metrics.stats(sim.config, sim.detail_count(), MEASURE_DAYS)
			var summary: Dictionary = G3TestUtil.sim_summary(sim)
			var mem: Dictionary = sim.memory_estimate()
			var save_info: Dictionary = {}
			if run_idx == 0:
				var path: String = G3TestUtil.temp_path("bench_%d_%d" % [detail, speed])
				var s: Dictionary = sim.save_to(path)
				var l: Dictionary = BSim.load_from(path)
				save_info = {
					"ok": s.get("ok", false) and l.get("ok", false),
					"bytes": int(s.get("bytes", 0)),
					"save_ms": float(s.get("save_ms", 0.0)),
					"load_ms": float(l.get("load_ms", 0.0)),
					"state_equal": false,
					"event_equal": false,
					"tier_equal": false,
				}
				if l.get("ok", false):
					var b: BSim = l["sim"]
					save_info["state_equal"] = b.state_hash() == sim.state_hash()
					save_info["event_equal"] = b.event_hash() == sim.event_hash()
					save_info["tier_equal"] = b.tier_hash() == sim.tier_hash()
				G3TestUtil.remove_temp(path)
			var run: Dictionary = {
				"run": run_idx + 1,
				"frames_info": frame_info,
				"stats": stats,
				"state": summary["state"],
				"event": summary["event"],
				"tier": summary["tier"],
				"alive": summary["alive"],
				"detail": summary["detail"],
				"keys": summary["keys"],
				"tier_stats": summary["tier_stats"],
				"detail_stats": summary["detail_stats"],
				"background_stats": summary["background_stats"],
				"memory": mem,
				"engine_static_before_bytes": before_mem,
				"engine_static_after_bytes": OS.get_static_memory_usage(),
				"save": save_info,
			}
			scenario["runs"].append(run)
			print("G3_B_BENCH detail=%d speed=%d run=%d frames=%d events_frame=%.1f p50=%.3f p95=%.3f p99=%.3f max=%.3f speed=%.1fx save=%dB" % [
				detail, speed, run_idx + 1, int(stats["frames"]),
				float(stats["events_per_frame"]), float(stats["frame_p50_ms"]),
				float(stats["frame_p95_ms"]), float(stats["frame_p99_ms"]),
				float(stats["frame_max_ms"]), float(stats["actual_speed_factor"]),
				int(save_info.get("bytes", 0))])
			sim = null
		combined["scenarios"].append(scenario)
	combined["elapsed_s"] = float(Time.get_ticks_usec() - t_start) / 1000000.0
	var out_path: String = G3TestUtil.RESULT_DIR + "/g3_b_spike_results.json"
	var ok: bool = G3TestUtil.write_json(out_path, combined)
	print("G3_B_BENCH_WRITE %s ok=%s elapsed_s=%.1f" % [
		out_path, str(ok), float(combined["elapsed_s"])])
	if ok:
		print("G3_B_BENCH_DONE")
		get_tree().quit(0)
	else:
		printerr("G3_B_BENCH_WRITE_FAILED")
		get_tree().quit(1)
