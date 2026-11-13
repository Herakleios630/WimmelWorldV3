extends RefCounted


static func run(ctx: G1aTestContext) -> void:
	_test_save_before_decision(ctx)
	_test_save_after_work(ctx)
	_test_save_version(ctx)


static func _test_save_before_decision(ctx: G1aTestContext) -> void:
	ctx.begin("T-SAVE-01", "Save/Load vor Entscheidung: exakter Verlauf")
	var a: Simulation = G1aTestUtil.new_sim()
	a.advance_to(G1aTestUtil.abs_time(0, 7, 59, 30))
	var path: String = G1aTestUtil.temp_path("before_decision")
	ctx.check(a.save_to(path).get("ok", false), "Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Load fehlgeschlagen")
	if loaded.get("ok", false):
		var b: Simulation = loaded["sim"]
		ctx.check_eq(b.state_hash(), a.state_hash(), "Snapshot nach Load nicht exakt")
		_advance_chunked(a, G1aTestUtil.abs_time(0, 10, 0), 60)
		b.advance_to(G1aTestUtil.abs_time(0, 10, 0))
		ctx.check_eq(b.state_hash(), a.state_hash(), "Verlauf nach Entscheidung abweichend")
		ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Entscheidung abweichend")
		ctx.check_eq(b.grain, a.grain, "Grain nach Entscheidung abweichend")
	G1aTestUtil.remove_temp(path)


static func _test_save_after_work(ctx: G1aTestContext) -> void:
	ctx.begin("T-SAVE-02", "Save/Load nach Arbeit: exakter Verlauf")
	var a: Simulation = G1aTestUtil.new_sim()
	a.advance_to(G1aTestUtil.abs_time(0, 12, 5))
	var path: String = G1aTestUtil.temp_path("after_work")
	ctx.check(a.save_to(path).get("ok", false), "Save fehlgeschlagen")
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Load fehlgeschlagen")
	if loaded.get("ok", false):
		var b: Simulation = loaded["sim"]
		ctx.check_eq(b.state_hash(), a.state_hash(), "Snapshot nach Arbeit nicht exakt")
		ctx.check_eq(b.grain, a.grain, "Grain nach Arbeit nicht exakt")
		_advance_chunked(a, G1aTestUtil.abs_time(0, 18, 0), 300)
		_advance_chunked(b, G1aTestUtil.abs_time(0, 18, 0), 7)
		ctx.check_eq(b.state_hash(), a.state_hash(), "Verlauf nach Arbeit abweichend")
		ctx.check_eq(b.event_hash(), a.event_hash(), "Events nach Arbeit abweichend")
		ctx.check_eq(b.grain_produced, a.grain_produced, "Produktion abweichend")
	G1aTestUtil.remove_temp(path)


static func _test_save_version(ctx: G1aTestContext) -> void:
	ctx.begin("T-SAVE-03", "Inkompatible Save-Version sichtbar abgelehnt")
	var sim: Simulation = G1aTestUtil.new_sim()
	sim.advance_to(G1aTestUtil.abs_time(0, 9, 0))
	var path: String = G1aTestUtil.temp_path("version")
	ctx.check(sim.save_to(path).get("ok", false), "Save fehlgeschlagen")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var state_before: int = sim.state_hash()
	var schema_path: String = G1aTestUtil.temp_path("version_schema")
	var schema_bytes: PackedByteArray = original.duplicate()
	schema_bytes.encode_u32(4, 999)
	_write_bytes(schema_path, schema_bytes)
	var bad: Dictionary = Simulation.load_from(schema_path)
	ctx.check(not bad.get("ok", false), "falsche Schema-Version wurde geladen")
	ctx.check_eq(str(bad.get("error", "")), "unsupported_schema", "Fehlermeldung Schema")
	var magic_path: String = G1aTestUtil.temp_path("version_magic")
	var magic_bytes: PackedByteArray = original.duplicate()
	magic_bytes.encode_u32(0, 0xDEADBEEF)
	_write_bytes(magic_path, magic_bytes)
	var bad_magic: Dictionary = Simulation.load_from(magic_path)
	ctx.check(not bad_magic.get("ok", false), "falsche Magic wurde geladen")
	ctx.check_eq(str(bad_magic.get("error", "")), "bad_magic", "Fehlermeldung Magic")
	var hash_path: String = G1aTestUtil.temp_path("version_hash")
	var hash_bytes: PackedByteArray = original.duplicate()
	hash_bytes.encode_u64(12, hash_bytes.decode_u64(12) ^ 0xFFFF)
	_write_bytes(hash_path, hash_bytes)
	var bad_hash: Dictionary = Simulation.load_from(hash_path)
	ctx.check(not bad_hash.get("ok", false), "Config-Hash-Mismatch wurde geladen")
	ctx.check_eq(str(bad_hash.get("error", "")), "config_hash_mismatch",
		"Fehlermeldung Config-Hash")
	ctx.check_eq(sim.state_hash(), state_before, "fehlgeschlagenes Laden mutiert Sim")
	for p in [path, schema_path, magic_path, hash_path]:
		G1aTestUtil.remove_temp(p)


static func _advance_chunked(sim: Simulation, target: int, chunk: int) -> void:
	while sim.clock.now < target:
		sim.advance_to(mini(target, sim.clock.now + chunk))


static func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
