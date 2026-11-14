class_name CaravanSystem
extends RefCounted

## 2-3 externe Knoten plus wenige physische Karawanen. Jede Karawane lädt am
## Siedlungsmarkt, reist deterministisch zum Knoten, verkauft dort, lädt ein
## Rückfahrgut und bringt es zurück. Es gibt keine Per-Tick-Transaktion und
## keinen lokalen 10k-Agenten pro Karawane.

const MAX_ACTIVE: int = 3
const MIN_CARGO: int = 10
const TRIP_BASE_COST: int = 200
const ROUTE_MID_OFFSET: float = 120.0

var nodes: Array = []
var caravans: Array = []
var next_id: int = 1
var dispatched_count: int = 0
var completed_count: int = 0
var profit_total: int = 0
var cash_in_total: int = 0
var cash_out_total: int = 0
var last_dispatch_day: int = -1


func _init(_config: SimConfig = null) -> void:
	nodes = ExternalNode.defaults()


func active_count() -> int:
	return caravans.size()


## Gebundene Kosten noch laufender Karawanen (Trip + bereits bezahlte Importe).
func outstanding_cost() -> int:
	var total: int = 0
	for caravan_v in caravans:
		var c: Caravan = caravan_v
		total += c.trip_cost + c.import_cost
	return total


func on_day_tick(day: int, sim: Simulation, economy) -> void:
	var now: int = day * SimConfig.TICKS_PER_DAY
	var keep: Array = []
	for caravan_v in caravans:
		var c: Caravan = caravan_v
		if c.state == Caravan.STATE_OUTBOUND and now >= c.arrive_time:
			_arrive(c, sim, economy, now)
		if c.state == Caravan.STATE_INBOUND and now >= c.return_time:
			_finish(c, sim, economy, now)
		else:
			keep.append(c)
	caravans = keep
	if day % maxi(1, sim.config.caravan_dispatch_interval_days) == 0 \
			and caravans.size() < MAX_ACTIVE:
		_dispatch(day, sim, economy, now)


func _tariff_for(node: ExternalNode, sim: Simulation) -> int:
	if node.neighbor_index >= 0 and sim.politics != null \
			and sim.politics.has_trade_treaty(node.neighbor_index):
		return sim.config.treaty_tariff_permille
	return sim.config.tariff_permille


func _dispatch(day: int, sim: Simulation, economy, now: int) -> void:
	var market: Market = economy.market
	var best_node: ExternalNode = null
	var best_good: int = 0
	var best_margin: int = -1
	var transport_milli: int = sim.config.caravan_transport_cost
	for node_v in nodes:
		var node: ExternalNode = node_v
		for good in Goods.COUNT:
			var reserve: int = market.target_stock[good] / 4
			if market.stock[good] - reserve < MIN_CARGO:
				continue
			var margin: int = node.price_milli[good] \
				- market.price_milli[good] - transport_milli
			if margin > best_margin:
				best_margin = margin
				best_node = node
				best_good = good
	if best_node == null or best_margin <= 0:
		return
	var reserve2: int = market.target_stock[best_good] / 4
	var available: int = market.stock[best_good] - reserve2
	var cargo: int = mini(sim.config.caravan_capacity, available)
	if cargo < MIN_CARGO:
		return
	var trip_cost: int = TRIP_BASE_COST \
		+ (cargo * sim.config.caravan_transport_cost) / 1000
	if sim.politics.nation.treasury < trip_cost:
		return
	market.take(best_good, cargo)
	sim.politics.nation.treasury -= trip_cost
	cash_out_total += trip_cost
	var travel: int = sim.config.caravan_travel_days * SimConfig.TICKS_PER_DAY
	var caravan: Caravan = Caravan.new(next_id, best_node.id, best_good, cargo,
		now, now + travel, trip_cost)
	caravan.tariff_permille = _tariff_for(best_node, sim)
	next_id += 1
	caravans.append(caravan)
	dispatched_count += 1
	last_dispatch_day = day
	sim.log_event(SimEvent.T_CARAVAN_DEPART, SimEvent.IMPORTANCE_NOTABLE, 0,
		"caravan_depart", "Karawane %d bringt %d %s nach %s" % [
			caravan.id, cargo, Goods.name_of(best_good), best_node.name],
		caravan.id)


func _arrive(c: Caravan, sim: Simulation, economy, now: int) -> void:
	var node: ExternalNode = nodes[c.node_id]
	var unit: int = node.sell_price(c.cargo_good, c.tariff_permille)
	c.sale_revenue = (c.cargo_amount * unit) / 1000
	sim.politics.nation.treasury += c.sale_revenue
	cash_in_total += c.sale_revenue
	node.stock[c.cargo_good] += c.cargo_amount
	sim.log_event(SimEvent.T_CARAVAN_ARRIVE, SimEvent.IMPORTANCE_NOTABLE, 0,
		"caravan_arrive", "Karawane %d erreicht %s (%d %s, +%d Geld)" % [
			c.id, node.name, c.cargo_amount, Goods.name_of(c.cargo_good),
			c.sale_revenue], c.id)
	# Rückfahrgut: höchster Preisvorteil am Heimatmarkt.
	var best_good: int = -1
	var best_margin: int = -1
	var transport_milli: int = sim.config.caravan_transport_cost
	for good in Goods.COUNT:
		var margin: int = economy.market.price_milli[good] \
			- node.price_milli[good] - transport_milli
		if margin > best_margin:
			best_margin = margin
			best_good = good
	var travel: int = sim.config.caravan_travel_days * SimConfig.TICKS_PER_DAY
	c.state = Caravan.STATE_INBOUND
	c.return_time = now + travel
	if best_good < 0 or best_margin <= 0:
		c.import_good = -1
		c.import_amount = 0
		return
	var affordable: int = (sim.politics.nation.treasury * 1000) \
		/ maxi(1, node.price_milli[best_good])
	var amount: int = mini(sim.config.caravan_capacity,
		mini(affordable, node.stock[best_good]))
	if amount < MIN_CARGO:
		c.import_good = -1
		c.import_amount = 0
		return
	c.import_good = best_good
	c.import_amount = amount
	c.import_cost = (amount * node.price_milli[best_good]) / 1000
	sim.politics.nation.treasury -= c.import_cost
	cash_out_total += c.import_cost
	node.stock[best_good] -= amount


