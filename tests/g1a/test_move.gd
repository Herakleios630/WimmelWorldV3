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
	ctx.begin("T-MOVE-03", "Waypoint-Bewegung, kein A*/Cache-Zwang")
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
	var files: PackedStringArray = PackedStringArray()
	for dir_path in ["res://src/navigation", "res://src/decisions"]:
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir != null:
			for file_name in dir.get_files():
				if file_name.ends_with(".gd"):
					files.append(dir_path + "/" + file_name)
	var no_astar: bool = true
	for path in files:
		var text: String = G1aTestUtil.read_text(path)
		if text.contains("AStar") or text.contains("astar") or text.contains("a_star"):
			no_astar = false
	ctx.check(no_astar, "A*-Referenz in G1a-Navigation/Entscheidungen")
