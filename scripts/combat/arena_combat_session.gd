class_name ArenaCombatSession
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")

const DEFAULT_SEED := 1
const MICROFEET_PER_FOOT := 1_000_000
const ENCOUNTER_READY := "ready"
const ENCOUNTER_RUNNING := "running"
const ENCOUNTER_PLAYER_VICTORY := "player_victory"
const ENCOUNTER_PLAYER_DEFEAT := "player_defeat"
const ENCOUNTER_DOUBLE_DEFEAT := "double_defeat"
const OPPONENT_BEHAVIOR_LABEL := "task15_deterministic_test_opponent"
const OPPONENT_MOVEMENT_TICK_US := 100_000

var simulation: CombatSimulation

var _attack_definition: CombatAttackDefinition
var _selected_target_id: StringName = &""
var _active_player_attack_id: String = ""
var _active_opponent_attack_id: String = ""
var _next_request_sequence: int = 0
var _last_error: String = ""
var _arena_bounds_microfeet := Rect2i(-100_000_000, -100_000_000, 200_000_000, 200_000_000)
var _battlefield: ArenaBattlefield = ArenaBattlefield.create_open(_arena_bounds_microfeet)
var _seed_value: int
var _uses_external_simulation: bool = false
var _initialized: bool = false
var _encounter_active: bool = true
var _encounter_state: String = ENCOUNTER_RUNNING
var _opponent_behavior_enabled: bool = false
var _opponent_behavior_status: String = "disabled"
var _initial_player_position_microfeet := Vector2i.ZERO
var _initial_opponent_position_microfeet := Vector2i.ZERO
var _opponent_path: Array[Vector2i] = []
var _opponent_movement_remainder: int = 0
var _opponent_last_movement_us: int = 0
var _player_movement_round_index: int = -1
var _player_movement_spent_microfeet: int = 0


func _init(seed_value: int = DEFAULT_SEED, existing_simulation: CombatSimulation = null) -> void:
	_seed_value = seed_value
	_uses_external_simulation = existing_simulation != null
	simulation = existing_simulation if existing_simulation != null else CombatSimulation.new(seed_value)


func initialize(
	player_position_microfeet: Vector2i,
	opponent_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = opponent_position_microfeet
	var initial_occupancy := {
		String(Fixture.PLAYER_ID): player_position_microfeet,
		String(Fixture.OPPONENT_ID): opponent_position_microfeet,
	}
	var player_position_check := _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, initial_occupancy)
	if not player_position_check["legal"]:
		return _failure("player_%s" % player_position_check["reason"])
	var opponent_position_check := _battlefield.is_position_legal(Fixture.OPPONENT_ID, opponent_position_microfeet, initial_occupancy)
	if not opponent_position_check["legal"]:
		return _failure("opponent_%s" % opponent_position_check["reason"])
	var result := Fixture.configure_simulation(simulation, player_position_microfeet, opponent_position_microfeet)
	if result.get("success", false):
		_attack_definition = result["attack_definition"]
		_selected_target_id = Fixture.OPPONENT_ID
		_initialized = true
		_encounter_active = start_active
		_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
		_opponent_behavior_status = "idle" if _opponent_behavior_enabled else "disabled"
		_opponent_path.clear()
		_opponent_movement_remainder = 0
		_opponent_last_movement_us = simulation.clock.get_elapsed_us()
		_player_movement_round_index = simulation.clock.get_round_index()
		_player_movement_spent_microfeet = 0
		_last_error = ""
	else:
		_initialized = false
		_encounter_active = false
		_last_error = String(result.get("reason", "fixture_initialization_failed"))
	return result


func set_opponent_behavior_enabled(enabled: bool) -> void:
	_opponent_behavior_enabled = enabled
	_opponent_behavior_status = "idle" if enabled else "disabled"
	if enabled and _encounter_active:
		_run_opponent_behavior()


func start_encounter() -> Dictionary:
	if not _initialized:
		return _failure("encounter_not_initialized")
	if _encounter_active:
		return _failure("encounter_already_running")
	if _encounter_state != ENCOUNTER_READY:
		return _failure("encounter_requires_reset")
	_encounter_active = true
	_encounter_state = ENCOUNTER_RUNNING
	_last_error = ""
	_run_opponent_behavior()
	return {"success": true, "encounter_state": _encounter_state}


