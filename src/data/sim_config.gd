class_name SimConfig
extends RefCounted

## G1a-Konfiguration. Nur autoritative Sim-Parameter.
## Kamera, Zoom, Sichtbarkeit und Speed sind bewusst NICHT enthalten.

const SCHEMA_VERSION: int = 1
const GAME_VERSION: int = 1

const TICKS_PER_DAY: int = 86400
const MINUTES_PER_DAY: int = 1440
const MAP_SIZE: int = 128
const TILE_METERS: float = 1.5
const PIXELS_PER_TILE: int = 16
const REAL_SECONDS_PER_DAY_AT_1X: int = 900

const DEFAULT_SEED: int = 1337
const DEFAULT_START_TIME: int = 6 * 3600
const WALK_SPEED_TILES_PER_S: float = 0.8
const START_GRAIN: int = 60
const MEAL_GRAIN_COST: int = 1
const GRAIN_PER_FIELD_HOUR: int = 1
const MEAL_DURATION_S: int = 1800
const SOCIAL_DURATION_S: int = 3600
const NAP_TARGET_ENERGY: float = 50.0
const SHORTAGE_RETRY_S: int = 7200
const ROUTINE_LOOKAHEAD_S: int = 3600
const SLEEP_LOOKAHEAD_S: int = 7200
const MIN_WAKE_S: int = 1

var seed: int = DEFAULT_SEED
var start_time: int = DEFAULT_START_TIME

# Need-Startwerte (G1-Spec §5; G1a nutzt Hunger/Energie/Sozial).
var start_hunger: float = 80.0
var start_energy: float = 80.0
var start_social: float = 70.0

# Raten pro Sim-Tag bzw. Wach-/Schlafenszeit (G1-Spec §5).
# G1a.1-Kalibrierung: 60 statt 100 pro 16 h. Start 80 und Schwelle 20 ergeben
# den Schwellenwert damit erst nach 16 h (22:00), also nach der Routine-
# Schlafenszeit (20:30/21:00). Kein Nachmittags-Nap verdrängt das Abendessen.
var hunger_per_day: float = 100.0
var energy_per_16h_awake: float = 60.0
var energy_per_8h_sleep: float = 80.0
var social_per_day: float = 50.0

var hunger_threshold: float = 60.0
var energy_threshold: float = 20.0
var social_threshold: float = 40.0
var meal_hunger_reduction: float = 50.0
var social_gain: float = 30.0

var walk_speed: float = WALK_SPEED_TILES_PER_S
var start_grain: int = START_GRAIN


func config_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, SCHEMA_VERSION)
	h = HashUtil.mix_i64(h, seed)
	h = HashUtil.mix_i64(h, start_time)
	h = HashUtil.mix_f64(h, start_hunger)
	h = HashUtil.mix_f64(h, start_energy)
	h = HashUtil.mix_f64(h, start_social)
	h = HashUtil.mix_f64(h, hunger_per_day)
	h = HashUtil.mix_f64(h, energy_per_16h_awake)
	h = HashUtil.mix_f64(h, energy_per_8h_sleep)
	h = HashUtil.mix_f64(h, social_per_day)
	h = HashUtil.mix_f64(h, hunger_threshold)
	h = HashUtil.mix_f64(h, energy_threshold)
	h = HashUtil.mix_f64(h, social_threshold)
	h = HashUtil.mix_f64(h, meal_hunger_reduction)
	h = HashUtil.mix_f64(h, social_gain)
	h = HashUtil.mix_f64(h, walk_speed)
	h = HashUtil.mix_i64(h, start_grain)
	return h
