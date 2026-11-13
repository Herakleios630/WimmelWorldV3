class_name SpikeRunner
extends RefCounted

## G0.5-Orchestrierung: führt die Szenarien aus und schreibt JSON/CSV.
##
## Kein Gameplay, keine Optimierung. Messungen sind Wandzeit in µs über
## Time.get_ticks_usec(); Warm-up-Läufe werden verworfen, 3 Läufe sind Default.
##
## Pfad-Szenario: 2 gewertete Läufe (512²/1000 Pfade sonst zu teuer für die
## Zeitbox) + 1 Warm-up — im Bericht ausgewiesen.

const SEED: int = 1337
const REPS: int = 3
const PATH_REPS: int = 3
const PATH_WORKING_SET: int = 32
const PATH_LOCAL_MIN: int = 8
const PATH_LOCAL_MAX: int = 40

var results_dir: String = ""
var notes: Array = []


func _init() -> void:
	results_dir = ProjectSettings.globalize_path("res://bench/results")
	DirAccess.make_dir_recursive_absolute(results_dir)


func run(only: PackedStringArray) -> Dictionary:
	var t_start: int = Time.get_ticks_usec()
	var out: Dictionary = {
		"meta": _meta(),
		"scenarios": {},
		"checks": {},
	}
	var scen: Dictionary = out["scenarios"]
	if only.is_empty() or only.has("scheduler"):
		scen["scheduler"] = scenario_scheduler()
	if only.is_empty() or only.has("soa"):
		scen["soa"] = scenario_soa()
	if only.is_empty() or only.has("needs"):
		scen["needs"] = scenario_needs()
	if only.is_empty() or only.has("path"):
		scen["path"] = scenario_path()
	if only.is_empty() or only.has("batch"):
		scen["batch"] = scenario_batch()
	if only.is_empty() or only.has("save"):
		scen["save"] = scenario_save()
	if only.is_empty() or only.has("repeat"):
		scen["repeat"] = scenario_repeat()
	if only.is_empty() or only.has("render"):
		scen["render"] = scenario_render()
	if only.is_empty() or only.has("native"):
		scen["native"] = scenario_native()
	out["notes"] = notes
	out["checks"] = _checks(out)
	out["meta"]["total_ms"] = float(Time.get_ticks_usec() - t_start) / 1000.0
	_write_json("spike_results.json", out)
	_write_csvs(out)
	return out


# ---------------------------------------------------------------------------
# 1) Scheduler
# ---------------------------------------------------------------------------

func scenario_scheduler() -> Dictionary:
	var batch: SpikeBatch = SpikeBatch.new()
	var rows: Array = []
	for n in [10000, 100000]:
		for burst in [0, 10, 50, 100]:
			var seed_value: int = SEED + n + burst * 97
			var events: PackedInt32Array = batch.make_scheduler_events(n, seed_value, burst)
			var runs: Array = []
			var warm_ok: bool = false
			for rep in range(REPS + 1):
				var sched: SpikeScheduler = SpikeScheduler.new()
				var t0: int = Time.get_ticks_usec()
				for i in n:
					sched.push(events[i * 3 + 1], events[i * 3], events[i * 3 + 2])
				var t1: int = Time.get_ticks_usec()
				var chunk: int = 64 if n <= 10000 else 256
				var samples: PackedFloat64Array = PackedFloat64Array()
				var acc: int = 0
				var order_ok: bool = true
				var last_t: int = -1
				var last_s: int = -1
				var done: int = 0
				while done < n:
					var c: int = mini(chunk, n - done)
					var c0: int = Time.get_ticks_usec()
					for k in c:
						sched.pop()
						acc += sched.last_seq
						if sched.last_time < last_t:
							order_ok = false
						elif sched.last_time == last_t and sched.last_seq < last_s:
							order_ok = false
						last_t = sched.last_time
						last_s = sched.last_seq
					var c1: int = Time.get_ticks_usec()
					samples.append(float(c1 - c0) / float(c))
					done += c
				var t2: int = Time.get_ticks_usec()
				if rep == 0:
					warm_ok = order_ok
					continue
				var total_us: float = float(t2 - t0)
				var push_us: float = float(t1 - t0)
				var pop_us: float = float(t2 - t1)
				var st: Dictionary = stats(samples)
				runs.append({
					"rep": rep,
					"total_ms": total_us / 1000.0,
					"events_per_s": float(n) / (total_us / 1000000.0),
					"us_per_event": total_us / float(n),
					"push_us_per_event": push_us / float(n),
					"pop_us_per_event": pop_us / float(n),
					"p50_us": st["p50"],
					"p95_us": st["p95"],
					"p99_us": st["p99"],
					"max_us": st["max"],
					"checksum": acc & 0xFFFFFFFF,
					"order_ok": order_ok,
				})
			var mid: Dictionary = median_run(runs, "us_per_event")
			rows.append({
				"events": n,
				"burst_percent": burst,
				"chunk_events": 64 if n <= 10000 else 256,
				"order_ok_warmup": warm_ok,
				"median": mid,
				"runs": runs,
			})
	return {
		"rows": rows,
		"notes": "Burst=% gleiche Sim-Zeit; Perzentile sind Batch-normalisierte µs/Event (Chunk 64/256).",
	}


