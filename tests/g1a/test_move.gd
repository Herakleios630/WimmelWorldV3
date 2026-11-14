extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_position_at(ctx)
	_test_arrival(ctx)
	_test_waypoint(ctx)


static func _test_position_at(ctx: G1aTestContext) -> void:
	ctx.begin("T-MOVE-01", "position_at exakt, keine Frame-Abhängigkeit")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 8, 0))
	var row: int = G1aTestUtil.row_of(sim, 1)
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_TRAVEL,
		"A1 ist um 08:00 nicht auf dem Weg zur Arbeit")
	var depart: int = sim.store.travel_depart[row]
	var arrive: int = sim.store.travel_arrive[row]
	var start: Vector2 = Vector2(sim.store.travel_start_x[row], sim.store.travel_start_y[row])
	var end: Vector2 = Vector2(sim.store.travel_end_x[row], sim.store.travel_end_y[row])
	ctx.check(arrive > depart, "Reisezeit nicht positiv")
	var p_depart: Vector2 = sim.agent_position_at(1, depart)
	var p_arrive: Vector2 = sim.agent_position_at(1, arrive)
	ctx.check(p_depart.distance_to(start) < 0.001, "Position zu Beginn falsch")
	ctx.check(p_arrive.distance_to(end) < 0.001, "Position bei Ankunft falsch")
	var mid: Vector2 = sim.agent_position_at(1, (depart + arrive) / 2)
	ctx.check(mid.distance_to(start) > 0.001 and mid.distance_to(end) > 0.001,
		"Zwischenposition liegt nicht zwischen Start und Ziel")
	var last_dist: float = -1.0
	var monotonic: bool = true
	for k in 11:
		var t: int = depart + (arrive - depart) * k / 10
		var dist: float = sim.agent_position_at(1, t).distance_to(start)
		if dist < last_dist - 0.0001:
			monotonic = false
		last_dist = dist
	ctx.check(monotonic, "Bewegung ist nicht monoton")
	# Frame-Unabhängigkeit: verschiedene Advance-Chunks, gleiche Sim-Zeit.
	var a: Simulation = G1aTestUtil.new_sim()
	var b: Simulation = G1aTestUtil.new_sim()
	var target: int = G1aTestUtil.abs_time(0, 8, 30)
	while a.clock.now < target:
		a.advance_to(mini(target, a.clock.now + 7))
	b.advance_to(target)
	ctx.check_eq(a.state_hash(), b.state_hash(), "Chunking verändert Sim-Zustand")
	for agent_id in [1, 2, 3, 10]:
		ctx.check(a.agent_position_at(agent_id, target).distance_to(
			b.agent_position_at(agent_id, target)) < 0.000001,
			"Position von A%d chunk-abhängig" % agent_id)


static func _test_arrival(ctx: G1aTestContext) -> void:
	ctx.begin("T-MOVE-02", "Ankunfts-Event exakt zum Termin")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 8, 0))
	var row: int = G1aTestUtil.row_of(sim, 1)
	var arrive: int = sim.store.travel_arrive[row]
	ctx.check(arrive > sim.clock.now, "kein laufender Weg")
	sim.advance_to(arrive - 1)
	ctx.check_eq(sim.store.activity[row], AgentStore.ACT_TRAVEL,
		"Agent ist vor dem Termin schon angekommen")
	sim.advance_to(arrive)
	ctx.check(sim.store.activity[row] != AgentStore.ACT_TRAVEL,
		"Agent ist am Termin noch unterwegs")
	var arrivals: Array = G1aTestUtil.events_of(sim, SimEvent.T_ARRIVE, 1)
	var found: bool = false
	for event in arrivals:
		if (event as SimEvent).time == arrive:
			found = true
	ctx.check(found, "Ankunfts-Event fehlt oder hat falsche Zeit")


static func _test_waypoint(ctx: G1aTestContext) -> void:
	ctx.begin("T-MOVE-03", "G1-Waypoints unverändert, G2-A*/Cache getrennt")
	var world: WorldMap = WorldMap.new(1337)
	var route: PackedVector2Array = world.find_route(
		world.door_point(WorldMap.B_HOUSE_H1), world.field_work_point)
	ctx.check(route.size() >= 3, "Route nutzt keine Zwischen-Wegpunkte")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 8, 0))
	var row: int = G1aTestUtil.row_of(sim, 1)
	ctx.check(sim.store.route_id[row] >= 0, "Agent hat keine Route")
	if sim.store.route_id[row] >= 0:
		var pts: PackedVector2Array = sim.routes.get_points(sim.store.route_id[row])
		ctx.check(pts.size() >= 3, "Agentenroute hat keine Wegpunkte")
	# G2 ergänzt A*/Cache als eigenes Modul; der G1-Default bleibt beim
	# Waypoint-Graphen. Der Test prüft beide Pfade getrennt (Erweiterung,
	# keine Abschwächung der G1-Routenprüfung).
	ctx.check(FileAccess.file_exists("res://src/navigation/path_finder.gd"),
		"G2-PathFinder fehlt")
	var g1_sim: Simulation = G1aTestUtil.new_sim()
	ctx.check(g1_sim.pathfinder == null, "G1-Default nutzt fälschlich G2-A*")
	var g2_world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_G2)
	var pf: PathFinder = PathFinder.new(g2_world, 1, 64, 100, 100)
	var start: Vector2 = g2_world.door_point(g2_world.house_ids()[0])
	var goal: Vector2 = g2_world.field_work_point_for(g2_world.field_ids()[0])
	pf.prewarm(start, goal)
	var p_a: PackedVector2Array = pf.request_path(start, goal)
	var p_b: PackedVector2Array = pf.request_path(start, goal)
	ctx.check(p_a.size() >= 2 and p_a.size() == p_b.size(),
		"G2-A*/Cache liefert keinen stabilen Pfad")
	ctx.check(pf.cache_hits >= 1, "G2-Pfad-Cache ohne Hit")
