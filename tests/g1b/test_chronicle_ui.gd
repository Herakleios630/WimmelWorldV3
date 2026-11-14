extends RefCounted

## G1b-Schritt 3: T-UI-05..08.
## Familienbaum, Follow, Alerts, Story of the Day. Headless Modelle, keine
## Fensterabhängigkeit.

const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")


static func run(ctx: G1aTestContext) -> void:
	_test_family_tree(ctx)
	_test_follow(ctx)
	_test_alerts(ctx)
	_test_story_of_day(ctx)


static func _run_year(seed_value: int) -> Simulation:
	var config: SimConfig = SimConfig.new()
	config.seed = seed_value
	var sim: Simulation = Simulation.create(config)
	var target: int = sim.clock.now + 30 * SimConfig.TICKS_PER_DAY
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + 3600))
	return sim


static func _test_family_tree(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-05", "Familienbaum: >= 3 Generationen, tote Knoten, korrekte Kanten")
	var sim: Simulation = _run_year(FeaturedSeed.FEATURED_SEED)
	var tree: Dictionary = FamilyTreeModel.build(sim)
	ctx.check(int(tree["generation_count"]) >= 3,
		"Familienbaum hat weniger als 3 Generationen: %d" % int(tree["generation_count"]))
	var edges: Array = tree["parent_edges"]
	ctx.check(_has_edge(edges, 8, 9), "Kante A5->A6 fehlt")
	ctx.check(_has_edge(edges, 9, 10), "Kante A6->A7 fehlt")
	var by_id: Dictionary = tree["by_id"]
	ctx.check(by_id.has(2) and not bool(by_id[2]["alive"]),
		"tote Alma fehlt als historischer Knoten")
	ctx.check(by_id.has(8) and not bool(by_id[8]["alive"]),
		"toter Gustav fehlt als historischer Knoten")
	if by_id.has(8):
		ctx.check(int(by_id[8]["death_day"]) >= 0, "toter Knoten ohne Todeszeit")
	var birth_edges: int = 0
	for edge in edges:
		if int(edge["b"]) > 10:
			birth_edges += 1
	ctx.check(birth_edges >= 2, "Geburtskanten zu Neugeborenen fehlen")
	var edge_keys: Dictionary = {}
	for edge in edges:
		var key: String = "%d:%d" % [int(edge["a"]), int(edge["b"])]
		ctx.check(not edge_keys.has(key), "doppelte Elternkante: " + key)
		edge_keys[key] = true
	var repeat: Dictionary = FamilyTreeModel.build(sim)
	ctx.check_eq(int(repeat["generation_count"]), int(tree["generation_count"]),
		"Familienbaum nicht deterministisch")
	ctx.check_eq(int((repeat["nodes"] as Array).size()), int((tree["nodes"] as Array).size()),
		"Familienbaum-Knoten nicht deterministisch")


static func _has_edge(edges: Array, a: int, b: int) -> bool:
	for edge in edges:
		if int(edge["a"]) == a and int(edge["b"]) == b:
			return true
	return false


static func _test_follow(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-06", "Follow: 60 s stabil, keine Sim-Mutation")
	var config: SimConfig = SimConfig.new()
	config.seed = SimConfig.DEFAULT_SEED
	var sim: Simulation = Simulation.create(config)
	var control: Simulation = Simulation.create(config)
	var start: int = G1aTestUtil.abs_time(1, 8, 0)
	sim.advance_to(start)
	control.advance_to(start)
	var view: ViewState = ViewState.new()
	view.follow_enabled = true
	view.follow_agent_id = 1
	var camera_tile: Vector2 = FollowModel.target_tile(sim, 1)
	var frames: int = 60 * 60
	var stable: bool = true
	for i in frames:
		sim.advance_to(sim.clock.now + 1)
		camera_tile = FollowModel.step(sim, view, camera_tile, 1.0 / 60.0)
		if not FollowModel.has_target(sim, 1):
			stable = false
			break
		if camera_tile != FollowModel.target_tile(sim, 1):
			stable = false
			break
	control.advance_to(sim.clock.now)
	ctx.check(stable, "Follow verlor das Ziel oder sprang")
	ctx.check_eq(view.follow_agent_id, 1, "Follow-Ziel wurde verändert")
	ctx.check_eq(sim.state_hash(), control.state_hash(),
		"Follow verändert den Sim-Zustand")
	ctx.check_eq(sim.event_hash(), control.event_hash(),
		"Follow verändert das Event-Log")
	ctx.check_eq(frames, 3600, "Follow-Messfenster ist nicht 60 s @60 Hz")
	ctx.check(FollowModel.pick_default_target(sim, 0) > 0,
		"Follow findet kein Standardziel")


static func _test_alerts(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-07", "Alerts: <= 20/Tag, nur major/historic")
	var sim: Simulation = _run_year(FeaturedSeed.FEATURED_SEED)
	var max_alerts: int = 0
	var limit_day: int = -1
	var limit_count: int = 0
	for day in range(0, 30):
		var alerts: Array = AlertModel.for_day(sim.chronicle, sim, day)
		max_alerts = maxi(max_alerts, alerts.size())
		if alerts.size() > limit_count:
			limit_count = alerts.size()
			limit_day = day
		ctx.check(alerts.size() <= sim.config.chronicle_alert_max_per_day,
			"Alert-Limit überschritten an Tag %d: %d" % [day, alerts.size()])
		for alert in alerts:
			ctx.check(int(alert["importance"]) >= SimEvent.IMPORTANCE_MAJOR,
				"Alert mit Routine/Notable-Wichtigkeit")
	ctx.check(max_alerts > 0, "keine Alerts im Jahr")
	if limit_day >= 0:
		var limited: Array = AlertModel.for_day(sim.chronicle, sim, limit_day, 2)
		ctx.check(limited.size() <= 2, "Alert-Limit wird nicht angewendet")
	print("G1B_ALERTS max_per_day=%d limit_day=%d" % [max_alerts, limit_day])


static func _test_story_of_day(ctx: G1aTestContext) -> void:
	ctx.begin("T-UI-08", "Story of the Day: <= 7/Tag, deterministisch bei festem Fokus")
	var sim: Simulation = _run_year(FeaturedSeed.FEATURED_SEED)
	var repeat: Simulation = _run_year(FeaturedSeed.FEATURED_SEED)
	var max_story: int = 0
	for day in range(0, 30):
		var story: Array = StoryOfDay.for_day(sim.chronicle, sim, day, 1)
		var story_repeat: Array = StoryOfDay.for_day(repeat.chronicle, repeat, day, 1)
		max_story = maxi(max_story, story.size())
		ctx.check(story.size() <= sim.config.chronicle_story_max_per_day,
			"Story-Limit überschritten an Tag %d: %d" % [day, story.size()])
		var ids: PackedInt32Array = PackedInt32Array()
		var notable_count: int = 0
		for entry in story:
			ids.append(int(entry["id"]))
			if int(entry["importance"]) == SimEvent.IMPORTANCE_NOTABLE:
				notable_count += 1
			ctx.check(int(entry["importance"]) >= SimEvent.IMPORTANCE_NOTABLE,
				"Story enthält Routine-Event")
		ctx.check(notable_count <= 1, "Story enthält mehr als eine persönliche Notable")
		ctx.check_eq(_ids_of(story_repeat), ids,
			"Story bei festem Fokus nicht deterministisch an Tag %d" % day)
	var before: int = sim.curated_chronicle_hash()
	StoryOfDay.for_day(sim.chronicle, sim, 10, 10)
	ctx.check_eq(sim.curated_chronicle_hash(), before,
		"Story-Fokus verändert Chronik-Events")
	print("G1B_STORY max_per_day=%d" % max_story)


static func _ids_of(entries: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for entry in entries:
		out.append(int(entry["id"]))
	return out