# ---------------------------------------------------------------------------
# 2) SoA
# ---------------------------------------------------------------------------

func scenario_soa() -> Dictionary:
	var rows: Array = []
	for n in [10, 1000, 10000, 100000]:
		var ticks: int = clampi(int(2000000 / n), 4, 100)
		var runs: Array = []
		var seed_value: int = SEED + n
		for rep in range(REPS + 1):
			var store: SpikeAgentStore = SpikeAgentStore.new()
			store.configure(n, seed_value)
			if rep == 0:
				for t in 5:
					store.tick(t * 30, 30.0)
				continue
			var samples: PackedFloat64Array = PackedFloat64Array()
			var scheduled: int = 0
			var t0: int = Time.get_ticks_usec()
			for t in ticks:
				var c0: int = Time.get_ticks_usec()
				scheduled += store.tick(t * 30, 30.0)
				var c1: int = Time.get_ticks_usec()
				samples.append(float(c1 - c0) / float(n))
			var total_us: float = float(Time.get_ticks_usec() - t0)
			var u0: int = Time.get_ticks_usec()
			for t in 5:
				store.update_needs_only(30.0)
			var u1: int = Time.get_ticks_usec()
			var update_us_agent: float = float(u1 - u0) / 5.0 / float(n)
			var st: Dictionary = stats(samples)
			runs.append({
				"rep": rep,
				"ticks": ticks,
				"total_ms": total_us / 1000.0,
				"us_per_agent_tick": total_us / float(n) / float(ticks),
				"p50_us_agent": st["p50"],
				"p95_us_agent": st["p95"],
				"p99_us_agent": st["p99"],
				"max_us_agent": st["max"],
				"update_only_us_agent": update_us_agent,
				"scheduled_events": scheduled,
				"us_per_scheduled_event": total_us / float(maxi(scheduled, 1)),
				"state_hash": store.state_hash(),
			})
		var mid: Dictionary = median_run(runs, "us_per_agent_tick")
		rows.append({
			"agents": n,
			"ticks": ticks,
			"memory_bytes": n * SpikeAgentStore.BYTES_PER_AGENT,
			"bytes_per_agent": SpikeAgentStore.BYTES_PER_AGENT,
			"median": mid,
			"runs": runs,
		})
	return {
		"rows": rows,
		"notes": "58 B/Agent SoA-Nutzlast; update_only trennt Decay von Terminplanung.",
	}


# ---------------------------------------------------------------------------
# 3) Needs / Termine
# ---------------------------------------------------------------------------

