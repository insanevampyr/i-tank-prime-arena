class_name CharacterBackupRestoration
extends RefCounted

# Explicit confirmation coordinator; storage timing never enters simulation.
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
var backup := {}
var status := {"success":false,"state":"idle"}
var storage: CharacterSaveStorage
var browser: CharacterBrowserStorage
var lease_service: PlayableBrowserPersistence
var _text := ""
var _namespace := ""
var _expected: Array = []
var _owner := ""
var _job := ""
var _phase := ""
var _owns_browser := false
var _native_locked := false
var uncertain := false

func begin(text: String, save_namespace: String, service: PlayableCharacterPersistence = null, isolated_storage: CharacterSaveStorage = null, browser_adapter: CharacterBrowserStorage = null) -> Dictionary:
	if status.state != "idle": return _failure("restoration_already_started")
	backup = Backup.decode(text,save_namespace)
	if not backup.success: return _failure(backup.get("reason","invalid_backup"))
	_text = text; _namespace = save_namespace
	if service != null:
		if service.profile_id != backup.manifest.profile_id or service.mode != save_namespace or not CharacterBackupReader.export_eligibility(service).success: return _failure("destination_admission_pending_or_mismatched")
	storage = isolated_storage if isolated_storage != null else (service.storage if service != null else PlayableCharacterPersistence.test_storage)
	if service is PlayableBrowserPersistence:
		lease_service = service
		browser = service.browser
		_owner = service.owner
	elif OS.has_feature("web") or browser_adapter != null or PlayableBrowserPersistence.test_factory.is_valid():
		browser = browser_adapter if browser_adapter != null else (PlayableBrowserPersistence.test_factory.call() if PlayableBrowserPersistence.test_factory.is_valid() else CharacterBrowserStorage.new())
		_owns_browser = true
		_owner = "restore_"+Crypto.new().generate_random_bytes(12).hex_encode()
		lease_service = PlayableBrowserPersistence.new()
		lease_service.mode = save_namespace; lease_service.profile_id = backup.manifest.profile_id
		lease_service.browser = browser; lease_service.owner = _owner
		return _dispatch("acquire",{"profile":backup.manifest.profile_id,"owner":_owner})
	if browser != null: return _dispatch("inspect",{"profile":backup.manifest.profile_id})
	if storage == null: storage = CharacterSaveStorage.new()
	var acquired := storage.acquire_writer(backup.manifest.profile_id)
	if not acquired.success: return _failure(acquired.get("reason","writer_unavailable"))
	_owner = acquired.owner; _native_locked = true
	return _evaluate(storage.inspect_owned(backup.manifest.profile_id,_owner))

func _evaluate(history: Dictionary) -> Dictionary:
	var classification := Backup.compare(backup,history,_namespace)
	if classification not in ["empty_destination","exact_match","destination_exact_prefix"]: return _failure(classification)
	_expected = CharacterSaveStorage.history_records(history)
	status = {"success":true,"state":"confirmation_required","classification":classification,"preview":backup.preview.duplicate(true)}
	return status.duplicate(true)

func confirm() -> Dictionary:
	if status.state != "confirmation_required" or uncertain: return _failure("explicit_restoration_confirmation_required")
	var checked := Backup.decode(_text,_namespace)
	if not checked.success or checked.backup_digest != backup.backup_digest: return _failure("backup_changed")
	if browser != null: return _dispatch("revalidate",{"profile":backup.manifest.profile_id},"inspect")
	var before := storage.inspect_owned(backup.manifest.profile_id,_owner)
	if not before.get("success",false) or before.writer_locked or before.pending_write or CharacterSaveStorage.history_records(before) != _expected: return _failure("destination_changed_after_preview")
	uncertain = true
	var written := storage.restore_history(backup.manifest.profile_id,backup.history,_expected,_owner)
	if not written.success: return _failure(written.get("reason","restoration_failed"))
	return _verified(storage.inspect_owned(backup.manifest.profile_id,_owner))

