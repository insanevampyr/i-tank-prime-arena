class_name CharacterPersistenceSession
extends RefCounted

# Host-side boundary. Never serialized into CombatSimulation or driven by its clock.
# An identity/instance provider must exist BEFORE a run; the UI cannot attest itself.
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
static var _profile_owners: Dictionary = {}
var _lease_token: int
var _storage: CharacterSaveStorage
var _source: CombatCharacterDefinitionResource
var _profile_id := ""
var _rules := ""
var _authority: Callable
var _modes: Array[String] = []
var _prepared: Dictionary = {}
var _prepared_source := ""
var _last_result: Dictionary = {}
var _new_profile_run := false
var _reset := false
var _admitted := false
var _status := {"persistent":false,"reason":"trusted_profile_and_item_ownership_unavailable"}

func _init(storage: CharacterSaveStorage = null) -> void:
	_lease_token = get_instance_id()
	_storage = storage if storage != null else CharacterSaveStorage.new()
	if OS.has_feature("web"): _block("web_write_coordination_unverified")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _profile_owners.get(_profile_id) == _lease_token:
		_profile_owners.erase(_profile_id)

func bind_before_run(source: CombatCharacterDefinitionResource, profile_id: String, rules_revision: String, authority: Callable) -> Dictionary:
	if not _modes.is_empty() or not _profile_id.is_empty() or _reset: return _failure("profile_binding_requires_new_session")
	if source == null or not CharacterSaveStorage._valid_id(profile_id) or rules_revision.is_empty() or not authority.is_valid(): return _failure("invalid_host_profile_binding")
	var binding := Profiles.fingerprint({"profile_id":profile_id,"rules_revision":rules_revision,"source":source.to_dictionary()})
	var approval: Variant = authority.call("bind",binding)
	if not approval is Dictionary or not approval.get("authorized",false) or approval.get("binding") != binding: return _failure("profile_ownership_not_authorized")
	if _profile_owners.has(profile_id): return _failure("profile_already_owned_by_session")
	_profile_owners[profile_id] = _lease_token
	_source = source.duplicate(true)
	_profile_id = profile_id
	_rules = rules_revision
	_authority = authority
	_block("profile_preflight_required")
	return {"success":true,"persistent":false}

func observe_mode(mode: String) -> void:
	# Monotonic lineage: a later NORMAL flag never launders DEV/TEST activity.
	if _modes.is_empty() or _modes.back() != mode: _modes.append(mode)
	if not _normal_lineage(): _block("nonproduction_mode_lineage")

func fixture_reset() -> void:
	# RESET is deliberately NOT NEW RUN or a profile-delete operation.
	_reset = true
	_block("fixture_reset_is_nonpersistent")

func inspect_before_run() -> Dictionary:
	_new_profile_run = false
	_admitted = false
	var ready := _eligible()
	if not ready.success: return ready
	var inspection := _storage.inspect_profile(_profile_id)
	if not inspection.get("success",false): return _block("profile_history_requires_review",inspection)
	if inspection.writer_locked or inspection.pending_write: return _block("profile_recovery_required",inspection)
	if inspection.generations.is_empty():
		_new_profile_run = true
		return _block("starter_instance_admission_required")
	var latest: Dictionary = inspection.generations.back().payload
	var candidate := Profiles.hydrate(latest,_source,_profile_id,_rules,_verify)
	if not candidate.get("success",false): return _block(String(candidate.get("reason","profile_hydration_failed")))
	# Current v2 requires one run's cumulative histories and receipt namespace.
	# Do not relabel those as a fresh run, replay purchases, or refill via hydration.
	return _block("new_run_history_and_instance_application_unavailable")

func can_start_run() -> bool:
	return not requires_checkpoint() or _admitted

