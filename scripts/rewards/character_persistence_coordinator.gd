class_name CharacterPersistenceCoordinator
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Receipts = preload("res://scripts/rewards/character_settlement_receipt.gd")
var _storage: CharacterSaveStorage

func _init(storage: CharacterSaveStorage) -> void:
	_storage = storage

# Pure preparation: caller supplies the COMPLETE receipt set, including history.
# Never re-merge rewards on retry; retain and retry this exact prepared request.
static func prepare(payload: Dictionary, settlements: Array, transaction_id: String, expected_generation: int, expected_checkpoints: Array) -> Dictionary:
	if not CharacterSaveStorage._valid_id(transaction_id) or expected_generation < 0: return _result("failure","invalid_transaction_identity")
	var candidate := payload.duplicate(true)
	candidate["settlements"] = settlements.duplicate(true)
	var encoded := Contract.encode(candidate)
	if not encoded.get("success",false): return _result("failure","invalid_contract",encoded)
	if not candidate.has("permanent") or candidate.generation != expected_generation+1: return _result("conflict","unexpected_candidate_generation")
	var validation := _validate_receipts(candidate)
	if not validation.success: return validation
	return {"success":true,"prepared":{
		"transaction_id":transaction_id,"expected_generation":expected_generation,
		"expected_checkpoints":expected_checkpoints.duplicate(),"payload":candidate,"document":encoded.text}}

func commit(prepared: Dictionary, source: CombatCharacterDefinitionResource, profile_id: String, rules_revision: String, verifier: Callable = Callable()) -> Dictionary:
	prepared = prepared.duplicate(true)
	var valid := _authorize(prepared,source,profile_id,rules_revision,verifier)
	if not valid.success: return valid
	if _storage == null: return _result("blocked","storage_unavailable")
	var status := _storage.get_storage_status()
	if not status.success: return _result("blocked",String(status.get("reason","storage_unavailable")),status)
	var inspection := _storage.inspect_profile(profile_id)
	var prior := _find_transaction(prepared,inspection)
	if prior.state != "not_committed": return prior
	if inspection.writer_locked or inspection.pending_write: return _result("blocked","recovery_required",inspection)
	var history: Array = inspection.generations
	var current: Dictionary = {} if history.is_empty() else history.back().payload
	var actual_generation := 0 if current.is_empty() else int(current.generation)
	if prepared.expected_generation != actual_generation: return _result("conflict","stale_generation")
	var checkpoints: Array = [] if current.is_empty() else current.secured_checkpoints
	if prepared.expected_checkpoints != checkpoints: return _result("conflict","checkpoint_comparison_failed")
	if not current.is_empty():
		var replacement := Contract.validate_replacement(current,prepared.payload)
		if not replacement.success: return _result("conflict",String(replacement.get("reason","invalid_replacement")),replacement)
		var continuity := _validate_continuity(current,prepared.payload)
		if not continuity.success: return continuity
	var new_items := _validate_new_items(current,prepared.payload)
	if not new_items.success: return new_items
	var written := _storage.write_profile(profile_id,prepared.payload,prepared.transaction_id)
	# Even a reported success is not acknowledged until exact readback. A lost
	# acknowledgement can be reconciled without issuing a second write.
	var after := _storage.inspect_profile(profile_id)
	var reconciled := _find_transaction(prepared,after)
	if reconciled.success:
		reconciled["reconciled"] = not written.get("success",false)
		reconciled["storage_result"] = written
		return reconciled
	if reconciled.state != "not_committed": return reconciled
	if written.get("success",false): return _result("uncertain","acknowledged_generation_not_verified",after)
	return _result("blocked" if not after.get("pending_write",false) else "uncertain",String(written.get("reason","write_not_verified")),{"storage":written,"inspection":after})

func reconcile(prepared: Dictionary, source: CombatCharacterDefinitionResource, profile_id: String, rules_revision: String, verifier: Callable = Callable()) -> Dictionary:
	prepared = prepared.duplicate(true)
	var valid := _authorize(prepared,source,profile_id,rules_revision,verifier)
	if not valid.success: return valid
	if _storage == null: return _result("blocked","storage_unavailable")
	var status := _storage.get_storage_status()
	if not status.success: return _result("blocked",String(status.get("reason","storage_unavailable")),status)
	var inspection := _storage.inspect_profile(profile_id)
	var result := _find_transaction(prepared,inspection)
	if result.state == "not_committed" and (inspection.writer_locked or inspection.pending_write): return _result("uncertain","unpublished_write_or_lock_requires_review",inspection)
	return result

