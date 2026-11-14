extends RefCounted

## T-G2-04: 30 Sim-Tage, drei Läufe mit unterschiedlicher Frame-Aufteilung.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-04", "30 Sim-Tage deterministisch, 3 Läufe")
	var chunks: PackedInt32Array = PackedInt32Array([80, 3600, 86400])
	var state_hashes: PackedStringArray = PackedStringArray()
	var event_hashes: PackedStringArray = PackedStringArray()
	var chronicle_hashes: PackedStringArray = PackedStringArray()
	var alive_counts: PackedInt32Array = PackedInt32Array()
	for run_idx in chunks.size():
		var sim: Simulation = G2TestUtil.new_sim(1337)
		var target: int = sim.clock.now + 30 * SimConfig.TICKS_PER_DAY
		var t0: int = Time.get_ticks_usec()
		G2TestUtil.advance_chunked(sim, target, chunks[run_idx])
		var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		state_hashes.append(HashUtil.hex(sim.state_hash()))
		event_hashes.append(HashUtil.hex(sim.event_hash()))
		chronicle_hashes.append(HashUtil.hex(sim.curated_chronicle_hash()))
		alive_counts.append(sim.count_alive())
		ctx.check_eq(sim.clock.now, target, "Lauf %d endet nicht am Zieltag" % run_idx)
		ctx.check(sim.count_alive() >= 80, "Bevölkerung bricht in Lauf %d ein" % run_idx)
		ctx.check_eq(int(sim.batch_stats().get("out_of_order", 1)), 0,
			"Batch-Ordnung in Lauf %d" % run_idx)
		print("G2_30D run=%d chunk=%d state=%s event=%s chronicle=%s alive=%d events=%d ms=%.1f" % [
			run_idx, chunks[run_idx], state_hashes[run_idx], event_hashes[run_idx],
			chronicle_hashes[run_idx], sim.count_alive(),
			int(sim.batch_stats().get("events", 0)), elapsed_ms])
	ctx.check(state_hashes[0] == state_hashes[1] and state_hashes[1] == state_hashes[2],
		"State-Hashes der 3 Läufe unterscheiden sich: " + str(state_hashes))
	ctx.check(event_hashes[0] == event_hashes[1] and event_hashes[1] == event_hashes[2],
		"Event-Hashes der 3 Läufe unterscheiden sich: " + str(event_hashes))
	ctx.check(chronicle_hashes[0] == chronicle_hashes[1]
		and chronicle_hashes[1] == chronicle_hashes[2],
		"Chronik-Hashes der 3 Läufe unterscheiden sich: " + str(chronicle_hashes))
	ctx.check(alive_counts[0] == alive_counts[1] and alive_counts[1] == alive_counts[2],
		"Alive-Zahlen unterscheiden sich")
