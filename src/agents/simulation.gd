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


static func create(p_config: SimConfig = null) -> Simulation:
	var sim: Simulation = Simulation.new()
	sim.setup_new(p_config if p_config != null else SimConfig.new())
	return sim


func setup_new(p_config: SimConfig) -> void:
	config = p_config
	clock = SimClock.new(config.start_time)
	rng = RngStreams.new(config.seed)
	world = WorldMap.new(config.seed)
	store = AgentStore.new()
	routes = RouteStore.new()
	scheduler = EventScheduler.new()
	logs = SimLogs.new()
	chronicle = ChronicleStore.new(config)
	decisions = DecisionSystem.new(self)
	lifecycle = LifecycleSystem.new(self)
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


func advance_to(target_time: int) -> int:
	if target_time < clock.now:
		return 0
	var processed: int = 0
	while scheduler.size() > 0 and scheduler.peek_time() <= target_time:
		if not scheduler.pop():
			break
		var event_time: int = scheduler.last_time
		if event_time > clock.now:
			clock.now = event_time
		_dispatch(scheduler.last_kind, scheduler.last_payload)
		processed += 1
		if processed > MAX_EVENTS_PER_ADVANCE:
			push_error("event storm guard triggered at t=%d" % clock.now)
			break
	clock.now = target_time
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
		if day > 0 and day % SimConfig.YEAR_DAYS == 0:
			_complete_year()
		var next_midnight: int = (clock.day_index() + 1) * SimConfig.TICKS_PER_DAY
		scheduler.push(next_midnight, SimKinds.EVENT_DAY_TICK, 0)
	elif kind == SimKinds.EVENT_FIELD_TICK:
		decisions.on_field_tick(payload)


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
	var field: Building = world.building_by_id(WorldMap.B_FIELD)
	if field != null:
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


## Wird nach einem Save-Restore aufgerufen: abgeleitete Laufzeitobjekte binden.
func rebuild_runtime() -> void:
	if world == null:
		world = WorldMap.new(config.seed)
	if chronicle == null:
		chronicle = ChronicleStore.new(config)
	decisions = DecisionSystem.new(self)
	lifecycle = LifecycleSystem.new(self)


func save_to(path: String) -> Dictionary:
	return SimSave.save_simulation(self, path)


static func load_from(path: String) -> Dictionary:
	return SimSave.load_simulation(path)
