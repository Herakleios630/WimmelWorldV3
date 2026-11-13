class_name NeedsModel
extends RefCounted

## G1a-Needs: Hunger, Energie, Sozial. Hygiene/Spaß/Gesundheit sind G1b.
##
## Semantik:
## - Hunger ist ein Antrieb (0 = satt, 100 = sehr hungrig), steigt.
## - Energie/Sozial sind Vorräte (100 = gut), fallen.
## - Needs werden nur zu logischen Terminen materialisiert. Anzeige nutzt
##   value_at() und schreibt nichts.
## - G1a hat keine Gesundheit: Knappheit verhindert Mahlzeiten, füllt nichts
##   auf und wird geloggt (G1b ergänzt Health-Folgen).

const NEED_HUNGER: int = 0
const NEED_ENERGY: int = 1
const NEED_SOCIAL: int = 2
const NEED_COUNT: int = 3

## Raten/Schwellen liegen autoritativ in SimConfig (versioniert/serialisiert).


static func clamp_need(value: float) -> float:
	if value < 0.0:
		return 0.0
	if value > 100.0:
		return 100.0
	return value


static func hunger_rate(config: SimConfig) -> float:
	return config.hunger_per_day / 86400.0


static func energy_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return config.energy_per_8h_sleep / (8.0 * 3600.0)
	return -config.energy_per_16h_awake / (16.0 * 3600.0)


static func social_rate(store: AgentStore, row: int, config: SimConfig) -> float:
	if store.activity[row] == AgentStore.ACT_SLEEP:
		return 0.0
	return -config.social_per_day / 86400.0


## Materialisiert Needs bis now. Idempotent für now <= need_time.
static func settle(store: AgentStore, row: int, now: int, config: SimConfig) -> void:
	var last: int = store.need_time[row]
	if now <= last:
		return
	var dt: float = float(now - last)
	var er: float = energy_rate(store, row, config)
	var sr: float = social_rate(store, row, config)
	store.hunger[row] = clamp_need(store.hunger[row] + hunger_rate(config) * dt)
	store.energy[row] = clamp_need(store.energy[row] + er * dt)
	store.social[row] = clamp_need(store.social[row] + sr * dt)
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
	return -1


static func apply_meal(store: AgentStore, row: int, config: SimConfig) -> void:
	store.hunger[row] = clamp_need(store.hunger[row] - config.meal_hunger_reduction)


static func apply_social(store: AgentStore, row: int, config: SimConfig) -> void:
	store.social[row] = clamp_need(store.social[row] + config.social_gain)


static func need_name(need: int) -> String:
	match need:
		NEED_HUNGER: return "Hunger"
		NEED_ENERGY: return "Energie"
		NEED_SOCIAL: return "Sozial"
	return "?"
