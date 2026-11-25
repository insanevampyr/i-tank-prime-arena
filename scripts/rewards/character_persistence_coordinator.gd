class_name CharacterPersistenceCoordinator
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Receipts = preload("res://scripts/rewards/character_settlement_receipt.gd")
var _storage: CharacterSaveStorage
var _compact_pending: RefCounted
var _compact_adapter: RefCounted
var _compact_handle: RefCounted
var _compact_route: RefCounted
var _minimal_owner: RefCounted
var _temporary_owner: RefCounted

# Dormant disposable prototype only. Existing prepare/commit/reconcile and all
# production storage paths below remain unchanged.
func admit_minimal_snapshot(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String, root: String, version: int = 1, player_factory: Callable = Callable()) -> Dictionary:
	if _minimal_owner != null: return _result("blocked","minimal_character_already_admitted")
	if _temporary_owner != null: return _result("blocked","temporary_character_already_admitted")
	var owner: RefCounted = load("res://scripts/rewards/minimal_character_transactions.gd").new()
	var opened: Dictionary = owner.admit(text,source,profile,scope,root,version,player_factory)
	if not opened.success:
		owner.dispose()
		return opened
	_minimal_owner = owner
	return opened

func admit_minimal_snapshot_v3(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String, root: String, player_factory: Callable = Callable()) -> Dictionary:
	return admit_minimal_snapshot(text,source,profile,scope,root,3,player_factory)

func minimal_view() -> Dictionary:
	return _minimal_owner.view() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

# Disposable 46I only. No legacy/playable dispatcher selects this transport.
func attach_minimal_windows(path: String, executable: String, sha256: String) -> Dictionary:
	return _minimal_owner.attach_windows(path,executable,sha256) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func publish_minimal_windows() -> Dictionary:
	return _minimal_owner.publish_windows() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func automatic_minimal_windows(enabled: bool) -> Dictionary:
	return _minimal_owner.automatic_windows(enabled) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

# Disposable 46J only. Existing owner, no production browser dispatcher.
func attach_minimal_browser(route: RefCounted) -> Dictionary:
	return _minimal_owner.attach_browser(route) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func begin_minimal_browser() -> Dictionary:
	return _minimal_owner.begin_browser() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func poll_minimal_browser() -> Dictionary:
	return _minimal_owner.poll_browser() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func cancel_minimal_browser() -> Dictionary:
	return _minimal_owner.cancel_browser() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func automatic_minimal_browser(enabled: bool) -> Dictionary:
	return _minimal_owner.automatic_browser(enabled) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func next_minimal_browser_wave() -> Dictionary:
	return _minimal_owner.next_browser_wave() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func prepare_minimal_fixed_credit(confirmation: Callable) -> Dictionary:
	return _minimal_owner.fixed_credit(confirmation) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func prepare_minimal_new_run(multiplier: int, confirmation: Callable) -> Dictionary:
	return _minimal_owner.new_run(multiplier,confirmation) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func prepare_minimal_snapshot(operation: Variant, revision: Variant) -> Dictionary:
	return _minimal_owner.prepare(operation,revision) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func simulate_minimal_acknowledgement(text: String) -> Dictionary:
	return _minimal_owner.simulate_ack(text) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func simulate_minimal_unknown_outcome() -> Dictionary:
	return _minimal_owner.simulate_unknown() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func simulate_minimal_automatic_checkpoints(enabled: bool) -> Dictionary:
	return _minimal_owner.simulate_automatic(enabled) if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func cancel_minimal_snapshot() -> Dictionary:
	return _minimal_owner.cancel() if _minimal_owner != null else _result("blocked","minimal_character_not_admitted")

func close_minimal_prototype() -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	if _minimal_owner != null:
		var disposed: Dictionary = _minimal_owner.dispose()
		if not disposed.success: return
	_minimal_owner = null

