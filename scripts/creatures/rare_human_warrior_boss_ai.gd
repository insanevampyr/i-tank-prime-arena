class_name RareHumanWarriorBossAI
extends RefCounted

const Fixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")

const MICROFEET_PER_FOOT := 1_000_000
const ROUND_DURATION_US := 5_000_000
const SPEAR_REACH_MICROFEET := 6_000_000
const UNARMED_REACH_MICROFEET := 1_000_000
const PICKUP_REACH_MICROFEET := 1_000_000
const REPATH_DISTANCE_MICROFEET := 1_000_000
const MIN_MIST_VALUE := 9
const MIN_POTION_VALUE := 7

var _simulation: CombatSimulation
var _battlefield: ArenaBattlefield
var _boss_id: StringName
var _target_id: StringName
var _path: Array[Vector2i] = []
var _path_goal_microfeet: Variant = null
var _path_reach_microfeet: int = 0
var _path_goal_kind: String = ""
var _failed_path_signature: String = ""
var _path_rebuild_count: int = 0
var _failed_path_cache_hits: int = 0
var _last_decision_signature: String = ""
var _abandoned_spear_world_item_id: String = ""


func _init(
		simulation: CombatSimulation,
		battlefield: ArenaBattlefield,
		boss_id: StringName = Fixture.ACTOR_ID,
		target_id: StringName = &"player") -> void:
	assert(simulation != null, "Rare Human Warrior AI requires the authoritative simulation.")
	assert(battlefield != null, "Rare Human Warrior AI requires authoritative battlefield facts.")
	_simulation = simulation
	_battlefield = battlefield
	_boss_id = boss_id
	_target_id = target_id