func scenario_needs() -> Dictionary:
	var reference: SpikeAgentStore = SpikeAgentStore.new()
	reference.configure(200, SEED + 4242)
	reference.tick(0, 60.0)
	var max_diff: int = 0
	var samples: Array = []
	for i in 200:
		var jitter: int = ((i * 2654435761) >> 8) % 83
		var ref_wake: float = SpikeNeeds.next_wake_seconds(
				reference.hunger[i], reference.energy[i], reference.social[i],
				reference.hygiene[i], reference.fun[i])
		var expected: int = int(ref_wake) + jitter
		var diff: int = absi(reference.next_event[i] - expected)
		if diff > max_diff:
			max_diff = diff
		if i < 10:
			samples.append({
				"i": i,
				"next_event": reference.next_event[i],
				"reference_seconds": ref_wake,
				"expected": expected,
			})
	return {
		"expected_events_per_agent_day": SpikeNeeds.expected_events_per_day(),
		"events_per_agent_day_detail": {
			"hunger": SpikeNeeds.SECONDS_PER_DAY / ((SpikeNeeds.WAKE_HUNGER - SpikeNeeds.RESTORE_HUNGER) * SpikeNeeds.HUNGER_SPU),
			"energy": SpikeNeeds.SECONDS_PER_DAY / ((SpikeNeeds.RESTORE_ENERGY - SpikeNeeds.WAKE_ENERGY) * SpikeNeeds.ENERGY_SPU),
			"social": SpikeNeeds.SECONDS_PER_DAY / ((SpikeNeeds.WAKE_SOCIAL - SpikeNeeds.RESTORE_SOCIAL) * SpikeNeeds.SOCIAL_SPU),
			"hygiene": SpikeNeeds.SECONDS_PER_DAY / ((SpikeNeeds.WAKE_HYGIENE - SpikeNeeds.RESTORE_HYGIENE) * SpikeNeeds.HYGIENE_SPU),
			"fun": SpikeNeeds.SECONDS_PER_DAY / ((SpikeNeeds.WAKE_FUN - SpikeNeeds.RESTORE_FUN) * SpikeNeeds.FUN_SPU),
		},
		"inline_vs_reference_max_diff_s": max_diff,
		"sample_rows": samples,
		"rates": {
			"hunger_spu_s": SpikeNeeds.HUNGER_SPU,
			"energy_spu_s": SpikeNeeds.ENERGY_SPU,
			"social_spu_s": SpikeNeeds.SOCIAL_SPU,
			"hygiene_spu_s": SpikeNeeds.HYGIENE_SPU,
			"fun_spu_s": SpikeNeeds.FUN_SPU,
		},
		"notes": "Kosten pro geplantem Termin stehen im soa-Szenario (us_per_scheduled_event).",
	}


# ---------------------------------------------------------------------------
# 4) Pfad
# ---------------------------------------------------------------------------

