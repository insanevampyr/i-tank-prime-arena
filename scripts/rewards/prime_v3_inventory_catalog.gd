class_name PrimeV3InventoryCatalog
extends RefCounted

const HEALTH_POTION_IDS := ["health_potion", "prime_v3_potion_06", "prime_v3_potion_18", "prime_v3_potion_20"]
const MANA_POTION_IDS := ["prime_v3_potion_12", "prime_v3_potion_19"]


static func make_carried_potion_action_definition(definition_id: String, action_id: StringName) -> CombatActionDefinition:
	var potion := get_verified_consumable(definition_id)
	if potion.is_empty(): return null
	return CombatActionDefinition.new(
		action_id, 2, true, true, {},
		{"verified_consumable": {
			"kind": "healing" if potion.effect_kind == "hpc" else "mana",
			"inventory_id": definition_id, "dice_count": potion.dice_count,
			"die_sides": potion.die_sides, "flat_bonus": potion.flat_bonus,
			"requires_free_hand": true,
		}, "preparation": "one_act_retrieve_carried_item_then_one_act_drink"},
		PackedStringArray(["PRIME-V3 p. 20: bag retrieval and drinking each cost one Act", "PRIME-V3 p. 120: Health/Mana Potion effects"])
	)


static func validate_potion_hands(actor_state: CombatActorState, strength: int) -> String:
	if not actor_state.hand_occupancy_authoritative:
		return "consumable_hand_occupancy_unresolved"
	if not String(actor_state.hand_occupancy.get("left", "")).is_empty() \
	and not String(actor_state.hand_occupancy.get("right", "")).is_empty():
		return "consumable_free_hand_required"
	# A partial grip must come from the owner-approved authoritative holding transition,
	# not a forged hand assignment. Holding grants no two-handed attack/Block permission.
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	for held_ref: Variant in actor_state.hand_occupancy.values():
		if String(held_ref).is_empty(): continue
		var weapon := catalog.get_weapon(StringName(held_ref))
		if weapon != null and weapon.effective_hands_required(strength) != 1:
			if String(actor_state.weapon_handling.get(String(held_ref), "")) != CombatWeaponHandling.ONE_HAND_HOLD:
				return "consumable_weapon_hand_occupancy_invalid"
	return ""


static func describe_item(
	definition_id: String,
	quantity: int,
	equipped: bool,
	catalog: CombatDefinitionCatalog,
	provenance: Dictionary = {}
) -> Dictionary:
	var result := {
		"definition_id": definition_id,
		"display_name": definition_id.replace("_", " ").capitalize(),
		"quantity": quantity,
		"category": "other",
		"equipped": equipped,
		"magical": false,
		"source_refs": [],
		"provenance": provenance.duplicate(true),
		"equipable": false,
		"usable": false,
		"blocked_reason": "item_definition_incomplete",
		"requirements": "Source definition incomplete",
	}
	var weapon := catalog.get_weapon(StringName(definition_id))
	if weapon != null:
		result.merge({
			"display_name": weapon.display_name, "category": "weapon",
			"magical": weapon.enchantment_bonus > 0,
			"source_refs": Array(weapon.source_refs), "equipable": quantity > 0,
			"blocked_reason": "" if quantity > 0 or equipped else "item_unavailable",
			"requirements": "STR %s; %s hand(s); reach %.0f ft" % [
				weapon.strength_requirement, weapon.base_hands_required,
				float(weapon.reach_microfeet) / 1_000_000.0,
			],
		}, true)
		return result
	var armor := catalog.get_armor(StringName(definition_id))
	if armor != null:
		result.merge({
			"display_name": armor.display_name, "category": "armor",
			"source_refs": Array(armor.source_refs), "equipable": quantity > 0,
			"blocked_reason": "" if quantity > 0 or equipped else "item_unavailable",
			"requirements": "STR %s; %s slot" % [armor.strength_requirement, String(armor.armor_slot)],
		}, true)
		return result
	var shield := catalog.get_shield(StringName(definition_id))
	if shield != null:
		result.merge({
			"display_name": shield.display_name, "category": "shield",
			"source_refs": Array(shield.source_refs), "equipable": quantity > 0,
			"blocked_reason": "" if quantity > 0 or equipped else "item_unavailable",
			"requirements": "STR %s; %s hand(s); SHP %s" % [
				shield.strength_requirement, shield.hand_occupancy, shield.maximum_shp,
			],
		}, true)
		return result
	var consumable := get_verified_consumable(definition_id)
	if not consumable.is_empty():
		result.merge(consumable, true)
		result["quantity"] = quantity
		result["usable"] = quantity > 0
		result["blocked_reason"] = "" if quantity > 0 else "item_unavailable"
		return result
	return result


static func get_verified_consumable(definition_id: String) -> Dictionary:
	if HEALTH_POTION_IDS.has(definition_id):
		return {
			"definition_id": definition_id,
			"display_name": "Health Potion",
			"category": "consumable",
			"magical": true,
			"effect_kind": "hpc",
			"dice_count": 1,
			"die_sides": 10,
			"flat_bonus": 2,
			"required_acts": 1,
			"requires_free_hand": true,
			"requirements": "One free hand; one Act; restores 1d10+2 HPC",
			"source_refs": ["PRIME-V3 p. 20 (item use costs one Act)", "PRIME-V3 p. 120 (Health Potion 1d10+2 HPC)"],
		}
	if MANA_POTION_IDS.has(definition_id):
		return {
			"definition_id": definition_id,
			"display_name": "Mana Potion",
			"category": "consumable",
			"magical": true,
			"effect_kind": "mana",
			"dice_count": 3,
			"die_sides": 6,
			"flat_bonus": 2,
			"required_acts": 1,
			"requires_free_hand": true,
			"requirements": "One free hand; one Act; restores 3d6+2 Mana",
			"source_refs": ["PRIME-V3 p. 20 (item use costs one Act)", "PRIME-V3 p. 120 (Mana Potion 3d6+2 Mana)"],
		}
	return {}
