class_name CombatSimulation
extends RefCounted

const CriticalConsequenceCatalog = preload("res://scripts/combat/combat_critical_consequence_catalog.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
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
var _verified_special_damage_definitions: Dictionary = {}
var _deferred_critical_records_by_attack: Dictionary = {}
var _accepted_request_ids: Dictionary = {}
var _accepted_defense_request_ids: Dictionary = {}
var _accepted_damage_request_ids: Dictionary = {}
var _accepted_special_damage_request_ids: Dictionary = {}
var _processed_midnight_ids: Dictionary = {}
var _world_items: Dictionary = {}
var _thrown_weapon_context_by_attack_id: Dictionary = {}
var _resolved_events: Array = []
var _arena_wave_state: Dictionary = {}
var _combat_started: bool = false
var _opening_sequence_complete: bool = false
var _current_opening_rank: int = 0
var _opening_rank_count: int = 0
var _attack_final_line_of_sight_resolver: Callable
var _rage_knockback_resolver: Callable
var _special_touch_resolver: Callable
var _gatherable_material_resolver: Callable
var _world_item_landing_resolver: Callable
var _world_item_pickup_resolver: Callable
var _thrown_weapon_trajectory_resolver: Callable


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


func set_rage_knockback_resolver(resolver: Callable) -> void:
	_rage_knockback_resolver = resolver


func set_special_touch_resolver(resolver: Callable) -> void:
	_special_touch_resolver = resolver


func set_gatherable_material_resolver(resolver: Callable) -> void:
	_gatherable_material_resolver = resolver


func set_world_item_landing_resolver(resolver: Callable) -> void:
	_world_item_landing_resolver = resolver


func set_world_item_pickup_resolver(resolver: Callable) -> void:
	_world_item_pickup_resolver = resolver


func set_thrown_weapon_trajectory_resolver(resolver: Callable) -> void:
	_thrown_weapon_trajectory_resolver = resolver


func get_ability_payment_preview(actor_id: StringName, definition: CombatActionDefinition) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	return _validate_ability_activation(actor_state, definition)


func apply_authoritative_midnight_refresh(midnight_id: String) -> Dictionary:
	if midnight_id.is_empty():
		return _failure("midnight_id_required")
	if _processed_midnight_ids.has(midnight_id):
		return _failure("duplicate_midnight_refresh")
	_processed_midnight_ids[midnight_id] = true
	var refreshed: Array = []
	var actor_keys: Array = _actor_states.keys()
	actor_keys.sort()
	for actor_key: String in actor_keys:
		var state: CombatActorState = _actor_states[actor_key]
		if state.ability_daily_maxima.is_empty():
			continue
		var definition: CombatActorDefinition = _actor_definitions[actor_key]
		var daily_before := state.ability_daily_remaining.duplicate(true)
		var ap_before: Variant = state.resources.get("ap")
		state.ability_daily_remaining = state.ability_daily_maxima.duplicate(true)
		if definition.resource_maxima.has("ap"):
			state.resources["ap"] = int(definition.resource_maxima["ap"])
		state.revision += 1
		_state_revision += 1
		var payload := {
			"midnight_id": midnight_id,
			"daily_uses_before": daily_before,
			"daily_uses_after": state.ability_daily_remaining.duplicate(true),
			"ap_before": ap_before,
			"ap_after": state.resources.get("ap"),
		}
		_record_resolved_event(
			clock.get_elapsed_us(), &"ability_resources_midnight_refreshed",
			_get_actor_initiative(actor_key), state.actor_id, &"", payload
		)
		refreshed.append({"actor_id": actor_key, "resources": payload})
	return _success({"midnight_id": midnight_id, "refreshed_actors": refreshed})


func configure_actor_hand_occupancy(actor_id: StringName, assignments: Dictionary) -> Dictionary:
	if _combat_started:
		return _failure("combat_already_started")
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	var normalized := {"left": "", "right": ""}
	var assigned_items := {}
	for hand: Variant in assignments:
		var hand_name := String(hand)
		var equipment_ref := String(assignments[hand])
		if not normalized.has(hand_name):
			return _failure("invalid_hand")
		if equipment_ref.is_empty():
			continue
		if not actor_state.equipment_refs.has(equipment_ref):
			return _failure("equipment_not_available")
		if assigned_items.has(equipment_ref) and assignments.size() != 2:
			return _failure("equipment_assigned_to_multiple_hands")
		normalized[hand_name] = equipment_ref
		assigned_items[equipment_ref] = true
	actor_state.hand_occupancy = normalized
	actor_state.hand_occupancy_authoritative = true
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"actor_hand_occupancy_configured", _get_actor_initiative(String(actor_id)), actor_id, &"", {
		"hand_occupancy": normalized.duplicate(true),
	})
	return _success({"hand_occupancy": normalized.duplicate(true)})


func start_gather_material_action(
	actor_id: StringName,
	material_id: StringName,
	surface_id: String,
	request_id: String
) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if String(material_id).is_empty() or surface_id.is_empty():
		return _failure("gatherable_material_unverified")
	if _gatherable_material_resolver.is_valid() \
	and not bool(_gatherable_material_resolver.call(actor_id, material_id, surface_id)):
		return _failure("gatherable_material_unverified")
	if not String(actor_state.hand_occupancy.get("left", "")).is_empty():
		return _failure("left_hand_occupied")
	if int(actor_state.held_materials.get(String(material_id), 0)) > 0:
		return _failure("material_already_held")
	var definition := CombatActionDefinition.new(
		StringName("gather_material:%s" % String(material_id)), 1, true, true, {},
		{"gather_material": {"material_id": String(material_id), "surface_id": surface_id, "hand": "left"}},
		PackedStringArray(["Task 32D owner ruling: gathering source-verified dirt costs one completed Act and occupies the left hand"])
	)
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	var action := get_action(String(result["action_instance_id"]))
	action.execution_context = {"material_id": String(material_id), "surface_id": surface_id, "hand": "left"}
	action.revision += 1
	return result


func start_equip_hand_item_action(
	actor_id: StringName,
	equipment_ref: StringName,
	hand: StringName,
	request_id: String
) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	var hand_name := String(hand)
	if not ["left", "right"].has(hand_name):
		return _failure("invalid_hand")
	if not actor_state.equipment_refs.has(String(equipment_ref)):
		return _failure("equipment_not_available")
	if not String(actor_state.hand_occupancy.get(hand_name, "")).is_empty():
		return _failure("hand_occupied")
	for occupied_ref: Variant in actor_state.hand_occupancy.values():
		if String(occupied_ref) == String(equipment_ref):
			return _failure("equipment_already_in_hand")
	var definition := CombatActionDefinition.new(
		StringName("equip_hand_item:%s:%s" % [String(equipment_ref), hand_name]), 1, true, true, {},
		{"equip_hand_item": {"equipment_ref": String(equipment_ref), "hand": hand_name}},
		PackedStringArray(["Task 32D owner ruling: equipping a weapon or shield requires one completed Act"])
	)
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	var action := get_action(String(result["action_instance_id"]))
	action.execution_context = {"equipment_ref": String(equipment_ref), "hand": hand_name}
	action.revision += 1
	return result


func start_thrown_weapon_attack(
	attacker_id: StringName,
	target_id: StringName,
	definition: CombatAttackDefinition,
	request_id: String,
	target_location: StringName,
	authoritative_line_of_sight: Variant,
	required_hands: PackedStringArray,
	strength_requirement: int,
	source_ref: String
) -> Dictionary:
	if definition == null or definition.delivery_class != &"thrown" or definition.strikes_per_act != 1:
		return _failure("thrown_weapon_definition_invalid")
	if required_hands.is_empty() or required_hands.size() > 2 or strength_requirement < 0 or source_ref.is_empty():
		return _failure("thrown_weapon_requirements_unresolved")
	var actor_state := get_actor_state(attacker_id)
	var actor_definition := get_actor_definition(attacker_id)
	if actor_state == null or actor_definition == null:
		return _failure("unknown_attacker")
	if int(actor_definition.attributes.get("str", -1)) < strength_requirement:
		return _failure("equipment_strength_requirement_not_met")
	if not actor_state.hand_occupancy_authoritative:
		return _failure("thrown_weapon_hand_occupancy_unresolved")
	var normalized_hands := required_hands.duplicate()
	normalized_hands.sort()
	if normalized_hands.size() != required_hands.size():
		return _failure("thrown_weapon_hand_requirement_invalid")
	for hand: String in normalized_hands:
		if not ["left", "right"].has(hand):
			return _failure("thrown_weapon_hand_requirement_invalid")
		if String(actor_state.hand_occupancy.get(hand, "")) != String(definition.weapon_ref):
			return _failure("weapon_not_in_required_hand")
	for world_item: Dictionary in _world_items.values():
		if String(world_item.get("equipment_ref", "")) == String(definition.weapon_ref) \
		and String(world_item.get("state", "")) != "retrieved":
			return _failure("weapon_already_in_world")
	var result := start_physical_attack(
		attacker_id, target_id, definition, request_id, target_location,
		authoritative_line_of_sight
	)
	if not result.get("success", false):
		return result
	var attack_instance_id := String(result.get("attack_instance_id", ""))
	var world_item_id := "world_item:%s:%s" % [String(attacker_id), String(definition.weapon_ref)]
	_thrown_weapon_context_by_attack_id[attack_instance_id] = {
		"world_item_id": world_item_id,
		"equipment_ref": String(definition.weapon_ref),
		"owner_actor_id": String(attacker_id),
		"required_hands": Array(normalized_hands),
		"strength_requirement": strength_requirement,
		"source_ref": source_ref,
		"released": false,
	}
	_state_revision += 1
	result["world_item_id"] = world_item_id
	return result


func resolve_thrown_weapon_landing(
	attack_instance_id: String,
	position_microfeet: Vector2i,
	authoritative_source_ref: String,
	request_id: String
) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_request_ids.has(request_id):
		return _failure("duplicate_request")
	if authoritative_source_ref.is_empty():
		return _failure("thrown_weapon_landing_source_unresolved")
	if not _thrown_weapon_context_by_attack_id.has(attack_instance_id):
		return _failure("unknown_thrown_weapon_attack")
	var context: Dictionary = _thrown_weapon_context_by_attack_id[attack_instance_id]
	var world_item_id := String(context.get("world_item_id", ""))
	if not bool(context.get("released", false)) or not _world_items.has(world_item_id):
		return _failure("thrown_weapon_not_released")
	var world_item: Dictionary = _world_items[world_item_id]
	if String(world_item.get("state", "")) != "pending_landing":
		return _failure("thrown_weapon_landing_already_resolved")
	var attack: CombatAttackInstance = _attacks.get(attack_instance_id)
	if attack == null:
		return _failure("unknown_attack")
	if not [
		CombatAttackInstance.STATUS_MISSED,
		CombatAttackInstance.STATUS_DEFENDED,
		CombatAttackInstance.STATUS_DAMAGE_RESOLVED,
		CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED,
	].has(attack.status):
		return _failure("thrown_weapon_attack_not_terminal")
	var landing_validation := _validate_world_item_landing(world_item, position_microfeet)
	if not landing_validation.get("success", false):
		return landing_validation
	return _commit_thrown_weapon_landing(
		attack,
		world_item,
		position_microfeet,
		authoritative_source_ref,
		request_id,
		{"contact_kind": "externally_authoritative"},
		""
	)


func _commit_thrown_weapon_landing(
	attack: CombatAttackInstance,
	world_item: Dictionary,
	position_microfeet: Vector2i,
	authoritative_source_ref: String,
	request_id: String,
	landing_evidence: Dictionary,
	parent_event_id: String
) -> Dictionary:
	var world_item_id := String(world_item.get("world_item_id", ""))
	world_item["state"] = "dropped"
	world_item["position_microfeet"] = position_microfeet
	world_item["landing_outcome"] = attack.status
	world_item["landing_source_ref"] = authoritative_source_ref
	world_item["landing_evidence"] = landing_evidence.duplicate(true)
	world_item["revision"] = int(world_item.get("revision", 0)) + 1
	_world_items[world_item_id] = world_item
	_accepted_request_ids[request_id] = "world_item_landing:%s" % world_item_id
	_state_revision += 1
	var event := _record_resolved_event(
		clock.get_elapsed_us(), &"thrown_weapon_landed", _get_actor_initiative(String(attack.attacker_id)),
		attack.attacker_id, attack.target_id,
		{
			"attack_instance_id": attack.attack_instance_id,
			"world_item_id": world_item_id,
			"equipment_ref": world_item.get("equipment_ref", ""),
			"position_microfeet": [position_microfeet.x, position_microfeet.y],
			"landing_outcome": attack.status,
			"authoritative_source_ref": authoritative_source_ref,
			"landing_evidence": landing_evidence.duplicate(true),
			"request_id": request_id,
		}, attack.result_event_id if parent_event_id.is_empty() else parent_event_id
	)
	return _success({
		"world_item_id": world_item_id,
		"event_id": event.event_id,
		"position_microfeet": position_microfeet,
		"landing_evidence": landing_evidence.duplicate(true),
	})


func start_world_item_retrieval_action(
	actor_id: StringName,
	world_item_id: String,
	request_id: String
) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	var actor_definition := get_actor_definition(actor_id)
	if actor_state == null or actor_definition == null:
		return _failure("unknown_actor")
	if actor_state.current_hpc == null or int(actor_state.current_hpc) <= 0:
		return _failure("actor_not_eligible")
	if not _world_items.has(world_item_id):
		return _failure("unknown_world_item")
	var world_item: Dictionary = _world_items[world_item_id]
	if String(world_item.get("state", "")) != "dropped":
		return _failure("world_item_not_retrievable")
	if String(world_item.get("owner_actor_id", "")) != String(actor_id):
		return _failure("world_item_wrong_owner")
	if int(actor_definition.attributes.get("str", -1)) < int(world_item.get("strength_requirement", -1)):
		return _failure("equipment_strength_requirement_not_met")
	var prerequisites := _validate_world_item_retrieval_prerequisites(actor_state, world_item)
	if not prerequisites.get("success", false):
		return prerequisites
	var definition := CombatActionDefinition.new(
		StringName("retrieve_world_item:%s" % world_item_id), 1, true, true, {},
		{"retrieve_world_item": {"world_item_id": world_item_id}},
		PackedStringArray(["Task 35E owner-approved Arena rule: legal dropped-weapon retrieval and re-equipping cost one ordinary Act"])
	)
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	var action := get_action(String(result.get("action_instance_id", "")))
	action.execution_context = {"world_item_id": world_item_id}
	action.revision += 1
	return result


func get_world_item(world_item_id: String) -> Dictionary:
	if not _world_items.has(world_item_id):
		return {}
	return (_world_items[world_item_id] as Dictionary).duplicate(true)


