extends Node

## Paritäts-Referenz für den C#-Native-Vergleich.
## Schreibt bench/results/parity_ref.json; NativeSpike schreibt dieselben
## Hashes nach native_csharp.json. Gleiche Seeds, gleiche Feldreihenfolge.

const SEED: int = 1337


func _ready() -> void:
	var out: Dictionary = {
		"meta": {
			"godot": Engine.get_version_info()["string"],
			"seed": SEED,
			"utc": Time.get_datetime_string_from_system(true),
		},
		"scheduler_workload_hash": {},
		"soa_state_hash_20_ticks": {},
		"needs_events_per_day": SpikeNeeds.expected_events_per_day(),
	}
	var batch: SpikeBatch = SpikeBatch.new()
	for n in [10000, 100000]:
		for burst in [0, 50, 100]:
			var events: PackedInt32Array = batch.make_scheduler_events(
					n, SEED + n + burst * 97, burst)
			var h: int = 2166136261
			for i in n:
				h = SpikeRepeat.mix(h, events[i * 3])
				h = SpikeRepeat.mix(h, events[i * 3 + 1])
				h = SpikeRepeat.mix(h, events[i * 3 + 2])
			out["scheduler_workload_hash"]["%d_%d" % [n, burst]] = SpikeRepeat.hex(h)
	var sample_after: Array = []
	for n in [10000, 100000]:
		var store: SpikeAgentStore = SpikeAgentStore.new()
		store.configure(n, SEED + n)
		for t in 20:
			store.tick(t * 30, 30.0)
		out["soa_state_hash_20_ticks"][str(n)] = SpikeRepeat.hex(store.state_hash())
		if n == 10000:
			for i in 3:
				sample_after.append({
					"hunger": "%.9f" % store.hunger[i],
					"energy": "%.9f" % store.energy[i],
					"next_event": store.next_event[i],
				})
	var dir: String = ProjectSettings.globalize_path("res://bench/results")
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join("parity_ref.json"), FileAccess.WRITE)
	if f == null:
		push_error("cannot write parity_ref.json")
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(out, "  ", false, true))
	f.close()
	print("PARITY_REF_OK %s" % JSON.stringify(out["scheduler_workload_hash"]))
	print("PARITY_REF_SOA %s" % JSON.stringify(out["soa_state_hash_20_ticks"]))
	get_tree().quit(0)


