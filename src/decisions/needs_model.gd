class_name NeedsModel
extends RefCounted

## G1b-Needs: Hunger, Energie, Sozial, Hygiene, Spaß plus Gesundheit.
##
## Semantik:
## - Hunger ist ein Antrieb (0 = satt, 100 = sehr hungrig), steigt.
## - Energie/Sozial/Hygiene/Spaß sind Vorräte (100 = gut), fallen.
## - Gesundheit ist ein langsamer Zustand (0-100): sinkt bei Hunger/Energie/
##   Hygiene unter Schwelle und altersbedingt, erholt sich bei guten Needs.
## - Keine Krankheit, keine Gewalt, kein Tod in G1b-Schritt 1.
## - Needs werden nur zu logischen Terminen materialisiert. Anzeige nutzt
##   value_at() und schreibt nichts.

const NEED_HUNGER: int = 0
const NEED_ENERGY: int = 1
const NEED_SOCIAL: int = 2
const NEED_HYGIENE: int = 3
const NEED_FUN: int = 4
const NEED_HEALTH: int = 5
const NEED_COUNT: int = 6

const OLD_AGE: int = 60

## Raten/Schwellen liegen autoritativ in SimConfig (versioniert/serialisiert).


static func clamp_need(value: float) -> float:
	if value < 0.0:
		return 0.0
	if value > 100.0:
		return 100.0
	return value


static func hunger_rate(config: SimConfig) -> float:
	return config.hunger_rate_s


static func energy_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return config.energy_sleep_rate_s
	return config.energy_awake_rate_s


static func social_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return 0.0
	var rate: float = config.social_rate_s
	# Niedriger Spaß senkt die Stimmung und beschleunigt den Sozialverlust.
	if store.fun[row] <= config.fun_threshold:
		rate *= 1.5
	return rate


static func hygiene_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	return config.hygiene_rate_s


static func fun_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return 0.0
	return config.fun_rate_s


## Gesundheit reagiert auf den Zustand vor dem Settle-Intervall. Das ist eine
## bewusst einfache, deterministische Stückweise-Integration.
static func health_is_bad(store: AgentStore, row: int, config: SimConfig) -> bool:
	return store.hunger[row] >= config.hunger_threshold \
		or store.energy[row] <= config.energy_threshold \
		or store.hygiene[row] <= config.hygiene_threshold


static func health_is_good(store: AgentStore, row: int, config: SimConfig) -> bool:
	return store.hunger[row] < config.hunger_threshold * 0.6 \
		and store.energy[row] > config.energy_threshold * 1.5 \
		and store.hygiene[row] > config.hygiene_threshold \
		and store.social[row] > config.social_threshold \
		and store.fun[row] > config.fun_threshold


static func health_rate(store: AgentStore, row: int, config: SimConfig,
		bad: bool, good: bool) -> float:
	var age_rate: float = 0.0
	if store.age_years[row] >= OLD_AGE:
		age_rate = config.health_old_rate_s
	if bad:
		return config.health_bad_rate_s + age_rate
	if good:
		return config.health_good_rate_s + age_rate
	return age_rate


## Materialisiert Needs bis now. Idempotent für now <= need_time.
static func settle(store: AgentStore, row: int, now: int, config: SimConfig) -> void:
	var last: int = store.need_time[row]
	if now <= last:
		return
	var dt: float = float(now - last)
	# Inline-Version der G1b-Formeln mit vorberechneten Sekundenraten. Die
	# Semantik ist identisch zu health_rate()/energy_rate() usw., spart aber
	# bei 10k mehrere statische Aufrufe und Config-Divisionen pro Wake.
	var hunger: float = store.hunger[row]
	var energy: float = store.energy[row]
	var social: float = store.social[row]
	var hygiene: float = store.hygiene[row]
	var fun: float = store.fun[row]
	var bad: bool = hunger >= config.hunger_threshold \
		or energy <= config.energy_threshold \
		or hygiene <= config.hygiene_threshold
	var good: bool = hunger < config.hunger_threshold * 0.6 \
		and energy > config.energy_threshold * 1.5 \
		and hygiene > config.hygiene_threshold \
		and social > config.social_threshold \
		and fun > config.fun_threshold
	var sleeping: bool = store.activity[row] == AgentStore.ACT_SLEEP
	var er: float = config.energy_sleep_rate_s if sleeping \
		else config.energy_awake_rate_s
	var sr: float = 0.0
	if not sleeping:
		sr = config.social_rate_s
		if fun <= config.fun_threshold:
			sr *= 1.5
	var fr: float = 0.0 if sleeping else config.fun_rate_s
	var health_r: float = 0.0
	if store.age_years[row] >= OLD_AGE:
		health_r = config.health_old_rate_s
	if bad:
		health_r += config.health_bad_rate_s
	elif good:
		health_r += config.health_good_rate_s
	store.hunger[row] = clampf(hunger + config.hunger_rate_s * dt, 0.0, 100.0)
	store.energy[row] = clampf(energy + er * dt, 0.0, 100.0)
	store.social[row] = clampf(social + sr * dt, 0.0, 100.0)
	store.hygiene[row] = clampf(hygiene + config.hygiene_rate_s * dt, 0.0, 100.0)
	store.fun[row] = clampf(fun + fr * dt, 0.0, 100.0)
	store.health[row] = clampf(store.health[row] + health_r * dt, 0.0, 100.0)
	store.need_time[row] = now


