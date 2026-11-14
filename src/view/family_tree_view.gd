class_name FamilyTreeView
extends Control

## Einfache grafische Familienbaum-Darstellung. Liest nur das Modell und
## schreibt nie Simulation.

var tree: Dictionary = {}
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(760, 440)


func configure(data: Dictionary) -> void:
	tree = data
	queue_redraw()


func _draw() -> void:
	if tree.is_empty():
		return
	var generations: Array = tree.get("generations", [])
	if generations.is_empty():
		return
	var positions: Dictionary = {}
	var x_step: float = 178.0
	var y_step: float = 58.0
	for gen_idx in generations.size():
		var generation_nodes: Array = generations[gen_idx]
		for row_idx in generation_nodes.size():
			var node: Dictionary = generation_nodes[row_idx]
			positions[int(node["id"])] = Vector2(24.0 + float(gen_idx) * x_step,
				34.0 + float(row_idx) * y_step)
	for edge in tree.get("parent_edges", []):
		var a: int = int(edge["a"])
		var b: int = int(edge["b"])
		if not positions.has(a) or not positions.has(b):
			continue
		var pa: Vector2 = positions[a] + Vector2(66, 34)
		var pb: Vector2 = positions[b] + Vector2(66, 0)
		var mid: Vector2 = Vector2(pa.x, (pa.y + pb.y) * 0.5)
		draw_line(pa, mid, Color(0.62, 0.58, 0.45, 0.9), 1.5)
		draw_line(mid, Vector2(pb.x, mid.y), Color(0.62, 0.58, 0.45, 0.9), 1.5)
		draw_line(Vector2(pb.x, mid.y), pb, Color(0.62, 0.58, 0.45, 0.9), 1.5)
	for edge in tree.get("partner_edges", []):
		var a2: int = int(edge["a"])
		var b2: int = int(edge["b"])
		if not positions.has(a2) or not positions.has(b2):
			continue
		var pa2: Vector2 = positions[a2] + Vector2(66, 34)
		var pb2: Vector2 = positions[b2] + Vector2(66, 34)
		if absf(pa2.y - pb2.y) < 1.0:
			draw_line(pa2, pb2, Color(0.78, 0.42, 0.46, 0.7), 1.5)
	for node in tree.get("nodes", []):
		var id: int = int(node["id"])
		if not positions.has(id):
			continue
		var pos: Vector2 = positions[id]
		var alive: bool = bool(node["alive"])
		var fill: Color = Color(0.20, 0.24, 0.20, 0.95) if alive \
			else Color(0.22, 0.21, 0.20, 0.95)
		var border: Color = Color(0.62, 0.72, 0.48) if alive \
			else Color(0.55, 0.48, 0.42)
		draw_rect(Rect2(pos, Vector2(132, 34)), fill)
		draw_rect(Rect2(pos, Vector2(132, 34)), border, false, 1.5)
		var label: String = "%s %d%s" % [str(node["name"]), id,
			"" if alive else " †"]
		draw_string(_font, pos + Vector2(6, 21), label,
			HORIZONTAL_ALIGNMENT_LEFT, 120, 12,
			Color(0.93, 0.91, 0.82) if alive else Color(0.72, 0.68, 0.62))
		draw_string(_font, pos + Vector2(6, 32), "Gen %d" % int(node["generation"]),
			HORIZONTAL_ALIGNMENT_LEFT, 120, 9, Color(0.65, 0.65, 0.58, 0.85))
