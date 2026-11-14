extends RefCounted

## T-G4a-10: D-57-Stubs, keine G4b-Systeme, B-Isolation, Dateigrenze,
## G1-G3-Regressionsflächen, Save-Schema 7.

const FORBIDDEN_DIRS: Array = ["economy", "politics", "trade", "caravan", "army"]


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4a-10", "D-57-Stubs, Scope, B-Isolation, Dateigrenze, Schema 7")
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
	# Keine G4b-Module.
	var dir_names: Array = []
	for dir_name in DirAccess.get_directories_at("res://src"):
		dir_names.append(dir_name.to_lower())
	var no_forbidden: bool = true
	for name in FORBIDDEN_DIRS:
		if dir_names.has(name):
			no_forbidden = false
	ctx.check(no_forbidden, "G4b-/Wirtschaftsmodul im src-Baum")
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
	# Dateigrenze im A-Code.
	var too_long: Array = []
	for path in _gd_files("res://src"):
		if path.contains("/lod/"):
			continue
		var lines: int = FileAccess.get_file_as_string(path).split("\n").size()
		if lines > 1000:
			too_long.append("%s:%d" % [path, lines])
	ctx.check(too_long.is_empty(), "Datei > 1000 Zeilen: %s" % str(too_long))
	# Schema-Versionen und Regressionsflächen.
	ctx.check_eq(SimConfig.SCALE_SCHEMA_VERSION, 7, "Schema nicht 7")
	ctx.check_eq(SimConfig.G3_SCHEMA_VERSION, 6, "G3-Schema verändert")
	ctx.check_eq(SimConfig.SCHEMA_VERSION, 5, "historisches Schema verändert")
	ctx.check_eq(SimConfig.scale(1337).save_schema_version(), 7,
		"Profil-Schema nicht 7")
	ctx.check_eq(SimConfig.g3(1337).save_schema_version(), 6,
		"G3-Profil-Schema verändert")
	for path in ["res://tests/g1a/g1a_suite.tscn",
			"res://tests/g1b/g1b_suite.tscn",
			"res://tests/g2/g2_suite.tscn",
			"res://tests/g3/g3_a_suite.tscn"]:
		ctx.check(FileAccess.file_exists(path), "Regression-Suite fehlt: %s" % path)
	# Keine G4b-/D-57-Simulation im Kern.
	for path in ["res://src/agents/simulation.gd",
			"res://src/decisions/decision_system.gd",
			"res://src/decisions/field_work_system.gd",
			"res://src/decisions/work_system.gd",
			"res://src/decisions/need_actions.gd"]:
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		ctx.check(not text.contains("d57"), "D57 im Kern: %s" % path)
		ctx.check(not text.contains("karawane"), "Karawane im Kern: %s" % path)
		ctx.check(not text.contains("steuer"), "Steuer im Kern: %s" % path)


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
