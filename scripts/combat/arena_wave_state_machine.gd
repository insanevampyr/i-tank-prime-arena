class_name ArenaWaveStateMachine
extends RefCounted

const Catalog = preload("res://scripts/combat/arena_wave_catalog.gd")

const STATE_UNINITIALIZED := "uninitialized"
const STATE_BLOCKED := "blocked_creature_integration"
const STATE_ACTIVE := "active_combat"
const STATE_VICTORY_DETECTED := "victory_detected"
const STATE_BETWEEN_WAVE_RECOVERY := "between_wave_recovery"
const STATE_COMPLETE := "complete"

var _definitions: Array[Dictionary] = Catalog.definitions()
var _state: String = STATE_UNINITIALIZED
var _current_wave_index: int = -1
var _resolved_roster: Array[Dictionary] = []
var _active_enemy_ids: PackedStringArray = PackedStringArray()
var _available_creature_integrations: Dictionary = {}


func initialize(roll_quantity: Callable) -> Dictionary:
	if _state != STATE_UNINITIALIZED:
		return _failure("wave_circuit_already_initialized")
	_current_wave_index = 0
	return _initialize_current_wave(roll_quantity, true)


func set_creature_integration_available(creature_id: StringName, available: bool) -> void:
	_available_creature_integrations[String(creature_id)] = available


func activate_current_wave(active_enemy_ids: PackedStringArray) -> Dictionary:
	if _state != STATE_BLOCKED:
		return _failure("wave_not_ready_for_activation")
	var missing := _missing_creature_integrations()
	if not missing.is_empty():
		return _failure("creature_integration_unavailable", {"missing_creature_ids": missing})
	if active_enemy_ids.size() != _resolved_enemy_count():
		return _failure("active_enemy_count_mismatch", {
			"expected": _resolved_enemy_count(),
			"received": active_enemy_ids.size(),
		})
	var ordered_ids := active_enemy_ids.duplicate()
	ordered_ids.sort()
	if ordered_ids.size() != _unique_count(ordered_ids):
		return _failure("duplicate_active_enemy_id")
	_active_enemy_ids = ordered_ids
	_state = STATE_ACTIVE
	return _success_with_events([_event(&"arena_wave_activated", {
		"wave_id": _current_wave_id(),
		"active_enemy_ids": Array(_active_enemy_ids),
		"resolved_enemy_count": _resolved_enemy_count(),
	})])


func observe_active_enemy_states(authoritative_enemy_states: Dictionary) -> Dictionary:
	if _state != STATE_ACTIVE:
		return _failure("wave_not_active")
	for enemy_id: String in _active_enemy_ids:
		if not authoritative_enemy_states.has(enemy_id):
			return _failure("active_enemy_state_missing", {"actor_id": enemy_id})
		var state: Dictionary = authoritative_enemy_states[enemy_id]
		if not bool(state.get("defeated", false)):
			return _success_with_events([])
	_state = STATE_VICTORY_DETECTED
	return _success_with_events([_event(&"arena_wave_victory_detected", {
		"wave_id": _current_wave_id(),
		"defeated_enemy_ids": Array(_active_enemy_ids),
	})])


func begin_between_wave_recovery() -> Dictionary:
	if _state != STATE_VICTORY_DETECTED:
		return _failure("wave_victory_not_detected")
	if _current_wave_index + 1 >= _definitions.size():
		_state = STATE_COMPLETE
		_active_enemy_ids = PackedStringArray()
		return _success_with_events([_event(&"arena_wave_circuit_completed", {
			"wave_id": _current_wave_id(),
		})])
	_state = STATE_BETWEEN_WAVE_RECOVERY
	return _success_with_events([_event(&"arena_wave_recovery_started", {
		"wave_id": _current_wave_id(),
	})])


func complete_between_wave_recovery(roll_quantity: Callable) -> Dictionary:
	if _state != STATE_BETWEEN_WAVE_RECOVERY:
		return _failure("wave_recovery_not_active")
	_current_wave_index += 1
	_active_enemy_ids = PackedStringArray()
	return _initialize_current_wave(roll_quantity, false)


func get_state() -> String:
	return _state


func get_current_wave_id() -> String:
	return _current_wave_id()


func get_resolved_enemy_count() -> int:
	return _resolved_enemy_count()


