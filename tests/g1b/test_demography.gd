extends RefCounted

## G1b-Schritt 2: T-BENCH-03 (G1b-Lauf) und T-BENCH-04 (Demografie).
## Der visuelle 1-Jahres-Lauf wird von tests/g1b/visual_year.tscn erzeugt.

const Demography = preload("res://tests/g1b/demography.gd")
const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")
const VISUAL_RESULT_PATH: String = "res://bench/results/g1b_year_result.json"


static func run(ctx: G1aTestContext) -> void:
	_test_g1b_year(ctx)
	_test_demography(ctx)


static func _featured_config() -> SimConfig:
	var config: SimConfig = SimConfig.new()
	config.seed = FeaturedSeed.FEATURED_SEED
	return config


static func _run_chunked(sim: Simulation, target: int, chunk: int) -> void:
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + chunk))


static func _test_g1b_year(ctx: G1aTestContext) -> void:
	ctx.begin("T-BENCH-03", "G1b-Lauf: 1 Sim-Jahr, Geburt + Tod, >= 50 % lebend")
	var sim: Simulation = Simulation.create(_featured_config())
	var target: int = 30 * SimConfig.TICKS_PER_DAY + 6 * 3600
	_run_chunked(sim, target, 3600)
	var alive: int = sim.count_alive()
	var initial_alive: int = 0
	for agent_id in range(1, 11):
		var row: int = sim.store.row_for_id(agent_id)
		if row >= 0 and sim.store.alive[row] != 0:
			initial_alive += 1
	print("G1B_YEAR_FEATURED seed=%d births=%d deaths=%d alive=%d initial_alive=%d grain=%d health_id8=%.1f households=%d" % [
		FeaturedSeed.FEATURED_SEED, sim.births, sim.deaths, alive, initial_alive, sim.grain,
		sim.store.health[sim.store.row_for_id(8)] if sim.store.row_for_id(8) >= 0 else -1.0,
		sim.households.size()])
	ctx.check_eq(sim.day_index(), 30, "Featured-Lauf umfasst kein Sim-Jahr")
	ctx.check(sim.births >= 1, "keine Geburt im Featured-Jahr")
	ctx.check(sim.deaths >= 1, "kein Tod im Featured-Jahr")
	ctx.check(alive >= 5, "weniger als 50 %% überleben: %d" % alive)
	ctx.check(initial_alive >= 5, "weniger als 50 %% der Startagenten überleben: %d" % initial_alive)
	var details: PackedStringArray = PackedStringArray()
	for event in sim.logs.chronicle_events:
		var e: SimEvent = event
		if e.type == SimEvent.T_BIRTH or e.type == SimEvent.T_DEATH:
			details.append("%s A%d Tag %d %s" % [
				SimEvent.type_name(e.type), e.agent_id,
				e.time / SimConfig.TICKS_PER_DAY + 1, e.text])
	print("G1B_FEATURED_EVENTS " + "; ".join(details))
	ctx.check(sim.grain >= 0, "Grain negativ")
	ctx.check_eq(sim.lifecycle.validate_households().size(), 0,
		"Featured-Jahr erzeugt inkonsistente Haushalte")
	ctx.check(_count_events(sim, SimEvent.T_BIRTH) == sim.births,
		"Geburts-Events passen nicht zum Zähler")
	ctx.check(_count_events(sim, SimEvent.T_DEATH) == sim.deaths,
		"Todes-Events passen nicht zum Zähler")
	var repeat: Simulation = Simulation.create(_featured_config())
	_run_chunked(repeat, target, 7)
	ctx.check_eq(repeat.state_hash(), sim.state_hash(),
		"Featured-Jahr nicht chunk-unabhängig")
	ctx.check_eq(repeat.event_hash(), sim.event_hash(),
		"Featured-Jahr-Events nicht chunk-unabhängig")
	# Der visuelle Lauf muss vor der Abnahme erzeugt worden sein.
	ctx.check(FileAccess.file_exists(VISUAL_RESULT_PATH),
		"visueller G1b-Jahreslauf fehlt; res://tests/g1b/visual_year.tscn ausführen")
	if FileAccess.file_exists(VISUAL_RESULT_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_RESULT_PATH))
		ctx.check(data is Dictionary, "G1b-Visual-Ergebnis ist kein JSON-Objekt")
		if data is Dictionary:
			print("G1B_VISUAL_YEAR " + JSON.stringify(data))
			ctx.check(bool(data.get("ok", false)), "visueller G1b-Jahreslauf nicht OK")
			ctx.check_eq(int(data.get("agents", 0)), 10, "visuell nicht 10 Agenten")
			ctx.check(float(data.get("sim_days", 0.0)) >= 29.5,
				"visueller Lauf deckt kein Sim-Jahr ab")
			ctx.check(int(data.get("births", 0)) >= 1, "keine sichtbare Geburt")
			ctx.check(int(data.get("deaths", 0)) >= 1, "kein sichtbarer Tod")
			ctx.check(int(data.get("alive", 0)) >= 5, "visuell < 50 % lebend")
			ctx.check(float(data.get("frame_p95_ms", 999.0)) <= 16.0,
				"visueller Frame p95 über 16 ms")


static func _test_demography(ctx: G1aTestContext) -> void:
	ctx.begin("T-BENCH-04", "Demografie: 1.000 Agenten, 100 Jahre, 5 Seeds, Zielverteilung")
	var config: SimConfig = SimConfig.new()
	var suite: Dictionary = Demography.run_suite(config)
	print("G1B_DEMO_BENCH " + Demography.summary_line({
		"seed": -1, "births": suite["births"], "deaths": suite["deaths"],
		"birth_deaths": suite["birth_deaths"],
		"median_death_age": suite["median_death_age"],
		"died_before_40": suite["died_before_40"],
		"reached_70": suite["reached_70"], "reached_80": suite["reached_80"],
		"censored": 0,
	}))
	ctx.check(Demography.meets_targets(suite), "Demografie-Zielverteilung nicht erfüllt")
	ctx.check(int(suite["births"]) >= 500, "Demografie: < 500 Geburten")
	ctx.check(int(suite["deaths"]) >= 500, "Demografie: < 500 Tode")
	ctx.check(float(suite["median_death_age"]) >= 48.0
		and float(suite["median_death_age"]) <= 52.0,
		"Demografie: Median außerhalb 48-52")


static func _count_events(sim: Simulation, type: int) -> int:
	var n: int = 0
	for event in sim.logs.debug_events:
		if (event as SimEvent).type == type:
			n += 1
	return n