## Anzeige-/Read-only-Wert zur Zeit now; mutiert nichts.
static func value_at(store: AgentStore, row: int, now: int, need: int,
		config: SimConfig) -> float:
	var dt: float = float(maxi(0, now - store.need_time[row]))
	match need:
		NEED_HUNGER:
			return clamp_need(store.hunger[row] + hunger_rate(config) * dt)
		NEED_ENERGY:
			return clamp_need(store.energy[row] + energy_rate(store, row, config) * dt)
		NEED_SOCIAL:
			return clamp_need(store.social[row] + social_rate(store, row, config) * dt)
		NEED_HYGIENE:
			return clamp_need(store.hygiene[row] + hygiene_rate(store, row, config) * dt)
		NEED_FUN:
			return clamp_need(store.fun[row] + fun_rate(store, row, config) * dt)
		NEED_HEALTH:
			return store.health[row]
	return 0.0


## Sekunden bis zum nächsten Schwellenwake; -1 = kein Wake (z. B. Schlaf).
static func seconds_to_threshold(store: AgentStore, row: int, now: int,
		need: int, config: SimConfig) -> int:
	var value: float = value_at(store, row, now, need, config)
	match need:
		NEED_HUNGER:
			if value >= config.hunger_threshold:
				return 0
			return int(ceil((config.hunger_threshold - value) / hunger_rate(config)))
		NEED_ENERGY:
			if store.activity[row] == AgentStore.ACT_SLEEP:
				return -1
			if value <= config.energy_threshold:
				return 0
			return int(ceil((value - config.energy_threshold) / (-energy_rate(store, row, config))))
		NEED_SOCIAL:
			if store.activity[row] == AgentStore.ACT_SLEEP:
				return -1
			if value <= config.social_threshold:
				return 0
			return int(ceil((value - config.social_threshold) / (-social_rate(store, row, config))))
		NEED_HYGIENE:
			if value <= config.hygiene_threshold:
				return 0
			return int(ceil((value - config.hygiene_threshold) / (-hygiene_rate(store, row, config))))
		NEED_FUN:
			if store.activity[row] == AgentStore.ACT_SLEEP:
				return -1
			if value <= config.fun_threshold:
				return 0
			return int(ceil((value - config.fun_threshold) / (-fun_rate(store, row, config))))
	return -1


static func apply_meal(store: AgentStore, row: int, config: SimConfig) -> void:
	store.hunger[row] = clamp_need(store.hunger[row] - config.meal_hunger_reduction)


static func apply_social(store: AgentStore, row: int, config: SimConfig) -> void:
	store.social[row] = clamp_need(store.social[row] + config.social_gain)
	store.fun[row] = clamp_need(store.fun[row] + config.social_fun_gain)


static func apply_hygiene(store: AgentStore, row: int, config: SimConfig) -> void:
	store.hygiene[row] = clamp_need(store.hygiene[row] + config.wash_gain)


static func apply_fun(store: AgentStore, row: int, config: SimConfig) -> void:
	store.fun[row] = clamp_need(store.fun[row] + config.fun_gain)


static func need_name(need: int) -> String:
	match need:
		NEED_HUNGER: return "Hunger"
		NEED_ENERGY: return "Energie"
		NEED_SOCIAL: return "Sozial"
		NEED_HYGIENE: return "Hygiene"
		NEED_FUN: return "Spaß"
		NEED_HEALTH: return "Gesundheit"
	return "?"
