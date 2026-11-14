class_name BTierSelector
extends RefCounted

## Deterministic detail-tier selection for B.
##
## Base selection is a stable hash rotation of the persistent agent ID (plus a
## priority bonus for event proximity, age, relationships, work and travel).
## The top-K is maintained with a bounded max-heap, filled in fixed Sim-time
## slices (selection events), so chunking does not change the result.
##
## The selector never reads camera, zoom, visibility, follow or inspector.

const SCORE_MOD: int = 10000000
const KEY_OFFSET: int = 40000000
const ROW_MASK: int = 0xFFFFFF
const DEAD_BUFFER: int = 64

var config: BConfig
var records: BRecords
var key_log: BKeyLog
var detail = null

var active: bool = false
var active_epoch: int = 0
var cursor: int = 0
var target_count: int = 0
var last_commit_epoch: int = -1

var heap_keys: PackedInt64Array = PackedInt64Array()
var heap_size: int = 0
var detail_rows: PackedInt32Array = PackedInt32Array()
var detail_set_hash: int = 0

var promotions: int = 0
var demotions: int = 0
var switch_count: int = 0
var catchup_usec: int = 0
var selection_usec: int = 0
var selection_rows: int = 0
var commit_usec: int = 0
var commit_count: int = 0


func setup(p_config: BConfig, p_records: BRecords, p_key_log: BKeyLog, p_detail) -> void:
	config = p_config
	records = p_records
	key_log = p_key_log
	detail = p_detail
	heap_keys.clear()
	heap_size = 0
	detail_rows = PackedInt32Array()
	detail_set_hash = 0
	promotions = 0
	demotions = 0
	switch_count = 0
	catchup_usec = 0
	selection_usec = 0
	selection_rows = 0
	commit_usec = 0
	commit_count = 0


func setup_initial(now: int) -> void:
	start_epoch(0)
	process_chunk(records.count)
	commit(now)


func start_epoch(epoch: int) -> void:
	active = true
	active_epoch = epoch
	cursor = 0
	target_count = records.count
	heap_keys.clear()
	heap_size = 0


func rows_remaining() -> int:
	return maxi(0, target_count - cursor)


func process_chunk(max_rows: int) -> void:
	if not active:
		return
	var t0: int = Time.get_ticks_usec()
	var start: int = cursor
	var end: int = mini(target_count, cursor + max_rows)
	var cap: int = config.detail_target + DEAD_BUFFER
	while cursor < end:
		var row: int = cursor
		cursor += 1
		if records.alive[row] == 0:
			continue
		var key: int = _score_key(row, active_epoch)
		if heap_size < cap:
			heap_keys.append(key)
			heap_size += 1
			_sift_up(heap_size - 1)
		elif key < heap_keys[0]:
			heap_keys[0] = key
			_sift_down(0)
	selection_rows += end - start
	selection_usec += Time.get_ticks_usec() - t0


func commit(now: int) -> void:
	if not active:
		return
	var t0: int = Time.get_ticks_usec()
	if cursor < target_count:
		process_chunk(target_count - cursor)
	heap_keys.sort()
	var mark: PackedByteArray = PackedByteArray()
	mark.resize(records.count)
	mark.fill(0)
	var new_rows: PackedInt32Array = PackedInt32Array()
	for i in heap_size:
		if new_rows.size() >= config.detail_target:
			break
		var row: int = int(heap_keys[i] & ROW_MASK)
		if row < 0 or row >= records.count:
			continue
		if records.alive[row] == 0:
			continue
		mark[row] = 1
		new_rows.append(row)
	var t_diff: int = Time.get_ticks_usec()
	for row in detail_rows:
		if row < 0 or row >= records.count:
			continue
		if mark[row] == 0 and records.tier[row] != 0:
			records.tier[row] = 0
			if detail != null:
				detail.on_demote(row, now)
			demotions += 1
	for row in new_rows:
		if records.tier[row] == 0:
			records.tier[row] = 1
			if detail != null:
				detail.on_promote(row, now)
			promotions += 1
	switch_count = promotions + demotions
	detail_rows = new_rows
	detail_set_hash = _detail_hash(new_rows)
	last_commit_epoch = active_epoch
	active = false
	var elapsed: int = Time.get_ticks_usec() - t0
	commit_usec += elapsed
	catchup_usec += Time.get_ticks_usec() - t_diff
	commit_count += 1


