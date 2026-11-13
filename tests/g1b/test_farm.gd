extends RefCounted

## G1b-Schritt 1: voller Feldzyklus, Aussaat/Ernte, Jahresbilanz, 1 Sim-Jahr.


static func run(ctx: G1aTestContext) -> void:
	_test_field_cycle(ctx)
	_test_sowing_harvest_balance(ctx)
	_test_fallow_failure(ctx)
	_test_one_year(ctx)


static func _stage_events(sim: Simulation) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.type == SimEvent.T_FIELD_STAGE:
			out.append(int(e.data))
	return out


static func _run_chunked(sim: Simulation, target: int, chunk: int) -> void:
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + chunk))


static func _test_field_cycle(ctx: G1aTestContext) -> void:
	ctx.begin("T-FARM-01", "Feldzyklus vollständig und deterministisch")
	var expected: PackedInt32Array = PackedInt32Array([
		Building.FIELD_PLOWING, Building.FIELD_PLOWED, Building.FIELD_SOWING,
		Building.FIELD_SOWN, Building.FIELD_GROWING, Building.FIELD_RIPE,
		Building.FIELD_HARVESTING, Building.FIELD_FALLOW,
	])
	var sequences: Array = []
	var state_hashes: PackedStringArray = PackedStringArray()
	var event_hashes: PackedStringArray = PackedStringArray()
	var chunks: PackedInt32Array = PackedInt32Array([1, 3600, 86400 * 7])
	for run_idx in 3:
		var sim: Simulation = G1aTestUtil.new_sim()
		var target: int = G1aTestUtil.abs_time(7, 0, 0)
		_run_chunked(sim, target, chunks[run_idx])
		var seq: PackedInt32Array = _stage_events(sim)
		sequences.append(seq)
		state_hashes.append(HashUtil.hex(sim.state_hash()))
		event_hashes.append(HashUtil.hex(sim.event_hash()))
		if run_idx == 0:
			ctx.check(seq.size() >= expected.size(),
				"zu wenige Feldstufen im ersten Zyklus: %d" % seq.size())
			if seq.size() >= expected.size():
				for i in expected.size():
					ctx.check_eq(seq[i], expected[i],
						"Feldstufe %d falsch" % i)
			ctx.check(sim.harvests_completed >= 1, "keine Ernte im Zyklus")
	ctx.check(sequences[0] == sequences[1] and sequences[1] == sequences[2],
		"Feldstufen über 3 Läufe nicht identisch")
	ctx.check(state_hashes[0] == state_hashes[1] and state_hashes[1] == state_hashes[2],
		"State-Hashes über 3 Läufe nicht identisch")
	ctx.check(event_hashes[0] == event_hashes[1] and event_hashes[1] == event_hashes[2],
		"Event-Hashes über 3 Läufe nicht identisch")
	print("G1B_FARM_DETERMINISM state=%s event=%s stages=%s" % [
		state_hashes[0], event_hashes[0], str(sequences[0])])
	# Arbeit ist Fortschritt, kein Instant-Zustandswechsel.
	var probe: Simulation = G1aTestUtil.new_sim()
	probe.advance_to(G1aTestUtil.abs_time(0, 8, 5))
	var pf: Building = probe.world.building_by_id(WorldMap.B_FIELD)
	ctx.check_eq(pf.field_stage, Building.FIELD_PLOWING, "Arbeitsstart nicht PLOWING")
	probe.advance_to(G1aTestUtil.abs_time(0, 12, 31))
	ctx.check(pf.field_work_s > 0, "kein Pflug-Fortschritt nach dem Vormittag")
	ctx.check(pf.field_work_s < probe.config.field_plow_work_s,
		"Pflügen ist sofort fertig")
	ctx.check_eq(pf.field_stage, Building.FIELD_PLOWING,
		"Pflügen ist vorzeitig abgeschlossen")
	probe.advance_to(G1aTestUtil.abs_time(1, 12, 31))
	ctx.check_eq(pf.field_stage, Building.FIELD_GROWING, "Aussaat startet nicht")
	# Schema-2-Save/Load mitten im Feldzyklus (offener FIELD_TICK) ist exakt.
	var a: Simulation = G1aTestUtil.new_sim()
	a.advance_to(G1aTestUtil.abs_time(2, 12, 0))
	var save_path: String = G1aTestUtil.temp_path("g1b_field_cycle")
	ctx.check(a.save_to(save_path).get("ok", false), "Feldzyklus-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(save_path)
	ctx.check(loaded.get("ok", false), "Feldzyklus-Load fehlgeschlagen")
	if loaded.get("ok", false):
		var b: Simulation = loaded["sim"]
		ctx.check_eq(b.state_hash(), a.state_hash(), "Feldzyklus-Snapshot nicht exakt")
		_run_chunked(a, G1aTestUtil.abs_time(7, 18, 0), 600)
		_run_chunked(b, G1aTestUtil.abs_time(7, 18, 0), 17)
		ctx.check_eq(b.state_hash(), a.state_hash(),
			"Feldzyklus nach Load abweichend")
		ctx.check_eq(b.event_hash(), a.event_hash(),
			"Feldzyklus-Events nach Load abweichend")
		ctx.check_eq(b.grain_produced, a.grain_produced,
			"Ernte nach Load abweichend")
	G1aTestUtil.remove_temp(save_path)


static func _test_sowing_harvest_balance(ctx: G1aTestContext) -> void:
	ctx.begin("T-FARM-02", "Aussaat/Ernte: Jahresbilanz korrekt, kein stilles Auffüllen")
	var sim: Simulation = G1aTestUtil.new_sim()
	_run_chunked(sim, G1aTestUtil.abs_time(30, 6, 0), 1800)
	ctx.check_eq(sim.last_year_index, 0, "Jahresabschluss fehlt")
	ctx.check(sim.last_year_harvests >= 4,
		"zu wenige Ernten im Jahr: %d" % sim.last_year_harvests)
	ctx.check_eq(sim.last_year_grain_produced, sim.grain_produced,
		"Jahres-Produktion weicht von kumulativem Grain ab")
	ctx.check_eq(sim.last_year_end_grain, sim.last_year_start_grain
		+ sim.last_year_grain_produced
		- sim.last_year_meals_served * SimConfig.MEAL_GRAIN_COST,
		"Jahresbilanz inkonsistent")
	ctx.check(sim.last_year_end_grain > sim.last_year_start_grain,
		"Jahresbilanz nicht positiv")
	ctx.check_eq(sim.grain, sim.config.start_grain + sim.grain_produced
		- sim.meals_served * SimConfig.MEAL_GRAIN_COST,
		"Grain-Bilanz inkonsistent (stilles Auffüllen?)")
	ctx.check_eq(sim.grain_harvested,
		sim.harvests_completed * sim.config.field_harvest_yield,
		"Erntemenge passt nicht zu den Ernten")
	ctx.check_eq(G1aTestUtil.count_events(sim, SimEvent.T_FIELD_HARVEST),
		sim.harvests_completed, "Ernte-Events fehlen")
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_FIELD_SOWN)
		>= sim.harvests_completed, "Aussaat-Events fehlen")
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_YEAR_SUMMARY) >= 1,
		"kein Jahresbilanz-Event")
	ctx.check(sim.meals_served > 0, "keine Mahlzeiten im Jahr")
	ctx.check(sim.meals_skipped > 0, "anfängliche Knappheit nicht sichtbar")
	ctx.check(sim.grain >= 0, "Grain-Bestand negativ")
	print("G1B_YEAR year=%d harvests=%d start=%d produced=%d meals=%d skipped=%d end=%d grain=%d births=%d deaths=%d alive=%d health_a1=%.1f" % [
		sim.last_year_index, sim.last_year_harvests, sim.last_year_start_grain,
		sim.last_year_grain_produced, sim.last_year_meals_served,
		sim.last_year_meals_skipped, sim.last_year_end_grain, sim.grain,
		sim.births, sim.deaths, sim.count_alive(),
		sim.store.health[G1aTestUtil.row_of(sim, 1)]])
	var harvest_times: PackedStringArray = PackedStringArray()
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.type == SimEvent.T_FIELD_HARVEST:
			harvest_times.append(SimClock.new(e.time).time_string())
	print("G1B_HARVESTS " + "; ".join(harvest_times))
	print("G1B_FIELD_STAGES " + str(_stage_events(sim)))


