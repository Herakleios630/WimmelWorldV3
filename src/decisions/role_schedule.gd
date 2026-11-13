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


static func plan_for_role(p_role: int) -> Array:
	match p_role:
		AgentStore.ROLE_CHILD:
			return _child_plan()
		AgentStore.ROLE_YOUTH:
			return _youth_plan()
		AgentStore.ROLE_OLD:
			return _old_plan()
		_:
			return _adult_plan()


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


## Eintrag, der die Minute enthält. Pläne sind lückenlos.
static func entry_at(p_role: int, minute_of_day: int) -> PackedInt32Array:
	var plan: Array = plan_for_role(p_role)
	for entry in plan:
		var e: PackedInt32Array = entry
		if minute_of_day >= e[0] and minute_of_day < e[1]:
			return e
	return plan[plan.size() - 1]


## Absoluter Endzeitpunkt des aktuellen Eintrags.
static func entry_end_abs(now: int, p_role: int) -> int:
	var day_start: int = now - (now % SimConfig.TICKS_PER_DAY)
	var minute_of_day: int = (now % SimConfig.TICKS_PER_DAY) / 60
	var entry: PackedInt32Array = entry_at(p_role, minute_of_day)
	return day_start + entry[1] * 60


## Nächster Planübergang strikt nach now.
static func next_transition_abs(now: int, p_role: int) -> int:
	var day_start: int = now - (now % SimConfig.TICKS_PER_DAY)
	var second_of_day: int = now % SimConfig.TICKS_PER_DAY
	var best: int = day_start + SimConfig.TICKS_PER_DAY
	for entry in plan_for_role(p_role):
		var e: PackedInt32Array = entry
		var start_abs: int = day_start + e[0] * 60
		if start_abs > now and start_abs < best:
			best = start_abs
	return best


## Sekunden bis zum nächsten Start einer Aktivität (nur heute/morgen).
static func seconds_until_next_activity(now: int, p_role: int, act: int) -> int:
	var day_start: int = now - (now % SimConfig.TICKS_PER_DAY)
	for day_offset in [0, 1]:
		var base: int = day_start + day_offset * SimConfig.TICKS_PER_DAY
		for entry in plan_for_role(p_role):
			var e: PackedInt32Array = entry
			if e[2] != act:
				continue
			var start_abs: int = base + e[0] * 60
			if start_abs > now:
				return start_abs - now
	return -1
