extends Node

## Erzeugt die vier G4c-P-Screenshots aus der echten Demo. Die Zeit wird
## ueber die Simulation (advance_to) vorgespult; es werden keine Felder,
## Agenten oder Events kuenstlich gesetzt. Nur Kamera/Auswahl/Hover sind View.

const DAY: int = SimConfig.TICKS_PER_DAY
const OUT_DIR: String = "res://bench/results"

var demo: Node2D
var sim: Simulation
var view_state: ViewState
var camera: Camera2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_DIR))
	var packed: PackedScene = load("res://tests/g4c_p/demo.tscn")
	demo = packed.instantiate()
	add_child(demo)
	await get_tree().process_frame
	sim = demo.sim
	view_state = demo.view_state
	camera = demo.camera
	view_state.paused = true
	# Hover nicht aus der Mausposition ueberschreiben; HUD/FPS laufen weiter.
	demo.screenshot_mode = true

	await _shot_closeup()
	await _shot_toggles()
	await _shot_overview()
	await _shot_night()
	await _shot_field_season()

	print("G4C_P_SCREENSHOTS_DONE")
	get_tree().quit(0)


func _shot_closeup() -> void:
	demo.set_hud_visible(true)
	_advance_to_day_time(0, 11 * 3600 + 1800)
	var row: int = _nearest_agent_row(Vector2(305.0, 148.0), 8.0)
	_set_selection(row)
	camera.focus_tile(Vector2(290.0, 150.0), 1.8)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_closeup.png")
	print("SHOT closeup day=%d time=%s zoom=%.2f selected=%d" % [
		sim.day_index() + 1, sim.clock.time_string(), view_state.zoom,
		view_state.selected_agent_id])


func _shot_toggles() -> void:
	demo.world_view.set_terrain_mode(1)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_toggle_terrain_base.png")
	demo.world_view.set_terrain_mode(0)
	demo.world_view.set_character_mode(1)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_toggle_vector.png")
	demo.world_view.set_character_mode(0)
	demo._refresh_hud(true)
	print("SHOT toggles terrain=%s characters=%s" % [
		demo.world_view.terrain_label(),
		demo.world_view.character_label()])


func _shot_overview() -> void:
	_advance_to_day_time(0, 12 * 3600)
	_set_selection(-1)
	demo.set_hud_visible(false)
	camera.focus_tile(Vector2(192.0, 190.0), 0.30)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_overview.png")
	demo.set_hud_visible(true)
	print("SHOT overview day=%d time=%s zoom=%.2f" % [
		sim.day_index() + 1, sim.clock.time_string(), view_state.zoom])


func _shot_night() -> void:
	demo.set_hud_visible(true)
	_advance_to_day_time(0, 22 * 3600 + 1800)
	_set_selection(_nearest_agent_row(Vector2(188.0, 150.0), 18.0))
	camera.focus_tile(Vector2(188.0, 150.0), 1.8)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_night.png")
	print("SHOT night day=%d time=%s zoom=%.2f" % [
		sim.day_index() + 1, sim.clock.time_string(), view_state.zoom])


func _shot_field_season() -> void:
	# Tag 61 = erster Herbsttag (Season 3/4 im 120-Tage-Jahr). Um 06:30
	# sind alle Felder reif; ab dem Arbeitsbeginn laufen sie in die Ernte.
	demo.set_hud_visible(true)
	_advance_to_day_time(60, 9 * 3600 + 1800)
	_set_selection(-1)
	camera.focus_tile(Vector2(300.0, 164.0), 0.48)
	demo._refresh_hud(true)
	await _settle()
	await _save("g4c_p_field_season.png")
	var stages: PackedStringArray = PackedStringArray()
	for field_id in sim.world.field_ids():
		var field: Building = sim.world.building_by_id(field_id)
		stages.append("%s=%s" % [field.name,
			demo.world_view.field_stage_label(field.field_stage)])
	print("SHOT field season day=%d time=%s stages=%s grain=%d" % [
		sim.day_index() + 1, sim.clock.time_string(),
		" | ".join(stages), sim.grain])


func _advance_to_day_time(day: int, second: int) -> void:
	var target: int = day * DAY + second
	if target > sim.clock.now:
		sim.advance_to(target)
	demo._update_day_night()
	demo._refresh_hud(true)
	demo.world_view.queue_redraw()
	_apply_hover()
	if camera != null:
		demo._refresh_hud(true)
		demo.world_view.queue_redraw()


func _set_selection(row: int) -> void:
	if row < 0:
		view_state.selected_agent_id = 0
		demo._hover_id = 0
		demo.world_view.hover_agent_id = 0
	else:
		view_state.selected_agent_id = sim.store.ids[row]
		demo._hover_id = sim.store.ids[row]
		demo.world_view.hover_agent_id = sim.store.ids[row]


func _nearest_agent_row(tile: Vector2, max_dist: float) -> int:
	var best: int = -1
	var best_d: float = max_dist
	for row in sim.store.count:
		if sim.store.alive[row] == 0:
			continue
		var d: float = sim.current_position(row).distance_to(tile)
		if d < best_d:
			best_d = d
			best = row
	return best


func _apply_hover() -> void:
	if view_state.selected_agent_id > 0:
		demo._hover_id = view_state.selected_agent_id
		demo.world_view.hover_agent_id = view_state.selected_agent_id


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(OUT_DIR.path_join(file_name))
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("save_png failed: %s (%d)" % [path, err])
	else:
		print("SAVED %s %dx%d" % [path, img.get_width(), img.get_height()])