static func _authorize(prepared: Dictionary, source: CombatCharacterDefinitionResource, profile_id: String, rules_revision: String, verifier: Callable) -> Dictionary:
	var keys := ["transaction_id","expected_generation","expected_checkpoints","payload","document"]
	if prepared.size() != keys.size() or not prepared.has_all(keys) or not prepared.payload is Dictionary or not prepared.expected_checkpoints is Array or not prepared.transaction_id is String or typeof(prepared.expected_generation) != TYPE_INT: return _result("failure","invalid_prepared_request")
	if not CharacterSaveStorage._valid_id(prepared.transaction_id) or prepared.expected_generation < 0 or prepared.payload.get("generation") != prepared.expected_generation+1: return _result("failure","invalid_prepared_generation")
	var encoded := Contract.encode(prepared.payload)
	if not encoded.get("success",false) or encoded.get("text") != prepared.document: return _result("failure","prepared_payload_changed")
	if not verifier.is_valid(): return _result("blocked","trusted_authority_unavailable")
	var checked_verifier := func(operation: String, binding: String) -> Dictionary:
		var response: Variant = verifier.call(operation,binding)
		return response if response is Dictionary else {"authorized":false}
	var authority: Dictionary = checked_verifier.call("commit",Profiles.fingerprint(prepared))
	if not authority.get("authorized",false) or authority.get("binding") != Profiles.fingerprint(prepared): return _result("blocked","transaction_authority_rejected")
	var candidate := Profiles.hydrate(prepared.payload,source,profile_id,rules_revision,checked_verifier)
	if not candidate.get("success",false): return _result("blocked",String(candidate.get("reason","invalid_candidate")),candidate)
	return _validate_receipts(prepared.payload)

static func _find_transaction(prepared: Dictionary, inspection: Dictionary) -> Dictionary:
	if not inspection.get("success",false):
		for rejected: Dictionary in inspection.get("rejected_files",[]):
			if rejected.get("reason") in ["unsupported_format_or_version","unsupported_storage_version"]: return _result("blocked",rejected.reason,inspection)
		return _result("uncertain","generation_recovery_required",inspection)
	var records: Array = inspection.generations
	var latest := 0 if records.is_empty() else int(records.back().payload.generation)
	for record: Dictionary in records:
		if record.transaction_id == prepared.transaction_id:
			if record.document != prepared.document: return _result("conflict","transaction_payload_conflict")
			return {"success":true,"state":"committed","generation":int(record.payload.generation),"latest_generation":latest,
				"transaction_id":prepared.transaction_id,"reconciled":true,"recovery_required":inspection.writer_locked or inspection.pending_write,
				"durable_power_loss_guaranteed":false}
	for record: Dictionary in records:
		if int(record.payload.generation) == int(prepared.payload.generation): return _result("conflict","generation_occupied_by_other_transaction")
	return _result("not_committed","transaction_not_found")

