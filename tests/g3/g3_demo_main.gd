extends DemoMain

## Sichtbare G3-Demo: 1000 Agenten in der 768x768-Kleinstadt.


func _make_config() -> SimConfig:
	return SimConfig.g3(1337)


func _save_path() -> String:
	return "user://g3_save.bin"
