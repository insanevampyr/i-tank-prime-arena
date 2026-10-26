class_name ArenaCombatSession
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const PrimeMovementModel = preload("res://scripts/movement/prime_movement_model.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const CommonGoblinFixture = preload("res://scripts/creatures/common_goblin_fixture.gd")
const CommonSpadoodleFixture = preload("res://scripts/creatures/common_spadoodle_fixture.gd")
const CommonSkellyFixture = preload("res://scripts/creatures/common_skelly_fixture.gd")
const HadesCombatFollowerFixture = preload("res://scripts/creatures/hades_combat_follower_fixture.gd")
const MiniGargoyleSwarmerFixture = preload("res://scripts/creatures/mini_gargoyle_swarmer_fixture.gd")
const RareHumanWarriorFixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
const RareHumanWarriorBossAI = preload("res://scripts/creatures/rare_human_warrior_boss_ai.gd")
const VaelisForce = preload("res://scripts/combat/vaelis_force_fixture.gd")

const DEFAULT_SEED := 1
const MICROFEET_PER_FOOT := 1_000_000
const ENCOUNTER_READY := "ready"
const ENCOUNTER_RUNNING := "running"
const ENCOUNTER_PLAYER_VICTORY := "player_victory"
const ENCOUNTER_PLAYER_DEFEAT := "player_defeat"
const ENCOUNTER_DOUBLE_DEFEAT := "double_defeat"
const ENCOUNTER_BETWEEN_WAVE_DOWNTIME := "between_wave_downtime"
const ENCOUNTER_WAVE_TRANSITION_BLOCKED := "wave_transition_blocked"
const SESSION_MODE_SOLO := "solo"
const SESSION_MODE_MULTIPLAYER := "multiplayer"
const MULTIPLAYER_DOWNTIME_DEADLINE_MS := 120_000
const OPPONENT_BEHAVIOR_LABEL := "task15_deterministic_test_opponent"
const OPPONENT_MOVEMENT_TICK_US := 100_000
const OPPONENT_REPATH_DISTANCE_MICROFEET := ArenaBattlefield.NAVIGATION_STEP_MICROFEET
const GARGOYLE_STAGING_ALTITUDE_MICROFEET := 9_000_000
const GARGOYLE_STAGING_RADIUS_MICROFEET := 4_000_000
const GARGOYLE_INJURED_STAGING_RADIUS_MICROFEET := 5_000_000
const GARGOYLE_ATTACK_HORIZONTAL_MICROFEET := 800_000
const GARGOYLE_ATTACK_ALTITUDE_MICROFEET := 600_000
const GARGOYLE_GOAL_TOLERANCE_MICROFEET := 100_000
const GARGOYLE_STATE_TAKING_OFF := "taking_off"
const GARGOYLE_STATE_STAGING := "staging"
const GARGOYLE_STATE_DIVING := "diving"
const GARGOYLE_STATE_STRIKING := "striking"
const GARGOYLE_STATE_WITHDRAWING := "withdrawing"
const GARGOYLE_STATE_BLOCKED := "blocked_recovery"
const INVALID_TRANSITION_POSITION := Vector2i(2_147_483_647, 2_147_483_647)

var simulation: CombatSimulation

var _attack_definition: CombatAttackDefinition
var _attack_definitions_by_actor: Dictionary = {}
var _active_attack_ids_by_actor: Dictionary = {}
var _selected_target_id: StringName = &""
var _selected_target_location: StringName = &"torso"
var _next_location_8_is_knee: bool = true
var _active_player_attack_id: String = ""
var _active_opponent_attack_id: String = ""
var _next_request_sequence: int = 0
var _last_error: String = ""
var _arena_bounds_microfeet := Rect2i(-100_000_000, -100_000_000, 200_000_000, 200_000_000)
var _battlefield: ArenaBattlefield = ArenaBattlefield.create_open(_arena_bounds_microfeet)
var _seed_value: int
var _encounter_fixture_id: StringName
var _player_character_id: StringName
var _uses_external_simulation: bool = false
var _initialized: bool = false
var _encounter_active: bool = true
var _encounter_state: String = ENCOUNTER_RUNNING
var _opponent_behavior_enabled: bool = false
var _opponent_behavior_status: String = "disabled"
var _initial_player_position_microfeet := Vector2i.ZERO
var _initial_opponent_position_microfeet := Vector2i.ZERO
var _opponent_path: Array[Vector2i] = []
var _opponent_path_target_microfeet: Variant = null
var _opponent_path_rebuild_count: int = 0
var _opponent_movement_remainder: int = 0
var _opponent_last_movement_us: int = 0
var _opponent_movement_model: PrimeMovementModel
var _opponent_movement_round_index: int = -1
var _opponent_movement_spent_microfeet: int = 0
var _player_movement_round_index: int = -1
var _player_movement_spent_microfeet: int = 0
var _resolved_event_history_generation: int = 0
var _arena_wave_state_machine: ArenaWaveStateMachine
var _session_mode: String = SESSION_MODE_SOLO
var _downtime_elapsed_ms: int = 0
var _downtime_advance_committed: bool = false
var _is_wave_one_goblin_encounter: bool = false
var _goblin_actor_ids := PackedStringArray()
var _is_wave_two_spadoodle_encounter: bool = false
var _spadoodle_actor_ids := PackedStringArray()
var _is_wave_three_skelly_hades_encounter: bool = false
var _skelly_actor_ids := PackedStringArray()
var _hades_follower_actor_ids := PackedStringArray()
var _is_wave_four_gargoyle_encounter: bool = false
var _gargoyle_actor_ids := PackedStringArray()
var _is_wave_five_boss_encounter: bool = false
var _rare_human_warrior_actor_ids := PackedStringArray()
var _rare_human_warrior_ai: RareHumanWarriorBossAI
var _goblin_paths: Dictionary = {}
var _goblin_path_targets: Dictionary = {}
var _goblin_path_target_actor_ids: Dictionary = {}
var _goblin_path_reaches: Dictionary = {}
var _goblin_attack_destinations: Dictionary = {}
var _goblin_path_rebuild_counts: Dictionary = {}
var _goblin_failed_path_cache: Dictionary = {}
var _goblin_failed_path_cache_hits: Dictionary = {}
var _goblin_static_collision_counts: Dictionary = {}
var _goblin_movement_models: Dictionary = {}
var _goblin_movement_round_indices: Dictionary = {}
var _goblin_movement_spent: Dictionary = {}
var _goblin_last_movement_us: int = 0
var _hades_last_tactical_signature: Dictionary = {}
var _hades_support_target_ids: Dictionary = {}
var _gargoyle_tactical_states: Dictionary = {}
var _gargoyle_lane_offsets: Dictionary = {}
var _gargoyle_failed_approach_counts: Dictionary = {}
var _gargoyle_last_tactical_signatures: Dictionary = {}


func _init(
	seed_value: int = DEFAULT_SEED,
	existing_simulation: CombatSimulation = null,
	encounter_fixture_id: StringName = Fixture.ENCOUNTER_MEDIUM_GUARDS,
	player_character_id: StringName = Fixture.PLAYER_CHARACTER_GUARD
) -> void:
	_seed_value = seed_value
	_encounter_fixture_id = encounter_fixture_id
	_player_character_id = player_character_id
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
	var result := Fixture.configure_simulation(simulation, player_position_microfeet, opponent_position_microfeet, _encounter_fixture_id, _player_character_id)
	if result.get("success", false):
		simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
		simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
		simulation.set_special_touch_resolver(_resolve_special_touch)
		simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
		_attack_definition = result["attack_definition"]
		_attack_definitions_by_actor = {
			String(Fixture.PLAYER_ID): _attack_definition,
			String(Fixture.OPPONENT_ID): result.get("opponent_attack_definition", Fixture.make_attack_definition()),
		}
		_active_attack_ids_by_actor.clear()
		_selected_target_id = Fixture.OPPONENT_ID
		_selected_target_location = &"torso"
		_next_location_8_is_knee = true
		_initialized = true
		_encounter_active = start_active
		_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
		_opponent_behavior_status = "idle" if _opponent_behavior_enabled else "disabled"
		_opponent_path.clear()
		_opponent_path_target_microfeet = null
		_opponent_path_rebuild_count = 0
		_opponent_movement_remainder = 0
		_opponent_last_movement_us = simulation.clock.get_elapsed_us()
		_opponent_movement_model = _make_opponent_movement_model(opponent_position_microfeet)
		_opponent_movement_round_index = simulation.clock.get_round_index()
		_opponent_movement_spent_microfeet = 0
		_player_movement_round_index = simulation.clock.get_round_index()
		_player_movement_spent_microfeet = 0
		_resolved_event_history_generation += 1
		if _player_character_id == Fixture.PLAYER_CHARACTER_VAELIS:
			simulation.configure_nac_automation(Fixture.PLAYER_ID, VaelisForce.default_nac_automation_settings())
		_last_error = ""
	else:
		_initialized = false
		_encounter_active = false
		_last_error = String(result.get("reason", "fixture_initialization_failed"))
	return result


func initialize_wave_one_goblins(
	player_position_microfeet: Vector2i,
	first_goblin_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	if _initialized:
		return _failure("encounter_already_initialized")
	_is_wave_one_goblin_encounter = true
	_is_wave_two_spadoodle_encounter = false
	_is_wave_three_skelly_hades_encounter = false
	_is_wave_four_gargoyle_encounter = false
	_is_wave_five_boss_encounter = false
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = first_goblin_position_microfeet
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var wave_initialization := _arena_wave_state_machine.initialize(_roll_wave_quantity)
	if not wave_initialization.get("success", false):
		return _failure(String(wave_initialization.get("reason", "wave_initialization_failed")))
	var goblin_count := _arena_wave_state_machine.get_resolved_enemy_count()
	var goblin_positions := _make_wave_one_goblin_positions(first_goblin_position_microfeet, goblin_count)
	if goblin_positions.size() != goblin_count:
		return _failure("goblin_spawn_positions_unavailable")
	var occupancy := {String(Fixture.PLAYER_ID): player_position_microfeet}
	if not _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, occupancy).get("legal", false):
		return _failure("player_spawn_position_illegal")
	for index in range(goblin_positions.size()):
		var actor_id := _goblin_actor_id(index)
		occupancy[String(actor_id)] = goblin_positions[index]
		if not _battlefield.is_position_legal(actor_id, goblin_positions[index], occupancy).get("legal", false):
			return _failure("goblin_spawn_position_illegal")

	var player_registration := _register_selected_player()
	if not player_registration.get("success", false):
		return player_registration

	_goblin_actor_ids = PackedStringArray()
	for index in range(goblin_count):
		var goblin_id := _goblin_actor_id(index)
		var goblin_actor := CommonGoblinFixture.make_actor(goblin_id, "Common Goblin %d" % (index + 1))
		var goblin_attack := CommonGoblinFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
		var goblin_validation := CommonGoblinFixture.validate_actor(goblin_actor, goblin_attack)
		if not goblin_validation.get("success", false):
			return _failure(String(goblin_validation.get("reason", "goblin_fixture_invalid")))
		var goblin_registration := _register_wave_combatant(
			goblin_actor,
			CommonGoblinFixture.make_defense_profile(goblin_id),
			CommonGoblinFixture.make_damage_protection_profile(goblin_id),
			goblin_attack
		)
		if not goblin_registration.get("success", false):
			return goblin_registration
		_attack_definitions_by_actor[String(goblin_id)] = goblin_attack
		_goblin_actor_ids.append(String(goblin_id))

	var player_position_result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	for index in range(_goblin_actor_ids.size()):
		var goblin_position_result := simulation.apply_authoritative_position(
			StringName(_goblin_actor_ids[index]), goblin_positions[index], 180_000 + index * 180_000
		)
		if not goblin_position_result.get("success", false):
			return goblin_position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
	simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
	simulation.set_special_touch_resolver(_resolve_special_touch)
	simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
	_publish_wave_transition(wave_initialization)
	set_wave_creature_integration_available(CommonGoblinFixture.CREATURE_ID, true)
	var activation := activate_current_wave(_goblin_actor_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = StringName(_goblin_actor_ids[0])
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialized = true
	_encounter_active = start_active
	_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
	_opponent_behavior_status = "goblin_wave_idle" if _opponent_behavior_enabled else "disabled"
	_goblin_paths.clear()
	_goblin_path_targets.clear()
	_goblin_path_target_actor_ids.clear()
	_goblin_path_reaches.clear()
	_hades_support_target_ids.clear()
	_goblin_attack_destinations.clear()
	_goblin_path_rebuild_counts.clear()
	_goblin_failed_path_cache.clear()
	_goblin_failed_path_cache_hits.clear()
	_goblin_static_collision_counts.clear()
	_goblin_movement_models.clear()
	_goblin_movement_round_indices.clear()
	_goblin_movement_spent.clear()
	_goblin_last_movement_us = simulation.clock.get_elapsed_us()
	for goblin_id: String in _goblin_actor_ids:
		_goblin_movement_models[goblin_id] = _make_goblin_movement_model(StringName(goblin_id), simulation.get_actor_state(StringName(goblin_id)).position_microfeet)
		_goblin_movement_round_indices[goblin_id] = simulation.clock.get_round_index()
		_goblin_movement_spent[goblin_id] = 0
		_goblin_path_rebuild_counts[goblin_id] = 0
		_goblin_failed_path_cache_hits[goblin_id] = 0
		_goblin_static_collision_counts[goblin_id] = 0
	_resolved_event_history_generation += 1
	_last_error = ""
	if _opponent_behavior_enabled and _encounter_active:
		_run_opponent_behavior()
	return {
		"success": true,
		"opening_order": opening_result.get("opening_order", []),
		"goblin_actor_ids": Array(_goblin_actor_ids),
		"resolved_goblin_count": goblin_count,
		"encounter_fixture_id": String(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS),
	}


func initialize_wave_two_spadoodles(
	player_position_microfeet: Vector2i,
	first_spadoodle_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	if _initialized:
		return _failure("encounter_already_initialized")
	_is_wave_one_goblin_encounter = false
	_is_wave_two_spadoodle_encounter = true
	_is_wave_three_skelly_hades_encounter = false
	_is_wave_four_gargoyle_encounter = false
	_is_wave_five_boss_encounter = false
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = first_spadoodle_position_microfeet
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var wave_initialization := _arena_wave_state_machine.initialize_at_wave(&"wave_2", _roll_wave_quantity)
	if not wave_initialization.get("success", false):
		return _failure(String(wave_initialization.get("reason", "wave_initialization_failed")))
	var spadoodle_count := _arena_wave_state_machine.get_resolved_enemy_count()
	var spadoodle_positions := _make_wave_two_spadoodle_positions(first_spadoodle_position_microfeet, spadoodle_count)
	if spadoodle_positions.size() != spadoodle_count:
		return _failure("spadoodle_spawn_positions_unavailable")
	var occupancy := {String(Fixture.PLAYER_ID): player_position_microfeet}
	if not _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, occupancy).get("legal", false):
		return _failure("player_spawn_position_illegal")
	for index in range(spadoodle_positions.size()):
		var actor_id := _spadoodle_actor_id(index)
		occupancy[String(actor_id)] = spadoodle_positions[index]
		if not _battlefield.is_position_legal(actor_id, spadoodle_positions[index], occupancy).get("legal", false):
			return _failure("spadoodle_spawn_position_illegal")

	var player_registration := _register_selected_player()
	if not player_registration.get("success", false):
		return player_registration

	_spadoodle_actor_ids = PackedStringArray()
	for index in range(spadoodle_count):
		var spadoodle_id := _spadoodle_actor_id(index)
		var spadoodle_actor := CommonSpadoodleFixture.make_actor(spadoodle_id, "Common Spadoodle %d" % (index + 1))
		var spadoodle_attack := CommonSpadoodleFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
		var spadoodle_validation := CommonSpadoodleFixture.validate_actor(spadoodle_actor, spadoodle_attack)
		if not spadoodle_validation.get("success", false):
			return _failure(String(spadoodle_validation.get("reason", "spadoodle_fixture_invalid")))
		var spadoodle_registration := _register_wave_combatant(
			spadoodle_actor,
			CommonSpadoodleFixture.make_defense_profile(spadoodle_id),
			CommonSpadoodleFixture.make_damage_protection_profile(spadoodle_id),
			spadoodle_attack
		)
		if not spadoodle_registration.get("success", false):
			return spadoodle_registration
		_attack_definitions_by_actor[String(spadoodle_id)] = spadoodle_attack
		_spadoodle_actor_ids.append(String(spadoodle_id))

	var player_position_result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	for index in range(_spadoodle_actor_ids.size()):
		var spadoodle_position_result := simulation.apply_authoritative_position(
			StringName(_spadoodle_actor_ids[index]), spadoodle_positions[index], 180_000 + index * 180_000
		)
		if not spadoodle_position_result.get("success", false):
			return spadoodle_position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
	simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
	simulation.set_special_touch_resolver(_resolve_special_touch)
	simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
	_publish_wave_transition(wave_initialization)
	set_wave_creature_integration_available(CommonSpadoodleFixture.CREATURE_ID, true)
	var activation := activate_current_wave(_spadoodle_actor_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = StringName(_spadoodle_actor_ids[0])
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialized = true
	_encounter_active = start_active
	_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
	_opponent_behavior_status = "spadoodle_wave_idle" if _opponent_behavior_enabled else "disabled"
	_initialize_wave_enemy_navigation_state()
	_resolved_event_history_generation += 1
	_last_error = ""
	if _opponent_behavior_enabled and _encounter_active:
		_run_opponent_behavior()
	return {
		"success": true,
		"opening_order": opening_result.get("opening_order", []),
		"spadoodle_actor_ids": Array(_spadoodle_actor_ids),
		"resolved_spadoodle_count": spadoodle_count,
		"encounter_fixture_id": String(Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES),
	}


func initialize_wave_three_skelly_hades(
	player_position_microfeet: Vector2i,
	first_enemy_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	if _initialized:
		return _failure("encounter_already_initialized")
	_is_wave_one_goblin_encounter = false
	_is_wave_two_spadoodle_encounter = false
	_is_wave_three_skelly_hades_encounter = true
	_is_wave_four_gargoyle_encounter = false
	_is_wave_five_boss_encounter = false
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = first_enemy_position_microfeet
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var wave_initialization := _arena_wave_state_machine.initialize_at_wave(&"wave_3", _roll_wave_quantity)
	if not wave_initialization.get("success", false):
		return _failure(String(wave_initialization.get("reason", "wave_initialization_failed")))
	var skelly_count := 0
	var hades_count := 0
	for roster_entry: Dictionary in _arena_wave_state_machine.get_resolved_roster():
		var creature_id := String(roster_entry.get("creature_id", ""))
		if creature_id == String(CommonSkellyFixture.CREATURE_ID):
			skelly_count = int(roster_entry.get("resolved_count", 0))
		elif creature_id == String(HadesCombatFollowerFixture.CREATURE_ID):
			hades_count = int(roster_entry.get("resolved_count", 0))
	if skelly_count < 1 or skelly_count > 2 or hades_count != 1:
		return _failure("wave_three_roster_invalid")
	var spawn_positions := _make_wave_three_positions(first_enemy_position_microfeet, skelly_count)
	if spawn_positions.size() != skelly_count + hades_count:
		return _failure("wave_three_spawn_positions_unavailable")
	var occupancy := {String(Fixture.PLAYER_ID): player_position_microfeet}
	if not _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, occupancy).get("legal", false):
		return _failure("player_spawn_position_illegal")
	for index in range(spawn_positions.size()):
		var spawn_actor_id := _skelly_actor_id(index) if index < skelly_count else _hades_follower_actor_id()
		occupancy[String(spawn_actor_id)] = spawn_positions[index]
		if not _battlefield.is_position_legal(spawn_actor_id, spawn_positions[index], occupancy).get("legal", false):
			return _failure("wave_three_spawn_position_illegal")

	var player_registration := _register_selected_player()
	if not player_registration.get("success", false):
		return player_registration

	_skelly_actor_ids = PackedStringArray()
	for index in range(skelly_count):
		var skelly_id := _skelly_actor_id(index)
		var skelly_actor := CommonSkellyFixture.make_actor(skelly_id, "Common Skelly %d" % (index + 1))
		var skelly_attack := CommonSkellyFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
		var skelly_validation := CommonSkellyFixture.validate_actor(skelly_actor, skelly_attack)
		if not skelly_validation.get("success", false):
			return _failure(String(skelly_validation.get("reason", "skelly_fixture_invalid")))
		var skelly_registration := _register_wave_combatant(
			skelly_actor,
			CommonSkellyFixture.make_defense_profile(skelly_id),
			CommonSkellyFixture.make_damage_protection_profile(skelly_id),
			skelly_attack
		)
		if not skelly_registration.get("success", false):
			return skelly_registration
		_attack_definitions_by_actor[String(skelly_id)] = skelly_attack
		_skelly_actor_ids.append(String(skelly_id))

	_hades_follower_actor_ids = PackedStringArray()
	_gargoyle_actor_ids = PackedStringArray()
	_rare_human_warrior_actor_ids = PackedStringArray()
	_rare_human_warrior_ai = null
	var hades_id := _hades_follower_actor_id()
	var hades_actor := HadesCombatFollowerFixture.make_actor(hades_id, "Uncommon Hades Combat Follower")
	var hades_attack := HadesCombatFollowerFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	var hades_validation := HadesCombatFollowerFixture.validate_actor(hades_actor, hades_attack)
	if not hades_validation.get("success", false):
		return _failure(String(hades_validation.get("reason", "hades_follower_fixture_invalid")))
	var hades_registration := _register_wave_combatant(
		hades_actor,
		HadesCombatFollowerFixture.make_defense_profile(hades_id),
		HadesCombatFollowerFixture.make_damage_protection_profile(hades_id),
		hades_attack
	)
	if not hades_registration.get("success", false):
		return hades_registration
	_attack_definitions_by_actor[String(hades_id)] = hades_attack
	_hades_follower_actor_ids.append(String(hades_id))
	var hand_configuration := simulation.configure_actor_hand_occupancy(hades_id, {
		"left": "",
		"right": String(HadesCombatFollowerFixture.WEAPON_REF),
	})
	if not hand_configuration.get("success", false):
		return _failure(String(hand_configuration.get("reason", "hades_hand_configuration_failed")))

	var player_position_result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	var wave_actor_ids := _wave_enemy_actor_ids()
	for index in range(wave_actor_ids.size()):
		var enemy_position_result := simulation.apply_authoritative_position(
			StringName(wave_actor_ids[index]), spawn_positions[index], 180_000 + index * 120_000
		)
		if not enemy_position_result.get("success", false):
			return enemy_position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
	simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
	simulation.set_special_touch_resolver(_resolve_special_touch)
	simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
	_publish_wave_transition(wave_initialization)
	set_wave_creature_integration_available(CommonSkellyFixture.CREATURE_ID, true)
	set_wave_creature_integration_available(HadesCombatFollowerFixture.CREATURE_ID, true)
	var activation := activate_current_wave(wave_actor_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = StringName(wave_actor_ids[0])
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialized = true
	_encounter_active = start_active
	_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
	_opponent_behavior_status = "wave_three_idle" if _opponent_behavior_enabled else "disabled"
	_initialize_wave_enemy_navigation_state()
	_resolved_event_history_generation += 1
	_last_error = ""
	if _opponent_behavior_enabled and _encounter_active:
		_run_opponent_behavior()
	return {
		"success": true,
		"opening_order": opening_result.get("opening_order", []),
		"skelly_actor_ids": Array(_skelly_actor_ids),
		"hades_follower_actor_ids": Array(_hades_follower_actor_ids),
		"resolved_skelly_count": skelly_count,
		"encounter_fixture_id": String(Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES),
	}


func initialize_wave_four_gargoyles(
	player_position_microfeet: Vector2i,
	first_gargoyle_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	if _initialized:
		return _failure("encounter_already_initialized")
	_is_wave_one_goblin_encounter = false
	_is_wave_two_spadoodle_encounter = false
	_is_wave_three_skelly_hades_encounter = false
	_is_wave_four_gargoyle_encounter = true
	_is_wave_five_boss_encounter = false
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = first_gargoyle_position_microfeet
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var wave_initialization := _arena_wave_state_machine.initialize_at_wave(&"wave_4", _roll_wave_quantity)
	if not wave_initialization.get("success", false):
		return _failure(String(wave_initialization.get("reason", "wave_initialization_failed")))
	var gargoyle_count := _arena_wave_state_machine.get_resolved_enemy_count()
	var gargoyle_positions := _make_wave_four_gargoyle_positions(first_gargoyle_position_microfeet, gargoyle_count)
	if gargoyle_positions.size() != gargoyle_count:
		return _failure("gargoyle_spawn_positions_unavailable")
	var occupancy := {String(Fixture.PLAYER_ID): player_position_microfeet}
	if not _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, occupancy).get("legal", false):
		return _failure("player_spawn_position_illegal")
	for index in range(gargoyle_positions.size()):
		var actor_id := _gargoyle_actor_id(index)
		occupancy[String(actor_id)] = gargoyle_positions[index]
		if not _battlefield.is_position_legal(actor_id, gargoyle_positions[index], occupancy).get("legal", false):
			return _failure("gargoyle_spawn_position_illegal")

	var player_registration := _register_selected_player()
	if not player_registration.get("success", false):
		return player_registration

	_gargoyle_actor_ids = PackedStringArray()
	for index in range(gargoyle_count):
		var gargoyle_id := _gargoyle_actor_id(index)
		var gargoyle_actor := MiniGargoyleSwarmerFixture.make_actor(gargoyle_id, "Uncommon Mini Gargoyle Swarmer %d" % (index + 1))
		var gargoyle_attack := MiniGargoyleSwarmerFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
		var gargoyle_validation := MiniGargoyleSwarmerFixture.validate_actor(gargoyle_actor, gargoyle_attack)
		if not gargoyle_validation.get("success", false):
			return _failure(String(gargoyle_validation.get("reason", "gargoyle_fixture_invalid")))
		var registration := _register_wave_combatant(gargoyle_actor, MiniGargoyleSwarmerFixture.make_defense_profile(gargoyle_id), MiniGargoyleSwarmerFixture.make_damage_protection_profile(gargoyle_id), gargoyle_attack)
		if not registration.get("success", false):
			return registration
		_attack_definitions_by_actor[String(gargoyle_id)] = gargoyle_attack
		_gargoyle_actor_ids.append(String(gargoyle_id))

	var player_position_result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	for index in range(_gargoyle_actor_ids.size()):
		var position_result := simulation.apply_authoritative_spatial_position(StringName(_gargoyle_actor_ids[index]), gargoyle_positions[index], 0, 180_000 + index * 90_000)
		if not position_result.get("success", false):
			return position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
	simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
	simulation.set_special_touch_resolver(_resolve_special_touch)
	simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
	_publish_wave_transition(wave_initialization)
	set_wave_creature_integration_available(MiniGargoyleSwarmerFixture.CREATURE_ID, true)
	var activation := activate_current_wave(_gargoyle_actor_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = StringName(_gargoyle_actor_ids[0])
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialized = true
	_encounter_active = start_active
	_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
	_opponent_behavior_status = "wave_four_night_idle" if _opponent_behavior_enabled else "disabled"
	_initialize_wave_enemy_navigation_state()
	_resolved_event_history_generation += 1
	_last_error = ""
	if _opponent_behavior_enabled and _encounter_active:
		_run_opponent_behavior()
	return {
		"success": true,
		"opening_order": opening_result.get("opening_order", []),
		"gargoyle_actor_ids": Array(_gargoyle_actor_ids),
		"resolved_gargoyle_count": gargoyle_count,
		"environment": {"time_of_day": "night", "maximum_altitude_microfeet": _battlefield.maximum_altitude_microfeet, "wall_height_microfeet": 8_000_000},
		"encounter_fixture_id": String(Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES),
	}


func initialize_wave_five_rare_human_warrior(
	player_position_microfeet: Vector2i,
	boss_position_microfeet: Vector2i,
	start_active: bool = true
) -> Dictionary:
	if _initialized:
		return _failure("encounter_already_initialized")
	_is_wave_one_goblin_encounter = false
	_is_wave_two_spadoodle_encounter = false
	_is_wave_three_skelly_hades_encounter = false
	_is_wave_four_gargoyle_encounter = false
	_is_wave_five_boss_encounter = true
	_initial_player_position_microfeet = player_position_microfeet
	_initial_opponent_position_microfeet = boss_position_microfeet
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var wave_initialization := _arena_wave_state_machine.initialize_at_wave(&"wave_5", _roll_wave_quantity)
	if not wave_initialization.get("success", false):
		return _failure(String(wave_initialization.get("reason", "wave_initialization_failed")))
	if _arena_wave_state_machine.get_resolved_enemy_count() != 1:
		return _failure("wave_five_roster_invalid")
	var occupancy := {
		String(Fixture.PLAYER_ID): player_position_microfeet,
		String(RareHumanWarriorFixture.ACTOR_ID): boss_position_microfeet,
	}
	if not _battlefield.is_position_legal(Fixture.PLAYER_ID, player_position_microfeet, occupancy).get("legal", false):
		return _failure("player_spawn_position_illegal")
	if not _battlefield.is_position_legal(RareHumanWarriorFixture.ACTOR_ID, boss_position_microfeet, occupancy).get("legal", false):
		return _failure("rare_human_warrior_spawn_position_illegal")

	var player_registration := _register_selected_player()
	if not player_registration.get("success", false):
		return player_registration
	var boss_result := RareHumanWarriorFixture.instantiate_foundation_actor()
	if not boss_result.get("success", false):
		return _failure(String(boss_result.get("reason", "rare_human_warrior_fixture_invalid")))
	var boss_actor: CombatActorDefinition = boss_result.get("actor")
	var boss_attack := RareHumanWarriorFixture.make_melee_attack_definition(HitLocations.get_same_size_attack_profile())
	var boss_protection := RareHumanWarriorFixture.make_damage_protection_profile(RareHumanWarriorFixture.ACTOR_ID)
	if boss_actor == null or boss_attack == null or boss_protection == null:
		return _failure("rare_human_warrior_combat_definition_incomplete")
	var boss_registration := _register_wave_combatant(
		boss_actor,
		RareHumanWarriorFixture.make_defense_profile(RareHumanWarriorFixture.ACTOR_ID),
		boss_protection,
		boss_attack
	)
	if not boss_registration.get("success", false):
		return boss_registration
	var hand_configuration := simulation.configure_actor_hand_occupancy(
		RareHumanWarriorFixture.ACTOR_ID,
		{"left": String(RareHumanWarriorFixture.WEAPON_REF), "right": String(RareHumanWarriorFixture.WEAPON_REF)}
	)
	if not hand_configuration.get("success", false):
		return _failure(String(hand_configuration.get("reason", "rare_human_warrior_hand_configuration_failed")))
	_attack_definitions_by_actor[String(RareHumanWarriorFixture.ACTOR_ID)] = boss_attack
	_rare_human_warrior_actor_ids = PackedStringArray([String(RareHumanWarriorFixture.ACTOR_ID)])

	var player_position_result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	var boss_position_result := simulation.apply_authoritative_position(RareHumanWarriorFixture.ACTOR_ID, boss_position_microfeet, 180_000)
	if not boss_position_result.get("success", false):
		return boss_position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	simulation.set_attack_final_line_of_sight_resolver(_resolve_attack_final_line_of_sight)
	simulation.set_rage_knockback_resolver(_resolve_rage_knockback)
	simulation.set_special_touch_resolver(_resolve_special_touch)
	simulation.set_gatherable_material_resolver(_resolve_gatherable_material)
	simulation.set_world_item_pickup_resolver(_resolve_world_item_pickup)
	RareHumanWarriorFixture.configure_spear_landing_geometry(simulation, _battlefield)
	_publish_wave_transition(wave_initialization)
	set_wave_creature_integration_available(&"rare_human_warrior", true)
	var activation := activate_current_wave(_rare_human_warrior_actor_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = RareHumanWarriorFixture.ACTOR_ID
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialized = true
	_encounter_active = start_active
	_encounter_state = ENCOUNTER_RUNNING if start_active else ENCOUNTER_READY
	_opponent_behavior_status = "wave_five_boss_idle" if _opponent_behavior_enabled else "disabled"
	_rare_human_warrior_ai = RareHumanWarriorBossAI.new(
		simulation, _battlefield, RareHumanWarriorFixture.ACTOR_ID, Fixture.PLAYER_ID
	)
	_goblin_last_movement_us = simulation.clock.get_elapsed_us()
	_resolved_event_history_generation += 1
	_last_error = ""
	if _opponent_behavior_enabled and _encounter_active:
		_run_opponent_behavior()
	return {
		"success": true,
		"opening_order": opening_result.get("opening_order", []),
		"rare_human_warrior_actor_ids": Array(_rare_human_warrior_actor_ids),
		"resolved_rare_human_warrior_count": 1,
		"encounter_fixture_id": String(Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR),
	}


func _register_wave_combatant(
	actor: CombatActorDefinition,
	defense_profile: CombatDefenseProfile,
	protection_profile: CombatDamageProtectionProfile,
	attack: CombatAttackDefinition
) -> Dictionary:
	for registration: Dictionary in [
		simulation.register_actor(actor),
		simulation.register_defense_profile(actor.actor_id, defense_profile),
		simulation.register_damage_protection_profile(actor.actor_id, protection_profile),
		simulation.register_critical_reaction_attack(actor.actor_id, attack, true),
	]:
		if not registration.get("success", false):
			return registration
	return {"success": true}


func _register_selected_player() -> Dictionary:
	var actor := Fixture.make_player_actor(_player_character_id, Fixture.PLAYER_ID)
	var attack := Fixture.make_player_attack_definition(_player_character_id)
	var defense := Fixture.make_player_defense_profile(_player_character_id, Fixture.PLAYER_ID)
	var protection := Fixture.make_player_damage_protection_profile(_player_character_id, Fixture.PLAYER_ID)
	var validation := Fixture.validate_player_combatant(_player_character_id, actor, defense, protection, attack)
	if not validation.get("success", false):
		return _failure(String(validation.get("reason", "player_fixture_invalid")))
	var registration := _register_wave_combatant(actor, defense, protection, attack)
	if not registration.get("success", false):
		return registration
	if _player_character_id == Fixture.PLAYER_CHARACTER_VAELIS:
		var hand_result := simulation.configure_actor_hand_occupancy(Fixture.PLAYER_ID, {
			"left": String(Fixture.VAELIS_WAND_REF),
			"right": String(Fixture.VAELIS_WEAPON_REF),
		})
		if not hand_result.get("success", false):
			return _failure(String(hand_result.get("reason", "vaelis_hand_configuration_failed")))
		var automation_result := simulation.configure_nac_automation(Fixture.PLAYER_ID, VaelisForce.default_nac_automation_settings())
		if not automation_result.get("success", false):
			return _failure(String(automation_result.get("reason", "vaelis_nac_configuration_failed")))
	_attack_definition = attack
	_attack_definitions_by_actor[String(Fixture.PLAYER_ID)] = attack
	return {"success": true}


func set_opponent_behavior_enabled(enabled: bool) -> void:
	_opponent_behavior_enabled = enabled
	_opponent_behavior_status = "idle" if enabled else "disabled"
	if enabled and _encounter_active:
		_run_opponent_behavior()


func start_encounter() -> Dictionary:
	if not _initialized:
		return _failure("encounter_not_initialized")
	if _arena_wave_state_machine != null and not _is_playable_wave_encounter():
		return _failure("wave_circuit_requires_creature_activation")
	if _is_playable_wave_encounter() and _arena_wave_state_machine.get_state() != ArenaWaveStateMachine.STATE_ACTIVE:
		return _failure("wave_not_active")
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
	_attack_definitions_by_actor.clear()
	_active_attack_ids_by_actor.clear()
	_selected_target_id = &""
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_active_player_attack_id = ""
	_active_opponent_attack_id = ""
	_next_request_sequence = 0
	_last_error = ""
	_initialized = false
	_encounter_active = false
	_encounter_state = ENCOUNTER_READY
	_opponent_behavior_status = "idle" if _opponent_behavior_enabled else "disabled"
	_opponent_movement_model = null
	_arena_wave_state_machine = null
	_downtime_elapsed_ms = 0
	_downtime_advance_committed = false
	_goblin_actor_ids = PackedStringArray()
	_spadoodle_actor_ids = PackedStringArray()
	_skelly_actor_ids = PackedStringArray()
	_hades_follower_actor_ids = PackedStringArray()
	_gargoyle_actor_ids = PackedStringArray()
	_rare_human_warrior_actor_ids = PackedStringArray()
	_rare_human_warrior_ai = null
	_goblin_paths.clear()
	_goblin_path_targets.clear()
	_goblin_path_target_actor_ids.clear()
	_goblin_path_reaches.clear()
	_hades_support_target_ids.clear()
	_goblin_attack_destinations.clear()
	_goblin_path_rebuild_counts.clear()
	_goblin_failed_path_cache.clear()
	_goblin_failed_path_cache_hits.clear()
	_goblin_static_collision_counts.clear()
	_goblin_movement_models.clear()
	_goblin_movement_round_indices.clear()
	_goblin_movement_spent.clear()
	_goblin_last_movement_us = 0
	_gargoyle_tactical_states.clear()
	_gargoyle_lane_offsets.clear()
	_gargoyle_failed_approach_counts.clear()
	_gargoyle_last_tactical_signatures.clear()
	_opponent_movement_round_index = -1
	_opponent_movement_spent_microfeet = 0
	if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_ONE_GOBLINS:
		return initialize_wave_one_goblins(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)
	if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES:
		return initialize_wave_two_spadoodles(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)
	if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES:
		return initialize_wave_three_skelly_hades(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)
	if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES:
		return initialize_wave_four_gargoyles(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)
	if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR:
		return initialize_wave_five_rare_human_warrior(_initial_player_position_microfeet, _initial_opponent_position_microfeet, start_active)
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
	_opponent_path_target_microfeet = null
	_goblin_paths.clear()
	_goblin_path_targets.clear()
	_goblin_path_target_actor_ids.clear()
	_goblin_path_reaches.clear()
	_hades_support_target_ids.clear()
	_goblin_attack_destinations.clear()
	_goblin_path_rebuild_counts.clear()
	_goblin_failed_path_cache.clear()
	_goblin_failed_path_cache_hits.clear()
	_goblin_static_collision_counts.clear()


func get_battlefield() -> ArenaBattlefield:
	return _battlefield


func select_target(target_id: StringName) -> Dictionary:
	if not get_targetable_enemy_ids().has(String(target_id)):
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


func cycle_target(direction: int) -> Dictionary:
	var candidates := get_targetable_enemy_ids()
	if candidates.is_empty():
		clear_target()
		return {"success": false, "reason": "no_target_available"}
	var selected := choose_cycled_target(_selected_target_id, candidates, direction)
	return select_target(selected)


func get_targetable_enemy_ids() -> PackedStringArray:
	var candidates := PackedStringArray()
	var active_wave_ids := PackedStringArray()
	if _arena_wave_state_machine != null:
		active_wave_ids = _arena_wave_state_machine.get_active_enemy_ids()
	for actor_snapshot: Dictionary in simulation.get_state_snapshot().get("actors", []):
		var state: Dictionary = actor_snapshot.get("state", {})
		var actor_id := String(state.get("actor_id", ""))
		if actor_id.is_empty() or actor_id == String(Fixture.PLAYER_ID):
			continue
		if _arena_wave_state_machine != null and not active_wave_ids.has(actor_id):
			continue
		if simulation.is_actor_retired(StringName(actor_id)):
			continue
		var current_hpc: Variant = state.get("current_hpc")
		if current_hpc == null or int(current_hpc) <= 0:
			continue
		candidates.append(actor_id)
	candidates.sort()
	return candidates


static func choose_cycled_target(current_target_id: StringName, candidates: PackedStringArray, direction: int) -> StringName:
	if candidates.is_empty():
		return &""
	var ordered := candidates.duplicate()
	ordered.sort()
	var step := -1 if direction < 0 else 1
	var current_index := ordered.find(String(current_target_id))
	if current_index < 0:
		return StringName(ordered[ordered.size() - 1] if step < 0 else ordered[0])
	return StringName(ordered[posmod(current_index + step, ordered.size())])


func select_target_location(location_id: StringName) -> Dictionary:
	var location := HitLocations.get_by_id(location_id)
	if location.is_empty():
		return _failure("invalid_target_location")
	_selected_target_location = location_id
	if location_id == HitLocations.LOCATION_8_KNEE:
		_next_location_8_is_knee = false
	elif location_id == HitLocations.LOCATION_8_LOWER_LEG:
		_next_location_8_is_knee = true
	else:
		_next_location_8_is_knee = true
	_last_error = ""
	return {"success": true, "target_location": String(location_id), "location_number": int(location["number"])}


func select_target_location_by_number(number: int) -> Dictionary:
	if number == 8:
		return select_target_location(
			HitLocations.LOCATION_8_KNEE
			if _next_location_8_is_knee
			else HitLocations.LOCATION_8_LOWER_LEG
		)
	var location := HitLocations.get_by_number(number)
	if location.is_empty():
		return _failure("invalid_target_location_number")
	return select_target_location(StringName(location["id"]))


func clear_target() -> void:
	_selected_target_id = &""
	_last_error = "no_target_selected"


func update_player_position(position_microfeet: Vector2i) -> Dictionary:
	if not _encounter_active:
		return _failure("encounter_not_running")
	if _battlefield.navigation_authoritative:
		var player_definition := _actor_definition_snapshot(Fixture.PLAYER_ID)
		return request_player_movement(position_microfeet, int(player_definition.get("combat_stats", {}).get("mr", 0)))
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	var facing := 0
	if player_state != null:
		facing = facing_millidegrees_for_displacement(
			position_microfeet - player_state.position_microfeet,
			player_state.facing_millidegrees
		)
	var result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, position_microfeet, facing)
	if not result.get("success", false):
		_last_error = String(result.get("reason", "position_update_rejected"))
	return result


func request_player_movement(position_microfeet: Vector2i, effective_mr: int) -> Dictionary:
	if not _encounter_active:
		var inactive_player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
		return _movement_rejected(
			"encounter_not_running",
			Vector2i.ZERO if inactive_player_state == null else inactive_player_state.position_microfeet
		)
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return _movement_rejected("player_unavailable")
	if effective_mr < 0:
		return _movement_rejected("invalid_effective_mr", player_state.position_microfeet)
	var resolved := _battlefield.resolve_motion(
		Fixture.PLAYER_ID,
		player_state.position_microfeet,
		position_microfeet,
		_actor_planar_occupancy_at_elevation(Fixture.PLAYER_ID, player_state.elevation_microfeet)
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
	if player_state.conditions.has("prone"):
		@warning_ignore("integer_division")
		allowance /= 4
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
		resolved = _battlefield.resolve_motion(
			Fixture.PLAYER_ID,
			start,
			destination,
			_actor_planar_occupancy_at_elevation(Fixture.PLAYER_ID, player_state.elevation_microfeet)
		)
		destination = resolved["position_microfeet"]
		movement_cost = int(resolved["movement_cost_microfeet"])
	player_state.movement_round_index = simulation.clock.get_round_index()
	player_state.remaining_mr_microfeet = remaining
	var facing := facing_millidegrees_for_displacement(
		destination - player_state.position_microfeet,
		player_state.facing_millidegrees
	)
	var result := simulation.apply_authoritative_position(Fixture.PLAYER_ID, destination, facing, movement_cost)
	if not result.get("success", false):
		return _movement_rejected(String(result.get("reason", "position_update_rejected")), player_state.position_microfeet)
	_player_movement_spent_microfeet += movement_cost
	_interrupt_invalid_special_contacts()
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
	var locked_location := _selected_target_location
	var result := _request_actor_attack(Fixture.PLAYER_ID, _selected_target_id, input_source, locked_location)
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
	if not _attack_definition.allowed_target_locations.has(String(_selected_target_location)):
		return {"success": false, "reason": "unsupported_target_location"}
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
	var attack_definition := _get_attack_definition_for_actor(attacker_id)
	if attack_definition == null:
		return {"success": false, "reason": "attack_definition_unavailable"}
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
	if not attacker_state.equipment_refs.has(String(attack_definition.weapon_ref)):
		return {"success": false, "reason": "weapon_not_equipped"}
	var geometry := _get_actor_attack_geometry(attacker_id, target_id)
	return {
		"success": true,
		"reason": "legal",
		"distance_microfeet": geometry["distance_microfeet"],
		"maximum_range_microfeet": geometry["maximum_range_microfeet"],
		"currently_in_range": geometry["in_range"],
		"currently_unobstructed": geometry["line_of_sight"],
		"approach_required": not geometry["success"],
	}


func _get_actor_attack_geometry(attacker_id: StringName, target_id: StringName) -> Dictionary:
	var attack_definition := _get_attack_definition_for_actor(attacker_id)
	if attack_definition == null:
		return {"success": false, "reason": "attack_definition_unavailable"}
	var attacker_state := simulation.get_actor_state(attacker_id)
	var target_state := simulation.get_actor_state(target_id)
	if attacker_state == null or target_state == null:
		return {"success": false, "reason": "attack_geometry_unavailable"}
	var offset := target_state.position_microfeet - attacker_state.position_microfeet
	var elevation_offset := target_state.elevation_microfeet - attacker_state.elevation_microfeet
	var maximum_range := int(attack_definition.maximum_range_microfeet)
	var distance_squared := offset.length_squared() + elevation_offset * elevation_offset
	var in_range := distance_squared <= maximum_range * maximum_range
	var line_of_sight: bool = not attack_definition.requires_line_of_sight or _resolve_attack_final_line_of_sight(attacker_id, target_id) == true
	return {
		"success": in_range and line_of_sight,
		"reason": "legal" if in_range and line_of_sight else ("target_out_of_range" if not in_range else "line_of_sight_blocked"),
		"distance_microfeet": roundi(Vector3(offset.x, offset.y, elevation_offset).length()),
		"maximum_range_microfeet": maximum_range,
		"in_range": in_range,
		"line_of_sight": line_of_sight,
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
		if _has_authoritative_opponent_movement() and _battlefield.navigation_authoritative:
			movement_tick_us = _next_opponent_movement_tick_us(simulation.clock.get_elapsed_us())
			step_timestamp_us = mini(step_timestamp_us, movement_tick_us)
		simulation.advance_to(step_timestamp_us)
		if step_timestamp_us == movement_tick_us:
			if _is_playable_wave_encounter():
				if _is_wave_five_boss_encounter:
					if _rare_human_warrior_ai != null:
						_rare_human_warrior_ai.advance_movement(step_timestamp_us - _goblin_last_movement_us)
				elif _is_wave_four_gargoyle_encounter:
					_advance_gargoyle_flight(step_timestamp_us - _goblin_last_movement_us)
				else:
					_advance_goblin_movement(step_timestamp_us - _goblin_last_movement_us)
				_goblin_last_movement_us = step_timestamp_us
			else:
				_advance_opponent_movement(step_timestamp_us - _opponent_last_movement_us)
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


func get_actor_max_hpm(actor_id: StringName) -> Variant:
	var definition := simulation.get_actor_definition(actor_id)
	return null if definition == null else definition.get_combat_stat("hpm")


func get_selected_target_location() -> StringName:
	return _selected_target_location


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


func get_encounter_fixture_id() -> StringName:
	return _encounter_fixture_id


func get_player_character_id() -> StringName:
	return _player_character_id


func get_player_character_display_name() -> String:
	return Fixture.get_player_character_display_name(_player_character_id)


func get_player_primary_weapon_display_name() -> String:
	return Fixture.get_player_primary_weapon_display_name(_player_character_id)


func get_player_loadout_id() -> StringName:
	return Fixture.get_player_loadout_id(_player_character_id)


func get_player_equipment_refs() -> PackedStringArray:
	var player_state := get_actor_state(Fixture.PLAYER_ID)
	return PackedStringArray() if player_state == null else player_state.equipment_refs.duplicate()


func request_player_special(
	special_id: StringName,
	target_id: StringName = &"",
	automatic_activation: bool = false,
	perceived_danger: bool = false
) -> Dictionary:
	if _player_character_id != Fixture.PLAYER_CHARACTER_VAELIS:
		return {"success": false, "reason": "player_special_not_available", "resource_spent": 0}
	if not _encounter_active or _encounter_state != ENCOUNTER_RUNNING:
		return {"success": false, "reason": "encounter_not_running", "resource_spent": 0}
	if special_id == VaelisForce.FORCE_BOLT_ID:
		var resolved_target := _selected_target_id if target_id == &"" else target_id
		if resolved_target == &"":
			return {"success": false, "reason": "no_target_selected", "resource_spent": 0}
		var result := simulation.start_nac_projectile_special(
			Fixture.PLAYER_ID, resolved_target,
			VaelisForce.make_force_bolt_attack_definition(Fixture.VAELIS_WAND_REF),
			_next_request_id("force_bolt"), VaelisForce.FORCE_BOLT_ID,
			VaelisForce.FORCE_BOLT_MANA_COST, _selected_target_location,
			_resolve_attack_final_line_of_sight(Fixture.PLAYER_ID, resolved_target),
			automatic_activation, perceived_danger
		)
		if result.get("success", false) and result.has("attack_instance_id"):
			_resolve_ready_attack_pipeline()
		return result
	if special_id == VaelisForce.FORCE_SHIELD_ID:
		var shield_target := Fixture.PLAYER_ID if target_id == &"" else target_id
		return simulation.start_verified_special_action(
			Fixture.PLAYER_ID, shield_target, VaelisForce.make_force_shield_action_definition(),
			_next_request_id("force_shield"), &"", shield_target == Fixture.PLAYER_ID
		)
	return {"success": false, "reason": "player_special_not_available", "resource_spent": 0}


func cancel_player_force_shield() -> Dictionary:
	if _player_character_id != Fixture.PLAYER_CHARACTER_VAELIS:
		return _failure("player_special_not_available")
	return simulation.cancel_persistent_damage_shield(Fixture.PLAYER_ID, VaelisForce.FORCE_SHIELD_ID, _next_request_id("force_shield_cancel"))


func configure_player_nac_automation(settings: Dictionary) -> Dictionary:
	if _player_character_id != Fixture.PLAYER_CHARACTER_VAELIS:
		return _failure("player_special_not_available")
	return simulation.configure_nac_automation(Fixture.PLAYER_ID, settings)


func get_player_nac_automation() -> Dictionary:
	return simulation.get_nac_automation(Fixture.PLAYER_ID)


func get_encounter_display_name() -> String:
	if _is_wave_one_goblin_encounter:
		return "WAVE 1: %d COMMON GOBLINS" % _goblin_actor_ids.size()
	if _is_wave_two_spadoodle_encounter:
		return "WAVE 2: %d COMMON SPADOODLES" % _spadoodle_actor_ids.size()
	if _is_wave_three_skelly_hades_encounter:
		return "WAVE 3: %d COMMON SKELLY + 1 HADES FOLLOWER" % _skelly_actor_ids.size()
	if _is_wave_four_gargoyle_encounter:
		return "WAVE 4 NIGHT: %d MINI GARGOYLE SWARMERS" % _gargoyle_actor_ids.size()
	if _is_wave_five_boss_encounter:
		return "WAVE 5: RARE HUMAN WARRIOR"
	return "MEDIUM vs SYNTHETIC SMALL" if _encounter_fixture_id == Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD else "MEDIUM vs MEDIUM"


func get_opponent_behavior_status() -> String:
	return _opponent_behavior_status


func get_opponent_behavior_label() -> String:
	return OPPONENT_BEHAVIOR_LABEL


func get_opponent_path_rebuild_count_for_testing() -> int:
	return _opponent_path_rebuild_count


func get_goblin_path_rebuild_counts_for_testing() -> Dictionary:
	return _goblin_path_rebuild_counts.duplicate(true)


func get_goblin_failed_path_cache_hits_for_testing() -> Dictionary:
	return _goblin_failed_path_cache_hits.duplicate(true)


func get_goblin_static_collision_counts_for_testing() -> Dictionary:
	return _goblin_static_collision_counts.duplicate(true)


func get_last_error() -> String:
	return _last_error


func initialize_five_wave_arena() -> Dictionary:
	if not _initialized:
		return _failure("encounter_not_initialized")
	if _encounter_active:
		return _failure("wave_framework_requires_ready_encounter")
	if _arena_wave_state_machine != null:
		return _failure("wave_circuit_already_initialized")
	_arena_wave_state_machine = ArenaWaveStateMachine.new()
	var result := _arena_wave_state_machine.initialize(_roll_wave_quantity)
	_publish_wave_transition(result)
	return result


func reset_five_wave_arena() -> Dictionary:
	var reset_result := reset_encounter(false)
	if not reset_result.get("success", false):
		return reset_result
	return initialize_five_wave_arena()


func set_wave_creature_integration_available(creature_id: StringName, available: bool) -> Dictionary:
	if _arena_wave_state_machine == null:
		return _failure("wave_circuit_not_initialized")
	_arena_wave_state_machine.set_creature_integration_available(creature_id, available)
	simulation.record_arena_wave_event(&"arena_wave_creature_integration_registered", {
		"creature_id": String(creature_id),
		"available": available,
	})
	_sync_wave_snapshot()
	return {"success": true}


func activate_current_wave(active_enemy_ids: PackedStringArray) -> Dictionary:
	if _arena_wave_state_machine == null:
		return _failure("wave_circuit_not_initialized")
	for actor_id: String in active_enemy_ids:
		if simulation.get_actor_state(StringName(actor_id)) == null:
			return _failure("active_wave_enemy_not_registered")
	var result := _arena_wave_state_machine.activate_current_wave(active_enemy_ids)
	_publish_wave_transition(result)
	return result


func evaluate_current_wave_victory() -> Dictionary:
	if _arena_wave_state_machine == null:
		return _failure("wave_circuit_not_initialized")
	var states := {}
	for actor_id: String in _arena_wave_state_machine.get_active_enemy_ids():
		var actor_state := simulation.get_actor_state(StringName(actor_id))
		if actor_state == null:
			return _failure("active_wave_enemy_not_registered")
		states[actor_id] = {
			"defeated": actor_state.current_hpc != null and int(actor_state.current_hpc) <= 0,
		}
	var result := _arena_wave_state_machine.observe_active_enemy_states(states)
	_publish_wave_transition(result)
	return result


func set_session_mode(mode: String) -> Dictionary:
	if not [SESSION_MODE_SOLO, SESSION_MODE_MULTIPLAYER].has(mode):
		return _failure("unsupported_session_mode")
	if _encounter_state == ENCOUNTER_BETWEEN_WAVE_DOWNTIME:
		return _failure("session_mode_locked_during_downtime")
	_session_mode = mode
	_downtime_elapsed_ms = 0
	_downtime_advance_committed = false
	if _initialized:
		simulation.record_arena_wave_event(&"arena_wave_session_mode_configured", {
			"session_mode": _session_mode,
			"multiplayer_downtime_deadline_ms": MULTIPLAYER_DOWNTIME_DEADLINE_MS,
		})
		_sync_wave_snapshot()
	return {"success": true, "session_mode": _session_mode}


func get_between_wave_downtime_state() -> Dictionary:
	var active := _arena_wave_state_machine != null \
		and _arena_wave_state_machine.get_state() == ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME
	var deadline_ms: Variant = MULTIPLAYER_DOWNTIME_DEADLINE_MS if _session_mode == SESSION_MODE_MULTIPLAYER else null
	return {
		"active": active,
		"session_mode": _session_mode,
		"elapsed_real_time_ms": _downtime_elapsed_ms,
		"deadline_real_time_ms": deadline_ms,
		"remaining_real_time_ms": null if deadline_ms == null else maxi(0, int(deadline_ms) - _downtime_elapsed_ms),
		"advance_committed": _downtime_advance_committed,
	}


func request_next_wave() -> Dictionary:
	if _session_mode != SESSION_MODE_SOLO:
		return _failure("solo_next_wave_unavailable")
	return _advance_from_between_wave_downtime("solo_next_wave")


func advance_multiplayer_downtime_real_time(delta_ms: int) -> Dictionary:
	if delta_ms < 0:
		return _failure("negative_downtime_delta")
	if _session_mode != SESSION_MODE_MULTIPLAYER:
		return _failure("multiplayer_downtime_unavailable")
	if _arena_wave_state_machine == null \
	or _arena_wave_state_machine.get_state() != ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME:
		return _failure("wave_downtime_not_active")
	if _downtime_advance_committed:
		return _failure("wave_advance_already_committed")
	_downtime_elapsed_ms = mini(MULTIPLAYER_DOWNTIME_DEADLINE_MS, _downtime_elapsed_ms + delta_ms)
	_sync_wave_snapshot()
	if _downtime_elapsed_ms < MULTIPLAYER_DOWNTIME_DEADLINE_MS:
		return {
			"success": true,
			"advanced": false,
			"remaining_real_time_ms": MULTIPLAYER_DOWNTIME_DEADLINE_MS - _downtime_elapsed_ms,
		}
	simulation.record_arena_wave_event(&"arena_wave_multiplayer_deadline_reached", {
		"deadline_real_time_ms": MULTIPLAYER_DOWNTIME_DEADLINE_MS,
		"elapsed_real_time_ms": _downtime_elapsed_ms,
	})
	return _advance_from_between_wave_downtime("multiplayer_deadline")


func recover_and_advance_wave() -> Dictionary:
	# Compatibility boundary: this operation no longer restores resources or
	# combines downtime entry with advancement.
	return request_next_wave()


func get_arena_wave_state() -> Dictionary:
	if _arena_wave_state_machine == null:
		return {}
	var result := _arena_wave_state_machine.to_dictionary()
	result["downtime"] = get_between_wave_downtime_state()
	return result


func get_actor_state(actor_id: StringName) -> CombatActorState:
	return simulation.get_actor_state(actor_id)


func get_resolved_events() -> Array:
	return simulation.get_resolved_events()


func get_resolved_event_count() -> int:
	return simulation.get_resolved_event_count()


func get_resolved_event_history_generation() -> int:
	return _resolved_event_history_generation


func get_resolved_events_since(cursor: int, history_generation: int) -> Dictionary:
	var generation_changed := history_generation != _resolved_event_history_generation
	var effective_cursor := 0 if generation_changed else cursor
	var result := simulation.get_resolved_events_from(effective_cursor)
	result["history_generation"] = _resolved_event_history_generation
	result["generation_changed"] = generation_changed
	if not result.get("success", false):
		result["next_cursor"] = 0
	return result


func get_state_snapshot() -> Dictionary:
	var snapshot := simulation.get_state_snapshot()
	snapshot["battlefield"] = _battlefield.to_dictionary()
	snapshot["encounter_fixture_id"] = String(_encounter_fixture_id)
	snapshot["opponent_behavior_status"] = _opponent_behavior_status
	snapshot["opponent_path"] = _serialize_vector_path(_opponent_path)
	snapshot["opponent_path_target_microfeet"] = (
		null
		if _opponent_path_target_microfeet == null
		else [_opponent_path_target_microfeet.x, _opponent_path_target_microfeet.y]
	)
	snapshot["opponent_path_rebuild_count"] = _opponent_path_rebuild_count
	snapshot["opponent_movement_remainder"] = _opponent_movement_remainder
	snapshot["opponent_movement"] = {} if _opponent_movement_model == null else _opponent_movement_model.to_dictionary()
	snapshot["opponent_movement_round_index"] = _opponent_movement_round_index
	snapshot["opponent_movement_spent_microfeet"] = _opponent_movement_spent_microfeet
	snapshot["player_movement_round_index"] = _player_movement_round_index
	snapshot["player_movement_spent_microfeet"] = _player_movement_spent_microfeet
	snapshot["arena_wave_state"] = get_arena_wave_state()
	snapshot["gargoyle_tactical_states"] = _sorted_dictionary_copy(_gargoyle_tactical_states)
	snapshot["gargoyle_lane_offsets"] = _sorted_dictionary_copy(_gargoyle_lane_offsets)
	snapshot["gargoyle_failed_approach_counts"] = _sorted_dictionary_copy(_gargoyle_failed_approach_counts)
	snapshot["rare_human_warrior_ai"] = (
		{} if _rare_human_warrior_ai == null else _rare_human_warrior_ai.get_diagnostics()
	)
	return snapshot


func _roll_wave_quantity(dice_sides: int) -> Dictionary:
	var value := simulation.roll_int(1, dice_sides)
	return {"value": value, "rng_draw_index": simulation.random.get_draw_count()}


func _publish_wave_transition(result: Dictionary) -> void:
	if _arena_wave_state_machine == null:
		return
	if result.get("success", false):
		for transition_event: Dictionary in result.get("events", []):
			simulation.record_arena_wave_event(
				StringName(transition_event["event_type"]),
				transition_event["payload"] as Dictionary
			)
	_sync_wave_snapshot()


func _sync_wave_snapshot() -> void:
	if _arena_wave_state_machine != null:
		simulation.set_arena_wave_state_snapshot(get_arena_wave_state())


func _enter_between_wave_downtime() -> Dictionary:
	if _arena_wave_state_machine == null:
		return _failure("wave_circuit_not_initialized")
	var transition := _arena_wave_state_machine.begin_between_wave_downtime()
	if not transition.get("success", false):
		return transition
	_downtime_elapsed_ms = 0
	_downtime_advance_committed = false
	_encounter_active = false
	_encounter_state = ENCOUNTER_BETWEEN_WAVE_DOWNTIME
	_opponent_behavior_status = "between_wave_downtime"
	_publish_wave_transition(transition)
	return {
		"success": true,
		"wave_id": _arena_wave_state_machine.get_current_wave_id(),
		"downtime": get_between_wave_downtime_state(),
	}


func _advance_from_between_wave_downtime(trigger: String) -> Dictionary:
	if _arena_wave_state_machine == null:
		return _failure("wave_circuit_not_initialized")
	if _downtime_advance_committed:
		return _failure("wave_advance_already_committed")
	if _arena_wave_state_machine.get_state() != ArenaWaveStateMachine.STATE_BETWEEN_WAVE_DOWNTIME:
		return _failure("wave_downtime_not_active")
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null or player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		return _failure("player_not_eligible_for_next_wave")
	var retiring_actor_ids := _wave_enemy_actor_ids()
	var retirement := simulation.retire_wave_combatants(retiring_actor_ids)
	if not retirement.get("success", false):
		return retirement
	for actor_id: String in retiring_actor_ids:
		_active_attack_ids_by_actor.erase(actor_id)
	var advance := _arena_wave_state_machine.advance_from_between_wave_downtime(_roll_wave_quantity, trigger)
	if not advance.get("success", false):
		return advance
	_publish_wave_transition(advance)
	if _arena_wave_state_machine.get_state() == ArenaWaveStateMachine.STATE_COMPLETE:
		_downtime_advance_committed = true
		_encounter_state = ENCOUNTER_PLAYER_VICTORY
		_opponent_behavior_status = "wave_circuit_complete"
	else:
		var integration := _register_and_activate_transitioned_wave()
		if not integration.get("success", false):
			_downtime_advance_committed = true
			_encounter_state = ENCOUNTER_WAVE_TRANSITION_BLOCKED
			_opponent_behavior_status = "next_wave_integration_failed_%s" % String(integration.get("reason", "unknown"))
			return integration
		_downtime_advance_committed = true
		_downtime_elapsed_ms = 0
		_encounter_active = true
		_encounter_state = ENCOUNTER_RUNNING
		_opponent_behavior_status = "wave_arrival_active"
		if _opponent_behavior_enabled:
			_run_opponent_behavior()
	return {
		"success": true,
		"advanced": true,
		"trigger": trigger,
		"next_wave_id": _arena_wave_state_machine.get_current_wave_id(),
		"wave_state": _arena_wave_state_machine.get_state(),
		"active_enemy_ids": Array(_arena_wave_state_machine.get_active_enemy_ids()),
	}


func _register_and_activate_transitioned_wave() -> Dictionary:
	var wave_id := _arena_wave_state_machine.get_current_wave_id()
	var registrations: Array[Dictionary] = []
	var enemy_ids := PackedStringArray()
	var preferred_positions: Array[Vector2i] = []
	var attacks_by_actor := {}
	_set_active_wave_kind(wave_id)
	match wave_id:
		"wave_2":
			var count := _arena_wave_state_machine.get_resolved_enemy_count()
			preferred_positions = _make_wave_two_spadoodle_positions(_initial_opponent_position_microfeet, count)
			for index in range(count):
				var actor_id := _spadoodle_actor_id(index)
				var actor := CommonSpadoodleFixture.make_actor(actor_id, "Common Spadoodle %d" % (index + 1))
				var attack := CommonSpadoodleFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
				var validation := CommonSpadoodleFixture.validate_actor(actor, attack)
				if not validation.get("success", false):
					return _failure(String(validation.get("reason", "spadoodle_fixture_invalid")))
				registrations.append(_wave_registration(actor, CommonSpadoodleFixture.make_defense_profile(actor_id), CommonSpadoodleFixture.make_damage_protection_profile(actor_id), attack))
				enemy_ids.append(String(actor_id))
				attacks_by_actor[String(actor_id)] = attack
			_spadoodle_actor_ids = enemy_ids.duplicate()
			set_wave_creature_integration_available(CommonSpadoodleFixture.CREATURE_ID, true)
		"wave_3":
			var skelly_count := 0
			var hades_count := 0
			for entry: Dictionary in _arena_wave_state_machine.get_resolved_roster():
				if String(entry.get("creature_id", "")) == String(CommonSkellyFixture.CREATURE_ID):
					skelly_count = int(entry.get("resolved_count", 0))
				elif String(entry.get("creature_id", "")) == String(HadesCombatFollowerFixture.CREATURE_ID):
					hades_count = int(entry.get("resolved_count", 0))
			if skelly_count < 1 or skelly_count > 2 or hades_count != 1:
				return _failure("wave_three_roster_invalid")
			preferred_positions = _make_wave_three_positions(_initial_opponent_position_microfeet, skelly_count)
			for index in range(skelly_count):
				var actor_id := _skelly_actor_id(index)
				var actor := CommonSkellyFixture.make_actor(actor_id, "Common Skelly %d" % (index + 1))
				var attack := CommonSkellyFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
				var validation := CommonSkellyFixture.validate_actor(actor, attack)
				if not validation.get("success", false):
					return _failure(String(validation.get("reason", "skelly_fixture_invalid")))
				registrations.append(_wave_registration(actor, CommonSkellyFixture.make_defense_profile(actor_id), CommonSkellyFixture.make_damage_protection_profile(actor_id), attack))
				enemy_ids.append(String(actor_id))
				attacks_by_actor[String(actor_id)] = attack
			_skelly_actor_ids = enemy_ids.duplicate()
			var hades_id := _hades_follower_actor_id()
			var hades_actor := HadesCombatFollowerFixture.make_actor(hades_id, "Uncommon Hades Combat Follower")
			var hades_attack := HadesCombatFollowerFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
			var hades_validation := HadesCombatFollowerFixture.validate_actor(hades_actor, hades_attack)
			if not hades_validation.get("success", false):
				return _failure(String(hades_validation.get("reason", "hades_follower_fixture_invalid")))
			registrations.append(_wave_registration(hades_actor, HadesCombatFollowerFixture.make_defense_profile(hades_id), HadesCombatFollowerFixture.make_damage_protection_profile(hades_id), hades_attack, {"left": "", "right": String(HadesCombatFollowerFixture.WEAPON_REF)}))
			enemy_ids.append(String(hades_id))
			attacks_by_actor[String(hades_id)] = hades_attack
			_hades_follower_actor_ids = PackedStringArray([String(hades_id)])
			set_wave_creature_integration_available(CommonSkellyFixture.CREATURE_ID, true)
			set_wave_creature_integration_available(HadesCombatFollowerFixture.CREATURE_ID, true)
		"wave_4":
			var count := _arena_wave_state_machine.get_resolved_enemy_count()
			preferred_positions = _make_wave_four_gargoyle_positions(_initial_opponent_position_microfeet, count)
			for index in range(count):
				var actor_id := _gargoyle_actor_id(index)
				var actor := MiniGargoyleSwarmerFixture.make_actor(actor_id, "Uncommon Mini Gargoyle Swarmer %d" % (index + 1))
				var attack := MiniGargoyleSwarmerFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
				var validation := MiniGargoyleSwarmerFixture.validate_actor(actor, attack)
				if not validation.get("success", false):
					return _failure(String(validation.get("reason", "gargoyle_fixture_invalid")))
				registrations.append(_wave_registration(actor, MiniGargoyleSwarmerFixture.make_defense_profile(actor_id), MiniGargoyleSwarmerFixture.make_damage_protection_profile(actor_id), attack))
				enemy_ids.append(String(actor_id))
				attacks_by_actor[String(actor_id)] = attack
			_gargoyle_actor_ids = enemy_ids.duplicate()
			set_wave_creature_integration_available(MiniGargoyleSwarmerFixture.CREATURE_ID, true)
		"wave_5":
			if _arena_wave_state_machine.get_resolved_enemy_count() != 1:
				return _failure("wave_five_roster_invalid")
			var boss_result := RareHumanWarriorFixture.instantiate_foundation_actor()
			if not boss_result.get("success", false):
				return _failure(String(boss_result.get("reason", "rare_human_warrior_fixture_invalid")))
			var actor: CombatActorDefinition = boss_result.get("actor")
			var attack := RareHumanWarriorFixture.make_melee_attack_definition(HitLocations.get_same_size_attack_profile())
			var protection := RareHumanWarriorFixture.make_damage_protection_profile(RareHumanWarriorFixture.ACTOR_ID)
			if actor == null or attack == null or protection == null:
				return _failure("rare_human_warrior_combat_definition_incomplete")
			registrations.append(_wave_registration(actor, RareHumanWarriorFixture.make_defense_profile(RareHumanWarriorFixture.ACTOR_ID), protection, attack, {"left": String(RareHumanWarriorFixture.WEAPON_REF), "right": String(RareHumanWarriorFixture.WEAPON_REF)}))
			enemy_ids.append(String(RareHumanWarriorFixture.ACTOR_ID))
			attacks_by_actor[String(RareHumanWarriorFixture.ACTOR_ID)] = attack
			preferred_positions = [_initial_opponent_position_microfeet]
			_rare_human_warrior_actor_ids = enemy_ids.duplicate()
			set_wave_creature_integration_available(&"rare_human_warrior", true)
		_:
			return _failure("unsupported_wave_transition")
	if registrations.size() != enemy_ids.size() or preferred_positions.size() != enemy_ids.size():
		return _failure("wave_transition_plan_incomplete")
	var spawn_result := _resolve_transition_spawn_positions(enemy_ids, preferred_positions)
	if not spawn_result.get("success", false):
		return spawn_result
	var registration_result := simulation.register_arriving_wave_combatants(registrations)
	if not registration_result.get("success", false):
		return registration_result
	var positions: Array = spawn_result["positions"]
	for index in range(enemy_ids.size()):
		var position_result := simulation.apply_authoritative_spatial_position(StringName(enemy_ids[index]), positions[index], 0, 180_000 + index * 90_000)
		if not position_result.get("success", false):
			return position_result
	for actor_id: String in enemy_ids:
		_attack_definitions_by_actor[actor_id] = attacks_by_actor[actor_id]
	if wave_id == "wave_5":
		simulation.set_world_item_pickup_resolver(_resolve_world_item_pickup)
		RareHumanWarriorFixture.configure_spear_landing_geometry(simulation, _battlefield)
		_rare_human_warrior_ai = RareHumanWarriorBossAI.new(simulation, _battlefield, RareHumanWarriorFixture.ACTOR_ID, Fixture.PLAYER_ID)
	var activation := activate_current_wave(enemy_ids)
	if not activation.get("success", false):
		return activation
	_selected_target_id = StringName(enemy_ids[0])
	_selected_target_location = &"torso"
	_next_location_8_is_knee = true
	_initialize_wave_enemy_navigation_state()
	return {"success": true, "actor_ids": Array(enemy_ids), "opening_order": registration_result.get("opening_order", [])}


func _wave_registration(actor: CombatActorDefinition, defense: CombatDefenseProfile, protection: CombatDamageProtectionProfile, attack: CombatAttackDefinition, hand_occupancy: Dictionary = {}) -> Dictionary:
	return {
		"actor": actor,
		"defense_profile": defense,
		"protection_profile": protection,
		"attack_definition": attack,
		"hand_occupancy": hand_occupancy.duplicate(true),
	}


func _set_active_wave_kind(wave_id: String) -> void:
	_is_wave_one_goblin_encounter = wave_id == "wave_1"
	_is_wave_two_spadoodle_encounter = wave_id == "wave_2"
	_is_wave_three_skelly_hades_encounter = wave_id == "wave_3"
	_is_wave_four_gargoyle_encounter = wave_id == "wave_4"
	_is_wave_five_boss_encounter = wave_id == "wave_5"
	if not _is_wave_one_goblin_encounter:
		_goblin_actor_ids = PackedStringArray()
	if not _is_wave_two_spadoodle_encounter:
		_spadoodle_actor_ids = PackedStringArray()
	if not _is_wave_three_skelly_hades_encounter:
		_skelly_actor_ids = PackedStringArray()
		_hades_follower_actor_ids = PackedStringArray()
	if not _is_wave_four_gargoyle_encounter:
		_gargoyle_actor_ids = PackedStringArray()
	if not _is_wave_five_boss_encounter:
		_rare_human_warrior_actor_ids = PackedStringArray()
		_rare_human_warrior_ai = null


func _resolve_transition_spawn_positions(actor_ids: PackedStringArray, preferred: Array[Vector2i]) -> Dictionary:
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return _failure("player_state_unavailable")
	var occupancy := {String(Fixture.PLAYER_ID): player_state.position_microfeet}
	var positions: Array[Vector2i] = []
	for index in range(actor_ids.size()):
		var actor_id := StringName(actor_ids[index])
		var candidate := preferred[index]
		if not _battlefield.is_position_legal(actor_id, candidate, occupancy).get("legal", false):
			candidate = _find_transition_spawn_position(actor_id, occupancy)
		if candidate == INVALID_TRANSITION_POSITION:
			return _failure("wave_spawn_positions_unavailable")
		positions.append(candidate)
		occupancy[String(actor_id)] = candidate
	return {"success": true, "positions": positions}


func _find_transition_spawn_position(actor_id: StringName, occupancy: Dictionary) -> Vector2i:
	var bounds := _battlefield.bounds_microfeet
	var step := 2 * MICROFEET_PER_FOOT
	var start_x := bounds.position.x + MICROFEET_PER_FOOT
	var start_y := bounds.position.y + MICROFEET_PER_FOOT
	var end_x := bounds.end.x - MICROFEET_PER_FOOT
	var end_y := bounds.end.y - MICROFEET_PER_FOOT
	var y := start_y
	while y <= end_y:
		var x := start_x
		while x <= end_x:
			var candidate := Vector2i(x, y)
			if _battlefield.is_position_legal(actor_id, candidate, occupancy).get("legal", false):
				return candidate
			x += step
		y += step
	return INVALID_TRANSITION_POSITION


func _request_actor_attack(attacker_id: StringName, target_id: StringName, input_source: String, target_location: StringName = &"torso") -> Dictionary:
	var attack_definition := _get_attack_definition_for_actor(attacker_id)
	if attack_definition == null:
		return _failure("attack_definition_unavailable")
	var request_id := _next_request_id("%s_%s_attack" % [String(attacker_id), input_source])
	var nac_context := {}
	if _is_wave_four_gargoyle_encounter and _gargoyle_actor_ids.has(String(attacker_id)):
		var actor_state := simulation.get_actor_state(attacker_id)
		if actor_state != null and int(actor_state.ability_daily_remaining.get(String(MiniGargoyleSwarmerFixture.FURY_ABILITY_ID), 0)) > 0:
			nac_context = {
				"ability_id": String(MiniGargoyleSwarmerFixture.FURY_ABILITY_ID),
				"damage_multiplier": {"numerator": 2, "denominator": 1, "kind": "fury", "source_ref": "Uncommon Mini Gargoyle Swarmers.doc Fury; Task 33A owner-approved one-Act contract"},
			}
	var result := simulation.start_physical_attack(
		attacker_id,
		target_id,
		attack_definition,
		request_id,
		target_location,
		_resolve_attack_final_line_of_sight(attacker_id, target_id),
		PackedStringArray(),
		false,
		nac_context
	)
	if not result.get("success", false):
		return result
	var attack_id := String(result["attack_instance_id"])
	if attacker_id == Fixture.PLAYER_ID:
		_active_player_attack_id = attack_id
	elif attacker_id == Fixture.OPPONENT_ID:
		_active_opponent_attack_id = attack_id
	_active_attack_ids_by_actor[String(attacker_id)] = attack_id
	if target_id == Fixture.PLAYER_ID and attacker_id != Fixture.PLAYER_ID:
		_try_automatic_force_bolt_against(attacker_id)
	return result


func _try_automatic_force_bolt_against(threat_actor_id: StringName) -> void:
	if _player_character_id != Fixture.PLAYER_CHARACTER_VAELIS:
		return
	var settings := simulation.get_nac_automation(Fixture.PLAYER_ID)
	if not bool(settings.get("automatic_enabled", false)) or not bool(settings.get("offensive_triggers_enabled", true)):
		return
	# A concrete hostile physical declaration against Vaelis is authoritative
	# perceived danger. Mere distance/proximity never reaches this boundary.
	request_player_special(VaelisForce.FORCE_BOLT_ID, threat_actor_id, true, true)


func _get_attack_definition_for_actor(actor_id: StringName) -> CombatAttackDefinition:
	if _attack_definitions_by_actor.has(String(actor_id)):
		return _attack_definitions_by_actor[String(actor_id)] as CombatAttackDefinition
	return _attack_definition if actor_id == Fixture.PLAYER_ID or actor_id == Fixture.OPPONENT_ID else null


func _resolve_attack_final_line_of_sight(attacker_id: StringName, target_id: StringName) -> Variant:
	var attacker_state := simulation.get_actor_state(attacker_id)
	var target_state := simulation.get_actor_state(target_id)
	if attacker_state == null or target_state == null:
		return null
	if attacker_state.elevation_microfeet != 0 or target_state.elevation_microfeet != 0:
		return _battlefield.has_spatial_line_of_sight(
			Vector3i(attacker_state.position_microfeet.x, attacker_state.position_microfeet.y, attacker_state.elevation_microfeet),
			Vector3i(target_state.position_microfeet.x, target_state.position_microfeet.y, target_state.elevation_microfeet)
		)
	return _battlefield.has_line_of_sight(attacker_state.position_microfeet, target_state.position_microfeet)


func _resolve_special_touch(actor_id: StringName, target_id: StringName) -> bool:
	if actor_id == target_id:
		return true
	if _is_playable_wave_encounter():
		var actor_is_enemy := _wave_enemy_actor_ids().has(String(actor_id))
		var target_is_enemy := _wave_enemy_actor_ids().has(String(target_id))
		if actor_is_enemy != target_is_enemy:
			return false
	elif (actor_id == Fixture.PLAYER_ID and target_id == Fixture.OPPONENT_ID) \
	or (actor_id == Fixture.OPPONENT_ID and target_id == Fixture.PLAYER_ID):
		# The bounded duel fixtures contain opposing combatants, not an ally.
		# Fail closed rather than treating mere touch range as permission to
		# apply a self-or-ally Special to an enemy.
		return false
	var actor_state := simulation.get_actor_state(actor_id)
	var target_state := simulation.get_actor_state(target_id)
	if actor_state == null or target_state == null:
		return false
	if actor_state.current_hpc == null or int(actor_state.current_hpc) <= 0 \
	or target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return false
	return _battlefield.is_attack_position_legal(
		actor_state.position_microfeet,
		target_state.position_microfeet,
		MICROFEET_PER_FOOT
	) and _battlefield.has_line_of_sight(actor_state.position_microfeet, target_state.position_microfeet)


func _resolve_gatherable_material(actor_id: StringName, material_id: StringName, surface_id: String) -> bool:
	var actor_state := simulation.get_actor_state(actor_id)
	if actor_state == null:
		return false
	var fact := _battlefield.get_gatherable_material_at(actor_state.position_microfeet, material_id)
	return bool(fact.get("available", false)) and String(fact.get("surface_id", "")) == surface_id


func _resolve_world_item_pickup(actor_id: StringName, item: Dictionary) -> bool:
	var actor_state := simulation.get_actor_state(actor_id)
	var item_position: Variant = item.get("position_microfeet")
	if actor_state == null or not (item_position is Vector2i):
		return false
	if actor_state.position_microfeet.distance_to(item_position) > float(MICROFEET_PER_FOOT):
		return false
	# A projectile may legally rest on a wall face. Combat LOS treats touching
	# that face as obstructed, but pickup requires reachable physical contact,
	# not sight through the obstacle. Resolve motion toward the exact item and
	# accept only when collision leaves the actor inside the verified reach.
	var contact := _battlefield.resolve_motion(
		actor_id, actor_state.position_microfeet, item_position, _actor_occupancy()
	)
	return contact.get("success", false) \
		and (contact.get("position_microfeet", actor_state.position_microfeet) as Vector2i).distance_to(item_position) <= float(MICROFEET_PER_FOOT)


func _resolve_rage_knockback(attacker_id: StringName, target_id: StringName, distance_microfeet: int) -> Dictionary:
	var attacker_state := simulation.get_actor_state(attacker_id)
	var target_state := simulation.get_actor_state(target_id)
	if attacker_state == null or target_state == null:
		return {"success": false, "reason": "knockback_actor_unavailable"}
	var offset := target_state.position_microfeet - attacker_state.position_microfeet
	if offset == Vector2i.ZERO:
		return {"success": false, "reason": "knockback_direction_unresolved"}
	var direction := Vector2(offset).normalized()
	var desired := target_state.position_microfeet + Vector2i(
		roundi(direction.x * float(distance_microfeet)),
		roundi(direction.y * float(distance_microfeet))
	)
	var result := _battlefield.resolve_motion(
		target_id,
		target_state.position_microfeet,
		desired,
		_actor_occupancy()
	)
	result["facing_millidegrees"] = target_state.facing_millidegrees
	return result


func _run_opponent_behavior() -> void:
	if not _opponent_behavior_enabled:
		_opponent_behavior_status = "disabled"
		return
	if not _encounter_active or _encounter_state != ENCOUNTER_RUNNING:
		_opponent_behavior_status = "stopped"
		return
	if _is_playable_wave_encounter():
		if _is_wave_five_boss_encounter:
			_run_rare_human_warrior_behavior()
		else:
			_run_goblin_wave_behavior()
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
		var geometry := _get_actor_attack_geometry(Fixture.OPPONENT_ID, Fixture.PLAYER_ID)
		if is_opponent_attack_in_flight() and not geometry.get("success", false):
			var path_result := _ensure_current_opponent_path()
			_opponent_behavior_status = (
				"attacking_while_approaching"
				if path_result.get("success", false)
				else "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))
			)
		else:
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
		_opponent_behavior_status = "blocked_%s" % String(legality.get("reason", "attack_illegal"))
		return
	var result := _request_actor_attack(Fixture.OPPONENT_ID, Fixture.PLAYER_ID, "scripted")
	if not result.get("success", false):
		_opponent_behavior_status = "blocked_%s" % String(result.get("reason", "attack_rejected"))
		return
	var geometry := _get_actor_attack_geometry(Fixture.OPPONENT_ID, Fixture.PLAYER_ID)
	if geometry.get("success", false):
		_opponent_behavior_status = "attacking"
	elif not _battlefield.navigation_authoritative:
		_opponent_behavior_status = "approach_blocked_unverified_path"
	else:
		var path_result := _ensure_current_opponent_path()
		_opponent_behavior_status = "attacking_while_approaching" if path_result.get("success", false) else "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))


func _run_goblin_wave_behavior() -> void:
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null or player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		_opponent_behavior_status = "stopped_target_defeated"
		return
	var statuses: Array[String] = []
	for actor_id: String in _wave_enemy_actor_ids():
		var goblin_id := StringName(actor_id)
		var goblin_state := simulation.get_actor_state(goblin_id)
		if goblin_state == null or goblin_state.current_hpc == null or int(goblin_state.current_hpc) <= 0:
			_release_goblin_navigation_state(goblin_id)
			statuses.append("%s:defeated" % actor_id)
			continue
		if goblin_state.awareness != &"aware":
			statuses.append("%s:blocked_unaware" % actor_id)
			continue
		if goblin_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
			statuses.append("%s:blocked_critical_stagger" % actor_id)
			continue
		if goblin_state.conditions.has("prone"):
			var stand_result := simulation.start_stand_action(goblin_id, _next_request_id("%s_stand" % actor_id))
			statuses.append("%s:%s" % [actor_id, "standing" if stand_result.get("success", false) else "blocked_stand"])
			continue
		if not goblin_state.current_action_instance_id.is_empty() or _is_actor_attack_in_flight(goblin_id):
			if _is_wave_four_gargoyle_encounter and _gargoyle_actor_ids.has(actor_id):
				statuses.append("%s:%s" % [actor_id, _update_active_gargoyle_tactical_state(goblin_id, Fixture.PLAYER_ID)])
				continue
			if not _is_actor_attack_in_flight(goblin_id) and _actor_current_action_allows_movement(goblin_id):
				var rage_path := _ensure_current_goblin_path(goblin_id)
				statuses.append("%s:%s" % [actor_id, "acting_while_approaching" if rage_path.get("success", false) else "action_in_progress"])
			else:
				statuses.append("%s:action_in_progress" % actor_id)
			continue
		if _is_hades_follower(goblin_id):
			var tactical_result := _run_hades_tactical_selection(goblin_id, Fixture.PLAYER_ID)
			if tactical_result.get("action_started", false):
				statuses.append("%s:%s" % [actor_id, String(tactical_result.get("status", "special_started"))])
				continue
			if tactical_result.get("suppress_attack", false):
				statuses.append("%s:%s" % [actor_id, String(tactical_result.get("status", "support_approach"))])
				continue
		if _is_wave_four_gargoyle_encounter and _gargoyle_actor_ids.has(actor_id):
			var tactical_result := _run_gargoyle_tactical_selection(goblin_id, Fixture.PLAYER_ID)
			statuses.append("%s:%s" % [actor_id, String(tactical_result.get("status", "tactical_idle"))])
			continue
		var legality := _get_actor_attack_legality(goblin_id, Fixture.PLAYER_ID, true)
		if not legality.get("success", false):
			statuses.append("%s:blocked_%s" % [actor_id, String(legality.get("reason", "attack_illegal"))])
			continue
		if not bool(legality.get("currently_in_range", false)) or not bool(legality.get("currently_unobstructed", false)):
			if _is_wave_four_gargoyle_encounter and goblin_state.elevation_microfeet > 0:
				statuses.append("%s:approaching_in_flight" % actor_id)
				continue
			var path_result := _ensure_current_goblin_path(goblin_id)
			statuses.append("%s:%s" % [actor_id, "approaching" if path_result.get("success", false) else "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))])
			continue
		var attack_result := _request_actor_attack(
			goblin_id,
			Fixture.PLAYER_ID,
			("wave_4_scripted" if _is_wave_four_gargoyle_encounter else ("wave_3_scripted" if _is_wave_three_skelly_hades_encounter else ("wave_2_scripted" if _is_wave_two_spadoodle_encounter else "wave_1_scripted")))
		)
		statuses.append("%s:%s" % [actor_id, "attacking" if attack_result.get("success", false) else "blocked_%s" % String(attack_result.get("reason", "attack_rejected"))])
	statuses.sort()
	var wave_prefix := "wave_four " if _is_wave_four_gargoyle_encounter else ("wave_three " if _is_wave_three_skelly_hades_encounter else ("spadoodle_wave " if _is_wave_two_spadoodle_encounter else "goblin_wave "))
	_opponent_behavior_status = wave_prefix + ", ".join(PackedStringArray(statuses))


func _run_rare_human_warrior_behavior() -> void:
	if _rare_human_warrior_ai == null:
		_opponent_behavior_status = "wave_five_boss_ai_unavailable"
		return
	var result := _rare_human_warrior_ai.evaluate_and_submit()
	var selected_action := String(result.get("selected_action", "idle"))
	_opponent_behavior_status = "wave_five_boss_%s" % selected_action
	if result.get("action_started", false) and ["spear_melee", "throw_spear", "unarmed_attack"].has(selected_action):
		_try_automatic_force_bolt_against(RareHumanWarriorFixture.ACTOR_ID)


func _run_gargoyle_tactical_selection(actor_id: StringName, target_id: StringName) -> Dictionary:
	var actor_state := simulation.get_actor_state(actor_id)
	var target_state := simulation.get_actor_state(target_id)
	if actor_state == null or target_state == null:
		return {"action_started": false, "status": "blocked_missing_actor_state"}
	var key := String(actor_id)
	var tactical_state := String(_gargoyle_tactical_states.get(key, GARGOYLE_STATE_STAGING))
	if tactical_state == GARGOYLE_STATE_DIVING or tactical_state == GARGOYLE_STATE_STRIKING:
		_set_gargoyle_tactical_state(
			actor_id,
			target_id,
			GARGOYLE_STATE_WITHDRAWING,
			"injured_cautious_withdrawal" if _is_gargoyle_injured(actor_id) else "attack_act_completed"
		)
		tactical_state = GARGOYLE_STATE_WITHDRAWING
	if actor_state.elevation_microfeet == 0:
		if tactical_state != GARGOYLE_STATE_TAKING_OFF:
			_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_TAKING_OFF, "grounded_takeoff")
		return {
			"action_started": false,
			"status": "taking_off",
		}
	if tactical_state == GARGOYLE_STATE_TAKING_OFF:
		if actor_state.elevation_microfeet < mini(GARGOYLE_STAGING_ALTITUDE_MICROFEET, _battlefield.maximum_altitude_microfeet):
			return {"action_started": false, "status": "taking_off"}
		_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_STAGING, "takeoff_completed")
		tactical_state = GARGOYLE_STATE_STAGING
	if tactical_state == GARGOYLE_STATE_BLOCKED:
		_rotate_gargoyle_lane(actor_id)
		_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_STAGING, "alternate_lane_selected")
		tactical_state = GARGOYLE_STATE_STAGING
	if tactical_state == GARGOYLE_STATE_WITHDRAWING:
		var withdrawal_goal := _gargoyle_staging_goal(actor_id, target_id)
		if _gargoyle_goal_reached(actor_state, withdrawal_goal):
			_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_STAGING, "staging_altitude_recovered")
			tactical_state = GARGOYLE_STATE_STAGING
		else:
			return {"action_started": false, "status": GARGOYLE_STATE_WITHDRAWING}
	var staging_goal := _gargoyle_staging_goal(actor_id, target_id)
	if not _gargoyle_goal_reached(actor_state, staging_goal):
		return {"action_started": false, "status": GARGOYLE_STATE_STAGING}
	if _another_gargoyle_is_diving(actor_id):
		return {"action_started": false, "status": "staging_for_coordinated_opening"}
	var legality := _get_actor_attack_legality(actor_id, target_id, true)
	if not legality.get("success", false):
		return {"action_started": false, "status": "attack_blocked_%s" % String(legality.get("reason", "illegal"))}
	var attack_result := _request_actor_attack(actor_id, target_id, "wave_4_dive")
	if not attack_result.get("success", false):
		return {"action_started": false, "status": "attack_blocked_%s" % String(attack_result.get("reason", "rejected"))}
	_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_DIVING, "approach_capable_attack_declared")
	return {"action_started": true, "status": "diving_attack_in_progress"}


func _update_active_gargoyle_tactical_state(actor_id: StringName, target_id: StringName) -> String:
	if _is_actor_attack_in_flight(actor_id):
		if _get_actor_attack_geometry(actor_id, target_id).get("success", false):
			_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_STRIKING, "effect_position_reached")
			return "striking"
		_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_DIVING, "approaching_effect_position")
		return "diving_attack_in_progress"
	return "action_in_progress"


func _set_gargoyle_tactical_state(actor_id: StringName, target_id: StringName, state: String, reason: String) -> void:
	var key := String(actor_id)
	var previous := String(_gargoyle_tactical_states.get(key, ""))
	_gargoyle_tactical_states[key] = state
	if previous == state:
		return
	var signature := "%s|%s" % [state, reason]
	_gargoyle_last_tactical_signatures[key] = signature
	simulation.record_tactical_decision(actor_id, target_id, {
		"profile": "mini_gargoyle_swarmer",
		"previous_state": previous,
		"selected_action": state,
		"reason": reason,
		"lane_index": _gargoyle_lane_index(actor_id),
	})


func _rotate_gargoyle_lane(actor_id: StringName) -> void:
	var key := String(actor_id)
	_gargoyle_lane_offsets[key] = (int(_gargoyle_lane_offsets.get(key, 0)) + 1) % 4


func _gargoyle_lane_index(actor_id: StringName) -> int:
	var roster_index := _gargoyle_actor_ids.find(String(actor_id))
	return posmod(maxi(0, roster_index) + int(_gargoyle_lane_offsets.get(String(actor_id), 0)), 4)


func _gargoyle_lane_direction(actor_id: StringName) -> Vector2i:
	return [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][_gargoyle_lane_index(actor_id)]


func _gargoyle_staging_goal(actor_id: StringName, target_id: StringName) -> Vector3i:
	var target_state := simulation.get_actor_state(target_id)
	if target_state == null:
		return Vector3i.ZERO
	var direction := _gargoyle_lane_direction(actor_id)
	var staging_radius := GARGOYLE_INJURED_STAGING_RADIUS_MICROFEET if _is_gargoyle_injured(actor_id) else GARGOYLE_STAGING_RADIUS_MICROFEET
	return Vector3i(
		target_state.position_microfeet.x + direction.x * staging_radius,
		target_state.position_microfeet.y + direction.y * staging_radius,
		mini(GARGOYLE_STAGING_ALTITUDE_MICROFEET, _battlefield.maximum_altitude_microfeet)
	)


func _is_gargoyle_injured(actor_id: StringName) -> bool:
	var actor_state := simulation.get_actor_state(actor_id)
	var definition := simulation.get_actor_definition(actor_id)
	if actor_state == null or definition == null or actor_state.current_hpc == null:
		return false
	var hpm: Variant = definition.get_combat_stat("hpm")
	return hpm != null and int(actor_state.current_hpc) * 2 <= int(hpm)


func _gargoyle_attack_goal(actor_id: StringName, target_id: StringName) -> Dictionary:
	var target_state := simulation.get_actor_state(target_id)
	if target_state == null:
		return {"success": false, "reason": "missing_target_state"}
	var occupancy := _actor_spatial_occupancy()
	for lane_offset in range(4):
		var lane := posmod(_gargoyle_lane_index(actor_id) + lane_offset, 4)
		var direction: Vector2i = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP][lane]
		var candidate := Vector3i(
			target_state.position_microfeet.x + direction.x * GARGOYLE_ATTACK_HORIZONTAL_MICROFEET,
			target_state.position_microfeet.y + direction.y * GARGOYLE_ATTACK_HORIZONTAL_MICROFEET,
			target_state.elevation_microfeet + GARGOYLE_ATTACK_ALTITUDE_MICROFEET
		)
		if not _battlefield.is_spatial_position_legal(actor_id, candidate, occupancy).get("legal", false):
			continue
		var target_position := Vector3i(target_state.position_microfeet.x, target_state.position_microfeet.y, target_state.elevation_microfeet)
		if not _battlefield.has_spatial_line_of_sight(candidate, target_position):
			continue
		return {"success": true, "position_microfeet": candidate, "lane_index": lane}
	return {"success": false, "reason": "no_legal_attack_space"}


func _gargoyle_goal_reached(actor_state: CombatActorState, goal: Vector3i) -> bool:
	var current := Vector3i(actor_state.position_microfeet.x, actor_state.position_microfeet.y, actor_state.elevation_microfeet)
	return Vector3(current - goal).length_squared() <= float(GARGOYLE_GOAL_TOLERANCE_MICROFEET * GARGOYLE_GOAL_TOLERANCE_MICROFEET)


func _another_gargoyle_is_diving(actor_id: StringName) -> bool:
	for other_id: String in _gargoyle_actor_ids:
		if other_id == String(actor_id):
			continue
		var other_state := simulation.get_actor_state(StringName(other_id))
		if other_state == null or (other_state.current_hpc != null and int(other_state.current_hpc) <= 0):
			continue
		var tactical_state := String(_gargoyle_tactical_states.get(other_id, ""))
		if tactical_state == GARGOYLE_STATE_DIVING or tactical_state == GARGOYLE_STATE_STRIKING:
			return true
	return false


func _gargoyle_landing_goal(gargoyle_position: Vector2i, target_position: Vector2i) -> Vector2i:
	var away := Vector2(gargoyle_position - target_position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	away = away.normalized()
	return target_position + Vector2i(
		roundi(away.x * float(MICROFEET_PER_FOOT)),
		roundi(away.y * float(MICROFEET_PER_FOOT))
	)


func _get_wave_enemy_navigation_goal(actor_id: StringName) -> Dictionary:
	var actor_state := simulation.get_actor_state(actor_id)
	if actor_state != null and not actor_state.current_action_instance_id.is_empty():
		var action := simulation.get_action(actor_state.current_action_instance_id)
		if action != null and bool(action.execution_context.get("touch_required", false)):
			return {
				"target_actor_id": StringName(action.execution_context.get("target_actor_id", "")),
				"reach_microfeet": MICROFEET_PER_FOOT,
			}
	var support_target := StringName(_hades_support_target_ids.get(String(actor_id), ""))
	if not String(support_target).is_empty():
		var support_state := simulation.get_actor_state(support_target)
		if support_state != null and support_state.current_hpc != null and int(support_state.current_hpc) > 0:
			return {"target_actor_id": support_target, "reach_microfeet": MICROFEET_PER_FOOT}
		_hades_support_target_ids.erase(String(actor_id))
	var attack_definition := _get_attack_definition_for_actor(actor_id)
	return {
		"target_actor_id": Fixture.PLAYER_ID,
		"reach_microfeet": 0 if attack_definition == null else int(attack_definition.maximum_range_microfeet),
	}


func _build_goblin_approach_path(goblin_id: StringName) -> Dictionary:
	var goblin_state := simulation.get_actor_state(goblin_id)
	var goal := _get_wave_enemy_navigation_goal(goblin_id)
	var target_id := StringName(goal.get("target_actor_id", ""))
	var target_state := simulation.get_actor_state(target_id)
	var reach_microfeet := int(goal.get("reach_microfeet", 0))
	if goblin_state == null or target_state == null or reach_microfeet <= 0:
		return {"success": false, "reason": "missing_actor_or_attack_definition"}
	var path_result := _battlefield.find_path_to_attack_position(
		goblin_id,
		goblin_state.position_microfeet,
		target_state.position_microfeet,
		reach_microfeet,
		_actor_occupancy_with_goblin_reservations(goblin_id, target_state.position_microfeet)
	)
	var key := String(goblin_id)
	var navigation_signature := _goblin_navigation_state_signature(goblin_id, target_state.position_microfeet, reach_microfeet)
	_goblin_paths[key] = []
	_goblin_path_targets[key] = target_state.position_microfeet
	_goblin_path_target_actor_ids[key] = String(target_id)
	_goblin_path_reaches[key] = reach_microfeet
	_goblin_path_rebuild_counts[key] = int(_goblin_path_rebuild_counts.get(key, 0)) + 1
	if path_result.get("success", false):
		var path: Array[Vector2i] = []
		for waypoint: Vector2i in path_result.get("waypoints", []):
			path.append(waypoint)
		_goblin_paths[key] = path
		_goblin_attack_destinations[key] = goblin_state.position_microfeet if path.is_empty() else path[-1]
		_goblin_failed_path_cache.erase(key)
	else:
		_goblin_attack_destinations.erase(key)
		_goblin_failed_path_cache[key] = {
			"signature": navigation_signature,
			"reason": String(path_result.get("reason", "no_legal_path")),
		}
	return path_result


func _ensure_current_goblin_path(goblin_id: StringName) -> Dictionary:
	var goal := _get_wave_enemy_navigation_goal(goblin_id)
	var target_id := StringName(goal.get("target_actor_id", ""))
	var target_state := simulation.get_actor_state(target_id)
	var reach_microfeet := int(goal.get("reach_microfeet", 0))
	if target_state == null or reach_microfeet <= 0:
		return {"success": false, "reason": "missing_actor_state"}
	var key := String(goblin_id)
	var path: Array = _goblin_paths.get(key, [])
	var remembered_target: Variant = _goblin_path_targets.get(key, null)
	if String(_goblin_path_target_actor_ids.get(key, "")) != String(target_id) \
	or int(_goblin_path_reaches.get(key, -1)) != reach_microfeet:
		_invalidate_goblin_path(goblin_id)
		return _build_goblin_approach_path(goblin_id)
	if path.is_empty() or remembered_target == null:
		var signature := _goblin_navigation_state_signature(goblin_id, target_state.position_microfeet, reach_microfeet)
		var cached_failure: Dictionary = _goblin_failed_path_cache.get(key, {})
		if not signature.is_empty() and String(cached_failure.get("signature", "")) == signature:
			_goblin_failed_path_cache_hits[key] = int(_goblin_failed_path_cache_hits.get(key, 0)) + 1
			return {
				"success": false,
				"reason": "cached_%s" % String(cached_failure.get("reason", "no_legal_path")),
			}
		return _build_goblin_approach_path(goblin_id)
	var target_offset: Vector2i = target_state.position_microfeet - remembered_target
	if target_offset != Vector2i.ZERO and _retarget_current_goblin_path(goblin_id, target_state.position_microfeet, target_offset, reach_microfeet).get("success", false):
		return {"success": true, "reason": "retargeted_existing_path"}
	if target_offset.length_squared() >= OPPONENT_REPATH_DISTANCE_MICROFEET * OPPONENT_REPATH_DISTANCE_MICROFEET:
		return _build_goblin_approach_path(goblin_id)
	return {"success": true, "reason": "stable_existing_path"}


func _goblin_navigation_state_signature(goblin_id: StringName, target_position: Vector2i, reach_microfeet: int = -1) -> String:
	var goblin_state := simulation.get_actor_state(goblin_id)
	var attack_definition := _get_attack_definition_for_actor(goblin_id)
	if goblin_state == null or attack_definition == null:
		return ""
	var effective_reach := int(attack_definition.maximum_range_microfeet) if reach_microfeet < 0 else reach_microfeet
	var occupancy := _actor_occupancy_with_goblin_reservations(goblin_id, target_position)
	var occupied_entries: Array[Dictionary] = []
	for occupancy_key: Variant in occupancy.keys():
		if String(occupancy_key) == String(goblin_id):
			continue
		occupied_entries.append({
			"id": String(occupancy_key),
			"position": occupancy[occupancy_key],
		})
	occupied_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left["id"]) < String(right["id"])
	)
	var parts := PackedStringArray([
		"start=%d,%d" % [goblin_state.position_microfeet.x, goblin_state.position_microfeet.y],
		"target=%d,%d" % [target_position.x, target_position.y],
		"reach=%d" % effective_reach,
	])
	for entry: Dictionary in occupied_entries:
		var position: Vector2i = entry["position"]
		parts.append("%s=%d,%d" % [String(entry["id"]), position.x, position.y])
	return "|".join(parts)


