class_name RoleSchedule
extends RefCounted

## Rollen-Schedules (v3-g1-spec.md §6). Eintrag = [start_min, end_min,
## activity, place]. Pläne decken 00:00..24:00 ohne Wrap ab.
## G1a ist ein vereinfachter Tagesablauf; keine Arbeitsfortschritts-Feinplanung
## pro Minute, sondern Übergänge und Need-Wakes.

const PLACE_HOME: int = 0
const PLACE_FIELD: int = 1
const PLACE_WORKSHOP: int = 2
const PLACE_PLAZA: int = 3
const PLACE_JOB: int = 4

const STRIDE: int = 4

## Pläne sind unveränderliche Daten. Sie werden einmal pro Rolle/Profil
## materialisiert, damit der Hot Path bei 10k keine Arrays pro Wake neu baut.
static var _plan_cache: Dictionary = {}
## Minuten-Tabellen pro Rolle/Profil: Aktivität, Ort, Endminute, nächster
## Übergang und nächster Start je Aktivität. O(1) statt Plan-Scan pro Wake.
static var _table_cache: Dictionary = {}
## Bitmaske je Rolle/Minute: 1=Hunger, 2=Energie, 4=Sozial, 8=Spaß werden
## durch die Routine unterdrückt. Spart mehrere Tabellen-Scans pro Wake.
static var _suppress_cache: Dictionary = {}

const SUPPRESS_HUNGER: int = 1
const SUPPRESS_ENERGY: int = 2
const SUPPRESS_SOCIAL: int = 4
const SUPPRESS_FUN: int = 8


static func plan_for_role(p_role: int, g3: bool = false) -> Array:
	var cache_key: int = (1 if g3 else 0) * 16 + p_role
	if _plan_cache.has(cache_key):
		return _plan_cache[cache_key]
	var plan: Array
	if g3:
		match p_role:
			AgentStore.ROLE_CHILD:
				plan = _g3_child_plan()
			AgentStore.ROLE_YOUTH:
				plan = _g3_youth_plan()
			AgentStore.ROLE_OLD:
				plan = _g3_old_plan()
			_:
				plan = _g3_adult_plan()
	else:
		match p_role:
			AgentStore.ROLE_CHILD:
				plan = _child_plan()
			AgentStore.ROLE_YOUTH:
				plan = _youth_plan()
			AgentStore.ROLE_OLD:
				plan = _old_plan()
			_:
				plan = _adult_plan()
	_plan_cache[cache_key] = plan
	return plan


