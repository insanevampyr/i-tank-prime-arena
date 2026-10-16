class_name CombatSimulation
extends RefCounted

const CriticalConsequenceCatalog = preload("res://scripts/combat/combat_critical_consequence_catalog.gd")
const MAX_SIGNED_INT_64 := 9_223_372_036_854_775_807

var clock: CombatClock
var event_queue: CombatEventQueue
var random: DeterministicCombatRng

var _next_sequence: int = 0
var _next_action_sequence: int = 0
var _next_attack_sequence: int = 0
var _next_defense_sequence: int = 0
var _next_damage_sequence: int = 0
var _next_critical_sequence: int = 0
var _state_revision: int = 0
var _actor_definitions: Dictionary = {}
var _actor_states: Dictionary = {}
var _action_definitions: Dictionary = {}
var _actions: Dictionary = {}
var _attack_definitions: Dictionary = {}
var _attacks: Dictionary = {}
var _attack_by_action_id: Dictionary = {}
var _defense_profiles: Dictionary = {}
var _defense_resolutions: Dictionary = {}
var _defense_by_attack_id: Dictionary = {}
var _damage_protection_profiles: Dictionary = {}
var _damage_resolutions: Dictionary = {}
var _damage_by_attack_id: Dictionary = {}
var _critical_records: Dictionary = {}
var _critical_record_by_roll_id: Dictionary = {}
var _critical_reaction_definitions: Dictionary = {}
var _deferred_critical_records_by_attack: Dictionary = {}
var _accepted_request_ids: Dictionary = {}
var _accepted_defense_request_ids: Dictionary = {}
var _accepted_damage_request_ids: Dictionary = {}
var _resolved_events: Array = []
var _combat_started: bool = false
var _opening_sequence_complete: bool = false
var _current_opening_rank: int = 0
var _opening_rank_count: int = 0
var _attack_final_line_of_sight_resolver: Callable


func _init(seed_value: int) -> void:
	clock = CombatClock.new()
	event_queue = CombatEventQueue.new()
	random = DeterministicCombatRng.new(seed_value)


func schedule_event(
	timestamp_us: int,
	event_type: StringName,
	initiative: int,
	source_actor_id: StringName = &"",
	target_actor_id: StringName = &"",
	payload: Dictionary = {},
	parent_event_id: String = "",
	dependency_event_ids: PackedStringArray = PackedStringArray(),
	resource_commitments: Dictionary = {}
) -> CombatEvent:
	assert(timestamp_us >= 0, "Combat event timestamps cannot be negative.")
	var event := _create_event(
		timestamp_us,
		event_type,
		initiative,
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		payload,
		resource_commitments
	)
	# Keep the mutation outside assert: release exports strip assertion expressions.
	var queued := event_queue.enqueue(event)
	assert(queued, "Internally generated combat event identifiers must be unique.")
	return event


func roll_int(min_inclusive: int, max_inclusive: int) -> int:
	return random.next_int(min_inclusive, max_inclusive)


func set_attack_final_line_of_sight_resolver(resolver: Callable) -> void:
	_attack_final_line_of_sight_resolver = resolver


func begin_combat() -> Dictionary:
	if _combat_started:
		return _failure("combat_already_started")
	if not _actions.is_empty():
		return _failure("actions_already_started")
	if _actor_definitions.is_empty():
		return _failure("no_combat_actors")
	var actor_keys: Array = _actor_definitions.keys()
	actor_keys.sort()
	for actor_key: String in actor_keys:
		var init_value: Variant = (_actor_definitions[actor_key] as CombatActorDefinition).get_combat_stat("init")
		if init_value == null:
			return _failure("unresolved_actor_init")

	for actor_key: String in actor_keys:
		var actor_definition: CombatActorDefinition = _actor_definitions[actor_key]
		var actor_state: CombatActorState = _actor_states[actor_key]
		actor_state.opening_initiative_roll = roll_int(1, 10)
		actor_state.opening_initiative_rng_draw_index = random.get_draw_count()
		actor_state.opening_initiative_total = int(actor_state.opening_initiative_roll) + int(actor_definition.get_combat_stat("init"))
		actor_state.revision += 1

	actor_keys.sort_custom(_opening_actor_precedes)
	var previous_total: Variant = null
	var previous_init: Variant = null
	var rank := -1
	for actor_key: String in actor_keys:
		var actor_definition: CombatActorDefinition = _actor_definitions[actor_key]
		var actor_state: CombatActorState = _actor_states[actor_key]
		var base_init := int(actor_definition.get_combat_stat("init"))
		if previous_total == null or actor_state.opening_initiative_total != previous_total or base_init != previous_init:
			rank += 1
		actor_state.opening_order_rank = rank
		previous_total = actor_state.opening_initiative_total
		previous_init = base_init
	_opening_rank_count = rank + 1
	_current_opening_rank = 0
	_opening_sequence_complete = false
	_combat_started = true
	_state_revision += 1

	var opening_order: Array = []
	for actor_key: String in actor_keys:
		var actor_definition: CombatActorDefinition = _actor_definitions[actor_key]
		var actor_state: CombatActorState = _actor_states[actor_key]
		var entry := {
			"actor_id": actor_key,
			"natural_d10": actor_state.opening_initiative_roll,
			"rng_draw_index": actor_state.opening_initiative_rng_draw_index,
			"base_init": int(actor_definition.get_combat_stat("init")),
			"total": actor_state.opening_initiative_total,
			"opening_order_rank": actor_state.opening_order_rank,
		}
		opening_order.append(entry)
		_record_resolved_event(
			clock.get_elapsed_us(),
			&"opening_initiative_rolled",
			int(actor_definition.get_combat_stat("init")),
			actor_definition.actor_id,
			&"",
			entry
		)
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"opening_initiative_resolved",
		0,
		&"",
		&"",
		{"opening_order": opening_order}
	)
	return _success({"opening_order": opening_order})


func register_actor(definition: CombatActorDefinition) -> Dictionary:
	if definition == null:
		return _failure("invalid_actor_definition")
	if _combat_started:
		return _failure("combat_already_started")
	var actor_key := String(definition.actor_id)
	if _actor_definitions.has(actor_key):
		return _failure("duplicate_actor_id")
	_actor_definitions[actor_key] = definition
	_actor_states[actor_key] = CombatActorState.new(definition)
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"actor_registered",
		_get_actor_initiative(actor_key),
		definition.actor_id,
		&"",
		{"actor_id": actor_key, "actor_kind": String(definition.actor_kind)}
	)
	return _success({"actor_id": actor_key})


func register_defense_profile(actor_id: StringName, profile: CombatDefenseProfile) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if profile == null:
		return _failure("invalid_defense_profile")
	if _combat_started:
		return _failure("combat_already_started")
	if _defense_profiles.has(actor_key):
		var existing: CombatDefenseProfile = _defense_profiles[actor_key]
		if existing.to_dictionary() != profile.to_dictionary():
			return _failure("conflicting_defense_profile")
		return _success({"actor_id": actor_key, "profile_id": String(profile.profile_id)})
	_defense_profiles[actor_key] = profile
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"defense_profile_registered",
		_get_actor_initiative(actor_key),
		actor_id,
		&"",
		{"actor_id": actor_key, "profile_id": String(profile.profile_id)}
	)
	return _success({"actor_id": actor_key, "profile_id": String(profile.profile_id)})


func register_damage_protection_profile(actor_id: StringName, profile: CombatDamageProtectionProfile) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if profile == null:
		return _failure("invalid_damage_protection_profile")
	if _combat_started:
		return _failure("combat_already_started")
	if _damage_protection_profiles.has(actor_key):
		var existing: CombatDamageProtectionProfile = _damage_protection_profiles[actor_key]
		if existing.to_dictionary() != profile.to_dictionary():
			return _failure("conflicting_damage_protection_profile")
		return _success({"actor_id": actor_key, "profile_id": String(profile.profile_id)})
	_damage_protection_profiles[actor_key] = profile
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"damage_protection_profile_registered",
		_get_actor_initiative(actor_key),
		actor_id,
		&"",
		{"actor_id": actor_key, "profile_id": String(profile.profile_id)}
	)
	return _success({"actor_id": actor_key, "profile_id": String(profile.profile_id)})


func register_critical_reaction_attack(actor_id: StringName, definition: CombatAttackDefinition, authoritative_line_of_sight: bool) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if definition == null:
		return _failure("invalid_attack_definition")
	if _combat_started:
		return _failure("combat_already_started")
	if not (_actor_states[actor_key] as CombatActorState).equipment_refs.has(String(definition.weapon_ref)):
		return _failure("weapon_not_equipped")
	var definition_key := String(definition.attack_definition_id)
	if _attack_definitions.has(definition_key) and (_attack_definitions[definition_key] as CombatAttackDefinition).to_dictionary() != definition.to_dictionary():
		return _failure("conflicting_attack_definition")
	_attack_definitions[definition_key] = definition
	_critical_reaction_definitions[actor_key] = {
		"attack_definition_id": definition_key,
		"authoritative_line_of_sight": authoritative_line_of_sight,
	}
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"critical_reaction_attack_registered", _get_actor_initiative(actor_key), actor_id, &"", {
		"attack_definition_id": definition_key,
		"authoritative_line_of_sight": authoritative_line_of_sight,
	})
	return _success({"actor_id": actor_key, "attack_definition_id": definition_key})


func set_actor_defense_state(actor_id: StringName, awareness: StringName, conditions: PackedStringArray) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if awareness != &"aware" and awareness != &"unaware":
		return _failure("invalid_awareness_state")
	var ordered_conditions := conditions.duplicate()
	ordered_conditions.sort()
	var actor_state: CombatActorState = _actor_states[actor_key]
	actor_state.awareness = awareness
	actor_state.conditions = ordered_conditions
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"actor_defense_state_changed",
		_get_actor_initiative(actor_key),
		actor_id,
		&"",
		{"awareness": String(awareness), "conditions": Array(ordered_conditions)}
	)
	return _success()


