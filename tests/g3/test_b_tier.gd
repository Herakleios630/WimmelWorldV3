extends RefCounted

## T-G3-B-02: deterministic detail tier 1k/5k, catch-up, tier switches,
## key-event proximity, camera/follow/inspector independence.


static func run(ctx: G1aTestContext) -> void:
	_test_initial_tier(ctx)
	_test_catchup(ctx)
	_test_switches(ctx)
	_test_key_priority(ctx)
	_test_camera_independence(ctx)


static func _test_initial_tier(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-02a", "Detailtier 1k/5k exakt und deterministisch")
	for target in [1000, 5000]:
		var a: BSim = G3TestUtil.new_sim(target, 150, G3TestUtil.SEED)
		var b: BSim = G3TestUtil.new_sim(target, 150, G3TestUtil.SEED)
		ctx.check_eq(a.detail_count(), target,
			"Detailtier %d nicht exakt: %d" % [target, a.detail_count()])
		ctx.check_eq(a.tier_selector.detail_rows.size(), target,
			"detail_rows != %d" % target)
		var tier1: int = 0
		var bad_tier: int = 0
		for row in a.records.count:
			if a.records.tier[row] != 0:
				tier1 += 1
				if a.records.alive[row] == 0:
					bad_tier += 1
		ctx.check_eq(tier1, target, "tier==1 nicht %d" % target)
		ctx.check_eq(bad_tier, 0, "tote Agenten im Detailtier")
		ctx.check_eq(a.tier_hash(), b.tier_hash(), "Tier nicht deterministisch (%d)" % target)
		ctx.check_eq(a.tier_selector.detail_set_hash, b.tier_selector.detail_set_hash,
			"Detail-Set-Hash nicht deterministisch (%d)" % target)
		print("G3_B_TIER_INITIAL target=%d actual=%d hash=%s state=%s" % [
			target, a.detail_count(), HashUtil.hex(a.tier_hash()),
			HashUtil.hex(a.state_hash())])


static func _test_catchup(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-02b", "Promotion/Demotion: Catch-up ohne Teleport")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	var row: int = -1
	for r in sim.records.count:
		if sim.records.alive[r] != 0 and sim.records.tier[r] == 0 \
				and sim.records.activity[r] == BConfig.ACTIVITY_IDLE:
			row = r
			break
	ctx.check(row >= 0, "kein Hintergrundagent für Catch-up gefunden")
	if row < 0:
		return
	var before_x: float = sim.records.pos_x[row]
	var before_y: float = sim.records.pos_y[row]
	var gen_before: int = sim.records.wake_gen[row]
	var now: int = sim.clock.now
	sim.detail.on_promote(row, now)
	ctx.check_eq(sim.records.tier[row], 1, "Promotion setzt tier nicht 1")
	ctx.check_eq(sim.records.need_time[row], now, "Catch-up materialisiert Needs nicht")
	ctx.check(sim.records.next_event[row] > now, "Promotion plant keinen Wake")
	ctx.check_close(sim.records.pos_x[row], before_x, 0.0001, "Promotion versetzt X")
	ctx.check_close(sim.records.pos_y[row], before_y, 0.0001, "Promotion versetzt Y")
	ctx.check_eq(sim.records.wake_gen[row], gen_before + 1, "Promotion erhöht wake_gen nicht")
	sim.detail.on_demote(row, now + 100)
	ctx.check_eq(sim.records.tier[row], 0, "Demotion setzt tier nicht 0")
	ctx.check_eq(sim.records.next_event[row], 0, "Demotion lässt Wake stehen")
	ctx.check_close(sim.records.pos_x[row], before_x, 0.0001, "Demotion versetzt X")
	ctx.check_close(sim.records.pos_y[row], before_y, 0.0001, "Demotion versetzt Y")
	# Demotion während einer Reise friert die interpolierte Position ein.
	var travel_row: int = -1
	for r in sim.records.count:
		if sim.records.alive[r] != 0 and sim.records.tier[r] == 0:
			travel_row = r
			break
	ctx.check(travel_row >= 0, "kein Agent für Reise-Demotion")
	if travel_row >= 0:
		sim.records.activity[travel_row] = BConfig.ACTIVITY_TRAVEL
		sim.records.travel_depart[travel_row] = 0
		sim.records.travel_arrive[travel_row] = 1000
		sim.records.travel_start_x[travel_row] = 0.0
		sim.records.travel_start_y[travel_row] = 0.0
		sim.records.travel_end_x[travel_row] = 100.0
		sim.records.travel_end_y[travel_row] = 0.0
		sim.records.pos_x[travel_row] = 0.0
		sim.records.pos_y[travel_row] = 0.0
		sim.records.tier[travel_row] = 1
		sim.records.wake_gen[travel_row] = 3
		sim.detail.on_demote(travel_row, 500)
		ctx.check_close(sim.records.pos_x[travel_row], 50.0, 0.01,
			"Reise-Demotion nicht interpoliert")
		ctx.check_close(sim.records.pos_y[travel_row], 0.0, 0.01,
			"Reise-Demotion Y nicht interpoliert")
		ctx.check(sim.records.pos_x[travel_row] >= 0.0
			and sim.records.pos_x[travel_row] <= 100.0,
			"Reise-Demotion springt aus dem Segment")


static func _test_switches(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-02c", "Tier-Wechsel über 3 Tage, Größe bleibt konstant")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(sim, G3TestUtil.abs_time(3, 0, 0), 300)
	var ts: Dictionary = sim.tier_stats()
	ctx.check(int(ts.get("switches", 0)) > 0, "keine Tier-Wechsel")
	ctx.check(int(ts.get("promotions", 0)) > 0, "keine Promotions")
	ctx.check(int(ts.get("demotions", 0)) > 0, "keine Demotions")
	ctx.check_eq(sim.detail_count(), 1000, "Detailgröße nach Wechseln nicht 1000")
	var tier1: int = 0
	var bad: int = 0
	for row in sim.records.count:
		if sim.records.tier[row] != 0:
			tier1 += 1
			if sim.records.alive[row] == 0:
				bad += 1
	ctx.check_eq(tier1, 1000, "tier==1 nach 3 Tagen nicht 1000")
	ctx.check_eq(bad, 0, "tote Agenten im Detailtier nach 3 Tagen")
	print("G3_B_TIER_SWITCHES %s detail=%d" % [str(ts), sim.detail_count()])


static func _test_key_priority(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-02d", "Ereignisnähe: Key-Agenten werden promoviert")
	var sim: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	G3TestUtil.advance_chunked(sim, G3TestUtil.abs_time(4, 0, 0), 300)
	var mark: PackedByteArray = G3TestUtil.detail_row_set(sim)
	var checked: int = 0
	var selected: int = 0
	for row in sim.records.count:
		if sim.records.alive[row] == 0:
			continue
		var day: int = sim.records.last_key_day[row]
		if day >= 1 and day <= 2:
			checked += 1
			if mark[row] != 0:
				selected += 1
	ctx.check(checked > 0, "keine Key-Agenten aus Tag 1-2 gefunden")
	ctx.check_eq(selected, checked, "nicht alle Key-Agenten sind im Detailtier")
	print("G3_B_KEY_PRIORITY checked=%d selected=%d detail=%d" % [
		checked, selected, sim.detail_count()])


static func _test_camera_independence(ctx: G1aTestContext) -> void:
	ctx.begin("T-G3-B-02e", "Follow/Inspector ändert keine Tier-Auswahl")
	var a: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	var b: BSim = G3TestUtil.new_sim(1000, 150, G3TestUtil.SEED)
	var target: int = G3TestUtil.abs_time(2, 0, 0)
	var step: int = 60
	var tick: int = 0
	while a.clock.now < target:
		var t: int = mini(target, a.clock.now + step)
		a.advance_to(t)
		b.advance_to(t)
		a.set_view_focus(a.records.ids[(tick * 37) % a.records.count])
		a.set_inspector(a.records.ids[(tick * 53 + 11) % a.records.count])
		tick += 1
	ctx.check_eq(a.state_hash(), b.state_hash(), "View-Fokus ändert State")
	ctx.check_eq(a.event_hash(), b.event_hash(), "View-Fokus ändert Events")
	ctx.check_eq(a.tier_hash(), b.tier_hash(), "View-Fokus ändert Tier")
	ctx.check_eq(a.tier_selector.detail_set_hash, b.tier_selector.detail_set_hash,
		"View-Fokus ändert Detail-Set")
	var tiers_equal: bool = true
	for row in a.records.count:
		if a.records.tier[row] != b.records.tier[row]:
			tiers_equal = false
			break
	ctx.check(tiers_equal, "View-Fokus ändert tier-Array")
	print("G3_B_CAMERA state=%s tier=%s focus=%d inspector=%d" % [
		HashUtil.hex(a.state_hash()), HashUtil.hex(a.tier_hash()),
		a.view_focus(), a.inspector()])
