class_name G1aTestUtil
extends RefCounted


static func new_sim(seed_value: int = SimConfig.DEFAULT_SEED) -> Simulation:
	var config: SimConfig = SimConfig.new()
	config.seed = seed_value
	return Simulation.create(config)


static func row_of(sim: Simulation, agent_id: int) -> int:
	return sim.store.row_for_id(agent_id)


static func abs_time(day: int, hour: int, minute: int = 0, second: int = 0) -> int:
	return day * SimConfig.TICKS_PER_DAY + hour * 3600 + minute * 60 + second


static func set_need(sim: Simulation, agent_id: int, need: int, value: float,
		wake: bool = true) -> void:
	var row: int = row_of(sim, agent_id)
	sim.store.need_time[row] = sim.clock.now
	match need:
		NeedsModel.NEED_HUNGER:
			sim.store.hunger[row] = value
		NeedsModel.NEED_ENERGY:
			sim.store.energy[row] = value
		NeedsModel.NEED_SOCIAL:
			sim.store.social[row] = value
		NeedsModel.NEED_HYGIENE:
			sim.store.hygiene[row] = value
		NeedsModel.NEED_FUN:
			sim.store.fun[row] = value
		NeedsModel.NEED_HEALTH:
			sim.store.health[row] = value
	if need == NeedsModel.NEED_HUNGER:
		sim.store.meal_retry[row] = 0
	if wake:
		sim.request_wake_by_id(agent_id, sim.clock.now + 1)


static func events_of(sim: Simulation, type: int, agent_id: int = -1) -> Array:
	var out: Array = []
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.type != type:
			continue
		if agent_id > 0 and e.agent_id != agent_id:
			continue
		out.append(e)
	return out


static func count_events(sim: Simulation, type: int, agent_id: int = -1) -> int:
	return events_of(sim, type, agent_id).size()


static func first_event(sim: Simulation, type: int, agent_id: int = -1) -> SimEvent:
	var list: Array = events_of(sim, type, agent_id)
	return list[0] if list.size() > 0 else null


static func temp_path(name: String) -> String:
	return "user://g1a_test_%s.bin" % name


static func remove_temp(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


static func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


static func code_uses_dictionary(path: String) -> bool:
	var text: String = read_text(path)
	for line in text.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		if stripped.contains("Dictionary"):
			return true
	return false
