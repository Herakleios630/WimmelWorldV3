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
const NEED_HYGIENE: int = 3
const NEED_FUN: int = 4

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
		# Pfad- oder G3-Routinejitter-Vertagung: nicht sofort erneut planen.
		if store.defer_until[row] > now:
			break
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
		if act == AgentStore.ACT_HYGIENE:
			if now >= store.action_end[row]:
				_finish_hygiene(row, now)
				continue
			break
		if act == AgentStore.ACT_LEARN:
			if now >= store.action_end[row]:
				store.activity[row] = AgentStore.ACT_IDLE
				continue
			var need_l: int = _need_urgency(row, now)
			if need_l >= 0:
				store.activity[row] = AgentStore.ACT_IDLE
				_start_need_action(row, now, need_l)
			break
		if act == AgentStore.ACT_PLAY:
			if now >= store.action_end[row]:
				_finish_play(row, now)
				continue
			var need_p: int = _need_urgency(row, now)
			if need_p >= 0:
				store.activity[row] = AgentStore.ACT_IDLE
				_start_need_action(row, now, need_p)
			break
		# IDLE
		var need_i: int = _need_urgency(row, now)
		if need_i >= 0:
			_start_need_action(row, now, need_i)
		else:
			_apply_routine(row, now)
		break
	schedule_next(row, now)


## G3-Routinejitter spreizt die 6-/7-/8-/13-/17-Uhr-Bursts deterministisch.
## Ohne Jitter würden 1000 Agenten im selben Batch einen Pfad anfordern; das
## 50-Lookup-Budget würde über viele Frames deferieren. Lange Fenster
## (Arbeit/Spiel/Sozial) streuen breiter als kurze Mahlzeiten. G1/G2 bleiben
## exakt beim bisherigen Zeitplan.
func _jitter_span_minutes(_act: int) -> int:
	# 0..89 Minuten; die G3-Pläne haben 90-min-Mahlzeitenfenster und
	# ausreichend lange Arbeits-/Sozial-/Schlaffenster.
	return 90


func _jitter_for_transition(row: int, at_abs: int) -> int:
	if not config.is_g3():
		return 0
	var minute: int = (at_abs % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row], minute,
		config.is_g3())
	var span: int = _jitter_span_minutes(entry[2])
	return ((store.ids[row] * 37 + store.home_id[row]) % span) * 60


func schedule_next(row: int, now: int) -> void:
	if row < 0 or row >= store.count or store.alive[row] == 0:
		return
	var act: int = store.activity[row]
	var best: int = 0
	var routine_transition: bool = false
	if act == AgentStore.ACT_TRAVEL:
		best = store.travel_arrive[row]
	elif act == AgentStore.ACT_WORK:
		best = store.work_end[row]
	elif act == AgentStore.ACT_EAT or act == AgentStore.ACT_SOCIAL:
		best = store.action_end[row]
	elif act == AgentStore.ACT_SLEEP:
		best = store.action_end[row]
	elif act == AgentStore.ACT_HYGIENE:
		best = store.action_end[row]
	elif act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		best = store.action_end[row]
	else:
		best = RoleSchedule.next_transition_abs(now, store.role[row],
			config.is_g3())
		routine_transition = true
	if routine_transition:
		best += _jitter_for_transition(row, best)
	if act == AgentStore.ACT_IDLE or act == AgentStore.ACT_WORK \
			or act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		# G3: Ferne Needs brauchen keinen teuren Schwellen-Wake; die nächste
		# Routinetransition liegt deutlich vor dem Schwellenwert.
		if not _need_far_from_threshold(row, NEED_HUNGER):
			var t_h: int = _need_wake_time(row, now, NEED_HUNGER)
			if t_h > 0 and t_h < best:
				best = t_h
		if not _need_far_from_threshold(row, NEED_ENERGY):
			var t_e: int = _need_wake_time(row, now, NEED_ENERGY)
			if t_e > 0 and t_e < best:
				best = t_e
		if not _need_far_from_threshold(row, NEED_SOCIAL):
			var t_s: int = _need_wake_time(row, now, NEED_SOCIAL)
			if t_s > 0 and t_s < best:
				best = t_s
		if not _need_far_from_threshold(row, NEED_HYGIENE):
			var t_hy: int = _need_wake_time(row, now, NEED_HYGIENE)
			if t_hy > 0 and t_hy < best:
				best = t_hy
		if not _need_far_from_threshold(row, NEED_FUN):
			var t_f: int = _need_wake_time(row, now, NEED_FUN)
			if t_f > 0 and t_f < best:
				best = t_f
	if store.defer_until[row] > now:
		best = store.defer_until[row]
	store.defer_until[row] = 0
	if best <= now:
		best = now + SimConfig.MIN_WAKE_S
	store.wake_gen[row] = (store.wake_gen[row] + 1) & 0x7FFFFFFF
	store.next_event[row] = best
	var payload: int = (store.wake_gen[row] << 32) | (row & 0xFFFFFFFF)
	scheduler.push(best, SimKinds.EVENT_AGENT_WAKE, payload)


