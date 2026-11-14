class_name DiplomacyState
extends RefCounted

## Ein abstrakter Nachbar: Relation, Handelsabkommen, Geschenk-Cooldown.
## Kein Krieg, keine Armee, keine Grenzsimulation.

const TREATY_NONE: int = 0
const TREATY_TRADE: int = 1

var neighbor_id: int = 0
var name: String = ""
var relation: int = 0
var treaty: int = TREATY_NONE
var treaty_day: int = -1
var last_gift_day: int = -100000
var gift_count: int = 0


func _init(p_id: int = 0, p_name: String = "", p_relation: int = 0) -> void:
	neighbor_id = p_id
	name = p_name
	relation = p_relation


func has_trade_treaty() -> bool:
	return treaty == TREATY_TRADE


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, neighbor_id)
	h = HashUtil.mix_string(h, name)
	h = HashUtil.mix(h, relation)
	h = HashUtil.mix(h, treaty)
	h = HashUtil.mix_i64(h, treaty_day)
	h = HashUtil.mix_i64(h, last_gift_day)
	h = HashUtil.mix_i64(h, gift_count)
	return h


func write_to(w: ByteWriter) -> void:
	w.i32(neighbor_id)
	w.string_value(name)
	w.i32(relation)
	w.i32(treaty)
	w.i64(treaty_day)
	w.i64(last_gift_day)
	w.i64(gift_count)


static func read_from(r: ByteReader) -> DiplomacyState:
	var state: DiplomacyState = DiplomacyState.new()
	state.neighbor_id = r.i32()
	state.name = r.string_value()
	state.relation = r.i32()
	state.treaty = r.i32()
	state.treaty_day = r.i64()
	state.last_gift_day = r.i64()
	state.gift_count = r.i64()
	return state
