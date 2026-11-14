extends Node2D

## Sichtbarer UI-Smoke für G1b-Schritt 3: Chronik, Story, Alerts, Familienbaum.
## godot --path V3 res://tests/g1b/capture_chronicle.tscn

const FeaturedSeed = preload("res://tests/g1b/featured_seed.gd")

var sim: Simulation
var view_state: ViewState
var world_view: WorldView
var camera: GameCamera
var hud: Hud
var chronicle_hud: ChronicleHud


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE_CHRONICLE requires a window")
		get_tree().quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var config: SimConfig = SimConfig.new()
	config.seed = FeaturedSeed.FEATURED_SEED
	sim = Simulation.create(config)
	view_state = ViewState.new()
	view_state.speed = 50
	view_state.paused = true
	view_state.camera_position = Vector2(64, 64)
	view_state.zoom = 1.35
	world_view = WorldView.new()
	add_child(world_view)
	world_view.configure(sim, view_state)
	camera = GameCamera.new()
	add_child(camera)
	camera.configure(view_state, sim)
	camera.enabled = true
	camera.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.configure(view_state)
	chronicle_hud = ChronicleHud.new()
	add_child(chronicle_hud)
	chronicle_hud.configure(sim, view_state)
	# Nach der ersten Geburt und den ersten Toden (Lifecycle-Tag 20 =
	# Anzeige Tag 21 00:00).
	sim.advance_to(20 * SimConfig.TICKS_PER_DAY + 6 * 3600)
	view_state.selected_agent_id = 11
	view_state.follow_agent_id = 11
	camera.focus_on_tile(sim.current_position(sim.store.row_for_id(11)))
	await get_tree().process_frame
	chronicle_hud.refresh(sim, true)
	hud.refresh(sim)
	for i in 6:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://bench/results"))
	var err: int = img.save_png("res://bench/results/g1b_chronicle_ui.png")
	print("CAPTURE_CHRONICLE chronicle err=%d size=%s" % [err, str(img.get_size())])
	view_state.family_tree_visible = true
	chronicle_hud.refresh(sim, true)
	for i in 6:
		await get_tree().process_frame
	var tree_img: Image = get_viewport().get_texture().get_image()
	var tree_err: int = tree_img.save_png("res://bench/results/g1b_family_tree.png")
	print("CAPTURE_CHRONICLE family err=%d size=%s" % [
		tree_err, str(tree_img.get_size())])
	get_tree().quit(0 if err == OK and tree_err == OK else 1)
