extends Node

## G4b-Headless-Suite: 10k-Kern mit Wirtschaft/Politik, 120-Tage-Jahr,
## Haushalte/Markt/Karawanen/Nation/Diplomatie/Krisen, Save-Schema 8,
## 10k@50x, UI und G1-G4a-Regression.
##
## godot --headless --path V3 res://tests/g4/g4_b_suite.tscn

const T01 = preload("res://tests/g4/test_g4b_01_households.gd")
const T02 = preload("res://tests/g4/test_g4b_02_market.gd")
const T03 = preload("res://tests/g4/test_g4b_03_caravans.gd")
const T04 = preload("res://tests/g4/test_g4b_04_nation.gd")
const T05 = preload("res://tests/g4/test_g4b_05_diplomacy.gd")
const T06 = preload("res://tests/g4/test_g4b_06_crisis.gd")
const T07 = preload("res://tests/g4/test_g4b_07_determinism.gd")
const T08 = preload("res://tests/g4/test_g4b_08_save.gd")
const T09 = preload("res://tests/g4/test_g4b_09_performance.gd")
const T10 = preload("res://tests/g4/test_g4b_10_ui.gd")
const T11 = preload("res://tests/g4/test_g4b_11_scope.gd")
const T12 = preload("res://tests/g4/test_g4b_12_regression.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G4B"
	# 07 zuerst: die drei 120-Tage-Läufe liefern Snapshot und geteilte Sim.
	T07.run(ctx)
	T01.run(ctx)
	T02.run(ctx)
	T03.run(ctx)
	T04.run(ctx)
	T05.run(ctx)
	T06.run(ctx)
	T08.run(ctx)
	T09.run(ctx)
	T10.run(ctx)
	T11.run(ctx)
	T12.run(ctx)
	ctx.print_summary()
	print("G4B_SUITE_DONE elapsed_s=%.2f" % [
		float(Time.get_ticks_msec() - t0) / 1000.0])
	var passed: bool = ctx.all_passed()
	G4BTestUtil.cleanup()
	get_tree().quit(0 if passed else 1)