func record_tactical_decision(actor_id: StringName, target_id: StringName, payload: Dictionary) -> CombatEvent:
	return _record_resolved_event(
		clock.get_elapsed_us(), &"tactical_action_selected", _get_actor_initiative(String(actor_id)),
		actor_id, target_id, payload.duplicate(true)
	)


func register_verified_special_damage_definition(
	special_id: StringName,
	special_field: StringName,
	source_ref: String
) -> Dictionary:
	var key := String(special_id)
	if key.is_empty() or String(special_field).is_empty() or source_ref.is_empty():
		return _failure("special_damage_definition_unresolved")
	var definition := {"special_id": key, "special_field": String(special_field), "source_ref": source_ref}
	if _verified_special_damage_definitions.has(key) and _verified_special_damage_definitions[key] != definition:
		return _failure("conflicting_special_damage_definition")
	_verified_special_damage_definitions[key] = definition
	_state_revision += 1
	return _success({"special_id": key})


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
	# Task 31E designer ruling: opening Initiative records priority but never
	# gates an actor's first legal declaration. INIT still orders genuinely
	# simultaneous queued effects through CombatEventQueue.
	_current_opening_rank = _opening_rank_count
	_opening_sequence_complete = true
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
	for dependency_id: String in dependency_action_ids:
		if not _actions.has(dependency_id):
			return _failure("unknown_dependency")
	if not actor_state.pending_called_shot.is_empty() \
	and String(definition.extension_metadata.get("kind", "")) != "physical_attack":
		var expired_preparation := actor_state.pending_called_shot.duplicate(true)
		actor_state.pending_called_shot.clear()
		actor_state.revision += 1
		_state_revision += 1
		_record_resolved_event(
			clock.get_elapsed_us(), &"called_shot_expired", _get_actor_initiative(actor_key), actor_id, &"",
			{
				"reason": "next_act_was_not_physical_attack",
				"prepared_target_actor_id": expired_preparation.get("target_actor_id", ""),
				"prepared_target_location": expired_preparation.get("target_location", ""),
			}, String(expired_preparation.get("source_event_id", ""))
		)

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
			"action_definition_id": definition_key,
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


func start_verified_timed_stat_effect_action(
	actor_id: StringName,
	definition: CombatActionDefinition,
	request_id: String
) -> Dictionary:
	if definition == null:
		return _failure("invalid_action_definition")
	var effect: Variant = definition.extension_metadata.get("timed_stat_effect")
	if typeof(effect) != TYPE_DICTIONARY:
		return _failure("timed_stat_effect_unresolved")
	var effect_definition: Dictionary = effect
	var effect_id := String(effect_definition.get("effect_id", ""))
	var duration_us := int(effect_definition.get("duration_us", 0))
	var modifiers: Variant = effect_definition.get("stat_modifiers")
	if effect_id.is_empty() or duration_us <= 0 or typeof(modifiers) != TYPE_DICTIONARY:
		return _failure("timed_stat_effect_invalid")
	for field_name: Variant in (modifiers as Dictionary):
		if not ["sb", "nal", "dt", "dp"].has(String(field_name)) or typeof((modifiers as Dictionary)[field_name]) != TYPE_INT:
			return _failure("timed_stat_modifier_invalid")
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if actor_state.timed_stat_effects.has(effect_id):
		return _failure("timed_stat_effect_already_active")
	for resource_name: Variant in definition.resource_commitments:
		var cost: Variant = definition.resource_commitments[resource_name]
		if typeof(cost) != TYPE_INT or int(cost) <= 0:
			return _failure("invalid_resource_commitment")
		if not actor_state.resources.has(resource_name) or int(actor_state.resources[resource_name]) < int(cost):
			return _failure("insufficient_committed_resource")
	var ability_payment := _validate_ability_activation(actor_state, definition)
	if not ability_payment.get("success", false):
		return ability_payment
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	for resource_name: Variant in definition.resource_commitments:
		actor_state.resources[resource_name] = int(actor_state.resources[resource_name]) - int(definition.resource_commitments[resource_name])
	var action := get_action(String(result["action_instance_id"]))
	if not definition.resource_commitments.is_empty():
		actor_state.revision += 1
		_state_revision += 1
		_record_resolved_event(
			clock.get_elapsed_us(),
			&"actor_resources_committed",
			action.initiative,
			actor_id,
			&"",
			{
				"action_instance_id": action.action_instance_id,
				"action_definition_id": String(action.action_definition_id),
				"resource_commitments": definition.resource_commitments.duplicate(true),
				"resources_after": actor_state.resources.duplicate(true),
			},
			action.start_event_id,
			PackedStringArray(),
			definition.resource_commitments
		)
	_commit_ability_activation(actor_state, action, definition, ability_payment)
	return result


