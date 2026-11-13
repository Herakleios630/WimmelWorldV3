class_name RngStream
extends RefCounted

## xorshift64* (wie G0.5). Ein Zustand pro Stream.
## Streams werden getrennt gespeichert; Ziehen aus einem Stream ändert keinen
## anderen Stream.

const MUL: int = 0x2545F4914F6CDD1D

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = seed_value
	if state == 0:
		state = MUL


func next_u64() -> int:
	var x: int = state
	x ^= x >> 12
	x ^= x << 25
	x ^= x >> 27
	state = x
	return x * MUL


func next_range(bound: int) -> int:
	if bound <= 1:
		return 0
	return (next_u64() & 0x7FFFFFFFFFFFFFFF) % bound


func next_unit() -> float:
	return float(next_u64() & 0x7FFFFFFFFFFFFFFF) / 9223372036854775808.0
