extends RefCounted

## T-G4b-04: Nation, Schatzkammer, Steuersatz, Budget und Geldbilanz.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-04", "Nation/Schatzkammer/Steuersatz/Budget")
	var sim: Simulation = G4BTestUtil.shared_year()
	var eco: EconomySystem = sim.economy
	var pol: PoliticsSystem = sim.politics
	ctx.check_eq(pol.nation.id, 1, "Nation-ID")
	ctx.check(pol.nation.name != "", "Nation ohne Namen")
	ctx.check(pol.nation.treasury > 0, "Schatzkammer nicht positiv")
	ctx.check(pol.nation.reserve_fund > 0, "Notreserve nicht aufgebaut")
	ctx.check(pol.nation.tax_rate_permille >= 50
		and pol.nation.tax_rate_permille <= 250, "Steuersatz außerhalb 50..250")
	ctx.check_eq(pol.nation.budget_granary, sim.config.budget_granary,
		"Kornbudget verändert")
	ctx.check_eq(pol.nation.budget_roads, sim.config.budget_roads,
		"Wegebudget verändert")
	ctx.check_eq(pol.nation.budget_guards, sim.config.budget_guards,
		"Wachenbudget verändert")
	ctx.check_eq(pol.nation.budget_reserve, sim.config.budget_reserve,
		"Notreservebudget verändert")
	ctx.check(pol.budget_spent_total > 0, "kein Budget ausgegeben")
	ctx.check(pol.tax_change_count > 0, "keine Steuerentscheidung")
	ctx.check(eco.total_taxes_collected > 0, "keine Steuereinnahmen")
	ctx.check(eco.total_wages_paid > 0, "keine Lohnausgaben")
	ctx.check(eco.total_market_sales > 0, "keine Markteinnahmen")
	# Vollständige Schatzkammer-Bilanz: alle Geldflüsse sind als Summen
	# gebucht, damit die Bilanz unabhängig von laufenden Karawanen exakt ist.
	var gift_total: int = pol.gift_count * 1000
	var expected: int = sim.config.nation_start_treasury \
		- eco.total_wages_paid + eco.total_taxes_collected \
		+ eco.total_market_sales + eco.caravans.cash_in_total \
		- eco.caravans.cash_out_total - pol.budget_spent_total \
		- gift_total - pol.nation.reserve_fund
	ctx.check_eq(pol.nation.treasury, expected,
		"Schatzkammer-Bilanz stimmt nicht")
	# Geldmenge bleibt begrenzt (Budget/Konsum sind Sinks).
	var supply: int = eco.total_money_supply(sim)
	ctx.check(supply > 0, "Geldmenge negativ")
	ctx.check(supply < 5000000, "Geldmenge ungebremst: %d" % supply)
	ctx.check_eq(SimConfig.civic(1337).save_schema_version(), 8,
		"G4b-Schema nicht 8")
	ctx.check_eq(SimConfig.scale(1337).save_schema_version(), 7,
		"G4a-Schema nicht 7")
	ctx.check_eq(SimConfig.g3(1337).save_schema_version(), 6,
		"G3-Schema nicht 6")
	ctx.check_eq(SimConfig.new().save_schema_version(), 5,
		"historisches Schema nicht 5")
	print("G4B_TREASURY treasury=%d expected=%d reserve=%d budget=%d gifts=%d wages=%d taxes=%d sales=%d cash_in=%d cash_out=%d profit=%d outstanding=%d household_money=%d supply=%d" % [
		pol.nation.treasury, expected, pol.nation.reserve_fund,
		pol.budget_spent_total, gift_total, eco.total_wages_paid,
		eco.total_taxes_collected, eco.total_market_sales,
		eco.caravans.cash_in_total, eco.caravans.cash_out_total,
		eco.caravans.profit_total, eco.caravans.outstanding_cost(),
		eco.household_money_total(), supply])
