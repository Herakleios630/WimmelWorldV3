extends RefCounted

## T-G3-B-04: determinism inside B over 3 runs and different advance_to chunks.


static func run(ctx: G1aTestContext) -> void:
	_test_three_runs_1k(ctx)
	_test_5k_chunks(ctx)


static func _test_three_runs_1k(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-04a", "2 Sim-Tage, 3 Läufe, Chunks 1/60/3600")
	var chunks: PackedInt32Array = PackedInt32Array([1, 60, 3600])
	var states: PackedStringArray = PackedStringArray()
	var events: PackedStringArray = PackedStringArray()
	var tiers: PackedStringArray = PackedStringArray()
	var alive: PackedInt32Array = PackedInt32Array()
	var detail: PackedInt32Array = PackedInt32Array()
	var key_hashes: PackedStringArray = PackedStringArray()
	var switch_counts: PackedInt32Array = PackedInt32Array()
	var out_of_order: int = 0
	for run_idx in chunks.size():
		var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
		var target: int = G3TestUtil.abs_time(2, 0, 0)
		G3TestUtil.advance_chunked(sim, target, chunks[run_idx])
		states.append(HashUtil.hex(sim.state_hash()))
		events.append(HashUtil.hex(sim.event_hash()))
		tiers.append(HashUtil.hex(sim.tier_hash()))
		alive.append(sim.count_alive())
		detail.append(sim.detail_count())
		key_hashes.append(HashUtil.hex(sim.key_log.state_hash()))
		switch_counts.append(sim.tier_selector.switch_count)
		out_of_order += int(sim.batch_stats().get("out_of_order", 0))
		print("G3_B_DET run=%d chunk=%d state=%s event=%s tier=%s alive=%d detail=%d keys=%s" % [
			run_idx + 1, chunks[run_idx], states[run_idx], events[run_idx],
			tiers[run_idx], alive[run_idx], detail[run_idx], key_hashes[run_idx]])
	ctx.check(states[0] == states[1] and states[1] == states[2],
		"State-Hashes unterscheiden sich: " + str(states))
	ctx.check(events[0] == events[1] and events[1] == events[2],
		"Event-Hashes unterscheiden sich: " + str(events))
	ctx.check(tiers[0] == tiers[1] and tiers[1] == tiers[2],
		"Tier-Hashes unterscheiden sich: " + str(tiers))
	ctx.check(key_hashes[0] == key_hashes[1] and key_hashes[1] == key_hashes[2],
		"Key-Log-Hashes unterscheiden sich")
	ctx.check(alive[0] == alive[1] and alive[1] == alive[2], "Alive-Zahlen unterscheiden sich")
	ctx.check(detail[0] == detail[1] and detail[1] == detail[2],
		"Detailgrößen unterscheiden sich")
	ctx.check(switch_counts[0] == switch_counts[1] and switch_counts[1] == switch_counts[2],
		"Tier-Wechselzahlen unterscheiden sich")
	ctx.check_eq(out_of_order, 0, "Batch-Ordnung verletzt")


static func _test_5k_chunks(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-04b", "5k-Detail, 2 Sim-Tage, Chunks 60/3600")
	var chunks: PackedInt32Array = PackedInt32Array([60, 3600])
	var states: PackedStringArray = PackedStringArray()
	var events: PackedStringArray = PackedStringArray()
	var tiers: PackedStringArray = PackedStringArray()
	var detail: PackedInt32Array = PackedInt32Array()
	for run_idx in chunks.size():
		var sim: BSim = G3TestUtil.new_sim(5000, 150, G3TestUtil.SEED)
		var target: int = G3TestUtil.abs_time(2, 0, 0)
		G3TestUtil.advance_chunked(sim, target, chunks[run_idx])
		states.append(HashUtil.hex(sim.state_hash()))
		events.append(HashUtil.hex(sim.event_hash()))
		tiers.append(HashUtil.hex(sim.tier_hash()))
		detail.append(sim.detail_count())
		print("G3_B_DET5K run=%d chunk=%d state=%s event=%s tier=%s detail=%d" % [
			run_idx + 1, chunks[run_idx], states[run_idx], events[run_idx],
			tiers[run_idx], detail[run_idx]])
	ctx.check_eq(states[0], states[1], "5k-State-Hashes unterscheiden sich")
	ctx.check_eq(events[0], events[1], "5k-Event-Hashes unterscheiden sich")
	ctx.check_eq(tiers[0], tiers[1], "5k-Tier-Hashes unterscheiden sich")
	ctx.check_eq(detail[0], 5000, "5k-Detail nicht 5000")
	ctx.check_eq(detail[1], 5000, "5k-Detail nicht 5000 (Chunk 3600)")
