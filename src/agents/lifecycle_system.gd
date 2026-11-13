class_name LifecycleSystem
extends RefCounted

## G1b-Schritt 2: Alterung, Sterblichkeit, Partnerschaft, Geburt und
## Haushaltsauflösung.
##
## Orchestrierung liegt hier; die reinen Regeln (Alter, Sterblichkeit,
## Fertilität) liegen in LifecycleRules und werden von der synthetischen
## Demografie-Kohorte exakt gleich genutzt.
##
## Zeitmodell: Alterung wird an jedem Tages-Tick geprüft. Sterblichkeit,
## Partnerschaft und Fertilität laufen auf festen Roll-Tagen (Default alle 5
## Sim-Tage ab Tag 10). Es gibt keinen Full-Agent-Sweep pro Frame.
##
## Kein starker Rückverweis auf Simulation (kein RefCounted-Zyklus).

## Schwacher Rückverweis: Simulation hält LifecycleSystem, LifecycleSystem darf
## die Simulation nicht stark halten (RefCounted-Zyklus/Leak).
var _sim_ref: WeakRef


func _init(sim_ref = null) -> void:
	_sim_ref = weakref(sim_ref)


func _sim():
	return _sim_ref.get_ref()


func _store() -> AgentStore:
	return _sim().store


func _config() -> SimConfig:
	return _sim().config


func _now() -> int:
	return _sim().clock.now


func on_day_tick(day: int) -> void:
	_update_birthdays(day)
	if _is_roll_day(day):
		_run_month(day)


func _is_roll_day(day: int) -> bool:
	var first: int = _config().lifecycle_first_roll_day
	var interval: int = maxi(1, _config().lifecycle_roll_interval_days)
	return day >= first and (day - first) % interval == 0


func _update_birthdays(day: int) -> void:
	var store: AgentStore = _store()
	for row in store.count:
		if store.alive[row] == 0:
			continue
		var new_age: int = LifecycleRules.age_from_birth_day(store.birth_day[row], day)
		if new_age <= store.age_years[row]:
			continue
		store.age_years[row] = new_age
		var rec: AgentRecord = _record(store.ids[row])
		if rec != null:
			rec.age_years = new_age
		_sim().log_event(SimEvent.T_AGE_UP, SimEvent.IMPORTANCE_ROUTINE,
			store.ids[row], "age_up", "Alter %d" % new_age, new_age)
		var new_role: int = LifecycleRules.role_for_age(new_age)
		if new_role != store.role[row]:
			_apply_role_change(row, new_role)


func _apply_role_change(row: int, new_role: int) -> void:
	var store: AgentStore = _store()
	var old_role: int = store.role[row]
	store.role[row] = new_role
	var rec: AgentRecord = _record(store.ids[row])
	var job_id: int = store.job_id[row]
	var job_kind: int = store.job_kind[row]
	match new_role:
		AgentStore.ROLE_CHILD:
			job_id = 0
			job_kind = AgentStore.JOB_NONE
		AgentStore.ROLE_YOUTH:
			job_id = AgentRecords.JOB_APPRENTICE
			job_kind = AgentStore.JOB_WORKSHOP
		AgentStore.ROLE_ADULT:
			job_id = AgentRecords.JOB_FIELD
			job_kind = AgentStore.JOB_FIELD
		AgentStore.ROLE_OLD:
			job_id = AgentRecords.JOB_LIGHT
			job_kind = AgentStore.JOB_WORKSHOP
	store.job_id[row] = job_id
	store.job_kind[row] = job_kind
	if rec != null:
		rec.role = new_role
		rec.job_id = job_id
		rec.job_kind = job_kind
	_sim().log_event(SimEvent.T_ROLE_CHANGE, SimEvent.IMPORTANCE_NOTABLE,
		store.ids[row], "role_change", "%s -> %s" % [
			AgentStore.role_name(old_role), AgentStore.role_name(new_role)], new_role)
	_sim().request_wake_by_id(store.ids[row], _now() + SimConfig.MIN_WAKE_S)


func _run_month(day: int) -> void:
	_process_births(day)
	_settle_all()
	_process_mortality(day)
	_form_partnerships(day)
	_process_conceptions(day)
	_sim().lifecycle_ticks += 1