func start_verified_special_action(
	actor_id: StringName,
	target_id: StringName,
	definition: CombatActionDefinition,
	request_id: String,
	target_location: StringName = &"",
	authoritative_touch: bool = false
) -> Dictionary:
	if definition == null:
		return _failure("invalid_action_definition")
	var special: Variant = definition.extension_metadata.get("verified_special")
	if typeof(special) != TYPE_DICTIONARY:
		return _failure("verified_special_unresolved")
	var special_definition: Dictionary = special
	var kind := String(special_definition.get("kind", ""))
	if not ["called_shot", "healing", "timed_stat_effect", "persistent_damage_shield"].has(kind):
		return _failure("verified_special_kind_unresolved")
	var actor_state := get_actor_state(actor_id)
	var target_state := get_actor_state(target_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if target_state == null:
		return _failure("unknown_target")
	if target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return _failure("target_not_eligible")
	var target_mode := String(special_definition.get("target_mode", ""))
	if target_mode == "self" and target_id != actor_id:
		return _failure("special_self_target_required")
	if target_mode == "other" and target_id == actor_id:
		return _failure("special_other_target_required")
	if target_mode == "self_or_touch" and target_id != actor_id \
	and not _is_special_touch_legal(actor_id, target_id, authoritative_touch):
		return _failure("special_touch_unverified")
	if kind == "called_shot" and HitLocations.get_by_id(target_location).is_empty():
		return _failure("illegal_target_location")
	if kind == "timed_stat_effect":
		var effect: Dictionary = definition.extension_metadata.get("timed_stat_effect", {})
		if effect.is_empty():
			return _failure("timed_stat_effect_unresolved")
		if target_state.timed_stat_effects.has(String(effect.get("effect_id", ""))):
			return _failure("timed_stat_effect_already_active")
	if kind == "persistent_damage_shield":
		var shield_id := String(special_definition.get("shield_id", ""))
		if shield_id.is_empty() or int(special_definition.get("capacity", 0)) <= 0:
			return _failure("persistent_damage_shield_unresolved")
		if target_state.persistent_damage_shields.has(shield_id):
			return _failure("persistent_damage_shield_already_active")
	var required_material := String(special_definition.get("requires_material", ""))
	if not required_material.is_empty():
		var held_count := int(actor_state.held_materials.get(required_material, 0))
		var held_in_left := String(actor_state.hand_occupancy.get("left", "")) == "material:%s" % required_material
		if held_count <= 0 or not held_in_left:
			return _failure("special_required_material_missing")
	for resource_name: Variant in definition.resource_commitments:
		var cost: Variant = definition.resource_commitments[resource_name]
		if typeof(cost) != TYPE_INT or int(cost) <= 0:
			return _failure("invalid_resource_commitment")
		if not actor_state.resources.has(resource_name) or int(actor_state.resources[resource_name]) < int(cost):
			return _failure("insufficient_committed_resource")
	var ability_payment := _validate_ability_activation(actor_state, definition)
	if not ability_payment.get("success", false):
		return ability_payment
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	var action := get_action(String(result["action_instance_id"]))
	action.execution_context = {
		"target_actor_id": String(target_id),
		"target_location": String(target_location),
		"authoritative_touch": authoritative_touch,
		"touch_required": target_mode == "self_or_touch" and target_id != actor_id,
		"required_material": required_material,
	}
	for resource_name: Variant in definition.resource_commitments:
		actor_state.resources[resource_name] = int(actor_state.resources[resource_name]) - int(definition.resource_commitments[resource_name])
	action.revision += 1
	if not definition.resource_commitments.is_empty():
		actor_state.revision += 1
		_state_revision += 1
		_record_resolved_event(
			clock.get_elapsed_us(), &"actor_resources_committed", action.initiative, actor_id, target_id,
			{
				"action_instance_id": action.action_instance_id,
				"action_definition_id": String(action.action_definition_id),
				"resource_commitments": definition.resource_commitments.duplicate(true),
				"resources_after": actor_state.resources.duplicate(true),
				"special_kind": kind,
			},
			action.start_event_id, PackedStringArray(), definition.resource_commitments
		)
	_commit_ability_activation(actor_state, action, definition, ability_payment)
	return result


func start_verified_consumable_healing_action(
	actor_id: StringName,
	definition: CombatActionDefinition,
	request_id: String
) -> Dictionary:
	if definition == null:
		return _failure("invalid_action_definition")
	var consumable: Variant = definition.extension_metadata.get("verified_consumable")
	if typeof(consumable) != TYPE_DICTIONARY:
		return _failure("verified_consumable_unresolved")
	var consumable_definition: Dictionary = consumable
	if String(consumable_definition.get("kind", "")) != "healing" \
	or String(consumable_definition.get("inventory_id", "")).is_empty() \
	or int(consumable_definition.get("dice_count", 0)) <= 0 \
	or int(consumable_definition.get("die_sides", 0)) <= 0:
		return _failure("verified_consumable_invalid")
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if actor_state.current_hpc == null or int(actor_state.current_hpc) <= 0:
		return _failure("actor_not_eligible")
	var inventory_id := String(consumable_definition["inventory_id"])
	if int(actor_state.inventory_quantities.get(inventory_id, 0)) <= 0:
		return _failure("consumable_unavailable")
	if bool(consumable_definition.get("requires_free_hand", false)):
		if not actor_state.hand_occupancy_authoritative:
			return _failure("consumable_hand_occupancy_unresolved")
		if not _actor_has_free_hand(actor_state):
			return _failure("consumable_free_hand_required")
	var result := start_action(actor_id, definition, request_id)
	if not result.get("success", false):
		return result
	var action := get_action(String(result["action_instance_id"]))
	action.execution_context = {
		"inventory_id": inventory_id,
		"requires_free_hand": bool(consumable_definition.get("requires_free_hand", false)),
	}
	action.revision += 1
	return result


func start_nac_projectile_special(
	actor_id: StringName,
	target_id: StringName,
	definition: CombatAttackDefinition,
	request_id: String,
	special_id: StringName,
	mana_cost: int,
	target_location: StringName = &"torso",
	authoritative_line_of_sight: Variant = null,
	automatic_activation: bool = false,
	perceived_danger: bool = false
) -> Dictionary:
	if not _combat_started:
		return _failure("opening_initiative_unresolved")
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_request_ids.has(request_id):
		return _failure("duplicate_request")
	if definition == null or definition.delivery_class != &"magic_projectile" \
	or definition.strikes_per_act != 1 or String(special_id).is_empty() or mana_cost <= 0:
		return _failure("nac_projectile_definition_invalid")
	var actor_state := get_actor_state(actor_id)
	var target_state := get_actor_state(target_id)
	var actor_definition := get_actor_definition(actor_id)
	var target_definition := get_actor_definition(target_id)
	if actor_state == null or actor_definition == null:
		return _failure("unknown_actor")
	if target_state == null or target_definition == null:
		return _failure("unknown_target")
	if actor_id == target_id:
		return _failure("self_target_not_allowed")
	if int(actor_state.current_hpc) <= 0:
		return _failure("attacker_not_eligible")
	if int(target_state.current_hpc) <= 0:
		return _failure("target_not_eligible")
	if automatic_activation and not perceived_danger:
		return _failure("automatic_nac_danger_not_perceived")
	if actor_state.awareness != &"aware":
		return _failure("attacker_unaware")
	if not actor_state.equipment_refs.has(String(definition.weapon_ref)):
		return _failure("casting_focus_not_equipped")
	if actor_state.hand_occupancy_authoritative \
	and not actor_state.hand_occupancy.values().has(String(definition.weapon_ref)):
		return _failure("casting_focus_not_in_hand")
	if int(actor_state.resources.get("mana", 0)) < mana_cost:
		return _failure("insufficient_mana")
	var round_index := clock.get_round_index()
	var uses_this_round := actor_state.nac_uses_this_round if actor_state.nac_round_index == round_index else 0
	if uses_this_round >= 5:
		return _failure("nac_round_cap_reached")
	if automatic_activation:
		var settings: Dictionary = actor_state.nac_automation_settings
		if not bool(settings.get("automatic_enabled", false)):
			return _failure("automatic_nac_disabled")
		if int(actor_state.resources.get("mana", 0)) - mana_cost < int(settings.get("minimum_mana_reserve", 0)):
			return _failure("automatic_nac_mana_reserve")
		var automatic_budget := mini(int(settings.get("automatic_nac_budget", 5)), 5)
		var automatic_uses := actor_state.automatic_nac_uses_this_round if actor_state.nac_round_index == round_index else 0
		if automatic_uses >= automatic_budget:
			return _failure("automatic_nac_budget_reached")
	var resolved_location := &"torso" if String(target_location).is_empty() else target_location
	if not definition.allowed_target_locations.has(String(resolved_location)):
		return _failure("illegal_target_location")
	var location_context := _resolve_location_acc_context(definition, actor_definition, target_definition, resolved_location)
	if not location_context.get("success", false):
		return _failure(String(location_context.get("reason", "unresolved_location_acc_modifier")))
	var offset := target_state.position_microfeet - actor_state.position_microfeet
	var elevation_offset := target_state.elevation_microfeet - actor_state.elevation_microfeet
	var distance_squared := offset.x * offset.x + offset.y * offset.y + elevation_offset * elevation_offset
	var maximum_range := int(definition.maximum_range_microfeet)
	if distance_squared > maximum_range * maximum_range:
		return _failure("target_out_of_range")
	if definition.requires_line_of_sight and authoritative_line_of_sight != true:
		return _failure("line_of_sight_unverified")
	var ss_value: Variant = actor_definition.get_combat_stat("ss")
	if ss_value == null:
		return _failure("special_skill_unresolved")
	var definition_key := String(definition.attack_definition_id)
	if _attack_definitions.has(definition_key) \
	and (_attack_definitions[definition_key] as CombatAttackDefinition).to_dictionary() != definition.to_dictionary():
		return _failure("conflicting_attack_definition")
	_attack_definitions[definition_key] = definition
	actor_state.resources["mana"] = int(actor_state.resources["mana"]) - mana_cost
	if actor_state.nac_round_index != round_index:
		actor_state.nac_round_index = round_index
		actor_state.nac_uses_this_round = 0
		actor_state.automatic_nac_uses_this_round = 0
	actor_state.nac_uses_this_round += 1
	if automatic_activation:
		actor_state.automatic_nac_uses_this_round += 1
	actor_state.revision += 1
	_state_revision += 1
	var committed := _record_resolved_event(clock.get_elapsed_us(), &"nac_special_committed", _get_actor_initiative(String(actor_id)), actor_id, target_id, {
		"special_id": String(special_id),
		"mana_cost": mana_cost,
		"mana_after": int(actor_state.resources["mana"]),
		"ordinary_acts_spent": 0,
		"nac_round_index": round_index,
		"nac_uses_this_round": actor_state.nac_uses_this_round,
		"nac_round_cap": 5,
		"automatic_activation": automatic_activation,
		"request_id": request_id,
	}, "", PackedStringArray(), {"mana": mana_cost})
	var natural_ss := roll_int(1, 20)
	var roll_bonus := _get_actor_roll_bonus(actor_definition)
	var adjusted_ss := natural_ss - roll_bonus
	var ss_success := adjusted_ss <= int(ss_value)
	var ss_event := _record_resolved_event(clock.get_elapsed_us(), &"special_skill_resolved", _get_actor_initiative(String(actor_id)), actor_id, target_id, {
		"special_id": String(special_id), "ss_target": int(ss_value), "natural_d20": natural_ss,
		"roll_bonus": roll_bonus, "adjusted_roll": adjusted_ss, "success": ss_success,
		"rng_draw_index": random.get_draw_count(),
	}, committed.event_id)
	_accepted_request_ids[request_id] = ss_event.event_id
	if not ss_success:
		return _success({"special_success": false, "reason": "special_skill_failed", "event_id": ss_event.event_id})
	var attack_instance_id := _make_attack_instance_id(_next_attack_sequence)
	_next_attack_sequence += 1
	var attack := CombatAttackInstance.new(
		attack_instance_id, definition, "", actor_id, target_id, resolved_location,
		clock.get_elapsed_us(), int(actor_definition.get_combat_stat("acc")), int(location_context["location_acc_modifier"]),
		roll_bonus, false, StringName(location_context.get("size_relationship", "")),
		StringName(location_context.get("attacker_size_category", "")), StringName(location_context.get("target_size_category", "")),
		int(location_context.get("tiny_target_dodge_bonus", 0))
	)
	attack.is_special_attack = true
	attack.special_id = special_id
	attack.special_knockback_microfeet = 2_000_000
	attack.declared_attacker_position_microfeet = actor_state.position_microfeet
	attack.declared_target_position_microfeet = target_state.position_microfeet
	attack.declared_attacker_elevation_microfeet = actor_state.elevation_microfeet
	attack.declared_target_elevation_microfeet = target_state.elevation_microfeet
	attack.declaration_line_of_sight_verified = authoritative_line_of_sight
	_attacks[attack_instance_id] = attack
	_state_revision += 1
	var declared := _record_resolved_event(clock.get_elapsed_us(), &"special_attack_declared", _get_actor_initiative(String(actor_id)), actor_id, target_id, {
		"attack_instance_id": attack_instance_id, "special_id": String(special_id),
		"target_location": String(resolved_location), "weapon_ref": String(attack.weapon_ref),
		"ordinary_acts_spent": 0, "automatic_activation": automatic_activation,
	}, ss_event.event_id)
	_resolve_instant_special_accuracy(attack, definition, declared.event_id)
	return _success({"special_success": true, "attack_instance_id": attack_instance_id, "event_id": attack.result_event_id})


func start_physical_attack(
	attacker_id: StringName,
	target_id: StringName,
	definition: CombatAttackDefinition,
	request_id: String,
	target_location: StringName = &"torso",
	authoritative_line_of_sight: Variant = null,
	dependency_action_ids: PackedStringArray = PackedStringArray(),
	is_back_attack: bool = false,
	nac_attack_context: Dictionary = {}
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
	var nac_validation := _validate_nac_attack_context(attacker_state, nac_attack_context)
	if not nac_validation.get("success", false):
		return nac_validation
	for strike_index in range(1, definition.strikes_per_act + 1):
		var strike_profile := definition.get_strike_profile(strike_index)
		var strike_weapon_ref := String(strike_profile.get("weapon_ref", String(definition.weapon_ref)))
		if definition.requires_equipped_weapon and not attacker_state.equipment_refs.has(strike_weapon_ref):
			return _failure("weapon_not_equipped")
		if definition.requires_hand_occupancy and attacker_state.hand_occupancy_authoritative \
		and not attacker_state.hand_occupancy.values().has(strike_weapon_ref):
			return _failure("weapon_not_in_hand")
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
	var target_definition: CombatActorDefinition = _actor_definitions[target_key]
	var location_context := _resolve_location_acc_context(definition, attacker_definition, target_definition, resolved_location)
	if not location_context.get("success", false):
		return _failure(String(location_context.get("reason", "unresolved_location_acc_modifier")))
	var location_modifier: int = int(location_context["location_acc_modifier"])
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
		var elevation_offset := target_state.elevation_microfeet - attacker_state.elevation_microfeet
		var declaration_distance_squared := declaration_offset.x * declaration_offset.x + declaration_offset.y * declaration_offset.y + elevation_offset * elevation_offset
		var minimum_range := 0 if definition.minimum_range_microfeet == null else int(definition.minimum_range_microfeet)
		var maximum_range := int(definition.maximum_range_microfeet)
		if declaration_distance_squared < minimum_range * minimum_range or declaration_distance_squared > maximum_range * maximum_range:
			return _failure("target_out_of_range")

	var definition_key := String(definition.attack_definition_id)
	var pending_called_shot: Dictionary = attacker_state.pending_called_shot.duplicate(true)
	var called_shot_matches: bool = not pending_called_shot.is_empty() \
		and String(pending_called_shot.get("target_actor_id", "")) == target_key \
		and String(pending_called_shot.get("target_location", "")) == String(resolved_location)
	if _attack_definitions.has(definition_key):
		if (_attack_definitions[definition_key] as CombatAttackDefinition).to_dictionary() != definition.to_dictionary():
			return _failure("conflicting_attack_definition")
	var action_result := start_action(attacker_id, definition.to_action_definition(), request_id, dependency_action_ids)
	if not action_result["success"]:
		return action_result
	if not _attack_definitions.has(definition_key):
		_attack_definitions[definition_key] = definition
	var action_instance_id: String = action_result["action_instance_id"]
	var declared_offset := target_state.position_microfeet - attacker_state.position_microfeet
	var declared_elevation_offset := target_state.elevation_microfeet - attacker_state.elevation_microfeet
	var distance_squared := declared_offset.x * declared_offset.x + declared_offset.y * declared_offset.y + declared_elevation_offset * declared_elevation_offset
	var attack_instance_ids: Array[String] = []
	for strike_index in range(1, definition.strikes_per_act + 1):
		var attack_instance_id := _make_attack_instance_id(_next_attack_sequence)
		_next_attack_sequence += 1
		var attack := CombatAttackInstance.new(
			attack_instance_id, definition, action_instance_id, attacker_id, target_id,
			resolved_location, clock.get_elapsed_us(), int(base_acc_value), location_modifier,
			roll_bonus, is_back_attack,
			StringName(location_context.get("size_relationship", "")),
			StringName(location_context.get("attacker_size_category", "")),
			StringName(location_context.get("target_size_category", "")),
			int(location_context.get("tiny_target_dodge_bonus", 0)), strike_index, definition.strikes_per_act
		)
		attack.declared_attacker_position_microfeet = attacker_state.position_microfeet
		attack.declared_target_position_microfeet = target_state.position_microfeet
		attack.declared_attacker_elevation_microfeet = attacker_state.elevation_microfeet
		attack.declared_target_elevation_microfeet = target_state.elevation_microfeet
		attack.declaration_line_of_sight_verified = authoritative_line_of_sight
		var strike_profile := definition.get_strike_profile(strike_index)
		if not strike_profile.is_empty():
			attack.strike_label = String(strike_profile["label"])
			attack.damage_dice_count_override = int(strike_profile["dice_count"])
			attack.damage_die_sides_override = int(strike_profile["die_sides"])
			attack.damage_types = PackedStringArray(strike_profile.get("damage_types", Array(definition.damage_types)))
			attack.weapon_ref = StringName(strike_profile.get("weapon_ref", String(definition.weapon_ref)))
			attack.minimum_range_microfeet_override = strike_profile.get("minimum_range_microfeet", definition.minimum_range_microfeet)
			attack.maximum_range_microfeet_override = strike_profile.get("maximum_range_microfeet", definition.maximum_range_microfeet)
			attack.flat_bonus_override = strike_profile.get("flat_bonus", null)
			attack.strength_bonus_eligible_override = strike_profile.get("strength_bonus_eligible", null)
		if not nac_attack_context.is_empty():
			attack.consequence_damage_multipliers.append((nac_attack_context["damage_multiplier"] as Dictionary).duplicate(true))
		if called_shot_matches:
			attack.automatic_accuracy_reason = "called_shot"
		_attacks[attack_instance_id] = attack
		attack_instance_ids.append(attack_instance_id)
		_record_resolved_event(
			clock.get_elapsed_us(), &"physical_attack_declared", _get_actor_initiative(attacker_key), attacker_id, target_id,
			{
				"attack_instance_id": attack_instance_id, "action_instance_id": action_instance_id,
				"attack_definition_id": definition_key, "weapon_ref": String(attack.weapon_ref),
				"target_location": String(resolved_location), "size_relationship": String(attack.size_relationship),
				"attacker_size_category": String(attack.attacker_size_category), "target_size_category": String(attack.target_size_category),
				"tiny_target_dodge_bonus": attack.tiny_target_dodge_bonus, "location_acc_modifier": attack.location_acc_modifier,
				"acc_target": attack.acc_target, "distance_squared_microfeet": distance_squared, "request_id": request_id,
				"delivery_class": String(attack.delivery_class), "damage_types": Array(attack.damage_types),
				"physical_soak_eligible": definition.physical_soak_eligible, "is_back_attack": is_back_attack,
				"strike_index": strike_index, "strikes_per_act": definition.strikes_per_act,
				"strike_label": attack.strike_label,
				"nac_ability_id": String(nac_attack_context.get("ability_id", "")),
			}
		)
	_attack_by_action_id[action_instance_id] = attack_instance_ids
	if not nac_attack_context.is_empty():
		_commit_nac_attack_context(attacker_state, attacker_id, target_id, action_instance_id, attack_instance_ids, nac_attack_context)
	if not pending_called_shot.is_empty():
		attacker_state.pending_called_shot.clear()
		attacker_state.revision += 1
		_record_resolved_event(
			clock.get_elapsed_us(), &"called_shot_consumed", _get_actor_initiative(attacker_key), attacker_id, target_id,
			{
				"action_instance_id": action_instance_id,
				"prepared_target_actor_id": pending_called_shot.get("target_actor_id", ""),
				"prepared_target_location": pending_called_shot.get("target_location", ""),
				"applied_to_attack": called_shot_matches,
				"applied_strike_count": definition.strikes_per_act if called_shot_matches else 0,
			},
			String(pending_called_shot.get("source_event_id", ""))
		)
	_state_revision += 1
	return _success({"attack_instance_id": attack_instance_ids[0], "attack_instance_ids": attack_instance_ids, "action_instance_id": action_instance_id})


func _resolve_location_acc_context(
	definition: CombatAttackDefinition,
	attacker_definition: CombatActorDefinition,
	target_definition: CombatActorDefinition,
	target_location: StringName
) -> Dictionary:
	if not definition.uses_size_based_location_acc:
		var static_modifier: Variant = definition.get_location_acc_modifier(target_location)
		if static_modifier == null:
			return {"success": false, "reason": "unresolved_location_acc_modifier"}
		return {
			"success": true,
			"location_acc_modifier": int(static_modifier),
			"size_relationship": "",
			"attacker_size_category": "",
			"target_size_category": "",
			"tiny_target_dodge_bonus": 0,
		}
	if attacker_definition.size_category.is_empty():
		return {"success": false, "reason": "unresolved_attacker_size_category"}
	if target_definition.size_category.is_empty():
		return {"success": false, "reason": "unresolved_target_size_category"}
	var profile := HitLocations.resolve_attack_profile(attacker_definition.size_category, target_definition.size_category)
	if not profile.get("success", false):
		return {"success": false, "reason": String(profile.get("reason", "unsupported_size_relationship"))}
	if not (profile.get("allowed_target_locations", PackedStringArray()) as PackedStringArray).has(String(target_location)):
		return {"success": false, "reason": "unresolved_location_acc_modifier"}
	var modifier: Variant = (profile.get("acc_modifiers_by_location", {}) as Dictionary).get(String(target_location))
	if modifier == null:
		return {"success": false, "reason": "unresolved_location_acc_modifier"}
	return {
		"success": true,
		"location_acc_modifier": int(modifier),
		"size_relationship": String(profile.get("size_relationship", "")),
		"attacker_size_category": String(profile.get("attacker_size", "")),
		"target_size_category": String(profile.get("target_size", "")),
		"tiny_target_dodge_bonus": int(profile.get("tiny_target_dodge_bonus", 0)),
	}


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
	if _committed_multistrike_target_is_incapacitated(attack, defender_state):
		return _exhaust_defenses_for_incapacitated_target(attack, request_id)
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
		var trajectory_outcome := "miss" if resolution.successful_defense_type == CombatDefenseProfile.DODGE else "blocked"
		_resolve_automatic_thrown_weapon_landing(attack, trajectory_outcome, resolved.event_id)
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


func _committed_multistrike_target_is_incapacitated(
	attack: CombatAttackInstance,
	defender_state: CombatActorState
) -> bool:
	return not attack.is_special_attack \
		and not attack.action_instance_id.is_empty() \
		and attack.strikes_per_act > 1 \
		and attack.strike_index > 1 \
		and defender_state.current_hpc != null \
		and int(defender_state.current_hpc) <= 0 \
		and _prior_committed_strike_established_incapacitation(attack)


func _prior_committed_strike_established_incapacitation(attack: CombatAttackInstance) -> bool:
	for prior_attack_id: String in _get_linked_attack_instance_ids(attack.action_instance_id):
		var prior_attack: CombatAttackInstance = _attacks.get(prior_attack_id)
		if prior_attack == null \
		or prior_attack.target_id != attack.target_id \
		or prior_attack.strike_index >= attack.strike_index \
		or prior_attack.status != CombatAttackInstance.STATUS_DAMAGE_RESOLVED \
		or prior_attack.damage_resolution_id.is_empty():
			continue
		var damage_resolution: CombatDamageResolution = _damage_resolutions.get(prior_attack.damage_resolution_id)
		if damage_resolution != null \
		and damage_resolution.hpc_before > 0 \
		and damage_resolution.hpc_after <= 0:
			return true
	return false


func _exhaust_defenses_for_incapacitated_target(
	attack: CombatAttackInstance,
	request_id: String
) -> Dictionary:
	var defender_key := String(attack.target_id)
	var profile: CombatDefenseProfile = _defense_profiles[defender_key]
	var defense_resolution_id := _make_defense_resolution_id(_next_defense_sequence)
	_next_defense_sequence += 1
	var resolution := CombatDefenseResolution.new(
		defense_resolution_id,
		attack.attack_instance_id,
		attack.target_id,
		profile,
		clock.get_elapsed_us(),
		request_id
	)
	resolution.status = CombatDefenseResolution.STATUS_EXHAUSTED
	resolution.resolved_at_us = clock.get_elapsed_us()
	resolution.revision += 1
	_defense_resolutions[defense_resolution_id] = resolution
	_defense_by_attack_id[attack.attack_instance_id] = defense_resolution_id
	_accepted_defense_request_ids[request_id] = defense_resolution_id
	attack.defense_resolution_id = defense_resolution_id
	attack.status = CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED
	attack.revision += 1
	_state_revision += 1
	var resolved := _record_resolved_event(
		clock.get_elapsed_us(),
		&"physical_defense_skipped_incapacitated",
		_get_actor_initiative(defender_key),
		attack.target_id,
		attack.attacker_id,
		{
			"defense_resolution_id": defense_resolution_id,
			"attack_instance_id": attack.attack_instance_id,
			"action_instance_id": attack.action_instance_id,
			"status": resolution.status,
			"reason": "target_incapacitated_after_committed_prior_strike",
			"attempt_count": 0,
			"strike_index": attack.strike_index,
			"strikes_per_act": attack.strikes_per_act,
			"damage_applied": false,
		},
		attack.result_event_id
	)
	resolution.start_event_id = resolved.event_id
	resolution.final_event_id = resolved.event_id
	return _success({
		"defense_resolution_id": defense_resolution_id,
		"status": resolution.status,
		"reason": "target_incapacitated_after_committed_prior_strike",
	})


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
	_resolve_automatic_thrown_weapon_landing(attack, "miss", event.event_id)
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
	resolution.flat_bonus = int(preparation["flat_bonus"])
	resolution.strength_bonus = preparation["strength_bonus"]
	var damage_dice_count := int(preparation["damage_dice_count"])
	var damage_die_sides := int(preparation["damage_die_sides"])
	for _die_index in range(damage_dice_count):
		var die_result := roll_int(1, damage_die_sides)
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
	var shield_result := _absorb_with_persistent_damage_shield(target_state, resolution.final_damage)
	resolution.protective_points_absorbed = int(shield_result.get("absorbed", 0))
	resolution.protective_points_remaining = int(shield_result.get("remaining", 0))
	resolution.final_damage = int(shield_result.get("unabsorbed", resolution.final_damage))
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
			"pre_multiplier_total": resolution.pre_multiplier_total,
			"combined_multiplier_numerator": resolution.combined_multiplier_numerator,
			"combined_multiplier_denominator": resolution.combined_multiplier_denominator,
			"multiplied_total": resolution.multiplied_total,
			"armor_tal": resolution.armor_tal,
			"natural_armor_level": resolution.natural_armor_level,
			"protective_points_absorbed": resolution.protective_points_absorbed,
			"protective_points_remaining": resolution.protective_points_remaining,
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
	if resolution.protective_points_absorbed > 0:
		_record_resolved_event(clock.get_elapsed_us(), &"persistent_damage_shield_absorbed", _get_actor_initiative(String(attack.target_id)), attack.target_id, attack.attacker_id, {
			"attack_instance_id": attack_instance_id,
			"shield_id": String(shield_result.get("shield_id", "")),
			"absorbed": resolution.protective_points_absorbed,
			"remaining": resolution.protective_points_remaining,
			"depleted": bool(shield_result.get("depleted", false)),
		}, event.event_id)
		_apply_force_shield_attacker_knockback(attack, int(shield_result.get("knockback_microfeet", 0)), event.event_id)
	if resolution.final_damage > 0:
		_schedule_special_interruption_for_physical_hit(attack.target_id, attack.attacker_id, event.event_id)
		_apply_successful_hit_knockback(attack, event.event_id)
	_resolve_automatic_thrown_weapon_landing(attack, "hit", event.event_id)
	_finalize_deferred_critical_consequences(attack)
	return _success({"damage_resolution_id": resolution_id, "final_damage": resolution.final_damage})


func _absorb_with_persistent_damage_shield(target_state: CombatActorState, incoming_damage: int) -> Dictionary:
	if incoming_damage <= 0 or target_state.persistent_damage_shields.is_empty():
		return {"absorbed": 0, "remaining": 0, "unabsorbed": incoming_damage, "depleted": false}
	var shield_ids: Array = target_state.persistent_damage_shields.keys()
	shield_ids.sort()
	var shield_id := String(shield_ids[0])
	var shield: Dictionary = target_state.persistent_damage_shields[shield_id]
	var capacity := int(shield.get("capacity", 0))
	var absorbed := mini(incoming_damage, capacity)
	var remaining := capacity - absorbed
	shield["capacity"] = remaining
	if remaining <= 0:
		target_state.persistent_damage_shields.erase(shield_id)
	else:
		target_state.persistent_damage_shields[shield_id] = shield
	target_state.revision += 1
	_state_revision += 1
	return {
		"shield_id": shield_id, "absorbed": absorbed, "remaining": remaining,
		"unabsorbed": incoming_damage - absorbed, "depleted": remaining <= 0,
		"knockback_microfeet": int(shield.get("physical_attacker_knockback_microfeet", 0)),
	}


func _apply_force_shield_attacker_knockback(attack: CombatAttackInstance, knockback_microfeet: int, parent_event_id: String) -> void:
	if knockback_microfeet <= 0 or not _rage_knockback_resolver.is_valid():
		return
	var attacker_state := get_actor_state(attack.attacker_id)
	if attacker_state == null:
		return
	var start := attacker_state.position_microfeet
	var result: Variant = _rage_knockback_resolver.call(attack.target_id, attack.attacker_id, knockback_microfeet)
	if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).get("success", false):
		return
	var destination: Vector2i = (result as Dictionary).get("position_microfeet", start)
	if destination != start:
		apply_authoritative_forced_position(attack.attacker_id, destination, int((result as Dictionary).get("facing_millidegrees", attacker_state.facing_millidegrees)), parent_event_id, "force_shield_knockback")
	_record_resolved_event(clock.get_elapsed_us(), &"force_shield_knockback_resolved", _get_actor_initiative(String(attack.target_id)), attack.target_id, attack.attacker_id, {
		"attack_instance_id": attack.attack_instance_id,
		"requested_distance_microfeet": knockback_microfeet,
		"start_microfeet": [start.x, start.y], "position_microfeet": [destination.x, destination.y],
		"resolved_distance_microfeet": roundi(Vector2(destination - start).length()),
	}, parent_event_id)


func resolve_nac_projectile_damage(attack_instance_id: String, request_id: String) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_special_damage_request_ids.has(request_id):
		return _failure("duplicate_special_damage_request")
	var attack := get_attack(attack_instance_id)
	if attack == null:
		return _failure("unknown_attack")
	if not attack.is_special_attack or attack.special_id != &"force_bolt":
		return _failure("unsupported_nac_projectile")
	if attack.status != CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED:
		return _failure("attack_not_damage_eligible")
	var target_state := get_actor_state(attack.target_id)
	if target_state == null or target_state.current_hpc == null:
		return _failure("target_hpc_unresolved")
	var damage_roll := roll_int(1, 6)
	var hpc_before := int(target_state.current_hpc)
	target_state.current_hpc = hpc_before - damage_roll
	target_state.revision += 1
	attack.status = CombatAttackInstance.STATUS_DAMAGE_RESOLVED
	attack.revision += 1
	_accepted_special_damage_request_ids[request_id] = attack_instance_id
	_state_revision += 1
	var parent_event_id := attack.result_event_id
	if not attack.defense_resolution_id.is_empty() and _defense_resolutions.has(attack.defense_resolution_id):
		parent_event_id = (_defense_resolutions[attack.defense_resolution_id] as CombatDefenseResolution).final_event_id
	var event := _record_resolved_event(clock.get_elapsed_us(), &"force_bolt_damage_resolved", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
		"attack_instance_id": attack_instance_id, "special_id": String(attack.special_id),
		"damage_roll": damage_roll, "rng_draw_index": random.get_draw_count(),
		"final_damage": damage_roll, "hpc_before": hpc_before,
		"hpc_after": int(target_state.current_hpc), "damage_applied": true,
	}, parent_event_id, PackedStringArray(), {"hpc": damage_roll})
	_apply_special_projectile_knockback(attack, event.event_id)
	_schedule_nac_physical_action_interruption(attack, event.event_id)
	return _success({"final_damage": damage_roll, "event_id": event.event_id})


