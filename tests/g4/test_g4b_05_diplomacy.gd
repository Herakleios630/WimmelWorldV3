extends RefCounted

## T-G4b-05: zwei abstrakte Nachbarn, Relationen, Geschenke, Handelsabkommen.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-05", "Diplomatie/Verträge mit zwei Nachbarn")
	var sim: Simulation = G4BTestUtil.shared_year()
	var pol: PoliticsSystem = sim.politics
	ctx.check_eq(pol.nation.neighbors.size(), 2, "nicht zwei Nachbarn")
	for neighbor_v in pol.nation.neighbors:
		var neighbor: DiplomacyState = neighbor_v
		ctx.check(neighbor.name != "", "Nachbar ohne Namen")
		ctx.check(neighbor.relation >= -100 and neighbor.relation <= 100,
			"Relation außerhalb -100..100")
		ctx.check_eq(pol.has_trade_treaty(neighbor.neighbor_id),
			neighbor.has_trade_treaty(), "Vertragsstatus inkonsistent")
	ctx.check(pol.treaty_count > 0, "kein Handelsabkommen geschlossen")
	ctx.check(pol.gift_count > 0, "keine Geschenke")
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_TREATY),
		"kein Vertrags-Event in der Chronik")
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_GIFT),
		"kein Geschenk-Event in der Chronik")
	ctx.check(sim.config.treaty_tariff_permille < sim.config.tariff_permille,
		"Abkommen senkt Zoll nicht")
	# Relation verändert sich wöchentlich deterministisch.
	var sim2: Simulation = G4BTestUtil.new_sim(1340)
	var before: int = (sim2.politics.nation.neighbors[0] as DiplomacyState).relation
	G4BTestUtil.advance_chunked(sim2, sim2.clock.now + 7 * SimConfig.TICKS_PER_DAY, 3600)
	var after: int = (sim2.politics.nation.neighbors[0] as DiplomacyState).relation
	ctx.check(before != after, "Relation unverändert nach einer Woche")
	# Kein Krieg: Spannungen sind erlaubt, aber kein Kriegs-Event/Feature.
	var war_tokens: int = 0
	for path in ["res://src/politics/nation.gd",
			"res://src/politics/politics_system.gd",
			"res://src/politics/diplomacy_state.gd"]:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		for token in ["declare_war", "battle", "soldier", "army"]:
			if text.contains(token):
				war_tokens += 1
	ctx.check_eq(war_tokens, 0, "Kriegs-Feature in Politikmodulen")
	print("G4B_DIPLOMACY treaties=%d gifts=%d tensions=%d relations=%s" % [
		pol.treaty_count, pol.gift_count, pol.tension_count,
		str([(pol.nation.neighbors[0] as DiplomacyState).relation,
			(pol.nation.neighbors[1] as DiplomacyState).relation])])
