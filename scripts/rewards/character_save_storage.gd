class_name CharacterSaveStorage
extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const DEFAULT_ROOT := "user://character_documents"
var _root: String
var _writers := {}
var _restore_fault := ""


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
	for name: String in dir.get_files():
		if name.begins_with("restoration_") and name.ends_with(".bundle"):
			var history := inspect_profile(profile_id)
			if not history.success or history.generations.is_empty(): return _failure("restoration_history_requires_review")
			return history.generations.back().duplicate(true)
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
	var guard := acquire_writer(profile_id)
	if not guard.success: return guard
	var result := _write_profile(profile_id,payload,transaction_id)
	if not release_writer(profile_id,guard.owner).success: result["lock_release_failed"] = true
	return result

func _write_profile(profile_id: String, payload: Dictionary, transaction_id: String) -> Dictionary:
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
		return {"success":true,"generations":[],"writer_locked":DirAccess.dir_exists_absolute(_writer_path(profile_id)),"pending_write":false,"profile_directory_exists":false}
	var dir := DirAccess.open(directory)
	if dir == null: return _failure("directory_read_failed")
	var records: Array = []
	var rejected: Array = []
	var names: Array[String] = []
	for name: String in dir.get_files():
		if name.begins_with("generation_") and name.ends_with(".json"): names.append(name)
	names.sort()
	var by_generation := {}
	var transactions := {}
	for name: String in names:
		var record := _read_generation(directory.path_join(name),profile_id)
		if record.get("success",false):
			by_generation[int(record.payload.generation)] = record
		else:
			rejected.append({"file":name,"reason":record.get("reason","")})
	for name: String in dir.get_files():
		if not name.begins_with("restoration_") or not name.ends_with(".bundle"): continue
		var bundle := _read_restoration(directory.path_join(name),profile_id)
		if not bundle.success:
			rejected.append({"file":name,"reason":bundle.get("reason","")})
			continue
		for record: Dictionary in bundle.records:
			var number := int(record.payload.generation)
			if by_generation.has(number) and by_generation[number] != record: rejected.append({"file":name,"reason":"conflicting_restoration_generation"})
			else: by_generation[number] = record
	var numbers := by_generation.keys()
	numbers.sort()
	for number: int in numbers:
		var record: Dictionary = by_generation[number]
		if number != records.size()+1: rejected.append({"reason":"generation_history_gap"})
		if transactions.has(record.transaction_id): rejected.append({"reason":"duplicate_transaction_in_history"})
		transactions[record.transaction_id] = true
		records.append(record)
	return {"success":rejected.is_empty(),"reason":"" if rejected.is_empty() else "generation_recovery_required","profile_directory_exists":true,
		"generations":records,"rejected_files":rejected,"writer_locked":DirAccess.dir_exists_absolute(directory.path_join("writer.lock")) or DirAccess.dir_exists_absolute(_writer_path(profile_id)),
		"pending_write":FileAccess.file_exists(directory.path_join("write.pending")) or FileAccess.file_exists(directory.path_join("restore.pending"))}


func _write_locked(directory: String, profile_id: String, payload: Dictionary, transaction_id: String, text: String) -> Dictionary:
	var dir := DirAccess.open(directory)
	if dir == null: return _failure("directory_read_failed")
	var history := inspect_profile(profile_id)
	if not history.success: return _failure("generation_recovery_required")
	if history.pending_write: return _failure("incomplete_write_requires_review")
	for record: Dictionary in history.generations:
		if record.transaction_id == transaction_id: return _failure("duplicate_transaction")
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


func _writer_path(profile: String) -> String:
	return _root.path_join(profile+".writer.lock")

func acquire_writer(profile: String) -> Dictionary:
	var status := get_storage_status()
	if not status.success: return status
	if not _valid_id(profile): return _failure("invalid_profile_id")
	if DirAccess.make_dir_recursive_absolute(_root) != OK: return _failure("storage_directory_unavailable")
	if DirAccess.make_dir_absolute(_writer_path(profile)) != OK: return _failure("writer_locked")
	var owner := Crypto.new().generate_random_bytes(16).hex_encode()
	var marker := FileAccess.open(_writer_path(profile).path_join("owner"),FileAccess.WRITE)
	if marker == null: return _failure("writer_identity_unavailable")
	marker.store_string(owner)
	marker.flush()
	var error := marker.get_error()
	marker.close()
	if error != OK or FileAccess.get_file_as_string(_writer_path(profile).path_join("owner")) != owner: return _failure("writer_identity_unverified")
	_writers[profile] = owner
	return {"success":true,"owner":owner}

