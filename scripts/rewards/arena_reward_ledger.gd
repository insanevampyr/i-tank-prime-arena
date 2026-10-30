class_name ArenaRewardLedger
extends RefCounted

const Catalog = preload("res://scripts/rewards/prime_v3_reward_catalog.gd")
const DropResolver = preload("res://scripts/rewards/prime_v3_random_drop_resolver.gd")
const Advancement = preload("res://scripts/rewards/prime_v3_advancement_catalog.gd")

const MODE_NORMAL := "normal"
const MODE_TEST := "test"
const MODE_DEV_NORMAL := "dev_normal"

var mode: String = MODE_TEST
var player_actor_id: StringName = &"player"
var player_level: int = -1
var earned_xp: int = 0
var spent_xp: int = 0
var current_wave_earned_xp: int = 0
var current_wave_id: String = ""
var awards: Array[Dictionary] = []
var drop_resolutions: Array[Dictionary] = []
var purchase_records: Array[Dictionary] = []
var processed_actor_ids: Dictionary = {}
var processed_defeat_event_ids: Dictionary = {}
var collected_world_item_ids: Dictionary = {}
var processed_purchase_request_ids: Dictionary = {}
var _next_world_item_sequence: int = 0
var profile_ownership: Dictionary = {}


func configure(p_mode: String, p_player_actor_id: StringName, p_player_level: int) -> Dictionary:
	if not [MODE_NORMAL, MODE_DEV_NORMAL, MODE_TEST].has(p_mode):
		return {"success": false, "reason": "unsupported_reward_mode"}
	mode = p_mode
	player_actor_id = p_player_actor_id
	player_level = p_player_level
	return {"success": true, "mode": mode, "player_level": player_level}


func begin_wave(wave_id: String) -> void:
	if current_wave_id == wave_id:
		return
	current_wave_id = wave_id
	current_wave_earned_xp = 0


