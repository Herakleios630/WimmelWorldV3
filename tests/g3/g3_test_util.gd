class_name G3TestUtil
extends RefCounted

const SEED: int = 1337
const RESULT_DIR: String = "res://bench/results"


static func new_sim(detail: int = 1000, speed: int = 150, seed_value: int = SEED) -> BSim:
	return BSim.create(BConfig.make(detail, speed, seed_value))


static func advance_chunked(sim: BSim, target: int, chunk: int) -> int:
	var events: int = 0
	var step: int = maxi(1, chunk)
	while sim.clock.now < target:
		events += sim.advance_to(mini(target, sim.clock.now + step))
	return events


static func advance_frames(sim: BSim, days: float, measure: bool) -> Dictionary:
	var start: int = sim.clock.now
	var target: int = start + int(round(days * float(BConfig.TICKS_PER_DAY)))
	var frame_seconds: int = sim.config.sim_seconds_per_frame()
	var frames: int = 0
	var events: int = 0
	while sim.clock.now < target:
		var t0: int = Time.get_ticks_usec()
		var n: int = sim.advance_to(mini(target, sim.clock.now + frame_seconds))
		if measure:
			sim.metrics.record_frame(Time.get_ticks_usec() - t0, n, frame_seconds)
		events += n
		frames += 1
	return {"frames": frames, "events": events,
		"sim_days": float(target - start) / float(BConfig.TICKS_PER_DAY)}


static func temp_path(name: String) -> String:
	return "user://g3_b_test_%s.bin" % name


static func remove_temp(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func abs_time(day: int, hour: int, minute: int = 0, second: int = 0) -> int:
	return day * BConfig.TICKS_PER_DAY + hour * 3600 + minute * 60 + second


static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var idx: int = int(round(float(sorted.size() - 1) * p))
	return sorted[idx]


static func write_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULT_DIR))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()


static func tier_array(sim: BSim) -> PackedByteArray:
	return sim.records.tier.duplicate()


static func detail_row_set(sim: BSim) -> PackedByteArray:
	var mark: PackedByteArray = PackedByteArray()
	mark.resize(sim.records.count)
	mark.fill(0)
	for row in sim.tier_selector.detail_rows:
		if row >= 0 and row < mark.size():
			mark[row] = 1
	return mark


static func sim_summary(sim: BSim) -> Dictionary:
	return {
		"now": sim.clock.now,
		"alive": sim.count_alive(),
		"detail": sim.detail_count(),
		"state": HashUtil.hex(sim.state_hash()),
		"event": HashUtil.hex(sim.event_hash()),
		"tier": HashUtil.hex(sim.tier_hash()),
		"keys": sim.key_stats(),
		"tier_stats": sim.tier_stats(),
		"detail_stats": sim.detail_stats(),
		"background_stats": sim.background_stats(),
	}
