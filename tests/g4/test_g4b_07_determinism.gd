extends RefCounted

## T-G4b-07: 120 Sim-Tage deterministisch, 3 Läufe, Chunks 1/60/3600.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-07", "120 Tage deterministisch, 3 Läufe, Chunks 1/60/3600")
	if G4BTestUtil.year_hashes().size() >= 3:
		_verify_cached(ctx)
		return
	var chunks: Array = [1, 60, 3600]
	for i in chunks.size():
		var chunk: int = int(chunks[i])
		var sim: Simulation = G4BTestUtil.run_year_snapshot(1337, chunk, i + 1)
		print("G4B_120D run=%d chunk=%d state=%s event=%s chronicle=%s alive=%d caravans=%d treaties=%d crises=%d household_money=%d treasury=%d market_index=%d" % [
			i + 1, chunk, HashUtil.hex(sim.state_hash()),
			HashUtil.hex(sim.event_hash()),
			HashUtil.hex(sim.curated_chronicle_hash()), sim.count_alive(),
			sim.economy.caravans.completed_count, sim.politics.treaty_count,
			_crisis_total(sim), sim.economy.household_money_total(),
			sim.politics.nation.treasury,
			sim.economy.market.max_price_ratio_permille()])
	_verify_cached(ctx)


static func _crisis_total(sim: Simulation) -> int:
	var total: int = 0
	for value in sim.economy.crisis_counts:
		total += value
	return total


static func _verify_cached(ctx: G1aTestContext) -> void:
	var runs: Array = G4BTestUtil.year_hashes()
	ctx.check_eq(runs.size(), 3, "nicht drei 120-Tage-Läufe")
	if runs.size() != 3:
		return
	ctx.check_eq(runs[0]["state"], runs[1]["state"], "State Lauf 1 vs 2")
	ctx.check_eq(runs[0]["state"], runs[2]["state"], "State Lauf 1 vs 3")
	ctx.check_eq(runs[0]["event"], runs[1]["event"], "Event Lauf 1 vs 2")
	ctx.check_eq(runs[0]["event"], runs[2]["event"], "Event Lauf 1 vs 3")
	ctx.check_eq(runs[0]["chronicle"], runs[1]["chronicle"],
		"Chronik Lauf 1 vs 2")
	ctx.check_eq(runs[0]["chronicle"], runs[2]["chronicle"],
		"Chronik Lauf 1 vs 3")
	ctx.check(int(runs[0]["alive"]) > 0, "Bevölkerung ausgestorben")
	ctx.check(int(runs[0]["caravans"]) > 0, "keine abgeschlossene Karawane")
	ctx.check(int(runs[0]["treaties"]) > 0, "kein Handelsabkommen")
	var sim: Simulation = G4BTestUtil.shared_year(1337)
	ctx.check_eq(sim.year_index, 1, "Jahr 1 nicht abgeschlossen")
	ctx.check_eq(sim.harvests_completed, 200, "nicht 200 Ernten")
	ctx.check(sim.economy.household_money_total() > 0, "Haushaltsgeld fehlt")
	ctx.check(sim.politics.nation.treasury > 0, "Schatzkammer nicht positiv")
