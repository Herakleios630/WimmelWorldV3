class_name NeedActions
extends RefCounted

## Need-getriebene Aktionen (Essen, Schlafen, Sozial, Hygiene, Spielen) und
## die zugehörigen deterministischen Zielpunkte. Aus DecisionSystem
## ausgelagert; das Verhalten bleibt unverändert. Das 10k-Profil teilt
## Home-/Werkstattpunkte pro Gebäude, damit Pfade wiederverwendet werden.

const NEED_HUNGER: int = 0
const NEED_ENERGY: int = 1
const NEED_SOCIAL: int = 2
const NEED_HYGIENE: int = 3
const NEED_FUN: int = 4

const NEAR_DISTANCE: float = 0.6
const MAX_NAP_S: int = 6 * 3600

## Schwacher Rückverweis: DecisionSystem hält NeedActions stark.
var _d_ref: WeakRef
var _home_points: PackedVector2Array = PackedVector2Array()
var _workshop_points: PackedVector2Array = PackedVector2Array()
var _plaza_points: PackedVector2Array = PackedVector2Array()
var _well_points: PackedVector2Array = PackedVector2Array()


func _init(host) -> void:
	_d_ref = weakref(host)


func _d():
	return _d_ref.get_ref()


func ensure_rows() -> void:
	var count: int = _d().store.count
	if _home_points.size() >= count:
		return
	var old_size: int = _home_points.size()
	_home_points.resize(count)
	_workshop_points.resize(count)
	_plaza_points.resize(count)
	_well_points.resize(count)
	for row in range(old_size, count):
		_home_points[row] = _home_point_uncached(row)
		_workshop_points[row] = _workshop_point_uncached(row)
		_plaza_points[row] = _plaza_point_uncached(row)
		_well_points[row] = _well_point_uncached(row)


func home_point(row: int) -> Vector2:
	ensure_rows()
	return _home_points[row]


func workshop_point(row: int) -> Vector2:
	ensure_rows()
	return _workshop_points[row]


func plaza_point(row: int) -> Vector2:
	ensure_rows()
	return _plaza_points[row]


func well_point(row: int) -> Vector2:
	ensure_rows()
	return _well_points[row]


func _home_point_uncached(row: int) -> Vector2:
	var base: Vector2 = _d().world.door_point(_d().store.home_id[row])
	if _d().config.is_scale():
		return base
	return _d().world.clamp_point(base + Vector2(
		(float(row % 4) - 1.5) * 1.2, 0.0))


func _workshop_point_uncached(row: int) -> Vector2:
	var base: Vector2 = _d().world.door_point(_d().world.workshop_id_for_row(row))
	if _d().config.is_scale():
		return base
	return _d().world.clamp_point(base + Vector2(float((row % 3) - 1) * 1.4, 0.0))


func _plaza_point_uncached(row: int) -> Vector2:
	var dx: float = float((row % 5) - 2) * 1.0
	var dy: float = float((row / 5) % 2) * 1.5
	return _d().world.clamp_point(_d().world.plaza_point + Vector2(dx, dy))


func _well_point_uncached(row: int) -> Vector2:
	var base: Vector2 = _d().world.door_point(_d().world.well_id())
	return _d().world.clamp_point(base + Vector2(float((row % 3) - 1) * 0.8, 0.0))


func resolve_place(row: int, place: int) -> Array:
	var home_id: int = _d().store.home_id[row]
	var home: Vector2 = home_point(row)
	match place:
		RoleSchedule.PLACE_FIELD:
			var field_id: int = _d().fields.field_id_for_row(row)
			var field: Building = _d().world.building_by_id(field_id)
			if not _d().fields.field_actionable(field):
				return [_d().world.workshop_id_for_row(row), workshop_point(row)]
			return [field_id, _d().fields.field_point(row)]
		RoleSchedule.PLACE_WORKSHOP:
			return [_d().world.workshop_id_for_row(row), workshop_point(row)]
		RoleSchedule.PLACE_PLAZA:
			return [_d().world.well_id(), plaza_point(row)]
		RoleSchedule.PLACE_JOB:
			if _d().store.job_kind[row] == AgentStore.JOB_FIELD:
				var fid: int = _d().fields.field_id_for_row(row)
				var field2: Building = _d().world.building_by_id(fid)
				if not _d().fields.field_actionable(field2):
					return [_d().world.workshop_id_for_row(row), workshop_point(row)]
				return [fid, _d().fields.field_point(row)]
			if _d().store.job_kind[row] == AgentStore.JOB_WORKSHOP:
				return [_d().world.workshop_id_for_row(row), workshop_point(row)]
			return [home_id, home]
		_:
			return [home_id, home]


