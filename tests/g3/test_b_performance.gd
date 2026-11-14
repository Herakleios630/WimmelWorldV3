extends RefCounted

## T-G3-B-06: 100k @150x/200x, detail 1k/5k, measured results and a live smoke
## frame slice. Full measurements are produced by tests/g3/bench_b.tscn.

const RESULT_PATH: String = "res://bench/results/g3_b_spike_results.json"


static func run(ctx: G1aTestContext) -> void:
	_test_live_slice(ctx)
	_test_full_results(ctx)
	_test_no_leak(ctx)


static func _test_live_slice(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-06a", "Live 100k@150x Detail 1k: p95 <= 16 ms")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	sim.measure_costs = false
	G3TestUtil.advance_frames(sim, 0.5, false)
	sim.metrics.reset()
	sim.measure_costs = true
	var run: Dictionary = G3TestUtil.advance_frames(sim, 0.5, true)
	var stats: Dictionary = sim.metrics.stats(sim.config, sim.detail_count(), 0.5)
	ctx.check(int(run["frames"]) > 0, "Live-Slice ohne Frames")
	ctx.check(float(stats["events_per_frame"]) > 0.0, "Live-Slice ohne Events")
	ctx.check(float(stats["frame_p95_ms"]) <= 16.67,
		"Live-Slice p95 über 16 ms: %.3f" % float(stats["frame_p95_ms"]))
	ctx.check(sim.detail_count() == 1000, "Live-Slice Detail nicht 1000")
	print("G3_B_PERF_LIVE frames=%d events_frame=%.2f p50=%.3f p95=%.3f p99=%.3f max=%.3f speed=%.1fx" % [
		int(run["frames"]), float(stats["events_per_frame"]),
		float(stats["frame_p50_ms"]), float(stats["frame_p95_ms"]),
		float(stats["frame_p99_ms"]), float(stats["frame_max_ms"]),
		float(stats["actual_speed_factor"])])


static func _test_full_results(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-06b", "Vollmessung 150x/200x, Detail 1k/5k")
	var data: Dictionary = G3TestUtil.read_json(RESULT_PATH)
	if data.is_empty():
		_run_fallback(ctx)
		return
	ctx.check(data.get("ok", false), "Messdatei nicht ok")
	var scenarios: Array = data.get("scenarios", [])
	ctx.check_eq(scenarios.size(), 4, "nicht 4 Messszenarien")
	var seen: Dictionary = {}
	for scenario in scenarios:
		var detail: int = int(scenario.get("detail", 0))
		var speed: int = int(scenario.get("speed", 0))
		var key: String = "%d@%d" % [detail, speed]
		seen[key] = true
		var runs: Array = scenario.get("runs", [])
		ctx.check_eq(runs.size(), 3, "%s: nicht 3 Läufe" % key)
		var state_hashes: PackedStringArray = PackedStringArray()
		var event_hashes: PackedStringArray = PackedStringArray()
		var tier_hashes: PackedStringArray = PackedStringArray()
		for run in runs:
			var stats: Dictionary = run.get("stats", {})
			var keys: Dictionary = run.get("keys", {})
			var tier_stats: Dictionary = run.get("tier_stats", {})
			var memory: Dictionary = run.get("memory", {})
			state_hashes.append(str(run.get("state", "")))
			event_hashes.append(str(run.get("event", "")))
			tier_hashes.append(str(run.get("tier", "")))
			ctx.check(int(stats.get("frames", 0)) > 0, "%s: keine Frames" % key)
			ctx.check(float(stats.get("events_per_frame", 0.0)) > 0.0,
				"%s: keine Events/Frame" % key)
			ctx.check(float(stats.get("frame_p95_ms", 999.0)) <= 16.67,
				"%s: p95 über 16 ms (%.3f)" % [key, float(stats.get("frame_p95_ms", 999.0))])
			ctx.check(float(stats.get("sustainable_speed_at_p95", 0.0)) >= float(speed),
				"%s: Speed bei p95 unter Ziel" % key)
			ctx.check(int(tier_stats.get("detail_actual", 0)) == detail,
				"%s: Detailgröße nicht %d" % [key, detail])
			ctx.check(int(keys.get("total", 0)) > 0, "%s: keine Key-Events" % key)
			ctx.check(int(keys.get("births", 0)) > 0, "%s: keine Geburten" % key)
			ctx.check(int(keys.get("deaths", 0)) > 0, "%s: keine Tode" % key)
			ctx.check(int(memory.get("total_bytes", 0)) > 0, "%s: keine Speichermessung" % key)
			ctx.check(int(memory.get("records_bytes", 0)) > 10000000,
				"%s: Record-Speicher unplausibel" % key)
		ctx.check(state_hashes[0] == state_hashes[1]
			and state_hashes[1] == state_hashes[2], "%s: States nicht identisch" % key)
		ctx.check(event_hashes[0] == event_hashes[1]
			and event_hashes[1] == event_hashes[2], "%s: Events nicht identisch" % key)
		ctx.check(tier_hashes[0] == tier_hashes[1]
			and tier_hashes[1] == tier_hashes[2], "%s: Tier nicht identisch" % key)
		var first: Dictionary = runs[0]
		var save: Dictionary = first.get("save", {})
		ctx.check(save.get("ok", false), "%s: Save fehlgeschlagen" % key)
		ctx.check(save.get("state_equal", false), "%s: Save-State nicht exakt" % key)
		ctx.check(save.get("event_equal", false), "%s: Save-Events nicht exakt" % key)
		ctx.check(save.get("tier_equal", false), "%s: Save-Tier nicht exakt" % key)
		print("G3_B_PERF %s p50=%.3f p95=%.3f p99=%.3f max=%.3f events_frame=%.1f speed=%.1fx save=%dB save_ms=%.1f load_ms=%.1f" % [
			key, float(first.get("stats", {}).get("frame_p50_ms", 0.0)),
			float(first.get("stats", {}).get("frame_p95_ms", 0.0)),
			float(first.get("stats", {}).get("frame_p99_ms", 0.0)),
			float(first.get("stats", {}).get("frame_max_ms", 0.0)),
			float(first.get("stats", {}).get("events_per_frame", 0.0)),
			float(first.get("stats", {}).get("actual_speed_factor", 0.0)),
			int(save.get("bytes", 0)), float(save.get("save_ms", 0.0)),
			float(save.get("load_ms", 0.0))])
	for key in ["1000@150", "5000@150", "1000@200", "5000@200"]:
		ctx.check(seen.has(key), "Messszenario fehlt: " + key)


static func _run_fallback(ctx: G1aTestContext) -> void:
	# Fresh clone without the ignored bench JSON: run a compact live proof for
	# all four scenarios instead of failing on the missing file.
	print("G3_B_PERF_FALLBACK " + RESULT_PATH + " fehlt, kompakte Live-Messung")
	for spec in [[1000, 150], [5000, 150], [1000, 200], [5000, 200]]:
		var detail: int = spec[0]
		var speed: int = spec[1]
		var sim: BSim = G3TestUtil.new_sim(detail, speed, G3TestUtil.SEED)
		sim.measure_costs = false
		G3TestUtil.advance_frames(sim, 0.5, false)
		sim.metrics.reset()
		sim.measure_costs = true
		var run: Dictionary = G3TestUtil.advance_frames(sim, 1.0, true)
		var stats: Dictionary = sim.metrics.stats(sim.config, sim.detail_count(), 1.0)
		ctx.check(int(run["frames"]) > 0, "Fallback %d@%d: keine Frames" % [detail, speed])
		ctx.check(float(stats["events_per_frame"]) > 0.0,
			"Fallback %d@%d: keine Events" % [detail, speed])
		ctx.check(float(stats["frame_p95_ms"]) <= 16.67,
			"Fallback %d@%d: p95 über 16 ms" % [detail, speed])
		ctx.check(sim.detail_count() == detail,
			"Fallback %d@%d: Detailgröße falsch" % [detail, speed])
		ctx.check(int(sim.key_stats().get("total", 0)) > 0,
			"Fallback %d@%d: keine Key-Events" % [detail, speed])
		print("G3_B_PERF_FALLBACK %d@%d p95=%.3f events_frame=%.1f speed=%.1fx" % [
			detail, speed, float(stats["frame_p95_ms"]),
			float(stats["events_per_frame"]), float(stats["actual_speed_factor"])])


static func _test_no_leak(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-06c", "Kein Leak bei wiederholtem Aufbau/Abbau")
	var before: int = OS.get_static_memory_usage()
	for i in 2:
		var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
		sim.advance_to(BConfig.TICKS_PER_DAY / 10)
		sim = null
	var after: int = OS.get_static_memory_usage()
	var delta: int = after - before
	ctx.check(delta <= 2 * 1024 * 1024,
		"Speicher wächst nach Freigabe um %d Bytes" % delta)
	print("G3_B_LEAK before=%d after=%d delta=%d" % [before, after, delta])
