class_name ChronicleStore
extends RefCounted

## Kuratierte Chronik mit drei Retention-Ebenen:
## - recent: letzte N Sim-Tage, nur notable+
## - summaries: Tagesdigests für 1 Sim-Jahr
## - historic: dauerhafte Jahres-/Meilenstein-Events, budgetiert
##
## Routine-Events werden an der Quelle aggregiert und nie einzeln gespeichert.
## Zusätzlich werden verdrängte Kausalitäts-Anker kompakt gehalten, damit ein
## „Warum?“-Link nicht auf einen fehlenden Record zeigt.

const CHRONICLE_SCHEMA: int = 1
const ANCHOR_MAX: int = 5000
const MAX_ITEMS: int = 2000000

var events: Array = []
var summaries: Array = []
var historic: Array = []
var anchors: Array = []
var routine: Dictionary = {}
var latest: Dictionary = {}

var next_id: int = 1
var day_index: int = 0
var ingested_total: int = 0
var routine_events: int = 0
var deduped_total: int = 0
var aggregated_total: int = 0
var pruned_recent: int = 0
var pruned_historic: int = 0
var pruned_anchors: int = 0

var max_recent_days: int = 7
var max_recent_events: int = 250000
var max_summary_days: int = 30
var max_summaries: int = 50000
var max_historic: int = 10000


func _init(config: SimConfig = null) -> void:
	apply_config(config)


func apply_config(config: SimConfig) -> void:
	if config == null:
		return
	max_recent_days = maxi(0, config.chronicle_recent_days)
	max_recent_events = maxi(1, config.chronicle_recent_max_events)
	max_summary_days = maxi(1, config.chronicle_summary_days)
	max_summaries = maxi(1, config.chronicle_summary_max)
	max_historic = maxi(1, config.chronicle_historic_max)


func ingest(event: SimEvent, sim: Simulation) -> void:
	ingested_total += 1
	var meta: Dictionary = ChronicleCurator.classify(event)
	var importance: int = int(meta["importance"])
	if importance == SimEvent.IMPORTANCE_ROUTINE:
		routine_events += 1
		aggregated_total += 1
		_routine_add(event, meta)
		return
	var key: String = ChronicleCurator.dedup_key(event, meta)
	if key != "":
		var existing: ChronicleEvent = _find_dedup(key, event.time)
		if existing != null:
			existing.add_source(event.id, event.time)
			existing.merge_related(ChronicleCurator.related_agent_ids(event))
			deduped_total += 1
			aggregated_total += 1
			_update_latest(existing)
			return
	var ce: ChronicleEvent = _make_event(event, sim, meta, key)
	if importance == SimEvent.IMPORTANCE_HISTORIC:
		historic.append(ce)
	else:
		events.append(ce)
	_update_latest(ce)


func _routine_add(event: SimEvent, meta: Dictionary) -> void:
	var day: int = event.time / SimConfig.TICKS_PER_DAY
	var key: String = "%d:%d:%d" % [day, event.type, event.agent_id]
	if routine.has(key):
		var bucket: Dictionary = routine[key]
		bucket["count"] = int(bucket["count"]) + 1
		bucket["last"] = event.time
	else:
		routine[key] = {
			"count": 1,
			"first": event.time,
			"last": event.time,
			"type": event.type,
			"agent": event.agent_id,
			"category": str(meta["category"]),
		}


func _make_event(event: SimEvent, sim: Simulation, meta: Dictionary,
		key: String) -> ChronicleEvent:
	var ce: ChronicleEvent = ChronicleEvent.new(next_id, event.time, event.type,
		int(meta["importance"]), str(meta["category"]),
		str(meta["template_key"]), ChronicleCurator.text_for(event, sim))
	next_id += 1
	if event.agent_id > 0:
		ce.actor_ids.append(event.agent_id)
		var row: int = sim.store.row_for_id(event.agent_id)
		if row >= 0:
			ce.household_id = sim.store.household_id[row]
	ce.location_id = 1
	ce.related_ids = ChronicleCurator.related_agent_ids(event)
	ce.data = event.data
	ce.dedup_key = key
	ce.source_ids.append(event.id)
	ce.first_time = event.time
	ce.last_time = event.time
	ce.causes = _causal_links(event, ce)
	return ce


