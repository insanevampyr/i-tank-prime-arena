class_name CharacterSaveStorage
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const DEFAULT_ROOT := "user://character_documents"
var _root: String


func _init(isolated_test_directory: String = "") -> void:
	_root = DEFAULT_ROOT
	if not isolated_test_directory.is_empty():
		var allowed := OS.get_cache_dir().path_join("itank-storage-tests").simplify_path() + "/"
		var candidate := isolated_test_directory.replace("\\", "/").simplify_path()
		_root = candidate if candidate.begins_with(allowed) else ""


func get_storage_status() -> Dictionary:
	if _root.is_empty(): return _failure("invalid_storage_root")
	if OS.has_feature("web"):
		return {"success": false, "reason": "web_write_coordination_unverified", "state": "unverified", "persistent_userfs_available": OS.is_userfs_persistent()}
	return {"success": true, "state": "ready", "durability": "filesystem_operations_only"}


func read_profile(profile_id: String) -> Dictionary:
	if not _valid_id(profile_id): return _failure("invalid_profile_id")
	if _root.is_empty(): return _failure("invalid_storage_root")
	var directory := _root.path_join(profile_id)
	if not DirAccess.dir_exists_absolute(directory): return _failure("save_missing")
	var dir := DirAccess.open(directory)
	if dir == null: return _failure("directory_read_failed")
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name.begins_with("generation_") and name.ends_with(".json"): names.append(name)
	names.sort()
	names.reverse()
	var rejected: Array[String] = []
	for name: String in names:
		var result := _read_generation(directory.path_join(name), profile_id)
		if result.get("success", false):
			result["recovered_previous_generation"] = not rejected.is_empty()
			result["rejected_files"] = rejected
			return result
		# Future versions must never be silently downgraded to an old backup.
		if result.get("reason") in ["unsupported_format_or_version","unsupported_storage_version"]: return result
		rejected.append(name)
	return _failure("no_valid_generation" if not names.is_empty() else "save_missing")


func write_profile(profile_id: String, payload: Dictionary, transaction_id: String) -> Dictionary:
	var status := get_storage_status()
	if not status.success: return status
	if not _valid_id(profile_id) or not _valid_id(transaction_id): return _failure("invalid_identifier")
	if payload.get("character_id") != profile_id: return _failure("character_identity_mismatch")
	var encoded := Contract.encode(payload)
	if not encoded.get("success", false): return encoded
	var directory := _root.path_join(profile_id)
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return _failure("directory_create_failed")
	# Exclusive directory creation is the bounded local writer guard. Stale locks
	# fail closed; they are never removed automatically after a crash.
	var lock_path := directory.path_join("writer.lock")
	if DirAccess.make_dir_absolute(lock_path) != OK: return _failure("writer_locked")
	var result := _write_locked(directory, profile_id, payload, transaction_id, encoded.text)
	var unlock_error := DirAccess.remove_absolute(lock_path)
	if unlock_error != OK:
		result["lock_release_failed"] = true
	return result


func inspect_profile(profile_id: String) -> Dictionary:
	# Read-only history inspection; never repairs/removes evidence or locks.
	if not _valid_id(profile_id) or _root.is_empty(): return _failure("invalid_profile_id")
	var directory := _root.path_join(profile_id)
	if not DirAccess.dir_exists_absolute(directory):
		return {"success":true,"generations":[],"writer_locked":false,"pending_write":false,"profile_directory_exists":false}
	var dir := DirAccess.open(directory)
	if dir == null: return _failure("directory_read_failed")
	var records: Array = []
	var rejected: Array = []
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name.begins_with("generation_") and name.ends_with(".json"): names.append(name)
	names.sort()
	var next_generation := 1
	var transactions := {}
	for name: String in names:
		var record := _read_generation(directory.path_join(name),profile_id)
		if record.get("success",false):
			if int(record.payload.generation) != next_generation: rejected.append({"file":name,"reason":"generation_history_gap"})
			if transactions.has(record.transaction_id): rejected.append({"file":name,"reason":"duplicate_transaction_in_history"})
			transactions[record.transaction_id] = true
			next_generation = int(record.payload.generation)+1
			records.append(record)
		else:
			rejected.append({"file":name,"reason":record.get("reason","")})
	return {"success":rejected.is_empty(),"reason":"" if rejected.is_empty() else "generation_recovery_required","profile_directory_exists":true,
		"generations":records,"rejected_files":rejected,"writer_locked":DirAccess.dir_exists_absolute(directory.path_join("writer.lock")),
		"pending_write":FileAccess.file_exists(directory.path_join("write.pending"))}


