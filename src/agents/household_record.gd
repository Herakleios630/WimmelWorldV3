class_name HouseholdRecord
extends RefCounted

## Kalter Haushaltsrecord. G1a teilt Nahrung über den zentralen Speicher;
## shared_food bleibt 0 und wird nicht simuliert.

var id: int = 0
var home_building_id: int = 0
var member_ids: PackedInt32Array = PackedInt32Array()
# G1b-Schritt 2: aufgelöste Haushalte bleiben als historischer Record stehen.
# member_ids ist dann leer; archived_member_ids hält den Stand bei Auflösung.
var dissolved: int = 0
var dissolved_day: int = -1
var dissolved_reason: int = 0
var archived_member_ids: PackedInt32Array = PackedInt32Array()


func _init(p_id: int = 0, p_home: int = 0, p_members: PackedInt32Array = PackedInt32Array(),
		p_dissolved: int = 0, p_dissolved_day: int = -1,
		p_dissolved_reason: int = 0) -> void:
	id = p_id
	home_building_id = p_home
	member_ids = p_members
	dissolved = p_dissolved
	dissolved_day = p_dissolved_day
	dissolved_reason = p_dissolved_reason


func is_active() -> bool:
	return dissolved == 0


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix(h, home_building_id)
	h = HashUtil.mix(h, dissolved)
	h = HashUtil.mix_i64(h, dissolved_day)
	h = HashUtil.mix(h, dissolved_reason)
	h = HashUtil.mix(h, member_ids.size())
	for member in member_ids:
		h = HashUtil.mix(h, member)
	h = HashUtil.mix(h, archived_member_ids.size())
	for member in archived_member_ids:
		h = HashUtil.mix(h, member)
	return h