func _apply_special_projectile_knockback(attack: CombatAttackInstance, parent_event_id: String) -> void:
	if attack.special_knockback_microfeet <= 0 or not _rage_knockback_resolver.is_valid():
		return
	var target_state := get_actor_state(attack.target_id)
	if target_state == null:
		return
	var start := target_state.position_microfeet
	var result: Variant = _rage_knockback_resolver.call(attack.attacker_id, attack.target_id, attack.special_knockback_microfeet)
	if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).get("success", false):
		return
	var destination: Vector2i = (result as Dictionary).get("position_microfeet", start)
	if destination != start:
		apply_authoritative_forced_position(attack.target_id, destination, int((result as Dictionary).get("facing_millidegrees", target_state.facing_millidegrees)), parent_event_id, "force_bolt_knockback")
	_record_resolved_event(clock.get_elapsed_us(), &"force_bolt_knockback_resolved", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
		"attack_instance_id": attack.attack_instance_id,
		"requested_distance_microfeet": attack.special_knockback_microfeet,
		"start_microfeet": [start.x, start.y], "position_microfeet": [destination.x, destination.y],
		"resolved_distance_microfeet": roundi(Vector2(destination - start).length()),
	}, parent_event_id)


func _schedule_nac_physical_action_interruption(attack: CombatAttackInstance, parent_event_id: String) -> void:
	var target_state := get_actor_state(attack.target_id)
	if target_state == null or target_state.current_action_instance_id.is_empty():
		return
	var action := get_action(target_state.current_action_instance_id)
	if action == null or action.is_terminal():
		return
	var action_definition: CombatActionDefinition = _action_definitions.get(String(action.action_definition_id))
	if action_definition == null or String(action_definition.extension_metadata.get("kind", "")) != "physical_attack":
		return
	var attacker_definition := get_actor_definition(attack.attacker_id)
	var target_definition := get_actor_definition(attack.target_id)
	if attacker_definition == null or target_definition == null:
		return
	var attacker_size_rank := _size_category_rank(attacker_definition.size_category)
	var target_size_rank := _size_category_rank(target_definition.size_category)
	if attacker_size_rank < 0 or target_size_rank < 0 or target_size_rank > attacker_size_rank:
		return
	var result := schedule_interruption(action.action_instance_id, clock.get_elapsed_us(), attack.attacker_id, "force_bolt_nac_interrupt", parent_event_id)
	if result.get("success", false):
		advance_to(clock.get_elapsed_us())


func _size_category_rank(size_category: StringName) -> int:
	return ["tiny", "small", "medium", "large", "extra_large", "gigantic", "enormous"].find(String(size_category))


func _schedule_special_interruption_for_physical_hit(target_id: StringName, source_id: StringName, parent_event_id: String) -> void:
	var target_state := get_actor_state(target_id)
	if target_state == null or target_state.current_action_instance_id.is_empty():
		return
	var action := get_action(target_state.current_action_instance_id)
	if action == null or action.is_terminal():
		return
	var definition: CombatActionDefinition = _action_definitions.get(String(action.action_definition_id))
	if definition == null or not definition.extension_metadata.has("verified_special"):
		return
	var result := schedule_interruption(action.action_instance_id, clock.get_elapsed_us(), source_id, "physical_hit_interrupts_special", parent_event_id)
	if result.get("success", false):
		advance_to(clock.get_elapsed_us())


func apply_verified_special_damage(
	source_actor_id: StringName,
	target_actor_id: StringName,
	special_id: StringName,
	special_field: StringName,
	otherwise_applicable_damage: int,
	request_id: String
) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_special_damage_request_ids.has(request_id):
		return _failure("duplicate_special_damage_request")
	if otherwise_applicable_damage < 0:
		return _failure("invalid_special_damage")
	if String(special_id).is_empty() or String(special_field).is_empty():
		return _failure("special_damage_definition_unresolved")
	if not _verified_special_damage_definitions.has(String(special_id)):
		return _failure("special_damage_definition_unregistered")
	var registered_definition: Dictionary = _verified_special_damage_definitions[String(special_id)]
	if String(registered_definition.get("special_field", "")) != String(special_field):
		return _failure("special_damage_field_mismatch")
	var target_state := get_actor_state(target_actor_id)
	var profile: CombatDamageProtectionProfile = _damage_protection_profiles.get(String(target_actor_id))
	if get_actor_state(source_actor_id) == null or target_state == null:
		return _failure("unknown_special_damage_actor")
	if int(target_state.current_hpc) <= 0:
		return _failure("target_not_eligible")
	if profile == null:
		return _failure("special_field_target_eligibility_unresolved")
	var response: Variant = profile.get_special_field_response(special_field)
	if response == null or not bool((response as Dictionary).get("eligible", false)):
		return _failure("target_not_eligible_for_special_field")
	var response_data: Dictionary = response
	var final_damage := _apply_multiplier_product_once(
		otherwise_applicable_damage,
		int(response_data["numerator"]),
		int(response_data["denominator"])
	)
	var hpc_before := int(target_state.current_hpc)
	target_state.current_hpc = hpc_before - final_damage
	target_state.revision += 1
	_state_revision += 1
	_accepted_special_damage_request_ids[request_id] = true
	var event := _record_resolved_event(
		clock.get_elapsed_us(), &"verified_special_damage_resolved", _get_actor_initiative(String(source_actor_id)),
		source_actor_id, target_actor_id,
		{
			"special_id": String(special_id),
			"special_field": String(special_field),
			"otherwise_applicable_damage": otherwise_applicable_damage,
			"field_multiplier_numerator": int(response_data["numerator"]),
			"field_multiplier_denominator": int(response_data["denominator"]),
			"final_damage": final_damage,
			"hpc_before": hpc_before,
			"hpc_after": int(target_state.current_hpc),
			"source_ref": String(response_data.get("source_ref", "")),
		}
	)
	return _success({"event_id": event.event_id, "final_damage": final_damage})


