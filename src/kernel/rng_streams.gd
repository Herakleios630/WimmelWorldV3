class_name RngStreams
extends RefCounted

## Feste, benannte Streams. Reihenfolge ist Teil des Save-Schemas.

const NAMES: Array = [
	"world", "agents", "economy", "lifecycle", "politics", "combat",
]

var streams: Array = []


func _init(seed_value: int = 1) -> void:
	streams.clear()
	for i in NAMES.size():
		var mixed: int = seed_value * 6364136223846793005 + (i + 1) * 1442695040888963407
		streams.append(RngStream.new(mixed))


func get_stream(stream_name: String) -> RngStream:
	var idx: int = NAMES.find(stream_name)
	if idx < 0:
		push_error("unknown rng stream: " + stream_name)
		return streams[0]
	return streams[idx]


func world() -> RngStream:
	return streams[0]


func agents() -> RngStream:
	return streams[1]


func state_hash() -> int:
	var h: int = HashUtil.FNV_OFFSET
	for i in streams.size():
		h = HashUtil.mix_i64(h, (streams[i] as RngStream).state)
	return h
