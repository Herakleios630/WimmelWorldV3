extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_hunger_interrupt(ctx)
	_test_energy_sleep(ctx)
	_test_social(ctx)
	_test_need_determinism(ctx)


static func _test_hunger_interrupt(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-01", "Hunger unterbricht Arbeit, Rückkehr zur Routine")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	var row: int = G1aTestUtil.row_of(sim, 1)
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_WORK, "A1 arbeitet um 10:00 nicht")
	var meals_before: int = sim.meals_served
	G1aTestUtil.set_need(sim, 1, NeedsModel.NEED_HUNGER, 90.0)
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 5))
	ctx.check(G1aTestUtil.count_events(sim, SimEvent.T_NEED_INTERRUPT, 1) >= 1,
		"kein Need-Interrupt geloggt")
	ctx.check(sim.store.activity[row] == AgentStore.ACT_TRAVEL \
		or sim.store.activity[row] == AgentStore.ACT_EAT,
		"Hunger hat die Arbeit nicht unterbrochen")
	sim.advance_to(G1aTestUtil.abs_time(0, 11, 0))
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_WORK,
		"keine Rückkehr zur Arbeit nach der Mahlzeit")
	var hunger_now: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HUNGER, sim.config)
	ctx.check(hunger_now < 70.0, "Mahlzeit hat Hunger nicht reduziert: %.1f" % hunger_now)
	ctx.check_eq(sim.meals_served, meals_before + 1,
		"Mahlzeit hat kein Grain verbraucht/serviert")


static func _test_energy_sleep(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-02", "Schlaffenster und Erholung korrekt")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 21, 30))
	var row: int = G1aTestUtil.row_of(sim, 1)
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_SLEEP, "A1 schläft um 21:30 nicht")
	var before: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_ENERGY, sim.config)
	sim.advance_to(G1aTestUtil.abs_time(1, 5, 30))
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_SLEEP, "A1 schläft um 05:30 nicht")
	var after: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_ENERGY, sim.config)
	var expected: float = minf(100.0, before + 80.0)
	ctx.check_close(after, expected, 1.5, "Schlaf-Erholung entspricht nicht +80/8h")
	sim.advance_to(G1aTestUtil.abs_time(1, 6, 1))
	ctx.check(sim.store.activity[row] != AgentStore.ACT_SLEEP,
		"A1 ist um 06:01 noch am Schlafen")
	ctx.check(NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_ENERGY, sim.config) >= 90.0, "Energie nach Nachtschlaf zu niedrig")
	ctx.check_eq(G1aTestUtil.count_events(sim, SimEvent.T_NAP_START), 0,
		"Routine-Tag erzeugt unerwartetes Nickerchen")


static func _test_social(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-03", "Sozialisieren erfüllt Need, kein Dauerloop")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	var row: int = G1aTestUtil.row_of(sim, 2)
	G1aTestUtil.set_need(sim, 2, NeedsModel.NEED_SOCIAL, 30.0)
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 0))
	var social_starts: Array = G1aTestUtil.events_of(sim, SimEvent.T_SOCIAL_START, 2)
	var need_social_starts: int = 0
	for event in social_starts:
		if (event as SimEvent).data == 1:
			need_social_starts += 1
	ctx.check_eq(need_social_starts, 1, "Sozial-Need startet nicht genau einmal")
	var social_now: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_SOCIAL, sim.config)
	ctx.check(social_now > 40.0, "Sozialisieren erfüllt Need nicht: %.1f" % social_now)


static func _test_need_determinism(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-04", "Need-Events über 3 Läufe identisch")
	var hashes: PackedStringArray = PackedStringArray()
	var event_hashes: PackedStringArray = PackedStringArray()
	var need_hashes: PackedStringArray = PackedStringArray()
	for run_idx in 3:
		var sim: Simulation = G1aTestUtil.new_sim()
		var target: int = G1aTestUtil.abs_time(0, 18, 0)
		while sim.clock.now < target:
			sim.advance_to(mini(target, sim.clock.now + 600))
		hashes.append(HashUtil.hex(sim.state_hash()))
		event_hashes.append(HashUtil.hex(sim.event_hash()))
		var h: int = HashUtil.FNV_OFFSET
		for row in sim.store.count:
			h = HashUtil.mix_f64(h, NeedsModel.value_at(sim.store, row, sim.clock.now,
				NeedsModel.NEED_HUNGER, sim.config))
			h = HashUtil.mix_f64(h, NeedsModel.value_at(sim.store, row, sim.clock.now,
				NeedsModel.NEED_ENERGY, sim.config))
			h = HashUtil.mix_f64(h, NeedsModel.value_at(sim.store, row, sim.clock.now,
				NeedsModel.NEED_SOCIAL, sim.config))
		need_hashes.append(HashUtil.hex(h))
	ctx.check(hashes[0] == hashes[1] and hashes[1] == hashes[2],
		"States über 3 Läufe nicht identisch: " + str(hashes))
	ctx.check(event_hashes[0] == event_hashes[1] and event_hashes[1] == event_hashes[2],
		"Need-Events über 3 Läufe nicht identisch: " + str(event_hashes))
	ctx.check(need_hashes[0] == need_hashes[1] and need_hashes[1] == need_hashes[2],
		"Need-Werte über 3 Läufe nicht identisch: " + str(need_hashes))

