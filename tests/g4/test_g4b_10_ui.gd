extends RefCounted

## T-G4b-10: UI-Panels Markt/Schatzkammer/Diplomatie/Karawanen plus
## Karawanenmarker; alle Lesezugriffe sind read-only.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-10", "UI Markt/Schatzkammer/Diplomatie/Karawanen")
	var sim: Simulation = G4BTestUtil.shared_year()
	var state_before: int = sim.state_hash()
	var hud: EconomyHud = EconomyHud.new()
	hud.configure(sim, ViewState.new())
	hud.refresh(sim, true)
	var panels: Dictionary = hud.panel_text()
	ctx.check_eq(hud.tab_count(), 4, "nicht vier Wirtschafts-Panels")
	ctx.check_eq(panels.size(), 4, "Panel-Texte unvollständig")
	ctx.check(str(panels.get("market", "")).contains("Siedlungsmarkt"),
		"Marktpanel fehlt")
	ctx.check(str(panels.get("market", "")).contains("Preis"),
		"Marktpanel ohne Preise")
	ctx.check(str(panels.get("market", "")).contains("Grain")
		and str(panels.get("market", "")).contains("Holz")
		and str(panels.get("market", "")).contains("Werkzeug"),
		"Marktpanel ohne Güter")
	ctx.check(str(panels.get("treasury", "")).contains("Schatzkammer"),
		"Schatzkammerpanel fehlt")
	ctx.check(str(panels.get("treasury", "")).contains("Steuersatz"),
		"Steuersatz fehlt")
	ctx.check(str(panels.get("treasury", "")).contains("Budget"),
		"Budget fehlt")
	ctx.check(str(panels.get("diplomacy", "")).contains("Diplomatie"),
		"Diplomatiepanel fehlt")
	var politics: PoliticsSystem = sim.politics
	for neighbor_v in politics.nation.neighbors:
		var neighbor: DiplomacyState = neighbor_v
		ctx.check(str(panels.get("diplomacy", "")).contains(neighbor.name),
			"Nachbar fehlt im Diplomatiepanel: " + neighbor.name)
	ctx.check(str(panels.get("caravans", "")).contains("Karawanen"),
		"Karawanenpanel fehlt")
	for node_v in sim.economy.caravans.nodes:
		ctx.check(str(panels.get("caravans", "")).contains((node_v as ExternalNode).name),
			"Handelsknoten fehlt im Panel")
	# Karawanenmarker sind vorhanden und gültig.
	var marker_sim: Simulation = G4BTestUtil.new_sim(1342)
	G4BTestUtil.advance_chunked(marker_sim, marker_sim.clock.now \
		+ 10 * SimConfig.TICKS_PER_DAY, 3600)
	var markers: Array = marker_sim.economy.caravans.marker_entries(
		marker_sim.clock.now, marker_sim)
	ctx.check(markers.size() > 0, "keine Karawanenmarker")
	for marker_v in markers:
		var marker: Dictionary = marker_v
		var position: Vector2 = marker["position"]
		ctx.check(position.x >= 0.0 and position.x <= float(marker_sim.world.size)
			and position.y >= 0.0 and position.y <= float(marker_sim.world.size),
			"Karawanenmarker außerhalb der Welt")
	# UI-/Chronik-Lesen mutiert die Simulation nicht.
	ctx.check_eq(sim.state_hash(), state_before, "UI-Refresh mutiert Sim")
	hud.refresh(sim, true)
	ctx.check_eq(sim.state_hash(), state_before, "zweiter UI-Refresh mutiert Sim")
	hud.free()