func scenario_path() -> Dictionary:
	var rows: Array = []
	for grid_size in [128, 512]:
		var grid: SpikePathGrid = SpikePathGrid.new()
		grid.build(grid_size, SEED + grid_size, 10)
		for cache_on in [true, false]:
			for nreq in [100, 1000]:
				var pair_rng: SpikeRng = SpikeRng.new(SEED + grid_size * 31 + nreq)
				var pairs: Array = _make_pairs(grid, pair_rng)
				var runs: Array = []
				for rep in range(PATH_REPS + 1):
					grid.cache_enabled = cache_on
					grid.clear_cache()
					grid.reset_stats()
					var durations: PackedFloat64Array = PackedFloat64Array()
					var found: int = 0
					var path_nodes: int = 0
					for i in nreq:
						var pair: Array = pairs[i % PATH_WORKING_SET]
						var t0: int = Time.get_ticks_usec()
						var path: PackedInt32Array = grid.find_path(pair[0], pair[1])
						var t1: int = Time.get_ticks_usec()
						durations.append(float(t1 - t0) / 1000.0)
						if path.size() > 0:
							found += 1
							path_nodes += path.size()
					if rep == 0:
						continue
					var total_ms: float = 0.0
					for d in durations:
						total_ms += d
					var st: Dictionary = stats(durations)
					var frames: Dictionary = {}
					for k in [1, 2, 4]:
						var frame_samples: PackedFloat64Array = PackedFloat64Array()
						var i: int = 0
						while i + k <= nreq:
							var s: float = 0.0
							for j in k:
								s += durations[i + j]
							frame_samples.append(s)
							i += k
						var fs: Dictionary = stats(frame_samples)
						frames[str(k)] = {"p50_ms": fs["p50"], "p95_ms": fs["p95"], "max_ms": fs["max"]}
					runs.append({
						"rep": rep,
						"total_ms": total_ms,
						"paths_per_s": float(nreq) / (total_ms / 1000.0) if total_ms > 0.0 else 0.0,
						"request_p50_ms": st["p50"],
						"request_p95_ms": st["p95"],
						"request_p99_ms": st["p99"],
						"request_max_ms": st["max"],
						"found": found,
						"failed": nreq - found,
						"avg_path_nodes": float(path_nodes) / float(maxi(found, 1)),
						"cache_hits": grid.cache_hits,
						"cache_misses": grid.cache_misses,
						"cache_hit_rate": float(grid.cache_hits) / float(maxi(grid.cache_hits + grid.cache_misses, 1)),
						"expansions": grid.expansions,
						"frames": frames,
					})
				var mid: Dictionary = median_run(runs, "total_ms")
				rows.append({
					"grid": grid_size,
					"blocked_percent": 10,
					"cache_enabled": cache_on,
					"requests": nreq,
					"working_set": PATH_WORKING_SET,
					"local_distance": [PATH_LOCAL_MIN, PATH_LOCAL_MAX],
					"median": mid,
					"runs": runs,
				})
				notes.append("path %dx%d cache=%s n=%d: %d gewertete Läufe (Zeitbox)" % [
					grid_size, grid_size, str(cache_on), nreq, PATH_REPS])
	return {
		"rows": rows,
		"notes": "Frame-Werte aus nicht-überlappenden Summen von k Anfragen (single-threaded, exakt).",
	}


func _make_pairs(grid: SpikePathGrid, rng: SpikeRng) -> Array:
	# Paare einmalig validieren: lokale Benchmarks sollen Pfadkosten messen,
	# nicht überwiegend isolierte Startzellen. Validierung liegt außerhalb der
	# Messung; Stats/Cache werden danach zurückgesetzt.
	grid.cache_enabled = false
	var pairs: Array = []
	for p in PATH_WORKING_SET:
		var chosen: Array = []
		for attempt in 24:
			var pr: Array = _random_pair(grid, rng)
			if pr[0] == pr[1]:
				continue
			if grid.find_path(pr[0], pr[1]).size() > 0:
				chosen = pr
				break
		if chosen.is_empty():
			chosen = _random_pair(grid, rng)
		pairs.append(chosen)
	grid.reset_stats()
	grid.clear_cache()
	return pairs


func _random_pair(grid: SpikePathGrid, rng: SpikeRng) -> Array:
	var start: int = -1
	var tries: int = 0
	while tries < 64:
		var cand: int = rng.next_range(grid.total)
		if grid.is_walkable(cand):
			start = cand
			break
		tries += 1
	if start < 0:
		start = _first_walkable(grid)
	var sx: int = start % grid.size
	var sy: int = start / grid.size
	var goal: int = -1
	var goal_tries: int = 0
	while goal_tries < 64:
		var dx: int = PATH_LOCAL_MIN + rng.next_range(PATH_LOCAL_MAX - PATH_LOCAL_MIN + 1)
		var dy: int = PATH_LOCAL_MIN + rng.next_range(PATH_LOCAL_MAX - PATH_LOCAL_MIN + 1)
		if rng.next_range(2) == 0:
			dx = -dx
		if rng.next_range(2) == 0:
			dy = -dy
		var gx: int = clampi(sx + dx, 0, grid.size - 1)
		var gy: int = clampi(sy + dy, 0, grid.size - 1)
		var cand2: int = gy * grid.size + gx
		if grid.is_walkable(cand2):
			goal = cand2
			break
		goal_tries += 1
	if goal < 0:
		goal = _first_walkable(grid)
	return [start, goal]


