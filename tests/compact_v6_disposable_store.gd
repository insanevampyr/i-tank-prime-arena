extends RefCounted

# Pass C only. Cache-gated transport, never a playable persistence backend.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const LegacyStorage = preload("res://scripts/rewards/character_save_storage.gd")
var root := ""
var source: CombatCharacterDefinitionResource
var profile := ""
var save_namespace := ""
var guard: CharacterSaveStorage

static func allowed(path: String) -> bool:
	var normalized := path.replace("\\","/").simplify_path()
	return normalized.is_absolute_path() and normalized.to_lower().begins_with(OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45m_").to_lower())

func _init(directory: String, definition: CombatCharacterDefinitionResource, identity: String, scope: String) -> void:
	if allowed(directory) and LegacyStorage._valid_id(identity) and scope in ["normal","dev_normal"] and not OS.has_feature("web"):
		root = directory.replace("\\","/").simplify_path()
		source = definition; profile = identity; save_namespace = scope
		guard = LegacyStorage.new(root)

func _fail(reason: String, extra: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"state":"recovery_required","power_loss_durability_proven":false}.merged(extra,true)

func _write(path: String, text: String) -> bool:
	if not allowed(root) or not path.simplify_path().begins_with(root+"/"): return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(text); file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and FileAccess.get_file_as_string(path) == text

func _read(path: String) -> Dictionary:
	if not allowed(root) or not path.simplify_path().begins_with(root+"/"): return _fail("invalid_disposable_root")
	if not FileAccess.file_exists(path): return _fail("file_missing")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _fail("read_failed")
	if file.get_length() > V6.MAX_BYTES: file.close(); return _fail("file_size_limit")
	var text := file.get_as_text(); var error := file.get_error(); file.close()
	return {"success":true,"text":text} if error == OK else _fail("read_failed")

func _file(digest: String) -> String:
	return root.path_join("record_"+digest+".v6")

func _head() -> Dictionary:
	var raw := _read(root.path_join("head.json"))
	if not raw.success: return raw
	var parser := JSON.new()
	if parser.parse(raw.text) != OK: return _fail("head_integrity_failed")
	var outer: Variant = parser.data
	if not outer is Dictionary or outer.size() != 2 or not outer.get("body") is String or outer.get("sha256") != outer.body.sha256_text(): return _fail("head_integrity_failed")
	if parser.parse(outer.body) != OK: return _fail("head_integrity_failed")
	var head: Variant = CharacterSaveContract._normalize_json_numbers(parser.data)
	if not head is Dictionary or head.size() != 7 or not head.has_all(["version","profile","namespace","epoch","sequence","digest","previous"]) or head.version != 1 or head.profile != profile or head.namespace != save_namespace or not V6._hash(head.digest) or (head.previous != null and not V6._hash(head.previous)) or not V6._uint(head.sequence) or head.sequence < 1: return _fail("head_identity_failed")
	return {"success":true,"head":head}

func _document(text: String) -> Dictionary:
	var decoded := V6.decode(text,source)
	if not decoded.success: return _fail("invalid_compact_document",{"validation":decoded})
	if decoded.record.current.character_id != profile or decoded.record.current.profile_namespace != save_namespace: return _fail("profile_identity_mismatch")
	return decoded

func load_current() -> Dictionary:
	if not allowed(root): return _fail("invalid_disposable_root")
	var start := Time.get_ticks_usec()
	var head := _head()
	if not head.success: return head
	var raw := _read(_file(head.head.digest))
	if not raw.success or raw.text.sha256_text() != head.head.digest: return _fail("latest_record_damaged",{"head":head.head})
	var decoded := _document(raw.text)
	if not decoded.success: return decoded
	if decoded.record.head.sequence != head.head.sequence or decoded.record.head.epoch != head.head.epoch: return _fail("committed_identity_mismatch")
	return {"success":true,"record":decoded.record,"text":raw.text,"head":head.head,"load_ms":float(Time.get_ticks_usec()-start)/1000.0}

func previous_diagnostic() -> Dictionary:
	if not allowed(root): return _fail("invalid_disposable_root")
	var head := _head()
	if not head.success or head.head.previous == null: return _fail("previous_record_unavailable")
	var raw := _read(_file(head.head.previous))
	if not raw.success or raw.text.sha256_text() != head.head.previous: return _fail("previous_record_damaged")
	var decoded := _document(raw.text)
	if not decoded.success: return decoded
	return {"success":true,"diagnostic_only":true,"is_current":false,"record":decoded.record}

func publish(text: String, expected: Variant, fault: String = "") -> Dictionary:
	if not allowed(root): return _fail("invalid_disposable_root")
	if fault not in ["","before_stage","partial_stage","after_stage","partial_head","head_staged","after_publish","lost_ack","orphan_writer"]: return _fail("unknown_fault")
	var acquired := guard.acquire_writer(profile)
	if not acquired.success: return acquired
	_write(root.path_join("writer_pid.json"),JSON.stringify({"pid":OS.get_process_id(),"owner":acquired.owner}))
	var result := _publish_locked(text,expected,fault)
	if fault != "orphan_writer":
		DirAccess.remove_absolute(root.path_join("writer_pid.json"))
		guard.release_writer(profile,acquired.owner)
	return result

func _publish_locked(text: String, expected: Variant, fault: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var candidate := _document(text)
	if not candidate.success: return candidate
	var digest := text.sha256_text()
	var before := _head()
	var current := {}
	if before.success:
		current = load_current()
		if not current.success: return current
		if digest == current.head.digest: return current.merged({"already_applied":true})
		var id: String = candidate.record.operations.back().id
		for operation: Dictionary in current.record.operations:
			if operation.id == id: return _fail("transaction_already_applied" if operation == candidate.record.operations.back() else "transaction_id_conflict")
		if expected != {"sequence":current.head.sequence,"digest":current.head.digest}: return _fail("stale_expected_head")
		var extension := V6.validate_extension(current.record,candidate.record,source)
		if not extension.success: return _fail("invalid_extension",{"validation":extension})
	else:
		if expected != null or FileAccess.file_exists(root.path_join("head.json")): return _fail("unknown_or_existing_head")
		for name: String in DirAccess.get_files_at(root):
			if name.begins_with("record_") and (name != "record_"+digest+".v6" or FileAccess.get_file_as_string(root.path_join(name)) != text): return _fail("unknown_or_existing_head")
		if candidate.record.head.sequence != 1 or candidate.record.head.parent_digest != null: return _fail("initial_baseline_required")
	return _install_verified(text,candidate,current,fault,started)

# Shared staged publication, used only after Pass C/D semantic validation.
func _install_verified(text: String, candidate: Dictionary, current: Dictionary, fault: String, started: int) -> Dictionary:
	var digest := text.sha256_text()
	if fault == "before_stage": return _fail("injected_before_stage")
	var pending := root.path_join("record.pending")
	if fault == "partial_stage": _write(pending,text.left(text.length()/2)); return _fail("injected_partial_stage")
	if not _write(pending,text) or not _document(FileAccess.get_file_as_string(pending)).success: return _fail("stage_verification_failed")
	if DirAccess.rename_absolute(pending,_file(digest)) != OK: return _fail("record_publish_failed")
	if fault == "after_stage": return _fail("injected_after_stage")
	var head := {"version":1,"profile":profile,"namespace":save_namespace,"epoch":candidate.record.head.epoch,"sequence":candidate.record.head.sequence,"digest":digest,"previous":current.get("head",{}).get("digest")}
	var body := JSON.stringify(head,"",true,true)
	var marker := JSON.stringify({"body":body,"sha256":body.sha256_text()},"",true,true)
	if fault == "partial_head": _write(root.path_join("head.pending"),marker.left(marker.length()/2)); return _fail("injected_partial_head")
	if not _write(root.path_join("head.pending"),marker): return _fail("head_stage_failed")
	if fault == "head_staged": return _fail("injected_head_staged")
	# One publication point. Record staging and cleanup are not claimed atomic.
	if DirAccess.rename_absolute(root.path_join("head.pending"),root.path_join("head.json")) != OK: return _fail("head_publish_failed")
	if fault in ["after_publish","orphan_writer"]: return _fail("injected_after_publish")
	var verify_started := Time.get_ticks_usec()
	var readback := load_current()
	if not readback.success or readback.text != text or readback.head != head: return _fail("readback_not_verified")
	_prune(head)
	if fault == "lost_ack": return _fail("acknowledgement_lost")
	return readback.merged({"save_ms":float(Time.get_ticks_usec()-started)/1000.0,"readback_ms":float(Time.get_ticks_usec()-verify_started)/1000.0,"power_loss_durability_proven":false})

func recover() -> Dictionary:
	if not allowed(root): return _fail("invalid_disposable_root")
	var start := Time.get_ticks_usec()
	var pid_file := root.path_join("writer_pid.json")
	var lock_dir := root.path_join(profile+".writer.lock")
	if DirAccess.dir_exists_absolute(lock_dir):
		if not FileAccess.file_exists(pid_file): return _fail("writer_still_active_or_unverified")
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(pid_file)) != OK: return _fail("writer_still_active_or_unverified")
		var owner: Variant = parser.data
		if not owner is Dictionary or not owner.get("pid") is float or not owner.get("owner") is String or OS.is_process_running(int(owner.pid)) or FileAccess.get_file_as_string(lock_dir.path_join("owner")) != owner.owner: return _fail("writer_still_active_or_unverified")
		DirAccess.remove_absolute(lock_dir.path_join("owner")); DirAccess.remove_absolute(lock_dir); DirAccess.remove_absolute(pid_file)
	var acquired := guard.acquire_writer(profile)
	if not acquired.success: return acquired
	var loaded := load_current()
	if loaded.success: _prune(loaded.head)
	guard.release_writer(profile,acquired.owner)
	return loaded.merged({"recovery_ms":float(Time.get_ticks_usec()-start)/1000.0})

func repair_exact(text: String) -> Dictionary:
	if not allowed(root): return _fail("invalid_disposable_root")
	var acquired := guard.acquire_writer(profile)
	if not acquired.success: return acquired
	var head := _head()
	var result := _fail("exact_acknowledged_record_required")
	if head.success and text.sha256_text() == head.head.digest and _document(text).success:
		if _write(root.path_join("repair.pending"),text) and DirAccess.rename_absolute(root.path_join("repair.pending"),_file(head.head.digest)) == OK: result = load_current()
	guard.release_writer(profile,acquired.owner)
	return result

func _prune(head: Dictionary) -> void:
	for name: String in DirAccess.get_files_at(root):
		if name in ["record.pending","head.pending","repair.pending"]: DirAccess.remove_absolute(root.path_join(name))
		elif name.begins_with("record_") and name.ends_with(".v6"):
			var digest := name.trim_prefix("record_").trim_suffix(".v6")
			if V6._hash(digest) and digest != head.digest and digest != head.previous: DirAccess.remove_absolute(root.path_join(name))