func release_writer(profile: String, owner: String) -> Dictionary:
	if not _owns_writer(profile,owner): return _failure("writer_ownership_required")
	if DirAccess.remove_absolute(_writer_path(profile).path_join("owner")) != OK: return _failure("writer_release_failed")
	if DirAccess.remove_absolute(_writer_path(profile)) != OK: return _failure("writer_release_failed")
	_writers.erase(profile)
	return {"success":true}

func inspect_owned(profile: String, owner: String) -> Dictionary:
	if not _owns_writer(profile,owner): return _failure("writer_ownership_required")
	var history := inspect_profile(profile)
	# Only this new outer guard is ours; legacy/stale locks remain a blocker.
	if history.success: history.writer_locked = DirAccess.dir_exists_absolute(_root.path_join(profile).path_join("writer.lock"))
	return history

func _owns_writer(profile: String, owner: String) -> bool:
	var path := _writer_path(profile).path_join("owner")
	return _writers.get(profile) == owner and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == owner

func restore_history(profile: String, records: Array, expected: Array, owner: String) -> Dictionary:
	var before := inspect_owned(profile,owner)
	if not before.get("success",false) or before.writer_locked or before.pending_write: return _failure("restoration_destination_uncertain")
	var actual := history_records(before)
	if actual == records: return {"success":true,"state":"filesystem_verified","reconciled":true}
	if actual != expected or records.size() <= actual.size() or records.slice(0,actual.size()) != actual: return _failure("restoration_history_conflict")
	# Defense in depth at the publication boundary, using the same full validator.
	var checked := CharacterBackupContract.validate_history({"success":true,"generations":records},"dev_normal" if profile.begins_with("dev_") else "normal")
	if not checked.success or checked.payload.character_id != profile: return _failure("invalid_restoration_history")
	var directory := _root.path_join(profile)
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return _failure("directory_create_failed")
	var pending := directory.path_join("restore.pending")
	var body := JSON.stringify(records,"",true,true)
	var digest := body.sha256_text()
	var destination := directory.path_join("restoration_%s.bundle" % digest)
	if _restore_fault == "abort": return _failure("injected_restoration_abort")
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return _failure("restoration_output_unavailable")
	file.store_string(JSON.stringify({"restoration_version":1,"body_json":body,"sha256":digest},"",true,true))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _restore_fault == "interrupted": return _failure("restoration_incomplete_recovery_required")
	var staged := _read_restoration(pending,profile)
	if not staged.success or history_records({"generations":staged.records}) != records: return _failure("restoration_staging_mismatch")
	if DirAccess.rename_absolute(pending,destination) != OK: return _failure("restoration_publication_failed")
	if _restore_fault == "lost_ack": return _failure("restoration_acknowledgement_lost")
	var after := inspect_owned(profile,owner)
	if _restore_fault == "readback_mismatch" or not after.success or history_records(after) != records: return _failure("restoration_readback_mismatch")
	return {"success":true,"state":"filesystem_verified","durable_power_loss_guaranteed":false}

func inject_restoration_test_fault(fault: String) -> bool:
	if _root == DEFAULT_ROOT or _root.is_empty(): return false
	_restore_fault = fault
	return true

static func history_records(history: Dictionary) -> Array:
	var records: Array = []
	for row: Dictionary in history.get("generations",[]):
		records.append({"generation":int(row.get("generation",row.get("payload",{}).get("generation",0))),"transaction_id":row.transaction_id,"document":row.document})
	return records

func _read_restoration(path: String, profile: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _failure("restoration_unreadable")
	if file.get_length() > 16*1024*1024: return _failure("restoration_size_limit")
	var wrapper: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not wrapper is Dictionary or wrapper.size() != 3 or wrapper.get("restoration_version") != 1 or not wrapper.get("body_json") is String or wrapper.body_json.sha256_text() != wrapper.get("sha256"): return _failure("invalid_restoration_bundle")
	if path.ends_with(".bundle") and path.get_file() != "restoration_%s.bundle" % wrapper.sha256: return _failure("restoration_filename_mismatch")
	var rows: Variant = JSON.parse_string(wrapper.body_json)
	if not rows is Array or rows.is_empty(): return _failure("invalid_restoration_records")
	var records: Array = []
	for row: Variant in rows:
		if not row is Dictionary or not row.get("document") is String or not row.get("transaction_id") is String or not _valid_id(row.transaction_id): return _failure("invalid_restoration_record")
		var decoded := Contract.decode(row.document)
		if not decoded.success or decoded.payload.character_id != profile or decoded.payload.generation != records.size()+1 or row.get("generation") != decoded.payload.generation: return _failure("invalid_restoration_generation")
		records.append({"success":true,"payload":decoded.payload,"transaction_id":row.transaction_id,"document":row.document})
	return {"success":true,"records":records}

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
