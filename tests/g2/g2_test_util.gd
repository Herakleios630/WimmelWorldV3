class_name G2TestUtil
extends RefCounted


static func new_sim(seed_value: int = 1337) -> Simulation:
	return Simulation.create(SimConfig.g2(seed_value))


static func advance_chunked(sim: Simulation, target: int, chunk: int) -> void:
	var step: int = maxi(1, chunk)
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + step))


static func temp_path(name: String) -> String:
	return "user://g2_test_%s.bin" % name


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
