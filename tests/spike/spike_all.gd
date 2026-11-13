extends Node

## Einstieg für die Kern-Szenarien (Scheduler, SoA, Needs, Pfad, Batch, Save,
## Repeat) plus Zusammenführung der separat erhobenen Render-/Native-Daten.
##
## headless: godot --headless --path V3 res://tests/spike/spike_all.tscn
##           -- --only=scheduler,soa   (optional)
##
## Exitcodes: 0 = alle Checks ok, 2 = mindestens ein Check fehlgeschlagen.


func _ready() -> void:
	var only: PackedStringArray = PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for part in arg.substr(7).split(",", false):
				var p: String = part.strip_edges()
				if not p.is_empty():
					only.append(p)
	var runner: SpikeRunner = SpikeRunner.new()
	var t0: int = Time.get_ticks_usec()
	var out: Dictionary = runner.run(only)
	_print_summary(out)
	var hard_ok: bool = true
	for key in out["checks"]:
		if not out["checks"][key]:
			hard_ok = false
	print("SPIKE_RUN_DONE elapsed_s=%.2f checks_ok=%s" % [
		float(Time.get_ticks_usec() - t0) / 1000000.0, str(hard_ok)])
	get_tree().quit(0 if hard_ok else 2)


func _print_summary(out: Dictionary) -> void:
	var scen: Dictionary = out["scenarios"]
	print("== G0.5 spike ==")
	if scen.has("scheduler"):
		for row in scen["scheduler"]["rows"]:
			var m: Dictionary = row["median"]
			print("scheduler events=%d burst=%d%% us/event=%.3f push=%.3f pop=%.3f events/s=%.0f p95=%.3f" % [
				row["events"], row["burst_percent"], m["us_per_event"], m["push_us_per_event"],
				m["pop_us_per_event"], m["events_per_s"], m["p95_us"]])
	if scen.has("soa"):
		for row in scen["soa"]["rows"]:
			var m2: Dictionary = row["median"]
			print("soa agents=%d us/agent/tick=%.4f update_only=%.4f us/event=%.3f mem=%d" % [
				row["agents"], m2["us_per_agent_tick"], m2["update_only_us_agent"],
				m2["us_per_scheduled_event"], row["memory_bytes"]])
	if scen.has("needs"):
		print("needs events/agent/day=%.3f inline_diff_s=%d" % [
			scen["needs"]["expected_events_per_agent_day"],
			scen["needs"]["inline_vs_reference_max_diff_s"]])
	if scen.has("path"):
		for row in scen["path"]["rows"]:
			var m3: Dictionary = row["median"]
			print("path %dx%d cache=%s n=%d total=%.1fms paths/s=%.0f p95=%.3fms hit=%.3f failures=%d" % [
				row["grid"], row["grid"], str(row["cache_enabled"]), row["requests"],
				m3["total_ms"], m3["paths_per_s"], m3["request_p95_ms"],
				m3["cache_hit_rate"], m3["failed"]])
	if scen.has("batch"):
		for row in scen["batch"]["rows"]:
			var m4: Dictionary = row["median"]
			print("batch n=%d us/event=%.3f p50=%.3fms p95=%.3fms events/s=%.0f" % [
				row["batch_events"], m4["us_per_event"], m4["batch_p50_ms"],
				m4["batch_p95_ms"], m4["events_per_s"]])
	if scen.has("save"):
		for row in scen["save"]["rows"]:
			var m5: Dictionary = row["median"]
			print("save agents=%d bytes=%d save=%.1fms (%.1f MB/s) load=%.1fms (%.1f MB/s) verified=%s" % [
				row["agents"], row["encoded_bytes"], m5["save_total_ms"], m5["save_mb_s"],
				m5["load_total_ms"], m5["load_mb_s"], str(m5["verified"])])
	if scen.has("repeat"):
		var r: Dictionary = scen["repeat"]
		print("repeat identical=%s neg_control=%s hash=%s" % [
			str(r["identical"]), str(r["negative_control_differs"]), r["runs"][0]["combined_hex"]])
	if scen.has("render"):
		print("render status=%s" % str(scen["render"].get("status", "?")))
	if scen.has("native"):
		print("native status=%s" % str(scen["native"].get("status", "?")))
	print("checks: %s" % JSON.stringify(out["checks"]))
