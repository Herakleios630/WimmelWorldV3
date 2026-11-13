extends RefCounted

## G1b-Schritt 2: T-LIFE-01..06.
## Alterung, Mortalität/Demografie-Kohorte, Partnerschaft, Geburt, Tod,
## Haushaltsauflösung. Headless und deterministisch.

const Demography = preload("res://tests/g1b/demography.gd")


static func run(ctx: G1aTestContext) -> void:
	_test_aging(ctx)
	_test_mortality_and_cohort(ctx)
	_test_partnership(ctx)
	_test_birth(ctx)
	_test_death(ctx)
	_test_household_dissolution(ctx)


static func _base_config() -> SimConfig:
	var config: SimConfig = SimConfig.new()
	config.mortality_age_0_4 = 0.0
	config.mortality_age_5_14 = 0.0
	config.mortality_age_15_29 = 0.0
	config.mortality_age_30_39 = 0.0
	config.mortality_age_40_49 = 0.0
	config.mortality_age_50_64 = 0.0
	config.mortality_age_65_79 = 0.0
	config.mortality_age_80_plus = 0.0
	config.monthly_conception_chance = 0.0
	config.birth_death_chance = 0.0
	config.lifecycle_first_roll_day = 0
	config.lifecycle_roll_interval_days = 1
	config.lifecycle_rolls_per_year = 30
	return config


static func _advance(sim: Simulation, day: int, hour: int = 0, minute: int = 0,
		second: int = 1) -> void:
	sim.advance_to(day * SimConfig.TICKS_PER_DAY + hour * 3600 + minute * 60 + second)


static func _spawn(sim: Simulation, age: int, sex: int, household: int,
		home: int, name: String = "") -> int:
	var role: int = LifecycleRules.role_for_age(age)
	var point: Vector2 = sim.world.door_point(home)
	var birth_day: int = LifecycleRules.birth_day_for_age(age, sim.clock.day_index())
	var id: int = sim.store.spawn_agent(age, role, household, home, 0,
		AgentStore.JOB_NONE, point.x, point.y, sim.config.start_hunger,
		sim.config.start_energy, sim.config.start_social, sim.clock.now,
		sim.config.start_hygiene, sim.config.start_fun, sim.config.start_health,
		sex, birth_day)
	var use_name: String = name
	if use_name == "":
		use_name = LifecycleRules.name_for(sex, id)
	sim.records.append(AgentRecord.new(id, use_name, sex, age, role, household,
		home, 0, AgentStore.JOB_NONE, birth_day))
	var h: HouseholdRecord = sim.lifecycle.household_by_id(household)
	if h != null and h.is_active():
		sim.lifecycle._add_to_household_sorted(h, id)
	sim.request_wake_by_id(id, sim.clock.now + 1)
	return id


static func _events_of(sim: Simulation, type: int, agent_id: int = -1) -> Array:
	return G1aTestUtil.events_of(sim, type, agent_id)


static func _contains(values: PackedInt32Array, value: int) -> bool:
	for v in values:
		if v == value:
			return true
	return false


