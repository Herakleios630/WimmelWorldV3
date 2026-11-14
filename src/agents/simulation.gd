class_name Simulation
extends RefCounted

## Autoritativer G1a-Zustand und Orchestrierung.
##
## - Clock/Scheduler/RNG/Agenten/Weltbestand sind die einzigen Zustandsquellen.
## - Keine View-/Kamera-Abhängigkeit.
## - Events liegen auf logischen Terminen; advance_to() verarbeitet nur fällige
##   Events und setzt danach die Zielzeit. Needs bleiben lazy.

const MAX_EVENTS_PER_ADVANCE: int = 500000

var config: SimConfig
var clock: SimClock
var world: WorldMap
var store: AgentStore
var routes: RouteStore
var scheduler: EventScheduler
var rng: RngStreams
var logs: SimLogs
var chronicle: ChronicleStore
var decisions: DecisionSystem
var lifecycle: LifecycleSystem
var pathfinder: PathFinder
var batcher: EventBatcher

var records: Array = []
var households: Array = []
var relationships: Array = []
var replay_meta: Dictionary = {}

var grain: int = 0
var grain_produced: int = 0
var grain_harvested: int = 0
var meals_served: int = 0
var meals_skipped: int = 0
var harvests_completed: int = 0
var field_cycles_completed: int = 0
var births: int = 0
var deaths: int = 0
var partnerships_formed: int = 0
var households_dissolved: int = 0
var lifecycle_ticks: int = 0

# Jahresbilanz (30-Tage-Jahr). year_* laufen, last_year_* ist der letzte
# abgeschlossene Jahresabschluss.
var year_index: int = 0
var year_start_grain: int = 0
var year_grain_produced: int = 0
var year_meals_served: int = 0
var year_meals_skipped: int = 0
var year_harvests: int = 0
var last_year_index: int = -1
var last_year_start_grain: int = 0
var last_year_grain_produced: int = 0
var last_year_meals_served: int = 0
var last_year_meals_skipped: int = 0
var last_year_harvests: int = 0
var last_year_end_grain: int = 0

var _frame_target: int = 0
var _path_frame_index: int = -1


static func create(p_config: SimConfig = null) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.setup_new(p_config if p_config != null else SimConfig.new())
	return sim


func setup_new(p_config: SimConfig) -> void:
	config = p_config
	clock = SimClock.new(config.start_time)
	rng = RngStreams.new(config.seed)
	world = WorldMap.create_for_config(config)
	store = AgentStore.new()
	routes = RouteStore.new()
	scheduler = EventScheduler.new()
	logs = SimLogs.new()
	chronicle = ChronicleStore.new(config)
	batcher = EventBatcher.new()
	decisions = DecisionSystem.new(self)
	lifecycle = LifecycleSystem.new(self)
	pathfinder = _make_pathfinder()
	if config.profile == SimConfig.PROFILE_G2:
		var generated: Dictionary = PopulationGenerator.generate(world, config)
		records = generated["records"]
		households = generated["households"]
		relationships = generated["relationships"]
	else:
		records = AgentRecords.default_agents()
		households = AgentRecords.default_households()
		relationships = AgentRecords.default_relationships()
	grain = config.start_grain
	grain_produced = 0
	grain_harvested = 0
	meals_served = 0
	meals_skipped = 0
	harvests_completed = 0
	field_cycles_completed = 0
	births = 0
	deaths = 0
	partnerships_formed = 0
	households_dissolved = 0
	lifecycle_ticks = 0
	year_index = 0
	year_start_grain = config.start_grain
	year_grain_produced = 0
	year_meals_served = 0
	year_meals_skipped = 0
	year_harvests = 0
	last_year_index = -1
	last_year_start_grain = 0
	last_year_grain_produced = 0
	last_year_meals_served = 0
	last_year_meals_skipped = 0
	last_year_harvests = 0
	last_year_end_grain = 0
	_spawn_initial_agents()
	_schedule_initial_field_ticks()
	_prewarm_paths()
	log_event(SimEvent.T_SIM_START, SimEvent.IMPORTANCE_NOTABLE,
		0, "sim_start", "G1b gestartet", config.seed)
	log_event(SimEvent.T_DAY_START, SimEvent.IMPORTANCE_ROUTINE,
		0, "day_start", "Tag beginnt", clock.day_index())
	for row in store.count:
		decisions.on_agent_wake(row)
	var next_midnight: int = (clock.day_index() + 1) * SimConfig.TICKS_PER_DAY
	scheduler.push(next_midnight, SimKinds.EVENT_DAY_TICK, 0)


