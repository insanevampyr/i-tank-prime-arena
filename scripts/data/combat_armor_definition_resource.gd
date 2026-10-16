class_name CombatArmorDefinitionResource
extends Resource

@export var definition_id: StringName
@export var display_name: String
@export var armor_slot: StringName
@export var covered_locations: PackedStringArray = PackedStringArray()
@export var tal_by_damage_type: Dictionary = {}
@export var strength_requirement: int = -1
@export var mr_penalty: int = 0
@export var dt_penalty: int = 0
@export var projectile_dodge_penalty: int = 0
@export var unresolved_penalty_fields: PackedStringArray = PackedStringArray()
@export var source_refs: PackedStringArray = PackedStringArray()


func validate_definition() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if String(definition_id).is_empty(): issues.append(_issue("invalid", "missing_armor_identifier"))
	if display_name.strip_edges().is_empty(): issues.append(_issue("invalid", "missing_armor_display_name"))
	if String(armor_slot).is_empty() or covered_locations.is_empty(): issues.append(_issue("invalid", "missing_armor_coverage"))
	for damage_type: Variant in tal_by_damage_type:
		if not ["bashing", "slashing", "piercing"].has(String(damage_type)):
			issues.append(_issue("not_yet_implemented", "unsupported_armor_damage_type"))
		elif typeof(tal_by_damage_type[damage_type]) != TYPE_INT or int(tal_by_damage_type[damage_type]) < 0:
			issues.append(_issue("invalid", "malformed_armor_tal"))
	if strength_requirement < 0: issues.append(_issue("requires_source_verification", "armor_strength_requirement_unresolved"))
	if mr_penalty > 0 or dt_penalty > 0 or projectile_dodge_penalty > 0:
		issues.append(_issue("invalid", "armor_penalty_must_be_non_positive"))
	for field_name: String in unresolved_penalty_fields:
		if not ["mr", "dt", "dp"].has(field_name):
			issues.append(_issue("invalid", "unknown_armor_penalty_field", {"field": field_name}))
		else:
			issues.append(_issue("requires_source_verification", "variable_armor_penalty_unresolved", {"field": field_name}))
	if source_refs.is_empty(): issues.append(_issue("requires_source_verification", "armor_source_missing"))
	return issues


func make_combat_armor_definition() -> Variant:
	for issue: Dictionary in validate_definition():
		if issue["status"] == "invalid": return null
	return CombatArmorDefinition.new(
		definition_id, armor_slot, covered_locations, tal_by_damage_type, source_refs,
		mr_penalty, dt_penalty, projectile_dodge_penalty
	)


func to_dictionary() -> Dictionary:
	return {
		"definition_id": String(definition_id), "display_name": display_name,
		"armor_slot": String(armor_slot), "covered_locations": Array(covered_locations),
		"tal_by_damage_type": tal_by_damage_type.duplicate(true),
		"strength_requirement": strength_requirement, "mr_penalty": mr_penalty,
		"dt_penalty": dt_penalty, "projectile_dodge_penalty": projectile_dodge_penalty,
		"unresolved_penalty_fields": Array(unresolved_penalty_fields), "source_refs": Array(source_refs),
	}


func _issue(status: String, code: String, details: Dictionary = {}) -> Dictionary:
	return {"status": status, "code": code, "details": details.duplicate(true)}