func _first_walkable(grid: SpikePathGrid) -> int:
	for i in grid.total:
		if grid.is_walkable(i):
			return i
	return 0


# ---------------------------------------------------------------------------
# 5) Batch
# ---------------------------------------------------------------------------

func scenario_batch() -> Dictionary:
	var batch: SpikeBatch = SpikeBatch.new()
	var rows: Array = []
	for n in [100, 1000, 10000, 100000]:
		var reps: int = 200 if n == 100 else (100 if n == 1000 else (30 if n == 10000 else 10))
		var agents: int = 1000 if n <= 1000 else 10000
		var events: PackedInt32Array = batch.make_events(n, SEED + n, agents, 0)
		var store: SpikeAgentStore = SpikeAgentStore.new()
		store.configure(agents, SEED + n + 1)
		var runs: Array = []
		for rep in range(REPS + 1):
			var batch_times: PackedFloat64Array = PackedFloat64Array()
			var checksum: int = 0
			var t0: int = Time.get_ticks_usec()
			for b in reps:
				var e0: int = Time.get_ticks_usec()
				checksum += batch.process(events, store, b * 60)
				var e1: int = Time.get_ticks_usec()
				batch_times.append(float(e1 - e0) / 1000.0)
			var total_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			if rep == 0:
				continue
			var st: Dictionary = stats(batch_times)
			runs.append({
				"rep": rep,
				"batches": reps,
				"total_ms": total_ms,
				"events_per_s": float(n * reps) / (total_ms / 1000.0),
				"us_per_event": total_ms * 1000.0 / float(n * reps),
				"batch_p50_ms": st["p50"],
				"batch_p95_ms": st["p95"],
				"batch_p99_ms": st["p99"],
				"batch_max_ms": st["max"],
				"checksum": checksum & 0xFFFFFFFF,
			})
		var mid: Dictionary = median_run(runs, "us_per_event")
		rows.append({
			"batch_events": n,
			"batches_per_run": reps,
			"agents": agents,
			"median": mid,
			"runs": runs,
		})
	return {
		"rows": rows,
		"notes": "Gleicher Seed je Batchgröße; Checksummen müssen über Läufe identisch sein.",
	}


# ---------------------------------------------------------------------------
# 6) Save
# ---------------------------------------------------------------------------

func scenario_save() -> Dictionary:
	var saver: SpikeSave = SpikeSave.new()
	var rows: Array = []
	for n in [10000, 100000]:
		var store: SpikeAgentStore = SpikeAgentStore.new()
		store.configure(n, SEED + n)
		for t in 10:
			store.tick(t * 30, 30.0)
		var path: String = _path("spike_save_%d.bin" % n)
		var runs: Array = []
		for rep in range(REPS + 1):
			if rep == 0:
				saver.save_measured(store, n, path + ".warm")
				continue
			var s: Dictionary = saver.save_measured(store, n, path)
			var l: Dictionary = saver.load_measured(store.state_hash(), path)
			runs.append({
				"rep": rep,
				"bytes": s.get("bytes", 0),
				"mbytes": s.get("mbytes", 0.0),
				"encode_ms": s.get("encode_ms", 0.0),
				"write_ms": s.get("write_ms", 0.0),
				"save_total_ms": s.get("total_ms", 0.0),
				"save_mb_s": s.get("mb_s", 0.0),
				"read_ms": l.get("read_ms", 0.0),
				"decode_ms": l.get("decode_ms", 0.0),
				"load_total_ms": l.get("total_ms", 0.0),
				"load_mb_s": l.get("mb_s", 0.0),
				"verified": l.get("verified", false),
			})
		DirAccess.remove_absolute(path + ".warm")
		var mid: Dictionary = median_run(runs, "save_total_ms")
		rows.append({
			"agents": n,
			"encoded_bytes": SpikeSave.HEADER + n * SpikeSave.STRIDE,
			"bytes_per_agent": SpikeSave.STRIDE,
			"file": path,
			"median": mid,
			"runs": runs,
		})
	return {
		"rows": rows,
		"notes": "Wegwerf-Format (12-Byte-Header + 58-Byte-Record), keine Kompression/Migration.",
	}


