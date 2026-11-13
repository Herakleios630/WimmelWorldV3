extends Node

func _ready() -> void:
	var a: int = 9223372036854775807
	print("overflow:", a + 1)
	var big: int = 0x2545F4914F6CDD1D
	print("mul:", (big * big))
	print("shift:", (big >> 32))
	print("headless:", DisplayServer.get_name())
	print("engine:", Engine.get_version_info())
	print("dir:", ProjectSettings.globalize_path("res://"))
	print("ticks_usec:", Time.get_ticks_usec())
	var path := ProjectSettings.globalize_path("res://bench/results")
	print("results_dir_exists:", DirAccess.dir_exists_absolute(path))
	var f := FileAccess.open(path.path_join("smoke.txt"), FileAccess.WRITE)
	print("file_open:", f != null)
	if f != null:
		f.store_string("ok")
		f.close()
	print("SPIKE_SMOKE_OK")
	get_tree().quit(0)