func evaluate_and_submit() -> Dictionary:
	var boss_state := _simulation.get_actor_state(_boss_id)
	var target_state := _simulation.get_actor_state(_target_id)
	if boss_state == null or target_state == null:
		return _decision("blocked_missing_actor", false)
	if boss_state.current_hpc == null or int(boss_state.current_hpc) <= 0:
		return _decision("stopped_incapacitated", false)
	if target_state.current_hpc == null or int(target_state.current_hpc) <= 0:
		return _decision("stopped_target_defeated", false)
	if boss_state.awareness != &"aware":
		return _decision("blocked_unaware", false)
	if boss_state.critical_stagger_until_us > _simulation.clock.get_elapsed_us():
		return _decision("blocked_critical_stagger", false)
	if not boss_state.current_action_instance_id.is_empty() or _has_attack_in_flight(_boss_id):
		return _decision("action_in_progress", false)
	if boss_state.conditions.has("prone"):
		return _submit_result(
			"stand",
			_simulation.start_stand_action(_boss_id, _request_id("stand"))
		)

	# Restore an already-held grip through the shared engine, never by mutating hands.
	var handling_refs := boss_state.weapon_handling.keys()
	handling_refs.sort()
	for ref: String in handling_refs:
		if String(boss_state.weapon_handling[ref]) == CombatWeaponHandling.ONE_HAND_HOLD \
		and _simulation.get_weapon_handling_preview(_boss_id, StringName(ref), "regrip").get("success", false):
			var regrip := _simulation.request_weapon_handling(_boss_id, StringName(ref), "regrip", _request_id("regrip"))
			if regrip.get("success", false): _record_decision("regrip_weapon", regrip)
	var dropped_spear := _find_owned_spear_world_item()
	var spear_held := _is_spear_held(boss_state)
	if dropped_spear.is_empty():
		_abandoned_spear_world_item_id = ""
	var geometry := _geometry_to_target(SPEAR_REACH_MICROFEET if spear_held else UNARMED_REACH_MICROFEET)
	var hpm := int(_simulation.get_actor_definition(_boss_id).get_combat_stat("hpm"))
	var missing_hpc := maxi(0, hpm - int(boss_state.current_hpc))

	if not dropped_spear.is_empty():
		var item_position: Variant = dropped_spear.get("position_microfeet")
		if String(dropped_spear.get("state", "")) == "dropped" and item_position is Vector2i \
		and _within_reach(boss_state.position_microfeet, item_position, PICKUP_REACH_MICROFEET):
			var retrieval := _submit_result(
				"retrieve_spear",
				_simulation.start_world_item_retrieval_action(
					_boss_id, String(dropped_spear.get("world_item_id", "")), _request_id("retrieve_spear")
				)
			)
			if not retrieval.get("success", false):
				_abandoned_spear_world_item_id = String(dropped_spear.get("world_item_id", ""))
			return retrieval

		var healing := _try_healing_action(boss_state, missing_hpc, geometry)
		if not healing.is_empty():
			return healing
		var gathering := _try_gather_defensive_dirt(boss_state, missing_hpc)
		if not gathering.is_empty():
			return gathering
		var support := _try_prepared_combat_ability(boss_state, missing_hpc)
		if not support.is_empty():
			return support
		if geometry.get("success", false):
			return _submit_unarmed_attack()
		if _is_current_spear_recovery_abandoned(dropped_spear):
			return _decision("approach_unarmed", false, {"reason": "spear_recovery_unreachable"})
		if String(dropped_spear.get("state", "")) == "dropped" and item_position is Vector2i:
			return _decision("approach_spear", false, {"world_item_id": dropped_spear.get("world_item_id", "")})
		return _decision("await_spear_landing", false)

	if not spear_held:
		var healing := _try_healing_action(boss_state, missing_hpc, geometry)
		if not healing.is_empty():
			return healing
		var support := _try_prepared_combat_ability(boss_state, missing_hpc)
		if not support.is_empty():
			return support
		if geometry.get("success", false):
			return _submit_unarmed_attack()
		return _decision("approach_unarmed", false)

	var healing := _try_healing_action(boss_state, missing_hpc, geometry)
	if not healing.is_empty():
		return healing
	var prepared_support := _try_prepared_combat_ability(boss_state, missing_hpc)
	if not prepared_support.is_empty():
		return prepared_support

	if not geometry.get("success", false):
		var rage := _try_rage(boss_state)
		if not rage.is_empty():
			return rage
	if geometry.get("success", false):
		var called_shot := _try_called_shot(boss_state, target_state)
		if not called_shot.is_empty():
			return called_shot
		return _submit_melee_attack()
	if _should_throw_spear(boss_state):
		return _submit_result(
			"throw_spear",
			Fixture.start_spear_throw(
				_simulation, _boss_id, _target_id, _request_id("throw_spear"), &"torso", true
			)
		)
	return _decision("approach_spear_melee", false)


