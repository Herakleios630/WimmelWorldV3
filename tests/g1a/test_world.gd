extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_reachability(ctx)
	_test_occupancy(ctx)
	_test_bounds(ctx)


static func _test_reachability(ctx: G1aTestContext) -> void:
	ctx.begin("T-WORLD-01", "Alle Häuser/Arbeitsplätze über Wege erreichbar")
	var world: WorldMap = WorldMap.new(1337)
	ctx.check_eq(world.buildings.size(), 7, "Gebäudeanzahl")
	var door_nodes: PackedInt32Array = PackedInt32Array()
	var door_road_ok: bool = true
	for building in world.buildings:
		var b: Building = building
		door_nodes.append(world.nearest_node(b.door_point))
		if not world.is_road_tile(b.door_tile.x, b.door_tile.y):
			door_road_ok = false
	ctx.check(door_road_ok, "mindestens ein Gebäudeeingang liegt nicht auf einem Weg")
	var all_reachable: bool = true
	for i in door_nodes.size():
		for j in range(i + 1, door_nodes.size()):
			if not world.graph_reachable(door_nodes[i], door_nodes[j]):
				all_reachable = false
	ctx.check(all_reachable, "nicht alle Gebäude sind im Weg-Graphen verbunden")
	# Konkrete Route Haus 1 -> Feld und Haus 3 -> Werkstatt.
	var route_home_field: PackedVector2Array = world.find_route(
		world.door_point(WorldMap.B_HOUSE_H1), world.field_work_point)
	var route_home_shop: PackedVector2Array = world.find_route(
		world.door_point(WorldMap.B_HOUSE_H3), world.door_point(WorldMap.B_WORKSHOP))
	ctx.check(route_home_field.size() >= 3, "Route Haus->Feld hat keine Wegpunkte")
	ctx.check(route_home_shop.size() >= 3, "Route Haus->Werkstatt hat keine Wegpunkte")
	ctx.check(WorldMap.polyline_length(route_home_field) > 0.0, "Route Haus->Feld leer")


static func _test_occupancy(ctx: G1aTestContext) -> void:
	ctx.begin("T-WORLD-02", "Occupancy: Gebäude blockieren, Türen begehbar")
	var world: WorldMap = WorldMap.new(1337)
	var blocked_ok: bool = true
	var field_walkable: bool = true
	for building in world.buildings:
		var b: Building = building
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if b.kind == Building.KIND_FIELD:
					if world.is_blocked_tile(x, y):
						field_walkable = false
				else:
					if not world.is_blocked_tile(x, y):
						blocked_ok = false
	ctx.check(blocked_ok, "Gebäude-Footprint nicht vollständig blockiert")
	ctx.check(field_walkable, "Feld ist fälschlich blockiert")
	var doors_open: bool = true
	for building in world.buildings:
		var b2: Building = building
		if world.is_blocked_tile(b2.door_tile.x, b2.door_tile.y):
			doors_open = false
	ctx.check(doors_open, "Gebäudetür ist blockiert")
	# Keine Gebäudeüberlappung.
	var overlap: bool = false
	for i in world.buildings.size():
		for j in range(i + 1, world.buildings.size()):
			var a: Building = world.buildings[i]
			var b3: Building = world.buildings[j]
			if a.rect.intersects(b3.rect):
				overlap = true
	ctx.check(not overlap, "Gebäude-Footprints überlappen")
	# Agentenpositionen bleiben auf begehbaren Tiles.
	var sim: Simulation = G1aTestUtil.new_sim()
	var walkable_ok: bool = true
	for step in 36:
		sim.advance_to(G1aTestUtil.abs_time(0, 6, 0) + step * 1200)
		for row in sim.store.count:
			var pos: Vector2 = sim.current_position(row)
			if not world.is_point_walkable(pos):
				walkable_ok = false
	ctx.check(walkable_ok, "Agent steht auf blockiertem Tile")


static func _test_bounds(ctx: G1aTestContext) -> void:
	ctx.begin("T-WORLD-03", "Weltgrenzen: kein Agent verlässt die Karte")
	var sim: Simulation = G1aTestUtil.new_sim()
	var inside: bool = true
	for step in 145:
		sim.advance_to(G1aTestUtil.abs_time(0, 6, 0) + step * 300)
		for row in sim.store.count:
			var pos: Vector2 = sim.current_position(row)
			if pos.x < 0.0 or pos.x > float(WorldMap.SIZE) \
					or pos.y < 0.0 or pos.y > float(WorldMap.SIZE):
				inside = false
			if sim.store.target_x[row] < 0.0 or sim.store.target_x[row] > float(WorldMap.SIZE) \
					or sim.store.target_y[row] < 0.0 or sim.store.target_y[row] > float(WorldMap.SIZE):
				inside = false
	ctx.check(inside, "Agent oder Ziel außerhalb der Karte")
	var world: WorldMap = WorldMap.new(1337)
	var clamped: Vector2 = world.clamp_point(Vector2(-100.0, 999.0))
	ctx.check(clamped.x >= 0.0 and clamped.x <= float(WorldMap.SIZE) \
		and clamped.y >= 0.0 and clamped.y <= float(WorldMap.SIZE), "clamp_point fehlerhaft")
	var route: PackedVector2Array = world.find_route(Vector2(-50.0, -50.0), Vector2(500.0, 500.0))
	var route_inside: bool = true
	for p in route:
		if p.x < 0.0 or p.x > float(WorldMap.SIZE) or p.y < 0.0 or p.y > float(WorldMap.SIZE):
			route_inside = false
	ctx.check(route_inside, "Route verlässt die Karte")
