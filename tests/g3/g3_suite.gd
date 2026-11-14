extends Node

## G3 B-spike headless suite: 100k records, 1k/5k detail, 150x/200x,
## background key events, determinism, save/load, camera independence.
##
## godot --headless --path V3 res://tests/g3/g3_suite.tscn

const GenerationTests = preload("res://tests/g3/test_b_generation.gd")
const TierTests = preload("res://tests/g3/test_b_tier.gd")
const BackgroundTests = preload("res://tests/g3/test_b_background.gd")
const DeterminismTests = preload("res://tests/g3/test_b_determinism.gd")
const SaveTests = preload("res://tests/g3/test_b_save.gd")
const PerformanceTests = preload("res://tests/g3/test_b_performance.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G3_B"
	GenerationTests.run(ctx)
	TierTests.run(ctx)
	BackgroundTests.run(ctx)
	DeterminismTests.run(ctx)
	SaveTests.run(ctx)
	PerformanceTests.run(ctx)
	ctx.print_summary()
	print("G3_B_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
