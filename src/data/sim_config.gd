class_name SimConfig
extends RefCounted

## G1b/G2/G3-Konfiguration. Nur autoritative Sim-Parameter.
## Kamera, Zoom, Sichtbarkeit und Speed sind bewusst NICHT enthalten.
##
## Historische Profile G1/G2 bleiben beim 30-Tage-Jahr, beim ganzjährigen
## Feldzyklus und beim Save-Schema 5. G3 ist ein eigenes Profil mit
## 120-Tage-Jahr, 4x30-Tage-Seasons, saisonalen Feldern und Save-Schema 6.

const SCHEMA_VERSION: int = 5
const GAME_VERSION: int = 5
const G3_SCHEMA_VERSION: int = 6
const G3_GAME_VERSION: int = 6

const TICKS_PER_DAY: int = 86400
const MINUTES_PER_DAY: int = 1440
const YEAR_DAYS: int = 30
const SEASON_DAYS: int = 30
const SEASONS: int = 4
const MAP_SIZE: int = 128
const MAP_SIZE_G2: int = 384
const MAP_SIZE_G3: int = 768

## G1-Weltprofil (10 Agenten, 128x128) bleibt der unveränderte G1-Default.
## G2 nutzt explizit SimConfig.g2(): 384x384, 100 Agenten, 20-25 Haushalte.
## G3 nutzt SimConfig.g3(): 768x768, 1000 Agenten, 200-250 Haushalte.
const PROFILE_G1: int = 0
const PROFILE_G2: int = 1
const PROFILE_G3: int = 2
const G2_TARGET_AGENTS: int = 100
const G2_TARGET_HOUSEHOLDS: int = 24
const G3_TARGET_AGENTS: int = 1000
const G3_TARGET_HOUSEHOLDS: int = 225
const G3_FIELD_COUNT: int = 40
const G3_YEAR_DAYS: int = 120
const G3_SEASON_DAYS: int = 30

const TILE_METERS: float = 1.5
const PIXELS_PER_TILE: int = 16
const REAL_SECONDS_PER_DAY_AT_1X: int = 900

const DEFAULT_SEED: int = 1337
const DEFAULT_START_TIME: int = 6 * 3600
const WALK_SPEED_TILES_PER_S: float = 0.8
# G1b-Schritt 2: 60 -> 120. Die Anfangsknappheit bleibt sichtbar, wird aber
# kürzer; die 260 Skips aus Schritt 1 sind damit adressiert, ohne still
# aufzufüllen.
const START_GRAIN: int = 120
const MEAL_GRAIN_COST: int = 1
const MEAL_DURATION_S: int = 1800
const SOCIAL_DURATION_S: int = 3600
const HYGIENE_DURATION_S: int = 900
const FUN_DURATION_S: int = 3600
const NAP_TARGET_ENERGY: float = 50.0
const SHORTAGE_RETRY_S: int = 7200
const ROUTINE_LOOKAHEAD_S: int = 3600
const SLEEP_LOOKAHEAD_S: int = 7200
const MIN_WAKE_S: int = 1

# Voller Feldzyklus (G1b): Arbeit ist Fortschritt, Wachstum ist Kalenderzeit.
const FIELD_PLOW_WORK_S: int = 20 * 3600
const FIELD_SOW_WORK_S: int = 8 * 3600
const FIELD_HARVEST_WORK_S: int = 16 * 3600
const FIELD_GROW_S: int = 4 * 86400
const FIELD_HARVEST_YIELD: int = 220

# G3-Platzhalter-Balance aus der G3-Spec. Keine finale Wirtschaft.
const G3_FIELD_GROSS_YIELD: int = 10000
const G3_FIELD_SEED_COST: int = 1000
const G3_START_GRAIN: int = 360000
const G3_GRANARY_CAPACITY: int = 720000

var seed: int = DEFAULT_SEED
var start_time: int = DEFAULT_START_TIME

