class_name CharacterBackupReader
extends RefCounted

# Read-only orchestration. There is deliberately no commit/restore/publish API.
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Task = preload("res://scripts/rewards/character_backup_task.gd")
var _task: RefCounted
var _incremental := false
var _deferred_profile := ""
var _wait_frame := false
var _cancelled := false
var _destination_job := {}
var _destination_reason := ""
var _service: PlayableCharacterPersistence
var _storage: CharacterSaveStorage
var _browser: CharacterBrowserStorage
var _owns_browser := false
var _job := ""
var _mode := ""
var _kind := ""
var _verified_text := ""
var _verified_snapshot := ""
var _backup := {}
var _result := {"success":false,"state":"idle"}

func begin_export(service: PlayableCharacterPersistence, incremental: bool = false) -> Dictionary:
	if _result.get("state") == "pending": return Backup.fail("backup_operation_in_flight")
	_cancelled = false
	var eligible := export_eligibility(service)
	if not eligible.success: return eligible
	_service = service
	_mode = service.mode
	_kind = "export"
	_incremental = incremental
	_storage = service.storage
	if service is PlayableBrowserPersistence: _browser = service.browser
	if incremental:
		_deferred_profile = service.profile_id; _wait_frame = true
		_result = {"success":false,"state":"pending","stage":"Reading saved history"}
		return _result
	return _inspect(service.profile_id)

func begin_preview(text: String, save_namespace: String, storage: CharacterSaveStorage = null, browser: CharacterBrowserStorage = null, incremental: bool = false) -> Dictionary:
	if _result.get("state") == "pending": return Backup.fail("backup_operation_in_flight")
	_cancelled = false
	_verified_text = text
	_verified_snapshot = ""
	_incremental = incremental
	if not incremental:
		_backup = Backup.decode(text,save_namespace)
		if not _backup.success: return _backup
		_verified_snapshot = Backup.snapshot_digest(_backup)
	_mode = save_namespace
	_kind = "preview"
	_storage = storage
	_browser = browser
	if _browser == null and (OS.has_feature("web") or PlayableBrowserPersistence.test_factory.is_valid()):
		_browser = PlayableBrowserPersistence.test_factory.call() if PlayableBrowserPersistence.test_factory.is_valid() else CharacterBrowserStorage.new()
		_owns_browser = true
	elif _storage == null and _browser == null:
		_storage = PlayableCharacterPersistence.test_storage if PlayableCharacterPersistence.test_storage != null else CharacterSaveStorage.new()
	if incremental:
		_task = Task.new("decode",save_namespace,{},text)
		_kind = "preview_decode"
		_result = {"success":false,"state":"pending","stage":"Checking selected file"}
		return _result
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
	if _wait_frame: _wait_frame = false; return _result
	if not _deferred_profile.is_empty():
		var profile := _deferred_profile; _deferred_profile = ""
		return _inspect(profile)
	if _task != null:
		var response: Dictionary = _task.step()
		if response.get("state") == "pending": _result = response; return response
		_task = null
		if not response.get("success",false): _result = response; return response
		if _kind == "preview_decode":
			_backup = response; _kind = "preview"
			_verified_snapshot = Backup.snapshot_digest(_backup)
			return _inspect(_backup.manifest.profile_id)
		var eligible := export_eligibility(_service)
		if not eligible.success or response.payload != CharacterSaveContract.decode(CharacterSaveContract.encode(_service._prior).text).get("payload"):
			_result = Backup.fail("stored_head_not_acknowledged_character"); return _result
		response["state"] = "export_ready"; _result = response
		return _result
	if not _destination_job.is_empty():
		var response := Backup.step_history_validation(_destination_job)
		if response.get("state") == "pending": _result = response; return response
		_destination_job = {}
		var classification := _compare_checked_destination(response)
		return _preview_result(classification,_destination_reason)
	var response := _browser.poll(_job)
	if response.get("state") == "pending": return response
	_job = ""
	if _cancelled: _result = {"success":false,"state":"cancelled"}; return _result
	if _incremental and response.get("success",false) and response.get("state") == "verified_committed":
		if not response.get("generations") is Array or bool(response.get("missing",false)) != response.generations.is_empty():
			return _finish(Backup.fail("ambiguous_browser_history"))
		return _finish({"success":true,"generations":response.generations})
	if _incremental: return _finish(Backup.fail(response.get("reason","browser_storage_unavailable")))
	return _finish(CharacterBrowserStorage.inspection(response))

func _finish(history: Dictionary) -> Dictionary:
	if _kind == "preview":
		if _incremental and history.get("success",false) and not history.get("generations",[]).is_empty() and not history.get("writer_locked",false) and not history.get("pending_write",false):
			_destination_job = Backup.begin_history_validation(history,_mode)
			_destination_reason = history.get("reason","")
			if _destination_job.success:
				_result = {"success":false,"state":"pending","stage":"Checking destination history"}; return _result
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
				if _incremental:
					_task = Task.new("export",_mode,history,"",Time.get_datetime_string_from_system(true)+"Z")
					_result = {"success":false,"state":"pending","stage":"Validating history"}; return _result
				_result = Backup.create(history,_mode,Time.get_datetime_string_from_system(true)+"Z")
				if _result.success: _result["state"] = "export_ready"
	if _owns_browser:
		_browser.dispose()
		_owns_browser = false
	return _result.duplicate(true)

# Typed host handoff only; JSON/imported flags cannot create a verified reader.
func validated_preview(text: String, save_namespace: String) -> Dictionary:
	if _cancelled or _result.get("state") != "preview" or save_namespace != _mode or text != _verified_text or _verified_snapshot.is_empty() or Backup.snapshot_digest(_backup) != _verified_snapshot: return Backup.fail("backup_changed")
	return _backup.duplicate(true)

func _compare_checked_destination(checked: Dictionary) -> String:
	if not checked.success:
		return "unsupported_namespace_or_version" if checked.get("reason") in ["unsupported_format_or_version","unsupported_character_version","profile_source_or_namespace_mismatch"] else "corrupt_or_uncertain_destination"
	var local: Array = checked.records
	for index in range(mini(local.size(),_backup.history.size())):
		if local[index] != _backup.history[index]: return "divergent_history"
	if local.size() == _backup.history.size(): return "exact_match"
	return "destination_exact_prefix" if local.size() < _backup.history.size() else "backup_older_than_destination"

func _preview_result(classification: String, reason: String) -> Dictionary:
	_result = {"success":true,"state":"preview","preview":_backup.preview.duplicate(true),"classification":classification,"destination_reason":reason,"backup_digest":_backup.backup_digest,"read_only":true}
	if _owns_browser: _browser.dispose(); _owns_browser = false
	return _result

func cancel_read_only() -> void:
	_cancelled = true
	if _task != null: _task.cancel(); _task = null
	_destination_job = {}; _deferred_profile = ""; _wait_frame = false
	_backup = {}; _service = null; _storage = null
	_verified_text = ""; _verified_snapshot = ""
	if _job.is_empty(): _result = {"success":false,"state":"cancelled"}
	if _owns_browser: _browser.dispose(); _owns_browser = false

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
	if _task != null: _task.cancel(); _task = null
	_backup = {}; _destination_job = {}; _service = null; _storage = null
	_verified_text = ""; _verified_snapshot = ""
	_deferred_profile = ""; _wait_frame = false
	_result = {"success":false,"state":"cancelled" if _cancelled else "disposed"}