func _spawn_initial_agents() -> void:
	for record in records:
		var rec: AgentRecord = record
		var home_point: Vector2 = world.door_point(rec.home_building_id)
		store.add_agent(rec.id, rec.age_years, rec.role, rec.household_id,
			rec.home_building_id, rec.job_id, rec.job_kind,
			home_point.x, home_point.y,
			config.start_hunger, config.start_energy, config.start_social,
			clock.now, config.start_hygiene, config.start_fun,
			config.start_health, rec.sex, rec.birth_day)


func _make_pathfinder() -> PathFinder:
	if config.profile != SimConfig.PROFILE_G2:
		return null
	return PathFinder.new(world, config.map_version,
		config.path_cache_capacity, config.path_lookup_budget,
		config.path_recalc_budget)


func _prewarm_paths() -> void:
	if pathfinder == null or decisions == null:
		return
	for row in store.count:
		if store.alive[row] == 0:
			continue
		var points: PackedVector2Array = decisions.warmup_points(row)
		if points.is_empty():
			continue
		var anchors: PackedVector2Array = PackedVector2Array()
		anchors.append(points[1])  # home
		anchors.append(points[2])  # field
		anchors.append(points[3])  # workshop
		anchors.append(points[4])  # plaza
		anchors.append(points[5])  # well
		for start_point in points:
			for goal_point in anchors:
				pathfinder.prewarm(start_point, goal_point)


func _schedule_initial_field_ticks() -> void:
	for field_id in world.field_ids():
		var field: Building = world.building_by_id(field_id)
		if field == null or field.field_stage != Building.FIELD_GROWING:
			continue
		var payload: int = (field_id << 32) | (field.field_growth_gen & 0xFFFFFFFF)
		scheduler.push(field.field_growth_end, SimKinds.EVENT_FIELD_TICK, payload)


## Pfadabfrage mit Profil-Dispatch. G1 nutzt unverändert den Waypoint-Graphen;
## G2 nutzt A* + Cache mit Frame-Budget.
func find_travel_path(start_point: Vector2, goal_point: Vector2) -> PackedVector2Array:
	if pathfinder != null:
		return pathfinder.request_path(start_point, goal_point)
	return world.find_route(start_point, goal_point)


func path_was_deferred() -> bool:
	return pathfinder != null and pathfinder.last_deferred


## Deterministische Vertagung auf den nächsten festen Sim-Frame (50x-Raster).
## Der Frame hängt damit nicht von der advance_to-Chunk-Größe des Aufrufers ab.
func deferred_wake_time() -> int:
	var span: int = maxi(1, config.path_frame_ticks)
	return ((clock.now / span) + 1) * span


func advance_to(target_time: int) -> int:
	if target_time < clock.now:
		return 0
	_frame_target = target_time
	var processed: int = 0
	while scheduler.size() > 0 and scheduler.peek_time() <= target_time:
		var batch_time: int = scheduler.peek_time()
		if pathfinder != null:
			var span: int = maxi(1, config.path_frame_ticks)
			var frame_index: int = batch_time / span
			if frame_index != _path_frame_index:
				# Budget gilt pro festem Sim-Frame, nicht pro Aufrufer-Chunk.
				pathfinder.begin_frame()
				_path_frame_index = frame_index
		var batch_start: int = processed
		var last_seq: int = -1
		# Alle Events derselben Sim-Zeit bilden einen Batch; die Reihenfolge
		# bleibt exakt die Scheduler-Ordnung (time, seq).
		while scheduler.size() > 0 and scheduler.peek_time() == batch_time:
			if not scheduler.pop():
				break
			var event_time: int = scheduler.last_time
			if event_time > clock.now:
				clock.now = event_time
			last_seq = scheduler.last_seq
			_dispatch(scheduler.last_kind, scheduler.last_payload)
			processed += 1
			if processed > MAX_EVENTS_PER_ADVANCE:
				push_error("event storm guard triggered at t=%d" % clock.now)
				break
		if batcher != null:
			batcher.record(batch_time, processed - batch_start, last_seq)
		if processed > MAX_EVENTS_PER_ADVANCE:
			break
	clock.now = target_time
	if pathfinder != null:
		pathfinder.end_frame()
	return processed


