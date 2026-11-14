class_name SimSave
extends RefCounted

## Versioniertes Binär-Save für G1a. Enthält autoritativen Zustand inklusive
## Scheduler, RNG, Agenten-SoA, Weltbestand, Routen und kalten Records.
## Debug- und Chronik-Log sind getrennte Sektionen und keine Replay-Quelle.
##
## Header: MAGIC u32 | SCHEMA u32 | GAME_VERSION u32 | CONFIG_HASH u64 |
##         PAYLOAD_SIZE u64

const MAGIC: int = 0x57473141
const SCHEMA_VERSION: int = 5
const GAME_VERSION: int = 5
const HEADER_SIZE: int = 28
const MAX_ARRAY: int = 2000000


static func default_path() -> String:
	return "user://g1a_save.bin"


static func save_simulation(sim: Simulation, path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var payload_writer: ByteWriter = ByteWriter.new()
	_encode_payload(sim, payload_writer)
	var payload: PackedByteArray = payload_writer.buf
	var writer: ByteWriter = ByteWriter.new()
	writer.u32(MAGIC)
	writer.u32(SCHEMA_VERSION)
	writer.u32(GAME_VERSION)
	writer.u64(sim.config.config_hash())
	writer.u64(payload.size())
	writer.raw(payload)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_write_failed", "path": path,
			"code": FileAccess.get_open_error()}
	file.store_buffer(writer.buf)
	file.close()
	var elapsed: float = float(Time.get_ticks_usec() - t0) / 1000.0
	return {"ok": true, "path": path, "bytes": writer.size(),
		"save_ms": elapsed, "schema": SCHEMA_VERSION,
		"config_hash": sim.config.config_hash(),
		"replay_meta": Replay.replay_meta(sim),
		"chronicle_budget": sim.chronicle.budget_info()}


