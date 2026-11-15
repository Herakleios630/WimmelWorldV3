extends Node2D

## G4c-P2.1b Demo: kompaktes 100-Agenten-Ringdorf, 176x176, 1,5 m/Tile,
## 120-Tage-Jahr mit vier Jahreszeiten. Die Lauf-Agenten sind reine
## View-Figuren auf dem generierten Weg-Graphen; Simulation/Save bleiben
## unberuehrt.

const GeneratorScript = preload("res://tests/g4c_p2/settlement_gen.gd")
const WorldViewScript = preload("res://tests/g4c_p2/world_view_p2.gd")
const CameraScript = preload("res://tests/g4c_p/pretest_camera.gd")

const SEED: int = 421337
const SEASONS: Array = ["Frühling", "Sommer", "Herbst", "Winter"]
const SEASON_TINT: Array = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.99, 0.92),
	Color(1.0, 0.92, 0.82), Color(0.90, 0.95, 1.02)]
const DAYS_PER_SEASON: int = 30

var layout: Dictionary
var view_state: ViewState
var world_view: Node2D
var camera: Camera2D
var day: int = 1
var second_of_day: float = 9.0 * 3600.0
var time_scale: float = 240.0
var paused: bool = false
var screenshot_mode: bool = false

var _hud_layer: CanvasLayer
var _hud_panel: Panel
var _hud_labels: Array = []
var _hud_timer: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.12, 0.09))
	var gen = GeneratorScript.new()
	layout = gen.generate(SEED)
	view_state = ViewState.new()
	view_state.camera_position = Vector2(88.0, 88.0)
	view_state.zoom = 1.05
	world_view = WorldViewScript.new()
	add_child(world_view)
	world_view.configure(layout, view_state, SEED)
	camera = CameraScript.new()
	add_child(camera)
	camera.configure(view_state, int(layout["size"]))
	camera.make_current()
	_build_hud()
	_apply_time()
	_refresh_hud()
	var s: Dictionary = gen.summary()
	print("G4C_P2_LAYOUT seed=%d houses=%d rows=%d farms=%d fields=%d roads=%d trees=%d civic=%d" % [
		SEED, int(s["houses"]), int(s["rows"]), int(s["farmsteads"]),
		int(s["fields"]), int(s["roads"]), int(s["trees"]), int(s["civic"])])



func _process(delta: float) -> void:
	if not paused:
		second_of_day += delta * time_scale
		while second_of_day >= 86400.0:
			second_of_day -= 86400.0
			day += 1
			if day > 120:
				day = 1
	_apply_time()
	_hud_timer += delta
	if _hud_timer >= 0.2:
		_hud_timer = 0.0
		_refresh_hud()


func set_clock(p_day: int, p_second: float) -> void:
	day = clampi(p_day, 1, 120)
	second_of_day = fmod(p_second, 86400.0)
	_apply_time()
	_refresh_hud()


func season_index() -> int:
	return int(float(day - 1) * 4.0 / 120.0)


func _apply_time() -> void:
	var hour: float = second_of_day / 3600.0
	var daylight: Color
	if hour < 5.0 or hour >= 21.5:
		daylight = Color(0.40, 0.46, 0.70)
	elif hour < 7.0:
		daylight = Color(0.40, 0.46, 0.70).lerp(Color(1.0, 0.87, 0.70),
			(hour - 5.0) / 2.0)
	elif hour < 17.5:
		daylight = Color(1.0, 0.98, 0.92)
	elif hour < 19.5:
		daylight = Color(1.0, 0.98, 0.92).lerp(Color(1.0, 0.72, 0.50),
			(hour - 17.5) / 2.0)
	else:
		daylight = Color(1.0, 0.72, 0.50).lerp(Color(0.40, 0.46, 0.70),
			(hour - 19.5) / 2.0)
	var tint: Color = SEASON_TINT[season_index()]
	world_view.modulate = Color(daylight.r * tint.r, daylight.g * tint.g,
		daylight.b * tint.b)
	if hour < 5.0 or hour >= 22.0:
		world_view.night_factor = 1.0
	elif hour < 7.0:
		world_view.night_factor = 1.0 - (hour - 5.0) / 2.0
	elif hour >= 18.0:
		world_view.night_factor = (hour - 18.0) / 4.0
	else:
		world_view.night_factor = 0.0
	world_view.season_index = season_index()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	_hud_panel = Panel.new()
	_hud_panel.position = Vector2(18, 16)
	_hud_panel.size = Vector2(560, 88)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.06, 0.78)
	style.border_color = Color(0.72, 0.63, 0.42, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_hud_panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(_hud_panel)
	for i in 2:
		var label: Label = Label.new()
		label.position = Vector2(14, 8 + i * 36)
		label.add_theme_font_size_override("font_size", 18 if i == 0 else 15)
		label.add_theme_color_override("font_color",
			Color(1.0, 0.94, 0.78) if i == 0 else Color(0.86, 0.88, 0.78))
		_hud_panel.add_child(label)
		_hud_labels.append(label)


func _refresh_hud() -> void:
	if _hud_labels.is_empty():
		return
	var hh: int = int(second_of_day / 3600.0)
	var mm: int = int(fmod(second_of_day, 3600.0) / 60.0)
	var s: Dictionary = layout.get("summary", {})
	var house_count: int = (layout["houses"] as Array).size()
	var field_count: int = (layout["fields"] as Array).size()
	_hud_labels[0].text = "G4c-P2.1b · %02d:%02d · Tag %d/120 · %s" % [
		hh, mm, day, SEASONS[season_index()]]
	_hud_labels[1].text = "%d Agenten · %d Häuser · %d Feldparzellen · %d Bäume" % [
		world_view.walkers.size(), house_count, field_count,
		(layout["trees"] as Array).size()]
	var speed: String = "pausiert" if paused else "%.0fx" % time_scale
	_hud_labels[1].text += " · %s" % speed


func set_hud_visible(v: bool) -> void:
	_hud_layer.visible = v


func focus_camera(tile: Vector2, zoom: float) -> void:
	camera.focus_tile(tile, zoom)
	world_view.queue_redraw()
