class_name RelationshipRecord
extends RefCounted

## Kalter Beziehungsrecord. Wird in G1a nur gespeichert/angezeigt, nicht
## simuliert (Partnerschaft/Geburt sind G1b).

const TYPE_PARTNER: int = 0
const TYPE_PARENT: int = 1
const TYPE_CHILD: int = 2
const TYPE_GRANDPARENT: int = 3
const TYPE_FRIEND: int = 4

var id: int = 0
var type: int = 0
var a_agent_id: int = 0
var b_agent_id: int = 0
var strength: int = 0
var since_day: int = 0


func _init(p_id: int = 0, p_type: int = 0, p_a: int = 0, p_b: int = 0,
		p_strength: int = 50, p_since_day: int = 0) -> void:
	id = p_id
	type = p_type
	a_agent_id = p_a
	b_agent_id = p_b
	strength = p_strength
	since_day = p_since_day


static func type_name(t: int) -> String:
	match t:
		TYPE_PARTNER: return "Partner"
		TYPE_PARENT: return "Elternteil"
		TYPE_CHILD: return "Kind"
		TYPE_GRANDPARENT: return "Großelternteil"
		TYPE_FRIEND: return "Freund"
	return "?"


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix(h, type)
	h = HashUtil.mix(h, a_agent_id)
	h = HashUtil.mix(h, b_agent_id)
	h = HashUtil.mix(h, strength)
	h = HashUtil.mix(h, since_day)
	return h
