class_name BMetrics
extends RefCounted

## Wall-clock measurement for the B spike. Only called when measurement is
## enabled; it never feeds simulation decisions or hashes.

const MAX_FRAME_SAMPLES: int = 200000
const MAX_BATCH_SAMPLES: int = 200000

var frames: int = 0
var frame_ms: PackedFloat64Array = PackedFloat64Array()
var frame_events: PackedFloat64Array = PackedFloat64Array()
var frame_sim_seconds: PackedFloat64Array = PackedFloat64Array()
var batch_ms: PackedFloat64Array = PackedFloat64Array()
var batch_sizes: PackedFloat64Array = PackedFloat64Array()

var total_events: int = 0
var total_sim_seconds: int = 0
var total_wall_usec: int = 0

var detail_usec: int = 0
var detail_events: int = 0
var background_usec: int = 0
var background_batches: int = 0
var selection_usec: int = 0
var selection_events: int = 0
var day_tick_usec: int = 0
var day_ticks: int = 0
var max_batch_size: int = 0


func reset() -> void:
	frames = 0
	frame_ms.clear()
	frame_events.clear()
	frame_sim_seconds.clear()
	batch_ms.clear()
	batch_sizes.clear()
	total_events = 0
	total_sim_seconds = 0
	total_wall_usec = 0
	detail_usec = 0
	detail_events = 0
	background_usec = 0
	background_batches = 0
	selection_usec = 0
	selection_events = 0
	day_tick_usec = 0
	day_ticks = 0
	max_batch_size = 0


func record_frame(wall_usec: int, events: int, sim_seconds: int) -> void:
	frames += 1
	total_events += events
	total_sim_seconds += sim_seconds
	total_wall_usec += wall_usec
	if frame_ms.size() < MAX_FRAME_SAMPLES:
		frame_ms.append(float(wall_usec) / 1000.0)
		frame_events.append(float(events))
		frame_sim_seconds.append(float(sim_seconds))


func record_batch(wall_usec: int, size: int) -> void:
	if size > max_batch_size:
		max_batch_size = size
	if batch_ms.size() < MAX_BATCH_SAMPLES:
		batch_ms.append(float(wall_usec) / 1000.0)
		batch_sizes.append(float(size))


static func percentile(values: PackedFloat64Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var idx: int = int(round(float(sorted.size() - 1) * p))
	return sorted[idx]


static func average(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in values:
		sum += v
	return sum / float(values.size())


func stats(config: BConfig, detail_agents: int, sim_days: float) -> Dictionary:
	var wall_seconds: float = float(total_wall_usec) / 1000000.0
	var actual_speed: float = 0.0
	if wall_seconds > 0.0:
		actual_speed = (float(total_sim_seconds) / wall_seconds) / (BConfig.TICKS_PER_DAY / BConfig.BASE_SECONDS_PER_DAY_AT_1X)
	var p95: float = percentile(frame_ms, 0.95)
	var sustainable_speed: float = 0.0
	if p95 > 0.0:
		sustainable_speed = (float(config.sim_seconds_per_frame()) / (p95 / 1000.0)) \
			/ (BConfig.TICKS_PER_DAY / BConfig.BASE_SECONDS_PER_DAY_AT_1X)
	var detail_agent_days: float = float(maxi(1, detail_agents)) * maxf(0.0001, sim_days)
	var background_batch_count: int = maxi(1, background_batches)
	return {
		"frames": frames,
		"total_events": total_events,
		"events_per_frame": float(total_events) / float(maxi(1, frames)),
		"frame_p50_ms": percentile(frame_ms, 0.50),
		"frame_p95_ms": p95,
		"frame_p99_ms": percentile(frame_ms, 0.99),
		"frame_max_ms": percentile(frame_ms, 1.0),
		"fps_avg": float(frames) / maxf(0.0001, wall_seconds),
		"target_speed": config.speed,
		"actual_speed_factor": actual_speed,
		"sustainable_speed_at_p95": sustainable_speed,
		"sim_seconds_per_frame": config.sim_seconds_per_frame(),
		"sim_days": sim_days,
		"detail_agents": detail_agents,
		"detail_us_per_agent_day": float(detail_usec) / detail_agent_days,
		"detail_events": detail_events,
		"background_us_per_settlement_batch": float(background_usec) / float(background_batch_count),
		"background_batches": background_batches,
		"selection_us_per_row": float(selection_usec) / float(maxi(1, selection_events)),
		"selection_rows": selection_events,
		"batch_p50_ms": percentile(batch_ms, 0.50),
		"batch_p95_ms": percentile(batch_ms, 0.95),
		"batch_p99_ms": percentile(batch_ms, 0.99),
		"batch_max_ms": percentile(batch_ms, 1.0),
		"batch_size_p50": percentile(batch_sizes, 0.50),
		"batch_size_p95": percentile(batch_sizes, 0.95),
		"batch_size_p99": percentile(batch_sizes, 0.99),
		"batch_size_max": max_batch_size,
		"batches": batch_sizes.size(),
		"day_ticks": day_ticks,
		"day_tick_us": float(day_tick_usec) / float(maxi(1, day_ticks)),
	}
