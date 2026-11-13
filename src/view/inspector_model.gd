class_name InspectorModel
extends RefCounted

## Read-only View-Model für den Inspector. Liest Simulation, schreibt nie.
## G1a zeigt Hunger/Energie/Sozial, Home, Job, Aktivität, Position.


static func for_agent(sim: Simulation, agent_id: int) -> Dictionary:
	var row: int = sim.store.row_for_id(agent_id)
	if row < 0 or row >= sim.store.count:
		return {}
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, agent_id)
	if rec == null:
		return {}
	var now: int = sim.clock.now
	var pos: Vector2 = sim.current_position(row)
	var role: int = sim.store.role[row]
	return {
		"id": agent_id,
		"name": rec.name,
		"sex": rec.sex,
		"age": sim.store.age_years[row],
		"role": role,
		"role_name": AgentStore.role_name(role),
		"household_id": sim.store.household_id[row],
		"home_id": sim.store.home_id[row],
		"home_name": sim.world.building_name(sim.store.home_id[row]),
		"job_id": sim.store.job_id[row],
		"job_name": AgentRecords.job_name(sim.store.job_id[row]),
		"activity": sim.store.activity[row],
		"activity_name": AgentStore.activity_name(sim.store.activity[row]),
		"hunger": NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_HUNGER, sim.config),
		"energy": NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_ENERGY, sim.config),
		"social": NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_SOCIAL, sim.config),
		"position": pos,
		"next_event": sim.store.next_event[row],
		"dead": sim.store.alive[row] == 0,
		"traveling": sim.store.activity[row] == AgentStore.ACT_TRAVEL,
	}


static func needs_snapshot(sim: Simulation, agent_id: int) -> PackedFloat64Array:
	var row: int = sim.store.row_for_id(agent_id)
	var out: PackedFloat64Array = PackedFloat64Array()
	if row < 0:
		return out
	var now: int = sim.clock.now
	out.append(NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_HUNGER, sim.config))
	out.append(NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_ENERGY, sim.config))
	out.append(NeedsModel.value_at(sim.store, row, now, NeedsModel.NEED_SOCIAL, sim.config))
	return out