func reset_encounter(start_active: bool = false) -> Dictionary:
	if _uses_external_simulation:
		return _failure("external_simulation_reset_unsupported")
	simulation = CombatSimulation.new(_seed_value)
	_attack_definition = null
	_selected_target_id = &""
	_active_player_attack_id = ""
	_active_opponent_attack_id = ""
	_next_request_sequence = 0
	_last_error = ""
	_initialized = false
	_encounter_active = false
	_encounter_state = ENCOUNTER_READY
	_opponent_behavior_status = "idle" if _opponent_behavior_enabled else "disabled"
	return initialize(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)


func set_arena_bounds_microfeet(bounds: Rect2i) -> void:
	if bounds.size.x > 0 and bounds.size.y > 0:
		_arena_bounds_microfeet = bounds
		_battlefield = ArenaBattlefield.create_open(bounds)


func configure_battlefield(battlefield: ArenaBattlefield) -> void:
	assert(battlefield != null, "Combat session requires an authoritative battlefield.")
	_battlefield = battlefield
	_arena_bounds_microfeet = battlefield.bounds_microfeet
	_opponent_path.clear()


func get_battlefield() -> ArenaBattlefield:
	return _battlefield


func select_target(target_id: StringName) -> Dictionary:
	if target_id != Fixture.OPPONENT_ID:
		_selected_target_id = &""
		_last_error = "invalid_target"
		return {"success": false, "reason": _last_error}
	var target_state := simulation.get_actor_state(target_id)
	if target_state == null or target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		_selected_target_id = &""
		_last_error = "target_not_eligible"
		return {"success": false, "reason": _last_error}
	_selected_target_id = target_id
	_last_error = ""
	return {"success": true, "target_id": String(target_id)}


func clear_target() -> void:
	_selected_target_id = &""
	_last_error = "no_target_selected"


func update_player_position(position_microfeet: Vector2i) -> Dictionary:
	if not _encounter_active:
		return _failure("encounter_not_running")
	if _battlefield.navigation_authoritative:
		var player_definition := _actor_definition_snapshot(Fixture.PLAYER_ID)
		return request_player_movement(position_microfeet, int(player_definition.get("combat_stats", {}).get("mr", 0)))
	var result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, position_microfeet, 0)
	if not result.get("success", false):
		_last_error = String(result.get("reason", "position_update_rejected"))
	return result


func request_player_movement(position_microfeet: Vector2i, effective_mr: int) -> Dictionary:
	if not _encounter_active:
		return _movement_rejected("encounter_not_running")
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return _movement_rejected("player_unavailable")
	if player_state.conditions.has("prone"):
		return _movement_rejected("movement_blocked_while_prone", player_state.position_microfeet)
	if effective_mr < 0:
		return _movement_rejected("invalid_effective_mr", player_state.position_microfeet)
	var resolved := _battlefield.resolve_motion(
		Fixture.PLAYER_ID,
		player_state.position_microfeet,
		position_microfeet,
		_actor_occupancy()
	)
	if not resolved.get("success", false):
		return _movement_rejected(String(resolved.get("reason", "movement_geometry_rejected")), player_state.position_microfeet)
	var destination: Vector2i = resolved["position_microfeet"]
	var movement_cost := int(resolved["movement_cost_microfeet"])
	if movement_cost == 0:
		return {
			"success": true,
			"position_microfeet": destination,
			"movement_cost_microfeet": 0,
			"blocked": resolved["blocked"],
			"reason": resolved["reason"],
		}
	_refresh_player_movement_ledger()
	var allowance := effective_mr * MICROFEET_PER_FOOT
	var remaining := maxi(0, allowance - _player_movement_spent_microfeet)
	if movement_cost > remaining:
		var start := player_state.position_microfeet
		var delta := destination - start
		if remaining <= 0:
			return _movement_rejected("insufficient_remaining_mr", start)
		destination = start + Vector2i(
			roundi(float(delta.x) * float(remaining) / float(movement_cost)),
			roundi(float(delta.y) * float(remaining) / float(movement_cost))
		)
		resolved = _battlefield.resolve_motion(Fixture.PLAYER_ID, start, destination, _actor_occupancy())
		destination = resolved["position_microfeet"]
		movement_cost = int(resolved["movement_cost_microfeet"])
	player_state.movement_round_index = simulation.clock.get_round_index()
	player_state.remaining_mr_microfeet = remaining
	var result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, destination, player_state.facing_millidegrees, movement_cost)
	if not result.get("success", false):
		return _movement_rejected(String(result.get("reason", "position_update_rejected")), player_state.position_microfeet)
	_player_movement_spent_microfeet += movement_cost
	_opponent_path.clear()
	return {
		"success": true,
		"position_microfeet": destination,
		"movement_cost_microfeet": movement_cost,
		"blocked": resolved["blocked"] or destination != position_microfeet,
		"reason": resolved["reason"],
	}