func _need_far_from_threshold(row: int, need: int) -> bool:
	if not config.is_g3():
		return false
	match need:
		NEED_HUNGER:
			return store.hunger[row] < config.hunger_threshold - 30.0
		NEED_ENERGY:
			return store.energy[row] > config.energy_threshold + 25.0
		NEED_SOCIAL:
			return store.social[row] > config.social_threshold + 25.0
		NEED_HYGIENE:
			return store.hygiene[row] > config.hygiene_threshold + 25.0
		NEED_FUN:
			return store.fun[row] > config.fun_threshold + 25.0
	return false


func _need_value(row: int, need: int) -> float:
	match need:
		NEED_HUNGER:
			return store.hunger[row]
		NEED_ENERGY:
			return store.energy[row]
		NEED_SOCIAL:
			return store.social[row]
		NEED_HYGIENE:
			return store.hygiene[row]
		NEED_FUN:
			return store.fun[row]
	return 0.0


func _routine_activity(row: int, now: int) -> int:
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row], minute,
		config.is_g3())
	return entry[2]


func _hunger_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_EAT:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_EAT:
		return true
	if now < store.meal_retry[row]:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_EAT, config.is_g3()) <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	return false


func _energy_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_SLEEP:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_SLEEP, config.is_g3()) <= SimConfig.SLEEP_LOOKAHEAD_S:
		return true
	return false


func _social_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SOCIAL:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_SOCIAL:
		return true
	if RoleSchedule.seconds_until_next_activity(now, store.role[row],
			AgentStore.ACT_SOCIAL, config.is_g3()) <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	return false


func _hygiene_suppressed(row: int, now: int) -> bool:
	return store.activity[row] == AgentStore.ACT_HYGIENE


func _fun_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_PLAY \
			or store.activity[row] == AgentStore.ACT_SOCIAL:
		return true
	if _routine_activity(row, now) == AgentStore.ACT_PLAY \
			or _routine_activity(row, now) == AgentStore.ACT_SOCIAL:
		return true
	var next_play: int = RoleSchedule.seconds_until_next_activity(now,
		store.role[row], AgentStore.ACT_PLAY, config.is_g3())
	var next_social: int = RoleSchedule.seconds_until_next_activity(now,
		store.role[row], AgentStore.ACT_SOCIAL, config.is_g3())
	if next_play >= 0 and next_play <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	if next_social >= 0 and next_social <= SimConfig.ROUTINE_LOOKAHEAD_S:
		return true
	return false