func advance_movement(delta_us: int) -> Dictionary:
	if delta_us <= 0:
		return {"success": true, "moved": false, "reason": "zero_delta"}
	var boss_state := _simulation.get_actor_state(_boss_id)
	var target_state := _simulation.get_actor_state(_target_id)
	if boss_state == null or target_state == null:
		return {"success": false, "moved": false, "reason": "missing_actor"}
	if int(boss_state.current_hpc) <= 0 or int(target_state.current_hpc) <= 0:
		return {"success": false, "moved": false, "reason": "combatant_incapacitated"}
	if boss_state.conditions.has("prone") or boss_state.critical_stagger_until_us > _simulation.clock.get_elapsed_us():
		return {"success": false, "moved": false, "reason": "movement_status_blocked"}
	if not boss_state.current_action_instance_id.is_empty():
		var action := _simulation.get_action(boss_state.current_action_instance_id)
		var action_definition := null if action == null else _simulation.get_action_definition(action.action_definition_id)
		if action_definition == null or not action_definition.allows_movement:
			return {"success": false, "moved": false, "reason": "movement_restricted_by_action"}

	var movement_goal := _movement_goal()
	if not movement_goal.get("success", false):
		return {"success": false, "moved": false, "reason": movement_goal.get("reason", "no_movement_goal")}
	var goal: Vector2i = movement_goal["position_microfeet"]
	var reach := int(movement_goal["reach_microfeet"])
	if _within_reach(boss_state.position_microfeet, goal, reach) \
	and (String(movement_goal.get("kind", "")) == "world_item" \
		or _battlefield.has_line_of_sight(boss_state.position_microfeet, goal)):
		_clear_path()
		return {"success": true, "moved": false, "reason": "goal_reached"}
	var path_result := _ensure_path(goal, reach, String(movement_goal.get("kind", "target")))
	if not path_result.get("success", false) or _path.is_empty():
		return {"success": false, "moved": false, "reason": path_result.get("reason", "no_legal_path")}

	var definition := _simulation.get_actor_definition(_boss_id)
	var movement_rate := int(definition.get_combat_stat("mr"))
	var tick_budget := int((movement_rate * MICROFEET_PER_FOOT * delta_us) / ROUND_DURATION_US)
	var remaining := 0 if boss_state.remaining_mr_microfeet == null else int(boss_state.remaining_mr_microfeet)
	var budget := mini(tick_budget, remaining)
	if budget <= 0:
		return {"success": true, "moved": false, "reason": "movement_budget_exhausted"}
	var waypoint: Vector2i = _path[0]
	var offset := waypoint - boss_state.position_microfeet
	var distance := roundi(Vector2(offset).length())
	var destination := waypoint
	if distance > budget:
		destination = boss_state.position_microfeet + Vector2i(
			roundi(float(offset.x) * float(budget) / float(distance)),
			roundi(float(offset.y) * float(budget) / float(distance))
		)
	var resolved := _battlefield.resolve_motion(
		_boss_id, boss_state.position_microfeet, destination, _actor_occupancy()
	)
	if not resolved.get("success", false) or int(resolved.get("movement_cost_microfeet", 0)) <= 0:
		_clear_path()
		return {"success": false, "moved": false, "reason": resolved.get("reason", "movement_blocked")}
	var resolved_position: Vector2i = resolved["position_microfeet"]
	var movement := _simulation.apply_authoritative_position(
		_boss_id,
		resolved_position,
		_facing_millidegrees_for_displacement(
			resolved_position - boss_state.position_microfeet, boss_state.facing_millidegrees
		),
		int(resolved["movement_cost_microfeet"])
	)
	if not movement.get("success", false):
		_clear_path()
		return {"success": false, "moved": false, "reason": movement.get("reason", "movement_rejected")}
	if resolved_position == waypoint:
		_path.pop_front()
	elif bool(resolved.get("blocked", false)):
		_clear_path()
	return {
		"success": true,
		"moved": true,
		"position_microfeet": resolved_position,
		"movement_cost_microfeet": int(resolved["movement_cost_microfeet"]),
	}


func get_diagnostics() -> Dictionary:
	return {
		"path_rebuild_count": _path_rebuild_count,
		"failed_path_cache_hits": _failed_path_cache_hits,
		"cached_waypoint_count": _path.size(),
		"last_decision_signature": _last_decision_signature,
		"abandoned_spear_world_item_id": _abandoned_spear_world_item_id,
	}


func _try_healing_action(boss_state: CombatActorState, missing_hpc: int, geometry: Dictionary) -> Dictionary:
	if missing_hpc <= 0:
		return {}
	var target_attacking_boss := _target_has_attack_in_flight()
	var opportunity_justified: bool = missing_hpc >= MIN_MIST_VALUE \
		and (target_attacking_boss or missing_hpc >= 14)
	var mist_definition := Fixture.make_rejuvenating_mist_action_definition()
	if opportunity_justified and _simulation.get_ability_payment_preview(_boss_id, mist_definition).get("success", false):
		return _submit_result(
			"rejuvenating_mist",
			_simulation.start_verified_special_action(
				_boss_id, _boss_id, mist_definition, _request_id("rejuvenating_mist")
			)
		)
	var potion_count := int(boss_state.inventory_quantities.get(String(Fixture.HEALTH_POTION_INVENTORY_ID), 0))
	var free_hand := String(boss_state.hand_occupancy.get("left", "")).is_empty() \
		or String(boss_state.hand_occupancy.get("right", "")).is_empty()
	if missing_hpc >= MIN_POTION_VALUE and potion_count > 0 \
	and (not target_attacking_boss or not geometry.get("success", false)):
		if not free_hand:
			var refs := Array(boss_state.equipment_refs)
			refs.sort()
			for ref: String in refs:
				if not _simulation.get_weapon_handling_preview(_boss_id, StringName(ref), "hold_one").get("success", false): continue
				var shifted := _simulation.request_weapon_handling(_boss_id, StringName(ref), "hold_one", _request_id("potion_hold_one"))
				if shifted.get("success", false):
					free_hand = true
					break
		if not free_hand: return {}
		return _submit_result(
			"health_potion",
			_simulation.start_verified_consumable_healing_action(
				_boss_id, Fixture.make_health_potion_action_definition(), _request_id("health_potion")
			)
		)
	return {}


