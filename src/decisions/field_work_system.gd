class_name FieldWorkSystem
extends RefCounted

## Feldarbeit und saisonaler Feldzustand. Aus DecisionSystem ausgelagert, um
## den 10k-Hot-Path und die Welt-/Feldlogik getrennt zu halten. Das Verhalten
## ist identisch zu G1b/G2/G3; das 10k-Profil teilt nur die Feldzuordnung pro
## Haushalt und die Arbeitspunkte pro Feld, damit der Pfad-Cache wirkt.

## Schwacher Rückverweis: DecisionSystem hält FieldWorkSystem stark.
var _d_ref: WeakRef
var _field_ids: PackedInt32Array = PackedInt32Array()
var _field_work_points: PackedVector2Array = PackedVector2Array()
var _row_field_id: PackedInt32Array = PackedInt32Array()
var _row_field_point: PackedVector2Array = PackedVector2Array()


func _init(host) -> void:
	_d_ref = weakref(host)
	_field_ids = _d().world.field_ids()
	for field_id in _field_ids:
		_field_work_points.append(_d().world.field_work_point_for(field_id))


func _d():
	return _d_ref.get_ref()


func ensure_rows() -> void:
	var count: int = _d().store.count
	if _row_field_id.size() >= count:
		return
	var old_size: int = _row_field_id.size()
	_row_field_id.resize(count)
	_row_field_point.resize(count)
	for row in range(old_size, count):
		if _field_ids.is_empty():
			_row_field_id[row] = -1
			_row_field_point[row] = Vector2.ZERO
			continue
		var field_id: int = -1
		if _d().config.is_scale():
			field_id = _field_ids[_d().store.home_id[row] % _field_ids.size()]
		else:
			field_id = _field_ids[(row + _d().store.home_id[row]) % _field_ids.size()]
		_row_field_id[row] = field_id
		_row_field_point[row] = _point_for_field(field_id, row)


func field_id_for_row(row: int) -> int:
	ensure_rows()
	if row < 0 or row >= _row_field_id.size():
		return -1
	return _row_field_id[row]


func field_point(row: int) -> Vector2:
	ensure_rows()
	if row < 0 or row >= _row_field_point.size():
		return Vector2.ZERO
	return _row_field_point[row]


func _point_for_field(field_id: int, row: int) -> Vector2:
	if _d().config.is_scale():
		return _d().world.clamp_point(_d().world.field_work_point_for(field_id))
	var slot: int = (row * 3) % 5
	var dx: float = float((slot % 3) - 1) * 3.0
	var dy: float = (float(slot / 3) - 0.5) * 4.0
	return _d().world.clamp_point(_d().world.field_work_point_for(field_id)
		+ Vector2(dx, dy))


## Ein Feld ist nur im Frühling (pflügen/säen) und im Herbst (ernten)
## bearbeitbar. Außerhalb der Fenster gehen Feldarbeiter zur Werkstatt.
func field_actionable(field: Building) -> bool:
	if field == null or field.kind != Building.KIND_FIELD:
		return false
	if not _d().config.seasonal_fields:
		return true
	var day: int = _d().clock.day_index()
	var year: int = _d().config.year_of_day(day)
	if _d().config.is_spring_day(day):
		if field.field_crop_year == year:
			return false
		return field.field_stage == Building.FIELD_FALLOW \
			or field.field_stage == Building.FIELD_PLOWING \
			or field.field_stage == Building.FIELD_PLOWED \
			or field.field_stage == Building.FIELD_SOWING
	if _d().config.is_autumn_day(day):
		if field.field_harvested_year == year:
			return false
		return field.field_stage == Building.FIELD_RIPE \
			or field.field_stage == Building.FIELD_HARVESTING
	return false


func field_stage(field_id: int) -> int:
	var field: Building = _d().world.building_by_id(field_id)
	return field.field_stage if field != null else -1


func set_stage(field: Building, stage: int) -> void:
	field.field_stage = stage
	(_d()._host()).log_event(SimEvent.T_FIELD_STAGE, SimEvent.IMPORTANCE_NOTABLE,
		0, "field_stage", Building.field_stage_name(stage), stage)


## Beim Arbeitsbeginn werden FALLOW/PLOWED/RIPE in den jeweiligen
## Arbeitszustand überführt. Der Zustand ist sichtbar, bevor Fortschritt
## entsteht; es gibt keinen Instant-Abschluss.
func on_work_start(field_id: int) -> void:
	var field: Building = _d().world.building_by_id(field_id)
	if field == null or field.kind != Building.KIND_FIELD:
		return
	match field.field_stage:
		Building.FIELD_FALLOW:
			if _d().config.seasonal_fields and not _d().config.is_spring_day(_d().clock.day_index()):
				return
			if _d().config.seasonal_fields \
					and field.field_crop_year == _d().config.year_of_day(_d().clock.day_index()):
				return
			set_stage(field, Building.FIELD_PLOWING)
		Building.FIELD_PLOWED:
			if _d().config.seasonal_fields and not _d().config.is_spring_day(_d().clock.day_index()):
				return
			set_stage(field, Building.FIELD_SOWING)
		Building.FIELD_RIPE:
			if _d().config.seasonal_fields and not _d().config.is_autumn_day(_d().clock.day_index()):
				return
			set_stage(field, Building.FIELD_HARVESTING)