# Welt-/Bevölkerungsprofil. G1-Default bleibt bitgleich zum bestandenen G1.
var profile: int = PROFILE_G1
var world_size: int = MAP_SIZE
var target_agents: int = 10
var target_households: int = 3

# Kalender-/Feldprofil. G1/G2: 30-Tage-Jahr, ganzjähriger G1b-Feldzyklus.
# G3: 120 Tage, 4x30 Seasons, eine Ernte/Feld/Jahr.
var year_days: int = YEAR_DAYS
var season_days: int = SEASON_DAYS
var seasonal_fields: bool = false
var field_seed_cost: int = 0
var granary_capacity: int = 0

# G2-Pfadbudget. Die Budgets beeinflussen, wann ein Pfad vertagt wird, sind
# damit autoritativ und Teil des Config-Hashs. Der Cache selbst ist abgeleitet.
var path_cache_capacity: int = 512
var path_recalc_budget: int = 2
var path_lookup_budget: int = 50
var path_frame_ticks: int = 80
var map_version: int = 1

# Need-Startwerte (G1-Spec §5). Gesundheit ist ein langsamer Zustand.
var start_hunger: float = 80.0
var start_energy: float = 80.0
var start_social: float = 70.0
var start_hygiene: float = 80.0
var start_fun: float = 70.0
var start_health: float = 100.0

# Raten pro Sim-Tag bzw. Wach-/Schlafenszeit (G1-Spec §5).
# G1a.1-Kalibrierung: 60 statt 100 pro 16 h. Start 80 und Schwelle 20 ergeben
# den Schwellenwert damit erst nach 16 h (22:00), also nach der Routine-
# Schlafenszeit (20:30/21:00). Kein Nachmittags-Nap verdrängt das Abendessen.
var hunger_per_day: float = 100.0
var energy_per_16h_awake: float = 60.0
var energy_per_8h_sleep: float = 80.0
var social_per_day: float = 50.0
var hygiene_per_day: float = 60.0
var fun_per_day: float = 40.0

var hunger_threshold: float = 60.0
var energy_threshold: float = 20.0
var social_threshold: float = 40.0
var hygiene_threshold: float = 50.0
var fun_threshold: float = 40.0
var meal_hunger_reduction: float = 50.0
var social_gain: float = 30.0
var wash_gain: float = 50.0
var fun_gain: float = 30.0
var social_fun_gain: float = 10.0

# Gesundheit: langsam, ohne Krankheit/Gewalt. G1b-Schritt 2 kalibriert die
# Folgen: schlechte Needs senken schneller, Erholung ist langsamer, Alter
# wirkt stärker. Schwere Gesundheit (<= Schwelle) erhöht das Sterberisiko.
var health_bad_per_day: float = 15.0
var health_recovery_per_day: float = 2.5
var health_old_per_year: float = 8.0
var health_critical_threshold: float = 10.0
var health_critical_monthly_chance: float = 0.15
var health_multiplier_curve: float = 4.0

# Lebenszyklus (G1b-Schritt 2). Alle Werte sind autoritativ und im Save.
# Ein G1b-Monat ist ein fester Roll-Intervall von 5 Sim-Tagen (6/Jahr). Die
# erste Prüfung liegt an Tag 10, damit die exakten G1a-Tag-0..6-Abnahmen
# unverändert bleiben; ab Tag 10 gilt der reguläre 5-Tage-Rhythmus.
var lifecycle_first_roll_day: int = 10
var lifecycle_roll_interval_days: int = 5
var lifecycle_rolls_per_year: int = 6

# Kalibrierte Sterblichkeit pro Sim-Jahr (ersetzt die provisorische
# G1-Spec-Tabelle; siehe docs/g1b/v3-g1b-step2-report.md).
var mortality_age_0_4: float = 0.010
var mortality_age_5_14: float = 0.002
var mortality_age_15_29: float = 0.005
var mortality_age_30_39: float = 0.015
var mortality_age_40_49: float = 0.035
var mortality_age_50_64: float = 0.044
var mortality_age_65_79: float = 0.080
var mortality_age_80_plus: float = 0.150

