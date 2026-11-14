extends RefCounted

## T-G3-01: 768x768-Kleinstadt, 1000 Agenten, 200-250 Haushalte, 40 Felder.


static func run(ctx: G1aTestContext) -> void:
	_test_world(ctx)
	_test_population(ctx)
	_test_determinism(ctx)


static func _test_world(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-01a", "Welt: 768x768, 200-250 Häuser, 40 Felder, 3 Werkstätten, Chunks")
	var world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_G3)
	ctx.check_eq(world.size, 768, "Weltgröße")
	ctx.check_eq(world.profile, SimConfig.PROFILE_G3, "Weltprofil")
	var houses: PackedInt32Array = world.house_ids()
	var fields: PackedInt32Array = world.field_ids()
	ctx.check(houses.size() >= 200 and houses.size() <= 250, "Hausanzahl 200-250")
	ctx.check_eq(fields.size(), 40, "Feldanzahl")
	ctx.check_eq(world.workshop_ids().size(), 3, "Werkstattanzahl")
	ctx.check(world.granary_id() > 0, "Kornspeicher fehlt")
	ctx.check(world.well_id() > 0, "Brunnen fehlt")
	ctx.check(world.barn_id() > 0, "Scheune fehlt")
	ctx.check_eq(world.buildings.size(), houses.size() + fields.size() + 6,
		"Gebäudeanzahl")
	var blocked_ok: bool = true
	var doors_open: bool = true
	var overlap: bool = false
	var road_doors: bool = true
	for i in world.buildings.size():
		var b: Building = world.buildings[i]
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
		for j in range(i + 1, world.buildings.size()):
			var other: Building = world.buildings[j]
			if b.rect.intersects(other.rect):
				overlap = true
	ctx.check(blocked_ok, "Occupancy falsch (Gebäude/Feld)")
	ctx.check(doors_open, "Gebäudetür blockiert")
	ctx.check(road_doors, "Haustür liegt nicht auf einem Weg")
	ctx.check(not overlap, "Gebäude überlappen")
	var pf: PathFinder = PathFinder.new(world, 1, 4096, 1000, 1000)
	var center: Vector2 = Vector2(384.5, 392.5)
	var reachable: bool = true
	for b in world.buildings:
		var building: Building = b
		var path: PackedVector2Array = pf.request_path(building.door_point, center)
		if path.is_empty():
			reachable = false
	ctx.check(reachable, "mindestens ein Gebäude ist nicht per A* erreichbar")
	# Chunk-Index: abgeleitet, deterministisch, nur bebaute Chunks materialisiert.
	ctx.check(world.chunk_count_x * world.chunk_count_y > 0, "Chunk-Index fehlt")
	var materialized: int = world.materialized_chunk_count()
	ctx.check(materialized > 0, "keine materialisierten Chunks")
	ctx.check(materialized < world.chunk_count_x * world.chunk_count_y,
		"alle Chunks gelten als materialisiert")
	var chunk_for_door: int = world.chunk_for_tile(68, 72)
	ctx.check(chunk_for_door >= 0, "Chunk-Zuordnung fehlt")
	ctx.check(world.is_chunk_active(world.chunk_for_tile(384, 384)),
		"Siedlungs-Chunk nicht aktiv")
	ctx.check_eq(world.chunk_state_hash(), WorldMap.new(1337,
		SimConfig.PROFILE_G3).chunk_state_hash(), "Chunk-Index nicht deterministisch")


static func _test_population(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-01b", "Bevölkerung: 1000 Agenten, 200-250 Haushalte, ~40 % erwerbsfähig")
	var sim: Simulation = G3ATestUtil.new_sim()
	ctx.check_eq(sim.store.count, 1000, "Agentenzahl")
	ctx.check_eq(sim.count_alive(), 1000, "lebende Agenten")
	ctx.check(sim.households.size() >= 200 and sim.households.size() <= 250,
		"Haushaltsanzahl")
	var working: int = G3ATestUtil.working_age_count(sim)
	ctx.check(working >= 350 and working <= 450,
		"Erwerbsfähige nicht bei ~40 %%: %d" % working)
	var roles: PackedInt32Array = PackedInt32Array()
	roles.resize(4)
	var field_jobs: int = 0
	var workshop_jobs: int = 0
	var sex_seen: PackedByteArray = PackedByteArray()
	sex_seen.resize(2)
	for row in sim.store.count:
		roles[sim.store.role[row]] += 1
		if sim.store.job_kind[row] == AgentStore.JOB_FIELD:
			field_jobs += 1
		elif sim.store.job_kind[row] == AgentStore.JOB_WORKSHOP:
			workshop_jobs += 1
		sex_seen[sim.store.sex[row]] = 1
	for role in 4:
		ctx.check(roles[role] > 0, "Rolle fehlt: %d" % role)
	ctx.check(field_jobs >= 120, "zu wenige Feldarbeiter: %d" % field_jobs)
	ctx.check(workshop_jobs > 0, "keine Werkstattarbeit")
	ctx.check(sex_seen[0] != 0 and sex_seen[1] != 0, "Geschlechter fehlen")
	var partner_count: int = 0
	var parent_count: int = 0
	var friend_count: int = 0
	var household_ok: bool = true
	for relationship in sim.relationships:
		var rel: RelationshipRecord = relationship
		if rel.type == RelationshipRecord.TYPE_PARTNER:
			partner_count += 1
		elif rel.type == RelationshipRecord.TYPE_PARENT:
			parent_count += 1
		elif rel.type == RelationshipRecord.TYPE_FRIEND:
			friend_count += 1
	for household in sim.households:
		var h: HouseholdRecord = household
		if h.member_ids.size() < 2:
			household_ok = false
		for member in h.member_ids:
			if sim.store.row_for_id(member) < 0:
				household_ok = false
	ctx.check(partner_count > 0, "keine Partnerschaften")
	ctx.check(parent_count >= 400, "zu wenige Eltern-Kind-Beziehungen")
	ctx.check(friend_count > 0, "keine Freundschaften")
	ctx.check(household_ok, "Haushaltsmitglieder ungültig")
	var target: int = sim.clock.now + 2 * 3600
	G3ATestUtil.advance_chunked(sim, target, 80)
	ctx.check(sim.count_alive() > 900, "Bevölkerung bricht in 2 h ein")
	var positions_ok: bool = true
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		if not sim.world.is_point_walkable(sim.current_position(row)):
			positions_ok = false
	ctx.check(positions_ok, "Agent steht auf blockiertem Tile")


static func _test_determinism(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-01c", "Generierung deterministisch, Seed-abhängig")
	var config_a: SimConfig = SimConfig.g3(1337)
	var config_b: SimConfig = SimConfig.g3(1337)
	var config_c: SimConfig = SimConfig.g3(1338)
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
	ctx.check_eq(_world_hash(world_a), _world_hash(world_b), "Welt nicht deterministisch")
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
