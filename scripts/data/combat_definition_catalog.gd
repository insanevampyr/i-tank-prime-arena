class_name CombatDefinitionCatalog
extends RefCounted

const WEAPON_HAND_CAPACITY := 2

const DEFAULT_CHARACTER_PATH := "res://data/characters/prime_v3_uncommon_guard.tres"
const DEFAULT_WEAPON_PATH := "res://data/equipment/weapons/prime_v3_battle_axe.tres"
const DEFAULT_SHIELD_PATH := "res://data/equipment/shields/prime_v3_metal_buckler.tres"
const DEFAULT_ARMOR_PATH := "res://data/equipment/armor/prime_v3_plate_torso.tres"
const DEFAULT_LOADOUT_PATH := "res://data/loadouts/arena_guard_plate_buckler.tres"
const SHORT_ROD_PATH := "res://data/equipment/weapons/prime_v3_short_rod.tres"
const GREAT_SWORD_PATH := "res://data/equipment/weapons/prime_v3_great_sword.tres"
const LONG_STAFF_PATH := "res://data/equipment/weapons/prime_v3_long_staff.tres"
const WOOD_BUCKLER_PATH := "res://data/equipment/shields/prime_v3_wood_buckler.tres"
const LEATHER_TORSO_PATH := "res://data/equipment/armor/prime_v3_leather_torso.tres"
const LEATHER_HEAD_PATH := "res://data/equipment/armor/prime_v3_leather_head.tres"
const COMMON_GOBLIN_CHARACTER_PATH := "res://data/characters/prime_v3_common_goblin.tres"
const COMMON_GOBLIN_FISTS_PATH := "res://data/equipment/weapons/prime_v3_common_goblin_fists.tres"
const COMMON_GOBLIN_LOADOUT_PATH := "res://data/loadouts/prime_v3_common_goblin_fists.tres"
const COMMON_SPADOODLE_CHARACTER_PATH := "res://data/characters/prime_v3_common_spadoodle.tres"
const COMMON_SPADOODLE_CLAWS_PATH := "res://data/equipment/weapons/prime_v3_common_spadoodle_claws.tres"
const COMMON_SPADOODLE_LOADOUT_PATH := "res://data/loadouts/prime_v3_common_spadoodle_claws.tres"
const COMMON_SKELLY_CHARACTER_PATH := "res://data/characters/prime_v3_common_skelly.tres"
const COMMON_SKELLY_CLAWS_PATH := "res://data/equipment/weapons/prime_v3_common_skelly_claws.tres"
const COMMON_SKELLY_LOADOUT_PATH := "res://data/loadouts/prime_v3_common_skelly_claws.tres"
const HADES_COMBAT_FOLLOWER_CHARACTER_PATH := "res://data/characters/prime_v3_uncommon_hades_combat_follower.tres"
const HADES_SHORT_SWORD_PATH := "res://data/equipment/weapons/prime_v3_hades_follower_short_sword.tres"
const HADES_COMBAT_FOLLOWER_LOADOUT_PATH := "res://data/loadouts/prime_v3_hades_combat_follower_short_sword.tres"
const MINI_GARGOYLE_CHARACTER_PATH := "res://data/characters/prime_v3_uncommon_mini_gargoyle_swarmer.tres"
const MINI_GARGOYLE_NATURAL_ATTACKS_PATH := "res://data/equipment/weapons/prime_v3_mini_gargoyle_natural_attacks.tres"
const MINI_GARGOYLE_LOADOUT_PATH := "res://data/loadouts/prime_v3_mini_gargoyle_natural_attacks.tres"
const VAELIS_CHARACTER_PATH := "res://data/characters/vaelis_thorn.tres"
const SHORT_SWORD_PATH := "res://data/equipment/weapons/prime_v3_short_sword.tres"
const SHORT_WAND_PATH := "res://data/equipment/weapons/prime_v3_short_wand.tres"
const VAELIS_LOADOUT_PATH := "res://data/loadouts/vaelis_thorn_short_sword_wand.tres"
const RARE_HUMAN_WARRIOR_CHARACTER_PATH := "res://data/characters/prime_v3_rare_human_warrior_boss.tres"
const RARE_HUMAN_WARRIOR_BOAR_SPEAR_PATH := "res://data/equipment/weapons/prime_v3_rare_human_warrior_boar_spear.tres"
const RARE_HUMAN_WARRIOR_LOADOUT_PATH := "res://data/loadouts/prime_v3_rare_human_warrior_boss.tres"
const SCALE_MAIL_ARMOR_PATHS := [
	"res://data/equipment/armor/prime_v3_scale_mail_torso.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_head.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_arms.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_legs.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_elbows.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_knees.tres",
	"res://data/equipment/armor/prime_v3_scale_mail_hands.tres",
]

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
	catalog.register_weapon(load(SHORT_ROD_PATH) as CombatWeaponDefinitionResource)
	catalog.register_weapon(load(GREAT_SWORD_PATH) as CombatWeaponDefinitionResource)
	catalog.register_weapon(load(LONG_STAFF_PATH) as CombatWeaponDefinitionResource)
	catalog.register_shield(load(WOOD_BUCKLER_PATH) as CombatShieldDefinitionResource)
	catalog.register_armor(load(LEATHER_TORSO_PATH) as CombatArmorDefinitionResource)
	catalog.register_armor(load(LEATHER_HEAD_PATH) as CombatArmorDefinitionResource)
	catalog.register_loadout(load(DEFAULT_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(COMMON_GOBLIN_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(COMMON_GOBLIN_FISTS_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(COMMON_GOBLIN_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(COMMON_SPADOODLE_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(COMMON_SPADOODLE_CLAWS_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(COMMON_SPADOODLE_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(COMMON_SKELLY_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(COMMON_SKELLY_CLAWS_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(COMMON_SKELLY_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(HADES_COMBAT_FOLLOWER_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(HADES_SHORT_SWORD_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(HADES_COMBAT_FOLLOWER_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(MINI_GARGOYLE_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(MINI_GARGOYLE_NATURAL_ATTACKS_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(MINI_GARGOYLE_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(VAELIS_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(SHORT_SWORD_PATH) as CombatWeaponDefinitionResource)
	catalog.register_weapon(load(SHORT_WAND_PATH) as CombatWeaponDefinitionResource)
	catalog.register_loadout(load(VAELIS_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
	catalog.register_character(load(RARE_HUMAN_WARRIOR_CHARACTER_PATH) as CombatCharacterDefinitionResource)
	catalog.register_weapon(load(RARE_HUMAN_WARRIOR_BOAR_SPEAR_PATH) as CombatWeaponDefinitionResource)
	for armor_path: String in SCALE_MAIL_ARMOR_PATHS:
		catalog.register_armor(load(armor_path) as CombatArmorDefinitionResource)
	catalog.register_loadout(load(RARE_HUMAN_WARRIOR_LOADOUT_PATH) as CombatLoadoutDefinitionResource)
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
	_validate_equipment_refs(issues, character.attributes.get("str"), loadout_definition.equipment_refs())
	return _validation_result(issues)


func validate_actor_equipment(actor: CombatActorDefinition) -> Dictionary:
	var issues: Array[Dictionary] = registration_issues.duplicate(true)
	if actor == null:
		issues.append(_issue("invalid", "missing_actor_definition"))
		return _validation_result(issues)
	_validate_equipment_refs(issues, actor.attributes.get("str"), actor.equipment_refs)
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
	var actor_equipment_validation := validate_actor_equipment(actor as CombatActorDefinition)
	if not actor_equipment_validation.get("success", false):
		return actor_equipment_validation
	var modifier_result := calculate_armor_stat_modifiers((actor as CombatActorDefinition).equipment_refs)
	if not modifier_result.get("success", false):
		return modifier_result
	(actor as CombatActorDefinition).apply_equipment_stat_modifiers(modifier_result["modifiers"])
	return {"success": true, "status": validation["status"], "issues": validation["issues"], "actor": actor}


func calculate_armor_stat_modifiers(equipment_refs: PackedStringArray) -> Dictionary:
	var modifiers := {"mr": 0, "dt": 0, "dp": 0}
	var issues: Array[Dictionary] = []
	var armor_refs: Array[String] = []
	var occupied_slots: Dictionary = {}
	for equipment_ref: String in equipment_refs:
		if weapons.has(equipment_ref) or shields.has(equipment_ref):
			continue
		if not armors.has(equipment_ref):
			issues.append(_issue("invalid", "missing_equipment_definition", {"equipment_ref": equipment_ref}))
			continue
		var armor: CombatArmorDefinitionResource = armors[equipment_ref]
		var armor_slot := String(armor.armor_slot)
		if occupied_slots.has(armor_slot):
			issues.append(_issue("invalid", "equipment_slot_conflict", {
				"slot": armor_slot,
				"equipment_refs": [occupied_slots[armor_slot], equipment_ref],
			}))
			continue
		occupied_slots[armor_slot] = equipment_ref
		if not armor.unresolved_penalty_fields.is_empty():
			for field_name: String in armor.unresolved_penalty_fields:
				issues.append(_issue("requires_source_verification", "variable_armor_penalty_unresolved", {
					"equipment_ref": equipment_ref,
					"field": field_name,
				}))
			continue
		modifiers["mr"] += armor.mr_penalty
		modifiers["dt"] += armor.dt_penalty
		modifiers["dp"] += armor.projectile_dodge_penalty
		armor_refs.append(equipment_ref)
	if not issues.is_empty():
		var issue_result := _validation_result(issues)
		issue_result["success"] = false
		issue_result["modifiers"] = {}
		return issue_result
	armor_refs.sort()
	return {
		"success": true,
		"status": "valid",
		"issues": [],
		"modifiers": modifiers,
		"armor_refs": armor_refs,
	}


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


func _validate_equipment_refs(issues: Array[Dictionary], strength_value: Variant, equipment_refs: PackedStringArray) -> void:
	var equipped_weapons: Array[CombatWeaponDefinitionResource] = []
	var shield: CombatShieldDefinitionResource = null
	var occupied_armor_slots: Dictionary = {}
	for equipment_ref: String in equipment_refs:
		if weapons.has(equipment_ref):
			if equipped_weapons.size() >= 2:
				issues.append(_issue("invalid", "too_many_weapons_not_supported", {"equipment_ref": equipment_ref}))
				continue
			var weapon: CombatWeaponDefinitionResource = weapons[equipment_ref]
			equipped_weapons.append(weapon)
			issues.append_array(weapon.validate_definition())
			_validate_strength_requirement(issues, strength_value, weapon.strength_requirement, weapon.definition_id)
		elif shields.has(equipment_ref):
			if shield != null:
				issues.append(_issue("invalid", "multiple_shields_not_supported", {"equipment_ref": equipment_ref}))
				continue
			shield = shields[equipment_ref]
			issues.append_array(shield.validate_definition())
			_validate_strength_requirement(issues, strength_value, shield.strength_requirement, shield.definition_id)
		elif armors.has(equipment_ref):
			var armor: CombatArmorDefinitionResource = armors[equipment_ref]
			issues.append_array(armor.validate_definition())
			_validate_strength_requirement(issues, strength_value, armor.strength_requirement, armor.definition_id)
			var armor_slot := String(armor.armor_slot)
			if occupied_armor_slots.has(armor_slot):
				issues.append(_issue("invalid", "equipment_slot_conflict", {
					"slot": armor_slot,
					"equipment_refs": [occupied_armor_slots[armor_slot], equipment_ref],
				}))
			else:
				occupied_armor_slots[armor_slot] = equipment_ref
		else:
			issues.append(_issue("invalid", "missing_equipment_definition", {"equipment_ref": equipment_ref}))
	if equipped_weapons.is_empty():
		issues.append(_issue("invalid", "missing_primary_weapon_equipment"))
		return
	if strength_value == null or typeof(strength_value) != TYPE_INT:
		return
	var weapon_hands := 0
	for weapon: CombatWeaponDefinitionResource in equipped_weapons:
		var required_hands := weapon.effective_hands_required(int(strength_value))
		if required_hands == CombatWeaponDefinitionResource.INVALID_HAND_REQUIREMENT:
			return
		weapon_hands += required_hands
	var shield_hands := 0 if shield == null else shield.hand_occupancy
	if weapon_hands + shield_hands > WEAPON_HAND_CAPACITY:
		issues.append(_issue("invalid", "equipment_hand_occupancy_conflict", {
			"weapon_refs": equipped_weapons.map(func(item: CombatWeaponDefinitionResource) -> String: return String(item.definition_id)),
			"weapon_hands": weapon_hands,
			"shield_ref": "" if shield == null else String(shield.definition_id),
			"shield_hands": shield_hands,
			"available_hands": WEAPON_HAND_CAPACITY,
		}))


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
