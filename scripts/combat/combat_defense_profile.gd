class_name CombatDefenseProfile
extends RefCounted

const DODGE := &"dodge"
const WEAPON_BLOCK := &"weapon_block"
const SHIELD_BLOCK := &"shield_block"
const PHYSICAL_SOAK := &"physical_soak"
const ALL_DEFENSES := [DODGE, WEAPON_BLOCK, SHIELD_BLOCK, PHYSICAL_SOAK]

var profile_id: StringName
var priority: PackedStringArray
var modifiers: Dictionary
var weapon_block: CombatBlockDefinition
var shield_block: CombatBlockDefinition
var source_refs: PackedStringArray


func _init(
	p_profile_id: StringName,
	p_priority: PackedStringArray = PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
	p_modifiers: Dictionary = {},
	p_weapon_block: CombatBlockDefinition = null,
	p_shield_block: CombatBlockDefinition = null,
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_profile_id).is_empty(), "Defense profiles require a stable identifier.")
	assert(p_priority.size() == ALL_DEFENSES.size(), "Defense priority must contain each supported defense exactly once.")
	for defense_type: StringName in ALL_DEFENSES:
		assert(p_priority.count(String(defense_type)) == 1, "Defense priority must contain each supported defense exactly once.")
	for key: Variant in p_modifiers:
		assert(ALL_DEFENSES.has(StringName(String(key))), "Defense modifiers may only target supported defenses.")
		assert(typeof(p_modifiers[key]) == TYPE_INT, "Defense modifiers must be integers.")
	if p_weapon_block != null:
		assert(p_weapon_block.defense_type == WEAPON_BLOCK, "Weapon Block slots require a weapon Block definition.")
	if p_shield_block != null:
		assert(p_shield_block.defense_type == SHIELD_BLOCK, "Shield Block slots require a shield Block definition.")
	profile_id = p_profile_id
	priority = p_priority.duplicate()
	modifiers = p_modifiers.duplicate(true)
	weapon_block = p_weapon_block
	shield_block = p_shield_block
	source_refs = p_source_refs.duplicate()


func get_modifier(defense_type: StringName) -> int:
	return int(modifiers.get(String(defense_type), 0))


func to_dictionary() -> Dictionary:
	return {
		"profile_id": String(profile_id),
		"priority": Array(priority),
		"modifiers": modifiers.duplicate(true),
		"weapon_block": null if weapon_block == null else weapon_block.to_dictionary(),
		"shield_block": null if shield_block == null else shield_block.to_dictionary(),
		"source_refs": Array(source_refs),
	}
