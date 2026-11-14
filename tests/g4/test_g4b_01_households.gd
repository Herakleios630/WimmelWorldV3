extends RefCounted

## T-G4b-01: Haushaltsbudgets, Löhne, Steuern; Tagesbatch statt
## Per-Agent-Per-Tick-Transaktionen; Geldbilanz und Savings-Cap.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-01", "Haushaltsbudgets/Löhne/Steuern im Tagesbatch")
	var sim: Simulation = G4BTestUtil.new_sim()
	ctx.check(sim.economy != null, "EconomySystem fehlt")
	ctx.check(sim.politics != null, "PoliticsSystem fehlt")
	if sim.economy == null or sim.politics == null:
		return
	var eco: EconomySystem = sim.economy
	var pol: PoliticsSystem = sim.politics
	ctx.check_eq(eco.household_count, 2000, "Haushaltsanzahl")
	var start_money: int = eco.household_money_total()
	ctx.check_eq(start_money, 2000 * sim.config.household_start_money,
		"Startbudget der Haushalte")
	var day1: int = sim.clock.now + SimConfig.TICKS_PER_DAY
	G4BTestUtil.advance_chunked(sim, day1, 3600)
	ctx.check_eq(eco.batch_count, 1, "nicht genau ein Tagesbatch")
	var wages1: int = eco.total_wages_paid
	var taxes1: int = eco.total_taxes_collected
	var sales1: int = eco.total_market_sales
	ctx.check(wages1 > 0, "keine Löhne")
	ctx.check(taxes1 > 0, "keine Steuern")
	ctx.check(sales1 > 0, "keine Marktverkäufe")
	ctx.check_eq(eco.household_income_total(), wages1,
		"Haushaltseinkommen != ausgezahlte Löhne")
	var tax_share: int = (taxes1 * 1000) / maxi(1, wages1)
	ctx.check(tax_share >= 80 and tax_share <= 120,
		"Steueranteil nicht ~10%%: %d‰" % tax_share)
	var expected_money: int = start_money + wages1 - taxes1 - sales1 \
		- eco.total_consumption_sink
	ctx.check_eq(eco.household_money_total(), expected_money,
		"Haushaltsgeld-Bilanz stimmt nicht")
	ctx.check(pol.nation.treasury > 0, "Schatzkammer nicht positiv")
	# Zweiter Tag: weiterer Batch, kumulierte Werte wachsen.
	var day2: int = sim.clock.now + SimConfig.TICKS_PER_DAY
	G4BTestUtil.advance_chunked(sim, day2, 3600)
	ctx.check_eq(eco.batch_count, 2, "nicht zwei Tagesbatches")
	ctx.check(eco.total_wages_paid > wages1, "Löhne wachsen nicht")
	ctx.check(eco.total_taxes_collected > taxes1, "Steuern wachsen nicht")
	# Kein Per-Agent-Tick: Batchzahl bleibt an Sim-Tage gebunden.
	ctx.check(eco.batch_count <= 2, "mehr als ein Batch pro Tag")
	# Savings-Cap verhindert unendliche Geldvermehrung pro Haushalt.
	var cap: int = sim.config.household_money_cap
	var sink_before: int = eco.total_consumption_sink
	eco.household_money[0] = cap + 5000
	eco._apply_savings_cap()
	ctx.check_eq(eco.household_money[0], cap, "Savings-Cap greift nicht")
	ctx.check(eco.total_consumption_sink >= sink_before + 5000,
		"Konsum-Sink nicht gebucht")
	# Lohn-/Steuer-Aggregate sind deterministisch.
	var other: Simulation = G4BTestUtil.new_sim()
	G4BTestUtil.advance_chunked(other, other.clock.now \
		+ 2 * SimConfig.TICKS_PER_DAY, 60)
	ctx.check_eq(other.economy.total_wages_paid, eco.total_wages_paid,
		"Löhne nicht deterministisch")
	ctx.check_eq(other.economy.total_taxes_collected, eco.total_taxes_collected,
		"Steuern nicht deterministisch")