func _causal_links(event: SimEvent, ce: ChronicleEvent) -> PackedInt32Array:
	var causes: PackedInt32Array = PackedInt32Array()
	match event.type:
		SimEvent.T_BIRTH:
			if ce.related_ids.size() > 0:
				_append_cause(causes, "pregnancy:%d" % ce.related_ids[0])
		SimEvent.T_DEATH:
			if event.data == LifecycleRules.CAUSE_BIRTH:
				_append_cause(causes, "pregnancy:%d" % event.agent_id)
			elif event.data == LifecycleRules.CAUSE_HEALTH:
				_append_cause(causes, "shortage:%d" % event.agent_id)
				_append_cause(causes, "meal_skipped:%d" % event.agent_id)
		SimEvent.T_MEAL_SKIPPED:
			_append_cause(causes, "shortage:%d" % event.agent_id)
		SimEvent.T_SHORTAGE:
			_append_cause(causes, "meal_skipped:%d" % event.agent_id)
		SimEvent.T_FIELD_RIPE:
			_append_cause(causes, "field_sown")
		SimEvent.T_FIELD_HARVEST:
			_append_cause(causes, "field_ripe")
			_append_cause(causes, "field_sown")
		SimEvent.T_HOUSEHOLD_DISSOLVED:
			_append_cause(causes, "death:%d" % event.data)
		SimEvent.T_HOUSEHOLD_REASSIGN, SimEvent.T_HOUSEHOLD_WARD:
			_append_cause(causes, "household_dissolved:%d" % event.data)
	return causes


func _append_cause(causes: PackedInt32Array, key: String) -> void:
	if not latest.has(key):
		return
	var event_id: int = int(latest[key])
	if event_id <= 0 or causes.has(event_id):
		return
	if _resolve_event(event_id) == null:
		return
	causes.append(event_id)


func _update_latest(ce: ChronicleEvent) -> void:
	var agent_id: int = ce.actor_ids[0] if ce.actor_ids.size() > 0 else 0
	match ce.type:
		SimEvent.T_PREGNANCY:
			latest["pregnancy:%d" % agent_id] = ce.id
		SimEvent.T_BIRTH:
			latest["birth:%d" % agent_id] = ce.id
		SimEvent.T_DEATH:
			latest["death:%d" % ce.household_id] = ce.id
		SimEvent.T_SHORTAGE:
			latest["shortage:%d" % agent_id] = ce.id
		SimEvent.T_MEAL_SKIPPED:
			latest["meal_skipped:%d" % agent_id] = ce.id
		SimEvent.T_FIELD_SOWN:
			latest["field_sown"] = ce.id
		SimEvent.T_FIELD_RIPE:
			latest["field_ripe"] = ce.id
		SimEvent.T_FIELD_HARVEST:
			latest["field_harvest"] = ce.id
		SimEvent.T_HOUSEHOLD_DISSOLVED:
			latest["household_dissolved:%d" % ce.data] = ce.id
		SimEvent.T_YEAR_SUMMARY:
			latest["year_summary"] = ce.id


func _find_dedup(key: String, at_time: int) -> ChronicleEvent:
	var window: int = SimConfig.TICKS_PER_DAY
	for i in range(events.size() - 1, -1, -1):
		var event: ChronicleEvent = events[i]
		if event.dedup_key == key and at_time - event.last_time <= window:
			return event
	for i in range(historic.size() - 1, -1, -1):
		var historic_event: ChronicleEvent = historic[i]
		if historic_event.dedup_key == key and at_time - historic_event.last_time <= window:
			return historic_event
	return null


