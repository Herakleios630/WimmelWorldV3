extends Node

## G4a-Headless-Suite: 10.000-Agenten-Kern, 120-Tage-Jahr, saisonale Felder,
## A*/Wegpunktgraph/Cache/Chunking, Batching, Save-Schema 7, Performance,
## UI/Chronik, D-57-Stubs. G4b-Wirtschaft/Politik ist nicht Teil dieser Suite.
##
## godot --headless --path V3 res://tests/g4/g4_a_suite.tscn

const T01 = preload("res://tests/g4/test_g4_01_world.gd")
const T02 = preload("res://tests/g4/test_g4_02_calendar.gd")
const T03 = preload("res://tests/g4/test_g4_03_fields.gd")
const T04 = preload("res://tests/g4/test_g4_04_navigation.gd")
const T05 = preload("res://tests/g4/test_g4_05_batching.gd")
const T06 = preload("res://tests/g4/test_g4_06_determinism.gd")
const T07 = preload("res://tests/g4/test_g4_07_save.gd")
const T08 = preload("res://tests/g4/test_g4_08_performance.gd")
const T09 = preload("res://tests/g4/test_g4_09_ui.gd")
const T10 = preload("res://tests/g4/test_g4_10_scope.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G4A"
	# 06 zuerst: die drei 120-Tage-Läufe liefern Snapshot und geteilte Sim.
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
	print("G4A_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