# ---------------------------------------------------------------------------
# 7) Repeat-Hash
# ---------------------------------------------------------------------------

func scenario_repeat() -> Dictionary:
	var runs: Array = []
	for i in 3:
		runs.append(SpikeRepeat.run(SEED))
	var same: bool = true
	for i in range(1, runs.size()):
		if runs[i]["combined_hex"] != runs[0]["combined_hex"]:
			same = false
	var other: Dictionary = SpikeRepeat.run(SEED + 1)
	return {
		"runs": runs,
		"identical": same,
		"negative_control_differs": other["combined_hex"] != runs[0]["combined_hex"],
		"negative_control_hex": other["combined_hex"],
		"notes": "Hash = FNV-1a-32 über Scheduler-Eventfolge + Agentzustand; kein Save/Replay.",
	}


# ---------------------------------------------------------------------------
# 8) Render (separat erhoben, hier nur zusammengeführt)
# ---------------------------------------------------------------------------

func scenario_render() -> Dictionary:
	var cpu: Dictionary = _read_json("render_cpu.json")
	var win: Dictionary = _read_json("render_window.json")
	var out: Dictionary = {
		"cpu_instance_build": cpu if not cpu.is_empty() else null,
		"windowed": win if not win.is_empty() else null,
	}
	if cpu.is_empty():
		out["status"] = "not_measured"
		out["reason"] = "render_cpu.json fehlt; render_spike.tscn headless ausführen."
	else:
		out["status"] = "partial" if win.is_empty() else "measured"
	if win.is_empty():
		out["gpu_note"] = "Keine GPU-/FPS-Messung vorhanden (headless=Dummy-Renderer oder Fenster-Lauf fehlgeschlagen)."
	return out


# ---------------------------------------------------------------------------
# 9) Native (separat erhoben, hier nur zusammengeführt)
# ---------------------------------------------------------------------------

func scenario_native() -> Dictionary:
	var native: Dictionary = _read_json("native_csharp.json")
	if native.is_empty():
		return {
			"status": "not_measured",
			"reason": "native_csharp.json fehlt; dotnet run -c Release in bench/native ausführen.",
		}
	var ref: Dictionary = _read_json("parity_ref.json")
	if not ref.is_empty() and native.has("parity"):
		var npar: Dictionary = native["parity"]
		var wl_ok: bool = true
		for key in ref.get("scheduler_workload_hash", {}):
			if str(npar.get("scheduler_workload_hash", {}).get(key, "")) != str(ref["scheduler_workload_hash"][key]):
				wl_ok = false
		var soa_ok: bool = true
		for key in ref.get("soa_state_hash_20_ticks", {}):
			if str(npar.get("soa_state_hash_20_ticks", {}).get(key, "")) != str(ref["soa_state_hash_20_ticks"][key]):
				soa_ok = false
		native["parity_check"] = {
			"workload_identical": wl_ok,
			"soa_state_identical": soa_ok,
			"reference": "parity_ref.json (GDScript, gleicher Seed)",
		}
	else:
		native["parity_check"] = {"available": false}
	native["status"] = "measured"
	return native


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

