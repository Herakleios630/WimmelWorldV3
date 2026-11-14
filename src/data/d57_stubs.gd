class_name D57Stubs
extends RefCounted

## D-57-Platzhalter für G2/G3. Reine Daten-/UI-Stubs ohne Simulationseffekt:
## keine Events, keine Zustandsänderung, keine Verbraucher, keine Produktion.

const SYSTEMS: Array = [
	"Wetter", "Feste", "Religion", "Kultur", "Krankheit", "Recht", "Bildung",
]

const STATUS: String = "Stub – keine Simulation, keine Events, keine Produktion"


static func labels() -> PackedStringArray:
	return PackedStringArray(SYSTEMS)


static func info() -> Array:
	var out: Array = []
	for name in SYSTEMS:
		out.append({
			"id": str(name).to_lower(),
			"name": name,
			"status": STATUS,
			"simulation_effect": false,
			"events": false,
			"state": false,
		})
	return out


static func hud_line() -> String:
	return "D-57: " + " · ".join(PackedStringArray(SYSTEMS)) + " (nur Platzhalter)"
