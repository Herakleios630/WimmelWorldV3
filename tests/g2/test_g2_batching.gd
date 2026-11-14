extends RefCounted

## T-G2-03: Event-Batching pro Sim-Zeit, stabile (time, seq)-Ordnung.


static func run(ctx: G1aTestContext) -> void:
	_test_batches(ctx)
	_test_order_across_chunks(ctx)
	_test_no_per_frame_sweep(ctx)


static func _test_batches(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-03a", "Batches: Ordnung, Größen, Zähler")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, sim.clock.now + 3 * SimConfig.TICKS_PER_DAY, 80)
	var stats: Dictionary = sim.batch_stats()
	ctx.check(int(stats.get("batches", 0)) > 0, "keine Batches")
	ctx.check(int(stats.get("events", 0)) > 0, "keine Events")
	ctx.check_eq(int(stats.get("out_of_order", 1)), 0, "Batch-Zeiten nicht monoton")
	var total: int = 0
	for size in sim.batcher.batch_sizes:
		total += size
	ctx.check_eq(total, int(stats.get("events", -1)), "Batch-Summe != Events")
	var max_batch: int = int(stats.get("max_batch", 9999))
	ctx.check(max_batch <= 200, "Batch zu groß: %d" % max_batch)
	ctx.check(float(stats.get("p95_batch", 999.0)) <= 200.0, "Batch-p95 zu groß")
	print("G2_BATCH stats=%s" % str(stats))


static func _test_order_across_chunks(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-03b", "Stabile Ordnung bei 3 unterschiedlichen Frame-Aufteilungen")
	var chunks: PackedInt32Array = PackedInt32Array([7, 300, 86400])
	var hashes: PackedStringArray = PackedStringArray()
	var batch_counts: PackedInt32Array = PackedInt32Array()
	var max_batches: PackedInt32Array = PackedInt32Array()
	for run_idx in chunks.size():
		var sim: Simulation = G2TestUtil.new_sim()
		var target: int = sim.clock.now + SimConfig.TICKS_PER_DAY
		G2TestUtil.advance_chunked(sim, target, chunks[run_idx])
		var stats: Dictionary = sim.batch_stats()
		hashes.append(HashUtil.hex(sim.event_hash()))
		batch_counts.append(int(stats.get("batches", 0)))
		max_batches.append(int(stats.get("max_batch", 0)))
		ctx.check_eq(int(stats.get("out_of_order", 1)), 0,
			"Ordnung in Lauf %d verletzt" % run_idx)
	ctx.check(hashes[0] == hashes[1] and hashes[1] == hashes[2],
		"Event-Hashes je Chunk unterschiedlich: " + str(hashes))
	ctx.check(batch_counts[0] == batch_counts[1] and batch_counts[1] == batch_counts[2],
		"Batch-Anzahl je Chunk unterschiedlich: " + str(batch_counts))
	ctx.check(max_batches[0] == max_batches[1] and max_batches[1] == max_batches[2],
		"Max-Batch je Chunk unterschiedlich: " + str(max_batches))


static func _test_no_per_frame_sweep(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-03c", "Kein Full-Agent-Sweep pro Frame")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(0, 12, 0), 80)
	var before: int = sim.logs.debug_events.size()
	var processed: int = 0
	for i in 20:
		processed += sim.advance_to(sim.clock.now)
	ctx.check_eq(processed, 0, "Advance ohne fällige Events verarbeitet Events")
	ctx.check_eq(sim.logs.debug_events.size(), before,
		"Advance ohne fällige Events erzeugt Log-Events")
	# Der Scheduler bleibt die einzige Event-Quelle; Lifecycle-Tagesprüfung
	# ist erlaubt und läuft als Tages-Event, nicht als Frame-Sweep.
	var source: String = FileAccess.get_file_as_string("res://src/agents/simulation.gd")
	ctx.check(source.contains("scheduler.peek_time"), "advance_to nutzt Scheduler nicht")
	ctx.check(source.contains("EVENT_DAY_TICK"), "Tages-Tick fehlt")
