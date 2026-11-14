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
var fields: FieldWorkSystem
var work: WorkSystem
var needs_actions: NeedActions
var _mask_row: int = -1
var _mask_now: int = -1
var _mask_value: int = 0


func _init(sim_ref) -> void:
	_host_ref = weakref(sim_ref)
	config = sim_ref.config
	clock = sim_ref.clock
	store = sim_ref.store
	world = sim_ref.world
	routes = sim_ref.routes
	scheduler = sim_ref.scheduler
	logs = sim_ref.logs
	fields = FieldWorkSystem.new(self)
	work = WorkSystem.new(self)
	needs_actions = NeedActions.new(self)


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
	_mask_row = -1
	_mask_now = -1
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
				needs_actions.finish_sleep(row, now)
				continue
			break
		if act == AgentStore.ACT_EAT:
			if now >= store.action_end[row]:
				needs_actions.finish_meal(row, now)
				continue
			break
		if act == AgentStore.ACT_SOCIAL:
			if now >= store.action_end[row]:
				needs_actions.finish_social(row, now)
				continue
			break
		if act == AgentStore.ACT_WORK:
			if now >= store.work_end[row]:
				work.finish_work(row, now)
				continue
			var need_w: int = _need_urgency(row, now)
			if need_w >= 0:
				work.finish_work(row, now)
				needs_actions.start_need_action(row, now, need_w)
			break
		if act == AgentStore.ACT_HYGIENE:
			if now >= store.action_end[row]:
				needs_actions.finish_hygiene(row, now)
				continue
			break
		if act == AgentStore.ACT_LEARN:
			if now >= store.action_end[row]:
				store.activity[row] = AgentStore.ACT_IDLE
				continue
			var need_l: int = _need_urgency(row, now)
			if need_l >= 0:
				store.activity[row] = AgentStore.ACT_IDLE
				needs_actions.start_need_action(row, now, need_l)
			break
		if act == AgentStore.ACT_PLAY:
			if now >= store.action_end[row]:
				needs_actions.finish_play(row, now)
				continue
			var need_p: int = _need_urgency(row, now)
			if need_p >= 0:
				store.activity[row] = AgentStore.ACT_IDLE
				needs_actions.start_need_action(row, now, need_p)
			break
		# IDLE
		var need_i: int = _need_urgency(row, now)
		if need_i >= 0:
			needs_actions.start_need_action(row, now, need_i)
		else:
			_apply_routine(row, now)
		break
	schedule_next(row, now)


## G3-Routinejitter spreizt die 6-/7-/8-/13-/17-Uhr-Bursts deterministisch.
## Ohne Jitter würden 1000 Agenten im selben Batch einen Pfad anfordern; das
## 50-Lookup-Budget würde über viele Frames deferieren. Lange Fenster
## (Arbeit/Spiel/Sozial) streuen breiter als kurze Mahlzeiten. G1/G2 bleiben
## exakt beim bisherigen Zeitplan.
func _jitter_span_minutes(act: int) -> int:
	# 0..89 Minuten; die G3-Pläne haben 90-min-Mahlzeitenfenster und
	# ausreichend lange Arbeits-/Sozial-/Schlaffenster.
	if not config.is_scale():
		return 90
	# 10k: große Übergänge (Arbeit/Schlaf) breiter spreizen, kurze Fenster
	# (Mahlzeit/Sozial) weiterhin innerhalb ihres Planfensters halten.
	match act:
		AgentStore.ACT_EAT:
			return 90
		AgentStore.ACT_SOCIAL:
			return 60
		AgentStore.ACT_WORK, AgentStore.ACT_LEARN, AgentStore.ACT_PLAY:
			return 150
		AgentStore.ACT_SLEEP:
			return 240
	return 90


func _jitter_for_transition(row: int, at_abs: int) -> int:
	if not config.uses_g3_schedule():
		return 0
	var minute: int = (at_abs % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(store.role[row], minute,
		config.uses_g3_schedule())
	var span: int = _jitter_span_minutes(entry[2])
	if config.is_scale():
		return _agent_jitter(row, span) * 60
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
			config.uses_g3_schedule())
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


## 10k: Schwellen-Wakes deterministisch um 0..14 Minuten spreizen, damit
## nicht tausende Agenten im selben Sim-Frame denselben Need-Wake auslösen.
## Die Raten/Schwellen bleiben unverändert; nur der Prüftermin streut.
func _need_jitter(row: int) -> int:
	if not config.is_scale():
		return 0
	# Sekundengranularität über eine Stunde; 10k Agenten verteilen sich so auf
	# rund 3 Wakes/Sekunde statt auf Minutenbuckets.
	return _agent_jitter(row, 3600)


## Deterministischer Avalanche-Hash für Agenten-Jitter. Lineare Kombinationen
## aus id/home erzeugten bei 10k periodische Cluster (id und home korrelieren).
func _agent_jitter(row: int, span: int) -> int:
	var x: int = (store.ids[row] * 0x9E3779B1 \
		+ store.home_id[row] * 0x85EBCA6B) & 0x7FFFFFFF
	x = ((x ^ (x >> 13)) * 0x5BD1E995) & 0x7FFFFFFF
	x = x ^ (x >> 15)
	return posmod(x, maxi(1, span))


