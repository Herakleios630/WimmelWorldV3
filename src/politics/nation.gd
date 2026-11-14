class_name Nation
extends RefCounted

## Eine Region/Nation mit Schatzkammer, Steuersatz, öffentlichem Budget und
## zwei abstrakten Nachbarn. Drei Ressourcen-Spezialisierungen sind Platzhalter.

const SPEC_GRAIN: int = 0
const SPEC_TOOL: int = 1
const SPEC_WOOD: int = 2

var id: int = 1
var name: String = "Wimmelmark"
var treasury: int = 0
var tax_rate_permille: int = 100
var specialization: int = SPEC_GRAIN
var budget_granary: int = 0
var budget_roads: int = 0
var budget_guards: int = 0
var budget_reserve: int = 0
var reserve_fund: int = 0
var neighbors: Array = []


func _init(config: SimConfig = null) -> void:
	if config != null:
		treasury = config.nation_start_treasury
		tax_rate_permille = config.tax_rate_permille
		budget_granary = config.budget_granary
		budget_roads = config.budget_roads
		budget_guards = config.budget_guards
		budget_reserve = config.budget_reserve
	neighbors.append(DiplomacyState.new(0, "Nordhaven", 15))
	neighbors.append(DiplomacyState.new(1, "Ostfurt", 5))


func specialization_name() -> String:
	match specialization:
		SPEC_GRAIN: return "Grain"
		SPEC_TOOL: return "Werkzeug"
		SPEC_WOOD: return "Holz"
	return "?"


func has_trade_treaty(neighbor_index: int) -> bool:
	if neighbor_index < 0 or neighbor_index >= neighbors.size():
		return false
	return (neighbors[neighbor_index] as DiplomacyState).has_trade_treaty()


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix_string(h, name)
	h = HashUtil.mix_i64(h, treasury)
	h = HashUtil.mix(h, tax_rate_permille)
	h = HashUtil.mix(h, specialization)
	h = HashUtil.mix_i64(h, budget_granary)
	h = HashUtil.mix_i64(h, budget_roads)
	h = HashUtil.mix_i64(h, budget_guards)
	h = HashUtil.mix_i64(h, budget_reserve)
	h = HashUtil.mix_i64(h, reserve_fund)
	for neighbor_v in neighbors:
		h = HashUtil.mix(h, (neighbor_v as DiplomacyState).state_hash())
	return h


func write_to(w: ByteWriter) -> void:
	w.i32(id)
	w.string_value(name)
	w.i64(treasury)
	w.i32(tax_rate_permille)
	w.i32(specialization)
	w.i64(budget_granary)
	w.i64(budget_roads)
	w.i64(budget_guards)
	w.i64(budget_reserve)
	w.i64(reserve_fund)
	w.u32(neighbors.size())
	for neighbor_v in neighbors:
		(neighbor_v as DiplomacyState).write_to(w)


static func read_from(r: ByteReader) -> Nation:
	var nation: Nation = Nation.new()
	nation.id = r.i32()
	nation.name = r.string_value()
	nation.treasury = r.i64()
	nation.tax_rate_permille = r.i32()
	nation.specialization = r.i32()
	nation.budget_granary = r.i64()
	nation.budget_roads = r.i64()
	nation.budget_guards = r.i64()
	nation.budget_reserve = r.i64()
	nation.reserve_fund = r.i64()
	nation.neighbors.clear()
	var count: int = r.u32()
	if count < 0 or count > 8:
		r.ok = false
		r.error = "bad_neighbors"
		return nation
	for _i in count:
		nation.neighbors.append(DiplomacyState.read_from(r))
	return nation
