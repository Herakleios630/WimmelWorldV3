extends DemoMain

## Sichtbare G2-Demo: 100 Agenten in der 384x384-Bauerschaft.


func _make_config() -> SimConfig:
	return SimConfig.g2(1337)


func _save_path() -> String:
	return "user://g2_save.bin"
