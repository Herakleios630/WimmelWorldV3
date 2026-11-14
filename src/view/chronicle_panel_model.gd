class_name ChroniclePanelModel
extends RefCounted

## Read-only Filter-/Listenmodell für das Chronik-Panel.
## Filter: Agent, Haushalt/Familie, Siedlung, Importance, Zeitraum, Kategorie.

const SETTLEMENT_ID: int = 1


static func query(sim: Simulation, filters: Dictionary = {},
		limit: int = 80) -> Array:
	var store: ChronicleStore = sim.chronicle
	var from_time: int = int(filters.get("from_time", -1))
	var to_time: int = int(filters.get("to_time", -1))
	var importance_min: int = int(filters.get("importance_min", 0))
	var agent_id: int = int(filters.get("agent_id", 0))
	var household_id: int = int(filters.get("household_id", 0))
	var settlement_id: int = int(filters.get("settlement_id", 0))
	var category: String = str(filters.get("category", ""))
	var out: Array = []
	for event in store.all_events():
		var ce: ChronicleEvent = event
		if ce.importance < importance_min:
			continue
		if from_time >= 0 and ce.last_time < from_time:
			continue
		if to_time >= 0 and ce.first_time >= to_time:
			continue
		if agent_id > 0 and not ce.actor_ids.has(agent_id) \
				and not ce.related_ids.has(agent_id):
			continue
		if household_id > 0 and ce.household_id != household_id:
			continue
		if settlement_id > 0 and ce.location_id != settlement_id:
			continue
		if category != "" and ce.category != category:
			continue
		out.append(to_entry(ce))
	out.sort_custom(func(a, b): return _entry_less(a, b))
	if out.size() > limit:
		out.resize(limit)
	return out


static func to_entry(ce: ChronicleEvent) -> Dictionary:
	return {
		"id": ce.id,
		"time": ce.time,
		"time_text": SimClock.new(ce.time).time_string(),
		"day": ce.time / SimConfig.TICKS_PER_DAY,
		"type": ce.type,
		"type_name": SimEvent.type_name(ce.type),
		"importance": ce.importance,
		"category": ce.category,
		"template": ce.template_key,
		"text": ce.display_text(),
		"count": ce.count,
		"actor_ids": ce.actor_ids.duplicate(),
		"related_ids": ce.related_ids.duplicate(),
		"household_id": ce.household_id,
		"location_id": ce.location_id,
		"causes": ce.causes.duplicate(),
	}


static func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["time"]) != int(b["time"]):
		return int(a["time"]) > int(b["time"])
	return int(a["id"]) > int(b["id"])


static func digest(sim: Simulation, day: int) -> PackedStringArray:
	return sim.chronicle.digest_lines(day, sim)
