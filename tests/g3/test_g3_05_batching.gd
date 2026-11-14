extends RefCounted

## T-G3-05: Event-Batching, stabile (time, seq)-Ordnung über Chunks.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-05", "Batching: Ordnung, Zähler, 80/3600/86400 identisch")
	var hashes: Array = []
	for chunk in [80, 3600, 86400]:
		var sim: Simulation = G3ATestUtil.new_sim(1337)
		var target: int = sim.clock.now + SimConfig.TICKS_PER_DAY
		G3ATestUtil.advance_chunked(sim, target, chunk)
		var batch: Dictionary = sim.batch_stats()
		ctx.check_eq(int(batch.get("out_of_order", 1)), 0,
			"Batchordnung bei Chunk %d" % chunk)
		ctx.check(int(batch.get("events", 0)) > 0, "keine Events bei Chunk %d" % chunk)
		ctx.check(int(batch.get("max_batch", 0)) <= 1000,
			"Batch > 1000 bei Chunk %d" % chunk)
		hashes.append([sim.state_hash(), sim.event_hash(),
			sim.curated_chronicle_hash()])
		print("G3_BATCH chunk=%d batch=%s" % [chunk, str(batch)])
	ctx.check_eq(hashes[0][0], hashes[1][0], "State-Hash Chunk 80 vs 3600")
	ctx.check_eq(hashes[0][0], hashes[2][0], "State-Hash Chunk 80 vs 86400")
	ctx.check_eq(hashes[0][1], hashes[1][1], "Event-Hash Chunk 80 vs 3600")
	ctx.check_eq(hashes[0][1], hashes[2][1], "Event-Hash Chunk 80 vs 86400")
	ctx.check_eq(hashes[0][2], hashes[1][2], "Chronik-Hash Chunk 80 vs 3600")
	ctx.check_eq(hashes[0][2], hashes[2][2], "Chronik-Hash Chunk 80 vs 86400")
