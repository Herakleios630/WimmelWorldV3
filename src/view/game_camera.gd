class_name GameCamera
extends Camera2D

## Kamera/Steuerung. Schreibt nur Kamera- und ViewState-Werte, nie Simulation.

const PAN_SPEED: float = 900.0
const ZOOM_MIN: float = 0.45
const ZOOM_MAX: float = 4.0

var view_state: ViewState
var _dragging: bool = false


func configure(p_view_state: ViewState) -> void:
	view_state = p_view_state
	position = p_view_state.camera_position * SimConfig.PIXELS_PER_TILE
	zoom = Vector2(p_view_state.zoom, p_view_state.zoom)


func _process(delta: float) -> void:
	if view_state == null:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_position()
	view_state.camera_position = position / SimConfig.PIXELS_PER_TILE
	view_state.zoom = zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		position -= mm.relative / zoom.x
		_clamp_position()


func _zoom_at(_screen_pos: Vector2, factor: float) -> void:
	var new_zoom: float = clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(new_zoom, new_zoom)


func _clamp_position() -> void:
	var half: Vector2 = get_viewport_rect().size * 0.5 / zoom.x
	var map_size: Vector2 = Vector2(WorldMap.SIZE * SimConfig.PIXELS_PER_TILE,
		WorldMap.SIZE * SimConfig.PIXELS_PER_TILE)
	var min_p: Vector2 = half
	var max_p: Vector2 = map_size - half
	if min_p.x > max_p.x:
		position.x = map_size.x * 0.5
	else:
		position.x = clampf(position.x, min_p.x, max_p.x)
	if min_p.y > max_p.y:
		position.y = map_size.y * 0.5
	else:
		position.y = clampf(position.y, min_p.y, max_p.y)


func focus_on_tile(tile_pos: Vector2) -> void:
	position = tile_pos * SimConfig.PIXELS_PER_TILE
	_clamp_position()
	if view_state != null:
		view_state.camera_position = position / SimConfig.PIXELS_PER_TILE
