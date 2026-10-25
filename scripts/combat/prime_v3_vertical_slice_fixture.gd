class_name PrimeV3VerticalSliceFixture
extends RefCounted

const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const PLAYER_ID := &"player"
const OPPONENT_ID := &"opponent"
const ATTACK_ID := &"prime_v3_battle_axe_torso"
const WEAPON_REF := &"prime_v3_battle_axe"
const SHIELD_REF := &"prime_v3_metal_buckler"
const ARMOR_REF := &"prime_v3_plate_torso"
const CHARACTER_DEFINITION_ID := &"prime_v3_uncommon_guard"
const LOADOUT_DEFINITION_ID := &"arena_guard_plate_buckler"
const PLAYER_CHARACTER_GUARD := &"uncommon_guard"
const PLAYER_CHARACTER_VAELIS := &"vaelis_thorn"
const VAELIS_CHARACTER_DEFINITION_ID := &"vaelis_thorn"
const VAELIS_LOADOUT_DEFINITION_ID := &"vaelis_thorn_short_sword_wand"
const VAELIS_WEAPON_REF := &"prime_v3_short_sword"
const VAELIS_WAND_REF := &"prime_v3_short_wand"
const ENCOUNTER_MEDIUM_GUARDS := &"medium_guard_vs_medium_guard"
const ENCOUNTER_SYNTHETIC_SMALL_GUARD := &"medium_guard_vs_synthetic_small_guard"
const ENCOUNTER_WAVE_ONE_GOBLINS := &"wave_1_common_goblins"
const ENCOUNTER_WAVE_TWO_SPADOODLES := &"wave_2_common_spadoodles"
const ENCOUNTER_WAVE_THREE_SKELLY_HADES := &"wave_3_skelly_hades_follower"
const ENCOUNTER_WAVE_FOUR_GARGOYLES := &"wave_4_mini_gargoyle_swarmers"
const ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR := &"wave_5_rare_human_warrior"

const PRIME_GUARD_SOURCE := "PRIME-V3 p. 336, Uncommon Guard"
const PRIME_BATTLE_AXE_SOURCE := "PRIME-V3 p. 127, Battle Axe"
const PRIME_PLATE_SOURCE := "PRIME-V3 p. 135, Plate torso armor"
const PRIME_BUCKLER_SOURCE := "PRIME-V3 p. 137, Metal Buckler"
const ARENA_DAMAGE_SOURCE := "ARENA-COMBAT-1.6 exact multiplier order"

const BATTLE_AXE_STRENGTH_REQUIREMENT := 12
const BATTLE_AXE_ONE_HAND_STRENGTH_REQUIREMENT := 24
const METAL_BUCKLER_STRENGTH_REQUIREMENT := 8
const PLATE_TORSO_STRENGTH_REQUIREMENT := 16

# Task 3 movement-test profile. These are not part of the Prime Guard stat row.
const PLAYER_RUNNING_SKILL_INVESTMENT := 3
const PLAYER_RUNNING_SCM := 0
const PLAYER_RUNNING_RNG_SEED := 1_337


