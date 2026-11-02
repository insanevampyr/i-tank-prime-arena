class_name CharacterBackupReader
extends RefCounted

# Read-only orchestration. There is deliberately no commit/restore/publish API.
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
var _service: PlayableCharacterPersistence
var _storage: CharacterSaveStorage
var _browser: CharacterBrowserStorage
var _owns_browser := false
var _job := ""
var _mode := ""
var _kind := ""
var _backup := {}
var _result := {"success":false,"state":"idle"}

func begin_export(service: PlayableCharacterPersistence) -> Dictionary:
	if _result.get("state") == "pending": return Backup.fail("backup_operation_in_flight")
	var eligible := export_eligibility(service)
	if not eligible.success: return eligible
	_service = service
	_mode = service.mode
	_kind = "export"
	_storage = service.storage
	if service is PlayableBrowserPersistence: _browser = service.browser
	return _inspect(service.profile_id)

func begin_preview(text: String, save_namespace: String, storage: CharacterSaveStorage = null, browser: CharacterBrowserStorage = null) -> Dictionary:
	if _result.get("state") == "pending": return Backup.fail("backup_operation_in_flight")
	_backup = Backup.decode(text,save_namespace)
	if not _backup.success: return _backup
	_mode = save_namespace
	_kind = "preview"
	_storage = storage
	_browser = browser
	if _browser == null and (OS.has_feature("web") or PlayableBrowserPersistence.test_factory.is_valid()):
		_browser = PlayableBrowserPersistence.test_factory.call() if PlayableBrowserPersistence.test_factory.is_valid() else CharacterBrowserStorage.new()
		_owns_browser = true
	elif _storage == null and _browser == null:
		_storage = PlayableCharacterPersistence.test_storage if PlayableCharacterPersistence.test_storage != null else CharacterSaveStorage.new()
	return _inspect(_backup.manifest.profile_id)

func _inspect(profile: String) -> Dictionary:
	if _browser != null:
		_result = _browser.begin("inspect",{"profile":profile})
		_job = _result.get("job","")
		if _result.get("state") != "pending": return _finish(_result)
		return _result.duplicate(true)
	return _finish(_storage.inspect_profile(profile))

func poll() -> Dictionary:
	if _result.get("state") != "pending": return _result.duplicate(true)
	var response := _browser.poll(_job)
	if response.get("state") == "pending": return response
	return _finish(CharacterBrowserStorage.inspection(response))

func _finish(history: Dictionary) -> Dictionary:
	if _kind == "preview":
		_result = {"success":true,"state":"preview","preview":_backup.preview.duplicate(true),"classification":Backup.compare(_backup,history,_mode),"destination_reason":history.get("reason",""),"backup_digest":_backup.backup_digest,"read_only":true}
	else:
		var eligible := export_eligibility(_service)
		if not eligible.success:
			_result = eligible
		elif not history.get("success",false) or history.get("generations",[]).is_empty():
			_result = Backup.fail("committed_history_unavailable")
		else:
			var last: Dictionary = history.generations.back()
			var payload: Dictionary = last.get("payload",{})
			if payload.is_empty():
				var decoded := CharacterSaveContract.decode(last.document)
				payload = decoded.get("payload",{})
			# Compare through the existing wire contract: JSON decoding represents
			# negative sentinel numbers as floats. Do not alter Contract V2 or bytes.
			var admitted: Variant = CharacterSaveContract.decode(CharacterSaveContract.encode(_service._prior).text).get("payload",{})
			if payload != admitted or payload.get("generation") != _service.generation:
				_result = Backup.fail("stored_head_not_acknowledged_character")
			elif not _service._prepared.is_empty() and _service._prepared.payload.generation == _service.generation and last.transaction_id != _service._prepared.transaction_id:
				_result = Backup.fail("stored_transaction_not_acknowledged_character")
			else:
				_result = Backup.create(history,_mode,Time.get_datetime_string_from_system(true)+"Z")
				if _result.success: _result["state"] = "export_ready"
	if _owns_browser:
		_browser.dispose()
		_owns_browser = false
	return _result.duplicate(true)

static func export_eligibility(service: PlayableCharacterPersistence) -> Dictionary:
	if service == null or service.mode not in ["normal","dev_normal"] or service.generation < 1 or not service.status().get("persistent",false) or service._reset or not service._failure.is_empty(): return Backup.fail("admitted_acknowledged_character_required")
	if not service._prepared.is_empty() and not service._last_ack: return Backup.fail("checkpoint_pending_or_uncertain")
	# Admission verifies existing durable history without publishing a new write.
	# Its empty proposal and validated-load status are distinct from an unacked write.
	var verified_load: bool = service._prepared.is_empty() and service.status().get("reason") == "validated_profile_loaded"
	if not service._last_ack and not verified_load: return Backup.fail("admitted_acknowledged_character_required")
	if service is PlayableBrowserPersistence:
		var state: String = service._browser_result.get("state","")
		if service.pending_or_unsecured() or not service._owns_lease or (state != "verified_committed" and not (verified_load and state == "loaded")): return Backup.fail("browser_storage_pending_or_unavailable")
	elif service.storage == null or not service.storage.get_storage_status().success: return Backup.fail("desktop_storage_unavailable")
	return {"success":true}

func dispose() -> void:
	if _owns_browser and _browser != null: _browser.dispose()
	_owns_browser = false
