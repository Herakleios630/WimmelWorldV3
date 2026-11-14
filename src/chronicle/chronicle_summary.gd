class_name ChronicleSummary
extends RefCounted

## Tagesdigest für die mittlere Retention-Ebene (1 Sim-Jahr).
## Summaries enthalten nur abgeleitete Zeilen und Event-IDs, nie Roh-Events.

var day: int = 0
var start_time: int = 0
var end_time: int = 0
var lines: PackedStringArray = PackedStringArray()
var event_ids: PackedInt32Array = PackedInt32Array()
var notable_count: int = 0
var major_count: int = 0
var historic_count: int = 0
var routine_count: int = 0


func _init(p_day: int = 0, p_start: int = 0, p_end: int = 0,
		p_lines: PackedStringArray = PackedStringArray()) -> void:
	day = p_day
	start_time = p_start
	end_time = p_end
	lines = p_lines


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, day)
	h = HashUtil.mix_i64(h, start_time)
	h = HashUtil.mix_i64(h, end_time)
	for line in lines:
		h = HashUtil.mix_string(h, line)
	for event_id in event_ids:
		h = HashUtil.mix(h, event_id)
	h = HashUtil.mix(h, notable_count)
	h = HashUtil.mix(h, major_count)
	h = HashUtil.mix(h, historic_count)
	h = HashUtil.mix(h, routine_count)
	return h


func write_to(w: ByteWriter) -> void:
	w.i64(day)
	w.i64(start_time)
	w.i64(end_time)
	ChronicleIO.write_string_array(w, lines)
	ChronicleIO.write_i32_array(w, event_ids)
	w.i32(notable_count)
	w.i32(major_count)
	w.i32(historic_count)
	w.i32(routine_count)


static func read_from(r: ByteReader) -> ChronicleSummary:
	var summary: ChronicleSummary = ChronicleSummary.new()
	summary.day = r.i64()
	summary.start_time = r.i64()
	summary.end_time = r.i64()
	summary.lines = ChronicleIO.read_string_array(r)
	summary.event_ids = ChronicleIO.read_i32_array(r)
	summary.notable_count = r.i32()
	summary.major_count = r.i32()
	summary.historic_count = r.i32()
	summary.routine_count = r.i32()
	return summary