func _dispatch(kind: int, payload: int) -> void:
	if kind == SimKinds.EVENT_AGENT_WAKE:
		var row: int = payload & 0xFFFFFFFF
		var gen: int = (payload >> 32) & 0xFFFFFFFF
		if row >= 0 and row < store.count and store.wake_gen[row] == gen:
			decisions.on_agent_wake(row)
	elif kind == SimKinds.EVENT_DAY_TICK:
		var day: int = clock.day_index()
		# Die Chronik finalisiert zuerst den abgelaufenen Tag. Das erzeugt
		# keine Sim-Events und ändert keine Event-Reihenfolge.
		if chronicle != null:
			chronicle.on_day_tick(day, self)
		log_event(SimEvent.T_DAY_START, SimEvent.IMPORTANCE_ROUTINE,
			0, "day_start", "Tag beginnt", day)
		lifecycle.on_day_tick(day)
		if config.profile == SimConfig.PROFILE_G2:
			routes.compact(store)
		if day > 0 and day % SimConfig.YEAR_DAYS == 0:
			_complete_year()
		var next_midnight: int = (clock.day_index() + 1) * SimConfig.TICKS_PER_DAY
		scheduler.push(next_midnight, SimKinds.EVENT_DAY_TICK, 0)
	elif kind == SimKinds.EVENT_FIELD_TICK:
		var field_id: int = (payload >> 32) & 0xFFFFFFFF
		var gen: int = payload & 0xFFFFFFFF
		decisions.on_field_tick(field_id, gen)


func _complete_year() -> void:
	last_year_index = year_index
	last_year_start_grain = year_start_grain
	last_year_grain_produced = year_grain_produced
	last_year_meals_served = year_meals_served
	last_year_meals_skipped = year_meals_skipped
	last_year_harvests = year_harvests
	last_year_end_grain = grain
	log_event(SimEvent.T_YEAR_SUMMARY, SimEvent.IMPORTANCE_NOTABLE, 0,
		"year_summary", "Jahr %d: Start %d + Ernte %d - Mahlzeiten %d = %d" % [
			year_index + 1, year_start_grain, year_grain_produced,
			year_meals_served, grain], grain)
	year_index += 1
	year_start_grain = grain
	year_grain_produced = 0
	year_meals_served = 0
	year_meals_skipped = 0
	year_harvests = 0


func log_event(type: int, importance: int, agent_id: int, template_key: String,
		text: String = "", data: int = 0) -> SimEvent:
	var event: SimEvent = logs.emit(clock.now, type, importance, agent_id,
		template_key, text, data)
	if chronicle != null:
		chronicle.ingest(event, self)
	return event


func request_wake_by_id(agent_id: int, at_time: int) -> void:
	var row: int = store.row_for_id(agent_id)
	if row >= 0:
		decisions.request_wake(row, at_time)


func agent_position_at(agent_id: int, t: int) -> Vector2:
	var row: int = store.row_for_id(agent_id)
	if row < 0:
		return Vector2.ZERO
	return decisions.position_at(row, t)


func current_position(row: int) -> Vector2:
	return decisions.position_at(row, clock.now)


func day_index() -> int:
	return clock.day_index()


