class_name BRecords
extends RefCounted

## Persistent B records for 100k agents: SoA hot state plus compact cold
## identity/lifecycle fields. IDs are stable and never reused. Dead agents stay
## as records (with death_day) so identities and key events are never lost.
##
## Background agents keep lazy needs/health materialisation; detail agents are
## updated on their own wake events. Tier membership is stored but always
## derived deterministically by BTierSelector at epoch boundaries.

const BAND_COUNT: int = 7
const SEXES: int = 2

var count: int = 0
var next_id: int = 1
var gen_seed: int = 0

var ids: PackedInt32Array = PackedInt32Array()
var alive: PackedByteArray = PackedByteArray()
var sex: PackedByteArray = PackedByteArray()
var settlement_id: PackedInt32Array = PackedInt32Array()
var household_id: PackedInt32Array = PackedInt32Array()
var home_id: PackedInt32Array = PackedInt32Array()
var job_id: PackedInt32Array = PackedInt32Array()
var job_kind: PackedByteArray = PackedByteArray()
var role: PackedByteArray = PackedByteArray()
var cohort_id: PackedInt32Array = PackedInt32Array()
var birth_day: PackedInt32Array = PackedInt32Array()
var death_day: PackedInt32Array = PackedInt32Array()
var health: PackedFloat32Array = PackedFloat32Array()
var partner_id: PackedInt32Array = PackedInt32Array()
var mother_id: PackedInt32Array = PackedInt32Array()
var father_id: PackedInt32Array = PackedInt32Array()

var need_time: PackedInt32Array = PackedInt32Array()
var hunger: PackedFloat32Array = PackedFloat32Array()
var energy: PackedFloat32Array = PackedFloat32Array()
var social: PackedFloat32Array = PackedFloat32Array()
var hygiene: PackedFloat32Array = PackedFloat32Array()
var fun: PackedFloat32Array = PackedFloat32Array()

var activity: PackedByteArray = PackedByteArray()
var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_y: PackedFloat32Array = PackedFloat32Array()
var travel_depart: PackedInt32Array = PackedInt32Array()
var travel_arrive: PackedInt32Array = PackedInt32Array()
var travel_start_x: PackedFloat32Array = PackedFloat32Array()
var travel_start_y: PackedFloat32Array = PackedFloat32Array()
var travel_end_x: PackedFloat32Array = PackedFloat32Array()
var travel_end_y: PackedFloat32Array = PackedFloat32Array()
var next_event: PackedInt64Array = PackedInt64Array()
var wake_gen: PackedInt32Array = PackedInt32Array()

var tier: PackedByteArray = PackedByteArray()
var last_job_change_day: PackedInt32Array = PackedInt32Array()
var last_key_day: PackedInt32Array = PackedInt32Array()
var key_event_count: PackedInt32Array = PackedInt32Array()
var key_event_hash: PackedInt32Array = PackedInt32Array()

var row_of_id: PackedInt32Array = PackedInt32Array()

# Settlement/cohort aggregates (authoritative background model).
var settlement_count: int = 0
var cohort_total: int = 0
var settlement_center_x: PackedFloat32Array = PackedFloat32Array()
var settlement_center_y: PackedFloat32Array = PackedFloat32Array()
var settlement_population: PackedInt32Array = PackedInt32Array()
var settlement_last_key_day: PackedInt32Array = PackedInt32Array()
var settlement_last_bg_day: PackedInt32Array = PackedInt32Array()
var settlement_batches: PackedInt32Array = PackedInt32Array()

var cohort_counts: PackedInt32Array = PackedInt32Array()
var cohort_mean_hunger: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_energy: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_social: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_hygiene: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_fun: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_health: PackedFloat32Array = PackedFloat32Array()
var cohort_mean_age: PackedFloat32Array = PackedFloat32Array()

# Derived index, rebuilt on load. Array of PackedInt32Array in row order.
var cohort_rows: Array = []


