class_name CombatLoadoutDefinitionResource
extends Resource

@export var definition_id: StringName
@export var display_name: String
@export var primary_weapon_ref: StringName
@export var secondary_weapon_ref: StringName
@export var shield_ref: StringName
@export var armor_refs: PackedStringArray = PackedStringArray()
@export var source_refs: PackedStringArray = PackedStringArray()


func equipment_refs() -> PackedStringArray:
	var refs := PackedStringArray()
	if not String(primary_weapon_ref).is_empty(): refs.append(String(primary_weapon_ref))
	if not String(secondary_weapon_ref).is_empty(): refs.append(String(secondary_weapon_ref))
	if not String(shield_ref).is_empty(): refs.append(String(shield_ref))
	for armor_ref: String in armor_refs: refs.append(armor_ref)
	return refs


func validate_definition() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if String(definition_id).is_empty(): issues.append({"status": "invalid", "code": "missing_loadout_identifier", "details": {}})
	if display_name.strip_edges().is_empty(): issues.append({"status": "invalid", "code": "missing_loadout_display_name", "details": {}})
	if String(primary_weapon_ref).is_empty(): issues.append({"status": "invalid", "code": "missing_primary_weapon_reference", "details": {}})
	var refs := equipment_refs()
	for equipment_ref: String in refs:
		if refs.count(equipment_ref) > 1:
			issues.append({"status": "invalid", "code": "duplicate_loadout_reference", "details": {"equipment_ref": equipment_ref}})
	return issues


func to_dictionary() -> Dictionary:
	return {
		"definition_id": String(definition_id), "display_name": display_name,
		"primary_weapon_ref": String(primary_weapon_ref), "secondary_weapon_ref": String(secondary_weapon_ref),
		"shield_ref": String(shield_ref),
		"armor_refs": Array(armor_refs), "source_refs": Array(source_refs),
	}