func start_action(
	actor_id: StringName,
	definition: CombatActionDefinition,
	request_id: String,
	dependency_action_ids: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var actor_key := String(actor_id)
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_request_ids.has(request_id):
		return _failure("duplicate_request")
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if definition == null:
		return _failure("invalid_action_definition")
	var actor_definition: CombatActorDefinition = _actor_definitions[actor_key]
	var at_value: Variant = actor_definition.get_combat_stat("at")
	if at_value == null or int(at_value) <= 0:
		return _failure("unresolved_actor_at")
	var actor_state: CombatActorState = _actor_states[actor_key]
	_refresh_actor_timed_conditions(actor_state)
	if _is_actor_critically_staggered(actor_state):
		return _failure("actor_critically_staggered")
	if actor_state.conditions.has("prone") and not bool(definition.extension_metadata.get("stands_from_prone", false)):
		return _failure("actor_prone")
	if not actor_state.current_action_instance_id.is_empty():
		return _failure("actor_action_in_progress")
	if not _can_begin_opening_action(actor_state):
		return _failure("opening_initiative_wait")
	for dependency_id: String in dependency_action_ids:
		if not _actions.has(dependency_id):
			return _failure("unknown_dependency")

	var definition_key := String(definition.action_definition_id)
	if _action_definitions.has(definition_key):
		var existing_definition: CombatActionDefinition = _action_definitions[definition_key]
		if existing_definition.to_dictionary() != definition.to_dictionary():
			return _failure("conflicting_action_definition")
	else:
		_action_definitions[definition_key] = definition

	var action_instance_id := _make_action_instance_id(_next_action_sequence)
	_next_action_sequence += 1
	var timestamp_us := clock.get_elapsed_us()
	if actor_state.action_timing_cursor_us != timestamp_us:
		actor_state.action_timing_anchor_us = timestamp_us
		actor_state.action_timing_cursor_us = timestamp_us
		actor_state.next_action_interval_index = 0
	var starting_interval_index := actor_state.next_action_interval_index
	var final_effect_due_at_us := _get_action_interval_timestamp(
		actor_state.action_timing_anchor_us,
		starting_interval_index + definition.required_acts,
		int(at_value)
	)
	var action := CombatActionInstance.new(
		action_instance_id,
		definition,
		actor_id,
		_get_actor_initiative(actor_key),
		timestamp_us,
		int(at_value),
		actor_state.action_timing_anchor_us,
		starting_interval_index,
		final_effect_due_at_us,
		dependency_action_ids,
		request_id
	)
	actor_state.current_action_instance_id = action_instance_id
	actor_state.revision += 1
	_actions[action_instance_id] = action
	_accepted_request_ids[request_id] = action_instance_id
	_state_revision += 1

	var declaration := _record_resolved_event(
		clock.get_elapsed_us(),
		&"action_declared",
		action.initiative,
		actor_id,
		&"",
		{
			"action_instance_id": action_instance_id,
			"action_definition_id": definition_key,
			"request_id": request_id,
			"dependency_action_ids": Array(dependency_action_ids),
		}
	)
	action.declaration_event_id = declaration.event_id
	var started := _record_resolved_event(
		clock.get_elapsed_us(),
		&"action_started",
		action.initiative,
		actor_id,
		&"",
		{
			"action_instance_id": action_instance_id,
			"completed_acts": action.completed_acts,
			"required_acts": action.required_acts,
			"at_at_start": action.at_at_start,
			"first_interval_due_at_us": _get_action_interval_timestamp(
				action.timing_anchor_us,
				action.starting_interval_index + 1,
				action.at_at_start
			),
			"final_effect_due_at_us": action.final_effect_due_at_us,
		},
		declaration.event_id,
		PackedStringArray(),
		definition.resource_commitments
	)
	action.start_event_id = started.event_id

	_schedule_action_internal_event(
		action,
		_get_action_interval_timestamp(
			action.timing_anchor_us,
			action.starting_interval_index + 1,
			action.at_at_start
		),
		&"action_act_due"
	)
	_mark_opening_action_declared(actor_state, action_instance_id)
	return _success({"action_instance_id": action_instance_id})


func start_stand_action(actor_id: StringName, request_id: String) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if not actor_state.conditions.has("prone"):
		return _failure("actor_not_prone")
	var definition := CombatActionDefinition.new(
		&"stand_from_prone",
		1,
		false,
		true,
		{},
		{"stands_from_prone": true},
		PackedStringArray(["ARENA-COMBAT-1.7 section 18: standing costs one Act"])
	)
	return start_action(actor_id, definition, request_id)


func start_physical_attack(
	attacker_id: StringName,
	target_id: StringName,
	definition: CombatAttackDefinition,
	request_id: String,
	target_location: StringName = &"torso",
	authoritative_line_of_sight: Variant = null,
	dependency_action_ids: PackedStringArray = PackedStringArray(),
	is_back_attack: bool = false
) -> Dictionary:
	if not _combat_started:
		return _failure("opening_initiative_unresolved")
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_request_ids.has(request_id):
		return _failure("duplicate_request")
	if definition == null:
		return _failure("invalid_attack_definition")
	var attacker_key := String(attacker_id)
	var target_key := String(target_id)
	if not _actor_states.has(attacker_key):
		return _failure("unknown_attacker")
	if not _actor_states.has(target_key):
		return _failure("unknown_target")
	if attacker_key == target_key:
		return _failure("self_target_not_allowed")
	var attacker_state: CombatActorState = _actor_states[attacker_key]
	var target_state: CombatActorState = _actor_states[target_key]
	if attacker_state.current_hpc == null or int(attacker_state.current_hpc) <= 0:
		return _failure("attacker_not_eligible")
	if target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return _failure("target_not_eligible")
	if not attacker_state.equipment_refs.has(String(definition.weapon_ref)):
		return _failure("weapon_not_equipped")
	var attacker_definition: CombatActorDefinition = _actor_definitions[attacker_key]
	var base_acc_value: Variant = attacker_definition.get_combat_stat("acc")
	if base_acc_value == null:
		return _failure("unresolved_actor_acc")
	var roll_bonus_value: Variant = attacker_definition.get_combat_stat("rb")
	var roll_bonus := 0 if roll_bonus_value == null else int(roll_bonus_value)
	if roll_bonus < 0:
		return _failure("invalid_actor_roll_bonus")
	var resolved_location := &"torso" if String(target_location).is_empty() else target_location
	if not definition.allowed_target_locations.has(String(resolved_location)):
		return _failure("illegal_target_location")
	var location_modifier: Variant = definition.get_location_acc_modifier(resolved_location)
	if location_modifier == null:
		return _failure("unresolved_location_acc_modifier")
	if not definition.has_resolved_range():
		return _failure("unresolved_attack_range")
	# Approved Arena approach-attack timing: an ordinary physical attack may be
	# declared before the attacker reaches weapon range or clears an obstruction.
	# Range and line of sight remain authoritative requirements, but they are
	# evaluated at the final effect point before the ACC die is rolled.
	if not definition.allows_approach_during_execution:
		if definition.requires_line_of_sight and authoritative_line_of_sight != true:
			return _failure("line_of_sight_unverified")
		var declaration_offset := target_state.position_microfeet - attacker_state.position_microfeet
		var declaration_distance_squared := declaration_offset.x * declaration_offset.x + declaration_offset.y * declaration_offset.y
		var minimum_range := 0 if definition.minimum_range_microfeet == null else int(definition.minimum_range_microfeet)
		var maximum_range := int(definition.maximum_range_microfeet)
		if declaration_distance_squared < minimum_range * minimum_range or declaration_distance_squared > maximum_range * maximum_range:
			return _failure("target_out_of_range")

	var definition_key := String(definition.attack_definition_id)
	if _attack_definitions.has(definition_key):
		if (_attack_definitions[definition_key] as CombatAttackDefinition).to_dictionary() != definition.to_dictionary():
			return _failure("conflicting_attack_definition")
	var action_result := start_action(attacker_id, definition.to_action_definition(), request_id, dependency_action_ids)
	if not action_result["success"]:
		return action_result
	if not _attack_definitions.has(definition_key):
		_attack_definitions[definition_key] = definition
	var action_instance_id: String = action_result["action_instance_id"]
	var attack_instance_id := _make_attack_instance_id(_next_attack_sequence)
	_next_attack_sequence += 1
	var attack := CombatAttackInstance.new(
		attack_instance_id,
		definition,
		action_instance_id,
		attacker_id,
		target_id,
		resolved_location,
		clock.get_elapsed_us(),
		int(base_acc_value),
		int(location_modifier),
		roll_bonus,
		is_back_attack
	)
	attack.declared_attacker_position_microfeet = attacker_state.position_microfeet
	attack.declared_target_position_microfeet = target_state.position_microfeet
	attack.declaration_line_of_sight_verified = authoritative_line_of_sight
	var declared_offset := target_state.position_microfeet - attacker_state.position_microfeet
	var distance_squared := declared_offset.x * declared_offset.x + declared_offset.y * declared_offset.y
	_attacks[attack_instance_id] = attack
	_attack_by_action_id[action_instance_id] = attack_instance_id
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_attack_declared",
		_get_actor_initiative(attacker_key),
		attacker_id,
		target_id,
		{
			"attack_instance_id": attack_instance_id,
			"action_instance_id": action_instance_id,
			"attack_definition_id": definition_key,
			"weapon_ref": String(definition.weapon_ref),
			"target_location": String(resolved_location),
			"acc_target": attack.acc_target,
			"distance_squared_microfeet": distance_squared,
			"request_id": request_id,
			"delivery_class": String(definition.delivery_class),
			"damage_types": Array(definition.damage_types),
			"physical_soak_eligible": definition.physical_soak_eligible,
			"is_back_attack": is_back_attack,
		}
	)
	return _success({"attack_instance_id": attack_instance_id, "action_instance_id": action_instance_id})


func resolve_pending_defense(
	attack_instance_id: String,
	request_id: String,
	dodge_context: CombatDodgeContext = null
) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_defense_request_ids.has(request_id):
		return _failure("duplicate_defense_request")
	if not _attacks.has(attack_instance_id):
		return _failure("unknown_attack")
	var attack: CombatAttackInstance = _attacks[attack_instance_id]
	if attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
		return _failure("attack_not_pending_defense")
	var defender_key := String(attack.target_id)
	if not _defense_profiles.has(defender_key):
		return _failure("defense_profile_unresolved")
	var profile: CombatDefenseProfile = _defense_profiles[defender_key]
	var defender_state: CombatActorState = _actor_states[defender_key]
	var defender_definition: CombatActorDefinition = _actor_definitions[defender_key]
	if _get_actor_roll_bonus(defender_definition) < 0:
		return _failure("invalid_actor_roll_bonus")
	_refresh_actor_movement_budgets()
	if _dodge_needs_context(attack, defender_state, defender_definition, profile) and dodge_context == null:
		return _failure("dodge_context_unresolved")

	var defense_resolution_id := _make_defense_resolution_id(_next_defense_sequence)
	_next_defense_sequence += 1
	var resolution := CombatDefenseResolution.new(
		defense_resolution_id,
		attack_instance_id,
		attack.target_id,
		profile,
		clock.get_elapsed_us(),
		request_id
	)
	_defense_resolutions[defense_resolution_id] = resolution
	_defense_by_attack_id[attack_instance_id] = defense_resolution_id
	_accepted_defense_request_ids[request_id] = defense_resolution_id
	attack.defense_resolution_id = defense_resolution_id
	attack.revision += 1
	_state_revision += 1
	var started := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_defense_started",
		_get_actor_initiative(defender_key),
		attack.target_id,
		attack.attacker_id,
		{
			"defense_resolution_id": defense_resolution_id,
			"attack_instance_id": attack_instance_id,
			"profile_id": String(profile.profile_id),
			"priority": Array(profile.priority),
			"request_id": request_id,
		},
		attack.result_event_id
	)
	resolution.start_event_id = started.event_id
	var previous_event_id := started.event_id
	var dodge_or_soak_attempted := false
	var resolution_locked := false
	var generic_critical_policy := CombatCriticalTriggerPolicy.new()

	for defense_key: String in profile.priority:
		var defense_type := StringName(defense_key)
		var attempt := CombatDefenseAttempt.new(defense_type)
		attempt.parent_event_id = previous_event_id
		if defense_type == CombatDefenseProfile.DODGE and dodge_context != null:
			attempt.resolution_context = dodge_context.to_dictionary()
		if resolution_locked:
			attempt.eligibility = CombatDefenseAttempt.ELIGIBLE_NOT_SELECTED
			attempt.eligibility_reason = "prior_defense_succeeded"
			var not_selected_event := _record_defense_attempt_event(attack, resolution, attempt, &"physical_defense_not_selected")
			attempt.result_event_id = not_selected_event.event_id
			previous_event_id = not_selected_event.event_id
			resolution.attempts.append(attempt)
			continue

		var eligibility := _evaluate_defense_eligibility(
			attack,
			defender_state,
			defender_definition,
			profile,
			defense_type,
			dodge_context,
			dodge_or_soak_attempted
		)
		attempt.equipment_ref = eligibility.get("equipment_ref", &"")
		attempt.base_target = eligibility.get("base_target", null)
		attempt.target_modifier = int(eligibility.get("target_modifier", 0))
		attempt.final_target = null if attempt.base_target == null else int(attempt.base_target) + attempt.target_modifier
		if not eligibility.get("eligible", false):
			attempt.eligibility = CombatDefenseAttempt.INELIGIBLE
			attempt.eligibility_reason = String(eligibility.get("reason", "ineligible"))
			var skipped_event := _record_defense_attempt_event(attack, resolution, attempt, &"physical_defense_ineligible")
			attempt.result_event_id = skipped_event.event_id
			previous_event_id = skipped_event.event_id
			resolution.attempts.append(attempt)
			continue

		attempt.eligibility = CombatDefenseAttempt.ATTEMPTED
		attempt.roll_id = "defense:%s:%d:%s" % [defense_resolution_id, resolution.attempts.size(), String(defense_type)]
		attempt.roll_bonus = _get_actor_roll_bonus(defender_definition)
		attempt.natural_roll = roll_int(1, 20)
		attempt.rng_draw_index = random.get_draw_count()
		attempt.adjusted_roll = int(attempt.natural_roll) - attempt.roll_bonus
		var critical_result := generic_critical_policy.classify(int(attempt.natural_roll))
		attempt.critical_success = critical_result == CombatCriticalTriggerPolicy.RESULT_SUCCESS
		attempt.critical_failure = critical_result == CombatCriticalTriggerPolicy.RESULT_FAILURE
		if attempt.critical_success:
			attempt.success = true
		elif attempt.critical_failure:
			attempt.success = false
		else:
			attempt.success = int(attempt.adjusted_roll) <= int(attempt.final_target)
		if defense_type == CombatDefenseProfile.DODGE or defense_type == CombatDefenseProfile.PHYSICAL_SOAK:
			dodge_or_soak_attempted = true
		if attempt.success and defense_type == CombatDefenseProfile.DODGE:
			if dodge_context.selection_status == CombatDodgeContext.SELECTION_AMBIGUOUS:
				resolution.status = CombatDefenseResolution.STATUS_PENDING_DODGE_DISPLACEMENT
				resolution.successful_defense_type = defense_type
				resolution.pending_dodge_context = dodge_context.to_dictionary()
				attack.status = CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT
			else:
				_apply_successful_dodge(defender_state, dodge_context, attempt)
				resolution.status = CombatDefenseResolution.STATUS_DEFENDED
				resolution.successful_defense_type = defense_type
				attack.status = CombatAttackInstance.STATUS_DEFENDED
			resolution_locked = true
		elif attempt.success:
			if defense_type == CombatDefenseProfile.SHIELD_BLOCK:
				_apply_successful_shield_block(defender_state, profile.shield_block, attempt)
			resolution.status = CombatDefenseResolution.STATUS_DEFENDED
			resolution.successful_defense_type = defense_type
			attack.status = CombatAttackInstance.STATUS_DEFENDED
			resolution_locked = true
		var attempt_event := _record_defense_attempt_event(attack, resolution, attempt, &"physical_defense_attempted")
		attempt.result_event_id = attempt_event.event_id
		previous_event_id = attempt_event.event_id
		if critical_result != CombatCriticalTriggerPolicy.RESULT_NONE:
			var critical_record := _record_critical_trigger(
				attempt.roll_id,
				defense_type,
				critical_result,
				int(attempt.natural_roll),
				generic_critical_policy,
				attack.target_id,
				attack.attacker_id,
				attempt_event.event_id,
				PackedStringArray(),
				attempt.resources_spent
			)
			attempt.critical_record_id = critical_record.critical_record_id
			attempt.result_event_id = critical_record.event_id
			previous_event_id = critical_record.event_id
			_apply_critical_consequence(critical_record, attack, attempt, profile)
		resolution.attempts.append(attempt)

	if resolution.status == CombatDefenseResolution.STATUS_RESOLVING:
		resolution.status = CombatDefenseResolution.STATUS_EXHAUSTED
		attack.status = CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED
	resolution.resolved_at_us = clock.get_elapsed_us()
	resolution.revision += 1
	attack.revision += 1
	_state_revision += 1
	var resolved := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_defense_resolved",
		_get_actor_initiative(defender_key),
		attack.target_id,
		attack.attacker_id,
		{
			"defense_resolution_id": defense_resolution_id,
			"attack_instance_id": attack_instance_id,
			"status": resolution.status,
			"successful_defense_type": String(resolution.successful_defense_type),
			"damage_applied": false,
		},
		previous_event_id
	)
	resolution.final_event_id = resolved.event_id
	if resolution.status == CombatDefenseResolution.STATUS_DEFENDED:
		_finalize_deferred_critical_consequences(attack)
	return _success({"defense_resolution_id": defense_resolution_id, "status": resolution.status})


