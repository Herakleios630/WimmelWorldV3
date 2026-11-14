extends RefCounted

## G1b-Schritt 3: T-CHRON-01..05.
## Kuratierte Chronik: Taxonomie, Dedup, Retention, Kausalität,
## Fokusunabhängigkeit. Headless und deterministisch.

const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")


static func run(ctx: G1aTestContext) -> void:
	_test_taxonomy(ctx)
	_test_dedup(ctx)
	_test_retention(ctx)
	_test_causality(ctx)
	_test_focus_independence(ctx)


static func _advance_chunked(sim: Simulation, target: int, chunk: int) -> void:
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + chunk))


static func _event_ids(events: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for event in events:
		out.append(int(event["id"]))
	return out


static func _ingest(store: ChronicleStore, sim: Simulation, time_value: int,
		type: int, importance: int, agent_id: int, template: String,
		text: String, data: int) -> void:
	var event: SimEvent = SimEvent.new(0, time_value, type, importance,
		agent_id, template, text, data)
	store.ingest(event, sim)


static func _test_taxonomy(ctx: G1aTestContext) -> void:
	ctx.begin("T-CHRON-01", "Event-Taxonomie: Kategorien und Importance vorhanden")
	var sim: Simulation = G1aTestUtil.new_sim()
	for type_value in range(1, 37):
		var event: SimEvent = SimEvent.new(0, sim.clock.now, type_value,
			SimEvent.IMPORTANCE_NOTABLE, 1, "probe", "probe", 0)
		var meta: Dictionary = ChronicleCurator.classify(event)
		ctx.check(ChronicleCurator.ALL_CATEGORIES.has(str(meta["category"])),
			"unbekannte Kategorie für Typ %d: %s" % [type_value, str(meta["category"])])
		var importance: int = int(meta["importance"])
		ctx.check(importance >= SimEvent.IMPORTANCE_ROUTINE
			and importance <= SimEvent.IMPORTANCE_HISTORIC,
			"ungültige Importance für Typ %d" % type_value)
		ctx.check(str(meta["template_key"]) != "",
			"leerer Template-Key für Typ %d" % type_value)
	var store: ChronicleStore = ChronicleStore.new(sim.config)
	var t0: int = sim.clock.now
	_ingest(store, sim, t0, SimEvent.T_PARTNER_FORMED,
		SimEvent.IMPORTANCE_NOTABLE, 1, "partner_formed", "Partnerschaft", 2)
	_ingest(store, sim, t0 + 10, SimEvent.T_ROLE_CHANGE,
		SimEvent.IMPORTANCE_NOTABLE, 10, "role_change", "Rollenwechsel", 2)
	_ingest(store, sim, t0 + 20, SimEvent.T_FIELD_HARVEST,
		SimEvent.IMPORTANCE_MAJOR, 0, "field_harvest", "Ernte", 220)
	_ingest(store, sim, t0 + 30, SimEvent.T_SHORTAGE,
		SimEvent.IMPORTANCE_MAJOR, 1, "shortage", "Knappheit", 0)
	_ingest(store, sim, t0 + 40, SimEvent.T_BIRTH,
		SimEvent.IMPORTANCE_MAJOR, 1, "birth", "Geburt", 2)
	_ingest(store, sim, t0 + 50, SimEvent.T_YEAR_SUMMARY,
		SimEvent.IMPORTANCE_HISTORIC, 0, "year_summary", "Jahr 1", 0)
	_ingest(store, sim, t0 + 60, SimEvent.T_WORK_END,
		SimEvent.IMPORTANCE_NOTABLE, 1, "work_end", "Arbeit beendet", 0)
	var categories: Dictionary = {}
	var importances: Dictionary = {}
	for event in store.all_events():
		var ce: ChronicleEvent = event
		categories[ce.category] = true
		importances[ce.importance] = true
	for expected in [ChronicleCurator.CAT_LIFE, ChronicleCurator.CAT_SOCIAL,
			ChronicleCurator.CAT_WORK, ChronicleCurator.CAT_ECONOMY,
			ChronicleCurator.CAT_CRISIS]:
		ctx.check(categories.has(expected), "Kategorie fehlt: " + expected)
	for expected_imp in [SimEvent.IMPORTANCE_NOTABLE, SimEvent.IMPORTANCE_MAJOR,
			SimEvent.IMPORTANCE_HISTORIC]:
		ctx.check(importances.has(expected_imp),
			"Importance fehlt: %d" % expected_imp)
	ctx.check(store.routine_events >= 1, "Routine-Event wurde nicht aggregiert")
	for event in store.all_events():
		ctx.check((event as ChronicleEvent).importance >= SimEvent.IMPORTANCE_NOTABLE,
			"Routine-Event liegt einzeln in der Chronik")
	# Chronik-Panel-Filter: Agent, Importance, Zeitraum, Siedlung.
	var original_store: ChronicleStore = sim.chronicle
	sim.chronicle = store
	var by_agent: Array = ChroniclePanelModel.query(sim, {"agent_id": 1}, 50)
	ctx.check(by_agent.size() > 0, "Agent-Filter liefert keine Einträge")
	for entry in by_agent:
		ctx.check((entry["actor_ids"] as PackedInt32Array).has(1)
			or (entry["related_ids"] as PackedInt32Array).has(1),
			"Agent-Filter liefert fremden Eintrag")
	var by_major: Array = ChroniclePanelModel.query(sim,
		{"importance_min": SimEvent.IMPORTANCE_MAJOR}, 50)
	ctx.check(by_major.size() > 0, "Importance-Filter liefert keine Einträge")
	for entry in by_major:
		ctx.check(int(entry["importance"]) >= SimEvent.IMPORTANCE_MAJOR,
			"Importance-Filter liefert zu niedrige Wichtigkeit")
	var by_time: Array = ChroniclePanelModel.query(sim,
		{"from_time": t0 + 20, "to_time": t0 + 45}, 50)
	ctx.check(by_time.size() > 0, "Zeitraum-Filter liefert keine Einträge")
	for entry in by_time:
		ctx.check(int(entry["time"]) >= t0 + 20 and int(entry["time"]) < t0 + 45,
			"Zeitraum-Filter liefert fremden Zeitpunkt")
	var by_settlement: Array = ChroniclePanelModel.query(sim,
		{"settlement_id": 1}, 50)
	ctx.check_eq(by_settlement.size(), store.all_events().size(),
		"Siedlungsfilter verliert Einträge")
	ctx.check(BiographyModel.for_agent(sim, 1).size() > 0,
		"Basis-Biografie ist leer")
	sim.chronicle = original_store


static func _test_dedup(ctx: G1aTestContext) -> void:
	ctx.begin("T-CHRON-02", "Dedup: Ratio > 80 %, keine erfundene Ursache")
	var sim: Simulation = G1aTestUtil.new_sim()
	_advance_chunked(sim, G1aTestUtil.abs_time(3, 0, 0), 1800)
	var ratio: float = sim.chronicle.dedup_ratio()
	print("G1B_CHRON_DEDUP day=3 ingested=%d stored=%d routine=%d ratio=%.3f" % [
		sim.chronicle.ingested_total, sim.chronicle.stored_event_count(),
		sim.chronicle.routine_events, ratio])
	ctx.check(ratio > 0.80, "Dedup-Ratio nicht über 80 %%: %.3f" % ratio)
	for event in sim.chronicle.all_events():
		ctx.check((event as ChronicleEvent).importance >= SimEvent.IMPORTANCE_NOTABLE,
			"Routine-Event in der kuratierten Chronik")
	# Wiederholte Meal-Skips derselben Person/Tages werden zu einem Eintrag.
	var dedup_sim: Simulation = G1aTestUtil.new_sim()
	var store: ChronicleStore = ChronicleStore.new(dedup_sim.config)
	for i in 3:
		_ingest(store, dedup_sim, G1aTestUtil.abs_time(0, 10, i * 5),
			SimEvent.T_MEAL_SKIPPED, SimEvent.IMPORTANCE_NOTABLE, 1,
			"meal_skipped", "kein Grain", 0)
	ctx.check_eq(store.events.size(), 1, "Meal-Skips nicht dedupliziert")
	if store.events.size() == 1:
		ctx.check_eq((store.events[0] as ChronicleEvent).count, 3,
			"Dedup-Zähler falsch")
	# Mehrere Tode am selben Tag werden nicht zu einer erfundenen Seuche.
	var year_sim: Simulation = Simulation.create(_featured_config())
	_advance_chunked(year_sim, year_sim.clock.now + 30 * SimConfig.TICKS_PER_DAY, 3600)
	var death_count: int = 0
	for event in year_sim.chronicle.all_events():
		var ce: ChronicleEvent = event
		if ce.type != SimEvent.T_DEATH:
			continue
		death_count += 1
		var lower: String = ce.text.to_lower()
		ctx.check(not lower.contains("seuche") and not lower.contains("epidemie")
			and not lower.contains("unglück"),
			"Tod wurde mit erfundener Ursache aggregiert: " + ce.text)
	ctx.check_eq(death_count, year_sim.deaths,
		"Todes-Chronik passt nicht zum Todeszähler")
	ctx.check(_all_causes_resolve(year_sim.chronicle),
		"Kausalitätslink zeigt auf einen fehlenden Record")


static func _featured_config() -> SimConfig:
	var config: SimConfig = SimConfig.new()
	config.seed = FeaturedSeed.FEATURED_SEED
	return config


static func _all_causes_resolve(store: ChronicleStore) -> bool:
	for event in store.all_events():
		var ce: ChronicleEvent = event
		for cause in ce.causes:
			if store.resolve_event(int(cause)) == null:
				return false
	return true


static func _test_retention(ctx: G1aTestContext) -> void:
	ctx.begin("T-CHRON-03", "Retention: Budgets, Summaries, exakter Save/Load")
	var config: SimConfig = SimConfig.new()
	config.seed = SimConfig.DEFAULT_SEED
	config.chronicle_recent_days = 1
	config.chronicle_recent_max_events = 30
	config.chronicle_summary_days = 3
	config.chronicle_summary_max = 5
	config.chronicle_historic_max = 2
	var sim: Simulation = Simulation.create(config)
	_advance_chunked(sim, G1aTestUtil.abs_time(8, 0, 0), 3600)
	ctx.check(sim.chronicle.events.size() <= config.chronicle_recent_max_events,
		"Recent-Budget überschritten: %d" % sim.chronicle.events.size())
	var cutoff: int = (sim.clock.day_index() - config.chronicle_recent_days) \
		* SimConfig.TICKS_PER_DAY
	for event in sim.chronicle.events:
		ctx.check((event as ChronicleEvent).last_time >= cutoff,
			"Recent-Event älter als das Ringpuffer-Fenster")
	ctx.check(sim.chronicle.summaries.size() <= config.chronicle_summary_max,
		"Summary-Budget überschritten: %d" % sim.chronicle.summaries.size())
	for summary in sim.chronicle.summaries:
		var s: ChronicleSummary = summary
		ctx.check(s.day >= sim.clock.day_index() - config.chronicle_summary_days,
			"Summary älter als das Jahresfenster")
		ctx.check(s.lines.size() <= 7, "Tagesdigest über 7 Zeilen")
		if s.notable_count + s.major_count + s.historic_count + s.routine_count > 0:
			ctx.check(s.lines.size() >= 3, "aktiver Tagesdigest unter 3 Zeilen")
	ctx.check(sim.chronicle.historic.size() <= config.chronicle_historic_max,
		"Historic-Budget überschritten")
	var path: String = G1aTestUtil.temp_path("g1b_chronicle_retention")
	var before_hash: int = sim.curated_chronicle_hash()
	ctx.check(sim.save_to(path).get("ok", false), "Chronik-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Chronik-Load fehlgeschlagen")
	if loaded.get("ok", false):
		var other: Simulation = loaded["sim"]
		ctx.check_eq(other.curated_chronicle_hash(), before_hash,
			"Chronik-Snapshot nach Load nicht exakt")
		ctx.check_eq(other.state_hash(), sim.state_hash(),
			"State-Snapshot nach Chronik-Load nicht exakt")
		_advance_chunked(sim, G1aTestUtil.abs_time(10, 0, 0), 3600)
		_advance_chunked(other, G1aTestUtil.abs_time(10, 0, 0), 3600)
		ctx.check_eq(other.state_hash(), sim.state_hash(),
			"Verlauf nach Chronik-Load abweichend")
		ctx.check_eq(other.curated_chronicle_hash(), sim.curated_chronicle_hash(),
			"Chronik nach Load abweichend")
	G1aTestUtil.remove_temp(path)
	ctx.check(sim.chronicle.budget_info().has("events_recent_bytes"),
		"Budget-Report fehlt")


static func _test_causality(ctx: G1aTestContext) -> void:
	ctx.begin("T-CHRON-04", "Kausalität: Warum-Links vorhanden")
	var birth_config: SimConfig = SimConfig.new()
	birth_config.monthly_conception_chance = 1.0
	birth_config.pregnancy_ticks = 1
	birth_config.birth_death_chance = 0.0
	birth_config.lifecycle_first_roll_day = 0
	birth_config.lifecycle_roll_interval_days = 1
	birth_config.lifecycle_rolls_per_year = 30
	birth_config.mortality_age_0_4 = 0.0
	birth_config.mortality_age_5_14 = 0.0
	birth_config.mortality_age_15_29 = 0.0
	birth_config.mortality_age_30_39 = 0.0
	birth_config.mortality_age_40_49 = 0.0
	birth_config.mortality_age_50_64 = 0.0
	birth_config.mortality_age_65_79 = 0.0
	birth_config.mortality_age_80_plus = 0.0
	var birth_sim: Simulation = Simulation.create(birth_config)
	_advance_chunked(birth_sim, G1aTestUtil.abs_time(2, 0, 0), 3600)
	var birth: ChronicleEvent = _first_of_type(birth_sim.chronicle, SimEvent.T_BIRTH)
	ctx.check(birth != null, "keine Geburt für Kausalitätstest")
	if birth != null:
		ctx.check(birth.causes.size() > 0, "Geburt ohne Kausalitätslink")
		if birth.causes.size() > 0:
			var cause: ChronicleEvent = birth_sim.chronicle.resolve_event(birth.causes[0])
			ctx.check(cause != null and cause.type == SimEvent.T_PREGNANCY,
				"Geburtsursache ist keine Schwangerschaft")
	# Ernte verweist auf Reife/Aussaat.
	var farm_sim: Simulation = G1aTestUtil.new_sim()
	_advance_chunked(farm_sim, G1aTestUtil.abs_time(8, 0, 0), 3600)
	var harvest: ChronicleEvent = _first_of_type(farm_sim.chronicle,
		SimEvent.T_FIELD_HARVEST)
	ctx.check(harvest != null, "keine Ernte für Kausalitätstest")
	if harvest != null:
		ctx.check(harvest.causes.size() > 0, "Ernte ohne Kausalitätslink")
		if harvest.causes.size() > 0:
			var harvest_cause: ChronicleEvent = farm_sim.chronicle.resolve_event(
				harvest.causes[0])
			ctx.check(harvest_cause != null
				and (harvest_cause.type == SimEvent.T_FIELD_RIPE
					or harvest_cause.type == SimEvent.T_FIELD_SOWN),
				"Ernte-Ursache ist keine Reife/Aussaat")
	# Knappheit verweist auf die übersprungene Mahlzeit.
	var shortage_sim: Simulation = G1aTestUtil.new_sim()
	shortage_sim.grain = 0
	_advance_chunked(shortage_sim, G1aTestUtil.abs_time(2, 0, 0), 1800)
	var shortage: ChronicleEvent = _first_of_type(shortage_sim.chronicle,
		SimEvent.T_SHORTAGE)
	ctx.check(shortage != null, "keine Knappheit für Kausalitätstest")
	if shortage != null:
		ctx.check(shortage.causes.size() > 0, "Knappheit ohne Kausalitätslink")
		if shortage.causes.size() > 0:
			var shortage_cause: ChronicleEvent = shortage_sim.chronicle.resolve_event(
				shortage.causes[0])
			ctx.check(shortage_cause != null
				and shortage_cause.type == SimEvent.T_MEAL_SKIPPED,
				"Knappheitsursache ist keine übersprungene Mahlzeit")
	ctx.check(_all_causes_resolve(birth_sim.chronicle)
		and _all_causes_resolve(farm_sim.chronicle)
		and _all_causes_resolve(shortage_sim.chronicle),
		"Kausalitätslink ohne auflösbaren Record")


static func _first_of_type(store: ChronicleStore, type_value: int) -> ChronicleEvent:
	for event in store.all_events():
		if (event as ChronicleEvent).type == type_value:
			return event
	return null


static func _test_focus_independence(ctx: G1aTestContext) -> void:
	ctx.begin("T-CHRON-05", "Fokusunabhängigkeit: View-Fokus ändert keine Chronik-Events")
	var a: Simulation = G1aTestUtil.new_sim()
	var b: Simulation = G1aTestUtil.new_sim()
	var view_a: ViewState = ViewState.new()
	var view_b: ViewState = ViewState.new()
	view_a.camera_position = Vector2(64, 64)
	view_a.zoom = 1.0
	view_b.camera_position = Vector2(20, 90)
	view_b.zoom = 2.4
	view_b.follow_enabled = true
	view_b.follow_agent_id = 10
	var target: int = G1aTestUtil.abs_time(5, 0, 0)
	while a.clock.now < target:
		StoryOfDay.for_day(a.chronicle, a, a.clock.day_index(), 1)
		AlertModel.for_day(a.chronicle, a, a.clock.day_index())
		a.advance_to(mini(target, a.clock.now + 1800))
		StoryOfDay.for_day(b.chronicle, b, b.clock.day_index(), 10)
		AlertModel.for_day(b.chronicle, b, b.clock.day_index())
		b.advance_to(mini(target, b.clock.now + 1800))
	ctx.check_eq(a.state_hash(), b.state_hash(),
		"Fokuspfad verändert Sim-Zustand")
	ctx.check_eq(a.event_hash(), b.event_hash(),
		"Fokuspfad verändert Event-Log")
	ctx.check_eq(a.curated_chronicle_hash(), b.curated_chronicle_hash(),
		"Fokuspfad verändert Chronik-Events")
	var before: int = a.curated_chronicle_hash()
	var story1: Array = StoryOfDay.for_day(a.chronicle, a, 5, 1)
	var story2: Array = StoryOfDay.for_day(a.chronicle, a, 5, 1)
	ctx.check_eq(_event_ids(story1), _event_ids(story2),
		"Story of the Day nicht deterministisch bei festem Fokus")
	ctx.check(story1.size() <= 7, "Story of the Day über 7 Einträge")
	ctx.check_eq(a.curated_chronicle_hash(), before,
		"Story-Lesen verändert die Chronik")
