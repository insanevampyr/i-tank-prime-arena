class_name DeterministicCombatRng
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed_value: int


func _init(seed_value: int) -> void:
	_seed_value = seed_value
	_rng.seed = seed_value


func get_seed_value() -> int:
	return _seed_value


func next_int(min_inclusive: int, max_inclusive: int) -> int:
	assert(min_inclusive <= max_inclusive, "Random range minimum must not exceed maximum.")
	return _rng.randi_range(min_inclusive, max_inclusive)


func next_float() -> float:
	return _rng.randf()