func _try_prepared_combat_ability(boss_state: CombatActorState, missing_hpc: int) -> Dictionary:
	if int(boss_state.held_materials.get("dirt", 0)) <= 0 \
		or boss_state.timed_stat_effects.has(String(Fixture.DEFENSIVE_BUFF_EFFECT_ID)):
		return {}
	if missing_hpc <= 0 and not _target_has_attack_in_flight():
		return {}
	var definition := Fixture.make_defensive_buff_action_definition()
	if not _simulation.get_ability_payment_preview(_boss_id, definition).get("success", false):
		return {}
	return _submit_result(
		"defensive_buff",
		_simulation.start_verified_special_action(
			_boss_id, _boss_id, definition, _request_id("defensive_buff")
		)
	)


func _try_gather_defensive_dirt(boss_state: CombatActorState, missing_hpc: int) -> Dictionary:
	if missing_hpc < 20 and not _target_has_attack_in_flight():
		return {}
	if int(boss_state.held_materials.get("dirt", 0)) > 0 \
		or not String(boss_state.hand_occupancy.get("left", "")).is_empty() \
		or boss_state.timed_stat_effects.has(String(Fixture.DEFENSIVE_BUFF_EFFECT_ID)):
		return {}
	var definition := Fixture.make_defensive_buff_action_definition()
	if not _simulation.get_ability_payment_preview(_boss_id, definition).get("success", false):
		return {}
	var surface := _battlefield.get_gatherable_material_at(boss_state.position_microfeet, &"dirt")
	if not surface.get("available", false):
		return {}
	return _submit_result(
		"gather_dirt",
		_simulation.start_gather_material_action(
			_boss_id, &"dirt", String(surface.get("surface_id", "")), _request_id("gather_dirt")
		)
	)


func _try_rage(boss_state: CombatActorState) -> Dictionary:
	if boss_state.timed_stat_effects.has(String(Fixture.RAGE_EFFECT_ID)):
		return {}
	var definition := Fixture.make_rage_action_definition()
	if not _simulation.get_ability_payment_preview(_boss_id, definition).get("success", false):
		return {}
	return _submit_result(
		"rage",
		_simulation.start_verified_timed_stat_effect_action(_boss_id, definition, _request_id("rage"))
	)


func _try_called_shot(boss_state: CombatActorState, target_state: CombatActorState) -> Dictionary:
	if not boss_state.pending_called_shot.is_empty() or int(target_state.current_hpc) <= 40:
		return {}
	var definition := Fixture.make_called_shot_action_definition()
	if not _simulation.get_ability_payment_preview(_boss_id, definition).get("success", false):
		return {}
	return _submit_result(
		"called_shot",
		_simulation.start_verified_special_action(
			_boss_id, _target_id, definition, _request_id("called_shot"), &"torso"
		)
	)


func _submit_melee_attack() -> Dictionary:
	var definition := Fixture.make_melee_attack_definition(_targeting_profile())
	return _submit_result(
		"spear_melee",
		_simulation.start_physical_attack(
			_boss_id, _target_id, definition, _request_id("spear_melee"), &"torso", true
		)
	)