func _write_locked(directory: String, profile_id: String, payload: Dictionary, transaction_id: String, text: String) -> Dictionary:
	var dir := DirAccess.open(directory)
	if dir == null: return _failure("directory_read_failed")
	for name: String in dir.get_files():
		if not name.begins_with("generation_") or not name.ends_with(".json"): continue
		var prior := _read_generation(directory.path_join(name), profile_id)
		if not prior.get("success", false):
			if prior.get("reason") in ["unsupported_format_or_version","unsupported_storage_version"]: return prior
			return _failure("generation_repair_required")
		if prior.transaction_id == transaction_id: return _failure("duplicate_transaction")
	var current := read_profile(profile_id)
	if current.get("success", false):
		var replacement := Contract.validate_replacement(current.payload, payload)
		if not replacement.get("success", false): return replacement
	elif current.get("reason") != "save_missing":
		return current
	elif int(payload.generation) != 1:
		return _failure("initial_generation_must_be_one")
	var pending := directory.path_join("write.pending")
	if FileAccess.file_exists(pending): return _failure("incomplete_write_requires_review")
	var destination := directory.path_join("generation_%016d.json" % int(payload.generation))
	if FileAccess.file_exists(destination): return _failure("generation_already_exists")
	var wrapper := JSON.stringify({"storage_version": 1, "transaction_id": transaction_id, "document": text}, "", true, true)
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null: return _failure("temporary_open_failed")
	file.store_string(wrapper)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return _failure("temporary_write_failed")
	var verified := _read_generation(pending, profile_id)
	if not verified.get("success", false) or verified.get("document") != text: return _failure("temporary_verification_failed")
	if DirAccess.rename_absolute(pending, destination) != OK: return _failure("publish_failed")
	var published := _read_generation(destination, profile_id)
	if not published.get("success", false) or published.get("document") != text: return _failure("published_verification_failed")
	return {"success": true, "generation": int(payload.generation), "transaction_id": transaction_id, "state": "filesystem_verified", "durable_power_loss_guaranteed": false}


func _read_generation(path: String, profile_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _failure("file_read_failed")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK: return _failure("invalid_storage_json")
	var parsed: Variant = parser.data
	if not parsed is Dictionary: return _failure("invalid_storage_document")
	if parsed.get("storage_version") != 1: return _failure("unsupported_storage_version")
	if typeof(parsed.get("document")) != TYPE_STRING or typeof(parsed.get("transaction_id")) != TYPE_STRING or parsed.size() != 3:
		return _failure("invalid_storage_document")
	if not _valid_id(parsed.transaction_id): return _failure("invalid_transaction_id")
	var decoded := Contract.decode(parsed.document)
	if not decoded.get("success", false): return decoded
	if decoded.payload.character_id != profile_id: return _failure("character_identity_mismatch")
	if path.get_file().ends_with(".json") and path.get_file() != "generation_%016d.json" % int(decoded.payload.generation):
		return _failure("generation_filename_mismatch")
	return {"success": true, "payload": decoded.payload, "document": parsed.document, "transaction_id": parsed.transaction_id}


static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64: return false
	for character: String in value:
		if not "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(character): return false
	return true


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
