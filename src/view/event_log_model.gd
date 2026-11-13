class_name EventLogModel
extends RefCounted

## Read-only Zugriff für das Event-Log. Nutzt ausschließlich den Debug-Log;
## die G1a-Chronik bleibt intern/roh.


static func recent(sim: Simulation, limit: int = 12) -> Array:
	var out: Array = []
	for event in sim.logs.recent_debug(limit):
		var e: SimEvent = event
		out.append({
			"id": e.id,
			"time": e.time,
			"time_text": SimClock.new(e.time).time_string(),
			"type": e.type,
			"type_name": SimEvent.type_name(e.type),
			"template": e.template_key,
			"importance": e.importance,
			"agent_id": e.agent_id,
			"agent_name": _agent_name(sim, e.agent_id),
			"text": e.text,
			"data": e.data,
		})
	return out


static func _agent_name(sim: Simulation, agent_id: int) -> String:
	if agent_id <= 0:
		return "Weiler"
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, agent_id)
	return rec.name if rec != null else ("A%d" % agent_id)


static func count_type(sim: Simulation, type: int) -> int:
	var n: int = 0
	for event in sim.logs.debug_events:
		if (event as SimEvent).type == type:
			n += 1
	return n