func _finish(c: Caravan, sim: Simulation, economy, now: int) -> void:
	if c.import_good >= 0 and c.import_amount > 0:
		economy.market.add_stock(c.import_good, c.import_amount)
	var profit: int = c.sale_revenue - c.import_cost - c.trip_cost
	profit_total += profit
	completed_count += 1
	sim.log_event(SimEvent.T_CARAVAN_RETURN, SimEvent.IMPORTANCE_NOTABLE, 0,
		"caravan_return", "Karawane %d kehrt zurück (%d %s, Bilanz %+d)" % [
			c.id, c.import_amount,
			Goods.name_of(c.import_good) if c.import_good >= 0 else "Ballast",
			profit], c.id)


## Reine Darstellungsroute. Keine Simulationszustandsänderung.
func route_points(node: ExternalNode, sim: Simulation) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var market_point: Vector2 = sim.world.door_point(sim.world.granary_id())
	var gate_point: Vector2 = Vector2(float(node.gate_tile.x) + 0.5,
		float(node.gate_tile.y) + 0.5)
	var mid: Vector2 = Vector2(gate_point.x - ROUTE_MID_OFFSET, market_point.y)
	points.append(market_point)
	points.append(mid)
	points.append(gate_point)
	return points


func marker_position(c: Caravan, now: int, sim: Simulation) -> Vector2:
	if c.node_id < 0 or c.node_id >= nodes.size():
		return Vector2.ZERO
	var node: ExternalNode = nodes[c.node_id]
	var points: PackedVector2Array = route_points(node, sim)
	var length: float = WorldMap.polyline_length(points)
	var fraction: float = 0.0
	if c.state == Caravan.STATE_OUTBOUND:
		var span: int = maxi(1, c.arrive_time - c.depart_time)
		fraction = clampf(float(now - c.depart_time) / float(span), 0.0, 1.0)
	else:
		var span2: int = maxi(1, c.return_time - c.arrive_time)
		fraction = clampf(float(now - c.arrive_time) / float(span2), 0.0, 1.0)
		fraction = 1.0 - fraction
	return WorldMap.point_on_polyline(points, length * fraction)


func marker_entries(now: int, sim: Simulation) -> Array:
	var out: Array = []
	for caravan_v in caravans:
		var c: Caravan = caravan_v
		var node: ExternalNode = nodes[c.node_id]
		out.append({
			"id": c.id,
			"position": marker_position(c, now, sim),
			"node_name": node.name,
			"state": c.state_name(),
			"cargo_good": c.cargo_good,
			"cargo_amount": c.cargo_amount,
			"eta": c.arrive_time if c.state == Caravan.STATE_OUTBOUND else c.return_time,
		})
	return out


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	for node_v in nodes:
		h = HashUtil.mix(h, (node_v as ExternalNode).state_hash())
	for caravan_v in caravans:
		h = HashUtil.mix(h, (caravan_v as Caravan).state_hash())
	h = HashUtil.mix(h, next_id)
	h = HashUtil.mix_i64(h, dispatched_count)
	h = HashUtil.mix_i64(h, completed_count)
	h = HashUtil.mix_i64(h, profit_total)
	h = HashUtil.mix_i64(h, cash_in_total)
	h = HashUtil.mix_i64(h, cash_out_total)
	h = HashUtil.mix_i64(h, last_dispatch_day)
	return h


func write_to(w: ByteWriter) -> void:
	w.u32(nodes.size())
	for node_v in nodes:
		(node_v as ExternalNode).write_to(w)
	w.u32(caravans.size())
	for caravan_v in caravans:
		(caravan_v as Caravan).write_to(w)
	w.i32(next_id)
	w.i64(dispatched_count)
	w.i64(completed_count)
	w.i64(profit_total)
	w.i64(cash_in_total)
	w.i64(cash_out_total)
	w.i64(last_dispatch_day)


static func read_from(r: ByteReader) -> CaravanSystem:
	var system: CaravanSystem = CaravanSystem.new()
	system.nodes.clear()
	var node_count: int = r.u32()
	if node_count < 0 or node_count > 16:
		r.ok = false
		r.error = "bad_external_nodes"
		return system
	for _i in node_count:
		system.nodes.append(ExternalNode.read_from(r))
	var caravan_count: int = r.u32()
	if caravan_count < 0 or caravan_count > MAX_ACTIVE * 4:
		r.ok = false
		r.error = "bad_caravans"
		return system
	for _i in caravan_count:
		system.caravans.append(Caravan.read_from(r))
	system.next_id = r.i32()
	system.dispatched_count = r.i64()
	system.completed_count = r.i64()
	system.profit_total = r.i64()
	system.cash_in_total = r.i64()
	system.cash_out_total = r.i64()
	system.last_dispatch_day = r.i64()
	return system