func _invalidate_goblin_path(goblin_id: StringName) -> void:
	var key := String(goblin_id)
	_goblin_paths[key] = []
	_goblin_path_targets.erase(key)
	_goblin_path_target_actor_ids.erase(key)
	_goblin_path_reaches.erase(key)
	_goblin_attack_destinations.erase(key)
	_goblin_failed_path_cache.erase(key)


func _release_goblin_navigation_state(goblin_id: StringName) -> void:
	var key := String(goblin_id)
	_goblin_paths.erase(key)
	_goblin_path_targets.erase(key)
	_goblin_path_target_actor_ids.erase(key)
	_goblin_path_reaches.erase(key)
	_goblin_attack_destinations.erase(key)
	_goblin_failed_path_cache.erase(key)


func _retarget_current_goblin_path(goblin_id: StringName, target_position: Vector2i, target_offset: Vector2i, reach_microfeet: int = -1) -> Dictionary:
	var key := String(goblin_id)
	var path: Array = _goblin_paths.get(key, [])
	var goblin_state := simulation.get_actor_state(goblin_id)
	var attack_definition := _get_attack_definition_for_actor(goblin_id)
	if path.is_empty() or goblin_state == null or attack_definition == null:
		return {"success": false, "reason": "missing_route_state"}
	var effective_reach := int(attack_definition.maximum_range_microfeet) if reach_microfeet < 0 else reach_microfeet
	var destination: Vector2i = path[-1] + target_offset
	var segment_start: Vector2i = goblin_state.position_microfeet if path.size() == 1 else path[-2]
	var static_occupancy := {String(goblin_id): goblin_state.position_microfeet}
	if not _battlefield.is_position_legal(goblin_id, destination, static_occupancy).get("legal", false):
		return {"success": false, "reason": "static_topology_changed"}
	if not _battlefield.is_attack_position_legal(destination, target_position, effective_reach):
		return {"success": false, "reason": "static_topology_changed"}
	if not _battlefield.is_direct_path_clear(goblin_id, segment_start, destination, static_occupancy):
		return {"success": false, "reason": "static_topology_changed"}
	var occupancy := _actor_occupancy_with_goblin_reservations(goblin_id, target_position)
	if not _battlefield.is_position_legal(goblin_id, destination, occupancy).get("legal", false):
		return {"success": false, "reason": "dynamic_occupancy_blocked"}
	if not _battlefield.is_direct_path_clear(goblin_id, segment_start, destination, occupancy):
		return {"success": false, "reason": "dynamic_occupancy_blocked"}
	path[-1] = destination
	_goblin_paths[key] = path
	_goblin_path_targets[key] = target_position
	_goblin_path_reaches[key] = effective_reach
	_goblin_attack_destinations[key] = destination
	return {"success": true, "reason": "retargeted"}


