class_name BiographyModel
extends RefCounted

## Basis-Biografie aus der kuratierten Chronik. Kein Rohlog, keine erfundenen
## Fakten. Für tote Agenten bleibt der Record lesbar.


static func for_agent(sim: Simulation, agent_id: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if agent_id <= 0:
		return out
	var events: Array = []
	for event in sim.chronicle.all_events():
		var ce: ChronicleEvent = event
		if ce.actor_ids.has(agent_id) or ce.related_ids.has(agent_id):
			events.append(ce)
	events.sort_custom(func(a, b):
		if a.time != b.time:
			return a.time < b.time
		return a.id < b.id)
	for i in mini(8, events.size()):
		var ce: ChronicleEvent = events[i]
		out.append("Tag %d · %s" % [ce.time / SimConfig.TICKS_PER_DAY + 1,
			ce.display_text()])
	if out.is_empty():
		out.append("Noch keine Chronik-Einträge.")
	return out


static func status_line(sim: Simulation, agent_id: int) -> String:
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, agent_id)
	if rec == null:
		return ""
	if rec.death_day >= 0:
		return "verstorben an Tag %d (%s)" % [rec.death_day + 1,
			LifecycleRules.cause_name(rec.death_cause)]
	return "lebend"
