class_name SimClock
extends RefCounted

## Ganzzahlige Sim-Zeit in Sekunden. Keine Wall-Clock, kein Speed.
## Speed/Zeitsteuerung gehört ausschließlich zur View.

var now: int = 0


func _init(start_time: int = 0) -> void:
	now = start_time


func day_index() -> int:
	return now / SimConfig.TICKS_PER_DAY


func second_of_day() -> int:
	return now % SimConfig.TICKS_PER_DAY


func minute_of_day() -> int:
	return second_of_day() / 60


func hour() -> int:
	return second_of_day() / 3600


func minute() -> int:
	return (second_of_day() % 3600) / 60


func time_string() -> String:
	return "Tag %d %02d:%02d" % [day_index() + 1, hour(), minute()]


func state_hash() -> int:
	return HashUtil.mix_i64(HashUtil.FNV_OFFSET, now)
