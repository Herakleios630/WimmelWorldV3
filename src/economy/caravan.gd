class_name Caravan
extends RefCounted

## Physische Karawane mit Ladung und deterministischem Start/Ziel. Sie ist
## kein lokaler 10k-Agent; es gibt nur wenige gleichzeitig.

const STATE_OUTBOUND: int = 0
const STATE_INBOUND: int = 1

var id: int = 0
var node_id: int = 0
var state: int = STATE_OUTBOUND
var cargo_good: int = 0
var cargo_amount: int = 0
var import_good: int = 0
var import_amount: int = 0
var depart_time: int = 0
var arrive_time: int = 0
var return_time: int = 0
var sale_revenue: int = 0
var import_cost: int = 0
var trip_cost: int = 0
var tariff_permille: int = 0


func _init(p_id: int = 0, p_node: int = 0, p_good: int = 0,
		p_amount: int = 0, p_depart: int = 0, p_arrive: int = 0,
		p_trip_cost: int = 0) -> void:
	id = p_id
	node_id = p_node
	cargo_good = p_good
	cargo_amount = p_amount
	depart_time = p_depart
	arrive_time = p_arrive
	return_time = p_arrive
	trip_cost = p_trip_cost


func is_outbound() -> bool:
	return state == STATE_OUTBOUND


func state_name() -> String:
	return "Hinreise" if state == STATE_OUTBOUND else "Rückreise"


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix(h, node_id)
	h = HashUtil.mix(h, state)
	h = HashUtil.mix(h, cargo_good)
	h = HashUtil.mix_i64(h, cargo_amount)
	h = HashUtil.mix(h, import_good)
	h = HashUtil.mix_i64(h, import_amount)
	h = HashUtil.mix_i64(h, depart_time)
	h = HashUtil.mix_i64(h, arrive_time)
	h = HashUtil.mix_i64(h, return_time)
	h = HashUtil.mix_i64(h, sale_revenue)
	h = HashUtil.mix_i64(h, import_cost)
	h = HashUtil.mix_i64(h, trip_cost)
	h = HashUtil.mix(h, tariff_permille)
	return h


func write_to(w: ByteWriter) -> void:
	w.i32(id)
	w.i32(node_id)
	w.i32(state)
	w.i32(cargo_good)
	w.i64(cargo_amount)
	w.i32(import_good)
	w.i64(import_amount)
	w.i64(depart_time)
	w.i64(arrive_time)
	w.i64(return_time)
	w.i64(sale_revenue)
	w.i64(import_cost)
	w.i64(trip_cost)
	w.i32(tariff_permille)


static func read_from(r: ByteReader) -> Caravan:
	var c: Caravan = Caravan.new()
	c.id = r.i32()
	c.node_id = r.i32()
	c.state = r.i32()
	c.cargo_good = r.i32()
	c.cargo_amount = r.i64()
	c.import_good = r.i32()
	c.import_amount = r.i64()
	c.depart_time = r.i64()
	c.arrive_time = r.i64()
	c.return_time = r.i64()
	c.sale_revenue = r.i64()
	c.import_cost = r.i64()
	c.trip_cost = r.i64()
	c.tariff_permille = r.i32()
	return c
