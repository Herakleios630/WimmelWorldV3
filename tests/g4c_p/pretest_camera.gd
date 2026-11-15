extends Camera2D

## G4c-P-Kamera. Schreibt ausschliesslich ViewState-Werte, nie Simulation.

const ZOOM_MIN: float = 0.14
const ZOOM_MAX: float = 6.0
const PAN_SPEED: float = 1200.0

var view_state: ViewState
var world_tiles: int = 384
var _dragging: bool = false


func configure(p_view_state: ViewState, p_world_tiles: int) -> void:
	view_state = p_view_state
	world_tiles = p_world_tiles
	position = view_state.camera_position * 16.0
	zoom = Vector2(view_state.zoom, view_state.zoom)


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
		_clamp()
	view_state.camera_position = position / 16.0
	view_state.zoom = zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.18)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.18)
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		position -= mm.relative / zoom.x
		_clamp()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return
	# Zoom auf den Mauszeiger: Weltpunkt unter dem Cursor bleibt stehen.
	var vp_center: Vector2 = get_viewport_rect().size * 0.5
	var before: Vector2 = position + (screen_pos - vp_center) / old_zoom
	zoom = Vector2(new_zoom, new_zoom)
	position = before - (screen_pos - vp_center) / new_zoom
	_clamp()


func _clamp() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var half: Vector2 = vp * 0.5 / maxf(0.01, zoom.x)
	var map_px: Vector2 = Vector2(world_tiles * 16, world_tiles * 16)
	if half.x * 2.0 >= map_px.x:
		position.x = map_px.x * 0.5
	else:
		position.x = clampf(position.x, half.x, map_px.x - half.x)
	if half.y * 2.0 >= map_px.y:
		position.y = map_px.y * 0.5
	else:
		position.y = clampf(position.y, half.y, map_px.y - half.y)


func focus_tile(tile: Vector2, p_zoom: float = -1.0) -> void:
	if p_zoom > 0.0:
		zoom = Vector2(clampf(p_zoom, ZOOM_MIN, ZOOM_MAX),
			clampf(p_zoom, ZOOM_MIN, ZOOM_MAX))
	position = tile * 16.0
	_clamp()
	if view_state != null:
		view_state.camera_position = position / 16.0
		view_state.zoom = zoom.x