func _checks(out: Dictionary) -> Dictionary:
	var scen: Dictionary = out["scenarios"]
	var checks: Dictionary = {}
	if scen.has("scheduler"):
		var checksums_ok: bool = true
		var order_ok: bool = true
		for row in scen["scheduler"]["rows"]:
			var first: int = row["runs"][0]["checksum"]
			for r in row["runs"]:
				if r["checksum"] != first:
					checksums_ok = false
			if not row["order_ok_warmup"]:
				order_ok = false
		checks["scheduler_checksums_stable"] = checksums_ok
		checks["scheduler_order_ok"] = order_ok
	if scen.has("repeat"):
		checks["repeat_identical"] = scen["repeat"]["identical"]
		checks["repeat_negative_control"] = scen["repeat"]["negative_control_differs"]
	if scen.has("save"):
		var verified: bool = true
		for row in scen["save"]["rows"]:
			for r in row["runs"]:
				if not r["verified"]:
					verified = false
		checks["save_roundtrip_verified"] = verified
	if scen.has("needs"):
		checks["needs_inline_matches_reference"] = scen["needs"]["inline_vs_reference_max_diff_s"] <= 1
	if scen.has("path"):
		var failures: int = 0
		for row in scen["path"]["rows"]:
			failures += row["median"]["failed"]
		checks["path_no_failures_in_median"] = failures == 0
	if scen.has("native") and scen["native"].get("parity_check", {}).has("workload_identical"):
		var pc: Dictionary = scen["native"]["parity_check"]
		checks["native_workload_identical"] = pc["workload_identical"]
		checks["native_soa_state_identical"] = pc["soa_state_identical"]
	checks["no_gameplay"] = true
	return checks


# ---------------------------------------------------------------------------
# Metriken / IO
# ---------------------------------------------------------------------------

func _meta() -> Dictionary:
	return {
		"gate": "G0.5",
		"kind": "technikspike",
		"seed": SEED,
		"reps": REPS,
		"path_reps": PATH_REPS,
		"godot": Engine.get_version_info()["string"],
		"godot_version": Engine.get_version_info(),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"cpu_count": OS.get_processor_count(),
		"display_server": DisplayServer.get_name(),
		"headless": DisplayServer.get_name() == "headless",
		"utc": Time.get_datetime_string_from_system(true),
		"project_dir": ProjectSettings.globalize_path("res://"),
		"results_dir": results_dir,
	}


