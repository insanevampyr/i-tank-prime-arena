extends RefCounted

# Host-only fixed maintenance transaction. Never a general reward command.
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
var status := {"success":false,"state":"idle"}
var quote := {}
var _session: ArenaCombatSession
var _service: PlayableCharacterPersistence
var _phase := ""
var _job := ""
var _validation := {}
var _binding := ""
var _runtime := ""
var _prepared := {}
var _async: CharacterBrowserPersistence

static func target(service: PlayableCharacterPersistence) -> bool:
	if service == null: return false
	var lineage: Variant = service._prior.get("lineage")
	return service.profile_id == Credit.PROFILE and service.mode == "dev_normal" and lineage is Dictionary and lineage.get("baseline_digest") == Credit.BASELINE

func blocks_gameplay() -> bool:
	return status.get("state") in ["pending","confirmation_required","recovery_required"]

func begin(session: ArenaCombatSession) -> Dictionary:
	if blocks_gameplay(): return {"success":false,"reason":"credit_operation_in_flight"}
	_session = session
	_service = session._playable_persistence if session != null else null
	var eligible := _eligibility()
	if not eligible.success: return _fail(eligible.get("reason","credit_unavailable"))
	_runtime = _runtime_digest()
	status = {"success":false,"state":"pending","stage":"Checking committed character history"}
	_phase = "inspect"
	if _service is PlayableBrowserPersistence:
		var response: Dictionary = _service.browser.begin("inspect",{"profile":Credit.PROFILE})
		_job = response.get("job","")
		if response.get("state") != "pending": return _fail(response.get("reason","credit_inspection_failed"))
	else:
		return _inspect(_service.storage.inspect_profile(Credit.PROFILE))
	return status

func _eligibility() -> Dictionary:
	if not target(_service) or _session._playable_persistence != _service: return {"success":false,"reason":"expc_credit_profile_mismatch"}
	var eligible := _session.get_character_advancement_eligibility()
	if not eligible.success: return eligible
	var progression := _session.get_actor_state(&"player").progression
	if progression.get("expc") != _service._prior.get("xp",{}).get("unspent") or progression.get("expm") != _service._prior.get("xp",{}).get("earned") or _session.get_reward_state().get("unspent_xp") != progression.get("expc"):
		return {"success":false,"reason":"credit_wallet_not_acknowledged"}
	return CharacterBackupReader.export_eligibility(_service)

func _runtime_digest() -> String:
	return Credit.digest({"actor":_session.simulation.get_actor_definition(&"player").to_dictionary(),"state":_session.get_actor_state(&"player").to_dictionary(),"ledger":_session.get_reward_state(),"clock":_session.simulation.clock.get_elapsed_us()})

func _inspect(history: Dictionary) -> Dictionary:
	_validation = Backup.begin_history_validation(history,"dev_normal")
	if not _validation.success: return _fail(_validation.get("reason","credit_history_invalid"))
	_phase = "validate"
	return status

func poll() -> Dictionary:
	if status.get("state") != "pending": return status
	if _phase == "publish":
		return _published(_async.poll())
	if _phase == "inspect":
		var response: Dictionary = _service.browser.poll(_job)
		if response.get("state") == "pending": return status
		return _inspect(CharacterBrowserStorage.inspection(response,Credit.PROFILE))
	var checked := Backup.step_history_validation(_validation)
	if checked.get("state") == "pending":
		status = checked
		return status
	if not checked.success: return _fail(checked.get("reason","credit_history_invalid"))
	var eligible := _eligibility()
	if not eligible.success or checked.payload != _service._prior or checked.payload.generation != _service.generation or _runtime_digest() != _runtime:
		return _fail("credit_head_or_session_changed")
	if checked.payload.has("expc_credits"):
		status = {"success":true,"state":"already_applied"}
		return status
	quote = {"profile_id":Credit.PROFILE,"namespace":"dev_normal","generation":_service.generation,"head_digest":Credit.digest(checked.payload),"history_digest":Credit.digest({"records":checked.records}),"expc_before":checked.payload.xp.unspent,"expc_after":checked.payload.xp.unspent+Credit.AMOUNT,"expm":checked.payload.xp.earned,"token":Crypto.new().generate_random_bytes(16).hex_encode()}
	_binding = Credit.digest(quote)
	status = {"success":false,"state":"confirmation_required","quote":quote.duplicate(true)}
	return status

