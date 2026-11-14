extends RefCounted

## G1b-Schritt 3: T-REPLAY-01..03.
## Replay ist Re-Simulation aus Seed + Konfiguration + Save-Snapshot.

const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")


static func run(ctx: G1aTestContext) -> void:
	_test_resimulation(ctx)
	_test_log_independence(ctx)
	_test_triplet(ctx)


static func _save_probe() -> String:
	var config: SimConfig = SimConfig.new()
	config.seed = FeaturedSeed.FEATURED_SEED
	var sim: Simulation = Simulation.create(config)
	sim.advance_to(sim.clock.now + 3 * SimConfig.TICKS_PER_DAY)
	var path: String = G1aTestUtil.temp_path("g1b_replay")
	ctx_save(sim, path)
	return path


static func ctx_save(sim: Simulation, path: String) -> Dictionary:
	return sim.save_to(path)


static func _test_resimulation(ctx: G1aTestContext) -> void:
	ctx.begin("T-REPLAY-01", "Re-Simulation: Seed+Config+Snapshot -> gleicher Verlauf")
	var path: String = _save_probe()
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Replay-Load fehlgeschlagen")
	if not loaded.get("ok", false):
		G1aTestUtil.remove_temp(path)
		return
	var control: Simulation = loaded["sim"]
	var target: int = control.clock.now + 3 * SimConfig.TICKS_PER_DAY
	control.advance_to(target)
	var replay: Dictionary = Replay.run_from_snapshot(path, target, 600)
	ctx.check(replay.get("ok", false), "Re-Simulation fehlgeschlagen")
	if replay.get("ok", false):
		var replay_sim: Simulation = replay["sim"]
		ctx.check_eq(replay_sim.state_hash(), control.state_hash(),
			"Re-Simulation ergibt anderen State")
		ctx.check_eq(replay_sim.event_hash(), control.event_hash(),
			"Re-Simulation ergibt andere Events")
		ctx.check_eq(replay_sim.curated_chronicle_hash(),
			control.curated_chronicle_hash(),
			"Re-Simulation ergibt andere Chronik")
		var meta: Dictionary = replay["meta"]
		ctx.check_eq(int(meta.get("seed", 0)), FeaturedSeed.FEATURED_SEED,
			"Replay-Metadaten ohne Seed")
		ctx.check(meta.has("config_hash"), "Replay-Metadaten ohne Config-Hash")
		ctx.check(meta.has("snapshot_time"), "Replay-Metadaten ohne Snapshot-Zeit")
	G1aTestUtil.remove_temp(path)


static func _test_log_independence(ctx: G1aTestContext) -> void:
	ctx.begin("T-REPLAY-02", "Log-Unabhängigkeit: gekürztes Chronik-Log ändert Replay nicht")
	var path: String = _save_probe()
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Replay-Load fehlgeschlagen")
	if not loaded.get("ok", false):
		G1aTestUtil.remove_temp(path)
		return
	var target: int = loaded["sim"].clock.now + 3 * SimConfig.TICKS_PER_DAY
	var result: Dictionary = Replay.verify_log_independence(path, target, 600)
	ctx.check(result.get("ok", false), "Log-Unabhängigkeit verletzt")
	ctx.check(bool(result.get("state_equal", false)),
		"State nach Log-Kürzung abweichend")
	ctx.check(bool(result.get("events_equal", false)),
		"Neue Events nach Log-Kürzung abweichend")
	ctx.check(int(result.get("new_events", 0)) > 0,
		"keine neuen Events im Replay-Fenster")
	G1aTestUtil.remove_temp(path)


static func _test_triplet(ctx: G1aTestContext) -> void:
	ctx.begin("T-REPLAY-03", "3 Replay-Läufe: identische Hashes/Events")
	var path: String = _save_probe()
	var loaded: Dictionary = Simulation.load_from(path)
	ctx.check(loaded.get("ok", false), "Replay-Load fehlgeschlagen")
	if not loaded.get("ok", false):
		G1aTestUtil.remove_temp(path)
		return
	var target: int = loaded["sim"].clock.now + 2 * SimConfig.TICKS_PER_DAY
	var result: Dictionary = Replay.verify_triplet(path, target)
	ctx.check(result.get("ok", false), "3 Replay-Läufe nicht identisch")
	ctx.check(bool(result.get("state_equal", false)), "State-Hashes abweichend")
	ctx.check(bool(result.get("events_equal", false)), "Event-Hashes abweichend")
	ctx.check(bool(result.get("curated_equal", false)), "Chronik-Hashes abweichend")
	print("G1B_REPLAY states=%s events=%s chronicle=%s" % [
		str(result.get("state_hashes", [])), str(result.get("event_hashes", [])),
		str(result.get("curated_hashes", []))])
	G1aTestUtil.remove_temp(path)
