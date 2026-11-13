extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_soa_store(ctx)
	_test_id_lifecycle(ctx)
	_test_no_per_agent_dicts(ctx)


static func _test_soa_store(ctx: G1aTestContext) -> void:
	ctx.begin("T-STORE-01", "SoA-Store: 10 Agenten, stabile IDs, keine Kopien")
	var sim: Simulation = G1aTestUtil.new_sim()
	var store: AgentStore = sim.store
	ctx.check_eq(store.count, 10, "Agentenzahl")
	ctx.check_eq(store.ids.size(), 10, "ids-Array Länge")
	ctx.check_eq(store.hunger.size(), 10, "hunger-Array Länge")
	ctx.check_eq(store.pos_x.size(), 10, "pos_x-Array Länge")
	var ids_seen: PackedByteArray = PackedByteArray()
	ids_seen.resize(32)
	var ids_ok: bool = true
	for row in store.count:
		var agent_id: int = store.ids[row]
		if agent_id < 1 or agent_id > 31:
			ids_ok = false
			continue
		if ids_seen[agent_id] != 0:
			ids_ok = false
		ids_seen[agent_id] = 1
		ctx.check_eq(store.row_for_id(agent_id), row, "row_for_id für A%d" % agent_id)
	ctx.check(ids_ok, "IDs nicht stabil/eindeutig")
	ctx.check_eq(store.row_for_id(999), -1, "unbekannte ID liefert keine Row")
	# Kalte Records und Haushalte.
	ctx.check_eq(sim.records.size(), 10, "kalte Records")
	ctx.check_eq(sim.households.size(), 3, "Haushalte")
	ctx.check_eq(sim.relationships.size() > 10, true, "Startbeziehungen fehlen")
	var arnd: AgentRecord = AgentRecords.record_by_id(sim.records, 1)
	var alma: AgentRecord = AgentRecords.record_by_id(sim.records, 2)
	var clara: AgentRecord = AgentRecords.record_by_id(sim.records, 3)
	var grete: AgentRecord = AgentRecords.record_by_id(sim.records, 10)
	ctx.check(arnd != null and arnd.name == "Arnd" and arnd.role == AgentStore.ROLE_ADULT,
		"A1-Record falsch")
	ctx.check(alma != null and clara != null and grete != null, "Record-Lookup fehlt")
	# A5 (ID 8) ist Witwer: keine Partner-Beziehung mit A5.
	var a5_partner: bool = false
	for relationship in sim.relationships:
		var rel: RelationshipRecord = relationship
		if rel.type == RelationshipRecord.TYPE_PARTNER and (rel.a_agent_id == 8 or rel.b_agent_id == 8):
			a5_partner = true
	ctx.check(not a5_partner, "A5 hat unerwartet eine Partnerin")
	# A7 ist Kind von A6.
	var a7_child_of_a6: bool = false
	for relationship in sim.relationships:
		var rel2: RelationshipRecord = relationship
		if rel2.type == RelationshipRecord.TYPE_PARENT and rel2.a_agent_id == 9 and rel2.b_agent_id == 10:
			a7_child_of_a6 = true
	ctx.check(a7_child_of_a6, "A6-A7-Elternbeziehung fehlt")
	# Keine Kopie: direkte Store-Mutation ist sofort im Sim-Store sichtbar.
	var before: float = store.hunger[0]
	store.hunger[0] = 12.5
	ctx.check_close(sim.store.hunger[0], 12.5, 0.0001, "Store ist keine gemeinsame Quelle")
	store.hunger[0] = before


static func _test_id_lifecycle(ctx: G1aTestContext) -> void:
	ctx.begin("T-STORE-02", "ID-Lebenszyklus: toter Agent bleibt referenzierbar")
	var sim: Simulation = G1aTestUtil.new_sim()
	var store: AgentStore = sim.store
	var row: int = store.row_for_id(10)
	ctx.check(row >= 0, "A10 nicht gefunden")
	store.set_alive(row, false)
	ctx.check_eq(store.alive[row], 0, "alive-Flag")
	ctx.check_eq(store.row_for_id(10), row, "toter Agent nicht mehr auffindbar")
	var rec: AgentRecord = AgentRecords.record_by_id(sim.records, 10)
	ctx.check(rec != null and rec.name == "Greta", "toter Record nicht referenzierbar")
	var new_id: int = store.spawn_agent(20, AgentStore.ROLE_ADULT, 1, 1, 0,
		AgentStore.JOB_NONE, 47.5, 59.5, 80.0, 80.0, 70.0, sim.clock.now)
	ctx.check(new_id > 10, "Agent-ID wurde wiederverwendet: %d" % new_id)
	ctx.check_eq(store.row_for_id(10), row, "alte ID nach Spawn verändert")
	ctx.check_eq(store.count, 11, "Spawn erhöht Count")
	ctx.check_eq(store.row_for_id(new_id), 10, "neue Row nicht auffindbar")


static func _test_no_per_agent_dicts(ctx: G1aTestContext) -> void:
	ctx.begin("T-STORE-03", "Keine Per-Agent-Dictionaries im Hot-Loop")
	var files: PackedStringArray = PackedStringArray([
		"res://src/agents/agent_store.gd",
		"res://src/kernel/event_scheduler.gd",
		"res://src/decisions/decision_system.gd",
		"res://src/decisions/needs_model.gd",
		"res://src/navigation/route_store.gd",
	])
	for path in files:
		ctx.check(not G1aTestUtil.code_uses_dictionary(path),
			"Dictionary im Hot-Loop-Code: " + path)
	var store: AgentStore = G1aTestUtil.new_sim().store
	ctx.check(store.hunger is PackedFloat64Array, "hunger ist kein PackedFloat64Array")
	ctx.check(store.hygiene is PackedFloat64Array, "hygiene ist kein PackedFloat64Array")
	ctx.check(store.fun is PackedFloat64Array, "fun ist kein PackedFloat64Array")
	ctx.check(store.health is PackedFloat64Array, "health ist kein PackedFloat64Array")
	ctx.check(store.next_event is PackedInt64Array, "next_event ist kein PackedInt64Array")
	ctx.check(store.activity is PackedByteArray, "activity ist kein PackedByteArray")
