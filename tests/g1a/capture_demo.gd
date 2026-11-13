extends Node2D

## Erzeugt einen Screenshot der G1a-Demo für die visuelle Smoke-Prüfung.
## godot --path V3 res://tests/g1a/capture_demo.tscn

func _ready() -> void:
	var demo_scene: PackedScene = load("res://tests/g1a/demo.tscn")
	var demo: DemoMain = demo_scene.instantiate()
	add_child(demo)
	await get_tree().process_frame
	await get_tree().process_frame
	demo.view_state.speed = 10
	demo.sim.advance_to(G1aTestUtil.abs_time(0, 10, 0))
	demo.view_state.paused = true
	demo.view_state.selected_agent_id = 1
	demo.view_state.camera_position = Vector2(70, 64)
	demo.camera.focus_on_tile(Vector2(75, 64))
	demo.hud.refresh(demo.sim)
	for i in 8:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://bench/results"))
	var err: int = img.save_png("res://bench/results/g1a_demo.png")
	print("CAPTURE_DEMO day err=%d size=%s" % [err, str(img.get_size())])
	demo.sim.advance_to(G1aTestUtil.abs_time(0, 22, 0))
	demo.hud.refresh(demo.sim)
	for i in 6:
		await get_tree().process_frame
	var night: Image = get_viewport().get_texture().get_image()
	var err_night: int = night.save_png("res://bench/results/g1a_demo_night.png")
	print("CAPTURE_DEMO night err=%d size=%s" % [err_night, str(night.get_size())])
	get_tree().quit(0 if err == OK and err_night == OK else 1)