func confirm(token: String) -> Dictionary:
	if status.get("state") != "confirmation_required" or token != quote.get("token") or Credit.digest(quote) != _binding:
		return {"success":false,"reason":"credit_confirmation_not_verified"}
	var eligible := _eligibility()
	if not eligible.success or _runtime_digest() != _runtime or Credit.digest(_service._prior) != quote.head_digest or _service.generation != quote.generation:
		return _fail("credit_head_or_session_changed")
	var credit := Credit.prepare(_service._prior,func(value: Dictionary) -> Dictionary:
		return {"confirmed":value.generation == quote.generation and value.head_digest == quote.head_digest,"binding":Credit.digest(value)}
	)
	if not credit.success or credit.get("no_op",false): return _fail("credit_preparation_rejected")
	var proposal := CharacterPersistenceCoordinator.prepare(credit.payload,credit.payload.settlements,credit.transaction_id,_service.generation,_service._prior.secured_checkpoints)
	if not proposal.success: return _fail(proposal.get("reason","credit_preparation_rejected"))
	_prepared = proposal.prepared
	_service._allowed_payloads[CharacterProfileProjection.fingerprint(_prepared.payload)] = _service._lineage.duplicate(true)
	_service._allowed_proposals[CharacterProfileProjection.fingerprint(_prepared)] = true
	_service._prepared = _prepared.duplicate(true)
	_service._last_ack = false
	return _publish()

func _publish() -> Dictionary:
	status = {"success":false,"state":"pending","stage":"Publishing the confirmed one-time credit"}
	_phase = "publish"
	if _service is PlayableBrowserPersistence:
		_async = CharacterBrowserPersistence.new(_service.browser)
		return _published(_async.begin_commit(_prepared,_service.source,Credit.PROFILE,PlayableCharacterAdmission.RULES,_service.owner,_service._verify))
	return _published(CharacterPersistenceCoordinator.new(_service.storage).commit(_prepared,_service.source,Credit.PROFILE,PlayableCharacterAdmission.RULES,_service._verify))

func retry() -> Dictionary:
	if status.get("state") != "recovery_required" or _prepared.is_empty(): return {"success":false,"reason":"credit_retry_unavailable"}
	# Retain the exact confirmed proposal; the coordinator reconciles before write.
	return _publish()

func _published(response: Dictionary) -> Dictionary:
	var _capture_scope: RefCounted
	var _capture_owner: RefCounted = _session._character_capture_gate if _session != null else null
	if _capture_owner != null:
		_capture_scope = _capture_owner.enter_mutation()
		if _capture_scope == null: return {"success":false,"reason":"character_capture_in_progress"}
	if response.get("state") == "pending": return status
	if not response.get("success",false) or response.get("generation") != _prepared.payload.generation or response.get("latest_generation") != _prepared.payload.generation or response.get("transaction_id") != _prepared.transaction_id or (response.has("document") and response.document != _prepared.document):
		return _fail(response.get("reason","credit_readback_unverified"),true)
	if _session._playable_persistence != _service or _runtime_digest() != _runtime: return _fail("credit_live_state_changed_reload_required",true)
	var ack := _service._ack(response)
	if not ack.success: return _fail(ack.get("reason","credit_readback_unverified"),true)
	_apply_runtime(_service.generation)
	if _service is PlayableBrowserPersistence:
		_service._browser_result = response.duplicate(true)
		_service._phase = "finished"
	var state := _session.get_actor_state(&"player")
	status = {"success":true,"state":"applied","generation":_service.generation,"expc":state.progression.expc,"expm":state.progression.expm}
	return status

# Shared original effect only. Publication authority remains in the caller:
# real verified readback above, or the cache-isolated dormant aggregate.
func _apply_runtime(generation: int) -> void:
	_service.candidate.xp = _prepared.payload.xp.duplicate(true)
	var state := _session.get_actor_state(&"player")
	state.progression.expc = _prepared.payload.xp.unspent
	state.progression["expc_credit_total"] = Credit.AMOUNT
	state.revision += 1
	_session._reward_ledger.expc_credit_total = Credit.AMOUNT
	_session.simulation.set_reward_state_snapshot(_session.get_reward_state())
	_session.simulation.record_reward_event(&"reward_expc_test_credit_applied",&"player",&"player",{"grant_id":Credit.GRANT_ID,"transaction_id":_prepared.transaction_id,"generation":generation,"expc_credit":Credit.AMOUNT,"expm_change":0})

func cancel() -> bool:
	if status.get("state") in ["applied","already_applied"]: return true
	if not _prepared.is_empty() or status.get("state") == "pending": return false
	quote = {}
	status = {"success":false,"state":"cancelled"}
	return true

func _fail(reason: String, uncertain: bool = false) -> Dictionary:
	status = {"success":false,"state":"recovery_required" if uncertain else "failed","reason":reason}
	return status