func request_player_attack(input_source: String) -> Dictionary:
	var legality := get_attack_legality()
	if not legality.get("success", false):
		_last_error = String(legality.get("reason", "attack_illegal"))
		return legality
	var result := _request_actor_attack(Fixture.PLAYER_ID, _selected_target_id, input_source)
	if result.get("success", false):
		_active_player_attack_id = String(result["attack_instance_id"])
		_last_error = ""
		_run_opponent_behavior()
	else:
		_last_error = String(result.get("reason", "attack_rejected"))
	return result


func get_attack_legality() -> Dictionary:
	if _selected_target_id == &"":
		return {"success": false, "reason": "no_target_selected"}
	return _get_actor_attack_legality(Fixture.PLAYER_ID, _selected_target_id)


func get_opponent_attack_legality() -> Dictionary:
	return _get_actor_attack_legality(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, true)


func request_player_stand(input_source: String) -> Dictionary:
	if not _encounter_active:
		return _failure("encounter_not_running")
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null or player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		return _failure("player_defeated")
	if not player_state.conditions.has("prone"):
		return _failure("player_not_prone")
	var result := simulation.start_stand_action(Fixture.PLAYER_ID, _next_request_id("%s_stand" % input_source))
	if not result.get("success", false):
		_last_error = String(result.get("reason", "stand_rejected"))
	else:
		_last_error = ""
		_run_opponent_behavior()
	return result


func is_actor_prone(actor_id: StringName) -> bool:
	var state := simulation.get_actor_state(actor_id)
	return state != null and state.conditions.has("prone")


func _get_actor_attack_legality(attacker_id: StringName, target_id: StringName, require_awareness: bool = false) -> Dictionary:
	var attacker_state := simulation.get_actor_state(attacker_id)
	var target_state := simulation.get_actor_state(target_id)
	if attacker_state == null:
		return {"success": false, "reason": "attacker_unavailable"}
	if target_state == null:
		return {"success": false, "reason": "invalid_target"}
	if attacker_state.current_hpc == null or int(attacker_state.current_hpc) <= 0:
		return {"success": false, "reason": "attacker_defeated"}
	if target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return {"success": false, "reason": "target_defeated"}
	if not _encounter_active:
		return {"success": false, "reason": "encounter_not_running"}
	if _encounter_state != ENCOUNTER_RUNNING:
		return {"success": false, "reason": "encounter_complete"}
	if require_awareness and attacker_state.awareness != &"aware":
		return {"success": false, "reason": "attacker_unaware"}
	if attacker_state.conditions.has("prone"):
		return {"success": false, "reason": "actor_prone"}
	if attacker_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
		return {"success": false, "reason": "actor_critically_staggered"}
	if not attacker_state.current_action_instance_id.is_empty() or _is_actor_attack_in_flight(attacker_id):
		return {"success": false, "reason": "attack_in_progress"}
	if not attacker_state.equipment_refs.has(String(_attack_definition.weapon_ref)):
		return {"success": false, "reason": "weapon_not_equipped"}
	var offset := target_state.position_microfeet - attacker_state.position_microfeet
	var maximum_range := int(_attack_definition.maximum_range_microfeet)
	if offset.length_squared() > maximum_range * maximum_range:
		return {
			"success": false,
			"reason": "target_out_of_range",
			"distance_microfeet": roundi(Vector2(offset).length()),
			"maximum_range_microfeet": maximum_range,
		}
	if _attack_definition.requires_line_of_sight \
		and not _battlefield.has_line_of_sight(attacker_state.position_microfeet, target_state.position_microfeet):
		return {
			"success": false,
			"reason": "line_of_sight_blocked",
			"distance_microfeet": roundi(Vector2(offset).length()),
			"maximum_range_microfeet": maximum_range,
		}
	return {
		"success": true,
		"distance_microfeet": roundi(Vector2(offset).length()),
		"maximum_range_microfeet": maximum_range,
	}


