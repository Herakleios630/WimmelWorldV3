extends SceneTree

## G4c-P-Pretest-Selbstcheck (kein Gate):
## Profil, Welt, Bevölkerung, Feldphasen, Toggles und Anzeige-Offset.
## Aufruf:
##   godot --headless --path V3 --script res://tests/g4c_p/pretest_check.gd

const DAY: int = SimConfig.TICKS_PER_DAY
const VIEW = preload("res://tests/g4c_p/kenney_world_view.gd")

var _failed: int = 0


func _init() -> void:
	var config: SimConfig = SimConfig.g4c_pre(1337)
	_check(config.profile == SimConfig.PROFILE_G4C_P, "Profil G4C_P")
	_check(config.world_size == 384, "Welt 384")
	_check(config.target_agents == 100, "100 Agenten")
	_check(config.target_households == 24, "24 Haushalte")
	_check(config.year_days == 120, "120-Tage-Jahr")
	_check(config.season_days == 30, "4x30 Seasons")
	_check(config.seasonal_fields, "saisonale Felder")
	_check(config.start_grain == 36000, "Startgrain 36000")
	_check(config.granary_capacity == 72000, "Granary 72000")
	_check(config.field_harvest_yield == 10000, "Feld brutto 10000")
	_check(config.field_seed_cost == 1000, "Saatgut 1000")
	_check(config.uses_g3_schedule(), "G3-Rollenplan")
	_check(config.uses_pathfinder(), "A*-Pfadfinder")

	var sim: Simulation = Simulation.create(config)
	_check(sim.count_alive() == 100, "100 lebende Agenten")
	_check(sim.households.size() == 24, "24 Haushalte in Sim")
	_check(sim.world.field_ids().size() == 4, "4 Felder")
	_check(sim.day_index() == 0, "Tag 1 (Index 0)")
	_check(config.season_name_for_day(0) == "Frühling", "Start Frühling")
	_check(sim.grain == 36000, "Grain 36000")
	for field_id in sim.world.field_ids():
		var f: Building = sim.world.building_by_id(field_id)
		_check(f.field_stage == Building.FIELD_FALLOW, "Feld %d startet Brache" % field_id)

	# Tag 1: nach dem Arbeitsbeginn sind die Felder nicht mehr alle Brache.
	sim.advance_to(18 * 3600 + 1800)
	var active: int = 0
	for field_id in sim.world.field_ids():
		var f2: Building = sim.world.building_by_id(field_id)
		if f2.field_stage != Building.FIELD_FALLOW:
			active += 1
	_check(active == 4, "Tag 1: alle 4 Felder bearbeitet")
	_check(sim.grain < 36000, "Saatgut wurde verbraucht")

	# Herbstartag: morgens reif, nach Arbeitsbeginn Ernte.
	sim.advance_to(60 * DAY + 6 * 3600 + 1800)
	var ripe: int = 0
	for field_id in sim.world.field_ids():
		var f3: Building = sim.world.building_by_id(field_id)
		if f3.field_stage == Building.FIELD_RIPE:
			ripe += 1
	_check(ripe == 4, "Tag 61 06:30: alle 4 Felder reif")
	sim.advance_to(60 * DAY + 9 * 3600 + 1800)
	var harvesting: int = 0
	for field_id in sim.world.field_ids():
		var f4: Building = sim.world.building_by_id(field_id)
		if f4.field_stage == Building.FIELD_HARVESTING:
			harvesting += 1
	_check(harvesting == 4, "Tag 61 09:30: alle 4 Felder in Ernte")

	# View-Toggles und Labels (nur Darstellung).
	var view: Node2D = VIEW.new()
	get_root().add_child(view)
	view.configure(sim, ViewState.new())
	_check(view.terrain_label() == "RPG Pack", "Terrain-Label Pack")
	view.set_terrain_mode(1)
	_check(view.terrain_label() == "RPG Base (16 px)", "Terrain-Toggle Base")
	view.set_terrain_mode(0)
	view.set_character_mode(1)
	_check(view.character_label() == "Vektor-Figuren", "C-Toggle Vektor")
	view.set_character_mode(0)
	_check(view.character_label() == "Kenney-Figuren", "C-Toggle Kenney")
	_check(view.field_stage_label(Building.FIELD_FALLOW) == "Brache",
		"Feldlabel Brache")
	_check(view.field_stage_label(Building.FIELD_RIPE) == "reif",
		"Feldlabel reif")
	_check(view.field_stage_label(Building.FIELD_HARVESTING) == "Ernte",
		"Feldlabel Ernte")
	var row: int = 0
	var true_pos: Vector2 = sim.current_position(row)
	var vis: Vector2 = view._agent_visual_pos(row, true_pos)
	_check(vis.distance_to(true_pos * 16.0) > 0.5,
		"Anzeige-Offset entzerrt gestapelte Agenten")
	_check(view._agent_visual_pos(row, true_pos).is_equal_approx(vis),
		"Anzeige-Offset ist stabil")
	view.queue_free()

	print("G4C_P_CHECK failed=%d" % _failed)
	print("G4C_P_CHECK_OK" if _failed == 0 else "G4C_P_CHECK_FAIL")
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("G4C_P_CHECK PASS  " + label)
	else:
		_failed += 1
		print("G4C_P_CHECK FAIL  " + label)