static func stats(samples: PackedFloat64Array) -> Dictionary:
	var n: int = samples.size()
	if n == 0:
		return {"count": 0, "mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var s: PackedFloat64Array = samples.duplicate()
	s.sort()
	var sum: float = 0.0
	for v in s:
		sum += v
	return {
		"count": n,
		"mean": sum / float(n),
		"p50": _pct(s, 50.0),
		"p95": _pct(s, 95.0),
		"p99": _pct(s, 99.0),
		"max": s[n - 1],
	}


static func _pct(sorted_values: PackedFloat64Array, p: float) -> float:
	var n: int = sorted_values.size()
	if n == 0:
		return 0.0
	var idx: int = int(ceil(p / 100.0 * float(n))) - 1
	return sorted_values[clampi(idx, 0, n - 1)]


static func median_run(runs: Array, key: String) -> Dictionary:
	if runs.is_empty():
		return {}
	var sorted: Array = runs.duplicate()
	sorted.sort_custom(func(a, b): return float(a[key]) < float(b[key]))
	return sorted[sorted.size() / 2]


func _path(file_name: String) -> String:
	return results_dir.path_join(file_name)


func _write_json(file_name: String, data: Variant) -> void:
	var f: FileAccess = FileAccess.open(_path(file_name), FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + file_name)
		return
	f.store_string(JSON.stringify(data, "  ", false, true))
	f.close()


func _read_json(file_name: String) -> Dictionary:
	var path: String = _path(file_name)
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _write_csvs(out: Dictionary) -> void:
	var scen: Dictionary = out["scenarios"]
	if scen.has("scheduler"):
		var rows: Array = []
		for row in scen["scheduler"]["rows"]:
			var m: Dictionary = row["median"]
			rows.append([row["events"], row["burst_percent"], m["us_per_event"],
				m["push_us_per_event"], m["pop_us_per_event"], m["events_per_s"],
				m["p50_us"], m["p95_us"], m["p99_us"], m["checksum"]])
		_write_csv("scheduler.csv",
			PackedStringArray(["events", "burst_percent", "us_per_event", "push_us_event",
				"pop_us_event", "events_per_s", "p50_us", "p95_us", "p99_us", "checksum"]), rows)
	if scen.has("soa"):
		var rows2: Array = []
		for row in scen["soa"]["rows"]:
			var m2: Dictionary = row["median"]
			rows2.append([row["agents"], m2["us_per_agent_tick"], m2["update_only_us_agent"],
				m2["us_per_scheduled_event"], m2["p95_us_agent"], row["memory_bytes"],
				m2["scheduled_events"]])
		_write_csv("soa.csv",
			PackedStringArray(["agents", "us_per_agent_tick", "update_only_us_agent",
				"us_per_scheduled_event", "p95_us_agent", "memory_bytes", "scheduled_events"]), rows2)
	if scen.has("path"):
		var rows3: Array = []
		for row in scen["path"]["rows"]:
			var m3: Dictionary = row["median"]
			rows3.append([row["grid"], str(row["cache_enabled"]), row["requests"],
				m3["total_ms"], m3["paths_per_s"], m3["request_p50_ms"], m3["request_p95_ms"],
				m3["request_p99_ms"], m3["cache_hit_rate"], m3["expansions"],
				m3["frames"]["1"]["p95_ms"], m3["frames"]["2"]["p95_ms"], m3["frames"]["4"]["p95_ms"]])
		_write_csv("path.csv",
			PackedStringArray(["grid", "cache", "requests", "total_ms", "paths_per_s",
				"request_p50_ms", "request_p95_ms", "request_p99_ms", "cache_hit_rate",
				"expansions", "frame1_p95_ms", "frame2_p95_ms", "frame4_p95_ms"]), rows3)
	if scen.has("batch"):
		var rows4: Array = []
		for row in scen["batch"]["rows"]:
			var m4: Dictionary = row["median"]
			rows4.append([row["batch_events"], m4["us_per_event"], m4["batch_p50_ms"],
				m4["batch_p95_ms"], m4["batch_p99_ms"], m4["events_per_s"]])
		_write_csv("batch.csv",
			PackedStringArray(["batch_events", "us_per_event", "batch_p50_ms",
				"batch_p95_ms", "batch_p99_ms", "events_per_s"]), rows4)
	if scen.has("save"):
		var rows5: Array = []
		for row in scen["save"]["rows"]:
			var m5: Dictionary = row["median"]
			rows5.append([row["agents"], row["encoded_bytes"], m5["save_total_ms"],
				m5["save_mb_s"], m5["load_total_ms"], m5["load_mb_s"], str(m5["verified"])])
		_write_csv("save.csv",
			PackedStringArray(["agents", "bytes", "save_total_ms", "save_mb_s",
				"load_total_ms", "load_mb_s", "verified"]), rows5)



func _write_csv(file_name: String, header: PackedStringArray, rows: Array) -> void:
	var f: FileAccess = FileAccess.open(_path(file_name), FileAccess.WRITE)
	if f == null:
		return
	f.store_csv_line(header)
	for row in rows:
		var vals: PackedStringArray = PackedStringArray()
		for v in row:
			vals.append(str(v))
		f.store_csv_line(vals)
	f.close()
