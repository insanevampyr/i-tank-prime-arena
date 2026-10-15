class_name PrimeV3VerticalSliceFixture
extends RefCounted

const PLAYER_ID := &"player"
const OPPONENT_ID := &"opponent"
const ATTACK_ID := &"prime_v3_battle_axe_torso"
const WEAPON_REF := &"prime_v3_battle_axe"
const SHIELD_REF := &"prime_v3_metal_buckler"
const ARMOR_REF := &"prime_v3_plate_torso"

const PRIME_GUARD_SOURCE := "PRIME-V3 pp. 350-351, Uncommon Guard"
const PRIME_BATTLE_AXE_SOURCE := "PRIME-V3 p. 122, Battle Axe"
const PRIME_PLATE_SOURCE := "PRIME-V3 p. 133, Plate torso armor"
const PRIME_BUCKLER_SOURCE := "PRIME-V3 p. 134, Metal Buckler"
const ARENA_DAMAGE_SOURCE := "ARENA-COMBAT-1.6 exact multiplier order"

const BATTLE_AXE_STRENGTH_REQUIREMENT := 12
const BATTLE_AXE_ONE_HAND_STRENGTH_REQUIREMENT := 24
const METAL_BUCKLER_STRENGTH_REQUIREMENT := 8
const PLATE_TORSO_STRENGTH_REQUIREMENT := 16


static func configure_simulation(
	simulation: CombatSimulation,
	player_position_microfeet: Vector2i,
	opponent_position_microfeet: Vector2i
) -> Dictionary:
	if simulation == null:
		return {"success": false, "reason": "missing_simulation"}
	var attack_definition := make_attack_definition()
	for actor_id: StringName in [PLAYER_ID, OPPONENT_ID]:
		var display_name := "Player Guard Fixture" if actor_id == PLAYER_ID else "Opponent Guard Fixture"
		var actor := make_guard_actor(actor_id, display_name)
		var defense_profile := make_defense_profile(actor_id)
		var protection_profile := make_damage_protection_profile(actor_id)
		var validation := validate_combatant_fixture(actor, defense_profile, protection_profile, attack_definition)
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
		var reaction_result := simulation.register_critical_reaction_attack(actor_id, attack_definition, true)
		if not reaction_result.get("success", false):
			return reaction_result

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
		"attack_definition": attack_definition,
		"opening_order": opening_result["opening_order"],
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
	if strength < BATTLE_AXE_STRENGTH_REQUIREMENT:
		return {"success": false, "reason": "battle_axe_strength_requirement_not_met"}
	if strength < METAL_BUCKLER_STRENGTH_REQUIREMENT:
		return {"success": false, "reason": "metal_buckler_strength_requirement_not_met"}
	if strength < PLATE_TORSO_STRENGTH_REQUIREMENT:
		return {"success": false, "reason": "plate_torso_strength_requirement_not_met"}
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
		"battle_axe_two_handed": strength < BATTLE_AXE_ONE_HAND_STRENGTH_REQUIREMENT,
		"buckler_preserves_two_free_hands": true,
	}


static func make_guard_actor(actor_id: StringName, display_name: String) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id,
		&"prime_v3_verified_vertical_slice_fixture",
		display_name,
		{
			"str": 16, "end": 10, "spd": 12, "dex": 14, "wis": 8,
			"int": 5, "wit": 8, "man": 12, "luk": 1, "app": 8,
		},
		{
			"hpm": 100, "acc": 12, "at": 2, "init": 4, "mr": 12,
			"nal": 1, "dt": 8, "dp": 6, "physical_soak": 4,
			"rb": 0, "sb": 4,
		},
		{},
		PackedStringArray([String(WEAPON_REF), String(SHIELD_REF), String(ARMOR_REF)]),
		{
			"dodge": true,
			"weapon_block": true,
			"shield_block": true,
			"physical_soak": true,
		},
		{
			"attributes": PRIME_GUARD_SOURCE,
			"combat_stats": PRIME_GUARD_SOURCE,
			"equipment": "Task 14 fixture assembled only from %s; %s; %s" % [
				PRIME_BATTLE_AXE_SOURCE, PRIME_PLATE_SOURCE, PRIME_BUCKLER_SOURCE,
			],
		},
		PackedStringArray()
	)


static func make_attack_definition() -> CombatAttackDefinition:
	var damage := CombatPhysicalDamageDefinition.new(
		2,
		10,
		3,
		true,
		true,
		{
			"torso": {
				"numerator": 1,
				"denominator": 1,
				"source_ref": "PRIME-V3 torso ordinary location",
			},
		},
		null,
		true,
		CombatPhysicalDamageDefinition.ROUNDING_FLOOR,
		PackedStringArray([PRIME_BATTLE_AXE_SOURCE, ARENA_DAMAGE_SOURCE])
	)
	var critical_policy := CombatCriticalTriggerPolicy.new(
		&"prime_v3_battle_axe_critical_range",
		2,
		0,
		20,
		&"",
		"%s: natural 1-2 is a critical strike" % PRIME_BATTLE_AXE_SOURCE,
		"PRIME-V3 pp. 16, 92, 350: natural 20 critical failure",
		PackedStringArray([PRIME_BATTLE_AXE_SOURCE, "ARENA-COMBAT-1.7 section 18"])
	)
	return CombatAttackDefinition.new(
		ATTACK_ID,
		WEAPON_REF,
		1,
		true,
		true,
		0,
		{"torso": 0},
		PackedStringArray(["torso"]),
		0,
		3_000_000,
		true,
		PackedStringArray([PRIME_BATTLE_AXE_SOURCE, "ARENA-COMBAT-1.7 section 18"]),
		&"hand_held",
		PackedStringArray(["slashing"]),
		true,
		CombatAttackDefinition.DUCKING_UNRESOLVED,
		damage,
		critical_policy
	)


static func make_defense_profile(actor_id: StringName) -> CombatDefenseProfile:
	var weapon_block := CombatBlockDefinition.new(
		CombatBlockDefinition.TYPE_WEAPON,
		WEAPON_REF,
		2,
		0,
		true,
		true,
		null,
		PackedStringArray([PRIME_BATTLE_AXE_SOURCE])
	)
	var shield_block := CombatBlockDefinition.new(
		CombatBlockDefinition.TYPE_SHIELD,
		SHIELD_REF,
		2,
		0,
		true,
		true,
		20,
		PackedStringArray([PRIME_BUCKLER_SOURCE]),
		null
	)
	return CombatDefenseProfile.new(
		StringName("task14_%s_defenses" % String(actor_id)),
		PackedStringArray(["dodge", "weapon_block", "shield_block", "physical_soak"]),
		{},
		weapon_block,
		shield_block,
		PackedStringArray([PRIME_GUARD_SOURCE, PRIME_BATTLE_AXE_SOURCE, PRIME_BUCKLER_SOURCE])
	)


static func make_damage_protection_profile(actor_id: StringName) -> CombatDamageProtectionProfile:
	var plate := CombatArmorDefinition.new(
		ARMOR_REF,
		&"torso",
		PackedStringArray(["torso"]),
		{"bashing": 3, "slashing": 3, "piercing": 3},
		PackedStringArray([PRIME_PLATE_SOURCE])
	)
	return CombatDamageProtectionProfile.new(
		StringName("task14_%s_protection" % String(actor_id)),
		[plate],
		{},
		PackedStringArray([PRIME_PLATE_SOURCE])
	)
