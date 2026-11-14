class_name PopulationGenerator
extends RefCounted

## Deterministischer G2-Bevölkerungsgenerator: 100 Agenten in 20-25
## Haushalten mit Kindern, Jugendlichen, Erwachsenen und Alten. Der Generator
## nutzt einen eigenen, aus dem Seed abgeleiteten RNG und verändert keinen
## bestehenden Simulations-Stream. Die erzeugten Records/Haushalte/
## Beziehungen sind autoritativ und werden gespeichert.

const TARGET_AGENTS: int = 100
const G2_SEED_SALT: int = 704602925


static func generate(world: WorldMap, config: SimConfig) -> Dictionary:
	var households: Array = []
	var records: Array = []
	var relationships: Array = []
	var h_count: int = clampi(config.target_households, 20, 25)
	var target_agents: int = maxi(h_count, config.target_agents)
	var partners: int = mini(h_count, 16)
	var elders: int = mini(20, maxi(0, target_agents - h_count - partners))
	var children: int = maxi(0, target_agents - h_count - partners - elders)
	var rng: RngStream = RngStream.new(config.seed * G2_SEED_SALT + 17)
	var next_id: int = 1
	var next_rel: int = 1
	var house_ids: PackedInt32Array = world.house_ids()
	var head_ids: PackedInt32Array = PackedInt32Array()
	var partner_ids: PackedInt32Array = PackedInt32Array()
	var child_ids_by_house: Array = []
	var elder_ids_by_house: Array = []
	for h in h_count:
		child_ids_by_house.append(PackedInt32Array())
		elder_ids_by_house.append(PackedInt32Array())
	for h in h_count:
		var household_id: int = h + 1
		var home_id: int = house_ids[h % house_ids.size()]
		var members: PackedInt32Array = PackedInt32Array()
		var head_sex: int = h % 2
		var head_age: int = 28 + rng.next_range(25)
		var head_id: int = next_id
		next_id += 1
		head_ids.append(head_id)
		_add_record(records, head_id, head_sex, head_age, household_id,
			home_id, rng, h)
		members.append(head_id)
		var partner_id: int = 0
		if h < partners:
			partner_id = next_id
			next_id += 1
			var partner_sex: int = 1 - head_sex
			var partner_age: int = 24 + rng.next_range(28)
			partner_ids.append(partner_id)
			_add_record(records, partner_id, partner_sex, partner_age,
				household_id, home_id, rng, h + 31)
			members.append(partner_id)
			_append_rel(relationships, next_rel, RelationshipRecord.TYPE_PARTNER,
				head_id, partner_id, 80, 0)
			next_rel += 1
			_append_rel(relationships, next_rel, RelationshipRecord.TYPE_PARTNER,
				partner_id, head_id, 80, 0)
			next_rel += 1
		var household: HouseholdRecord = HouseholdRecord.new(household_id,
			home_id, members)
		households.append(household)
		if partner_id > 0:
			partner_ids[partner_ids.size() - 1] = partner_id
	# Kinder auf die Haushalte verteilen: die ersten Haushalte erhalten zwei,
	# die übrigen eines, damit jedes Haus einen Erziehungsberechtigten und
	# mindestens ein Kind hat.
	for child_idx in children:
		var h: int = child_idx % h_count
		var child_age: int = rng.next_range(18)
		var child_sex: int = rng.next_range(2)
		var child_id: int = next_id
		next_id += 1
		var household_id: int = h + 1
		var home_id: int = house_ids[h % house_ids.size()]
		_add_record(records, child_id, child_sex, child_age, household_id,
			home_id, rng, h + 61)
		child_ids_by_house[h].append(child_id)
		var household: HouseholdRecord = households[h]
		household.member_ids = _insert_sorted(household.member_ids, child_id)
		var head_id: int = head_ids[h]
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_PARENT,
			head_id, child_id, 90, 0)
		next_rel += 1
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_CHILD,
			child_id, head_id, 90, 0)
		next_rel += 1
		if h < partners and h < partner_ids.size():
			var pid: int = partner_ids[h]
			_append_rel(relationships, next_rel, RelationshipRecord.TYPE_PARENT,
				pid, child_id, 90, 0)
			next_rel += 1
			_append_rel(relationships, next_rel, RelationshipRecord.TYPE_CHILD,
				child_id, pid, 90, 0)
			next_rel += 1
	# Alte: in jedem vierten Haushalt lebt ein Großelternteil des Haushaltsvor-
	# stands. Das erzeugt mindestens drei Generationen im Familienbaum.
	for e in elders:
		var h: int = e % h_count
		var elder_age: int = 62 + rng.next_range(20)
		var elder_sex: int = (h + 1) % 2
		var elder_id: int = next_id
		next_id += 1
		var household_id: int = h + 1
		var home_id: int = house_ids[h % house_ids.size()]
		_add_record(records, elder_id, elder_sex, elder_age, household_id,
			home_id, rng, h + 97)
		elder_ids_by_house[h].append(elder_id)
		var household2: HouseholdRecord = households[h]
		household2.member_ids = _insert_sorted(household2.member_ids, elder_id)
		var head_id2: int = head_ids[h]
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_PARENT,
			elder_id, head_id2, 85, 0)
		next_rel += 1
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_CHILD,
			head_id2, elder_id, 85, 0)
		next_rel += 1
		if e % 4 == 0:
			_append_rel(relationships, next_rel,
				RelationshipRecord.TYPE_GRANDPARENT, elder_id, head_id2, 70, 0)
			next_rel += 1
			_append_rel(relationships, next_rel,
				RelationshipRecord.TYPE_CHILD, head_id2, elder_id, 70, 0)
			next_rel += 1
	# Freundschaften zwischen Kindern benachbarter Haushalte.
	for h in h_count:
		var kids: PackedInt32Array = child_ids_by_house[h]
		if kids.is_empty():
			continue
		var other: PackedInt32Array = child_ids_by_house[(h + 1) % h_count]
		if other.is_empty():
			continue
		var a: int = kids[0]
		var b: int = other[0]
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_FRIEND,
			a, b, 40, 0)
		next_rel += 1
		_append_rel(relationships, next_rel, RelationshipRecord.TYPE_FRIEND,
			b, a, 40, 0)
		next_rel += 1
	records.sort_custom(func(a, b): return (a as AgentRecord).id < (b as AgentRecord).id)
	return {
		"records": records,
		"households": households,
		"relationships": relationships,
	}