# Partnerschaft/Fertilität. Nur lebende, unverpartnerte Erwachsene 18..59
# werden gepaart; bestehende lebende Partner bleiben. Fruchtbarkeit ist ein
# binäres Altersfenster, die Monatswahrscheinlichkeit ist flach.
var pair_min_age: int = 18
var pair_max_age: int = 59
var fertile_female_min: int = 18
var fertile_female_max: int = 40
var fertile_male_min: int = 18
var fertile_male_max: int = 55
var monthly_conception_chance: float = 0.20
var pregnancy_ticks: int = 2
var birth_death_chance: float = 0.005

var walk_speed: float = WALK_SPEED_TILES_PER_S
var start_grain: int = START_GRAIN
var field_plow_work_s: int = FIELD_PLOW_WORK_S
var field_sow_work_s: int = FIELD_SOW_WORK_S
var field_harvest_work_s: int = FIELD_HARVEST_WORK_S
var field_grow_s: int = FIELD_GROW_S
var field_harvest_yield: int = FIELD_HARVEST_YIELD

# G1b-Schritt 3: Chronik-/Retention-Budgets. Reine Darstellungs-/Speicher-
# entscheidungen; sie beeinflussen weder Need- noch Lebenszyklusentscheidungen.
# Die Byte-Budgets aus docs/v3-chronicle.md werden über die Anzahl-Reports
# in ChronicleStore.budget_info() ausgewiesen.
var chronicle_recent_days: int = 7
var chronicle_recent_max_events: int = 250000
var chronicle_summary_days: int = 30
var chronicle_summary_max: int = 50000
var chronicle_historic_max: int = 10000
var chronicle_story_max_per_day: int = 7
var chronicle_alert_max_per_day: int = 20


## G2-Profil: gleiche G1b-Regeln, größere Welt/Bevölkerung. Nur die
## Grain-Kalibrierung skaliert mit der 100er-Bevölkerung (4 Felder statt 1).
static func g2(seed_value: int = DEFAULT_SEED) -> SimConfig:
	var c: SimConfig = SimConfig.new()
	c.seed = seed_value
	c.profile = PROFILE_G2
	c.world_size = MAP_SIZE_G2
	c.target_agents = G2_TARGET_AGENTS
	c.target_households = G2_TARGET_HOUSEHOLDS
	c.start_grain = 1200
	c.field_harvest_yield = 600
	c.path_cache_capacity = 2048
	c.path_recalc_budget = 2
	c.path_lookup_budget = 50
	c.path_frame_ticks = 80
	c.map_version = 1
	return c


## G3-Profil: 1000 Agenten, 225 Haushalte, 40 Felder, 120-Tage-Jahr mit
## 4x30-Tage-Seasons. Der Lebenszyklus behält 6 Rollen/Jahr; das Intervall
## wird auf 20 Tage gestreckt, damit Jahressterblichkeit/-fertilität und
## RNG-Konsum pro Jahr mit G1b vergleichbar bleiben.
static func g3(seed_value: int = DEFAULT_SEED) -> SimConfig:
	var c: SimConfig = SimConfig.new()
	c.seed = seed_value
	c.profile = PROFILE_G3
	c.world_size = MAP_SIZE_G3
	c.target_agents = G3_TARGET_AGENTS
	c.target_households = G3_TARGET_HOUSEHOLDS
	c.year_days = G3_YEAR_DAYS
	c.season_days = G3_SEASON_DAYS
	c.seasonal_fields = true
	c.start_grain = G3_START_GRAIN
	c.granary_capacity = G3_GRANARY_CAPACITY
	c.field_harvest_yield = G3_FIELD_GROSS_YIELD
	c.field_seed_cost = G3_FIELD_SEED_COST
	c.field_plow_work_s = FIELD_PLOW_WORK_S
	c.field_sow_work_s = FIELD_SOW_WORK_S
	c.field_harvest_work_s = FIELD_HARVEST_WORK_S
	c.path_cache_capacity = 16384
	c.path_recalc_budget = 2
	c.path_lookup_budget = 50
	c.path_frame_ticks = 80
	c.map_version = 1
	c.lifecycle_first_roll_day = 10
	c.lifecycle_roll_interval_days = 20
	c.lifecycle_rolls_per_year = 6
	c.chronicle_summary_days = G3_YEAR_DAYS
	c.chronicle_summary_max = 50000
	return c


