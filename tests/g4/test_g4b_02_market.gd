extends RefCounted

## T-G4b-02: Marktpreise reagieren gedämpft auf Bestand und Tagessaldo.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-02", "Marktpreise/Angebot/Nachfrage gedämpft und deterministisch")
	var sim: Simulation = G4BTestUtil.new_sim()
	var market: Market = sim.economy.market
	ctx.check_eq(market.stock.size(), Goods.COUNT, "Güteranzahl")
	# Niedriger Bestand -> Preis steigt, bleibt aber unter dem 3-fachen Basispreis.
	market.stock[Goods.WOOD] = 1
	market.price_milli[Goods.WOOD] = Goods.BASE_PRICE_MILLI[Goods.WOOD]
	market.supply[Goods.WOOD] = 0
	market.demand[Goods.WOOD] = 0
	var base_price: int = Goods.BASE_PRICE_MILLI[Goods.WOOD]
	market.update_prices(1)
	var low_stock_price: int = market.price_milli[Goods.WOOD]
	ctx.check(low_stock_price > base_price, "Preis steigt bei Knappheit nicht")
	ctx.check(low_stock_price <= base_price * 3, "Preis über Maximalgrenze")
	ctx.check(low_stock_price < base_price * 3,
		"Preis springt ungedämpft auf Maximum")
	# Hoher Bestand -> Preis fällt.
	market.stock[Goods.WOOD] = market.target_stock[Goods.WOOD] * 4
	market.price_milli[Goods.WOOD] = base_price
	for good in Goods.COUNT:
		market.supply[good] = 0
		market.demand[good] = 0
	market.update_prices(2)
	ctx.check(market.price_milli[Goods.WOOD] < base_price,
		"Preis fällt bei Überangebot nicht")
	# Nachfrage > Angebot hebt den Preis.
	market.stock[Goods.WOOD] = market.target_stock[Goods.WOOD]
	market.price_milli[Goods.WOOD] = base_price
	market.supply[Goods.WOOD] = 0
	market.demand[Goods.WOOD] = market.target_stock[Goods.WOOD] / 2
	market.update_prices(3)
	var demand_price: int = market.price_milli[Goods.WOOD]
	ctx.check(demand_price > base_price, "Nachfrage hebt Preis nicht")
	ctx.check_eq(market.demand[Goods.WOOD], 0, "Nachfrage nicht zurückgesetzt")
	# Angebot > Nachfrage senkt den Preis.
	market.stock[Goods.WOOD] = market.target_stock[Goods.WOOD]
	market.price_milli[Goods.WOOD] = base_price
	market.supply[Goods.WOOD] = market.target_stock[Goods.WOOD] / 2
	market.demand[Goods.WOOD] = 0
	market.update_prices(4)
	ctx.check(market.price_milli[Goods.WOOD] < base_price,
		"Angebot senkt Preis nicht")
	# Tagesbatch erzeugt echte Käufe und hält die Preise in den Grenzen.
	var sim2: Simulation = G4BTestUtil.new_sim(1338)
	G4BTestUtil.advance_chunked(sim2, sim2.clock.now + SimConfig.TICKS_PER_DAY, 3600)
	var market2: Market = sim2.economy.market
	ctx.check(market2.total_units_sold > 0, "keine Marktverkäufe")
	ctx.check(market2.total_sales_value > 0, "kein Markterlös")
	for good in Goods.COUNT:
		ctx.check(market2.stock[good] >= 0, "negativer Bestand: %d" % good)
		ctx.check(market2.price_milli[good] >= Goods.BASE_PRICE_MILLI[good] / 3,
			"Preis unter Minimum: %d" % good)
		ctx.check(market2.price_milli[good] <= Goods.BASE_PRICE_MILLI[good] * 3,
			"Preis über Maximum: %d" % good)
	# Determinismus der Preisfunktion.
	var a: Market = Market.new(SimConfig.civic(7))
	var b: Market = Market.new(SimConfig.civic(7))
	a.stock[Goods.TOOL] = 123
	b.stock[Goods.TOOL] = 123
	a.update_prices(9)
	b.update_prices(9)
	ctx.check_eq(a.state_hash(), b.state_hash(), "Preisfunktion nicht deterministisch")
