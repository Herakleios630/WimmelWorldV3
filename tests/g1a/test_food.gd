extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_daily_work(ctx)
	_test_meal(ctx)
	_test_shortage(ctx)


static func _test_daily_work(ctx: G1aTestContext) -> void:
	ctx.begin("T-FOOD-01", "Tägliche Arbeit erzeugt Grain pro Arbeitstag")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 0))
	# 4 Feldarbeiter, je 3 volle Stunden am Vormittag = 12 Grain.
	ctx.check_eq(sim.grain_produced, 12, "Vormittags-Grain")
	ctx.check_eq(sim.meals_served, 10, "Frühstücksmahlzeiten")
	ctx.check_eq(sim.grain, 60 - 10 + 12, "Grain-Bestand um 12:00")
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 31))
	ctx.check_eq(sim.meals_served, 20, "Mittagsmahlzeiten nicht serviert")
	ctx.check_eq(sim.grain, 60 - 20 + 12, "Grain-Bestand nach Mittag")
	sim.advance_to(G1aTestUtil.abs_time(0, 16, 0))
	# Nachmittagsarbeit bis zum Energie-Nickerchen: weitere 3 h je Feldarbeiter.
	ctx.check_eq(sim.grain_produced, 24, "Tages-Grain nach Nachmittagsarbeit")
	ctx.check_eq(sim.grain, 60 - 20 + 24, "Tages-Grain-Bestand")


static func _test_meal(ctx: G1aTestContext) -> void:
	ctx.begin("T-FOOD-02", "Mahlzeit: Grain-Verbrauch und Hunger-Reset")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 29))
	var row: int = G1aTestUtil.row_of(sim, 1)
	var hunger_before: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HUNGER, sim.config)
	var meals_before: int = sim.meals_served
	var grain_before: int = sim.grain
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 31))
	var hunger_after: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HUNGER, sim.config)
	ctx.check_eq(sim.meals_served, meals_before + 10, "nicht 10 Mittagessen serviert")
	ctx.check_eq(sim.grain, grain_before - 10, "Grain-Verbrauch pro Mahlzeit falsch")
	ctx.check(hunger_before - hunger_after >= 45.0,
		"Hunger-Reset zu klein: before=%.1f after=%.1f" % [hunger_before, hunger_after])


static func _test_shortage(ctx: G1aTestContext) -> void:
	ctx.begin("T-FOOD-03", "Knappheit: kein stilles Auffüllen, Hunger reagiert")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.grain = 0
	# 08:30: Frühstück ist ausgefallen, Feldarbeit hat noch keinen Ertrag geliefert.
	sim.advance_to(G1aTestUtil.abs_time(0, 8, 30))
	ctx.check_eq(sim.grain, 0, "Grain wurde ohne Arbeit aufgefüllt")
	ctx.check_eq(sim.grain_produced, 0, "Grain ohne abgeschlossene Arbeit erzeugt")
	ctx.check_eq(sim.meals_served, 0, "Mahlzeit trotz leerem Speicher serviert")
	ctx.check(sim.meals_skipped >= 10, "Knappheit nicht pro Agent geloggt")
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_SHORTAGE) >= 1,
		"kein Shortage-Event")
	var row: int = G1aTestUtil.row_of(sim, 1)
	var hunger: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HUNGER, sim.config)
	ctx.check(hunger > 85.0, "Hunger reagiert nicht auf ausgefallene Mahlzeit: %.1f" % hunger)
	sim.advance_to(G1aTestUtil.abs_time(0, 13, 0))
	ctx.check(sim.grain_produced > 0, "keine Arbeit -> kein Grain erzeugt")
	ctx.check(sim.meals_served > 0, "erarbeiteter Grain ermöglicht keine Mahlzeit")
	ctx.check(sim.grain >= 0, "Grain-Bestand negativ")
	ctx.check_eq(sim.grain, sim.grain_produced + 0 - sim.meals_served * SimConfig.MEAL_GRAIN_COST,
		"Grain-Bilanz inkonsistent (stilles Auffüllen?)")