## Wird vom Tages-Tick aufgerufen. Finalisiert alle noch offenen Tage bis
## einschließlich new_day-1 und wendet danach die Retention an.
func on_day_tick(new_day: int, sim: Simulation) -> void:
	if new_day <= day_index:
		return
	var day: int = day_index
	while day < new_day:
		_finalize_day(day, sim)
		day += 1
	day_index = new_day
	_prune(sim)


func _finalize_day(day: int, sim: Simulation) -> void:
	if _summary_by_day(day) != null:
		_clear_routine_day(day)
		return
	var day_start: int = day * SimConfig.TICKS_PER_DAY
	var day_end: int = day_start + SimConfig.TICKS_PER_DAY
	var day_events: Array = events_for_day(day)
	var lines: PackedStringArray = _build_lines_for_day(day, sim)
	var summary: ChronicleSummary = ChronicleSummary.new(day, day_start,
		day_end, lines)
	for event in day_events:
		var ce: ChronicleEvent = event
		summary.event_ids.append(ce.id)
		match ce.importance:
			SimEvent.IMPORTANCE_NOTABLE:
				summary.notable_count += 1
			SimEvent.IMPORTANCE_MAJOR:
				summary.major_count += 1
			SimEvent.IMPORTANCE_HISTORIC:
				summary.historic_count += 1
	summary.routine_count = _routine_count_for_day(day)
	summaries.append(summary)
	_clear_routine_day(day)


func _build_lines_for_day(day: int, sim: Simulation) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var day_events: Array = events_for_day(day)
	day_events.sort_custom(func(a, b): return _event_less(a, b))
	for i in mini(4, day_events.size()):
		out.append((day_events[i] as ChronicleEvent).display_text())
	var routine_lines: PackedStringArray = _routine_lines_for_day(day, sim)
	for i in routine_lines.size():
		if out.size() >= 3:
			break
		out.append(routine_lines[i])
	if out.is_empty():
		out.append("Ruhiger Tag im Weiler.")
	elif out.size() < 3:
		out.append("Im Weiler blieb es sonst ruhig.")
		if out.size() < 3:
			out.append("Keine weiteren besonderen Ereignisse.")
	while out.size() > 7:
		out.remove_at(out.size() - 1)
	return out


func _routine_lines_for_day(day: int, sim: Simulation) -> PackedStringArray:
	var counts: Dictionary = {}
	var day_start: int = day * SimConfig.TICKS_PER_DAY
	var day_end: int = day_start + SimConfig.TICKS_PER_DAY
	for key in routine:
		var bucket: Dictionary = routine[key]
		var first: int = int(bucket["first"])
		var last: int = int(bucket["last"])
		if last < day_start or first >= day_end:
			continue
		var agent_id: int = int(bucket["agent"])
		if agent_id <= 0:
			continue
		counts[agent_id] = int(counts.get(agent_id, 0)) + int(bucket["count"])
	var agent_ids: Array = counts.keys()
	agent_ids.sort()
	var out: PackedStringArray = PackedStringArray()
	for agent_id in agent_ids:
		var name: String = "Weiler"
		var rec: AgentRecord = AgentRecords.record_by_id(sim.records, int(agent_id))
		if rec != null:
			name = rec.name
		out.append("%s: %d Alltagsaktivitäten" % [name, int(counts[agent_id])])
	return out


func _routine_count_for_day(day: int) -> int:
	var total: int = 0
	var day_start: int = day * SimConfig.TICKS_PER_DAY
	var day_end: int = day_start + SimConfig.TICKS_PER_DAY
	for key in routine:
		var bucket: Dictionary = routine[key]
		var first: int = int(bucket["first"])
		var last: int = int(bucket["last"])
		if last >= day_start and first < day_end:
			total += int(bucket["count"])
	return total