func _actor_occupancy_with_goblin_reservations(mover_id: StringName, target_position: Vector2i) -> Dictionary:
	var occupancy := _actor_occupancy()
	for actor_key: Variant in _goblin_attack_destinations.keys():
		var other_key := String(actor_key)
		if String(mover_id) == other_key:
			continue
		var other_state := simulation.get_actor_state(StringName(other_key))
		if other_state == null or other_state.current_hpc == null or int(other_state.current_hpc) <= 0:
			continue
		var reserved: Vector2i = _goblin_attack_destinations[other_key]
		var remembered_target: Variant = _goblin_path_targets.get(other_key, target_position)
		if remembered_target != null:
			reserved += target_position - (remembered_target as Vector2i)
		occupancy["goblin_attack_reservation:%s" % other_key] = reserved
	return occupancy


func _advance_goblin_movement(delta_us: int) -> void:
	if delta_us <= 0 or not _encounter_active or not _opponent_behavior_enabled:
		return
	for actor_id: String in _wave_enemy_actor_ids():
		var goblin_id := StringName(actor_id)
		var goblin_state := simulation.get_actor_state(goblin_id)
		var movement_model: PrimeMovementModel = _goblin_movement_models.get(actor_id)
		if goblin_state == null or movement_model == null or goblin_state.current_hpc == null or int(goblin_state.current_hpc) <= 0:
			continue
		if goblin_state.conditions.has("prone") or goblin_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
			movement_model.set_prone(goblin_state.conditions.has("prone"))
			movement_model.advance(delta_us, Vector2.ZERO)
			continue
		var goal := _get_wave_enemy_navigation_goal(goblin_id)
		var goal_target_id := StringName(goal.get("target_actor_id", ""))
		var goal_target_state := simulation.get_actor_state(goal_target_id)
		var goal_reach := int(goal.get("reach_microfeet", 0))
		var geometry := _get_actor_attack_geometry(goblin_id, Fixture.PLAYER_ID) \
			if goal_target_id == Fixture.PLAYER_ID else {"success": false}
		var goal_reached: bool = bool(geometry.get("success", false))
		if goal_target_state != null and goal_target_id != Fixture.PLAYER_ID:
			goal_reached = _battlefield.is_attack_position_legal(
				goblin_state.position_microfeet, goal_target_state.position_microfeet, goal_reach
			) and _battlefield.has_line_of_sight(goblin_state.position_microfeet, goal_target_state.position_microfeet)
		var movement_blocked_by_action := not goblin_state.current_action_instance_id.is_empty() and not _actor_current_action_allows_movement(goblin_id)
		if goal_reached or movement_blocked_by_action or _is_actor_attack_in_flight(goblin_id):
			movement_model.advance(delta_us, Vector2.ZERO)
			continue
		var path_result := _ensure_current_goblin_path(goblin_id)
		var path: Array = _goblin_paths.get(actor_id, [])
		if not path_result.get("success", false) or path.is_empty():
			movement_model.advance(delta_us, Vector2.ZERO)
			continue
		_refresh_goblin_movement_ledger(goblin_id)
		var allowance := int(_actor_definition_snapshot(goblin_id).get("combat_stats", {}).get("mr", 0)) * MICROFEET_PER_FOOT
		var spent := int(_goblin_movement_spent.get(actor_id, 0))
		var remaining := maxi(0, allowance - spent)
		var waypoint: Vector2i = path[0]
		var offset := waypoint - goblin_state.position_microfeet
		movement_model.position_feet = Vector2(goblin_state.position_microfeet) / float(MICROFEET_PER_FOOT)
		var displacement := movement_model.advance(delta_us, Vector2(offset).normalized())
		var budget := mini(roundi(displacement.length() * float(MICROFEET_PER_FOOT)), remaining)
		if budget <= 0:
			continue
		var destination := waypoint
		var distance := roundi(Vector2(offset).length())
		if distance > budget:
			destination = goblin_state.position_microfeet + Vector2i(roundi(float(offset.x) * budget / float(distance)), roundi(float(offset.y) * budget / float(distance)))
		var movement_start: Vector2i = goblin_state.position_microfeet
		var resolved := _battlefield.resolve_motion(goblin_id, movement_start, destination, _actor_occupancy())
		if not resolved.get("success", false) or int(resolved.get("movement_cost_microfeet", 0)) <= 0:
			_invalidate_goblin_path(goblin_id)
			continue
		var collision_limited: bool = bool(resolved.get("blocked", false)) or resolved["position_microfeet"] != destination
		var static_path_clear := _battlefield.is_direct_path_clear(
			goblin_id,
			movement_start,
			destination,
			{String(goblin_id): movement_start}
		)
		var blocked_by_static_geometry: bool = collision_limited and not static_path_clear
		goblin_state.movement_round_index = simulation.clock.get_round_index()
		goblin_state.remaining_mr_microfeet = remaining
		var facing := facing_millidegrees_for_displacement(
			resolved["position_microfeet"] - movement_start,
			goblin_state.facing_millidegrees
		)
		var movement_result := simulation.apply_authoritative_position(goblin_id, resolved["position_microfeet"], facing, int(resolved["movement_cost_microfeet"]))
		if movement_result.get("success", false):
			_goblin_movement_spent[actor_id] = spent + int(resolved["movement_cost_microfeet"])
			movement_model.position_feet = Vector2(resolved["position_microfeet"]) / float(MICROFEET_PER_FOOT)
			if blocked_by_static_geometry:
				_goblin_static_collision_counts[actor_id] = int(_goblin_static_collision_counts.get(actor_id, 0)) + 1
				_invalidate_goblin_path(goblin_id)
			elif resolved["position_microfeet"] == waypoint:
				path.pop_front()
				_goblin_paths[actor_id] = path
	_interrupt_invalid_special_contacts()


