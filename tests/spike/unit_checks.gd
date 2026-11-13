extends Node

## Minimale G0.5-Unit-/Smoke-Checks (kein Testframework, headless).
## godot --headless --path V3 res://tests/spike/unit_checks.tscn
## Exitcode 0 + "SPIKE_UNIT_OK", sonst 1.

var failures: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_check_scheduler_order()
	_check_scheduler_burst()
	_check_needs()
	_check_agent_store()
	_check_path()
	_check_save()
	_check_repeat()
	if failures.is_empty():
		print("SPIKE_UNIT_OK")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("SPIKE_UNIT_FAILED count=%d" % failures.size())
		get_tree().quit(1)


func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures.append(message)


func _check_scheduler_order() -> void:
	var sched: SpikeScheduler = SpikeScheduler.new()
	var inputs: Array = [
		[10, SpikeScheduler.KIND_NEED, 1],
		[5, SpikeScheduler.KIND_WORK, 2],
		[10, SpikeScheduler.KIND_ARRIVE, 3],
		[5, SpikeScheduler.KIND_SOCIAL, 4],
		[1, SpikeScheduler.KIND_LIFECYCLE, 5],
	]
	for e in inputs:
		sched.push(e[0], e[1], e[2])
	var seen: Array = []
	while sched.pop():
		seen.append([sched.last_time, sched.last_kind])
	_expect(seen.size() == 5, "scheduler pop count")
	_expect(seen[0] == [1, SpikeScheduler.KIND_LIFECYCLE], "scheduler time order 1")
	_expect(seen[1] == [5, SpikeScheduler.KIND_WORK], "scheduler seq order @5 a")
	_expect(seen[2] == [5, SpikeScheduler.KIND_SOCIAL], "scheduler seq order @5 b")
	_expect(seen[3] == [10, SpikeScheduler.KIND_NEED], "scheduler seq order @10 a")
	_expect(seen[4] == [10, SpikeScheduler.KIND_ARRIVE], "scheduler seq order @10 b")
	_expect(not sched.pop(), "scheduler empty pop")


func _check_scheduler_burst() -> void:
	var batch: SpikeBatch = SpikeBatch.new()
	var events: PackedInt32Array = batch.make_scheduler_events(500, 77, 100, 60)
	var sched: SpikeScheduler = SpikeScheduler.new()
	for i in 500:
		sched.push(events[i * 3 + 1], events[i * 3], events[i * 3 + 2])
	var expected_seq: int = 0
	var ok: bool = true
	while sched.pop():
		if sched.last_seq != expected_seq:
			ok = false
		expected_seq += 1
	_expect(ok and expected_seq == 500, "scheduler burst 100% preserves push order")


func _check_needs() -> void:
	var per_day: float = SpikeNeeds.expected_events_per_day()
	_expect(per_day > 8.0 and per_day < 11.0,
		"needs events/day out of 8..11: %.3f" % per_day)
	var a: float = SpikeNeeds.next_wake_seconds(0.0, 100.0, 0.0, 0.0, 0.0)
	var b: float = SpikeNeeds.next_wake_seconds(60.0, 100.0, 0.0, 0.0, 0.0)
	_expect(b < a, "needs wake shrink with higher hunger")


func _check_agent_store() -> void:
	var s1: SpikeAgentStore = SpikeAgentStore.new()
	var s2: SpikeAgentStore = SpikeAgentStore.new()
	s1.configure(1000, 424242)
	s2.configure(1000, 424242)
	_expect(s1.state_hash() == s2.state_hash(), "agent store initial hash equal")
	var scheduled: int = 0
	for t in 20:
		scheduled += s1.tick(t * 30, 30.0)
		s2.tick(t * 30, 30.0)
	_expect(s1.state_hash() == s2.state_hash(), "agent store tick hash equal")
	_expect(scheduled == 1000 * 20, "agent store schedules one wake per agent/tick")
	for i in 1000:
		_expect(s1.next_event[i] > 19 * 30, "next_event in future for agent %d" % i)
		if failures.size() > 20:
			break


func _check_path() -> void:
	var grid: SpikePathGrid = SpikePathGrid.new()
	grid.build(128, 99, 10)
	var start: int = -1
	var goal: int = -1
	var path: PackedInt32Array = PackedInt32Array()
	var offsets: Array = [1, grid.size, 2, grid.size * 2, 3]
	for i in grid.total:
		if not grid.is_walkable(i):
			continue
		var found: bool = false
		for d in offsets:
			var j: int = i + d
			if j >= grid.total or not grid.is_walkable(j):
				continue
			var p: PackedInt32Array = grid.find_path(i, j)
			if p.size() > 0:
				start = i
				goal = j
				path = p
				found = true
				break
		if found:
			break
	_expect(path.size() > 0, "path found on 128 grid")
	if path.size() > 0:
		_expect(path[0] == start, "path starts at start")
		_expect(path[path.size() - 1] == goal, "path ends at goal")
		var contiguous: bool = true
		for i in range(1, path.size()):
			var d: int = absi(path[i] - path[i - 1])
			if d != 1 and d != grid.size:
				contiguous = false
		_expect(contiguous, "path is contiguous 4-neighbour")
		var hits_before: int = grid.cache_hits
		grid.find_path(start, goal)
		_expect(grid.cache_hits == hits_before + 1, "path cache hit on repeat")
	grid.cache_enabled = false
	var off_hits: int = grid.cache_hits
	grid.find_path(start, goal)
	_expect(grid.cache_hits == off_hits, "path cache disabled does not hit")


func _check_save() -> void:
	var store: SpikeAgentStore = SpikeAgentStore.new()
	store.configure(1000, 31337)
	for t in 5:
		store.tick(t * 30, 30.0)
	var saver: SpikeSave = SpikeSave.new()
	var path: String = ProjectSettings.globalize_path("res://bench/results/unit_save.bin")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var s: Dictionary = saver.save_measured(store, 1000, path)
	_expect(s["ok"], "save ok")
	var l: Dictionary = saver.load_measured(store.state_hash(), path)
	_expect(l["verified"], "save/load hash roundtrip")
	_expect(int(l["count"]) == 1000, "save count")
	DirAccess.remove_absolute(path)


func _check_repeat() -> void:
	var a: Dictionary = SpikeRepeat.run(1234)
	var b: Dictionary = SpikeRepeat.run(1234)
	var c: Dictionary = SpikeRepeat.run(1234)
	_expect(a["combined_hex"] == b["combined_hex"] and b["combined_hex"] == c["combined_hex"],
		"repeat hash identical over 3 runs")
	_expect(a["order_ok"], "repeat scheduler order ok")
	var d: Dictionary = SpikeRepeat.run(1235)
	_expect(d["combined_hex"] != a["combined_hex"], "repeat hash differs for other seed")
