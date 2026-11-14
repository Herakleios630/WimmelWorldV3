class_name BDetail
extends RefCounted

## Detail-tier agent updates. Detail agents are woken by their own scheduler
## events (about 8 routine decisions per Sim day). Background agents have no
## per-frame updates. Promotion materialises needs/health from the last
## authoritative B record and schedules a wake; demotion freezes the current
## (possibly interpolated) position. No teleport and no skipped events.

var config: BConfig
var records: BRecords
var scheduler: EventScheduler

var wake_count: int = 0
var routine_events: int = 0
var travel_starts: int = 0
var work_starts: int = 0
var sleep_starts: int = 0


func setup(p_config: BConfig, p_records: BRecords, p_scheduler: EventScheduler) -> void:
	config = p_config
	records = p_records
	scheduler = p_scheduler
	wake_count = 0
	routine_events = 0
	travel_starts = 0
	work_starts = 0
	sleep_starts = 0


func on_promote(row: int, now: int) -> void:
	if row < 0 or row >= records.count or records.alive[row] == 0:
		return
	records.materialize_needs(row, now, config)
	records.activity[row] = BConfig.ACTIVITY_IDLE
	records.wake_gen[row] += 1
	records.tier[row] = 1
	var jitter: int = BHash.hash3(records.ids[row], records.wake_gen[row], config.seed) % 1800
	_schedule(row, now + jitter, records.wake_gen[row])


func on_demote(row: int, now: int) -> void:
	if row < 0 or row >= records.count:
		return
	if records.activity[row] == BConfig.ACTIVITY_TRAVEL:
		var p: Vector2 = position_at(row, now)
		records.pos_x[row] = p.x
		records.pos_y[row] = p.y
		_clear_travel(row)
	records.materialize_needs(row, now, config)
	records.activity[row] = BConfig.ACTIVITY_IDLE
	records.next_event[row] = 0
	records.wake_gen[row] += 1
	records.tier[row] = 0


func on_death(row: int, now: int) -> void:
	if row < 0 or row >= records.count:
		return
	if records.activity[row] == BConfig.ACTIVITY_TRAVEL:
		var p: Vector2 = position_at(row, now)
		records.pos_x[row] = p.x
		records.pos_y[row] = p.y
		_clear_travel(row)
	records.activity[row] = BConfig.ACTIVITY_IDLE
	records.next_event[row] = 0
	records.wake_gen[row] += 1
	records.tier[row] = 0


func process_wake(row: int, now: int, gen: int) -> bool:
	if row < 0 or row >= records.count:
		return false
	if records.wake_gen[row] != gen:
		return false
	if records.alive[row] == 0 or records.tier[row] == 0:
		return false
	wake_count += 1
	records.materialize_needs(row, now, config)
	if records.activity[row] == BConfig.ACTIVITY_TRAVEL:
		records.pos_x[row] = records.travel_end_x[row]
		records.pos_y[row] = records.travel_end_y[row]
		_clear_travel(row)
		records.activity[row] = BConfig.ACTIVITY_IDLE
	var act: int = _choose_activity(row, now)
	routine_events += 1
	if act == BConfig.ACTIVITY_TRAVEL:
		return true
	var at: int = _next_wake(row, now, act)
	_schedule(row, at, gen)
	return true


func _choose_activity(row: int, now: int) -> int:
	if records.energy[row] <= config.energy_threshold:
		records.energy[row] = clampf(records.energy[row] + 80.0, 0.0, 100.0)
		records.activity[row] = BConfig.ACTIVITY_SLEEP
		sleep_starts += 1
		return BConfig.ACTIVITY_SLEEP
	if records.hunger[row] >= config.hunger_threshold:
		records.hunger[row] = clampf(records.hunger[row] - 50.0, 0.0, 100.0)
		records.activity[row] = BConfig.ACTIVITY_EAT
		return BConfig.ACTIVITY_EAT
	if records.hygiene[row] <= config.hygiene_threshold:
		records.hygiene[row] = clampf(records.hygiene[row] + 50.0, 0.0, 100.0)
		records.activity[row] = BConfig.ACTIVITY_HYGIENE
		return BConfig.ACTIVITY_HYGIENE
	if records.social[row] <= config.social_threshold:
		records.social[row] = clampf(records.social[row] + 30.0, 0.0, 100.0)
		records.fun[row] = clampf(records.fun[row] + 10.0, 0.0, 100.0)
		records.activity[row] = BConfig.ACTIVITY_SOCIAL
		return BConfig.ACTIVITY_SOCIAL
	if records.fun[row] <= config.fun_threshold:
		records.fun[row] = clampf(records.fun[row] + 30.0, 0.0, 100.0)
		records.activity[row] = BConfig.ACTIVITY_LEISURE
		return BConfig.ACTIVITY_LEISURE
	var hour: int = (now % BConfig.TICKS_PER_DAY) / 3600
	var age: int = records.age_years_now(row, now)
	var pos: Vector2 = Vector2(records.pos_x[row], records.pos_y[row])
	var home: Vector2 = records.home_point(records.home_id[row])
	if hour < 8 or hour >= 17:
		if pos.distance_to(home) > 2.0:
			_start_travel(row, home, now, records.wake_gen[row])
			return BConfig.ACTIVITY_TRAVEL
		records.activity[row] = BConfig.ACTIVITY_IDLE
		return BConfig.ACTIVITY_IDLE
	var job: int = records.job_id[row]
	if age >= 18 and age <= 74 and job > 0:
		var work: Vector2 = records.work_point(job)
		if pos.distance_to(work) > 2.0:
			_start_travel(row, work, now, records.wake_gen[row])
			return BConfig.ACTIVITY_TRAVEL
		records.activity[row] = BConfig.ACTIVITY_WORK
		work_starts += 1
		return BConfig.ACTIVITY_WORK
	records.activity[row] = BConfig.ACTIVITY_IDLE
	return BConfig.ACTIVITY_IDLE