func _advance_gargoyle_flight(delta_us: int) -> void:
	if delta_us <= 0 or not _encounter_active or not _opponent_behavior_enabled:
		return
	var target_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if target_state == null or target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return
	for actor_id: String in _gargoyle_actor_ids:
		var gargoyle_id := StringName(actor_id)
		var state := simulation.get_actor_state(gargoyle_id)
		if state == null or state.current_hpc == null or int(state.current_hpc) <= 0:
			continue
		if state.conditions.has("prone") or state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
			continue
		var tactical_state := String(_gargoyle_tactical_states.get(actor_id, GARGOYLE_STATE_STAGING))
		var attack_in_flight := _is_actor_attack_in_flight(gargoyle_id)
		if attack_in_flight and _get_actor_attack_geometry(gargoyle_id, Fixture.PLAYER_ID).get("success", false):
			_set_gargoyle_tactical_state(gargoyle_id, Fixture.PLAYER_ID, GARGOYLE_STATE_STRIKING, "effect_position_reached")
			continue
		if state.elevation_microfeet == 0 and tactical_state != GARGOYLE_STATE_TAKING_OFF:
			continue
		_refresh_goblin_movement_ledger(gargoyle_id)
		var movement_rate := int(_actor_definition_snapshot(gargoyle_id).get("combat_stats", {}).get("mr", 0))
		var allowance := movement_rate * MICROFEET_PER_FOOT
		var spent := int(_goblin_movement_spent.get(actor_id, 0))
		var remaining := maxi(0, allowance - spent)
		@warning_ignore("integer_division")
		var tick_budget := int((movement_rate * MICROFEET_PER_FOOT * delta_us) / CombatClock.ROUND_DURATION_US)
		var budget := mini(tick_budget, remaining)
		if budget <= 0:
			continue
		var start := Vector3i(state.position_microfeet.x, state.position_microfeet.y, state.elevation_microfeet)
		var goal := Vector3i(state.position_microfeet.x, state.position_microfeet.y, state.elevation_microfeet)
		if tactical_state == GARGOYLE_STATE_TAKING_OFF:
			goal.z = mini(GARGOYLE_STAGING_ALTITUDE_MICROFEET, _battlefield.maximum_altitude_microfeet)
		elif attack_in_flight:
			var attack_goal := _gargoyle_attack_goal(gargoyle_id, Fixture.PLAYER_ID)
			if not attack_goal.get("success", false):
				_record_gargoyle_approach_failure(gargoyle_id, Fixture.PLAYER_ID, String(attack_goal.get("reason", "no_legal_attack_space")))
				continue
			goal = attack_goal["position_microfeet"]
		else:
			goal = _gargoyle_staging_goal(gargoyle_id, Fixture.PLAYER_ID)
		var delta := goal - start
		var distance := roundi(Vector3(delta).length())
		if distance <= 0:
			continue
		var desired := goal
		if distance > budget:
			desired = start + Vector3i(
				roundi(float(delta.x) * float(budget) / float(distance)),
				roundi(float(delta.y) * float(budget) / float(distance)),
				roundi(float(delta.z) * float(budget) / float(distance))
			)
		var resolved := _battlefield.resolve_spatial_motion(gargoyle_id, start, desired, _actor_spatial_occupancy())
		if not resolved.get("success", false) or int(resolved.get("movement_cost_microfeet", 0)) <= 0:
			if desired != start:
				var static_occupancy := {String(gargoyle_id): start}
				var static_resolution := _battlefield.resolve_spatial_motion(gargoyle_id, start, desired, static_occupancy)
				var dynamic_congestion: bool = int(static_resolution.get("movement_cost_microfeet", 0)) > 0
				_record_gargoyle_approach_failure(
					gargoyle_id,
					Fixture.PLAYER_ID,
					"actor_congestion" if dynamic_congestion else String(resolved.get("reason", "collision_limited")),
					not dynamic_congestion
				)
			continue
		var destination: Vector3i = resolved["position_microfeet"]
		state.movement_round_index = simulation.clock.get_round_index()
		state.remaining_mr_microfeet = remaining
		var facing := facing_millidegrees_for_displacement(Vector2i(destination.x - start.x, destination.y - start.y), state.facing_millidegrees)
		var movement_result := simulation.apply_authoritative_spatial_position(
			gargoyle_id, Vector2i(destination.x, destination.y), destination.z, facing, int(resolved["movement_cost_microfeet"])
		)
		if movement_result.get("success", false):
			_goblin_movement_spent[actor_id] = spent + int(resolved["movement_cost_microfeet"])
			if bool(resolved.get("blocked", false)) and destination != desired:
				var static_occupancy := {String(gargoyle_id): start}
				var static_resolution := _battlefield.resolve_spatial_motion(gargoyle_id, start, desired, static_occupancy)
				var dynamic_congestion: bool = static_resolution.get("position_microfeet", start) == desired
				_record_gargoyle_approach_failure(
					gargoyle_id,
					Fixture.PLAYER_ID,
					"actor_congestion" if dynamic_congestion else String(resolved.get("reason", "collision_limited")),
					not dynamic_congestion
				)


