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

# G1b-Schritt 3: reine View-Zustände. Follow/Familienbaum/Chronik schreiben
# nie in die Simulation.
var follow_enabled: bool = false
var follow_agent_id: int = 0
var family_tree_visible: bool = false
var chronicle_visible: bool = true
var chronicle_filter_agent_id: int = 0
var chronicle_filter_household_id: int = 0
var chronicle_filter_importance: int = 0
var chronicle_filter_days: int = 7