func advance_by(delta_us: int) -> void:
	if delta_us < 0:
		_last_error = "negative_time_delta"
		return
	if not _encounter_active:
		return
	var target_timestamp_us := simulation.clock.get_elapsed_us() + delta_us
	_run_opponent_behavior()
	var iterations := 0
	while simulation.clock.get_elapsed_us() < target_timestamp_us:
		iterations += 1
		if iterations > 10_000:
			_last_error = "encounter_advance_iteration_limit"
			return
		var step_timestamp_us := target_timestamp_us
		var movement_tick_us := -1
		if not simulation.event_queue.is_empty():
			step_timestamp_us = mini(step_timestamp_us, (simulation.event_queue.peek_next() as CombatEvent).timestamp_us)
		if _opponent_behavior_enabled and _battlefield.navigation_authoritative:
			movement_tick_us = _next_opponent_movement_tick_us(simulation.clock.get_elapsed_us())
			step_timestamp_us = mini(step_timestamp_us, movement_tick_us)
		simulation.advance_to(step_timestamp_us)
		if step_timestamp_us == movement_tick_us:
			_advance_opponent_approach(step_timestamp_us - _opponent_last_movement_us)
			_opponent_last_movement_us = step_timestamp_us
		_resolve_ready_attack_pipeline()
		_refresh_active_attacks()
		_update_encounter_outcome()
		if not _encounter_active:
			break
		_run_opponent_behavior()
		if step_timestamp_us == target_timestamp_us:
			break


func get_selected_target_id() -> StringName:
	return _selected_target_id


func get_active_player_attack_id() -> String:
	return _active_player_attack_id


func get_active_opponent_attack_id() -> String:
	return _active_opponent_attack_id


func get_active_player_attack_status() -> String:
	return _get_active_attack_status(_active_player_attack_id)


func get_active_opponent_attack_status() -> String:
	return _get_active_attack_status(_active_opponent_attack_id)


func is_player_attack_in_flight() -> bool:
	return _is_attack_in_flight(_active_player_attack_id)


func is_opponent_attack_in_flight() -> bool:
	return _is_attack_in_flight(_active_opponent_attack_id)


func is_encounter_active() -> bool:
	return _encounter_active


func get_encounter_state() -> String:
	return _encounter_state


func get_opponent_behavior_status() -> String:
	return _opponent_behavior_status


func get_opponent_behavior_label() -> String:
	return OPPONENT_BEHAVIOR_LABEL


func get_last_error() -> String:
	return _last_error


func get_actor_state(actor_id: StringName) -> CombatActorState:
	return simulation.get_actor_state(actor_id)


func get_resolved_events() -> Array:
	return simulation.get_resolved_events()


func get_state_snapshot() -> Dictionary:
	var snapshot := simulation.get_state_snapshot()
	snapshot["battlefield"] = _battlefield.to_dictionary()
	snapshot["opponent_behavior_status"] = _opponent_behavior_status
	snapshot["opponent_path"] = _serialize_vector_path(_opponent_path)
	snapshot["opponent_movement_remainder"] = _opponent_movement_remainder
	snapshot["player_movement_round_index"] = _player_movement_round_index
	snapshot["player_movement_spent_microfeet"] = _player_movement_spent_microfeet
	return snapshot


func _request_actor_attack(attacker_id: StringName, target_id: StringName, input_source: String) -> Dictionary:
	var request_id := _next_request_id("%s_%s_attack" % [String(attacker_id), input_source])
	var result := simulation.start_physical_attack(
		attacker_id,
		target_id,
		_attack_definition,
		request_id,
		&"torso",
		_battlefield.has_line_of_sight(
			simulation.get_actor_state(attacker_id).position_microfeet,
			simulation.get_actor_state(target_id).position_microfeet
		)
	)
	if not result.get("success", false):
		return result
	var attack_id := String(result["attack_instance_id"])
	if attacker_id == Fixture.PLAYER_ID:
		_active_player_attack_id = attack_id
	elif attacker_id == Fixture.OPPONENT_ID:
		_active_opponent_attack_id = attack_id
	return result


