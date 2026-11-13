class_name AgentStore
extends RefCounted

## SoA-Hotstore für G1a. Keine Per-Agent-Dictionaries, keine Objekte pro Agent.
## Kalte Daten (Name, Beziehungen) liegen in agent_records.gd.

const ROLE_CHILD: int = 0
const ROLE_YOUTH: int = 1
const ROLE_ADULT: int = 2
const ROLE_OLD: int = 3

const ACT_IDLE: int = 0
const ACT_TRAVEL: int = 1
const ACT_WORK: int = 2
const ACT_EAT: int = 3
const ACT_SLEEP: int = 4
const ACT_SOCIAL: int = 5
const ACT_LEARN: int = 6
const ACT_PLAY: int = 7
const ACT_COUNT: int = 8

const JOB_NONE: int = 0
const JOB_FIELD: int = 1
const JOB_WORKSHOP: int = 2

var count: int = 0
var next_id: int = 1

var ids: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()
var age_years: PackedInt32Array = PackedInt32Array()
var role: PackedByteArray = PackedByteArray()
var household_id: PackedInt32Array = PackedInt32Array()
var home_id: PackedInt32Array = PackedInt32Array()
var job_id: PackedInt32Array = PackedInt32Array()
var job_kind: PackedByteArray = PackedByteArray()

var activity: PackedByteArray = PackedByteArray()
var intent: PackedByteArray = PackedByteArray()
var action_source: PackedByteArray = PackedByteArray()
var target_building_id: PackedInt32Array = PackedInt32Array()
var target_x: PackedFloat64Array = PackedFloat64Array()
var target_y: PackedFloat64Array = PackedFloat64Array()
var pos_x: PackedFloat64Array = PackedFloat64Array()
var pos_y: PackedFloat64Array = PackedFloat64Array()

var travel_depart: PackedInt64Array = PackedInt64Array()
var travel_arrive: PackedInt64Array = PackedInt64Array()
var travel_start_x: PackedFloat64Array = PackedFloat64Array()
var travel_start_y: PackedFloat64Array = PackedFloat64Array()
var travel_end_x: PackedFloat64Array = PackedFloat64Array()
var travel_end_y: PackedFloat64Array = PackedFloat64Array()
var route_id: PackedInt32Array = PackedInt32Array()

var wake_gen: PackedInt32Array = PackedInt32Array()
var next_event: PackedInt64Array = PackedInt64Array()
var need_time: PackedInt64Array = PackedInt64Array()
var hunger: PackedFloat64Array = PackedFloat64Array()
var energy: PackedFloat64Array = PackedFloat64Array()
var social: PackedFloat64Array = PackedFloat64Array()

var action_end: PackedInt64Array = PackedInt64Array()
var work_start: PackedInt64Array = PackedInt64Array()
var work_end: PackedInt64Array = PackedInt64Array()
var work_accum: PackedInt64Array = PackedInt64Array()
var meal_retry: PackedInt64Array = PackedInt64Array()
var shortage_logged_day: PackedInt32Array = PackedInt32Array()

var row_of_id: PackedInt32Array = PackedInt32Array()


func add_agent(agent_id: int, p_age: int, p_role: int, p_household: int,
		p_home: int, p_job_id: int, p_job_kind: int, p_x: float, p_y: float,
		p_hunger: float, p_energy: float, p_social: float, now: int) -> int:
	var row: int = count
	count += 1
	ids.append(agent_id)
	alive.append(1)
	age_years.append(p_age)
	role.append(p_role)
	household_id.append(p_household)
	home_id.append(p_home)
	job_id.append(p_job_id)
	job_kind.append(p_job_kind)
	activity.append(ACT_IDLE)
	intent.append(ACT_IDLE)
	action_source.append(0)
	target_building_id.append(0)
	target_x.append(p_x)
	target_y.append(p_y)
	pos_x.append(p_x)
	pos_y.append(p_y)
	travel_depart.append(0)
	travel_arrive.append(0)
	travel_start_x.append(p_x)
	travel_start_y.append(p_y)
	travel_end_x.append(p_x)
	travel_end_y.append(p_y)
	route_id.append(-1)
	wake_gen.append(0)
	next_event.append(now)
	need_time.append(now)
	hunger.append(p_hunger)
	energy.append(p_energy)
	social.append(p_social)
	action_end.append(0)
	work_start.append(-1)
	work_end.append(-1)
	work_accum.append(0)
	meal_retry.append(0)
	shortage_logged_day.append(-1)
	if agent_id >= row_of_id.size():
		var old_size: int = row_of_id.size()
		row_of_id.resize(agent_id + 1)
		for i in range(old_size, agent_id + 1):
			row_of_id[i] = -1
	row_of_id[agent_id] = row
	if agent_id >= next_id:
		next_id = agent_id + 1
	return row


