class_name CombatWeaponHandling
extends RefCounted

const STOWED := "stowed"
const ONE_HAND_HOLD := "one_hand_hold"


static func initial_assignments(refs: PackedStringArray, catalog: CombatDefinitionCatalog, actor: CombatActorDefinition) -> Dictionary:
	# Explicit two-slot fixture/loadout setup, not automatic anatomy for arbitrary actors.
	var hands := {"left": "", "right": ""}
	for ref: String in refs:
		var weapon := catalog.get_weapon(StringName(ref))
		if weapon == null: continue
		var required := weapon.effective_hands_required(int(actor.attributes.get("str", -1)))
		if required < 1: return {}
		if required == 2:
			if hands.left != "" or hands.right != "": return {}
			hands.left = ref
			hands.right = ref
		elif hands.right == "": hands.right = ref
		elif hands.left == "": hands.left = ref
		else: return {}
	for ref: String in refs:
		var shield := catalog.get_shield(StringName(ref))
		if shield != null and shield.hand_occupancy == 1:
			if hands.left != "": return {}
			hands.left = ref
	return hands


static func is_attack_ready(state: CombatActorState, weapon_ref: String) -> bool:
	return not state.weapon_handling.has(weapon_ref)


static func plan(state: CombatActorState, weapon: CombatWeaponDefinitionResource, strength: int, operation: String) -> Dictionary:
	if not state.hand_occupancy_authoritative or state.hand_occupancy.size() != 2 or not state.hand_occupancy.has("left") or not state.hand_occupancy.has("right"):
		return _failure("weapon_hand_anatomy_unresolved")
	if weapon == null: return _failure("weapon_definition_unresolved")
	var ref := String(weapon.definition_id)
	if not state.equipment_refs.has(ref): return _failure("weapon_not_owned_in_loadout")
	var required := weapon.effective_hands_required(strength)
	if required < 1: return _failure("equipment_strength_requirement_not_met")
	var hands := state.hand_occupancy.duplicate(true)
	var held: Array[String] = []
	var free: Array[String] = []
	for hand: String in ["right", "left"]:
		if String(hands.get(hand, "")) == ref: held.append(hand)
		elif String(hands.get(hand, "")).is_empty(): free.append(hand)
	var mode := String(state.weapon_handling.get(ref, ""))
	var next_mode := ""
	var acts := 0
	match operation:
		"stow":
			if held.is_empty() or mode == STOWED: return _failure("weapon_not_held")
			for hand: String in held: hands[hand] = ""
			next_mode = STOWED
		"hold_one":
			if required != 2 or held.size() != 2 or not mode.is_empty(): return _failure("weapon_not_in_two_hand_grip")
			hands[held[1]] = ""
			next_mode = ONE_HAND_HOLD
		"regrip":
			if mode != ONE_HAND_HOLD or held.size() != 1: return _failure("weapon_not_held_one_handed")
			if free.size() < required - held.size(): return _failure("weapon_required_hand_occupied")
			for index in range(required - held.size()): hands[free[index]] = ref
		"draw":
			if mode != STOWED or not held.is_empty(): return _failure("weapon_not_stowed")
			if free.size() < required: return _failure("weapon_required_hand_occupied")
			for index in range(required): hands[free[index]] = ref
			acts = 1
		_: return _failure("weapon_operation_unsupported")
	return {"success": true, "hand_occupancy": hands, "mode": next_mode, "required_acts": acts}


static func label(state: CombatActorState, weapon: CombatWeaponDefinitionResource, strength: int) -> String:
	var ref := String(weapon.definition_id)
	match String(state.weapon_handling.get(ref, "")):
		STOWED: return "STOWED"
		ONE_HAND_HOLD: return "HELD — ONE HAND"
	if not state.hand_occupancy.values().has(ref): return "NOT HELD"
	return "READY — TWO-HANDED" if weapon.effective_hands_required(strength) == 2 else "READY — ONE-HANDED"


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
