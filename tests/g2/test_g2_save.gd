extends RefCounted

## T-G2-05: Save/Load exakt, Schema 5, alte Schemas abgelehnt, Replay.


static func run(ctx: G1aTestContext) -> void:
	_test_roundtrip(ctx)
	_test_schema_rejection(ctx)
	_test_replay(ctx)


static func _test_roundtrip(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-05a", "Save/Load exakt bei 100 Agenten, Schema 5")
	var a: Simulation = G2TestUtil.new_sim()
	var snapshot: int = G2TestUtil.abs_time(12, 17, 0)
	G2TestUtil.advance_chunked(a, snapshot, 300)
	var traveling: int = -1
	for row in a.store.count:
		if a.store.alive[row] != 0 and a.store.route_id[row] >= 0:
			traveling = row
			break
	ctx.check(traveling >= 0, "kein Agent bei Save in Bewegung")
	var path: String = G2TestUtil.temp_path("roundtrip")
	var info: Dictionary = a.save_to(path)
	ctx.check(info.get("ok", false), "Save fehlgeschlagen")
	ctx.check_eq(int(info.get("schema", 0)), 5, "Save-Schema nicht 5")
	ctx.check(int(info.get("bytes", 0)) > 0, "Save leer")
	ctx.check(int(info.get("bytes", 0)) < 16 * 1024 * 1024, "Save unerwartet groß")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Load fehlgeschlagen")
	if not loaded.get("ok", false):
		G2TestUtil.remove_temp(path)
		return
	var b: Simulation = loaded["sim"]
	ctx.check_eq(int(loaded.get("schema", 0)), 5, "Load-Schema nicht 5")
	ctx.check_eq(b.state_hash(), a.state_hash(), "Snapshot-State nicht exakt")
	ctx.check_eq(b.curated_chronicle_hash(), a.curated_chronicle_hash(),
		"Chronik-Snapshot nicht exakt")
	ctx.check_eq(b.store.count, 100, "Load hat nicht 100 Agenten")
	ctx.check_eq(b.world.field_ids().size(), 4, "Load hat nicht 4 Felder")
	ctx.check(b.pathfinder != null, "Load ohne PathFinder")
	if b.pathfinder != null:
		ctx.check(b.pathfinder.cache_size() > 0, "Cache nach Load nicht rekonstruiert")
		ctx.check(b.pathfinder.prewarm_recalculations > 0, "Cache nicht prewarmed")
		ctx.check_eq(b.pathfinder.cache_hits, 0, "Save enthält Cache-Hits")
	print("G2_SAVE schema=5 bytes=%d save_ms=%.2f load_ms=%.2f" % [
		int(info.get("bytes", 0)), float(info.get("save_ms", 0.0)),
		float(loaded.get("load_ms", 0.0))])
	var target: int = snapshot + 3 * SimConfig.TICKS_PER_DAY
	G2TestUtil.advance_chunked(a, target, 300)
	G2TestUtil.advance_chunked(b, target, 7)
	ctx.check_eq(b.state_hash(), a.state_hash(), "Verlauf nach Load abweichend")
	ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Load abweichend")
	ctx.check_eq(b.curated_chronicle_hash(), a.curated_chronicle_hash(),
		"Chronik nach Load abweichend")
	G2TestUtil.remove_temp(path)


static func _test_schema_rejection(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-05b", "Schema 1-4 und ungültige Header sichtbar abgelehnt")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(2, 9, 0), 300)
	var path: String = G2TestUtil.temp_path("schema")
	var info: Dictionary = sim.save_to(path)
	ctx.check(info.get("ok", false), "Save fehlgeschlagen")
	ctx.check_eq(SimConfig.SCHEMA_VERSION, 5, "Config-Schema nicht 5")
	ctx.check_eq(SimSave.SCHEMA_VERSION, 5, "Save-Schema nicht 5")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var state_before: int = sim.state_hash()
	for schema in [1, 2, 3, 4, 999]:
		var bytes: PackedByteArray = original.duplicate()
		bytes.encode_u32(4, schema)
		var p: String = G2TestUtil.temp_path("schema_%d" % schema)
		_write_bytes(p, bytes)
		var bad: Dictionary = Simulation.load_from(p)
		ctx.check(not bad.get("ok", false), "Schema %d wurde geladen" % schema)
		ctx.check_eq(str(bad.get("error", "")), "unsupported_schema",
			"Fehlermeldung für Schema %d" % schema)
		G2TestUtil.remove_temp(p)
	var magic_path: String = G2TestUtil.temp_path("magic")
	var magic_bytes: PackedByteArray = original.duplicate()
	magic_bytes.encode_u32(0, 0xDEADBEEF)
	_write_bytes(magic_path, magic_bytes)
	var bad_magic: Dictionary = Simulation.load_from(magic_path)
	ctx.check_eq(str(bad_magic.get("error", "")), "bad_magic", "Magic-Fehler")
	var hash_path: String = G2TestUtil.temp_path("hash")
	var hash_bytes: PackedByteArray = original.duplicate()
	hash_bytes.encode_u64(12, hash_bytes.decode_u64(12) ^ 0xFFFF)
	_write_bytes(hash_path, hash_bytes)
	var bad_hash: Dictionary = Simulation.load_from(hash_path)
	ctx.check_eq(str(bad_hash.get("error", "")), "config_hash_mismatch",
		"Config-Hash-Fehler")
	ctx.check_eq(sim.state_hash(), state_before, "fehlgeschlagenes Laden mutiert Sim")
	for p in [path, magic_path, hash_path]:
		G2TestUtil.remove_temp(p)


static func _test_replay(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-05c", "Replay = Re-Simulation aus Seed+Config+Snapshot")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(5, 12, 0), 300)
	var path: String = G2TestUtil.temp_path("replay")
	ctx.check(sim.save_to(path).get("ok", false), "Replay-Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Replay-Load fehlgeschlagen")
	if not loaded.get("ok", false):
		G2TestUtil.remove_temp(path)
		return
	var control: Simulation = loaded["sim"]
	var target: int = control.clock.now + 2 * SimConfig.TICKS_PER_DAY
	var triplet: Dictionary = Replay.verify_triplet(path, target)
	ctx.check(triplet.get("ok", false), "3 Replay-Läufe nicht identisch")
	ctx.check(bool(triplet.get("state_equal", false)), "Replay-State abweichend")
	ctx.check(bool(triplet.get("events_equal", false)), "Replay-Events abweichend")
	ctx.check(bool(triplet.get("curated_equal", false)), "Replay-Chronik abweichend")
	var log_independent: Dictionary = Replay.verify_log_independence(path, target, 600)
	ctx.check(log_independent.get("ok", false), "Log-Kürzung ändert Verlauf")
	ctx.check(int(log_independent.get("new_events", 0)) > 0,
		"keine neuen Events im Replay-Fenster")
	G2TestUtil.remove_temp(path)


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
