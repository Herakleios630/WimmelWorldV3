extends RefCounted

## G1b-Schritt 1: Hygiene, Spaß und Gesundheit. Keine Krankheit/Gewalt/Tod.


static func run(ctx: G1aTestContext) -> void:
	_test_hygiene(ctx)
	_test_fun(ctx)
	_test_health(ctx)


static func _test_hygiene(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-05", "Hygiene: Waschen erfüllt Need; Health-Folge")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	G1aTestUtil.set_need(sim, 2, NeedsModel.NEED_HYGIENE, 20.0)
	sim.advance_to(G1aTestUtil.abs_time(0, 11, 30))
	var row: int = G1aTestUtil.row_of(sim, 2)
	var hygiene: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_HYGIENE, sim.config)
	ctx.check(hygiene > sim.config.hygiene_threshold,
		"Waschen erfüllt Hygiene nicht: %.1f" % hygiene)
	var wash_starts: int = 0
	var wash_ends: int = 0
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.agent_id != 2:
			continue
		if e.type == SimEvent.T_ACTIVITY_START and e.data == AgentStore.ACT_HYGIENE:
			wash_starts += 1
		elif e.type == SimEvent.T_ACTIVITY_END and e.data == AgentStore.ACT_HYGIENE:
			wash_ends += 1
	ctx.check_eq(wash_starts, 1, "Hygiene-Need startet nicht genau einmal")
	ctx.check_eq(wash_ends, 1, "Waschen endet nicht genau einmal")
	ctx.check(sim.store.activity[row] != AgentStore.ACT_HYGIENE,
		"Agent bleibt dauerhaft beim Waschen")
	# Health-Folge: schlechte Hygiene senkt Gesundheit langsam, gute erholt sie.
	var now: int = sim.clock.now
	var hrow: int = G1aTestUtil.row_of(sim, 1)
	sim.store.need_time[hrow] = now
	sim.store.hunger[hrow] = 30.0
	sim.store.energy[hrow] = 80.0
	sim.store.hygiene[hrow] = 10.0
	sim.store.social[hrow] = 80.0
	sim.store.fun[hrow] = 80.0
	sim.store.health[hrow] = 100.0
	NeedsModel.settle(sim.store, hrow, now + 6 * 3600, sim.config)
	ctx.check(sim.store.health[hrow] < 100.0,
		"schlechte Hygiene senkt Gesundheit nicht")
	ctx.check(sim.store.health[hrow] > 90.0,
		"Gesundheit sinkt nicht langsam (Hygiene)")
	now = sim.clock.now
	sim.store.need_time[hrow] = now
	sim.store.hunger[hrow] = 10.0
	sim.store.energy[hrow] = 90.0
	sim.store.hygiene[hrow] = 90.0
	sim.store.social[hrow] = 80.0
	sim.store.fun[hrow] = 80.0
	sim.store.health[hrow] = 50.0
	NeedsModel.settle(sim.store, hrow, now + 3600, sim.config)
	ctx.check(sim.store.health[hrow] > 50.0,
		"gute Hygiene erholt Gesundheit nicht")


