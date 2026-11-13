class_name SimEvent
extends RefCounted

## Ein Log-Eintrag. Debug- und Chronik-Log enthalten dieselbe Record-Form,
## sind aber getrennte Container und werden getrennt gespeichert.

const IMPORTANCE_ROUTINE: int = 0
const IMPORTANCE_NOTABLE: int = 1
const IMPORTANCE_MAJOR: int = 2
const IMPORTANCE_HISTORIC: int = 3

const T_SIM_START: int = 1
const T_DAY_START: int = 2
const T_WORK_START: int = 3
const T_WORK_END: int = 4
const T_MEAL_START: int = 5
const T_MEAL_END: int = 6
const T_MEAL_SKIPPED: int = 7
const T_SLEEP_START: int = 8
const T_WAKE_UP: int = 9
const T_SOCIAL_START: int = 10
const T_SOCIAL_END: int = 11
const T_ARRIVE: int = 12
const T_NEED_INTERRUPT: int = 13
const T_SHORTAGE: int = 14
const T_TRAVEL_START: int = 15
const T_SAVE: int = 16
const T_LOAD: int = 17
const T_NAP_START: int = 18
const T_NAP_END: int = 19
const T_GRAIN_AWARD: int = 20
const T_ACTIVITY_START: int = 21

var id: int = 0
var time: int = 0
var type: int = 0
var importance: int = 0
var agent_id: int = 0
var template_key: String = ""
var text: String = ""
var data: int = 0


func _init(p_id: int = 0, p_time: int = 0, p_type: int = 0,
		p_importance: int = 0, p_agent_id: int = 0,
		p_template: String = "", p_text: String = "", p_data: int = 0) -> void:
	id = p_id
	time = p_time
	type = p_type
	importance = p_importance
	agent_id = p_agent_id
	template_key = p_template
	text = p_text
	data = p_data


static func type_name(t: int) -> String:
	match t:
		T_SIM_START: return "sim_start"
		T_DAY_START: return "day_start"
		T_WORK_START: return "work_start"
		T_WORK_END: return "work_end"
		T_MEAL_START: return "meal_start"
		T_MEAL_END: return "meal_end"
		T_MEAL_SKIPPED: return "meal_skipped"
		T_SLEEP_START: return "sleep_start"
		T_WAKE_UP: return "wake_up"
		T_SOCIAL_START: return "social_start"
		T_SOCIAL_END: return "social_end"
		T_ARRIVE: return "arrive"
		T_NEED_INTERRUPT: return "need_interrupt"
		T_SHORTAGE: return "shortage"
		T_TRAVEL_START: return "travel_start"
		T_SAVE: return "save"
		T_LOAD: return "load"
		T_NAP_START: return "nap_start"
		T_NAP_END: return "nap_end"
		T_GRAIN_AWARD: return "grain_award"
		T_ACTIVITY_START: return "activity_start"
		_: return "unknown"


func to_text() -> String:
	var who: String = ("A%d" % agent_id) if agent_id > 0 else "-"
	return "%s %s %s %s" % [SimClock.new(time).time_string(), who,
		type_name(type), text]


func hash_into(h: int) -> int:
	h = HashUtil.mix_i64(h, id)
	h = HashUtil.mix_i64(h, time)
	h = HashUtil.mix(h, type)
	h = HashUtil.mix(h, importance)
	h = HashUtil.mix(h, agent_id)
	h = HashUtil.mix_string(h, template_key)
	h = HashUtil.mix_i64(h, data)
	return h