## Neue ID, nie wiederverwendet. Für Lebenszyklus-Tests/G1b vorbereitet.
func spawn_agent(p_age: int, p_role: int, p_household: int, p_home: int,
		p_job_id: int, p_job_kind: int, p_x: float, p_y: float,
		p_hunger: float, p_energy: float, p_social: float, now: int) -> int:
	var new_id: int = next_id
	next_id += 1
	add_agent(new_id, p_age, p_role, p_household, p_home, p_job_id,
		p_job_kind, p_x, p_y, p_hunger, p_energy, p_social, now)
	return new_id


func row_for_id(agent_id: int) -> int:
	if agent_id < 0 or agent_id >= row_of_id.size():
		return -1
	return row_of_id[agent_id]


func is_alive_row(row: int) -> bool:
	return row >= 0 and row < count and alive[row] != 0


func set_alive(row: int, value: bool) -> void:
	if row >= 0 and row < count:
		alive[row] = 1 if value else 0


static func activity_name(act: int) -> String:
	match act:
		ACT_IDLE: return "untätig"
		ACT_TRAVEL: return "unterwegs"
		ACT_WORK: return "Arbeit"
		ACT_EAT: return "Mahlzeit"
		ACT_SLEEP: return "Schlaf"
		ACT_SOCIAL: return "Sozial"
		ACT_LEARN: return "Lernen"
		ACT_PLAY: return "Spielen"
	return "?"


static func role_name(p_role: int) -> String:
	match p_role:
		ROLE_CHILD: return "Kind"
		ROLE_YOUTH: return "Jugend"
		ROLE_ADULT: return "Erwachsen"
		ROLE_OLD: return "Alt"
	return "?"


func state_hash(now: int) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, count)
	for i in count:
		h = HashUtil.mix(h, ids[i])
		h = HashUtil.mix(h, alive[i])
		h = HashUtil.mix(h, age_years[i])
		h = HashUtil.mix(h, role[i])
		h = HashUtil.mix(h, household_id[i])
		h = HashUtil.mix(h, home_id[i])
		h = HashUtil.mix(h, job_id[i])
		h = HashUtil.mix(h, job_kind[i])
		h = HashUtil.mix(h, activity[i])
		h = HashUtil.mix(h, intent[i])
		h = HashUtil.mix(h, action_source[i])
		h = HashUtil.mix(h, target_building_id[i])
		h = HashUtil.mix_f64(h, target_x[i])
		h = HashUtil.mix_f64(h, target_y[i])
		h = HashUtil.mix_f64(h, pos_x[i])
		h = HashUtil.mix_f64(h, pos_y[i])
		h = HashUtil.mix_i64(h, travel_depart[i])
		h = HashUtil.mix_i64(h, travel_arrive[i])
		h = HashUtil.mix_f64(h, travel_start_x[i])
		h = HashUtil.mix_f64(h, travel_start_y[i])
		h = HashUtil.mix_f64(h, travel_end_x[i])
		h = HashUtil.mix_f64(h, travel_end_y[i])
		h = HashUtil.mix(h, route_id[i])
		h = HashUtil.mix(h, wake_gen[i])
		h = HashUtil.mix_i64(h, next_event[i])
		h = HashUtil.mix_i64(h, need_time[i])
		h = HashUtil.mix_f64(h, hunger[i])
		h = HashUtil.mix_f64(h, energy[i])
		h = HashUtil.mix_f64(h, social[i])
		h = HashUtil.mix_i64(h, action_end[i])
		h = HashUtil.mix_i64(h, work_start[i])
		h = HashUtil.mix_i64(h, work_end[i])
		h = HashUtil.mix_i64(h, work_accum[i])
		h = HashUtil.mix_i64(h, meal_retry[i])
		h = HashUtil.mix(h, shortage_logged_day[i])
	return h

