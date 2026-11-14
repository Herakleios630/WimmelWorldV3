class_name ExternalNode
extends RefCounted

## Abstrakter externer Handelsknoten. Kein lokaler 10k-Agent; nur Preise,
## Bestand und ein deterministischer Kartenanker am Weltkartenrand.

var id: int = 0
var name: String = ""
var neighbor_index: int = 0
var gate_tile: Vector2i = Vector2i.ZERO
var price_milli: PackedInt64Array = PackedInt64Array()
var stock: PackedInt64Array = PackedInt64Array()


func _init(p_id: int = 0, p_name: String = "", p_neighbor: int = 0,
		p_gate: Vector2i = Vector2i.ZERO,
		p_prices: PackedInt64Array = PackedInt64Array(),
		p_stock: PackedInt64Array = PackedInt64Array()) -> void:
	id = p_id
	name = p_name
	neighbor_index = p_neighbor
	gate_tile = p_gate
	price_milli = p_prices
	stock = p_stock
	if price_milli.size() != Goods.COUNT:
		price_milli = Goods.BASE_PRICE_MILLI.duplicate()
	if stock.size() != Goods.COUNT:
		stock.resize(Goods.COUNT)
		stock.fill(100000)


static func defaults() -> Array:
	var out: Array = []
	out.append(ExternalNode.new(0, "Nordhaven", 0, Vector2i(2036, 560),
		PackedInt64Array([900, 2600, 4800]),
		PackedInt64Array([100000, 100000, 100000])))
	out.append(ExternalNode.new(1, "Ostfurt", 1, Vector2i(2036, 1560),
		PackedInt64Array([1200, 1800, 5600]),
		PackedInt64Array([100000, 100000, 100000])))
	out.append(ExternalNode.new(2, "Südweide", -1, Vector2i(1500, 2036),
		PackedInt64Array([1050, 2200, 4200]),
		PackedInt64Array([100000, 100000, 100000])))
	return out


func sell_price(good: int, tariff_permille: int) -> int:
	return (price_milli[good] * maxi(0, 1000 - tariff_permille)) / 1000


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, id)
	h = HashUtil.mix_string(h, name)
	h = HashUtil.mix(h, neighbor_index)
	h = HashUtil.mix(h, gate_tile.x)
	h = HashUtil.mix(h, gate_tile.y)
	for good in Goods.COUNT:
		h = HashUtil.mix_i64(h, price_milli[good])
		h = HashUtil.mix_i64(h, stock[good])
	return h


func write_to(w: ByteWriter) -> void:
	w.i32(id)
	w.string_value(name)
	w.i32(neighbor_index)
	w.i32(gate_tile.x)
	w.i32(gate_tile.y)
	for good in Goods.COUNT:
		w.i64(price_milli[good])
		w.i64(stock[good])


static func read_from(r: ByteReader) -> ExternalNode:
	var node: ExternalNode = ExternalNode.new()
	node.id = r.i32()
	node.name = r.string_value()
	node.neighbor_index = r.i32()
	node.gate_tile = Vector2i(r.i32(), r.i32())
	node.price_milli.resize(Goods.COUNT)
	node.stock.resize(Goods.COUNT)
	for good in Goods.COUNT:
		node.price_milli[good] = r.i64()
		node.stock[good] = r.i64()
	return node
