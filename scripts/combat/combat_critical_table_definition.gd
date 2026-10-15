class_name CombatCriticalTableDefinition
extends RefCounted

var table_id: StringName
var roll_category: StringName
var weapon_ref: StringName
var outcomes_by_rarity: Dictionary
var prerequisites_by_outcome: Dictionary
var approved: bool
var active: bool
var source_refs: PackedStringArray


func _init(
	p_table_id: StringName,
	p_roll_category: StringName,
	p_weapon_ref: StringName = &"",
	p_outcomes_by_rarity: Dictionary = {},
	p_prerequisites_by_outcome: Dictionary = {},
	p_approved: bool = false,
	p_active: bool = false,
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_table_id).is_empty(), "Critical consequence tables require a stable identifier.")
	assert(not String(p_roll_category).is_empty(), "Critical consequence tables require a roll category.")
	assert(not p_active or p_approved, "An unapproved critical consequence table cannot be active.")
	for rarity: Variant in p_outcomes_by_rarity:
		assert(
			String(rarity) == String(CombatCriticalRecord.RARITY_COMMON)
			or String(rarity) == String(CombatCriticalRecord.RARITY_UNCOMMON)
			or String(rarity) == String(CombatCriticalRecord.RARITY_RARE),
			"Critical consequence tables contain an unsupported rarity."
		)
		assert(typeof(p_outcomes_by_rarity[rarity]) == TYPE_ARRAY, "Critical rarity rows must contain ordered outcome identifiers.")
	table_id = p_table_id
	roll_category = p_roll_category
	weapon_ref = p_weapon_ref
	outcomes_by_rarity = p_outcomes_by_rarity.duplicate(true)
	prerequisites_by_outcome = p_prerequisites_by_outcome.duplicate(true)
	approved = p_approved
	active = p_active
	source_refs = p_source_refs.duplicate()


func to_dictionary() -> Dictionary:
	return {
		"table_id": String(table_id),
		"roll_category": String(roll_category),
		"weapon_ref": String(weapon_ref),
		"outcomes_by_rarity": outcomes_by_rarity.duplicate(true),
		"prerequisites_by_outcome": prerequisites_by_outcome.duplicate(true),
		"approved": approved,
		"active": active,
		"source_refs": Array(source_refs),
	}
