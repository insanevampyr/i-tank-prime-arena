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


func wave_entry_state() -> Dictionary:
	# Strings preserve every signed 64-bit bit through JSON. Not a snapshot change.
	return {"seed":str(_seed_value),"state":str(_rng.state),"draw_count":_draw_count}


func restore_wave_entry(value: Dictionary) -> bool:
	if value.size() != 3 or not value.has_all(["seed","state","draw_count"]): return false
	if not value.seed is String or not value.state is String or not value.seed.is_valid_int() or not value.state.is_valid_int(): return false
	if (typeof(value.draw_count) != TYPE_INT and typeof(value.draw_count) != TYPE_FLOAT) or not is_finite(float(value.draw_count)) or value.draw_count < 0 or value.draw_count > 9007199254740991 or floor(float(value.draw_count)) != float(value.draw_count): return false
	_seed_value = value.seed.to_int()
	_rng.seed = _seed_value
	_rng.state = value.state.to_int()
	_draw_count = int(value.draw_count)
	return true