func _need_urgency(row: int, now: int) -> int:
	if store.hunger[row] >= config.hunger_threshold and not _hunger_suppressed(row, now):
		return NEED_HUNGER
	if store.energy[row] <= config.energy_threshold and not _energy_suppressed(row, now):
		return NEED_ENERGY
	if store.hygiene[row] <= config.hygiene_threshold and not _hygiene_suppressed(row, now):
		return NEED_HYGIENE
	if store.fun[row] <= config.fun_threshold and not _fun_suppressed(row, now):
		return NEED_FUN
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
					store.role[row], AgentStore.ACT_EAT, config.is_g3())
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
		NEED_HYGIENE:
			if value <= config.hygiene_threshold:
				if _hygiene_suppressed(row, now):
					return -1
				return now
			var dth: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dth < 0 else now + dth
		NEED_FUN:
			if value <= config.fun_threshold:
				if _fun_suppressed(row, now):
					return -1
				return now
			var dtf: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dtf < 0 else now + dtf
	return -1


## Kleine, deterministische Positionsoffsets verhindern, dass mehrere Agenten
## exakt übereinander stehen (Wimmelbild). Alle Punkte bleiben begehbar.
func _home_point(row: int) -> Vector2:
	var base: Vector2 = world.door_point(store.home_id[row])
	return world.clamp_point(base + Vector2((float(row % 4) - 1.5) * 1.2, 0.0))


func _field_id_for_row(row: int) -> int:
	var ids: PackedInt32Array = world.field_ids()
	if ids.is_empty():
		return -1
	return ids[(row + store.home_id[row]) % ids.size()]


func _field_point(row: int) -> Vector2:
	var field_id: int = _field_id_for_row(row)
	var slot: int = (row * 3) % 5
	var dx: float = float((slot % 3) - 1) * 3.0
	var dy: float = (float(slot / 3) - 0.5) * 4.0
	return world.clamp_point(world.field_work_point_for(field_id) + Vector2(dx, dy))


func _workshop_point(row: int) -> Vector2:
	var base: Vector2 = world.door_point(world.workshop_id_for_row(row))
	return world.clamp_point(base + Vector2(float((row % 3) - 1) * 1.4, 0.0))


## G3: Ein Feld ist nur im Frühling (pflügen/säen) und im Herbst (ernten)
## bearbeitbar. Außerhalb der Fenster gehen Feldarbeiter zur Werkstatt, statt
## wirkungslose Feldarbeit zu protokollieren.
func _field_actionable(field: Building) -> bool:
	if field == null or field.kind != Building.KIND_FIELD:
		return false
	if not config.seasonal_fields:
		return true
	var day: int = clock.day_index()
	var year: int = config.year_of_day(day)
	if config.is_spring_day(day):
		if field.field_crop_year == year:
			return false
		return field.field_stage == Building.FIELD_FALLOW \
			or field.field_stage == Building.FIELD_PLOWING \
			or field.field_stage == Building.FIELD_PLOWED \
			or field.field_stage == Building.FIELD_SOWING
	if config.is_autumn_day(day):
		if field.field_harvested_year == year:
			return false
		return field.field_stage == Building.FIELD_RIPE \
			or field.field_stage == Building.FIELD_HARVESTING
	return false


func _plaza_point(row: int) -> Vector2:
	var dx: float = float((row % 5) - 2) * 1.0
	var dy: float = float((row / 5) % 2) * 1.5
	return world.clamp_point(world.plaza_point + Vector2(dx, dy))


func _well_point(row: int) -> Vector2:
	var base: Vector2 = world.door_point(world.well_id())
	return world.clamp_point(base + Vector2(float((row % 3) - 1) * 0.8, 0.0))


