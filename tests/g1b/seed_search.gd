extends Node

## Seed-Suche fuer den sichtbaren G1b-Jahreslauf. Kein Gate-Test.
## Sucht Seeds, bei denen im ersten Sim-Jahr mindestens eine Geburt und ein
## Tod auftreten und mindestens 50 % der Siedlung leben.
## godot --headless --path V3 res://tests/g1b/seed_search.tscn

const MAX_SEED: int = 300


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var candidates: Array = []
	var births_only: int = 0
	var deaths_only: int = 0
	var scanned: int = 0
	for seed_value in range(1, MAX_SEED + 1):
		scanned += 1
		var config: SimConfig = SimConfig.new()
		config.seed = seed_value
		var sim: Simulation = Simulation.create(config)
		var target: int = 30 * SimConfig.TICKS_PER_DAY + 6 * 3600
		while sim.clock.now < target:
			sim.advance_to(mini(target, sim.clock.now + 3600))
		var alive: int = sim.count_alive()
		if sim.births >= 1:
			births_only += 1
		if sim.deaths >= 1:
			deaths_only += 1
		if sim.births >= 1 and sim.deaths >= 1 and alive >= 5:
			var first_birth: int = _first_event_day(sim, SimEvent.T_BIRTH)
			var first_death: int = _first_event_day(sim, SimEvent.T_DEATH)
			candidates.append({
				"seed": seed_value, "births": sim.births, "deaths": sim.deaths,
				"alive": alive, "grain": sim.grain,
				"first_birth_day": first_birth, "first_death_day": first_death,
				"health_id8": sim.store.health[sim.store.row_for_id(8)]
					if sim.store.row_for_id(8) >= 0 else -1.0,
			})
			if candidates.size() <= 20:
				print("CANDIDATE " + JSON.stringify(candidates[candidates.size() - 1]))
	print("SEED_SEARCH max_seed=%d scanned=%d births_only=%d deaths_only=%d candidates=%d elapsed_ms=%d" % [
		MAX_SEED, scanned, births_only, deaths_only, candidates.size(),
		Time.get_ticks_msec() - t0])
	if candidates.size() > 0:
		var best: Dictionary = candidates[0]
		for candidate in candidates:
			var c: Dictionary = candidate
			if int(c["alive"]) > int(best["alive"]):
				best = c
		print("SEED_SEARCH_RECOMMENDED " + JSON.stringify(best))
	get_tree().quit(0)


func _first_event_day(sim: Simulation, type: int) -> int:
	for event in sim.logs.debug_events:
		var e: SimEvent = event
		if e.type == type:
			return e.time / SimConfig.TICKS_PER_DAY
	return -1