func _process_births(day: int) -> void:
	var store: AgentStore = _store()
	var now: int = _now()
	var n: int = store.count
	for row in n:
		if store.alive[row] == 0 or store.pregnant[row] == 0:
			continue
		if now < store.pregnancy_due[row]:
			continue
		_give_birth(row, day)


func _settle_all() -> void:
	var store: AgentStore = _store()
	var now: int = _now()
	var n: int = store.count
	for row in n:
		if store.alive[row] != 0:
			NeedsModel.settle(store, row, now, _config())


func _process_mortality(day: int) -> void:
	var store: AgentStore = _store()
	var rng: RngStream = _sim().rng.get_stream("lifecycle")
	var n: int = store.count
	for row in n:
		if store.alive[row] == 0:
			continue
		# Neugeborene werden am Geburtstag nicht sofort erneut gewürfelt.
		if store.birth_day[row] == day:
			continue
		var age: int = store.age_years[row]
		var health: float = store.health[row]
		var chance: float = LifecycleRules.monthly_death_chance(_config(), age, health)
		if rng.next_unit() >= chance:
			continue
		var cause: int = LifecycleRules.death_cause(_config(), age, health)
		kill_agent(store.ids[row], cause)


func _form_partnerships(day: int) -> void:
	var store: AgentStore = _store()
	var eligible: PackedInt32Array = PackedInt32Array()
	for row in store.count:
		if store.alive[row] == 0:
			continue
		var age: int = store.age_years[row]
		if age < _config().pair_min_age or age > _config().pair_max_age:
			continue
		eligible.append(store.ids[row])
	eligible.sort()
	for i in eligible.size():
		var a: int = eligible[i]
		if not _is_alive(a) or partner_of(a) > 0:
			continue
		var row_a: int = store.row_for_id(a)
		var age_a: int = store.age_years[row_a]
		var sex_a: int = store.sex[row_a]
		for j in range(i + 1, eligible.size()):
			var b: int = eligible[j]
			if not _is_alive(b) or partner_of(b) > 0:
				continue
			var row_b: int = store.row_for_id(b)
			var age_b: int = store.age_years[row_b]
			var sex_b: int = store.sex[row_b]
			if not LifecycleRules.can_pair(_config(), age_a, sex_a, age_b, sex_b):
				continue
			if has_direct_kin(a, b):
				continue
			_form_partnership(a, b, day)
			break


func _form_partnership(a: int, b: int, day: int) -> void:
	add_relationship(RelationshipRecord.TYPE_PARTNER, a, b, 80, day)
	add_relationship(RelationshipRecord.TYPE_PARTNER, b, a, 80, day)
	_sim().partnerships_formed += 1
	_sim().log_event(SimEvent.T_PARTNER_FORMED, SimEvent.IMPORTANCE_NOTABLE,
		a, "partner_formed", "Partnerschaft", b)


func _process_conceptions(day: int) -> void:
	var store: AgentStore = _store()
	var rng: RngStream = _sim().rng.get_stream("lifecycle")
	var n: int = store.count
	for row in n:
		if store.alive[row] == 0 or store.pregnant[row] != 0:
			continue
		if store.sex[row] != LifecycleRules.SEX_FEMALE:
			continue
		var age: int = store.age_years[row]
		if not LifecycleRules.is_fertile_female(_config(), age):
			continue
		var partner: int = partner_of(store.ids[row])
		if partner <= 0 or not _is_alive(partner):
			continue
		var partner_row: int = store.row_for_id(partner)
		if not LifecycleRules.is_fertile_male(_config(), store.age_years[partner_row]):
			continue
		var chance: float = LifecycleRules.monthly_conception_chance(_config(), age)
		if rng.next_unit() >= chance:
			continue
		store.pregnant[row] = 1
		store.pregnancy_father_id[row] = partner
		store.pregnancy_due[row] = _now() + _config().pregnancy_ticks \
			* _config().lifecycle_roll_interval_days * SimConfig.TICKS_PER_DAY
		_sim().log_event(SimEvent.T_PREGNANCY, SimEvent.IMPORTANCE_NOTABLE,
			store.ids[row], "pregnancy", "Schwangerschaft", partner)