func is_g3() -> bool:
	return profile == PROFILE_G3


func save_schema_version() -> int:
	return G3_SCHEMA_VERSION if is_g3() else SCHEMA_VERSION


func game_version_for_save() -> int:
	return G3_GAME_VERSION if is_g3() else GAME_VERSION


## 0-basierter Tag innerhalb des Jahres.
func day_of_year(day: int) -> int:
	var span: int = maxi(1, year_days)
	return day % span


func year_of_day(day: int) -> int:
	return day / maxi(1, year_days)


## Season-Index 0..3. G3 nutzt echte 30-Tage-Seasons; G1/G2 behalten die
## historische 30-Tage-Jahr-Anzeige (4 Viertel im 30-Tage-Jahr).
func season_index_for_day(day: int) -> int:
	if seasonal_fields:
		return (day_of_year(day) / maxi(1, season_days)) % SEASONS
	return (day_of_year(day) * SEASONS) / maxi(1, year_days)


func season_name_for_day(day: int) -> String:
	return ["Frühling", "Sommer", "Herbst", "Winter"][season_index_for_day(day)]


## Absoluter Tagesindex des Season-Starts im Jahr von `day`.
func season_start_day(day: int) -> int:
	var year_start: int = day - day_of_year(day)
	if seasonal_fields:
		return year_start + season_index_for_day(day) * season_days
	return year_start


## Absoluter Tagesindex des Herbststarts im Jahr von `day`.
func autumn_start_day(day: int) -> int:
	var year_start: int = day - day_of_year(day)
	if seasonal_fields:
		return year_start + 2 * season_days
	# G1/G2 haben keinen saisonalen Feldfenster; der bestehende Feldzyklus
	# nutzt diesen Wert nicht.
	return year_start + int(round(float(year_days) * 0.5))


func next_year_start_day(day: int) -> int:
	return day - day_of_year(day) + maxi(1, year_days)


func is_spring_day(day: int) -> bool:
	return seasonal_fields and season_index_for_day(day) == 0


func is_autumn_day(day: int) -> bool:
	return seasonal_fields and season_index_for_day(day) == 2


