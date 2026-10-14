class_name CombatArmorDefinition
extends RefCounted

var equipment_ref: StringName
var armor_slot: StringName
var covered_locations: PackedStringArray
var tal_by_damage_type: Dictionary
var source_refs: PackedStringArray


func _init(
	p_equipment_ref: StringName,
	p_armor_slot: StringName,
	p_covered_locations: PackedStringArray,
	p_tal_by_damage_type: Dictionary,
	p_source_refs: PackedStringArray = PackedStringArray()
) -> void:
	assert(not String(p_equipment_ref).is_empty(), "Armor definitions require an equipment reference.")
	assert(not String(p_armor_slot).is_empty(), "Armor definitions require a stable slot.")
	assert(not p_covered_locations.is_empty(), "Armor definitions require explicit location coverage.")
	for damage_type: Variant in p_tal_by_damage_type:
		assert(_is_physical_damage_type(String(damage_type)), "Armor TAL only supports audited physical damage types.")
		assert(typeof(p_tal_by_damage_type[damage_type]) == TYPE_INT and int(p_tal_by_damage_type[damage_type]) >= 0, "Armor TAL must be a non-negative integer.")
	equipment_ref = p_equipment_ref
	armor_slot = p_armor_slot
	covered_locations = p_covered_locations.duplicate()
	tal_by_damage_type = p_tal_by_damage_type.duplicate(true)
	source_refs = p_source_refs.duplicate()


func get_tal(damage_type: StringName) -> int:
	return int(tal_by_damage_type[String(damage_type)])


func has_tal(damage_type: StringName) -> bool:
	return tal_by_damage_type.has(String(damage_type))


func _is_physical_damage_type(damage_type: String) -> bool:
	return damage_type == "bashing" or damage_type == "slashing" or damage_type == "piercing"


func to_dictionary() -> Dictionary:
	return {
		"equipment_ref": String(equipment_ref),
		"armor_slot": String(armor_slot),
		"covered_locations": Array(covered_locations),
		"tal_by_damage_type": tal_by_damage_type.duplicate(true),
		"source_refs": Array(source_refs),
	}
