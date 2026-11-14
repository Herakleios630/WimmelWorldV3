class_name ChronicleIO
extends RefCounted

## Kleine Serialisierungshelfer für Chronik-Records. Keine Simulationslogik.

const MAX_ITEMS: int = 2000000


static func write_i32_array(w: ByteWriter, values: PackedInt32Array) -> void:
	w.u32(values.size())
	for value in values:
		w.i32(value)


static func read_i32_array(r: ByteReader) -> PackedInt32Array:
	var count: int = r.u32()
	if count < 0 or count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_array_length"
		return PackedInt32Array()
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(count)
	for i in count:
		out[i] = r.i32()
	return out


static func write_string_array(w: ByteWriter, values: PackedStringArray) -> void:
	w.u32(values.size())
	for value in values:
		w.string_value(value)


static func read_string_array(r: ByteReader) -> PackedStringArray:
	var count: int = r.u32()
	if count < 0 or count > MAX_ITEMS:
		r.ok = false
		r.error = "bad_chronicle_array_length"
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for i in count:
		out.append(r.string_value())
	return out
