extends RefCounted

## T-G4b-06: Knappheit, Preisspitze, Überschuldung, Unruhe als Chronik;
## kein Game Over und Cooldown gegen Event-Flut.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-06", "Krisen + Chronik ohne Game Over")
	var sim: Simulation = G4BTestUtil.new_sim(1341)
	G4BTestUtil.advance_chunked(sim, sim.clock.now + SimConfig.TICKS_PER_DAY, 3600)
	var eco: EconomySystem = sim.economy
	var pol: PoliticsSystem = sim.politics
	# Krisenbedingungen gezielt setzen (Testschnittstelle, keine UI-Aktion).
	sim.grain = 0
	eco.market.stock[Goods.GRAIN] = 0
	eco.market.price_milli[Goods.TOOL] = Goods.BASE_PRICE_MILLI[Goods.TOOL] * 4
	pol.nation.treasury = -1000
	pol.nation.tax_rate_permille = 250
	pol.unrest = 90
	eco.crisis_last_day.fill(EconomySystem.NO_CRISIS_DAY)
	eco.crisis_counts.fill(0)
	eco.crisis_active.fill(0)
	var day: int = sim.clock.day_index()
	eco.on_crisis_check(day, sim)
	for kind in EconomySystem.CRISIS_COUNT:
		ctx.check_eq(eco.crisis_counts[kind], 1,
			"Krise %d nicht ausgelöst" % kind)
		ctx.check_eq(eco.crisis_active[kind], 1,
			"Krise %d nicht aktiv" % kind)
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_CRISIS_SHORTAGE),
		"Knappheits-Event fehlt")
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_CRISIS_PRICE),
		"Preisspitzen-Event fehlt")
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_CRISIS_DEBT),
		"Überschuldungs-Event fehlt")
	ctx.check(G4BTestUtil.has_chronicle_type(sim, SimEvent.T_CRISIS_UNREST),
		"Unruhe-Event fehlt")
	# Cooldown: gleicher Tag erzeugt keine Duplikate.
	var before: PackedInt32Array = eco.crisis_counts.duplicate()
	eco.on_crisis_check(day, sim)
	for kind in EconomySystem.CRISIS_COUNT:
		ctx.check_eq(eco.crisis_counts[kind], before[kind],
			"Krisen-Cooldown greift nicht: %d" % kind)
	# Kein Game Over: Simulation und Bevölkerung bleiben handlungsfähig.
	ctx.check(sim.count_alive() > 0, "Bevölkerung nach Krise ausgestorben")
	ctx.check_eq(sim.clock.day_index(), day, "Sim-Zeit nach Krise verändert")
	G4BTestUtil.advance_chunked(sim, sim.clock.now + SimConfig.TICKS_PER_DAY, 3600)
	ctx.check(sim.clock.day_index() > day, "Simulation nach Krise blockiert")
	# Krisen sind major/notable, nicht routine.
	for event_v in sim.chronicle.all_events():
		var ce: ChronicleEvent = event_v
		if ce.type >= SimEvent.T_CRISIS_SHORTAGE \
				and ce.type <= SimEvent.T_CRISIS_UNREST:
			ctx.check(ce.importance >= SimEvent.IMPORTANCE_NOTABLE,
				"Krisen-Event routine")
	print("G4B_CRISIS counts=%s active=%s" % [
		str(eco.crisis_counts), str(eco.crisis_active)])
