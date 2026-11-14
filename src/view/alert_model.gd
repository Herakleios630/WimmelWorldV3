class_name AlertModel
extends RefCounted

## Alerts sind ausschließlich major/historic. Routine und notable erzeugen
## keinen Alert. Pro Tag gilt ein hartes Limit aus SimConfig.


static func for_day(store: ChronicleStore, sim: Simulation, day: int,
		limit: int = -1) -> Array:
	var max_alerts: int = limit
	if max_alerts < 0:
		max_alerts = sim.config.chronicle_alert_max_per_day
	var candidates: Array = []
	for event in store.events_for_day(day):
		var ce: ChronicleEvent = event
		if ce.importance >= SimEvent.IMPORTANCE_MAJOR:
			candidates.append(ce)
	candidates.sort_custom(func(a, b): return _less(a, b))
	var out: Array = []
	for i in mini(max_alerts, candidates.size()):
		var ce: ChronicleEvent = candidates[i]
		out.append({
			"id": ce.id,
			"time": ce.time,
			"time_text": SimClock.new(ce.time).time_string(),
			"importance": ce.importance,
			"category": ce.category,
			"type": ce.type,
			"template": ce.template_key,
			"text": ce.display_text(),
			"household_id": ce.household_id,
			"actor_ids": ce.actor_ids.duplicate(),
		})
	return out


static func count_for_day(store: ChronicleStore, day: int) -> int:
	var n: int = 0
	for event in store.events_for_day(day):
		if (event as ChronicleEvent).importance >= SimEvent.IMPORTANCE_MAJOR:
			n += 1
	return n


static func _less(a: ChronicleEvent, b: ChronicleEvent) -> bool:
	if a.importance != b.importance:
		return a.importance > b.importance
	if a.time != b.time:
		return a.time < b.time
	return a.id < b.id
