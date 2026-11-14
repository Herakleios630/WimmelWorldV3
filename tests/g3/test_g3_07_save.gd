extends RefCounted

## T-G3-07: Save/Load exakt, Schema 6, alte Schemas sichtbar abgelehnt.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-07", "Save/Load exakt bei 1k, Schema 6, alte Schemas abgelehnt")
	var path: String = G3ATestUtil.snapshot_path()
	ctx.check(path != "" and FileAccess.file_exists(path), "Snapshot fehlt")
	if path == "" or not FileAccess.file_exists(path):
		return
	var t0: int = Time.get_ticks_msec()
	var load_a: Dictionary = Simulation.load_from(path)
	var load_ms: int = Time.get_ticks_msec() - t0
	ctx.check(load_a.get("ok", false), "Load fehlgeschlagen")
	if not load_a.get("ok", false):
		return
	ctx.check_eq(int(load_a.get("schema", 0)), 6, "Schema nicht 6")
	print("G3_SAVE schema=6 bytes=%d load_ms=%d" % [
		FileAccess.get_file_as_bytes(path).size(), load_ms])
	var a: Simulation = load_a["sim"]
	ctx.check(a.store.count >= 1000, "Agentenzahl nach Load")
	ctx.check(a.count_alive() <= a.store.count, "lebende Agenten > Records")
	ctx.check_eq(a.world.field_ids().size(), 40, "Feldanzahl nach Load")
	ctx.check_eq(a.config.year_days, 120, "Kalender nach Load")
	ctx.check(a.pathfinder != null and a.pathfinder.cache_size() > 0,
		"Pfad-Cache nach Load nicht aufgebaut")
	var state_snapshot: int = a.state_hash()
	var chronicle_snapshot: int = a.curated_chronicle_hash()
	# Snapshot liegt in der Feldphase und möglichst mit Bewegung.
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
	# Zweiter Load: identischer Zustand, kein Cache im Save.
	var load_b: Dictionary = Simulation.load_from(path)
	ctx.check(load_b.get("ok", false), "zweiter Load fehlgeschlagen")
	var b: Simulation = null
	if load_b.get("ok", false):
		b = load_b["sim"]
		ctx.check_eq(b.state_hash(), state_snapshot, "Load nicht deterministisch")
		ctx.check_eq(b.curated_chronicle_hash(), chronicle_snapshot,
			"Chronik nach Load nicht exakt")
	var expected: Dictionary = G3ATestUtil.snapshot_expected()
	ctx.check(not expected.is_empty(), "Checkpoint-Hashes fehlen")
	var target: int = int(expected.get("time", 0))
	G3ATestUtil.advance_chunked(a, target, 3600)
	if b != null:
		G3ATestUtil.advance_chunked(b, target, 80)
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
	# Schema 1-5 und ungültige Header sichtbar ablehnen.
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var rejected: int = 0
	for schema in [1, 2, 3, 4, 5]:
		var bad: PackedByteArray = bytes.duplicate()
		bad[4] = schema & 0xFF
		bad[5] = (schema >> 8) & 0xFF
		bad[6] = (schema >> 16) & 0xFF
		bad[7] = (schema >> 24) & 0xFF
		var bad_path: String = G3ATestUtil.temp_path("schema%d" % schema)
		var f: FileAccess = FileAccess.open(bad_path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(bad)
			f.close()
		var result: Dictionary = Simulation.load_from(bad_path)
		if not result.get("ok", true) \
				and str(result.get("error", "")) == "unsupported_schema":
			rejected += 1
		G3ATestUtil.remove_temp(bad_path)
	ctx.check_eq(rejected, 5, "Schema 1-5 nicht sichtbar abgelehnt")
	var garbage_path: String = G3ATestUtil.temp_path("garbage")
	var gf: FileAccess = FileAccess.open(garbage_path, FileAccess.WRITE)
	if gf != null:
		gf.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
		gf.close()
	var garbage: Dictionary = Simulation.load_from(garbage_path)
	ctx.check(not garbage.get("ok", true), "ungültiger Header akzeptiert")
	G3ATestUtil.remove_temp(garbage_path)