func _apply_successful_hit_knockback(attack: CombatAttackInstance, parent_event_id: String) -> void:
	var attacker_state := get_actor_state(attack.attacker_id)
	var target_state := get_actor_state(attack.target_id)
	if attacker_state == null or target_state == null:
		return
	var knockback_microfeet := 0
	var effect_id := ""
	var effect_keys: Array = attacker_state.timed_stat_effects.keys()
	effect_keys.sort()
	for key: Variant in effect_keys:
		var effect: Dictionary = attacker_state.timed_stat_effects[key]
		var amount := int(effect.get("successful_hit_knockback_microfeet", 0))
		if amount > 0:
			knockback_microfeet = amount
			effect_id = String(key)
			break
	if knockback_microfeet <= 0 or not _rage_knockback_resolver.is_valid():
		return
	var result: Variant = _rage_knockback_resolver.call(attack.attacker_id, attack.target_id, knockback_microfeet)
	if typeof(result) != TYPE_DICTIONARY:
		return
	var resolution: Dictionary = result
	if not resolution.get("success", false):
		return
	var destination: Vector2i = resolution.get("position_microfeet", target_state.position_microfeet)
	var start := target_state.position_microfeet
	if destination != start:
		apply_authoritative_forced_position(attack.target_id, destination, int(resolution.get("facing_millidegrees", target_state.facing_millidegrees)), parent_event_id, "rage_knockback")
	_record_resolved_event(
		clock.get_elapsed_us(), &"rage_knockback_resolved", _get_actor_initiative(String(attack.attacker_id)),
		attack.attacker_id, attack.target_id,
		{
			"attack_instance_id": attack.attack_instance_id,
			"effect_id": effect_id,
			"requested_distance_microfeet": knockback_microfeet,
			"start_microfeet": [start.x, start.y],
			"position_microfeet": [destination.x, destination.y],
			"resolved_distance_microfeet": roundi(Vector2(destination - start).length()),
			"blocked": bool(resolution.get("blocked", false)),
			"collision_reason": String(resolution.get("reason", "")),
		}, parent_event_id
	)


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


func apply_authoritative_spatial_position(
	actor_id: StringName,
	position: Vector2i,
	elevation_microfeet: int,
	facing_millidegrees: int,
	movement_cost_microfeet: int = 0
) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key):
		return _failure("unknown_actor")
	if elevation_microfeet < 0 or movement_cost_microfeet < 0:
		return _failure("invalid_spatial_movement")
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
	var previous_position := actor_state.position_microfeet
	var previous_elevation := actor_state.elevation_microfeet
	actor_state.set_spatial_position(position, elevation_microfeet, facing_millidegrees)
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"actor_position_changed", _get_actor_initiative(actor_key), actor_id, &"",
		{
			"position_microfeet": [position.x, position.y],
			"elevation_microfeet": elevation_microfeet,
			"previous_position_microfeet": [previous_position.x, previous_position.y],
			"previous_elevation_microfeet": previous_elevation,
			"facing_millidegrees": facing_millidegrees,
			"movement_cost_microfeet": movement_cost_microfeet,
			"remaining_mr_microfeet": actor_state.remaining_mr_microfeet,
			"flight_movement": true,
			"action_continues": not actor_state.current_action_instance_id.is_empty(),
		}, "", PackedStringArray(), {} if movement_cost_microfeet == 0 else {"mr_microfeet": movement_cost_microfeet}
	)
	return _success()


func apply_authoritative_forced_position(
	actor_id: StringName,
	position: Vector2i,
	facing_millidegrees: int,
	parent_event_id: String,
	reason: String
) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	var previous := actor_state.position_microfeet
	actor_state.set_position(position, facing_millidegrees)
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"actor_position_changed", _get_actor_initiative(String(actor_id)), actor_id, &"",
		{
			"position_microfeet": [position.x, position.y],
			"previous_position_microfeet": [previous.x, previous.y],
			"facing_millidegrees": facing_millidegrees,
			"movement_cost_microfeet": 0,
			"remaining_mr_microfeet": actor_state.remaining_mr_microfeet,
			"forced_displacement": true,
			"forced_displacement_reason": reason,
			"action_continues": not actor_state.current_action_instance_id.is_empty(),
		}, parent_event_id
	)
	return _success()


func get_actor_state(actor_id: StringName) -> CombatActorState:
	return _actor_states.get(String(actor_id)) as CombatActorState


func get_actor_definition(actor_id: StringName) -> CombatActorDefinition:
	return _actor_definitions.get(String(actor_id)) as CombatActorDefinition


func get_effective_actor_combat_stat(actor_id: StringName, field_name: String) -> Variant:
	var actor_key := String(actor_id)
	if not _actor_definitions.has(actor_key) or not _actor_states.has(actor_key):
		return null
	var value: Variant = (_actor_definitions[actor_key] as CombatActorDefinition).get_combat_stat(field_name)
	if value == null:
		return null
	var total := int(value)
	var state: CombatActorState = _actor_states[actor_key]
	var effect_ids: Array = state.timed_stat_effects.keys()
	effect_ids.sort()
	for effect_key: Variant in effect_ids:
		var active_effect: Dictionary = state.timed_stat_effects[effect_key]
		var modifiers: Dictionary = active_effect.get("stat_modifiers", {})
		if modifiers.has(field_name):
			total += int(modifiers[field_name])
	return total


func _effective_stats_snapshot(actor_id: StringName, field_names: Array) -> Dictionary:
	var result := {}
	for field_name: Variant in field_names:
		result[String(field_name)] = get_effective_actor_combat_stat(actor_id, String(field_name))
	return result


func get_action(action_instance_id: String) -> CombatActionInstance:
	return _actions.get(action_instance_id) as CombatActionInstance


func get_action_definition(action_definition_id: StringName) -> CombatActionDefinition:
	return _action_definitions.get(String(action_definition_id)) as CombatActionDefinition


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


func get_resolved_event_count() -> int:
	return _resolved_events.size()


func get_resolved_events_from(cursor: int) -> Dictionary:
	if cursor < 0 or cursor > _resolved_events.size():
		return {
			"success": false,
			"reason": "resolved_event_cursor_invalid",
			"next_cursor": _resolved_events.size(),
			"events": [],
		}
	return {
		"success": true,
		"reason": "",
		"next_cursor": _resolved_events.size(),
		"events": _resolved_events.slice(cursor),
	}


func record_arena_wave_event(event_type: StringName, payload: Dictionary = {}) -> CombatEvent:
	assert(String(event_type).begins_with("arena_wave_"), "Arena wave events must use the reserved arena_wave_ prefix.")
	return _record_resolved_event(
		clock.get_elapsed_us(),
		event_type,
		0,
		&"",
		&"",
		payload.duplicate(true)
	)


func set_arena_wave_state_snapshot(wave_state: Dictionary) -> void:
	_arena_wave_state = wave_state.duplicate(true)
	_state_revision += 1


func restore_actor_between_wave_resources(actor_id: StringName) -> Dictionary:
	var actor_key := String(actor_id)
	if not _actor_states.has(actor_key) or not _actor_definitions.has(actor_key):
		return _failure("unknown_actor")
	# Task 35B supersedes the original recovery prototype. Between-wave
	# downtime must never restore actor state implicitly; legal actions are the
	# only recovery path.
	return _failure("automatic_between_wave_recovery_prohibited")


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
	var special_damage_definition_snapshots: Array = []
	var special_definition_keys: Array = _verified_special_damage_definitions.keys()
	special_definition_keys.sort()
	for special_key: String in special_definition_keys:
		special_damage_definition_snapshots.append((_verified_special_damage_definitions[special_key] as Dictionary).duplicate(true))
	var processed_midnight_ids: Array = _processed_midnight_ids.keys()
	processed_midnight_ids.sort()
	var world_item_snapshots: Array = []
	var world_item_keys: Array = _world_items.keys()
	world_item_keys.sort()
	for world_item_key: String in world_item_keys:
		var world_item: Dictionary = (_world_items[world_item_key] as Dictionary).duplicate(true)
		world_item["position_microfeet"] = _serialized_world_item_position(world_item.get("position_microfeet"))
		world_item_snapshots.append(world_item)
	var thrown_context_snapshots: Array = []
	var thrown_attack_keys: Array = _thrown_weapon_context_by_attack_id.keys()
	thrown_attack_keys.sort()
	for attack_key: String in thrown_attack_keys:
		thrown_context_snapshots.append({
			"attack_instance_id": attack_key,
			"context": (_thrown_weapon_context_by_attack_id[attack_key] as Dictionary).duplicate(true),
		})

	return {
		"schema_version": 12,
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
		"arena_wave_state": _arena_wave_state.duplicate(true),
		"processed_midnight_ids": processed_midnight_ids,
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
		"verified_special_damage_definitions": special_damage_definition_snapshots,
		"world_items": world_item_snapshots,
		"thrown_weapon_contexts": thrown_context_snapshots,
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
		"timed_stat_effect_expire_due":
			_resolved_events.append(event)
			_resolve_timed_stat_effect_expire_due(event)
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
			"action_definition_id": String(action.action_definition_id),
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
	var special: Dictionary = definition.extension_metadata.get("verified_special", {})
	var special_kind := String(special.get("kind", ""))
	var completion_prerequisites_satisfied := true
	if not special.is_empty():
		completion_prerequisites_satisfied = _validate_verified_special_completion(action, completed.event_id)
	if completion_prerequisites_satisfied and bool(special.get("requires_ss_check", false)):
		completion_prerequisites_satisfied = _resolve_special_skill_check(action, special, completed.event_id)
	if definition.extension_metadata.has("gather_material"):
		completion_prerequisites_satisfied = _apply_gathered_material(actor_state, action, completed.event_id)
	if definition.extension_metadata.has("equip_hand_item"):
		completion_prerequisites_satisfied = _apply_equipped_hand_item(actor_state, action, completed.event_id)
	if definition.extension_metadata.has("retrieve_world_item"):
		completion_prerequisites_satisfied = _apply_retrieved_world_item(actor_state, action, completed.event_id)
	if definition.extension_metadata.has("verified_consumable"):
		completion_prerequisites_satisfied = _apply_verified_consumable_healing(
			actor_state,
			action,
			definition.extension_metadata["verified_consumable"],
			completed.event_id
		)
	var required_material := String(special.get("requires_material", ""))
	if completion_prerequisites_satisfied and not required_material.is_empty():
		completion_prerequisites_satisfied = _consume_held_material(actor_state, action, required_material, completed.event_id)
	if special_kind == "called_shot" and completion_prerequisites_satisfied:
		_apply_called_shot_preparation(actor_state, action, completed.event_id)
	elif special_kind == "healing" and completion_prerequisites_satisfied:
		_apply_verified_healing(action, special, completed.event_id)
	elif special_kind == "persistent_damage_shield" and completion_prerequisites_satisfied:
		_apply_persistent_damage_shield(action, special, completed.event_id)
	if completion_prerequisites_satisfied and definition.extension_metadata.has("timed_stat_effect"):
		var effect_target := actor_state
		var target_actor_id := StringName(action.execution_context.get("target_actor_id", String(action.actor_id)))
		if String(target_actor_id) != String(action.actor_id):
			effect_target = get_actor_state(target_actor_id)
		if effect_target != null:
			_apply_timed_stat_effect(effect_target, action, definition.extension_metadata["timed_stat_effect"], completed.event_id)
	_resolve_linked_attack_accuracy(action, completed.event_id)


func _validate_verified_special_completion(action: CombatActionInstance, parent_event_id: String) -> bool:
	var target_id := StringName(action.execution_context.get("target_actor_id", String(action.actor_id)))
	var target_state := get_actor_state(target_id)
	var failure_reason := ""
	if target_state == null or target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		failure_reason = "special_target_no_longer_eligible"
	elif bool(action.execution_context.get("touch_required", false)) \
	and not _is_special_touch_legal(action.actor_id, target_id, false):
		failure_reason = "special_touch_lost_before_completion"
	if failure_reason.is_empty():
		return true
	_record_resolved_event(
		clock.get_elapsed_us(), &"verified_special_completion_failed", action.initiative,
		action.actor_id, target_id,
		{
			"action_instance_id": action.action_instance_id,
			"action_definition_id": String(action.action_definition_id),
			"reason": failure_reason,
			"material_preserved": true,
		}, parent_event_id
	)
	return false


func _resolve_special_skill_check(action: CombatActionInstance, special: Dictionary, parent_event_id: String) -> bool:
	var actor_definition := get_actor_definition(action.actor_id)
	if actor_definition == null:
		return false
	var ss_value: Variant = actor_definition.get_combat_stat("ss")
	if ss_value == null:
		_record_resolved_event(clock.get_elapsed_us(), &"special_skill_check_failed_closed", action.initiative, action.actor_id, &"", {
			"action_instance_id": action.action_instance_id,
			"special_id": String(special.get("special_id", "")),
			"reason": "special_skill_unresolved",
		}, parent_event_id)
		return false
	var natural_roll := roll_int(1, 20)
	var roll_bonus := _get_actor_roll_bonus(actor_definition)
	var adjusted_roll := natural_roll - roll_bonus
	var succeeded := adjusted_roll <= int(ss_value)
	_record_resolved_event(clock.get_elapsed_us(), &"special_skill_resolved", action.initiative, action.actor_id, StringName(action.execution_context.get("target_actor_id", "")), {
		"action_instance_id": action.action_instance_id,
		"special_id": String(special.get("special_id", "")),
		"ss_target": int(ss_value),
		"natural_d20": natural_roll,
		"roll_bonus": roll_bonus,
		"adjusted_roll": adjusted_roll,
		"success": succeeded,
		"rng_draw_index": random.get_draw_count(),
	}, parent_event_id)
	return succeeded


func _apply_persistent_damage_shield(action: CombatActionInstance, special: Dictionary, parent_event_id: String) -> void:
	var target_id := StringName(action.execution_context.get("target_actor_id", String(action.actor_id)))
	var target_state := get_actor_state(target_id)
	if target_state == null:
		return
	var shield_id := String(special.get("shield_id", ""))
	var capacity := int(special.get("capacity", 0))
	target_state.persistent_damage_shields[shield_id] = {
		"shield_id": shield_id,
		"capacity": capacity,
		"maximum_capacity": capacity,
		"source_actor_id": String(action.actor_id),
		"source_action_instance_id": action.action_instance_id,
		"physical_attacker_knockback_microfeet": int(special.get("physical_attacker_knockback_microfeet", 0)),
	}
	target_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"persistent_damage_shield_applied", action.initiative, action.actor_id, target_id, {
		"action_instance_id": action.action_instance_id,
		"shield_id": shield_id,
		"capacity": capacity,
		"maximum_capacity": capacity,
		"expires_at_us": null,
	}, parent_event_id)