func poll() -> Dictionary:
	if status.state != "pending": return status.duplicate(true)
	var response := browser.poll(_job)
	if response.get("state") == "pending": return status.duplicate(true)
	if not response.get("success",false): return _failure(response.get("reason","browser_restoration_failed"))
	if _phase == "acquire":
		lease_service._owns_lease = true
		return _dispatch("inspect",{"profile":backup.manifest.profile_id})
	var history := CharacterBrowserStorage.inspection(response,backup.manifest.profile_id)
	if _phase == "inspect": return _evaluate(history)
	if _phase == "revalidate":
		if not history.get("success",false) or CharacterSaveStorage.history_records(history) != _expected: return _failure("destination_changed_after_preview")
		uncertain = true
		return _dispatch("restore",{"profile":backup.manifest.profile_id,"owner":_owner,"expected":_expected,"records":backup.history})
	if _phase == "restore":
		# Never trust a queued operation or even an optimistic transport success.
		return _dispatch("verify",{"profile":backup.manifest.profile_id},"inspect")
	if _phase == "reconcile" and history.get("success",false) and CharacterSaveStorage.history_records(history) == _expected:
		uncertain = false
		return _evaluate(history)
	return _verified(history)

func reconcile() -> Dictionary:
	if not uncertain: return _failure("no_uncertain_restoration")
	if browser != null: return _dispatch("reconcile",{"profile":backup.manifest.profile_id},"inspect")
	var history := storage.inspect_owned(backup.manifest.profile_id,_owner)
	if history.get("success",false) and not history.pending_write and CharacterSaveStorage.history_records(history) == _expected:
		uncertain = false
		return _evaluate(history)
	return _verified(history)

func _verified(history: Dictionary) -> Dictionary:
	if not history.get("success",false) or history.get("writer_locked",false) or history.get("pending_write",false) or CharacterSaveStorage.history_records(history) != backup.history: return _failure("restoration_readback_mismatch")
	var checked := Backup.validate_history(history,_namespace)
	if not checked.success: return _failure(checked.get("reason","restored_history_invalid"))
	uncertain = false
	status = {"success":true,"state":"verified_committed","payload":checked.payload,"generation":backup.manifest.head_generation,"digest":backup.backup_digest}
	return status.duplicate(true)

func _dispatch(phase: String, args: Dictionary, operation: String = "") -> Dictionary:
	_phase = phase
	status = browser.begin(phase if operation.is_empty() else operation,args)
	_job = status.get("job","")
	if status.get("state") != "pending": return _failure("asynchronous_storage_request_required")
	return status.duplicate(true)

func cancel() -> Dictionary:
	if status.state == "pending" or uncertain: return {"success":false,"reason":"restoration_requires_verification"}
	if _native_locked:
		var unlocked := storage.release_writer(backup.manifest.profile_id,_owner)
		if not unlocked.success: return unlocked
		_native_locked = false
	if _owns_browser:
		browser.dispose()
		_owns_browser = false
	status = {"success":true,"state":"cancelled"}
	return status.duplicate(true)

func handoff() -> Dictionary:
	# The existing playable admission path takes over this already-held Web Lock.
	if _native_locked:
		var unlocked := storage.release_writer(backup.manifest.profile_id,_owner)
		if not unlocked.success:
			uncertain = true
			return _failure("restoration_writer_release_failed")
		_native_locked = false
	_owns_browser = false
	return {"success":true}

func _failure(reason: String) -> Dictionary:
	status = {"success":false,"state":"recovery_required" if uncertain else "failed","reason":reason}
	return status.duplicate(true)

func dispose() -> void:
	if _native_locked:
		storage.release_writer(backup.manifest.profile_id,_owner)
		_native_locked = false
	if _owns_browser and browser != null: browser.dispose()
	_owns_browser = false