static func configure_simulation(
	simulation: CombatSimulation,
	player_position_microfeet: Vector2i,
	opponent_position_microfeet: Vector2i,
	encounter_fixture_id: StringName = ENCOUNTER_MEDIUM_GUARDS,
	player_character_id: StringName = PLAYER_CHARACTER_GUARD
) -> Dictionary:
	if simulation == null:
		return {"success": false, "reason": "missing_simulation"}
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var catalog_validation := catalog.validate_character_loadout(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID)
	if not catalog_validation.get("success", false):
		return {"success": false, "reason": "fixture_catalog_invalid", "issues": catalog_validation.get("issues", [])}
	var attack_definition := make_attack_definition()
	if not [ENCOUNTER_MEDIUM_GUARDS, ENCOUNTER_SYNTHETIC_SMALL_GUARD].has(encounter_fixture_id):
		return {"success": false, "reason": "unsupported_encounter_fixture"}
	for actor_id: StringName in [PLAYER_ID, OPPONENT_ID]:
		var is_player := actor_id == PLAYER_ID
		var actor := (
			make_synthetic_small_guard_actor(actor_id)
			if actor_id == OPPONENT_ID and encounter_fixture_id == ENCOUNTER_SYNTHETIC_SMALL_GUARD
			else (make_player_actor(player_character_id, actor_id) if is_player else make_guard_actor(actor_id, "Opponent Guard Fixture"))
		)
		var actor_attack := make_player_attack_definition(player_character_id) if is_player else attack_definition
		var defense_profile := make_player_defense_profile(player_character_id, actor_id) if is_player else make_defense_profile(actor_id)
		var protection_profile := make_player_damage_protection_profile(player_character_id, actor_id) if is_player else make_damage_protection_profile(actor_id)
		var validation := validate_player_combatant(player_character_id, actor, defense_profile, protection_profile, actor_attack) if is_player else validate_combatant_fixture(actor, defense_profile, protection_profile, actor_attack)
		if not validation.get("success", false):
			return validation
		var actor_result := simulation.register_actor(actor)
		if not actor_result.get("success", false):
			return actor_result
		var defense_result := simulation.register_defense_profile(actor_id, defense_profile)
		if not defense_result.get("success", false):
			return defense_result
		var protection_result := simulation.register_damage_protection_profile(actor_id, protection_profile)
		if not protection_result.get("success", false):
			return protection_result
		var reaction_result := simulation.register_critical_reaction_attack(actor_id, actor_attack, true)
		if not reaction_result.get("success", false):
			return reaction_result
		if is_player and player_character_id == PLAYER_CHARACTER_VAELIS:
			var hand_result := simulation.configure_actor_hand_occupancy(actor_id, {"left": String(VAELIS_WAND_REF), "right": String(VAELIS_WEAPON_REF)})
			if not hand_result.get("success", false):
				return hand_result

	var player_position_result := simulation.apply_authoritative_position(PLAYER_ID, player_position_microfeet, 0)
	if not player_position_result.get("success", false):
		return player_position_result
	var opponent_position_result := simulation.apply_authoritative_position(OPPONENT_ID, opponent_position_microfeet, 180_000)
	if not opponent_position_result.get("success", false):
		return opponent_position_result
	var opening_result := simulation.begin_combat()
	if not opening_result.get("success", false):
		return opening_result
	return {
		"success": true,
		"attack_definition": make_player_attack_definition(player_character_id),
		"opponent_attack_definition": attack_definition,
		"opening_order": opening_result["opening_order"],
		"encounter_fixture_id": String(encounter_fixture_id),
	}


static func validate_combatant_fixture(
	actor: CombatActorDefinition,
	defense_profile: CombatDefenseProfile,
	protection_profile: CombatDamageProtectionProfile,
	attack_definition: CombatAttackDefinition
) -> Dictionary:
	if actor == null or defense_profile == null or protection_profile == null or attack_definition == null:
		return {"success": false, "reason": "fixture_component_missing"}
	if not actor.unresolved_fields.is_empty():
		return {"success": false, "reason": "fixture_actor_fields_unresolved", "fields": Array(actor.unresolved_fields)}
	for field_name: String in ["hpm", "at", "init", "acc", "mr", "nal", "dt", "dp", "physical_soak", "rb", "sb"]:
		if actor.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "fixture_combat_stat_unresolved", "field": field_name}
	var strength := int(actor.attributes.get("str", -1))
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var equipment_validation := catalog.validate_actor_equipment(actor)
	if not equipment_validation.get("success", false):
		for issue: Dictionary in equipment_validation.get("issues", []):
			if issue.get("code") == "equipment_strength_requirement_not_met":
				var equipment_ref := String(issue.get("details", {}).get("equipment_ref", ""))
				if equipment_ref == String(WEAPON_REF): return {"success": false, "reason": "battle_axe_strength_requirement_not_met", "issues": equipment_validation["issues"]}
				if equipment_ref == String(SHIELD_REF): return {"success": false, "reason": "metal_buckler_strength_requirement_not_met", "issues": equipment_validation["issues"]}
				if equipment_ref == String(ARMOR_REF): return {"success": false, "reason": "plate_torso_strength_requirement_not_met", "issues": equipment_validation["issues"]}
		return {"success": false, "reason": "fixture_equipment_invalid", "issues": equipment_validation.get("issues", [])}
	for equipment_ref: StringName in [WEAPON_REF, SHIELD_REF, ARMOR_REF]:
		if not actor.equipment_refs.has(String(equipment_ref)):
			return {"success": false, "reason": "fixture_equipment_not_equipped", "equipment_ref": String(equipment_ref)}
	if attack_definition.weapon_ref != WEAPON_REF or attack_definition.maximum_range_microfeet != 3_000_000:
		return {"success": false, "reason": "fixture_weapon_definition_mismatch"}
	if defense_profile.weapon_block == null or defense_profile.weapon_block.equipment_ref != WEAPON_REF:
		return {"success": false, "reason": "fixture_weapon_block_mismatch"}
	if defense_profile.shield_block == null or defense_profile.shield_block.equipment_ref != SHIELD_REF:
		return {"success": false, "reason": "fixture_shield_block_mismatch"}
	if int(defense_profile.shield_block.current_shp) != 20:
		return {"success": false, "reason": "fixture_shield_shp_mismatch"}
	if protection_profile.armors.size() != 1:
		return {"success": false, "reason": "fixture_armor_profile_mismatch"}
	var armor := protection_profile.armors[0]
	if armor.equipment_ref != ARMOR_REF or not armor.covered_locations.has("torso"):
		return {"success": false, "reason": "fixture_armor_coverage_mismatch"}
	for damage_type: String in ["bashing", "slashing", "piercing"]:
		if not armor.has_tal(StringName(damage_type)) or armor.get_tal(StringName(damage_type)) != 3:
			return {"success": false, "reason": "fixture_armor_tal_mismatch", "damage_type": damage_type}
	return {
		"success": true,
		"battle_axe_two_handed": catalog.get_weapon(WEAPON_REF).effective_hands_required(strength) == 2,
		"buckler_preserves_two_free_hands": catalog.get_shield(SHIELD_REF).hand_occupancy == 0,
	}