func _clear_routine_day(day: int) -> void:
	var day_start: int = day * SimConfig.TICKS_PER_DAY
	var day_end: int = day_start + SimConfig.TICKS_PER_DAY
	var remove_keys: Array = []
	for key in routine:
		var bucket: Dictionary = routine[key]
		var last: int = int(bucket["last"])
		var first: int = int(bucket["first"])
		if last < day_end and first < day_end:
			remove_keys.append(key)
	for key in remove_keys:
		routine.erase(key)


func _prune(sim: Simulation) -> void:
	var cutoff_time: int = (day_index - max_recent_days) * SimConfig.TICKS_PER_DAY
	var anchor_cutoff: int = (day_index - max_summary_days) * SimConfig.TICKS_PER_DAY
	var keep: Array = []
	for event in events:
		var ce: ChronicleEvent = event
		if ce.last_time >= cutoff_time:
			keep.append(ce)
		elif _is_cause_anchor(ce.id) and ce.time >= anchor_cutoff:
			anchors.append(ce)
			pruned_recent += 1
		else:
			pruned_recent += 1
	events = keep
	while events.size() > max_recent_events:
		var retired: ChronicleEvent = events.pop_front()
		if _is_cause_anchor(retired.id) and retired.time >= anchor_cutoff:
			anchors.append(retired)
		pruned_recent += 1
	var kept_summaries: Array = []
	for summary in summaries:
		if int((summary as ChronicleSummary).day) >= day_index - max_summary_days:
			kept_summaries.append(summary)
	summaries = kept_summaries
	while summaries.size() > max_summaries:
		summaries.pop_front()
	var kept_historic: Array = []
	for event in historic:
		kept_historic.append(event)
	historic = kept_historic
	while historic.size() > max_historic:
		historic.pop_front()
		pruned_historic += 1
	var kept_anchors: Array = []
	for event in anchors:
		if (event as ChronicleEvent).time >= anchor_cutoff:
			kept_anchors.append(event)
		else:
			pruned_anchors += 1
	anchors = kept_anchors
	while anchors.size() > ANCHOR_MAX:
		anchors.pop_front()
		pruned_anchors += 1


func _is_cause_anchor(event_id: int) -> bool:
	for key in latest:
		if int(latest[key]) == event_id:
			return true
	for event in events:
		if (event as ChronicleEvent).causes.has(event_id):
			return true
	for event in historic:
		if (event as ChronicleEvent).causes.has(event_id):
			return true
	for event in anchors:
		if (event as ChronicleEvent).causes.has(event_id):
			return true
	return false


func events_for_day(day: int) -> Array:
	var out: Array = []
	var start_time: int = day * SimConfig.TICKS_PER_DAY
	var end_time: int = start_time + SimConfig.TICKS_PER_DAY
	for event in events:
		var ce: ChronicleEvent = event
		if ce.last_time >= start_time and ce.first_time < end_time:
			out.append(ce)
	for event in historic:
		var he: ChronicleEvent = event
		if he.last_time >= start_time and he.first_time < end_time:
			out.append(he)
	for event in anchors:
		var ae: ChronicleEvent = event
		if ae.last_time >= start_time and ae.first_time < end_time:
			out.append(ae)
	out.sort_custom(func(a, b): return _event_less(a, b))
	return out


func _event_less(a: ChronicleEvent, b: ChronicleEvent) -> bool:
	if a.importance != b.importance:
		return a.importance > b.importance
	if a.time != b.time:
		return a.time < b.time
	return a.id < b.id


func summary_for_day(day: int) -> ChronicleSummary:
	return _summary_by_day(day)


func _summary_by_day(day: int) -> ChronicleSummary:
	for summary in summaries:
		if (summary as ChronicleSummary).day == day:
			return summary
	return null


func digest_lines(day: int, sim: Simulation) -> PackedStringArray:
	var summary: ChronicleSummary = _summary_by_day(day)
	if summary != null:
		return summary.lines.duplicate()
	return _build_lines_for_day(day, sim)


func resolve_event(event_id: int) -> ChronicleEvent:
	return _resolve_event(event_id)


