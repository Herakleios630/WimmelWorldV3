class_name ByteReader
extends RefCounted

## Gegenstück zu ByteWriter. ok=false bei jeder Grenzverletzung.

var buf: PackedByteArray
var pos: int = 0
var ok: bool = true
var error: String = ""


func _init(p_buf: PackedByteArray) -> void:
	buf = p_buf


func _need(n: int) -> bool:
	if not ok:
		return false
	if pos + n > buf.size():
		ok = false
		error = "unexpected_eof"
		return false
	return true


func u8() -> int:
	if not _need(1):
		return 0
	var v: int = buf.decode_u8(pos)
	pos += 1
	return v


func i32() -> int:
	if not _need(4):
		return 0
	var v: int = buf.decode_s32(pos)
	pos += 4
	return v


func u32() -> int:
	if not _need(4):
		return 0
	var v: int = buf.decode_u32(pos)
	pos += 4
	return v


func i64() -> int:
	if not _need(8):
		return 0
	var v: int = buf.decode_s64(pos)
	pos += 8
	return v


func u64() -> int:
	if not _need(8):
		return 0
	var v: int = buf.decode_u64(pos)
	pos += 8
	return v


func f64() -> float:
	if not _need(8):
		return 0.0
	var v: float = buf.decode_double(pos)
	pos += 8
	return v


func string_value() -> String:
	var n: int = u32()
	if not ok or n < 0 or n > 16 * 1024 * 1024:
		ok = false
		error = "bad_string_length"
		return ""
	if not _need(n):
		return ""
	var s: String = buf.slice(pos, pos + n).get_string_from_utf8()
	pos += n
	return s


func remaining() -> int:
	return buf.size() - pos
