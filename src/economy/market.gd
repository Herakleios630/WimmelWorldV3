class_name Market
extends RefCounted

## Siedlungsmarkt für Grain/Holz/Werkzeug. Der Bestand ist autoritativ, die
## Preise werden täglich aus Bestand und Tagessaldo gedämpft fortgeschrieben.
## Alle Rechnungen sind ganzzahlig; es gibt keine Float-Akkumulation und keine
## Dictionary-Iteration in der Preisfunktion.

const DAMPING_DIVISOR: int = 4
const MIN_PRESSURE_MILLI: int = 400
const MAX_PRESSURE_MILLI: int = 3000
const FLOW_WINDOW_MILLI: int = 1600
const MAX_STOCK_FACTOR: int = 4

var stock: PackedInt64Array = PackedInt64Array()
var price_milli: PackedInt64Array = PackedInt64Array()
var supply: PackedInt64Array = PackedInt64Array()
var demand: PackedInt64Array = PackedInt64Array()
var base_price_milli: PackedInt64Array = PackedInt64Array()
var target_stock: PackedInt64Array = PackedInt64Array()
var last_update_day: int = 0
var total_sales_value: int = 0
var total_units_sold: int = 0


func _init(config: SimConfig = null) -> void:
	stock.resize(Goods.COUNT)
	price_milli.resize(Goods.COUNT)
	supply.resize(Goods.COUNT)
	demand.resize(Goods.COUNT)
	base_price_milli = Goods.BASE_PRICE_MILLI.duplicate()
	target_stock = Goods.TARGET_STOCK.duplicate()
	if config != null:
		target_stock[Goods.GRAIN] = config.market_grain_target
		target_stock[Goods.WOOD] = config.market_wood_target
		target_stock[Goods.TOOL] = config.market_tool_target
		stock[Goods.GRAIN] = config.market_grain_start
		stock[Goods.WOOD] = config.market_wood_start
		stock[Goods.TOOL] = config.market_tool_start
	for good in Goods.COUNT:
		price_milli[good] = base_price_milli[good]
		supply[good] = 0
		demand[good] = 0


func apply_daily_supply(config: SimConfig) -> void:
	_add_supply(Goods.GRAIN, config.market_grain_daily_supply)
	_add_supply(Goods.WOOD, config.market_wood_daily_supply)
	_add_supply(Goods.TOOL, config.market_tool_daily_supply)


func _add_supply(good: int, amount: int) -> void:
	if amount <= 0:
		return
	stock[good] = mini(stock[good] + amount,
		target_stock[good] * MAX_STOCK_FACTOR)
	supply[good] += amount


## Entnimmt Bestand für Export/Kauf. Liefert die tatsächlich entnommene Menge.
func take(good: int, amount: int) -> int:
	if good < 0 or good >= Goods.COUNT or amount <= 0:
		return 0
	var taken: int = mini(amount, stock[good])
	stock[good] -= taken
	return taken


func add_stock(good: int, amount: int) -> void:
	if good < 0 or good >= Goods.COUNT or amount <= 0:
		return
	stock[good] = mini(stock[good] + amount,
		target_stock[good] * MAX_STOCK_FACTOR)


func buy(good: int, amount: int) -> int:
	if amount <= 0 or stock[good] <= 0:
		return 0
	var bought: int = mini(amount, stock[good])
	stock[good] -= bought
	demand[good] += bought
	total_units_sold += bought
	return bought


func record_sale(value: int) -> void:
	total_sales_value += maxi(0, value)


## Gedämpfte, deterministische Preisfunktion:
## price += (base * stock_pressure * flow_pressure - price) / 4.
func update_prices(day: int) -> void:
	for good in Goods.COUNT:
		var stock_eff: int = maxi(stock[good], 1)
		var stock_pressure: int = (target_stock[good] * 1000) / stock_eff
		stock_pressure = clampi(stock_pressure, MIN_PRESSURE_MILLI,
			MAX_PRESSURE_MILLI)
		var flow: int = demand[good] - supply[good]
		var flow_pressure: int = 1000 \
			+ (flow * 1000) / maxi(1, target_stock[good])
		flow_pressure = clampi(flow_pressure, 1000 - FLOW_WINDOW_MILLI,
			1000 + FLOW_WINDOW_MILLI)
		var pressure: int = (stock_pressure * flow_pressure) / 1000
		var desired: int = (base_price_milli[good] * pressure) / 1000
		var min_price: int = base_price_milli[good] / 3
		var max_price: int = base_price_milli[good] * 3
		var delta: int = (desired - price_milli[good]) / DAMPING_DIVISOR
		price_milli[good] = clampi(price_milli[good] + delta,
			min_price, max_price)
		demand[good] = 0
		supply[good] = 0
	last_update_day = day


func max_price_ratio_permille() -> int:
	var best: int = 0
	for good in Goods.COUNT:
		var ratio: int = (price_milli[good] * 1000) / base_price_milli[good]
		if ratio > best:
			best = ratio
	return best


func price_ratio_permille(good: int) -> int:
	return (price_milli[good] * 1000) / maxi(1, base_price_milli[good])


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	for good in Goods.COUNT:
		h = HashUtil.mix_i64(h, stock[good])
		h = HashUtil.mix_i64(h, price_milli[good])
		h = HashUtil.mix_i64(h, supply[good])
		h = HashUtil.mix_i64(h, demand[good])
		h = HashUtil.mix_i64(h, base_price_milli[good])
		h = HashUtil.mix_i64(h, target_stock[good])
	h = HashUtil.mix_i64(h, last_update_day)
	h = HashUtil.mix_i64(h, total_sales_value)
	h = HashUtil.mix_i64(h, total_units_sold)
	return h


func write_to(w: ByteWriter) -> void:
	w.i32(Goods.COUNT)
	for good in Goods.COUNT:
		w.i64(stock[good])
		w.i64(price_milli[good])
		w.i64(supply[good])
		w.i64(demand[good])
		w.i64(base_price_milli[good])
		w.i64(target_stock[good])
	w.i64(last_update_day)
	w.i64(total_sales_value)
	w.i64(total_units_sold)


static func read_from(r: ByteReader) -> Market:
	var market: Market = Market.new()
	var count: int = r.i32()
	if count != Goods.COUNT:
		r.ok = false
		r.error = "bad_goods_count"
		return market
	for good in Goods.COUNT:
		market.stock[good] = r.i64()
		market.price_milli[good] = r.i64()
		market.supply[good] = r.i64()
		market.demand[good] = r.i64()
		market.base_price_milli[good] = r.i64()
		market.target_stock[good] = r.i64()
	market.last_update_day = r.i64()
	market.total_sales_value = r.i64()
	market.total_units_sold = r.i64()
	return market
