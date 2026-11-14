extends RefCounted

## T-G3-10: D-57 nur Stubs, keine G4-Features, B bleibt getrennt.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-10", "D-57-Stubs, Scope-Grenzen, B-Isolation, Dateigrenze")
	var stubs: PackedStringArray = D57Stubs.labels()
	ctx.check_eq(stubs.size(), 7, "nicht sieben D-57-Stubs")
	var infos: Array = D57Stubs.info()
	ctx.check_eq(infos.size(), 7, "D-57-Info nicht sieben")
	var stub_ok: bool = true
	for info in infos:
		var item: Dictionary = info
		if str(item.get("name", "")) == "" or bool(item.get("events", true)) \
				or bool(item.get("state", true)):
			stub_ok = false
	ctx.check(stub_ok, "D-57-Stub mit Events/Zustand/Label")
	ctx.check(D57Stubs.hud_line().contains("Platzhalter"), "D-57-HUD-Linie")
	# Keine D-57-Events/Verbraucher/Produktion in der A-Simulation.
	var sim_text: String = FileAccess.get_file_as_string(
		"res://src/agents/simulation.gd")
	var dec_text: String = FileAccess.get_file_as_string(
		"res://src/decisions/decision_system.gd")
	ctx.check(not sim_text.to_lower().contains("d57"), "D57 im Simulationscode")
	ctx.check(not dec_text.to_lower().contains("d57"), "D57 im Entscheidungscode")
	# Keine G4-/Wirtschafts-/Politikmodule. D-68: Ab G4b sind
	# economy/politics/trade/caravan erlaubt; nur die Kriegs-Armee bleibt
	# außerhalb des V3-Kerns.
	var forbidden_dirs: Array = ["army"]
	var dir_names: Array = []
	for dir_name in DirAccess.get_directories_at("res://src"):
		dir_names.append(dir_name.to_lower())
	var no_forbidden: bool = true
	for name in forbidden_dirs:
		if dir_names.has(name):
			no_forbidden = false
	ctx.check(no_forbidden, "G4-/Wirtschaftsmodul im src-Baum")
	ctx.check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		"res://src/lod")), "B-Spike-Code fehlt")
	ctx.check(FileAccess.file_exists("res://tests/g3/g3_suite.tscn"),
		"B-Suite fehlt")
	ctx.check(FileAccess.file_exists("res://tests/g3/test_b_save.gd"),
		"B-Test fehlt")
	# B darf nicht in A importiert werden.
	var b_refs: int = 0
	for path in _gd_files("res://src"):
		if path.contains("/lod/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for token in ["BSim", "BConfig", "BDetail", "BBackground", "b_sim.gd",
				"b_detail.gd", "b_background.gd"]:
			if text.contains(token):
				b_refs += 1
	ctx.check_eq(b_refs, 0, "B-Referenz im A-Code")
	# Dateigrenze und Schema.
	var too_long: Array = []
	for path in _gd_files("res://src"):
		if path.contains("/lod/"):
			continue
		var lines: int = FileAccess.get_file_as_string(path).split("\n").size()
		if lines > 1000:
			too_long.append("%s:%d" % [path, lines])
	ctx.check(too_long.is_empty(), "Datei > 1000 Zeilen: %s" % str(too_long))
	ctx.check_eq(SimConfig.G3_SCHEMA_VERSION, 6, "Schema nicht 6")
	ctx.check_eq(SimConfig.SCHEMA_VERSION, 5, "historisches Schema verändert")
	# D-68: Die G3-Suite verbietet keine G4b-Fachbegriffe mehr in SimConfig.
	# Die G3-eigenen Schema- und Verhaltensprüfungen bleiben unverändert.


static func _gd_files(root: String) -> Array:
	var out: Array = []
	var dirs: Array = [root]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".gd"):
				out.append(dir + "/" + file_name)
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + "/" + sub)
	return out
