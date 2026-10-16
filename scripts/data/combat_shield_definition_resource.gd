class_name CombatShieldDefinitionResource
extends Resource

@export var definition_id: StringName
@export var display_name: String
@export var strength_requirement: int = -1
@export var block_target: int = -1
@export var maximum_shp: int = -1
@export var two_hands_free: bool = false
@export var source_refs: PackedStringArray = PackedStringArray()


func validate_definition() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if String(definition_id).is_empty(): issues.append(_issue("invalid", "missing_shield_identifier"))
	if display_name.strip_edges().is_empty(): issues.append(_issue("invalid", "missing_shield_display_name"))
	if strength_requirement < 0: issues.append(_issue("requires_source_verification", "shield_strength_requirement_unresolved"))
	if block_target < 0: issues.append(_issue("invalid", "invalid_shield_block_target"))
	if maximum_shp < 0: issues.append(_issue("invalid", "invalid_shield_shp"))
	if source_refs.is_empty(): issues.append(_issue("requires_source_verification", "shield_source_missing"))
	return issues


func make_block_definition() -> Variant:
	for issue: Dictionary in validate_definition():
		if issue["status"] == "invalid": return null
	return CombatBlockDefinition.new(
		CombatBlockDefinition.TYPE_SHIELD, definition_id, block_target, 0,
		true, true, maximum_shp, source_refs, null
	)


func to_dictionary() -> Dictionary:
	return {
		"definition_id": String(definition_id), "display_name": display_name,
		"strength_requirement": strength_requirement, "block_target": block_target,
		"maximum_shp": maximum_shp, "two_hands_free": two_hands_free,
		"source_refs": Array(source_refs),
	}


func _issue(status: String, code: String) -> Dictionary:
	return {"status": status, "code": code, "details": {}}