func _give_birth(row: int, day: int) -> void:
	var store: AgentStore = _store()
	var mother_id: int = store.ids[row]
	var father_id: int = store.pregnancy_father_id[row]
	var household_id: int = store.household_id[row]
	var home_id: int = store.home_id[row]
	store.pregnant[row] = 0
	store.pregnancy_due[row] = 0
	store.pregnancy_father_id[row] = 0
	var child_id: int = store.next_id
	var rng: RngStream = _sim().rng.get_stream("lifecycle")
	var child_sex: int = rng.next_range(2)
	var child_name: String = LifecycleRules.name_for(child_sex, child_id)
	var home_point: Vector2 = _sim().world.door_point(home_id)
	if home_id <= 0:
		home_point = Vector2.ZERO
	home_point = _sim().world.clamp_point(home_point + Vector2(
		float((child_id % 4) - 1.5) * 1.2, 0.0))
	var new_id: int = store.spawn_agent(0, AgentStore.ROLE_CHILD, household_id,
		home_id, 0, AgentStore.JOB_NONE, home_point.x, home_point.y,
		_config().start_hunger, _config().start_energy, _config().start_social,
		_now(), _config().start_hygiene, _config().start_fun,
		_config().start_health, child_sex, day)
	var rec: AgentRecord = AgentRecord.new(new_id, child_name, child_sex, 0,
		AgentStore.ROLE_CHILD, household_id, home_id, 0, AgentStore.JOB_NONE, day)
	_sim().records.append(rec)
	var household: HouseholdRecord = household_by_id(household_id)
	if household != null and household.is_active():
		_add_to_household_sorted(household, new_id)
	add_relationship(RelationshipRecord.TYPE_PARENT, mother_id, new_id, 90, day)
	add_relationship(RelationshipRecord.TYPE_CHILD, new_id, mother_id, 90, day)
	if father_id > 0:
		add_relationship(RelationshipRecord.TYPE_PARENT, father_id, new_id, 90, day)
		add_relationship(RelationshipRecord.TYPE_CHILD, new_id, father_id, 90, day)
	_sim().births += 1
	_sim().log_event(SimEvent.T_BIRTH, SimEvent.IMPORTANCE_MAJOR,
		new_id, "birth", "Geburt: %s" % child_name, mother_id)
	_sim().request_wake_by_id(new_id, _now() + SimConfig.MIN_WAKE_S)
	# Geburtsrisiko: die Mutter kann bei der Geburt sterben. Das Kind bleibt
	# mit beiden Elternbeziehungen (auch zu einem toten Vater) bestehen.
	if rng.next_unit() < _config().birth_death_chance:
		kill_agent(mother_id, LifecycleRules.CAUSE_BIRTH)


## Öffentlich für Todes-/Haushaltstests und schwere Gesundheitsfolgen.
func kill_agent(agent_id: int, cause: int) -> void:
	var store: AgentStore = _store()
	var row: int = store.row_for_id(agent_id)
	if row < 0 or store.alive[row] == 0:
		return
	var day: int = _sim().clock.day_index()
	store.alive[row] = 0
	store.death_day[row] = day
	store.death_cause[row] = cause
	store.pregnant[row] = 0
	store.pregnancy_due[row] = 0
	store.pregnancy_father_id[row] = 0
	store.activity[row] = AgentStore.ACT_IDLE
	store.intent[row] = AgentStore.ACT_IDLE
	store.action_source[row] = 0
	store.action_end[row] = 0
	store.route_id[row] = -1
	store.work_start[row] = -1
	store.work_end[row] = -1
	store.wake_gen[row] = (store.wake_gen[row] + 1) & 0x7FFFFFFF
	store.next_event[row] = 0
	var rec: AgentRecord = _record(agent_id)
	if rec != null:
		rec.death_day = day
		rec.death_cause = cause
	var old_household: int = store.household_id[row]
	_remove_from_household(old_household, agent_id)
	_sim().deaths += 1
	_sim().log_event(SimEvent.T_DEATH, SimEvent.IMPORTANCE_MAJOR,
		agent_id, "death", "Tod: %s" % LifecycleRules.cause_name(cause), cause)
	_resolve_household(old_household, day)


