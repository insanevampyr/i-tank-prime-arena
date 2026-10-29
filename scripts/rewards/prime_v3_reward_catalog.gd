class_name PrimeV3RewardCatalog
extends RefCounted

const CREATURE_REWARDS := {
	"common_goblin": {
		"xp": 1,
		"drop_codes": [{"code": "B", "count": 2}],
		"source_ref": "Common Goblin.doc: EXP 1; Drops B x2",
	},
	"common_spadoodle": {
		"xp": 3,
		"drop_codes": [{"code": "C", "count": 1}],
		"source_ref": "Common Spadoodle.doc: EXP 3 each; Drops C x1",
	},
	"common_skelly": {
		"xp": 10,
		"drop_codes": [{"code": "C", "count": 1}],
		"source_ref": "Common Skelly.doc: EXP 10; Drops C x1",
	},
	"hades_combat_follower": {
		"xp": 100,
		"drop_codes": [{"code": "C", "count": 1}],
		"source_ref": "Uncommon Hades Follower Combat.doc: EXP 100; Drops C x1",
	},
	"mini_gargoyle_swarmer": {
		"xp": 500,
		"drop_codes": [{"code": "C", "count": 3}, {"code": "A", "count": 1}],
		"source_ref": "Uncommon Mini Gargoyle Swarmers.doc: EXP 500 per; Drops C x3 and A x1",
	},
}

const ARENA_XP_OVERRIDES := {
	"common_goblin": 10, "common_spadoodle": 30, "common_skelly": 50,
	"hades_combat_follower": 100, "mini_gargoyle_swarmer": 500,
}

const CREATURE_POSSESSIONS := {
	"hades_combat_follower": [
		{
			"definition_id": "prime_v3_hades_follower_short_sword",
			"display_name": "Short Sword",
			"item_kind": "equipment",
			"quantity": 1,
			"source_ref": "Uncommon Hades Follower Combat.doc: carried Short Sword",
		},
	],
	"rare_human_warrior_boss": [
		{"definition_id": "prime_v3_rare_human_warrior_boar_spear", "display_name": "Enchanted Boar Spear", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35E boss equipment resource"},
		{"definition_id": "prime_v3_scale_mail_torso", "display_name": "Scale Mail Torso", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_head", "display_name": "Scale Mail Head", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_arms", "display_name": "Scale Mail Arms", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_legs", "display_name": "Scale Mail Legs", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_elbows", "display_name": "Scale Mail Elbows", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_knees", "display_name": "Scale Mail Knees", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
		{"definition_id": "prime_v3_scale_mail_hands", "display_name": "Scale Mail Hands", "item_kind": "equipment", "quantity": 1, "source_ref": "Accepted Task 35C-35D seven-location boss loadout"},
	],
}

const CREATURE_INVENTORY_POSSESSIONS := {
	"rare_human_warrior_boss": [
		{"inventory_id": "backpack", "display_name": "Backpack", "item_kind": "possession", "source_ref": "Accepted Task 35C boss inventory resource"},
		{"inventory_id": "good_ration", "display_name": "Good Ration", "item_kind": "consumable", "source_ref": "Accepted Task 35C boss inventory resource"},
		{"inventory_id": "health_potion", "display_name": "Health Potion", "item_kind": "potion", "source_ref": "Accepted Task 35C/35G boss inventory resource"},
		{"inventory_id": "lantern_and_oils", "display_name": "Lantern and Oil", "item_kind": "possession", "source_ref": "Accepted Task 35C boss inventory resource"},
		{"inventory_id": "rope", "display_name": "Rope", "item_kind": "possession", "source_ref": "Accepted Task 35C boss inventory resource"},
		{"inventory_id": "water", "display_name": "Water", "item_kind": "consumable", "source_ref": "Accepted Task 35C boss inventory resource"},
	],
}


static func creature_id_for_actor(actor_id: StringName) -> String:
	var value := String(actor_id)
	if value.begins_with("wave_1_common_goblin_"):
		return "common_goblin"
	if value.begins_with("wave_2_common_spadoodle_"):
		return "common_spadoodle"
	if value.begins_with("wave_3_common_skelly_"):
		return "common_skelly"
	if value.begins_with("wave_3_hades_combat_follower_"):
		return "hades_combat_follower"
	if value.begins_with("wave_4_mini_gargoyle_swarmer_"):
		return "mini_gargoyle_swarmer"
	if value == "wave_5_rare_human_warrior_1":
		return "rare_human_warrior_boss"
	return ""


static func get_reward(creature_id: String) -> Dictionary:
	return (CREATURE_REWARDS.get(creature_id, {}) as Dictionary).duplicate(true)


static func get_possessions(creature_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in CREATURE_POSSESSIONS.get(creature_id, []):
		result.append(entry.duplicate(true))
	return result


static func get_inventory_possessions(creature_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in CREATURE_INVENTORY_POSSESSIONS.get(creature_id, []):
		result.append(entry.duplicate(true))
	return result


static func get_blocked_reason(creature_id: String) -> String:
	if creature_id == "rare_human_warrior_boss":
		return "rare_human_warrior_reward_source_protected_and_not_recorded_elsewhere"
	return "creature_reward_source_unverified"
