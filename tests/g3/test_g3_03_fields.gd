extends RefCounted

## T-G3-03: saisonale Felder, genau 40 Ernten im Herbst, 0 außerhalb.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-03", "40 Felder: Frühling säen, Herbst ernten, Winter Brache")
	var sim: Simulation = G3ATestUtil.shared_year(1337)
	var counts: PackedInt32Array = sim.harvest_season_counts
	ctx.check_eq(counts[0], 0, "Ernte im Frühling")
	ctx.check_eq(counts[1], 0, "Ernte im Sommer")
	ctx.check_eq(counts[2], 40, "nicht genau 40 Herbsternten")
	ctx.check_eq(counts[3], 0, "Ernte im Winter")
	ctx.check_eq(sim.harvests_completed, 40, "Erntezähler")
	ctx.check_eq(sim.world.field_ids().size(), 40, "Feldanzahl")
	var harvested: int = 0
	var unique: bool = true
	var all_fallow: bool = true
	var crop_year_ok: bool = true
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		if field == null:
			unique = false
			continue
		if field.field_harvested_year == 0:
			harvested += 1
		if field.field_crop_year != 0:
			crop_year_ok = false
		if field.field_stage != Building.FIELD_FALLOW:
			all_fallow = false
		if field.field_harvested_year == 0 and field.field_crop_year != 0:
			unique = false
	ctx.check_eq(harvested, 40, "nicht jedes Feld genau einmal geerntet")
	ctx.check(crop_year_ok, "Feld hat falsches Erntejahr")
	ctx.check(all_fallow, "Feld im Winter nicht Brache")
	ctx.check(unique, "Feld mehrfach im selben Jahr geerntet")
	ctx.check_eq(sim.grain_seed_used, 40000, "Saatgutverbrauch nicht 40x1000")
	ctx.check(sim.grain <= sim.config.granary_capacity, "Granary über Kapazität")
	var expected: int = sim.config.start_grain + sim.grain_harvested \
		- sim.grain_seed_used - sim.meals_served
	ctx.check_eq(sim.grain, expected, "Grain-Bilanz inkonsistent")
	ctx.check_eq(sim.grain_overflow, 0, "unerwarteter Granary-Overflow")
	ctx.check(sim.grain_harvested >= 400000, "Bruttoernte unter 400k")
	ctx.check(sim.meals_served > 0, "keine Mahlzeiten")
	# 360.000 Startgrain sind der Jahresvorrat: keine Massen-Skips, Bevölkerung
	# bleibt nahe 1.000 (nur normale Alters-/Health-Tode).
	ctx.check(sim.meals_skipped <= 5000,
		"zu viele Mahlzeiten-Skips im ersten Jahr: %d" % sim.meals_skipped)
	ctx.check(sim.count_alive() >= 900,
		"Bevölkerung zu stark gesunken: %d" % sim.count_alive())
	ctx.check(sim.grain >= 300000,
		"Jahresend-Grain zu niedrig: %d" % sim.grain)
	ctx.check(sim.grain <= sim.config.granary_capacity,
		"Granary-Kapazität gebrochen")
	# harvest_season_counts ist autoritativ und überlebt die Debug-Ringpflege:
	# 40 im Herbst, 0 in Frühling/Sommer/Winter.
	ctx.check_eq(sim.harvest_season_counts[2], sim.harvests_completed,
		"nicht alle Ernten im Herbst")
	print("G3_YEAR alive=%d grain=%d start=%d seed=%d harvested=%d meals=%d skipped=%d seasons=%s field_cycles=%d" % [
		sim.count_alive(), sim.grain, sim.config.start_grain, sim.grain_seed_used,
		sim.grain_harvested, sim.meals_served, sim.meals_skipped,
		str(sim.harvest_season_counts), sim.field_cycles_completed])