func _submit_unarmed_attack() -> Dictionary:
	return _submit_result(
		"unarmed_attack",
		Fixture.start_unarmed_fallback_attack(
			_simulation, _boss_id, _target_id, _request_id("unarmed_attack"), &"torso", true
		)
	)


func _should_throw_spear(boss_state: CombatActorState) -> bool:
	var target_state := _simulation.get_actor_state(_target_id)
	if target_state == null or not _battlefield.has_line_of_sight(boss_state.position_microfeet, target_state.position_microfeet):
		return false
	var distance := roundi(Vector2(target_state.position_microfeet - boss_state.position_microfeet).length())
	if distance <= SPEAR_REACH_MICROFEET or distance > Fixture.THROW_RANGE_MICROFEET:
		return false
	# Throw only when an immediate legal attack avoids more travel than the
	# boss can fund this round. Otherwise retaining melee Block and pursuing is
	# the stable tactical preference.
	var actor_definition := _simulation.get_actor_definition(_boss_id)
	var action_duration_us := int(ROUND_DURATION_US / int(actor_definition.get_combat_stat("at")))
	var approach_before_effect := int(
		int(actor_definition.get_combat_stat("mr")) * MICROFEET_PER_FOOT * action_duration_us / ROUND_DURATION_US
	)
	var remaining := 0 if boss_state.remaining_mr_microfeet == null else int(boss_state.remaining_mr_microfeet)
	return distance - SPEAR_REACH_MICROFEET > mini(approach_before_effect, remaining)


func _movement_goal() -> Dictionary:
	var boss_state := _simulation.get_actor_state(_boss_id)
	var target_state := _simulation.get_actor_state(_target_id)
	if boss_state == null or target_state == null:
		return {"success": false, "reason": "missing_actor"}
	var spear := _find_owned_spear_world_item()
	if not spear.is_empty():
		if String(spear.get("state", "")) != "dropped" or not (spear.get("position_microfeet") is Vector2i):
			return {"success": false, "reason": "spear_position_unavailable"}
		if _within_reach(boss_state.position_microfeet, target_state.position_microfeet, UNARMED_REACH_MICROFEET) \
		and _battlefield.has_line_of_sight(boss_state.position_microfeet, target_state.position_microfeet):
			return {"success": true, "position_microfeet": target_state.position_microfeet, "reach_microfeet": UNARMED_REACH_MICROFEET, "kind": "target"}
		if _is_current_spear_recovery_abandoned(spear):
			return {"success": true, "position_microfeet": target_state.position_microfeet, "reach_microfeet": UNARMED_REACH_MICROFEET, "kind": "target"}
		return {"success": true, "position_microfeet": spear["position_microfeet"], "reach_microfeet": PICKUP_REACH_MICROFEET, "kind": "world_item"}
	return {
		"success": true,
		"position_microfeet": target_state.position_microfeet,
		"reach_microfeet": SPEAR_REACH_MICROFEET if _is_spear_held(boss_state) else UNARMED_REACH_MICROFEET,
		"kind": "target",
	}


