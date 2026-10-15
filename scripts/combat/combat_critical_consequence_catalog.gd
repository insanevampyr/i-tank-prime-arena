class_name CombatCriticalConsequenceCatalog
extends RefCounted

const SOURCE_REF := "ARENA-COMBAT-1.7 section 18; APPROVED-CRITICAL-TABLES 2026-10-14"
const DWARVESTEK_FIREARM_TABLE := &"dwarvestek_firearm_failure"
const GRENTEK_EXPLOSIVE_TABLE := &"grentek_explosive_failure"


static func get_outcome(roll_category: StringName, result_kind: StringName, rarity: StringName) -> Dictionary:
	var table_key := "%s:%s" % [String(roll_category), String(result_kind)]
	var tables := _tables()
	if not tables.has(table_key):
		return {}
	var table: Dictionary = tables[table_key]
	var outcome: Dictionary = (table.get(String(rarity), {}) as Dictionary).duplicate(true)
	if outcome.is_empty():
		return {}
	outcome["table_id"] = StringName("%s_%s" % [String(roll_category), String(result_kind)])
	outcome["source_ref"] = SOURCE_REF
	return outcome


static func get_all_outcomes() -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var tables := _tables()
	var table_keys: Array = tables.keys()
	table_keys.sort()
	for table_key: String in table_keys:
		var parts := table_key.split(":")
		for rarity: StringName in [CombatCriticalRecord.RARITY_COMMON, CombatCriticalRecord.RARITY_UNCOMMON, CombatCriticalRecord.RARITY_RARE]:
			var outcome := get_outcome(StringName(parts[0]), StringName(parts[1]), rarity)
			outcome["roll_category"] = parts[0]
			outcome["result_kind"] = parts[1]
			outcome["rarity"] = String(rarity)
			outcomes.append(outcome)
	return outcomes


static func get_weapon_specific_outcome(table_id: StringName, rarity: StringName) -> Dictionary:
	var themes := {
		String(DWARVESTEK_FIREARM_TABLE): {
			"common": ["dwarvestek_common_misfire_theme", "Dwarvestek Common Misfire Theme"],
			"uncommon": ["dwarvestek_uncommon_backfire_theme", "Dwarvestek Dangerous Backfire Theme"],
			"rare": ["dwarvestek_rare_catastrophic_theme", "Dwarvestek Catastrophic Failure Theme"],
		},
		String(GRENTEK_EXPLOSIVE_TABLE): {
			"common": ["grentek_common_mishap_theme", "Grentek Common Mishap Theme"],
			"uncommon": ["grentek_uncommon_backfire_theme", "Grentek Dangerous Backfire Theme"],
			"rare": ["grentek_rare_catastrophic_theme", "Grentek Catastrophic Failure Theme"],
		},
	}
	if not themes.has(String(table_id)) or not (themes[String(table_id)] as Dictionary).has(String(rarity)):
		return {}
	var row: Array = themes[String(table_id)][String(rarity)]
	return {
		"table_id": table_id,
		"outcome_id": row[0],
		"name": row[1],
		"effects": [_effect("%s_gate" % row[0], "weapon_specific_gate", "source", {
			"reason": "exact_weapon_specific_mechanics_unresolved",
		})],
		"source_ref": SOURCE_REF,
	}


static func _effect(effect_id: String, effect_type: String, target: String = "", extra: Dictionary = {}) -> Dictionary:
	var value := {"effect_id": effect_id, "type": effect_type, "target": target}
	value.merge(extra, true)
	return value


static func _outcome(outcome_id: String, name: String, effects: Array) -> Dictionary:
	return {"outcome_id": outcome_id, "name": name, "effects": effects}


