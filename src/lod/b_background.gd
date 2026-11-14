class_name BBackground
extends RefCounted

## Background coarse model. Deaths and births are processed daily per
## settlement/cohort; marriages and job changes on the settlement's weekly day.
## Key events are always individual records with stable agent IDs. Routine
## needs/health are aggregated per cohort and materialised lazily for promoted
## agents, so background work stays far below 100k per-agent updates per day.

var config: BConfig
var records: BRecords
var key_log: BKeyLog
var scheduler: EventScheduler
var detail: BDetail

var batch_count: int = 0
var daily_batches: int = 0
var weekly_batches: int = 0
var death_events: int = 0
var birth_events: int = 0
var marriage_events: int = 0
var job_change_events: int = 0


func setup(p_config: BConfig, p_records: BRecords, p_key_log: BKeyLog,
		p_scheduler: EventScheduler, p_detail: BDetail) -> void:
	config = p_config
	records = p_records
	key_log = p_key_log
	scheduler = p_scheduler
	detail = p_detail
	batch_count = 0
	daily_batches = 0
	weekly_batches = 0
	death_events = 0
	birth_events = 0
	marriage_events = 0
	job_change_events = 0


func initial_offset(sid: int) -> int:
	var off: int = BHash.hash3(sid, config.background_salt, config.seed) % BConfig.TICKS_PER_DAY
	if off < config.start_time:
		off += BConfig.TICKS_PER_DAY
	return off


func process_settlement(sid: int, now: int) -> void:
	var day: int = now / BConfig.TICKS_PER_DAY
	if sid < 0 or sid >= records.settlement_count:
		return
	if records.settlement_last_bg_day[sid] >= day:
		scheduler.push(now + BConfig.TICKS_PER_DAY, BKinds.EVENT_SETTLEMENT_BATCH, sid)
		return
	var weekly: bool = ((day + sid) % config.weekly_cadence_days) == 0
	for band in BRecords.BAND_COUNT:
		for sx in BRecords.SEXES:
			var cid: int = sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + sx
			_process_deaths(sid, cid, band, day, now)
			_update_cohort_mean(cid, band)
			if band >= 2 and band <= 3 and sx == 0:
				_process_births(sid, cid, band, day, now)
	if weekly:
		_process_marriages(sid, day, now)
		_process_job_changes(sid, day, now)
		weekly_batches += 1
	records.settlement_last_bg_day[sid] = day
	records.settlement_batches[sid] += 1
	batch_count += 1
	daily_batches += 1
	scheduler.push(now + BConfig.TICKS_PER_DAY, BKinds.EVENT_SETTLEMENT_BATCH, sid)


func _process_deaths(sid: int, cid: int, band: int, day: int, now: int) -> void:
	var count: int = records.cohort_counts[cid]
	if count <= 0:
		return
	var expected: float = float(count) * config.mortality[band] / float(BConfig.YEAR_DAYS)
	var n: int = int(expected)
	if BHash.unit4(sid, day, cid, 0xDE ^ config.seed) < (expected - float(n)):
		n += 1
	n = mini(n, 4)
	for k in n:
		var key: int = BHash.hash4(sid, day, cid, (k + 1) ^ config.seed)
		var row: int = records.pick_live_row(cid, key)
		if row < 0:
			break
		_kill(row, sid, cid, band, day, now)


func _kill(row: int, sid: int, cid: int, band: int, day: int, now: int) -> void:
	var aid: int = records.ids[row]
	records.alive[row] = 0
	records.death_day[row] = day
	records.health[row] = 0.0
	records.cohort_counts[cid] -= 1
	records.settlement_population[sid] -= 1
	var partner: int = records.partner_id[row]
	if partner > 0:
		var prow: int = records.row_for_id(partner)
		if prow >= 0 and records.partner_id[prow] == aid:
			records.partner_id[prow] = 0
	if detail != null:
		detail.on_death(row, now)
	var eid: int = key_log.emit(BKeyLog.TYPE_DEATH, now, aid, 0, sid, band)
	_touch_key(row, eid, day)
	records.settlement_last_key_day[sid] = day
	death_events += 1


func _process_births(sid: int, cid: int, band: int, day: int, now: int) -> void:
	var count: int = records.cohort_counts[cid]
	if count <= 0:
		return
	var expected: float = float(count) * config.birth_rate_per_female_day
	var n: int = int(expected)
	if BHash.unit4(sid, day, cid, 0xB1 ^ config.seed) < (expected - float(n)):
		n += 1
	n = mini(n, 3)
	for k in n:
		var row: int = records.pick_live_row(cid, BHash.hash4(sid, day, cid, (k + 11) ^ config.seed))
		if row < 0:
			break
		var age: int = records.age_years_now(row, now)
		if age < 15 or age > 40:
			continue
		var father_row: int = -1
		var partner: int = records.partner_id[row]
		if partner > 0:
			father_row = records.row_for_id(partner)
			if father_row >= 0 and records.alive[father_row] == 0:
				father_row = -1
		var mother_id: int = records.ids[row]
		var father_id: int = records.ids[father_row] if father_row >= 0 else 0
		var child_row: int = records.spawn_child(row, father_row, now, config)
		var child_id: int = records.ids[child_row]
		var eid: int = key_log.emit(BKeyLog.TYPE_BIRTH, now, child_id,
			mother_id, sid, father_id)
		_touch_key(child_row, eid, day)
		_touch_key(row, eid, day)
		records.settlement_last_key_day[sid] = day
		birth_events += 1


