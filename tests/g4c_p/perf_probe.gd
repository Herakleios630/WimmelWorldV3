extends SceneTree

## Headless-Performance und Determinismus des G4c-P-Profils.
## Kein Gate: misst Setup, 120 Sim-Tage und einen zweiten 120-Tage-Lauf.
## Aufruf:
##   godot --headless --path V3 --script res://tests/g4c_p/perf_probe.gd

const DAY: int = SimConfig.TICKS_PER_DAY
const START: int = 6 * 3600
const SEED: int = 1337
const OUT: String = "res://bench/results/g4c_p_perf.json"


func _init() -> void:
	var setup_start: int = Time.get_ticks_usec()
	var config: SimConfig = SimConfig.g4c_pre(SEED)
	var sim: Simulation = Simulation.create(config)
	var setup_ms: float = float(Time.get_ticks_usec() - setup_start) / 1000.0
	var day_ms: Array = []
	var events: int = 0
	for d in range(1, 121):
		var t0: int = Time.get_ticks_usec()
		events += sim.advance_to(d * DAY + START)
		day_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	var sorted: Array = day_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for ms in day_ms:
		total += float(ms)
	var p50: float = float(sorted[int(sorted.size() * 0.50)])
	var p95: float = float(sorted[int(sorted.size() * 0.95)])
	var p99: float = float(sorted[int(sorted.size() * 0.99)])
	var max_ms: float = float(sorted[sorted.size() - 1])
	var hash_a: int = sim.state_hash()
	var alive_a: int = sim.count_alive()
	var grain_a: int = sim.grain
	var harvests_a: int = sim.harvests_completed
	var cycles_a: int = sim.field_cycles_completed
	var births_a: int = sim.births
	var deaths_a: int = sim.deaths
	var overflow_a: int = sim.grain_overflow
	var seasons_a: Array = []
	for v in sim.harvest_season_counts:
		seasons_a.append(int(v))
	var nav: Dictionary = sim.navigation_stats()

	var sim_b: Simulation = Simulation.create(SimConfig.g4c_pre(SEED))
	sim_b.advance_to(120 * DAY + START)
	var hash_b: int = sim_b.state_hash()

	var result: Dictionary = {
		"profile": "g4c_pre",
		"seed": SEED,
		"world_tiles": config.world_size,
		"target_agents": config.target_agents,
		"target_households": config.target_households,
		"year_days": config.year_days,
		"season_days": config.season_days,
		"seasonal_fields": config.seasonal_fields,
		"start_grain": config.start_grain,
		"granary_capacity": config.granary_capacity,
		"field_harvest_yield": config.field_harvest_yield,
		"field_seed_cost": config.field_seed_cost,
		"setup_ms": setup_ms,
		"days": 120,
		"events": events,
		"day_ms_total": total,
		"day_ms_avg": total / 120.0,
		"day_ms_p50": p50,
		"day_ms_p95": p95,
		"day_ms_p99": p99,
		"day_ms_max": max_ms,
		"alive_end": alive_a,
		"grain_end": grain_a,
		"harvests": harvests_a,
		"field_cycles": cycles_a,
		"births": births_a,
		"deaths": deaths_a,
		"grain_overflow": overflow_a,
		"harvest_seasons": seasons_a,
		"state_hash_run1": str(hash_a),
		"state_hash_run2": str(hash_b),
		"deterministic": hash_a == hash_b,
		"navigation": nav,
	}
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://bench/results"))
	var file: FileAccess = FileAccess.open(
		ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "  "))
		file.close()
	print("G4C_P_PERF " + JSON.stringify(result))
	print("G4C_P_PERF_JSON " + ProjectSettings.globalize_path(OUT))
	quit(0 if hash_a == hash_b else 1)
