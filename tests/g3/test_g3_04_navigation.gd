extends RefCounted

## T-G3-04: A*/Pfad-Cache/Chunking, 2 Recalcs + 50 Lookups/Frame.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-04", "A*/Cache/Chunking bei 1k, Budgets, deterministische Pfade")
	var sim: Simulation = G3ATestUtil.shared_year(1337)
	var nav: Dictionary = sim.navigation_stats()
	print("G3_NAV " + str(nav))
	ctx.check(float(nav.get("cache_hit_rate", 0.0)) > 0.90,
		"Cache-Hit <= 90 %%: %.3f" % float(nav.get("cache_hit_rate", 0.0)))
	ctx.check(float(nav.get("request_hit_rate", 0.0)) > 0.50,
		"Request-Hit <= 50 %%")
	ctx.check(int(nav.get("max_lookups_per_frame", 999)) <= 50,
		"Lookup-Budget > 50")
	ctx.check(int(nav.get("max_recalcs_per_frame", 999)) <= 2,
		"Recalc-Budget > 2")
	ctx.check(int(nav.get("cache_size", 0)) <= sim.config.path_cache_capacity,
		"Cache größer als Kapazität")
	ctx.check(sim.pathfinder.cache_capacity == 16384, "G3-Cachekapazität")
	# Chunking: 768er Welt, abgeleiteter Index, nicht alle Chunks materialisiert.
	var world: WorldMap = sim.world
	ctx.check_eq(world.chunk_count_x, 24, "Chunk-Spalten")
	ctx.check_eq(world.materialized_chunk_count(), 338, "materialisierte Chunks")
	ctx.check(world.materialized_chunk_count() < world.chunk_count_x
		* world.chunk_count_y, "alle Chunks materialisiert")
	ctx.check(world.is_chunk_active(world.chunk_for_tile(68, 72)),
		"Wohnhaus-Chunk nicht aktiv")
	ctx.check(world.chunk_for_tile(767, 767) >= 0, "Chunk-Zuordnung fehlt")
	# Pfaddeterminismus, getrennt vom Laufzeitcache.
	var world2: WorldMap = WorldMap.create_for_config(SimConfig.g3(1337))
	var pf_a: PathFinder = PathFinder.new(world2, 1, 4096, 1000, 1000)
	var pf_b: PathFinder = PathFinder.new(world2, 1, 4096, 1000, 1000)
	var start: Vector2 = world2.door_point(world2.house_ids()[0])
	var goal: Vector2 = world2.field_work_point_for(world2.field_ids()[0])
	var pa: PackedVector2Array = pf_a.request_path(start, goal)
	var pb: PackedVector2Array = pf_b.request_path(start, goal)
	ctx.check(not pa.is_empty(), "A* liefert keinen Pfad")
	ctx.check_eq(pa.size(), pb.size(), "A* nicht deterministisch")
	var equal: bool = true
	for i in pa.size():
		if pa[i] != pb[i]:
			equal = false
	ctx.check(equal, "A*-Pfadpunkte nicht deterministisch")
	var walkable: bool = true
	for point in pa:
		if not world2.is_point_walkable(point):
			walkable = false
	ctx.check(walkable, "A*-Pfad über blockierte Tiles")
	# Kein Full-Agent-Sweep: Batch-p95 bleibt klein.
	var batch: Dictionary = sim.batch_stats()
	ctx.check(float(batch.get("p95_batch", 9999)) <= 500.0, "Batch-p95 zu groß")
	ctx.check_eq(int(batch.get("out_of_order", 1)), 0, "Batchordnung verletzt")
