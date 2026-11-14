class_name Replay
extends RefCounted

## Replay = Re-Simulation aus Seed + Konfiguration + Save-Snapshot.
## Die Chronik-/Debug-Logs sind niemals Replay-Quelle.

const REPLAY_VERSION: int = 1


static func replay_meta(sim: Simulation) -> Dictionary:
	return {
		"version": REPLAY_VERSION,
		"seed": sim.config.seed,
		"config_hash": sim.config.config_hash(),
		"snapshot_time": sim.clock.now,
	}


static func run_from_snapshot(save_path: String, target_time: int,
		chunk_size: int = 3600) -> Dictionary:
	var loaded: Dictionary = Simulation.load_from(save_path)
	if not loaded.get("ok", false):
		return {"ok": false, "error": loaded.get("error", "load_failed")}
	var sim: Simulation = loaded["sim"]
	var start_state: int = sim.state_hash()
	var start_meta: Dictionary = replay_meta(sim)
	_advance_chunked(sim, target_time, chunk_size)
	return {
		"ok": true,
		"sim": sim,
		"meta": start_meta,
		"start_state": start_state,
		"state_hash": sim.state_hash(),
		"event_hash": sim.event_hash(),
		"curated_hash": sim.curated_chronicle_hash(),
	}


static func verify_log_independence(save_path: String, target_time: int,
		chunk_size: int = 3600) -> Dictionary:
	var control_loaded: Dictionary = Simulation.load_from(save_path)
	var truncated_loaded: Dictionary = Simulation.load_from(save_path)
	if not control_loaded.get("ok", false) or not truncated_loaded.get("ok", false):
		return {"ok": false, "error": "load_failed"}
	var control: Simulation = control_loaded["sim"]
	var truncated: Simulation = truncated_loaded["sim"]
	var first_new_event_id: int = control.logs.next_event_id
	truncated.logs.chronicle_events.clear()
	truncated.logs.debug_events.clear()
	truncated.chronicle.clear_all(truncated.clock.day_index())
	_advance_chunked(control, target_time, chunk_size)
	_advance_chunked(truncated, target_time, chunk_size)
	var control_signatures: PackedStringArray = PackedStringArray()
	for event in control.logs.debug_events:
		var ce: SimEvent = event
		if ce.id >= first_new_event_id:
			control_signatures.append(_signature(ce))
	var truncated_signatures: PackedStringArray = PackedStringArray()
	for event in truncated.logs.debug_events:
		var te: SimEvent = event
		truncated_signatures.append(_signature(te))
	var state_equal: bool = control.state_hash() == truncated.state_hash()
	var events_equal: bool = control_signatures == truncated_signatures
	return {
		"ok": state_equal and events_equal,
		"state_equal": state_equal,
		"events_equal": events_equal,
		"new_events": control_signatures.size(),
		"control_state": control.state_hash(),
		"truncated_state": truncated.state_hash(),
	}


static func verify_triplet(save_path: String, target_time: int) -> Dictionary:
	var chunks: PackedInt32Array = PackedInt32Array([1, 60, 3600])
	var state_hashes: PackedStringArray = PackedStringArray()
	var event_hashes: PackedStringArray = PackedStringArray()
	var curated_hashes: PackedStringArray = PackedStringArray()
	for i in chunks.size():
		var loaded: Dictionary = Simulation.load_from(save_path)
		if not loaded.get("ok", false):
			return {"ok": false, "error": loaded.get("error", "load_failed")}
		var sim: Simulation = loaded["sim"]
		_advance_chunked(sim, target_time, chunks[i])
		state_hashes.append(HashUtil.hex(sim.state_hash()))
		event_hashes.append(HashUtil.hex(sim.event_hash()))
		curated_hashes.append(HashUtil.hex(sim.curated_chronicle_hash()))
	var states_equal: bool = state_hashes[0] == state_hashes[1] \
		and state_hashes[1] == state_hashes[2]
	var events_equal: bool = event_hashes[0] == event_hashes[1] \
		and event_hashes[1] == event_hashes[2]
	var curated_equal: bool = curated_hashes[0] == curated_hashes[1] \
		and curated_hashes[1] == curated_hashes[2]
	return {
		"ok": states_equal and events_equal and curated_equal,
		"state_equal": states_equal,
		"events_equal": events_equal,
		"curated_equal": curated_equal,
		"state_hashes": state_hashes,
		"event_hashes": event_hashes,
		"curated_hashes": curated_hashes,
	}


static func _advance_chunked(sim: Simulation, target_time: int, chunk_size: int) -> void:
	var chunk: int = maxi(1, chunk_size)
	while sim.clock.now < target_time:
		sim.advance_to(mini(target_time, sim.clock.now + chunk))


static func _signature(event: SimEvent) -> String:
	return "%d|%d|%d|%d|%d|%s|%s|%d" % [event.id, event.time, event.type,
		event.importance, event.agent_id, event.template_key, event.text, event.data]
