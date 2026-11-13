extends RefCounted

## Synthetische Demografie-Kohorte fuer G1b-Schritt 2.
##
## Kalibrierungswerkzeug, kein Gameplay-Ersatz. Die Kohorte folgt 1.000
## Startagenten (500 weiblich, 500 maennlich, Alter 0) ueber 100 Sim-Jahre.
## Sterblichkeit, Altersrollen, Partnerschafts-Eignung und Fertilität nutzen
## exakt dieselben LifecycleRules/SimConfig-Funktionen wie die Hauptsimulation.
## Geburten werden mit derselben Monatswahrscheinlichkeit und
## Schwangerschaftsdauer erzeugt und gezaehlt; die Neugeborenen werden in
## dieser reinen Kohorten-Lebenstafel nicht als neue Kohortenmitglieder
## weiterverfolgt. Damit bleibt die Sterbealtersverteilung unverzerrt und es
## gibt keinen separaten versteckten Balance-Satz.

const SEEDS: Array = [1337, 1338, 1339, 1340, 1341]
const DEFAULT_POPULATION: int = 1000
const DEFAULT_YEARS: int = 100

const TARGET_MEDIAN_MIN: float = 48.0
const TARGET_MEDIAN_MAX: float = 52.0
const TARGET_DIE_BEFORE_40_MIN: float = 0.25
const TARGET_DIE_BEFORE_40_MAX: float = 0.35
const TARGET_REACH_70_MIN: float = 0.15
const TARGET_REACH_70_MAX: float = 0.25
const TARGET_REACH_80_MIN: float = 0.05
const TARGET_REACH_80_MAX: float = 0.10


static func lifecycle_stream_for_seed(seed_value: int) -> RngStream:
	return RngStream.new(seed_value * 6364136223846793005
		+ 4 * 1442695040888963407)


static func run_cohort(seed_value: int, config: SimConfig,
		population: int = DEFAULT_POPULATION, years: int = DEFAULT_YEARS) -> Dictionary:
	var rng: RngStream = lifecycle_stream_for_seed(seed_value)
	var n: int = population
	var alive: PackedByteArray = PackedByteArray()
	var sex: PackedByteArray = PackedByteArray()
	var partner: PackedInt32Array = PackedInt32Array()
	var pregnant_due: PackedInt32Array = PackedInt32Array()
	var death_age: PackedInt32Array = PackedInt32Array()
	var reached_70: PackedByteArray = PackedByteArray()
	var reached_80: PackedByteArray = PackedByteArray()
	alive.resize(n)
	sex.resize(n)
	partner.resize(n)
	pregnant_due.resize(n)
	death_age.resize(n)
	reached_70.resize(n)
	reached_80.resize(n)
	for i in n:
		alive[i] = 1
		sex[i] = i % 2
		partner[i] = -1
		pregnant_due[i] = -1
		death_age[i] = -1
	var months: int = years * config.lifecycle_rolls_per_year
	var births: int = 0
	var deaths: int = 0
	var birth_deaths: int = 0
	for m in months:
		var day: int = (m + 1) * config.lifecycle_roll_interval_days
		var age: int = day / SimConfig.YEAR_DAYS
		for i in n:
			if alive[i] == 0:
				continue
			if age >= 70:
				reached_70[i] = 1
			if age >= 80:
				reached_80[i] = 1
		_pair_unpaired(alive, sex, partner, n, age, config)
		# Geburten, die in diesem Monat faellig sind.
		for i in n:
			if alive[i] == 0 or sex[i] != LifecycleRules.SEX_FEMALE:
				continue
			if pregnant_due[i] != m:
				continue
			births += 1
			pregnant_due[i] = -1
			if rng.next_unit() < config.birth_death_chance:
				deaths += 1
				birth_deaths += 1
				alive[i] = 0
				death_age[i] = age
				_unlink_partner(alive, partner, i)
		# Sterblichkeit (nach den fuelligen Geburten, wie in der Hauptsimulation).
		for i in n:
			if alive[i] == 0:
				continue
			var chance: float = LifecycleRules.monthly_death_chance(config, age, 100.0)
			if rng.next_unit() < chance:
				deaths += 1
				alive[i] = 0
				death_age[i] = age
				pregnant_due[i] = -1
				_unlink_partner(alive, partner, i)
		# Empfaengnis nach Partnerschaft/Sterblichkeit.
		for i in n:
			if alive[i] == 0 or sex[i] != LifecycleRules.SEX_FEMALE:
				continue
			if pregnant_due[i] >= 0:
				continue
			if not LifecycleRules.is_fertile_female(config, age):
				continue
			var p: int = partner[i]
			if p < 0 or alive[p] == 0:
				continue
			if not LifecycleRules.is_fertile_male(config, age):
				continue
			var chance2: float = LifecycleRules.monthly_conception_chance(config, age)
			if rng.next_unit() < chance2:
				pregnant_due[i] = m + config.pregnancy_ticks
	var death_ages: PackedInt32Array = PackedInt32Array()
	var died_before_40: int = 0
	var reach_70_count: int = 0
	var reach_80_count: int = 0
	var censored: int = 0
	for i in n:
		if death_age[i] >= 0:
			death_ages.append(death_age[i])
			if death_age[i] < 40:
				died_before_40 += 1
		else:
			censored += 1
		if reached_70[i] != 0:
			reach_70_count += 1
		if reached_80[i] != 0:
			reach_80_count += 1
	return {
		"seed": seed_value,
		"population": n,
		"years": years,
		"births": births,
		"deaths": deaths,
		"birth_deaths": birth_deaths,
		"median_death_age": _median(death_ages),
		"died_before_40": float(died_before_40) / float(n),
		"reached_70": float(reach_70_count) / float(n),
		"reached_80": float(reach_80_count) / float(n),
		"censored": censored,
		"death_ages": death_ages,
	}