func _record_gargoyle_approach_failure(actor_id: StringName, target_id: StringName, reason: String, rotate_lane: bool = true) -> void:
	var key := String(actor_id)
	var failure_signature := "%s|%s|%s" % [reason, str(simulation.get_actor_state(actor_id).position_microfeet), str(_gargoyle_lane_index(actor_id))]
	if String(_gargoyle_last_tactical_signatures.get("failure:%s" % key, "")) == failure_signature:
		return
	_gargoyle_last_tactical_signatures["failure:%s" % key] = failure_signature
	_gargoyle_failed_approach_counts[key] = int(_gargoyle_failed_approach_counts.get(key, 0)) + 1
	if rotate_lane:
		_rotate_gargoyle_lane(actor_id)
		_set_gargoyle_tactical_state(actor_id, target_id, GARGOYLE_STATE_BLOCKED, "approach_failed_%s" % reason)
	else:
		simulation.record_tactical_decision(actor_id, target_id, {
			"profile": "mini_gargoyle_swarmer",
			"selected_action": "hold_for_actor_clearance",
			"reason": reason,
			"lane_index": _gargoyle_lane_index(actor_id),
		})


func _interrupt_invalid_special_contacts() -> void:
	var interruption_scheduled := false
	for actor_id: String in _wave_enemy_actor_ids():
		var state := simulation.get_actor_state(StringName(actor_id))
		if state == null or state.current_action_instance_id.is_empty():
			continue
		var action := simulation.get_action(state.current_action_instance_id)
		if action == null or not bool(action.execution_context.get("touch_required", false)):
			continue
		var target_id := StringName(action.execution_context.get("target_actor_id", ""))
		if _resolve_special_touch(StringName(actor_id), target_id):
			continue
		var interruption := simulation.schedule_interruption(
			action.action_instance_id, simulation.clock.get_elapsed_us(), target_id, "special_touch_lost"
		)
		interruption_scheduled = interruption_scheduled or bool(interruption.get("success", false))
	if interruption_scheduled:
		simulation.advance_to(simulation.clock.get_elapsed_us())


