class_name Building
extends RefCounted

const KIND_HOUSE: int = 0
const KIND_FIELD: int = 1
const KIND_GRANARY: int = 2
const KIND_WELL: int = 3
const KIND_WORKSHOP: int = 4

var id: int = 0
var kind: int = 0
var name: String = ""
var rect: Rect2i = Rect2i()
var door_tile: Vector2i = Vector2i()
var door_point: Vector2 = Vector2.ZERO


func _init(p_id: int = 0, p_kind: int = 0, p_name: String = "",
		p_rect: Rect2i = Rect2i(), p_door: Vector2i = Vector2i()) -> void:
	id = p_id
	kind = p_kind
	name = p_name
	rect = p_rect
	door_tile = p_door
	door_point = Vector2(p_door.x + 0.5, p_door.y + 0.5)


func has_tile(x: int, y: int) -> bool:
	return x >= rect.position.x and x < rect.position.x + rect.size.x \
		and y >= rect.position.y and y < rect.position.y + rect.size.y


static func kind_name(p_kind: int) -> String:
	match p_kind:
		KIND_HOUSE: return "Wohnhaus"
		KIND_FIELD: return "Feld"
		KIND_GRANARY: return "Kornspeicher"
		KIND_WELL: return "Brunnen"
		KIND_WORKSHOP: return "Scheune/Werkstatt"
	return "?"