static func generate(config: BConfig) -> BRecords:
	var r: BRecords = BRecords.new()
	r.gen_seed = config.seed
	r.settlement_count = config.settlement_count
	r.cohort_total = config.cohort_count()
	r._init_aggregates(config)
	r.row_of_id.resize(config.population + 1)
	for i in r.row_of_id.size():
		r.row_of_id[i] = -1
	for sid in config.settlement_count:
		r._generate_settlement(sid, config)
	r.next_id = config.population + 1
	return r


func _init_aggregates(config: BConfig) -> void:
	settlement_center_x.resize(settlement_count)
	settlement_center_y.resize(settlement_count)
	settlement_population.resize(settlement_count)
	settlement_last_key_day.resize(settlement_count)
	settlement_last_bg_day.resize(settlement_count)
	settlement_batches.resize(settlement_count)
	for sid in settlement_count:
		var gx: int = sid % 20
		var gy: int = sid / 20
		settlement_center_x[sid] = float(gx * 240 + 120)
		settlement_center_y[sid] = float(gy * 240 + 120)
		settlement_population[sid] = 0
		settlement_last_key_day[sid] = -1
		settlement_last_bg_day[sid] = -1
		settlement_batches[sid] = 0
	cohort_counts.resize(cohort_total)
	cohort_mean_hunger.resize(cohort_total)
	cohort_mean_energy.resize(cohort_total)
	cohort_mean_social.resize(cohort_total)
	cohort_mean_hygiene.resize(cohort_total)
	cohort_mean_fun.resize(cohort_total)
	cohort_mean_health.resize(cohort_total)
	cohort_mean_age.resize(cohort_total)
	for c in cohort_total:
		cohort_counts[c] = 0
		cohort_mean_hunger[c] = 55.0
		cohort_mean_energy[c] = 65.0
		cohort_mean_social[c] = 60.0
		cohort_mean_hygiene[c] = 65.0
		cohort_mean_fun[c] = 60.0
		cohort_mean_health[c] = 85.0
		var band: int = (c % BConfig.COHORTS_PER_SETTLEMENT) / 2
		cohort_mean_age[c] = float((BConfig.AGE_BANDS[band] as Vector2i).x)
	cohort_rows.resize(cohort_total)
	for c in cohort_total:
		cohort_rows[c] = PackedInt32Array()


func _generate_settlement(sid: int, config: BConfig) -> void:
	var size: int = config.settlement_size()
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(BAND_COUNT)
	var used: int = 0
	for band in BAND_COUNT:
		var q: int = int(round(float(size) * float(BConfig.BAND_WEIGHTS[band]) / 100.0))
		if band == BAND_COUNT - 1:
			q = size - used
		quotas[band] = q
		used += q
	var remaining: PackedInt32Array = quotas.duplicate()
	var taken: PackedInt32Array = PackedInt32Array()
	taken.resize(BAND_COUNT)
	for band in BAND_COUNT:
		taken[band] = 0
	var rows: PackedInt32Array = PackedInt32Array()
	while rows.size() < size:
		for band in BAND_COUNT:
			if remaining[band] <= 0:
				continue
			var half: int = int(quotas[band] / 2)
			var sx: int = 0 if taken[band] < half else 1
			if quotas[band] % 2 == 1 and taken[band] >= half and taken[band] >= quotas[band] - 1:
				sx = 1
			var row: int = _make_initial_row(sid, band, sx, config)
			rows.append(row)
			taken[band] += 1
			remaining[band] -= 1
			if rows.size() >= size:
				break
	_assign_households(sid, rows, config)


