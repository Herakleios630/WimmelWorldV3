class_name EconomyHud
extends CanvasLayer

## Read-only G4b-Panels für Markt, Schatzkammer, Diplomatie und Karawanen.
## Liest ausschließlich Simulation/ViewState und schreibt nie Simulation.

const REFRESH_MS: int = 500

var sim: Simulation
var view_state: ViewState
var _root: PanelContainer
var _tabs: TabContainer
var _market_text: RichTextLabel
var _treasury_text: RichTextLabel
var _diplomacy_text: RichTextLabel
var _caravan_text: RichTextLabel
var _last_refresh_ms: int = 0
var _panel_text: Dictionary = {}
const TAB_TITLES: Array = ["Markt", "Schatzkammer", "Diplomatie", "Karawanen"]


func _ready() -> void:
	layer = 2


func configure(p_sim: Simulation, p_view_state: ViewState) -> void:
	sim = p_sim
	view_state = p_view_state
	_build()
	refresh(sim, true)


func _build() -> void:
	_root = PanelContainer.new()
	_root.anchor_left = 0.0
	_root.anchor_right = 0.0
	_root.anchor_top = 1.0
	_root.anchor_bottom = 1.0
	_root.offset_left = 12.0
	_root.offset_right = 452.0
	_root.offset_top = -336.0
	_root.offset_bottom = -58.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(440, 278)
	_root.add_child(_tabs)
	_market_text = _make_tab("Markt")
	_treasury_text = _make_tab("Schatzkammer")
	_diplomacy_text = _make_tab("Diplomatie")
	_caravan_text = _make_tab("Karawanen")


func _make_tab(title: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.name = title
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.custom_minimum_size = Vector2(420, 240)
	_tabs.add_child(label)
	return label


func refresh(p_sim: Simulation, force: bool = false) -> void:
	if p_sim != null:
		sim = p_sim
	if sim == null or sim.economy == null or _tabs == null:
		return
	_root.visible = view_state == null or view_state.economy_visible
	if not _root.visible:
		return
	var now_ms: int = Time.get_ticks_msec()
	if not force and now_ms - _last_refresh_ms < REFRESH_MS:
		return
	_last_refresh_ms = now_ms
	var economy: EconomySystem = sim.economy
	var market: Market = economy.market
	var politics: PoliticsSystem = sim.politics
	var market_lines: PackedStringArray = PackedStringArray()
	market_lines.append("[b]Siedlungsmarkt[/b] · Index %d%%" % [
		market.max_price_ratio_permille() / 10])
	for good in Goods.COUNT:
		market_lines.append("%s: Preis %d · Lager %d · Nachfrage %d · Angebot %d" % [
			Goods.name_of(good), Goods.unit_price(market.price_milli[good]),
			market.stock[good], market.demand[good], market.supply[good]])
	market_lines.append("Verkäufe: %d Einheiten / %d Geld" % [
		market.total_units_sold, market.total_sales_value])
	market_lines.append("Haushaltsgeld: %d · Ausgaben: %d" % [
		economy.household_money_total(), economy.household_spent_total()])
	_market_text.text = "\n".join(market_lines)
	var treasury_lines: PackedStringArray = PackedStringArray()
	if politics != null:
		treasury_lines.append("[b]Schatzkammer[/b] · %s" % politics.nation.name)
		treasury_lines.append("Schatz: %d Geld · Notreserve: %d" % [
			politics.nation.treasury, politics.nation.reserve_fund])
		treasury_lines.append("Steuersatz: %d‰ · Unruhe: %d" % [
			politics.nation.tax_rate_permille, politics.unrest])
		treasury_lines.append("Budget: Korn %d · Wege %d · Wachen %d · Reserve %d" % [
			politics.nation.budget_granary, politics.nation.budget_roads,
			politics.nation.budget_guards, politics.nation.budget_reserve])
		treasury_lines.append("Löhne: %d · Steuern: %d · Markt: %d" % [
			economy.total_wages_paid, economy.total_taxes_collected,
			economy.total_market_sales])
		treasury_lines.append("Geldmenge: %d · Konsum-Sink: %d" % [
			economy.total_money_supply(sim), economy.total_consumption_sink])
		treasury_lines.append("Spezialisierung: %s" % politics.nation.specialization_name())
	_treasury_text.text = "\n".join(treasury_lines)
	var diplomacy_lines: PackedStringArray = PackedStringArray()
	if politics != null:
		diplomacy_lines.append("[b]Diplomatie[/b] · kein Krieg")
		for neighbor_v in politics.nation.neighbors:
			var neighbor: DiplomacyState = neighbor_v
			var treaty: String = "Handelsabkommen" if neighbor.has_trade_treaty() \
				else "kein Vertrag"
			diplomacy_lines.append("%s: Relation %d · %s · Geschenke %d" % [
				neighbor.name, neighbor.relation, treaty, neighbor.gift_count])
		diplomacy_lines.append("Verträge: %d · Geschenke: %d · Spannungen: %d" % [
			politics.treaty_count, politics.gift_count, politics.tension_count])
	_diplomacy_text.text = "\n".join(diplomacy_lines)
	var caravan_lines: PackedStringArray = PackedStringArray()
	caravan_lines.append("[b]Karawanen[/b] · aktiv %d · abgeschlossen %d" % [
		economy.caravans.active_count(), economy.caravans.completed_count])
	caravan_lines.append("Bilanz: %+d Geld" % economy.caravans.profit_total)
	for entry in economy.caravans.marker_entries(sim.clock.now, sim):
		caravan_lines.append("K%d → %s · %s · %d %s · ETA %s" % [
			int(entry["id"]), str(entry["node_name"]), str(entry["state"]),
			int(entry["cargo_amount"]), Goods.name_of(int(entry["cargo_good"])),
			SimClock.new(int(entry["eta"])).time_string()])
	for node_v in economy.caravans.nodes:
		var node: ExternalNode = node_v
		caravan_lines.append("%s: Grain %d · Holz %d · Werkzeug %d" % [
			node.name, Goods.unit_price(node.price_milli[Goods.GRAIN]),
			Goods.unit_price(node.price_milli[Goods.WOOD]),
			Goods.unit_price(node.price_milli[Goods.TOOL])])
	_caravan_text.text = "\n".join(caravan_lines)
	_panel_text = {
		"market": _market_text.text,
		"treasury": _treasury_text.text,
		"diplomacy": _diplomacy_text.text,
		"caravans": _caravan_text.text,
	}


func panel_text() -> Dictionary:
	return _panel_text.duplicate()


func tab_count() -> int:
	return TAB_TITLES.size()
