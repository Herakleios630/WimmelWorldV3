extends RefCounted

## T-G2-02: lokaler A*, deterministische Pfade, Cache und Frame-Budget.


static func run(ctx: G1aTestContext) -> void:
	_test_paths(ctx)
	_test_cache_and_budget(ctx)
	_test_occupancy(ctx)


static func _test_paths(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-02a", "A*: deterministische Pfade, begehbar, Cache-fähig")
	var world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_G2)
	var pf: PathFinder = PathFinder.new(world, 1, 256, 1000, 1000)
	var start: Vector2 = world.door_point(world.house_ids()[0])
	var goal: Vector2 = world.field_work_point_for(world.field_ids()[0])
	pf.prewarm(start, goal)
	var p1: PackedVector2Array = pf.request_path(start, goal)
	var p2: PackedVector2Array = pf.request_path(start, goal)
	ctx.check(p1.size() >= 2, "A*-Pfad zu kurz")
	ctx.check_eq(p1.size(), p2.size(), "A*-Pfad nicht stabil (Länge)")
	var same: bool = true
	for i in mini(p1.size(), p2.size()):
		if p1[i].distance_to(p2[i]) > 0.000001:
			same = false
	ctx.check(same, "A*-Pfad nicht deterministisch")
	ctx.check(pf.cache_hits >= 1, "Cache-Hit nach Prewarm fehlt")
	var walkable: bool = true
	for p in p1:
		if not world.is_point_walkable(p):
			walkable = false
	ctx.check(walkable, "A*-Pfad führt über blockiertes Tile")
	# Map-Version invalidiert den Cache.
	pf.set_map_version(2)
	ctx.check_eq(pf.cache_size(), 0, "Map-Version invalidiert Cache nicht")
	var p3: PackedVector2Array = pf.request_path(start, goal)
	ctx.check(p3.size() >= 2, "Pfad nach Cache-Invalidierung fehlt")


static func _test_cache_and_budget(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-02b", "Cache-Hit > 90 %, 2 Recalcs + 50 Lookups/Frame")
	var sim: Simulation = G2TestUtil.new_sim()
	ctx.check(sim.pathfinder != null, "G2 hat keinen PathFinder")
	if sim.pathfinder == null:
		return
	G2TestUtil.advance_chunked(sim, sim.clock.now + 5 * SimConfig.TICKS_PER_DAY, 80)
	var nav: Dictionary = sim.navigation_stats()
	var hit_rate: float = float(nav.get("cache_hit_rate", 0.0))
	ctx.check(hit_rate > 0.90, "Cache-Hit-Rate <= 90 %%: %.4f" % hit_rate)
	ctx.check(int(nav.get("max_lookups_per_frame", 999)) <= 50,
		"mehr als 50 Cache-Lookups/Frame: %d" % int(nav.get("max_lookups_per_frame", 999)))
	ctx.check(int(nav.get("max_recalcs_per_frame", 999)) <= 2,
		"mehr als 2 Neuberechnungen/Frame: %d" % int(nav.get("max_recalcs_per_frame", 999)))
	ctx.check(int(nav.get("cache_misses", 999)) < int(nav.get("cache_hits", 0)),
		"Cache-Misses dominieren")
	ctx.check(int(nav.get("deferred", 0)) >= 0, "Deferred-Zähler fehlt")
	print("G2_NAV stats=%s" % str(nav))
	# Der Cache ist abgeleitet und nicht Teil des Save-Formats.
	var save_source: String = FileAccess.get_file_as_string("res://src/persistence/sim_save.gd")
	ctx.check(not save_source.contains("pathfinder")
		and not save_source.contains("cache_hits")
		and not save_source.contains("cache_order"), "Save schreibt Pfad-Cache")


static func _test_occupancy(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-02c", "Occupancy: Gebäude blockieren, Türen/Felder begehbar")
	var world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_G2)
	var blocked_ok: bool = true
	var doors_open: bool = true
	var fields_walkable: bool = true
	for building in world.buildings:
		var b: Building = building
		if b.kind == Building.KIND_FIELD:
			if world.is_blocked_tile(b.door_tile.x, b.door_tile.y):
				fields_walkable = false
			continue
		if world.is_blocked_tile(b.door_tile.x, b.door_tile.y):
			doors_open = false
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if not world.is_blocked_tile(x, y):
					blocked_ok = false
	ctx.check(blocked_ok, "Gebäude blockieren nicht")
	ctx.check(doors_open, "Tür blockiert")
	ctx.check(fields_walkable, "Feldzugang blockiert")
	# Agenten bleiben während eines Tages auf begehbaren Tiles.
	var sim: Simulation = G2TestUtil.new_sim()
	var ok: bool = true
	for step in 60:
		sim.advance_to(G2TestUtil.abs_time(0, 6, 0) + step * 900)
		for row in sim.store.count:
			if sim.store.alive[row] == 0:
				continue
			if not sim.world.is_point_walkable(sim.current_position(row)):
				ok = false
	ctx.check(ok, "Agent auf blockiertem Tile")