static func _test_aging(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-01", "Alterung: Kind/Jugend/Erwachsen/Alt und Rollenwechsel")
	var config: SimConfig = _base_config()
	var sim: Simulation = Simulation.create(config)
	ctx.check_eq(LifecycleRules.role_for_age(0), AgentStore.ROLE_CHILD, "Rolle 0")
	ctx.check_eq(LifecycleRules.role_for_age(12), AgentStore.ROLE_CHILD, "Rolle 12")
	ctx.check_eq(LifecycleRules.role_for_age(13), AgentStore.ROLE_YOUTH, "Rolle 13")
	ctx.check_eq(LifecycleRules.role_for_age(17), AgentStore.ROLE_YOUTH, "Rolle 17")
	ctx.check_eq(LifecycleRules.role_for_age(18), AgentStore.ROLE_ADULT, "Rolle 18")
	ctx.check_eq(LifecycleRules.role_for_age(59), AgentStore.ROLE_ADULT, "Rolle 59")
	ctx.check_eq(LifecycleRules.role_for_age(60), AgentStore.ROLE_OLD, "Rolle 60")
	_advance(sim, 30)
	var row_a7: int = sim.store.row_for_id(10)
	var row_c1: int = sim.store.row_for_id(3)
	var row_a5: int = sim.store.row_for_id(8)
	var row_a1: int = sim.store.row_for_id(1)
	ctx.check_eq(sim.store.age_years[row_a7], 18, "A7 nicht 18")
	ctx.check_eq(sim.store.age_years[row_c1], 13, "C1 nicht 13")
	ctx.check_eq(sim.store.age_years[row_a5], 71, "A5 nicht 71")
	ctx.check_eq(sim.store.age_years[row_a1], 39, "A1 nicht 39")
	ctx.check_eq(sim.store.role[row_a7], AgentStore.ROLE_ADULT, "A7 nicht erwachsen")
	ctx.check_eq(sim.store.role[row_c1], AgentStore.ROLE_YOUTH, "C1 nicht Jugend")
	ctx.check_eq(sim.store.role[row_a5], AgentStore.ROLE_OLD, "A5 nicht alt")
	ctx.check_eq(sim.store.job_kind[row_a7], AgentStore.JOB_FIELD,
		"A7 erhält keinen Erwachsenen-Job")
	ctx.check_eq(sim.store.job_kind[row_c1], AgentStore.JOB_WORKSHOP,
		"C1 erhält keinen Jugend-Job")
	var rec_a7: AgentRecord = AgentRecords.record_by_id(sim.records, 10)
	var rec_c1: AgentRecord = AgentRecords.record_by_id(sim.records, 3)
	ctx.check(rec_a7 != null and rec_a7.age_years == 18
		and rec_a7.role == AgentStore.ROLE_ADULT, "A7-Record nicht aktualisiert")
	ctx.check(rec_c1 != null and rec_c1.age_years == 13
		and rec_c1.role == AgentStore.ROLE_YOUTH, "C1-Record nicht aktualisiert")
	ctx.check(_events_of(sim, SimEvent.T_AGE_UP).size() >= 10,
		"keine Age-up-Events")
	ctx.check(_events_of(sim, SimEvent.T_ROLE_CHANGE, 10).size() >= 1,
		"kein Rollenwechsel bei A7")
	ctx.check(_events_of(sim, SimEvent.T_ROLE_CHANGE, 3).size() >= 1,
		"kein Rollenwechsel bei C1")
	# Der Rollen-Schedule wechselt tatsächlich: 13:00 ist für Erwachsene
	# Arbeit, für Jugend Lernen.
	ctx.check_eq(RoleSchedule.entry_at(AgentStore.ROLE_ADULT, 13 * 60)[2],
		AgentStore.ACT_WORK, "Erwachsenen-Schedule 13:00")
	ctx.check_eq(RoleSchedule.entry_at(AgentStore.ROLE_YOUTH, 13 * 60)[2],
		AgentStore.ACT_LEARN, "Jugend-Schedule 13:00")
	# Determinismus über zwei gleiche Läufe.
	var sim2: Simulation = Simulation.create(_base_config())
	_advance(sim2, 30)
	ctx.check_eq(sim2.state_hash(), sim.state_hash(), "Alterung nicht deterministisch")
	ctx.check_eq(sim2.event_hash(), sim.event_hash(), "Alterungs-Events nicht deterministisch")


static func _test_mortality_and_cohort(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-02", "Mortalität: Alters-/Health-Einfluss, 1.000er-Kohorte 100 Jahre/5 Seeds")
	var config: SimConfig = SimConfig.new()
	ctx.check(LifecycleRules.annual_death_rate(config, 70)
		> LifecycleRules.annual_death_rate(config, 30),
		"Alterssterblichkeit steigt nicht")
	ctx.check(LifecycleRules.monthly_death_chance(config, 30, 20.0)
		> LifecycleRules.monthly_death_chance(config, 30, 100.0),
		"Health senkt das Sterberisiko nicht")
	ctx.check(LifecycleRules.monthly_death_chance(config, 30, 5.0)
		>= config.health_critical_monthly_chance - 0.000001,
		"kritische Gesundheit ohne Mindestrisiko")
	ctx.check_eq(LifecycleRules.death_cause(config, 30, 5.0),
		LifecycleRules.CAUSE_HEALTH, "Todesursache bei kritischer Gesundheit")
	ctx.check_eq(LifecycleRules.death_cause(config, 30, 80.0),
		LifecycleRules.CAUSE_AGE, "Todesursache bei normaler Gesundheit")
	var det_a: Dictionary = Demography.run_cohort(1337, config)
	var det_b: Dictionary = Demography.run_cohort(1337, config)
	ctx.check_eq(int(det_a["births"]), int(det_b["births"]),
		"Kohorte nicht deterministisch (Geburten)")
	ctx.check_eq(int(det_a["deaths"]), int(det_b["deaths"]),
		"Kohorte nicht deterministisch (Tode)")
	ctx.check_eq(str(det_a["death_ages"]), str(det_b["death_ages"]),
		"Kohorte nicht deterministisch (Sterbealter)")
	var suite: Dictionary = Demography.run_suite(config)
	for cohort in suite["cohorts"]:
		print("G1B_DEMO " + Demography.summary_line(cohort))
	print("G1B_DEMO_AGG seeds=%d population=%d births=%d deaths=%d birth_deaths=%d median=%.1f before40=%.3f reach70=%.3f reach80=%.3f" % [
		int(suite["seeds"].size()), int(suite["population"]), int(suite["births"]),
		int(suite["deaths"]), int(suite["birth_deaths"]),
		float(suite["median_death_age"]), float(suite["died_before_40"]),
		float(suite["reached_70"]), float(suite["reached_80"])])
	ctx.check(int(suite["births"]) >= 500, "zu wenige Geburten: %d" % int(suite["births"]))
	ctx.check(int(suite["deaths"]) >= 500, "zu wenige Tode: %d" % int(suite["deaths"]))
	ctx.check(float(suite["median_death_age"]) >= 48.0
		and float(suite["median_death_age"]) <= 52.0,
		"Median-Sterbealter außerhalb 48-52: %.2f" % float(suite["median_death_age"]))
	ctx.check(float(suite["died_before_40"]) >= 0.25
		and float(suite["died_before_40"]) <= 0.35,
		"Anteil Tod vor 40 außerhalb 25-35%%: %.3f" % float(suite["died_before_40"]))
	ctx.check(float(suite["reached_70"]) >= 0.15
		and float(suite["reached_70"]) <= 0.25,
		"Anteil 70+ außerhalb 15-25%%: %.3f" % float(suite["reached_70"]))
	ctx.check(float(suite["reached_80"]) >= 0.05
		and float(suite["reached_80"]) <= 0.10,
		"Anteil 80+ außerhalb 5-10%%: %.3f" % float(suite["reached_80"]))
	ctx.check(Demography.meets_targets(suite), "Demografie-Ziele nicht erfüllt")


static func _test_partnership(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-03", "Partnerschaft: nur gültige Partner, deterministisch")
	var sim: Simulation = Simulation.create(_base_config())
	# A6 (id 9) ist ein unverpartnerter Erwachsener und würde sonst die erste
	# neue Frau binden. Ein Blocker-Paar isoliert den Testfall deterministisch.
	_spawn(sim, 30, LifecycleRules.SEX_FEMALE, 1, 1, "Blockerin")
	var male: int = _spawn(sim, 25, LifecycleRules.SEX_MALE, 1, 1, "Testmann")
	var female: int = _spawn(sim, 24, LifecycleRules.SEX_FEMALE, 1, 1, "Testfrau")
	var minor: int = _spawn(sim, 15, LifecycleRules.SEX_FEMALE, 1, 1, "Testkind")
	var male2: int = _spawn(sim, 30, LifecycleRules.SEX_MALE, 1, 1, "Testmann2")
	_advance(sim, 2)
	ctx.check_eq(sim.lifecycle.partner_of(male), female, "gültiges Paar nicht gebildet")
	ctx.check_eq(sim.lifecycle.partner_of(female), male, "Partner nicht symmetrisch")
	ctx.check_eq(sim.lifecycle.partner_of(11), 9, "A6/Blockerin nicht verpaart")
	ctx.check_eq(sim.lifecycle.partner_of(minor), 0, "Minderjährige wurde verpaart")
	ctx.check_eq(sim.lifecycle.partner_of(male2), 0, "unerwartete Zweitpartnerschaft")
	ctx.check(sim.partnerships_formed >= 2, "Partnerschafts-Zähler fehlt")
	ctx.check_eq(sim.lifecycle.partner_of(1), 2, "bestehende A1/A2-Partnerschaft verändert")
	ctx.check_eq(sim.lifecycle.partner_of(5), 6, "bestehende A3/A4-Partnerschaft verändert")
	# Determinismus über 3 identische Läufe.
	var pairs: PackedStringArray = PackedStringArray()
	for run_idx in 3:
		var repeat: Simulation = Simulation.create(_base_config())
		_spawn(repeat, 30, LifecycleRules.SEX_FEMALE, 1, 1, "Blockerin")
		var m: int = _spawn(repeat, 25, LifecycleRules.SEX_MALE, 1, 1, "Testmann")
		var f: int = _spawn(repeat, 24, LifecycleRules.SEX_FEMALE, 1, 1, "Testfrau")
		_spawn(repeat, 15, LifecycleRules.SEX_FEMALE, 1, 1, "Testkind")
		_spawn(repeat, 30, LifecycleRules.SEX_MALE, 1, 1, "Testmann2")
		_advance(repeat, 2)
		pairs.append("%d-%d" % [repeat.lifecycle.partner_of(m), repeat.lifecycle.partner_of(f)])
		ctx.check_eq(repeat.state_hash(), sim.state_hash(), "Partnerschaft nicht deterministisch")
	ctx.check(pairs[0] == pairs[1] and pairs[1] == pairs[2],
		"Partnerwahl über 3 Läufe nicht identisch: " + str(pairs))
	# Blutsverwandte Erwachsene werden nicht verpaart.
	var kin_sim: Simulation = Simulation.create(_base_config())
	_spawn(kin_sim, 30, LifecycleRules.SEX_FEMALE, 1, 1, "Blockerin")
	var kin_male: int = _spawn(kin_sim, 40, LifecycleRules.SEX_MALE, 1, 1, "Vater")
	var kin_female: int = _spawn(kin_sim, 20, LifecycleRules.SEX_FEMALE, 1, 1, "Tochter")
	kin_sim.lifecycle.add_relationship(RelationshipRecord.TYPE_PARENT, kin_male,
		kin_female, 90, 0)
	kin_sim.lifecycle.add_relationship(RelationshipRecord.TYPE_CHILD, kin_female,
		kin_male, 90, 0)
	_advance(kin_sim, 2)
	ctx.check_eq(kin_sim.lifecycle.partner_of(kin_male), 0,
		"Blutsverwandte wurden verpaart")
	ctx.check_eq(kin_sim.lifecycle.partner_of(kin_female), 0,
		"Blutsverwandte wurden verpaart (Kind)")
	# Save/Load nach Beziehungswechsel exakt.
	var path: String = G1aTestUtil.temp_path("g1b_partner")
	ctx.check(sim.save_to(path).get("ok", false), "Partnerschafts-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Partnerschafts-Load fehlgeschlagen")
	if loaded.get("ok", false):
		var other: Simulation = loaded["sim"]
		ctx.check_eq(other.state_hash(), sim.state_hash(), "Partnerschafts-Snapshot nicht exakt")
		ctx.check_eq(other.lifecycle.partner_of(male), female, "Partner nach Load verloren")
		_advance(sim, 5)
		_advance(other, 5)
		ctx.check_eq(other.state_hash(), sim.state_hash(), "Partnerschafts-Verlauf nach Load abweichend")
		ctx.check_eq(other.event_hash(), sim.event_hash(), "Partnerschafts-Events nach Load abweichend")
	G1aTestUtil.remove_temp(path)


static func _birth_config() -> SimConfig:
	var config: SimConfig = _base_config()
	config.monthly_conception_chance = 1.0
	config.pregnancy_ticks = 1
	return config


static func _test_birth(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-04", "Geburt: Schwangerschaft/Geburt deterministisch, Save-fähig")
	var sim: Simulation = Simulation.create(_birth_config())
	_advance(sim, 1)
	var row_a2: int = sim.store.row_for_id(2)
	var row_a4: int = sim.store.row_for_id(6)
	ctx.check_eq(sim.store.pregnant[row_a2], 1, "A2 nicht schwanger")
	ctx.check_eq(sim.store.pregnant[row_a4], 1, "A4 nicht schwanger")
	ctx.check(_events_of(sim, SimEvent.T_PREGNANCY).size() >= 2,
		"keine Schwangerschafts-Events")
	# Vor der Geburt speichern und exakt weiterlaufen.
	var path_pregnant: String = G1aTestUtil.temp_path("g1b_pregnant")
	ctx.check(sim.save_to(path_pregnant).get("ok", false), "Schwangerschafts-Save fehlgeschlagen")
	var loaded_pregnant: Dictionary = Simulation.load_from(path_pregnant)
	ctx.check(loaded_pregnant.get("ok", false), "Schwangerschafts-Load fehlgeschlagen")
	var twin: Simulation = null
	if loaded_pregnant.get("ok", false):
		twin = loaded_pregnant["sim"]
		ctx.check_eq(twin.state_hash(), sim.state_hash(), "Schwangerschafts-Snapshot nicht exakt")
	# Keine erneute Empfängnis im Geburtsmonat, damit die Geburt isoliert prüfbar ist.
	sim.config.monthly_conception_chance = 0.0
	if twin != null:
		twin.config.monthly_conception_chance = 0.0
	_advance(sim, 2)
	ctx.check_eq(sim.births, 2, "nicht genau zwei Geburten")
	ctx.check_eq(sim.store.count, 12, "Geburten erhöhen den Store nicht")
	ctx.check_eq(sim.records.size(), 12, "Geburten erzeugen keinen kalten Record")
	ctx.check_eq(_events_of(sim, SimEvent.T_BIRTH).size(), 2, "Geburts-Events fehlen")
	ctx.check_eq(sim.store.pregnant[row_a2], 0, "Schwangerschaft A2 nicht beendet")
	ctx.check_eq(sim.store.pregnant[row_a4], 0, "Schwangerschaft A4 nicht beendet")
	var child_a: int = 11
	var child_b: int = 12
	var rec_a: AgentRecord = AgentRecords.record_by_id(sim.records, child_a)
	var rec_b: AgentRecord = AgentRecords.record_by_id(sim.records, child_b)
	ctx.check(rec_a != null and rec_a.age_years == 0
		and rec_a.role == AgentStore.ROLE_CHILD, "Kind A nicht korrekt")
	ctx.check(rec_b != null and rec_b.age_years == 0
		and rec_b.role == AgentStore.ROLE_CHILD, "Kind B nicht korrekt")
	ctx.check(rec_a != null and (rec_a.household_id == 1 or rec_a.household_id == 2),
		"Kind A hat keinen Mutterhaushalt")
	ctx.check(rec_b != null and (rec_b.household_id == 1 or rec_b.household_id == 2),
		"Kind B hat keinen Mutterhaushalt")
	var parents_a: PackedInt32Array = _parent_ids(sim, child_a)
	var parents_b: PackedInt32Array = _parent_ids(sim, child_b)
	ctx.check(_contains(parents_a, 1) and _contains(parents_a, 2),
		"Elternbeziehungen für Kind A fehlen")
	ctx.check(_contains(parents_b, 5) and _contains(parents_b, 6),
		"Elternbeziehungen für Kind B fehlen")
	ctx.check_eq(sim.lifecycle.validate_households().size(), 0,
		"Geburt erzeugt inkonsistente Haushalte")
	# Save/Load nach der Geburt exakt.
	var path_born: String = G1aTestUtil.temp_path("g1b_born")
	ctx.check(sim.save_to(path_born).get("ok", false), "Geburts-Save fehlgeschlagen")
	var loaded_born: Dictionary = Simulation.load_from(path_born)
	ctx.check(loaded_born.get("ok", false), "Geburts-Load fehlgeschlagen")
	if loaded_born.get("ok", false):
		var born_sim: Simulation = loaded_born["sim"]
		ctx.check_eq(born_sim.state_hash(), sim.state_hash(), "Geburts-Snapshot nicht exakt")
		ctx.check_eq(born_sim.births, sim.births, "Geburtszähler nach Load")
	# Save/Load vor der Geburt: Verlauf bis nach der Geburt exakt.
	if twin != null:
		_advance(twin, 3)
		_advance(sim, 3)
		ctx.check_eq(twin.state_hash(), sim.state_hash(),
			"Verlauf vor Geburt nach Load abweichend")
		ctx.check_eq(twin.event_hash(), sim.event_hash(),
			"Geburts-Events nach Load abweichend")
		ctx.check_eq(twin.births, sim.births, "Geburtszähler nach Verlauf abweichend")
	# Geburtsrisiko: Mutter stirbt, Kind bleibt mit Elternbeziehungen bestehen.
	var risk_config: SimConfig = _birth_config()
	risk_config.birth_death_chance = 1.0
	var risk_sim: Simulation = Simulation.create(risk_config)
	_advance(risk_sim, 1)
	risk_sim.config.monthly_conception_chance = 0.0
	_advance(risk_sim, 2)
	ctx.check_eq(risk_sim.births, 2, "Geburtsrisiko verhindert Geburten")
	ctx.check_eq(risk_sim.store.alive[risk_sim.store.row_for_id(2)], 0,
		"Mutter A2 überlebt das Geburtsrisiko")
	ctx.check_eq(risk_sim.store.alive[risk_sim.store.row_for_id(6)], 0,
		"Mutter A4 überlebt das Geburtsrisiko")
	ctx.check_eq(risk_sim.store.death_cause[risk_sim.store.row_for_id(2)],
		LifecycleRules.CAUSE_BIRTH, "falsche Todesursache A2")
	ctx.check_eq(risk_sim.store.alive[risk_sim.store.row_for_id(11)], 1,
		"Kind A stirbt mit der Mutter")
	ctx.check_eq(risk_sim.store.alive[risk_sim.store.row_for_id(12)], 1,
		"Kind B stirbt mit der Mutter")
	ctx.check_eq(risk_sim.lifecycle.validate_households().size(), 0,
		"Geburtsrisiko erzeugt inkonsistente Haushalte")
	G1aTestUtil.remove_temp(path_pregnant)
	G1aTestUtil.remove_temp(path_born)


static func _parent_ids(sim: Simulation, child_id: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for relationship in sim.relationships:
		var rel: RelationshipRecord = relationship
		if rel.type == RelationshipRecord.TYPE_PARENT and rel.b_agent_id == child_id:
			out.append(rel.a_agent_id)
	return out


static func _test_death(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-05", "Tod: Zeitpunkt/Record, Scheduler stale, Haushalt aktualisiert")
	var sim: Simulation = Simulation.create(_base_config())
	var row: int = sim.store.row_for_id(10)
	var next_before: int = sim.store.next_event[row]
	ctx.check(row >= 0 and next_before > 0, "A10 nicht aktiv")
	var household: HouseholdRecord = sim.lifecycle.household_by_id(3)
	ctx.check(household != null and _contains(household.member_ids, 10),
		"A10 nicht im Haushalt")
	sim.lifecycle.kill_agent(10, LifecycleRules.CAUSE_AGE)
	ctx.check_eq(sim.store.alive[row], 0, "Toter Agent bleibt lebendig")
	ctx.check_eq(sim.store.row_for_id(10), row, "tote ID nicht mehr referenzierbar")
	ctx.check_eq(sim.store.death_day[row], 0, "Todestag falsch")
	ctx.check_eq(sim.store.death_cause[row], LifecycleRules.CAUSE_AGE, "Todesursache falsch")
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, 10)
	ctx.check(rec != null and rec.death_day == 0
		and rec.death_cause == LifecycleRules.CAUSE_AGE, "Cold-Record Tod fehlt")
	ctx.check_eq(_events_of(sim, SimEvent.T_DEATH, 10).size(), 1, "Todes-Event fehlt")
	var death_event_id: int = -1
	for event in sim.logs.debug_events:
		var de: SimEvent = event
		if de.agent_id == 10 and de.type == SimEvent.T_DEATH:
			death_event_id = de.id
			break
	ctx.check_eq(sim.deaths, 1, "Todeszähler falsch")
	ctx.check_eq(sim.count_alive(), 9, "Alive-Zähler falsch")
	ctx.check(not _contains(household.member_ids, 10), "Toter bleibt Haushaltsmitglied")
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_IDLE, "Toter bleibt aktiv")
	# Stale Scheduler-Wake wird ignoriert.
	var event_count_before: int = sim.logs.debug_events.size()
	_advance(sim, 2)
	var events_after: int = sim.logs.debug_events.size()
	ctx.check_eq(sim.store.alive[row], 0, "stale Wake erweckt Toten")
	ctx.check(events_after >= event_count_before, "Event-Log schrumpfte")
	var stale_event: bool = false
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.agent_id == 10 and e.type != SimEvent.T_DEATH and e.id > death_event_id:
			stale_event = true
	ctx.check(not stale_event, "Toter erzeugt nach dem Tod ein Event")
	# Natürlicher Alterstod: A5 (70) stirbt bei 100 % Jahresrisiko.
	var natural_config: SimConfig = _base_config()
	natural_config.mortality_age_65_79 = 1.0
	natural_config.lifecycle_rolls_per_year = 1
	var natural: Simulation = Simulation.create(natural_config)
	_advance(natural, 1)
	ctx.check_eq(natural.deaths, 1, "natürlicher Tod nicht genau einmal")
	ctx.check_eq(natural.store.alive[natural.store.row_for_id(8)], 0,
		"A5 nicht natürlich gestorben")
	ctx.check_eq(natural.store.alive[natural.store.row_for_id(9)], 1,
		"A6 stirbt unerwartet")
	ctx.check_eq(natural.store.alive[natural.store.row_for_id(7)], 1,
		"Kind C3 stirbt unerwartet")
	ctx.check_eq(natural.lifecycle.validate_households().size(), 0,
		"natürlicher Tod erzeugt inkonsistente Haushalte")
	# Save/Load nach Tod exakt.
	var path: String = G1aTestUtil.temp_path("g1b_death")
	ctx.check(natural.save_to(path).get("ok", false), "Todes-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Todes-Load fehlgeschlagen")
	if loaded.get("ok", false):
		var other: Simulation = loaded["sim"]
		ctx.check_eq(other.state_hash(), natural.state_hash(), "Todes-Snapshot nicht exakt")
		_advance(natural, 2)
		_advance(other, 2)
		ctx.check_eq(other.state_hash(), natural.state_hash(), "Todes-Verlauf nach Load abweichend")
		ctx.check_eq(other.event_hash(), natural.event_hash(), "Todes-Events nach Load abweichend")
	G1aTestUtil.remove_temp(path)


static func _test_household_dissolution(ctx: G1aTestContext) -> void:
	ctx.begin("T-LIFE-06", "Haushaltsauflösung: Minderjährige zugeordnet, kein Dangling")
	# Fall A: H2 verliert beide Erwachsenen. Ein zusätzliches Kind hat einen
	# lebenden Verwandten in H1; C3 hat keinen lebenden Verwandten.
	var sim: Simulation = Simulation.create(_base_config())
	var foster: int = _spawn(sim, 5, LifecycleRules.SEX_MALE, 2, 2, "Pflegekind")
	sim.lifecycle.add_relationship(RelationshipRecord.TYPE_PARENT, 1, foster, 90, 0)
	sim.lifecycle.add_relationship(RelationshipRecord.TYPE_CHILD, foster, 1, 90, 0)
	sim.lifecycle.kill_agent(5, LifecycleRules.CAUSE_AGE)
	ctx.check_eq(sim.lifecycle.household_by_id(2).is_active(), true,
		"H2 löst sich zu früh auf")
	sim.lifecycle.kill_agent(6, LifecycleRules.CAUSE_AGE)
	var h2: HouseholdRecord = sim.lifecycle.household_by_id(2)
	var h1: HouseholdRecord = sim.lifecycle.household_by_id(1)
	ctx.check(h2 != null and not h2.is_active(), "H2 nicht aufgelöst")
	ctx.check_eq(h2.member_ids.size(), 0, "aufgelöster H2 hat Mitglieder")
	ctx.check(_contains(h2.archived_member_ids, 7), "C3 fehlt im H2-Archiv")
	ctx.check(_contains(h2.archived_member_ids, foster), "Pflegekind fehlt im H2-Archiv")
	ctx.check_eq(sim.store.household_id[sim.store.row_for_id(foster)], 1,
		"Pflegekind nicht H1 zugeordnet")
	ctx.check(_contains(h1.member_ids, foster), "Pflegekind fehlt in H1")
	ctx.check_eq(sim.store.household_id[sim.store.row_for_id(7)], 0,
		"C3 hat keinen expliziten Nicht-Haushalt")
	ctx.check_eq(sim.store.alive[sim.store.row_for_id(7)], 1, "C3 ist gestorben")
	ctx.check_eq(sim.lifecycle.validate_households().size(), 0,
		"Fall A erzeugt Dangling-Referenzen")
	ctx.check(_events_of(sim, SimEvent.T_HOUSEHOLD_DISSOLVED, 0).size() >= 1,
		"kein Haushaltsauflösungs-Event")
	ctx.check(_events_of(sim, SimEvent.T_HOUSEHOLD_REASSIGN, foster).size() >= 1,
		"kein Zuordnungs-Event")
	ctx.check(_events_of(sim, SimEvent.T_HOUSEHOLD_WARD, 7).size() >= 1,
		"kein Ward-Event")
	# Save/Load nach Auflösung exakt.
	var path: String = G1aTestUtil.temp_path("g1b_household")
	ctx.check(sim.save_to(path).get("ok", false), "Haushalts-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Haushalts-Load fehlgeschlagen")
	if loaded.get("ok", false):
		var other: Simulation = loaded["sim"]
		ctx.check_eq(other.state_hash(), sim.state_hash(), "Haushalts-Snapshot nicht exakt")
		ctx.check_eq(other.lifecycle.validate_households().size(), 0,
			"Haushalte nach Load inkonsistent")
		_advance(sim, 3)
		_advance(other, 3)
		ctx.check_eq(other.state_hash(), sim.state_hash(),
			"Haushalts-Verlauf nach Load abweichend")
	# Fall B: H1 verliert beide Erwachsenen; C1/C2 haben keine lebenden
	# Verwandten und werden zu expliziten Nicht-Haushalten.
	var no_kin: Simulation = Simulation.create(_base_config())
	no_kin.lifecycle.kill_agent(1, LifecycleRules.CAUSE_AGE)
	ctx.check_eq(no_kin.lifecycle.household_by_id(1).is_active(), true,
		"H1 löst sich nach A1 zu früh auf")
	no_kin.lifecycle.kill_agent(2, LifecycleRules.CAUSE_AGE)
	var h1b: HouseholdRecord = no_kin.lifecycle.household_by_id(1)
	ctx.check(h1b != null and not h1b.is_active(), "H1 nicht aufgelöst")
	ctx.check_eq(no_kin.store.household_id[no_kin.store.row_for_id(3)], 0,
		"C1 nicht als Nicht-Haushalt markiert")
	ctx.check_eq(no_kin.store.household_id[no_kin.store.row_for_id(4)], 0,
		"C2 nicht als Nicht-Haushalt markiert")
	ctx.check_eq(no_kin.lifecycle.validate_households().size(), 0,
		"Fall B erzeugt Dangling-Referenzen")
	# Determinismus der Auflösung: zwei frische, identische Szenarien.
	var repeat_a: Simulation = Simulation.create(_base_config())
	var repeat_b: Simulation = Simulation.create(_base_config())
	for repeat in [repeat_a, repeat_b]:
		var foster2: int = _spawn(repeat, 5, LifecycleRules.SEX_MALE, 2, 2, "Pflegekind")
		repeat.lifecycle.add_relationship(RelationshipRecord.TYPE_PARENT, 1, foster2, 90, 0)
		repeat.lifecycle.add_relationship(RelationshipRecord.TYPE_CHILD, foster2, 1, 90, 0)
		repeat.lifecycle.kill_agent(5, LifecycleRules.CAUSE_AGE)
		repeat.lifecycle.kill_agent(6, LifecycleRules.CAUSE_AGE)
	ctx.check_eq(repeat_b.state_hash(), repeat_a.state_hash(),
		"Haushaltsauflösung nicht deterministisch")
	ctx.check_eq(repeat_b.event_hash(), repeat_a.event_hash(),
		"Haushaltsauflösungs-Events nicht deterministisch")
	G1aTestUtil.remove_temp(path)
