class_name CombatDefinitionCatalog
extends RefCounted

const DEFAULT_CHARACTER_PATH := "res://data/characters/prime_v3_uncommon_guard.tres"
const DEFAULT_WEAPON_PATH := "res://data/equipment/weapons/prime_v3_battle_axe.tres"
const DEFAULT_SHIELD_PATH := "res://data/equipment/shields/prime_v3_metal_buckler.tres"
const DEFAULT_ARMOR_PATH := "res://data/equipment/armor/prime_v3_plate_torso.tres"
const DEFAULT_LOADOUT_PATH := "res://data/loadouts/arena_guard_plate_buckler.tres"

var characters: Dictionary = {}
var weapons: Dictionary = {}
var shields: Dictionary = {}
var armors: Dictionary = {}
var loadouts: Dictionary = {}
var registration_issues: Array[Dictionary] = []


static func load_default_fixture_catalog() -> CombatDefinitionCatalog:
	var catalog := CombatDefinitionCatalog.new()
	catalog.register_character(load(DEFAULT_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(DEFAULT_WEAPON_PATH) as CombatWeaponDefinitionResource)
	catalog.register_shield(load(DEFAULT_SHIELD_PATH) as CombatShieldDefinitionResource)
	catalog.register_armor(load(DEFAULT_ARMOR_PATH) as CombatArmorDefinitionResource)
	catalog.register_loadout(load(DEFAULT_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	return catalog


func register_character(definition: CombatCharacterDefinitionResource) -> Dictionary:
	return _register_definition(characters, definition, "character")


func register_weapon(definition: CombatWeaponDefinitionResource) -> Dictionary:
	return _register_definition(weapons, definition, "weapon")


func register_shield(definition: CombatShieldDefinitionResource) -> Dictionary:
	return _register_definition(shields, definition, "shield")


func register_armor(definition: CombatArmorDefinitionResource) -> Dictionary:
	return _register_definition(armors, definition, "armor")


func register_loadout(definition: CombatLoadoutDefinitionResource) -> Dictionary:
	return _register_definition(loadouts, definition, "loadout")


func validate_character_loadout(character_id: StringName, loadout_id: StringName) -> Dictionary:
	var issues: Array[Dictionary] = registration_issues.duplicate(true)
	var character: CombatCharacterDefinitionResource = characters.get(String(character_id))
	var loadout_definition: CombatLoadoutDefinitionResource = loadouts.get(String(loadout_id))
	if character == null:
		issues.append(_issue("invalid", "missing_character_definition", {"definition_id": String(character_id)}))
	if loadout_definition == null:
		issues.append(_issue("invalid", "missing_loadout_definition", {"definition_id": String(loadout_id)}))
	if character == null or loadout_definition == null:
		return _validation_result(issues)
	issues.append_array(character.validate_definition())
	issues.append_array(loadout_definition.validate_definition())
	var strength_value: Variant = character.attributes.get("str")
	var weapon: CombatWeaponDefinitionResource = weapons.get(String(loadout_definition.primary_weapon_ref))
	if weapon == null:
		issues.append(_issue("invalid", "missing_equipment_definition", {"equipment_ref": String(loadout_definition.primary_weapon_ref)}))
	else:
		issues.append_array(weapon.validate_definition())
		_validate_strength_requirement(issues, strength_value, weapon.strength_requirement, weapon.definition_id)
	var shield: CombatShieldDefinitionResource = null
	if not String(loadout_definition.shield_ref).is_empty():
		shield = shields.get(String(loadout_definition.shield_ref))
		if shield == null:
			issues.append(_issue("invalid", "missing_equipment_definition", {"equipment_ref": String(loadout_definition.shield_ref)}))
		else:
			issues.append_array(shield.validate_definition())
			_validate_strength_requirement(issues, strength_value, shield.strength_requirement, shield.definition_id)
	for armor_ref: String in loadout_definition.armor_refs:
		var armor: CombatArmorDefinitionResource = armors.get(armor_ref)
		if armor == null:
			issues.append(_issue("invalid", "missing_equipment_definition", {"equipment_ref": armor_ref}))
			continue
		issues.append_array(armor.validate_definition())
		_validate_strength_requirement(issues, strength_value, armor.strength_requirement, armor.definition_id)
	return _validation_result(issues)


func instantiate_actor(character_id: StringName, loadout_id: StringName, actor_id: StringName, display_name: String) -> Dictionary:
	var validation := validate_character_loadout(character_id, loadout_id)
	if not validation["success"]:
		return validation
	var character: CombatCharacterDefinitionResource = characters[String(character_id)]
	var loadout_definition: CombatLoadoutDefinitionResource = loadouts[String(loadout_id)]
	var actor: Variant = character.instantiate_actor(actor_id, display_name, loadout_definition.equipment_refs())
	if actor == null:
		return _validation_result([_issue("invalid", "character_instantiation_failed")])
	return {"success": true, "status": validation["status"], "issues": validation["issues"], "actor": actor}


func get_weapon(definition_id: StringName) -> CombatWeaponDefinitionResource:
	return weapons.get(String(definition_id))


func get_shield(definition_id: StringName) -> CombatShieldDefinitionResource:
	return shields.get(String(definition_id))


func get_armor(definition_id: StringName) -> CombatArmorDefinitionResource:
	return armors.get(String(definition_id))


func get_loadout(definition_id: StringName) -> CombatLoadoutDefinitionResource:
	return loadouts.get(String(definition_id))


func _register_definition(collection: Dictionary, definition: Variant, kind: String) -> Dictionary:
	if definition == null:
		var missing := _issue("invalid", "missing_definition_resource", {"kind": kind})
		registration_issues.append(missing)
		return {"success": false, "issue": missing}
	var definition_id := String(definition.definition_id)
	if definition_id.is_empty():
		var missing_id := _issue("invalid", "missing_definition_identifier", {"kind": kind})
		registration_issues.append(missing_id)
		return {"success": false, "issue": missing_id}
	if collection.has(definition_id):
		var duplicate := _issue("invalid", "duplicate_definition_identifier", {"kind": kind, "definition_id": definition_id})
		registration_issues.append(duplicate)
		return {"success": false, "issue": duplicate}
	collection[definition_id] = definition
	return {"success": true}


func _validate_strength_requirement(issues: Array[Dictionary], strength_value: Variant, requirement: int, equipment_id: StringName) -> void:
	if requirement < 0:
		issues.append(_issue("requires_source_verification", "equipment_requirement_unresolved", {"equipment_ref": String(equipment_id)}))
	elif strength_value == null or typeof(strength_value) != TYPE_INT:
		issues.append(_issue("invalid", "character_strength_missing", {"equipment_ref": String(equipment_id)}))
	elif int(strength_value) < requirement:
		issues.append(_issue("invalid", "equipment_strength_requirement_not_met", {"equipment_ref": String(equipment_id), "required": requirement, "actual": int(strength_value)}))


func _validation_result(issues: Array[Dictionary]) -> Dictionary:
	var status := "valid"
	for issue: Dictionary in issues:
		if issue["status"] == "invalid":
			status = "invalid"
			break
		if issue["status"] == "requires_source_verification":
			status = "requires_source_verification"
		elif issue["status"] == "not_yet_implemented" and status == "valid":
			status = "not_yet_implemented"
	return {"success": status != "invalid", "status": status, "issues": issues.duplicate(true)}


func _issue(status: String, code: String, details: Dictionary = {}) -> Dictionary:
	return {"status": status, "code": code, "details": details.duplicate(true)}
