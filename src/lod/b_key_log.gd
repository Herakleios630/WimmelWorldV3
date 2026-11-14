class_name BKeyLog
extends RefCounted

## Individual key-lifecycle events for B. Routine detail events are counted but
## not stored here. Every key event references stable agent IDs; death/birth/
## marriage/job-change identities are therefore preserved across tiers.

const TYPE_BIRTH: int = 1
const TYPE_DEATH: int = 2
const TYPE_MARRIAGE: int = 3
const TYPE_JOB_CHANGE: int = 4

const TYPE_NAMES: Array = ["", "birth", "death", "marriage", "job_change"]

var ids: PackedInt64Array = PackedInt64Array()
var times: PackedInt64Array = PackedInt64Array()
var days: PackedInt32Array = PackedInt32Array()
var types: PackedByteArray = PackedByteArray()
var a_ids: PackedInt32Array = PackedInt32Array()
var b_ids: PackedInt32Array = PackedInt32Array()
var settlement_ids: PackedInt32Array = PackedInt32Array()
var data: PackedInt64Array = PackedInt64Array()

var next_id: int = 1
var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])


static func type_name(t: int) -> String:
	if t >= 0 and t < TYPE_NAMES.size():
		return TYPE_NAMES[t]
	return "unknown"


func emit(p_type: int, now: int, a: int, b: int, sid: int, p_data: int = 0) -> int:
	var eid: int = next_id
	next_id += 1
	ids.append(eid)
	times.append(now)
	days.append(now / BConfig.TICKS_PER_DAY)
	types.append(p_type)
	a_ids.append(a)
	b_ids.append(b)
	settlement_ids.append(sid)
	data.append(p_data)
	if p_type >= 0 and p_type < counts.size():
		counts[p_type] += 1
	return eid


func total() -> int:
	return ids.size()


func count_of(p_type: int) -> int:
	if p_type >= 0 and p_type < counts.size():
		return counts[p_type]
	return 0


func hash_into_agent(h: int, row_hash: int) -> int:
	return HashUtil.mix(h, row_hash)


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, next_id)
	for i in ids.size():
		h = HashUtil.mix_i64(h, ids[i])
		h = HashUtil.mix_i64(h, times[i])
		h = HashUtil.mix_i64(h, days[i])
		h = HashUtil.mix(h, types[i])
		h = HashUtil.mix(h, a_ids[i])
		h = HashUtil.mix(h, b_ids[i])
		h = HashUtil.mix(h, settlement_ids[i])
		h = HashUtil.mix_i64(h, data[i])
	for t in counts.size():
		h = HashUtil.mix(h, counts[t])
	return h


func memory_bytes_estimate() -> int:
	var n: int = ids.size()
	return n * (8 + 8 + 4 + 1 + 4 + 4 + 4 + 8)


func verify_identities(records: BRecords) -> Dictionary:
	var failures: PackedStringArray = PackedStringArray()
	for i in ids.size():
		var t: int = types[i]
		var a: int = a_ids[i]
		var b: int = b_ids[i]
		if t == TYPE_BIRTH:
			var child: int = records.row_for_id(a)
			if child < 0:
				failures.append("birth_missing_child:%d" % a)
			else:
				if records.birth_day[child] != days[i]:
					failures.append("birth_day_mismatch:%d" % a)
				if b > 0 and records.mother_id[child] != b:
					failures.append("birth_mother_mismatch:%d" % a)
				if int(data[i]) > 0 and records.father_id[child] != int(data[i]):
					failures.append("birth_father_mismatch:%d" % a)
		elif t == TYPE_DEATH:
			var row: int = records.row_for_id(a)
			if row < 0:
				failures.append("death_missing_agent:%d" % a)
			else:
				if records.alive[row] != 0:
					failures.append("death_alive:%d" % a)
				if records.death_day[row] != days[i]:
					failures.append("death_day_mismatch:%d" % a)
		elif t == TYPE_MARRIAGE:
			var ra: int = records.row_for_id(a)
			var rb: int = records.row_for_id(b)
			if ra < 0 or rb < 0:
				failures.append("marriage_missing_agent:%d:%d" % [a, b])
			elif records.alive[ra] != 0 and records.alive[rb] != 0:
				if records.partner_id[ra] != b or records.partner_id[rb] != a:
					failures.append("marriage_partner_mismatch:%d:%d" % [a, b])
		elif t == TYPE_JOB_CHANGE:
			var r: int = records.row_for_id(a)
			if r < 0:
				failures.append("job_missing_agent:%d" % a)
			else:
				if records.last_job_change_day[r] != days[i]:
					failures.append("job_day_mismatch:%d" % a)
	return {"ok": failures.is_empty(), "failures": failures}
