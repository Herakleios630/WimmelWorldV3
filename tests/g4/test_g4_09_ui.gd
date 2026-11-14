extends RefCounted

## T-G4a-09: Inspector/Event-Log/Chronik/Familienbaum/Follow bei 10k.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-09", "Inspector/Event-Log/Chronik/Familienbaum bei 10k")
	var sim: Simulation = G4ATestUtil.shared_year(1337)
	var keys: Array = ["name", "age", "role_name", "household_id", "home_name",
		"job_name", "activity_name", "hunger", "energy", "social", "hygiene",
		"fun", "health", "position", "next_event"]
	var fields_ok: bool = true
	var samples: int = 0
	var max_us: int = 0
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var t0: int = Time.get_ticks_usec()
		var info: Dictionary = InspectorModel.for_agent(sim, sim.store.ids[row])
		max_us = maxi(max_us, Time.get_ticks_usec() - t0)
		samples += 1
		if info.is_empty():
			fields_ok = false
			continue
		for key in keys:
			if not info.has(key):
				fields_ok = false
	ctx.check(fields_ok, "Inspector-Felder fehlen bei 10k")
	ctx.check_eq(samples, sim.count_alive(), "Inspector nicht für alle Lebenden")
	ctx.check(max_us < 100000, "Inspector-Öffnen >= 100 ms: %d us" % max_us)
	var recent: Array = EventLogModel.recent(sim, 60)
	ctx.check(recent.size() > 0, "Event-Log leer")
	var ordered: bool = true
	var last_time: int = -1
	for entry in recent:
		if int(entry["time"]) < last_time:
			ordered = false
		last_time = int(entry["time"])
	ctx.check(ordered, "Event-Log nicht chronologisch")
	var all_entries: Array = ChroniclePanelModel.query(sim, {}, 40)
	ctx.check(all_entries.size() > 0, "Chronik leer")
	var agent_id: int = 0
	for row in sim.store.count:
		if sim.store.alive[row] != 0:
			agent_id = sim.store.ids[row]
			break
	ctx.check(agent_id > 0, "kein lebender Agent für Filter")
	var agent_entries: Array = ChroniclePanelModel.query(sim, {"agent_id": agent_id}, 20)
	var agent_ok: bool = true
	for entry in agent_entries:
		if not (entry["actor_ids"] as PackedInt32Array).has(agent_id) \
				and not (entry["related_ids"] as PackedInt32Array).has(agent_id):
			agent_ok = false
	ctx.check(agent_ok, "Agent-Filter liefert fremde Einträge")
	var household_id: int = sim.store.household_id[sim.store.row_for_id(agent_id)]
	var household_entries: Array = ChroniclePanelModel.query(sim,
		{"household_id": household_id}, 20)
	var household_ok: bool = true
	for entry in household_entries:
		if int(entry["household_id"]) != household_id:
			household_ok = false
	ctx.check(household_ok, "Haushaltsfilter liefert fremde Einträge")
	var t_tree: int = Time.get_ticks_usec()
	var tree: Dictionary = FamilyTreeModel.build(sim)
	var tree_ms: float = float(Time.get_ticks_usec() - t_tree) / 1000.0
	ctx.check_eq(int((tree.get("nodes", []) as Array).size()), sim.records.size(),
		"Familienbaum nicht vollständig")
	ctx.check(int(tree.get("generation_count", 0)) >= 3,
		"Familienbaum hat < 3 Generationen")
	ctx.check(tree_ms < 2000.0, "Familienbaum >= 2000 ms: %.1f" % tree_ms)
	var t0: int = Time.get_ticks_usec()
	for i in 100:
		ChroniclePanelModel.query(sim, {"importance_min": 1}, 18)
	var filter_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	ctx.check(filter_ms < 2000.0, "100 Chronik-Filter >= 2000 ms: %.1f" % filter_ms)
	var target: int = FollowModel.pick_default_target(sim, agent_id)
	ctx.check(target > 0, "Follow findet kein Ziel")
	var stable: bool = true
	var read_only: bool = true
	for i in 30:
		if not FollowModel.has_target(sim, target):
			stable = false
			break
		var hash_before: int = sim.state_hash()
		FollowModel.target_tile(sim, target)
		FollowModel.step(sim, ViewState.new(), Vector2.ZERO, 0.016)
		if sim.state_hash() != hash_before:
			read_only = false
		sim.advance_to(sim.clock.now + 1)
	ctx.check(stable, "Follow-Ziel verliert Stabilität")
	ctx.check(read_only, "Follow mutiert Simulation")
	var day: int = sim.clock.day_index()
	var alerts: Array = AlertModel.for_day(sim.chronicle, sim, day)
	ctx.check(alerts.size() <= sim.config.chronicle_alert_max_per_day,
		"mehr Alerts als Tageslimit")
	var story: Array = StoryOfDay.for_day(sim.chronicle, sim, day, target)
	ctx.check(story.size() <= sim.config.chronicle_story_max_per_day,
		"mehr Story-Einträge als Tageslimit")
	ctx.check_eq(sim.households.size(), 2000, "Haushaltsfilter nicht 2000")
	ctx.check(sim.records.size() >= 10000, "Agentenfilter unter 10000")
	ctx.check_eq(sim.records.size(), sim.store.count, "Records/Store im UI")
	# Chronicle-/UI-Queries nach dem Follow-Lauf dürfen den Zustand nicht ändern.
	var state_after_follow: int = sim.state_hash()
	ChroniclePanelModel.query(sim, {}, 40)
	InspectorModel.for_agent(sim, agent_id)
	FamilyTreeModel.build(sim)
	ctx.check_eq(sim.state_hash(), state_after_follow,
		"UI-/Chronik-Lesen mutiert Sim")
