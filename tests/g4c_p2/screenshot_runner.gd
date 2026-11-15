extends Node

## Erzeugt die vier P2.1a-Screenshots aus der Demo. Nur Kamera/Zeit/HUD.

const OUT_DIR: String = "res://bench/results"

var demo: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT_DIR))
	var packed: PackedScene = load("res://tests/g4c_p2/demo.tscn")
	demo = packed.instantiate()
	add_child(demo)
	await get_tree().process_frame
	demo.paused = true
	demo.screenshot_mode = true
	await _shot("g4c_p2_closeup.png", 1, 10.5 * 3600.0,
		Vector2(166.0, 151.0), 2.8, true)
	await _shot("g4c_p2_overview.png", 1, 13.0 * 3600.0,
		Vector2(192.0, 202.0), 0.27, true)
	await _shot("g4c_p2_fields.png", 1, 15.0 * 3600.0,
		Vector2(44.0, 259.0), 2.1, true)
	await _shot("g4c_p2_night.png", 1, 22.5 * 3600.0,
		Vector2(192.0, 190.0), 1.0, true)
	print("G4C_P2_SCREENSHOTS_DONE")
	get_tree().quit(0)


func _shot(file_name: String, day: int, second: float,
		tile: Vector2, zoom: float, hud: bool) -> void:
	demo.set_clock(day, second)
	demo.set_hud_visible(hud)
	demo.focus_camera(tile, zoom)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(
		OUT_DIR.path_join(file_name))
	var err: Error = img.save_png(path)
	print("SHOT %s err=%d day=%d time=%.0f zoom=%.2f size=%dx%d" % [
		path, err, day, second, zoom, img.get_width(), img.get_height()])
	if err != OK:
		push_error("save_png failed: %s" % path)

