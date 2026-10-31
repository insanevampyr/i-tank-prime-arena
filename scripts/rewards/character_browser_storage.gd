class_name CharacterBrowserStorage
extends RefCounted

# Infrastructure only: neither this adapter nor the asynchronous coordinator is
# constructed by playable persistence. Desktop CharacterSaveStorage is unchanged.
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const SCRIPT_PATH := "res://scripts/rewards/character_browser_store.js"
var _bridge: JavaScriptObject
var _handle := ""
var _transport: Callable
var _testing := false
var _test_publish_fault := ""

func _init(test_transport: Callable = Callable(), test_database: String = "") -> void:
	_transport = test_transport
	_testing = _transport.is_valid() or test_database.begins_with("itank-arena-test-36k-")
	if _transport.is_valid() or not OS.has_feature("web"): return
	JavaScriptBridge.eval(FileAccess.get_file_as_string(SCRIPT_PATH),true)
	_bridge = JavaScriptBridge.get_interface("ArenaCharacterBrowserStorage")
	if _bridge == null: return
	var config := {}
	if not test_database.is_empty():
		if not test_database.begins_with("itank-arena-test-36k-"): return
		config = {"testing":true,"database":test_database}
	_handle = str(_bridge.create(JSON.stringify(config)))

func begin(operation: String, arguments: Dictionary) -> Dictionary:
	if _testing and operation == "publish" and not _test_publish_fault.is_empty():
		arguments = arguments.duplicate(true)
		arguments["fault"] = _test_publish_fault
		_test_publish_fault = ""
	if _transport.is_valid(): return _transport.call("begin",{"operation":operation,"arguments":arguments.duplicate(true)})
	if _bridge == null or _handle.is_empty(): return status("unavailable","browser_storage_unavailable")
	var job := str(_bridge.request(_handle,operation,JSON.stringify(arguments)))
	if job.is_empty(): return status("unavailable","browser_queue_unavailable")
	return {"success":false,"state":"pending","reason":"operation_pending","job":job}

func inject_test_fault(fault: String) -> bool:
	if not _testing: return false
	_test_publish_fault = fault
	return true

func poll(job: String) -> Dictionary:
	var response: Variant
	if _transport.is_valid(): response = _transport.call("poll",{"job":job})
	elif _bridge != null: response = JSON.parse_string(str(_bridge.poll(_handle,job)))
	else: return status("unavailable","browser_storage_unavailable")
	if not response is Dictionary or not response.get("state","") in ["pending","verified_committed","failed","unavailable","recovery_required"]: return status("recovery_required","invalid_browser_response")
	return response.duplicate(true)

# Decode every canonical document with the SAME contract as desktop, not a JS
# approximation of character validation. Transport errors never mean missing.
static func inspection(response: Dictionary, profile: String = "") -> Dictionary:
	if response.get("state") != "verified_committed" or not response.get("success",false): return response
	if not response.get("generations") is Array: return status("recovery_required","browser_history_missing")
	var records: Array = []
	var seen := {}
	for record: Variant in response.generations:
		if not record is Dictionary or not record.has_all(["document","transaction_id","generation"]) or not record.document is String: return status("recovery_required","invalid_browser_record")
		var decoded := Contract.decode(record.document)
		if not decoded.get("success",false): return status("recovery_required",decoded.get("reason","invalid_contract"))
		if not profile.is_empty() and decoded.payload.character_id != profile: return status("recovery_required","browser_profile_mismatch")
		if decoded.payload.generation != records.size()+1 or decoded.payload.generation != record.generation or seen.has(record.transaction_id): return status("recovery_required","browser_history_mismatch")
		if not records.is_empty() and not Contract.validate_replacement(records.back().payload,decoded.payload).get("success",false): return status("recovery_required","browser_history_continuity_failed")
		seen[record.transaction_id] = true
		records.append({"document":record.document,"transaction_id":record.transaction_id,"payload":decoded.payload})
	if bool(response.get("missing",false)) != records.is_empty(): return status("recovery_required","ambiguous_browser_history")
	return {"success":true,"generations":records,"writer_locked":false,"pending_write":false}

func dispose() -> void:
	# Asynchronously drains already-authorized bridge work, then releases leases.
	# It does not acknowledge a save or require a live Godot polling callback.
	if _bridge != null and not _handle.is_empty(): _bridge.dispose(_handle)

static func status(state: String, reason: String) -> Dictionary:
	return {"success":state == "verified_committed","state":state,"reason":reason}
