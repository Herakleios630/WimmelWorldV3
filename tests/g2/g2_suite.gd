extends Node

## G2-Headless-Suite: 100-Agenten-Bauerschaft, A*/Cache, Batching,
## 30-Tage-Determinismus, Save/Load/Replay, Performance, UI, D-57-Stubs.
##
## godot --headless --path V3 res://tests/g2/g2_suite.tscn

const GenerationTests = preload("res://tests/g2/test_g2_generation.gd")
const NavigationTests = preload("res://tests/g2/test_g2_navigation.gd")
const BatchingTests = preload("res://tests/g2/test_g2_batching.gd")
const DeterminismTests = preload("res://tests/g2/test_g2_determinism.gd")
const SaveTests = preload("res://tests/g2/test_g2_save.gd")
const PerformanceTests = preload("res://tests/g2/test_g2_performance.gd")
const UiTests = preload("res://tests/g2/test_g2_ui.gd")
const StubTests = preload("res://tests/g2/test_g2_stubs.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G2"
	GenerationTests.run(ctx)
	NavigationTests.run(ctx)
	BatchingTests.run(ctx)
	DeterminismTests.run(ctx)
	SaveTests.run(ctx)
	PerformanceTests.run(ctx)
	UiTests.run(ctx)
	StubTests.run(ctx)
	ctx.print_summary()
	print("G2_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
