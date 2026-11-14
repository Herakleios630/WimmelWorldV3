extends RefCounted

## T-G4b-11: kein Krieg, keine D-57-Simulation, keine G5-Features,
## keine B-Integration, Dateigrenze, Schema 8.


static func run(ctx: G1aTestContext) -> void:
	ctx.begin("T-G4b-11", "Scope: kein Krieg/D-57/G5/B")
	var sim: Simulation = G4BTestUtil.new_sim()
	ctx.check_eq(sim.store.count, 10000, "nicht 10.000 Agenten")
	ctx.check_eq(sim.config.target_agents, 10000, "G5-Agentenziel")
	ctx.check_eq(sim.politics.nation.neighbors.size(), 2,
		"nicht zwei abstrakte Nachbarn")
	ctx.check_eq(sim.economy.caravans.nodes.size(), 3, "nicht drei Knoten")
	ctx.check(sim.economy.caravans.active_count() <= CaravanSystem.MAX_ACTIVE,
		"zu viele physische Karawanen")
	# Kein Krieg/Armee-Modul und keine Kriegssimulation in G4b-Modulen.
	ctx.check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		"res://src/army")), "Armee-Modul vorhanden")
	var war_tokens: int = 0
	for path in _gd_files("res://src/economy") + _gd_files("res://src/politics"):
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		for token in ["declare_war", "battle", "soldier", "army", "siege"]:
			if text.contains(token):
				war_tokens += 1
	ctx.check_eq(war_tokens, 0, "Kriegs-Feature in G4b-Modulen")
	# D-57 bleibt inert und wird nicht konsumiert.
	var stubs: PackedStringArray = D57Stubs.labels()
	ctx.check_eq(stubs.size(), 7, "nicht sieben D-57-Stubs")
	for info in D57Stubs.info():
		var item: Dictionary = info
		ctx.check(not bool(item.get("events", true))
			and not bool(item.get("state", true)),
			"D-57-Stub mit Events/Zustand")
	for path in _gd_files("res://src/economy") + _gd_files("res://src/politics") \
			+ ["res://src/agents/simulation.gd"]:
		ctx.check(not FileAccess.get_file_as_string(path).to_lower().contains("d57stubs"),
			"D-57-Stub im G4b-Code: " + path)
	# G5-Grenzen: eine Nation, keine 100k/3-Nationen-Struktur.
	var civic: SimConfig = SimConfig.civic(1337)
	ctx.check_eq(civic.target_agents, 10000, "Profil nicht 10k")
	ctx.check_eq(civic.target_households, 2000, "Profil nicht 2k Haushalte")
	ctx.check_eq(sim.politics.nation.id, 1, "mehr als eine Nation")
	# B-Isolation.
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
	ctx.check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(
		"res://src/lod")), "B-Spike-Code fehlt")
	# Dateigrenze.
	var too_long: Array = []
	for path in _gd_files("res://src"):
		if path.contains("/lod/"):
			continue
		var lines: int = FileAccess.get_file_as_string(path).split("\n").size()
		if lines > 1000:
			too_long.append("%s:%d" % [path, lines])
	ctx.check(too_long.is_empty(), "Datei > 1000 Zeilen: %s" % str(too_long))
	# Schema-Grenzen.
	ctx.check_eq(SimConfig.CIVIC_SCHEMA_VERSION, 8, "G4b-Schema nicht 8")
	ctx.check_eq(SimConfig.SCALE_SCHEMA_VERSION, 7, "G4a-Schema verändert")
	ctx.check_eq(SimConfig.G3_SCHEMA_VERSION, 6, "G3-Schema verändert")
	ctx.check_eq(SimConfig.SCHEMA_VERSION, 5, "historisches Schema verändert")
	ctx.check_eq(civic.save_schema_version(), 8, "G4b-Profil nicht Schema 8")
	ctx.check_eq(SimConfig.scale(1337).save_schema_version(), 7,
		"G4a-Profil nicht Schema 7")
	# Keine G4b-UI im G4a-Profil (Economy bleibt null).
	var g4a: Simulation = Simulation.create(SimConfig.scale(1337))
	ctx.check(g4a.economy == null and g4a.politics == null,
		"G4b-Systeme im G4a-Profil aktiv")


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
