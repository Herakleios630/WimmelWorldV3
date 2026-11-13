class_name SpikeScheduler
extends RefCounted

## Deterministischer Min-Heap für G0.5.
##
## Ordnung: (time, seq). seq wird pro push vergeben und ist eindeutig, damit
## gleiche Zeiten deterministisch in Einfügereihenfolge abgearbeitet werden.
## Parallele Packed-Arrays = SoA-Heap ohne Dictionary / Objekt pro Event.
##
## Hot-Loop-API: pop() schreibt in last_* und vermeidet Allokationen.
## pop_event() liefert ein Array und ist nur für Tests/Komfort gedacht.

const KIND_NEED: int = 0
const KIND_WORK: int = 1
const KIND_ARRIVE: int = 2
const KIND_SOCIAL: int = 3
const KIND_LIFECYCLE: int = 4
const KIND_COUNT: int = 5

var _time: PackedInt64Array = PackedInt64Array()
var _seq: PackedInt64Array = PackedInt64Array()
var _kind: PackedInt32Array = PackedInt32Array()
var _payload: PackedInt64Array = PackedInt64Array()
var _size: int = 0
var _next_seq: int = 0

var last_time: int = 0
var last_seq: int = 0
var last_kind: int = 0
var last_payload: int = 0


func clear() -> void:
	_time.clear()
	_seq.clear()
	_kind.clear()
	_payload.clear()
	_size = 0
	_next_seq = 0


func size() -> int:
	return _size


func is_empty() -> bool:
	return _size == 0


func peek_time() -> int:
	return _time[0] if _size > 0 else 0x7FFFFFFFFFFFFFFF


func push(time_value: int, kind: int, payload: int) -> int:
	var s: int = _next_seq
	_next_seq = s + 1
	var i: int = _size
	_time.append(time_value)
	_seq.append(s)
	_kind.append(kind)
	_payload.append(payload)
	_size = i + 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		var pt: int = _time[parent]
		if pt < time_value or (pt == time_value and _seq[parent] < s):
			break
		_time[i] = pt
		_seq[i] = _seq[parent]
		_kind[i] = _kind[parent]
		_payload[i] = _payload[parent]
		i = parent
	_time[i] = time_value
	_seq[i] = s
	_kind[i] = kind
	_payload[i] = payload
	return s


## Entfernt das kleinste Event. true = gültig, false = leer.
func pop() -> bool:
	var n: int = _size
	if n == 0:
		return false
	last_time = _time[0]
	last_seq = _seq[0]
	last_kind = _kind[0]
	last_payload = _payload[0]
	n -= 1
	_size = n
	if n == 0:
		_time.resize(0)
		_seq.resize(0)
		_kind.resize(0)
		_payload.resize(0)
		return true
	var lt: int = _time[n]
	var ls: int = _seq[n]
	var lk: int = _kind[n]
	var lp: int = _payload[n]
	_time.resize(n)
	_seq.resize(n)
	_kind.resize(n)
	_payload.resize(n)
	var i: int = 0
	var half: int = n >> 1
	while i < half:
		var child: int = (i << 1) + 1
		var right: int = child + 1
		if right < n:
			var rt: int = _time[right]
			var ct: int = _time[child]
			if rt < ct or (rt == ct and _seq[right] < _seq[child]):
				child = right
		var ct2: int = _time[child]
		if lt < ct2 or (lt == ct2 and ls < _seq[child]):
			break
		_time[i] = ct2
		_seq[i] = _seq[child]
		_kind[i] = _kind[child]
		_payload[i] = _payload[child]
		i = child
	_time[i] = lt
	_seq[i] = ls
	_kind[i] = lk
	_payload[i] = lp
	return true


## Nur für Tests/Determinismus-Snapshots.
func pop_event() -> Array:
	if not pop():
		return []
	return [last_time, last_seq, last_kind, last_payload]