func _resolve_household(old_household: int, day: int) -> void:
	if old_household <= 0:
		return
	var household: HouseholdRecord = household_by_id(old_household)
	if household == null or not household.is_active():
		return
	var store: AgentStore = _store()
	var have_guardian: bool = false
	for member in household.member_ids:
		var mrow: int = store.row_for_id(member)
		if mrow >= 0 and store.alive[mrow] != 0 \
				and LifecycleRules.is_guardian(store.age_years[mrow]):
			have_guardian = true
			break
	if have_guardian:
		return
	var archive: PackedInt32Array = household.member_ids.duplicate()
	var minors: PackedInt32Array = PackedInt32Array()
	for member in household.member_ids:
		var mrow2: int = store.row_for_id(member)
		if mrow2 >= 0 and store.alive[mrow2] != 0 \
				and LifecycleRules.is_minor(store.age_years[mrow2]):
			minors.append(member)
	for minor in minors:
		_assign_minor(minor, old_household, day)
	household.dissolved = 1
	household.dissolved_day = day
	household.dissolved_reason = LifecycleRules.REASON_LAST_ADULT
	household.archived_member_ids = archive
	household.member_ids.clear()
	_sim().households_dissolved += 1
	_sim().log_event(SimEvent.T_HOUSEHOLD_DISSOLVED, SimEvent.IMPORTANCE_MAJOR,
		0, "household_dissolved", "Haushalt aufgelöst", old_household)


func _assign_minor(minor_id: int, old_household: int, day: int) -> void:
	var target: int = _find_related_household(minor_id, old_household)
	var store: AgentStore = _store()
	var row: int = store.row_for_id(minor_id)
	if target > 0 and row >= 0:
		var target_household: HouseholdRecord = household_by_id(target)
		if target_household != null and target_household.is_active():
			_remove_from_household(old_household, minor_id)
			_add_to_household_sorted(target_household, minor_id)
			store.household_id[row] = target
			store.home_id[row] = target_household.home_building_id
			var rec: AgentRecord = _record(minor_id)
			if rec != null:
				rec.household_id = target
				rec.home_building_id = target_household.home_building_id
			_sim().log_event(SimEvent.T_HOUSEHOLD_REASSIGN, SimEvent.IMPORTANCE_NOTABLE,
				minor_id, "household_reassign", "Haushalt zugeordnet", target)
			_sim().request_wake_by_id(minor_id, _now() + SimConfig.MIN_WAKE_S)
			return
	# Kein verwandter Erwachsener: expliziter Zustand "kein Haushalt" (0).
	# home_id bleibt ein gültiges Gebäude; es entsteht keine Dangling-Referenz.
	if row >= 0:
		store.household_id[row] = 0
		var rec2: AgentRecord = _record(minor_id)
		if rec2 != null:
			rec2.household_id = 0
		_sim().log_event(SimEvent.T_HOUSEHOLD_WARD, SimEvent.IMPORTANCE_NOTABLE,
			minor_id, "household_ward", "kein Haushalt", old_household)


func _find_related_household(minor_id: int, old_household: int) -> int:
	var store: AgentStore = _store()
	var best_household: int = 0
	var best_priority: int = 99
	var best_relative: int = 0x7FFFFFFF
	for relationship in _sim().relationships:
		var rel: RelationshipRecord = relationship
		var relative: int = 0
		var priority: int = 2
		if rel.type == RelationshipRecord.TYPE_PARENT \
				and rel.b_agent_id == minor_id:
			relative = rel.a_agent_id
			priority = 0
		elif rel.type == RelationshipRecord.TYPE_GRANDPARENT \
				and rel.b_agent_id == minor_id:
			relative = rel.a_agent_id
			priority = 1
		elif rel.type == RelationshipRecord.TYPE_CHILD \
				and rel.a_agent_id == minor_id:
			relative = rel.b_agent_id
			priority = 0
		else:
			continue
		if relative <= 0 or not _is_alive(relative):
			continue
		var relative_row: int = store.row_for_id(relative)
		if relative_row < 0:
			continue
		var age: int = store.age_years[relative_row]
		if not LifecycleRules.is_guardian(age):
			continue
		var hid: int = store.household_id[relative_row]
		if hid <= 0 or hid == old_household:
			continue
		var household: HouseholdRecord = household_by_id(hid)
		if household == null or not household.is_active():
			continue
		if priority < best_priority \
				or (priority == best_priority and hid < best_household) \
				or (priority == best_priority and hid == best_household
					and relative < best_relative):
			best_priority = priority
			best_household = hid
			best_relative = relative
	return best_household


