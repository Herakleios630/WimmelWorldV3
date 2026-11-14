class_name G4BTestUtil
extends RefCounted

## G4b-Testhelfer: gleicher 10k-Kern wie G4a, aber mit aktivierter
## Wirtschaft/Politik und Save-Schema 8.

const SEED: int = 1337
const RESULT_DIR: String = "res://bench/results"

static var _year_sim: Simulation = null
static var _year_hashes: Array = []
static var _snapshot_path: String = ""
static var _snapshot_time: int = 0
static var _snapshot_info: Dictionary = {}
static var _snapshot_expected: Dictionary = {}


static func new_sim(seed_value: int = SEED) -> Simulation:
	return Simulation.create(SimConfig.civic(seed_value))


static func advance_chunked(sim: Simulation, target: int, chunk: int) -> int:
	var events: int = 0
	var step: int = maxi(1, chunk)
	while sim.clock.now < target:
		events += sim.advance_to(mini(target, sim.clock.now + step))
	return events


static func temp_path(name: String) -> String:
	return "user://g4_b_test_%s.bin" % name


static func remove_temp(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func abs_time(day: int, hour: int, minute: int = 0, second: int = 0) -> int:
	return day * SimConfig.TICKS_PER_DAY + hour * 3600 + minute * 60 + second


static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var idx: int = int(round(float(sorted.size() - 1) * p))
	return sorted[idx]


## 120-Tage-Lauf mit Save-Snapshot an Tag 61, 07:10. Der Snapshot liegt
## mitten in Markt/Karawane/Politik. Die Fortsetzung wird drei Tage später
## mit dem erwarteten Hash festgehalten.
static func run_year_snapshot(seed_value: int, chunk: int,
		run_id: int) -> Simulation:
	var sim: Simulation = new_sim(seed_value)
	var snapshot_at: int = 60 * SimConfig.TICKS_PER_DAY + 7 * 3600 + 10 * 60
	var checkpoint: int = snapshot_at + 3 * SimConfig.TICKS_PER_DAY
	var target: int = sim.clock.now + 120 * SimConfig.TICKS_PER_DAY
	var path: String = temp_path("year_run%d" % run_id)
	advance_chunked(sim, snapshot_at, chunk)
	var save_info: Dictionary = sim.save_to(path)
	if run_id == 1:
		_snapshot_path = path
		_snapshot_time = snapshot_at
		_snapshot_info = save_info
		print("G4B_SNAPSHOT schema=%d bytes=%d save_ms=%.1f" % [
			int(save_info.get("schema", 0)), int(save_info.get("bytes", 0)),
			float(save_info.get("save_ms", 0.0))])
	advance_chunked(sim, checkpoint, chunk)
	if run_id == 1:
		_snapshot_expected = {
			"time": checkpoint,
			"state": sim.state_hash(),
			"event": sim.event_hash(),
			"chronicle": sim.curated_chronicle_hash(),
		}
	advance_chunked(sim, target, chunk)
	if run_id == 1:
		_year_sim = sim
	_year_hashes.append({
		"run": run_id,
		"chunk": chunk,
		"state": sim.state_hash(),
		"event": sim.event_hash(),
		"chronicle": sim.curated_chronicle_hash(),
		"alive": sim.count_alive(),
		"caravans": sim.economy.caravans.completed_count,
		"treaties": sim.politics.treaty_count,
		"crises": _crisis_total(sim),
	})
	return sim


static func _crisis_total(sim: Simulation) -> int:
	var total: int = 0
	for value in sim.economy.crisis_counts:
		total += value
	return total


static func shared_year(seed_value: int = SEED) -> Simulation:
	if _year_sim != null:
		return _year_sim
	return run_year_snapshot(seed_value, 3600, 1)


static func year_hashes() -> Array:
	return _year_hashes.duplicate()


static func snapshot_path() -> String:
	return _snapshot_path


static func snapshot_time() -> int:
	return _snapshot_time


static func snapshot_info() -> Dictionary:
	return _snapshot_info.duplicate()


static func snapshot_expected() -> Dictionary:
	return _snapshot_expected.duplicate()


static func write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


static func has_chronicle_type(sim: Simulation, type: int) -> bool:
	for event_v in sim.chronicle.all_events():
		if (event_v as ChronicleEvent).type == type:
			return true
	# Der kuratierte Ringpuffer kürzt notable Events nach 7 Tagen. Für
	# Vertrags-/Geschenk-Nachweise zählt zusätzlich das Roh-Chroniklog.
	for event_v in sim.logs.chronicle_events:
		if (event_v as SimEvent).type == type:
			return true
	return false


static func chronicle_type_count(sim: Simulation, type: int) -> int:
	var count: int = 0
	for event_v in sim.chronicle.all_events():
		if (event_v as ChronicleEvent).type == type:
			count += 1
	return count


## Gibt statische Testreferenzen frei, damit der Prozess ohne ObjectDB-
## Leakwarnung beendet werden kann.
static func cleanup() -> void:
	_year_sim = null
	_year_hashes.clear()
	_snapshot_info.clear()
	_snapshot_expected.clear()
	_snapshot_path = ""
	_snapshot_time = 0
