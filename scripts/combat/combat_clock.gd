class_name CombatClock
extends RefCounted

const ROUND_DURATION_US: int = 5_000_000

var _elapsed_us: int = 0


func get_elapsed_us() -> int:
	return _elapsed_us


func get_round_index() -> int:
	return get_round_index_at(_elapsed_us)


func get_round_index_at(timestamp_us: int) -> int:
	assert(timestamp_us >= 0, "Combat timestamps cannot be negative.")
	return floori(float(timestamp_us) / float(ROUND_DURATION_US))


func get_round_offset_us_at(timestamp_us: int) -> int:
	assert(timestamp_us >= 0, "Combat timestamps cannot be negative.")
	return timestamp_us % ROUND_DURATION_US


func advance(delta_us: int) -> void:
	assert(delta_us >= 0, "Combat clock advancement cannot be negative.")
	_elapsed_us += delta_us


func reset() -> void:
	_elapsed_us = 0
