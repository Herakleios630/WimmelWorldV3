class_name BConfig
extends RefCounted

## Configuration for the deterministic B tiering spike (100k @ 150x/200x).
##
## Speed is B's own time-compression factor relative to the V3 base of 900
## wall-seconds per Sim day at 1x:
##   150x -> 6.0 s per Sim day -> 240 Sim seconds per 60 Hz frame
##   200x -> 4.5 s per Sim day -> 320 Sim seconds per 60 Hz frame
##
## Camera, zoom, visibility, follow and inspector are deliberately absent.

const SCHEMA_VERSION: int = 1
const DEFAULT_SEED: int = 1337
const TICKS_PER_DAY: int = 86400
const YEAR_DAYS: int = 30
const BASE_SECONDS_PER_DAY_AT_1X: float = 900.0
const FPS: int = 60

const DEFAULT_POPULATION: int = 100000
const DEFAULT_SETTLEMENTS: int = 200
const COHORTS_PER_SETTLEMENT: int = 14
const AGE_BANDS: Array = [
	Vector2i(0, 4),
	Vector2i(5, 14),
	Vector2i(15, 29),
	Vector2i(30, 44),
	Vector2i(45, 59),
	Vector2i(60, 74),
	Vector2i(75, 120),
]
const BAND_WEIGHTS: Array = [8, 14, 22, 25, 18, 9, 4]

const DETAIL_TARGETS: Array = [1000, 5000]
const SPEEDS: Array = [150, 200]

const ACTIVITY_IDLE: int = 0
const ACTIVITY_TRAVEL: int = 1
const ACTIVITY_WORK: int = 2
const ACTIVITY_EAT: int = 3
const ACTIVITY_SLEEP: int = 4
const ACTIVITY_SOCIAL: int = 5
const ACTIVITY_HYGIENE: int = 6
const ACTIVITY_LEISURE: int = 7

const JOB_NONE: int = 0
const JOB_FIELD: int = 1
const JOB_WORKSHOP: int = 2
const JOB_SERVICE: int = 3

const ROLE_CHILD: int = 0
const ROLE_YOUTH: int = 1
const ROLE_ADULT: int = 2
const ROLE_OLD: int = 3

var seed: int = DEFAULT_SEED
var start_time: int = 0
var population: int = DEFAULT_POPULATION
var settlement_count: int = DEFAULT_SETTLEMENTS
var cohorts_per_settlement: int = COHORTS_PER_SETTLEMENT
var detail_target: int = 1000
var speed: int = 150

# Tier selection cadence/work split. Selection for epoch D+1 is computed in
# 1440 fixed Sim-second slices during day D and committed at midnight D+1.
var selection_cadence_days: int = 1
var selection_events_per_day: int = 1440
var selection_rotation_days: int = 5
var key_priority_days: int = 3

# Background cadence. Deaths/births are daily per settlement; marriages/job
# changes are processed on that settlement's weekly day.
var background_cadence_days: int = 1
var weekly_cadence_days: int = 7

# Background key-event rates (spike placeholders, documented in the report).
var birth_rate_per_female_day: float = 0.0020
var marriage_rate_per_eligible_week: float = 0.05
var job_change_rate_per_worker_week: float = 0.01

# Need/health rates for the detail tier and lazy catch-up. Hunger is a
# high-is-bad need; energy/social/hygiene/fun are high-is-good.
var hunger_per_day: float = 100.0
var energy_per_day: float = 90.0
var social_per_day: float = 50.0
var hygiene_per_day: float = 60.0
var fun_per_day: float = 40.0
var hunger_threshold: float = 60.0
var energy_threshold: float = 20.0
var social_threshold: float = 40.0
var hygiene_threshold: float = 50.0
var fun_threshold: float = 40.0
var health_decay_adult_per_day: float = 0.02
var health_decay_old_per_day: float = 0.15

# Mortality per Sim year for the seven B age bands.
var mortality: PackedFloat64Array = PackedFloat64Array([
	0.010, 0.002, 0.005, 0.025, 0.040, 0.060, 0.150,
])

