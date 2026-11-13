extends Node2D

## Render-Spike (Q6). Kein Kunst-Asset, nur Instanzen/Marker.
##
## Headless: Dummy-Renderer -> keine GPU-/FPS-Aussage. Es wird trotzdem die
## CPU-Kosten des Instanzaufbaus/Updates gemessen (render_cpu.json).
## Fenster: echte Frames/Draw Calls (render_window.json), GPU-ms nicht über
## Godot-API verfügbar -> FPS/Frame-Zeit als Proxy, klar dokumentiert.

const COUNTS: Array = [1000, 10000, 100000]
const PHASE_FRAMES: int = 60
const SPACING: float = 8.0
const QUAD_SIZE: float = 2.5

var _mmi: MultiMeshInstance2D = null
var _cam: Camera2D = null
var _headless: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_cam = Camera2D.new()
	_cam.enabled = true
	add_child(_cam)
	var out: Dictionary = {
		"meta": _meta(),
		"counts": [],
	}
	for n in COUNTS:
		var row: Dictionary = await _run_count(n)
		out["counts"].append(row)
		await get_tree().process_frame
	var file_name: String = "render_cpu.json" if _headless else "render_window.json"
	_write_json(file_name, out)
	print("RENDER_SPIKE_OK headless=%s file=%s" % [str(_headless), file_name])
	get_tree().quit(0)


func _meta() -> Dictionary:
	var meta: Dictionary = {
		"headless": _headless,
		"display_server": DisplayServer.get_name(),
		"godot": Engine.get_version_info()["string"],
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"gpu_measured": not _headless,
		"gpu_ms_available": false,
		"resolution": Vector2i(
			DisplayServer.window_get_size().x, DisplayServer.window_get_size().y),
		"utc": Time.get_datetime_string_from_system(true),
	}
	if not _headless:
		meta["video_adapter"] = RenderingServer.get_video_adapter_name()
		meta["video_vendor"] = RenderingServer.get_video_adapter_vendor()
	return meta


func _run_count(n: int) -> Dictionary:
	if _mmi != null:
		_mmi.queue_free()
		_mmi = null
		await get_tree().process_frame

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = false
	mm.mesh = mesh
	mm.instance_count = n

	var cols: int = int(ceil(sqrt(float(n))))
	var extent: float = float(cols) * SPACING
	var palette: Array = [
		Color(0.95, 0.55, 0.35), Color(0.45, 0.75, 0.95), Color(0.55, 0.85, 0.55),
		Color(0.9, 0.85, 0.45), Color(0.8, 0.55, 0.85), Color(0.65, 0.65, 0.7),
	]
	var t0: int = Time.get_ticks_usec()
	for i in n:
		var cx: int = i % cols
		var cy: int = i / cols
		var x: float = float(cx) * SPACING - extent * 0.5
		var y: float = float(cy) * SPACING - extent * 0.5
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(x, y)))
		mm.set_instance_color(i, palette[i % palette.size()])
	var build_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	_mmi = MultiMeshInstance2D.new()
	_mmi.multimesh = mm
	add_child(_mmi)
	_cam.position = Vector2.ZERO
	_cam.zoom = Vector2.ONE
	_cam.make_current()
	# Warm-up: Shader-/Pipeline-Compile, erster Instanz-Upload und alle drei
	# Zoom-Zustaende vorwaermen, damit sie nicht in die Messphasen fallen.
	await _prewarm()

	var phases: Dictionary = {}
	phases["near"] = await _measure_phase(Vector2(2.0, 2.0), false, extent)
	phases["far"] = await _measure_phase(Vector2(0.05, 0.05), false, extent)
	phases["pan"] = await _measure_phase(Vector2(0.35, 0.35), true, extent)

	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var video_mem: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var result: Dictionary = {
		"instances": n,
		"grid_cols": cols,
		"world_extent": extent,
		"build_ms": build_ms,
		"us_per_instance_build": build_ms * 1000.0 / float(n),
		"draw_calls_last_frame": draw_calls,
		"objects_last_frame": objects,
		"primitives_last_frame": primitives,
		"video_mem_bytes": video_mem,
		"phases": phases,
		"gpu_measured": not _headless,
	}
	_mmi.queue_free()
	_mmi = null
	return result


func _prewarm() -> void:
	_cam.position = Vector2.ZERO
	for z in [Vector2(2.0, 2.0), Vector2(0.05, 0.05), Vector2(0.35, 0.35)]:
		_cam.zoom = z
		for i in 20:
			await get_tree().process_frame
	_cam.position = Vector2.ZERO
	_cam.zoom = Vector2.ONE


func _measure_phase(zoom: Vector2, pan: bool, extent: float) -> Dictionary:
	_cam.zoom = zoom
	_cam.position = Vector2.ZERO
	for i in 10:
		await get_tree().process_frame
	var last: int = Time.get_ticks_usec()
	var frames: PackedFloat64Array = PackedFloat64Array()
	for i in PHASE_FRAMES:
		if pan:
			var t: float = float(i) / float(maxi(PHASE_FRAMES - 1, 1))
			_cam.position = Vector2(extent * 0.5 * (t * 2.0 - 1.0), 0.0)
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
	var st: Dictionary = SpikeRunner.stats(frames)
	var mean_ms: float = st["mean"]
	return {
		"zoom": [zoom.x, zoom.y],
		"pan": pan,
		"frames": PHASE_FRAMES,
		"frame_p50_ms": st["p50"],
		"frame_p95_ms": st["p95"],
		"frame_max_ms": st["max"],
		"fps_mean": 1000.0 / mean_ms if mean_ms > 0.0 else 0.0,
	}


func _write_json(file_name: String, data: Variant) -> void:
	var dir: String = ProjectSettings.globalize_path("res://bench/results")
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join(file_name), FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + file_name)
		return
	f.store_string(JSON.stringify(data, "  ", false, true))
	f.close()
