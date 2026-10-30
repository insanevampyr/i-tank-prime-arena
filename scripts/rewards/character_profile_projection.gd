class_name CharacterProfileProjection
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Advancement = preload("res://scripts/rewards/prime_v3_advancement_catalog.gd")
const Growth = preload("res://scripts/rewards/prime_v3_level_catalog.gd")
const HISTORY_FIELDS := ["prior_level", "level", "threshold", "hit_die_sides", "die_flat_bonus", "roll", "hpb", "hpm_increase", "hpm_before", "hpm_after", "resource", "wisdom", "maximum_before", "maximum_increase", "maximum_after"]
const PURCHASE_FIELDS := ["purchase_kind", "target_id", "value_before", "value_after", "cost", "source_ref"]
const PERMANENT_FIELDS := ["level", "growth", "resource_maxima", "ability_allowances", "equipment_refs", "inventory_quantities", "xp_baseline", "award_receipts"]
const LINEAGE_FIELDS := ["profile_id", "definition_id", "rules_revision", "run_id", "mode_history", "baseline_digest"]

# The verifier is a trusted host authority port, NOT data from UI or a save.
# No live session supplies this port in Pass1. Missing lineage/instance evidence
# therefore fails closed. Tests supply an explicitly isolated authority fixture.
static func project(source: CombatCharacterDefinitionResource, actor: CombatActorDefinition, state: CombatActorState, ledger: Dictionary, defense: CombatDefenseProfile, verifier: Callable = Callable()) -> Dictionary:
	if source == null or actor == null or state == null: return _fail("source_unavailable")
	if state.actor_id != actor.actor_id or actor.progression_policy != source.progression_policy or actor.class_names != source.class_names: return _fail("source_identity_mismatch")
	if not verifier.is_valid(): return _fail("authoritative_lineage_and_instances_unavailable")
	var binding := fingerprint({"actor":actor.to_dictionary(), "state":state.to_dictionary(), "ledger":ledger, "defense":defense.to_dictionary() if defense != null else {}})
	var evidence: Dictionary = verifier.call("project", binding)
	if not evidence.get("authorized",false) or evidence.get("binding") != binding: return _fail("source_authority_rejected")
	var save_namespace := String(evidence.get("profile_namespace","normal"))
	if save_namespace not in ["normal","dev_normal"] or ledger.get("mode") != save_namespace: return _fail("production_normal_only")
	if save_namespace == "dev_normal" and not String(evidence.get("profile_id","")).begins_with("dev_"): return _fail("developer_namespace_required")
	if not state.weapon_handling.is_empty() and not evidence.has("equipment_state"): return _fail("weapon_handling_instance_mapping_unavailable")
	var daily_maxima := {}
	for id: String in actor.ability_allowances:
		var maximum: Variant = actor.get_ability_daily_maximum(StringName(id))
		if maximum == null: return _fail("daily_entitlement_unverified")
		daily_maxima[id] = maximum
	if state.ability_daily_maxima != daily_maxima: return _fail("unrepresented_daily_entitlement")
	var awards: Array = []
	for id: String in state.progression.get("award_ids",[]):
		if not evidence.get("award_receipts",{}).has(id): return _fail("durable_award_identity_unavailable")
		awards.append(evidence.award_receipts[id].duplicate(true))
	var purchases: Array = []
	for record: Dictionary in ledger.get("purchase_records",[]):
		var key := String(record.get("request_id",""))
		if not evidence.get("purchase_ids",{}).has(key): return _fail("durable_purchase_identity_unavailable")
		var normalized := {"purchase_id":evidence.purchase_ids[key]}
		for field: String in PURCHASE_FIELDS:
			if not record.has(field): return _fail("purchase_history_incomplete")
			normalized[field] = record[field]
		purchases.append(normalized)
	var history: Array = []
	for record: Dictionary in state.progression.get("history",[]):
		var key := "%s:%s" % [record.get("award_id",""),record.get("level",0)]
		if not evidence.get("growth_ids",{}).has(key): return _fail("durable_growth_identity_unavailable")
		var normalized := {"growth_id":evidence.growth_ids[key]}
		for field: String in HISTORY_FIELDS:
			if not record.has(field): return _fail("growth_history_incomplete")
			normalized[field] = record[field]
		history.append(normalized)
	var initial_expm := int(actor.progression_policy.get("initial_expm",-1))
	var initial_expc := int(actor.progression_policy.get("initial_expc",-1))
	var earned := int(ledger.get("earned_xp",-1))
	var spent := int(ledger.get("spent_xp",-1))
	var expm := initial_expm + earned
	var expc := initial_expc + earned - spent
	if state.progression.get("expm",initial_expm) != expm or state.progression.get("expc",initial_expc) != expc: return _fail("progression_ledger_mismatch")
	if state.progression.get("run_earned_xp",0) != earned or state.progression.get("run_spent_xp",0) != spent: return _fail("progression_run_totals_mismatch")
	var payload := {
		"character_id":evidence.get("profile_id",""), "definition_id":String(source.definition_id),
		"rules_revision":evidence.get("rules_revision",""), "generation":evidence.get("generation",0),
		"base_attributes":source.attributes.duplicate(true),
		"xp":{"earned":expm,"spent":expm-expc,"unspent":expc}, "purchases":purchases,
		"items":evidence.get("items",[]).duplicate(true), "secured_checkpoints":evidence.get("secured_checkpoints",[]).duplicate(),
		"lineage":{}, "permanent":{
			"level":state.progression.get("level",actor.level), "growth":history,
			"resource_maxima":actor.resource_maxima.duplicate(true), "ability_allowances":actor.ability_allowances.duplicate(true),
			"equipment_refs":Array(state.equipment_refs), "inventory_quantities":state.inventory_quantities.duplicate(true),
			"xp_baseline":{"expm":initial_expm,"expc":initial_expc,"earned":earned,"spent":spent}, "award_receipts":awards}}
	for field: String in LINEAGE_FIELDS: payload.lineage[field] = evidence.get(field)
	if evidence.has("profile_namespace"): payload["profile_namespace"] = save_namespace
	if evidence.has("run_history"): payload["run_history"] = evidence.run_history.duplicate()
	if evidence.has("equipment_state"):
		if evidence.equipment_state != {"hands":state.hand_occupancy,"handling":state.weapon_handling}: return _fail("equipment_state_source_mismatch")
		payload["equipment_state"] = evidence.equipment_state.duplicate(true)
	var candidate := hydrate(payload, source, String(payload.character_id), String(payload.rules_revision), verifier)
	if not candidate.get("success",false): return candidate
	var reconstructed: CombatActorDefinition = candidate.actor_definition
	var source_definition := actor.to_dictionary()
	source_definition.actor_id = String(reconstructed.actor_id)
	if source_definition != reconstructed.to_dictionary() or actor.equipment_refs != state.equipment_refs:
		return _fail("unrepresented_character_changes")
	if state.hand_occupancy_authoritative and state.hand_occupancy != candidate.hand_occupancy: return _fail("hand_ownership_mismatch")
	if defense != null and defense.shield_block != null:
		var ref := String(defense.shield_block.equipment_ref)
		if not candidate.shield_blocks.has(ref) or candidate.shield_blocks[ref].current_shp != defense.shield_block.current_shp or candidate.shield_blocks[ref].usable != defense.shield_block.usable: return _fail("shield_instance_state_mismatch")
	elif not candidate.shield_blocks.is_empty(): return _fail("shield_damage_source_unavailable")
	var encoded := Contract.encode(payload)
	if not encoded.get("success",false): return encoded
	return {"success":true,"payload":payload,"text":encoded.text}

