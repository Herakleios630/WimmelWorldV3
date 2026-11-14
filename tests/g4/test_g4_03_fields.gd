extends RefCounted

## T-G4a-03: 200 Herbsternten, 0 außerhalb, Jahresbilanz.

const EXPECTED_HARVESTS: int = 200


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-03", "200 Herbsternten, 0 außerhalb, Grain-Jahresbilanz")
	var sim: Simulation = G4ATestUtil.shared_year(1337)
	ctx.check_eq(sim.harvests_completed, EXPECTED_HARVESTS, "Erntezahl")
	ctx.check_eq(G4ATestUtil.year_harvest_count(sim), EXPECTED_HARVESTS,
		"Season-Erntesumme")
	ctx.check_eq(int(sim.harvest_season_counts[0]), 0, "Ernte im Frühling")
	ctx.check_eq(int(sim.harvest_season_counts[1]), 0, "Ernte im Sommer")
	ctx.check_eq(int(sim.harvest_season_counts[2]), EXPECTED_HARVESTS,
		"Ernte im Herbst")
	ctx.check_eq(int(sim.harvest_season_counts[3]), 0, "Ernte im Winter")
	ctx.check_eq(sim.grain_produced, EXPECTED_HARVESTS * 20000,
		"Bruttoproduktion")
	ctx.check_eq(sim.grain_harvested, EXPECTED_HARVESTS * 20000,
		"eingelagerte Ernte")
	ctx.check_eq(sim.grain_overflow, 0, "Granary-Überlauf")
	ctx.check_eq(sim.grain_seed_used, EXPECTED_HARVESTS * 2000, "Saatgut")
	var balance: int = sim.config.start_grain - sim.grain_seed_used \
		+ sim.grain_produced - sim.meals_served
	ctx.check_eq(sim.grain, balance, "Grain-Bilanz")
	ctx.check(sim.grain > 0, "Grain leer")
	ctx.check(sim.grain <= sim.config.granary_capacity, "Granary überschritten")
	ctx.check(sim.meals_served > 3500000, "zu wenige Mahlzeiten")
	ctx.check_eq(sim.meals_skipped, 0, "Mahlzeiten übersprungen")
	ctx.check_eq(sim.year_index, 1, "Jahr nicht abgeschlossen")
	var non_fallow: int = 0
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field != null and field.field_stage != Building.FIELD_FALLOW:
			non_fallow += 1
	ctx.check_eq(non_fallow, 0, "Felder nach der Ernte nicht brach")
	print("G4A_YEAR alive=%d grain=%d start=%d seed=%d harvested=%d meals=%d skipped=%d seasons=%s" % [
		sim.count_alive(), sim.grain, sim.config.start_grain,
		sim.grain_seed_used, sim.grain_harvested, sim.meals_served,
		sim.meals_skipped, str(sim.harvest_season_counts)])
