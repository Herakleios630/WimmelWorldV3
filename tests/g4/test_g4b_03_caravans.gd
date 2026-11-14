extends RefCounted

## T-G4b-03: externe Knoten, physische Karawanen, Ladung/Ankunft/Preisdifferenz.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-03", "Karawanen und externe Knoten")
	var sim: Simulation = G4BTestUtil.shared_year()
	var caravans: CaravanSystem = sim.economy.caravans
	ctx.check_eq(caravans.nodes.size(), 3, "nicht drei externe Knoten")
	var node_stock_changed: bool = false
	for node_v in caravans.nodes:
		var node: ExternalNode = node_v
		ctx.check_eq(node.price_milli.size(), Goods.COUNT, "Knotenpreise unvollständig")
		ctx.check_eq(node.stock.size(), Goods.COUNT, "Knotenbestand unvollständig")
		for good in Goods.COUNT:
			if node.stock[good] != 100000:
				node_stock_changed = true
	ctx.check(node_stock_changed, "externer Knotenbestand unverändert")
	ctx.check(caravans.dispatched_count > 0, "keine Karawane gestartet")
	ctx.check(caravans.completed_count > 0, "keine Karawane abgeschlossen")
	ctx.check(caravans.profit_total != 0, "Karawanenbilanz leer")
	ctx.check_eq(sim.economy.total_caravan_profit, caravans.profit_total,
		"Karawanenbilanz nicht konsistent")
	ctx.check(caravans.active_count() <= CaravanSystem.MAX_ACTIVE,
		"zu viele aktive Karawanen")
	# Frischer Lauf: aktive Karawane mit gültigem Marker und Ladung.
	var sim2: Simulation = G4BTestUtil.new_sim(1339)
	G4BTestUtil.advance_chunked(sim2, sim2.clock.now + 10 * SimConfig.TICKS_PER_DAY, 3600)
	var active: Array = sim2.economy.caravans.caravans
	ctx.check(active.size() > 0, "keine aktive Karawane nach 10 Tagen")
	for caravan_v in active:
		var c: Caravan = caravan_v
		ctx.check(c.cargo_amount > 0, "Karawane ohne Ladung")
		var node: ExternalNode = sim2.economy.caravans.nodes[c.node_id]
		ctx.check(sim2.economy.caravans.route_points(node, sim2).size() >= 2,
			"Karawanenroute fehlt")
	var markers: Array = sim2.economy.caravans.marker_entries(
		sim2.clock.now, sim2)
	ctx.check(markers.size() > 0, "keine Karawanenmarker")
	for marker_v in markers:
		var marker: Dictionary = marker_v
		var position: Vector2 = marker["position"]
		ctx.check(position.x >= 0.0 and position.x <= float(sim2.world.size)
			and position.y >= 0.0 and position.y <= float(sim2.world.size),
			"Karawanenmarker außerhalb der Welt")
		ctx.check(int(marker["cargo_amount"]) > 0, "Marker ohne Ladung")