func start_need_action(row: int, now: int, need: int) -> void:
	var agent_id: int = _d()._agent_id(row)
	(_d()._host()).log_event(SimEvent.T_NEED_INTERRUPT, SimEvent.IMPORTANCE_NOTABLE,
		agent_id, "need_interrupt", NeedsModel.need_name(need), need)
	var home_id: int = _d().store.home_id[row]
	var home: Vector2 = home_point(row)
	if need == NEED_HUNGER:
		_d().store.target_building_id[row] = home_id
		_d().store.target_x[row] = home.x
		_d().store.target_y[row] = home.y
		if _near(row, home):
			_d()._begin_action(row, AgentStore.ACT_EAT, now,
				now + SimConfig.MEAL_DURATION_S, DecisionSystem.SOURCE_NEED)
		else:
			_d()._start_travel(row, AgentStore.ACT_EAT, home_id, home,
				DecisionSystem.SOURCE_NEED, -1, SimConfig.MEAL_DURATION_S)
	elif need == NEED_ENERGY:
		var nap_s: int = nap_duration(row)
		_d().store.target_building_id[row] = home_id
		_d().store.target_x[row] = home.x
		_d().store.target_y[row] = home.y
		if _near(row, home):
			var end_time: int = _d()._extend_sleep_if_needed(now + nap_s, row)
			_d()._begin_action(row, AgentStore.ACT_SLEEP, now, end_time,
				DecisionSystem.SOURCE_NEED)
		else:
			_d()._start_travel(row, AgentStore.ACT_SLEEP, home_id, home,
				DecisionSystem.SOURCE_NEED, -1, nap_s)
	elif need == NEED_SOCIAL:
		var plaza: Vector2 = plaza_point(row)
		_d().store.target_building_id[row] = _d().world.well_id()
		_d().store.target_x[row] = plaza.x
		_d().store.target_y[row] = plaza.y
		if _near(row, plaza):
			_d()._begin_action(row, AgentStore.ACT_SOCIAL, now,
				now + SimConfig.SOCIAL_DURATION_S, DecisionSystem.SOURCE_NEED)
		else:
			_d()._start_travel(row, AgentStore.ACT_SOCIAL, _d().world.well_id(), plaza,
				DecisionSystem.SOURCE_NEED, -1, SimConfig.SOCIAL_DURATION_S)
	elif need == NEED_HYGIENE:
		var well: Vector2 = well_point(row)
		_d().store.target_building_id[row] = _d().world.well_id()
		_d().store.target_x[row] = well.x
		_d().store.target_y[row] = well.y
		if _near(row, well):
			_d()._begin_action(row, AgentStore.ACT_HYGIENE, now,
				now + SimConfig.HYGIENE_DURATION_S, DecisionSystem.SOURCE_NEED)
		else:
			_d()._start_travel(row, AgentStore.ACT_HYGIENE, _d().world.well_id(), well,
				DecisionSystem.SOURCE_NEED, -1, SimConfig.HYGIENE_DURATION_S)
	elif need == NEED_FUN:
		var leisure: Vector2 = plaza_point(row)
		_d().store.target_building_id[row] = _d().world.well_id()
		_d().store.target_x[row] = leisure.x
		_d().store.target_y[row] = leisure.y
		if _near(row, leisure):
			_d()._begin_action(row, AgentStore.ACT_PLAY, now,
				now + SimConfig.FUN_DURATION_S, DecisionSystem.SOURCE_NEED)
		else:
			_d()._start_travel(row, AgentStore.ACT_PLAY, _d().world.well_id(), leisure,
				DecisionSystem.SOURCE_NEED, -1, SimConfig.FUN_DURATION_S)


