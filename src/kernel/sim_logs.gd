class_name SimLogs
extends RefCounted

## Getrennte Debug- und Chronik-Logs. Keiner ist Replay-Quelle.
## G1a-Chronik ist roh/intern (keine Kuratierung, keine Retention-Politik).

const DEBUG_CAPACITY: int = 20000
const CHRONICLE_CAPACITY: int = 5000

var debug_events: Array = []
var chronicle_events: Array = []
var next_event_id: int = 1


func emit(time_value: int, type: int, importance: int, agent_id: int,
		template_key: String, text: String = "", data: int = 0) -> SimEvent:
	var event: SimEvent = SimEvent.new(next_event_id, time_value, type, importance,
		agent_id, template_key, text, data)
	next_event_id += 1
	debug_events.append(event)
	if debug_events.size() > DEBUG_CAPACITY:
		debug_events.remove_at(0)
	if importance >= SimEvent.IMPORTANCE_NOTABLE:
		chronicle_events.append(event)
		if chronicle_events.size() > CHRONICLE_CAPACITY:
			chronicle_events.remove_at(0)
	return event


func recent_debug(limit: int) -> Array:
	var out: Array = []
	var start: int = maxi(0, debug_events.size() - limit)
	for i in range(start, debug_events.size()):
		out.append(debug_events[i])
	return out


func recent_chronicle(limit: int) -> Array:
	var out: Array = []
	var start: int = maxi(0, chronicle_events.size() - limit)
	for i in range(start, chronicle_events.size()):
		out.append(chronicle_events[i])
	return out


func debug_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	for event in debug_events:
		h = (event as SimEvent).hash_into(h)
	return h


func chronicle_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	for event in chronicle_events:
		h = (event as SimEvent).hash_into(h)
	return h


func clear_chronicle_only() -> void:
	chronicle_events.clear()


func restore(debug_list: Array, chronicle_list: Array, p_next_event_id: int) -> void:
	debug_events = debug_list
	chronicle_events = chronicle_list
	next_event_id = p_next_event_id