func _make_initial_row(sid: int, band: int, sx: int, config: BConfig) -> int:
	var id: int = count + 1
	var band_range: Vector2i = BConfig.AGE_BANDS[band] as Vector2i
	var span: int = band_range.y - band_range.x + 1
	if band == BAND_COUNT - 1:
		span = 21  # 75..95, avoid implausible 120-year-olds
	var age: int = band_range.x + (BHash.hash3(id, sid, 0x41A7 ^ config.seed) % span)
	var birth: int = -(age * BConfig.YEAR_DAYS
		+ (BHash.hash3(id, 0xB117, config.seed) % BConfig.YEAR_DAYS))
	var h: int = BHash.hash3(id, 0x9E37, config.seed)
	var health_value: float = clampf(92.0 - float(age) * 0.35 + float(h % 1700) / 100.0, 10.0, 100.0)
	var cid: int = sid * BConfig.COHORTS_PER_SETTLEMENT + band * 2 + sx
	var household: int = sid * 10000
	var home: int = sid * 1000
	var pos: Vector2 = _home_point(sid, home)
	var job: int = _initial_job(id, age, sid, config)
	var rr: int = role_for_age(age)
	var nt: int = config.start_time
	var row: int = _append_row(id, sx, sid, household, home, job,
		job_kind_for_job(job), rr, cid, birth, health_value, 0, 0, 0,
		pos.x, pos.y, nt, config)
	settlement_population[sid] += 1
	cohort_counts[cid] += 1
	var list: PackedInt32Array = cohort_rows[cid]
	list.append(row)
	cohort_rows[cid] = list
	return row


func _assign_households(sid: int, rows: PackedInt32Array, config: BConfig) -> void:
	var i: int = 0
	var hh_index: int = 0
	var homes: int = 50
	while i < rows.size():
		var hh_size: int = 2 + (BHash.hash4(sid, hh_index, 0x77, config.seed) % 4)
		if i + hh_size > rows.size():
			hh_size = rows.size() - i
		var household: int = sid * 10000 + hh_index
		var home: int = sid * 1000 + (hh_index % homes)
		var pos: Vector2 = _home_point(sid, home)
		var adult_female: int = -1
		var adult_male: int = -1
		for k in hh_size:
			var row: int = rows[i + k]
			household_id[row] = household
			home_id[row] = home
			pos_x[row] = pos.x
			pos_y[row] = pos.y
			var age: int = age_years_at(row, 0)
			if age >= 18 and age <= 59:
				if sex[row] == 0 and adult_female < 0:
					adult_female = row
				elif sex[row] == 1 and adult_male < 0:
					adult_male = row
		if adult_female >= 0 and adult_male >= 0:
			partner_id[adult_female] = ids[adult_male]
			partner_id[adult_male] = ids[adult_female]
		for k in hh_size:
			var row: int = rows[i + k]
			if sex[row] == 0 and age_years_at(row, 0) < 18:
				mother_id[row] = ids[adult_female] if adult_female >= 0 else 0
				father_id[row] = ids[adult_male] if adult_male >= 0 else 0
			elif sex[row] == 1 and age_years_at(row, 0) < 18:
				mother_id[row] = ids[adult_female] if adult_female >= 0 else 0
				father_id[row] = ids[adult_male] if adult_male >= 0 else 0
		i += hh_size
		hh_index += 1
	_pair_settlement_adults(sid, rows, config)


func _pair_settlement_adults(sid: int, rows: PackedInt32Array, config: BConfig) -> void:
	var females: PackedInt32Array = PackedInt32Array()
	var males: PackedInt32Array = PackedInt32Array()
	for row in rows:
		if alive[row] == 0 or partner_id[row] != 0:
			continue
		var age: int = age_years_at(row, 0)
		if age < 18 or age > 59:
			continue
		if sex[row] == 0:
			females.append(row)
		else:
			males.append(row)
	var n: int = mini(females.size(), males.size())
	if n <= 0:
		return
	var take: int = int(float(n) * 0.7)
	var off_f: int = BHash.hash3(sid, 0xF1, config.seed) % females.size()
	var off_m: int = BHash.hash3(sid, 0xF2, config.seed) % males.size()
	for k in take:
		var frow: int = females[(off_f + k) % females.size()]
		var mrow: int = males[(off_m + k) % males.size()]
		if partner_id[frow] == 0 and partner_id[mrow] == 0:
			partner_id[frow] = ids[mrow]
			partner_id[mrow] = ids[frow]