static func _validate_receipts(payload: Dictionary) -> Dictionary:
	if not payload.get("settlements") is Array: return _result("failure","settlement_set_required")
	if not payload.get("permanent") is Dictionary or not payload.permanent.get("award_receipts") is Array or not payload.get("lineage") is Dictionary or not payload.lineage.get("run_id") is String: return _result("failure","incomplete_permanent_profile")
	var ids := {}
	var effects := {}
	var awards := {}
	var purchases := {}
	var origins := {}
	for receipt: Variant in payload.settlements:
		if not receipt is Dictionary: return _result("failure","invalid_settlement")
		var validation := Receipts.validate(receipt)
		if not validation.success: return _result("failure",validation.reason)
		if receipt.profile_id != payload.character_id: return _result("blocked","settlement_lineage_mismatch")
		if receipt.run_id != payload.lineage.run_id:
			if not payload.get("run_history",[]).has(receipt.run_id): return _result("blocked","settlement_lineage_mismatch")
			var content_id: String = receipt.content.get("award_id",receipt.content.get("purchase_id",receipt.content.get("instance_id","")))
			var prefix := "%s/%s/%s/" % [payload.character_id,receipt.run_id,receipt.wave_id]
			if receipt.kind in ["xp","purchase"]: prefix = "%s/%s/" % [payload.character_id,payload.lineage.run_id] + "%s/%s/" % [receipt.run_id,receipt.wave_id]
			if not content_id.begins_with(prefix): return _result("blocked","settlement_run_or_wave_mismatch")
		var effect := Receipts.effect_id(receipt)
		if ids.has(receipt.receipt_id) or effects.has(effect): return _result("conflict","duplicate_settlement_or_effect")
		ids[receipt.receipt_id] = receipt
		effects[effect] = receipt
		if receipt.kind in ["item","currency"]:
			if origins.has(receipt.content.provenance_digest): return _result("conflict","duplicate_acquisition_origin")
			origins[receipt.content.provenance_digest] = true
		if receipt.kind == "xp": awards[receipt.content.award_id] = receipt.content.amount
		elif receipt.kind == "purchase": purchases[receipt.content.purchase_id] = receipt.content.cost
	for award: Variant in payload.permanent.award_receipts:
		if not award is Dictionary or not award.has_all(["award_id","xp"]): return _result("failure","invalid_award_receipt")
		if awards.get(award.award_id) != award.xp: return _result("blocked","xp_settlement_missing_or_mismatched")
	for purchase: Dictionary in payload.purchases:
		if not purchase.has_all(["purchase_id","cost"]): return _result("failure","invalid_purchase_receipt")
		if purchases.get(purchase.purchase_id) != purchase.cost: return _result("blocked","purchase_settlement_missing_or_mismatched")
	if awards.size() != payload.permanent.award_receipts.size() or purchases.size() != payload.purchases.size(): return _result("blocked","unrepresented_reward_settlement")
	return {"success":true}

static func _validate_continuity(current: Dictionary, candidate: Dictionary) -> Dictionary:
	if not current.has("settlements"): return _result("blocked","legacy_settlement_history_unavailable")
	for receipt: Dictionary in current.settlements:
		if not candidate.settlements.has(receipt): return _result("conflict","settlement_history_changed")
	for key: String in ["purchases"]:
		if candidate[key].slice(0,current[key].size()) != current[key]: return _result("conflict","purchase_history_changed")
	for key: String in ["growth","award_receipts"]:
		if candidate.permanent[key].slice(0,current.permanent[key].size()) != current.permanent[key]: return _result("conflict","progression_history_changed")
	if candidate.xp.earned < current.xp.earned or candidate.xp.spent < current.xp.spent: return _result("conflict","progression_rollback")
	return {"success":true}

static func _validate_new_items(current: Dictionary, candidate: Dictionary) -> Dictionary:
	var old_ids := {}
	for receipt: Dictionary in current.get("settlements",[]): old_ids[receipt.receipt_id] = true
	var previous_items := {}
	for item: Dictionary in current.get("items",[]): previous_items[item.instance_id] = item
	var acquisitions := {}
	for receipt: Dictionary in candidate.settlements:
		if receipt.kind in ["item","currency"]: acquisitions[receipt.content.instance_id] = receipt
	for item: Dictionary in candidate.items:
		var acquisition: Dictionary = acquisitions.get(item.instance_id,{})
		if acquisition.is_empty(): return _result("blocked","item_acquisition_receipt_required")
		if item.definition_id != acquisition.content.definition_id or item.quantity > acquisition.content.quantity or Profiles.fingerprint(item.provenance) != acquisition.content.provenance_digest: return _result("blocked","item_settlement_ownership_mismatch")
		if previous_items.has(item.instance_id):
			var previous: Dictionary = previous_items[item.instance_id]
			if item.quantity > previous.quantity: return _result("conflict","item_quantity_increase_requires_distinct_acquisition")
			if previous.mutable_state.has("shp") and item.mutable_state.get("shp",0) > previous.mutable_state.shp: return _result("blocked","equipment_repair_requires_verified_transaction")
		elif old_ids.has(acquisition.receipt_id): return _result("conflict","settled_item_cannot_be_reintroduced")
	return {"success":true}

static func _result(state: String, reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"state":state,"reason":reason,"details":details}