func _resolve_event(event_id: int) -> ChronicleEvent:
	for event in events:
		if (event as ChronicleEvent).id == event_id:
			return event
	for event in historic:
		if (event as ChronicleEvent).id == event_id:
			return event
	for event in anchors:
		if (event as ChronicleEvent).id == event_id:
			return event
	return null


func all_events() -> Array:
	var out: Array = []
	out.append_array(events)
	out.append_array(historic)
	out.append_array(anchors)
	out.sort_custom(func(a, b): return _event_less(a, b))
	return out


func stored_event_count() -> int:
	return events.size() + historic.size()


func dedup_ratio() -> float:
	if ingested_total <= 0:
		return 1.0
	var ratio: float = 1.0 - float(stored_event_count()) / float(ingested_total)
	return clampf(ratio, 0.0, 1.0)


func metrics() -> Dictionary:
	return {
		"ingested": ingested_total,
		"routine_events": routine_events,
		"stored_recent": events.size(),
		"stored_historic": historic.size(),
		"stored_summaries": summaries.size(),
		"stored_anchors": anchors.size(),
		"deduped": deduped_total,
		"aggregated": aggregated_total,
		"dedup_ratio": dedup_ratio(),
		"pruned_recent": pruned_recent,
		"pruned_historic": pruned_historic,
		"pruned_anchors": pruned_anchors,
	}


func budget_info() -> Dictionary:
	return {
		"events_recent": events.size(),
		"events_recent_bytes": _events_bytes(events),
		"summaries": summaries.size(),
		"summaries_bytes": _summaries_bytes(),
		"historic": historic.size(),
		"historic_bytes": _events_bytes(historic),
		"anchors": anchors.size(),
		"anchors_bytes": _events_bytes(anchors),
		"limits": {
			"recent_days": max_recent_days,
			"recent_events": max_recent_events,
			"summary_days": max_summary_days,
			"summaries": max_summaries,
			"historic": max_historic,
		},
	}


func _events_bytes(items: Array) -> int:
	var total: int = 0
	for event in items:
		var ce: ChronicleEvent = event
		total += 96 + ce.text.to_utf8_buffer().size() \
			+ ce.category.to_utf8_buffer().size() \
			+ ce.template_key.to_utf8_buffer().size() \
			+ ce.dedup_key.to_utf8_buffer().size() \
			+ ce.actor_ids.size() * 4 + ce.causes.size() * 4 \
			+ ce.related_ids.size() * 4 + ce.source_ids.size() * 4
	return total


func _summaries_bytes() -> int:
	var total: int = 0
	for summary in summaries:
		var s: ChronicleSummary = summary
		total += 48 + s.event_ids.size() * 4
		for line in s.lines:
			total += 4 + line.to_utf8_buffer().size()
	return total


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, day_index)
	h = HashUtil.mix_i64(h, next_id)
	h = HashUtil.mix_i64(h, ingested_total)
	h = HashUtil.mix_i64(h, routine_events)
	h = HashUtil.mix_i64(h, deduped_total)
	h = HashUtil.mix_i64(h, aggregated_total)
	for event in events:
		h = HashUtil.mix(h, (event as ChronicleEvent).state_hash())
	for event in historic:
		h = HashUtil.mix(h, (event as ChronicleEvent).state_hash())
	for event in anchors:
		h = HashUtil.mix(h, (event as ChronicleEvent).state_hash())
	for summary in summaries:
		h = HashUtil.mix(h, (summary as ChronicleSummary).state_hash())
	var routine_keys: Array = routine.keys()
	routine_keys.sort()
	for key in routine_keys:
		var bucket: Dictionary = routine[key]
		h = HashUtil.mix_string(h, str(key))
		h = HashUtil.mix_i64(h, int(bucket["count"]))
		h = HashUtil.mix_i64(h, int(bucket["first"]))
		h = HashUtil.mix_i64(h, int(bucket["last"]))
		h = HashUtil.mix(h, int(bucket["type"]))
		h = HashUtil.mix(h, int(bucket["agent"]))
	var latest_keys: Array = latest.keys()
	latest_keys.sort()
	for key in latest_keys:
		h = HashUtil.mix_string(h, str(key))
		h = HashUtil.mix_i64(h, int(latest[key]))
	return h


