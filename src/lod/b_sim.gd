class_name BSim
extends RefCounted

## Deterministic B spike simulation: 100k persistent records, 1k/5k detail
## tier, settlement/cohort background batches, individual key events, 150x/200x.
##
## The simulation never reads camera, zoom, visibility, follow or inspector.
## View focus is stored only for the camera-independence test and is excluded
## from state_hash().

const MAX_EVENTS_PER_ADVANCE: int = 1000000

var config: BConfig
var clock: SimClock
var scheduler: EventScheduler
var batcher: EventBatcher
var records: BRecords
var key_log: BKeyLog
var tier_selector: BTierSelector
var detail: BDetail
var background: BBackground
var metrics: BMetrics

var measure_costs: bool = false
var view_focus_agent_id: int = -1
var inspector_agent_id: int = -1
var _frame_target: int = 0
var _start_time: int = 0


static func create(p_config: BConfig) -> BSim:
	var sim: BSim = BSim.new()
	sim.setup(p_config)
	return sim


func setup(p_config: BConfig) -> void:
	config = p_config
	var valid: Dictionary = config.validate()
	if not valid.get("ok", false):
		push_error("B config invalid: " + str(valid.get("error", "")))
	clock = SimClock.new(config.start_time)
	scheduler = EventScheduler.new()
	batcher = EventBatcher.new()
	records = BRecords.generate(config)
	key_log = BKeyLog.new()
	metrics = BMetrics.new()
	detail = BDetail.new()
	detail.setup(config, records, scheduler)
	background = BBackground.new()
	background.setup(config, records, key_log, scheduler, detail)
	tier_selector = BTierSelector.new()
	tier_selector.setup(config, records, key_log, detail)
	tier_selector.setup_initial(clock.now)
	_start_time = clock.now
	for sid in config.settlement_count:
		var off: int = background.initial_offset(sid)
		scheduler.push(off, BKinds.EVENT_SETTLEMENT_BATCH, sid)
	scheduler.push(BConfig.TICKS_PER_DAY, BKinds.EVENT_DAY_TICK, 1)
	_schedule_selection_day(0)


func _schedule_selection_day(day: int) -> void:
	tier_selector.start_epoch(day + 1)
	var per_day: int = config.selection_events_per_day
	var step: int = BConfig.TICKS_PER_DAY / per_day
	for k in per_day:
		scheduler.push(day * BConfig.TICKS_PER_DAY + k * step,
			BKinds.EVENT_TIER_SELECTION, day + 1)


func advance_to(target_time: int) -> int:
	if target_time < clock.now:
		return 0
	_frame_target = target_time
	var processed: int = 0
	while scheduler.size() > 0 and scheduler.peek_time() <= target_time:
		var batch_time: int = scheduler.peek_time()
		var batch_start: int = processed
		var last_seq: int = -1
		var batch_usec: int = Time.get_ticks_usec()
		while scheduler.size() > 0 and scheduler.peek_time() == batch_time:
			if not scheduler.pop():
				break
			var event_time: int = scheduler.last_time
			if event_time > clock.now:
				clock.now = event_time
			last_seq = scheduler.last_seq
			var t0: int = Time.get_ticks_usec() if measure_costs else 0
			_dispatch(scheduler.last_kind, scheduler.last_payload)
			if measure_costs:
				_attribute_cost(scheduler.last_kind, t0)
			processed += 1
			if processed > MAX_EVENTS_PER_ADVANCE:
				push_error("B event storm guard triggered at t=%d" % clock.now)
				break
		if batcher != null:
			batcher.record(batch_time, processed - batch_start, last_seq)
		if measure_costs:
			metrics.record_batch(Time.get_ticks_usec() - batch_usec, processed - batch_start)
		if processed > MAX_EVENTS_PER_ADVANCE:
			break
	clock.now = target_time
	return processed


func _dispatch(kind: int, payload: int) -> void:
	if kind == BKinds.EVENT_AGENT_WAKE:
		var row: int = payload & 0xFFFFFFFF
		var gen: int = (payload >> 32) & 0xFFFFFFFF
		detail.process_wake(row, clock.now, gen)
	elif kind == BKinds.EVENT_SETTLEMENT_BATCH:
		background.process_settlement(payload, clock.now)
	elif kind == BKinds.EVENT_DAY_TICK:
		_on_day_tick()
	elif kind == BKinds.EVENT_TIER_SELECTION:
		if payload == tier_selector.active_epoch:
			var before: int = tier_selector.cursor
			tier_selector.process_chunk(config.rows_per_selection_event())
			if measure_costs:
				metrics.selection_events += tier_selector.cursor - before


func _attribute_cost(kind: int, t0: int) -> void:
	var dt: int = Time.get_ticks_usec() - t0
	if kind == BKinds.EVENT_AGENT_WAKE:
		metrics.detail_usec += dt
		metrics.detail_events += 1
	elif kind == BKinds.EVENT_SETTLEMENT_BATCH:
		metrics.background_usec += dt
		metrics.background_batches += 1
	elif kind == BKinds.EVENT_TIER_SELECTION:
		metrics.selection_usec += dt
	elif kind == BKinds.EVENT_DAY_TICK:
		metrics.day_tick_usec += dt
		metrics.day_ticks += 1


func _on_day_tick() -> void:
	var day: int = clock.now / BConfig.TICKS_PER_DAY
	tier_selector.commit(clock.now)
	_schedule_selection_day(day)
	scheduler.push((day + 1) * BConfig.TICKS_PER_DAY, BKinds.EVENT_DAY_TICK, day + 1)