func _make_goblin_movement_model(goblin_id: StringName, position_microfeet: Vector2i) -> PrimeMovementModel:
	var actor := _actor_definition_snapshot(goblin_id)
	var model := PrimeMovementModel.new(
		int(actor.get("combat_stats", {}).get("mr", 0)),
		int(actor.get("attributes", {}).get("spd", 0)),
		int(actor.get("attributes", {}).get("end", 0)),
		0,
		0,
		int(actor.get("combat_stats", {}).get("rb", 0)),
		simulation.random
	)
	model.position_feet = Vector2(position_microfeet) / float(MICROFEET_PER_FOOT)
	return model


func _refresh_goblin_movement_ledger(goblin_id: StringName) -> void:
	var key := String(goblin_id)
	var round_index := simulation.clock.get_round_index()
	if int(_goblin_movement_round_indices.get(key, -1)) == round_index:
		return
	_goblin_movement_round_indices[key] = round_index
	_goblin_movement_spent[key] = 0


func _update_encounter_outcome() -> void:
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if _is_playable_wave_encounter():
		if player_state == null:
			return
		if player_state.current_hpc != null and int(player_state.current_hpc) <= 0:
			_encounter_state = ENCOUNTER_PLAYER_DEFEAT
			_encounter_active = false
			_opponent_behavior_status = "stopped_player_defeated"
			return
		var wave_victory := evaluate_current_wave_victory()
		if wave_victory.get("success", false) and _arena_wave_state_machine.get_state() == ArenaWaveStateMachine.STATE_VICTORY_DETECTED:
			var downtime := _enter_between_wave_downtime()
			if not downtime.get("success", false):
				_last_error = String(downtime.get("reason", "between_wave_downtime_failed"))
		return
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
	if _active_attack_ids_by_actor.has(String(actor_id)):
		return _is_attack_in_flight(String(_active_attack_ids_by_actor[String(actor_id)]))
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
			var attack := simulation.get_attack(attack_id)
			if status == CombatAttackInstance.STATUS_PENDING_DEFENSE:
				var defense_result := simulation.resolve_pending_defense_automatically(
					attack_id,
					_next_request_id("defense"),
					_make_dodge_environment(attack)
				)
				if not defense_result.get("success", false):
					_last_error = String(defense_result.get("reason", "defense_resolution_failed"))
				else:
					changed = true
					if attack != null and attack.strikes_per_act > 1:
						break
			elif status == CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED:
				var damage_result := (
					simulation.resolve_nac_projectile_damage(attack_id, _next_request_id("special_damage"))
					if attack != null and attack.is_special_attack
					else simulation.resolve_physical_damage(attack_id, _next_request_id("damage"))
				)
				if not damage_result.get("success", false):
					_last_error = String(damage_result.get("reason", "damage_resolution_failed"))
				else:
					changed = true
					if attack != null and attack.strikes_per_act > 1:
						break


