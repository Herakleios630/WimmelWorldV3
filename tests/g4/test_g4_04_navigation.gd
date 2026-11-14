extends RefCounted

## T-G4a-04: A*/Wegpunktgraph, Cache, Chunking, Pfadbudget bei 10k.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-04", "A*/Cache/Chunking bei 10k, Pfadbudget, kein Full-Sweep")
	var sim: Simulation = G4ATestUtil.new_sim(1337)
	G4ATestUtil.advance_chunked(sim, sim.clock.now + 5 * SimConfig.TICKS_PER_DAY, 80)
	var nav: Dictionary = sim.navigation_stats()
	ctx.check(int(nav["requests"]) > 100000, "zu wenige Pfadanfragen")
	ctx.check(float(nav["cache_hit_rate"]) > 0.90,
		"Cache-Hit unter 90 %%: %.3f" % float(nav["cache_hit_rate"]))
	ctx.check(int(nav["max_lookups_per_frame"]) <= sim.config.path_lookup_budget,
		"Lookup-Budget überschritten")
	ctx.check(int(nav["max_recalcs_per_frame"]) <= sim.config.path_recalc_budget,
		"Recalc-Budget überschritten")
	ctx.check(int(nav["deferred"]) < int(nav["requests"]) / 5,
		"zu viele Pfad-Vertagungen")
	ctx.check(sim.pathfinder.cache_size() > 8000, "Pfad-Cache zu klein")
	# A*-Fallback bleibt funktionsfähig (Tile-Grid). Der Wegpunktgraph ist der
	# primäre 10k-Pfad; beide liefern begehbare Punkte.
	var pf: PathFinder = PathFinder.new(sim.world, 1, 8192, 512, 16, 128)
	var paths_ok: bool = true
	var walkable_ok: bool = true
	for i in 50:
		var home: Vector2 = sim.world.door_point(
			sim.world.house_ids()[i * 31])
		var field: Vector2 = sim.world.field_work_point_for(
			sim.world.field_ids()[i * 3])
		var path: PackedVector2Array = pf.request_path(home, field)
		if path.is_empty():
			paths_ok = false
			continue
		for p in path:
			if not sim.world.is_point_walkable(p):
				walkable_ok = false
	ctx.check(paths_ok, "A*-Pfad fehlt")
	ctx.check(walkable_ok, "A*-Pfad über blockierte Tiles")
	# Chunking: nur materialisierte Chunks, deterministisch.
	ctx.check(sim.world.materialized_chunk_count() > 0, "keine Chunks")
	ctx.check(sim.world.materialized_chunk_count()
		< sim.world.chunk_count_x * sim.world.chunk_count_y,
		"alle Chunks materialisiert")
	# Kein Full-Agent-Sweep im Advance-/Wake-Pfad.
	var adv_src: String = FileAccess.get_file_as_string(
		"res://src/agents/simulation.gd")
	var wake_src: String = FileAccess.get_file_as_string(
		"res://src/decisions/decision_system.gd")
	ctx.check(not _func_body(adv_src, "func advance_to").contains(
		"for row in store.count"), "Full-Agent-Sweep in simulation.advance")
	ctx.check(not _func_body(wake_src, "func on_agent_wake").contains(
		"for row in store.count"), "Full-Agent-Sweep im Wake-Pfad")
	var stats: Dictionary = sim.batch_stats()
	ctx.check_eq(int(stats["out_of_order"]), 0, "Event-Batches ungeordnet")
	ctx.check(sim.count_alive() > 9900, "Bevölkerung nach 5 Tagen eingebrochen")


static func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	if start < 0:
		return ""
	var next_func: int = src.find("\nfunc ", start + signature.length())
	if next_func < 0:
		return src.substr(start)
	return src.substr(start, next_func - start)
