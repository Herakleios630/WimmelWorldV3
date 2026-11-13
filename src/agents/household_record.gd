class_name HouseholdRecord
extends RefCounted

## Kalter Haushaltsrecord. G1a teilt Nahrung über den zentralen Speicher;
## shared_food bleibt 0 und wird nicht simuliert.

var id: int = 0
var home_building_id: int = 0
var member_ids: PackedInt32Array = PackedInt32Array()


func _init(p_id: int = 0, p_home: int = 0, p_members: PackedInt32Array = PackedInt32Array()) -> void:
	id = p_id
	home_building_id = p_home
	member_ids = p_members


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix(h, home_building_id)
	h = HashUtil.mix(h, member_ids.size())
	for member in member_ids:
		h = HashUtil.mix(h, member)
	return h