func clear_all(day: int = -1) -> void:
	events.clear()
	summaries.clear()
	historic.clear()
	anchors.clear()
	routine.clear()
	latest.clear()
	next_id = 1
	ingested_total = 0
	routine_events = 0
	deduped_total = 0
	aggregated_total = 0
	pruned_recent = 0
	pruned_historic = 0
	pruned_anchors = 0
	if day >= 0:
		day_index = day


func write_to(w: ByteWriter) -> void:
	w.i32(CHRONICLE_SCHEMA)
	w.i64(day_index)
	w.i64(next_id)
	w.i64(ingested_total)
	w.i64(routine_events)
	w.i64(deduped_total)
	w.i64(aggregated_total)
	w.u32(events.size())
	for event in events:
		(event as ChronicleEvent).write_to(w)
	w.u32(historic.size())
	for event in historic:
		(event as ChronicleEvent).write_to(w)
	w.u32(anchors.size())
	for event in anchors:
		(event as ChronicleEvent).write_to(w)
	w.u32(summaries.size())
	for summary in summaries:
		(summary as ChronicleSummary).write_to(w)
	var routine_keys: Array = routine.keys()
	routine_keys.sort()
	w.u32(routine_keys.size())
	for key in routine_keys:
		var bucket: Dictionary = routine[key]
		w.string_value(str(key))
		w.i32(int(bucket["count"]))
		w.i64(int(bucket["first"]))
		w.i64(int(bucket["last"]))
		w.i32(int(bucket["type"]))
		w.i32(int(bucket["agent"]))
		w.string_value(str(bucket["category"]))
	var latest_keys: Array = latest.keys()
	latest_keys.sort()
	w.u32(latest_keys.size())
	for key in latest_keys:
		w.string_value(str(key))
		w.i64(int(latest[key]))


static func read_from(r: ByteReader, config: SimConfig) -> ChronicleStore:
	var store: ChronicleStore = ChronicleStore.new(config)
	var schema: int = r.i32()
	if schema != CHRONICLE_SCHEMA:
		r.ok = false
		r.error = "unsupported_chronicle_schema"
		return store
	store.day_index = r.i64()
	store.next_id = r.i64()
	store.ingested_total = r.i64()
	store.routine_events = r.i64()
	store.deduped_total = r.i64()
	store.aggregated_total = r.i64()
	var event_count: int = r.u32()
	if event_count < 0 or event_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_events"
		return store
	for i in event_count:
		store.events.append(ChronicleEvent.read_from(r))
	var historic_count: int = r.u32()
	if historic_count < 0 or historic_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_historic"
		return store
	for i in historic_count:
		store.historic.append(ChronicleEvent.read_from(r))
	var anchor_count: int = r.u32()
	if anchor_count < 0 or anchor_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_anchors"
		return store
	for i in anchor_count:
		store.anchors.append(ChronicleEvent.read_from(r))
	var summary_count: int = r.u32()
	if summary_count < 0 or summary_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_summaries"
		return store
	for i in summary_count:
		store.summaries.append(ChronicleSummary.read_from(r))
	var routine_count: int = r.u32()
	if routine_count < 0 or routine_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_routine"
		return store
	for i in routine_count:
		var key: String = r.string_value()
		store.routine[key] = {
			"count": r.i32(),
			"first": r.i64(),
			"last": r.i64(),
			"type": r.i32(),
			"agent": r.i32(),
			"category": r.string_value(),
		}
	var latest_count: int = r.u32()
	if latest_count < 0 or latest_count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_latest"
		return store
	for i in latest_count:
		var latest_key: String = r.string_value()
		store.latest[latest_key] = r.i64()
	return store