func _make_dodge_environment(attack: CombatAttackInstance) -> CombatDodgeEnvironment:
	var defender_state := simulation.get_actor_state(attack.target_id)
	var attacker_state := simulation.get_actor_state(attack.attacker_id)
	var candidates: Array[CombatDodgeCandidate] = []
	if defender_state == null or attacker_state == null:
		return CombatDodgeEnvironment.new(&"task14_incomplete", false, candidates, "Task 14 fixture actor state unavailable")
	var defender_definition: Dictionary = _actor_definition_snapshot(attack.target_id)
	var defender_mr := int(defender_definition.get("combat_stats", {}).get("mr", 0))
	var maximum_dodge_feet := floori(float(defender_mr) / 2.0)
	if defender_state.conditions.has("prone"):
		# Arena Task 17 crawl is one quarter walking MR; Prime then rounds the
		# half-MR Dodge allowance down to whole feet.
		@warning_ignore("integer_division")
		maximum_dodge_feet = defender_mr / 8
	var attack_definition := simulation.get_attack_definition(attack.attack_definition_id)
	if attack_definition == null:
		attack_definition = _get_attack_definition_for_actor(attack.attacker_id)
	var maximum_attack_range := (
		VaelisForce.FORCE_BOLT_RANGE_MICROFEET
		if attack.is_special_attack and attack.special_id == VaelisForce.FORCE_BOLT_ID
		else (0 if attack_definition == null else int(attack_definition.maximum_range_microfeet))
	)
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
	for actor_snapshot: Dictionary in simulation.get_state_snapshot().get("actors", []):
		var actor_id := StringName(actor_snapshot.get("state", {}).get("actor_id", ""))
		var state := simulation.get_actor_state(actor_id)
		if state == null:
			continue
		if state.current_hpc != null and int(state.current_hpc) <= 0:
			continue
		occupancy[String(actor_id)] = state.position_microfeet
	return occupancy


func _actor_spatial_occupancy() -> Dictionary:
	var occupancy := {}
	for actor_snapshot: Dictionary in simulation.get_state_snapshot().get("actors", []):
		var actor_id := StringName(actor_snapshot.get("state", {}).get("actor_id", ""))
		var state := simulation.get_actor_state(actor_id)
		if state == null or (state.current_hpc != null and int(state.current_hpc) <= 0):
			continue
		occupancy[String(actor_id)] = Vector3i(state.position_microfeet.x, state.position_microfeet.y, state.elevation_microfeet)
	return occupancy


func _actor_planar_occupancy_at_elevation(mover_id: StringName, elevation_microfeet: int) -> Dictionary:
	var occupancy := {}
	var minimum_separation := _battlefield.actor_radius_microfeet * 2
	for actor_snapshot: Dictionary in simulation.get_state_snapshot().get("actors", []):
		var actor_id := StringName(actor_snapshot.get("state", {}).get("actor_id", ""))
		if actor_id == mover_id:
			continue
		var state := simulation.get_actor_state(actor_id)
		if state == null or (state.current_hpc != null and int(state.current_hpc) <= 0):
			continue
		if absi(state.elevation_microfeet - elevation_microfeet) >= minimum_separation:
			continue
		occupancy[String(actor_id)] = state.position_microfeet
	return occupancy


func _sorted_dictionary_copy(source: Dictionary) -> Dictionary:
	var result := {}
	var keys: Array = source.keys()
	keys.sort()
	for key: Variant in keys:
		result[key] = source[key]
	return result


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


func _has_authoritative_opponent_movement() -> bool:
	return _opponent_behavior_enabled and (_is_playable_wave_encounter() or _opponent_movement_model != null)


func _make_wave_one_goblin_positions(first_position: Vector2i, count: int) -> Array[Vector2i]:
	# Fixed source-neutral Arena test positions. They only determine placement;
	# all movement, reach and collision remain authoritative afterwards.
	# The first four offsets remain unchanged. The second four extend the same
	# legal two-column formation vertically without changing Arena dimensions.
	var offsets := [
		Vector2i.ZERO,
		Vector2i(0, 2_000_000),
		Vector2i(2_000_000, 0),
		Vector2i(2_000_000, 2_000_000),
		Vector2i(0, -2_000_000),
		Vector2i(2_000_000, -2_000_000),
		Vector2i(0, 4_000_000),
		Vector2i(2_000_000, 4_000_000),
	]
	var positions: Array[Vector2i] = []
	for index in range(count):
		if index >= offsets.size():
			return []
		positions.append(first_position + offsets[index])
	return positions


func _goblin_actor_id(index: int) -> StringName:
	return StringName("wave_1_common_goblin_%02d" % (index + 1))


func _spadoodle_actor_id(index: int) -> StringName:
	return StringName("wave_2_common_spadoodle_%02d" % (index + 1))


func _make_wave_two_spadoodle_positions(first_position: Vector2i, count: int) -> Array[Vector2i]:
	var offsets := [
		Vector2i.ZERO,
		Vector2i(0, 2_000_000),
		Vector2i(2_000_000, 0),
	]
	var positions: Array[Vector2i] = []
	for index in range(count):
		if index >= offsets.size():
			return []
		positions.append(first_position + offsets[index])
	return positions


func _gargoyle_actor_id(index: int) -> StringName:
	return StringName("wave_4_mini_gargoyle_swarmer_%02d" % (index + 1))


func _make_wave_four_gargoyle_positions(first_position: Vector2i, count: int) -> Array[Vector2i]:
	var offsets := [Vector2i.ZERO, Vector2i(0, 2_000_000), Vector2i(2_000_000, 0), Vector2i(2_000_000, 2_000_000)]
	var positions: Array[Vector2i] = []
	for index in range(count):
		if index >= offsets.size():
			return []
		positions.append(first_position + offsets[index])
	return positions


func _skelly_actor_id(index: int) -> StringName:
	return StringName("wave_3_common_skelly_%02d" % (index + 1))


func _hades_follower_actor_id() -> StringName:
	return &"wave_3_hades_combat_follower_01"


