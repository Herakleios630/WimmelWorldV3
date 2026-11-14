class_name G3ATestUtil
extends RefCounted

## G3-A-Testhelfer (1000 Agenten, 120-Tage-Jahr). Bewusst getrennt von der
## B-Spike-Utility und den B-Tests.

const SEED: int = 1337
const RESULT_DIR: String = "res://bench/results"

static var _year_sim: Simulation = null
static var _year_days_done: int = 0
static var _year_hashes: Array = []
static var _snapshot_path: String = ""
static var _snapshot_time: int = 0
static var _snapshot_expected: Dictionary = {}


static func new_sim(seed_value: int = SEED) -> Simulation:
	return Simulation.create(SimConfig.g3(seed_value))


static func advance_chunked(sim: Simulation, target: int, chunk: int) -> int:
	var events: int = 0
	var step: int = maxi(1, chunk)
	while sim.clock.now < target:
		events += sim.advance_to(mini(target, sim.clock.now + step))
	return events


static func temp_path(name: String) -> String:
	return "user://g3_a_test_%s.bin" % name


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


static func working_age_count(sim: Simulation) -> int:
	var n: int = 0
	for row in sim.store.count:
		var age: int = sim.store.age_years[row]
		if age >= 18 and age <= 59:
			n += 1
	return n


## Ein 120-Tage-Lauf mit Save-Snapshot mitten in der Feldphase. Wird von
## T-G3-06, T-G3-03, T-G3-07 und T-G3-09 geteilt. Der Save resettet den
## abgeleiteten Pfad-Cache deterministisch; deshalb machen alle drei
## Determinismus-Läufe denselben Save.
static func run_year_snapshot(seed_value: int, chunk: int,
		run_id: int) -> Simulation:
	var sim: Simulation = new_sim(seed_value)
	# Tag 61 (1-basiert) = 60*TICKS; 09:10 liegt im Herbst-/Erntefenster,
	# bevor die volle Belegschaft alle 40 Felder abgeerntet hat.
	var snapshot_at: int = 60 * SimConfig.TICKS_PER_DAY + 9 * 3600 + 10 * 60
	var checkpoint: int = snapshot_at + 3 * SimConfig.TICKS_PER_DAY
	var target: int = sim.clock.now + 120 * SimConfig.TICKS_PER_DAY
	var path: String = temp_path("year_run%d" % run_id)
	advance_chunked(sim, snapshot_at, chunk)
	var save_info: Dictionary = sim.save_to(path)
	if run_id == 1:
		_snapshot_path = path
		_snapshot_time = snapshot_at
		print("G3A_SNAPSHOT schema=%d bytes=%d save_ms=%.1f" % [
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
		_year_days_done = 120
	_year_hashes.append({
		"run": run_id,
		"chunk": chunk,
		"state": sim.state_hash(),
		"event": sim.event_hash(),
		"chronicle": sim.curated_chronicle_hash(),
		"alive": sim.count_alive(),
	})
	return sim


static func shared_year(seed_value: int = SEED) -> Simulation:
	if _year_sim != null and _year_days_done == 120:
		return _year_sim
	# Fallback, falls T-G3-03 ohne T-G3-06 läuft.
	return run_year_snapshot(seed_value, 3600, 1)


static func year_hashes() -> Array:
	return _year_hashes.duplicate()


static func snapshot_path() -> String:
	return _snapshot_path


static func snapshot_time() -> int:
	return _snapshot_time


static func snapshot_expected() -> Dictionary:
	return _snapshot_expected.duplicate()


static func year_harvest_count(sim: Simulation) -> int:
	var total: int = 0
	for i in sim.harvest_season_counts.size():
		total += sim.harvest_season_counts[i]
	return total


static func write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true