## G3-Pläne: 1-Stunden-Mahlzeitenfenster und breitere Arbeits-/Sozialfenster.
## Das erlaubt deterministischen Routinejitter, ohne Mahlzeiten zu verpassen.
static func _g3_adult_plan() -> Array:
	return [
		PackedInt32Array([0, 360, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([360, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 510, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([510, 720, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([720, 810, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([810, 1020, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1200, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1200, 1260, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1260, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _g3_child_plan() -> Array:
	return [
		PackedInt32Array([0, 390, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([390, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 510, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([510, 720, AgentStore.ACT_LEARN, PLACE_HOME]),
		PackedInt32Array([720, 810, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([810, 840, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([840, 1020, AgentStore.ACT_PLAY, PLACE_PLAZA]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1200, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1200, 1230, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1230, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _g3_youth_plan() -> Array:
	return [
		PackedInt32Array([0, 390, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([390, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 510, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([510, 720, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([720, 810, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([810, 1020, AgentStore.ACT_LEARN, PLACE_WORKSHOP]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1200, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1200, 1260, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1260, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _g3_old_plan() -> Array:
	return [
		PackedInt32Array([0, 390, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([390, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 510, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([510, 570, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([570, 690, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([690, 720, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([720, 810, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([810, 900, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([900, 1020, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1080, 1200, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1200, 1230, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1230, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _adult_plan() -> Array:
	return [
		PackedInt32Array([0, 360, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([360, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 450, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([450, 480, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([480, 720, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([720, 750, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([750, 780, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([780, 1020, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1110, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1110, 1260, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1260, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _child_plan() -> Array:
	return [
		PackedInt32Array([0, 420, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([420, 450, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([450, 480, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([480, 720, AgentStore.ACT_LEARN, PLACE_HOME]),
		PackedInt32Array([720, 750, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([750, 780, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([780, 1020, AgentStore.ACT_PLAY, PLACE_PLAZA]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1110, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1110, 1230, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1230, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _youth_plan() -> Array:
	return [
		PackedInt32Array([0, 390, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([390, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 450, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([450, 480, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([480, 720, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([720, 750, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([750, 780, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([780, 1020, AgentStore.ACT_LEARN, PLACE_WORKSHOP]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1080, 1110, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1110, 1260, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1260, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _old_plan() -> Array:
	return [
		PackedInt32Array([0, 390, AgentStore.ACT_SLEEP, PLACE_HOME]),
		PackedInt32Array([390, 420, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([420, 450, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([450, 540, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([540, 660, AgentStore.ACT_WORK, PLACE_JOB]),
		PackedInt32Array([660, 720, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([720, 750, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([750, 900, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([900, 1020, AgentStore.ACT_SOCIAL, PLACE_PLAZA]),
		PackedInt32Array([1020, 1080, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1080, 1110, AgentStore.ACT_EAT, PLACE_HOME]),
		PackedInt32Array([1110, 1230, AgentStore.ACT_IDLE, PLACE_HOME]),
		PackedInt32Array([1230, 1440, AgentStore.ACT_SLEEP, PLACE_HOME]),
	]


static func _tables_for(p_role: int, g3: bool) -> Dictionary:
	var key: int = (1 if g3 else 0) * 16 + p_role
	if _table_cache.has(key):
		return _table_cache[key]
	var plan: Array = plan_for_role(p_role, g3)
	var act_t: PackedInt32Array = PackedInt32Array()
	var place_t: PackedInt32Array = PackedInt32Array()
	var end_t: PackedInt32Array = PackedInt32Array()
	var next_t: PackedInt32Array = PackedInt32Array()
	var entry_t: Array = []
	act_t.resize(1440); place_t.resize(1440); end_t.resize(1440); next_t.resize(1440)
	var starts: PackedInt32Array = PackedInt32Array()
	for entry in plan:
		starts.append((entry as PackedInt32Array)[0])
	var start_set: Dictionary = {}
	for s in starts:
		start_set[int(s)] = true
	for minute in 1440:
		var chosen: PackedInt32Array = plan[plan.size() - 1]
		for entry in plan:
			var e: PackedInt32Array = entry
			if minute >= e[0] and minute < e[1]:
				chosen = e
				break
		entry_t.append(chosen)
		act_t[minute] = chosen[2]
		place_t[minute] = chosen[3]
		end_t[minute] = chosen[1]
		var next_start: int = -1
		var scan: int = minute + 1
		while scan < 1440:
			if start_set.has(scan):
				next_start = scan
				break
			scan += 1
		next_t[minute] = next_start
	# Nächste Startminute je Aktivität (strikt nach der aktuellen Minute).
	var next_act: Dictionary = {}
	var first_act: Dictionary = {}
	for entry in plan:
		var e: PackedInt32Array = entry
		if not first_act.has(e[2]):
			first_act[e[2]] = e[0]
		if not next_act.has(e[2]):
			var empty: PackedInt32Array = PackedInt32Array()
			empty.resize(1440)
			next_act[e[2]] = empty
	for act_key in next_act:
		var arr: PackedInt32Array = next_act[act_key]
		var next_s: int = -1
		var scan2: int = 1439
		while scan2 >= 0:
			arr[scan2] = next_s
			if start_set.has(scan2):
				for entry in plan:
					var e2: PackedInt32Array = entry
					if e2[0] == scan2 and e2[2] == act_key:
						next_s = scan2
						break
			scan2 -= 1
	var table: Dictionary = {
		"act": act_t, "place": place_t, "end": end_t, "next": next_t,
		"next_act": next_act, "first_act": first_act, "entry": entry_t,
	}
	_table_cache[key] = table
	return table


static func suppress_mask(p_role: int, minute_of_day: int, g3: bool) -> int:
	var key: int = (1 if g3 else 0) * 16 + p_role
	if not _suppress_cache.has(key):
		var t: Dictionary = _tables_for(p_role, g3)
		var act_t: PackedInt32Array = t["act"]
		var masks: PackedInt32Array = PackedInt32Array()
		masks.resize(1440)
		for minute in 1440:
			var now: int = minute * 60
			var mask: int = 0
			var act: int = act_t[minute]
			if act == AgentStore.ACT_EAT or seconds_until_next_activity(now,
					p_role, AgentStore.ACT_EAT, g3) <= SimConfig.ROUTINE_LOOKAHEAD_S:
				mask |= SUPPRESS_HUNGER
			if act == AgentStore.ACT_SLEEP or seconds_until_next_activity(now,
					p_role, AgentStore.ACT_SLEEP, g3) <= SimConfig.SLEEP_LOOKAHEAD_S:
				mask |= SUPPRESS_ENERGY
			if act == AgentStore.ACT_SOCIAL or seconds_until_next_activity(now,
					p_role, AgentStore.ACT_SOCIAL, g3) <= SimConfig.ROUTINE_LOOKAHEAD_S:
				mask |= SUPPRESS_SOCIAL
			if act == AgentStore.ACT_PLAY or act == AgentStore.ACT_SOCIAL:
				mask |= SUPPRESS_FUN
			else:
				var next_play: int = seconds_until_next_activity(now, p_role,
					AgentStore.ACT_PLAY, g3)
				var next_social: int = seconds_until_next_activity(now, p_role,
					AgentStore.ACT_SOCIAL, g3)
				if (next_play >= 0 and next_play <= SimConfig.ROUTINE_LOOKAHEAD_S) \
						or (next_social >= 0
						and next_social <= SimConfig.ROUTINE_LOOKAHEAD_S):
					mask |= SUPPRESS_FUN
			masks[minute] = mask
		_suppress_cache[key] = masks
	return int((_suppress_cache[key] as PackedInt32Array)[
		clampi(minute_of_day, 0, 1439)])


## Eintrag, der die Minute enthält. Pläne sind lückenlos.
static func entry_at(p_role: int, minute_of_day: int,
		g3: bool = false) -> PackedInt32Array:
	var t: Dictionary = _tables_for(p_role, g3)
	var m: int = clampi(minute_of_day, 0, 1439)
	return t["entry"][m]


## Absoluter Endzeitpunkt des aktuellen Eintrags.
static func entry_end_abs(now: int, p_role: int, g3: bool = false) -> int:
	var day_start: int = now - (now % SimConfig.TICKS_PER_DAY)
	var minute_of_day: int = (now % SimConfig.TICKS_PER_DAY) / 60
	return day_start + int((_tables_for(p_role, g3)["end"] as PackedInt32Array)[
		clampi(minute_of_day, 0, 1439)]) * 60


## Nächster Planübergang strikt nach now.
static func next_transition_abs(now: int, p_role: int, g3: bool = false) -> int:
	var day_start: int = now - (now % SimConfig.TICKS_PER_DAY)
	var minute_of_day: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var next_start: int = int((_tables_for(p_role, g3)["next"] as PackedInt32Array)[
		clampi(minute_of_day, 0, 1439)])
	if next_start < 0:
		return day_start + SimConfig.TICKS_PER_DAY
	return day_start + next_start * 60


## Sekunden bis zum nächsten Start einer Aktivität (nur heute/morgen).
static func seconds_until_next_activity(now: int, p_role: int, act: int,
		g3: bool = false) -> int:
	var t: Dictionary = _tables_for(p_role, g3)
	var next_act: Dictionary = t["next_act"]
	if not next_act.has(act):
		return -1
	var minute_of_day: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var sec: int = now % 60
	var s: int = int((next_act[act] as PackedInt32Array)[
		clampi(minute_of_day, 0, 1439)])
	var day_offset: int = 0
	if s < 0:
		s = int(t["first_act"][act])
		day_offset = 1
	return (day_offset * 1440 + s - minute_of_day) * 60 - sec