func resolve_pending_defense_automatically(
	attack_instance_id: String,
	request_id: String,
	dodge_environment: CombatDodgeEnvironment = null
) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_defense_request_ids.has(request_id):
		return _failure("duplicate_defense_request")
	if not _attacks.has(attack_instance_id):
		return _failure("unknown_attack")
	var attack: CombatAttackInstance = _attacks[attack_instance_id]
	if attack.status != CombatAttackInstance.STATUS_PENDING_DEFENSE:
		return _failure("attack_not_pending_defense")
	var defender_key := String(attack.target_id)
	if not _defense_profiles.has(defender_key):
		return _failure("defense_profile_unresolved")
	var defender_state: CombatActorState = _actor_states[defender_key]
	var defender_definition: CombatActorDefinition = _actor_definitions[defender_key]
	var profile: CombatDefenseProfile = _defense_profiles[defender_key]
	_refresh_actor_movement_budgets()
	var dodge_context: CombatDodgeContext = null
	if _dodge_needs_context(attack, defender_state, defender_definition, profile):
		var selection := _select_automatic_dodge_context(attack, defender_state, dodge_environment)
		if not selection["success"]:
			return selection
		dodge_context = selection["dodge_context"]
	return resolve_pending_defense(attack_instance_id, request_id, dodge_context)


func complete_pending_dodge_displacement(
	attack_instance_id: String,
	request_id: String,
	dodge_context: CombatDodgeContext
) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_defense_request_ids.has(request_id):
		return _failure("duplicate_defense_request")
	if not _attacks.has(attack_instance_id):
		return _failure("unknown_attack")
	var attack: CombatAttackInstance = _attacks[attack_instance_id]
	if attack.status != CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT:
		return _failure("dodge_displacement_not_pending")
	if dodge_context == null or dodge_context.selection_status != CombatDodgeContext.SELECTION_RESOLVED:
		return _failure("dodge_destination_unresolved")
	var resolution: CombatDefenseResolution = _defense_resolutions[attack.defense_resolution_id]
	if clock.get_elapsed_us() != int(resolution.resolved_at_us):
		return _failure("dodge_displacement_time_advanced")
	var defender_state: CombatActorState = _actor_states[String(attack.target_id)]
	var validation := _validate_resolved_dodge_context(attack, defender_state, dodge_context)
	if not validation["valid"]:
		return _failure(String(validation["reason"]))
	var successful_attempt: CombatDefenseAttempt = null
	for attempt: CombatDefenseAttempt in resolution.attempts:
		if attempt.defense_type == CombatDefenseProfile.DODGE and attempt.success == true:
			successful_attempt = attempt
			break
	assert(successful_attempt != null, "Pending Dodge displacement requires a successful Dodge attempt.")
	successful_attempt.resolution_context = dodge_context.to_dictionary()
	_apply_successful_dodge(defender_state, dodge_context, successful_attempt)
	_complete_pending_dodge_critical_effect(successful_attempt)
	resolution.status = CombatDefenseResolution.STATUS_DEFENDED
	resolution.pending_dodge_context = {}
	resolution.resolved_at_us = clock.get_elapsed_us()
	resolution.revision += 1
	attack.status = CombatAttackInstance.STATUS_DEFENDED
	attack.revision += 1
	_accepted_defense_request_ids[request_id] = resolution.defense_resolution_id
	_state_revision += 1
	var event := _record_resolved_event(
		clock.get_elapsed_us(),
		&"dodge_displacement_resolved",
		_get_actor_initiative(String(attack.target_id)),
		attack.target_id,
		attack.attacker_id,
		{
			"defense_resolution_id": resolution.defense_resolution_id,
			"attack_instance_id": attack_instance_id,
			"destination_microfeet": [dodge_context.destination_microfeet.x, dodge_context.destination_microfeet.y],
			"movement_cost_microfeet": dodge_context.movement_cost_microfeet,
			"in_place_duck": dodge_context.in_place_duck,
			"dodge_context": dodge_context.to_dictionary(),
			"damage_applied": false,
		},
		resolution.final_event_id,
		PackedStringArray(),
		successful_attempt.resources_spent
	)
	resolution.final_event_id = event.event_id
	_finalize_deferred_critical_consequences(attack)
	return _success({"defense_resolution_id": resolution.defense_resolution_id, "status": resolution.status})


func resolve_physical_damage(attack_instance_id: String, request_id: String) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_damage_request_ids.has(request_id):
		return _failure("duplicate_damage_request")
	if not _attacks.has(attack_instance_id):
		return _failure("unknown_attack")
	var attack: CombatAttackInstance = _attacks[attack_instance_id]
	if attack.status != CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED:
		return _failure("attack_not_damage_eligible")
	var preparation := _prepare_physical_damage(attack)
	if not preparation["success"]:
		return preparation

	var definition: CombatPhysicalDamageDefinition = preparation["damage_definition"]
	var target_state: CombatActorState = _actor_states[String(attack.target_id)]
	var resolution_id := _make_damage_resolution_id(_next_damage_sequence)
	_next_damage_sequence += 1
	var resolution := CombatDamageResolution.new(
		resolution_id,
		attack_instance_id,
		attack.attacker_id,
		attack.target_id,
		request_id,
		clock.get_elapsed_us()
	)
	resolution.flat_bonus = definition.flat_bonus
	resolution.strength_bonus = preparation["strength_bonus"]
	for _die_index in range(definition.dice_count):
		var die_result := roll_int(1, definition.die_sides)
		resolution.weapon_rolls.append(die_result)
		resolution.rng_draw_indices.append(random.get_draw_count())
		resolution.weapon_dice_total += die_result
	resolution.pre_multiplier_total = resolution.weapon_dice_total + resolution.flat_bonus + resolution.strength_bonus

	var running_total: int
	var type_response: Dictionary = preparation["type_response"]
	resolution.type_response = type_response.duplicate(true)
	for multiplier_entry: Dictionary in preparation["pre_protection_multipliers"]:
		resolution.applied_multipliers.append(_recorded_multiplier(multiplier_entry["kind"], multiplier_entry["multiplier"]))
	resolution.combined_multiplier_numerator = int(preparation["pre_multiplier_product"]["numerator"])
	resolution.combined_multiplier_denominator = int(preparation["pre_multiplier_product"]["denominator"])
	running_total = _apply_multiplier_product_once(
		resolution.pre_multiplier_total,
		resolution.combined_multiplier_numerator,
		resolution.combined_multiplier_denominator
	)
	resolution.multiplied_total = running_total
	resolution.armor_equipment_ref = preparation["armor_equipment_ref"]
	resolution.armor_slot = preparation["armor_slot"]
	resolution.armor_tal = preparation["armor_tal"]
	resolution.natural_armor_level = preparation["nal"]
	running_total -= resolution.armor_tal
	running_total -= resolution.natural_armor_level

	if String(type_response.get("kind", "")) == CombatDamageProtectionProfile.RESPONSE_MULTIPLIER \
	and String(type_response.get("stage", "")) == CombatDamageProtectionProfile.STAGE_POST_PROTECTION:
		var post_product: Dictionary = preparation["post_multiplier_product"]
		running_total = _apply_multiplier_product_once(running_total, int(post_product["numerator"]), int(post_product["denominator"]))
		resolution.applied_multipliers.append(_recorded_multiplier("type_response_post_protection", type_response))

	if String(type_response.get("kind", "")) == CombatDamageProtectionProfile.RESPONSE_IMMUNE:
		resolution.final_damage = 0
	elif running_total <= 0 and definition.minimum_one_applies == true:
		resolution.minimum_one_applied = true
		resolution.final_damage = 1
	else:
		resolution.final_damage = maxi(running_total, 0)
	resolution.hpc_before = int(target_state.current_hpc)
	resolution.hpc_after = resolution.hpc_before - resolution.final_damage
	target_state.current_hpc = resolution.hpc_after
	target_state.revision += 1
	attack.status = CombatAttackInstance.STATUS_DAMAGE_RESOLVED
	attack.damage_resolution_id = resolution_id
	attack.revision += 1
	_damage_resolutions[resolution_id] = resolution
	_damage_by_attack_id[attack_instance_id] = resolution_id
	_accepted_damage_request_ids[request_id] = resolution_id
	_state_revision += 1
	var defense_resolution: CombatDefenseResolution = _defense_resolutions[attack.defense_resolution_id]
	var event := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_damage_resolved",
		_get_actor_initiative(String(attack.attacker_id)),
		attack.attacker_id,
		attack.target_id,
		{
			"damage_resolution_id": resolution_id,
			"attack_instance_id": attack_instance_id,
			"weapon_rolls": resolution.weapon_rolls.duplicate(),
			"strength_bonus": resolution.strength_bonus,
			"combined_multiplier_numerator": resolution.combined_multiplier_numerator,
			"combined_multiplier_denominator": resolution.combined_multiplier_denominator,
			"multiplied_total": resolution.multiplied_total,
			"armor_tal": resolution.armor_tal,
			"natural_armor_level": resolution.natural_armor_level,
			"final_damage": resolution.final_damage,
			"hpc_before": resolution.hpc_before,
			"hpc_after": resolution.hpc_after,
			"damage_applied": resolution.final_damage > 0,
		},
		defense_resolution.final_event_id,
		PackedStringArray(),
		{"hpc": resolution.final_damage}
	)
	resolution.event_id = event.event_id
	_finalize_deferred_critical_consequences(attack)
	return _success({"damage_resolution_id": resolution_id, "final_damage": resolution.final_damage})


func schedule_interruption(
	action_instance_id: String,
	timestamp_us: int,
	source_actor_id: StringName,
	reason: String,
	parent_event_id: String = ""
) -> Dictionary:
	if not _actions.has(action_instance_id):
		return _failure("unknown_action")
	if timestamp_us < clock.get_elapsed_us():
		return _failure("timestamp_in_past")
	if reason.is_empty():
		return _failure("missing_interruption_reason")
	var source_key := String(source_actor_id)
	if not source_key.is_empty() and not _actor_states.has(source_key):
		return _failure("unknown_source_actor")
	var event := schedule_event(
		timestamp_us,
		&"action_interrupt_due",
		_get_actor_initiative(source_key),
		source_actor_id,
		StringName((_actions[action_instance_id] as CombatActionInstance).actor_id),
		{"action_instance_id": action_instance_id, "reason": reason},
		parent_event_id
	)
	return _success({"event_id": event.event_id})


func advance_to(timestamp_us: int) -> Array:
	assert(timestamp_us >= clock.get_elapsed_us(), "Authoritative combat time cannot move backward.")
	while not event_queue.is_empty():
		var next_event := event_queue.peek_next()
		if next_event.timestamp_us > timestamp_us:
			break
		_advance_clock_to(next_event.timestamp_us)
		var event := event_queue.pop_next()
		_resolve_due_event(event)
		_release_waiting_dependents()
	_advance_clock_to(timestamp_us)
	return get_resolved_events()


func resolve_all_pending_events() -> Array:
	while not event_queue.is_empty():
		advance_to((event_queue.peek_next() as CombatEvent).timestamp_us)
	return get_resolved_events()


func apply_authoritative_position(
	actor_id: StringName,
	position: Vector2i,
	facing_millidegrees: int,
	movement_cost_microfeet: int = 0
) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if movement_cost_microfeet < 0:
		return _failure("invalid_movement_cost")
	_refresh_actor_movement_budgets()
	var actor_state: CombatActorState = _actor_states[actor_key]
	_refresh_actor_timed_conditions(actor_state)
	if _is_actor_critically_staggered(actor_state):
		return _failure("movement_blocked_by_critical_stagger")
	if not actor_state.current_action_instance_id.is_empty():
		var action: CombatActionInstance = _actions[actor_state.current_action_instance_id]
		var definition: CombatActionDefinition = _action_definitions[String(action.action_definition_id)]
		if not definition.allows_movement:
			return _failure("movement_restricted_by_action")
	if movement_cost_microfeet > 0 and not actor_state.spend_movement(movement_cost_microfeet):
		return _failure("insufficient_remaining_mr")
	actor_state.set_position(position, facing_millidegrees)
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"actor_position_changed",
		_get_actor_initiative(actor_key),
		actor_id,
		&"",
		{
			"position_microfeet": [position.x, position.y],
			"facing_millidegrees": facing_millidegrees,
			"movement_cost_microfeet": movement_cost_microfeet,
			"remaining_mr_microfeet": actor_state.remaining_mr_microfeet,
			"action_continues": not actor_state.current_action_instance_id.is_empty(),
		},
		"",
		PackedStringArray(),
		{} if movement_cost_microfeet == 0 else {"mr_microfeet": movement_cost_microfeet}
	)
	return _success()


func get_actor_state(actor_id: StringName) -> CombatActorState:
	return _actor_states.get(String(actor_id)) as CombatActorState


func get_action(action_instance_id: String) -> CombatActionInstance:
	return _actions.get(action_instance_id) as CombatActionInstance


func get_attack(attack_instance_id: String) -> CombatAttackInstance:
	return _attacks.get(attack_instance_id) as CombatAttackInstance


func get_defense_resolution(defense_resolution_id: String) -> CombatDefenseResolution:
	return _defense_resolutions.get(defense_resolution_id) as CombatDefenseResolution