var selection_salt: int = 0x51ED270B
var background_salt: int = 0x2C1B3C6D
var detail_speed_tiles_per_s: float = 0.8


static func make(p_detail: int, p_speed: int, p_seed: int = DEFAULT_SEED) -> BConfig:
	var c: BConfig = BConfig.new()
	c.detail_target = p_detail
	c.speed = p_speed
	c.seed = p_seed
	return c


func validate() -> Dictionary:
	if population <= 0:
		return {"ok": false, "error": "bad_population"}
	if settlement_count <= 0:
		return {"ok": false, "error": "bad_settlement_count"}
	if population % settlement_count != 0:
		return {"ok": false, "error": "population_not_divisible"}
	if detail_target <= 0 or detail_target >= population:
		return {"ok": false, "error": "bad_detail_target"}
	if speed != 150 and speed != 200:
		return {"ok": false, "error": "bad_speed"}
	if cohorts_per_settlement != AGE_BANDS.size() * 2:
		return {"ok": false, "error": "bad_cohort_count"}
	if selection_events_per_day <= 0 or TICKS_PER_DAY % selection_events_per_day != 0:
		return {"ok": false, "error": "bad_selection_slices"}
	if selection_rotation_days <= 0:
		return {"ok": false, "error": "bad_selection_rotation"}
	return {"ok": true}


func settlement_size() -> int:
	return population / settlement_count


func cohort_count() -> int:
	return settlement_count * cohorts_per_settlement


func seconds_per_sim_day_at_speed() -> float:
	return BASE_SECONDS_PER_DAY_AT_1X / float(speed)


func sim_seconds_per_frame() -> int:
	return int(round(float(TICKS_PER_DAY) / (seconds_per_sim_day_at_speed() * float(FPS))))


func frames_per_sim_day() -> int:
	return int(round(seconds_per_sim_day_at_speed() * float(FPS)))


func rows_per_selection_event() -> int:
	return int(ceil(float(population) / float(selection_events_per_day)))


func config_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, SCHEMA_VERSION)
	h = HashUtil.mix_i64(h, seed)
	h = HashUtil.mix_i64(h, start_time)
	h = HashUtil.mix(h, population)
	h = HashUtil.mix(h, settlement_count)
	h = HashUtil.mix(h, cohorts_per_settlement)
	h = HashUtil.mix(h, detail_target)
	h = HashUtil.mix(h, speed)
	h = HashUtil.mix(h, selection_cadence_days)
	h = HashUtil.mix(h, selection_events_per_day)
	h = HashUtil.mix(h, selection_rotation_days)
	h = HashUtil.mix(h, key_priority_days)
	h = HashUtil.mix(h, background_cadence_days)
	h = HashUtil.mix(h, weekly_cadence_days)
	h = HashUtil.mix_f64(h, birth_rate_per_female_day)
	h = HashUtil.mix_f64(h, marriage_rate_per_eligible_week)
	h = HashUtil.mix_f64(h, job_change_rate_per_worker_week)
	h = HashUtil.mix_f64(h, hunger_per_day)
	h = HashUtil.mix_f64(h, energy_per_day)
	h = HashUtil.mix_f64(h, social_per_day)
	h = HashUtil.mix_f64(h, hygiene_per_day)
	h = HashUtil.mix_f64(h, fun_per_day)
	h = HashUtil.mix_f64(h, hunger_threshold)
	h = HashUtil.mix_f64(h, energy_threshold)
	h = HashUtil.mix_f64(h, social_threshold)
	h = HashUtil.mix_f64(h, hygiene_threshold)
	h = HashUtil.mix_f64(h, fun_threshold)
	h = HashUtil.mix_f64(h, health_decay_adult_per_day)
	h = HashUtil.mix_f64(h, health_decay_old_per_day)
	for rate in mortality:
		h = HashUtil.mix_f64(h, rate)
	h = HashUtil.mix(h, selection_salt)
	h = HashUtil.mix(h, background_salt)
	h = HashUtil.mix_f64(h, detail_speed_tiles_per_s)
	return h
