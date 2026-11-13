class_name DecisionSystem
extends RefCounted

## Need-basierter Zustandsautomat + Rollen-Routine.
##
## Es gibt genau ein gültiges Scheduler-Event pro Agent (Generation im Payload).
## Jeder Wake materialisiert Needs, schließt fällige Aktionen ab und plant genau
## einen nächsten logischen Termin. Kein Full-Agent-Sweep pro Frame/Tick.
##
## G1a-Vereinfachungen:
## - Arbeit ist Fortschritt: volle Arbeitsstunden erzeugen Grain, Reststunden
##   werden über Unterbrechungen hinweg getragen.
## - Mahlzeiten verbrauchen Grain; bei Knappheit wird nichts aufgefüllt.
## - Energie/Sozial/Arbeit sind Commitments; Hunger kann Arbeit unterbrechen.

const SOURCE_ROUTINE: int = 0
const SOURCE_NEED: int = 1

const NEED_HUNGER: int = 0
const NEED_ENERGY: int = 1
const NEED_SOCIAL: int = 2

const NEAR_DISTANCE: float = 0.6
const MAX_NAP_S: int = 6 * 3600

## Kein starker Rückverweis auf Simulation (kein RefCounted-Zyklus).
var _host_ref: WeakRef
var config: SimConfig
var clock: SimClock
var store: AgentStore
var world: WorldMap
var routes: RouteStore
var scheduler: EventScheduler
var logs: SimLogs


func _init(sim_ref) -> void:
	_host_ref = weakref(sim_ref)
	config = sim_ref.config
	clock = sim_ref.clock
	store = sim_ref.store
	world = sim_ref.world
	routes = sim_ref.routes
	scheduler = sim_ref.scheduler
	logs = sim_ref.logs


func _host():
	return _host_ref.get_ref()


func _now() -> int:
	return clock.now


func _agent_id(row: int) -> int:
	return store.ids[row]


## Erzwingt einen externen Wake (Tests, spätere Gefahr/Job-Wakes).
## Das alte Event bleibt als stale Event im Heap und wird ignoriert.
func request_wake(row: int, at_time: int) -> void:
	if row < 0 or row >= store.count or store.alive[row] == 0:
		return
	var when: int = maxi(at_time, _now() + SimConfig.MIN_WAKE_S)
	store.wake_gen[row] = (store.wake_gen[row] + 1) & 0x7FFFFFFF
	store.next_event[row] = when
	var payload: int = (store.wake_gen[row] << 32) | (row & 0xFFFFFFFF)
	scheduler.push(when, SimKinds.EVENT_AGENT_WAKE, payload)


func on_agent_wake(row: int) -> void:
	if row < 0 or row >= store.count or store.alive[row] == 0:
		return
	NeedsModel.settle(store, row, _now(), config)
	var now: int = _now()
	var guard: int = 0
	while guard < 8:
		guard += 1
		var act: int = store.activity[row]
		if act == AgentStore.ACT_TRAVEL:
			if now >= store.travel_arrive[row]:
				_complete_arrival(row, now)
				continue
			break
		if act == AgentStore.ACT_SLEEP:
			if now >= store.action_end[row]:
				_finish_sleep(row, now)
				continue
			break
		if act == AgentStore.ACT_EAT:
			if now >= store.action_end[row]:
				_finish_meal(row, now)
				continue
			break
		if act == AgentStore.ACT_SOCIAL:
			if now >= store.action_end[row]:
				_finish_social(row, now)
				continue
			break
		if act == AgentStore.ACT_WORK:
			if now >= store.work_end[row]:
				_finish_work(row, now)
				continue
			var need_w: int = _need_urgency(row, now)
			if need_w >= 0:
				_finish_work(row, now)
				_start_need_action(row, now, need_w)
			break
		if act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
			if now >= store.action_end[row]:
				store.activity[row] = AgentStore.ACT_IDLE
				continue
			var need_l: int = _need_urgency(row, now)
			if need_l >= 0:
				store.activity[row] = AgentStore.ACT_IDLE
				_start_need_action(row, now, need_l)
			break
		# IDLE
		var need_i: int = _need_urgency(row, now)
		if need_i >= 0:
			_start_need_action(row, now, need_i)
		else:
			_apply_routine(row, now)
		break
	schedule_next(row, now)