# Dormant 46F request ownership only. No existing writer calls this API.
func bind_temporary_requests(session: ArenaCombatSession, player: Node, text: String) -> Dictionary:
	if _minimal_owner != null: return _result("blocked","minimal_character_already_admitted")
	if _temporary_owner != null: return _result("blocked","temporary_already_admitted")
	var owner: RefCounted = load("res://scripts/rewards/temporary_character_requests.gd").new()
	var result: Dictionary = owner.admit(session,player,text)
	if result.success: _temporary_owner = owner
	return result

func temporary_context() -> RefCounted:
	if _minimal_owner != null: return _minimal_owner.request_context()
	return _temporary_owner.current() if _temporary_owner != null else null

func issue_temporary_request(context: RefCounted, kind: String, definition: String, operation: String, request_id: String) -> Dictionary:
	if _minimal_owner != null: return _minimal_owner.issue_item(context,kind,definition,operation,request_id)
	return _temporary_owner.issue(context,kind,definition,operation,request_id) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func execute_temporary_request(request: RefCounted) -> Dictionary:
	if _minimal_owner != null: return _minimal_owner.execute_item(request)
	return _temporary_owner.execute(request) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func cancel_temporary_request(request: RefCounted) -> Dictionary:
	if _minimal_owner != null: return _minimal_owner.cancel_item(request)
	return _temporary_owner.cancel_request(request) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func capture_temporary_checkpoint(phase: String, operation_id: String) -> Dictionary:
	return _temporary_owner.capture(phase,operation_id) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func simulate_temporary_unknown(capture: RefCounted) -> Dictionary:
	return _temporary_owner.unknown(capture) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func simulate_temporary_ack(capture: RefCounted, text: String) -> Dictionary:
	return _temporary_owner.acknowledge(capture,text) if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func cancel_temporary_checkpoint() -> Dictionary:
	return _temporary_owner.cancel_capture() if _temporary_owner != null else _result("blocked","temporary_not_admitted")

func close_temporary_requests() -> Dictionary:
	if _minimal_owner != null: return _result("blocked","close_minimal_owner_required")
	if _temporary_owner == null: return _result("blocked","temporary_not_admitted")
	var result: Dictionary = _temporary_owner.close()
	if result.success: _temporary_owner = null
	return result

func temporary_request_status() -> Dictionary:
	return _temporary_owner.status() if _temporary_owner != null else {"closed":true,"durable":false}

class CompactPrepared extends RefCounted:
	var _bytes := "":
		set(value):
			if _bytes.is_empty(): _bytes = value
	func _init(value: Dictionary) -> void: _bytes = JSON.stringify(value,"",true,true)
	func copy() -> Dictionary: return CharacterSaveContract._normalize_json_numbers(JSON.parse_string(_bytes))
	func bytes() -> String: return _bytes

