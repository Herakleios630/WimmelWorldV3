class_name EconomySystem
extends RefCounted

## Leichte, deterministische Wirtschaftsschicht auf dem 10k-Kern.
##
## Alle Buchungen laufen in einem Tagesbatch pro Siedlung/Haushalt. Es gibt
## keine Transaktion pro Agent und Tick. Grain bleibt G4a-öffentlich; der
## Markt handelt nur einen kleinen separaten Marktanteil.

const CRISIS_SHORTAGE: int = 0
const CRISIS_PRICE: int = 1
const CRISIS_DEBT: int = 2
const CRISIS_UNREST: int = 3
const CRISIS_COUNT: int = 4
const NO_CRISIS_DAY: int = -100000

var market: Market
var caravans: CaravanSystem
var household_count: int = 0
var household_money: PackedInt64Array = PackedInt64Array()
var household_income: PackedInt64Array = PackedInt64Array()
var household_tax: PackedInt64Array = PackedInt64Array()
var household_spent: PackedInt64Array = PackedInt64Array()
var total_wages_paid: int = 0
var total_taxes_collected: int = 0
var total_market_sales: int = 0
var total_consumption_sink: int = 0
var total_caravan_profit: int = 0
var batch_count: int = 0
var last_batch_day: int = -1
var last_meals_skipped: int = 0
var daily_meals_skipped: int = 0
var price_event_day: int = -100000
var crisis_last_day: PackedInt32Array = PackedInt32Array()
var crisis_counts: PackedInt32Array = PackedInt32Array()
var crisis_active: PackedByteArray = PackedByteArray()
# Nur Diagnose, nicht Teil des autoritativen Zustands/Saves.
var last_batch_usec: int = 0
var max_batch_usec: int = 0
var total_batch_usec: int = 0


func _init(config: SimConfig = null) -> void:
	market = Market.new(config)
	caravans = CaravanSystem.new(config)
	household_count = config.target_households if config != null else 0
	household_money.resize(household_count)
	household_income.resize(household_count)
	household_tax.resize(household_count)
	household_spent.resize(household_count)
	household_money.fill(config.household_start_money if config != null else 0)
	_household_money_cap = config.household_money_cap if config != null else 3000
	crisis_last_day.resize(CRISIS_COUNT)
	crisis_last_day.fill(NO_CRISIS_DAY)
	crisis_counts.resize(CRISIS_COUNT)
	crisis_counts.fill(0)
	crisis_active.resize(CRISIS_COUNT)
	crisis_active.fill(0)


func on_day_tick(day: int, sim: Simulation) -> void:
	if sim == null or sim.politics == null:
		return
	var t0: int = Time.get_ticks_usec()
	batch_count += 1
	last_batch_day = day
	daily_meals_skipped = maxi(0, sim.meals_skipped - last_meals_skipped)
	last_meals_skipped = sim.meals_skipped
	_pay_wages(sim)
	_collect_taxes(sim)
	market.apply_daily_supply(sim.config)
	_household_purchases(day, sim)
	var caravan_before: int = caravans.profit_total
	caravans.on_day_tick(day, sim, self)
	total_caravan_profit += caravans.profit_total - caravan_before
	market.update_prices(day)
	_apply_savings_cap()
	_maybe_price_event(day, sim)
	last_batch_usec = Time.get_ticks_usec() - t0
	total_batch_usec += last_batch_usec
	if last_batch_usec > max_batch_usec:
		max_batch_usec = last_batch_usec


func batch_stats() -> Dictionary:
	return {
		"batches": batch_count,
		"last_us": last_batch_usec,
		"max_us": max_batch_usec,
		"avg_us": total_batch_usec / maxi(1, batch_count),
	}


func _pay_wages(sim: Simulation) -> void:
	household_income.fill(0)
	var config: SimConfig = sim.config
	var store: AgentStore = sim.store
	var total: int = 0
	for row in store.count:
		if store.alive[row] == 0:
			continue
		var age: int = store.age_years[row]
		if age < 12:
			continue
		var kind: int = store.job_kind[row]
		var wage: int = 0
		if kind == AgentStore.JOB_FIELD:
			wage = config.wage_field if age < 65 else config.wage_light
		elif kind == AgentStore.JOB_WORKSHOP:
			if age < 18 or age >= 65:
				wage = config.wage_light
			else:
				wage = config.wage_workshop
		if wage <= 0:
			continue
		var index: int = store.household_id[row] - 1
		if index >= 0 and index < household_count:
			household_income[index] += wage
			total += wage
	if total <= 0:
		return
	var treasury: int = sim.politics.nation.treasury
	var factor: int = 1000
	if treasury < total:
		factor = clampi((maxi(0, treasury) * 1000) / total, 0, 1000)
	var paid_total: int = 0
	for i in household_count:
		var paid: int = (household_income[i] * factor) / 1000
		household_income[i] = paid
		household_money[i] += paid
		paid_total += paid
	sim.politics.nation.treasury -= paid_total
	total_wages_paid += paid_total