func cancel_persistent_damage_shield(actor_id: StringName, shield_id: StringName, request_id: String) -> Dictionary:
	if request_id.is_empty():
		return _failure("missing_request_id")
	if _accepted_request_ids.has(request_id):
		return _failure("duplicate_request")
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	if not actor_state.persistent_damage_shields.has(String(shield_id)):
		return _failure("persistent_damage_shield_not_active")
	var canceled: Dictionary = actor_state.persistent_damage_shields[String(shield_id)]
	actor_state.persistent_damage_shields.erase(String(shield_id))
	actor_state.revision += 1
	_state_revision += 1
	_accepted_request_ids[request_id] = "shield_cancel:%s" % String(shield_id)
	var event := _record_resolved_event(clock.get_elapsed_us(), &"persistent_damage_shield_canceled", _get_actor_initiative(String(actor_id)), actor_id, actor_id, {
		"shield_id": String(shield_id),
		"capacity_before": int(canceled.get("capacity", 0)),
		"ordinary_acts_spent": 0,
		"request_id": request_id,
	})
	return _success({"event_id": event.event_id})


func _apply_gathered_material(actor_state: CombatActorState, action: CombatActionInstance, parent_event_id: String) -> bool:
	var material_id := String(action.execution_context.get("material_id", ""))
	var surface_id := String(action.execution_context.get("surface_id", ""))
	var hand := String(action.execution_context.get("hand", ""))
	var surface_still_legal := not _gatherable_material_resolver.is_valid() \
		or bool(_gatherable_material_resolver.call(actor_state.actor_id, StringName(material_id), surface_id))
	if material_id.is_empty() or surface_id.is_empty() or hand != "left" \
	or not String(actor_state.hand_occupancy.get(hand, "")).is_empty() or not surface_still_legal:
		_record_resolved_event(clock.get_elapsed_us(), &"material_gather_failed", action.initiative, action.actor_id, &"", {
			"action_instance_id": action.action_instance_id,
			"material_id": material_id,
			"surface_id": surface_id,
			"reason": "gather_completion_prerequisite_failed",
		}, parent_event_id)
		return false
	actor_state.hand_occupancy[hand] = "material:%s" % material_id
	actor_state.held_materials[material_id] = int(actor_state.held_materials.get(material_id, 0)) + 1
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"material_gathered", action.initiative, action.actor_id, &"", {
		"action_instance_id": action.action_instance_id,
		"material_id": material_id,
		"surface_id": surface_id,
		"hand": hand,
		"held_materials_after": actor_state.held_materials.duplicate(true),
		"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
	}, parent_event_id)
	return true


func _apply_equipped_hand_item(actor_state: CombatActorState, action: CombatActionInstance, parent_event_id: String) -> bool:
	var equipment_ref := String(action.execution_context.get("equipment_ref", ""))
	var hand := String(action.execution_context.get("hand", ""))
	if equipment_ref.is_empty() or not ["left", "right"].has(hand) \
	or not actor_state.equipment_refs.has(equipment_ref) \
	or not String(actor_state.hand_occupancy.get(hand, "")).is_empty():
		_record_resolved_event(clock.get_elapsed_us(), &"hand_item_equip_failed", action.initiative, action.actor_id, &"", {
			"action_instance_id": action.action_instance_id,
			"equipment_ref": equipment_ref,
			"hand": hand,
			"reason": "equip_completion_prerequisite_failed",
		}, parent_event_id)
		return false
	actor_state.hand_occupancy[hand] = equipment_ref
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"hand_item_equipped", action.initiative, action.actor_id, &"", {
		"action_instance_id": action.action_instance_id,
		"equipment_ref": equipment_ref,
		"hand": hand,
		"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
	}, parent_event_id)
	return true


func _apply_retrieved_world_item(actor_state: CombatActorState, action: CombatActionInstance, parent_event_id: String) -> bool:
	var world_item_id := String(action.execution_context.get("world_item_id", ""))
	if world_item_id.is_empty() or not _world_items.has(world_item_id):
		_record_world_item_retrieval_failure(actor_state, action, world_item_id, "world_item_unavailable_at_completion", parent_event_id)
		return false
	var world_item: Dictionary = _world_items[world_item_id]
	if String(world_item.get("state", "")) != "dropped" \
	or String(world_item.get("owner_actor_id", "")) != String(actor_state.actor_id):
		_record_world_item_retrieval_failure(actor_state, action, world_item_id, "world_item_unavailable_at_completion", parent_event_id)
		return false
	var actor_definition := get_actor_definition(actor_state.actor_id)
	if actor_definition == null \
	or int(actor_definition.attributes.get("str", -1)) < int(world_item.get("strength_requirement", -1)):
		_record_world_item_retrieval_failure(actor_state, action, world_item_id, "equipment_strength_requirement_not_met", parent_event_id)
		return false
	var prerequisites := _validate_world_item_retrieval_prerequisites(actor_state, world_item)
	if not prerequisites.get("success", false):
		_record_world_item_retrieval_failure(actor_state, action, world_item_id, String(prerequisites.get("reason", "retrieval_prerequisite_failed")), parent_event_id)
		return false
	var equipment_ref := String(world_item.get("equipment_ref", ""))
	_world_items.erase(world_item_id)
	if not actor_state.equipment_refs.has(equipment_ref):
		actor_state.equipment_refs.append(equipment_ref)
	for hand: Variant in world_item.get("required_hands", []):
		actor_state.hand_occupancy[String(hand)] = equipment_ref
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"world_item_retrieved", action.initiative, action.actor_id, &"",
		{
			"action_instance_id": action.action_instance_id,
			"world_item_id": world_item_id,
			"equipment_ref": equipment_ref,
			"position_microfeet": _serialized_world_item_position(world_item.get("position_microfeet")),
			"required_hands": (world_item.get("required_hands", []) as Array).duplicate(),
			"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
			"ordinary_acts_spent": 1,
		}, parent_event_id
	)
	return true


func _record_world_item_retrieval_failure(
	actor_state: CombatActorState,
	action: CombatActionInstance,
	world_item_id: String,
	reason: String,
	parent_event_id: String
) -> void:
	_record_resolved_event(
		clock.get_elapsed_us(), &"world_item_retrieval_failed", action.initiative, action.actor_id, &"",
		{
			"action_instance_id": action.action_instance_id,
			"world_item_id": world_item_id,
			"reason": reason,
			"equipment_state_unchanged": true,
			"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
		}, parent_event_id
	)


func _validate_world_item_landing(world_item: Dictionary, position_microfeet: Vector2i) -> Dictionary:
	if not _world_item_landing_resolver.is_valid():
		return _failure("world_item_landing_geometry_unresolved")
	var value: Variant = _world_item_landing_resolver.call(world_item.duplicate(true), position_microfeet)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = value
		if not result.get("success", false):
			return _failure(String(result.get("reason", "world_item_landing_position_illegal")))
		return _success()
	if value != true:
		return _failure("world_item_landing_position_illegal")
	return _success()


func _resolve_automatic_thrown_weapon_landing(
	attack: CombatAttackInstance,
	trajectory_outcome: String,
	parent_event_id: String = ""
) -> Dictionary:
	if not _thrown_weapon_context_by_attack_id.has(attack.attack_instance_id):
		return _failure("thrown_weapon_context_unresolved")
	var context: Dictionary = _thrown_weapon_context_by_attack_id[attack.attack_instance_id]
	var world_item_id := String(context.get("world_item_id", ""))
	if not bool(context.get("released", false)) or not _world_items.has(world_item_id):
		return _failure("thrown_weapon_not_released")
	var world_item: Dictionary = _world_items[world_item_id]
	if String(world_item.get("state", "")) != "pending_landing":
		return _success({"world_item_id": world_item_id, "already_resolved": true})
	if not _thrown_weapon_trajectory_resolver.is_valid():
		return _failure("thrown_weapon_trajectory_unresolved")
	if attack.final_attacker_position_microfeet == null or attack.final_target_position_microfeet == null:
		return _failure("thrown_weapon_resolution_positions_unresolved")
	var final_attacker_position: Vector2i = attack.final_attacker_position_microfeet
	var final_target_position: Vector2i = attack.final_target_position_microfeet
	var definition: CombatAttackDefinition = _attack_definitions.get(String(attack.attack_definition_id))
	if definition == null or definition.maximum_range_microfeet == null:
		return _failure("thrown_weapon_maximum_range_unresolved")
	var stop_at_impact := ["hit", "blocked", "intercepted", "obstacle_intercepted"].has(trajectory_outcome)
	var request := {
		"attack_instance_id": attack.attack_instance_id,
		"world_item_id": world_item_id,
		"trajectory_outcome": trajectory_outcome,
		"start_microfeet": final_attacker_position,
		"direction_point_microfeet": final_target_position,
		"maximum_distance_microfeet": int(definition.maximum_range_microfeet),
		"stop_at_direction_point": stop_at_impact,
	}
	var resolution: Variant = _thrown_weapon_trajectory_resolver.call(request.duplicate(true))
	if typeof(resolution) != TYPE_DICTIONARY:
		return _failure("thrown_weapon_trajectory_unresolved")
	var trajectory: Dictionary = resolution
	if not trajectory.get("success", false):
		return _failure(String(trajectory.get("reason", "thrown_weapon_trajectory_unresolved")))
	var position_value: Variant = trajectory.get("position_microfeet")
	if typeof(position_value) != TYPE_VECTOR2I:
		return _failure("thrown_weapon_landing_position_unresolved")
	if trajectory_outcome == "obstacle_intercepted" \
	and String(trajectory.get("contact_kind", "")) != "solid_obstacle":
		return _failure("thrown_weapon_obstacle_contact_unresolved")
	var position_microfeet: Vector2i = position_value
	if _world_item_landing_resolver.is_valid():
		var landing_validation := _validate_world_item_landing(world_item, position_microfeet)
		if not landing_validation.get("success", false):
			return landing_validation
	var landing_evidence := {
		"trajectory_outcome": trajectory_outcome,
		"contact_kind": String(trajectory.get("contact_kind", "")),
		"obstacle_id": String(trajectory.get("obstacle_id", "")),
		"traveled_distance_microfeet": int(trajectory.get("traveled_distance_microfeet", 0)),
		"maximum_distance_microfeet": int(definition.maximum_range_microfeet),
		"resolution_target_microfeet": [
			final_target_position.x,
			final_target_position.y,
		],
	}
	return _commit_thrown_weapon_landing(
		attack,
		world_item,
		position_microfeet,
		"Task 35E-Fix1 designer-approved deterministic trajectory",
		"automatic_thrown_landing:%s" % attack.attack_instance_id,
		landing_evidence,
		parent_event_id
	)


func _validate_world_item_retrieval_prerequisites(actor_state: CombatActorState, world_item: Dictionary) -> Dictionary:
	if not actor_state.hand_occupancy_authoritative:
		return _failure("retrieval_hand_occupancy_unresolved")
	for hand: Variant in world_item.get("required_hands", []):
		if not String(actor_state.hand_occupancy.get(String(hand), "")).is_empty():
			return _failure("retrieval_required_hand_occupied")
	if not _world_item_pickup_resolver.is_valid():
		return _failure("world_item_pickup_reach_unresolved")
	var value: Variant = _world_item_pickup_resolver.call(actor_state.actor_id, world_item.duplicate(true))
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = value
		if not result.get("success", false):
			return _failure(String(result.get("reason", "world_item_out_of_pickup_reach")))
		return _success()
	if value != true:
		return _failure("world_item_out_of_pickup_reach")
	return _success()


func _serialized_world_item_position(value: Variant) -> Variant:
	if value == null:
		return null
	var position: Vector2i = value
	return [position.x, position.y]


func _consume_held_material(
	actor_state: CombatActorState,
	action: CombatActionInstance,
	material_id: String,
	parent_event_id: String
) -> bool:
	if int(actor_state.held_materials.get(material_id, 0)) <= 0 \
	or String(actor_state.hand_occupancy.get("left", "")) != "material:%s" % material_id:
		_record_resolved_event(clock.get_elapsed_us(), &"special_material_consumption_failed", action.initiative, action.actor_id, &"", {
			"action_instance_id": action.action_instance_id,
			"material_id": material_id,
			"reason": "held_material_missing_at_completion",
		}, parent_event_id)
		return false
	var remaining := int(actor_state.held_materials[material_id]) - 1
	if remaining <= 0:
		actor_state.held_materials.erase(material_id)
	else:
		actor_state.held_materials[material_id] = remaining
	actor_state.hand_occupancy["left"] = ""
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"special_material_consumed", action.initiative, action.actor_id, actor_state.actor_id, {
		"action_instance_id": action.action_instance_id,
		"material_id": material_id,
		"hand": "left",
		"held_materials_after": actor_state.held_materials.duplicate(true),
		"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
	}, parent_event_id)
	return true


func _apply_called_shot_preparation(actor_state: CombatActorState, action: CombatActionInstance, parent_event_id: String) -> void:
	actor_state.pending_called_shot = {
		"target_actor_id": String(action.execution_context.get("target_actor_id", "")),
		"target_location": String(action.execution_context.get("target_location", "")),
		"prepared_at_us": clock.get_elapsed_us(),
		"source_action_instance_id": action.action_instance_id,
		"source_event_id": parent_event_id,
	}
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"called_shot_prepared", action.initiative, action.actor_id,
		StringName(actor_state.pending_called_shot["target_actor_id"]),
		{
			"action_instance_id": action.action_instance_id,
			"target_location": actor_state.pending_called_shot["target_location"],
			"attacks_this_act_automatically_accurate": true,
		}, parent_event_id
	)