static func _test_fallow_failure(ctx: G1aTestContext) -> void:
	ctx.begin("T-FARM-03", "Ernteausfall: Hunger/Health, Chronik; Ernte rettet")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.grain = 0
	var field: Building = sim.world.building_by_id(WorldMap.B_FIELD)
	field.field_stage = Building.FIELD_GROWING
	field.field_work_s = 0
	field.field_growth_end = sim.clock.now + 30 * SimConfig.TICKS_PER_DAY
	field.field_growth_gen = 0
	sim.advance_to(G1aTestUtil.abs_time(3, 6, 0))
	ctx.check_eq(sim.grain_produced, 0, "Grain ohne Ernte erzeugt")
	ctx.check_eq(sim.meals_served, 0, "Mahlzeit ohne Grain serviert")
	ctx.check(sim.meals_skipped >= 10, "Knappheit nicht sichtbar")
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_SHORTAGE) >= 1,
		"kein Shortage-Event")
	var row: int = G1aTestUtil.row_of(sim, 1)
	ctx.check(sim.store.health[row] < sim.config.start_health,
		"Gesundheit reagiert nicht auf den Ernteausfall")
	var chronicle_has_shortage: bool = false
	for event in sim.logs.chronicle_events:
		if (event as SimEvent).type == SimEvent.T_SHORTAGE:
			chronicle_has_shortage = true
	ctx.check(chronicle_has_shortage, "Shortage fehlt in der Chronik")
	# Reife erzwingen: die Arbeit erzeugt die Ernte, kein stilles Auffüllen.
	field.field_stage = Building.FIELD_RIPE
	field.field_work_s = 0
	sim.advance_to(G1aTestUtil.abs_time(3, 18, 31))
	ctx.check_eq(sim.grain_produced, sim.config.field_harvest_yield,
		"erzwungene Ernte liefert keinen Ertrag")
	ctx.check(sim.meals_served > 0, "Ernte ermöglicht keine Mahlzeit")
	ctx.check(sim.grain >= 0, "Grain-Bestand negativ")
	ctx.check_eq(sim.grain, sim.grain_produced
		- sim.meals_served * SimConfig.MEAL_GRAIN_COST,
		"Grain-Bilanz nach Ernte inkonsistent")
	var chronicle_has_harvest: bool = false
	for event in sim.logs.chronicle_events:
		if (event as SimEvent).type == SimEvent.T_FIELD_HARVEST:
			chronicle_has_harvest = true
	ctx.check(chronicle_has_harvest, "Ernte fehlt in der Chronik")