static func _tables() -> Dictionary:
	return {
		"physical_attack:success": {
			"common": _outcome("potent_strike", "Potent Strike", [_effect("potent_strike_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1})]),
			"uncommon": _outcome("relentless_follow_up", "Relentless Follow-up", [_effect("relentless_follow_up_reaction", "critical_reaction", "source_to_target")]),
			"rare": _outcome("perfect_sequence", "Perfect Sequence", [_effect("perfect_sequence_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1}), _effect("perfect_sequence_reaction", "critical_reaction", "source_to_target")]),
		},
		"physical_attack:failure": {
			"common": _outcome("off_balance", "Off Balance", [_effect("off_balance_stagger", "critical_stagger", "source")]),
			"uncommon": _outcome("bad_opening", "Bad Opening", [_effect("bad_opening_counter", "critical_reaction", "target_to_source")]),
			"rare": _outcome("disastrous_backfire", "Disastrous Backfire", [_effect("disastrous_backfire_redirect", "backfire_redirect", "source")]),
		},
		"dodge:success": {
			"common": _outcome("perfect_evasion", "Perfect Evasion", [_effect("perfect_evasion_selection", "perfect_evasion", "source")]),
			"uncommon": _outcome("wrong_footed", "Wrong-Footed", [_effect("wrong_footed_stagger", "critical_stagger", "target")]),
			"rare": _outcome("turnabout", "Turnabout", [_effect("turnabout_counter", "critical_reaction", "source_to_target")]),
		},
		"dodge:failure": {
			"common": _outcome("stumble", "Stumble", [_effect("stumble_stagger", "critical_stagger", "source")]),
			"uncommon": _outcome("hard_fall", "Hard Fall", [_effect("hard_fall_prone", "prone", "source")]),
			"rare": _outcome("catastrophic_misstep", "Catastrophic Misstep", [_effect("catastrophic_misstep_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1})]),
		},
		"weapon_block:success": {
			"common": _outcome("jarring_parry", "Jarring Parry", [_effect("jarring_parry_stagger", "critical_stagger", "target")]),
			"uncommon": _outcome("riposte", "Riposte", [_effect("riposte_counter", "critical_reaction", "source_to_target")]),
			"rare": _outcome("masterful_reversal", "Masterful Reversal", [_effect("masterful_reversal_stagger", "critical_stagger", "target"), _effect("masterful_reversal_counter", "critical_reaction", "source_to_target")]),
		},
		"weapon_block:failure": {
			"common": _outcome("shaken_guard", "Shaken Guard", [_effect("shaken_guard_stagger", "critical_stagger", "source")]),
			"uncommon": _outcome("knocked_down", "Knocked Down", [_effect("knocked_down_prone", "prone", "source")]),
			"rare": _outcome("guard_shattered", "Guard Shattered", [_effect("guard_shattered_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1})]),
		},
		"shield_block:success": {
			"common": _outcome("shield_bash", "Shield Bash", [_effect("shield_bash_stagger", "critical_stagger", "target")]),
			"uncommon": _outcome("shield_reversal", "Shield Reversal", [_effect("shield_reversal_counter", "critical_reaction", "source_to_target")]),
			"rare": _outcome("devastating_reversal", "Devastating Reversal", [_effect("devastating_reversal_prone", "shield_contact_prone", "target"), _effect("devastating_reversal_counter", "critical_reaction", "source_to_target")]),
		},
		"shield_block:failure": {
			"common": _outcome("buckled_guard", "Buckled Guard", [_effect("buckled_guard_stagger", "critical_stagger", "source")]),
			"uncommon": _outcome("driven_down", "Driven Down", [_effect("driven_down_prone", "prone", "source")]),
			"rare": _outcome("crushing_breakthrough", "Crushing Breakthrough", [_effect("crushing_breakthrough_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1})]),
		},
		"physical_soak:success": {
			"common": _outcome("unshakable", "Unshakable", [_effect("unshakable_same_attack", "same_attack_protection", "source")]),
			"uncommon": _outcome("immovable", "Immovable", [_effect("immovable_stagger", "critical_stagger", "target")]),
			"rare": _outcome("overpowering_resilience", "Overpowering Resilience", [_effect("overpowering_resilience_stagger", "critical_stagger", "target"), _effect("overpowering_resilience_counter", "critical_reaction", "source_to_target")]),
		},
		"physical_soak:failure": {
			"common": _outcome("overwhelmed", "Overwhelmed", [_effect("overwhelmed_stagger", "critical_stagger", "source")]),
			"uncommon": _outcome("brought_down", "Brought Down", [_effect("brought_down_prone", "prone", "source")]),
			"rare": _outcome("crushing_impact", "Crushing Impact", [_effect("crushing_impact_x2", "damage_multiplier", "parent_attack", {"numerator": 2, "denominator": 1})]),
		},
	}