func _apply_verified_healing(action: CombatActionInstance, special: Dictionary, parent_event_id: String) -> void:
	var target_id := StringName(action.execution_context.get("target_actor_id", String(action.actor_id)))
	var target_state := get_actor_state(target_id)
	var target_definition := get_actor_definition(target_id)
	if target_state == null or target_definition == null:
		return
	var rolls: Array[int] = []
	var draw_indices: Array[int] = []
	var rolled_total := 0
	for _index in range(int(special.get("dice_count", 0))):
		var value := roll_int(1, int(special.get("die_sides", 0)))
		rolls.append(value)
		draw_indices.append(random.get_draw_count())
		rolled_total += value
	var amount := rolled_total + int(special.get("flat_bonus", 0))
	var hpc_before := int(target_state.current_hpc)
	var hpc_max := int(target_definition.get_combat_stat("hpm"))
	target_state.current_hpc = mini(hpc_before + amount, hpc_max)
	target_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"verified_healing_resolved", action.initiative, action.actor_id, target_id,
		{
			"action_instance_id": action.action_instance_id,
			"rolls": rolls,
			"rng_draw_indices": draw_indices,
			"flat_bonus": int(special.get("flat_bonus", 0)),
			"rolled_healing": amount,
			"hpc_before": hpc_before,
			"hpc_after": int(target_state.current_hpc),
			"hpc_max": hpc_max,
		}, parent_event_id
	)


func _apply_verified_consumable_healing(
	actor_state: CombatActorState,
	action: CombatActionInstance,
	consumable: Dictionary,
	parent_event_id: String
) -> bool:
	var inventory_id := String(consumable.get("inventory_id", ""))
	var failure_reason := ""
	if actor_state.current_hpc == null or int(actor_state.current_hpc) <= 0:
		failure_reason = "actor_no_longer_eligible"
	elif int(actor_state.inventory_quantities.get(inventory_id, 0)) <= 0:
		failure_reason = "consumable_unavailable_at_completion"
	elif bool(consumable.get("requires_free_hand", false)) and not _actor_has_free_hand(actor_state):
		failure_reason = "consumable_free_hand_lost"
	if not failure_reason.is_empty():
		_record_resolved_event(
			clock.get_elapsed_us(), &"consumable_completion_failed", action.initiative,
			action.actor_id, action.actor_id,
			{
				"action_instance_id": action.action_instance_id,
				"inventory_id": inventory_id,
				"reason": failure_reason,
				"quantity_after": int(actor_state.inventory_quantities.get(inventory_id, 0)),
			}, parent_event_id
		)
		return false
	var quantity_before := int(actor_state.inventory_quantities[inventory_id])
	actor_state.inventory_quantities[inventory_id] = quantity_before - 1
	var rolls: Array[int] = []
	var draw_indices: Array[int] = []
	var rolled_total := 0
	for _index in range(int(consumable.get("dice_count", 0))):
		var value := roll_int(1, int(consumable.get("die_sides", 0)))
		rolls.append(value)
		draw_indices.append(random.get_draw_count())
		rolled_total += value
	var amount := rolled_total + int(consumable.get("flat_bonus", 0))
	var actor_definition := get_actor_definition(action.actor_id)
	var hpc_before := int(actor_state.current_hpc)
	var hpc_max := int(actor_definition.get_combat_stat("hpm"))
	actor_state.current_hpc = mini(hpc_before + amount, hpc_max)
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"consumable_healing_resolved", action.initiative,
		action.actor_id, action.actor_id,
		{
			"action_instance_id": action.action_instance_id,
			"inventory_id": inventory_id,
			"quantity_before": quantity_before,
			"quantity_after": int(actor_state.inventory_quantities[inventory_id]),
			"rolls": rolls,
			"rng_draw_indices": draw_indices,
			"flat_bonus": int(consumable.get("flat_bonus", 0)),
			"rolled_healing": amount,
			"hpc_before": hpc_before,
			"hpc_after": int(actor_state.current_hpc),
			"hpc_max": hpc_max,
		}, parent_event_id
	)
	return true


func _actor_has_free_hand(actor_state: CombatActorState) -> bool:
	return String(actor_state.hand_occupancy.get("left", "")).is_empty() \
		or String(actor_state.hand_occupancy.get("right", "")).is_empty()


func _apply_timed_stat_effect(
	actor_state: CombatActorState,
	action: CombatActionInstance,
	effect_definition: Dictionary,
	parent_event_id: String
) -> void:
	var effect_id := String(effect_definition["effect_id"])
	var expires_at_us := clock.get_elapsed_us() + int(effect_definition["duration_us"])
	var stats_before := {}
	for stat_name: Variant in (effect_definition["stat_modifiers"] as Dictionary):
		stats_before[String(stat_name)] = get_effective_actor_combat_stat(actor_state.actor_id, String(stat_name))
	actor_state.timed_stat_effects[effect_id] = {
		"effect_id": effect_id,
		"applied_at_us": clock.get_elapsed_us(),
		"expires_at_us": expires_at_us,
		"stat_modifiers": (effect_definition["stat_modifiers"] as Dictionary).duplicate(true),
		"source_action_instance_id": action.action_instance_id,
		"successful_hit_knockback_microfeet": int(effect_definition.get("successful_hit_knockback_microfeet", 0)),
	}
	_add_actor_condition(actor_state, effect_id)
	var applied := _record_resolved_event(
		clock.get_elapsed_us(),
		&"timed_stat_effect_applied",
		action.initiative,
		action.actor_id,
		actor_state.actor_id,
		{
			"action_instance_id": action.action_instance_id,
			"effect_id": effect_id,
			"expires_at_us": expires_at_us,
			"stat_modifiers": (effect_definition["stat_modifiers"] as Dictionary).duplicate(true),
			"stats_before": stats_before,
			"stats_after": _effective_stats_snapshot(actor_state.actor_id, (effect_definition["stat_modifiers"] as Dictionary).keys()),
		},
		parent_event_id
	)
	schedule_event(
		expires_at_us,
		&"timed_stat_effect_expire_due",
		action.initiative,
		actor_state.actor_id,
		&"",
		{"effect_id": effect_id, "expected_expires_at_us": expires_at_us},
		applied.event_id
	)


func _resolve_timed_stat_effect_expire_due(event: CombatEvent) -> void:
	var actor_state := get_actor_state(event.source_actor_id)
	var effect_id := String(event.payload.get("effect_id", ""))
	if actor_state == null or not actor_state.timed_stat_effects.has(effect_id):
		return
	var active_effect: Dictionary = actor_state.timed_stat_effects[effect_id]
	if int(active_effect.get("expires_at_us", -1)) != int(event.payload.get("expected_expires_at_us", -2)):
		return
	var modifier_names: Array = (active_effect.get("stat_modifiers", {}) as Dictionary).keys()
	var stats_before := _effective_stats_snapshot(actor_state.actor_id, modifier_names)
	actor_state.timed_stat_effects.erase(effect_id)
	_remove_actor_condition(actor_state, effect_id)
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		event.timestamp_us,
		&"timed_stat_effect_expired",
		event.initiative,
		event.source_actor_id,
		&"",
		{
			"effect_id": effect_id,
			"stats_before": stats_before,
			"stats_after": _effective_stats_snapshot(actor_state.actor_id, modifier_names),
		},
		event.event_id
	)


func _resolve_linked_attack_accuracy(action: CombatActionInstance, parent_event_id: String) -> void:
	if not _attack_by_action_id.has(action.action_instance_id):
		return
	for attack_instance_id: String in _get_linked_attack_instance_ids(action.action_instance_id):
		var attack: CombatAttackInstance = _attacks[attack_instance_id]
		_resolve_single_linked_attack_accuracy(action, attack, parent_event_id)


func _resolve_instant_special_accuracy(attack: CombatAttackInstance, definition: CombatAttackDefinition, parent_event_id: String) -> void:
	var final_legality := _evaluate_final_attack_legality(attack, definition)
	if not final_legality.get("success", false):
		attack.status = CombatAttackInstance.STATUS_FINAL_LEGALITY_FAILED
		attack.final_legality_reason = String(final_legality.get("reason", "final_legality_failed"))
		attack.resolved_at_us = clock.get_elapsed_us()
		attack.revision += 1
		_state_revision += 1
		var failed := _record_resolved_event(clock.get_elapsed_us(), &"special_attack_final_legality_failed", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
			"attack_instance_id": attack.attack_instance_id, "special_id": String(attack.special_id),
			"reason": attack.final_legality_reason, "accuracy_rolled": false,
		}, parent_event_id)
		attack.result_event_id = failed.event_id
		return
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
	var result := _record_resolved_event(clock.get_elapsed_us(), &"special_attack_accuracy_resolved", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
		"attack_instance_id": attack.attack_instance_id, "special_id": String(attack.special_id),
		"target_location": String(attack.target_location), "natural_d20": attack.natural_roll,
		"adjusted_roll": attack.adjusted_roll, "acc_target": attack.acc_target,
		"accuracy_success": attack.accuracy_success, "critical_success": attack.critical_success,
		"critical_failure": attack.critical_failure, "result_state": attack.status,
		"damage_applied": false,
	}, parent_event_id)
	attack.accuracy_event_id = result.event_id
	attack.result_event_id = result.event_id
	if critical_result != CombatCriticalTriggerPolicy.RESULT_NONE:
		var record := _record_critical_trigger(
			"special:%s:acc" % attack.attack_instance_id, &"special_attack", critical_result,
			int(attack.natural_roll), definition.critical_trigger_policy, attack.attacker_id,
			attack.target_id, result.event_id
		)
		attack.critical_record_id = record.critical_record_id
		attack.result_event_id = record.event_id
		record.consequence_status = CombatCriticalRecord.CONSEQUENCE_BLOCKED
		record.consequence_reason = "special_critical_consequence_not_approved"
		var unavailable := _record_resolved_event(clock.get_elapsed_us(), &"critical_effect_unavailable", _get_actor_initiative(String(attack.attacker_id)), attack.attacker_id, attack.target_id, {
			"critical_record_id": record.critical_record_id,
			"reason": "special_critical_consequence_not_approved",
		}, record.event_id)
		record.child_event_ids.append(unavailable.event_id)
		_state_revision += 1


func _resolve_single_linked_attack_accuracy(action: CombatActionInstance, attack: CombatAttackInstance, parent_event_id: String) -> void:
	if attack.status != CombatAttackInstance.STATUS_EXECUTING:
		return
	var definition: CombatAttackDefinition = _attack_definitions[String(attack.attack_definition_id)]
	var final_legality := _evaluate_final_attack_legality(attack, definition)
	var is_committed_throw := _thrown_weapon_context_by_attack_id.has(attack.attack_instance_id)
	var failed_throw_trajectory_outcome := ""
	if final_legality.get("success", false) and is_committed_throw:
		final_legality = _release_committed_thrown_weapon(attack, parent_event_id)
	elif is_committed_throw and String(final_legality.get("reason", "")) in [
		"target_out_of_range_at_resolution",
		"line_of_sight_blocked_at_resolution",
	]:
		var release_result := _release_committed_thrown_weapon(attack, parent_event_id)
		if not release_result.get("success", false):
			final_legality = release_result
		else:
			failed_throw_trajectory_outcome = "obstacle_intercepted" \
				if String(final_legality.get("reason", "")) == "line_of_sight_blocked_at_resolution" \
				else "miss"
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
				"strike_index": attack.strike_index,
				"strikes_per_act": attack.strikes_per_act,
			},
			parent_event_id
		)
		attack.result_event_id = failed.event_id
		if not failed_throw_trajectory_outcome.is_empty():
			_resolve_automatic_thrown_weapon_landing(attack, failed_throw_trajectory_outcome, failed.event_id)
		return
	var critical_result := CombatCriticalTriggerPolicy.RESULT_NONE
	if attack.automatic_accuracy_reason == "called_shot":
		attack.natural_roll = null
		attack.rng_draw_index = null
		attack.adjusted_roll = null
		attack.accuracy_success = true
	else:
		attack.natural_roll = roll_int(1, 20)
		attack.rng_draw_index = random.get_draw_count()
		attack.adjusted_roll = int(attack.natural_roll) - attack.roll_bonus
		critical_result = definition.critical_trigger_policy.classify(int(attack.natural_roll))
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
			"attacker_size_category": String(attack.attacker_size_category),
			"target_size_category": String(attack.target_size_category),
			"size_relationship": String(attack.size_relationship),
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
			"strike_index": attack.strike_index,
			"strikes_per_act": attack.strikes_per_act,
			"accuracy_rolled": attack.automatic_accuracy_reason.is_empty(),
			"automatic_accuracy_reason": attack.automatic_accuracy_reason,
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
		_resolve_automatic_thrown_weapon_landing(attack, "miss")
		_finalize_deferred_critical_consequences(attack)


func _release_committed_thrown_weapon(attack: CombatAttackInstance, parent_event_id: String) -> Dictionary:
	if not _thrown_weapon_context_by_attack_id.has(attack.attack_instance_id):
		return _failure("thrown_weapon_context_unresolved")
	var context: Dictionary = _thrown_weapon_context_by_attack_id[attack.attack_instance_id]
	if bool(context.get("released", false)):
		return _failure("thrown_weapon_already_released")
	var actor_state := get_actor_state(attack.attacker_id)
	if actor_state == null:
		return _failure("unknown_attacker")
	var equipment_ref := String(context.get("equipment_ref", ""))
	if equipment_ref.is_empty() or not actor_state.equipment_refs.has(equipment_ref):
		return _failure("weapon_not_equipped_at_release")
	var world_item_id := String(context.get("world_item_id", ""))
	if world_item_id.is_empty() or _world_items.has(world_item_id):
		return _failure("thrown_weapon_world_item_conflict")
	for hand: Variant in context.get("required_hands", []):
		if String(actor_state.hand_occupancy.get(String(hand), "")) != equipment_ref:
			return _failure("weapon_not_in_required_hand_at_release")
	actor_state.equipment_refs.erase(equipment_ref)
	for hand: Variant in actor_state.hand_occupancy.keys():
		if String(actor_state.hand_occupancy[hand]) == equipment_ref:
			actor_state.hand_occupancy[hand] = ""
	actor_state.revision += 1
	var world_item := {
		"world_item_id": world_item_id,
		"equipment_ref": equipment_ref,
		"owner_actor_id": String(context.get("owner_actor_id", String(attack.attacker_id))),
		"source_actor_id": String(attack.attacker_id),
		"source_attack_instance_id": attack.attack_instance_id,
		"state": "pending_landing",
		"position_microfeet": null,
		"required_hands": (context.get("required_hands", []) as Array).duplicate(),
		"strength_requirement": int(context.get("strength_requirement", -1)),
		"landing_outcome": "",
		"landing_source_ref": "",
		"revision": 1,
	}
	_world_items[world_item_id] = world_item
	context["released"] = true
	_thrown_weapon_context_by_attack_id[attack.attack_instance_id] = context
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"thrown_weapon_released", _get_actor_initiative(String(attack.attacker_id)),
		attack.attacker_id, attack.target_id,
		{
			"attack_instance_id": attack.attack_instance_id,
			"world_item_id": world_item_id,
			"equipment_ref": equipment_ref,
			"owner_actor_id": world_item["owner_actor_id"],
			"state": "pending_landing",
			"hand_occupancy_after": actor_state.hand_occupancy.duplicate(true),
		}, parent_event_id
	)
	return _success({"world_item_id": world_item_id})


