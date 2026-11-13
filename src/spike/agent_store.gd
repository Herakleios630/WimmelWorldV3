class_name SpikeAgentStore
extends RefCounted

## Wegwerf-SoA für G0.5: Need-Update + Terminplanung in einem Durchlauf.
##
## Kein Gameplay, keine Entscheidungen. Felder orientieren sich an
## v3-architecture.md §2.3, damit Speicher/µs realistisch sind.
## float32 für Needs/Position (Speicherrealismus); Dokumentation der daraus
## folgenden Float-Semantik gehört zum G0.5-Bericht.

const BYTES_PER_AGENT: int = 58

# Need-Indizes (Reihenfolge = Batch-Event-Payload).
const NEED_HUNGER: int = 0
const NEED_ENERGY: int = 1
const NEED_SOCIAL: int = 2
const NEED_HYGIENE: int = 3
const NEED_FUN: int = 4

const ACTIVITY_IDLE: int = 0
const ACTIVITY_WORK: int = 1
const ACTIVITY_EAT: int = 2
const ACTIVITY_SLEEP: int = 3
const ACTIVITY_SOCIAL: int = 4
const ACTIVITY_TRAVEL: int = 5

var count: int = 0

var ids: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()
var activity: PackedByteArray = PackedByteArray()
var age_days: PackedFloat32Array = PackedFloat32Array()
var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_y: PackedFloat32Array = PackedFloat32Array()
var next_event: PackedInt64Array = PackedInt64Array()
var hunger: PackedFloat32Array = PackedFloat32Array()
var energy: PackedFloat32Array = PackedFloat32Array()
var social: PackedFloat32Array = PackedFloat32Array()
var hygiene: PackedFloat32Array = PackedFloat32Array()
var fun: PackedFloat32Array = PackedFloat32Array()
var health: PackedFloat32Array = PackedFloat32Array()
var home_id: PackedInt32Array = PackedInt32Array()
var job_id: PackedInt32Array = PackedInt32Array()


func configure(n: int, seed_value: int = 1) -> void:
	count = n
	ids.resize(n)
	alive.resize(n)
	activity.resize(n)
	age_days.resize(n)
	pos_x.resize(n)
	pos_y.resize(n)
	next_event.resize(n)
	hunger.resize(n)
	energy.resize(n)
	social.resize(n)
	hygiene.resize(n)
	fun.resize(n)
	health.resize(n)
	home_id.resize(n)
	job_id.resize(n)
	var rng: SpikeRng = SpikeRng.new(seed_value)
	for i in n:
		ids[i] = i
		alive[i] = 1
		activity[i] = ACTIVITY_IDLE
		age_days[i] = 16.0 + rng.next_unit() * 44.0
		pos_x[i] = rng.next_unit() * 1024.0
		pos_y[i] = rng.next_unit() * 1024.0
		next_event[i] = 0
		hunger[i] = rng.next_unit() * 60.0
		energy[i] = 40.0 + rng.next_unit() * 60.0
		social[i] = rng.next_unit() * 60.0
		hygiene[i] = rng.next_unit() * 70.0
		fun[i] = rng.next_unit() * 70.0
		health[i] = 70.0 + rng.next_unit() * 30.0
		home_id[i] = rng.next_range(5000)
		job_id[i] = rng.next_range(64)


## Nur Need-Decay, ohne Terminplanung (Q3-Kostentrennung).
func update_needs_only(dt: float, n: int = -1) -> void:
	if n < 0:
		n = count
	var hr: float = dt / SpikeNeeds.HUNGER_SPU
	var er: float = dt / SpikeNeeds.ENERGY_SPU
	var sr: float = dt / SpikeNeeds.SOCIAL_SPU
	var yr: float = dt / SpikeNeeds.HYGIENE_SPU
	var fr: float = dt / SpikeNeeds.FUN_SPU
	for i in n:
		var v: float = hunger[i] + hr
		hunger[i] = 100.0 if v > 100.0 else v
		v = energy[i] - er
		energy[i] = 0.0 if v < 0.0 else v
		v = social[i] + sr
		social[i] = 100.0 if v > 100.0 else v
		v = hygiene[i] + yr
		hygiene[i] = 100.0 if v > 100.0 else v
		v = fun[i] + fr
		fun[i] = 100.0 if v > 100.0 else v


