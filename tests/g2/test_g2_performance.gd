extends RefCounted

## T-G2-06: 100@50x Performance, 5-Minuten-Fenster, 3 Läufe.

const VISUAL_RUNS: Array = [
	"res://bench/results/g2_visual_run1.json",
	"res://bench/results/g2_visual_run2.json",
	"res://bench/results/g2_visual_run3.json",
]


static func run(ctx: G1aTestContext) -> void:
	_test_headless_runs(ctx)
	_test_visual_runs(ctx)


static func _test_headless_runs(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-06a", "100@50x Sim-Slice: p95 <= 6 ms, 3 Läufe")
	var all_ok: bool = true
	for run_idx in 3:
		var sim: Simulation = G2TestUtil.new_sim(1337)
		var warm_frames: int = 1800
		var measure_frames: int = 18000
		for i in warm_frames:
			sim.advance_to(sim.clock.now + sim.config.path_frame_ticks)
		var samples: PackedFloat64Array = PackedFloat64Array()
		var events: int = 0
		for i in measure_frames:
			var t0: int = Time.get_ticks_usec()
			events += sim.advance_to(sim.clock.now + sim.config.path_frame_ticks)
			samples.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		var p50: float = G2TestUtil.percentile(samples, 0.50)
		var p95: float = G2TestUtil.percentile(samples, 0.95)
		var p99: float = G2TestUtil.percentile(samples, 0.99)
		var max_ms: float = G2TestUtil.percentile(samples, 1.0)
		var nav: Dictionary = sim.navigation_stats()
		var batch: Dictionary = sim.batch_stats()
		var ok: bool = p95 <= 6.0
		all_ok = all_ok and ok
		print("G2_PERF_HEADLESS run=%d frames=%d events=%d sim_p50=%.4f sim_p95=%.4f sim_p99=%.4f sim_max=%.4f events_frame=%.4f nav=%s batch=%s ok=%s" % [
			run_idx + 1, measure_frames, events, p50, p95, p99, max_ms,
			float(events) / float(measure_frames), str(nav), str(batch), str(ok)])
		ctx.check(ok, "Sim-p95 über 6 ms in Lauf %d: %.3f" % [run_idx + 1, p95])
		ctx.check(float(nav.get("cache_hit_rate", 0.0)) > 0.90,
			"Cache-Hit in Lauf %d <= 90 %%" % (run_idx + 1))
		ctx.check(int(nav.get("max_lookups_per_frame", 999)) <= 50,
			"Lookup-Budget in Lauf %d verletzt" % (run_idx + 1))
		ctx.check(int(nav.get("max_recalcs_per_frame", 999)) <= 2,
			"Recalc-Budget in Lauf %d verletzt" % (run_idx + 1))
	ctx.check(all_ok, "mindestens ein Headless-Lauf über Sim-p95")


static func _test_visual_runs(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-06b", "100@50x Gesamtframe/Render: p95 <= 16/6 ms, p99 <= 20 ms")
	var found: int = 0
	for path in VISUAL_RUNS:
		if not FileAccess.file_exists(path):
			ctx.check(false, "visueller Lauf fehlt: " + path)
			continue
		found += 1
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (data is Dictionary):
			ctx.check(false, "Visual-Ergebnis ist kein JSON-Objekt: " + path)
			continue
		var frame_p95: float = float(data.get("frame_p95_ms", 999.0))
		var frame_p99: float = float(data.get("frame_p99_ms", 999.0))
		var sim_p95: float = float(data.get("sim_p95_ms", 999.0))
		var render_p95: float = float(data.get("render_p95_ms", 999.0))
		var fps: float = float(data.get("fps_avg", 0.0))
		var sim_days: float = float(data.get("sim_days", 0.0))
		var agents: int = int(data.get("agents", 0))
		print("G2_PERF_VISUAL %s agents=%d frame_p95=%.2f frame_p99=%.2f sim_p95=%.3f render_p95=%.3f fps=%.1f sim_days=%.2f draw_avg=%.1f" % [
			path.get_file(), agents, frame_p95, frame_p99, sim_p95, render_p95,
			fps, sim_days, float(data.get("draw_calls_avg", 0.0))])
		ctx.check(agents == 100, "visueller Lauf nicht mit 100 Agenten: " + path)
		ctx.check_eq(int(data.get("speed", 0)), 50, "visueller Lauf nicht 50x")
		ctx.check(frame_p95 <= 16.0, "Frame-p95 über 16 ms: " + path)
		ctx.check(frame_p99 <= 20.0, "Frame-p99 über 20 ms: " + path)
		ctx.check(sim_p95 <= 6.0, "Sim-p95 über 6 ms: " + path)
		ctx.check(render_p95 <= 6.0, "Render-p95 über 6 ms: " + path)
		ctx.check(fps >= 55.0, "FPS unter 55: " + path)
		ctx.check(sim_days >= 15.5, "5-Minuten-Fenster deckt < 15,5 Sim-Tage ab: " + path)
	ctx.check_eq(found, 3, "nicht alle drei visuellen Läufe vorhanden")