static func make_guard_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var result := catalog.instantiate_actor(CHARACTER_DEFINITION_ID, LOADOUT_DEFINITION_ID, actor_id, display_name)
	return result.get("actor") as CombatActorDefinition


static func make_player_actor(player_character_id: StringName, actor_id: StringName = PLAYER_ID) -> CombatActorDefinition:
	if player_character_id == PLAYER_CHARACTER_GUARD:
		return make_guard_actor(actor_id, "Player Guard Fixture")
	if player_character_id == PLAYER_CHARACTER_VAELIS:
		var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
		var result := catalog.instantiate_actor(VAELIS_CHARACTER_DEFINITION_ID, VAELIS_LOADOUT_DEFINITION_ID, actor_id, "Vaelis Thorn")
		return result.get("actor") as CombatActorDefinition
	return null


static func make_player_attack_definition(player_character_id: StringName) -> CombatAttackDefinition:
	if player_character_id == PLAYER_CHARACTER_GUARD:
		return make_attack_definition()
	if player_character_id == PLAYER_CHARACTER_VAELIS:
		var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
		var sword := catalog.get_weapon(VAELIS_WEAPON_REF)
		var wand := catalog.get_weapon(VAELIS_WAND_REF)
		if sword == null or wand == null:
			return null
		var attack := sword.make_attack_definition(&"vaelis_thorn_sword_wand_attack", HitLocations.get_same_size_attack_profile()) as CombatAttackDefinition
		if attack == null:
			return null
		attack.strikes_per_act = 2
		attack.strike_profiles = [
			{
				"label": "short_sword",
				"weapon_ref": String(VAELIS_WEAPON_REF),
				"dice_count": sword.damage_dice_count,
				"die_sides": sword.damage_die_sides,
				"flat_bonus": sword.fixed_damage_bonus,
				"strength_bonus_eligible": sword.strength_bonus_eligible,
				"damage_types": Array(sword.damage_types),
				"minimum_range_microfeet": 0,
				"maximum_range_microfeet": sword.reach_microfeet,
			},
			{
				"label": "short_wand",
				"weapon_ref": String(VAELIS_WAND_REF),
				"dice_count": wand.damage_dice_count,
				"die_sides": wand.damage_die_sides,
				"flat_bonus": wand.fixed_damage_bonus,
				"strength_bonus_eligible": wand.strength_bonus_eligible,
				"damage_types": Array(wand.damage_types),
				"minimum_range_microfeet": 0,
				"maximum_range_microfeet": wand.reach_microfeet,
			},
		]
		return attack
	return null


static func make_player_defense_profile(player_character_id: StringName, actor_id: StringName = PLAYER_ID) -> CombatDefenseProfile:
	if player_character_id == PLAYER_CHARACTER_GUARD:
		return make_defense_profile(actor_id)
	if player_character_id == PLAYER_CHARACTER_VAELIS:
		return CombatDefenseProfile.new(
			&"vaelis_thorn_defenses",
			PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
			{}, null, null,
			PackedStringArray(["PRIME-V3 pp. 19-20; supplied Vaelis DT/DP allocation; no armor or shield"])
		)
	return null


static func make_player_damage_protection_profile(player_character_id: StringName, actor_id: StringName = PLAYER_ID) -> CombatDamageProtectionProfile:
	if player_character_id == PLAYER_CHARACTER_GUARD:
		return make_damage_protection_profile(actor_id)
	if player_character_id == PLAYER_CHARACTER_VAELIS:
		return CombatDamageProtectionProfile.new(
			&"vaelis_thorn_protection", [], {},
			PackedStringArray(["Supplied Vaelis record: light clothing, no armor; PRIME-V3 p. 53 NAL 1 at END 6"])
		)
	return null