func _ensure_path(goal: Vector2i, reach: int, goal_kind: String) -> Dictionary:
	var boss_state := _simulation.get_actor_state(_boss_id)
	var needs_rebuild := _path.is_empty() or _path_goal_microfeet == null \
		or _path_reach_microfeet != reach or _path_goal_kind != goal_kind
	if not needs_rebuild:
		var offset: Vector2i = goal - (_path_goal_microfeet as Vector2i)
		needs_rebuild = offset.length_squared() >= REPATH_DISTANCE_MICROFEET * REPATH_DISTANCE_MICROFEET
	if not needs_rebuild and not _path.is_empty():
		needs_rebuild = not _battlefield.is_direct_path_clear(
			_boss_id, boss_state.position_microfeet, _path[0], _actor_occupancy()
		)
	if not needs_rebuild:
		return {"success": true, "reason": "cached_path"}
	var failure_signature := "%s|%s|%s|%s" % [boss_state.position_microfeet, goal, reach, _occupancy_signature()]
	if _failed_path_signature == failure_signature:
		_failed_path_cache_hits += 1
		return {"success": false, "reason": "unchanged_blocked_path"}
	var result := _battlefield.find_path_to_reach_position(
		_boss_id, boss_state.position_microfeet, goal, reach, _actor_occupancy()
	) if goal_kind == "world_item" else _battlefield.find_path_to_attack_position(
		_boss_id, boss_state.position_microfeet, goal, reach, _actor_occupancy()
	)
	_path_rebuild_count += 1
	_path.clear()
	_path_goal_microfeet = goal
	_path_reach_microfeet = reach
	_path_goal_kind = goal_kind
	if result.get("success", false):
		for waypoint: Vector2i in result.get("waypoints", []):
			_path.append(waypoint)
		_failed_path_signature = ""
		if goal_kind == "world_item":
			_abandoned_spear_world_item_id = ""
	else:
		_failed_path_signature = failure_signature
		if goal_kind == "world_item":
			var spear := _find_owned_spear_world_item()
			_abandoned_spear_world_item_id = String(spear.get("world_item_id", ""))
	return result


func _is_current_spear_recovery_abandoned(spear: Dictionary) -> bool:
	var world_item_id := String(spear.get("world_item_id", ""))
	return not world_item_id.is_empty() and world_item_id == _abandoned_spear_world_item_id


func _actor_occupancy() -> Dictionary:
	var occupancy := {}
	for actor_entry: Dictionary in _simulation.get_state_snapshot().get("actors", []):
		var state: Dictionary = actor_entry.get("state", {})
		if state.get("current_hpc") == null or int(state.get("current_hpc", 0)) <= 0:
			continue
		var serialized: Array = state.get("position_microfeet", [])
		if serialized.size() == 2:
			occupancy[String(state.get("actor_id", ""))] = Vector2i(int(serialized[0]), int(serialized[1]))
	return occupancy


func _occupancy_signature() -> String:
	var occupancy := _actor_occupancy()
	var keys: Array = occupancy.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key: String in keys:
		parts.append("%s:%s" % [key, occupancy[key]])
	return "|".join(parts)


func _find_owned_spear_world_item() -> Dictionary:
	for item: Dictionary in _simulation.get_state_snapshot().get("world_items", []):
		if String(item.get("owner_actor_id", "")) != String(_boss_id) \
		or String(item.get("equipment_ref", "")) != String(Fixture.WEAPON_REF):
			continue
		var copy := item.duplicate(true)
		var serialized: Variant = copy.get("position_microfeet")
		if serialized is Array and serialized.size() == 2:
			copy["position_microfeet"] = Vector2i(int(serialized[0]), int(serialized[1]))
		return copy
	return {}


func _is_spear_held(state: CombatActorState) -> bool:
	return state.equipment_refs.has(String(Fixture.WEAPON_REF)) \
		and String(state.hand_occupancy.get("left", "")) == String(Fixture.WEAPON_REF) \
		and String(state.hand_occupancy.get("right", "")) == String(Fixture.WEAPON_REF)


func _geometry_to_target(reach: int) -> Dictionary:
	var boss_state := _simulation.get_actor_state(_boss_id)
	var target_state := _simulation.get_actor_state(_target_id)
	if boss_state == null or target_state == null:
		return {"success": false, "reason": "missing_actor"}
	var distance := roundi(Vector2(target_state.position_microfeet - boss_state.position_microfeet).length())
	return {
		"success": distance <= reach and _battlefield.has_line_of_sight(boss_state.position_microfeet, target_state.position_microfeet),
		"distance_microfeet": distance,
		"line_of_sight": _battlefield.has_line_of_sight(boss_state.position_microfeet, target_state.position_microfeet),
	}


