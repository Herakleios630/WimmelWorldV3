extends RefCounted

## T-G3-B-01: 100k persistent records, synthetic settlements/cohorts,
## deterministic generation.


static func run(ctx: G1aTestContext) -> void:
	_test_population(ctx)
	_test_settlements_cohorts(ctx)
	_test_determinism(ctx)


static func _test_population(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-01a", "100k Records: IDs, Rollen, Jobs, Beziehungen")
	var c: BConfig = BConfig.make(1000, 150, G3TestUtil.SEED)
	var r: BRecords = BRecords.generate(c)
	ctx.check_eq(r.count, 100000, "Record-Anzahl nicht 100k")
	ctx.check_eq(r.next_id, 100001, "next_id nicht 100001")
	var alive: int = 0
	var workers: int = 0
	var children: int = 0
	var youth: int = 0
	var adults: int = 0
	var old: int = 0
	var jobs: int = 0
	var partners: int = 0
	var parent_links: int = 0
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(100001)
	seen.fill(0)
	var unique: bool = true
	for row in r.count:
		var aid: int = r.ids[row]
		if aid < 1 or aid > 100000 or seen[aid] != 0:
			unique = false
		seen[aid] = 1
		if r.alive[row] != 0:
			alive += 1
		var age: int = r.age_years_at(row, 0)
		if age < 15:
			children += 1
		elif age < 18:
			youth += 1
		elif age < 60:
			adults += 1
		else:
			old += 1
		if r.job_kind[row] != BConfig.JOB_NONE:
			jobs += 1
		if r.partner_id[row] > 0:
			partners += 1
		if r.mother_id[row] > 0:
			parent_links += 1
	ctx.check(unique, "IDs nicht eindeutig/fortlaufend")
	ctx.check_eq(alive, 100000, "nicht alle 100k lebend")
	ctx.check(children > 10000, "zu wenige Kinder: %d" % children)
	ctx.check(youth > 2000, "zu wenige Jugendliche: %d" % youth)
	ctx.check(adults > 50000, "zu wenige Erwachsene: %d" % adults)
	ctx.check(old > 5000, "zu wenige Alte: %d" % old)
	ctx.check(jobs > 40000, "zu wenige Jobs: %d" % jobs)
	ctx.check(partners > 20000, "zu wenige Partnerbeziehungen: %d" % partners)
	ctx.check(parent_links > 10000, "zu wenige Eltern-Kind-Verknüpfungen: %d" % parent_links)
	print("G3_B_GENERATION records=%d children=%d youth=%d adults=%d old=%d jobs=%d partners=%d parents=%d mem=%d" % [
		r.count, children, youth, adults, old, jobs, partners, parent_links,
		r.memory_bytes_estimate()])


static func _test_settlements_cohorts(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-01b", "200 Siedlungen x 14 Kohorten, Summen konsistent")
	var c: BConfig = BConfig.make(1000, 150, G3TestUtil.SEED)
	var r: BRecords = BRecords.generate(c)
	ctx.check_eq(r.settlement_count, 200, "Siedlungszahl nicht 200")
	ctx.check_eq(r.cohort_total, 2800, "Kohortenzahl nicht 2800")
	var cohort_sum: int = 0
	for count in r.cohort_counts:
		cohort_sum += count
	ctx.check_eq(cohort_sum, 100000, "Kohortensumme nicht 100k")
	var pop_sum: int = 0
	var all_500: bool = true
	for sid in r.settlement_count:
		pop_sum += r.settlement_population[sid]
		if r.settlement_population[sid] != 500:
			all_500 = false
		var local: int = 0
		for k in BConfig.COHORTS_PER_SETTLEMENT:
			local += r.cohort_counts[sid * BConfig.COHORTS_PER_SETTLEMENT + k]
		if local != 500:
			all_500 = false
	ctx.check_eq(pop_sum, 100000, "Siedlungssumme nicht 100k")
	ctx.check(all_500, "nicht jede Siedlung hat 500 Agenten/Kohortensumme")
	ctx.check(r.cohort_rows.size() == 2800, "cohort_rows nicht 2800")
	var row_sum: int = 0
	for list in r.cohort_rows:
		row_sum += (list as PackedInt32Array).size()
	ctx.check_eq(row_sum, 100000, "cohort_rows-Summe nicht 100k")
	print("G3_B_SETTLEMENTS settlements=%d cohorts=%d pop_sum=%d cohort_sum=%d" % [
		r.settlement_count, r.cohort_total, pop_sum, cohort_sum])


static func _test_determinism(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-01c", "Generierung deterministisch, Seed-abhängig")
	var c: BConfig = BConfig.make(1000, 150, G3TestUtil.SEED)
	var a: BRecords = BRecords.generate(c)
	var b: BRecords = BRecords.generate(BConfig.make(1000, 150, G3TestUtil.SEED))
	ctx.check_eq(a.state_hash(), b.state_hash(), "gleicher Seed erzeugt anderen Zustand")
	var other: BRecords = BRecords.generate(BConfig.make(1000, 150, G3TestUtil.SEED + 1))
	ctx.check(a.state_hash() != other.state_hash(), "anderer Seed erzeugt gleichen Zustand")
	ctx.check_eq(a.ids[0], 1, "erste ID nicht 1")
	ctx.check_eq(a.ids[a.count - 1], 100000, "letzte ID nicht 100000")