func config_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, SCHEMA_VERSION)
	h = HashUtil.mix(h, YEAR_DAYS)
	h = HashUtil.mix(h, SEASONS)
	h = HashUtil.mix_i64(h, seed)
	h = HashUtil.mix_i64(h, start_time)
	h = HashUtil.mix(h, profile)
	h = HashUtil.mix(h, world_size)
	h = HashUtil.mix(h, target_agents)
	h = HashUtil.mix(h, target_households)
	h = HashUtil.mix(h, year_days)
	h = HashUtil.mix(h, season_days)
	h = HashUtil.mix(h, 1 if seasonal_fields else 0)
	h = HashUtil.mix_i64(h, field_seed_cost)
	h = HashUtil.mix_i64(h, granary_capacity)
	h = HashUtil.mix(h, path_cache_capacity)
	h = HashUtil.mix(h, path_recalc_budget)
	h = HashUtil.mix(h, path_lookup_budget)
	h = HashUtil.mix(h, path_frame_ticks)
	h = HashUtil.mix(h, map_version)
	h = HashUtil.mix_f64(h, start_hunger)
	h = HashUtil.mix_f64(h, start_energy)
	h = HashUtil.mix_f64(h, start_social)
	h = HashUtil.mix_f64(h, start_hygiene)
	h = HashUtil.mix_f64(h, start_fun)
	h = HashUtil.mix_f64(h, start_health)
	h = HashUtil.mix_f64(h, hunger_per_day)
	h = HashUtil.mix_f64(h, energy_per_16h_awake)
	h = HashUtil.mix_f64(h, energy_per_8h_sleep)
	h = HashUtil.mix_f64(h, social_per_day)
	h = HashUtil.mix_f64(h, hygiene_per_day)
	h = HashUtil.mix_f64(h, fun_per_day)
	h = HashUtil.mix_f64(h, hunger_threshold)
	h = HashUtil.mix_f64(h, energy_threshold)
	h = HashUtil.mix_f64(h, social_threshold)
	h = HashUtil.mix_f64(h, hygiene_threshold)
	h = HashUtil.mix_f64(h, fun_threshold)
	h = HashUtil.mix_f64(h, meal_hunger_reduction)
	h = HashUtil.mix_f64(h, social_gain)
	h = HashUtil.mix_f64(h, wash_gain)
	h = HashUtil.mix_f64(h, fun_gain)
	h = HashUtil.mix_f64(h, social_fun_gain)
	h = HashUtil.mix_f64(h, health_bad_per_day)
	h = HashUtil.mix_f64(h, health_recovery_per_day)
	h = HashUtil.mix_f64(h, health_old_per_year)
	h = HashUtil.mix_f64(h, health_critical_threshold)
	h = HashUtil.mix_f64(h, health_critical_monthly_chance)
	h = HashUtil.mix_f64(h, health_multiplier_curve)
	h = HashUtil.mix_i64(h, lifecycle_first_roll_day)
	h = HashUtil.mix_i64(h, lifecycle_roll_interval_days)
	h = HashUtil.mix_i64(h, lifecycle_rolls_per_year)
	h = HashUtil.mix_f64(h, mortality_age_0_4)
	h = HashUtil.mix_f64(h, mortality_age_5_14)
	h = HashUtil.mix_f64(h, mortality_age_15_29)
	h = HashUtil.mix_f64(h, mortality_age_30_39)
	h = HashUtil.mix_f64(h, mortality_age_40_49)
	h = HashUtil.mix_f64(h, mortality_age_50_64)
	h = HashUtil.mix_f64(h, mortality_age_65_79)
	h = HashUtil.mix_f64(h, mortality_age_80_plus)
	h = HashUtil.mix_i64(h, pair_min_age)
	h = HashUtil.mix_i64(h, pair_max_age)
	h = HashUtil.mix_i64(h, fertile_female_min)
	h = HashUtil.mix_i64(h, fertile_female_max)
	h = HashUtil.mix_i64(h, fertile_male_min)
	h = HashUtil.mix_i64(h, fertile_male_max)
	h = HashUtil.mix_f64(h, monthly_conception_chance)
	h = HashUtil.mix_i64(h, pregnancy_ticks)
	h = HashUtil.mix_f64(h, birth_death_chance)
	h = HashUtil.mix_f64(h, walk_speed)
	h = HashUtil.mix_i64(h, start_grain)
	h = HashUtil.mix_i64(h, field_plow_work_s)
	h = HashUtil.mix_i64(h, field_sow_work_s)
	h = HashUtil.mix_i64(h, field_harvest_work_s)
	h = HashUtil.mix_i64(h, field_grow_s)
	h = HashUtil.mix_i64(h, field_harvest_yield)
	h = HashUtil.mix_i64(h, chronicle_recent_days)
	h = HashUtil.mix_i64(h, chronicle_recent_max_events)
	h = HashUtil.mix_i64(h, chronicle_summary_days)
	h = HashUtil.mix_i64(h, chronicle_summary_max)
	h = HashUtil.mix_i64(h, chronicle_historic_max)
	h = HashUtil.mix_i64(h, chronicle_story_max_per_day)
	h = HashUtil.mix_i64(h, chronicle_alert_max_per_day)
	return h