func schedule_next(row: int, now: int) -> void:
	if row < 0 or row >= store.count or store.alive[row] == 0:
		return
	var act: int = store.activity[row]
	var best: int = 0
	if act == AgentStore.ACT_TRAVEL:
		best = store.travel_arrive[row]
	elif act == AgentStore.ACT_WORK:
		best = store.work_end[row]
	elif act == AgentStore.ACT_EAT or act == AgentStore.ACT_SOCIAL:
		best = store.action_end[row]
	elif act == AgentStore.ACT_SLEEP:
		best = store.action_end[row]
	elif act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		best = store.action_end[row]
	else:
		best = RoleSchedule.next_transition_abs(now, store.role[row])
	if act == AgentStore.ACT_IDLE or act == AgentStore.ACT_WORK \
			or act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		var t_h: int = _need_wake_time(row, now, NEED_HUNGER)
		if t_h > 0 and t_h < best:
			best = t_h
		var t_e: int = _need_wake_time(row, now, NEED_ENERGY)
		if t_e > 0 and t_e < best:
			best = t_e
		var t_s: int = _need_wake_time(row, now, NEED_SOCIAL)
		if t_s > 0 and t_s < best:
			best = t_s
	if best <= now:
		best = now + SimConfig.MIN_WAKE_S
	store.wake_gen[row] = (store.wake_gen[row] + 1) & 0x7FFFFFFF
	store.next_event[row] = best
	var payload: int = (store.wake_gen[row] << 32) | (row & 0xFFFFFFFF)
	scheduler.push(best, SimKinds.EVENT_AGENT_WAKE, payload)


func _need_value(row: int, need: int) -> float:
	match need:
		NEED_HUNGER:
			return store.hunger[row]
		NEED_ENERGY:
			return store.energy[row]
		NEED_SOCIAL:
			return store.social[row]
	return 0.0


func _routine_activity(row: int, now: int) -> int:
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row], minute)
	return entry[2]


func _hunger_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_EAT:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_EAT:
		return true
	if now < store.meal_retry[row]:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_EAT) <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	return false


func _energy_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_SLEEP:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_SLEEP) <= SimConfig.SLEEP_LOOKAHEAD_S:
		return true
	return false


func _social_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SOCIAL:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_SOCIAL:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_SOCIAL) <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	return false


func _need_urgency(row: int, now: int) -> int:
	if store.hunger[row] >= config.hunger_threshold and not _hunger_suppressed(row, now):
		return NEED_HUNGER
	if store.energy[row] <= config.energy_threshold and not _energy_suppressed(row, now):
		return NEED_ENERGY
	if store.social[row] <= config.social_threshold and not _social_suppressed(row, now):
		return NEED_SOCIAL
	return -1


func _need_wake_time(row: int, now: int, need: int) -> int:
	var value: float = _need_value(row, need)
	match need:
		NEED_HUNGER:
			if value >= config.hunger_threshold:
				if now < store.meal_retry[row]:
					return store.meal_retry[row]
				if _hunger_suppressed(row, now):
					return -1
				return now
			if _hunger_suppressed(row, now):
				# Ein geplantes Routinemahl reduziert Hunger vor dem Termin.
				var dt0: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
				var meal_in: int = RoleSchedule.seconds_until_next_activity(now,
					store.role[row], AgentStore.ACT_EAT)
				if meal_in >= 0 and meal_in <= SimConfig.ROUTINE_LOOKAHEAD_S:
					return -1
				if dt0 < 0:
					return -1
				return now + dt0
			var dt: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dt < 0 else now + dt
		NEED_ENERGY:
			if value <= config.energy_threshold:
				if _energy_suppressed(row, now):
					return -1
				return now
			var dte: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dte < 0 else now + dte
		NEED_SOCIAL:
			if value <= config.social_threshold:
				if _social_suppressed(row, now):
					return -1
				return now
			var dts: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dts < 0 else now + dts
	return -1


## Kleine, deterministische Positionsoffsets verhindern, dass mehrere Agenten
## exakt übereinander stehen (Wimmelbild). Alle Punkte bleiben begehbar.
func _home_point(row: int) -> Vector2:
	var base: Vector2 = world.door_point(store.home_id[row])
	return world.clamp_point(base + Vector2((float(row % 4) - 1.5) * 1.2, 0.0))


func _field_point(row: int) -> Vector2:
	var slot: int = (row * 3) % 5
	var dx: float = float((slot % 3) - 1) * 3.0
	var dy: float = (float(slot / 3) - 0.5) * 4.0
	return world.clamp_point(world.field_work_point + Vector2(dx, dy))