func _collect_taxes(sim: Simulation) -> void:
	var rate: int = sim.politics.nation.tax_rate_permille
	var total_income: int = household_income_total()
	var total_tax: int = (total_income * rate) / 1000
	var assigned: int = 0
	for i in household_count:
		var tax: int = (household_income[i] * total_tax) / maxi(1, total_income)
		household_tax[i] = tax
		household_money[i] -= tax
		assigned += tax
	var remainder: int = total_tax - assigned
	for i in household_count:
		if remainder <= 0:
			break
		if household_income[i] > 0:
			household_tax[i] += 1
			household_money[i] -= 1
			remainder -= 1
	sim.politics.nation.treasury += total_tax
	total_taxes_collected += total_tax


func _household_purchases(day: int, sim: Simulation) -> void:
	var cash: int = 0
	for i in household_count:
		# Holz kauft jeder Haushalt täglich; Werkzeug und Grain rotieren
		# deterministisch über die Haushalte, damit keine Tagescluster entstehen.
		cash += _try_buy(i, Goods.WOOD, 1)
		if (day + i) % 5 == 0:
			cash += _try_buy(i, Goods.TOOL, 1)
		if (day + i) % 3 == 0:
			cash += _try_buy(i, Goods.GRAIN, 1)
	sim.politics.nation.treasury += cash
	total_market_sales += cash


func _try_buy(index: int, good: int, amount: int) -> int:
	var unit: int = Goods.unit_price(market.price_milli[good])
	if market.stock[good] <= 0 or household_money[index] < unit:
		return 0
	var bought: int = market.buy(good, amount)
	if bought <= 0:
		return 0
	var cost: int = bought * unit
	household_money[index] -= cost
	household_spent[index] += cost
	market.record_sale(cost)
	return cost


func _apply_savings_cap() -> void:
	var cap: int = market_base_cap()
	for i in household_count:
		if household_money[i] > cap:
			total_consumption_sink += household_money[i] - cap
			household_money[i] = cap


var _household_money_cap: int = 3000


func market_base_cap() -> int:
	return _household_money_cap


func configure_cap(cap: int) -> void:
	_household_money_cap = maxi(1, cap)


func _maybe_price_event(day: int, sim: Simulation) -> void:
	var ratio: int = market.max_price_ratio_permille()
	if ratio >= 1250 or ratio <= 750:
		if day - price_event_day < 5:
			return
		price_event_day = day
		sim.log_event(SimEvent.T_MARKET_PRICE, SimEvent.IMPORTANCE_NOTABLE, 0,
			"market_price", "Marktpreise: Grain %d, Holz %d, Werkzeug %d (Index %d%%)" % [
				Goods.unit_price(market.price_milli[Goods.GRAIN]),
				Goods.unit_price(market.price_milli[Goods.WOOD]),
				Goods.unit_price(market.price_milli[Goods.TOOL]),
				ratio / 10], ratio)


func on_crisis_check(day: int, sim: Simulation) -> void:
	if sim.politics == null:
		return
	var ratio: int = market.max_price_ratio_permille()
	_check_crisis(CRISIS_SHORTAGE, day, sim,
		sim.grain < sim.config.shortage_grain_threshold
			or market.stock[Goods.GRAIN] < 2000,
		SimEvent.IMPORTANCE_MAJOR, SimEvent.T_CRISIS_SHORTAGE,
		"crisis_shortage", "Knappheit: Kornspeicher %d, Markt-Grain %d" % [
			sim.grain, market.stock[Goods.GRAIN]], sim.grain)
	_check_crisis(CRISIS_PRICE, day, sim,
		ratio >= sim.config.price_spike_permille,
		SimEvent.IMPORTANCE_NOTABLE, SimEvent.T_CRISIS_PRICE,
		"crisis_price", "Preisspitze: Marktindex %d%%" % [ratio / 10], ratio)
	_check_crisis(CRISIS_DEBT, day, sim, sim.politics.nation.treasury < 0,
		SimEvent.IMPORTANCE_MAJOR, SimEvent.T_CRISIS_DEBT,
		"crisis_debt", "Überschuldung: Schatzkammer %d" % [
			sim.politics.nation.treasury], sim.politics.nation.treasury)
	_check_crisis(CRISIS_UNREST, day, sim,
		sim.politics.unrest >= sim.config.unrest_threshold,
		SimEvent.IMPORTANCE_MAJOR, SimEvent.T_CRISIS_UNREST,
		"crisis_unrest", "Unruhe: %d (Steuersatz %d‰)" % [
			sim.politics.unrest, sim.politics.nation.tax_rate_permille],
		sim.politics.unrest)