func advance_frame() -> int:
	return advance_to(clock.now + config.sim_seconds_per_frame())


func run_days(days: float, fps: int = 60) -> Dictionary:
	var frames: int = int(round(days * float(config.seconds_per_sim_day_at_speed()) * float(fps)))
	var out: int = 0
	for i in frames:
		var t0: int = Time.get_ticks_usec()
		var events: int = advance_frame()
		if measure_costs:
			metrics.record_frame(Time.get_ticks_usec() - t0, events, config.sim_seconds_per_frame())
		out += events
	return {"events": out, "frames": frames}


func count_alive() -> int:
	var n: int = 0
	for row in records.count:
		if records.alive[row] != 0:
			n += 1
	return n


func detail_count() -> int:
	return tier_selector.detail_count()


func tier_of_agent(agent_id: int) -> int:
	var row: int = records.row_for_id(agent_id)
	return records.tier[row] if row >= 0 else -1


func agent_position_at(agent_id: int, t: int) -> Vector2:
	var row: int = records.row_for_id(agent_id)
	if row < 0:
		return Vector2.ZERO
	return detail.position_at(row, t)


func set_view_focus(agent_id: int) -> void:
	view_focus_agent_id = agent_id


func set_inspector(agent_id: int) -> void:
	inspector_agent_id = agent_id


func view_focus() -> int:
	return view_focus_agent_id


func inspector() -> int:
	return inspector_agent_id


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, config.config_hash())
	h = HashUtil.mix_i64(h, clock.now)
	h = HashUtil.mix(h, scheduler.state_hash())
	h = HashUtil.mix(h, records.state_hash())
	h = HashUtil.mix(h, key_log.state_hash())
	h = HashUtil.mix(h, tier_selector.state_hash())
	h = HashUtil.mix(h, background.state_hash())
	h = HashUtil.mix(h, detail.state_hash())
	return h


func event_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, key_log.state_hash())
	h = HashUtil.mix_i64(h, detail.routine_events)
	h = HashUtil.mix_i64(h, background.death_events)
	h = HashUtil.mix_i64(h, background.birth_events)
	h = HashUtil.mix_i64(h, background.marriage_events)
	h = HashUtil.mix_i64(h, background.job_change_events)
	return h


func tier_hash() -> int:
	return tier_selector.assignment_hash()


func tier_stats() -> Dictionary:
	return {
		"detail_target": config.detail_target,
		"detail_actual": tier_selector.detail_count(),
		"promotions": tier_selector.promotions,
		"demotions": tier_selector.demotions,
		"switches": tier_selector.switch_count,
		"commits": tier_selector.commit_count,
		"active_epoch": tier_selector.active_epoch,
		"last_commit_epoch": tier_selector.last_commit_epoch,
		"selection_rows": tier_selector.selection_rows,
		"selection_us": tier_selector.selection_usec,
		"commit_us": tier_selector.commit_usec,
		"catchup_us": tier_selector.catchup_usec,
		"detail_set_hash": HashUtil.hex(tier_selector.detail_set_hash),
	}


func batch_stats() -> Dictionary:
	if batcher == null:
		return {}
	return batcher.stats()


func key_stats() -> Dictionary:
	return {
		"total": key_log.total(),
		"births": key_log.count_of(BKeyLog.TYPE_BIRTH),
		"deaths": key_log.count_of(BKeyLog.TYPE_DEATH),
		"marriages": key_log.count_of(BKeyLog.TYPE_MARRIAGE),
		"job_changes": key_log.count_of(BKeyLog.TYPE_JOB_CHANGE),
	}


func detail_stats() -> Dictionary:
	return {
		"wake_count": detail.wake_count,
		"routine_events": detail.routine_events,
		"travel_starts": detail.travel_starts,
		"work_starts": detail.work_starts,
		"sleep_starts": detail.sleep_starts,
	}


func background_stats() -> Dictionary:
	return {
		"batch_count": background.batch_count,
		"daily_batches": background.daily_batches,
		"weekly_batches": background.weekly_batches,
		"death_events": background.death_events,
		"birth_events": background.birth_events,
		"marriage_events": background.marriage_events,
		"job_change_events": background.job_change_events,
	}


func memory_estimate() -> Dictionary:
	var record_bytes: int = records.memory_bytes_estimate()
	var key_bytes: int = key_log.memory_bytes_estimate()
	var cohort_rows_bytes: int = 0
	for list in records.cohort_rows:
		cohort_rows_bytes += (list as PackedInt32Array).size() * 4
	var sched_bytes: int = scheduler.times.size() * 8 + scheduler.seqs.size() * 8 \
		+ scheduler.kinds.size() * 4 + scheduler.payloads.size() * 8
	return {
		"records_bytes": record_bytes,
		"key_log_bytes": key_bytes,
		"cohort_rows_bytes": cohort_rows_bytes,
		"scheduler_bytes": sched_bytes,
		"total_bytes": record_bytes + key_bytes + cohort_rows_bytes + sched_bytes,
		"engine_static_bytes": OS.get_static_memory_usage(),
		"engine_static_peak_bytes": OS.get_static_memory_peak_usage(),
	}


func save_to(path: String) -> Dictionary:
	return BSave.save_simulation(self, path)


static func load_from(path: String) -> Dictionary:
	return BSave.load_simulation(path)