func _workshop_point(row: int) -> Vector2:
	var base: Vector2 = world.door_point(WorldMap.B_WORKSHOP)
	return world.clamp_point(base + Vector2(float((row % 3) - 1) * 1.4, 0.0))


func _plaza_point(row: int) -> Vector2:
	var dx: float = float((row % 5) - 2) * 1.0
	var dy: float = float((row / 5) % 2) * 1.5
	return world.clamp_point(world.plaza_point + Vector2(dx, dy))


func _resolve_place(row: int, place: int) -> Array:
	var home_id: int = store.home_id[row]
	var home_point: Vector2 = _home_point(row)
	match place:
		RoleSchedule.PLACE_FIELD:
			return [WorldMap.B_FIELD, _field_point(row)]
		RoleSchedule.PLACE_WORKSHOP:
			return [WorldMap.B_WORKSHOP, _workshop_point(row)]
		RoleSchedule.PLACE_PLAZA:
			return [WorldMap.B_WELL, _plaza_point(row)]
		RoleSchedule.PLACE_JOB:
			if store.job_kind[row] == AgentStore.JOB_FIELD:
				return [WorldMap.B_FIELD, _field_point(row)]
			if store.job_kind[row] == AgentStore.JOB_WORKSHOP:
				return [WorldMap.B_WORKSHOP, _workshop_point(row)]
			return [home_id, home_point]
		_:
			return [home_id, home_point]


func _apply_routine(row: int, now: int) -> void:
	var role: int = store.role[row]
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(role, minute)
	var act: int = entry[2]
	var end_abs: int = RoleSchedule.entry_end_abs(now, role)
	if act == AgentStore.ACT_SLEEP:
		end_abs = _extend_sleep_if_needed(end_abs, row)
	var place: Array = _resolve_place(row, entry[3])
	_go_or_act(row, act, place[0], place[1], end_abs, SOURCE_ROUTINE)


func _go_or_act(row: int, act: int, building_id: int, point: Vector2,
		end_abs: int, source: int) -> void:
	var now: int = _now()
	store.target_building_id[row] = building_id
	store.target_x[row] = point.x
	store.target_y[row] = point.y
	if now >= end_abs:
		store.activity[row] = AgentStore.ACT_IDLE
		return
	var current: Vector2 = Vector2(store.pos_x[row], store.pos_y[row])
	if current.distance_to(point) <= NEAR_DISTANCE:
		store.pos_x[row] = point.x
		store.pos_y[row] = point.y
		_begin_action(row, act, now, end_abs, source)
	else:
		_start_travel(row, act, building_id, point, source, end_abs, 0)


func _start_travel(row: int, act: int, building_id: int, point: Vector2,
		source: int, abs_end: int, duration_after: int) -> void:
	var now: int = _now()
	var start: Vector2 = Vector2(store.pos_x[row], store.pos_y[row])
	var points: PackedVector2Array = world.find_route(start, point)
	var length: float = WorldMap.polyline_length(points)
	var travel_s: int = maxi(1, int(ceil(length / config.walk_speed)))
	var arrival: int = now + travel_s
	var action_end: int = abs_end if abs_end > 0 else arrival + duration_after
	if act == AgentStore.ACT_SLEEP:
		action_end = _extend_sleep_if_needed(action_end, row)
	var route: int = routes.create(points)
	store.activity[row] = AgentStore.ACT_TRAVEL
	store.intent[row] = act
	store.action_source[row] = source
	store.action_end[row] = action_end
	store.route_id[row] = route
	store.travel_depart[row] = now
	store.travel_arrive[row] = arrival
	store.travel_start_x[row] = start.x
	store.travel_start_y[row] = start.y
	store.travel_end_x[row] = point.x
	store.travel_end_y[row] = point.y
	_host().log_event(SimEvent.T_TRAVEL_START, SimEvent.IMPORTANCE_ROUTINE,
		_agent_id(row), "travel_start", "Weg zum Ziel", building_id)


func _extend_sleep_if_needed(end_time: int, row: int) -> int:
	var result: int = end_time
	var guard: int = 0
	while guard < 4:
		guard += 1
		var minute: int = (result % SimConfig.TICKS_PER_DAY) / 60
		var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row], minute)
		if entry[2] != AgentStore.ACT_SLEEP:
			break
		var entry_end: int = RoleSchedule.entry_end_abs(result, store.role[row])
		if entry_end <= result:
			break
		result = entry_end
	return result


