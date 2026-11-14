class_name ChronicleEvent
extends RefCounted

## Kuratierter Chronik-Eintrag. Kein Rohlog: Importance, Kategorie,
## Kausalitätslinks und Aggregationszähler gehören zum Record.
##
## Die Record-Form ist bewusst unabhängig vom Debug-Log. Sie wird aus
## SimEvents abgeleitet und ist niemals Replay-Quelle.

var id: int = 0
var time: int = 0
var type: int = 0
var importance: int = 0
var category: String = ""
var actor_ids: PackedInt32Array = PackedInt32Array()
var household_id: int = 0
var location_id: int = 0
var causes: PackedInt32Array = PackedInt32Array()
var template_key: String = ""
var data: int = 0
var text: String = ""
var count: int = 1
var first_time: int = 0
var last_time: int = 0
var dedup_key: String = ""
var related_ids: PackedInt32Array = PackedInt32Array()
var source_ids: PackedInt32Array = PackedInt32Array()


func _init(p_id: int = 0, p_time: int = 0, p_type: int = 0,
		p_importance: int = 0, p_category: String = "",
		p_template: String = "", p_text: String = "") -> void:
	id = p_id
	time = p_time
	type = p_type
	importance = p_importance
	category = p_category
	template_key = p_template
	text = p_text
	first_time = p_time
	last_time = p_time


func add_source(source_id: int, at_time: int) -> void:
	count += 1
	last_time = at_time
	source_ids.append(source_id)


func merge_related(ids: PackedInt32Array) -> void:
	for value in ids:
		if value > 0 and not related_ids.has(value):
			related_ids.append(value)


func display_text() -> String:
	if count > 1:
		return "%s (×%d)" % [text, count]
	return text


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, id)
	h = HashUtil.mix_i64(h, time)
	h = HashUtil.mix(h, type)
	h = HashUtil.mix(h, importance)
	h = HashUtil.mix_string(h, category)
	for value in actor_ids:
		h = HashUtil.mix(h, value)
	h = HashUtil.mix(h, household_id)
	h = HashUtil.mix(h, location_id)
	for value in causes:
		h = HashUtil.mix(h, value)
	h = HashUtil.mix_string(h, template_key)
	h = HashUtil.mix_i64(h, data)
	h = HashUtil.mix_string(h, text)
	h = HashUtil.mix(h, count)
	h = HashUtil.mix_i64(h, first_time)
	h = HashUtil.mix_i64(h, last_time)
	h = HashUtil.mix_string(h, dedup_key)
	for value in related_ids:
		h = HashUtil.mix(h, value)
	for value in source_ids:
		h = HashUtil.mix(h, value)
	return h


func write_to(w: ByteWriter) -> void:
	w.i64(id)
	w.i64(time)
	w.i32(type)
	w.i32(importance)
	w.string_value(category)
	ChronicleIO.write_i32_array(w, actor_ids)
	w.i32(household_id)
	w.i32(location_id)
	ChronicleIO.write_i32_array(w, causes)
	w.string_value(template_key)
	w.i64(data)
	w.string_value(text)
	w.i32(count)
	w.i64(first_time)
	w.i64(last_time)
	w.string_value(dedup_key)
	ChronicleIO.write_i32_array(w, related_ids)
	ChronicleIO.write_i32_array(w, source_ids)


static func read_from(r: ByteReader) -> ChronicleEvent:
	var event: ChronicleEvent = ChronicleEvent.new()
	event.id = r.i64()
	event.time = r.i64()
	event.type = r.i32()
	event.importance = r.i32()
	event.category = r.string_value()
	event.actor_ids = ChronicleIO.read_i32_array(r)
	event.household_id = r.i32()
	event.location_id = r.i32()
	event.causes = ChronicleIO.read_i32_array(r)
	event.template_key = r.string_value()
	event.data = r.i64()
	event.text = r.string_value()
	event.count = r.i32()
	event.first_time = r.i64()
	event.last_time = r.i64()
	event.dedup_key = r.string_value()
	event.related_ids = ChronicleIO.read_i32_array(r)
	event.source_ids = ChronicleIO.read_i32_array(r)
	return event