func _resolve_place(row: int, place: int) -> Array:
	var home_id: int = store.home_id[row]
	var home_point: Vector2 = _home_point(row)
	match place:
		RoleSchedule.PLACE_FIELD:
			var field_id: int = _field_id_for_row(row)
			var field: Building = world.building_by_id(field_id)
			if not _field_actionable(field):
				return [world.workshop_id_for_row(row), _workshop_point(row)]
			return [field_id, _field_point(row)]
		RoleSchedule.PLACE_WORKSHOP:
			return [world.workshop_id_for_row(row), _workshop_point(row)]
		RoleSchedule.PLACE_PLAZA:
			return [world.well_id(), _plaza_point(row)]
		RoleSchedule.PLACE_JOB:
			if store.job_kind[row] == AgentStore.JOB_FIELD:
				var fid: int = _field_id_for_row(row)
				var field2: Building = world.building_by_id(fid)
				if not _field_actionable(field2):
					return [world.workshop_id_for_row(row), _workshop_point(row)]
				return [fid, _field_point(row)]
			if store.job_kind[row] == AgentStore.JOB_WORKSHOP:
				return [world.workshop_id_for_row(row), _workshop_point(row)]
			return [home_id, home_point]
		_:
			return [home_id, home_point]


func _apply_routine(row: int, now: int) -> void:
	var role: int = store.role[row]
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(role, minute,
		config.is_g3())
	var act: int = entry[2]
	var end_abs: int = RoleSchedule.entry_end_abs(now, role, config.is_g3())
	if act == AgentStore.ACT_SLEEP:
		end_abs = _extend_sleep_if_needed(end_abs, row)
	# G3: auch feste Aktionsenden (12:00/17:00/18:00/6:00) deterministisch
	# spreizen, damit nicht 1000 Agents im selben Batch enden.
	if config.is_g3():
		end_abs += _jitter_for_transition(row, end_abs)
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
		source: int, abs_end: int, duration_after: int) -> bool:
	var now: int = _now()
	var start: Vector2 = Vector2(store.pos_x[row], store.pos_y[row])
	var points: PackedVector2Array = _host().find_travel_path(start, point)
	if points.is_empty():
		if _host().path_was_deferred():
			store.defer_until[row] = _host().deferred_wake_time()
		store.activity[row] = AgentStore.ACT_IDLE
		store.route_id[row] = -1
		return false
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
	return true


func _extend_sleep_if_needed(end_time: int, row: int) -> int:
	var result: int = end_time
	var guard: int = 0
	while guard < 4:
		guard += 1
		var minute: int = (result % SimConfig.TICKS_PER_DAY) / 60
		var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row],
			minute, config.is_g3())
		if entry[2] != AgentStore.ACT_SLEEP:
			break
		var entry_end: int = RoleSchedule.entry_end_abs(result, store.role[row],
			config.is_g3())
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
		if store.job_kind[row] == AgentStore.JOB_FIELD:
			_field_on_work_start(store.target_building_id[row])
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
	elif act == AgentStore.ACT_HYGIENE:
		_host().log_event(SimEvent.T_ACTIVITY_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "activity_start", "Waschen", act)
	elif act == AgentStore.ACT_LEARN or act == AgentStore.ACT_PLAY:
		_host().log_event(SimEvent.T_ACTIVITY_START, SimEvent.IMPORTANCE_ROUTINE,
			agent_id, "activity_start", AgentStore.activity_name(act), act)



func _finish_work(row: int, now: int) -> void:
	if store.work_start[row] >= 0:
		var worked: int = now - store.work_start[row]
		if worked > 0:
			if store.job_kind[row] == AgentStore.JOB_FIELD:
				_field_add_work(store.target_building_id[row], worked)
			else:
				store.work_accum[row] += worked
		store.work_start[row] = -1
	var field_stage: int = _field_stage(store.target_building_id[row])
	_host().log_event(SimEvent.T_WORK_END, SimEvent.IMPORTANCE_NOTABLE,
		_agent_id(row), "work_end", "Arbeit beendet", field_stage)
	store.work_end[row] = -1
	store.activity[row] = AgentStore.ACT_IDLE