func get_damage_resolution(damage_resolution_id: String) -> CombatDamageResolution:
	return _damage_resolutions.get(damage_resolution_id) as CombatDamageResolution


func get_critical_record(critical_record_id: String) -> CombatCriticalRecord:
	return _critical_records.get(critical_record_id) as CombatCriticalRecord


func get_critical_records() -> Array:
	var records: Array = []
	var record_ids: Array = _critical_records.keys()
	record_ids.sort()
	for record_id: String in record_ids:
		records.append(_critical_records[record_id])
	return records


func get_resolved_events() -> Array:
	return _resolved_events.duplicate()


func take_resolved_events() -> Array:
	var events := _resolved_events.duplicate()
	_resolved_events.clear()
	return events


func get_state_snapshot() -> Dictionary:
	var actor_snapshots: Array = []
	var actor_keys: Array = _actor_definitions.keys()
	actor_keys.sort()
	for actor_key: String in actor_keys:
		var definition: CombatActorDefinition = _actor_definitions[actor_key]
		var state: CombatActorState = _actor_states[actor_key]
		actor_snapshots.append({"definition": definition.to_dictionary(), "state": state.to_dictionary()})

	var action_definition_snapshots: Array = []
	var definition_keys: Array = _action_definitions.keys()
	definition_keys.sort()
	for definition_key: String in definition_keys:
		action_definition_snapshots.append((_action_definitions[definition_key] as CombatActionDefinition).to_dictionary())

	var action_snapshots: Array = []
	var action_keys: Array = _actions.keys()
	action_keys.sort()
	for action_key: String in action_keys:
		action_snapshots.append((_actions[action_key] as CombatActionInstance).to_dictionary())

	var attack_definition_snapshots: Array = []
	var attack_definition_keys: Array = _attack_definitions.keys()
	attack_definition_keys.sort()
	for definition_key: String in attack_definition_keys:
		attack_definition_snapshots.append((_attack_definitions[definition_key] as CombatAttackDefinition).to_dictionary())

	var attack_snapshots: Array = []
	var attack_keys: Array = _attacks.keys()
	attack_keys.sort()
	for attack_key: String in attack_keys:
		attack_snapshots.append((_attacks[attack_key] as CombatAttackInstance).to_dictionary())

	var defense_profile_snapshots: Array = []
	var defense_profile_keys: Array = _defense_profiles.keys()
	defense_profile_keys.sort()
	for actor_key: String in defense_profile_keys:
		defense_profile_snapshots.append({
			"actor_id": actor_key,
			"profile": (_defense_profiles[actor_key] as CombatDefenseProfile).to_dictionary(),
		})

	var defense_resolution_snapshots: Array = []
	var defense_resolution_keys: Array = _defense_resolutions.keys()
	defense_resolution_keys.sort()
	for defense_key: String in defense_resolution_keys:
		defense_resolution_snapshots.append((_defense_resolutions[defense_key] as CombatDefenseResolution).to_dictionary())

	var damage_protection_snapshots: Array = []
	var damage_protection_keys: Array = _damage_protection_profiles.keys()
	damage_protection_keys.sort()
	for actor_key: String in damage_protection_keys:
		damage_protection_snapshots.append({
			"actor_id": actor_key,
			"profile": (_damage_protection_profiles[actor_key] as CombatDamageProtectionProfile).to_dictionary(),
		})

	var damage_resolution_snapshots: Array = []
	var damage_resolution_keys: Array = _damage_resolutions.keys()
	damage_resolution_keys.sort()
	for damage_key: String in damage_resolution_keys:
		damage_resolution_snapshots.append((_damage_resolutions[damage_key] as CombatDamageResolution).to_dictionary())

	var critical_record_snapshots: Array = []
	var critical_record_keys: Array = _critical_records.keys()
	critical_record_keys.sort()
	for critical_key: String in critical_record_keys:
		critical_record_snapshots.append((_critical_records[critical_key] as CombatCriticalRecord).to_dictionary())

	var reaction_definition_snapshots: Array = []
	var reaction_actor_keys: Array = _critical_reaction_definitions.keys()
	reaction_actor_keys.sort()
	for actor_key: String in reaction_actor_keys:
		var registration: Dictionary = _critical_reaction_definitions[actor_key]
		reaction_definition_snapshots.append({
			"actor_id": actor_key,
			"attack_definition_id": registration["attack_definition_id"],
			"authoritative_line_of_sight": registration["authoritative_line_of_sight"],
		})
	var deferred_critical_snapshots: Array = []
	var deferred_attack_keys: Array = _deferred_critical_records_by_attack.keys()
	deferred_attack_keys.sort()
	for attack_key: String in deferred_attack_keys:
		deferred_critical_snapshots.append({"attack_instance_id": attack_key, "entries": (_deferred_critical_records_by_attack[attack_key] as Array).duplicate(true)})

	return {
		"schema_version": 8,
		"timestamp_us": clock.get_elapsed_us(),
		"round_index": clock.get_round_index(),
		"state_revision": _state_revision,
		"rng": random.to_dictionary(),
		"next_event_sequence": _next_sequence,
		"next_action_sequence": _next_action_sequence,
		"next_attack_sequence": _next_attack_sequence,
		"next_defense_sequence": _next_defense_sequence,
		"next_damage_sequence": _next_damage_sequence,
		"next_critical_sequence": _next_critical_sequence,
		"combat_started": _combat_started,
		"opening_sequence_complete": _opening_sequence_complete,
		"current_opening_rank": _current_opening_rank,
		"actors": actor_snapshots,
		"action_definitions": action_definition_snapshots,
		"actions": action_snapshots,
		"attack_definitions": attack_definition_snapshots,
		"attacks": attack_snapshots,
		"defense_profiles": defense_profile_snapshots,
		"defense_resolutions": defense_resolution_snapshots,
		"damage_protection_profiles": damage_protection_snapshots,
		"damage_resolutions": damage_resolution_snapshots,
		"critical_records": critical_record_snapshots,
		"critical_reaction_definitions": reaction_definition_snapshots,
		"deferred_critical_consequences": deferred_critical_snapshots,
		"pending_events": event_queue.snapshot(),
	}


func _resolve_due_event(event: CombatEvent) -> void:
	match String(event.event_type):
		"action_act_due":
			_resolved_events.append(event)
			_resolve_action_act_due(event)
		"action_finalize_due":
			_resolved_events.append(event)
			_resolve_action_finalize_due(event)
		"action_interrupt_due":
			_resolved_events.append(event)
			_resolve_action_interrupt_due(event)
		_:
			_resolved_events.append(event)


func _resolve_action_act_due(event: CombatEvent) -> void:
	var action_instance_id: String = event.payload.get("action_instance_id", "")
	if not _actions.has(action_instance_id):
		return
	var action: CombatActionInstance = _actions[action_instance_id]
	if action.status != CombatActionInstance.STATUS_IN_PROGRESS:
		return
	var actor_key := String(action.actor_id)
	var actor_state: CombatActorState = _actor_states[actor_key]
	action.completed_acts += 1
	action.revision += 1
	actor_state.next_action_interval_index = action.starting_interval_index + action.completed_acts
	actor_state.action_timing_cursor_us = event.timestamp_us
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		event.timestamp_us,
		&"action_progressed",
		action.initiative,
		action.actor_id,
		&"",
		{
			"action_instance_id": action_instance_id,
			"completed_acts": action.completed_acts,
			"required_acts": action.required_acts,
		},
		action.start_event_id
	)
	if action.completed_acts >= action.required_acts:
		if _dependencies_are_terminal(action):
			_complete_action(action, event.event_id)
		else:
			action.status = CombatActionInstance.STATUS_AWAITING_DEPENDENCIES
			action.revision += 1
			_state_revision += 1
		return
	_schedule_action_internal_event(
		action,
		_get_action_interval_timestamp(
			action.timing_anchor_us,
			action.starting_interval_index + action.completed_acts + 1,
			action.at_at_start
		),
		&"action_act_due"
	)


func _resolve_action_finalize_due(event: CombatEvent) -> void:
	var action_instance_id: String = event.payload.get("action_instance_id", "")
	if not _actions.has(action_instance_id):
		return
	var action: CombatActionInstance = _actions[action_instance_id]
	action.finalization_scheduled = false
	if action.is_terminal():
		return
	if not _dependencies_are_terminal(action):
		action.status = CombatActionInstance.STATUS_AWAITING_DEPENDENCIES
		action.revision += 1
		_state_revision += 1
		return
	_complete_action(action, event.event_id)


func _resolve_action_interrupt_due(event: CombatEvent) -> void:
	var action_instance_id: String = event.payload.get("action_instance_id", "")
	if not _actions.has(action_instance_id):
		return
	var action: CombatActionInstance = _actions[action_instance_id]
	var definition: CombatActionDefinition = _action_definitions[String(action.action_definition_id)]
	if action.is_terminal() or not definition.interruptible:
		_record_resolved_event(
			event.timestamp_us,
			&"action_interruption_ignored",
			event.initiative,
			event.source_actor_id,
			action.actor_id,
			{"action_instance_id": action_instance_id, "reason": "action_not_interruptible_or_terminal"},
			event.event_id
		)
		return
	action.status = CombatActionInstance.STATUS_INTERRUPTED
	action.interrupted_at_us = event.timestamp_us
	action.cause_event_id = event.event_id
	action.interruption_reason = String(event.payload.get("reason", ""))
	action.revision += 1
	var actor_state: CombatActorState = _actor_states[String(action.actor_id)]
	if actor_state.current_action_instance_id == action_instance_id:
		actor_state.current_action_instance_id = ""
		actor_state.revision += 1
	_state_revision += 1
	var canceled_completion_event_ids := event_queue.cancel_action_events(action_instance_id)
	var interrupted := _record_resolved_event(
		event.timestamp_us,
		&"action_interrupted",
		event.initiative,
		event.source_actor_id,
		action.actor_id,
		{
			"action_instance_id": action_instance_id,
			"completed_acts": action.completed_acts,
			"required_acts": action.required_acts,
			"reason": action.interruption_reason,
			"canceled_completion_event_ids": Array(canceled_completion_event_ids),
		},
		event.event_id
	)
	action.final_event_id = interrupted.event_id
	_interrupt_linked_attack(action, interrupted.event_id)


func _complete_action(action: CombatActionInstance, cause_event_id: String) -> void:
	action.status = CombatActionInstance.STATUS_COMPLETED
	action.completed_at_us = clock.get_elapsed_us()
	action.cause_event_id = cause_event_id
	action.revision += 1
	var actor_state: CombatActorState = _actor_states[String(action.actor_id)]
	if actor_state.current_action_instance_id == action.action_instance_id:
		actor_state.current_action_instance_id = ""
		actor_state.revision += 1
	_state_revision += 1
	var completed := _record_resolved_event(
		clock.get_elapsed_us(),
		&"action_completed",
		action.initiative,
		action.actor_id,
		&"",
		{
			"action_instance_id": action.action_instance_id,
			"completed_acts": action.completed_acts,
			"required_acts": action.required_acts,
			"dependency_action_ids": Array(action.dependency_action_ids),
		},
		cause_event_id
	)
	action.final_event_id = completed.event_id
	var definition: CombatActionDefinition = _action_definitions[String(action.action_definition_id)]
	if bool(definition.extension_metadata.get("stands_from_prone", false)):
		_remove_actor_condition(actor_state, "prone")
		_record_resolved_event(clock.get_elapsed_us(), &"actor_stood_from_prone", action.initiative, action.actor_id, &"", {
			"action_instance_id": action.action_instance_id,
		}, completed.event_id)
	_resolve_linked_attack_accuracy(action, completed.event_id)


