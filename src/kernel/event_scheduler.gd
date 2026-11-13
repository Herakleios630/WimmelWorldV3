class_name EventScheduler
extends RefCounted

## Deterministischer Min-Heap mit stabiler Ordnung (time, seq).
## Parallele Packed-Arrays = SoA-Heap; kein Dictionary/Objekt pro Event.
## Hot-Loop-API: pop() schreibt in last_*, ohne Allokation.

var times: PackedInt64Array = PackedInt64Array()
var seqs: PackedInt64Array = PackedInt64Array()
var kinds: PackedInt32Array = PackedInt32Array()
var payloads: PackedInt64Array = PackedInt64Array()

var _size: int = 0
var _next_seq: int = 0

var last_time: int = 0
var last_seq: int = 0
var last_kind: int = 0
var last_payload: int = 0


func clear() -> void:
	times.clear()
	seqs.clear()
	kinds.clear()
	payloads.clear()
	_size = 0
	_next_seq = 0


func size() -> int:
	return _size


func is_empty() -> bool:
	return _size == 0


func peek_time() -> int:
	return times[0] if _size > 0 else 0x7FFFFFFFFFFFFFFF


func next_seq() -> int:
	return _next_seq


func push(time_value: int, kind: int, payload: int) -> int:
	var s: int = _next_seq
	_next_seq = s + 1
	var i: int = _size
	times.append(time_value)
	seqs.append(s)
	kinds.append(kind)
	payloads.append(payload)
	_size = i + 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		var parent_time: int = times[parent]
		if parent_time < time_value or (parent_time == time_value and seqs[parent] < s):
			break
		times[i] = parent_time
		seqs[i] = seqs[parent]
		kinds[i] = kinds[parent]
		payloads[i] = payloads[parent]
		i = parent
	times[i] = time_value
	seqs[i] = s
	kinds[i] = kind
	payloads[i] = payload
	return s


func pop() -> bool:
	var n: int = _size
	if n == 0:
		return false
	last_time = times[0]
	last_seq = seqs[0]
	last_kind = kinds[0]
	last_payload = payloads[0]
	n -= 1
	_size = n
	if n == 0:
		times.resize(0)
		seqs.resize(0)
		kinds.resize(0)
		payloads.resize(0)
		return true
	var last_t: int = times[n]
	var last_s: int = seqs[n]
	var last_k: int = kinds[n]
	var last_p: int = payloads[n]
	times.resize(n)
	seqs.resize(n)
	kinds.resize(n)
	payloads.resize(n)
	var i: int = 0
	var half: int = n >> 1
	while i < half:
		var child: int = (i << 1) + 1
		var right: int = child + 1
		if right < n:
			var right_time: int = times[right]
			var child_time: int = times[child]
			if right_time < child_time or (right_time == child_time and seqs[right] < seqs[child]):
				child = right
		var ctime: int = times[child]
		if last_t < ctime or (last_t == ctime and last_s < seqs[child]):
			break
		times[i] = ctime
		seqs[i] = seqs[child]
		kinds[i] = kinds[child]
		payloads[i] = payloads[child]
		i = child
	times[i] = last_t
	seqs[i] = last_s
	kinds[i] = last_k
	payloads[i] = last_p
	return true


## Nur für Tests/Komfort. Hot-Loop nutzt pop() + last_*.
func pop_event() -> Array:
	if not pop():
		return []
	return [last_time, last_seq, last_kind, last_payload]


## Restore aus Save: Arrays sind ein gültiger Heap.
func restore_arrays(p_times: PackedInt64Array, p_seqs: PackedInt64Array,
		p_kinds: PackedInt32Array, p_payloads: PackedInt64Array,
		p_size: int, p_next_seq: int) -> void:
	times = p_times
	seqs = p_seqs
	kinds = p_kinds
	payloads = p_payloads
	_size = p_size
	_next_seq = p_next_seq


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, _size)
	h = HashUtil.mix_i64(h, _next_seq)
	for i in _size:
		h = HashUtil.mix_i64(h, times[i])
		h = HashUtil.mix_i64(h, seqs[i])
		h = HashUtil.mix(h, kinds[i])
		h = HashUtil.mix_i64(h, payloads[i])
	return h