static func hydrate(payload: Dictionary, source: CombatCharacterDefinitionResource, profile_id: String, rules_revision: String, verifier: Callable = Callable()) -> Dictionary:
	var validation := Contract.validate(payload)
	if not validation.success: return _fail("invalid_contract",validation)
	if not payload.has("permanent") or not payload.has("lineage"): return _fail("v1_lossless_migration_requires_missing_history")
	if source == null or String(source.definition_id) != payload.definition_id or payload.character_id != profile_id or payload.rules_revision != rules_revision: return _fail("profile_definition_or_rules_mismatch")
	if not CharacterSaveStorage._valid_id(profile_id): return _fail("invalid_profile_identity")
	if not verifier.is_valid(): return _fail("authoritative_lineage_and_instances_unavailable")
	var evidence: Dictionary = verifier.call("hydrate",fingerprint(payload))
	if not evidence.get("authorized",false) or evidence.get("binding") != fingerprint(payload) or evidence.get("lineage") != payload.lineage: return _fail("profile_authority_rejected")
	var lineage: Dictionary = payload.lineage
	if not _keys(lineage,LINEAGE_FIELDS) or lineage.profile_id != profile_id or lineage.definition_id != payload.definition_id or lineage.rules_revision != rules_revision or lineage.baseline_digest != fingerprint(source.to_dictionary()) or not lineage.run_id is String or not CharacterSaveStorage._valid_id(lineage.run_id): return _fail("lineage_identity_mismatch")
	if not lineage.mode_history is Array or lineage.mode_history.is_empty(): return _fail("nonproduction_lineage")
	var save_namespace := String(payload.get("profile_namespace","normal"))
	for mode: Variant in lineage.mode_history:
		if mode != save_namespace: return _fail("nonproduction_lineage")
	var p: Dictionary = payload.permanent
	if not _keys(p,PERMANENT_FIELDS) or not p.growth is Array or not p.resource_maxima is Dictionary or not p.inventory_quantities is Dictionary or not p.equipment_refs is Array or not p.xp_baseline is Dictionary or not p.award_receipts is Array: return _fail("invalid_permanent_fields")
	for ref: Variant in p.equipment_refs:
		if not ref is String or ref.is_empty(): return _fail("invalid_equipment_reference")
	if payload.base_attributes != source.attributes: return _fail("attribute_history_unverified")
	var actor: CombatActorDefinition = source.instantiate_actor(&"profile_candidate", source.display_name, PackedStringArray(p.equipment_refs))
	if actor == null: return _fail("definition_invalid")
	var policy := actor.progression_policy
	if not Growth.validate(policy,actor).is_empty(): return _fail("progression_source_unverified")
	var b: Dictionary = p.xp_baseline
	if not _keys(b,["expm","expc","earned","spent"]): return _fail("xp_baseline_invalid")
	for value: Variant in b.values():
		if not Contract._integer(value,0): return _fail("xp_baseline_invalid")
	if b.expm != policy.initial_expm or b.expc != policy.initial_expc or b.spent > b.earned or payload.xp.earned != b.expm+b.earned or payload.xp.unspent != b.expc+b.earned-b.spent: return _fail("xp_baseline_mismatch")
	var award_total := 0
	var award_ids := {}
	for receipt: Variant in p.award_receipts:
		if not receipt is Dictionary or not _keys(receipt,["award_id","xp"]) or not _namespaced(receipt.award_id,profile_id,lineage.run_id) or award_ids.has(receipt.award_id) or not Contract._integer(receipt.xp,0): return _fail("invalid_award_receipt")
		award_ids[receipt.award_id] = true
		award_total += int(receipt.xp)
	if award_total != b.earned: return _fail("award_total_mismatch")
	var purchase_cost := 0
	for purchase: Dictionary in payload.purchases:
		if not _keys(purchase,PURCHASE_FIELDS+["purchase_id"]) or not _namespaced(purchase.purchase_id,profile_id,lineage.run_id): return _fail("invalid_purchase_record")
		for field: String in ["purchase_kind","target_id","source_ref"]:
			if not purchase[field] is String: return _fail("invalid_purchase_record")
		for field: String in ["value_before","value_after","cost"]:
			if not Contract._integer(purchase[field],0): return _fail("invalid_purchase_record")
		var preview := Advancement.make_purchase_preview(StringName(purchase.purchase_kind),StringName(purchase.target_id),purchase.value_before,purchase.value_after)
		if not preview.available or preview.cost != purchase.cost or preview.source_ref != purchase.source_ref: return _fail("unsupported_or_inconsistent_purchase")
		var applied := actor.apply_verified_resistance_advancement(String(purchase.target_id),purchase.value_before,purchase.value_after)
		if not applied.success: return _fail("purchase_application_failed")
		purchase_cost += int(purchase.cost)
	if purchase_cost != b.spent: return _fail("purchase_spending_mismatch")
	var expected_level := actor.level
	var seen_growth := {}
	for record: Variant in p.growth:
		if not record is Dictionary or not _keys(record,HISTORY_FIELDS+["growth_id"]) or not _namespaced(record.growth_id,profile_id,lineage.run_id) or seen_growth.has(record.growth_id): return _fail("invalid_growth_record")
		seen_growth[record.growth_id] = true
		for field: String in HISTORY_FIELDS:
			if field != "resource" and typeof(record[field]) != TYPE_INT: return _fail("invalid_growth_number")
		var terms := CharacterLevelProgression.growth_terms(actor)
		var die := int(terms.die)
		var flat := int(terms.flat)
		var resource := String(terms.resource)
		var gain := int(terms.resource_gain)
		if record.prior_level != expected_level or record.level != expected_level+1 or record.threshold != Growth.threshold(policy.exp_type,record.level) or record.hit_die_sides != die or record.die_flat_bonus != flat or record.roll < 1 or record.roll > die or record.hpb != actor.combat_stats.hpb or record.wisdom != actor.attributes.wis: return _fail("growth_source_mismatch")
		if record.hpm_before != actor.get_combat_stat("hpm") or record.hpm_increase != record.roll+flat+record.hpb or record.hpm_after != record.hpm_before+record.hpm_increase or record.resource != resource or record.maximum_before != actor.resource_maxima.get(resource,0) or record.maximum_increase != gain or record.maximum_after != record.maximum_before+gain: return _fail("growth_arithmetic_mismatch")
		actor.progression_hpm_increase += int(record.hpm_increase)
		actor.apply_equipment_stat_modifiers({})
		actor.resource_maxima[resource] = record.maximum_after
		expected_level += 1
	if p.level != expected_level or p.level != Growth.level_for(policy.exp_type,payload.xp.earned) or p.resource_maxima != actor.resource_maxima or p.ability_allowances != actor.ability_allowances: return _fail("level_or_entitlement_mismatch")
	for maximum: Variant in p.resource_maxima.values():
		if not Contract._integer(maximum,0): return _fail("invalid_resource_maximum")
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	var legality := catalog.validate_actor_equipment(actor)
	if not legality.get("success",false): return _fail("equipment_illegal")
	var armor_modifiers := catalog.calculate_armor_stat_modifiers(actor.equipment_refs)
	if not armor_modifiers.get("success",false): return _fail("armor_modifiers_unverified")
	actor.apply_equipment_stat_modifiers(armor_modifiers.modifiers)
	var ownership := _ownership(payload,actor,catalog)
	if not ownership.get("success",false): return ownership
	if payload.has("recovery"):
		var recovery_validation := CharacterWaveCheckpoint.validate(payload.recovery,actor)
		if not recovery_validation.success: return recovery_validation
		var ledger: Dictionary = payload.recovery.ledger
		if ledger.get("mode") != save_namespace or ledger.get("earned_xp") != b.earned or ledger.get("spent_xp") != b.spent or ledger.get("player_level") != p.level: return _fail("recovery_progression_generation_mismatch")
		for award: Dictionary in p.award_receipts:
			var parts: PackedStringArray = String(award.award_id).split("/")
			if parts.size() != 6 or parts[-2] != "defeat": return _fail("recovery_award_identity_unverified")
			var creature := PrimeV3RewardCatalog.creature_id_for_actor(StringName(parts[-1]))
			var expected_xp := int(PrimeV3RewardCatalog.ARENA_XP_OVERRIDES.get(creature,-1)) * (10 if save_namespace == "dev_normal" else 1)
			if award.xp != expected_xp: return _fail("recovery_award_value_unverified")
	# Candidate is permanent-only: deliberately NOT CombatActorState.new(actor),
	# whose constructor would refill HPC/Mana/AP/daily allowances.
	return {"success":true,"actor_definition":actor,"permanent":p.duplicate(true),"xp":payload.xp.duplicate(true),"purchases":payload.purchases.duplicate(true),"items":payload.items.duplicate(true),"hand_occupancy":ownership.hands,"shield_blocks":ownership.shields,"profile_id":profile_id}