func _evaluate_final_attack_legality(attack: CombatAttackInstance, definition: CombatAttackDefinition) -> Dictionary:
	var attacker_state: CombatActorState = _actor_states.get(String(attack.attacker_id))
	var target_state: CombatActorState = _actor_states.get(String(attack.target_id))
	if attacker_state == null or target_state == null:
		attack.final_range_legal = false
		attack.final_line_of_sight_legal = null
		return _failure("final_attack_actor_unavailable")
	if attacker_state.current_hpc == null or int(attacker_state.current_hpc) <= 0:
		return _failure("attacker_not_eligible_at_resolution")
	if target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return _failure("target_not_eligible_at_resolution")
	if definition.requires_equipped_weapon and not attacker_state.equipment_refs.has(String(attack.weapon_ref)):
		return _failure("weapon_not_equipped_at_resolution")
	if definition.requires_hand_occupancy and attacker_state.hand_occupancy_authoritative \
	and not attacker_state.hand_occupancy.values().has(String(attack.weapon_ref)):
		return _failure("weapon_not_in_hand_at_resolution")
	attack.final_attacker_position_microfeet = attacker_state.position_microfeet
	attack.final_target_position_microfeet = target_state.position_microfeet
	attack.final_attacker_elevation_microfeet = attacker_state.elevation_microfeet
	attack.final_target_elevation_microfeet = target_state.elevation_microfeet
	var offset := target_state.position_microfeet - attacker_state.position_microfeet
	var elevation_offset := target_state.elevation_microfeet - attacker_state.elevation_microfeet
	var distance_squared := offset.x * offset.x + offset.y * offset.y + elevation_offset * elevation_offset
	attack.final_distance_squared_microfeet = distance_squared
	var effective_minimum_range: Variant = definition.minimum_range_microfeet if attack.minimum_range_microfeet_override == null else attack.minimum_range_microfeet_override
	var effective_maximum_range: Variant = definition.maximum_range_microfeet if attack.maximum_range_microfeet_override == null else attack.maximum_range_microfeet_override
	if effective_maximum_range == null:
		return _failure("unresolved_attack_range")
	var minimum_range := 0 if effective_minimum_range == null else int(effective_minimum_range)
	var maximum_range := int(effective_maximum_range)
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
		and target_state.position_microfeet == attack.declared_target_position_microfeet \
		and attacker_state.elevation_microfeet == attack.declared_attacker_elevation_microfeet \
		and target_state.elevation_microfeet == attack.declared_target_elevation_microfeet:
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
	for attack_instance_id: String in _get_linked_attack_instance_ids(action.action_instance_id):
		var attack: CombatAttackInstance = _attacks[attack_instance_id]
		if attack.status != CombatAttackInstance.STATUS_EXECUTING:
			continue
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
				"strike_index": attack.strike_index,
				"strikes_per_act": attack.strikes_per_act,
			},
			parent_event_id
		)
		attack.result_event_id = interrupted.event_id


func _get_linked_attack_instance_ids(action_instance_id: String) -> Array[String]:
	var linked: Variant = _attack_by_action_id.get(action_instance_id, [])
	if linked is Array:
		var result: Array[String] = []
		for attack_instance_id: Variant in linked:
			result.append(String(attack_instance_id))
		return result
	if linked is String:
		return [linked]
	return []


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
	if stat_name.is_empty() or get_effective_actor_combat_stat(defender_state.actor_id, stat_name) == null:
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
			result["base_target"] = get_effective_actor_combat_stat(defender_state.actor_id, stat_name)
			if result["base_target"] == null:
				result["reason"] = "dodge_target_unresolved"
				return result
			result["target_modifier"] = profile.get_modifier(defense_type) + attack.tiny_target_dodge_bonus
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
			if attack.is_special_attack:
				result["reason"] = "special_attack_not_blockable"
				return result
			return _evaluate_block_eligibility(defender_state, profile.weapon_block, defense_type, profile.get_modifier(defense_type))
		CombatDefenseProfile.SHIELD_BLOCK:
			if attack.is_special_attack:
				result["reason"] = "special_attack_not_blockable"
				return result
			return _evaluate_block_eligibility(defender_state, profile.shield_block, defense_type, profile.get_modifier(defense_type))
		CombatDefenseProfile.PHYSICAL_SOAK:
			if attack.is_special_attack:
				result["reason"] = "special_attack_not_physical_soak_eligible"
				return result
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
			result["base_target"] = get_effective_actor_combat_stat(defender_state.actor_id, "physical_soak")
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
	var strength_bonus_eligible: Variant = damage_definition.strength_bonus_eligible if attack.strength_bonus_eligible_override == null else attack.strength_bonus_eligible_override
	if strength_bonus_eligible == null:
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
	if strength_bonus_eligible == true:
		var sb_value: Variant = get_effective_actor_combat_stat(attack.attacker_id, "sb")
		if sb_value == null:
			return _failure("attacker_strength_bonus_unresolved")
		strength_bonus = int(sb_value)
	var target_definition: CombatActorDefinition = _actor_definitions[String(attack.target_id)]
	var nal_value: Variant = get_effective_actor_combat_stat(attack.target_id, "nal")
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
		"flat_bonus": damage_definition.flat_bonus if attack.flat_bonus_override == null else int(attack.flat_bonus_override),
		"damage_dice_count": damage_definition.dice_count if attack.damage_dice_count_override == null else int(attack.damage_dice_count_override),
		"damage_die_sides": damage_definition.die_sides if attack.damage_die_sides_override == null else int(attack.damage_die_sides_override),
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
	var elevation_offset := target_state.elevation_microfeet - reactor_state.elevation_microfeet
	var distance_squared := offset.x * offset.x + offset.y * offset.y + elevation_offset * elevation_offset
	var minimum_range := 0 if definition.minimum_range_microfeet == null else int(definition.minimum_range_microfeet)
	if not definition.has_resolved_range() or distance_squared < minimum_range * minimum_range or distance_squared > int(definition.maximum_range_microfeet) * int(definition.maximum_range_microfeet):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_target_out_of_range")
		return
	var acc_value: Variant = (_actor_definitions[reactor_key] as CombatActorDefinition).get_combat_stat("acc")
	if acc_value == null:
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_acc_unresolved")
		return
	var reactor_definition: CombatActorDefinition = _actor_definitions[reactor_key]
	var target_definition: CombatActorDefinition = _actor_definitions[target_key]
	var location_context := _resolve_location_acc_context(definition, reactor_definition, target_definition, &"torso")
	if not location_context.get("success", false):
		_record_critical_effect(record, effect, &"critical_effect_unavailable", false, "critical_reaction_torso_target_unresolved")
		return
	var attack_id := _make_attack_instance_id(_next_attack_sequence)
	_next_attack_sequence += 1
	var reaction := CombatAttackInstance.new(
		attack_id, definition, "", reactor_id, reaction_target_id, &"torso", clock.get_elapsed_us(),
		int(acc_value), int(location_context["location_acc_modifier"]), _get_actor_roll_bonus(reactor_definition), false,
		StringName(location_context.get("size_relationship", "")),
		StringName(location_context.get("attacker_size_category", "")),
		StringName(location_context.get("target_size_category", "")),
		int(location_context.get("tiny_target_dodge_bonus", 0))
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
	if delivery_class == &"magic_projectile":
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


func _is_special_touch_legal(actor_id: StringName, target_id: StringName, fallback_fact: bool) -> bool:
	if actor_id == target_id:
		return true
	if _special_touch_resolver.is_valid():
		return bool(_special_touch_resolver.call(actor_id, target_id))
	return fallback_fact


func configure_nac_automation(actor_id: StringName, settings: Dictionary) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	if actor_state == null:
		return _failure("unknown_actor")
	var profile := String(settings.get("profile", "Balanced"))
	if not ["Balanced", "Defensive", "Aggressive", "Guardian"].has(profile):
		return _failure("unsupported_nac_profile")
	var minimum_mana_reserve := int(settings.get("minimum_mana_reserve", 0))
	var automatic_nac_budget := int(settings.get("automatic_nac_budget", 5))
	if minimum_mana_reserve < 0 or automatic_nac_budget < 0 or automatic_nac_budget > 5:
		return _failure("invalid_nac_automation_limits")
	actor_state.nac_automation_settings = {
		"profile": profile,
		"automatic_enabled": bool(settings.get("automatic_enabled", false)),
		"minimum_mana_reserve": minimum_mana_reserve,
		"automatic_nac_budget": automatic_nac_budget,
		"emergency_defense_enabled": bool(settings.get("emergency_defense_enabled", true)),
		"offensive_triggers_enabled": bool(settings.get("offensive_triggers_enabled", true)),
		"ally_protection_enabled": bool(settings.get("ally_protection_enabled", false)),
		"priority": PackedStringArray(settings.get("priority", PackedStringArray(["force_bolt"]))),
	}
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(clock.get_elapsed_us(), &"nac_automation_configured", _get_actor_initiative(String(actor_id)), actor_id, &"", actor_state.nac_automation_settings.duplicate(true))
	return _success({"settings": actor_state.nac_automation_settings.duplicate(true)})


func get_nac_automation(actor_id: StringName) -> Dictionary:
	var actor_state := get_actor_state(actor_id)
	return {} if actor_state == null else actor_state.nac_automation_settings.duplicate(true)


func _validate_nac_attack_context(actor_state: CombatActorState, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return _success()
	var ability_id := String(context.get("ability_id", ""))
	var multiplier: Variant = context.get("damage_multiplier")
	if ability_id.is_empty() or typeof(multiplier) != TYPE_DICTIONARY:
		return _failure("invalid_nac_attack_context")
	var value: Dictionary = multiplier
	if int(value.get("numerator", 0)) <= 0 or int(value.get("denominator", 0)) <= 0:
		return _failure("invalid_nac_damage_multiplier")
	if not actor_state.ability_daily_remaining.has(ability_id):
		return _failure("nac_allowance_unregistered")
	if int(actor_state.ability_daily_remaining[ability_id]) <= 0:
		return _failure("nac_daily_use_exhausted")
	var round_index := clock.get_round_index()
	var uses_this_round := actor_state.nac_uses_this_round if actor_state.nac_round_index == round_index else 0
	if uses_this_round >= 5:
		return _failure("nac_round_cap_reached")
	return _success()


func _commit_nac_attack_context(
	actor_state: CombatActorState,
	actor_id: StringName,
	target_id: StringName,
	action_instance_id: String,
	attack_instance_ids: Array[String],
	context: Dictionary
) -> void:
	var ability_id := String(context["ability_id"])
	var round_index := clock.get_round_index()
	if actor_state.nac_round_index != round_index:
		actor_state.nac_round_index = round_index
		actor_state.nac_uses_this_round = 0
		actor_state.automatic_nac_uses_this_round = 0
	var before := int(actor_state.ability_daily_remaining[ability_id])
	actor_state.ability_daily_remaining[ability_id] = before - 1
	actor_state.nac_uses_this_round += 1
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"nac_attack_enhancement_committed", _get_actor_initiative(String(actor_id)), actor_id, target_id,
		{
			"ability_id": ability_id,
			"action_instance_id": action_instance_id,
			"attack_instance_ids": attack_instance_ids.duplicate(),
			"daily_before": before,
			"daily_after": before - 1,
			"nac_round_index": round_index,
			"nac_uses_this_round": actor_state.nac_uses_this_round,
			"nac_round_cap": 5,
			"damage_multiplier": (context["damage_multiplier"] as Dictionary).duplicate(true),
			"ap_spent": 0,
			"ordinary_acts_spent": 0,
		}, "", PackedStringArray(), {ability_id: 1}
	)


func _validate_ability_activation(
	actor_state: CombatActorState,
	definition: CombatActionDefinition
) -> Dictionary:
	var ability_value: Variant = definition.extension_metadata.get("ability_use")
	if typeof(ability_value) != TYPE_DICTIONARY:
		return _success({"uses_ability": false})
	var ability: Dictionary = ability_value
	var ability_id := String(ability.get("ability_id", ""))
	var fallback_ap_cost := int(ability.get("fallback_ap_cost", 0))
	if ability_id.is_empty() or fallback_ap_cost != 1:
		return _failure("invalid_ability_use_definition")
	if not actor_state.ability_daily_maxima.has(ability_id) \
	or not actor_state.ability_daily_remaining.has(ability_id):
		return _failure("ability_allowance_unregistered")
	var remaining_before := int(actor_state.ability_daily_remaining[ability_id])
	var ap_before := int(actor_state.resources.get("ap", 0))
	if remaining_before > 0:
		return _success({
			"uses_ability": true,
			"ability_id": ability_id,
			"payment_kind": "daily_use",
			"daily_before": remaining_before,
			"daily_after": remaining_before - 1,
			"ap_before": ap_before,
			"ap_after": ap_before,
			"ap_spent": 0,
		})
	if ap_before >= fallback_ap_cost:
		return _success({
			"uses_ability": true,
			"ability_id": ability_id,
			"payment_kind": "ability_point",
			"daily_before": 0,
			"daily_after": 0,
			"ap_before": ap_before,
			"ap_after": ap_before - fallback_ap_cost,
			"ap_spent": fallback_ap_cost,
		})
	return _failure("insufficient_ability_resources")


func _commit_ability_activation(
	actor_state: CombatActorState,
	action: CombatActionInstance,
	definition: CombatActionDefinition,
	payment: Dictionary
) -> void:
	if not bool(payment.get("uses_ability", false)):
		return
	var ability_id := String(payment["ability_id"])
	actor_state.ability_daily_remaining[ability_id] = int(payment["daily_after"])
	if String(payment["payment_kind"]) == "ability_point":
		actor_state.resources["ap"] = int(payment["ap_after"])
	actor_state.revision += 1
	_state_revision += 1
	_record_resolved_event(
		clock.get_elapsed_us(), &"ability_use_committed", action.initiative,
		action.actor_id, StringName(action.execution_context.get("target_actor_id", "")),
		{
			"action_instance_id": action.action_instance_id,
			"action_definition_id": String(definition.action_definition_id),
			"ability_id": ability_id,
			"daily_maximum": int(actor_state.ability_daily_maxima[ability_id]),
			"daily_before": int(payment["daily_before"]),
			"daily_after": int(payment["daily_after"]),
			"payment_kind": String(payment["payment_kind"]),
			"ap_before": int(payment["ap_before"]),
			"ap_after": int(payment["ap_after"]),
			"ap_spent": int(payment["ap_spent"]),
		}, action.start_event_id
	)


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