func _need_far_from_threshold(row: int, need: int) -> bool:
	if not config.uses_g3_schedule():
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


func _suppress_bits(row: int, now: int) -> int:
	if row == _mask_row and now == _mask_now:
		return _mask_value
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	_mask_value = RoleSchedule.suppress_mask(store.role[row], minute,
		config.uses_g3_schedule())
	_mask_row = row
	_mask_now = now
	return _mask_value


func _hunger_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_EAT:
		return true
	if now < store.meal_retry[row]:
		return true
	return (_suppress_bits(row, now) & RoleSchedule.SUPPRESS_HUNGER) != 0


func _energy_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return true
	return (_suppress_bits(row, now) & RoleSchedule.SUPPRESS_ENERGY) != 0


func _social_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_SOCIAL:
		return true
	return (_suppress_bits(row, now) & RoleSchedule.SUPPRESS_SOCIAL) != 0


func _hygiene_suppressed(row: int, now: int) -> bool:
	return store.activity[row] == AgentStore.ACT_HYGIENE


func _fun_suppressed(row: int, now: int) -> bool:
	if store.activity[row] == AgentStore.ACT_PLAY \
			or store.activity[row] == AgentStore.ACT_SOCIAL:
		return true
	return (_suppress_bits(row, now) & RoleSchedule.SUPPRESS_FUN) != 0


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
	var jitter: int = _need_jitter(row)
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
					store.role[row], AgentStore.ACT_EAT, config.uses_g3_schedule())
				if meal_in >= 0 and meal_in <= SimConfig.ROUTINE_LOOKAHEAD_S:
					return -1
				if dt0 < 0:
					return -1
				return now + dt0 + jitter
			var dt: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dt < 0 else now + dt + jitter
		NEED_ENERGY:
			if value <= config.energy_threshold:
				if _energy_suppressed(row, now):
					return -1
				return now
			var dte: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dte < 0 else now + dte + jitter
		NEED_SOCIAL:
			if value <= config.social_threshold:
				if _social_suppressed(row, now):
					return -1
				return now
			var dts: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dts < 0 else now + dts + jitter
		NEED_HYGIENE:
			if value <= config.hygiene_threshold:
				if _hygiene_suppressed(row, now):
					return -1
				return now
			var dth: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dth < 0 else now + dth + jitter
		NEED_FUN:
			if value <= config.fun_threshold:
				if _fun_suppressed(row, now):
					return -1
				return now
			var dtf: int = NeedsModel.seconds_to_threshold(store, row, now, need, config)
			return -1 if dtf < 0 else now + dtf + jitter
	return -1


## Dünne Zugriffe auf die ausgelagerten Aktionsmodule. Die Punkt-Caches sind
## abgeleitet und deterministisch; sie reduzieren bei 10k die Vektor-/Welt-
## Lookups pro Wake.
func _home_point(row: int) -> Vector2:
	return needs_actions.home_point(row)


func _field_id_for_row(row: int) -> int:
	return fields.field_id_for_row(row)


func _field_point(row: int) -> Vector2:
	return fields.field_point(row)


func _workshop_point(row: int) -> Vector2:
	return needs_actions.workshop_point(row)


func _field_actionable(field: Building) -> bool:
	return fields.field_actionable(field)


func _plaza_point(row: int) -> Vector2:
	return needs_actions.plaza_point(row)


func _well_point(row: int) -> Vector2:
	return needs_actions.well_point(row)


func _resolve_place(row: int, place: int) -> Array:
	return needs_actions.resolve_place(row, place)


func _apply_routine(row: int, now: int) -> void:
	var role: int = store.role[row]
	var minute: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = RoleSchedule.entry_at(role, minute,
		config.uses_g3_schedule())
	var act: int = entry[2]
	var end_abs: int = RoleSchedule.entry_end_abs(now, role, config.uses_g3_schedule())
	if act == AgentStore.ACT_SLEEP:
		end_abs = _extend_sleep_if_needed(end_abs, row)
	# G3: auch feste Aktionsenden (12:00/17:00/18:00/6:00) deterministisch
	# spreizen, damit nicht 1000 Agents im selben Batch enden.
	if config.uses_g3_schedule():
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
			minute, config.uses_g3_schedule())
		if entry[2] != AgentStore.ACT_SLEEP:
			break
		var entry_end: int = RoleSchedule.entry_end_abs(result, store.role[row],
			config.uses_g3_schedule())
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
			fields.on_work_start(store.target_building_id[row])
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



func on_field_tick(field_id: int, gen: int) -> void:
	fields.on_field_tick(field_id, gen)


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
		var total: float = routes.length(route)
		var traveled: float = 0.0
		if arrive > depart:
			traveled = total * float(t - depart) / float(arrive - depart)
		return WorldMap.point_on_polyline(points, traveled)
	return Vector2(store.pos_x[row], store.pos_y[row])
