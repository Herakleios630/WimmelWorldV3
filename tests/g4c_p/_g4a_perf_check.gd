extends Node

const T08 = preload("res://tests/g4/test_g4_08_performance.gd")

func _ready() -> void:
	var ctx: G1aTestContext = G1aTestContext.new()
	ctx.gate_name = "G4A-PERF-RECHECK"
	T08.run(ctx)
	ctx.print_summary()
	get_tree().quit(0 if ctx.all_passed() else 1)