func _run_opponent_behavior() -> void:
	if not _opponent_behavior_enabled:
		_opponent_behavior_status = "disabled"
		return
	if not _encounter_active or _encounter_state != ENCOUNTER_RUNNING:
		_opponent_behavior_status = "stopped"
		return
	var opponent_state := simulation.get_actor_state(Fixture.OPPONENT_ID)
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if opponent_state == null or player_state == null:
		_opponent_behavior_status = "blocked_missing_actor_state"
		return
	if opponent_state.current_hpc == null or int(opponent_state.current_hpc) <= 0:
		_opponent_behavior_status = "stopped_defeated"
		return
	if player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		_opponent_behavior_status = "stopped_target_defeated"
		return
	if opponent_state.awareness != &"aware":
		_opponent_behavior_status = "blocked_unaware"
		return
	if opponent_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
		_opponent_behavior_status = "blocked_critical_stagger"
		return
	if not opponent_state.current_action_instance_id.is_empty() or is_opponent_attack_in_flight():
		_opponent_behavior_status = "action_in_progress"
		return
	if opponent_state.conditions.has("prone"):
		var stand_result := simulation.start_stand_action(
			Fixture.OPPONENT_ID,
			_next_request_id("opponent_stand")
		)
		_opponent_behavior_status = "standing" if stand_result.get("success", false) else "blocked_%s" % String(stand_result.get("reason", "stand_rejected"))
		return
	var legality := get_opponent_attack_legality()
	if not legality.get("success", false):
		var reason := String(legality.get("reason", "attack_illegal"))
		if reason == "target_out_of_range":
			if not _battlefield.navigation_authoritative:
				_opponent_behavior_status = "approach_blocked_unverified_path"
				return
			var path_result := {"success": true, "reason": "existing_path"} if not _opponent_path.is_empty() else _build_opponent_approach_path()
			if path_result.get("success", false):
				_opponent_behavior_status = "approaching"
			else:
				_opponent_behavior_status = "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))
		else:
			_opponent_behavior_status = "blocked_%s" % reason
		return
	var result := _request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "scripted")
	_opponent_behavior_status = "attacking" if result.get("success", false) else "blocked_%s" % String(result.get("reason", "attack_rejected"))


func _update_encounter_outcome() -> void:
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	var opponent_state := simulation.get_actor_state(Fixture.OPPONENT_ID)
	if player_state == null or opponent_state == null:
		return
	var player_defeated := player_state.current_hpc != null and int(player_state.current_hpc) <= 0
	var opponent_defeated := opponent_state.current_hpc != null and int(opponent_state.current_hpc) <= 0
	if not player_defeated and not opponent_defeated:
		return
	if player_defeated and opponent_defeated:
		_encounter_state = ENCOUNTER_DOUBLE_DEFEAT
	elif opponent_defeated:
		_encounter_state = ENCOUNTER_PLAYER_VICTORY
	else:
		_encounter_state = ENCOUNTER_PLAYER_DEFEAT
	_encounter_active = false
	_opponent_behavior_status = "stopped"


func _get_active_attack_status(attack_id: String) -> String:
	if attack_id.is_empty():
		return "idle"
	var attack := simulation.get_attack(attack_id)
	return "unavailable" if attack == null else String(attack.status)


func _is_attack_in_flight(attack_id: String) -> bool:
	if attack_id.is_empty():
		return false
	var attack := simulation.get_attack(attack_id)
	if attack == null:
		return false
	return attack.status == CombatAttackInstance.STATUS_EXECUTING \
		or attack.status == CombatAttackInstance.STATUS_PENDING_DEFENSE \
		or attack.status == CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT \
		or attack.status == CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED


func _is_actor_attack_in_flight(actor_id: StringName) -> bool:
	if actor_id == Fixture.PLAYER_ID:
		return is_player_attack_in_flight()
	if actor_id == Fixture.OPPONENT_ID:
		return is_opponent_attack_in_flight()
	return false


func _failure(reason: String) -> Dictionary:
	_last_error = reason
	return {"success": false, "reason": reason}


