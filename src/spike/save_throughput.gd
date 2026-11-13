class_name SpikeSave
extends RefCounted

## Wegwerf-Binärformat für G0.5 (KEIN finales Save-Format).
##
## Zweck: Durchsatz/Größe von SoA-Serialisierung messen. Header + festes
## Record-Layout, keine Versionierung/Migration/Kompression.

const MAGIC: int = 0x57575350
const VERSION: int = 1
const HEADER: int = 12
const STRIDE: int = 58

# Record-Offsets (Bytes, relativ zum Agenten-Record).
const OFF_ID: int = 0
const OFF_ALIVE: int = 4
const OFF_ACTIVITY: int = 5
const OFF_AGE: int = 6
const OFF_POS_X: int = 10
const OFF_POS_Y: int = 14
const OFF_NEXT_EVENT: int = 18
const OFF_HUNGER: int = 26
const OFF_ENERGY: int = 30
const OFF_SOCIAL: int = 34
const OFF_HYGIENE: int = 38
const OFF_FUN: int = 42
const OFF_HEALTH: int = 46
const OFF_HOME: int = 50
const OFF_JOB: int = 54


func encoded_size(n: int) -> int:
	return HEADER + n * STRIDE


func encode(store: SpikeAgentStore, n: int) -> PackedByteArray:
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(HEADER + n * STRIDE)
	buf.encode_u32(0, MAGIC)
	buf.encode_u32(4, VERSION)
	buf.encode_u32(8, n)
	var ids: PackedInt32Array = store.ids
	var alive: PackedByteArray = store.alive
	var act: PackedByteArray = store.activity
	var age: PackedFloat32Array = store.age_days
	var px: PackedFloat32Array = store.pos_x
	var py: PackedFloat32Array = store.pos_y
	var ne: PackedInt64Array = store.next_event
	var hu: PackedFloat32Array = store.hunger
	var en: PackedFloat32Array = store.energy
	var so: PackedFloat32Array = store.social
	var hy: PackedFloat32Array = store.hygiene
	var fu: PackedFloat32Array = store.fun
	var he: PackedFloat32Array = store.health
	var home: PackedInt32Array = store.home_id
	var job: PackedInt32Array = store.job_id
	var o: int = HEADER
	for i in n:
		buf.encode_s32(o + OFF_ID, ids[i])
		buf.encode_u8(o + OFF_ALIVE, alive[i])
		buf.encode_u8(o + OFF_ACTIVITY, act[i])
		buf.encode_float(o + OFF_AGE, age[i])
		buf.encode_float(o + OFF_POS_X, px[i])
		buf.encode_float(o + OFF_POS_Y, py[i])
		buf.encode_s64(o + OFF_NEXT_EVENT, ne[i])
		buf.encode_float(o + OFF_HUNGER, hu[i])
		buf.encode_float(o + OFF_ENERGY, en[i])
		buf.encode_float(o + OFF_SOCIAL, so[i])
		buf.encode_float(o + OFF_HYGIENE, hy[i])
		buf.encode_float(o + OFF_FUN, fu[i])
		buf.encode_float(o + OFF_HEALTH, he[i])
		buf.encode_s32(o + OFF_HOME, home[i])
		buf.encode_s32(o + OFF_JOB, job[i])
		o += STRIDE
	return buf


func decode(buf: PackedByteArray) -> SpikeAgentStore:
	var n: int = buf.decode_u32(8)
	var store: SpikeAgentStore = SpikeAgentStore.new()
	store.count = n
	store.ids.resize(n)
	store.alive.resize(n)
	store.activity.resize(n)
	store.age_days.resize(n)
	store.pos_x.resize(n)
	store.pos_y.resize(n)
	store.next_event.resize(n)
	store.hunger.resize(n)
	store.energy.resize(n)
	store.social.resize(n)
	store.hygiene.resize(n)
	store.fun.resize(n)
	store.health.resize(n)
	store.home_id.resize(n)
	store.job_id.resize(n)
	var o: int = HEADER
	for i in n:
		store.ids[i] = buf.decode_s32(o + OFF_ID)
		store.alive[i] = buf.decode_u8(o + OFF_ALIVE)
		store.activity[i] = buf.decode_u8(o + OFF_ACTIVITY)
		store.age_days[i] = buf.decode_float(o + OFF_AGE)
		store.pos_x[i] = buf.decode_float(o + OFF_POS_X)
		store.pos_y[i] = buf.decode_float(o + OFF_POS_Y)
		store.next_event[i] = buf.decode_s64(o + OFF_NEXT_EVENT)
		store.hunger[i] = buf.decode_float(o + OFF_HUNGER)
		store.energy[i] = buf.decode_float(o + OFF_ENERGY)
		store.social[i] = buf.decode_float(o + OFF_SOCIAL)
		store.hygiene[i] = buf.decode_float(o + OFF_HYGIENE)
		store.fun[i] = buf.decode_float(o + OFF_FUN)
		store.health[i] = buf.decode_float(o + OFF_HEALTH)
		store.home_id[i] = buf.decode_s32(o + OFF_HOME)
		store.job_id[i] = buf.decode_s32(o + OFF_JOB)
		o += STRIDE
	return store


## Speichert und misst Serialisierung + Schreiben getrennt.
func save_measured(store: SpikeAgentStore, n: int, path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var buf: PackedByteArray = encode(store, n)
	var t1: int = Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "open_write_failed", "path": path}
	f.store_buffer(buf)
	f.close()
	var t2: int = Time.get_ticks_usec()
	var encode_ms: float = float(t1 - t0) / 1000.0
	var write_ms: float = float(t2 - t1) / 1000.0
	var total_ms: float = encode_ms + write_ms
	var mbytes: float = float(buf.size()) / 1000000.0
	return {
		"ok": true,
		"path": path,
		"bytes": buf.size(),
		"mbytes": mbytes,
		"encode_ms": encode_ms,
		"write_ms": write_ms,
		"total_ms": total_ms,
		"mb_s": mbytes / (total_ms / 1000.0) if total_ms > 0.0 else 0.0,
	}


## Lädt, dekodiert und vergleicht den Zustands-Hash mit dem Original.
func load_measured(expected_hash: int, path: String) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var buf: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var t1: int = Time.get_ticks_usec()
	if buf.is_empty():
		return {"ok": false, "error": "read_failed", "path": path}
	if buf.decode_u32(0) != MAGIC:
		return {"ok": false, "error": "bad_magic", "path": path}
	var store: SpikeAgentStore = decode(buf)
	var t2: int = Time.get_ticks_usec()
	var read_ms: float = float(t1 - t0) / 1000.0
	var decode_ms: float = float(t2 - t1) / 1000.0
	var total_ms: float = read_ms + decode_ms
	var mbytes: float = float(buf.size()) / 1000000.0
	var hash: int = store.state_hash()
	return {
		"ok": hash == expected_hash,
		"verified": hash == expected_hash,
		"hash": hash,
		"expected_hash": expected_hash,
		"count": store.count,
		"bytes": buf.size(),
		"mbytes": mbytes,
		"read_ms": read_ms,
		"decode_ms": decode_ms,
		"total_ms": total_ms,
		"mb_s": mbytes / (total_ms / 1000.0) if total_ms > 0.0 else 0.0,
	}
