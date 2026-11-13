extends RefCounted

const VISUAL_RESULT_PATH: String = "res://bench/results/g1a_visual_result.json"


static func run(ctx: G1aTestContext) -> void:
	_test_three_runs(ctx)
	_test_headless_and_visual(ctx)


static func _test_three_runs(ctx: G1aTestContext) -> void:
	ctx.begin("T-BENCH-01", "3 G1a-Läufe, unterschiedliche Frame-Aufteilung")
	var state_hashes: PackedStringArray = PackedStringArray()
	var event_hashes: PackedStringArray = PackedStringArray()
	var chronicle_hashes: PackedStringArray = PackedStringArray()
	var seed_value: int = SimConfig.DEFAULT_SEED
	var chunk_sizes: PackedInt32Array = PackedInt32Array([1, 300, 86400])
	for run_idx in 3:
		var sim: Simulation = G1aTestUtil.new_sim()
		var target: int = sim.clock.now + SimConfig.TICKS_PER_DAY
		var chunk: int = chunk_sizes[run_idx]
		while sim.clock.now < target:
			sim.advance_to(mini(target, sim.clock.now + chunk))
		state_hashes.append(HashUtil.hex(sim.state_hash()))
		event_hashes.append(HashUtil.hex(sim.event_hash()))
		chronicle_hashes.append(HashUtil.hex(sim.chronicle_hash()))
		ctx.check_eq(sim.clock.now, target, "Lauf %d endet nicht am Zieltag" % run_idx)
		ctx.check(sim.grain >= 0, "Lauf %d hat negativen Grain" % run_idx)
		if run_idx == 0:
			print("G1A_DAY seed=%d events=%d grain=%d produced=%d meals=%d skipped=%d state=%s event=%s chronicle=%s" % [
				seed_value, sim.logs.debug_events.size(),
				sim.grain, sim.grain_produced, sim.meals_served, sim.meals_skipped,
				state_hashes[0], event_hashes[0], chronicle_hashes[0]])
	ctx.check(state_hashes[0] == state_hashes[1] and state_hashes[1] == state_hashes[2],
		"State-Hashes der 3 Läufe unterscheiden sich: " + str(state_hashes))
	ctx.check(event_hashes[0] == event_hashes[1] and event_hashes[1] == event_hashes[2],
		"Event-Hashes der 3 Läufe unterscheiden sich: " + str(event_hashes))
	ctx.check(chronicle_hashes[0] == chronicle_hashes[1] and chronicle_hashes[1] == chronicle_hashes[2],
		"Chronik-Hashes der 3 Läufe unterscheiden sich: " + str(chronicle_hashes))


static func _test_headless_and_visual(ctx: G1aTestContext) -> void:
	ctx.begin("T-BENCH-02", "Headless- und visuelle Messung dokumentiert")
	var sim: Simulation = G1aTestUtil.new_sim()
	var start: int = sim.clock.now
	var warmup: int = start + 1800
	while sim.clock.now < warmup:
		sim.advance_to(mini(warmup, sim.clock.now + 80))
	var target: int = warmup + SimConfig.TICKS_PER_DAY
	var samples: PackedInt64Array = PackedInt64Array()
	var events_total: int = 0
	var total_us: int = 0
	while sim.clock.now < target:
		var t0: int = Time.get_ticks_usec()
		var events: int = sim.advance_to(mini(target, sim.clock.now + 80))
		var elapsed: int = Time.get_ticks_usec() - t0
		samples.append(elapsed)
		total_us += elapsed
		events_total += events
	samples.sort()
	var p50: float = _percentile(samples, 0.50) / 1000.0
	var p95: float = _percentile(samples, 0.95) / 1000.0
	var p99: float = _percentile(samples, 0.99) / 1000.0
	var max_ms: float = float(samples[samples.size() - 1]) / 1000.0
	print("G1A_HEADLESS agents=10 frames=%d events=%d sim_p50_ms=%.4f sim_p95_ms=%.4f sim_p99_ms=%.4f sim_max_ms=%.4f events_per_frame=%.4f us_per_event=%.2f" % [
		samples.size(), events_total, p50, p95, p99, max_ms,
		float(events_total) / float(samples.size()),
		float(total_us) / maxf(1.0, float(events_total))])
	ctx.check(p95 <= 6.0, "Sim-Slice p95 über 6 ms: %.3f" % p95)
	ctx.check(samples.size() > 100, "zu wenige Messframes")
	ctx.check(FileAccess.file_exists(VISUAL_RESULT_PATH),
		"visueller Benchmark fehlt; res://tests/g1a/bench_visual.tscn ausführen")
	if FileAccess.file_exists(VISUAL_RESULT_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_RESULT_PATH))
		if data is Dictionary:
			var vp95: float = float(data.get("frame_p95_ms", 999.0))
			var vfps: float = float(data.get("fps_avg", 0.0))
			var vdays: float = float(data.get("sim_days", 0.0))
			print("G1A_VISUAL agents=%d frames=%d p50=%.2fms p95=%.2fms p99=%.2fms fps=%.1f sim_days=%.2f draw_calls_avg=%.1f draw_calls_max=%d" % [
				int(data.get("agents", 0)), int(data.get("frames", 0)),
				float(data.get("frame_p50_ms", 0.0)), vp95,
				float(data.get("frame_p99_ms", 0.0)), vfps, vdays,
				float(data.get("draw_calls_avg", 0.0)),
				int(data.get("draw_calls_max", 0))])
			ctx.check(vp95 <= 16.0, "visueller Frame p95 über 16 ms: %.2f" % vp95)
			ctx.check(vfps >= 55.0, "visuelle FPS zu niedrig: %.1f" % vfps)
			ctx.check(vdays > 0.5, "visueller Lauf zu kurz")
			ctx.check(int(data.get("agents", 0)) == 10, "visuell nicht 10 Agenten")
		else:
			ctx.check(false, "Visual-Ergebnis ist kein JSON-Objekt")


static func _percentile(sorted_values: PackedInt64Array, p: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var idx: int = int(round(float(sorted_values.size() - 1) * p))
	return float(sorted_values[idx])
