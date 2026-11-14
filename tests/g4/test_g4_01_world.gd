extends RefCounted

## T-G4a-01: 10.000 Agenten, 2.000 Haushalte, 2048x2048, 200 Felder.


static func run(ctx: G1aTestContext) -> void:
	_test_world(ctx)
	_test_population(ctx)
	_test_determinism(ctx)


static func _test_world(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-01a", "Welt: 2048x2048, 2.000 Häuser, 200 Felder, 6 Support-Bauten")
	var world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_SCALE)
	ctx.check_eq(world.size, 2048, "Weltgröße")
	ctx.check_eq(world.profile, SimConfig.PROFILE_SCALE, "Weltprofil")
	var houses: PackedInt32Array = world.house_ids()
	var fields: PackedInt32Array = world.field_ids()
	ctx.check_eq(houses.size(), 2000, "Hausanzahl")
	ctx.check_eq(fields.size(), 200, "Feldanzahl")
	ctx.check_eq(world.workshop_ids().size(), 3, "Werkstattanzahl")
	ctx.check(world.granary_id() > 0, "Kornspeicher fehlt")
	ctx.check(world.well_id() > 0, "Brunnen fehlt")
	ctx.check(world.barn_id() > 0, "Scheune fehlt")
	ctx.check_eq(world.buildings.size(), 2000 + 200 + 6, "Gebäudeanzahl")
	var blocked_ok: bool = true
	var doors_open: bool = true
	var road_doors: bool = true
	for b_v in world.buildings:
		var b: Building = b_v
		for y in range(b.rect.position.y, b.rect.position.y + b.rect.size.y):
			for x in range(b.rect.position.x, b.rect.position.x + b.rect.size.x):
				if b.kind == Building.KIND_FIELD:
					if world.is_blocked_tile(x, y):
						blocked_ok = false
				elif not world.is_blocked_tile(x, y):
					blocked_ok = false
		if world.is_blocked_tile(b.door_tile.x, b.door_tile.y):
			doors_open = false
		if b.kind == Building.KIND_HOUSE \
				and not world.is_road_tile(b.door_tile.x, b.door_tile.y):
			road_doors = false
	ctx.check(blocked_ok, "Occupancy falsch (Gebäude/Feld)")
	ctx.check(doors_open, "Gebäudetür blockiert")
	ctx.check(road_doors, "Haustür liegt nicht auf einem Weg")
	var chunks: int = world.chunk_count_x * world.chunk_count_y
	ctx.check_eq(chunks, 4096, "Chunk-Anzahl")
	var materialized: int = world.materialized_chunk_count()
	ctx.check(materialized > 0 and materialized < chunks,
		"Chunk-Index nicht selektiv: %d/%d" % [materialized, chunks])
	ctx.check_eq(world.chunk_state_hash(),
		WorldMap.new(1337, SimConfig.PROFILE_SCALE).chunk_state_hash(),
		"Chunk-Index nicht deterministisch")
	var pf: PathFinder = PathFinder.new(world, 1, 8192, 512, 16, 128)
	var ok: bool = true
	for i in 20:
		var home: Vector2 = world.door_point(houses[i * 97])
		var field: Vector2 = world.field_work_point_for(fields[i * 9])
		if pf.request_path(home, field).is_empty():
			ok = false
	ctx.check(ok, "A*/Wegpunktpfad unvollständig")
	ctx.check(pf.cache_size() > 0, "Pfad-Cache leer")


