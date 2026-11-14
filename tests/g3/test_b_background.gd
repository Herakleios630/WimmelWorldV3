extends RefCounted

## T-G3-B-03: background cohort cadence, individual key events, identity and
## key-event preservation.


static func run(ctx: G1aTestContext) -> void:
	_test_key_events(ctx)
	_test_cadence(ctx)


static func _test_key_events(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-03a", "Key-Events: Geburt/Tod/Ehe/Jobwechsel, Identitäten")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(sim, G3TestUtil.abs_time(5, 0, 0), 300)
	var keys: Dictionary = sim.key_stats()
	ctx.check(int(keys.get("births", 0)) > 0, "keine Geburten")
	ctx.check(int(keys.get("deaths", 0)) > 0, "keine Tode")
	ctx.check(int(keys.get("marriages", 0)) > 0, "keine Ehen")
	ctx.check(int(keys.get("job_changes", 0)) > 0, "keine Jobwechsel")
	var verify: Dictionary = sim.key_log.verify_identities(sim.records)
	ctx.check(verify.get("ok", false), "Key-Event-Identitäten verletzt: "
		+ str(verify.get("failures", [])))
	var alive: int = sim.count_alive()
	var births: int = int(keys.get("births", 0))
	var deaths: int = int(keys.get("deaths", 0))
	ctx.check_eq(alive, 100000 + births - deaths,
		"Bevölkerung passt nicht zu Geburten/Toden")
	var cohort_sum: int = 0
	for count in sim.records.cohort_counts:
		cohort_sum += count
	ctx.check_eq(cohort_sum, alive, "Kohortensumme != lebende Agenten")
	var pop_sum: int = 0
	for pop in sim.records.settlement_population:
		pop_sum += pop
	ctx.check_eq(pop_sum, alive, "Siedlungssumme != lebende Agenten")
	var bg: Dictionary = sim.background_stats()
	ctx.check_eq(int(bg.get("birth_events", 0)), births, "Geburtszähler abweichend")
	ctx.check_eq(int(bg.get("death_events", 0)), deaths, "Todeszähler abweichend")
	ctx.check_eq(int(bg.get("marriage_events", 0)), int(keys.get("marriages", 0)),
		"Ehezähler abweichend")
	ctx.check_eq(int(bg.get("job_change_events", 0)), int(keys.get("job_changes", 0)),
		"Jobwechselzähler abweichend")
	print("G3_B_KEY_EVENTS keys=%s alive=%d cohort_sum=%d" % [str(keys), alive, cohort_sum])


static func _test_cadence(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-03b", "Tages-/Wochen-Cadence pro Siedlung/Kohorte")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(sim, G3TestUtil.abs_time(5, 0, 0), 300)
	var bg: Dictionary = sim.background_stats()
	var batches: int = int(bg.get("batch_count", 0))
	var daily: int = int(bg.get("daily_batches", 0))
	var weekly: int = int(bg.get("weekly_batches", 0))
	ctx.check(batches >= 200 * 4, "zu wenige Siedlungsbatches: %d" % batches)
	ctx.check(batches <= 200 * 6, "zu viele Siedlungsbatches: %d" % batches)
	ctx.check_eq(daily, batches, "daily_batches != batch_count")
	ctx.check(weekly > 100 and weekly < 200, "Wochenbatches unplausibel: %d" % weekly)
	var min_last: int = 99
	for sid in sim.records.settlement_count:
		var last: int = sim.records.settlement_last_bg_day[sid]
		if last < min_last:
			min_last = last
	ctx.check(min_last >= 4, "nicht jede Siedlung wurde täglich verarbeitet: %d" % min_last)
	ctx.check(int(bg.get("weekly_batches", 0)) > 0, "keine Wochenbatches")
	print("G3_B_CADENCE batches=%d daily=%d weekly=%d min_last_day=%d" % [
		batches, daily, weekly, min_last])
