class_name ViewState
extends RefCounted

## Ausschließlich Darstellung: Kamera, Zoom, Sichtbarkeit, Auswahl.
## Diese Werte werden nie an die Simulation übergeben.

var camera_position: Vector2 = Vector2(64, 64)
var zoom: float = 1.5
var agents_visible: bool = true
var event_log_visible: bool = true
var selected_agent_id: int = 0
var speed: int = 1
var paused: bool = false