func _check_crisis(kind: int, day: int, sim: Simulation, condition: bool,
		importance: int, event_type: int, template: String, text: String,
		data: int) -> void:
	if not condition:
		crisis_active[kind] = 0
		return
	if day - crisis_last_day[kind] < sim.config.crisis_cooldown_days:
		return
	crisis_last_day[kind] = day
	crisis_counts[kind] += 1
	crisis_active[kind] = 1
	sim.log_event(event_type, importance, 0, template, text, data)


func household_money_total() -> int:
	var total: int = 0
	for value in household_money:
		total += value
	return total


func household_income_total() -> int:
	var total: int = 0
	for value in household_income:
		total += value
	return total


func household_tax_total() -> int:
	var total: int = 0
	for value in household_tax:
		total += value
	return total


func household_spent_total() -> int:
	var total: int = 0
	for value in household_spent:
		total += value
	return total


func total_money_supply(sim: Simulation) -> int:
	var total: int = household_money_total()
	if sim.politics != null:
		total += sim.politics.nation.treasury
		total += sim.politics.nation.reserve_fund
	return total


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, market.state_hash())
	h = HashUtil.mix(h, caravans.state_hash())
	h = HashUtil.mix(h, household_count)
	for i in household_count:
		h = HashUtil.mix_i64(h, household_money[i])
		h = HashUtil.mix_i64(h, household_income[i])
		h = HashUtil.mix_i64(h, household_tax[i])
		h = HashUtil.mix_i64(h, household_spent[i])
	h = HashUtil.mix_i64(h, total_wages_paid)
	h = HashUtil.mix_i64(h, total_taxes_collected)
	h = HashUtil.mix_i64(h, total_market_sales)
	h = HashUtil.mix_i64(h, total_consumption_sink)
	h = HashUtil.mix_i64(h, total_caravan_profit)
	h = HashUtil.mix_i64(h, batch_count)
	h = HashUtil.mix_i64(h, last_batch_day)
	h = HashUtil.mix_i64(h, last_meals_skipped)
	h = HashUtil.mix_i64(h, daily_meals_skipped)
	h = HashUtil.mix_i64(h, price_event_day)
	for i in CRISIS_COUNT:
		h = HashUtil.mix(h, crisis_last_day[i])
		h = HashUtil.mix(h, crisis_counts[i])
		h = HashUtil.mix(h, crisis_active[i])
	return h


func write_to(w: ByteWriter) -> void:
	market.write_to(w)
	caravans.write_to(w)
	w.i32(household_count)
	for i in household_count:
		w.i64(household_money[i])
		w.i64(household_income[i])
		w.i64(household_tax[i])
		w.i64(household_spent[i])
	w.i64(total_wages_paid)
	w.i64(total_taxes_collected)
	w.i64(total_market_sales)
	w.i64(total_consumption_sink)
	w.i64(total_caravan_profit)
	w.i64(batch_count)
	w.i64(last_batch_day)
	w.i64(last_meals_skipped)
	w.i64(daily_meals_skipped)
	w.i64(price_event_day)
	for i in CRISIS_COUNT:
		w.i32(crisis_last_day[i])
		w.i32(crisis_counts[i])
		w.u8(crisis_active[i])
	w.i64(_household_money_cap)


static func read_from(r: ByteReader, config: SimConfig) -> EconomySystem:
	var system: EconomySystem = EconomySystem.new(config)
	system.market = Market.read_from(r)
	system.caravans = CaravanSystem.read_from(r)
	system.household_count = r.i32()
	if system.household_count < 0 or system.household_count > 100000:
		r.ok = false
		r.error = "bad_household_count"
		return system
	system.household_money.resize(system.household_count)
	system.household_income.resize(system.household_count)
	system.household_tax.resize(system.household_count)
	system.household_spent.resize(system.household_count)
	for i in system.household_count:
		system.household_money[i] = r.i64()
		system.household_income[i] = r.i64()
		system.household_tax[i] = r.i64()
		system.household_spent[i] = r.i64()
	system.total_wages_paid = r.i64()
	system.total_taxes_collected = r.i64()
	system.total_market_sales = r.i64()
	system.total_consumption_sink = r.i64()
	system.total_caravan_profit = r.i64()
	system.batch_count = r.i64()
	system.last_batch_day = r.i64()
	system.last_meals_skipped = r.i64()
	system.daily_meals_skipped = r.i64()
	system.price_event_day = r.i64()
	for i in CRISIS_COUNT:
		system.crisis_last_day[i] = r.i32()
		system.crisis_counts[i] = r.i32()
		system.crisis_active[i] = r.u8()
	system._household_money_cap = r.i64()
	return system