func process_defeat(
	simulation: CombatSimulation,
	defeated_actor_id: StringName,
	defeat_event_id: String
) -> Dictionary:
	var actor_key := String(defeated_actor_id)
	if actor_key.is_empty() or defeat_event_id.is_empty():
		return {"success": false, "reason": "defeat_identity_unresolved"}
	if processed_actor_ids.has(actor_key) or processed_defeat_event_ids.has(defeat_event_id):
		return {"success": false, "reason": "reward_already_processed"}
	var actor_state := simulation.get_actor_state(defeated_actor_id)
	if actor_state == null or actor_state.current_hpc == null or int(actor_state.current_hpc) > 0:
		return {"success": false, "reason": "actor_not_defeated"}
	processed_actor_ids[actor_key] = true
	processed_defeat_event_ids[defeat_event_id] = true
	var creature_id := Catalog.creature_id_for_actor(defeated_actor_id)
	if mode == MODE_TEST:
		_sync(simulation)
		return {"success": true, "suppressed": true, "reason": "developer_test_mode"}
	var reward := Catalog.get_reward(creature_id)
	var blocked_reason := ""
	var blocked_event_id := ""
	if reward.is_empty():
		blocked_reason = Catalog.get_blocked_reason(creature_id)
		var blocked_event := simulation.record_reward_event(
			&"reward_source_blocked", defeated_actor_id, player_actor_id,
			{"creature_id": creature_id, "reason": blocked_reason, "defeat_event_id": defeat_event_id},
			defeat_event_id
		)
		blocked_event_id = blocked_event.event_id
	var source_xp := int(reward.get("xp", 0))
	var arena_xp := int(Catalog.ARENA_XP_OVERRIDES.get(creature_id, 0))
	var xp := arena_xp * (10 if mode == MODE_DEV_NORMAL else 1)
	if not reward.is_empty():
		earned_xp += xp
		current_wave_earned_xp += xp
	var award := {
		"actor_id": actor_key,
		"creature_id": creature_id,
		"defeat_event_id": defeat_event_id,
		"wave_id": current_wave_id,
		"xp": xp,
		"prime_v3_xp": source_xp,
		"arena_xp": arena_xp,
		"xp_multiplier": 10 if mode == MODE_DEV_NORMAL else 1,
		"arena_source_ref": "Task 36G owner-approved Arena XP override",
		"source_ref": reward.get("source_ref", ""),
	}
	var award_event_id := blocked_event_id
	if not reward.is_empty():
		var xp_event := simulation.record_reward_event(
			&"reward_xp_awarded", defeated_actor_id, player_actor_id,
			award.merged({
				"cumulative_earned_xp": earned_xp,
				"spent_xp": spent_xp,
				"unspent_xp": earned_xp - spent_xp,
				"distribution": "full_award_to_each_eligible_participant",
			}, true), defeat_event_id
		)
		award_event_id = xp_event.event_id
		award["award_event_id"] = award_event_id
		awards.append(award)
	var actor_position := actor_state.position_microfeet
	var created_world_item_ids: Array[String] = []
	for drop_record: Dictionary in reward.get("drop_codes", []):
		var code := String(drop_record.get("code", ""))
		for occurrence in range(int(drop_record.get("count", 0))):
			var resolver := DropResolver.new(func(minimum: int, maximum: int) -> Dictionary:
				return {
					"value": simulation.roll_int(minimum, maximum),
					"rng_draw_index": simulation.random.get_draw_count(),
				}
			)
			var resolution: Dictionary = resolver.resolve(code, player_level)
			resolution["actor_id"] = actor_key
			resolution["creature_id"] = creature_id
			resolution["defeat_event_id"] = defeat_event_id
			resolution["occurrence"] = occurrence + 1
			var resolution_event := simulation.record_reward_event(
				&"reward_drop_resolved", defeated_actor_id, player_actor_id,
				resolution, defeat_event_id
			)
			resolution["event_id"] = resolution_event.event_id
			drop_resolutions.append(resolution.duplicate(true))
			for item: Dictionary in resolution.get("items", []):
				var item_id := _next_world_item_id(actor_key)
				var creation := simulation.create_ground_loot_item(
					item_id, item, actor_position, defeated_actor_id,
					resolution_event.event_id,
					{"source_kind": "random_drop", "drop_code": code, "occurrence": occurrence + 1}
				)
				if creation.get("success", false):
					created_world_item_ids.append(item_id)
	for possession: Dictionary in Catalog.get_possessions(creature_id):
		var item_id := _next_world_item_id(actor_key)
		var transfer := simulation.transfer_defeated_actor_possession_to_ground(
			defeated_actor_id, item_id, possession, award_event_id
		)
		if transfer.get("success", false):
			created_world_item_ids.append(item_id)
		else:
			simulation.record_reward_event(
				&"reward_possession_transfer_blocked", defeated_actor_id, player_actor_id,
				{
					"definition_id": possession.get("definition_id", ""),
					"reason": transfer.get("reason", "possession_transfer_failed"),
					"defeat_event_id": defeat_event_id,
				}, award_event_id
			)
	for inventory_possession: Dictionary in Catalog.get_inventory_possessions(creature_id):
		var item_id := _next_world_item_id(actor_key)
		var transfer := simulation.transfer_defeated_actor_inventory_to_ground(
			defeated_actor_id, item_id, inventory_possession, award_event_id
		)
		if transfer.get("success", false):
			created_world_item_ids.append(item_id)
	if not reward.is_empty():
		var progression := simulation.apply_character_experience_award(player_actor_id, award_event_id, xp, earned_xp, spent_xp)
		if progression.get("success",false): player_level = int(progression.level)
	_sync(simulation)
	if reward.is_empty():
		return {"success": true, "blocked": true, "reason": blocked_reason, "event_id": blocked_event_id, "world_item_ids": created_world_item_ids}
	return {
		"success": true,
		"xp": xp,
		"award_event_id": award_event_id,
		"world_item_ids": created_world_item_ids,
	}


func note_collection(simulation: CombatSimulation, world_item_id: String) -> void:
	collected_world_item_ids[world_item_id] = true
	_sync(simulation)


func get_purchase_options(simulation: CombatSimulation) -> Array[Dictionary]:
	var actor := simulation.get_actor_definition(player_actor_id)
	var options := Advancement.build_actor_purchase_options(actor)
	for option: Dictionary in options:
		if mode == MODE_TEST:
			option["available"] = false
			option["blocked_reason"] = "test_mode_advancement_prohibited"
			continue
		if option.get("available", false) and int(option.get("cost", 0)) > earned_xp - spent_xp:
			option["available"] = false
			option["blocked_reason"] = "insufficient_xp"
	return options