static func load_simulation(path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {"ok": false, "error": "read_failed_or_empty", "path": path}
	var result: Dictionary = decode_bytes(bytes)
	if result["ok"]:
		result["load_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
		result["path"] = path
		result["bytes"] = bytes.size()
	return result


static func decode_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE:
		return {"ok": false, "error": "file_too_short"}
	var header: ByteReader = ByteReader.new(bytes)
	var magic: int = header.u32()
	if magic != MAGIC:
		return {"ok": false, "error": "bad_magic", "magic": magic}
	var schema: int = header.u32()
	if schema != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema", "schema": schema}
	var game_version: int = header.u32()
	if game_version < 1:
		return {"ok": false, "error": "unsupported_game_version", "game_version": game_version}
	var config_hash: int = header.u64()
	var payload_size: int = header.u64()
	if payload_size < 0 or HEADER_SIZE + payload_size > bytes.size():
		return {"ok": false, "error": "bad_payload_size", "payload_size": payload_size}
	var payload: PackedByteArray = bytes.slice(HEADER_SIZE, HEADER_SIZE + payload_size)
	var reader: ByteReader = ByteReader.new(payload)
	var config: SimConfig = _read_config(reader)
	if not reader.ok:
		return {"ok": false, "error": reader.error}
	if config.config_hash() != config_hash:
		return {"ok": false, "error": "config_hash_mismatch"}
	var sim: Simulation = Simulation.new()
	sim.config = config
	var now: int = reader.i64()
	sim.clock = SimClock.new(now)
	sim.scheduler = _read_scheduler(reader)
	sim.rng = RngStreams.new(config.seed)
	for i in RngStreams.NAMES.size():
		(sim.rng.streams[i] as RngStream).state = reader.i64()
	sim.world = WorldMap.create_for_config(config)
	sim.store = _read_store(reader)
	if not reader.ok:
		return {"ok": false, "error": reader.error}
	sim.records = _read_records(reader)
	sim.households = _read_households(reader)
	sim.relationships = _read_relationships(reader)
	sim.grain = reader.i32()
	sim.grain_produced = reader.i64()
	sim.grain_harvested = reader.i64()
	sim.meals_served = reader.i64()
	sim.meals_skipped = reader.i64()
	sim.harvests_completed = reader.i64()
	sim.field_cycles_completed = reader.i64()
	sim.births = reader.i64()
	sim.deaths = reader.i64()
	sim.partnerships_formed = reader.i64()
	sim.households_dissolved = reader.i64()
	sim.lifecycle_ticks = reader.i64()
	var field_count: int = reader.u32()
	if field_count < 0 or field_count > 16:
		return {"ok": false, "error": "bad_field_count"}
	for _i in field_count:
		var field_id: int = reader.i32()
		var field_stage: int = reader.i32()
		var field_work_s: int = reader.i64()
		var field_growth_end: int = reader.i64()
		var field_growth_gen: int = reader.i32()
		var field: Building = sim.world.building_by_id(field_id)
		if field != null:
			field.field_stage = field_stage
			field.field_work_s = field_work_s
			field.field_growth_end = field_growth_end
			field.field_growth_gen = field_growth_gen
	sim.year_index = reader.i64()
	sim.year_start_grain = reader.i64()
	sim.year_grain_produced = reader.i64()
	sim.year_meals_served = reader.i64()
	sim.year_meals_skipped = reader.i64()
	sim.year_harvests = reader.i64()
	sim.last_year_index = reader.i64()
	sim.last_year_start_grain = reader.i64()
	sim.last_year_grain_produced = reader.i64()
	sim.last_year_meals_served = reader.i64()
	sim.last_year_meals_skipped = reader.i64()
	sim.last_year_harvests = reader.i64()
	sim.last_year_end_grain = reader.i64()
	sim.routes = _read_routes(reader)
	_read_logs(reader, sim)
	sim.chronicle = ChronicleStore.read_from(reader, config)
	var replay_version: int = reader.i32()
	var replay_seed: int = reader.i64()
	var replay_config_hash: int = reader.i64()
	var replay_snapshot_time: int = reader.i64()
	sim.replay_meta = {
		"version": replay_version,
		"seed": replay_seed,
		"config_hash": replay_config_hash,
		"snapshot_time": replay_snapshot_time,
		"source": "seed_config_snapshot",
	}
	sim.decisions = DecisionSystem.new(sim)
	sim.rebuild_runtime()
	if not reader.ok:
		return {"ok": false, "error": reader.error}
	if reader.remaining() != 0:
		return {"ok": false, "error": "trailing_bytes", "remaining": reader.remaining()}
	return {"ok": true, "sim": sim, "schema": schema, "game_version": game_version,
		"config_hash": config_hash, "replay_meta": sim.replay_meta.duplicate(),
		"chronicle_budget": sim.chronicle.budget_info()}


static func _encode_payload(sim: Simulation, w: ByteWriter) -> void:
	var config: SimConfig = sim.config
	w.i64(config.seed)
	w.i64(config.start_time)
	w.i32(config.profile)
	w.i32(config.world_size)
	w.i32(config.target_agents)
	w.i32(config.target_households)
	w.i32(config.path_cache_capacity)
	w.i32(config.path_recalc_budget)
	w.i32(config.path_lookup_budget)
	w.i32(config.path_frame_ticks)
	w.i32(config.map_version)
	w.f64(config.start_hunger)
	w.f64(config.start_energy)
	w.f64(config.start_social)
	w.f64(config.start_hygiene)
	w.f64(config.start_fun)
	w.f64(config.start_health)
	w.f64(config.hunger_per_day)
	w.f64(config.energy_per_16h_awake)
	w.f64(config.energy_per_8h_sleep)
	w.f64(config.social_per_day)
	w.f64(config.hygiene_per_day)
	w.f64(config.fun_per_day)
	w.f64(config.hunger_threshold)
	w.f64(config.energy_threshold)
	w.f64(config.social_threshold)
	w.f64(config.hygiene_threshold)
	w.f64(config.fun_threshold)
	w.f64(config.meal_hunger_reduction)
	w.f64(config.social_gain)
	w.f64(config.wash_gain)
	w.f64(config.fun_gain)
	w.f64(config.social_fun_gain)
	w.f64(config.health_bad_per_day)
	w.f64(config.health_recovery_per_day)
	w.f64(config.health_old_per_year)
	w.f64(config.walk_speed)
	w.i32(config.start_grain)
	w.i64(config.field_plow_work_s)
	w.i64(config.field_sow_work_s)
	w.i64(config.field_harvest_work_s)
	w.i64(config.field_grow_s)
	w.i64(config.field_harvest_yield)
	w.f64(config.health_critical_threshold)
	w.f64(config.health_critical_monthly_chance)
	w.f64(config.health_multiplier_curve)
	w.i64(config.lifecycle_first_roll_day)
	w.i64(config.lifecycle_roll_interval_days)
	w.i64(config.lifecycle_rolls_per_year)
	w.f64(config.mortality_age_0_4)
	w.f64(config.mortality_age_5_14)
	w.f64(config.mortality_age_15_29)
	w.f64(config.mortality_age_30_39)
	w.f64(config.mortality_age_40_49)
	w.f64(config.mortality_age_50_64)
	w.f64(config.mortality_age_65_79)
	w.f64(config.mortality_age_80_plus)
	w.i64(config.pair_min_age)
	w.i64(config.pair_max_age)
	w.i64(config.fertile_female_min)
	w.i64(config.fertile_female_max)
	w.i64(config.fertile_male_min)
	w.i64(config.fertile_male_max)
	w.f64(config.monthly_conception_chance)
	w.i64(config.pregnancy_ticks)
	w.f64(config.birth_death_chance)
	w.i64(config.chronicle_recent_days)
	w.i64(config.chronicle_recent_max_events)
	w.i64(config.chronicle_summary_days)
	w.i64(config.chronicle_summary_max)
	w.i64(config.chronicle_historic_max)
	w.i64(config.chronicle_story_max_per_day)
	w.i64(config.chronicle_alert_max_per_day)

	w.i64(sim.clock.now)
	var sched: EventScheduler = sim.scheduler
	w.u32(sched.size())
	w.i64(sched.next_seq())
	_write_i64_array(w, sched.times, sched.size())
	_write_i64_array(w, sched.seqs, sched.size())
	_write_i32_array(w, sched.kinds, sched.size())
	_write_i64_array(w, sched.payloads, sched.size())

	for i in RngStreams.NAMES.size():
		w.i64((sim.rng.streams[i] as RngStream).state)

	_write_store(w, sim.store)
	_write_records(w, sim.records)
	_write_households(w, sim.households)
	_write_relationships(w, sim.relationships)

	w.i32(sim.grain)
	w.i64(sim.grain_produced)
	w.i64(sim.grain_harvested)
	w.i64(sim.meals_served)
	w.i64(sim.meals_skipped)
	w.i64(sim.harvests_completed)
	w.i64(sim.field_cycles_completed)
	w.i64(sim.births)
	w.i64(sim.deaths)
	w.i64(sim.partnerships_formed)
	w.i64(sim.households_dissolved)
	w.i64(sim.lifecycle_ticks)
	var field_ids: PackedInt32Array = sim.world.field_ids()
	w.u32(field_ids.size())
	for field_id in field_ids:
		var field: Building = sim.world.building_by_id(field_id)
		w.i32(field_id)
		w.i32(field.field_stage if field != null else 0)
		w.i64(field.field_work_s if field != null else 0)
		w.i64(field.field_growth_end if field != null else 0)
		w.i32(field.field_growth_gen if field != null else 0)
	w.i64(sim.year_index)
	w.i64(sim.year_start_grain)
	w.i64(sim.year_grain_produced)
	w.i64(sim.year_meals_served)
	w.i64(sim.year_meals_skipped)
	w.i64(sim.year_harvests)
	w.i64(sim.last_year_index)
	w.i64(sim.last_year_start_grain)
	w.i64(sim.last_year_grain_produced)
	w.i64(sim.last_year_meals_served)
	w.i64(sim.last_year_meals_skipped)
	w.i64(sim.last_year_harvests)
	w.i64(sim.last_year_end_grain)

	var routes: RouteStore = sim.routes
	w.u32(routes.routes.size())
	for route in routes.routes:
		var points: PackedVector2Array = route
		w.u32(points.size())
		for p in points:
			w.f64(p.x)
			w.f64(p.y)

	_write_logs(w, sim.logs)
	var chronicle: ChronicleStore = sim.chronicle
	if chronicle == null:
		chronicle = ChronicleStore.new(config)
	chronicle.write_to(w)
	var meta: Dictionary = Replay.replay_meta(sim)
	w.i32(int(meta["version"]))
	w.i64(int(meta["seed"]))
	w.i64(int(meta["config_hash"]))
	w.i64(int(meta["snapshot_time"]))


static func _write_store(w: ByteWriter, store: AgentStore) -> void:
	w.u32(store.count)
	w.i64(store.next_id)
	_write_i32_array(w, store.ids, store.count)
	_write_u8_array(w, store.alive, store.count)
	_write_i32_array(w, store.age_years, store.count)
	_write_u8_array(w, store.role, store.count)
	_write_i32_array(w, store.household_id, store.count)
	_write_i32_array(w, store.home_id, store.count)
	_write_i32_array(w, store.job_id, store.count)
	_write_u8_array(w, store.job_kind, store.count)
	_write_u8_array(w, store.activity, store.count)
	_write_u8_array(w, store.intent, store.count)
	_write_u8_array(w, store.action_source, store.count)
	_write_i32_array(w, store.target_building_id, store.count)
	_write_f64_array(w, store.target_x, store.count)
	_write_f64_array(w, store.target_y, store.count)
	_write_f64_array(w, store.pos_x, store.count)
	_write_f64_array(w, store.pos_y, store.count)
	_write_i64_array(w, store.travel_depart, store.count)
	_write_i64_array(w, store.travel_arrive, store.count)
	_write_f64_array(w, store.travel_start_x, store.count)
	_write_f64_array(w, store.travel_start_y, store.count)
	_write_f64_array(w, store.travel_end_x, store.count)
	_write_f64_array(w, store.travel_end_y, store.count)
	_write_i32_array(w, store.route_id, store.count)
	_write_i32_array(w, store.wake_gen, store.count)
	_write_i64_array(w, store.defer_until, store.count)
	_write_i64_array(w, store.next_event, store.count)
	_write_i64_array(w, store.need_time, store.count)
	_write_f64_array(w, store.hunger, store.count)
	_write_f64_array(w, store.energy, store.count)
	_write_f64_array(w, store.social, store.count)
	_write_f64_array(w, store.hygiene, store.count)
	_write_f64_array(w, store.fun, store.count)
	_write_f64_array(w, store.health, store.count)
	_write_i64_array(w, store.action_end, store.count)
	_write_i64_array(w, store.work_start, store.count)
	_write_i64_array(w, store.work_end, store.count)
	_write_i64_array(w, store.work_accum, store.count)
	_write_i64_array(w, store.meal_retry, store.count)
	_write_i32_array(w, store.shortage_logged_day, store.count)
	_write_u8_array(w, store.sex, store.count)
	_write_i32_array(w, store.birth_day, store.count)
	_write_u8_array(w, store.pregnant, store.count)
	_write_i64_array(w, store.pregnancy_due, store.count)
	_write_i32_array(w, store.pregnancy_father_id, store.count)
	_write_i32_array(w, store.death_day, store.count)
	_write_u8_array(w, store.death_cause, store.count)


static func _read_store(r: ByteReader) -> AgentStore:
	var store: AgentStore = AgentStore.new()
	store.count = r.u32()
	store.next_id = r.i64()
	store.ids = _read_i32_array(r)
	store.alive = _read_u8_array(r)
	store.age_years = _read_i32_array(r)
	store.role = _read_u8_array(r)
	store.household_id = _read_i32_array(r)
	store.home_id = _read_i32_array(r)
	store.job_id = _read_i32_array(r)
	store.job_kind = _read_u8_array(r)
	store.activity = _read_u8_array(r)
	store.intent = _read_u8_array(r)
	store.action_source = _read_u8_array(r)
	store.target_building_id = _read_i32_array(r)
	store.target_x = _read_f64_array(r)
	store.target_y = _read_f64_array(r)
	store.pos_x = _read_f64_array(r)
	store.pos_y = _read_f64_array(r)
	store.travel_depart = _read_i64_array(r)
	store.travel_arrive = _read_i64_array(r)
	store.travel_start_x = _read_f64_array(r)
	store.travel_start_y = _read_f64_array(r)
	store.travel_end_x = _read_f64_array(r)
	store.travel_end_y = _read_f64_array(r)
	store.route_id = _read_i32_array(r)
	store.wake_gen = _read_i32_array(r)
	store.defer_until = _read_i64_array(r)
	store.next_event = _read_i64_array(r)
	store.need_time = _read_i64_array(r)
	store.hunger = _read_f64_array(r)
	store.energy = _read_f64_array(r)
	store.social = _read_f64_array(r)
	store.hygiene = _read_f64_array(r)
	store.fun = _read_f64_array(r)
	store.health = _read_f64_array(r)
	store.action_end = _read_i64_array(r)
	store.work_start = _read_i64_array(r)
	store.work_end = _read_i64_array(r)
	store.work_accum = _read_i64_array(r)
	store.meal_retry = _read_i64_array(r)
	store.shortage_logged_day = _read_i32_array(r)
	store.sex = _read_u8_array(r)
	store.birth_day = _read_i32_array(r)
	store.pregnant = _read_u8_array(r)
	store.pregnancy_due = _read_i64_array(r)
	store.pregnancy_father_id = _read_i32_array(r)
	store.death_day = _read_i32_array(r)
	store.death_cause = _read_u8_array(r)
	if store.ids.size() != store.count:
		r.ok = false
		r.error = "store_count_mismatch"
		return store
	var max_id: int = -1
	for agent_id in store.ids:
		if agent_id > max_id:
			max_id = agent_id
	store.row_of_id.resize(max_id + 1)
	for i in store.row_of_id.size():
		store.row_of_id[i] = -1
	for row in store.count:
		store.row_of_id[store.ids[row]] = row
	return store


static func _write_records(w: ByteWriter, records: Array) -> void:
	w.u32(records.size())
	for record in records:
		var rec: AgentRecord = record
		w.i32(rec.id)
		w.string_value(rec.name)
		w.i32(rec.sex)
		w.i32(rec.age_years)
		w.i32(rec.role)
		w.i32(rec.household_id)
		w.i32(rec.home_building_id)
		w.i32(rec.job_id)
		w.i32(rec.job_kind)
		w.i32(rec.birth_day)
		w.i32(rec.death_day)
		w.i32(rec.death_cause)


static func _read_records(r: ByteReader) -> Array:
	var count: int = r.u32()
	var out: Array = []
	for i in count:
		var rec: AgentRecord = AgentRecord.new()
		rec.id = r.i32()
		rec.name = r.string_value()
		rec.sex = r.i32()
		rec.age_years = r.i32()
		rec.role = r.i32()
		rec.household_id = r.i32()
		rec.home_building_id = r.i32()
		rec.job_id = r.i32()
		rec.job_kind = r.i32()
		rec.birth_day = r.i32()
		rec.death_day = r.i32()
		rec.death_cause = r.i32()
		out.append(rec)
	return out


static func _write_households(w: ByteWriter, households: Array) -> void:
	w.u32(households.size())
	for household in households:
		var h: HouseholdRecord = household
		w.i32(h.id)
		w.i32(h.home_building_id)
		w.u32(h.member_ids.size())
		for member in h.member_ids:
			w.i32(member)
		w.i32(h.dissolved)
		w.i32(h.dissolved_day)
		w.i32(h.dissolved_reason)
		w.u32(h.archived_member_ids.size())
		for member in h.archived_member_ids:
			w.i32(member)


static func _read_households(r: ByteReader) -> Array:
	var count: int = r.u32()
	var out: Array = []
	for i in count:
		var h: HouseholdRecord = HouseholdRecord.new()
		h.id = r.i32()
		h.home_building_id = r.i32()
		var n: int = r.u32()
		h.member_ids.resize(n)
		for j in n:
			h.member_ids[j] = r.i32()
		h.dissolved = r.i32()
		h.dissolved_day = r.i32()
		h.dissolved_reason = r.i32()
		var an: int = r.u32()
		h.archived_member_ids.resize(an)
		for j in an:
			h.archived_member_ids[j] = r.i32()
		out.append(h)
	return out


static func _write_relationships(w: ByteWriter, relationships: Array) -> void:
	w.u32(relationships.size())
	for relationship in relationships:
		var rel: RelationshipRecord = relationship
		w.i32(rel.id)
		w.i32(rel.type)
		w.i32(rel.a_agent_id)
		w.i32(rel.b_agent_id)
		w.i32(rel.strength)
		w.i32(rel.since_day)


static func _read_relationships(r: ByteReader) -> Array:
	var count: int = r.u32()
	var out: Array = []
	for i in count:
		var rel: RelationshipRecord = RelationshipRecord.new()
		rel.id = r.i32()
		rel.type = r.i32()
		rel.a_agent_id = r.i32()
		rel.b_agent_id = r.i32()
		rel.strength = r.i32()
		rel.since_day = r.i32()
		out.append(rel)
	return out


static func _write_logs(w: ByteWriter, logs: SimLogs) -> void:
	w.i64(logs.next_event_id)
	# G2: Debug-Log ist bounded (SimLogs.DEBUG_CAPACITY), aber weiterhin im Save,
	# weil G1b-Event-Hash-Tests ihn als Historie nutzen. G3-Auflage: Debug-Log
	# vom Save entkoppeln und Tests auf state_hash/chronicle_hash umstellen.
	w.u32(logs.debug_events.size())
	for event in logs.debug_events:
		_write_event(w, event)
	w.u32(logs.chronicle_events.size())
	for event in logs.chronicle_events:
		_write_event(w, event)


static func _read_logs(r: ByteReader, sim: Simulation) -> void:
	var next_id: int = r.i64()
	var debug_count: int = r.u32()
	var debug_events: Array = []
	for i in debug_count:
		debug_events.append(_read_event(r))
	var chronicle_count: int = r.u32()
	var chronicle_events: Array = []
	for i in chronicle_count:
		chronicle_events.append(_read_event(r))
	sim.logs = SimLogs.new()
	sim.logs.restore(debug_events, chronicle_events, next_id)


static func _write_event(w: ByteWriter, event: SimEvent) -> void:
	w.i64(event.id)
	w.i64(event.time)
	w.i32(event.type)
	w.i32(event.importance)
	w.i32(event.agent_id)
	w.string_value(event.template_key)
	w.string_value(event.text)
	w.i64(event.data)


static func _read_event(r: ByteReader) -> SimEvent:
	var event: SimEvent = SimEvent.new()
	event.id = r.i64()
	event.time = r.i64()
	event.type = r.i32()
	event.importance = r.i32()
	event.agent_id = r.i32()
	event.template_key = r.string_value()
	event.text = r.string_value()
	event.data = r.i64()
	return event


static func _read_scheduler(r: ByteReader) -> EventScheduler:
	var scheduler: EventScheduler = EventScheduler.new()
	var size: int = r.u32()
	var next_seq: int = r.i64()
	var times: PackedInt64Array = _read_i64_array(r)
	var seqs: PackedInt64Array = _read_i64_array(r)
	var kinds: PackedInt32Array = _read_i32_array(r)
	var payloads: PackedInt64Array = _read_i64_array(r)
	scheduler.restore_arrays(times, seqs, kinds, payloads, size, next_seq)
	return scheduler


static func _read_routes(r: ByteReader) -> RouteStore:
	var routes: RouteStore = RouteStore.new()
	var count: int = r.u32()
	for i in count:
		var n: int = r.u32()
		var points: PackedVector2Array = PackedVector2Array()
		for j in n:
			points.append(Vector2(r.f64(), r.f64()))
		routes.routes.append(points)
	return routes


static func _read_config(r: ByteReader) -> SimConfig:
	var config: SimConfig = SimConfig.new()
	config.seed = r.i64()
	config.start_time = r.i64()
	config.profile = r.i32()
	config.world_size = r.i32()
	config.target_agents = r.i32()
	config.target_households = r.i32()
	config.path_cache_capacity = r.i32()
	config.path_recalc_budget = r.i32()
	config.path_lookup_budget = r.i32()
	config.path_frame_ticks = r.i32()
	config.map_version = r.i32()
	config.start_hunger = r.f64()
	config.start_energy = r.f64()
	config.start_social = r.f64()
	config.start_hygiene = r.f64()
	config.start_fun = r.f64()
	config.start_health = r.f64()
	config.hunger_per_day = r.f64()
	config.energy_per_16h_awake = r.f64()
	config.energy_per_8h_sleep = r.f64()
	config.social_per_day = r.f64()
	config.hygiene_per_day = r.f64()
	config.fun_per_day = r.f64()
	config.hunger_threshold = r.f64()
	config.energy_threshold = r.f64()
	config.social_threshold = r.f64()
	config.hygiene_threshold = r.f64()
	config.fun_threshold = r.f64()
	config.meal_hunger_reduction = r.f64()
	config.social_gain = r.f64()
	config.wash_gain = r.f64()
	config.fun_gain = r.f64()
	config.social_fun_gain = r.f64()
	config.health_bad_per_day = r.f64()
	config.health_recovery_per_day = r.f64()
	config.health_old_per_year = r.f64()
	config.walk_speed = r.f64()
	config.start_grain = r.i32()
	config.field_plow_work_s = r.i64()
	config.field_sow_work_s = r.i64()
	config.field_harvest_work_s = r.i64()
	config.field_grow_s = r.i64()
	config.field_harvest_yield = r.i64()
	config.health_critical_threshold = r.f64()
	config.health_critical_monthly_chance = r.f64()
	config.health_multiplier_curve = r.f64()
	config.lifecycle_first_roll_day = r.i64()
	config.lifecycle_roll_interval_days = r.i64()
	config.lifecycle_rolls_per_year = r.i64()
	config.mortality_age_0_4 = r.f64()
	config.mortality_age_5_14 = r.f64()
	config.mortality_age_15_29 = r.f64()
	config.mortality_age_30_39 = r.f64()
	config.mortality_age_40_49 = r.f64()
	config.mortality_age_50_64 = r.f64()
	config.mortality_age_65_79 = r.f64()
	config.mortality_age_80_plus = r.f64()
	config.pair_min_age = r.i64()
	config.pair_max_age = r.i64()
	config.fertile_female_min = r.i64()
	config.fertile_female_max = r.i64()
	config.fertile_male_min = r.i64()
	config.fertile_male_max = r.i64()
	config.monthly_conception_chance = r.f64()
	config.pregnancy_ticks = r.i64()
	config.birth_death_chance = r.f64()
	config.chronicle_recent_days = r.i64()
	config.chronicle_recent_max_events = r.i64()
	config.chronicle_summary_days = r.i64()
	config.chronicle_summary_max = r.i64()
	config.chronicle_historic_max = r.i64()
	config.chronicle_story_max_per_day = r.i64()
	config.chronicle_alert_max_per_day = r.i64()
	return config


static func _write_i32_array(w: ByteWriter, arr: PackedInt32Array, count: int) -> void:
	w.u32(count)
	for i in count:
		w.i32(arr[i])


static func _write_u8_array(w: ByteWriter, arr: PackedByteArray, count: int) -> void:
	w.u32(count)
	for i in count:
		w.u8(arr[i])


static func _write_i64_array(w: ByteWriter, arr: PackedInt64Array, count: int) -> void:
	w.u32(count)
	for i in count:
		w.i64(arr[i])


static func _write_f64_array(w: ByteWriter, arr: PackedFloat64Array, count: int) -> void:
	w.u32(count)
	for i in count:
		w.f64(arr[i])


static func _read_i32_array(r: ByteReader) -> PackedInt32Array:
	var n: int = r.u32()
	if n < 0 or n > MAX_ARRAY:
		r.ok = false
		r.error = "bad_array_length"
		return PackedInt32Array()
	var arr: PackedInt32Array = PackedInt32Array()
	arr.resize(n)
	for i in n:
		arr[i] = r.i32()
	return arr


static func _read_u8_array(r: ByteReader) -> PackedByteArray:
	var n: int = r.u32()
	if n < 0 or n > MAX_ARRAY:
		r.ok = false
		r.error = "bad_array_length"
		return PackedByteArray()
	var arr: PackedByteArray = PackedByteArray()
	arr.resize(n)
	for i in n:
		arr[i] = r.u8()
	return arr


static func _read_i64_array(r: ByteReader) -> PackedInt64Array:
	var n: int = r.u32()
	if n < 0 or n > MAX_ARRAY:
		r.ok = false
		r.error = "bad_array_length"
		return PackedInt64Array()
	var arr: PackedInt64Array = PackedInt64Array()
	arr.resize(n)
	for i in n:
		arr[i] = r.i64()
	return arr


static func _read_f64_array(r: ByteReader) -> PackedFloat64Array:
	var n: int = r.u32()
	if n < 0 or n > MAX_ARRAY:
		r.ok = false
		r.error = "bad_array_length"
		return PackedFloat64Array()
	var arr: PackedFloat64Array = PackedFloat64Array()
	arr.resize(n)
	for i in n:
		arr[i] = r.f64()
	return arr