# Dormant S4 only. The explicitly cache-gated route is never selected by commit().
func prepare_compact(route: RefCounted, adapter: RefCounted, candidate: RefCounted, expected: Variant) -> Dictionary:
	var started := Time.get_ticks_usec()
	if route == null or not is_instance_of(route,load("res://scripts/rewards/compact_v6_windows_storage.gd")) or not route.valid_context() or adapter == null or candidate == null or route.guard != _storage: return _result("blocked","compact_context_required")
	var adapter_type: GDScript = load("res://scripts/rewards/compact_v6_gameplay_candidate.gd")
	if not is_instance_of(adapter,adapter_type) or not is_instance_of(candidate,adapter_type.Prepared): return _result("blocked","compact_owned_candidate_required")
	if _compact_pending != null:
		return {"success":true,"prepared":_compact_pending,"exact_retry":true} if route == _compact_route and adapter == _compact_adapter and candidate == _compact_handle and _compact_pending.copy().expected == expected else _result("blocked","compact_operation_in_flight")
	var request: Dictionary = adapter.publication_request(candidate)
	if not request.success: return request
	if request.source != route.source or request.profile != route.profile or request.namespace != route.scope: return _result("blocked","compact_identity_mismatch")
	var checked := _authorize(request.proposal,request.source,request.profile,request.rules,request.verifier)
	if not checked.success: return checked
	var v6: GDScript = load("res://scripts/rewards/compact_character_v6_prototype.gd")
	var portable: GDScript = load("res://scripts/rewards/compact_v6_portable.gd")
	var windows: GDScript = load("res://scripts/rewards/compact_v6_windows_storage.gd")
	var before: Dictionary = route.load_current()
	var history: Array = []
	var legacy := {"count":0,"digest":v6.digest([])}
	var record: Dictionary = v6.decode(request.candidate_text,request.source)
	if not record.success: return record
	if v6._projection(record.record) != Contract.decode(request.proposal.document).payload: return _result("blocked","compact_projection_mismatch")
	if before.get("empty",false) or (not before.success and before.reason == "compact_route_missing"):
		var inspection := _storage.inspect_profile(request.profile)
		if not inspection.success or inspection.writer_locked or inspection.pending_write or not inspection.generations.is_empty() or request.logical_parent.format != 0 or expected != null or record.record.head.sequence != 1: return _result("blocked","compact_initial_boundary_invalid")
	else:
		if not before.success or before.exact_recovery_needed or windows.token(before) != expected: return _result("conflict","stale_compact_storage_head")
		if request.logical_parent != {"format":6,"epoch":before.record.head.epoch,"sequence":before.record.head.sequence,"digest":v6.digest(before.record)}: return _result("conflict","compact_logical_parent_mismatch")
		var step: Dictionary = portable.transition(before.record,record.record,request.source)
		if not step.success: return step
		history = before.history.duplicate(true); history.append(step.transition)
	var packed: Dictionary = portable.export_record(request.candidate_text,history,request.source)
	if not packed.success: return packed
	_compact_adapter = adapter; _compact_handle = candidate; _compact_route = route
	_compact_pending = CompactPrepared.new({"expected":expected,"logical_parent":request.logical_parent,"source_digest":v6.digest(request.source.to_dictionary()),"identity":{"profile":request.profile,"namespace":request.namespace,"rules":request.rules},"request_digest":v6.digest(request.proposal),"adapter_digest":request.adapter_digest,"text":request.candidate_text,"capsule":packed.text,"capsule_digest":packed.text.sha256_text(),"legacy":legacy})
	return {"success":true,"prepared":_compact_pending,"prepare_ms":float(Time.get_ticks_usec()-started)/1000.0}

func commit_compact(prepared: RefCounted) -> Dictionary:
	var started := Time.get_ticks_usec()
	if prepared == null or prepared != _compact_pending or _compact_route == null: return _result("blocked","foreign_compact_prepared_operation")
	var route: RefCounted = _compact_route
	var owned: Dictionary = route.acquire()
	if not owned.success: return owned
	var result := _commit_compact_owned(prepared,owned.owner)
	var released: Dictionary = route.release(owned.owner)
	if not released.success: return _result("uncertain","compact_writer_release_failed",released)
	result["commit_ms"] = float(Time.get_ticks_usec()-started)/1000.0
	return result