func _resolve_ready_attack_pipeline() -> void:
	var changed := true
	while changed:
		changed = false
		var attack_snapshots: Array = simulation.get_state_snapshot()["attacks"]
		for attack_snapshot: Dictionary in attack_snapshots:
			var attack_id := String(attack_snapshot["attack_instance_id"])
			var status := String(attack_snapshot["status"])
			if status == CombatAttackInstance.STATUS_PENDING_DEFENSE:
				var defense_result := simulation.resolve_pending_defense_automatically(
					attack_id,
					_next_request_id("defense"),
					_make_dodge_environment(simulation.get_attack(attack_id))
				)
				if not defense_result.get("success", false):
					_last_error = String(defense_result.get("reason", "defense_resolution_failed"))
				else:
					changed = true
			elif status == CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED:
				var damage_result := simulation.resolve_physical_damage(attack_id, _next_request_id("damage"))
				if not damage_result.get("success", false):
					_last_error = String(damage_result.get("reason", "damage_resolution_failed"))
				else:
					changed = true


func _make_dodge_environment(attack: CombatAttackInstance) -> CombatDodgeEnvironment:
	var defender_state := simulation.get_actor_state(attack.target_id)
	var attacker_state := simulation.get_actor_state(attack.attacker_id)
	var candidates: Array[CombatDodgeCandidate] = []
	if defender_state == null or attacker_state == null:
		return CombatDodgeEnvironment.new(&"task14_incomplete", false, candidates, "Task 14 fixture actor state unavailable")
	var defender_definition: Dictionary = _actor_definition_snapshot(attack.target_id)
	var maximum_dodge_feet := floori(float(int(defender_definition.get("combat_stats", {}).get("mr", 0))) / 2.0)
	var maximum_attack_range := int(_attack_definition.maximum_range_microfeet)
	var candidate_facts := _battlefield.build_dodge_candidate_facts(
		attack.target_id,
		defender_state.position_microfeet,
		attacker_state.position_microfeet,
		maximum_dodge_feet,
		maximum_attack_range,
		_actor_occupancy()
	)
	for fact: Dictionary in candidate_facts:
		candidates.append(CombatDodgeCandidate.new(
			StringName(fact["id"]),
			fact["destination_microfeet"],
			fact["movement_cost_microfeet"],
			false,
			fact["path_valid"],
			fact["collision_free"],
			fact["terrain_legal"],
			fact["unoccupied"],
			fact["escapes_attack"],
			false,
			fact["hazard_tier"],
			"Task 16 authoritative battlefield geometry; no authored special hazards"
		))
	return CombatDodgeEnvironment.new(
		&"task16_authoritative_battlefield",
		true,
		candidates,
		"Task 16 authoritative bounds, obstacle, occupancy and path facts; no in-place duck because Battle Axe duck eligibility is unresolved"
	)


func _actor_definition_snapshot(actor_id: StringName) -> Dictionary:
	for actor_snapshot: Dictionary in simulation.get_state_snapshot()["actors"]:
		var definition: Dictionary = actor_snapshot["definition"]
		if String(definition["actor_id"]) == String(actor_id):
			return definition
	return {}


func _actor_occupancy() -> Dictionary:
	var occupancy := {}
	for actor_id: StringName in [Fixture.PLAYER_ID, Fixture.OPPONENT_ID]:
		var state := simulation.get_actor_state(actor_id)
		if state != null:
			occupancy[String(actor_id)] = state.position_microfeet
	return occupancy


func _movement_rejected(reason: String, position: Vector2i = Vector2i.ZERO) -> Dictionary:
	_last_error = reason
	return {
		"success": false,
		"reason": reason,
		"position_microfeet": position,
		"movement_cost_microfeet": 0,
		"blocked": true,
	}


func _refresh_player_movement_ledger() -> void:
	var round_index := simulation.clock.get_round_index()
	if _player_movement_round_index == round_index:
		return
	_player_movement_round_index = round_index
	_player_movement_spent_microfeet = 0


func _next_opponent_movement_tick_us(current_us: int) -> int:
	@warning_ignore("integer_division")
	var next_tick := (current_us / OPPONENT_MOVEMENT_TICK_US + 1) * OPPONENT_MOVEMENT_TICK_US
	var round_index := simulation.clock.get_round_index_at(current_us)
	var next_round_boundary := (round_index + 1) * CombatClock.ROUND_DURATION_US
	if next_tick == next_round_boundary and current_us < next_round_boundary - 1:
		return next_round_boundary - 1
	return next_tick