func checkpoint(actor: CombatActorDefinition, state: CombatActorState, ledger: Dictionary, defense: CombatDefenseProfile, boundary: String) -> Dictionary:
	var ready := _eligible()
	if not ready.success: return ready
	if not _new_profile_run: return _block("validated_new_profile_admission_required")
	if boundary not in ["run_admission","wave_completed","character_changed","next_wave"]: return _block("unsupported_checkpoint_boundary")
	if actor == null or state == null: return _block("character_state_unavailable")
	var source_binding := Profiles.fingerprint({"actor":actor.to_dictionary(),"state":state.to_dictionary(),"ledger":ledger,"defense":defense.to_dictionary() if defense != null else {}})
	if not _prepared.is_empty():
		if source_binding == _prepared_source:
			if not _has_wave_checkpoint(_prepared.payload,ledger,boundary): return _block("completed_wave_checkpoint_identity_required")
			# Retain the EXACT proposal. Never mint another claim to retry a write.
			if not _last_result.get("success",false): return reconcile_pending()
			return _commit_prepared()
		if not _last_result.get("success",false): return _block("unresolved_checkpoint_must_reconcile")
	var projected := Profiles.project(_source,actor,state,ledger,defense,_verify)
	if not projected.get("success",false): return _block(String(projected.get("reason","projection_failed")))
	if not _has_wave_checkpoint(projected.payload,ledger,boundary): return _block("completed_wave_checkpoint_identity_required")
	var authorization := _verify("checkpoint",Profiles.fingerprint({"source":source_binding,"boundary":boundary,"payload":projected.payload}))
	if not authorization.get("authorized",false): return _block("checkpoint_receipts_not_authorized")
	if not authorization.get("settlements") is Array or not authorization.get("transaction_id") is String or typeof(authorization.get("expected_generation")) != TYPE_INT or not authorization.get("expected_checkpoints") is Array: return _block("checkpoint_identity_or_receipts_unavailable")
	var proposal := Coordinator.prepare(projected.payload,authorization.settlements,authorization.transaction_id,authorization.expected_generation,authorization.expected_checkpoints)
	if not proposal.get("success",false): return _block(String(proposal.get("reason","preparation_failed")))
	_prepared = proposal.prepared
	_prepared_source = source_binding
	return _commit_prepared()

func reconcile_pending() -> Dictionary:
	var ready := _eligible()
	if not ready.success: return ready
	if _prepared.is_empty(): return _failure("no_pending_checkpoint")
	var coordinator := Coordinator.new(_storage)
	var result := coordinator.reconcile(_prepared,_source,_profile_id,_rules,_verify)
	_last_result = result.duplicate(true)
	if result.get("success",false) and not result.get("recovery_required",false) and result.generation == result.latest_generation:
		_admitted = true
		_status = {"persistent":true,"reason":"checkpoint_verified","generation":result.generation}
	else:
		_last_result["success"] = false
		return _block(String(result.get("reason","checkpoint_recovery_required")),result)
	return result

func _has_wave_checkpoint(payload: Dictionary, ledger: Dictionary, boundary: String) -> bool:
	if boundary not in ["wave_completed","next_wave"]: return true
	var wave_id := String(ledger.get("current_wave_id",""))
	if not CharacterSaveStorage._valid_id(wave_id): return false
	return payload.secured_checkpoints.has("%s/%s/%s" % [_profile_id,payload.lineage.run_id,wave_id])

func requires_checkpoint() -> bool:
	return not _profile_id.is_empty() and _normal_lineage() and not _reset

func get_status() -> Dictionary:
	var status := _status.duplicate(true)
	status["text"] = "Progress checkpoint verified" if status.persistent else "Progress not saved"
	status["mode_history"] = _modes.duplicate()
	return status

func _commit_prepared() -> Dictionary:
	var coordinator := Coordinator.new(_storage)
	var result := coordinator.commit(_prepared,_source,_profile_id,_rules,_verify)
	_last_result = result.duplicate(true)
	if result.get("success",false) and not result.get("recovery_required",false) and result.generation == result.latest_generation:
		_admitted = true
		_status = {"persistent":true,"reason":"checkpoint_verified","generation":result.generation}
		return result
	_last_result["success"] = false
	return _block(String(result.get("reason","checkpoint_recovery_required")),result)

func _verify(operation: String, binding: String) -> Dictionary:
	if not _normal_lineage() or _reset or not _authority.is_valid(): return {"authorized":false}
	var response: Variant = _authority.call(operation,binding)
	if not response is Dictionary or not response.get("authorized",false) or response.get("binding") != binding: return {"authorized":false}
	if operation == "project":
		if response.get("profile_id") != _profile_id or response.get("rules_revision") != _rules or response.get("definition_id") != String(_source.definition_id) or response.get("mode_history") != Array(_modes): return {"authorized":false}
	if operation == "hydrate":
		var lineage: Variant = response.get("lineage")
		if not lineage is Dictionary or lineage.get("profile_id") != _profile_id or lineage.get("rules_revision") != _rules or lineage.get("definition_id") != String(_source.definition_id) or lineage.get("mode_history") != Array(_modes): return {"authorized":false}
	return response.duplicate(true)

func _eligible() -> Dictionary:
	if _reset: return _block("fixture_reset_is_nonpersistent")
	if not _normal_lineage(): return _block("nonproduction_mode_lineage")
	var platform := _storage.get_storage_status()
	if not platform.get("success",false): return _block(String(platform.get("reason","storage_unavailable")))
	if _profile_id.is_empty(): return _block("trusted_profile_and_item_ownership_unavailable")
	return {"success":true}

func _normal_lineage() -> bool:
	return not _modes.is_empty() and _modes.all(func(mode: String) -> bool: return mode == "normal")

func _block(reason: String, details: Dictionary = {}) -> Dictionary:
	_status = {"persistent":false,"reason":reason}
	return {"success":false,"reason":reason,"details":details}

func _failure(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
