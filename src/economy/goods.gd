class_name Goods
extends RefCounted

## G4b-Güter. Grain bleibt zusätzlich im öffentlichen G4a-Kornspeicher; der
## Marktbestand ist ein kleiner, separater Marktanteil und bricht die
## Grundversorgung nicht. Preise werden als Tausendstel (milli) geführt, damit
## die Preisfunktion rein ganzzahlig und deterministisch bleibt.

const GRAIN: int = 0
const WOOD: int = 1
const TOOL: int = 2
const COUNT: int = 3

const CONFIG_VERSION: int = 1
static var BASE_PRICE_MILLI: PackedInt64Array = PackedInt64Array([1000, 2000, 5000])
static var TARGET_STOCK: PackedInt64Array = PackedInt64Array([60000, 15000, 4000])
const NAME_DE: Array = ["Grain", "Holz", "Werkzeug"]


static func name_of(good: int) -> String:
	if good < 0 or good >= COUNT:
		return "?"
	return str(NAME_DE[good])


static func unit_price(price_milli: int) -> int:
	return maxi(1, price_milli / 1000)