static func _ownership(payload: Dictionary, actor: CombatActorDefinition, catalog: CombatDefinitionCatalog) -> Dictionary:
	var quantities := {}
	var equipped := {}
	var shields := {}
	var hands := CombatWeaponHandling.initial_assignments(actor.equipment_refs,catalog,actor)
	if hands.is_empty(): return _fail("hand_assignments_unverified")
	var handling := {}
	if payload.has("equipment_state"):
		hands = payload.equipment_state.hands.duplicate(true)
		handling = payload.equipment_state.handling.duplicate(true)
		if not _keys(hands,["left","right"]): return _fail("invalid_saved_hands")
		for hand: String in hands:
			if not hands[hand] is String or (hands[hand] != "" and not actor.equipment_refs.has(hands[hand])): return _fail("invalid_saved_hands")
		for ref: String in handling:
			if not actor.equipment_refs.has(ref) or catalog.get_weapon(StringName(ref)) == null or handling[ref] not in [CombatWeaponHandling.STOWED,CombatWeaponHandling.ONE_HAND_HOLD]: return _fail("invalid_saved_grip")
		for ref: String in actor.equipment_refs:
			var weapon := catalog.get_weapon(StringName(ref))
			var shield := catalog.get_shield(StringName(ref))
			var count := int(hands.left == ref)+int(hands.right == ref)
			if weapon != null:
				var required := weapon.effective_hands_required(int(actor.attributes.str))
				if handling.get(ref) == CombatWeaponHandling.STOWED:
					if count != 0: return _fail("invalid_saved_grip")
				elif handling.get(ref) == CombatWeaponHandling.ONE_HAND_HOLD:
					if required != 2 or count != 1: return _fail("invalid_saved_grip")
				elif count != required: return _fail("invalid_saved_grip")
			elif shield != null and (count != shield.hand_occupancy or (shield.hand_occupancy == 1 and hands.left != ref)): return _fail("invalid_saved_shield_hand")
	for item: Dictionary in payload.items:
		if not _keys(item,["instance_id","definition_id","quantity","provenance","equipped_slots","mutable_state"]) or not item.provenance.has_all(["origin_id","source_ref"]) or not item.provenance.origin_id is String or item.provenance.origin_id.is_empty() or not item.provenance.source_ref is String or item.provenance.source_ref.is_empty(): return _fail("item_provenance_unverified")
		# No arbitrary nested combat state is admitted into permanent records.
		if not _keys(item.provenance,["origin_id","source_ref"]): return _fail("unsupported_provenance_fields")
		if item.equipped_slots.is_empty():
			if not item.mutable_state.is_empty():
				var carried_shield := catalog.get_shield(StringName(item.definition_id))
				if not payload.has("equipment_state") or carried_shield == null or not _keys(item.mutable_state,["shp","usable"]) or not Contract._integer(item.mutable_state.shp,0) or item.mutable_state.shp > carried_shield.maximum_shp or item.mutable_state.usable != (item.mutable_state.shp > 0): return _fail("carried_item_mutable_state_unmapped")
			quantities[item.definition_id] = int(quantities.get(item.definition_id,0)) + int(item.quantity)
			continue
		var ref := String(item.definition_id)
		if not actor.equipment_refs.has(ref) or equipped.has(ref): return _fail("equipment_ownership_mismatch")
		var slots: Array = []
		var weapon := catalog.get_weapon(StringName(ref))
		var shield := catalog.get_shield(StringName(ref))
		var armor := catalog.get_armor(StringName(ref))
		if weapon != null:
			for hand: String in ["left","right"]:
				if hands[hand] == ref: slots.append(hand)
			if handling.get(ref) == CombatWeaponHandling.STOWED: slots = ["stowed:"+ref]
		elif shield != null:
			slots = ["left"] if shield.hand_occupancy == 1 else ["shield"]
		elif armor != null: slots = ["armor:"+String(armor.armor_slot)]
		else: return _fail("equipped_definition_unavailable")
		var declared: Array = item.equipped_slots.duplicate()
		declared.sort()
		slots.sort()
		if declared != slots: return _fail("equipment_slot_mismatch")
		if shield != null:
			if not _keys(item.mutable_state,["shp","usable"]) or not Contract._integer(item.mutable_state.shp,0) or item.mutable_state.shp > shield.maximum_shp or typeof(item.mutable_state.usable) != TYPE_BOOL or item.mutable_state.usable != (item.mutable_state.shp > 0): return _fail("invalid_shield_damage")
			var block: CombatBlockDefinition = shield.make_block_definition()
			if block == null: return _fail("shield_definition_unverified")
			block.current_shp = int(item.mutable_state.shp)
			block.usable = item.mutable_state.usable
			shields[ref] = block
		elif not item.mutable_state.is_empty(): return _fail("equipment_mutable_state_unmapped")
		equipped[ref] = item.instance_id
	for ref: String in actor.equipment_refs:
		if not equipped.has(ref): return _fail("missing_equipped_instance")
	var expected: Dictionary = payload.permanent.inventory_quantities.duplicate(true)
	for id: Variant in expected.keys():
		if not id is String or id.is_empty(): return _fail("invalid_inventory_identity")
		if not Contract._integer(expected[id],0): return _fail("invalid_inventory_quantity")
		if expected[id] == 0: expected.erase(id)
	if quantities != expected: return _fail("inventory_instance_totals_mismatch")
	return {"success":true,"hands":hands,"shields":shields}

static func fingerprint(value: Variant) -> String:
	return JSON.stringify(value,"",true,true).sha256_text()

static func _namespaced(value: Variant, profile: String, run: String) -> bool:
	return value is String and value.begins_with(profile+"/"+run+"/") and value.length() > profile.length()+run.length()+2

static func _keys(value: Dictionary, keys: Array) -> bool:
	return value.size() == keys.size() and value.has_all(keys)

static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