## Need-Update + Terminplanung. Rückgabe: Anzahl geplanter Termine.
func tick(now: int, dt: float, n: int = -1) -> int:
	if n < 0:
		n = count
	var hr: float = dt / SpikeNeeds.HUNGER_SPU
	var er: float = dt / SpikeNeeds.ENERGY_SPU
	var sr: float = dt / SpikeNeeds.SOCIAL_SPU
	var yr: float = dt / SpikeNeeds.HYGIENE_SPU
	var fr: float = dt / SpikeNeeds.FUN_SPU
	var scheduled: int = 0
	for i in n:
		var v: float = hunger[i] + hr
		if v > 100.0:
			v = 100.0
		hunger[i] = v
		v = energy[i] - er
		if v < 0.0:
			v = 0.0
		energy[i] = v
		v = social[i] + sr
		if v > 100.0:
			v = 100.0
		social[i] = v
		v = hygiene[i] + yr
		if v > 100.0:
			v = 100.0
		hygiene[i] = v
		v = fun[i] + fr
		if v > 100.0:
			v = 100.0
		fun[i] = v

		# Frühester Schwellenabstand (inline, muss zu needs.gd passen).
		var best: float = (SpikeNeeds.WAKE_HUNGER - hunger[i]) * SpikeNeeds.HUNGER_SPU
		var d: float = (energy[i] - SpikeNeeds.WAKE_ENERGY) * SpikeNeeds.ENERGY_SPU
		if d < best:
			best = d
		d = (SpikeNeeds.WAKE_SOCIAL - social[i]) * SpikeNeeds.SOCIAL_SPU
		if d < best:
			best = d
		d = (SpikeNeeds.WAKE_HYGIENE - hygiene[i]) * SpikeNeeds.HYGIENE_SPU
		if d < best:
			best = d
		d = (SpikeNeeds.WAKE_FUN - fun[i]) * SpikeNeeds.FUN_SPU
		if d < best:
			best = d
		if best < SpikeNeeds.MIN_WAKE:
			best = SpikeNeeds.MIN_WAKE
		var jitter: int = ((i * 2654435761) >> 8) % 83
		next_event[i] = now + int(best) + jitter
		scheduled += 1
	return scheduled


## Event-Handler für einen fälligen Need-Wake. Gibt den betroffenen Need zurück.
func apply_need_wake(i: int, now: int) -> int:
	var need: int = NEED_HUNGER
	var worst: float = hunger[i] - SpikeNeeds.WAKE_HUNGER
	var v: float = SpikeNeeds.WAKE_ENERGY - energy[i]
	if v > worst:
		worst = v
		need = NEED_ENERGY
	v = social[i] - SpikeNeeds.WAKE_SOCIAL
	if v > worst:
		worst = v
		need = NEED_SOCIAL
	v = hygiene[i] - SpikeNeeds.WAKE_HYGIENE
	if v > worst:
		worst = v
		need = NEED_HYGIENE
	v = fun[i] - SpikeNeeds.WAKE_FUN
	if v > worst:
		worst = v
		need = NEED_FUN
	match need:
		NEED_HUNGER:
			hunger[i] = SpikeNeeds.RESTORE_HUNGER
			activity[i] = ACTIVITY_EAT
		NEED_ENERGY:
			energy[i] = SpikeNeeds.RESTORE_ENERGY
			activity[i] = ACTIVITY_SLEEP
		NEED_SOCIAL:
			social[i] = SpikeNeeds.RESTORE_SOCIAL
			activity[i] = ACTIVITY_SOCIAL
		NEED_HYGIENE:
			hygiene[i] = SpikeNeeds.RESTORE_HYGIENE
			activity[i] = ACTIVITY_IDLE
		NEED_FUN:
			fun[i] = SpikeNeeds.RESTORE_FUN
			activity[i] = ACTIVITY_IDLE
	var wake: float = SpikeNeeds.next_wake_seconds(
			hunger[i], energy[i], social[i], hygiene[i], fun[i])
	next_event[i] = now + int(wake) + (((i * 2654435761) >> 8) % 83)
	return need


## Einfache, deterministische Arbeitslast für Batch-Events (kein Gameplay).
func apply_work_start(i: int, now: int) -> void:
	activity[i] = ACTIVITY_WORK
	next_event[i] = now + 3600 + (i % 97)


func apply_arrive(i: int, now: int, cache_hit: bool) -> void:
	activity[i] = ACTIVITY_TRAVEL
	pos_x[i] = pos_x[i] + (1.5 if cache_hit else 0.0)
	next_event[i] = now + 60 + (i % 31)


func apply_social(i: int, now: int) -> void:
	social[i] = SpikeNeeds.RESTORE_SOCIAL
	fun[i] = fun[i] + 2.0 if fun[i] < 98.0 else 100.0
	next_event[i] = now + 1800 + (i % 211)


func apply_lifecycle(i: int, now: int) -> void:
	age_days[i] = age_days[i] + 1.0
	health[i] = health[i] - 0.01 if health[i] > 0.0 else 0.0
	next_event[i] = now + 86400 + (i % 359)


func memory_bytes() -> int:
	return count * BYTES_PER_AGENT


func _mix(h: int, v: int) -> int:
	return ((h ^ (v & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


## FNV-1a-32 über den SoA-Zustand (Determinismus-Snapshot).
func state_hash() -> int:
	var h: int = 2166136261
	for i in count:
		h = _mix(h, ids[i])
		h = _mix(h, alive[i])
		h = _mix(h, activity[i])
		h = _mix(h, int(round(age_days[i] * 1000.0)))
		h = _mix(h, int(round(pos_x[i] * 1000.0)))
		h = _mix(h, int(round(pos_y[i] * 1000.0)))
		h = _mix(h, next_event[i])
		h = _mix(h, int(round(hunger[i] * 1000.0)))
		h = _mix(h, int(round(energy[i] * 1000.0)))
		h = _mix(h, int(round(social[i] * 1000.0)))
		h = _mix(h, int(round(hygiene[i] * 1000.0)))
		h = _mix(h, int(round(fun[i] * 1000.0)))
		h = _mix(h, int(round(health[i] * 1000.0)))
		h = _mix(h, home_id[i])
		h = _mix(h, job_id[i])
	return h
