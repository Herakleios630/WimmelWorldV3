extends RefCounted

## T-G4b-09: 10k@50x, 5-Minuten-Fenster (18.000 Frames), p95/p99, 3 Läufe,
## inklusive Wirtschafts-/Politik-Tagesbatch-Diagnose.

const WARMUP_FRAMES: int = 1800
const MEASURE_FRAMES: int = 18000


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-09", "10k@50x p95 <= 16 ms, p99 <= 20 ms, 3 Läufe")
	var results: Array = []
	for run in 3:
		var r: Dictionary = _run_once(1337 + run)
		results.append(r)
		print("G4B_PERF run=%d p50=%.2f p95=%.2f p99=%.2f max=%.2f events_frame=%.1f over16=%d econ_avg_us=%d econ_max_us=%d" % [
			run + 1, r["p50"], r["p95"], r["p99"], r["max"],
			r["events_frame"], r["over16"], r["econ_avg_us"], r["econ_max_us"]])
		ctx.check(float(r["p95"]) <= 16.0,
			"Lauf %d p95 > 16 ms: %.2f" % [run + 1, r["p95"]])
		ctx.check(float(r["p99"]) <= 20.0,
			"Lauf %d p99 > 20 ms: %.2f" % [run + 1, r["p99"]])
		ctx.check(float(r["cache_hit"]) > 0.90,
			"Lauf %d Cache-Hit <= 90 %%: %.3f" % [run + 1, r["cache_hit"]])
		ctx.check(int(r["econ_batches"]) > 0,
			"Lauf %d ohne Wirtschafts-Tagesbatch" % [run + 1])
		ctx.check(int(r["econ_max_us"]) < 50000,
			"Lauf %d Economie-Batch >= 50 ms: %d us" % [
				run + 1, int(r["econ_max_us"])])
		ctx.check(float(r["p95"]) > 0.0, "keine Messwerte")
	G4BTestUtil.write_json("res://bench/results/g4b_perf_result.json", {
		"warmup_frames": WARMUP_FRAMES,
		"measure_frames": MEASURE_FRAMES,
		"runs": results,
	})


static func _run_once(seed_value: int) -> Dictionary:
	var sim: Simulation = G4BTestUtil.new_sim(seed_value)
	for i in WARMUP_FRAMES:
		sim.advance_to(sim.clock.now + sim.config.path_frame_ticks)
	var samples: PackedFloat64Array = PackedFloat64Array()
	var total_events: int = 0
	var over16: int = 0
	for i in MEASURE_FRAMES:
		var t0: int = Time.get_ticks_usec()
		total_events += sim.advance_to(sim.clock.now \
			+ sim.config.path_frame_ticks)
		samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		if samples[samples.size() - 1] > 16.0:
			over16 += 1
	var nav: Dictionary = sim.navigation_stats()
	var batch: Dictionary = sim.economy.batch_stats() if sim.economy != null else {}
	return {
		"p50": G4BTestUtil.percentile(samples, 0.50),
		"p95": G4BTestUtil.percentile(samples, 0.95),
		"p99": G4BTestUtil.percentile(samples, 0.99),
		"max": G4BTestUtil.percentile(samples, 1.0),
		"events_frame": float(total_events) / float(MEASURE_FRAMES),
		"over16": over16,
		"cache_hit": float(nav.get("cache_hit_rate", 0.0)),
		"econ_batches": int(batch.get("batches", 0)),
		"econ_avg_us": int(batch.get("avg_us", 0)),
		"econ_max_us": int(batch.get("max_us", 0)),
		"nav": nav,
		"batch": batch,
	}