func _resolve_linked_attack_accuracy(action: CombatActionInstance, parent_event_id: String) -> void:
	if not _attack_by_action_id.has(action.action_instance_id):
		return
	var attack_instance_id: String = _attack_by_action_id[action.action_instance_id]
	var attack: CombatAttackInstance = _attacks[attack_instance_id]
	if attack.status != CombatAttackInstance.STATUS_EXECUTING:
		return
	var definition: CombatAttackDefinition = _attack_definitions[String(attack.attack_definition_id)]
	var final_legality := _evaluate_final_attack_legality(attack, definition)
	if not final_legality["success"]:
		attack.status = CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED
		attack.resolved_at_us = clock.get_elapsed_us()
		attack.final_legality_reason = String(final_legality["reason"])
		attack.revision += 1
		_state_revision += 1
		var failed := _record_resolved_event(
			clock.get_elapsed_us(),
			&"physical_attack_final_legality_failed",
			action.initiative,
			attack.attacker_id,
			attack.target_id,
			{
				"attack_instance_id": attack.attack_instance_id,
				"action_instance_id": action.action_instance_id,
				"reason": attack.final_legality_reason,
				"final_distance_squared_microfeet": attack.final_distance_squared_microfeet,
				"final_range_legal": attack.final_range_legal,
				"final_line_of_sight_legal": attack.final_line_of_sight_legal,
				"natural_d20": null,
				"accuracy_rolled": false,
				"elapsed_action_time_refunded": false,
				"damage_applied": false,
			},
			parent_event_id
		)
		attack.result_event_id = failed.event_id
		return
	attack.natural_roll = roll_int(1, 20)
	attack.rng_draw_index = random.get_draw_count()
	attack.adjusted_roll = int(attack.natural_roll) - attack.roll_bonus
	var critical_result := definition.critical_trigger_policy.classify(int(attack.natural_roll))
	attack.critical_success = critical_result == CombatCriticalTriggerPolicy.RESULT_SUCCESS
	attack.critical_failure = critical_result == CombatCriticalTriggerPolicy.RESULT_FAILURE
	if attack.critical_success:
		attack.accuracy_success = true
	elif attack.critical_failure:
		attack.accuracy_success = false
	else:
		attack.accuracy_success = int(attack.adjusted_roll) <= attack.acc_target
	attack.status = CombatAttackInstance.STATUS_PENDING_DEFENSE if attack.accuracy_success else CombatAttackInstance.STATUS_MISSED
	attack.resolved_at_us = clock.get_elapsed_us()
	attack.revision += 1
	_state_revision += 1
	var result := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_attack_accuracy_resolved",
		action.initiative,
		attack.attacker_id,
		attack.target_id,
		{
			"attack_instance_id": attack.attack_instance_id,
			"action_instance_id": action.action_instance_id,
			"weapon_ref": String(attack.weapon_ref),
			"target_location": String(attack.target_location),
			"base_acc": attack.base_acc,
			"base_acc_modifier": attack.base_acc_modifier,
			"location_acc_modifier": attack.location_acc_modifier,
			"acc_target": attack.acc_target,
			"roll_bonus": attack.roll_bonus,
			"rng_draw_index": attack.rng_draw_index,
			"natural_d20": attack.natural_roll,
			"adjusted_roll": attack.adjusted_roll,
			"accuracy_success": attack.accuracy_success,
			"critical_success": attack.critical_success,
			"critical_failure": attack.critical_failure,
			"result_state": attack.status,
			"damage_applied": false,
		},
		parent_event_id
	)
	attack.accuracy_event_id = result.event_id
	attack.result_event_id = result.event_id
	if critical_result != CombatCriticalTriggerPolicy.RESULT_NONE:
		var critical_record := _record_critical_trigger(
			"attack:%s:acc" % attack.attack_instance_id,
			&"physical_attack",
			critical_result,
			int(attack.natural_roll),
			definition.critical_trigger_policy,
			attack.attacker_id,
			attack.target_id,
			result.event_id
		)
		attack.critical_record_id = critical_record.critical_record_id
		attack.result_event_id = critical_record.event_id
		_apply_critical_consequence(critical_record, attack)
	if attack.status == CombatAttackInstance.STATUS_MISSED:
		_finalize_deferred_critical_consequences(attack)


func _evaluate_final_attack_legality(attack: CombatAttackInstance, definition: CombatAttackDefinition) -> Dictionary:
	var attacker_state: CombatActorState = _actor_states.get(String(attack.attacker_id))
	var target_state: CombatActorState = _actor_states.get(String(attack.target_id))
	if attacker_state == null or target_state == null:
		attack.final_range_legal = false
		attack.final_line_of_sight_legal = null
		return _failure("final_attack_actor_unavailable")
	attack.final_attacker_position_microfeet = attacker_state.position_microfeet
	attack.final_target_position_microfeet = target_state.position_microfeet
	var offset := target_state.position_microfeet - attacker_state.position_microfeet
	var distance_squared := offset.x * offset.x + offset.y * offset.y
	attack.final_distance_squared_microfeet = distance_squared
	var minimum_range := 0 if definition.minimum_range_microfeet == null else int(definition.minimum_range_microfeet)
	var maximum_range := int(definition.maximum_range_microfeet)
	attack.final_range_legal = distance_squared >= minimum_range * minimum_range \
		and distance_squared <= maximum_range * maximum_range
	if not attack.final_range_legal:
		attack.final_line_of_sight_legal = null
		return _failure("target_out_of_range_at_resolution")
	if not definition.requires_line_of_sight:
		attack.final_line_of_sight_legal = true
		return _success()
	var line_of_sight: Variant = null
	if _attack_final_line_of_sight_resolver.is_valid():
		line_of_sight = _attack_final_line_of_sight_resolver.call(attack.attacker_id, attack.target_id)
	elif attacker_state.position_microfeet == attack.declared_attacker_position_microfeet \
		and target_state.position_microfeet == attack.declared_target_position_microfeet:
		# A static fixture can reuse its declaration fact only when neither
		# endpoint moved. Moved endpoints fail closed without geometry.
		line_of_sight = attack.declaration_line_of_sight_verified
	attack.final_line_of_sight_legal = line_of_sight
	if line_of_sight == null:
		return _failure("final_line_of_sight_unresolved")
	if line_of_sight != true:
		return _failure("line_of_sight_blocked_at_resolution")
	return _success()


func _interrupt_linked_attack(action: CombatActionInstance, parent_event_id: String) -> void:
	if not _attack_by_action_id.has(action.action_instance_id):
		return
	var attack: CombatAttackInstance = _attacks[_attack_by_action_id[action.action_instance_id]]
	if attack.status != CombatAttackInstance.STATUS_EXECUTING:
		return
	attack.status = CombatAttackInstance.STATUS_INTERRUPTED
	attack.resolved_at_us = clock.get_elapsed_us()
	attack.revision += 1
	_state_revision += 1
	var interrupted := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_attack_interrupted",
		action.initiative,
		attack.attacker_id,
		attack.target_id,
		{
			"attack_instance_id": attack.attack_instance_id,
			"action_instance_id": action.action_instance_id,
			"natural_d20": null,
			"damage_applied": false,
		},
		parent_event_id
	)
	attack.result_event_id = interrupted.event_id


func _dodge_needs_context(
	attack: CombatAttackInstance,
	defender_state: CombatActorState,
	defender_definition: CombatActorDefinition,
	profile: CombatDefenseProfile
) -> bool:
	if not profile.priority.has(String(CombatDefenseProfile.DODGE)):
		return false
	if _active_defenses_restricted(defender_state):
		return false
	if defender_state.conditions.has("held") or defender_state.conditions.has("immobilized"):
		return false
	var stat_name := _get_dodge_stat_name(attack.delivery_class)
	if stat_name.is_empty() or defender_definition.get_combat_stat(stat_name) == null:
		return false
	return true


func _evaluate_defense_eligibility(
	attack: CombatAttackInstance,
	defender_state: CombatActorState,
	defender_definition: CombatActorDefinition,
	profile: CombatDefenseProfile,
	defense_type: StringName,
	dodge_context: CombatDodgeContext,
	dodge_or_soak_attempted: bool
) -> Dictionary:
	var result := {
		"eligible": false,
		"reason": "unsupported_defense",
		"equipment_ref": &"",
		"base_target": null,
		"target_modifier": profile.get_modifier(defense_type),
	}
	if _active_defenses_restricted(defender_state):
		result["reason"] = "defender_unaware_or_surprised"
		return result

	match defense_type:
		CombatDefenseProfile.DODGE:
			if dodge_or_soak_attempted:
				result["reason"] = "mutually_exclusive_with_physical_soak"
				return result
			if defender_state.conditions.has("held") or defender_state.conditions.has("immobilized"):
				result["reason"] = "defender_cannot_move"
				return result
			var stat_name := _get_dodge_stat_name(attack.delivery_class)
			if stat_name.is_empty():
				result["reason"] = "attack_delivery_unresolved"
				return result
			result["base_target"] = defender_definition.get_combat_stat(stat_name)
			if result["base_target"] == null:
				result["reason"] = "dodge_target_unresolved"
				return result
			if dodge_context == null:
				result["reason"] = "dodge_context_unresolved"
				return result
			if dodge_context.selection_status == CombatDodgeContext.SELECTION_UNAVAILABLE:
				result["reason"] = "no_legal_dodge_destination"
				return result
			if dodge_context.selection_status == CombatDodgeContext.SELECTION_RESOLVED:
				var validation := _validate_resolved_dodge_context(attack, defender_state, dodge_context)
				if not validation["valid"]:
					result["reason"] = validation["reason"]
					return result
			result["eligible"] = true
			result["reason"] = "eligible"
		CombatDefenseProfile.WEAPON_BLOCK:
			return _evaluate_block_eligibility(defender_state, profile.weapon_block, defense_type, profile.get_modifier(defense_type))
		CombatDefenseProfile.SHIELD_BLOCK:
			return _evaluate_block_eligibility(defender_state, profile.shield_block, defense_type, profile.get_modifier(defense_type))
		CombatDefenseProfile.PHYSICAL_SOAK:
			if dodge_or_soak_attempted:
				result["reason"] = "mutually_exclusive_with_dodge"
				return result
			if attack.is_back_attack:
				result["reason"] = "back_attack"
				return result
			if attack.damage_types.is_empty() or attack.physical_soak_eligible == null:
				result["reason"] = "physical_soak_eligibility_unresolved"
				return result
			if attack.damage_types.has("piercing") or attack.physical_soak_eligible == false:
				result["reason"] = "attack_not_physical_soak_eligible"
				return result
			result["base_target"] = defender_definition.get_combat_stat("physical_soak")
			if result["base_target"] == null:
				result["reason"] = "physical_soak_target_unresolved"
				return result
			result["eligible"] = true
			result["reason"] = "eligible"
	return result


func _evaluate_block_eligibility(
	defender_state: CombatActorState,
	block_definition: CombatBlockDefinition,
	defense_type: StringName,
	target_modifier: int
) -> Dictionary:
	var result := {
		"eligible": false,
		"reason": "block_definition_unresolved",
		"equipment_ref": &"",
		"base_target": null,
		"target_modifier": target_modifier,
	}
	if block_definition == null:
		return result
	result["equipment_ref"] = block_definition.equipment_ref
	result["base_target"] = block_definition.block_target
	result["target_modifier"] = target_modifier + block_definition.target_modifier
	if not defender_state.equipment_refs.has(String(block_definition.equipment_ref)):
		result["reason"] = "blocking_equipment_not_equipped"
		return result
	if not block_definition.proficiency_verified:
		result["reason"] = "blocking_proficiency_unverified"
		return result
	if not block_definition.usable:
		result["reason"] = "blocking_equipment_unusable"
		return result
	if block_definition.block_target == null:
		result["reason"] = "block_target_unresolved"
		return result
	if defense_type == CombatDefenseProfile.SHIELD_BLOCK:
		if block_definition.current_shp == null:
			result["reason"] = "shield_shp_unresolved"
			return result
		if int(block_definition.current_shp) <= 0:
			result["reason"] = "shield_has_zero_shp"
			return result
	result["eligible"] = true
	result["reason"] = "eligible"
	return result


func _validate_resolved_dodge_context(
	_attack: CombatAttackInstance,
	defender_state: CombatActorState,
	dodge_context: CombatDodgeContext
) -> Dictionary:
	if not dodge_context.authoritative_path_valid:
		return {"valid": false, "reason": "dodge_path_unverified"}
	if not dodge_context.authoritative_escape_valid:
		return {"valid": false, "reason": "dodge_escape_unverified"}
	if dodge_context.authoritative_collision_free == false:
		return {"valid": false, "reason": "dodge_collision_blocked"}
	if dodge_context.authoritative_terrain_legal == false:
		return {"valid": false, "reason": "dodge_terrain_illegal"}
	if dodge_context.authoritative_unoccupied == false:
		return {"valid": false, "reason": "dodge_destination_occupied"}
	if dodge_context.movement_cost_microfeet == null:
		return {"valid": false, "reason": "dodge_movement_cost_unresolved"}
	var movement_cost := int(dodge_context.movement_cost_microfeet)
	if dodge_context.in_place_duck:
		if movement_cost != 0:
			return {"valid": false, "reason": "in_place_dodge_must_cost_zero_mr"}
	else:
		if movement_cost <= 0 or dodge_context.destination_microfeet == defender_state.position_microfeet:
			return {"valid": false, "reason": "dodge_displacement_invalid"}
	if defender_state.remaining_mr_microfeet == null:
		return {"valid": false, "reason": "remaining_mr_unresolved"}
	var defender_definition: CombatActorDefinition = _actor_definitions[String(defender_state.actor_id)]
	var mr_value: Variant = defender_definition.get_combat_stat("mr")
	if mr_value == null:
		return {"valid": false, "reason": "actor_mr_unresolved"}
	var movement_allowance_microfeet := int(mr_value) * 1_000_000
	if defender_state.conditions.has("prone"):
		@warning_ignore("integer_division")
		movement_allowance_microfeet /= 4
	@warning_ignore("integer_division")
	var maximum_dodge_microfeet := movement_allowance_microfeet / (2 * 1_000_000) * 1_000_000
	if movement_cost > maximum_dodge_microfeet:
		return {"valid": false, "reason": "dodge_exceeds_half_mr"}
	if movement_cost > int(defender_state.remaining_mr_microfeet):
		return {"valid": false, "reason": "insufficient_remaining_mr"}
	return {"valid": true, "reason": "valid"}