func _complete_arrival(row: int, now: int) -> void:
	store.pos_x[row] = store.travel_end_x[row]
	store.pos_y[row] = store.travel_end_y[row]
	store.route_id[row] = -1
	store.activity[row] = AgentStore.ACT_IDLE
	_host().log_event(SimEvent.T_ARRIVE, SimEvent.IMPORTANCE_ROUTINE,
		_agent_id(row), "arrive", "angekommen", store.target_building_id[row])
	var act: int = store.intent[row]
	var end_time: int = store.action_end[row]
	var source: int = store.action_source[row]
	if now < end_time:
		_begin_action(row, act, now, end_time, source)
	else:
		store.activity[row] = AgentStore.ACT_IDLE


func _begin_action(row: int, act: int, now: int, end_time: int, source: int) -> void:
	if end_time <= now:
		store.activity[row] = AgentStore.ACT_IDLE
		return
	store.activity[row] = act
	store.action_end[row] = end_time
	store.action_source[row] = source
	store.work_start[row] = -1
	store.work_end[row] = -1
	var agent_id: int = _agent_id(row)
	if act == AgentStore.ACT_WORK:
		store.work_start[row] = now
		store.work_end[row] = end_time
		_host().log_event(SimEvent.T_WORK_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "work_start", "Arbeit beginnt", store.target_building_id[row])
	elif act == AgentStore.ACT_EAT:
		_host().log_event(SimEvent.T_MEAL_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "meal_start", "Mahlzeit beginnt", source)
	elif act == AgentStore.ACT_SLEEP:
		if source == SOURCE_NEED:
			_host().log_event(SimEvent.T_NAP_START, SimEvent.IMPORTANCE_ROUTINE,
				agent_id, "nap_start", "Nickerchen", 0)
		else:
			_host().log_event(SimEvent.T_SLEEP_START, SimEvent.IMPORTANCE_ROUTINE,
				agent_id, "sleep_start", "Schlaf beginnt", 0)
	elif act == AgentStore.ACT_SOCIAL:
		_host().log_event(SimEvent.T_SOCIAL_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "social_start", "Sozialisieren", source)
	elif act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		_host().log_event(SimEvent.T_ACTIVITY_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "activity_start", AgentStore.activity_name(act), act)


func _finish_work(row: int, now: int) -> void:
	if store.work_start[row] >= 0:
		var worked: int = now - store.work_start[row]
		if worked > 0:
			store.work_accum[row] += worked
		store.work_start[row] = -1
	var hours: int = int(store.work_accum[row] / 3600)
	if hours > 0:
		store.work_accum[row] -= hours * 3600
		if store.job_kind[row] == AgentStore.JOB_FIELD:
			var grain_added: int = hours * SimConfig.GRAIN_PER_FIELD_HOUR
			_host().grain += grain_added
			_host().grain_produced += grain_added
			_host().log_event(SimEvent.T_WORK_END, SimEvent.IMPORTANCE_NOTABLE,
				_agent_id(row), "work_end", "Feldarbeit", grain_added)
			_host().log_event(SimEvent.T_GRAIN_AWARD, SimEvent.IMPORTANCE_ROUTINE,
				_agent_id(row), "grain_award", "Grain eingelagert", grain_added)
	store.work_end[row] = -1
	store.activity[row] = AgentStore.ACT_IDLE


func _finish_meal(row: int, now: int) -> void:
	if _host().grain >= SimConfig.MEAL_GRAIN_COST:
		_host().grain -= SimConfig.MEAL_GRAIN_COST
		_host().meals_served += 1
		NeedsModel.apply_meal(store, row, config)
		store.meal_retry[row] = 0
		_host().log_event(SimEvent.T_MEAL_END, SimEvent.IMPORTANCE_ROUTINE,
			_agent_id(row), "meal_end", "Mahlzeit beendet", _host().grain)
	else:
		_host().meals_skipped += 1
		store.meal_retry[row] = now + SimConfig.SHORTAGE_RETRY_S
		_host().log_event(SimEvent.T_MEAL_SKIPPED, SimEvent.IMPORTANCE_NOTABLE,
			_agent_id(row), "meal_skipped", "kein Grain", _host().grain)
		var day: int = clock.day_index()
		if store.shortage_logged_day[row] != day:
			store.shortage_logged_day[row] = day
			_host().log_event(SimEvent.T_SHORTAGE, SimEvent.IMPORTANCE_MAJOR,
				_agent_id(row), "shortage", "Nahrungsknappheit", _host().grain)
	store.activity[row] = AgentStore.ACT_IDLE


