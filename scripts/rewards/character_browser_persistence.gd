class_name CharacterBrowserPersistence
extends RefCounted

# Explicit host-driven pump. No simulation ticks, await loops or filesystem I/O.
# The future playable host owns acquire/transfer/release of the session lease.
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Browser = preload("res://scripts/rewards/character_browser_storage.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
var _storage: CharacterBrowserStorage
var _prepared := {}
var _profile := ""
var _owner := ""
var _job := ""
var _phase := ""
var _reconcile_only := false
var _status := Browser.status("unavailable","no_operation")

func _init(storage: CharacterBrowserStorage) -> void:
	_storage = storage

func begin_commit(prepared: Dictionary, source: CombatCharacterDefinitionResource, profile: String, rules: String, owner: String, verifier: Callable, reconcile_only: bool = false) -> Dictionary:
	if _status.state == "pending": return Browser.status("failed","operation_in_flight")
	# Reuse ALL desktop authority checks before dispatching any browser mutation.
	var authorized := Coordinator._authorize(prepared,source,profile,rules,verifier)
	if not authorized.success: return _finish("failed",authorized.get("reason","authority_rejected"))
	if _storage == null: return _finish("unavailable","storage_unavailable")
	_prepared = prepared.duplicate(true)
	_profile = profile
	_owner = owner
	_reconcile_only = reconcile_only
	return _dispatch("inspect",{"profile":profile})

func poll() -> Dictionary:
	if _status.state != "pending": return _status.duplicate(true)
	var response := _storage.poll(_job)
	if response.state == "pending": return _status.duplicate(true)
	if response.state != "verified_committed":
		_status = response
		return _status.duplicate(true)
	if _phase == "inspect":
		var inspection := Browser.inspection(response,_profile)
		if not inspection.success: return _finish("recovery_required",inspection.get("reason","invalid_history"))
		var prior := Coordinator._find_transaction(_prepared,inspection)
		if prior.state == "committed":
			# Reconciliation uses another fresh IDB transaction, even for exact retries.
			return _dispatch("reconcile",_arguments())
		if prior.state != "not_committed": return _finish("recovery_required",prior.get("reason","history_conflict"))
		if _reconcile_only: return _finish("failed","transaction_not_found")
		var records: Array = inspection.generations
		var current: Dictionary = {} if records.is_empty() else records.back().payload
		var generation := 0 if current.is_empty() else int(current.generation)
		if generation != _prepared.expected_generation: return _finish("failed","stale_generation")
		if _prepared.expected_checkpoints != current.get("secured_checkpoints",[]): return _finish("failed","checkpoint_comparison_failed")
		if not current.is_empty():
			for validation: Dictionary in [Contract.validate_replacement(current,_prepared.payload),Coordinator._validate_continuity(current,_prepared.payload)]:
				if not validation.success: return _finish("failed",validation.get("reason","invalid_replacement"))
		var items := Coordinator._validate_new_items(current,_prepared.payload)
		if not items.success: return _finish("failed",items.get("reason","unverified_items"))
		return _dispatch("publish",_arguments())
	# Exact bytes, not just an optimistic success flag or matching generation.
	if not response.get("success",false) or response.get("document") != _prepared.document or response.get("transaction_id") != _prepared.transaction_id or response.get("generation") != _prepared.payload.generation: return _finish("recovery_required","acknowledgement_mismatch")
	_status = response
	return _status.duplicate(true)

func _arguments() -> Dictionary:
	return {"profile":_profile,"owner":_owner,"transaction_id":_prepared.transaction_id,"expected_generation":_prepared.expected_generation,"document":_prepared.document}

func _dispatch(operation: String, arguments: Dictionary) -> Dictionary:
	_phase = operation
	_status = _storage.begin(operation,arguments)
	if _status.get("state") == "verified_committed": return _finish("recovery_required","queued_operation_cannot_acknowledge_commit")
	_job = _status.get("job","")
	return _status.duplicate(true)

func _finish(state: String, reason: String) -> Dictionary:
	_status = Browser.status(state,reason)
	return _status.duplicate(true)