func _select_automatic_dodge_context(
	attack: CombatAttackInstance,
	defender_state: CombatActorState,
	dodge_environment: CombatDodgeEnvironment
) -> Dictionary:
	if dodge_environment == null or not dodge_environment.information_complete:
		var incomplete_source := "ARENA-TASK-8: environmental information incomplete"
		var incomplete_environment_id := &""
		if dodge_environment != null:
			incomplete_environment_id = dodge_environment.environment_id
			if not dodge_environment.source_ref.is_empty():
				incomplete_source = dodge_environment.source_ref
		return _success({
			"dodge_context": CombatDodgeContext.new(
				CombatDodgeContext.SELECTION_AMBIGUOUS,
				defender_state.position_microfeet,
				null,
				false,
				false,
				false,
				incomplete_source,
				&"",
				incomplete_environment_id,
				null,
				null,
				null,
				null,
				"environmental_information_incomplete"
			)
		})

	var candidate_ids := {}
	var legal_candidates: Array[CombatDodgeCandidate] = []
	var unresolved_duck_candidate := false
	for candidate: CombatDodgeCandidate in dodge_environment.candidates:
		var candidate_key := String(candidate.candidate_id)
		if candidate_ids.has(candidate_key):
			return _failure("duplicate_dodge_candidate_id")
		candidate_ids[candidate_key] = true
		if not candidate.path_clear or not candidate.collision_free or not candidate.terrain_legal or not candidate.unoccupied:
			continue
		if not candidate.escapes_attack:
			continue
		if candidate.in_place_duck:
			if not candidate.duck_legally_sufficient:
				continue
			if candidate.movement_cost_microfeet != 0 or candidate.destination_microfeet != defender_state.position_microfeet:
				continue
			if attack.ducking_policy == CombatAttackDefinition.DUCKING_PROHIBITED:
				continue
			if attack.ducking_policy == CombatAttackDefinition.DUCKING_UNRESOLVED:
				unresolved_duck_candidate = true
				continue
		elif candidate.movement_cost_microfeet <= 0 or candidate.destination_microfeet == defender_state.position_microfeet:
			continue
		var context := _dodge_context_from_candidate(dodge_environment, candidate)
		if not _validate_resolved_dodge_context(attack, defender_state, context)["valid"]:
			continue
		legal_candidates.append(candidate)

	if legal_candidates.is_empty() and unresolved_duck_candidate:
		return _success({
			"dodge_context": CombatDodgeContext.new(
				CombatDodgeContext.SELECTION_AMBIGUOUS,
				defender_state.position_microfeet,
				null,
				true,
				true,
				true,
				dodge_environment.source_ref,
				&"",
				dodge_environment.environment_id,
				true,
				true,
				true,
				null,
				"attack_ducking_policy_unresolved"
			)
		})
	if legal_candidates.is_empty():
		return _success({
			"dodge_context": CombatDodgeContext.new(
				CombatDodgeContext.SELECTION_UNAVAILABLE,
				defender_state.position_microfeet,
				null,
				false,
				false,
				false,
				dodge_environment.source_ref,
				&"",
				dodge_environment.environment_id
			)
		})

	legal_candidates.sort_custom(_automatic_dodge_candidate_precedes)
	return _success({"dodge_context": _dodge_context_from_candidate(dodge_environment, legal_candidates[0])})


func _dodge_context_from_candidate(
	dodge_environment: CombatDodgeEnvironment,
	candidate: CombatDodgeCandidate
) -> CombatDodgeContext:
	return CombatDodgeContext.new(
		CombatDodgeContext.SELECTION_RESOLVED,
		candidate.destination_microfeet,
		candidate.movement_cost_microfeet,
		candidate.in_place_duck,
		candidate.path_clear,
		candidate.escapes_attack,
		candidate.source_ref if not candidate.source_ref.is_empty() else dodge_environment.source_ref,
		candidate.candidate_id,
		dodge_environment.environment_id,
		candidate.collision_free,
		candidate.terrain_legal,
		candidate.unoccupied,
		candidate.known_hazard_score,
		"automatic_candidate_selected"
	)


func _automatic_dodge_candidate_precedes(left: CombatDodgeCandidate, right: CombatDodgeCandidate) -> bool:
	if left.known_hazard_score != right.known_hazard_score:
		return left.known_hazard_score < right.known_hazard_score
	if left.movement_cost_microfeet != right.movement_cost_microfeet:
		return left.movement_cost_microfeet < right.movement_cost_microfeet
	if String(left.candidate_id) != String(right.candidate_id):
		return String(left.candidate_id) < String(right.candidate_id)
	if left.destination_microfeet.x != right.destination_microfeet.x:
		return left.destination_microfeet.x < right.destination_microfeet.x
	return left.destination_microfeet.y < right.destination_microfeet.y


func _prepare_physical_damage(attack: CombatAttackInstance) -> Dictionary:
	var definition: CombatAttackDefinition = _attack_definitions.get(String(attack.attack_definition_id))
	if definition == null or definition.physical_damage == null:
		return _failure("physical_damage_definition_unresolved")
	var damage_definition: CombatPhysicalDamageDefinition = definition.physical_damage
	if damage_definition.strength_bonus_eligible == null:
		return _failure("strength_bonus_eligibility_unresolved")
	if damage_definition.minimum_one_applies == null:
		return _failure("minimum_one_damage_policy_unresolved")
	if attack.damage_types.is_empty():
		return _failure("physical_damage_types_unresolved")
	var unique_types := {}
	for damage_type: String in attack.damage_types:
		if damage_type != "bashing" and damage_type != "slashing" and damage_type != "piercing":
			return _failure("unsupported_physical_damage_type")
		if unique_types.has(damage_type):
			return _failure("duplicate_physical_damage_type")
		unique_types[damage_type] = true

	var attacker_definition: CombatActorDefinition = _actor_definitions[String(attack.attacker_id)]
	var strength_bonus := 0
	if damage_definition.strength_bonus_eligible == true:
		var sb_value: Variant = attacker_definition.get_combat_stat("sb")
		if sb_value == null:
			return _failure("attacker_strength_bonus_unresolved")
		strength_bonus = int(sb_value)
	var target_definition: CombatActorDefinition = _actor_definitions[String(attack.target_id)]
	var nal_value: Variant = target_definition.get_combat_stat("nal")
	if nal_value == null:
		return _failure("target_nal_unresolved")
	var target_key := String(attack.target_id)
	if not _damage_protection_profiles.has(target_key):
		return _failure("damage_protection_profile_unresolved")
	var protection_profile: CombatDamageProtectionProfile = _damage_protection_profiles[target_key]
	var target_state: CombatActorState = _actor_states[target_key]
	if target_state.current_hpc == null:
		return _failure("target_hpc_unresolved")
	var armor_result := _select_applicable_armor(protection_profile, target_state, attack.target_location, attack.damage_types)
	if not armor_result["success"]:
		return armor_result

	var location_multiplier: Variant = damage_definition.get_location_multiplier(attack.target_location)
	if location_multiplier == null:
		return _failure("location_damage_multiplier_unresolved")
	var core_multipliers: Array = []
	if not _multiplier_is_unit(location_multiplier):
		core_multipliers.append({"kind": "location", "multiplier": location_multiplier})
	if attack.critical_success and attack.consequence_damage_multipliers.is_empty() and damage_definition.critical_multiplier != null:
		if not _multiplier_is_unit(damage_definition.critical_multiplier):
			core_multipliers.append({"kind": "source_specific_critical", "multiplier": damage_definition.critical_multiplier})
	for consequence_multiplier: Dictionary in attack.consequence_damage_multipliers:
		core_multipliers.append({
			"kind": String(consequence_multiplier.get("kind", "critical_consequence")),
			"multiplier": consequence_multiplier,
		})
	if target_state.conditions.has("prone"):
		core_multipliers.append({
			"kind": "arena_prone_target",
			"multiplier": {
				"numerator": 3,
				"denominator": 2,
				"source_ref": "ARENA-TASK-17 experimental prone physical-damage playtest rule",
			},
		})

	var type_response_value: Variant = protection_profile.get_exact_type_response(attack.damage_types)
	var type_response: Dictionary = {} if type_response_value == null else (type_response_value as Dictionary).duplicate(true)
	var pre_protection_multipliers: Array = core_multipliers.duplicate(true)
	var post_protection_multipliers: Array = []
	if String(type_response.get("kind", "")) == CombatDamageProtectionProfile.RESPONSE_MULTIPLIER:
		var type_entry := {
			"kind": "type_response_%s" % String(type_response.get("stage", "")),
			"multiplier": type_response,
		}
		if String(type_response.get("stage", "")) == CombatDamageProtectionProfile.STAGE_PRE_PROTECTION:
			pre_protection_multipliers.append(type_entry)
		else:
			post_protection_multipliers.append(type_entry)
	var pre_product := _combine_multiplier_product(pre_protection_multipliers)
	if not pre_product["success"]:
		return pre_product
	var post_product := _combine_multiplier_product(post_protection_multipliers)
	if not post_product["success"]:
		return post_product

	return _success({
		"damage_definition": damage_definition,
		"strength_bonus": strength_bonus,
		"nal": int(nal_value),
		"armor_equipment_ref": armor_result["equipment_ref"],
		"armor_slot": armor_result["armor_slot"],
		"armor_tal": armor_result["tal"],
		"pre_protection_multipliers": pre_protection_multipliers,
		"pre_multiplier_product": pre_product,
		"post_multiplier_product": post_product,
		"type_response": type_response,
	})


func _select_applicable_armor(
	profile: CombatDamageProtectionProfile,
	target_state: CombatActorState,
	target_location: StringName,
	damage_types: PackedStringArray
) -> Dictionary:
	var matches: Array[CombatArmorDefinition] = []
	for armor: CombatArmorDefinition in profile.armors:
		if not target_state.equipment_refs.has(String(armor.equipment_ref)):
			continue
		if armor.covered_locations.has(String(target_location)):
			matches.append(armor)
	if matches.size() > 1:
		return _failure("multiple_armor_items_cover_location")
	if matches.is_empty():
		return _success({"equipment_ref": &"", "armor_slot": &"", "tal": 0})
	var selected: CombatArmorDefinition = matches[0]
	var selected_tal: Variant = null
	for damage_type: String in damage_types:
		if not selected.has_tal(StringName(damage_type)):
			return _failure("armor_tal_unresolved")
		var type_tal := selected.get_tal(StringName(damage_type))
		selected_tal = type_tal if selected_tal == null else mini(int(selected_tal), type_tal)
	return _success({
		"equipment_ref": selected.equipment_ref,
		"armor_slot": selected.armor_slot,
		"tal": 0 if selected_tal == null else int(selected_tal),
	})


func _multiplier_is_unit(multiplier: Variant) -> bool:
	var value: Dictionary = multiplier
	return int(value["numerator"]) == int(value["denominator"])


func _combine_multiplier_product(multiplier_entries: Array) -> Dictionary:
	var product_numerator := 1
	var product_denominator := 1
	for entry: Dictionary in multiplier_entries:
		var multiplier: Dictionary = entry["multiplier"]
		var factor_numerator := int(multiplier["numerator"])
		var factor_denominator := int(multiplier["denominator"])
		var cross_cancel := _greatest_common_divisor(product_numerator, factor_denominator)
		@warning_ignore("integer_division")
		product_numerator /= cross_cancel
		@warning_ignore("integer_division")
		factor_denominator /= cross_cancel
		cross_cancel = _greatest_common_divisor(factor_numerator, product_denominator)
		@warning_ignore("integer_division")
		factor_numerator /= cross_cancel
		@warning_ignore("integer_division")
		product_denominator /= cross_cancel
		if _nonnegative_multiplication_overflows(product_numerator, factor_numerator) \
		or _nonnegative_multiplication_overflows(product_denominator, factor_denominator):
			return _failure("damage_multiplier_product_overflow")
		product_numerator *= factor_numerator
		product_denominator *= factor_denominator
	return _success({"numerator": product_numerator, "denominator": product_denominator})


func _apply_multiplier_product_once(value: int, multiplier_numerator: int, multiplier_denominator: int) -> int:
	assert(multiplier_numerator >= 0 and multiplier_denominator > 0, "Damage multiplier products must be non-negative rational values.")
	var reduced_value := value
	var reduced_denominator := multiplier_denominator
	var cross_cancel := _greatest_common_divisor(absi(reduced_value), reduced_denominator)
	@warning_ignore("integer_division")
	reduced_value /= cross_cancel
	@warning_ignore("integer_division")
	reduced_denominator /= cross_cancel
	assert(
		not _signed_by_nonnegative_multiplication_overflows(reduced_value, multiplier_numerator),
		"Damage multiplier overflow must be rejected during preflight."
	)
	var exact_numerator := reduced_value * multiplier_numerator
	@warning_ignore("integer_division")
	var floored_value := exact_numerator / reduced_denominator
	if exact_numerator < 0 and exact_numerator % reduced_denominator != 0:
		floored_value -= 1
	return floored_value


func _greatest_common_divisor(left: int, right: int) -> int:
	var a := absi(left)
	var b := absi(right)
	while b != 0:
		var remainder := a % b
		a = b
		b = remainder
	return maxi(a, 1)


func _nonnegative_multiplication_overflows(left: int, right: int) -> bool:
	assert(left >= 0 and right >= 0, "Overflow checks require non-negative factors.")
	return left != 0 and right > MAX_SIGNED_INT_64 / left


func _signed_by_nonnegative_multiplication_overflows(left: int, right: int) -> bool:
	assert(right >= 0, "Damage multiplier numerators cannot be negative.")
	if left == 0 or right == 0:
		return false
	return absi(left) > MAX_SIGNED_INT_64 / right


func _recorded_multiplier(kind: String, multiplier: Dictionary) -> Dictionary:
	return {
		"kind": kind,
		"numerator": int(multiplier["numerator"]),
		"denominator": int(multiplier["denominator"]),
		"source_ref": String(multiplier.get("source_ref", "")),
	}


func _apply_successful_shield_block(
	defender_state: CombatActorState,
	shield: CombatBlockDefinition,
	attempt: CombatDefenseAttempt
) -> void:
	assert(shield != null and shield.current_shp != null and int(shield.current_shp) > 0, "A successful shield Block requires positive verified SHP.")
	shield.current_shp = int(shield.current_shp) - 1
	var destroyed := int(shield.current_shp) == 0
	if destroyed:
		shield.usable = false
		defender_state.equipment_refs.remove_at(defender_state.equipment_refs.find(String(shield.equipment_ref)))
		defender_state.revision += 1
	attempt.resources_spent = {"shield_shp": 1}
	attempt.resolution_context = {
		"shield_shp_after": shield.current_shp,
		"shield_destroyed": destroyed,
	}