func _finish_meal(row: int, now: int) -> void:
	if _host().grain >= SimConfig.MEAL_GRAIN_COST:
		_host().grain -= SimConfig.MEAL_GRAIN_COST
		_host().meals_served += 1
		_host().year_meals_served += 1
		NeedsModel.apply_meal(store, row, config)
		store.meal_retry[row] = 0
		_host().log_event(SimEvent.T_MEAL_END, SimEvent.IMPORTANCE_ROUTINE,
			_agent_id(row), "meal_end", "Mahlzeit beendet", _host().grain)
	else:
		_host().meals_skipped += 1
		_host().year_meals_skipped += 1
		store.meal_retry[row] = now + SimConfig.SHORTAGE_RETRY_S
		var day: int = clock.day_index()
		# G3 aggregiert die sichtbare Mahlzeiten-Knappheit pro Agent/Tag an
		# der Quelle; der autoritative Zähler meals_skipped bleibt exakt.
		var log_this_skip: bool = true
		if config.is_g3() and store.shortage_logged_day[row] == day:
			log_this_skip = false
		if log_this_skip:
			_host().log_event(SimEvent.T_MEAL_SKIPPED, SimEvent.IMPORTANCE_NOTABLE,
				_agent_id(row), "meal_skipped", "kein Grain", _host().grain)
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


func _finish_play(row: int, now: int) -> void:
	NeedsModel.apply_fun(store, row, config)
	_host().log_event(SimEvent.T_ACTIVITY_END, SimEvent.IMPORTANCE_ROUTINE,
		_agent_id(row), "activity_end", "Spielen beendet", AgentStore.ACT_PLAY)
	store.activity[row] = AgentStore.ACT_IDLE


func _finish_hygiene(row: int, now: int) -> void:
	NeedsModel.apply_hygiene(store, row, config)
	_host().log_event(SimEvent.T_ACTIVITY_END, SimEvent.IMPORTANCE_ROUTINE,
		_agent_id(row), "activity_end", "Waschen beendet", AgentStore.ACT_HYGIENE)
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
		store.target_building_id[row] = world.well_id()
		store.target_x[row] = plaza.x
		store.target_y[row] = plaza.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(plaza) <= NEAR_DISTANCE:
			_begin_action(row, AgentStore.ACT_SOCIAL, now,
				now + SimConfig.SOCIAL_DURATION_S, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_SOCIAL, world.well_id(), plaza,
				SOURCE_NEED, -1, SimConfig.SOCIAL_DURATION_S)
	elif need == NEED_HYGIENE:
		var well: Vector2 = _well_point(row)
		store.target_building_id[row] = world.well_id()
		store.target_x[row] = well.x
		store.target_y[row] = well.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(well) <= NEAR_DISTANCE:
			_begin_action(row, AgentStore.ACT_HYGIENE, now,
				now + SimConfig.HYGIENE_DURATION_S, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_HYGIENE, world.well_id(), well,
				SOURCE_NEED, -1, SimConfig.HYGIENE_DURATION_S)
	elif need == NEED_FUN:
		var leisure: Vector2 = _plaza_point(row)
		store.target_building_id[row] = world.well_id()
		store.target_x[row] = leisure.x
		store.target_y[row] = leisure.y
		if Vector2(store.pos_x[row], store.pos_y[row]).distance_to(leisure) <= NEAR_DISTANCE:
			_begin_action(row, AgentStore.ACT_PLAY, now,
				now + SimConfig.FUN_DURATION_S, SOURCE_NEED)
		else:
			_start_travel(row, AgentStore.ACT_PLAY, world.well_id(), leisure,
				SOURCE_NEED, -1, SimConfig.FUN_DURATION_S)


func _nap_duration(row: int) -> int:
	var missing: float = maxf(0.0, SimConfig.NAP_TARGET_ENERGY - store.energy[row])
	var sleep_rate: float = config.energy_per_8h_sleep / (8.0 * 3600.0)
	var seconds: int = int(ceil(missing / sleep_rate))
	return clampi(seconds, 1800, MAX_NAP_S)


func _field_stage(field_id: int) -> int:
	var field: Building = world.building_by_id(field_id)
	return field.field_stage if field != null else -1


func _field_set_stage(field: Building, stage: int) -> void:
	field.field_stage = stage
	_host().log_event(SimEvent.T_FIELD_STAGE, SimEvent.IMPORTANCE_NOTABLE,
		0, "field_stage", Building.field_stage_name(stage), stage)


