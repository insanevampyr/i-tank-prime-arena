class_name CombatBlockDefinition
extends RefCounted

const TYPE_WEAPON := &"weapon_block"
const TYPE_SHIELD := &"shield_block"

var defense_type: StringName
var equipment_ref: StringName
var block_target: Variant
var target_modifier: int
var proficiency_verified: bool
var usable: bool
var current_shp: Variant
var source_refs: PackedStringArray


func _init(
	p_defense_type: StringName,
	p_equipment_ref: StringName,
	p_block_target: Variant,
	p_target_modifier: int = 0,
	p_proficiency_verified: bool = false,
	p_usable: bool = true,
	p_current_shp: Variant = null,
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(p_defense_type == TYPE_WEAPON or p_defense_type == TYPE_SHIELD, "Block definitions must be weapon or shield Blocks.")
	assert(not String(p_equipment_ref).is_empty(), "Block definitions require an equipment reference.")
	if p_block_target != null:
		assert(typeof(p_block_target) == TYPE_INT and int(p_block_target) >= 0, "Resolved BLK targets must be non-negative integers.")
	if p_current_shp != null:
		assert(p_defense_type == TYPE_SHIELD, "Only shield Block definitions may carry SHP.")
		assert(typeof(p_current_shp) == TYPE_INT and int(p_current_shp) >= 0, "Resolved SHP must be a non-negative integer.")
	defense_type = p_defense_type
	equipment_ref = p_equipment_ref
	block_target = p_block_target
	target_modifier = p_target_modifier
	proficiency_verified = p_proficiency_verified
	usable = p_usable
	current_shp = p_current_shp
	source_refs = p_source_refs.duplicate()


func to_dictionary() -> Dictionary:
	return {
		"defense_type": String(defense_type),
		"equipment_ref": String(equipment_ref),
		"block_target": block_target,
		"target_modifier": target_modifier,
		"proficiency_verified": proficiency_verified,
		"usable": usable,
		"current_shp": current_shp,
		"shield_zero_shp_destruction_supported": defense_type == TYPE_SHIELD,
		"source_refs": Array(source_refs),
	}
