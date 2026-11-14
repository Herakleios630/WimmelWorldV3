class_name BHash
extends RefCounted

## Stateless deterministic hashing for the B tiering spike.
##
## B uses stable stateless hashes instead of consuming the shared RNG streams:
## the same (id, epoch, salt) always produces the same selection and key-event
## decision, independent of advance_to() chunk sizes. This is part of B's own
## model, not an A/Cursed-Beyond rule.

const MASK32: int = 0xFFFFFFFF


static func hash1(a: int) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, a)
	h = HashUtil.mix(h, h ^ (h >> 13))
	h = HashUtil.mix(h, h ^ (h >> 7))
	return h & MASK32


static func hash2(a: int, b: int) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, a)
	h = HashUtil.mix_i64(h, b)
	h = HashUtil.mix(h, h ^ (h >> 13))
	h = HashUtil.mix(h, h ^ (h >> 7))
	return h & MASK32


static func hash3(a: int, b: int, c: int) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, a)
	h = HashUtil.mix_i64(h, b)
	h = HashUtil.mix_i64(h, c)
	h = HashUtil.mix(h, h ^ (h >> 13))
	h = HashUtil.mix(h, h ^ (h >> 7))
	return h & MASK32


static func hash4(a: int, b: int, c: int, d: int) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, a)
	h = HashUtil.mix_i64(h, b)
	h = HashUtil.mix_i64(h, c)
	h = HashUtil.mix_i64(h, d)
	h = HashUtil.mix(h, h ^ (h >> 13))
	h = HashUtil.mix(h, h ^ (h >> 7))
	return h & MASK32


static func unit2(a: int, b: int) -> float:
	return float(hash2(a, b)) / 4294967296.0


static func unit3(a: int, b: int, c: int) -> float:
	return float(hash3(a, b, c)) / 4294967296.0


static func unit4(a: int, b: int, c: int, d: int) -> float:
	return float(hash4(a, b, c, d)) / 4294967296.0


static func f32_bits(value: float) -> int:
	return PackedFloat32Array([value]).to_byte_array().decode_s32(0)