static func _test_population(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-01b", "Bevölkerung: 10.000 Agenten, 2.000 Haushalte, Erwerbsquote")
	var sim: Simulation = G4ATestUtil.new_sim()
	ctx.check_eq(sim.store.count, 10000, "Agentenzahl")
	ctx.check_eq(sim.count_alive(), 10000, "lebende Agenten")
	ctx.check_eq(sim.households.size(), 2000, "Haushaltsanzahl")
	var working: int = G4ATestUtil.working_age_count(sim)
	ctx.check(working >= 3600 and working <= 4200,
		"Erwerbsfähige nicht ~3900: %d" % working)
	var roles: PackedInt32Array = PackedInt32Array()
	roles.resize(4)
	var field_jobs: int = 0
	var workshop_jobs: int = 0
	for row in sim.store.count:
		roles[sim.store.role[row]] += 1
		if sim.store.job_kind[row] == AgentStore.JOB_FIELD:
			field_jobs += 1
		elif sim.store.job_kind[row] == AgentStore.JOB_WORKSHOP:
			workshop_jobs += 1
	for role in 4:
		ctx.check(roles[role] > 0, "Rolle fehlt: %d" % role)
	ctx.check(field_jobs >= 1900, "zu wenige Feldarbeiter: %d" % field_jobs)
	ctx.check(workshop_jobs > 0, "keine Werkstattarbeit")
	var partner_count: int = 0
	var parent_count: int = 0
	for rel_v in sim.relationships:
		var rel: RelationshipRecord = rel_v
		if rel.type == RelationshipRecord.TYPE_PARTNER:
			partner_count += 1
		elif rel.type == RelationshipRecord.TYPE_PARENT:
			parent_count += 1
	ctx.check(partner_count >= 3800, "zu wenige Partnerschaften")
	ctx.check(parent_count >= 11000, "zu wenige Eltern-Kind-Beziehungen: %d" % parent_count)
	var target: int = sim.clock.now + 2 * 3600
	G4ATestUtil.advance_chunked(sim, target, 80)
	ctx.check(sim.count_alive() > 9900, "Bevölkerung bricht in 2 h ein")
	var positions_ok: bool = true
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		if not sim.world.is_point_walkable(sim.current_position(row)):
			positions_ok = false
	ctx.check(positions_ok, "Agent steht auf blockiertem Tile")


static func _test_determinism(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-01c", "Generierung deterministisch, Seed-abhängig")
	var config_a: SimConfig = SimConfig.scale(1337)
	var config_b: SimConfig = SimConfig.scale(1337)
	var config_c: SimConfig = SimConfig.scale(1338)
	var world_a: WorldMap = WorldMap.create_for_config(config_a)
	var world_b: WorldMap = WorldMap.create_for_config(config_b)
	var world_c: WorldMap = WorldMap.create_for_config(config_c)
	var gen_a: Dictionary = PopulationGenerator.generate(world_a, config_a)
	var gen_b: Dictionary = PopulationGenerator.generate(world_b, config_b)
	var gen_c: Dictionary = PopulationGenerator.generate(world_c, config_c)
	ctx.check_eq(_records_hash(gen_a["records"]), _records_hash(gen_b["records"]),
		"gleicher Seed -> andere Records")
	ctx.check(_records_hash(gen_a["records"]) != _records_hash(gen_c["records"]),
		"anderer Seed -> gleiche Records")
	ctx.check_eq(_world_hash(world_a), _world_hash(world_b),
		"Welt nicht deterministisch")
	ctx.check(_world_hash(world_a) != _world_hash(world_c),
		"anderer Seed -> gleiche Welt")


static func _records_hash(records: Array) -> int:
	var h: int = HashUtil.FNV_OFFSET
	for record in records:
		h = HashUtil.mix(h, (record as AgentRecord).state_hash())
	return h


static func _world_hash(world: WorldMap) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, world.size)
	for building in world.buildings:
		var b: Building = building
		h = HashUtil.mix(h, b.id)
		h = HashUtil.mix(h, b.kind)
		h = HashUtil.mix(h, b.rect.position.x)
		h = HashUtil.mix(h, b.rect.position.y)
		h = HashUtil.mix(h, b.rect.size.x)
		h = HashUtil.mix(h, b.rect.size.y)
		h = HashUtil.mix(h, b.door_tile.x)
		h = HashUtil.mix(h, b.door_tile.y)
	for p in world.decor_trees:
		h = HashUtil.mix_f64(h, p.x)
		h = HashUtil.mix_f64(h, p.y)
	return h
