extends Node

## G3-A-Headless-Suite: 1000-Agenten-Kleinstadt, 120-Tage-Jahr, saisonale
## Felder, A*/Cache/Chunking, Batching, Save-Schema 6, Performance, UI,
## D-57-Stubs. Die B-Spike-Suite (g3_suite.tscn) bleibt unverändert.
##
## godot --headless --path V3 res://tests/g3/g3_a_suite.tscn

const T01 = preload("res://tests/g3/test_g3_01_world.gd")
const T02 = preload("res://tests/g3/test_g3_02_calendar.gd")
const T03 = preload("res://tests/g3/test_g3_03_fields.gd")
const T04 = preload("res://tests/g3/test_g3_04_navigation.gd")
const T05 = preload("res://tests/g3/test_g3_05_batching.gd")
const T06 = preload("res://tests/g3/test_g3_06_determinism.gd")
const T07 = preload("res://tests/g3/test_g3_07_save.gd")
const T08 = preload("res://tests/g3/test_g3_08_performance.gd")
const T09 = preload("res://tests/g3/test_g3_09_ui.gd")
const T10 = preload("res://tests/g3/test_g3_10_scope.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G3A"
	# 06 zuerst: die drei 120-Tage-Läufe liefern den gemeinsamen Snapshot für
	# 03/07 und den geteilten Sim für 04/09.
	T01.run(ctx)
	T02.run(ctx)
	T06.run(ctx)
	T03.run(ctx)
	T04.run(ctx)
	T05.run(ctx)
	T07.run(ctx)
	T08.run(ctx)
	T09.run(ctx)
	T10.run(ctx)
	ctx.print_summary()
	print("G3A_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
