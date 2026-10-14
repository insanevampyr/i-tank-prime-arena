class_name DeterministicCombatRng
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed_value: int
var _draw_count: int = 0


func _init(seed_value: int) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value


func get_seed_value() -> int:
	return _seed_value


func next_int(min_inclusive: int, max_inclusive: int) -> int:
	assert(min_inclusive <= max_inclusive, "Random range minimum must not exceed maximum.")
	_draw_count += 1
	return _rng.randi_range(min_inclusive, max_inclusive)


func next_float() -> float:
	_draw_count += 1
	return _rng.randf()


func get_draw_count() -> int:
	return _draw_count


func to_dictionary() -> Dictionary:
	return {"seed": _seed_value, "draw_count": _draw_count}