func _home_point(sid: int, home: int) -> Vector2:
	var ox: int = (BHash.hash4(sid, home, 0x11, gen_seed) % 160) - 80
	var oy: int = (BHash.hash4(sid, home, 0x22, gen_seed) % 160) - 80
	return Vector2(settlement_center_x[sid] + float(ox), settlement_center_y[sid] + float(oy))


func home_point(home: int) -> Vector2:
	var sid: int = home / 1000
	if sid < 0 or sid >= settlement_count:
		return Vector2.ZERO
	return _home_point(sid, home)


func work_point(job: int) -> Vector2:
	var sid: int = job / 10000
	if sid < 0 or sid >= settlement_count:
		return Vector2.ZERO
	var ox: int = (BHash.hash2(job, 0x66) % 120) - 60
	var oy: int = (BHash.hash2(job, 0x77) % 120) - 60
	return Vector2(settlement_center_x[sid] + float(ox), settlement_center_y[sid] + float(oy))


func _initial_job(id: int, age: int, sid: int, config: BConfig) -> int:
	if age < 18 or age > 74:
		return 0
	var r: int = BHash.hash3(id, sid, 0x33 ^ config.seed) % 100
	var kind: int = BConfig.JOB_NONE
	if age < 60:
		if r < 55:
			kind = BConfig.JOB_FIELD
		elif r < 80:
			kind = BConfig.JOB_WORKSHOP
		elif r < 95:
			kind = BConfig.JOB_SERVICE
	else:
		if r < 30:
			kind = BConfig.JOB_SERVICE
		elif r < 50:
			kind = BConfig.JOB_WORKSHOP
	if kind == BConfig.JOB_NONE:
		return 0
	return sid * 10000 + kind * 1000 + (BHash.hash3(id, 0x44, config.seed) % 1000)


static func job_kind_for_job(job: int) -> int:
	if job <= 0:
		return BConfig.JOB_NONE
	return (job / 1000) % 10


func _append_row(id: int, p_sex: int, sid: int, household: int, home: int,
		job: int, job_kind_value: int, p_role: int, cid: int, birth: int,
		health_value: float, partner: int, mother: int, father: int,
		px: float, py: float, nt: int, config: BConfig) -> int:
	var row: int = count
	count += 1
	ids.append(id)
	alive.append(1)
	sex.append(p_sex)
	settlement_id.append(sid)
	household_id.append(household)
	home_id.append(home)
	job_id.append(job)
	job_kind.append(job_kind_value)
	role.append(p_role)
	cohort_id.append(cid)
	birth_day.append(birth)
	death_day.append(-1)
	health.append(health_value)
	partner_id.append(partner)
	mother_id.append(mother)
	father_id.append(father)
	need_time.append(nt)
	var hv: int = BHash.hash3(id, 0x55, config.seed)
	hunger.append(float(40 + hv % 45))
	energy.append(float(50 + (hv >> 3) % 45))
	social.append(float(45 + (hv >> 6) % 45))
	hygiene.append(float(50 + (hv >> 9) % 45))
	fun.append(float(45 + (hv >> 12) % 45))
	activity.append(BConfig.ACTIVITY_IDLE)
	pos_x.append(px)
	pos_y.append(py)
	travel_depart.append(0)
	travel_arrive.append(0)
	travel_start_x.append(px)
	travel_start_y.append(py)
	travel_end_x.append(px)
	travel_end_y.append(py)
	next_event.append(0)
	wake_gen.append(0)
	tier.append(0)
	last_job_change_day.append(-1)
	last_key_day.append(-1)
	key_event_count.append(0)
	key_event_hash.append(HashUtil.FNV_OFFSET)
	if id >= row_of_id.size():
		var old_size: int = row_of_id.size()
		row_of_id.resize(id + 1)
		for j in range(old_size, id + 1):
			row_of_id[j] = -1
	row_of_id[id] = row
	if id >= next_id:
		next_id = id + 1
	return row