func _commit_compact_owned(prepared: RefCounted, owner: String) -> Dictionary:
	var request: Dictionary = _compact_adapter.publication_request(_compact_handle)
	if not request.success: return request
	var v6: GDScript = load("res://scripts/rewards/compact_character_v6_prototype.gd")
	var windows: GDScript = load("res://scripts/rewards/compact_v6_windows_storage.gd")
	var body: Dictionary = prepared.copy()
	if v6.digest(request.proposal) != body.request_digest or request.adapter_digest != body.adapter_digest or request.candidate_text != body.text or v6.digest(request.source.to_dictionary()) != body.source_digest or request.logical_parent != body.logical_parent: return _result("blocked","compact_request_changed")
	var authority := _authorize(request.proposal,request.source,request.profile,request.rules,request.verifier)
	if not authority.success: return authority
	var before: Dictionary = _compact_route.load_current()
	var identical: bool = before.get("success",false) and before.get("text") == body.text
	if not identical:
		if body.expected == null:
			var inspection: Dictionary = _compact_route.legacy_owned(owner)
			if not inspection.success or inspection.pending_write or not inspection.generations.is_empty(): return _result("conflict","compact_activation_source_changed")
		else:
			if not before.success or windows.token(before) != body.expected or before.exact_recovery_needed: return _result("conflict","stale_compact_storage_head")
			var previous: Dictionary = v6._projection(before.record)
			if request.proposal.expected_generation != previous.generation or request.proposal.expected_checkpoints != previous.secured_checkpoints: return _result("conflict","compact_checkpoint_comparison_failed")
			for proof: Dictionary in [_validate_continuity(previous,request.proposal.payload),_validate_new_items(previous,request.proposal.payload)]:
				if not proof.success: return proof
		var written: Dictionary = _compact_route.install(body.text,body.capsule,body.expected,body.legacy,owner)
		# A reported failure may be a lost acknowledgement: exact readback decides.
		var readback: Dictionary = _compact_route.load_current()
		if not readback.get("success",false) or readback.get("text") != body.text: return _result("uncertain","compact_publication_unverified",written)
	before = _compact_route.load_current()
	if not before.success or before.exact_recovery_needed or before.text != body.text or before.capsule_text != body.capsule: return _result("uncertain","compact_readback_mismatch")
	var final: Dictionary = _compact_route.finalize(owner,before)
	if not final.success: return final
	return {"success":true,"state":"committed","format":6,"generation":request.proposal.payload.generation,"latest_generation":request.proposal.payload.generation,"transaction_id":request.proposal.transaction_id,"request_digest":body.request_digest,"candidate_digest":body.text.sha256_text(),"route_digest":before.route_digest,"head":before.head,"already_applied":identical,"durable_power_loss_guaranteed":false}

func finish_compact(prepared: RefCounted) -> bool:
	if prepared != _compact_pending: return false
	_compact_pending = null; _compact_route = null; _compact_adapter = null; _compact_handle = null
	return true

# Explicit, dormant conversion admission. No mutation is authorized by a hash:
# complete source history and independent conversion equivalence run under lease.
func activate_compact(route: RefCounted, confirmation: Callable) -> Dictionary:
	if route == null or not is_instance_of(route,load("res://scripts/rewards/compact_v6_windows_storage.gd")) or not route.valid_context() or route.guard != _storage or not confirmation.is_valid(): return _result("blocked","compact_activation_confirmation_required")
	var lease: Dictionary = route.acquire()
	if not lease.success: return lease
	var result := _activate_compact_owned(route,confirmation,lease.owner)
	var released: Dictionary = route.release(lease.owner)
	if not released.success: return _result("uncertain","compact_activation_release_failed",released)
	return result

