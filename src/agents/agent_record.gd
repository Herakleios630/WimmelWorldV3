class_name AgentRecord
extends RefCounted

## Kalter Agentenrecord: Identität, Rolle, Zugehörigkeit. Nicht im Hot-Loop.

var id: int = 0
var name: String = ""
var sex: int = 0
var age_years: int = 0
var role: int = 0
var household_id: int = 0
var home_building_id: int = 0
var job_id: int = 0
var job_kind: int = 0


func _init(p_id: int = 0, p_name: String = "", p_sex: int = 0, p_age: int = 0,
		p_role: int = 0, p_household: int = 0, p_home: int = 0,
		p_job_id: int = 0, p_job_kind: int = 0) -> void:
	id = p_id
	name = p_name
	sex = p_sex
	age_years = p_age
	role = p_role
	household_id = p_household
	home_building_id = p_home
	job_id = p_job_id
	job_kind = p_job_kind


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix_string(h, name)
	h = HashUtil.mix(h, sex)
	h = HashUtil.mix(h, age_years)
	h = HashUtil.mix(h, role)
	h = HashUtil.mix(h, household_id)
	h = HashUtil.mix(h, home_building_id)
	h = HashUtil.mix(h, job_id)
	h = HashUtil.mix(h, job_kind)
	return h
