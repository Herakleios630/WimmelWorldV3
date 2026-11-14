class_name BSave
extends RefCounted

## Binary save for the B spike (schema 1, not a final format). Stores the
## authoritative B state: clock, scheduler, persistent records, cohort
## aggregates, key-event log, tier selection progress and counters.
## Derived indexes (row_of_id, cohort_rows) are rebuilt on load.

const MAGIC: int = 0x42335350
const SCHEMA_VERSION: int = 1
const HEADER_SIZE: int = 24


static func save_simulation(sim: BSim, path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var w: ByteWriter = ByteWriter.new()
	_encode(sim, w)
	var payload: PackedByteArray = w.buf
	var out: ByteWriter = ByteWriter.new()
	out.u32(MAGIC)
	out.u32(SCHEMA_VERSION)
	out.u64(sim.config.config_hash())
	out.u64(payload.size())
	out.raw(payload)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "open_write_failed", "path": path}
	file.store_buffer(out.buf)
	file.close()
	return {
		"ok": true,
		"path": path,
		"bytes": out.size(),
		"save_ms": float(Time.get_ticks_usec() - t0) / 1000.0,
		"schema": SCHEMA_VERSION,
		"config_hash": sim.config.config_hash(),
	}


static func load_simulation(path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {"ok": false, "error": "read_failed_or_empty", "path": path}
	var result: Dictionary = decode_bytes(bytes)
	if result.get("ok", false):
		result["load_ms"] = float(Time.get_ticks_usec() - t0) / 1000.0
		result["path"] = path
		result["bytes"] = bytes.size()
	return result


static func decode_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_SIZE:
		return {"ok": false, "error": "file_too_short"}
	var r: ByteReader = ByteReader.new(bytes)
	var magic: int = r.u32()
	if magic != MAGIC:
		return {"ok": false, "error": "bad_magic", "magic": magic}
	var schema: int = r.u32()
	if schema != SCHEMA_VERSION:
		return {"ok": false, "error": "unsupported_schema", "schema": schema}
	var config_hash: int = r.u64()
	var payload_size: int = r.u64()
	if payload_size < 0 or HEADER_SIZE + payload_size > bytes.size():
		return {"ok": false, "error": "bad_payload_size"}
	var payload: PackedByteArray = bytes.slice(HEADER_SIZE, HEADER_SIZE + payload_size)
	var p: ByteReader = ByteReader.new(payload)
	var config: BConfig = _read_config(p)
	if not p.ok:
		return {"ok": false, "error": p.error}
	if config.config_hash() != config_hash:
		return {"ok": false, "error": "config_hash_mismatch"}
	var sim: BSim = BSim.new()
	sim.config = config
	sim.clock = SimClock.new(p.i64())
	sim.scheduler = _read_scheduler(p)
	sim.records = _read_records(p)
	sim.records.gen_seed = config.seed
	sim.key_log = _read_key_log(p)
	sim.metrics = BMetrics.new()
	sim.batcher = EventBatcher.new()
	sim.records.rebuild_index()
	sim.detail = BDetail.new()
	sim.detail.setup(config, sim.records, sim.scheduler)
	sim.detail.wake_count = p.i32()
	sim.detail.routine_events = p.i32()
	sim.detail.travel_starts = p.i32()
	sim.detail.work_starts = p.i32()
	sim.detail.sleep_starts = p.i32()
	sim.background = BBackground.new()
	sim.background.setup(config, sim.records, sim.key_log, sim.scheduler, sim.detail)
	sim.background.batch_count = p.i32()
	sim.background.daily_batches = p.i32()
	sim.background.weekly_batches = p.i32()
	sim.background.death_events = p.i32()
	sim.background.birth_events = p.i32()
	sim.background.marriage_events = p.i32()
	sim.background.job_change_events = p.i32()
	sim.tier_selector = BTierSelector.new()
	sim.tier_selector.setup(config, sim.records, sim.key_log, sim.detail)
	sim.tier_selector.active = p.u8() != 0
	sim.tier_selector.active_epoch = p.i32()
	sim.tier_selector.cursor = p.i32()
	sim.tier_selector.target_count = p.i32()
	sim.tier_selector.last_commit_epoch = p.i32()
	sim.tier_selector.heap_size = p.i32()
	sim.tier_selector.heap_keys = _read_i64(p)
	sim.tier_selector.detail_rows = _read_i32(p)
	sim.tier_selector.detail_set_hash = p.i64()
	sim.tier_selector.promotions = p.i32()
	sim.tier_selector.demotions = p.i32()
	sim.tier_selector.switch_count = p.i32()
	sim.tier_selector.selection_rows = p.i32()
	sim._start_time = config.start_time
	if not p.ok:
		return {"ok": false, "error": p.error}
	if p.remaining() != 0:
		return {"ok": false, "error": "trailing_bytes", "remaining": p.remaining()}
	return {
		"ok": true,
		"sim": sim,
		"schema": schema,
		"config_hash": config_hash,
	}


static func _encode(sim: BSim, w: ByteWriter) -> void:
	var c: BConfig = sim.config
	w.i64(c.seed)
	w.i64(c.start_time)
	w.i32(c.population)
	w.i32(c.settlement_count)
	w.i32(c.cohorts_per_settlement)
	w.i32(c.detail_target)
	w.i32(c.speed)
	w.i32(c.selection_cadence_days)
	w.i32(c.selection_events_per_day)
	w.i32(c.selection_rotation_days)
	w.i32(c.key_priority_days)
	w.i32(c.background_cadence_days)
	w.i32(c.weekly_cadence_days)
	w.f64(c.birth_rate_per_female_day)
	w.f64(c.marriage_rate_per_eligible_week)
	w.f64(c.job_change_rate_per_worker_week)
	w.f64(c.hunger_per_day)
	w.f64(c.energy_per_day)
	w.f64(c.social_per_day)
	w.f64(c.hygiene_per_day)
	w.f64(c.fun_per_day)
	w.f64(c.hunger_threshold)
	w.f64(c.energy_threshold)
	w.f64(c.social_threshold)
	w.f64(c.hygiene_threshold)
	w.f64(c.fun_threshold)
	w.f64(c.health_decay_adult_per_day)
	w.f64(c.health_decay_old_per_day)
	_write_f64(w, c.mortality)
	w.i32(c.selection_salt)
	w.i32(c.background_salt)
	w.f64(c.detail_speed_tiles_per_s)

	w.i64(sim.clock.now)
	_write_scheduler(w, sim.scheduler)
	_write_records(w, sim.records)
	_write_key_log(w, sim.key_log)

	w.i32(sim.detail.wake_count)
	w.i32(sim.detail.routine_events)
	w.i32(sim.detail.travel_starts)
	w.i32(sim.detail.work_starts)
	w.i32(sim.detail.sleep_starts)

	w.i32(sim.background.batch_count)
	w.i32(sim.background.daily_batches)
	w.i32(sim.background.weekly_batches)
	w.i32(sim.background.death_events)
	w.i32(sim.background.birth_events)
	w.i32(sim.background.marriage_events)
	w.i32(sim.background.job_change_events)

	w.u8(1 if sim.tier_selector.active else 0)
	w.i32(sim.tier_selector.active_epoch)
	w.i32(sim.tier_selector.cursor)
	w.i32(sim.tier_selector.target_count)
	w.i32(sim.tier_selector.last_commit_epoch)
	w.i32(sim.tier_selector.heap_size)
	_write_i64(w, sim.tier_selector.heap_keys)
	_write_i32(w, sim.tier_selector.detail_rows)
	w.i64(sim.tier_selector.detail_set_hash)
	w.i32(sim.tier_selector.promotions)
	w.i32(sim.tier_selector.demotions)
	w.i32(sim.tier_selector.switch_count)
	w.i32(sim.tier_selector.selection_rows)


static func _write_records(w: ByteWriter, r: BRecords) -> void:
	w.i32(r.count)
	w.i32(r.next_id)
	_write_i32(w, r.ids)
	_write_u8(w, r.alive)
	_write_u8(w, r.sex)
	_write_i32(w, r.settlement_id)
	_write_i32(w, r.household_id)
	_write_i32(w, r.home_id)
	_write_i32(w, r.job_id)
	_write_u8(w, r.job_kind)
	_write_u8(w, r.role)
	_write_i32(w, r.cohort_id)
	_write_i32(w, r.birth_day)
	_write_i32(w, r.death_day)
	_write_f32(w, r.health)
	_write_i32(w, r.partner_id)
	_write_i32(w, r.mother_id)
	_write_i32(w, r.father_id)
	_write_i32(w, r.need_time)
	_write_f32(w, r.hunger)
	_write_f32(w, r.energy)
	_write_f32(w, r.social)
	_write_f32(w, r.hygiene)
	_write_f32(w, r.fun)
	_write_u8(w, r.activity)
	_write_f32(w, r.pos_x)
	_write_f32(w, r.pos_y)
	_write_i32(w, r.travel_depart)
	_write_i32(w, r.travel_arrive)
	_write_f32(w, r.travel_start_x)
	_write_f32(w, r.travel_start_y)
	_write_f32(w, r.travel_end_x)
	_write_f32(w, r.travel_end_y)
	_write_i64(w, r.next_event)
	_write_i32(w, r.wake_gen)
	_write_u8(w, r.tier)
	_write_i32(w, r.last_job_change_day)
	_write_i32(w, r.last_key_day)
	_write_i32(w, r.key_event_count)
	_write_i32(w, r.key_event_hash)
	_write_f32(w, r.settlement_center_x)
	_write_f32(w, r.settlement_center_y)
	_write_i32(w, r.settlement_population)
	_write_i32(w, r.settlement_last_key_day)
	_write_i32(w, r.settlement_last_bg_day)
	_write_i32(w, r.settlement_batches)
	_write_i32(w, r.cohort_counts)
	_write_f32(w, r.cohort_mean_hunger)
	_write_f32(w, r.cohort_mean_energy)
	_write_f32(w, r.cohort_mean_social)
	_write_f32(w, r.cohort_mean_hygiene)
	_write_f32(w, r.cohort_mean_fun)
	_write_f32(w, r.cohort_mean_health)
	_write_f32(w, r.cohort_mean_age)


static func _read_records(p: ByteReader) -> BRecords:
	var r: BRecords = BRecords.new()
	r.count = p.i32()
	r.next_id = p.i32()
	r.ids = _read_i32(p)
	r.alive = _read_u8(p)
	r.sex = _read_u8(p)
	r.settlement_id = _read_i32(p)
	r.household_id = _read_i32(p)
	r.home_id = _read_i32(p)
	r.job_id = _read_i32(p)
	r.job_kind = _read_u8(p)
	r.role = _read_u8(p)
	r.cohort_id = _read_i32(p)
	r.birth_day = _read_i32(p)
	r.death_day = _read_i32(p)
	r.health = _read_f32(p)
	r.partner_id = _read_i32(p)
	r.mother_id = _read_i32(p)
	r.father_id = _read_i32(p)
	r.need_time = _read_i32(p)
	r.hunger = _read_f32(p)
	r.energy = _read_f32(p)
	r.social = _read_f32(p)
	r.hygiene = _read_f32(p)
	r.fun = _read_f32(p)
	r.activity = _read_u8(p)
	r.pos_x = _read_f32(p)
	r.pos_y = _read_f32(p)
	r.travel_depart = _read_i32(p)
	r.travel_arrive = _read_i32(p)
	r.travel_start_x = _read_f32(p)
	r.travel_start_y = _read_f32(p)
	r.travel_end_x = _read_f32(p)
	r.travel_end_y = _read_f32(p)
	r.next_event = _read_i64(p)
	r.wake_gen = _read_i32(p)
	r.tier = _read_u8(p)
	r.last_job_change_day = _read_i32(p)
	r.last_key_day = _read_i32(p)
	r.key_event_count = _read_i32(p)
	r.key_event_hash = _read_i32(p)
	r.settlement_center_x = _read_f32(p)
	r.settlement_center_y = _read_f32(p)
	r.settlement_population = _read_i32(p)
	r.settlement_last_key_day = _read_i32(p)
	r.settlement_last_bg_day = _read_i32(p)
	r.settlement_batches = _read_i32(p)
	r.cohort_counts = _read_i32(p)
	r.cohort_mean_hunger = _read_f32(p)
	r.cohort_mean_energy = _read_f32(p)
	r.cohort_mean_social = _read_f32(p)
	r.cohort_mean_hygiene = _read_f32(p)
	r.cohort_mean_fun = _read_f32(p)
	r.cohort_mean_health = _read_f32(p)
	r.cohort_mean_age = _read_f32(p)
	r.settlement_count = r.settlement_center_x.size()
	r.cohort_total = r.cohort_counts.size()
	return r


static func _write_scheduler(w: ByteWriter, s: EventScheduler) -> void:
	w.u32(s.size())
	w.i64(s.next_seq())
	_write_i64(w, s.times)
	_write_i64(w, s.seqs)
	_write_i32(w, s.kinds)
	_write_i64(w, s.payloads)


static func _read_scheduler(p: ByteReader) -> EventScheduler:
	var s: EventScheduler = EventScheduler.new()
	var size: int = p.u32()
	var next_seq: int = p.i64()
	var times: PackedInt64Array = _read_i64(p)
	var seqs: PackedInt64Array = _read_i64(p)
	var kinds: PackedInt32Array = _read_i32(p)
	var payloads: PackedInt64Array = _read_i64(p)
	s.restore_arrays(times, seqs, kinds, payloads, size, next_seq)
	return s


static func _write_key_log(w: ByteWriter, k: BKeyLog) -> void:
	w.i64(k.next_id)
	_write_i64(w, k.ids)
	_write_i64(w, k.times)
	_write_i32(w, k.days)
	_write_u8(w, k.types)
	_write_i32(w, k.a_ids)
	_write_i32(w, k.b_ids)
	_write_i32(w, k.settlement_ids)
	_write_i64(w, k.data)
	_write_i32(w, k.counts)


static func _read_key_log(p: ByteReader) -> BKeyLog:
	var k: BKeyLog = BKeyLog.new()
	k.next_id = p.i64()
	k.ids = _read_i64(p)
	k.times = _read_i64(p)
	k.days = _read_i32(p)
	k.types = _read_u8(p)
	k.a_ids = _read_i32(p)
	k.b_ids = _read_i32(p)
	k.settlement_ids = _read_i32(p)
	k.data = _read_i64(p)
	k.counts = _read_i32(p)
	return k


static func _read_config(p: ByteReader) -> BConfig:
	var c: BConfig = BConfig.new()
	c.seed = p.i64()
	c.start_time = p.i64()
	c.population = p.i32()
	c.settlement_count = p.i32()
	c.cohorts_per_settlement = p.i32()
	c.detail_target = p.i32()
	c.speed = p.i32()
	c.selection_cadence_days = p.i32()
	c.selection_events_per_day = p.i32()
	c.selection_rotation_days = p.i32()
	c.key_priority_days = p.i32()
	c.background_cadence_days = p.i32()
	c.weekly_cadence_days = p.i32()
	c.birth_rate_per_female_day = p.f64()
	c.marriage_rate_per_eligible_week = p.f64()
	c.job_change_rate_per_worker_week = p.f64()
	c.hunger_per_day = p.f64()
	c.energy_per_day = p.f64()
	c.social_per_day = p.f64()
	c.hygiene_per_day = p.f64()
	c.fun_per_day = p.f64()
	c.hunger_threshold = p.f64()
	c.energy_threshold = p.f64()
	c.social_threshold = p.f64()
	c.hygiene_threshold = p.f64()
	c.fun_threshold = p.f64()
	c.health_decay_adult_per_day = p.f64()
	c.health_decay_old_per_day = p.f64()
	c.mortality = _read_f64(p)
	c.selection_salt = p.i32()
	c.background_salt = p.i32()
	c.detail_speed_tiles_per_s = p.f64()
	return c


static func _write_u8(w: ByteWriter, a: PackedByteArray) -> void:
	w.u32(a.size())
	w.raw(a)


static func _write_i32(w: ByteWriter, a: PackedInt32Array) -> void:
	w.u32(a.size())
	w.raw(a.to_byte_array())


static func _write_i64(w: ByteWriter, a: PackedInt64Array) -> void:
	w.u32(a.size())
	w.raw(a.to_byte_array())


static func _write_f32(w: ByteWriter, a: PackedFloat32Array) -> void:
	w.u32(a.size())
	w.raw(a.to_byte_array())


static func _write_f64(w: ByteWriter, a: PackedFloat64Array) -> void:
	w.u32(a.size())
	w.raw(a.to_byte_array())


static func _read_raw(p: ByteReader, n: int) -> PackedByteArray:
	if n < 0 or p.pos + n > p.buf.size():
		p.ok = false
		p.error = "unexpected_eof"
		return PackedByteArray()
	var out: PackedByteArray = p.buf.slice(p.pos, p.pos + n)
	p.pos += n
	return out


static func _read_u8(p: ByteReader) -> PackedByteArray:
	var n: int = p.u32()
	return _read_raw(p, n)


static func _read_i32(p: ByteReader) -> PackedInt32Array:
	var n: int = p.u32()
	var bytes: PackedByteArray = _read_raw(p, n * 4)
	if not p.ok:
		return PackedInt32Array()
	return bytes.to_int32_array()


static func _read_i64(p: ByteReader) -> PackedInt64Array:
	var n: int = p.u32()
	var bytes: PackedByteArray = _read_raw(p, n * 8)
	if not p.ok:
		return PackedInt64Array()
	return bytes.to_int64_array()


static func _read_f32(p: ByteReader) -> PackedFloat32Array:
	var n: int = p.u32()
	var bytes: PackedByteArray = _read_raw(p, n * 4)
	if not p.ok:
		return PackedFloat32Array()
	return bytes.to_float32_array()


static func _read_f64(p: ByteReader) -> PackedFloat64Array:
	var n: int = p.u32()
	var bytes: PackedByteArray = _read_raw(p, n * 8)
	if not p.ok:
		return PackedFloat64Array()
	return bytes.to_float64_array()
