extends RefCounted

## T-G2-07: Inspector, Event-Log, Chronik, Familienbaum, Follow, Alerts, Story
## bei 100 Agenten.


static func run(ctx: G1aTestContext) -> void:
	_test_inspector(ctx)
	_test_chronicle_and_family(ctx)
	_test_follow_alerts_story(ctx)


static func _test_inspector(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-07a", "Inspector/Event-Log bei 100 Agenten")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(0, 13, 0), 80)
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
		var us: int = Time.get_ticks_usec() - t0
		max_us = maxi(max_us, us)
		samples += 1
		if info.is_empty():
			fields_ok = false
			continue
		for key in keys:
			if not info.has(key):
				fields_ok = false
	ctx.check(fields_ok, "Inspector-Felder fehlen bei 100 Agenten")
	ctx.check_eq(samples, sim.count_alive(), "Inspector nicht für alle Agenten")
	ctx.check(max_us < 100000, "Inspector-Öffnen >= 100 ms: %d us" % max_us)
	var recent: Array = EventLogModel.recent(sim, 60)
	ctx.check(recent.size() > 0, "Event-Log leer")
	var last_time: int = -1
	var ordered: bool = true
	for entry in recent:
		if int(entry["time"]) < last_time:
			ordered = false
		last_time = int(entry["time"])
	ctx.check(ordered, "Event-Log nicht chronologisch")
	var labels: Dictionary = {}
	var labels_ok: bool = true
	for record in sim.records:
		var rec: AgentRecord = record
		var label: String = WorldView.field_label(rec, rec.id, false)
		if label == "A" or label == "":
			labels_ok = false
		if labels.has(label):
			labels_ok = false
		labels[label] = true
	ctx.check(labels_ok, "Feldlabels bei 100 Agenten nicht eindeutig/lesbar")


static func _test_chronicle_and_family(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-07b", "Chronik-Filter und Familienbaum bei 100 Agenten")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(0, 20, 0), 80)
	var state_before: int = sim.state_hash()
	var all_entries: Array = ChroniclePanelModel.query(sim, {}, 40)
	ctx.check(all_entries.size() > 0, "Chronik-Filter liefert keine Einträge")
	var agent_id: int = 1
	for record in sim.records:
		var rec: AgentRecord = record
		if sim.store.row_for_id(rec.id) >= 0:
			agent_id = rec.id
			break
	var agent_entries: Array = ChroniclePanelModel.query(sim, {"agent_id": agent_id}, 20)
	var agent_ok: bool = true
	for entry in agent_entries:
		var actors: PackedInt32Array = entry["actor_ids"]
		var related: PackedInt32Array = entry["related_ids"]
		if not actors.has(agent_id) and not related.has(agent_id):
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
	var tree: Dictionary = FamilyTreeModel.build(sim)
	ctx.check(int(tree.get("nodes", []).size()) >= 100, "Familienbaum < 100 Knoten")
	ctx.check(int(tree.get("generation_count", 0)) >= 3,
		"Familienbaum hat weniger als 3 Generationen")
	ctx.check(sim.households.size() >= 20 and sim.households.size() <= 25,
		"Chronik-Haushaltsfilter nicht auf 20-25 Haushalte skalierbar")
	ctx.check_eq(sim.state_hash(), state_before, "Chronik-/Baum-Lesen mutiert Sim")
	# Filterkosten dürfen die Simulation nicht ausbremsen.
	var t0: int = Time.get_ticks_usec()
	for i in 100:
		ChroniclePanelModel.query(sim, {"importance_min": 1}, 18)
	var filter_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	ctx.check(filter_ms < 1000.0, "100 Chronik-Filterabfragen >= 1000 ms: %.1f" % filter_ms)


static func _test_follow_alerts_story(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-07c", "Follow stabil, Alerts/Story im Tageslimit")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(0, 15, 0), 80)
	var target: int = FollowModel.pick_default_target(sim, 42)
	ctx.check(target > 0, "Follow findet kein Ziel")
	var stable: bool = true
	var read_only: bool = true
	for i in 60:
		if not FollowModel.has_target(sim, target):
			stable = false
			break
		var hash_before_read: int = sim.state_hash()
		FollowModel.target_tile(sim, target)
		FollowModel.step(sim, ViewState.new(), Vector2.ZERO, 0.016)
		if sim.state_hash() != hash_before_read:
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