## Beim Arbeitsbeginn werden FALLOW/PLOWED/RIPE in den jeweiligen
## Arbeitszustand überführt. Der Zustand ist damit sichtbar, bevor Fortschritt
## entsteht; es gibt keinen Instant-Abschluss.
func _field_on_work_start(field_id: int) -> void:
	var field: Building = world.building_by_id(field_id)
	if field == null or field.kind != Building.KIND_FIELD:
		return
	match field.field_stage:
		Building.FIELD_FALLOW:
			if config.seasonal_fields and not config.is_spring_day(clock.day_index()):
				return
			if config.seasonal_fields \
					and field.field_crop_year == config.year_of_day(clock.day_index()):
				return
			_field_set_stage(field, Building.FIELD_PLOWING)
		Building.FIELD_PLOWED:
			if config.seasonal_fields and not config.is_spring_day(clock.day_index()):
				return
			_field_set_stage(field, Building.FIELD_SOWING)
		Building.FIELD_RIPE:
			if config.seasonal_fields and not config.is_autumn_day(clock.day_index()):
				return
			_field_set_stage(field, Building.FIELD_HARVESTING)


func _field_add_work(field_id: int, seconds: int) -> void:
	var field: Building = world.building_by_id(field_id)
	if field == null or field.kind != Building.KIND_FIELD or seconds <= 0:
		return
	if config.seasonal_fields:
		_field_add_work_seasonal(field, seconds)
		return
	var required: int = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			required = config.field_plow_work_s
		Building.FIELD_SOWING:
			required = config.field_sow_work_s
		Building.FIELD_HARVESTING:
			required = config.field_harvest_work_s
	if required <= 0:
		return
	field.field_work_s += seconds
	if field.field_work_s < required:
		return
	# Restsekunden einer Arbeitssitzung werden nicht in die Folgestufe
	# übertragen. Jede Stufe braucht eigene Arbeit; kein Instant-Kettenlauf.
	field.field_work_s = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			_field_set_stage(field, Building.FIELD_PLOWED)
		Building.FIELD_SOWING:
			_field_set_stage(field, Building.FIELD_SOWN)
			var host = _host()
			host.log_event(SimEvent.T_FIELD_SOWN, SimEvent.IMPORTANCE_NOTABLE,
				0, "field_sown", "Aussaat abgeschlossen",
				_now() + config.field_grow_s)
			_field_set_stage(field, Building.FIELD_GROWING)
			field.field_growth_end = _now() + config.field_grow_s
			field.field_growth_gen += 1
			var payload: int = (field.id << 32) | (field.field_growth_gen & 0xFFFFFFFF)
			scheduler.push(field.field_growth_end, SimKinds.EVENT_FIELD_TICK,
				payload)
		Building.FIELD_HARVESTING:
			_apply_harvest(field)


