class_name EventBatcher
extends RefCounted

## Messung/Struktur der Event-Batches. Die autoritative Ordnung bleibt der
## Scheduler mit (time, seq); dieser Baustein bündelt nur alle fälligen Events
## derselben Sim-Zeit für Dispatch und Messung.

const MAX_SAMPLES: int = 20000

var batch_count: int = 0
var total_events: int = 0
var max_batch: int = 0
var last_batch: int = 0
var batch_sizes: PackedInt32Array = PackedInt32Array()
var batch_times: PackedInt64Array = PackedInt64Array()
var out_of_order: int = 0
var _last_time: int = -1
var _last_seq: int = -1


func reset() -> void:
	batch_count = 0
	total_events = 0
	max_batch = 0
	last_batch = 0
	batch_sizes.clear()
	batch_times.clear()
	out_of_order = 0
	_last_time = -1
	_last_seq = -1


func record(batch_time: int, batch_size: int, last_seq: int) -> void:
	batch_count += 1
	last_batch = batch_size
	total_events += batch_size
	if batch_size > max_batch:
		max_batch = batch_size
	if batch_count <= MAX_SAMPLES:
		batch_sizes.append(batch_size)
		batch_times.append(batch_time)
	if batch_time < _last_time or (batch_time == _last_time and last_seq < _last_seq):
		out_of_order += 1
	_last_time = batch_time
	_last_seq = last_seq


func p95_batch_size() -> float:
	if batch_sizes.is_empty():
		return 0.0
	var sorted: PackedInt32Array = batch_sizes.duplicate()
	sorted.sort()
	var idx: int = int(round(float(sorted.size() - 1) * 0.95))
	return float(sorted[idx])


func stats() -> Dictionary:
	return {
		"batches": batch_count,
		"events": total_events,
		"max_batch": max_batch,
		"last_batch": last_batch,
		"p95_batch": p95_batch_size(),
		"out_of_order": out_of_order,
	}