func _activate_compact_owned(route: RefCounted, confirmation: Callable, owner: String) -> Dictionary:
	var v6: GDScript = load("res://scripts/rewards/compact_character_v6_prototype.gd")
	var current: Dictionary = route.load_current()
	if current.get("success",false) and not current.get("empty",false): return _result("blocked","compact_already_active")
	if route._fence().success: return _result("blocked","compact_activation_recovery_required")
	var inspection: Dictionary = route.legacy_owned(owner)
	if not inspection.success or inspection.pending_write or inspection.generations.is_empty(): return _result("blocked","verified_legacy_source_required")
	var rows := CharacterSaveStorage.history_records(inspection)
	var converted: Dictionary = load("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(rows,route.scope)
	if not converted.success: return converted
	if converted.record.source_digest != v6.digest(route.source.to_dictionary()) or converted.record.current.character_id != route.profile: return _result("blocked","compact_activation_source_mismatch")
	var legacy := {"count":rows.size(),"digest":v6.digest(rows)}
	var quote := {"kind":"explicit_compact_activation","profile":route.profile,"namespace":route.scope,"source_digest":converted.record.source_digest,"legacy":legacy,"candidate_digest":converted.text.sha256_text()}
	var consent: Variant = confirmation.call(quote.duplicate(true))
	if not consent is Dictionary or consent.get("confirmed") != true or consent.get("binding") != v6.digest(quote): return _result("blocked","compact_activation_confirmation_required")
	var fresh: Dictionary = route.legacy_owned(owner)
	if not fresh.success or fresh.pending_write or CharacterSaveStorage.history_records(fresh) != rows: return _result("conflict","compact_activation_source_changed")
	var portable: Dictionary = load("res://scripts/rewards/compact_v6_portable.gd").export_record(converted.text,[],route.source)
	if not portable.success: return portable
	var written: Dictionary = route.install(converted.text,portable.text,null,legacy,owner)
	var loaded: Dictionary = route.load_current()
	if not loaded.success or loaded.text != converted.text or loaded.exact_recovery_needed: return _result("uncertain","compact_activation_unverified",written)
	var finalized: Dictionary = route.finalize(owner,loaded)
	if not finalized.success: return finalized
	return loaded.merged({"format":6,"activated":true,"legacy_generations_unchanged":rows.size()})

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
	var multipliers := {}
	if payload.has("run_reward_policy"):
		if not payload.has("recovery"): return _result("blocked", "verified_run_boundary_required")
		if payload.generation == 1 and (payload.recovery.phase != "entry" or payload.recovery.wave_id != "wave_1" or not payload.permanent.award_receipts.is_empty()):
			return _result("blocked", "run_reward_policy_requires_new_wave_one_entry")
		multipliers = Profiles.run_xp_multipliers(payload)
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
		if receipt.kind == "xp": awards[receipt.content.award_id] = receipt
		elif receipt.kind == "purchase": purchases[receipt.content.purchase_id] = receipt.content.cost
	for award: Variant in payload.permanent.award_receipts:
		if not award is Dictionary or not award.has_all(["award_id","xp"]): return _result("failure","invalid_award_receipt")
		var settlement: Dictionary = awards.get(award.award_id, {})
		if settlement.get("content", {}).get("amount") != award.xp: return _result("blocked","xp_settlement_missing_or_mismatched")
		if not multipliers.is_empty():
			var verified := Profiles.validate_playable_xp_award(payload, award, multipliers)
			if not verified.success: return _result("blocked", verified.reason)
			if settlement.run_id != verified.run_id or settlement.wave_id != verified.wave_id:
				return _result("blocked", "xp_settlement_run_or_wave_mismatch")
	for purchase: Dictionary in payload.purchases:
		if not purchase.has_all(["purchase_id","cost"]): return _result("failure","invalid_purchase_receipt")
		if purchases.get(purchase.purchase_id) != purchase.cost: return _result("blocked","purchase_settlement_missing_or_mismatched")
	if awards.size() != payload.permanent.award_receipts.size() or purchases.size() != payload.purchases.size(): return _result("blocked","unrepresented_reward_settlement")
	return {"success":true}

static func _validate_continuity(current: Dictionary, candidate: Dictionary) -> Dictionary:
	var old_development: Dictionary = current.get("permanent",{}).get("development",{})
	var new_development: Dictionary = candidate.get("permanent",{}).get("development",{})
	if not old_development.is_empty() or not new_development.is_empty():
		if not CharacterDevelopment.continuity(old_development,new_development): return _result("conflict","development_history_changed")
	if not current.has("settlements"): return _result("blocked","legacy_settlement_history_unavailable")
	if not current.settlements.is_empty():
		var receipts_by_id := {}
		for receipt: Dictionary in candidate.settlements:
			var key := JSON.stringify(["settlement",receipt.get("receipt_id")])
			if not receipts_by_id.has(key): receipts_by_id[key] = []
			receipts_by_id[key].append(receipt)
		# Full receipt validation still rejects duplicates. Buckets preserve this
		# helper's complete-value membership semantics even for invalid raw input.
		for receipt: Dictionary in current.settlements:
			var bucket: Array = receipts_by_id.get(JSON.stringify(["settlement",receipt.get("receipt_id")]),[])
			if not bucket.has(receipt): return _result("conflict","settlement_history_changed")
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
