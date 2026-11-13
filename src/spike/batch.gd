class_name SpikeBatch
extends RefCounted

## Gemischte Event-Batches für G0.5 (kein Gameplay).
##
## Event-Layout als PackedInt32Array mit stride 4: kind, agent, time, value.
## Erzeugung und Verarbeitung sind deterministisch (xorshift64*, feste Reihenfolge).

const STRIDE: int = 4
const KIND_NEED: int = 0
const KIND_WORK: int = 1
const KIND_ARRIVE: int = 2
const KIND_SOCIAL: int = 3
const KIND_LIFECYCLE: int = 4


## Scheduler-Last: stride 3 (kind, time, payload).
func make_scheduler_events(n: int, seed_value: int, burst_percent: int,
		window_seconds: int = 3600) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n * 3)
	var rng: SpikeRng = SpikeRng.new(seed_value)
	for i in n:
		var kind: int = i % 5
		var t: int = 0 if rng.next_range(100) < burst_percent else rng.next_range(window_seconds)
		out[i * 3] = kind
		out[i * 3 + 1] = t
		out[i * 3 + 2] = rng.next_range(1000000)
	return out


func make_events(n: int, seed_value: int, agent_count: int, burst_percent: int = 0,
		window_seconds: int = 3600) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(n * STRIDE)
	var rng: SpikeRng = SpikeRng.new(seed_value)
	for i in n:
		var kind: int = i % 5
		var agent: int = rng.next_range(agent_count)
		var t: int = 0 if rng.next_range(100) < burst_percent else rng.next_range(window_seconds)
		out[i * STRIDE] = kind
		out[i * STRIDE + 1] = agent
		out[i * STRIDE + 2] = t
		out[i * STRIDE + 3] = rng.next_range(2)
	return out


## Verarbeitet einen Batch. Rückgabe ist eine Prüfsumme gegen Dead-Code-Abbau.
func process(events: PackedInt32Array, store: SpikeAgentStore, now: int) -> int:
	var n: int = events.size() / STRIDE
	var acc: int = 0
	for e in n:
		var off: int = e * STRIDE
		var kind: int = events[off]
		var idx: int = events[off + 1]
		var value: int = events[off + 3]
		if kind == KIND_NEED:
			acc += store.apply_need_wake(idx, now)
		elif kind == KIND_WORK:
			store.apply_work_start(idx, now)
			acc += 1
		elif kind == KIND_ARRIVE:
			store.apply_arrive(idx, now, (value & 1) == 1)
			acc += 2
		elif kind == KIND_SOCIAL:
			store.apply_social(idx, now)
			acc += 3
		else:
			store.apply_lifecycle(idx, now)
			acc += 4
	return acc & 0xFFFFFFFF
