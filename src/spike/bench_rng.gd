class_name SpikeRng
extends RefCounted

## Wegwerf-PRNG für den G0.5-Spike.
##
## xorshift64* — bitgleich in GDScript und C# (NativeSpike) implementiert, damit
## GDScript- und C#-Last dieselbe Eventfolge erzeugen. Keine Simulation-Schnitt-
## stelle; nur Benchmark-Input.

const MUL: int = 0x2545F4914F6CDD1D

var state: int = 0

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


## Gleichverteilt in [0, bound). bound muss > 0 sein.
func next_range(bound: int) -> int:
	if bound <= 1:
		return 0
	return (next_u64() & 0x7FFFFFFFFFFFFFFF) % bound


func next_unit() -> float:
	return float(next_u64() & 0x7FFFFFFFFFFFFFFF) / 9223372036854775808.0