func _apply_successful_dodge(
	defender_state: CombatActorState,
	dodge_context: CombatDodgeContext,
	attempt: CombatDefenseAttempt
) -> void:
	var movement_cost := int(dodge_context.movement_cost_microfeet)
	assert(defender_state.spend_movement(movement_cost), "Validated Dodge movement must remain spendable in the same transaction.")
	if not dodge_context.in_place_duck:
		defender_state.set_position(dodge_context.destination_microfeet, defender_state.facing_millidegrees)
	attempt.resources_spent = {"mr_microfeet": movement_cost}


func _record_defense_attempt_event(
	attack: CombatAttackInstance,
	resolution: CombatDefenseResolution,
	attempt: CombatDefenseAttempt,
	event_type: StringName
) -> CombatEvent:
	return _record_resolved_event(
		clock.get_elapsed_us(),
		event_type,
		_get_actor_initiative(String(attack.target_id)),
		attack.target_id,
		attack.attacker_id,
		{
			"defense_resolution_id": resolution.defense_resolution_id,
			"attack_instance_id": attack.attack_instance_id,
			"attempt": attempt.to_dictionary(),
			"damage_applied": false,
		},
		attempt.parent_event_id,
		PackedStringArray(),
		attempt.resources_spent
	)


func _record_critical_trigger(
	roll_id: String,
	roll_category: StringName,
	result_kind: StringName,
	natural_d20: int,
	policy: CombatCriticalTriggerPolicy,
	source_actor_id: StringName,
	target_actor_id: StringName,
	parent_event_id: String,
	dependency_event_ids: PackedStringArray = PackedStringArray(),
	resource_commits: Dictionary = {}
) -> CombatCriticalRecord:
	if _critical_record_by_roll_id.has(roll_id):
		return _critical_records[_critical_record_by_roll_id[roll_id]] as CombatCriticalRecord
	assert(policy.classify(natural_d20) == result_kind, "Critical record inputs must match the source trigger policy.")
	var rarity_roll := roll_int(1, 100)
	var record_id := _make_critical_record_id(_next_critical_sequence)
	_next_critical_sequence += 1
	var record := CombatCriticalRecord.new(
		record_id,
		roll_id,
		roll_category,
		result_kind,
		natural_d20,
		policy,
		rarity_roll,
		random.get_draw_count(),
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		resource_commits
	)
	var selected_outcome: Dictionary = {}
	if policy.consequence_table_id == CriticalConsequenceCatalog.DWARVESTEK_FIREARM_TABLE or policy.consequence_table_id == CriticalConsequenceCatalog.GRENTEK_EXPLOSIVE_TABLE:
		selected_outcome = CriticalConsequenceCatalog.get_weapon_specific_outcome(policy.consequence_table_id, record.rarity)
	else:
		selected_outcome = CriticalConsequenceCatalog.get_outcome(roll_category, result_kind, record.rarity)
	if not selected_outcome.is_empty():
		record.consequence_table_id = selected_outcome["table_id"]
		record.outcome_id = StringName(selected_outcome["outcome_id"])
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_SELECTED
	else:
		record.consequence_reason = "no_approved_general_table_for_roll_category"
	var event := _create_event(
		clock.get_elapsed_us(),
		&"critical_trigger_recorded",
		_get_actor_initiative(String(source_actor_id)),
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		{},
		{}
	)
	record.event_id = event.event_id
	event.payload = {"critical_record": record.to_dictionary(), "consequence_applied": false}
	_critical_records[record_id] = record
	_critical_record_by_roll_id[roll_id] = record_id
	_resolved_events.append(event)
	_state_revision += 1
	return record


func _apply_critical_consequence(
	record: CombatCriticalRecord,
	attack: CombatAttackInstance,
	attempt: CombatDefenseAttempt = null,
	profile: CombatDefenseProfile = null
) -> void:
	var outcome: Dictionary = {}
	if record.consequence_table_id == CriticalConsequenceCatalog.DWARVESTEK_FIREARM_TABLE or record.consequence_table_id == CriticalConsequenceCatalog.GRENTEK_EXPLOSIVE_TABLE:
		outcome = CriticalConsequenceCatalog.get_weapon_specific_outcome(record.consequence_table_id, record.rarity)
	else:
		outcome = CriticalConsequenceCatalog.get_outcome(record.roll_category, record.result_kind, record.rarity)
	if outcome.is_empty():
		return
	var pending_effect := false
	for effect: Dictionary in outcome["effects"]:
		var effect_id := String(effect["effect_id"])
		var effect_type := String(effect["type"])
		match effect_type:
			"damage_multiplier":
				if not _attack_has_consequence_multiplier(attack, record.critical_record_id, effect_id):
					attack.consequence_damage_multipliers.append({
						"numerator": int(effect["numerator"]),
						"denominator": int(effect["denominator"]),
						"source_ref": CriticalConsequenceCatalog.SOURCE_REF,
						"kind": effect_id,
						"critical_record_id": record.critical_record_id,
					})
					attack.revision += 1
					_state_revision += 1
				_record_critical_effect(record, effect, &"critical_damage_multiplier_attached", true)
			"critical_stagger":
				var stagger_actor_id := _critical_effect_actor_id(record, String(effect["target"]))
				if attack.same_attack_condition_protected_actor_id == stagger_actor_id:
					_record_critical_effect(record, effect, &"critical_effect_blocked", false, "same_attack_unshakable_protection")
				else:
					_apply_critical_stagger(record, stagger_actor_id, effect)
			"prone":
				var prone_actor_id := _critical_effect_actor_id(record, String(effect["target"]))
				if attack.same_attack_condition_protected_actor_id == prone_actor_id:
					_record_critical_effect(record, effect, &"critical_effect_blocked", false, "same_attack_unshakable_protection")
				else:
					_apply_prone(record, prone_actor_id, effect)
			"shield_contact_prone":
				var contact_verified: bool = profile != null and profile.shield_block != null and profile.shield_block.verified_shield_contact == true
				if contact_verified:
					_apply_prone(record, _critical_effect_actor_id(record, String(effect["target"])), effect)
				else:
					_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "shield_contact_unverified")
			"perfect_evasion":
				if attempt != null and attempt.success == true and String(attempt.resolution_context.get("selection_status", "")) == String(CombatDodgeContext.SELECTION_RESOLVED):
					_record_critical_effect(record, effect, &"critical_perfect_evasion_applied", true)
				elif attempt != null and attempt.success == true and String(attempt.resolution_context.get("selection_status", "")) == String(CombatDodgeContext.SELECTION_AMBIGUOUS):
					var deferred := _record_resolved_event(clock.get_elapsed_us(), &"critical_effect_deferred", _get_actor_initiative(String(record.source_actor_id)), record.source_actor_id, record.target_actor_id, {
						"critical_record_id": record.critical_record_id,
						"outcome_id": String(record.outcome_id),
						"effect_id": effect_id,
						"reason": "awaiting_legal_dodge_destination",
					}, record.event_id)
					record.child_event_ids.append(deferred.event_id)
					record.consequence_reason = "awaiting_legal_dodge_destination"
					pending_effect = true
				else:
					_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "legal_dodge_destination_unresolved")
			"same_attack_protection":
				attack.same_attack_condition_protected_actor_id = record.source_actor_id
				attack.revision += 1
				_state_revision += 1
				_record_critical_effect(record, effect, &"critical_same_attack_protection_applied", true)
			"critical_reaction":
				_defer_critical_effect(record, attack, effect)
				pending_effect = true
			"backfire_redirect":
				_record_critical_effect(record, effect, &"critical_effect_blocked", false, "verified_backfire_redirection_geometry_unavailable")
			"weapon_specific_gate":
				_record_critical_effect(record, effect, &"critical_effect_blocked", false, String(effect.get("reason", "exact_weapon_specific_mechanics_unresolved")))
			_:
				_record_critical_effect(record, effect, &"critical_effect_blocked", false, "unsupported_approved_effect_type")
	_update_critical_record_status(record, pending_effect)


func _record_critical_effect(
	record: CombatCriticalRecord,
	effect: Dictionary,
	event_type: StringName,
	applied: bool,
	reason: String = ""
) -> CombatEvent:
	var effect_id := String(effect["effect_id"])
	var affected_actor_id := _critical_effect_actor_id(record, String(effect.get("target", "source")))
	if applied:
		if not record.applied_effect_ids.has(effect_id):
			record.applied_effect_ids.append(effect_id)
	else:
		if not record.blocked_effect_ids.has(effect_id):
			record.blocked_effect_ids.append(effect_id)
	if not reason.is_empty():
		record.consequence_reason = reason
	var event := _record_resolved_event(
		clock.get_elapsed_us(), event_type, _get_actor_initiative(String(record.source_actor_id)),
		record.source_actor_id, record.target_actor_id,
		{
			"critical_record_id": record.critical_record_id,
			"outcome_id": String(record.outcome_id),
			"effect_id": effect_id,
			"affected_actor_id": String(affected_actor_id),
			"applied": applied,
			"reason": reason,
		}, record.event_id
	)
	if not record.child_event_ids.has(event.event_id):
		record.child_event_ids.append(event.event_id)
	_state_revision += 1
	return event


func _defer_critical_effect(record: CombatCriticalRecord, attack: CombatAttackInstance, effect: Dictionary) -> void:
	var attack_id := attack.attack_instance_id
	if not _deferred_critical_records_by_attack.has(attack_id):
		_deferred_critical_records_by_attack[attack_id] = []
	var pending: Array = _deferred_critical_records_by_attack[attack_id]
	pending.append({"critical_record_id": record.critical_record_id, "effect": effect.duplicate(true)})
	record.consequence_status = CombatCriticalRecord.CONSEQUENCE_PENDING
	var deferred := _record_resolved_event(clock.get_elapsed_us(), &"critical_effect_deferred", _get_actor_initiative(String(record.source_actor_id)), record.source_actor_id, record.target_actor_id, {
		"critical_record_id": record.critical_record_id,
		"outcome_id": String(record.outcome_id),
		"effect_id": String(effect["effect_id"]),
		"reason": "awaiting_parent_attack_terminal_state",
	}, record.event_id)
	record.child_event_ids.append(deferred.event_id)
	_state_revision += 1


func _finalize_deferred_critical_consequences(attack: CombatAttackInstance) -> void:
	var attack_id := attack.attack_instance_id
	if not _deferred_critical_records_by_attack.has(attack_id):
		return
	var pending: Array = _deferred_critical_records_by_attack[attack_id]
	_deferred_critical_records_by_attack.erase(attack_id)
	for entry: Dictionary in pending:
		var record: CombatCriticalRecord = _critical_records[entry["critical_record_id"]]
		var effect: Dictionary = entry["effect"]
		_execute_critical_reaction(record, effect, attack)
		_update_critical_record_status(record, false)


func _execute_critical_reaction(record: CombatCriticalRecord, effect: Dictionary, parent_attack: CombatAttackInstance) -> void:
	var direction := String(effect["target"])
	var reactor_id := record.source_actor_id
	var reaction_target_id := record.target_actor_id
	if direction == "target_to_source":
		reactor_id = record.target_actor_id
		reaction_target_id = record.source_actor_id
	var reactor_key := String(reactor_id)
	var target_key := String(reaction_target_id)
	if not _critical_reaction_definitions.has(reactor_key):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_attack_definition_unregistered")
		return
	if not _actor_states.has(reactor_key) or not _actor_states.has(target_key):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_actor_unavailable")
		return
	var reactor_state: CombatActorState = _actor_states[reactor_key]
	var target_state: CombatActorState = _actor_states[target_key]
	var registration: Dictionary = _critical_reaction_definitions[reactor_key]
	var definition: CombatAttackDefinition = _attack_definitions[registration["attack_definition_id"]]
	if reactor_state.current_hpc == null or int(reactor_state.current_hpc) <= 0 or target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_actor_not_eligible")
		return
	if _active_defenses_restricted(reactor_state):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_awareness_restricted")
		return
	if not reactor_state.equipment_refs.has(String(definition.weapon_ref)):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_weapon_not_equipped")
		return
	if definition.requires_line_of_sight and registration["authoritative_line_of_sight"] != true:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_line_of_sight_unverified")
		return
	var offset := target_state.position_microfeet - reactor_state.position_microfeet
	var distance_squared := offset.x * offset.x + offset.y * offset.y
	var minimum_range := 0 if definition.minimum_range_microfeet == null else int(definition.minimum_range_microfeet)
	if not definition.has_resolved_range() or distance_squared < minimum_range * minimum_range or distance_squared > int(definition.maximum_range_microfeet) * int(definition.maximum_range_microfeet):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_target_out_of_range")
		return
	var acc_value: Variant = (_actor_definitions[reactor_key] as CombatActorDefinition).get_combat_stat("acc")
	if acc_value == null:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_acc_unresolved")
		return
	var location_modifier: Variant = definition.get_location_acc_modifier(&"torso")
	if location_modifier == null:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_torso_target_unresolved")
		return
	var attack_id := _make_attack_instance_id(_next_attack_sequence)
	_next_attack_sequence += 1
	var reaction := CombatAttackInstance.new(
		attack_id, definition, "", reactor_id, reaction_target_id, &"torso", clock.get_elapsed_us(),
		int(acc_value), int(location_modifier), _get_actor_roll_bonus(_actor_definitions[reactor_key])
	)
	_attacks[attack_id] = reaction
	_state_revision += 1
	var declared := _record_resolved_event(clock.get_elapsed_us(), &"critical_reaction_attack_declared", _get_actor_initiative(reactor_key), reactor_id, reaction_target_id, {
		"attack_instance_id": attack_id,
		"critical_record_id": record.critical_record_id,
		"attack_definition_id": String(definition.attack_definition_id),
		"ordinary_act_cost": 0,
		"counts_as_nac": false,
	}, record.event_id)
	record.child_event_ids.append(declared.event_id)
	_record_critical_effect(record, effect, &"critical_reaction_started", true)
	_resolve_reaction_attack_accuracy(reaction, definition, declared.event_id)