func _near(row: int, point: Vector2) -> bool:
	return Vector2(_d().store.pos_x[row], _d().store.pos_y[row]).distance_to(point) \
		<= NEAR_DISTANCE


func nap_duration(row: int) -> int:
	var missing: float = maxf(0.0, SimConfig.NAP_TARGET_ENERGY - _d().store.energy[row])
	var sleep_rate: float = _d().config.energy_per_8h_sleep / (8.0 * 3600.0)
	var seconds: int = int(ceil(missing / sleep_rate))
	return clampi(seconds, 1800, MAX_NAP_S)


func finish_meal(row: int, now: int) -> void:
	var host = _d()._host()
	if host.grain >= SimConfig.MEAL_GRAIN_COST:
		host.grain -= SimConfig.MEAL_GRAIN_COST
		host.meals_served += 1
		host.year_meals_served += 1
		NeedsModel.apply_meal(_d().store, row, _d().config)
		_d().store.meal_retry[row] = 0
		host.log_event(SimEvent.T_MEAL_END, SimEvent.IMPORTANCE_ROUTINE,
			_d()._agent_id(row), "meal_end", "Mahlzeit beendet", host.grain)
	else:
		host.meals_skipped += 1
		host.year_meals_skipped += 1
		_d().store.meal_retry[row] = now + SimConfig.SHORTAGE_RETRY_S
		var day: int = _d().clock.day_index()
		var log_this_skip: bool = true
		if _d().config.uses_g3_schedule() and _d().store.shortage_logged_day[row] == day:
			log_this_skip = false
		if log_this_skip:
			host.log_event(SimEvent.T_MEAL_SKIPPED, SimEvent.IMPORTANCE_NOTABLE,
				_d()._agent_id(row), "meal_skipped", "kein Grain", host.grain)
		if _d().store.shortage_logged_day[row] != day:
			_d().store.shortage_logged_day[row] = day
			host.log_event(SimEvent.T_SHORTAGE, SimEvent.IMPORTANCE_MAJOR,
				_d()._agent_id(row), "shortage", "Nahrungsknappheit", host.grain)
	_d().store.activity[row] = AgentStore.ACT_IDLE


func finish_social(row: int, now: int) -> void:
	NeedsModel.apply_social(_d().store, row, _d().config)
	(_d()._host()).log_event(SimEvent.T_SOCIAL_END, SimEvent.IMPORTANCE_ROUTINE,
		_d()._agent_id(row), "social_end", "Sozialisieren beendet",
		int(round(_d().store.social[row])))
	_d().store.activity[row] = AgentStore.ACT_IDLE


func finish_play(row: int, now: int) -> void:
	NeedsModel.apply_fun(_d().store, row, _d().config)
	(_d()._host()).log_event(SimEvent.T_ACTIVITY_END, SimEvent.IMPORTANCE_ROUTINE,
		_d()._agent_id(row), "activity_end", "Spielen beendet", AgentStore.ACT_PLAY)
	_d().store.activity[row] = AgentStore.ACT_IDLE


func finish_hygiene(row: int, now: int) -> void:
	NeedsModel.apply_hygiene(_d().store, row, _d().config)
	(_d()._host()).log_event(SimEvent.T_ACTIVITY_END, SimEvent.IMPORTANCE_ROUTINE,
		_d()._agent_id(row), "activity_end", "Waschen beendet", AgentStore.ACT_HYGIENE)
	_d().store.activity[row] = AgentStore.ACT_IDLE


func finish_sleep(row: int, now: int) -> void:
	if _d().store.action_source[row] == DecisionSystem.SOURCE_NEED:
		(_d()._host()).log_event(SimEvent.T_NAP_END, SimEvent.IMPORTANCE_ROUTINE,
			_d()._agent_id(row), "nap_end", "Nickerchen beendet", 0)
	else:
		(_d()._host()).log_event(SimEvent.T_WAKE_UP, SimEvent.IMPORTANCE_ROUTINE,
			_d()._agent_id(row), "wake_up", "aufgewacht", 0)
	_d().store.activity[row] = AgentStore.ACT_IDLE