static func _add_record(records: Array, agent_id: int, sex: int, age: int,
		household_id: int, home_id: int, rng: RngStream, salt: int) -> void:
	var role: int = LifecycleRules.role_for_age(age)
	var job_id: int = 0
	var job_kind: int = AgentStore.JOB_NONE
	if role == AgentStore.ROLE_ADULT:
		var slot: int = (agent_id + salt) % 10
		if slot < 5:
			job_id = AgentRecords.JOB_FIELD
			job_kind = AgentStore.JOB_FIELD
		elif slot < 7:
			job_id = AgentRecords.JOB_APPRENTICE
			job_kind = AgentStore.JOB_WORKSHOP
		elif slot < 9:
			job_id = AgentRecords.JOB_HOUSEHOLD
			job_kind = AgentStore.JOB_NONE
		else:
			job_id = AgentRecords.JOB_LIGHT
			job_kind = AgentStore.JOB_WORKSHOP
	elif role == AgentStore.ROLE_YOUTH:
		job_id = AgentRecords.JOB_APPRENTICE
		job_kind = AgentStore.JOB_WORKSHOP
	elif role == AgentStore.ROLE_OLD:
		job_id = AgentRecords.JOB_LIGHT
		job_kind = AgentStore.JOB_WORKSHOP
	var names: Array = LifecycleRules.FEMALE_NAMES if sex == LifecycleRules.SEX_FEMALE \
		else LifecycleRules.MALE_NAMES
	var name: String = str(names[(agent_id * 7 + salt) % names.size()])
	var birth_day: int = -age * SimConfig.YEAR_DAYS - rng.next_range(SimConfig.YEAR_DAYS)
	records.append(AgentRecord.new(agent_id, name, sex, age, role,
		household_id, home_id, job_id, job_kind, birth_day))


static func _append_rel(relationships: Array, rel_id: int, rel_type: int,
		a: int, b: int, strength: int, since_day: int) -> void:
	relationships.append(RelationshipRecord.new(rel_id, rel_type, a, b,
		strength, since_day))


static func _insert_sorted(members: PackedInt32Array, agent_id: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var inserted: bool = false
	for member in members:
		if not inserted and agent_id < member:
			out.append(agent_id)
			inserted = true
		if member != agent_id:
			out.append(member)
	if not inserted:
		out.append(agent_id)
	return out