func _build_opponent_approach_path() -> Dictionary:
	var opponent_state := simulation.get_actor_state(Fixture.OPPONENT_ID)
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if opponent_state == null or player_state == null:
		_opponent_path.clear()
		return {"success": false, "reason": "missing_actor_state"}
	var path_result := _battlefield.find_path_to_attack_position(
		Fixture.OPPONENT_ID,
		opponent_state.position_microfeet,
		player_state.position_microfeet,
		int(_attack_definition.maximum_range_microfeet),
		_actor_occupancy()
	)
	_opponent_path.clear()
	if path_result.get("success", false):
		for waypoint: Vector2i in path_result["waypoints"]:
			_opponent_path.append(waypoint)
	return path_result


func _advance_opponent_approach(delta_us: int) -> void:
	if delta_us <= 0 or not _encounter_active or not _opponent_behavior_enabled:
		return
	var legality := get_opponent_attack_legality()
	if legality.get("success", false) or String(legality.get("reason", "")) != "target_out_of_range":
		return
	var opponent_state := simulation.get_actor_state(Fixture.OPPONENT_ID)
	if opponent_state == null or opponent_state.conditions.has("prone") \
		or opponent_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
		return
	var path_result := {"success": true, "reason": "existing_path"} if not _opponent_path.is_empty() else _build_opponent_approach_path()
	if not path_result.get("success", false) or _opponent_path.is_empty():
		_opponent_behavior_status = "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))
		return
	var definition := _actor_definition_snapshot(Fixture.OPPONENT_ID)
	var movement_rate := int(definition.get("combat_stats", {}).get("mr", 0))
	if movement_rate <= 0:
		_opponent_behavior_status = "approach_blocked_no_movement_rate"
		return
	var numerator := delta_us * movement_rate * MICROFEET_PER_FOOT + _opponent_movement_remainder
	@warning_ignore("integer_division")
	var movement_budget := numerator / CombatClock.ROUND_DURATION_US
	_opponent_movement_remainder = numerator % CombatClock.ROUND_DURATION_US
	if movement_budget <= 0:
		return
	var destination: Vector2i = _opponent_path[0]
	var offset := destination - opponent_state.position_microfeet
	var distance := roundi(Vector2(offset).length())
	if distance > movement_budget:
		destination = opponent_state.position_microfeet + Vector2i(
			roundi(float(offset.x) * float(movement_budget) / float(distance)),
			roundi(float(offset.y) * float(movement_budget) / float(distance))
		)
	var resolved := _battlefield.resolve_motion(
		Fixture.OPPONENT_ID,
		opponent_state.position_microfeet,
		destination,
		_actor_occupancy()
	)
	if not resolved.get("success", false) or int(resolved.get("movement_cost_microfeet", 0)) <= 0:
		_opponent_behavior_status = "approach_blocked_collision"
		_opponent_path.clear()
		return
	var movement_result := simulation.apply_authoritative_position(
		Fixture.OPPONENT_ID,
		resolved["position_microfeet"],
		opponent_state.facing_millidegrees,
		int(resolved["movement_cost_microfeet"])
	)
	if not movement_result.get("success", false):
		var reason := String(movement_result.get("reason", "movement_rejected"))
		_opponent_behavior_status = "approach_waiting_for_mr" if reason == "insufficient_remaining_mr" else "approach_blocked_%s" % reason
		return
	if resolved["position_microfeet"] == _opponent_path[0]:
		_opponent_path.pop_front()
	_opponent_behavior_status = "approaching"


func _serialize_vector_path(path: Array[Vector2i]) -> Array:
	var serialized: Array = []
	for point: Vector2i in path:
		serialized.append([point.x, point.y])
	return serialized


func _next_request_id(kind: String) -> String:
	_next_request_sequence += 1
	return "task14_%s_%06d" % [kind, _next_request_sequence]


func _refresh_active_attacks() -> void:
	if not is_player_attack_in_flight():
		_active_player_attack_id = ""
	if not is_opponent_attack_in_flight():
		_active_opponent_attack_id = ""
