extends RefCounted

## T-G3-B-05: B save/load exact, mid-selection tier state, schema rejection.


static func run(ctx: G1aTestContext) -> void:
	_test_roundtrip(ctx)
	_test_mid_selection(ctx)
	_test_schema_rejection(ctx)


static func _test_roundtrip(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-05a", "Save/Load exakt innerhalb B, Schema 1")
	var a: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(a, G3TestUtil.abs_time(3, 0, 0), 300)
	var path: String = G3TestUtil.temp_path("roundtrip")
	var info: Dictionary = a.save_to(path)
	ctx.check(info.get("ok", false), "Save fehlgeschlagen")
	ctx.check_eq(int(info.get("schema", 0)), 1, "Save-Schema nicht 1")
	ctx.check(int(info.get("bytes", 0)) > 0, "Save leer")
	ctx.check(int(info.get("bytes", 0)) < 32 * 1024 * 1024, "Save unerwartet groß")
	var loaded: Dictionary = BSim.load_from(path)
	ctx.check(loaded.get("ok", false), "Load fehlgeschlagen: " + str(loaded.get("error", "")))
	if not loaded.get("ok", false):
		G3TestUtil.remove_temp(path)
		return
	var b: BSim = loaded["sim"]
	ctx.check_eq(b.clock.now, a.clock.now, "Clock nach Load abweichend")
	ctx.check_eq(b.state_hash(), a.state_hash(), "State nach Load nicht exakt")
	ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Load nicht exakt")
	ctx.check_eq(b.tier_hash(), a.tier_hash(), "Tier nach Load nicht exakt")
	ctx.check_eq(b.detail_count(), a.detail_count(), "Detailgröße nach Load abweichend")
	ctx.check_eq(b.records.state_hash(), a.records.state_hash(), "Records nach Load abweichend")
	ctx.check_eq(b.key_log.state_hash(), a.key_log.state_hash(), "Key-Log nach Load abweichend")
	ctx.check_eq(b.scheduler.state_hash(), a.scheduler.state_hash(), "Scheduler nach Load abweichend")
	ctx.check_eq(b.background.batch_count, a.background.batch_count, "Background-Zähler abweichend")
	ctx.check_eq(b.detail.routine_events, a.detail.routine_events, "Detail-Zähler abweichend")
	print("G3_B_SAVE bytes=%d save_ms=%.2f load_ms=%.2f detail=%d keys=%s" % [
		int(info.get("bytes", 0)), float(info.get("save_ms", 0.0)),
		float(loaded.get("load_ms", 0.0)), b.detail_count(), str(b.key_stats())])
	var target: int = a.clock.now + 2 * BConfig.TICKS_PER_DAY
	G3TestUtil.advance_chunked(a, target, 300)
	G3TestUtil.advance_chunked(b, target, 7)
	ctx.check_eq(b.state_hash(), a.state_hash(), "Verlauf nach Load abweichend")
	ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Load abweichend")
	ctx.check_eq(b.tier_hash(), a.tier_hash(), "Tier nach Load abweichend")
	G3TestUtil.remove_temp(path)


static func _test_mid_selection(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-05b", "Save/Load mitten in der Tier-Auswahl")
	var a: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(a, G3TestUtil.abs_time(2, 6, 0), 300)
	ctx.check(a.tier_selector.active, "Tier-Auswahl bei Save nicht aktiv")
	var path: String = G3TestUtil.temp_path("midselect")
	ctx.check(a.save_to(path).get("ok", false), "Save mitten in Auswahl fehlgeschlagen")
	var loaded: Dictionary = BSim.load_from(path)
	ctx.check(loaded.get("ok", false), "Load mitten in Auswahl fehlgeschlagen")
	if not loaded.get("ok", false):
		G3TestUtil.remove_temp(path)
		return
	var b: BSim = loaded["sim"]
	ctx.check_eq(b.tier_selector.active_epoch, a.tier_selector.active_epoch,
		"aktive Auswahl-Epoche abweichend")
	ctx.check_eq(b.tier_selector.cursor, a.tier_selector.cursor, "Auswahl-Cursor abweichend")
	ctx.check_eq(b.tier_selector.heap_size, a.tier_selector.heap_size,
		"Auswahl-Heapgröße abweichend")
	ctx.check_eq(b.state_hash(), a.state_hash(), "Mid-Selection-State abweichend")
	var target: int = a.clock.now + BConfig.TICKS_PER_DAY
	G3TestUtil.advance_chunked(a, target, 60)
	G3TestUtil.advance_chunked(b, target, 3600)
	ctx.check_eq(b.state_hash(), a.state_hash(), "Tier-Wechsel nach Mid-Selection-Load abweichend")
	ctx.check_eq(b.tier_hash(), a.tier_hash(), "Tier-Set nach Mid-Selection-Load abweichend")
	print("G3_B_SAVE_MID epoch=%d cursor=%d heap=%d state=%s" % [
		a.tier_selector.active_epoch, a.tier_selector.cursor,
		a.tier_selector.heap_size, HashUtil.hex(a.state_hash())])
	G3TestUtil.remove_temp(path)


static func _test_schema_rejection(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-05c", "Schema/Magic/Config-Hash sichtbar abgelehnt")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(sim, G3TestUtil.abs_time(1, 0, 0), 300)
	var path: String = G3TestUtil.temp_path("schema")
	ctx.check(sim.save_to(path).get("ok", false), "Save fehlgeschlagen")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var state_before: int = sim.state_hash()
	var bad_schema: PackedByteArray = original.duplicate()
	bad_schema.encode_u32(4, 999)
	var p1: String = G3TestUtil.temp_path("schema_999")
	G3TestUtil.write_bytes(p1, bad_schema)
	var bad1: Dictionary = BSim.load_from(p1)
	ctx.check(not bad1.get("ok", false), "Schema 999 wurde geladen")
	ctx.check_eq(str(bad1.get("error", "")), "unsupported_schema", "Schema-Fehler falsch")
	var bad_magic: PackedByteArray = original.duplicate()
	bad_magic.encode_u32(0, 0xDEADBEEF)
	var p2: String = G3TestUtil.temp_path("magic")
	G3TestUtil.write_bytes(p2, bad_magic)
	var bad2: Dictionary = BSim.load_from(p2)
	ctx.check_eq(str(bad2.get("error", "")), "bad_magic", "Magic-Fehler falsch")
	var bad_hash: PackedByteArray = original.duplicate()
	bad_hash.encode_u64(8, bad_hash.decode_u64(8) ^ 0xFFFF)
	var p3: String = G3TestUtil.temp_path("hash")
	G3TestUtil.write_bytes(p3, bad_hash)
	var bad3: Dictionary = BSim.load_from(p3)
	ctx.check_eq(str(bad3.get("error", "")), "config_hash_mismatch", "Config-Hash-Fehler falsch")
	ctx.check_eq(sim.state_hash(), state_before, "fehlgeschlagenes Laden mutiert Sim")
	for p in [path, p1, p2, p3]:
		G3TestUtil.remove_temp(p)
