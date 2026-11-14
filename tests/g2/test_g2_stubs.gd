extends RefCounted

## T-G2-08: D-57 nur Stubs, keine G3-Features, Dateigrenzen.


static func run(ctx: G1aTestContext) -> void:
	_test_stubs(ctx)
	_test_no_events(ctx)
	_test_no_g3(ctx)


static func _test_stubs(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-08a", "D-57: sieben Platzhalter ohne Simulationseffekt")
	var labels: PackedStringArray = D57Stubs.labels()
	ctx.check_eq(labels.size(), 7, "nicht sieben D-57-Systeme")
	for name in ["Wetter", "Feste", "Religion", "Kultur", "Krankheit", "Recht", "Bildung"]:
		ctx.check(labels.has(name), "D-57-System fehlt: " + name)
	var info: Array = D57Stubs.info()
	ctx.check_eq(info.size(), 7, "D-57-Info unvollständig")
	var inert: bool = true
	for entry in info:
		if bool(entry["simulation_effect"]) or bool(entry["events"]) or bool(entry["state"]):
			inert = false
	ctx.check(inert, "D-57-Stub hat Simulationseffekt")
	for path in ["res://src/agents/simulation.gd",
			"res://src/decisions/decision_system.gd",
			"res://src/agents/lifecycle_system.gd"]:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		ctx.check(not text.contains("d57stubs"), "D-57-Stub wird von Sim konsumiert: " + path)


static func _test_no_events(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-08b", "Keine D-57-Events/Zustände/Verbraucher/Produktion")
	var sim: Simulation = G2TestUtil.new_sim()
	G2TestUtil.advance_chunked(sim, G2TestUtil.abs_time(0, 23, 0), 80)
	var forbidden: Array = ["weather", "wetter", "festival", "fest", "religion",
		"culture", "kultur", "disease", "krankheit", "law", "recht",
		"education", "bildung"]
	var found: bool = false
	for event in sim.logs.debug_events:
		var key: String = (event as SimEvent).template_key.to_lower()
		for term in forbidden:
			if key.contains(term):
				found = true
	ctx.check(not found, "D-57-Event im Debug-Log")
	var source: String = FileAccess.get_file_as_string("res://src/kernel/sim_event.gd").to_lower()
	for term in forbidden:
		ctx.check(not source.contains(term), "D-57-Eventtyp im Kernel: " + term)


static func _test_no_g3(ctx: G1aTestContext) -> void:
	ctx.begin("T-G2-08c", "Keine G3/G4/G5-Features, Dateigrenze")
	var config: SimConfig = SimConfig.g2(1337)
	ctx.check_eq(config.target_agents, 100, "G2-Ziel ist nicht 100 Agenten")
	ctx.check_eq(config.world_size, 384, "Weltgröße ist nicht 384")
	for path in ["res://src/economy", "res://src/politics", "res://src/trade",
			"res://src/caravan"]:
		ctx.check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)),
			"G3/G4/G5-Modul vorhanden: " + path)
	var g3_terms: Array = ["bookmark", "timeline", "caravan", "karawane",
		"nation_id", "market_id", "tax_rate"]
	var src_files: Array = _recursive_gd("res://src")
	var clean: bool = true
	for path in src_files:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		for term in g3_terms:
			if text.contains(term):
				clean = false
		var lines: int = text.split("\n").size()
		if lines > 1000:
			clean = false
	ctx.check(clean, "G3-Begriff oder Datei > 1000 Zeilen in src")
	var tests_files: Array = _recursive_gd("res://tests/g2")
	ctx.check(tests_files.size() >= 8, "G2-Testsuite unvollständig")
	for path in tests_files:
		ctx.check(FileAccess.get_file_as_string(path).split("\n").size() <= 1000,
			"G2-Testdatei > 1000 Zeilen: " + path)
	ctx.check(FileAccess.file_exists("res://docs/g2/v3-g2-report.md"),
		"G2-Report fehlt")
	ctx.check(FileAccess.file_exists("res://docs/g2/README.md"), "G2-README fehlt")


static func _recursive_gd(root: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(root + "/" + file)
	for sub in dir.get_directories():
		out.append_array(_recursive_gd(root + "/" + sub))
	return out
