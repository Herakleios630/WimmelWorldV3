class_name ByteWriter
extends RefCounted

## Kleiner Little-Endian-Binärschreiber für das versionierte G1a-Save.

var buf: PackedByteArray = PackedByteArray()


func u8(value: int) -> void:
	buf.append(value & 0xFF)


func i32(value: int) -> void:
	var pos: int = buf.size()
	buf.resize(pos + 4)
	buf.encode_s32(pos, value)


func u32(value: int) -> void:
	var pos: int = buf.size()
	buf.resize(pos + 4)
	buf.encode_u32(pos, value)


func i64(value: int) -> void:
	var pos: int = buf.size()
	buf.resize(pos + 8)
	buf.encode_s64(pos, value)


func u64(value: int) -> void:
	var pos: int = buf.size()
	buf.resize(pos + 8)
	buf.encode_u64(pos, value)


func f64(value: float) -> void:
	var pos: int = buf.size()
	buf.resize(pos + 8)
	buf.encode_double(pos, value)


func string_value(value: String) -> void:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	u32(bytes.size())
	buf.append_array(bytes)


func raw(bytes: PackedByteArray) -> void:
	buf.append_array(bytes)


func size() -> int:
	return buf.size()