func _resolve_reaction_attack_accuracy(attack: CombatAttackInstance, definition: CombatAttackDefinition, parent_event_id: String) -> void:
	attack.natural_roll = roll_int(1, 20)
	attack.rng_draw_index = random.get_draw_count()
	attack.adjusted_roll = int(attack.natural_roll) - attack.roll_bonus
	var critical_result := definition.critical_trigger_policy.classify(int(attack.natural_roll))
	attack.critical_success = critical_result == CombatCriticalTriggerPolicy.RESULT_SUCCESS
	attack.critical_failure = critical_result == CombatCriticalTriggerPolicy.RESULT_FAILURE
	attack.accuracy_success = attack.critical_success or (not attack.critical_failure and int(attack.adjusted_roll) <= attack.acc_target)
	attack.status = CombatAttackInstance.STATUS_PENDING_DEFENSE if attack.accuracy_success else CombatAttackInstance.STATUS_MISSED
	attack.resolved_at_us = clock.get_elapsed_us()
	attack.revision += 1
	_state_revision += 1
	var result := _record_resolved_event(clock.get_elapsed_us(), &"physical_attack_accuracy_resolved", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
		"attack_instance_id": attack.attack_instance_id,
		"action_instance_id": "",
		"critical_reaction": true,
		"natural_d20": attack.natural_roll,
		"adjusted_roll": attack.adjusted_roll,
		"accuracy_success": attack.accuracy_success,
		"critical_success": attack.critical_success,
		"critical_failure": attack.critical_failure,
		"result_state": attack.status,
		"damage_applied": false,
	}, parent_event_id)
	attack.accuracy_event_id = result.event_id
	attack.result_event_id = result.event_id
	if critical_result != CombatCriticalTriggerPolicy.RESULT_NONE:
		var child_record := _record_critical_trigger("attack:%s:acc" % attack.attack_instance_id, &"physical_attack", critical_result, int(attack.natural_roll), definition.critical_trigger_policy, attack.attacker_id, attack.target_id, result.event_id)
		attack.critical_record_id = child_record.critical_record_id
		attack.result_event_id = child_record.event_id
		_apply_critical_consequence(child_record, attack)
	if attack.status == CombatAttackInstance.STATUS_MISSED:
		_finalize_deferred_critical_consequences(attack)


func _apply_critical_stagger(record: CombatCriticalRecord, actor_id: StringName, effect: Dictionary) -> void:
	var actor_state: CombatActorState = _actor_states.get(String(actor_id))
	if actor_state == null:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_stagger_actor_unavailable")
		return
	var until_us := clock.get_elapsed_us() + CombatCriticalEffectDefinition.CRITICAL_STAGGER_DURATION_US
	actor_state.critical_stagger_until_us = maxi(actor_state.critical_stagger_until_us, until_us)
	_add_actor_condition(actor_state, "critical_stagger")
	var applied := _record_critical_effect(record, effect, &"critical_stagger_applied", true)
	if not actor_state.current_action_instance_id.is_empty():
		var action: CombatActionInstance = _actions[actor_state.current_action_instance_id]
		var definition: CombatActionDefinition = _action_definitions[String(action.action_definition_id)]
		if not action.is_terminal() and definition.interruptible:
			var interrupt := _create_event(clock.get_elapsed_us(), &"action_interrupt_due", _get_actor_initiative(String(record.source_actor_id)), record.source_actor_id, actor_id, applied.event_id, PackedStringArray(), {
				"action_instance_id": action.action_instance_id,
				"reason": "critical_stagger",
			}, {})
			_resolved_events.append(interrupt)
			_resolve_action_interrupt_due(interrupt)


func _apply_prone(record: CombatCriticalRecord, actor_id: StringName, effect: Dictionary) -> void:
	var actor_state: CombatActorState = _actor_states.get(String(actor_id))
	if actor_state == null:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "prone_actor_unavailable")
		return
	var already_prone := actor_state.conditions.has("prone")
	_add_actor_condition(actor_state, "prone")
	_record_critical_effect(record, effect, &"critical_prone_applied", true, "already_prone_no_additional_cost" if already_prone else "")


func _complete_pending_dodge_critical_effect(attempt: CombatDefenseAttempt) -> void:
	if attempt == null or attempt.critical_record_id.is_empty() or not _critical_records.has(attempt.critical_record_id):
		return
	var record: CombatCriticalRecord = _critical_records[attempt.critical_record_id]
	if record.outcome_id != &"perfect_evasion" or record.consequence_status != CombatCriticalRecord.CONSEQUENCE_PENDING:
		return
	var outcome: Dictionary = CriticalConsequenceCatalog.get_outcome(record.roll_category, record.result_kind, record.rarity)
	for effect: Dictionary in outcome["effects"]:
		if String(effect["type"]) == "perfect_evasion":
			_record_critical_effect(record, effect, &"critical_perfect_evasion_applied", true)
	_update_critical_record_status(record, false)


func _critical_effect_actor_id(record: CombatCriticalRecord, target_selector: String) -> StringName:
	return record.target_actor_id if target_selector == "target" else record.source_actor_id


func _attack_has_consequence_multiplier(attack: CombatAttackInstance, record_id: String, effect_id: String) -> bool:
	for multiplier: Dictionary in attack.consequence_damage_multipliers:
		if multiplier.get("critical_record_id", "") == record_id and multiplier.get("kind", "") == effect_id:
			return true
	return false


func _update_critical_record_status(record: CombatCriticalRecord, pending_effect: bool) -> void:
	if pending_effect:
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_PENDING
	elif not record.applied_effect_ids.is_empty() and not record.blocked_effect_ids.is_empty():
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_PARTIAL
	elif not record.applied_effect_ids.is_empty():
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_APPLIED
	else:
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_BLOCKED
	_state_revision += 1


func _add_actor_condition(actor_state: CombatActorState, condition: String) -> void:
	if actor_state.conditions.has(condition):
		return
	actor_state.conditions.append(condition)
	actor_state.conditions.sort()
	actor_state.revision += 1
	_state_revision += 1


func _remove_actor_condition(actor_state: CombatActorState, condition: String) -> void:
	var index := actor_state.conditions.find(condition)
	if index < 0:
		return
	actor_state.conditions.remove_at(index)
	actor_state.revision += 1
	_state_revision += 1


func _refresh_actor_timed_conditions(actor_state: CombatActorState) -> void:
	if actor_state.critical_stagger_until_us > 0 and clock.get_elapsed_us() >= actor_state.critical_stagger_until_us:
		actor_state.critical_stagger_until_us = 0
		_remove_actor_condition(actor_state, "critical_stagger")


func _is_actor_critically_staggered(actor_state: CombatActorState) -> bool:
	return actor_state.critical_stagger_until_us > clock.get_elapsed_us()


func _active_defenses_restricted(defender_state: CombatActorState) -> bool:
	return (
		defender_state.awareness != &"aware"
		or defender_state.conditions.has("surprised")
		or defender_state.conditions.has("unaware")
	)


func _get_dodge_stat_name(delivery_class: StringName) -> String:
	if delivery_class == &"hand_held":
		return "dt"
	if delivery_class == &"thrown":
		return "dp"
	return ""


func _get_actor_roll_bonus(definition: CombatActorDefinition) -> int:
	var value: Variant = definition.get_combat_stat("rb")
	return 0 if value == null else int(value)


func _release_waiting_dependents() -> void:
	var action_keys: Array = _actions.keys()
	action_keys.sort()
	for action_key: String in action_keys:
		var action: CombatActionInstance = _actions[action_key]
		if action.status != CombatActionInstance.STATUS_AWAITING_DEPENDENCIES:
			continue
		if action.finalization_scheduled or not _dependencies_are_terminal(action):
			continue
		action.finalization_scheduled = true
		_schedule_action_internal_event(action, clock.get_elapsed_us(), &"action_finalize_due")


func _dependencies_are_terminal(action: CombatActionInstance) -> bool:
	for dependency_id: String in action.dependency_action_ids:
		if not _actions.has(dependency_id) or not (_actions[dependency_id] as CombatActionInstance).is_terminal():
			return false
	return true


func _schedule_action_internal_event(action: CombatActionInstance, timestamp_us: int, event_type: StringName) -> void:
	schedule_event(
		timestamp_us,
		event_type,
		action.initiative,
		action.actor_id,
		&"",
		{"action_instance_id": action.action_instance_id},
		action.start_event_id
	)


func _record_resolved_event(
	timestamp_us: int,
	event_type: StringName,
	initiative: int,
	source_actor_id: StringName,
	target_actor_id: StringName,
	payload: Dictionary,
	parent_event_id: String = "",
	dependency_event_ids: PackedStringArray = PackedStringArray(),
	resource_commitments: Dictionary = {}
) -> CombatEvent:
	var event := _create_event(
		timestamp_us,
		event_type,
		initiative,
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		payload,
		resource_commitments
	)
	_resolved_events.append(event)
	return event


func _create_event(
	timestamp_us: int,
	event_type: StringName,
	initiative: int,
	source_actor_id: StringName,
	target_actor_id: StringName,
	parent_event_id: String,
	dependency_event_ids: PackedStringArray,
	payload: Dictionary,
	resource_commitments: Dictionary
) -> CombatEvent:
	var sequence := _next_sequence
	_next_sequence += 1
	return CombatEvent.new(
		_make_event_id(sequence),
		timestamp_us,
		initiative,
		sequence,
		event_type,
		source_actor_id,
		target_actor_id,
		parent_event_id,
		dependency_event_ids,
		payload,
		resource_commitments
	)


func _get_action_interval_timestamp(anchor_us: int, interval_index: int, at_value: int) -> int:
	assert(anchor_us >= 0, "Action timing anchors cannot be negative.")
	assert(interval_index > 0, "Action interval indexes must be positive.")
	assert(at_value > 0, "AT must be positive when scheduling an action interval.")
	var numerator := interval_index * CombatClock.ROUND_DURATION_US
	@warning_ignore("integer_division")
	return anchor_us + (numerator + at_value - 1) / at_value


func _opening_actor_precedes(left_key: String, right_key: String) -> bool:
	var left_state: CombatActorState = _actor_states[left_key]
	var right_state: CombatActorState = _actor_states[right_key]
	if left_state.opening_initiative_total != right_state.opening_initiative_total:
		return int(left_state.opening_initiative_total) > int(right_state.opening_initiative_total)
	var left_init := int((_actor_definitions[left_key] as CombatActorDefinition).get_combat_stat("init"))
	var right_init := int((_actor_definitions[right_key] as CombatActorDefinition).get_combat_stat("init"))
	if left_init != right_init:
		return left_init > right_init
	return left_key < right_key


func _can_begin_opening_action(actor_state: CombatActorState) -> bool:
	if not _combat_started or _opening_sequence_complete or actor_state.opening_action_declared:
		return true
	return actor_state.opening_order_rank == _current_opening_rank


func _mark_opening_action_declared(actor_state: CombatActorState, action_instance_id: String) -> void:
	if not _combat_started or actor_state.opening_action_declared:
		return
	actor_state.opening_action_declared = true
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(),
		&"opening_action_declared",
		_get_actor_initiative(String(actor_state.actor_id)),
		actor_state.actor_id,
		&"",
		{
			"action_instance_id": action_instance_id,
			"opening_order_rank": actor_state.opening_order_rank,
		}
	)
	while _current_opening_rank < _opening_rank_count:
		var rank_has_pending_actor := false
		for state_value: Variant in _actor_states.values():
			var state: CombatActorState = state_value
			if state.opening_order_rank == _current_opening_rank and not state.opening_action_declared:
				rank_has_pending_actor = true
				break
		if rank_has_pending_actor:
			break
		_current_opening_rank += 1
	if _current_opening_rank >= _opening_rank_count:
		_opening_sequence_complete = true


func _make_attack_instance_id(sequence: int) -> String:
	return "attack_%010d" % sequence


func _make_defense_resolution_id(sequence: int) -> String:
	return "defense_%010d" % sequence


func _make_damage_resolution_id(sequence: int) -> String:
	return "damage_%010d" % sequence


func _make_critical_record_id(sequence: int) -> String:
	return "critical_%010d" % sequence


func _get_actor_initiative(actor_key: String) -> int:
	if actor_key.is_empty() or not _actor_definitions.has(actor_key):
		return 0
	var value: Variant = (_actor_definitions[actor_key] as CombatActorDefinition).get_combat_stat("init")
	return 0 if value == null else int(value)


func _advance_clock_to(timestamp_us: int) -> void:
	clock.advance(timestamp_us - clock.get_elapsed_us())
	_refresh_actor_movement_budgets()
	for actor_state: CombatActorState in _actor_states.values():
		_refresh_actor_timed_conditions(actor_state)


func _refresh_actor_movement_budgets() -> void:
	var round_index := clock.get_round_index()
	var changed := false
	for actor_key: String in _actor_states:
		var actor_state: CombatActorState = _actor_states[actor_key]
		if actor_state.movement_round_index == round_index:
			continue
		actor_state.refresh_movement_budget(_actor_definitions[actor_key], round_index)
		changed = true
	if changed:
		_state_revision += 1


func _make_action_instance_id(sequence: int) -> String:
	return "action_%010d" % sequence


func _success(extra: Dictionary = {}) -> Dictionary:
	var result := {"success": true, "reason": ""}
	result.merge(extra, true)
	return result


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}


func _make_event_id(sequence: int) -> String:
	return "event_%010d" % sequence