func spawn_child(mother_row: int, father_row: int, now: int, config: BConfig) -> int:
	var sid: int = settlement_id[mother_row]
	var child_id: int = next_id
	next_id += 1
	var sx: int = BHash.hash3(child_id, 0xC11D, config.seed) & 1
	var cid: int = sid * BConfig.COHORTS_PER_SETTLEMENT + sx
	var home: int = home_id[mother_row]
	var household: int = household_id[mother_row]
	var px: float = pos_x[mother_row]
	var py: float = pos_y[mother_row]
	var birth: int = now / BConfig.TICKS_PER_DAY
	var row: int = _append_row(child_id, sx, sid, household, home, 0,
		BConfig.JOB_NONE, BConfig.ROLE_CHILD, cid, birth, 100.0,
		0, ids[mother_row], ids[father_row] if father_row >= 0 else 0,
		px, py, now, config)
	settlement_population[sid] += 1
	cohort_counts[cid] += 1
	var list: PackedInt32Array = cohort_rows[cid]
	list.append(row)
	cohort_rows[cid] = list
	hunger[row] = 70.0
	energy[row] = 90.0
	social[row] = 75.0
	hygiene[row] = 85.0
	fun[row] = 75.0
	return row


func row_for_id(p_id: int) -> int:
	if p_id <= 0 or p_id >= row_of_id.size():
		return -1
	return row_of_id[p_id]


func is_alive(row: int) -> bool:
	return row >= 0 and row < count and alive[row] != 0


func age_years_at(row: int, day: int) -> int:
	var v: int = day - birth_day[row]
	if v < 0:
		return 0
	return v / BConfig.YEAR_DAYS


func age_years_now(row: int, now: int) -> int:
	return age_years_at(row, now / BConfig.TICKS_PER_DAY)


static func role_for_age(age: int) -> int:
	if age < 15:
		return BConfig.ROLE_CHILD
	if age < 18:
		return BConfig.ROLE_YOUTH
	if age < 60:
		return BConfig.ROLE_ADULT
	return BConfig.ROLE_OLD


static func band_for_age(age: int) -> int:
	if age <= 4:
		return 0
	if age <= 14:
		return 1
	if age <= 29:
		return 2
	if age <= 44:
		return 3
	if age <= 59:
		return 4
	if age <= 74:
		return 5
	return 6


func materialize_needs(row: int, now: int, config: BConfig) -> void:
	var dt: int = now - need_time[row]
	if dt <= 0:
		return
	var days: float = float(dt) / float(BConfig.TICKS_PER_DAY)
	hunger[row] = clampf(hunger[row] + config.hunger_per_day * days, 0.0, 100.0)
	energy[row] = clampf(energy[row] - config.energy_per_day * days, 0.0, 100.0)
	social[row] = clampf(social[row] - config.social_per_day * days, 0.0, 100.0)
	hygiene[row] = clampf(hygiene[row] - config.hygiene_per_day * days, 0.0, 100.0)
	fun[row] = clampf(fun[row] - config.fun_per_day * days, 0.0, 100.0)
	var age: int = age_years_now(row, now)
	var decay: float = config.health_decay_old_per_day if age >= 60 else config.health_decay_adult_per_day
	health[row] = clampf(health[row] - decay * days, 0.0, 100.0)
	need_time[row] = now


func pick_live_row(cid: int, key: int) -> int:
	var list: PackedInt32Array = cohort_rows[cid]
	var n: int = list.size()
	if n == 0:
		return -1
	var start: int = key % n
	for k in n:
		var row: int = list[(start + k) % n]
		if alive[row] != 0:
			return row
	return -1


