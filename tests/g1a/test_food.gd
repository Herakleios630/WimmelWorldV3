extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_daily_work(ctx)
	_test_meal(ctx)
	_test_shortage(ctx)


## W6b ersetzt die tägliche Grain-Erzeugung durch den vollen Feldzyklus.
## T-FOOD-01 prüft weiter die Kernzusage: Feldarbeit ist Fortschritt, Grain
## entsteht erst durch die Ernte, und die Bilanz bleibt exakt.
static func _test_daily_work(ctx: G1aTestContext) -> void:
	ctx.begin("T-FOOD-01", "Feldarbeit ist Fortschritt; Ernte erzeugt Grain")
	var sim: Simulation = G1aTestUtil.new_sim()
	var start_grain: int = sim.config.start_grain
	var field: Building = sim.world.building_by_id(WorldMap.B_FIELD)
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	ctx.check_eq(field.field_stage, Building.FIELD_PLOWING, "Feld pflügt um 10:00 nicht")
	ctx.check_eq(sim.grain_produced, 0, "Grain ohne Ernte erzeugt")
	# Der Vormittag liefert Fortschritt, aber noch keinen Abschluss der Stufe.
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 31))
	ctx.check_eq(field.field_stage, Building.FIELD_PLOWING,
		"Pflügen ist vorzeitig abgeschlossen")
	ctx.check(field.field_work_s > 0, "kein Pflug-Fortschritt um 12:31")
	ctx.check(field.field_work_s < sim.config.field_plow_work_s,
		"Pflügen ist sofort fertig")
	ctx.check_eq(sim.meals_served, 20, "Frühstück/Mittag nicht serviert")
	ctx.check_eq(sim.grain, start_grain - 20, "Grain-Bestand nach Mittag")
	sim.advance_to(G1aTestUtil.abs_time(0, 13, 30))
	ctx.check_eq(field.field_stage, Building.FIELD_PLOWING,
		"Feld verlässt PLOWING vor dem zweiten Arbeitsslot nicht")
	sim.advance_to(G1aTestUtil.abs_time(0, 17, 30))
	ctx.check_eq(field.field_stage, Building.FIELD_PLOWED,
		"Feld nicht gepflügt nach dem Nachmittag")
	ctx.check_eq(sim.grain_produced, 0, "Grain vor der Ernte erzeugt")
	ctx.check_eq(sim.meals_served, 20, "Abendessen vor 18:00 serviert")
	ctx.check_eq(sim.grain, start_grain - 20, "Grain-Bestand vor dem Abendessen")
	sim.advance_to(G1aTestUtil.abs_time(0, 18, 31))
	ctx.check_eq(sim.meals_served, 30, "Abendessen nicht vollständig serviert")
	ctx.check_eq(sim.meals_skipped, 0, "Mahlzeit ohne Knappheit übersprungen")
	ctx.check_eq(sim.grain, start_grain - 30, "Tages-Grain-Bestand")
	# Aussaat am Tag 1, Wachstum ist Kalenderzeit, erste Ernte an Tag 6.
	sim.advance_to(G1aTestUtil.abs_time(1, 12, 31))
	ctx.check_eq(field.field_stage, Building.FIELD_GROWING,
		"Aussaat/GROWING am Tag 1 nicht erreicht")
	sim.advance_to(G1aTestUtil.abs_time(6, 12, 31))
	ctx.check_eq(sim.grain_produced, sim.config.field_harvest_yield,
		"Ernte liefert nicht genau einen Feldernte-Ertrag")
	ctx.check_eq(sim.harvests_completed, 1, "Ernte nicht genau einmal abgeschlossen")
	ctx.check_eq(field.field_stage, Building.FIELD_FALLOW,
		"Feld nach der Ernte nicht FALLOW")
	ctx.check_eq(sim.grain, start_grain + sim.grain_produced - sim.meals_served,
		"Grain-Bilanz nach der ersten Ernte")


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
	ctx.begin("T-FOOD-03", "Knappheit: kein stilles Auffüllen, Hunger/Health reagieren")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.grain = 0
	# 08:30: Frühstück ist ausgefallen, der Feldzyklus hat noch keine Ernte
	# geliefert. Grain wird nicht aufgefüllt.
	sim.advance_to(G1aTestUtil.abs_time(0, 8, 30))
	ctx.check_eq(sim.grain, 0, "Grain wurde ohne Arbeit aufgefüllt")
	ctx.check_eq(sim.grain_produced, 0, "Grain ohne Ernte erzeugt")
	ctx.check_eq(sim.meals_served, 0, "Mahlzeit trotz leerem Speicher serviert")
	ctx.check(sim.meals_skipped >= 10, "Knappheit nicht pro Agent geloggt")
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_SHORTAGE) >= 1,
		"kein Shortage-Event")
	var row: int = G1aTestUtil.row_of(sim, 1)
	var hunger: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HUNGER, sim.config)
	ctx.check(hunger > 85.0, "Hunger reagiert nicht auf ausgefallene Mahlzeit: %.1f" % hunger)
	# Gesundheit ist ein langsamer Zustand und reagiert auf die Knappheit.
	sim.advance_to(G1aTestUtil.abs_time(1, 6, 0))
	var health: float = sim.store.health[row]
	ctx.check(health < sim.config.start_health,
		"Gesundheit reagiert nicht auf anhaltende Knappheit: %.1f" % health)
	ctx.check(health > sim.config.start_health - 24.0,
		"Gesundheit fällt nicht langsam: %.1f" % health)
	# Erst die Ernte (Tag 6) liefert wieder Grain; keine stille Auffüllung.
	sim.advance_to(G1aTestUtil.abs_time(6, 12, 31))
	ctx.check(sim.grain_produced > 0, "Ernte hat keinen Grain erzeugt")
	ctx.check(sim.meals_served > 0, "geernteter Grain ermöglicht keine Mahlzeit")
	ctx.check(sim.grain >= 0, "Grain-Bestand negativ")
	ctx.check_eq(sim.grain, sim.grain_produced
		- sim.meals_served * SimConfig.MEAL_GRAIN_COST,
		"Grain-Bilanz inkonsistent (stilles Auffüllen?)")

