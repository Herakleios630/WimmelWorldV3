class_name FollowModel
extends RefCounted

## Follow ist reine View-Logik: Sie liest Position und Lebendstatus, schreibt
## nie in die Simulation.


static func has_target(sim: Simulation, agent_id: int) -> bool:
	if sim == null or agent_id <= 0:
		return false
	var row: int = sim.store.row_for_id(agent_id)
	return row >= 0 and sim.store.alive[row] != 0


static func target_tile(sim: Simulation, agent_id: int) -> Vector2:
	if not has_target(sim, agent_id):
		return Vector2.ZERO
	return sim.current_position(sim.store.row_for_id(agent_id))


static func step(sim: Simulation, view_state: ViewState,
		current_camera_tile: Vector2, _delta: float) -> Vector2:
	if view_state == null or not view_state.follow_enabled:
		return current_camera_tile
	if not has_target(sim, view_state.follow_agent_id):
		return current_camera_tile
	return target_tile(sim, view_state.follow_agent_id)


static func pick_default_target(sim: Simulation, preferred_id: int = 0) -> int:
	if has_target(sim, preferred_id):
		return preferred_id
	if sim == null:
		return 0
	for row in sim.store.count:
		if sim.store.alive[row] != 0:
			return sim.store.ids[row]
	return 0
