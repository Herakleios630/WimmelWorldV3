class_name LifecycleRules
extends RefCounted

## Reine, deterministische Lebenszyklus-/Fertilitätsregeln.
##
## Dieses Modul enthält KEINE Simulationsobjekte und keinen versteckten
## Balance-Satz. Hauptsimulation und die synthetische Demografie-Kohorte rufen
## exakt dieselben Funktionen und dieselben SimConfig-Parameter auf.

const CAUSE_NONE: int = 0
const CAUSE_AGE: int = 1
const CAUSE_HEALTH: int = 2
const CAUSE_BIRTH: int = 3

const REASON_LAST_ADULT: int = 0

const SEX_MALE: int = 0
const SEX_FEMALE: int = 1

const MALE_NAMES: Array = [
	"Anselm", "Bernd", "Caspar", "Dietrich", "Emil", "Friedrich",
	"Gerhard", "Heinrich", "Jakob", "Konrad", "Lorenz", "Matthias",
	"Nikolaus", "Otto", "Peter", "Reinhard", "Simon", "Thomas",
	"Ulrich", "Valentin", "Wendel", "Wilhelm",
]

const FEMALE_NAMES: Array = [
	"Adelheid", "Anna", "Beatrix", "Clara", "Dorothea", "Elisabeth",
	"Frida", "Gertrud", "Hedwig", "Ida", "Johanna", "Katharina",
	"Lena", "Magdalena", "Nora", "Ottilie", "Rosa", "Sophia",
	"Theresa", "Ursula", "Verena", "Wilhelmina",
]


static func role_for_age(age: int) -> int:
	if age < 0:
		return AgentStore.ROLE_CHILD
	if age <= 12:
		return AgentStore.ROLE_CHILD
	if age <= 17:
		return AgentStore.ROLE_YOUTH
	if age <= 59:
		return AgentStore.ROLE_ADULT
	return AgentStore.ROLE_OLD


static func is_minor(age: int) -> bool:
	return age < 18


static func is_guardian(age: int) -> bool:
	return age >= 18


static func age_from_birth_day(birth_day: int, day: int) -> int:
	var elapsed: int = day - birth_day
	if elapsed < 0:
		return 0
	return elapsed / SimConfig.YEAR_DAYS


static func birth_day_for_age(age: int, day: int) -> int:
	return day - age * SimConfig.YEAR_DAYS


static func annual_death_rate(config: SimConfig, age: int) -> float:
	if age < 5:
		return config.mortality_age_0_4
	if age < 15:
		return config.mortality_age_5_14
	if age < 30:
		return config.mortality_age_15_29
	if age < 40:
		return config.mortality_age_30_39
	if age < 50:
		return config.mortality_age_40_49
	if age < 65:
		return config.mortality_age_50_64
	if age < 80:
		return config.mortality_age_65_79
	return config.mortality_age_80_plus


## Gesundheit multipliziert das Altersrisiko. 100 Gesundheit = 1.0,
## 0 Gesundheit = 1 + health_multiplier_curve (Default 5.0).
static func health_multiplier(config: SimConfig, health: float) -> float:
	var deficit: float = clampf((100.0 - health) / 100.0, 0.0, 1.0)
	return 1.0 + config.health_multiplier_curve * deficit * deficit


## Monatliche Todeswahrscheinlichkeit aus der Jahresrate. Der Roll-Rhythmus
## ist lifecycle_rolls_per_year (6 Rollen pro 30-Tage-Jahr).
static func monthly_death_chance(config: SimConfig, age: int, health: float) -> float:
	var annual: float = annual_death_rate(config, age) * health_multiplier(config, health)
	annual = clampf(annual, 0.0, 1.0)
	var per_roll: float = 1.0 - pow(1.0 - annual, 1.0 / float(maxi(1, config.lifecycle_rolls_per_year)))
	if health <= config.health_critical_threshold:
		per_roll = maxf(per_roll, config.health_critical_monthly_chance)
	return clampf(per_roll, 0.0, 1.0)


static func death_cause(config: SimConfig, age: int, health: float) -> int:
	if health <= config.health_critical_threshold:
		return CAUSE_HEALTH
	return CAUSE_AGE


static func is_fertile_female(config: SimConfig, age: int) -> bool:
	return age >= config.fertile_female_min and age <= config.fertile_female_max


static func is_fertile_male(config: SimConfig, age: int) -> bool:
	return age >= config.fertile_male_min and age <= config.fertile_male_max


static func can_pair(config: SimConfig, age_a: int, sex_a: int, age_b: int,
		sex_b: int) -> bool:
	if sex_a == sex_b:
		return false
	if age_a < config.pair_min_age or age_a > config.pair_max_age:
		return false
	if age_b < config.pair_min_age or age_b > config.pair_max_age:
		return false
	return true


static func monthly_conception_chance(config: SimConfig, mother_age: int) -> float:
	if mother_age < config.fertile_female_min or mother_age > config.fertile_female_max:
		return 0.0
	return clampf(config.monthly_conception_chance, 0.0, 1.0)


static func cause_name(cause: int) -> String:
	match cause:
		CAUSE_AGE: return "Alter"
		CAUSE_HEALTH: return "schwere Gesundheit"
		CAUSE_BIRTH: return "Geburt"
	return "unbekannt"


static func name_for(sex: int, agent_id: int) -> String:
	var names: Array = FEMALE_NAMES if sex == SEX_FEMALE else MALE_NAMES
	return str(names[agent_id % names.size()])


static func sex_name(sex: int) -> String:
	return "weiblich" if sex == SEX_FEMALE else "männlich"
