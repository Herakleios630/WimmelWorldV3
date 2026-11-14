extends RefCounted

## T-G4b-08: Save/Load Schema 8 exakt, Budgets, alte Schemas abgelehnt,
## G4a-Schema 7 bleibt im G4a-Profil ladbar.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-08", "Save/Load Schema 8, Budgets, Ablehnung 1-7")
	var path: String = G4BTestUtil.snapshot_path()
	ctx.check(path != "" and FileAccess.file_exists(path), "Snapshot fehlt")
	if path == "" or not FileAccess.file_exists(path):
		return
	var info: Dictionary = G4BTestUtil.snapshot_info()
	var bytes: int = int(info.get("bytes", 0))
	var save_ms: float = float(info.get("save_ms", 99999.0))
	ctx.check_eq(int(info.get("schema", 0)), 8, "Snapshot nicht Schema 8")
	ctx.check(bytes > 0 and bytes <= 40 * 1024 * 1024,
		"Save-Größe über 40 MB: %d" % bytes)
	ctx.check(save_ms <= 3000.0, "Save über 3 s: %.1f ms" % save_ms)
	var t0: int = Time.get_ticks_msec()
	var load_a: Dictionary = Simulation.load_from(path)
	var load_ms: int = Time.get_ticks_msec() - t0
	ctx.check(load_a.get("ok", false), "Load fehlgeschlagen")
	if not load_a.get("ok", false):
		return
	ctx.check(load_ms <= 12000, "Load über 12 s: %d ms" % load_ms)
	ctx.check_eq(int(load_a.get("schema", 0)), 8, "Load-Schema nicht 8")
	print("G4B_SAVE schema=8 bytes=%d save_ms=%.1f load_ms=%d" % [
		bytes, save_ms, load_ms])
	var a: Simulation = load_a["sim"]
	ctx.check(a.economy != null, "Economy nach Load fehlt")
	ctx.check(a.politics != null, "Politics nach Load fehlt")
	ctx.check_eq(a.economy.household_count, 2000, "Haushalte nach Load")
	ctx.check(a.economy.caravans.dispatched_count > 0,
		"Karawanen nach Load leer")
	var state_snapshot: int = a.state_hash()
	var event_snapshot: int = a.event_hash()
	var chronicle_snapshot: int = a.curated_chronicle_hash()
	var econ_snapshot: int = a.economy.state_hash()
	var pol_snapshot: int = a.politics.state_hash()
	var load_b: Dictionary = Simulation.load_from(path)
	ctx.check(load_b.get("ok", false), "zweiter Load fehlgeschlagen")
	var b: Simulation = null
	if load_b.get("ok", false):
		b = load_b["sim"]
		ctx.check_eq(b.state_hash(), state_snapshot, "Load nicht deterministisch")
		ctx.check_eq(b.event_hash(), event_snapshot, "Event nach Load nicht exakt")
		ctx.check_eq(b.curated_chronicle_hash(), chronicle_snapshot,
			"Chronik nach Load nicht exakt")
		ctx.check_eq(b.economy.state_hash(), econ_snapshot,
			"Wirtschaft nach Load nicht exakt")
		ctx.check_eq(b.politics.state_hash(), pol_snapshot,
			"Politik nach Load nicht exakt")
	var expected: Dictionary = G4BTestUtil.snapshot_expected()
	ctx.check(not expected.is_empty(), "Checkpoint-Hashes fehlen")
	var target: int = int(expected.get("time", 0))
	G4BTestUtil.advance_chunked(a, target, 3600)
	if b != null:
		G4BTestUtil.advance_chunked(b, target, 240)
	ctx.check_eq(a.state_hash(), int(expected.get("state", 0)),
		"Fortsetzung nach Load nicht exakt (State)")
	ctx.check_eq(a.event_hash(), int(expected.get("event", 0)),
		"Fortsetzung nach Load nicht exakt (Event)")
	ctx.check_eq(a.curated_chronicle_hash(), int(expected.get("chronicle", 0)),
		"Fortsetzung nach Load nicht exakt (Chronik)")
	if b != null:
		ctx.check_eq(b.state_hash(), a.state_hash(),
			"Fortsetzung chunkabhängig (State)")
		ctx.check_eq(b.event_hash(), a.event_hash(),
			"Fortsetzung chunkabhängig (Event)")
	# Schema 1-7 im G4b-Profil sichtbar ablehnen.
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var rejected: int = 0
	for schema in [1, 2, 3, 4, 5, 6, 7]:
		var bad: PackedByteArray = raw.duplicate()
		bad[4] = schema & 0xFF
		bad[5] = (schema >> 8) & 0xFF
		bad[6] = (schema >> 16) & 0xFF
		bad[7] = (schema >> 24) & 0xFF
		var bad_path: String = G4BTestUtil.temp_path("schema%d" % schema)
		var f: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bad)
			f.close()
		var result: Dictionary = Simulation.load_from(bad_path)
		if not result.get("ok", true) \
				and str(result.get("error", "")) == "unsupported_schema":
			rejected += 1
		G4BTestUtil.remove_temp(bad_path)
	ctx.check_eq(rejected, 7, "Schema 1-7 nicht sichtbar abgelehnt")
	# G4a-Profil bleibt bei Schema 7 und ist weiterhin ladbar.
	var g4a: Simulation = Simulation.create(SimConfig.scale(1337))
	G4BTestUtil.advance_chunked(g4a, g4a.clock.now + 3600, 3600)
	var g4a_path: String = G4BTestUtil.temp_path("g4a_schema7")
	var g4a_info: Dictionary = g4a.save_to(g4a_path)
	ctx.check_eq(int(g4a_info.get("schema", 0)), 7, "G4a-Save nicht Schema 7")
	var g4a_load: Dictionary = Simulation.load_from(g4a_path)
	ctx.check(g4a_load.get("ok", false), "G4a-Schema-7-Load fehlgeschlagen")
	if g4a_load.get("ok", false):
		ctx.check_eq((g4a_load["sim"] as Simulation).config.save_schema_version(),
			7, "G4a-Load-Profil nicht Schema 7")
	G4BTestUtil.remove_temp(g4a_path)