static func run_suite(config: SimConfig, seeds: Array = SEEDS) -> Dictionary:
	var cohorts: Array = []
	var all_ages: PackedInt32Array = PackedInt32Array()
	var births: int = 0
	var deaths: int = 0
	var birth_deaths: int = 0
	var died_before_40: int = 0
	var reached_70: int = 0
	var reached_80: int = 0
	var population: int = 0
	for seed_value in seeds:
		var result: Dictionary = run_cohort(seed_value, config)
		cohorts.append(result)
		births += int(result["births"])
		deaths += int(result["deaths"])
		birth_deaths += int(result["birth_deaths"])
		died_before_40 += int(round(float(result["died_before_40"])
			* float(result["population"])))
		reached_70 += int(round(float(result["reached_70"])
			* float(result["population"])))
		reached_80 += int(round(float(result["reached_80"])
			* float(result["population"])))
		population += int(result["population"])
		var ages: PackedInt32Array = result["death_ages"]
		for age in ages:
			all_ages.append(age)
	return {
		"seeds": seeds,
		"cohorts": cohorts,
		"population": population,
		"births": births,
		"deaths": deaths,
		"birth_deaths": birth_deaths,
		"median_death_age": _median(all_ages),
		"died_before_40": float(died_before_40) / float(maxi(1, population)),
		"reached_70": float(reached_70) / float(maxi(1, population)),
		"reached_80": float(reached_80) / float(maxi(1, population)),
	}


static func _pair_unpaired(alive: PackedByteArray, sex: PackedByteArray,
		partner: PackedInt32Array, n: int, age: int, config: SimConfig) -> void:
	if age < config.pair_min_age or age > config.pair_max_age:
		return
	for i in n:
		if alive[i] == 0 or partner[i] >= 0:
			continue
		for j in range(i + 1, n):
			if alive[j] == 0 or partner[j] >= 0:
				continue
			if not LifecycleRules.can_pair(config, age, sex[i], age, sex[j]):
				continue
			partner[i] = j
			partner[j] = i
			break


static func _unlink_partner(alive: PackedByteArray, partner: PackedInt32Array,
		agent_index: int) -> void:
	var p: int = partner[agent_index]
	if p >= 0:
		partner[p] = -1
	partner[agent_index] = -1


static func _median(values: PackedInt32Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedInt32Array = values.duplicate()
	sorted.sort()
	var mid: int = sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[mid])
	return (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5


static func meets_targets(suite: Dictionary) -> bool:
	var median: float = float(suite["median_death_age"])
	return int(suite["births"]) >= 500 \
		and int(suite["deaths"]) >= 500 \
		and median >= TARGET_MEDIAN_MIN and median <= TARGET_MEDIAN_MAX \
		and float(suite["died_before_40"]) >= TARGET_DIE_BEFORE_40_MIN \
		and float(suite["died_before_40"]) <= TARGET_DIE_BEFORE_40_MAX \
		and float(suite["reached_70"]) >= TARGET_REACH_70_MIN \
		and float(suite["reached_70"]) <= TARGET_REACH_70_MAX \
		and float(suite["reached_80"]) >= TARGET_REACH_80_MIN \
		and float(suite["reached_80"]) <= TARGET_REACH_80_MAX


static func summary_line(result: Dictionary) -> String:
	return "seed=%d births=%d deaths=%d birth_deaths=%d median=%.1f before40=%.3f reach70=%.3f reach80=%.3f censored=%d" % [
		int(result["seed"]), int(result["births"]), int(result["deaths"]),
		int(result["birth_deaths"]), float(result["median_death_age"]),
		float(result["died_before_40"]), float(result["reached_70"]),
		float(result["reached_80"]), int(result["censored"])]