func count_alive() -> int:
	var n: int = 0
	for row in store.count:
		if store.alive[row] != 0:
			n += 1
	return n


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, config.config_hash())
	h = HashUtil.mix_i64(h, clock.now)
	h = HashUtil.mix(h, scheduler.state_hash())
	h = HashUtil.mix(h, rng.state_hash())
	h = HashUtil.mix(h, store.state_hash(clock.now))
	h = HashUtil.mix(h, routes.state_hash())
	h = HashUtil.mix_i64(h, grain)
	h = HashUtil.mix_i64(h, grain_produced)
	h = HashUtil.mix_i64(h, grain_harvested)
	h = HashUtil.mix_i64(h, meals_served)
	h = HashUtil.mix_i64(h, meals_skipped)
	h = HashUtil.mix_i64(h, harvests_completed)
	h = HashUtil.mix_i64(h, field_cycles_completed)
	h = HashUtil.mix_i64(h, births)
	h = HashUtil.mix_i64(h, deaths)
	h = HashUtil.mix_i64(h, partnerships_formed)
	h = HashUtil.mix_i64(h, households_dissolved)
	h = HashUtil.mix_i64(h, lifecycle_ticks)
	for field_id in world.field_ids():
		var field: Building = world.building_by_id(field_id)
		if field == null:
			continue
		h = HashUtil.mix(h, field.id)
		h = HashUtil.mix(h, field.field_stage)
		h = HashUtil.mix_i64(h, field.field_work_s)
		h = HashUtil.mix_i64(h, field.field_growth_end)
		h = HashUtil.mix(h, field.field_growth_gen)
	h = HashUtil.mix_i64(h, year_index)
	h = HashUtil.mix_i64(h, year_start_grain)
	h = HashUtil.mix_i64(h, year_grain_produced)
	h = HashUtil.mix_i64(h, year_meals_served)
	h = HashUtil.mix_i64(h, year_meals_skipped)
	h = HashUtil.mix_i64(h, year_harvests)
	h = HashUtil.mix_i64(h, last_year_index)
	h = HashUtil.mix_i64(h, last_year_start_grain)
	h = HashUtil.mix_i64(h, last_year_grain_produced)
	h = HashUtil.mix_i64(h, last_year_meals_served)
	h = HashUtil.mix_i64(h, last_year_meals_skipped)
	h = HashUtil.mix_i64(h, last_year_harvests)
	h = HashUtil.mix_i64(h, last_year_end_grain)
	for record in records:
		h = HashUtil.mix(h, (record as AgentRecord).state_hash())
	for household in households:
		h = HashUtil.mix(h, (household as HouseholdRecord).state_hash())
	for relationship in relationships:
		h = HashUtil.mix(h, (relationship as RelationshipRecord).state_hash())
	return h


func event_hash() -> int:
	return logs.debug_hash()


func chronicle_hash() -> int:
	return logs.chronicle_hash()


## Hash der kuratierten Chronik. Bewusst nicht Teil von state_hash: Kürzen
## oder Löschen der Chronik darf den Simulationszustand nicht verändern.
func curated_chronicle_hash() -> int:
	return chronicle.state_hash() if chronicle != null else 0


func navigation_stats() -> Dictionary:
	if pathfinder == null:
		return {}
	return pathfinder.stats()


func batch_stats() -> Dictionary:
	if batcher == null:
		return {}
	return batcher.stats()


## Wird nach einem Save-Restore aufgerufen: abgeleitete Laufzeitobjekte binden.
## Der Pfad-Cache ist abgeleitet und startet nach jedem Load leer.
func rebuild_runtime() -> void:
	if world == null:
		world = WorldMap.create_for_config(config)
	if chronicle == null:
		chronicle = ChronicleStore.new(config)
	if batcher == null:
		batcher = EventBatcher.new()
	decisions = DecisionSystem.new(self)
	lifecycle = LifecycleSystem.new(self)
	pathfinder = _make_pathfinder()
	_prewarm_paths()


func save_to(path: String) -> Dictionary:
	return SimSave.save_simulation(self, path)


static func load_from(path: String) -> Dictionary:
	return SimSave.load_simulation(path)