func _finish_social(row: int, now: int) -> void:
	NeedsModel.apply_social(store, row, config)
	_host().log_event(SimEvent.T_SOCIAL_END, SimEvent.IMPORTANCE_ROUTINE,
		_agent_id(row), "social_end", "Sozialisieren beendet", int(round(store.social[row])))
	store.activity[row] = AgentStore.ACT_IDLE


func _finish_sleep(row: int, now: int) -> void:
	if store.action_source[row] == SOURCE_NEED:
		_host().log_event(SimEvent.T_NAP_END, SimEvent.IMPORTANCE_ROUTINE,
			_agent_id(row), "nap_end", "Nickerchen beendet", 0)
	else:
		_host().log_event(SimEvent.T_WAKE_UP, SimEvent.IMPORTANCE_ROUTINE,
			_agent_id(row), "wake_up", "aufgewacht", 0)
	store.activity[row] = AgentStore.ACT_IDLE


func _start_need_action(row: int, now: int, need: int) -> void:
	var agent_id: int = _agent_id(row)
	_host().log_event(SimEvent.T_NEED_INTERRUPT, SimEvent.IMPORTANCE_NOTABLE,
		agent_id, "need_interrupt", NeedsModel.need_name(need), need)
	var home_id: int = store.home_id[row]
	var home_point: Vector2 = _home_point(row)
	if need == NEED_HUNGER:
		store.target_building_id[row] = home_id
		store.target_x[row] = home_point.x
		store.target_y[row] = home_point.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(home_point) <= NEAR_DISTANCE:
			_begin_action(row, AgentStore.ACT_EAT, now,
				now + SimConfig.MEAL_DURATION_S, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_EAT, home_id, home_point, SOURCE_NEED,
				-1, SimConfig.MEAL_DURATION_S)
	elif need == NEED_ENERGY:
		var nap_s: int = _nap_duration(row)
		store.target_building_id[row] = home_id
		store.target_x[row] = home_point.x
		store.target_y[row] = home_point.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(home_point) <= NEAR_DISTANCE:
			var end_time: int = _extend_sleep_if_needed(now + nap_s, row)
			_begin_action(row, AgentStore.ACT_SLEEP, now, end_time, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_SLEEP, home_id, home_point, SOURCE_NEED,
				-1, nap_s)
	elif need == NEED_SOCIAL:
		var plaza: Vector2 = _plaza_point(row)
		store.target_building_id[row] = WorldMap.B_WELL
		store.target_x[row] = plaza.x
		store.target_y[row] = plaza.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(plaza) <= NEAR_DISTANCE:
			_begin_action(row, AgentStore.ACT_SOCIAL, now,
				now + SimConfig.SOCIAL_DURATION_S, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_SOCIAL, WorldMap.B_WELL, plaza,
				SOURCE_NEED, -1, SimConfig.SOCIAL_DURATION_S)


func _nap_duration(row: int) -> int:
	var missing: float = maxf(0.0, SimConfig.NAP_TARGET_ENERGY - store.energy[row])
	var sleep_rate: float = config.energy_per_8h_sleep / (8.0 * 3600.0)
	var seconds: int = int(ceil(missing / sleep_rate))
	return clampi(seconds, 1800, MAX_NAP_S)


## Position zur Sim-Zeit t. Reine Geometrie, keine Frame-Abhängigkeit.
func position_at(row: int, t: int) -> Vector2:
	if row < 0 or row >= store.count:
		return Vector2.ZERO
	var route: int = store.route_id[row]
	if route >= 0:
		var depart: int = store.travel_depart[row]
		var arrive: int = store.travel_arrive[row]
		if t < depart:
			return Vector2(store.travel_start_x[row], store.travel_start_y[row])
		if t >= arrive:
			return Vector2(store.travel_end_x[row], store.travel_end_y[row])
		var points: PackedVector2Array = routes.get_points(route)
		var total: float = WorldMap.polyline_length(points)
		var traveled: float = 0.0
		if arrive > depart:
			traveled = total * float(t - depart) / float(arrive - depart)
		return WorldMap.point_on_polyline(points, traveled)
	return Vector2(store.pos_x[row], store.pos_y[row])
