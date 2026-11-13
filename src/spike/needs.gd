class_name SpikeNeeds
extends RefCounted

## Analytische Needs für den G0.5-Spike (Referenzformel).
##
## Die Hot-Loop-Variante in agent_store.gd ist inline (GDScript-Funktionsaufrufe
## pro Agent wären Messrauschen). Diese Datei ist die lesbare Referenz; der
## Runner prüft Stichproben gegen next_wake_seconds().
##
## Semantik: Werte 0..100. Hunger/Social/Hygiene/Fun steigen, Energie fällt.
## Ein Wake terminiert den frühesten Schwellenabstand; kein Polling pro Tick.

const SECONDS_PER_DAY: float = 86400.0

# Sekunden pro Need-Punkt (deterministische Raten, keine RNG).
const HUNGER_SPU: float = 470.0
const ENERGY_SPU: float = 840.0
const SOCIAL_SPU: float = 655.0
const HYGIENE_SPU: float = 935.0
const FUN_SPU: float = 750.0

# Wake-Schwellen.
const WAKE_HUNGER: float = 70.0
const WAKE_ENERGY: float = 30.0
const WAKE_SOCIAL: float = 75.0
const WAKE_HYGIENE: float = 80.0
const WAKE_FUN: float = 85.0

# Werte nach einem Wake (Erholung).
const RESTORE_HUNGER: float = 5.0
const RESTORE_ENERGY: float = 100.0
const RESTORE_SOCIAL: float = 10.0
const RESTORE_HYGIENE: float = 15.0
const RESTORE_FUN: float = 20.0

const MIN_WAKE: float = 1.0


## Referenz: Sekunden bis zum frühesten Need-Wake.
static func next_wake_seconds(hunger: float, energy: float, social: float,
		hygiene: float, fun: float) -> float:
	var best: float = (WAKE_HUNGER - hunger) * HUNGER_SPU
	var d: float = (energy - WAKE_ENERGY) * ENERGY_SPU
	if d < best:
		best = d
	d = (WAKE_SOCIAL - social) * SOCIAL_SPU
	if d < best:
		best = d
	d = (WAKE_HYGIENE - hygiene) * HYGIENE_SPU
	if d < best:
		best = d
	d = (WAKE_FUN - fun) * FUN_SPU
	if d < best:
		best = d
	if best < MIN_WAKE:
		return MIN_WAKE
	return best


## Erwartete Need-Wakes pro Agent und Sim-Tag bei diesem Modell.
static func expected_events_per_day() -> float:
	var total: float = 0.0
	total += SECONDS_PER_DAY / ((WAKE_HUNGER - RESTORE_HUNGER) * HUNGER_SPU)
	total += SECONDS_PER_DAY / ((RESTORE_ENERGY - WAKE_ENERGY) * ENERGY_SPU)
	total += SECONDS_PER_DAY / ((WAKE_SOCIAL - RESTORE_SOCIAL) * SOCIAL_SPU)
	total += SECONDS_PER_DAY / ((WAKE_HYGIENE - RESTORE_HYGIENE) * HYGIENE_SPU)
	total += SECONDS_PER_DAY / ((WAKE_FUN - RESTORE_FUN) * FUN_SPU)
	return total
