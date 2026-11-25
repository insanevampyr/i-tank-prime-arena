class_name EnduranceGrowthHistory
extends RefCounted

# Transient evidence produced ONLY from already verified generation predecessors.
# No save fields, storage authority, timestamps or inferred plateau ordering.
const Rules = preload("res://scripts/combat/prime_v3_attribute_engine.gd")

static func digest(value: Dictionary) -> String:
	return JSON.stringify(value,"",true,true).sha256_text()

static func has_purchases(payload: Dictionary) -> bool:
	for row: Variant in payload.get("purchases",[]):
		if row is Dictionary and row.get("purchase_kind") == "attribute" and row.get("target_id") == "end": return true
	return false

static func resolve(source: CombatCharacterDefinitionResource, payload: Dictionary, evidence: Dictionary) -> Dictionary:
	if source == null or not evidence.get("endurance_history",{}) is Dictionary or not evidence.get("previous_payload",{}) is Dictionary: return fail("end_history_evidence_malformed")
	var proof: Dictionary = evidence.get("endurance_history",{})
	if proof.get("head_digest") == digest(payload):
		if proof.get("success") != true or not proof.get("growth") is Dictionary or typeof(proof.get("end")) != TYPE_INT or proof.get("source_digest") != digest(source.to_dictionary()) or proof.get("generation") != payload.get("generation"): return fail("end_history_binding_mismatch")
		return proof
	var previous: Dictionary = evidence.get("previous_payload",{})
	if previous.is_empty(): return fail("end_generation_history_unavailable")
	return extend(source,payload,previous,proof)

static func extend(source: CombatCharacterDefinitionResource, payload: Dictionary, previous: Dictionary, proof: Dictionary = {}) -> Dictionary:
	if source == null or not payload.get("permanent") is Dictionary or not previous.get("permanent") is Dictionary: return fail("end_generation_history_unavailable")
	if typeof(payload.get("generation")) != TYPE_INT or typeof(previous.get("generation")) != TYPE_INT or payload.generation != previous.generation+1: return fail("end_history_generation_discontinuity")
	for field: String in ["character_id","definition_id","rules_revision","base_attributes","lineage","profile_namespace"]:
		if payload.get(field) != previous.get(field): return fail("end_history_identity_changed")
	var old: Variant = previous.permanent.get("growth")
	var records: Variant = payload.permanent.get("growth")
	if not old is Array or not records is Array or not previous.get("purchases") is Array or not payload.get("purchases") is Array: return fail("end_history_incomplete")
	if records.slice(0,old.size()) != old or payload.purchases.slice(0,previous.purchases.size()) != previous.purchases: return fail("end_history_prefix_changed")
	var start: Variant = source.attributes.get("end")
	var starting_hpb: Variant = source.combat_stats.get("hpb")
	if typeof(start) != TYPE_INT or typeof(starting_hpb) != TYPE_INT: return fail("end_history_source_unavailable")
	var verified := {}
	if has_purchases(previous):
		if proof.get("head_digest") != digest(previous) or proof.get("source_digest") != digest(source.to_dictionary()) or not proof.get("growth") is Dictionary: return fail("end_history_predecessor_unverified")
		verified = proof.growth.duplicate(true)
	else:
		# A verified legacy head has never changed END. Preserve its authored HPB,
		# rather than manufacturing old END purchases or rerolling creation HD.
		for row: Variant in old:
			if not row is Dictionary or not row.get("growth_id") is String or row.get("hpb") != starting_hpb or verified.has(row.growth_id): return fail("end_legacy_growth_source_mismatch")
			verified[row.growth_id] = {"end":start,"hpb":starting_hpb,"record_digest":digest(row)}
	var score: int = start
	var old_count := 0
	var count := 0
	for index in range(payload.purchases.size()):
		var step: Variant = payload.purchases[index]
		if not step is Dictionary: return fail("invalid_end_history_purchase")
		if step.get("purchase_kind") != "attribute" or step.get("target_id") != "end": continue
		if typeof(step.get("value_before")) != TYPE_INT or typeof(step.get("value_after")) != TYPE_INT or step.value_before != score or score < 1 or step.value_after != score+1 or step.value_after > 20: return fail("end_purchase_history_discontinuity")
		if step.get("cost") != PrimeV3AdvancementCatalog.attribute_cost(score) or step.get("source_ref") != PrimeV3AdvancementCatalog.PURCHASE_SOURCE_REF: return fail("end_purchase_history_price_mismatch")
		score += 1
		count += 1
		if index < previous.purchases.size(): old_count += 1
	if count == 0: return fail("end_history_purchase_missing")
	var baseline := Rules.lookup("END",start,"mana")
	for pair: Array in [["nal","NAL"],["physical_soak","PS"],["hpb","HPB"]]:
		if not baseline.success or baseline.outcome != "values" or source.combat_stats.get(pair[0]) != baseline.values[pair[1]].get("value"): return fail("end_authored_derived_exception_unsupported")
	# Existing safe management publishes END purchases separately from earned
	# growth. Do not guess an order if a supplied generation coalesces the two.
	if count > old_count and records.size() != old.size(): return fail("end_purchase_growth_same_generation_ambiguous")
	var expected: int = Rules.lookup("END",score,"mana").values.HPB.value
	for index in range(records.size()):
		var row: Variant = records[index]
		if not row is Dictionary or not row.get("growth_id") is String: return fail("invalid_end_growth_record")
		if index < old.size():
			if not verified.has(row.growth_id) or verified[row.growth_id].get("record_digest") != digest(row): return fail("end_growth_evidence_missing")
		else:
			if verified.has(row.growth_id) or row.get("hpb") != expected: return fail("end_event_time_hpb_mismatch")
			verified[row.growth_id] = {"end":score,"hpb":expected,"record_digest":digest(row)}
	return {"success":true,"source_digest":digest(source.to_dictionary()),"head_digest":digest(payload),"generation":payload.generation,"end":score,"growth":verified}

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