func detail_count() -> int:
	return detail_rows.size()


func assignment_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, active_epoch)
	h = HashUtil.mix_i64(h, detail_rows.size())
	for row in detail_rows:
		h = HashUtil.mix(h, records.ids[row] if row >= 0 and row < records.count else 0)
	return h


func _detail_hash(rows: PackedInt32Array) -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, rows.size())
	for row in rows:
		h = HashUtil.mix(h, records.ids[row])
	return h


func _score_key(row: int, epoch: int) -> int:
	var id: int = records.ids[row]
	var rotation_epoch: int = epoch / config.selection_rotation_days
	var base: int = BHash.hash3(id, rotation_epoch, config.selection_salt ^ config.seed) % SCORE_MOD
	var bonus: int = 0
	if records.last_key_day[row] >= epoch - config.key_priority_days:
		bonus += 20000000
	var age: int = records.age_years_at(row, epoch)
	if age <= 4 or age >= 75:
		bonus += 1500000
	elif age >= 15 and age <= 29:
		bonus += 300000
	if records.partner_id[row] > 0:
		bonus += 300000
	if records.job_kind[row] != BConfig.JOB_NONE:
		bonus += 100000
	if BHash.hash4(id, rotation_epoch, 0xA11, config.selection_salt ^ config.seed) % 100 < 3:
		bonus += 2000000
	var act: int = records.activity[row]
	if act == BConfig.ACTIVITY_TRAVEL:
		bonus += 4000000
	elif act != BConfig.ACTIVITY_IDLE:
		bonus += 500000
	var sid: int = records.settlement_id[row]
	if sid >= 0 and sid < records.settlement_count:
		if records.settlement_last_key_day[sid] >= epoch - 2:
			bonus += 500000
	var score: int = base - bonus
	return ((score + KEY_OFFSET) << 24) | (row & ROW_MASK)


func _sift_up(i: int) -> void:
	var key: int = heap_keys[i]
	while i > 0:
		var parent: int = (i - 1) >> 1
		if heap_keys[parent] >= key:
			break
		heap_keys[i] = heap_keys[parent]
		i = parent
	heap_keys[i] = key


func _sift_down(i: int) -> void:
	var key: int = heap_keys[i]
	var n: int = heap_size
	var half: int = n >> 1
	while i < half:
		var child: int = (i << 1) + 1
		var right: int = child + 1
		if right < n and heap_keys[right] > heap_keys[child]:
			child = right
		if key >= heap_keys[child]:
			break
		heap_keys[i] = heap_keys[child]
		i = child
	heap_keys[i] = key


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix(h, 1 if active else 0)
	h = HashUtil.mix_i64(h, active_epoch)
	h = HashUtil.mix_i64(h, cursor)
	h = HashUtil.mix_i64(h, target_count)
	h = HashUtil.mix_i64(h, last_commit_epoch)
	h = HashUtil.mix_i64(h, heap_size)
	for i in heap_size:
		h = HashUtil.mix_i64(h, heap_keys[i])
	h = HashUtil.mix_i64(h, detail_rows.size())
	for row in detail_rows:
		h = HashUtil.mix(h, row)
		h = HashUtil.mix(h, records.ids[row])
	h = HashUtil.mix_i64(h, detail_set_hash)
	h = HashUtil.mix_i64(h, promotions)
	h = HashUtil.mix_i64(h, demotions)
	h = HashUtil.mix_i64(h, switch_count)
	return h

