class_name PrimeV3AdvancementCatalog
extends RefCounted

const ATTRIBUTE_IDS := [&"str", &"end", &"spd", &"dex", &"wis", &"int", &"wit", &"man", &"luk", &"app"]
const ATTRIBUTE_EXCLUSIONS := ["app"]
const SOURCE_REF := "ITank Prime V3 printed pp. 18-21, 27, 46, 67, 72, 87-89, 99-102, 229"
const PURCHASE_SOURCE_REF := "ITank Prime V3 printed p. 102"


static func attribute_cost(current_value: int) -> Variant:
	if current_value < 1:
		return null
	if current_value <= 5:
		return 2_000
	if current_value <= 10:
		return 3_000
	if current_value <= 15:
		return 5_000
	if current_value <= 20:
		return 7_000
	if current_value <= 30:
		return 8_000
	return 10_000


static func field_level_cost(field_kind: StringName, target_level: int) -> Variant:
	if target_level < 1:
		return null
	var multiplier := 2_000 if field_kind == &"hsf" else (3_000 if field_kind == &"osf" else 0)
	if multiplier == 0:
		return null
	if target_level >= 14:
		return target_level * multiplier
	var hsf_costs := [500, 1_000, 1_500, 4_000, 5_000, 6_000, 14_000, 16_000, 18_000, 20_000, 22_000, 24_000, 26_000]
	var osf_costs := [600, 1_200, 1_800, 6_000, 7_500, 9_000, 21_000, 24_000, 27_000, 30_000, 33_000, 36_000, 39_000]
	return (hsf_costs if field_kind == &"hsf" else osf_costs)[target_level - 1]


static func make_purchase_preview(
	purchase_kind: StringName,
	target_id: StringName,
	current_value: int,
	target_value: int
) -> Dictionary:
	var cost: Variant = null
	var blocked_reason := ""
	var available := false
	if purchase_kind in [&"attribute", &"special_resistance", &"talent_bonus"]:
		if purchase_kind == &"attribute" and ATTRIBUTE_EXCLUSIONS.has(String(target_id)):
			blocked_reason = "appearance_uses_source_specific_advancement_not_this_chart"
		elif purchase_kind == &"attribute" and not ATTRIBUTE_IDS.has(target_id):
			blocked_reason = "unknown_attribute"
		elif purchase_kind == &"special_resistance" and target_id != &"sr":
			blocked_reason = "special_resistance_target_mismatch"
		elif purchase_kind == &"talent_bonus" and target_id != &"tb":
			blocked_reason = "talent_bonus_target_mismatch"
		elif target_value != current_value + 1:
			blocked_reason = "advancement_must_increase_one_point"
		else:
			cost = attribute_cost(current_value)
			if purchase_kind == &"attribute":
				blocked_reason = _attribute_blocked_reason(target_id)
			else:
				available = cost != null
	elif purchase_kind in [&"hsf", &"osf"]:
		cost = field_level_cost(purchase_kind, target_value)
		blocked_reason = (
			"osf_requires_expc_before_ss_check_training_clock_failure_lockout_and_field_progression"
			if purchase_kind == &"osf"
			else "hsf_requires_ordered_field_progression_training_clock_and_character_field_records"
		)
	elif purchase_kind == &"skill":
		blocked_reason = "skills_use_s_number_investments_no_verified_expc_purchase_rule"
	elif purchase_kind == &"special_repurchase":
		blocked_reason = "special_repurchase_requires_verified_field_level_daily_cadence_and_character_access_record"
	else:
		blocked_reason = "purchase_kind_unverified"
	if cost == null and blocked_reason.is_empty():
		blocked_reason = "purchase_cost_unresolved"
	return {
		"purchase_kind": String(purchase_kind),
		"target_id": String(target_id),
		"current_value": current_value,
		"target_value": target_value,
		"cost": cost,
		"available": available,
		"blocked_reason": blocked_reason,
		"source_ref": PURCHASE_SOURCE_REF,
	}


static func build_actor_purchase_options(actor: CombatActorDefinition) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if actor == null:
		return options
	for attribute_id: StringName in ATTRIBUTE_IDS:
		var current: Variant = actor.attributes.get(String(attribute_id))
		if typeof(current) != TYPE_INT:
			options.append(_unresolved_option(&"attribute", attribute_id, "source_current_value_unresolved"))
			continue
		options.append(make_purchase_preview(&"attribute", attribute_id, int(current), int(current) + 1))
	for resistance: Dictionary in [
		{"purchase_kind": &"special_resistance", "target_id": &"sr"},
		{"purchase_kind": &"talent_bonus", "target_id": &"tb"},
	]:
		var current: Variant = actor.get_base_combat_stat(String(resistance["target_id"]))
		if typeof(current) != TYPE_INT:
			options.append(_unresolved_option(resistance["purchase_kind"], resistance["target_id"], "source_current_value_unresolved"))
			continue
		options.append(make_purchase_preview(
			resistance["purchase_kind"], resistance["target_id"], int(current), int(current) + 1
		))
	options.append(_unresolved_option(&"skill", &"verified_skill", "skills_use_s_number_investments_no_verified_expc_purchase_rule"))
	options.append(_unresolved_option(&"hsf", &"verified_hsf", "hsf_requires_ordered_field_progression_training_clock_and_character_field_records"))
	options.append(_unresolved_option(&"osf", &"verified_osf", "osf_requires_expc_before_ss_check_training_clock_failure_lockout_and_field_progression"))
	options.append(_unresolved_option(&"special_repurchase", &"verified_special", "special_repurchase_requires_verified_field_level_daily_cadence_and_character_access_record"))
	return options


static func _attribute_blocked_reason(attribute_id: StringName) -> String:
	match attribute_id:
		&"dex":
			return "dex_increase_requires_authoritative_dt_dp_allocation_choice"
		&"wis":
			return "wis_increase_requires_verified_mana_and_magic_derived_recalculation_policy"
		&"app":
			return "appearance_uses_source_specific_advancement_not_this_chart"
		_:
			return "attribute_dependent_stat_recalculation_not_yet_source_integrated"


static func _unresolved_option(purchase_kind: StringName, target_id: StringName, reason: String) -> Dictionary:
	return {
		"purchase_kind": String(purchase_kind),
		"target_id": String(target_id),
		"current_value": null,
		"target_value": null,
		"cost": null,
		"available": false,
		"blocked_reason": reason,
		"source_ref": SOURCE_REF,
	}
