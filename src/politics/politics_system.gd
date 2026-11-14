class_name PoliticsSystem
extends RefCounted

## Leichte, deterministische Politikschicht: Schatzkammer, Steuersatz, Budget,
## zwei abstrakte Nachbarn mit Relation/Handelsabkommen, Geschenke und
## Verträge. Kein Krieg, keine LLM-Entscheidungen.

const WEEK_DAYS: int = 7

var nation: Nation
var unrest: int = 0
var budget_spent_total: int = 0
var tax_change_count: int = 0
var treaty_count: int = 0
var gift_count: int = 0
var tension_count: int = 0
var last_tax_change_day: int = -100000
var last_diplomacy_day: int = -100000


func _init(config: SimConfig = null) -> void:
	nation = Nation.new(config)


func on_day_tick(day: int, sim: Simulation) -> void:
	if sim == null or sim.economy == null:
		return
	_daily_budget()
	_update_unrest(sim)
	if day % WEEK_DAYS == 0:
		_tax_decision(day, sim)
		_diplomacy(day, sim)


func _daily_budget() -> void:
	if nation.treasury > 5000:
		var spend: int = nation.budget_granary + nation.budget_roads \
			+ nation.budget_guards
		nation.treasury -= spend
		budget_spent_total += spend
	var reserve_move: int = mini(nation.budget_reserve,
		maxi(0, nation.treasury))
	nation.treasury -= reserve_move
	nation.reserve_fund += reserve_move


func _update_unrest(sim: Simulation) -> void:
	var ratio: int = sim.economy.market.max_price_ratio_permille()
	var tax_component: int = (nation.tax_rate_permille * 100) / 250
	var price_component: int = clampi((ratio - 1000) / 10, 0, 50)
	var alive: int = maxi(1, sim.count_alive())
	var food_component: int = clampi(
		(sim.economy.daily_meals_skipped * 10000) / (alive * 3), 0, 50)
	unrest = clampi((tax_component + price_component + food_component) / 2,
		0, 100)


func _tax_decision(day: int, sim: Simulation) -> void:
	var old_rate: int = nation.tax_rate_permille
	var new_rate: int = old_rate
	if nation.treasury < 50000 and old_rate < 250:
		new_rate = mini(250, old_rate + 10)
	elif unrest > 60 and old_rate > 50:
		new_rate = maxi(50, old_rate - 10)
	elif nation.treasury > 800000 and old_rate > 50 and unrest < 40:
		new_rate = maxi(50, old_rate - 10)
	if new_rate == old_rate:
		return
	nation.tax_rate_permille = new_rate
	tax_change_count += 1
	last_tax_change_day = day
	sim.log_event(SimEvent.T_TAX_CHANGE, SimEvent.IMPORTANCE_NOTABLE, 0,
		"tax_change", "Steuersatz: %d‰ → %d‰" % [old_rate, new_rate], new_rate)


func _diplomacy(day: int, sim: Simulation) -> void:
	last_diplomacy_day = day
	var index: int = 0
	for neighbor_v in nation.neighbors:
		var neighbor: DiplomacyState = neighbor_v
		var drift: int = 2 if (day / WEEK_DAYS) % 3 == 0 else -1
		neighbor.relation = clampi(neighbor.relation + drift, -100, 100)
		if nation.treasury > 200000 and neighbor.relation < 40 \
				and day - neighbor.last_gift_day >= 30:
			nation.treasury -= 1000
			neighbor.relation = clampi(neighbor.relation + 10, -100, 100)
			neighbor.last_gift_day = day
			neighbor.gift_count += 1
			gift_count += 1
			sim.log_event(SimEvent.T_GIFT, SimEvent.IMPORTANCE_NOTABLE, 0,
				"diplomacy_gift", "Geschenk an %s (Relation %d)" % [
					neighbor.name, neighbor.relation], index)
		if neighbor.relation >= 40 and not neighbor.has_trade_treaty():
			neighbor.treaty = DiplomacyState.TREATY_TRADE
			neighbor.treaty_day = day
			treaty_count += 1
			sim.log_event(SimEvent.T_TREATY, SimEvent.IMPORTANCE_MAJOR, 0,
				"trade_treaty", "Handelsabkommen mit %s" % neighbor.name, index)
		elif neighbor.relation < -60 and day % 28 == 0:
			tension_count += 1
			sim.log_event(SimEvent.T_DIPLOMATIC_TENSION,
				SimEvent.IMPORTANCE_NOTABLE, 0, "diplomatic_tension",
				"Spannung mit %s (kein Krieg)" % neighbor.name, index)
		index += 1


func has_trade_treaty(neighbor_index: int) -> bool:
	return nation.has_trade_treaty(neighbor_index)


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, nation.state_hash())
	h = HashUtil.mix(h, unrest)
	h = HashUtil.mix_i64(h, budget_spent_total)
	h = HashUtil.mix_i64(h, tax_change_count)
	h = HashUtil.mix_i64(h, treaty_count)
	h = HashUtil.mix_i64(h, gift_count)
	h = HashUtil.mix_i64(h, tension_count)
	h = HashUtil.mix_i64(h, last_tax_change_day)
	h = HashUtil.mix_i64(h, last_diplomacy_day)
	return h


func write_to(w: ByteWriter) -> void:
	nation.write_to(w)
	w.i32(unrest)
	w.i64(budget_spent_total)
	w.i64(tax_change_count)
	w.i64(treaty_count)
	w.i64(gift_count)
	w.i64(tension_count)
	w.i64(last_tax_change_day)
	w.i64(last_diplomacy_day)


static func read_from(r: ByteReader, _config: SimConfig) -> PoliticsSystem:
	var system: PoliticsSystem = PoliticsSystem.new()
	system.nation = Nation.read_from(r)
	system.unrest = r.i32()
	system.budget_spent_total = r.i64()
	system.tax_change_count = r.i64()
	system.treaty_count = r.i64()
	system.gift_count = r.i64()
	system.tension_count = r.i64()
	system.last_tax_change_day = r.i64()
	system.last_diplomacy_day = r.i64()
	return system
