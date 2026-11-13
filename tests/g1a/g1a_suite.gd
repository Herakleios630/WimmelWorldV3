extends Node

## G1a-Headless-Suite. Führt alle Test-IDs aus, die ohne Fenster prüfbar sind.
## T-UI-04 und die visuelle Hälfte von T-BENCH-02 lesen das von
## res://tests/g1a/bench_visual.tscn erzeugte Ergebnis.
##
## godot --headless --path V3 res://tests/g1a/g1a_suite.tscn

const KernelTests = preload("res://tests/g1a/test_kernel.gd")
const StoreTests = preload("res://tests/g1a/test_store.gd")
const NeedTests = preload("res://tests/g1a/test_needs.gd")
const WorldTests = preload("res://tests/g1a/test_world.gd")
const MoveTests = preload("res://tests/g1a/test_move.gd")
const FoodTests = preload("res://tests/g1a/test_food.gd")
const SaveTests = preload("res://tests/g1a/test_save.gd")
const UiTests = preload("res://tests/g1a/test_ui.gd")
const BenchTests = preload("res://tests/g1a/test_bench.gd")


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	var ctx: G1aTestContext = G1aTestContext.new()
	KernelTests.run(ctx)
	StoreTests.run(ctx)
	NeedTests.run(ctx)
	WorldTests.run(ctx)
	MoveTests.run(ctx)
	FoodTests.run(ctx)
	SaveTests.run(ctx)
	UiTests.run(ctx)
	BenchTests.run(ctx)
	ctx.print_summary()
	print("G1A_SUITE_DONE elapsed_s=%.2f" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0 if ctx.all_passed() else 1)