static func _test_one_year(ctx: G1aTestContext) -> void:
	ctx.begin("T-FARM-04", "1 Sim-Jahr: vier Jahreszeiten, mindestens ein Zyklus")
	var target: int = G1aTestUtil.abs_time(30, 6, 0)
	var chunked: Simulation = G1aTestUtil.new_sim()
	_run_chunked(chunked, target, 3600)
	var jumped: Simulation = G1aTestUtil.new_sim()
	jumped.advance_to(target)
	ctx.check_eq(chunked.clock.now, target, "1 Sim-Jahr endet nicht am Ziel")
	ctx.check_eq(chunked.day_index(), 30, "1 Sim-Jahr umfasst nicht 30 Tage")
	ctx.check_eq(chunked.state_hash(), jumped.state_hash(),
		"Jahreslauf ist nicht frame-/chunk-unabhängig")
	ctx.check_eq(chunked.event_hash(), jumped.event_hash(),
		"Jahres-Events sind nicht chunk-unabhängig")
	var seasons: PackedByteArray = PackedByteArray()
	seasons.resize(4)
	for day in SimConfig.YEAR_DAYS:
		var season: int = (day % SimConfig.YEAR_DAYS) * SimConfig.SEASONS / SimConfig.YEAR_DAYS
		seasons[season] = 1
	for season_idx in 4:
		ctx.check_eq(seasons[season_idx], 1, "Jahreszeit %d fehlt" % season_idx)
	var seq: PackedInt32Array = _stage_events(chunked)
	ctx.check(seq.size() >= 8, "kein vollständiger Feldzyklus im Jahr")
	ctx.check(chunked.harvests_completed >= 1, "keine Ernte im Jahr")
	ctx.check(chunked.last_year_index == 0, "Jahresabschluss fehlt")
	ctx.check(chunked.year_index == 1, "Jahr wird nicht fortgeschrieben")
	ctx.check(chunked.last_year_end_grain > 0, "Jahres-Endbestand nicht positiv")
	ctx.check(chunked.grain == chunked.config.start_grain + chunked.grain_produced
		- chunked.meals_served * SimConfig.MEAL_GRAIN_COST,
		"Grain-Bilanz im Jahr inkonsistent")