static func _test_fun(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-06", "Spaß: Freizeit erfüllt Need; kein Dauerloop")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	G1aTestUtil.set_need(sim, 3, NeedsModel.NEED_FUN, 20.0)
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 30))
	var row: int = G1aTestUtil.row_of(sim, 3)
	var fun: float = NeedsModel.value_at(sim.store, row, sim.clock.now,
		NeedsModel.NEED_FUN, sim.config)
	ctx.check(fun > sim.config.fun_threshold, "Freizeit erfüllt Spaß nicht: %.1f" % fun)
	var need_play_starts: int = 0
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.agent_id != 3:
			continue
		if e.type == SimEvent.T_ACTIVITY_START and e.data == AgentStore.ACT_PLAY:
			need_play_starts += 1
	ctx.check_eq(need_play_starts, 1, "Spaß-Need startet nicht genau einmal")
	sim.advance_to(G1aTestUtil.abs_time(0, 12, 50))
	var need_play_after: int = 0
	for event in sim.logs.debug_events:
		var e2: SimEvent = event
		if e2.agent_id == 3 and e2.type == SimEvent.T_ACTIVITY_START \
				and e2.data == AgentStore.ACT_PLAY:
			need_play_after += 1
	ctx.check_eq(need_play_after, 1, "Spaß-Need erzeugt Dauerloop")
	# Soziales trägt ebenfalls zu Spaß bei.
	var before: float = sim.store.fun[row]
	NeedsModel.apply_social(sim.store, row, sim.config)
	ctx.check(sim.store.fun[row] > before, "Soziales erhöht Spaß nicht")
	# Niedriger Spaß beschleunigt den Sozialverlust (Stimmung/Soziales).
	var now: int = sim.clock.now
	sim.store.need_time[row] = now
	sim.store.fun[row] = 20.0
	sim.store.social[row] = 80.0
	sim.store.hunger[row] = 80.0
	sim.store.activity[row] = AgentStore.ACT_IDLE
	NeedsModel.settle(sim.store, row, now + 3600, sim.config)
	ctx.check(sim.store.social[row] < 77.5,
		"niedriger Spaß beschleunigt Sozialverlust nicht: %.2f" % sim.store.social[row])


static func _test_health(ctx: G1aTestContext) -> void:
	ctx.begin("T-NEED-07", "Gesundheit: langsamer Zustand, keine Krankheit/Gewalt")
	var sim: Simulation = G1aTestUtil.new_sim()
	var row: int = G1aTestUtil.row_of(sim, 1)
	var now: int = sim.clock.now
	# Schlechte Needs: Gesundheit sinkt, aber langsam.
	sim.store.need_time[row] = now
	sim.store.hunger[row] = 90.0
	sim.store.energy[row] = 10.0
	sim.store.hygiene[row] = 10.0
	sim.store.social[row] = 30.0
	sim.store.fun[row] = 30.0
	sim.store.health[row] = 100.0
	NeedsModel.settle(sim.store, row, now + 6 * 3600, sim.config)
	ctx.check(sim.store.health[row] < 100.0, "schlechte Needs senken Gesundheit nicht")
	ctx.check(sim.store.health[row] > 90.0, "Gesundheit sinkt nicht langsam")
	# Gute Needs: langsame Erholung.
	now = sim.clock.now
	sim.store.need_time[row] = now
	sim.store.hunger[row] = 10.0
	sim.store.energy[row] = 90.0
	sim.store.hygiene[row] = 90.0
	sim.store.social[row] = 80.0
	sim.store.fun[row] = 80.0
	sim.store.health[row] = 50.0
	NeedsModel.settle(sim.store, row, now + 3600, sim.config)
	ctx.check(sim.store.health[row] > 50.0, "gute Needs erholen Gesundheit nicht")
	ctx.check(sim.store.health[row] < 51.0, "Gesundheit erholt sich nicht langsam")
	# Altersbedingter Rückgang (A5 ist 70) bei neutralen Needs.
	now = sim.clock.now
	var old_row: int = G1aTestUtil.row_of(sim, 8)
	sim.store.need_time[old_row] = now
	sim.store.hunger[old_row] = 10.0
	sim.store.energy[old_row] = 90.0
	sim.store.hygiene[old_row] = 90.0
	sim.store.social[old_row] = 30.0
	sim.store.fun[old_row] = 80.0
	sim.store.health[old_row] = 80.0
	NeedsModel.settle(sim.store, old_row, now + 86400, sim.config)
	ctx.check(sim.store.health[old_row] < 80.0,
		"altersbedingter Gesundheitsrückgang fehlt")
	# Kein Tod: Gesundheit clamp bei 0, Agent bleibt am Leben.
	now = sim.clock.now
	sim.store.need_time[row] = now
	sim.store.hunger[row] = 100.0
	sim.store.energy[row] = 0.0
	sim.store.hygiene[row] = 0.0
	sim.store.health[row] = 1.0
	NeedsModel.settle(sim.store, row, now + 10 * 86400, sim.config)
	ctx.check_eq(sim.store.health[row], 0.0, "Gesundheit clamp nicht bei 0")
	ctx.check_eq(sim.store.alive[row], 1, "Agent ist trotz Gesundheit 0 gestorben")
