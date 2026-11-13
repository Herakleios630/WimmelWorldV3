class_name SpikeRepeat
extends RefCounted

## Determinismus-Probe für G0.5.
##
## Drei identische Läufe (gleicher Seed) müssen denselben Hash über
## Scheduler-Eventfolge und Agentzustand liefern. Kein Save, kein Replay.

const FNV_OFFSET: int = 2166136261

static func mix(h: int, v: int) -> int:
	return ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


static func hex(h: int) -> String:
	return "0x%08X" % (h & 0xFFFFFFFF)


## Ein vollständiger, kleiner Lauf. Gleicher Seed => gleicher Hash.
static func run(seed_value: int) -> Dictionary:
	var batch: SpikeBatch = SpikeBatch.new()
	var events: PackedInt32Array = batch.make_scheduler_events(2000, seed_value, 25, 600)
	var sched: SpikeScheduler = SpikeScheduler.new()
	var n_events: int = events.size() / 3
	for i in n_events:
		sched.push(events[i * 3 + 1], events[i * 3], events[i * 3 + 2])

	var event_hash: int = FNV_OFFSET
	var last_time: int = -1
	var last_seq: int = -1
	var order_ok: bool = true
	var popped: int = 0
	while sched.pop():
		if sched.last_time < last_time:
			order_ok = false
		elif sched.last_time == last_time and sched.last_seq < last_seq:
			order_ok = false
		last_time = sched.last_time
		last_seq = sched.last_seq
		event_hash = mix(event_hash, sched.last_time)
		event_hash = mix(event_hash, sched.last_seq)
		event_hash = mix(event_hash, sched.last_kind)
		event_hash = mix(event_hash, sched.last_payload)
		popped += 1

	var store: SpikeAgentStore = SpikeAgentStore.new()
	store.configure(1000, seed_value ^ 0x5F3759DF)
	var rng: SpikeRng = SpikeRng.new(seed_value * 31 + 7)
	var state_hash: int = FNV_OFFSET
	var scheduled_total: int = 0
	for t in 120:
		var now: int = t * 30
		scheduled_total += store.tick(now, 30.0)
		for k in 20:
			var idx: int = rng.next_range(1000)
			var need: int = store.apply_need_wake(idx, now)
			state_hash = mix(state_hash, need)
			state_hash = mix(state_hash, idx)
		state_hash = mix(state_hash, store.next_event[0])

	var final_state: int = store.state_hash()
	var combined: int = mix(mix(event_hash, state_hash), final_state)
	return {
		"seed": seed_value,
		"events_popped": popped,
		"events_expected": n_events,
		"event_hash": event_hash,
		"event_hex": hex(event_hash),
		"state_hash": final_state,
		"state_hex": hex(final_state),
		"combined_hash": combined,
		"combined_hex": hex(combined),
		"order_ok": order_ok and popped == n_events,
		"scheduled_total": scheduled_total,
	}