func memory_bytes_estimate() -> int:
	var bytes: int = 0
	bytes += count * 4  # ids
	bytes += count * 1  # alive
	bytes += count * 1  # sex
	bytes += count * 4 * 6  # settlement, household, home, job, cohort, birth
	bytes += count * 1 * 3  # job_kind, role, activity
	bytes += count * 4 * 2  # death_day, need_time
	bytes += count * 4 * 8  # health, hunger, energy, social, hygiene, fun, pos x/y
	bytes += count * 4 * 3  # partner, mother, father
	bytes += count * 4 * 6  # travel depart/arrive + 4 f32
	bytes += count * 8  # next_event
	bytes += count * 4 * 8  # wake_gen, tier, last_job, last_key, count, hash, ...
	bytes += cohort_total * 4 * 2
	bytes += cohort_total * 4 * 7
	return bytes


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	h = HashUtil.mix_i64(h, count)
	h = HashUtil.mix_i64(h, next_id)
	for i in count:
		h = HashUtil.mix(h, ids[i])
		h = HashUtil.mix(h, alive[i])
		h = HashUtil.mix(h, sex[i])
		h = HashUtil.mix(h, settlement_id[i])
		h = HashUtil.mix(h, household_id[i])
		h = HashUtil.mix(h, home_id[i])
		h = HashUtil.mix(h, job_id[i])
		h = HashUtil.mix(h, job_kind[i])
		h = HashUtil.mix(h, role[i])
		h = HashUtil.mix(h, cohort_id[i])
		h = HashUtil.mix_i64(h, birth_day[i])
		h = HashUtil.mix_i64(h, death_day[i])
		h = HashUtil.mix(h, BHash.f32_bits(health[i]))
		h = HashUtil.mix(h, partner_id[i])
		h = HashUtil.mix(h, mother_id[i])
		h = HashUtil.mix(h, father_id[i])
		h = HashUtil.mix_i64(h, need_time[i])
		h = HashUtil.mix(h, BHash.f32_bits(hunger[i]))
		h = HashUtil.mix(h, BHash.f32_bits(energy[i]))
		h = HashUtil.mix(h, BHash.f32_bits(social[i]))
		h = HashUtil.mix(h, BHash.f32_bits(hygiene[i]))
		h = HashUtil.mix(h, BHash.f32_bits(fun[i]))
		h = HashUtil.mix(h, activity[i])
		h = HashUtil.mix(h, BHash.f32_bits(pos_x[i]))
		h = HashUtil.mix(h, BHash.f32_bits(pos_y[i]))
		h = HashUtil.mix_i64(h, travel_depart[i])
		h = HashUtil.mix_i64(h, travel_arrive[i])
		h = HashUtil.mix(h, BHash.f32_bits(travel_start_x[i]))
		h = HashUtil.mix(h, BHash.f32_bits(travel_start_y[i]))
		h = HashUtil.mix(h, BHash.f32_bits(travel_end_x[i]))
		h = HashUtil.mix(h, BHash.f32_bits(travel_end_y[i]))
		h = HashUtil.mix_i64(h, next_event[i])
		h = HashUtil.mix(h, wake_gen[i])
		h = HashUtil.mix(h, tier[i])
		h = HashUtil.mix_i64(h, last_job_change_day[i])
		h = HashUtil.mix_i64(h, last_key_day[i])
		h = HashUtil.mix(h, key_event_count[i])
		h = HashUtil.mix(h, key_event_hash[i])
	for sid in settlement_count:
		h = HashUtil.mix(h, settlement_population[sid])
		h = HashUtil.mix_i64(h, settlement_last_key_day[sid])
		h = HashUtil.mix_i64(h, settlement_last_bg_day[sid])
		h = HashUtil.mix(h, settlement_batches[sid])
	for c in cohort_total:
		h = HashUtil.mix(h, cohort_counts[c])
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_hunger[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_energy[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_social[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_hygiene[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_fun[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_health[c]))
		h = HashUtil.mix(h, BHash.f32_bits(cohort_mean_age[c]))
	return h


func rebuild_index() -> void:
	row_of_id.resize(next_id)
	for i in row_of_id.size():
		row_of_id[i] = -1
	cohort_rows.resize(cohort_total)
	for c in cohort_total:
		cohort_rows[c] = PackedInt32Array()
	for row in count:
		var aid: int = ids[row]
		if aid >= row_of_id.size():
			row_of_id.resize(aid + 1)
		row_of_id[aid] = row
		var cid: int = cohort_id[row]
		if cid >= 0 and cid < cohort_total:
			var list: PackedInt32Array = cohort_rows[cid]
			list.append(row)
			cohort_rows[cid] = list