func add_work(field_id: int, seconds: int) -> void:
	var field: Building = _d().world.building_by_id(field_id)
	if field == null or field.kind != Building.KIND_FIELD or seconds <= 0:
		return
	if _d().config.seasonal_fields:
		_add_work_seasonal(field, seconds)
		return
	var required: int = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			required = _d().config.field_plow_work_s
		Building.FIELD_SOWING:
			required = _d().config.field_sow_work_s
		Building.FIELD_HARVESTING:
			required = _d().config.field_harvest_work_s
	if required <= 0:
		return
	field.field_work_s += seconds
	if field.field_work_s < required:
		return
	field.field_work_s = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			set_stage(field, Building.FIELD_PLOWED)
		Building.FIELD_SOWING:
			set_stage(field, Building.FIELD_SOWN)
			var host = _d()._host()
			host.log_event(SimEvent.T_FIELD_SOWN, SimEvent.IMPORTANCE_NOTABLE,
				0, "field_sown", "Aussaat abgeschlossen",
				_d()._now() + _d().config.field_grow_s)
			set_stage(field, Building.FIELD_GROWING)
			field.field_growth_end = _d()._now() + _d().config.field_grow_s
			field.field_growth_gen += 1
			var payload: int = (field.id << 32) | (field.field_growth_gen & 0xFFFFFFFF)
			_d().scheduler.push(field.field_growth_end, SimKinds.EVENT_FIELD_TICK,
				payload)
		Building.FIELD_HARVESTING:
			apply_harvest(field)


## Frühling pflügen/säen, Sommer wachsen, Herbst ernten, Winter Brache.
## Genau eine Ernte pro Feld und Jahr; saatgut wird bei Aussaat abgezogen.
func _add_work_seasonal(field: Building, seconds: int) -> void:
	var day: int = _d().clock.day_index()
	var year: int = _d().config.year_of_day(day)
	var required: int = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			if not _d().config.is_spring_day(day):
				return
			required = _d().config.field_plow_work_s
		Building.FIELD_SOWING:
			if not _d().config.is_spring_day(day):
				return
			required = _d().config.field_sow_work_s
		Building.FIELD_HARVESTING:
			if not _d().config.is_autumn_day(day):
				return
			required = _d().config.field_harvest_work_s
	if required <= 0:
		return
	field.field_work_s += seconds
	if field.field_work_s < required:
		return
	field.field_work_s = 0
	match field.field_stage:
		Building.FIELD_PLOWING:
			set_stage(field, Building.FIELD_PLOWED)
		Building.FIELD_SOWING:
			var host = _d()._host()
			if _d().config.field_seed_cost > 0 and host.grain < _d().config.field_seed_cost:
				set_stage(field, Building.FIELD_PLOWED)
				if field.field_last_shortage_day != day:
					field.field_last_shortage_day = day
					host.log_event(SimEvent.T_FIELD_STAGE,
						SimEvent.IMPORTANCE_NOTABLE, 0, "field_stage",
						"kein Saatgut", field.id)
				return
			if _d().config.field_seed_cost > 0:
				host.grain -= _d().config.field_seed_cost
				host.grain_seed_used += _d().config.field_seed_cost
			field.field_crop_year = year
			var grow_end: int = _d().config.autumn_start_day(day) \
				* SimConfig.TICKS_PER_DAY
			if grow_end <= _d()._now():
				grow_end = _d().config.next_year_start_day(day) \
					* SimConfig.TICKS_PER_DAY
			set_stage(field, Building.FIELD_SOWN)
			host.log_event(SimEvent.T_FIELD_SOWN, SimEvent.IMPORTANCE_NOTABLE,
				0, "field_sown", "Aussaat abgeschlossen", grow_end)
			set_stage(field, Building.FIELD_GROWING)
			field.field_growth_end = grow_end
			field.field_growth_gen += 1
			var payload: int = (field.id << 32) \
				| (field.field_growth_gen & 0xFFFFFFFF)
			_d().scheduler.push(field.field_growth_end, SimKinds.EVENT_FIELD_TICK,
				payload)
		Building.FIELD_HARVESTING:
			apply_harvest(field)


func apply_harvest(field: Building) -> void:
	var host = _d()._host()
	var yield_grain: int = _d().config.field_harvest_yield
	var overflow: int = 0
	if _d().config.granary_capacity > 0:
		var room: int = maxi(0, _d().config.granary_capacity - host.grain)
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
	var season: int = _d().config.season_index_for_day(_d().clock.day_index())
	if season >= 0 and season < host.harvest_season_counts.size():
		host.harvest_season_counts[season] += 1
	if _d().config.seasonal_fields:
		field.field_harvested_year = _d().config.year_of_day(_d().clock.day_index())
	host.log_event(SimEvent.T_FIELD_HARVEST, SimEvent.IMPORTANCE_MAJOR,
		0, "field_harvest", "Ernte eingelagert", yield_grain)
	set_stage(field, Building.FIELD_FALLOW)


func on_field_tick(field_id: int, gen: int) -> void:
	var resolved_id: int = field_id if field_id > 0 else field_id_for_row(0)
	var field: Building = _d().world.building_by_id(resolved_id)
	if field == null:
		return
	if field.field_stage != Building.FIELD_GROWING:
		return
	if gen != field.field_growth_gen:
		return
	if _d()._now() < field.field_growth_end:
		return
	set_stage(field, Building.FIELD_RIPE)
	(_d()._host()).log_event(SimEvent.T_FIELD_RIPE, SimEvent.IMPORTANCE_NOTABLE,
		0, "field_ripe", "Feld ist reif", field.field_growth_end)
