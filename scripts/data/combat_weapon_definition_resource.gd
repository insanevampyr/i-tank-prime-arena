class_name CombatWeaponDefinitionResource
extends Resource

const INVALID_HAND_REQUIREMENT := -1

@export var definition_id: StringName
@export var display_name: String
@export var damage_dice_count: int = -1
@export var damage_die_sides: int = -1
@export var fixed_damage_bonus: int = 0
@export var strength_bonus_eligible: bool = false
@export var damage_types: PackedStringArray = PackedStringArray()
@export var reach_microfeet: int = -1
@export var strength_requirement: int = -1
@export var one_hand_strength_requirement: int = -1
@export_range(1, 2) var base_hands_required: int = 1
@export var block_target: int = -1
@export var required_acts: int = 1
@export var critical_success_max_natural: int = 1
@export var approach_attack_eligible: bool = false
@export var ducking_policy: StringName = &"unresolved"
@export var combat_ready: bool = true
@export var blocked_capabilities: PackedStringArray = PackedStringArray()
@export var source_refs: PackedStringArray = PackedStringArray()


func validate_definition() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if String(definition_id).is_empty():
		issues.append(_issue("invalid", "missing_weapon_identifier"))
	if display_name.strip_edges().is_empty():
		issues.append(_issue("invalid", "missing_weapon_display_name"))
	if damage_dice_count <= 0 or damage_die_sides <= 0:
		issues.append(_issue("invalid", "invalid_weapon_damage_dice"))
	if damage_types.is_empty():
		issues.append(_issue("invalid", "missing_weapon_damage_type"))
	for damage_type: String in damage_types:
		if not ["bashing", "slashing", "piercing"].has(damage_type):
			issues.append(_issue("not_yet_implemented", "unsupported_weapon_damage_type", {"damage_type": damage_type}))
	if reach_microfeet < 0:
		issues.append(_issue("invalid", "invalid_weapon_reach"))
	if strength_requirement < 0:
		issues.append(_issue("requires_source_verification", "weapon_strength_requirement_unresolved"))
	if base_hands_required < 1 or base_hands_required > 2:
		issues.append(_issue("invalid", "invalid_weapon_hand_requirement"))
	elif base_hands_required == 1 and one_hand_strength_requirement != -1:
		issues.append(_issue("invalid", "unexpected_one_hand_strength_threshold"))
	elif base_hands_required == 2 and strength_requirement >= 0 and one_hand_strength_requirement != strength_requirement * 2:
		issues.append(_issue("invalid", "weapon_one_hand_strength_threshold_mismatch", {
			"expected": strength_requirement * 2,
			"actual": one_hand_strength_requirement,
		}))
	if block_target < 0:
		issues.append(_issue("requires_source_verification", "weapon_block_unresolved"))
	if required_acts <= 0:
		issues.append(_issue("invalid", "invalid_weapon_act_requirement"))
	if critical_success_max_natural < 1 or critical_success_max_natural > 19:
		issues.append(_issue("invalid", "invalid_weapon_critical_range"))
	if not [CombatAttackDefinition.DUCKING_ALLOWED, CombatAttackDefinition.DUCKING_PROHIBITED, CombatAttackDefinition.DUCKING_UNRESOLVED].has(ducking_policy):
		issues.append(_issue("invalid", "invalid_weapon_ducking_policy"))
	if not combat_ready:
		if blocked_capabilities.is_empty():
			issues.append(_issue("invalid", "weapon_not_combat_ready_without_reason"))
		else:
			issues.append(_issue("not_yet_implemented", "weapon_not_combat_ready", {"blocked_capabilities": Array(blocked_capabilities)}))
	if source_refs.is_empty():
		issues.append(_issue("requires_source_verification", "weapon_source_missing"))
	return issues


func effective_hands_required(character_strength: int) -> int:
	if strength_requirement < 0 or character_strength < strength_requirement:
		return INVALID_HAND_REQUIREMENT
	if base_hands_required == 1:
		return 1
	return 1 if character_strength >= strength_requirement * 2 else 2


func make_attack_definition(attack_definition_id: StringName) -> Variant:
	if _has_invalid_issue(validate_definition()) or not combat_ready:
		return null
	var damage := CombatPhysicalDamageDefinition.new(
		damage_dice_count,
		damage_die_sides,
		fixed_damage_bonus,
		strength_bonus_eligible,
		true,
		{
			"torso": {
				"numerator": 1,
				"denominator": 1,
				"source_ref": "PRIME-V3 pp. 95-98, same-size torso hit location 3",
			},
		},
		null,
		true,
		CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		source_refs
	)
	var critical_policy := CombatCriticalTriggerPolicy.new(
		StringName("%s_critical_range" % String(definition_id)),
		critical_success_max_natural,
		0,
		20,
		&"",
		"%s: natural 1-%d is a critical strike" % [display_name, critical_success_max_natural],
		"PRIME-V3 natural 20 critical failure",
		source_refs
	)
	return CombatAttackDefinition.new(
		attack_definition_id,
		definition_id,
		required_acts,
		true,
		true,
		0,
		{"torso": 0},
		PackedStringArray(["torso"]),
		0,
		reach_microfeet,
		true,
		source_refs,
		&"hand_held",
		damage_types,
		true,
		ducking_policy,
		damage,
		critical_policy,
		approach_attack_eligible
	)


func make_block_definition() -> Variant:
	if _has_invalid_issue(validate_definition()) or block_target < 0:
		return null
	return CombatBlockDefinition.new(
		CombatBlockDefinition.TYPE_WEAPON,
		definition_id,
		block_target,
		0,
		true,
		true,
		null,
		source_refs
	)


func to_dictionary() -> Dictionary:
	return {
		"definition_id": String(definition_id), "display_name": display_name,
		"damage_dice_count": damage_dice_count, "damage_die_sides": damage_die_sides,
		"fixed_damage_bonus": fixed_damage_bonus, "strength_bonus_eligible": strength_bonus_eligible,
		"damage_types": Array(damage_types), "reach_microfeet": reach_microfeet,
		"strength_requirement": strength_requirement, "one_hand_strength_requirement": one_hand_strength_requirement,
		"base_hands_required": base_hands_required,
		"block_target": block_target, "required_acts": required_acts,
		"critical_success_max_natural": critical_success_max_natural,
		"approach_attack_eligible": approach_attack_eligible, "ducking_policy": String(ducking_policy),
		"combat_ready": combat_ready, "blocked_capabilities": Array(blocked_capabilities),
		"source_refs": Array(source_refs),
	}


func _has_invalid_issue(issues: Array[Dictionary]) -> bool:
	for issue: Dictionary in issues:
		if issue["status"] == "invalid":
			return true
	return false


func _issue(status: String, code: String, details: Dictionary = {}) -> Dictionary:
	return {"status": status, "code": code, "details": details.duplicate(true)}