## G3: Frühling pflügen/säen, Sommer wachsen, Herbst ernten, Winter Brache.
## Genau eine Ernte pro Feld und Jahr; Saatgut wird beim Abschluss der Aussaat
## aus dem Kornspeicher abgezogen.
func _field_add_work_seasonal(field: Building, seconds: int) -> void:
	var day: int = clock.day_index()
	var year: int = config.year_of_day(day)
	var required: int = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			if not config.is_spring_day(day):
				return
			required = config.field_plow_work_s
		Building.FIELD_SOWING:
			if not config.is_spring_day(day):
				return
			required = config.field_sow_work_s
		Building.FIELD_HARVESTING:
			if not config.is_autumn_day(day):
				return
			required = config.field_harvest_work_s
	if required <= 0:
		return
	field.field_work_s += seconds
	if field.field_work_s < required:
		return
	field.field_work_s = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			_field_set_stage(field, Building.FIELD_PLOWED)
		Building.FIELD_SOWING:
			var host = _host()
			if config.field_seed_cost > 0 and host.grain < config.field_seed_cost:
				_field_set_stage(field, Building.FIELD_PLOWED)
				if field.field_last_shortage_day != day:
					field.field_last_shortage_day = day
					host.log_event(SimEvent.T_FIELD_STAGE,
						SimEvent.IMPORTANCE_NOTABLE, 0, "field_stage",
						"kein Saatgut", field.id)
				return
			if config.field_seed_cost > 0:
				host.grain -= config.field_seed_cost
				host.grain_seed_used += config.field_seed_cost
			field.field_crop_year = year
			var grow_end: int = config.autumn_start_day(day) \
				* SimConfig.TICKS_PER_DAY
			if grow_end <= _now():
				grow_end = config.next_year_start_day(day) \
					* SimConfig.TICKS_PER_DAY
			_field_set_stage(field, Building.FIELD_SOWN)
			host.log_event(SimEvent.T_FIELD_SOWN, SimEvent.IMPORTANCE_NOTABLE,
				0, "field_sown", "Aussaat abgeschlossen", grow_end)
			_field_set_stage(field, Building.FIELD_GROWING)
			field.field_growth_end = grow_end
			field.field_growth_gen += 1
			var payload: int = (field.id << 32) \
				| (field.field_growth_gen & 0xFFFFFFFF)
			scheduler.push(field.field_growth_end, SimKinds.EVENT_FIELD_TICK,
				payload)
		Building.FIELD_HARVESTING:
			_apply_harvest(field)


func _apply_harvest(field: Building) -> void:
	var host = _host()
	var yield_grain: int = config.field_harvest_yield
	var overflow: int = 0
	if config.granary_capacity > 0:
		var room: int = maxi(0, config.granary_capacity - host.grain)
		if yield_grain > room:
			overflow = yield_grain - room
			yield_grain = room
	host.grain += yield_grain
	host.grain_produced += yield_grain
	host.grain_harvested += yield_grain
	host.grain_overflow += overflow
	host.harvests_completed += 1
	host.field_cycles_completed += 1
	host.year_grain_produced += yield_grain
	host.year_harvests += 1
	var season: int = config.season_index_for_day(clock.day_index())
	if season >= 0 and season < host.harvest_season_counts.size():
		host.harvest_season_counts[season] += 1
	if config.seasonal_fields:
		field.field_harvested_year = config.year_of_day(clock.day_index())
	host.log_event(SimEvent.T_FIELD_HARVEST, SimEvent.IMPORTANCE_MAJOR,
		0, "field_harvest", "Ernte eingelagert", yield_grain)
	_field_set_stage(field, Building.FIELD_FALLOW)


func on_field_tick(field_id: int, gen: int) -> void:
	var resolved_id: int = field_id if field_id > 0 else _field_id_for_row(0)
	var field: Building = world.building_by_id(resolved_id)
	if field == null:
		return
	if field.field_stage != Building.FIELD_GROWING:
		return
	if gen != field.field_growth_gen:
		return
	if _now() < field.field_growth_end:
		return
	_field_set_stage(field, Building.FIELD_RIPE)
	_host().log_event(SimEvent.T_FIELD_RIPE, SimEvent.IMPORTANCE_NOTABLE,
		0, "field_ripe", "Feld ist reif", field.field_growth_end)


## Punkte für das deterministische Cache-Prewarming. Nur Lesen, keine
## Simulationseffekte; der Pfad-Cache bleibt abgeleitet.
func warmup_points(row: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.append(Vector2(store.pos_x[row], store.pos_y[row]))
	out.append(_home_point(row))
	out.append(_field_point(row))
	out.append(_workshop_point(row))
	out.append(_plaza_point(row))
	out.append(_well_point(row))
	if store.route_id[row] >= 0:
		out.append(Vector2(store.travel_start_x[row], store.travel_start_y[row]))
		out.append(Vector2(store.travel_end_x[row], store.travel_end_y[row]))
	return out


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