func _remove_from_household(household_id: int, agent_id: int) -> void:
	var household: HouseholdRecord = household_by_id(household_id)
	if household == null:
		return
	var out: PackedInt32Array = PackedInt32Array()
	for member in household.member_ids:
		if member != agent_id:
			out.append(member)
	household.member_ids = out


func _add_to_household_sorted(household: HouseholdRecord, agent_id: int) -> void:
	var out: PackedInt32Array = PackedInt32Array()
	var inserted: bool = false
	for member in household.member_ids:
		if not inserted and agent_id < member:
			out.append(agent_id)
			inserted = true
		if member != agent_id:
			out.append(member)
	if not inserted:
		out.append(agent_id)
	household.member_ids = out


func household_by_id(household_id: int) -> HouseholdRecord:
	for household in _sim().households:
		if (household as HouseholdRecord).id == household_id:
			return household
	return null


func _record(agent_id: int) -> AgentRecord:
	return AgentRecords.record_by_id(_sim().records, agent_id)


func _is_alive(agent_id: int) -> bool:
	var row: int = _store().row_for_id(agent_id)
	return row >= 0 and _store().alive[row] != 0


## Lebender Partner; historische Partnerbeziehungen zu Toten blockieren nicht.
func partner_of(agent_id: int) -> int:
	if not _is_alive(agent_id):
		return 0
	for relationship in _sim().relationships:
		var rel: RelationshipRecord = relationship
		if rel.type != RelationshipRecord.TYPE_PARTNER:
			continue
		var other: int = 0
		if rel.a_agent_id == agent_id:
			other = rel.b_agent_id
		elif rel.b_agent_id == agent_id:
			other = rel.a_agent_id
		else:
			continue
		if other > 0 and _is_alive(other):
			return other
	return 0


func has_direct_kin(a: int, b: int) -> bool:
	for relationship in _sim().relationships:
		var rel: RelationshipRecord = relationship
		if rel.type != RelationshipRecord.TYPE_PARENT \
				and rel.type != RelationshipRecord.TYPE_CHILD \
				and rel.type != RelationshipRecord.TYPE_GRANDPARENT:
			continue
		if (rel.a_agent_id == a and rel.b_agent_id == b) \
				or (rel.a_agent_id == b and rel.b_agent_id == a):
			return true
	return false


func add_relationship(rel_type: int, a: int, b: int, strength: int,
		since_day: int) -> RelationshipRecord:
	var next_id: int = 1
	for relationship in _sim().relationships:
		var rel: RelationshipRecord = relationship
		if rel.id >= next_id:
			next_id = rel.id + 1
	var record: RelationshipRecord = RelationshipRecord.new(next_id, rel_type,
		a, b, strength, since_day)
	_sim().relationships.append(record)
	return record


## Prüft Haushaltszuordnung und Home-Referenzen. Leer = konsistent.
func validate_households() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var store: AgentStore = _store()
	for row in store.count:
		if store.alive[row] == 0:
			continue
		var agent_id: int = store.ids[row]
		if _sim().world.building_by_id(store.home_id[row]) == null:
			errors.append("A%d home_id %d fehlt" % [agent_id, store.home_id[row]])
		var hid: int = store.household_id[row]
		if hid == 0:
			continue
		var household: HouseholdRecord = household_by_id(hid)
		if household == null:
			errors.append("A%d household_id %d fehlt" % [agent_id, hid])
			continue
		if not household.is_active():
			errors.append("A%d household_id %d ist aufgelöst" % [agent_id, hid])
		if not household.member_ids.has(agent_id):
			errors.append("A%d fehlt in Haushalt %d" % [agent_id, hid])
	for household in _sim().households:
		var h: HouseholdRecord = household
		if not h.is_active():
			if h.member_ids.size() != 0:
				errors.append("aufgelöster Haushalt %d hat Mitglieder" % h.id)
			continue
		for member in h.member_ids:
			var mrow: int = store.row_for_id(member)
			if mrow < 0 or store.alive[mrow] == 0:
				errors.append("Haushalt %d enthält tote/unbekannte A%d" % [h.id, member])
				continue
			if store.household_id[mrow] != h.id:
				errors.append("A%d zeigt nicht auf Haushalt %d" % [member, h.id])
	return errors
