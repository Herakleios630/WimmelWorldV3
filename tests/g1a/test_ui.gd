extends RefCounted

const VISUAL_RESULT_PATH: String = "res://bench/results/g1a_visual_result.json"


static func run(ctx: G1aTestContext) -> void:
	_test_inspector(ctx)
	_test_event_log(ctx)
	_test_camera_independence(ctx)
	_test_visual_frame_budget(ctx)


static func _test_inspector(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-01", "Inspector: Agent, Needs, Home, Job sichtbar")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	var info: Dictionary = InspectorModel.for_agent(sim, 1)
	ctx.check(not info.is_empty(), "Inspector liefert keine Daten")
	for key in ["name", "age", "role_name", "household_id", "home_name",
			"job_name", "activity_name", "hunger", "energy", "social",
			"position", "next_event"]:
		ctx.check(info.has(key), "Inspector-Feld fehlt: " + key)
	ctx.check_eq(info.get("name", ""), "Arnd", "Inspector-Name")
	ctx.check(str(info.get("home_name", "")) != "", "Home-Name leer")
	ctx.check(str(info.get("job_name", "")) != "", "Job-Name leer")
	for need_key in ["hunger", "energy", "social"]:
		var v: float = float(info.get(need_key, -1.0))
		ctx.check(v >= 0.0 and v <= 100.0, "Need außerhalb 0..100: " + need_key)
	# Needs-Snapshot stimmt mit Inspector überein.
	var snap: PackedFloat64Array = InspectorModel.needs_snapshot(sim, 1)
	ctx.check_close(snap[0], float(info["hunger"]), 0.001, "Hunger-Snapshot")
	ctx.check_close(snap[1], float(info["energy"]), 0.001, "Energie-Snapshot")
	ctx.check_close(snap[2], float(info["social"]), 0.001, "Sozial-Snapshot")


static func _test_event_log(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-02", "Event-Log sichtbar, keine Sim-Mutation")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 13, 0))
	var recent: Array = EventLogModel.recent(sim, 40)
	ctx.check(recent.size() > 0, "Event-Log ist leer")
	var templates: PackedStringArray = PackedStringArray()
	var last_time: int = -1
	var ordered: bool = true
	for entry in recent:
		templates.append(str(entry["template"]))
		if int(entry["time"]) < last_time:
			ordered = false
		last_time = int(entry["time"])
	ctx.check(ordered, "Event-Log nicht chronologisch")
	for expected in ["meal_end", "work_end", "arrive"]:
		ctx.check(templates.has(expected), "Kernereignis fehlt im Log: " + expected)
	var state_before: int = sim.state_hash()
	var log_before: int = sim.event_hash()
	for i in 5:
		EventLogModel.recent(sim, 12)
		InspectorModel.for_agent(sim, 1)
		InspectorModel.for_agent(sim, 10)
	ctx.check_eq(sim.state_hash(), state_before, "Log-/Inspector-Lesen mutiert Sim")
	ctx.check_eq(sim.event_hash(), log_before, "Log-Lesen verändert Event-Log")


static func _test_camera_independence(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-03", "Kamera/Zoom/Sichtbarkeit ändern keinen Sim-Zustand")
	var a: Simulation = G1aTestUtil.new_sim()
	var b: Simulation = G1aTestUtil.new_sim()
	var view: ViewState = ViewState.new()
	var target: int = G1aTestUtil.abs_time(0, 18, 0)
	while a.clock.now < target:
		view.camera_position = Vector2(32.0 + a.clock.now % 64, 40.0)
		view.zoom = 0.75 + float(a.clock.now % 5) * 0.5
		view.agents_visible = (a.clock.now % 2 == 0)
		view.event_log_visible = (a.clock.now % 3 == 0)
		view.selected_agent_id = 1 + (a.clock.now % 10)
		InspectorModel.for_agent(a, view.selected_agent_id)
		EventLogModel.recent(a, 12)
		a.advance_to(mini(target, a.clock.now + 17))
	b.advance_to(target)
	ctx.check_eq(a.state_hash(), b.state_hash(), "View-Status verändert Sim-Zustand")
	ctx.check_eq(a.event_hash(), b.event_hash(), "View-Status verändert Event-Log")
	ctx.check_eq(view.selected_agent_id >= 1, true, "Auswahl nicht gesetzt")
	# Sichtbarkeit aus/an darf keine Events erzeugen.
	var count_before: int = a.logs.debug_events.size()
	view.agents_visible = false
	view.agents_visible = true
	EventLogModel.recent(a, 5)
	ctx.check_eq(a.logs.debug_events.size(), count_before,
		"Sichtbarkeit erzeugt Sim-Events")


static func _test_visual_frame_budget(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-04", "10 Agenten@50x: Gesamtframe p95 <= 16 ms (visuell)")
	ctx.check(FileAccess.file_exists(VISUAL_RESULT_PATH),
		"visueller Benchmark fehlt; res://tests/g1a/bench_visual.tscn ausführen")
	if not FileAccess.file_exists(VISUAL_RESULT_PATH):
		return
	var text: String = FileAccess.get_file_as_string(VISUAL_RESULT_PATH)
	var data = JSON.parse_string(text)
	ctx.check(data is Dictionary, "Visual-Ergebnis ist kein JSON-Objekt")
	if not (data is Dictionary):
		return
	var p95: float = float(data.get("frame_p95_ms", 999.0))
	var fps: float = float(data.get("fps_avg", 0.0))
	var sim_days: float = float(data.get("sim_days", 0.0))
	ctx.check(p95 > 0.0 and p95 <= 16.0, "Frame-p95 über 16 ms: %.2f" % p95)
	ctx.check(fps >= 55.0, "FPS zu niedrig: %.1f" % fps)
	ctx.check(sim_days > 0.5, "visueller Lauf deckt keinen halben Sim-Tag ab")
	ctx.check(int(data.get("agents", 0)) == 10, "visueller Lauf nicht mit 10 Agenten")