static func validate_player_combatant(
	player_character_id: StringName,
	actor: CombatActorDefinition,
	defense_profile: CombatDefenseProfile,
	protection_profile: CombatDamageProtectionProfile,
	attack_definition: CombatAttackDefinition
) -> Dictionary:
	if player_character_id == PLAYER_CHARACTER_GUARD:
		return validate_combatant_fixture(actor, defense_profile, protection_profile, attack_definition)
	if player_character_id != PLAYER_CHARACTER_VAELIS:
		return {"success": false, "reason": "unsupported_player_character"}
	if actor == null or defense_profile == null or protection_profile == null or attack_definition == null:
		return {"success": false, "reason": "vaelis_component_missing"}
	if not actor.unresolved_fields.is_empty():
		return {"success": false, "reason": "vaelis_fields_unresolved", "fields": Array(actor.unresolved_fields)}
	var equipment_validation := CombatDefinitionCatalog.load_default_fixture_catalog().validate_actor_equipment(actor)
	if not equipment_validation.get("success", false):
		return {"success": false, "reason": "vaelis_equipment_invalid", "issues": equipment_validation.get("issues", [])}
	if actor.equipment_refs != PackedStringArray([String(VAELIS_WEAPON_REF), String(VAELIS_WAND_REF)]):
		return {"success": false, "reason": "vaelis_loadout_mismatch"}
	if attack_definition.weapon_ref != VAELIS_WEAPON_REF or attack_definition.maximum_range_microfeet != 2_000_000 \
	or attack_definition.strikes_per_act != 2 or attack_definition.strike_profiles.size() != 2 \
	or String(attack_definition.strike_profiles[1].get("weapon_ref", "")) != String(VAELIS_WAND_REF):
		return {"success": false, "reason": "vaelis_attack_mismatch"}
	if defense_profile.weapon_block != null or defense_profile.shield_block != null or not protection_profile.armors.is_empty():
		return {"success": false, "reason": "vaelis_protection_mismatch"}
	return {"success": true}


static func get_player_character_display_name(player_character_id: StringName) -> String:
	return "Vaelis Thorn" if player_character_id == PLAYER_CHARACTER_VAELIS else "Uncommon Guard"


static func get_player_primary_weapon_display_name(player_character_id: StringName) -> String:
	return "SHORT SWORD" if player_character_id == PLAYER_CHARACTER_VAELIS else "AXE"


static func get_player_loadout_id(player_character_id: StringName) -> StringName:
	return VAELIS_LOADOUT_DEFINITION_ID if player_character_id == PLAYER_CHARACTER_VAELIS else LOADOUT_DEFINITION_ID


static func make_synthetic_small_guard_actor(actor_id: StringName = OPPONENT_ID) -> CombatActorDefinition:
	var actor := make_guard_actor(actor_id, "Synthetic Small Guard Test Fixture")
	if actor == null:
		return null
	actor.actor_kind = &"arena_synthetic_size_test_fixture"
	actor.size_category = HitLocations.SIZE_SMALL
	actor.field_sources["size_category"] = "TASK-29 approved synthetic Arena test assignment; not a printed Prime creature"
	actor.field_sources["fixture_identity"] = "Reuses verified Prime V3 Uncommon Guard statistics and existing Arena loadout solely to test Medium/Small directional ACC"
	return actor


static func make_attack_definition() -> CombatAttackDefinition:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(WEAPON_REF)
	return null if weapon == null else weapon.make_attack_definition(ATTACK_ID, HitLocations.get_same_size_attack_profile()) as CombatAttackDefinition


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var weapon := catalog.get_weapon(WEAPON_REF)
	var shield := catalog.get_shield(SHIELD_REF)
	var weapon_block: CombatBlockDefinition = null if weapon == null else weapon.make_block_definition()
	var shield_block: CombatBlockDefinition = null if shield == null else shield.make_block_definition()
	return CombatDefenseProfile.new(
		StringName("task14_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		weapon_block,
		shield_block,
		PackedStringArray([PRIME_GUARD_SOURCE, PRIME_BATTLE_AXE_SOURCE, PRIME_BUCKLER_SOURCE])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var armor := catalog.get_armor(ARMOR_REF)
	var plate: CombatArmorDefinition = null if armor == null else armor.make_combat_armor_definition()
	return CombatDamageProtectionProfile.new(
		StringName("task14_%s_protection" % String(actor_id)),
		[plate],
		{},
		PackedStringArray([PRIME_PLATE_SOURCE])
	)
