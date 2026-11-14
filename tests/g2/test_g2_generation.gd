extends RefCounted

## T-G2-01: deterministische 384x384-Welt und 100-Agenten-Bevölkerung.


static func run(ctx: G1aTestContext) -> void:
	_test_world(ctx)
	_test_population(ctx)
	_test_determinism(ctx)


static func _test_world(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-01a", "Welt: 384x384, 20-25 Häuser, 4 Felder, Wege, Occupancy")
	var world: WorldMap = WorldMap.new(1337, SimConfig.PROFILE_G2)
	ctx.check_eq(world.size, 384, "Weltgröße")
	ctx.check_eq(world.profile, SimConfig.PROFILE_G2, "Weltprofil")
	var houses: PackedInt32Array = world.house_ids()
	var fields: PackedInt32Array = world.field_ids()
	ctx.check(houses.size() >= 20 and houses.size() <= 25, "Hausanzahl 20-25")
	ctx.check_eq(fields.size(), 4, "Feldanzahl")
	ctx.check_eq(world.buildings.size(), houses.size() + 8, "Gebäudeanzahl")
	ctx.check(world.granary_id() > 0, "Kornspeicher fehlt")
	ctx.check(world.well_id() > 0, "Brunnen fehlt")
	ctx.check(world.workshop_id() > 0, "Werkstatt fehlt")
	ctx.check(world.barn_id() > 0, "Scheune fehlt")
	# Footprints blockieren, Türen und Felder bleiben begehbar.
	var blocked_ok: bool = true
	var doors_open: bool = true
	var overlap: bool = false
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
		for j in range(i + 1, world.buildings.size()):
			var other: Building = world.buildings[j]
			if b.rect.intersects(other.rect):
				overlap = true
	ctx.check(blocked_ok, "Occupancy falsch (Gebäude/Feld)")
	ctx.check(doors_open, "Gebäudetür blockiert")
	ctx.check(not overlap, "Gebäude überlappen")
	# Alle Türen sind über den Tile-Graphen erreichbar.
	var pf: PathFinder = PathFinder.new(world, 1, 2048, 1000, 1000)
	var center: Vector2 = Vector2(196.5, 196.5)
	var reachable: bool = true
	for b in world.buildings:
		var building: Building = b
		var path: PackedVector2Array = pf.request_path(building.door_point, center)
		if path.is_empty():
			reachable = false
	ctx.check(reachable, "mindestens ein Gebäude ist nicht per A* erreichbar")
	# Wege zwischen allen Häusern sichtbar vorhanden.
	var road_ok: bool = true
	for h in houses:
		var house: Building = world.building_by_id(h)
		if house == null or not world.is_road_tile(house.door_tile.x, house.door_tile.y):
			road_ok = false
	ctx.check(road_ok, "Haustür liegt nicht auf einem Weg")


static func _test_population(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-01b", "Bevölkerung: 100 Agenten, 20-25 Haushalte, Rollen/Jobs/Beziehungen")
	var sim: Simulation = G2TestUtil.new_sim()
	ctx.check_eq(sim.store.count, 100, "Agentenzahl")
	ctx.check_eq(sim.count_alive(), 100, "lebende Agenten")
	ctx.check(sim.households.size() >= 20 and sim.households.size() <= 25,
		"Haushaltsanzahl")
	ctx.check(G2TestUtil.working_age_count(sim) >= 20, "weniger als 20 Erwerbsfähige")
	var roles: PackedInt32Array = PackedInt32Array()
	roles.resize(4)
	var jobs: PackedInt32Array = PackedInt32Array()
	jobs.resize(5)
	var sex_seen: PackedByteArray = PackedByteArray()
	sex_seen.resize(2)
	for row in sim.store.count:
		roles[sim.store.role[row]] += 1
		var job: int = sim.store.job_id[row]
		if job >= 0 and job < jobs.size():
			jobs[job] += 1
		sex_seen[sim.store.sex[row]] = 1
	for role in 4:
		ctx.check(roles[role] > 0, "Rolle fehlt: %d" % role)
	ctx.check(jobs[AgentRecords.JOB_FIELD] > 0, "keine Feldarbeit")
	ctx.check(jobs[AgentRecords.JOB_APPRENTICE] > 0, "keine Werkstatt/Lehre")
	ctx.check(jobs[AgentRecords.JOB_HOUSEHOLD] > 0, "kein Haushaltsjob")
	ctx.check(jobs[AgentRecords.JOB_LIGHT] > 0, "keine leichten Aufgaben")
	ctx.check(sex_seen[0] != 0 and sex_seen[1] != 0, "Geschlechter fehlen")
	var partner_count: int = 0
	var parent_count: int = 0
	var friend_count: int = 0
	var family_sizes_ok: bool = true
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
			family_sizes_ok = false
		for member in h.member_ids:
			if sim.store.row_for_id(member) < 0:
				family_sizes_ok = false
	ctx.check(partner_count > 0, "keine Partnerschaften")
	ctx.check(parent_count >= 40, "zu wenige Eltern-Kind-Beziehungen")
	ctx.check(friend_count > 0, "keine Freundschaften")
	ctx.check(family_sizes_ok, "Haushaltsmitglieder ungültig")
	# Reale Simulation: Positionen bleiben begehbar, Need-/Arbeitslogik läuft.
	var target: int = sim.clock.now + SimConfig.TICKS_PER_DAY
	G2TestUtil.advance_chunked(sim, target, 80)
	ctx.check(sim.count_alive() > 0, "Bevölkerung stirbt am ersten Tag aus")
	var positions_ok: bool = true
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		if not sim.world.is_point_walkable(sim.current_position(row)):
			positions_ok = false
	ctx.check(positions_ok, "Agent steht auf blockiertem Tile")


static func _test_determinism(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-01c", "Generierung deterministisch, Seed-abhängig")
	var a: Simulation = G2TestUtil.new_sim(1337)
	var b: Simulation = G2TestUtil.new_sim(1337)
	var c: Simulation = G2TestUtil.new_sim(1338)
	ctx.check_eq(a.state_hash(), b.state_hash(), "gleicher Seed -> anderer State")
	ctx.check_eq(_world_hash(a.world), _world_hash(b.world), "Welt nicht deterministisch")
	ctx.check(a.state_hash() != c.state_hash(), "anderer Seed -> gleicher State")
	ctx.check(_world_hash(a.world) != _world_hash(c.world),
		"anderer Seed -> gleiche Welt")


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