func _process_marriages(sid: int, day: int, now: int) -> void:
	var adults: int = 0
	for band in range(2, 5):
		adults += records.cohort_counts[sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2]
		adults += records.cohort_counts[sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + 1]
	var eligible_pairs: float = float(adults) * 0.15
	var expected: float = eligible_pairs * config.marriage_rate_per_eligible_week
	var n: int = int(expected)
	if BHash.unit3(sid, day, 0xAA11 ^ config.seed) < (expected - float(n)):
		n += 1
	n = mini(n, 3)
	for k in n:
		var female: int = _pick_unpartnered(sid, 0, BHash.hash3(sid, day, (k + 21) ^ config.seed), now)
		var male: int = _pick_unpartnered(sid, 1, BHash.hash3(sid, day, (k + 41) ^ config.seed), now)
		if female < 0 or male < 0:
			break
		var fa: int = records.ids[female]
		var ma: int = records.ids[male]
		records.partner_id[female] = ma
		records.partner_id[male] = fa
		var eid: int = key_log.emit(BKeyLog.TYPE_MARRIAGE, now, fa, ma, sid, 0)
		_touch_key(female, eid, day)
		_touch_key(male, eid, day)
		records.settlement_last_key_day[sid] = day
		marriage_events += 1


func _pick_unpartnered(sid: int, sx: int, key: int, now: int) -> int:
	for attempt in 24:
		var band: int = 2 + ((key + attempt * 7) % 3)
		var cid: int = sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + sx
		var row: int = records.pick_live_row(cid, key + attempt * 13)
		if row < 0:
			continue
		var age: int = records.age_years_now(row, now)
		if age >= 18 and age <= 59 and records.partner_id[row] == 0:
			return row
	return -1


func _process_job_changes(sid: int, day: int, now: int) -> void:
	var workers: int = 0
	for band in range(2, 5):
		workers += records.cohort_counts[sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2]
		workers += records.cohort_counts[sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + 1]
	var expected: float = float(workers) * 0.7 * config.job_change_rate_per_worker_week
	var n: int = int(expected)
	if BHash.unit3(sid, day, 0xBB22 ^ config.seed) < (expected - float(n)):
		n += 1
	n = mini(n, 8)
	for k in n:
		var row: int = _pick_worker(sid, BHash.hash3(sid, day, (k + 31) ^ config.seed), now)
		if row < 0:
			break
		var kind: int = 1 + (BHash.hash3(records.ids[row], day, 0xCC33 ^ config.seed) % 3)
		records.job_kind[row] = kind
		records.job_id[row] = sid * 10000 + kind * 1000 + (BHash.hash3(records.ids[row], day, config.seed) % 1000)
		records.last_job_change_day[row] = day
		var eid: int = key_log.emit(BKeyLog.TYPE_JOB_CHANGE, now, records.ids[row], 0, sid, kind)
		_touch_key(row, eid, day)
		records.settlement_last_key_day[sid] = day
		job_change_events += 1


func _pick_worker(sid: int, key: int, now: int) -> int:
	for attempt in 24:
		var band: int = 2 + ((key + attempt * 5) % 3)
		var sx: int = (key + attempt) & 1
		var cid: int = sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + sx
		var row: int = records.pick_live_row(cid, key + attempt * 17)
		if row < 0:
			continue
		var age: int = records.age_years_now(row, now)
		if age >= 18 and age <= 59 and records.job_kind[row] != BConfig.JOB_NONE:
			return row
	return -1


func _touch_key(row: int, eid: int, day: int) -> void:
	records.last_key_day[row] = day
	records.key_event_count[row] += 1
	records.key_event_hash[row] = HashUtil.mix(records.key_event_hash[row], eid)


func _update_cohort_mean(cid: int, band: int) -> void:
	records.cohort_mean_hunger[cid] = clampf(
		records.cohort_mean_hunger[cid] + config.hunger_per_day, 0.0, 100.0)
	records.cohort_mean_energy[cid] = clampf(
		records.cohort_mean_energy[cid] - config.energy_per_day, 0.0, 100.0)
	records.cohort_mean_social[cid] = clampf(
		records.cohort_mean_social[cid] - config.social_per_day, 0.0, 100.0)
	records.cohort_mean_hygiene[cid] = clampf(
		records.cohort_mean_hygiene[cid] - config.hygiene_per_day, 0.0, 100.0)
	records.cohort_mean_fun[cid] = clampf(
		records.cohort_mean_fun[cid] - config.fun_per_day, 0.0, 100.0)
	records.cohort_mean_health[cid] = clampf(
		records.cohort_mean_health[cid] - config.health_decay_adult_per_day, 0.0, 100.0)
	var band_range: Vector2i = BConfig.AGE_BANDS[band] as Vector2i
	records.cohort_mean_age[cid] = float(band_range.x)


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, batch_count)
	h = HashUtil.mix_i64(h, daily_batches)
	h = HashUtil.mix_i64(h, weekly_batches)
	h = HashUtil.mix_i64(h, death_events)
	h = HashUtil.mix_i64(h, birth_events)
	h = HashUtil.mix_i64(h, marriage_events)
	h = HashUtil.mix_i64(h, job_change_events)
	return h

