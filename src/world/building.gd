class_name Building
extends RefCounted

const KIND_HOUSE: int = 0
const KIND_FIELD: int = 1
const KIND_GRANARY: int = 2
const KIND_WELL: int = 3
const KIND_WORKSHOP: int = 4
const KIND_BARN: int = 5

## Voller Feldzyklus (G1b): FALLOW -> PLOWING -> PLOWED -> SOWING -> SOWN
## -> GROWING -> RIPE -> HARVESTING -> FALLOW. SOWN ist der Aussaat-Abschluss;
## GROWING ist der persistierte Wachstumszustand bis RIPE.
const FIELD_FALLOW: int = 0
const FIELD_PLOWING: int = 1
const FIELD_PLOWED: int = 2
const FIELD_SOWING: int = 3
const FIELD_SOWN: int = 4
const FIELD_GROWING: int = 5
const FIELD_RIPE: int = 6
const FIELD_HARVESTING: int = 7
const FIELD_STAGE_COUNT: int = 8

var id: int = 0
var kind: int = 0
var name: String = ""
var rect: Rect2i = Rect2i()
var door_tile: Vector2i = Vector2i()
var door_point: Vector2 = Vector2.ZERO

# Nur für kind == KIND_FIELD: autoritativer Feldzustand (wird gespeichert).
var field_stage: int = FIELD_FALLOW
var field_work_s: int = 0
var field_growth_end: int = 0
var field_growth_gen: int = 0


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
		KIND_WORKSHOP: return "Werkstatt"
		KIND_BARN: return "Scheune"
	return "?"


static func field_stage_name(stage: int) -> String:
	match stage:
		FIELD_FALLOW: return "FALLOW"
		FIELD_PLOWING: return "PLOWING"
		FIELD_PLOWED: return "PLOWED"
		FIELD_SOWING: return "SOWING"
		FIELD_SOWN: return "SOWN"
		FIELD_GROWING: return "GROWING"
		FIELD_RIPE: return "RIPE"
		FIELD_HARVESTING: return "HARVESTING"
	return "?"