func get_active_enemy_ids() -> PackedStringArray:
	return _active_enemy_ids.duplicate()


func to_dictionary() -> Dictionary:
	return {
		"state": _state,
		"current_wave_index": _current_wave_index,
		"current_wave_id": _current_wave_id(),
		"resolved_roster": _resolved_roster.duplicate(true),
		"active_enemy_ids": Array(_active_enemy_ids),
		"missing_creature_integrations": _missing_creature_integrations(),
		"future_extension_points": Array(Catalog.future_extension_points()),
	}


func _initialize_current_wave(roll_quantity: Callable, is_circuit_initialization: bool) -> Dictionary:
	_resolved_roster.clear()
	var events: Array[Dictionary] = []
	if is_circuit_initialization:
		events.append(_event(&"arena_wave_circuit_initialized", {
			"wave_count": _definitions.size(),
			"future_extension_points": Array(Catalog.future_extension_points()),
		}))
	for entry: Dictionary in _current_definition().get("roster", []):
		var quantity: Dictionary = entry["quantity"]
		var resolved_count: int
		var rng_draw_index: Variant = null
		var rng_draw_indices: Array[int] = []
		var dice_results: Array[int] = []
		var dice_count := 0
		if quantity.get("kind") == "dice":
			dice_count = int(quantity.get("dice_count", 1))
			resolved_count = 0
			for unused_die in range(dice_count):
				var roll: Dictionary = roll_quantity.call(int(quantity["sides"]))
				var die_result := int(roll["value"])
				dice_results.append(die_result)
				resolved_count += die_result
				if roll.get("rng_draw_index") != null:
					rng_draw_indices.append(int(roll["rng_draw_index"]))
			rng_draw_index = null if rng_draw_indices.is_empty() else rng_draw_indices[0]
		else:
			resolved_count = int(quantity["count"])
		var resolved := {
			"creature_id": String(entry["creature_id"]),
			"display_name": String(entry["display_name"]),
			"quantity_kind": String(quantity["kind"]),
			"dice_sides": null if quantity.get("kind") != "dice" else int(quantity["sides"]),
			"dice_count": dice_count,
			"dice_results": dice_results,
			"rng_draw_index": rng_draw_index,
			"rng_draw_indices": rng_draw_indices,
			"resolved_count": resolved_count,
			"creature_integration_status": String(entry["creature_integration_status"]),
		}
		_resolved_roster.append(resolved)
		events.append(_event(&"arena_wave_quantity_resolved", {
			"wave_id": _current_wave_id(),
			"entry": resolved.duplicate(true),
		}))
	_state = STATE_BLOCKED
	var missing := _missing_creature_integrations()
	events.append(_event(&"arena_wave_blocked", {
		"wave_id": _current_wave_id(),
		"reason": "creature_integration_unavailable",
		"missing_creature_ids": missing,
		"resolved_enemy_count": _resolved_enemy_count(),
	}))
	return _success_with_events(events)


func _current_definition() -> Dictionary:
	if _current_wave_index < 0 or _current_wave_index >= _definitions.size():
		return {}
	return _definitions[_current_wave_index]


func _current_wave_id() -> String:
	return String(_current_definition().get("wave_id", ""))


func _missing_creature_integrations() -> Array[String]:
	var missing: Array[String] = []
	for entry: Dictionary in _current_definition().get("roster", []):
		var creature_id := String(entry["creature_id"])
		if not bool(_available_creature_integrations.get(creature_id, false)):
			missing.append(creature_id)
	return missing


func _resolved_enemy_count() -> int:
	var total := 0
	for entry: Dictionary in _resolved_roster:
		total += int(entry["resolved_count"])
	return total


func _event(event_type: StringName, payload: Dictionary) -> Dictionary:
	return {"event_type": String(event_type), "payload": payload.duplicate(true)}


func _unique_count(values: PackedStringArray) -> int:
	var seen := {}
	for value: String in values:
		seen[value] = true
	return seen.size()


func _success_with_events(events: Array[Dictionary]) -> Dictionary:
	return {"success": true, "events": events}


func _failure(reason: String, detail: Dictionary = {}) -> Dictionary:
	var result := {"success": false, "reason": reason}
	for key: Variant in detail:
		result[key] = detail[key]
	return result
