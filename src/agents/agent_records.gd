class_name AgentRecords
extends RefCounted

## G1a-Startbevölkerung: exakt 10 Agenten, 3 Haushalte (v3-g1-spec.md §4).
## IDs sind stabil und werden nie wiederverwendet.

const HOUSE_H1: int = 1
const HOUSE_H2: int = 2
const HOUSE_H3: int = 3
const BUILDING_GRANARY: int = 4
const BUILDING_WELL: int = 5
const BUILDING_WORKSHOP: int = 6
const BUILDING_FIELD: int = 7

const JOB_FIELD: int = 1
const JOB_HOUSEHOLD: int = 2
const JOB_APPRENTICE: int = 3
const JOB_LIGHT: int = 4


static func job_name(job_id: int) -> String:
	match job_id:
		JOB_FIELD: return "Landwirt"
		JOB_HOUSEHOLD: return "Haushalt/Köchin"
		JOB_APPRENTICE: return "Lehrling"
		JOB_LIGHT: return "leichte Aufgaben"
	return "ohne"


static func default_agents() -> Array:
	var out: Array = []
	out.append(AgentRecord.new(1, "Arnd", 0, 38, AgentStore.ROLE_ADULT, 1, HOUSE_H1, JOB_FIELD, AgentStore.JOB_FIELD))
	out.append(AgentRecord.new(2, "Alma", 1, 35, AgentStore.ROLE_ADULT, 1, HOUSE_H1, JOB_FIELD, AgentStore.JOB_FIELD))
	out.append(AgentRecord.new(3, "Clara", 1, 12, AgentStore.ROLE_CHILD, 1, HOUSE_H1, 0, AgentStore.JOB_NONE))
	out.append(AgentRecord.new(4, "Clemens", 0, 6, AgentStore.ROLE_CHILD, 1, HOUSE_H1, 0, AgentStore.JOB_NONE))
	out.append(AgentRecord.new(5, "Bodo", 0, 30, AgentStore.ROLE_ADULT, 2, HOUSE_H2, JOB_FIELD, AgentStore.JOB_FIELD))
	out.append(AgentRecord.new(6, "Berta", 1, 28, AgentStore.ROLE_ADULT, 2, HOUSE_H2, JOB_HOUSEHOLD, AgentStore.JOB_NONE))
	out.append(AgentRecord.new(7, "Bruno", 0, 3, AgentStore.ROLE_CHILD, 2, HOUSE_H2, 0, AgentStore.JOB_NONE))
	out.append(AgentRecord.new(8, "Gustav", 0, 70, AgentStore.ROLE_OLD, 3, HOUSE_H3, JOB_LIGHT, AgentStore.JOB_WORKSHOP))
	out.append(AgentRecord.new(9, "Georg", 0, 42, AgentStore.ROLE_ADULT, 3, HOUSE_H3, JOB_FIELD, AgentStore.JOB_FIELD))
	out.append(AgentRecord.new(10, "Greta", 1, 17, AgentStore.ROLE_YOUTH, 3, HOUSE_H3, JOB_APPRENTICE, AgentStore.JOB_WORKSHOP))
	return out


static func default_households() -> Array:
	var out: Array = []
	out.append(HouseholdRecord.new(1, HOUSE_H1, PackedInt32Array([1, 2, 3, 4])))
	out.append(HouseholdRecord.new(2, HOUSE_H2, PackedInt32Array([5, 6, 7])))
	out.append(HouseholdRecord.new(3, HOUSE_H3, PackedInt32Array([8, 9, 10])))
	return out


static func default_relationships() -> Array:
	var out: Array = []
	var next_id: int = 1
	# Partner
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARTNER, 1, 2, 80, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARTNER, 5, 6, 80, 0)); next_id += 1
	# Eltern -> Kinder (beide Richtungen als getrennte Records)
	for child in [3, 4]:
		out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 1, child, 90, 0)); next_id += 1
		out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 2, child, 90, 0)); next_id += 1
		out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, child, 1, 90, 0)); next_id += 1
		out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, child, 2, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 5, 7, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 6, 7, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, 7, 5, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, 7, 6, 90, 0)); next_id += 1
	# H3: A5 Vater von A6, A6 Vater von A7, A5 Großvater von A7.
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 8, 9, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, 9, 8, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_PARENT, 9, 10, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, 10, 9, 90, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_GRANDPARENT, 8, 10, 70, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_CHILD, 10, 8, 70, 0)); next_id += 1
	# Erste Freundschaft C1-C3.
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_FRIEND, 3, 7, 40, 0)); next_id += 1
	out.append(RelationshipRecord.new(next_id, RelationshipRecord.TYPE_FRIEND, 7, 3, 40, 0)); next_id += 1
	return out


static func record_by_id(records: Array, agent_id: int) -> AgentRecord:
	for record in records:
		if (record as AgentRecord).id == agent_id:
			return record
	return null


static func records_hash(records: Array) -> int:
	var h: int = HashUtil.FNV_OFFSET
	for record in records:
		h = HashUtil.mix(h, (record as AgentRecord).state_hash())
	return h
