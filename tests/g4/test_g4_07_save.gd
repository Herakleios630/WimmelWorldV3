extends RefCounted

## T-G4a-07: Save/Load exakt, Schema 7, Budgets, alte Schemas abgelehnt.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-07", "Save/Load exakt bei 10k, Schema 7, Budgets")
	var path: String = G4ATestUtil.snapshot_path()
	ctx.check(path != "" and FileAccess.file_exists(path), "Snapshot fehlt")
	if path == "" or not FileAccess.file_exists(path):
		return
	var info: Dictionary = G4ATestUtil.snapshot_info()
	var bytes: int = int(info.get("bytes", 0))
	var save_ms: float = float(info.get("save_ms", 9999.0))
	ctx.check_eq(int(info.get("schema", 0)), 7, "Snapshot nicht Schema 7")
	ctx.check(bytes > 0 and bytes <= 30 * 1024 * 1024,
		"Save-Größe über 30 MB: %d" % bytes)
	ctx.check(save_ms <= 2000.0, "Save über 2 s: %.1f ms" % save_ms)
	var t0: int = Time.get_ticks_msec()
	var load_a: Dictionary = Simulation.load_from(path)
	var load_ms: int = Time.get_ticks_msec() - t0
	ctx.check(load_a.get("ok", false), "Load fehlgeschlagen")
	if not load_a.get("ok", false):
		return
	ctx.check(load_ms <= 10000, "Load über 10 s: %d ms" % load_ms)
	ctx.check_eq(int(load_a.get("schema", 0)), 7, "Load-Schema nicht 7")
	print("G4A_SAVE schema=7 bytes=%d save_ms=%.1f load_ms=%d" % [
		bytes, save_ms, load_ms])
	var a: Simulation = load_a["sim"]
	ctx.check(a.store.count >= 10000, "Agentenzahl nach Load zu klein")
	ctx.check_eq(a.records.size(), a.store.count, "Records/Store nach Load")
	ctx.check_eq(a.households.size(), 2000, "Haushalte nach Load")
	ctx.check_eq(a.world.field_ids().size(), 200, "Felder nach Load")
	ctx.check_eq(a.config.year_days, 120, "Kalender nach Load")
	ctx.check_eq(a.config.save_schema_version(), 7, "Schema-Konstante")
	ctx.check(a.pathfinder != null and a.pathfinder.cache_size() > 0,
		"Pfad-Cache nach Load nicht aufgebaut")
	ctx.check(a.births > 0, "Snapshot ohne Geburten")
	ctx.check(a.deaths > 0, "Snapshot ohne Todesfälle")
	var non_fallow: int = 0
	for field_id in a.world.field_ids():
		var f: Building = a.world.building_by_id(field_id)
		if f != null and f.field_stage != Building.FIELD_FALLOW:
			non_fallow += 1
	var traveling: int = 0
	for row in a.store.count:
		if a.store.activity[row] == AgentStore.ACT_TRAVEL:
			traveling += 1
	ctx.check(non_fallow > 0, "Snapshot nicht in der Feldphase")
	ctx.check(traveling > 0, "Snapshot ohne Bewegung")
	var state_snapshot: int = a.state_hash()
	var chronicle_snapshot: int = a.curated_chronicle_hash()
	var load_b: Dictionary = Simulation.load_from(path)
	ctx.check(load_b.get("ok", false), "zweiter Load fehlgeschlagen")
	var b: Simulation = null
	if load_b.get("ok", false):
		b = load_b["sim"]
		ctx.check_eq(b.state_hash(), state_snapshot, "Load nicht deterministisch")
		ctx.check_eq(b.curated_chronicle_hash(), chronicle_snapshot,
			"Chronik nach Load nicht exakt")
	var expected: Dictionary = G4ATestUtil.snapshot_expected()
	ctx.check(not expected.is_empty(), "Checkpoint-Hashes fehlen")
	var target: int = int(expected.get("time", 0))
	G4ATestUtil.advance_chunked(a, target, 3600)
	if b != null:
		G4ATestUtil.advance_chunked(b, target, 240)
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
	# Schema 1-6 sichtbar ablehnen.
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var rejected: int = 0
	for schema in [1, 2, 3, 4, 5, 6]:
		var bad: PackedByteArray = raw.duplicate()
		bad[4] = schema & 0xFF
		bad[5] = (schema >> 8) & 0xFF
		bad[6] = (schema >> 16) & 0xFF
		bad[7] = (schema >> 24) & 0xFF
		var bad_path: String = G4ATestUtil.temp_path("schema%d" % schema)
		var f: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bad)
			f.close()
		var result: Dictionary = Simulation.load_from(bad_path)
		if not result.get("ok", true) \
				and str(result.get("error", "")) == "unsupported_schema":
			rejected += 1
		G4ATestUtil.remove_temp(bad_path)
	ctx.check_eq(rejected, 6, "Schema 1-6 nicht sichtbar abgelehnt")
	var garbage_path: String = G4ATestUtil.temp_path("garbage")
	var gf: FileAccess = FileAccess.open(garbage_path, FileAccess.WRITE)
	if gf != null:
		gf.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
		gf.close()
	var garbage: Dictionary = Simulation.load_from(garbage_path)
	ctx.check(not garbage.get("ok", true), "ungültiger Header akzeptiert")
	G4ATestUtil.remove_temp(garbage_path)