func _make_wave_three_positions(first_position: Vector2i, skelly_count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var offsets := [Vector2i.ZERO, Vector2i(0, 2_000_000)]
	for index in range(skelly_count):
		positions.append(first_position + offsets[index])
	positions.append(first_position + Vector2i(2_000_000, 0))
	return positions


func _is_playable_wave_encounter() -> bool:
	return _is_wave_one_goblin_encounter or _is_wave_two_spadoodle_encounter or _is_wave_three_skelly_hades_encounter or _is_wave_four_gargoyle_encounter or _is_wave_five_boss_encounter


func _wave_enemy_actor_ids() -> PackedStringArray:
	if _is_wave_five_boss_encounter:
		return _rare_human_warrior_actor_ids
	if _is_wave_four_gargoyle_encounter:
		return _gargoyle_actor_ids
	if _is_wave_three_skelly_hades_encounter:
		var combined := _skelly_actor_ids.duplicate()
		combined.append_array(_hades_follower_actor_ids)
		return combined
	return _spadoodle_actor_ids if _is_wave_two_spadoodle_encounter else _goblin_actor_ids


func _is_hades_follower(actor_id: StringName) -> bool:
	return String(actor_id).begins_with("wave_3_hades_combat_follower_")


func _actor_current_action_allows_movement(actor_id: StringName) -> bool:
	var actor_state := simulation.get_actor_state(actor_id)
	if actor_state == null or actor_state.current_action_instance_id.is_empty():
		return false
	var action := simulation.get_action(actor_state.current_action_instance_id)
	if action == null:
		return false
	var definition := simulation.get_action_definition(action.action_definition_id)
	return definition != null and definition.allows_movement


func _run_hades_tactical_selection(actor_id: StringName, target_id: StringName) -> Dictionary:
	var actor_state := simulation.get_actor_state(actor_id)
	var actor_definition := simulation.get_actor_definition(actor_id)
	if actor_state == null or actor_definition == null:
		return {"action_started": false, "status": "missing_actor"}
	if not actor_state.pending_called_shot.is_empty():
		_record_hades_tactical_decision(actor_id, target_id, "normal_attack", [
			{"action": "called_shot", "reason": "called_shot_already_prepared"},
		])
		return {"action_started": false, "status": "called_shot_attack_due"}
	var hpc := int(actor_state.current_hpc)
	var hpm := int(actor_definition.get_combat_stat("hpm"))
	var rejected: Array[Dictionary] = []
	var mist_definition := HadesCombatFollowerFixture.make_rejuvenating_mist_action_definition()
	var mist_target := _select_hades_healing_target(actor_id)
	var mist_payment := simulation.get_ability_payment_preview(actor_id, mist_definition)
	if not String(mist_target).is_empty() and mist_payment.get("success", false):
		if mist_target != actor_id and not _resolve_special_touch(actor_id, mist_target):
			_hades_support_target_ids[String(actor_id)] = String(mist_target)
			_invalidate_goblin_path(actor_id)
			_record_hades_tactical_decision(actor_id, mist_target, "approach_rejuvenating_mist", rejected)
			return {"action_started": false, "suppress_attack": true, "status": "approaching_mist_ally"}
		var mist := simulation.start_verified_special_action(
			actor_id, mist_target, mist_definition,
			_next_request_id("%s_rejuvenating_mist" % String(actor_id)), &"",
			mist_target == actor_id or _resolve_special_touch(actor_id, mist_target)
		)
		if mist.get("success", false):
			_hades_support_target_ids.erase(String(actor_id))
			_record_hades_tactical_decision(actor_id, mist_target, "rejuvenating_mist", rejected)
			return {"action_started": true, "status": "casting_rejuvenating_mist"}
		rejected.append({"action": "rejuvenating_mist", "reason": String(mist.get("reason", "rejected"))})
	else:
		rejected.append({"action": "rejuvenating_mist", "reason": "no_injured_ally_or_ability_resource"})
	var buff_definition := HadesCombatFollowerFixture.make_defensive_buff_action_definition()
	var buff_target := _select_hades_buff_target(actor_id)
	var buff_payment := simulation.get_ability_payment_preview(actor_id, buff_definition)
	if not String(buff_target).is_empty() and buff_payment.get("success", false):
		if int(actor_state.held_materials.get("dirt", 0)) > 0:
			if buff_target != actor_id and not _resolve_special_touch(actor_id, buff_target):
				_hades_support_target_ids[String(actor_id)] = String(buff_target)
				_invalidate_goblin_path(actor_id)
				_record_hades_tactical_decision(actor_id, buff_target, "approach_defensive_buff", rejected)
				return {"action_started": false, "suppress_attack": true, "status": "approaching_buff_ally"}
			var buff := simulation.start_verified_special_action(
				actor_id, buff_target, buff_definition,
				_next_request_id("%s_defensive_buff" % String(actor_id)), &"",
				buff_target == actor_id or _resolve_special_touch(actor_id, buff_target)
			)
			if buff.get("success", false):
				_hades_support_target_ids.erase(String(actor_id))
				_record_hades_tactical_decision(actor_id, buff_target, "defensive_buff", rejected)
				return {"action_started": true, "status": "casting_defensive_buff"}
			rejected.append({"action": "defensive_buff", "reason": String(buff.get("reason", "rejected"))})
		else:
			var surface := _battlefield.get_gatherable_material_at(actor_state.position_microfeet, &"dirt")
			if surface.get("available", false):
				var gather := simulation.start_gather_material_action(
					actor_id, &"dirt", String(surface.get("surface_id", "")),
					_next_request_id("%s_gather_dirt" % String(actor_id))
				)
				if gather.get("success", false):
					_record_hades_tactical_decision(actor_id, target_id, "gather_dirt", rejected)
					return {"action_started": true, "status": "gathering_dirt"}
				rejected.append({"action": "gather_dirt", "reason": String(gather.get("reason", "rejected"))})
			else:
				rejected.append({"action": "defensive_buff", "reason": "dirt_unavailable"})
	else:
		rejected.append({"action": "defensive_buff", "reason": "no_eligible_ally_or_ability_resource"})
	var rage_definition := HadesCombatFollowerFixture.make_rage_action_definition()
	var rage_payment := simulation.get_ability_payment_preview(actor_id, rage_definition)
	if not actor_state.timed_stat_effects.has(String(HadesCombatFollowerFixture.RAGE_EFFECT_ID)) \
	and rage_payment.get("success", false):
		var rage := simulation.start_verified_timed_stat_effect_action(
			actor_id, rage_definition,
			_next_request_id("%s_rage" % String(actor_id))
		)
		if rage.get("success", false):
			_record_hades_tactical_decision(actor_id, target_id, "rage", rejected)
			return {"action_started": true, "status": "casting_rage"}
		rejected.append({"action": "rage", "reason": String(rage.get("reason", "rejected"))})
	else:
		rejected.append({"action": "rage", "reason": "active_or_ability_resource_unavailable"})
	var geometry := _get_actor_attack_geometry(actor_id, target_id)
	var called_definition := HadesCombatFollowerFixture.make_called_shot_action_definition()
	var called_payment := simulation.get_ability_payment_preview(actor_id, called_definition)
	if called_payment.get("success", false) and geometry.get("success", false):
		var called := simulation.start_verified_special_action(
			actor_id, target_id, called_definition,
			_next_request_id("%s_called_shot" % String(actor_id)), &"torso"
		)
		if called.get("success", false):
			_record_hades_tactical_decision(actor_id, target_id, "called_shot", rejected)
			return {"action_started": true, "status": "preparing_called_shot"}
		rejected.append({"action": "called_shot", "reason": String(called.get("reason", "rejected"))})
	else:
		rejected.append({"action": "called_shot", "reason": "no_current_attack_opportunity_or_ability_resource_unavailable"})
	_hades_support_target_ids.erase(String(actor_id))
	_record_hades_tactical_decision(actor_id, target_id, "normal_attack", rejected)
	return {"action_started": false, "status": "normal_attack"}


func _hades_eligible_ally_ids(actor_id: StringName) -> PackedStringArray:
	var allies := PackedStringArray()
	for candidate_id: String in _wave_enemy_actor_ids():
		var state := simulation.get_actor_state(StringName(candidate_id))
		if state == null or state.current_hpc == null or int(state.current_hpc) <= 0:
			continue
		allies.append(candidate_id)
	if not allies.has(String(actor_id)):
		allies.append(String(actor_id))
	allies.sort()
	return allies


func _select_hades_healing_target(actor_id: StringName) -> StringName:
	var ranked: Array[Dictionary] = []
	for candidate_id: String in _hades_eligible_ally_ids(actor_id):
		var state := simulation.get_actor_state(StringName(candidate_id))
		var definition := simulation.get_actor_definition(StringName(candidate_id))
		if state == null or definition == null:
			continue
		var missing := int(definition.get_combat_stat("hpm")) - int(state.current_hpc)
		if missing < 4:
			continue
		ranked.append({"actor_id": candidate_id, "missing": missing})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["missing"]) > int(right["missing"]) \
			if int(left["missing"]) != int(right["missing"]) \
			else String(left["actor_id"]) < String(right["actor_id"])
	)
	return &"" if ranked.is_empty() else StringName(ranked[0]["actor_id"])


func _select_hades_buff_target(actor_id: StringName) -> StringName:
	var ranked: Array[Dictionary] = []
	for candidate_id: String in _hades_eligible_ally_ids(actor_id):
		var state := simulation.get_actor_state(StringName(candidate_id))
		var definition := simulation.get_actor_definition(StringName(candidate_id))
		if state == null or definition == null \
		or state.timed_stat_effects.has(String(HadesCombatFollowerFixture.DEFENSIVE_BUFF_EFFECT_ID)):
			continue
		var hpm := int(definition.get_combat_stat("hpm"))
		if int(state.current_hpc) * 4 > hpm * 3:
			continue
		ranked.append({"actor_id": candidate_id, "hpc": int(state.current_hpc), "hpm": hpm})
	ranked.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left["hpc"]) * int(right["hpm"])
		var right_score := int(right["hpc"]) * int(left["hpm"])
		return left_score < right_score if left_score != right_score \
			else String(left["actor_id"]) < String(right["actor_id"])
	)
	return &"" if ranked.is_empty() else StringName(ranked[0]["actor_id"])


func _record_hades_tactical_decision(
	actor_id: StringName,
	target_id: StringName,
	selected_action: String,
	rejected_alternatives: Array[Dictionary]
) -> void:
	var actor_state := simulation.get_actor_state(actor_id)
	var signature := "%s|%s|%s|%s|%s|%s" % [
		selected_action,
		actor_state.current_hpc if actor_state != null else "?",
		actor_state.resources.get("ap", "?") if actor_state != null else "?",
		actor_state.ability_daily_remaining if actor_state != null else {},
		actor_state.timed_stat_effects.keys() if actor_state != null else [],
		actor_state.held_materials if actor_state != null else {},
	]
	if String(_hades_last_tactical_signature.get(String(actor_id), "")) == signature:
		return
	_hades_last_tactical_signature[String(actor_id)] = signature
	simulation.record_tactical_decision(actor_id, target_id, {
		"selected_action": selected_action,
		"rejected_alternatives": rejected_alternatives.duplicate(true),
		"hpc": actor_state.current_hpc if actor_state != null else null,
		"ap_remaining": actor_state.resources.get("ap", null) if actor_state != null else null,
		"ability_daily_remaining": actor_state.ability_daily_remaining.duplicate(true) if actor_state != null else {},
		"active_effects": actor_state.timed_stat_effects.keys() if actor_state != null else [],
		"held_materials": actor_state.held_materials.duplicate(true) if actor_state != null else {},
	})


func _initialize_wave_enemy_navigation_state() -> void:
	_goblin_paths.clear()
	_goblin_path_targets.clear()
	_goblin_path_target_actor_ids.clear()
	_goblin_path_reaches.clear()
	_goblin_attack_destinations.clear()
	_goblin_path_rebuild_counts.clear()
	_goblin_failed_path_cache.clear()
	_goblin_failed_path_cache_hits.clear()
	_goblin_static_collision_counts.clear()
	_goblin_movement_models.clear()
	_goblin_movement_round_indices.clear()
	_goblin_movement_spent.clear()
	_hades_last_tactical_signature.clear()
	_hades_support_target_ids.clear()
	_gargoyle_tactical_states.clear()
	_gargoyle_lane_offsets.clear()
	_gargoyle_failed_approach_counts.clear()
	_gargoyle_last_tactical_signatures.clear()
	_goblin_last_movement_us = simulation.clock.get_elapsed_us()
	for actor_id: String in _wave_enemy_actor_ids():
		_goblin_movement_models[actor_id] = _make_goblin_movement_model(StringName(actor_id), simulation.get_actor_state(StringName(actor_id)).position_microfeet)
		_goblin_movement_round_indices[actor_id] = simulation.clock.get_round_index()
		_goblin_movement_spent[actor_id] = 0
		_goblin_path_rebuild_counts[actor_id] = 0
		_goblin_failed_path_cache_hits[actor_id] = 0
		_goblin_static_collision_counts[actor_id] = 0
		if _is_wave_four_gargoyle_encounter:
			_gargoyle_tactical_states[actor_id] = GARGOYLE_STATE_STAGING
			_gargoyle_lane_offsets[actor_id] = 0
			_gargoyle_failed_approach_counts[actor_id] = 0


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
		_opponent_path_target_microfeet = null
		return {"success": false, "reason": "missing_actor_state"}
	var path_result := _battlefield.find_path_to_attack_position(
		Fixture.OPPONENT_ID,
		opponent_state.position_microfeet,
		player_state.position_microfeet,
		int(_attack_definition.maximum_range_microfeet),
		_actor_occupancy()
	)
	_opponent_path.clear()
	_opponent_path_target_microfeet = player_state.position_microfeet
	_opponent_path_rebuild_count += 1
	if path_result.get("success", false):
		for waypoint: Vector2i in path_result["waypoints"]:
			_opponent_path.append(waypoint)
	return path_result


func _ensure_current_opponent_path() -> Dictionary:
	var player_state := simulation.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		_opponent_path.clear()
		_opponent_path_target_microfeet = null
		return {"success": false, "reason": "missing_actor_state"}
	if _opponent_path.is_empty() or _opponent_path_target_microfeet == null:
		return _build_opponent_approach_path()
	var target_offset: Vector2i = player_state.position_microfeet - _opponent_path_target_microfeet
	if target_offset.length_squared() >= OPPONENT_REPATH_DISTANCE_MICROFEET * OPPONENT_REPATH_DISTANCE_MICROFEET:
		return _build_opponent_approach_path()
	return {"success": true, "reason": "stable_existing_path"}


func _advance_opponent_movement(delta_us: int) -> void:
	if delta_us <= 0 or not _encounter_active or not _opponent_behavior_enabled:
		return
	if _opponent_movement_model == null:
		return
	var attack := simulation.get_attack(_active_opponent_attack_id)
	if attack == null or attack.status != CombatAttackInstance.STATUS_EXECUTING:
		_stop_opponent_running_if_active()
		_opponent_movement_model.advance(delta_us, Vector2.ZERO)
		return
	var geometry := _get_actor_attack_geometry(Fixture.OPPONENT_ID, Fixture.PLAYER_ID)
	if geometry.get("success", false):
		_opponent_path.clear()
		_opponent_path_target_microfeet = null
		_stop_opponent_running_if_active()
		_opponent_movement_model.advance(delta_us, Vector2.ZERO)
		return
	var opponent_state := simulation.get_actor_state(Fixture.OPPONENT_ID)
	if opponent_state == null or opponent_state.conditions.has("prone") \
		or opponent_state.critical_stagger_until_us > simulation.clock.get_elapsed_us():
		_opponent_movement_model.set_prone(opponent_state != null and opponent_state.conditions.has("prone"))
		_opponent_movement_model.advance(delta_us, Vector2.ZERO)
		return
	_opponent_movement_model.set_prone(false)
	var path_result := _ensure_current_opponent_path()
	if not path_result.get("success", false) or _opponent_path.is_empty():
		_opponent_behavior_status = "approach_blocked_%s" % String(path_result.get("reason", "no_legal_path"))
		_stop_opponent_running_if_active()
		_opponent_movement_model.advance(delta_us, Vector2.ZERO)
		return
	if not _opponent_movement_model.is_running():
		_opponent_movement_model.request_running()
	var movement_rate := _opponent_movement_model.get_effective_mr()
	if movement_rate <= 0:
		_opponent_behavior_status = "approach_blocked_no_movement_rate"
		return
	_refresh_opponent_movement_ledger()
	var round_allowance := movement_rate * MICROFEET_PER_FOOT
	var remaining_round_movement := maxi(0, round_allowance - _opponent_movement_spent_microfeet)
	var destination: Vector2i = _opponent_path[0]
	var offset := destination - opponent_state.position_microfeet
	var requested_direction := Vector2(offset).normalized()
	_opponent_movement_model.position_feet = Vector2(opponent_state.position_microfeet) / float(MICROFEET_PER_FOOT)
	var displacement_feet := _opponent_movement_model.advance(delta_us, requested_direction)
	var movement_budget := mini(
		roundi(displacement_feet.length() * float(MICROFEET_PER_FOOT)),
		remaining_round_movement
	)
	if movement_budget <= 0:
		_opponent_behavior_status = "approach_waiting_for_mr"
		return
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
		_opponent_path_target_microfeet = null
		return
	opponent_state.movement_round_index = simulation.clock.get_round_index()
	opponent_state.remaining_mr_microfeet = remaining_round_movement
	var movement_result := simulation.apply_authoritative_position(
		Fixture.OPPONENT_ID,
		resolved["position_microfeet"],
		facing_millidegrees_for_displacement(
			resolved["position_microfeet"] - opponent_state.position_microfeet,
			opponent_state.facing_millidegrees
		),
		int(resolved["movement_cost_microfeet"])
	)
	if not movement_result.get("success", false):
		var reason := String(movement_result.get("reason", "movement_rejected"))
		_opponent_behavior_status = "approach_waiting_for_mr" if reason == "insufficient_remaining_mr" else "approach_blocked_%s" % reason
		return
	_opponent_movement_spent_microfeet += int(resolved["movement_cost_microfeet"])
	_opponent_movement_model.position_feet = Vector2(resolved["position_microfeet"]) / float(MICROFEET_PER_FOOT)
	if resolved["position_microfeet"] == _opponent_path[0]:
		_opponent_path.pop_front()
	_opponent_behavior_status = "attacking_while_approaching"


static func facing_millidegrees_for_displacement(displacement: Vector2i, fallback_facing: int) -> int:
	if displacement == Vector2i.ZERO:
		return posmod(fallback_facing, 360_000)
	var degrees := rad_to_deg(Vector2(displacement).angle())
	return posmod(roundi(degrees * 1000.0), 360_000)


func _make_opponent_movement_model(position_microfeet: Vector2i) -> PrimeMovementModel:
	var actor := Fixture.make_guard_actor(Fixture.OPPONENT_ID, "Opponent Guard Fixture")
	var model := PrimeMovementModel.new(
		int(actor.get_combat_stat("mr")),
		int(actor.attributes["spd"]),
		int(actor.attributes["end"]),
		Fixture.PLAYER_RUNNING_SKILL_INVESTMENT,
		Fixture.PLAYER_RUNNING_SCM,
		int(actor.get_combat_stat("rb"))
	)
	model.position_feet = Vector2(position_microfeet) / float(MICROFEET_PER_FOOT)
	return model


func _refresh_opponent_movement_ledger() -> void:
	var round_index := simulation.clock.get_round_index()
	if _opponent_movement_round_index == round_index:
		return
	_opponent_movement_round_index = round_index
	_opponent_movement_spent_microfeet = 0


func _stop_opponent_running_if_active() -> void:
	if _opponent_movement_model != null and _opponent_movement_model.is_running():
		_opponent_movement_model.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)


func _serialize_vector_path(path: Array[Vector2i]) -> Array:
	var serialized: Array = []
	for point: Vector2i in path:
		serialized.append([point.x, point.y])
	return serialized


func _next_request_id(kind: String) -> String:
	_next_request_sequence += 1
	return "task14_%s_%06d" % [kind, _next_request_sequence]


func _refresh_active_attacks() -> void:
	for actor_id: String in _active_attack_ids_by_actor.keys():
		if not _is_attack_in_flight(String(_active_attack_ids_by_actor[actor_id])):
			_active_attack_ids_by_actor.erase(actor_id)
	if not is_player_attack_in_flight():
		_active_player_attack_id = ""
	if not is_opponent_attack_in_flight():
		_active_opponent_attack_id = ""
