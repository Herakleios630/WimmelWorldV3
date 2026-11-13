extends Node

## G1b-Headless-Suite für Schritt 1 (Needs + Feldzyklus) und Schritt 2
## (Lebenszyklus, Demografie, Save-Schema 3).
## godot --headless --path V3 res://tests/g1b/g1b_suite.tscn

const NeedTests = preload("res://tests/g1b/test_needs_g1b.gd")
const FarmTests = preload("res://tests/g1b/test_farm.gd")
const LifecycleTests = preload("res://tests/g1b/test_lifecycle.gd")
const DemographyBenchTests = preload("res://tests/g1b/test_demography.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G1B"
	NeedTests.run(ctx)
	FarmTests.run(ctx)
	LifecycleTests.run(ctx)
	DemographyBenchTests.run(ctx)
	ctx.print_summary()
	print("G1B_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