func _has_attack_in_flight(actor_id: StringName) -> bool:
	for attack: Dictionary in _simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("attacker_id", "")) != String(actor_id):
			continue
		if String(attack.get("status", "")) in [
			CombatAttackInstance.STATUS_EXECUTING,
			CombatAttackInstance.STATUS_PENDING_DEFENSE,
			CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT,
			CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED,
		]:
			return true
	return false


func _target_has_attack_in_flight() -> bool:
	for attack: Dictionary in _simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("attacker_id", "")) == String(_target_id) \
		and String(attack.get("target_id", "")) == String(_boss_id) \
		and String(attack.get("status", "")) in [
			CombatAttackInstance.STATUS_EXECUTING,
			CombatAttackInstance.STATUS_PENDING_DEFENSE,
			CombatAttackInstance.STATUS_PENDING_DODGE_DISPLACEMENT,
			CombatAttackInstance.STATUS_DEFENSES_EXHAUSTED,
		]:
			return true
	return false


func _targeting_profile() -> Dictionary:
	var boss := _simulation.get_actor_definition(_boss_id)
	var target := _simulation.get_actor_definition(_target_id)
	if boss == null or target == null:
		return {}
	var result := CombatHitLocationCatalog.resolve_attack_profile(boss.size_category, target.size_category)
	return result if result.get("success", false) else {}


func _request_id(action_name: String) -> String:
	return "task35h:%s:%s:%s" % [String(_boss_id), _simulation.clock.get_elapsed_us(), action_name]


func _submit_result(selected_action: String, result: Dictionary) -> Dictionary:
	var success := bool(result.get("success", false))
	_record_decision(selected_action if success else "rejected_%s" % selected_action, {
		"result": result.duplicate(true),
	})
	var response := result.duplicate(true)
	response["selected_action"] = selected_action
	response["action_started"] = success
	return response


func _decision(selected_action: String, action_started: bool, evidence: Dictionary = {}) -> Dictionary:
	_record_decision(selected_action, evidence)
	return {
		"success": true,
		"selected_action": selected_action,
		"action_started": action_started,
		"evidence": evidence.duplicate(true),
	}


func _record_decision(selected_action: String, evidence: Dictionary) -> void:
	var boss_state := _simulation.get_actor_state(_boss_id)
	var target_state := _simulation.get_actor_state(_target_id)
	var signature := "%s|%s|%s|%s|%s|%s" % [
		selected_action,
		boss_state.current_hpc if boss_state != null else "?",
		target_state.current_hpc if target_state != null else "?",
		boss_state.equipment_refs if boss_state != null else [],
		boss_state.ability_daily_remaining if boss_state != null else {},
		boss_state.timed_stat_effects.keys() if boss_state != null else [],
	]
	if signature == _last_decision_signature:
		return
	_last_decision_signature = signature
	_simulation.record_tactical_decision(_boss_id, _target_id, {
		"controller": "rare_human_warrior_boss_ai",
		"selected_action": selected_action,
		"observable_evidence": evidence.duplicate(true),
		"boss_hpc": boss_state.current_hpc if boss_state != null else null,
		"target_hpc": target_state.current_hpc if target_state != null else null,
		"spear_held": _is_spear_held(boss_state) if boss_state != null else false,
		"active_effects": boss_state.timed_stat_effects.keys() if boss_state != null else [],
		"ability_daily_remaining": boss_state.ability_daily_remaining.duplicate(true) if boss_state != null else {},
		"inventory_quantities": boss_state.inventory_quantities.duplicate(true) if boss_state != null else {},
	})


func _within_reach(start: Vector2i, finish: Vector2i, reach: int) -> bool:
	var offset := finish - start
	return offset.length_squared() <= reach * reach


static func _facing_millidegrees_for_displacement(displacement: Vector2i, fallback_facing: int) -> int:
	if displacement == Vector2i.ZERO:
		return posmod(fallback_facing, 360_000)
	return posmod(roundi(rad_to_deg(Vector2(displacement).angle()) * 1000.0), 360_000)


func _clear_path() -> void:
	_path.clear()
	_path_goal_microfeet = null
	_path_reach_microfeet = 0
	_path_goal_kind = ""
