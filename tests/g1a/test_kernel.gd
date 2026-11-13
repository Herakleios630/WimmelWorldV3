extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_scheduler_order(ctx)
	_test_rng_streams(ctx)
	_test_log_separation(ctx)
	_test_snapshot_restore(ctx)


static func _test_scheduler_order(ctx: G1aTestContext) -> void:
	ctx.begin("T-KERN-01", "Scheduler-Ordnung (time, seq), 3 Läufe identisch")
	var hashes: PackedStringArray = PackedStringArray()
	for run_idx in 3:
		var rng: RngStream = RngStream.new(424242)
		var scheduler: EventScheduler = EventScheduler.new()
		for i in 300:
			var t: int = rng.next_range(120)
			var kind: int = rng.next_range(4)
			scheduler.push(t, kind, i)
		var last_time: int = -1
		var last_seq: int = -1
		var order_ok: bool = true
		var count: int = 0
		var h: int = HashUtil.FNV_OFFSET
		while scheduler.pop():
			if scheduler.last_time < last_time:
				order_ok = false
			if scheduler.last_time == last_time and scheduler.last_seq < last_seq:
				order_ok = false
			last_time = scheduler.last_time
			last_seq = scheduler.last_seq
			h = HashUtil.mix_i64(h, scheduler.last_time)
			h = HashUtil.mix_i64(h, scheduler.last_seq)
			h = HashUtil.mix(h, scheduler.last_kind)
			h = HashUtil.mix_i64(h, scheduler.last_payload)
			count += 1
		ctx.check(order_ok, "Ordnung (time, seq) verletzt Lauf %d" % run_idx)
		ctx.check_eq(count, 300, "Eventanzahl Lauf %d" % run_idx)
		hashes.append(HashUtil.hex(h))
	ctx.check(hashes[0] == hashes[1] and hashes[1] == hashes[2],
		"Scheduler-Ordnung über 3 Läufe nicht identisch: " + str(hashes))
	# Keine Dictionary-Iteration im Hot-Heap.
	ctx.check(not G1aTestUtil.code_uses_dictionary("res://src/kernel/event_scheduler.gd"),
		"event_scheduler.gd nutzt Dictionary im Code")


static func _test_rng_streams(ctx: G1aTestContext) -> void:
	ctx.begin("T-KERN-02", "RNG-Streams getrennt und reproduzierbar")
	var a: RngStreams = RngStreams.new(99)
	var b: RngStreams = RngStreams.new(99)
	var same: bool = true
	for i in 40:
		if a.world().next_u64() != b.world().next_u64():
			same = false
	ctx.check(same, "gleicher Seed erzeugt nicht dieselben world-Werte")
	var fresh: RngStreams = RngStreams.new(99)
	var agents_equal: bool = true
	for i in 20:
		if a.agents().next_u64() != fresh.agents().next_u64():
			agents_equal = false
	ctx.check(agents_equal, "world-Ziehen verändert agents-Stream")
	ctx.check_eq(RngStreams.NAMES.size(), 6, "Stream-Anzahl")
	# Save-Restore der Streams über T-KERN-04 abgedeckt; hier nur Trennung.
	var economy_before: int = a.get_stream("economy").state
	a.world().next_u64()
	ctx.check_eq(a.get_stream("economy").state, economy_before,
		"world-Ziehen verändert economy-Stream")


static func _test_log_separation(ctx: G1aTestContext) -> void:
	ctx.begin("T-KERN-03", "Debug-/Chronik-Log getrennt, keine Replay-Quelle")
	var a: Simulation = G1aTestUtil.new_sim()
	var b: Simulation = G1aTestUtil.new_sim()
	a.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	b.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	ctx.check(a.logs.debug_events.size() > a.logs.chronicle_events.size(),
		"Debug-Log enthält nicht mehr Events als die Chronik")
	var chronicle_ok: bool = true
	for event in a.logs.chronicle_events:
		if (event as SimEvent).importance < SimEvent.IMPORTANCE_NOTABLE:
			chronicle_ok = false
	ctx.check(chronicle_ok, "Chronik enthält Routine-Events")
	var state_before: int = a.state_hash()
	a.logs.clear_chronicle_only()
	ctx.check_eq(a.state_hash(), state_before, "Chronik-Löschen verändert Sim-Zustand")
	a.logs.debug_events.clear()
	b.advance_to(G1aTestUtil.abs_time(0, 12, 0))
	a.advance_to(G1aTestUtil.abs_time(0, 12, 0))
	ctx.check_eq(a.state_hash(), b.state_hash(),
		"Sim hängt vom Log-Inhalt ab (Replay aus Log)")
	var path: String = G1aTestUtil.temp_path("kernel_logs")
	var info: Dictionary = b.save_to(path)
	ctx.check(info.get("ok", false), "Save für Log-Trennung fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Load für Log-Trennung fehlgeschlagen")
	if loaded.get("ok", false):
		var c: Simulation = loaded["sim"]
		ctx.check_eq(c.logs.debug_events.size(), b.logs.debug_events.size(),
			"Debug-Log nicht separat gespeichert")
		ctx.check_eq(c.logs.chronicle_events.size(), b.logs.chronicle_events.size(),
			"Chronik nicht separat gespeichert")
		ctx.check_eq(c.event_hash(), b.event_hash(), "Debug-Event-Hash nach Load")
		ctx.check_eq(c.chronicle_hash(), b.chronicle_hash(), "Chronik-Hash nach Load")
	G1aTestUtil.remove_temp(path)


static func _test_snapshot_restore(ctx: G1aTestContext) -> void:
	ctx.begin("T-KERN-04", "Snapshot/Restore von Clock, Scheduler, RNG")
	var a: Simulation = G1aTestUtil.new_sim()
	a.advance_to(G1aTestUtil.abs_time(0, 12, 5))
	var path: String = G1aTestUtil.temp_path("kernel_snapshot")
	ctx.check(a.save_to(path).get("ok", false), "Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Load fehlgeschlagen")
	if loaded.get("ok", false):
		var b: Simulation = loaded["sim"]
		ctx.check_eq(b.clock.now, a.clock.now, "Clock nicht exakt")
		ctx.check_eq(b.scheduler.state_hash(), a.scheduler.state_hash(),
			"Scheduler nicht exakt")
		ctx.check_eq(b.rng.state_hash(), a.rng.state_hash(), "RNG nicht exakt")
		ctx.check_eq(b.state_hash(), a.state_hash(), "Snapshot-State nicht exakt")
		ctx.check_eq(b.scheduler.next_seq(), a.scheduler.next_seq(), "Scheduler next_seq")
		a.advance_to(a.clock.now + 3 * 3600)
		b.advance_to(b.clock.now + 3 * 3600)
		ctx.check_eq(b.state_hash(), a.state_hash(), "Verlauf nach Restore nicht exakt")
		ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Restore nicht exakt")
	G1aTestUtil.remove_temp(path)


