class_name StoryOfDay
extends RefCounted

## Deterministische Story-of-the-Day-Auswahl.
##
## Fokus ist reiner View-Input: Er beeinflusst nur die Auswahl/Reihenfolge der
## bereits kuratierten Events, niemals die Chronik-Events selbst.

const MAX_STORY: int = 7


static func for_day(store: ChronicleStore, sim: Simulation, day: int,
		focus_agent_id: int = 0, focus_household_id: int = 0) -> Array:
	var household_id: int = focus_household_id
	if household_id <= 0 and focus_agent_id > 0:
		var row: int = sim.store.row_for_id(focus_agent_id)
		if row >= 0:
			household_id = sim.store.household_id[row]
	var major: Array = []
	var notable: Array = []
	for event in store.events_for_day(day):
		var ce: ChronicleEvent = event
		if ce.importance >= SimEvent.IMPORTANCE_MAJOR:
			major.append(ce)
		elif ce.importance == SimEvent.IMPORTANCE_NOTABLE:
			notable.append(ce)
	major.sort_custom(func(a, b): return _less(a, b, focus_agent_id, household_id))
	notable.sort_custom(func(a, b): return _less(a, b, focus_agent_id, household_id))
	var picked: Array = []
	for i in mini(MAX_STORY - 1, major.size()):
		picked.append(major[i])
	if notable.size() > 0:
		picked.append(notable[0])
	var max_allowed: int = mini(MAX_STORY, sim.config.chronicle_story_max_per_day)
	while picked.size() > max_allowed:
		picked.remove_at(picked.size() - 1)
	var out: Array = []
	for event in picked:
		out.append(to_entry(event, focus_agent_id, household_id))
	return out


static func _less(a: ChronicleEvent, b: ChronicleEvent, focus_agent_id: int,
		household_id: int) -> bool:
	if a.importance != b.importance:
		return a.importance > b.importance
	var a_relevant: bool = _is_relevant(a, focus_agent_id, household_id)
	var b_relevant: bool = _is_relevant(b, focus_agent_id, household_id)
	if a_relevant != b_relevant:
		return a_relevant
	if a.time != b.time:
		return a.time < b.time
	return a.id < b.id


static func _is_relevant(event: ChronicleEvent, focus_agent_id: int,
		household_id: int) -> bool:
	if focus_agent_id > 0 and event.actor_ids.has(focus_agent_id):
		return true
	if focus_agent_id > 0 and event.related_ids.has(focus_agent_id):
		return true
	if household_id > 0 and event.household_id == household_id:
		return true
	return false


static func to_entry(event: ChronicleEvent, focus_agent_id: int,
		household_id: int) -> Dictionary:
	return {
		"id": event.id,
		"time": event.time,
		"time_text": SimClock.new(event.time).time_string(),
		"type": event.type,
		"type_name": SimEvent.type_name(event.type),
		"importance": event.importance,
		"category": event.category,
		"text": event.display_text(),
		"count": event.count,
		"focus_relevant": _is_relevant(event, focus_agent_id, household_id),
		"causes": event.causes.duplicate(),
	}