func purchase_advancement(
	simulation: CombatSimulation,
	request_id: String,
	purchase_kind: StringName,
	target_id: StringName
) -> Dictionary:
	if request_id.is_empty():
		return {"success": false, "reason": "advancement_request_id_required"}
	if processed_purchase_request_ids.has(request_id):
		return {"success": false, "reason": "duplicate_advancement_request"}
	if mode == MODE_TEST:
		return {"success": false, "reason": "test_mode_advancement_prohibited"}
	var matching_option := {}
	for option: Dictionary in get_purchase_options(simulation):
		if String(option.get("purchase_kind", "")) == String(purchase_kind) \
		and String(option.get("target_id", "")) == String(target_id):
			matching_option = option
			break
	if matching_option.is_empty():
		return {"success": false, "reason": "invalid_advancement_target"}
	if not matching_option.get("available", false):
		return {
			"success": false,
			"reason": String(matching_option.get("blocked_reason", "advancement_unavailable")),
			"preview": matching_option.duplicate(true),
		}
	var cost := int(matching_option.get("cost", 0))
	if cost <= 0 or earned_xp - spent_xp < cost:
		return {"success": false, "reason": "insufficient_xp"}
	var current_value := int(matching_option.get("current_value", -1))
	var target_value := int(matching_option.get("target_value", -1))
	var application := simulation.apply_verified_character_advancement(
		player_actor_id, purchase_kind, target_id, current_value, target_value
	)
	if not application.get("success", false):
		return application
	spent_xp += cost
	var player_state := simulation.get_actor_state(player_actor_id)
	if not player_state.progression.is_empty():
		player_state.progression["run_spent_xp"] = spent_xp
		player_state.progression["expc"] = int(simulation.get_actor_definition(player_actor_id).progression_policy.initial_expc) + earned_xp - spent_xp
		player_state.revision += 1
	processed_purchase_request_ids[request_id] = true
	var record := {
		"request_id": request_id,
		"actor_id": String(player_actor_id),
		"purchase_kind": String(purchase_kind),
		"target_id": String(target_id),
		"value_before": current_value,
		"value_after": target_value,
		"cost": cost,
		"earned_xp": earned_xp,
		"spent_xp": spent_xp,
		"unspent_xp": earned_xp - spent_xp,
		"source_ref": matching_option.get("source_ref", ""),
		"preserved_state": application.get("preserved_state", {}).duplicate(true),
	}
	var purchase_event := simulation.record_reward_event(
		&"reward_advancement_purchased", player_actor_id, player_actor_id,
		record.duplicate(true)
	)
	record["event_id"] = purchase_event.event_id
	purchase_records.append(record.duplicate(true))
	_sync(simulation)
	return {
		"success": true,
		"purchase": record.duplicate(true),
		"application": application.duplicate(true),
	}


func to_dictionary() -> Dictionary:
	var actor_ids: Array = processed_actor_ids.keys()
	actor_ids.sort()
	var event_ids: Array = processed_defeat_event_ids.keys()
	event_ids.sort()
	var collected_ids: Array = collected_world_item_ids.keys()
	collected_ids.sort()
	var purchase_request_ids: Array = processed_purchase_request_ids.keys()
	purchase_request_ids.sort()
	var snapshot := {
		"mode": mode,
		"player_actor_id": String(player_actor_id),
		"player_level": player_level,
		"current_wave_id": current_wave_id,
		"current_wave_earned_xp": current_wave_earned_xp,
		"earned_xp": earned_xp,
		"spent_xp": spent_xp,
		"unspent_xp": earned_xp - spent_xp,
		"awards": awards.duplicate(true),
		"drop_resolutions": drop_resolutions.duplicate(true),
		"purchase_records": purchase_records.duplicate(true),
		"processed_actor_ids": actor_ids,
		"processed_defeat_event_ids": event_ids,
		"collected_world_item_ids": collected_ids,
		"processed_purchase_request_ids": purchase_request_ids,
		"next_world_item_sequence": _next_world_item_sequence,
		"spending_available": mode != MODE_TEST,
		"spending_blocked_reason": "" if mode != MODE_TEST else "test_mode_advancement_prohibited",
	}
	if not profile_ownership.is_empty(): snapshot["profile_ownership"] = profile_ownership.duplicate(true)
	return snapshot


func _next_world_item_id(actor_id: String) -> String:
	var result := "loot:%s:%06d" % [actor_id, _next_world_item_sequence]
	_next_world_item_sequence += 1
	return result


func _sync(simulation: CombatSimulation) -> void:
	simulation.set_reward_state_snapshot(to_dictionary())
