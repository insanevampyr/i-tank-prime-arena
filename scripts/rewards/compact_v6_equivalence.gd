extends RefCounted

# Independent read-only comparison. The expected head/actor/proof come from the
# legacy validation walk, never from the converted record or its packer.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")

static func compare(record: Dictionary, original: Dictionary, actor: CombatActorDefinition, end_proof: Dictionary, source: CombatCharacterDefinitionResource, rows: Array) -> Dictionary:
	var checked := V6.validate(record,source)
	if not checked.success: return _fail("compact_validation_failed",checked)
	var restored := V6._projection(record)
	# Whole-head equality catches omissions as well as renamed/recalculated
	# values: checkpoints, RNG, movement, fatigue, timers and resource remainders.
	if restored != original:
		var fields: Array = []
		for key: Variant in original:
			if not restored.has(key) or restored[key] != original[key]: fields.append(key)
		return _fail("legacy_projection_mismatch",{"fields":fields})
	if actor == null or checked.actor.to_dictionary() != actor.to_dictionary(): return _fail("permanent_or_equipment_adjusted_actor_mismatch")
	var expected_growth := {}
	for row: Dictionary in original.permanent.growth:
		if end_proof.is_empty():
			expected_growth[row.growth_id] = {"end":source.attributes.end,"hpb":row.hpb,"record_digest":V6.digest(row)}
		else:
			if not end_proof.get("growth",{}).has(row.growth_id): return _fail("legacy_end_witness_missing")
			expected_growth[row.growth_id] = end_proof.growth[row.growth_id]
	if checked.end_growth != expected_growth: return _fail("event_time_end_witness_mismatch")
	var required := {}
	for row: Dictionary in rows:
		var operation := {"id":row.transaction_id,"request_digest":row.document.sha256_text(),"binding_kind":"legacy_document"}
		required[JSON.stringify(["operation",row.transaction_id])] = V6.digest(operation)
	for group: Array in [["award",original.permanent.award_receipts,"award_id"],["purchase",original.purchases,"purchase_id"],["growth",original.permanent.growth,"growth_id"],["settlement",original.settlements,"receipt_id"]]:
		for row: Dictionary in group[1]: required[JSON.stringify([group[0],row[group[2]]])] = V6.digest(row)
	for receipt: Dictionary in original.settlements:
		if receipt.kind in ["item","currency"]: required[JSON.stringify(["item_origin",receipt.content.instance_id])] = V6.digest(receipt)
	for row: Dictionary in original.get("expc_credits",{}).get("records",[]): required[JSON.stringify(["credit",row.grant_id])] = V6.digest(row)
	for command: Dictionary in original.permanent.get("development",{}).get("commands",[]): required[JSON.stringify(["development",command.id])] = V6.digest(command)
	for run: String in original.get("run_history",[]): required[JSON.stringify(["run",run])] = V6.digest(run)
	var actual := {}
	for row: Dictionary in record.applied_ids: actual[JSON.stringify([row.scope,row.id])] = row.record_digest
	if actual != required: return _fail("lifetime_identity_or_provenance_mismatch")
	return {"success":true,"matched":["original_attributes","permanent_and_equipment_adjusted_actor","level_and_xp","purchases_and_credit","hpm_hpc_mana_ap_and_original_growth","items_ownership_slots_and_condition","run_policy_wave_checkpoint_rng_movement_and_timers","lifetime_ids_and_reward_provenance"],"original_projection_digest":V6.digest(original)}

static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
