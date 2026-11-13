class_name HashUtil
extends RefCounted

## FNV-1a-32 für deterministische Zustands-/Event-Hashes.
## Keine Engine-Hashes, keine Dictionary-Reihenfolge.

const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619
const MASK32: int = 0xFFFFFFFF


static func mix(h: int, v: int) -> int:
	return ((h ^ (v & MASK32)) * FNV_PRIME) & MASK32


static func mix_i64(h: int, v: int) -> int:
	h = mix(h, v & MASK32)
	h = mix(h, (v >> 32) & MASK32)
	return h


static func mix_f64(h: int, f: float) -> int:
	var bits: int = PackedFloat64Array([f]).to_byte_array().decode_s64(0)
	return mix_i64(h, bits)


static func mix_string(h: int, s: String) -> int:
	var bytes: PackedByteArray = s.to_utf8_buffer()
	h = mix(h, bytes.size())
	for b in bytes:
		h = ((h ^ b) * FNV_PRIME) & MASK32
	return h


static func hex(h: int) -> String:
	return "0x%08X" % (h & MASK32)