func _next_wake(row: int, now: int, act: int) -> int:
	var duration: int = 0
	if act == BConfig.ACTIVITY_SLEEP:
		duration = 8 * 3600
	elif act == BConfig.ACTIVITY_EAT:
		duration = 1800
	elif act == BConfig.ACTIVITY_HYGIENE:
		duration = 900
	elif act == BConfig.ACTIVITY_SOCIAL:
		duration = 3600
	elif act == BConfig.ACTIVITY_LEISURE:
		duration = 3600
	elif act == BConfig.ACTIVITY_WORK:
		duration = 2 * 3600
	if duration > 0:
		var jitter: int = BHash.hash4(records.ids[row], records.wake_gen[row], now, config.seed) % 300
		return now + duration + jitter
	var best: int = 3 * 3600
	var dt: int = 0
	if records.hunger[row] < config.hunger_threshold:
		dt = int((config.hunger_threshold - records.hunger[row])
			/ config.hunger_per_day * float(BConfig.TICKS_PER_DAY))
		if dt > 0 and dt < best:
			best = dt
	if records.energy[row] > config.energy_threshold:
		dt = int((records.energy[row] - config.energy_threshold)
			/ config.energy_per_day * float(BConfig.TICKS_PER_DAY))
		if dt > 0 and dt < best:
			best = dt
	if records.social[row] > config.social_threshold:
		dt = int((records.social[row] - config.social_threshold)
			/ config.social_per_day * float(BConfig.TICKS_PER_DAY))
		if dt > 0 and dt < best:
			best = dt
	if records.hygiene[row] > config.hygiene_threshold:
		dt = int((records.hygiene[row] - config.hygiene_threshold)
			/ config.hygiene_per_day * float(BConfig.TICKS_PER_DAY))
		if dt > 0 and dt < best:
			best = dt
	if records.fun[row] > config.fun_threshold:
		dt = int((records.fun[row] - config.fun_threshold)
			/ config.fun_per_day * float(BConfig.TICKS_PER_DAY))
		if dt > 0 and dt < best:
			best = dt
	if best < 60:
		best = 60
	var jitter2: int = BHash.hash4(records.ids[row], records.wake_gen[row], now, 0x9A ^ config.seed) % 300
	return now + best + jitter2


func _start_travel(row: int, target: Vector2, now: int, gen: int) -> void:
	var start: Vector2 = position_at(row, now)
	var distance: float = start.distance_to(target)
	var duration: int = maxi(30, int(distance / maxf(0.1, config.detail_speed_tiles_per_s)))
	records.travel_depart[row] = now
	records.travel_arrive[row] = now + duration
	records.travel_start_x[row] = start.x
	records.travel_start_y[row] = start.y
	records.travel_end_x[row] = target.x
	records.travel_end_y[row] = target.y
	records.activity[row] = BConfig.ACTIVITY_TRAVEL
	travel_starts += 1
	_schedule(row, now + duration, gen)


func _clear_travel(row: int) -> void:
	records.travel_depart[row] = 0
	records.travel_arrive[row] = 0
	records.travel_start_x[row] = records.pos_x[row]
	records.travel_start_y[row] = records.pos_y[row]
	records.travel_end_x[row] = records.pos_x[row]
	records.travel_end_y[row] = records.pos_y[row]


func _schedule(row: int, at: int, gen: int) -> void:
	if at <= 0:
		at = 1
	records.next_event[row] = at
	scheduler.push(at, BKinds.EVENT_AGENT_WAKE,
		(gen << 32) | (row & 0xFFFFFFFF))


func position_at(row: int, t: int) -> Vector2:
	if row < 0 or row >= records.count:
		return Vector2.ZERO
	if records.activity[row] == BConfig.ACTIVITY_TRAVEL:
		var depart: int = records.travel_depart[row]
		var arrive: int = records.travel_arrive[row]
		if t >= depart and t <= arrive and arrive > depart:
			var u: float = float(t - depart) / float(arrive - depart)
			return Vector2(
				lerpf(records.travel_start_x[row], records.travel_end_x[row], u),
				lerpf(records.travel_start_y[row], records.travel_end_y[row], u))
	return Vector2(records.pos_x[row], records.pos_y[row])


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, wake_count)
	h = HashUtil.mix_i64(h, routine_events)
	h = HashUtil.mix_i64(h, travel_starts)
	h = HashUtil.mix_i64(h, work_starts)
	h = HashUtil.mix_i64(h, sleep_starts)
	return h

