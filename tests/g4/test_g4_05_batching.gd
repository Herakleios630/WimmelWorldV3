extends RefCounted

## T-G4a-05: Event-Batching, stabile (time, seq)-Ordnung.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-05", "Event-Batching und stabile Ordnung bei 10k")
	var target: int = SimConfig.TICKS_PER_DAY
	var a: Simulation = G4ATestUtil.new_sim(1337)
	var ev_a: int = G4ATestUtil.advance_chunked(a, target, 1)
	var b: Simulation = G4ATestUtil.new_sim(1337)
	var ev_b: int = G4ATestUtil.advance_chunked(b, target, 3600)
	ctx.check_eq(ev_a, ev_b, "Eventzahl chunkabhängig")
	ctx.check_eq(a.state_hash(), b.state_hash(), "State chunkabhängig")
	ctx.check_eq(a.event_hash(), b.event_hash(), "Event-Hash chunkabhängig")
	ctx.check_eq(a.curated_chronicle_hash(), b.curated_chronicle_hash(),
		"Chronik chunkabhängig")
	var sa: Dictionary = a.batch_stats()
	var sb: Dictionary = b.batch_stats()
	ctx.check_eq(int(sa["out_of_order"]), 0, "Batches ungeordnet (chunk 1)")
	ctx.check_eq(int(sb["out_of_order"]), 0, "Batches ungeordnet (chunk 3600)")
	ctx.check(int(sa["batches"]) > 0 and int(sb["batches"]) > 0,
		"keine Batches")
	ctx.check_eq(int(sa["batches"]), int(sb["batches"]),
		"Batch-Zahl chunkabhängig")
	ctx.check_eq(int(sa["events"]), int(sb["events"]),
		"Batch-Events chunkabhängig")
	ctx.check(int(a.suppressed_events_total) > 0,
		"Routine-Quellaggregation inaktiv")
	ctx.check(a.logs.recent_debug(1).size() > 0, "Debug-/Event-Log leer")
