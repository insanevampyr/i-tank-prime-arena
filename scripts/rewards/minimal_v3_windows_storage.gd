extends RefCounted

# Disposable 46I transport ONLY. Existing coordinator owns gameplay authority.
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Scan = preload("res://scripts/rewards/character_backup_contract.gd")
const FORMAT := "itank_arena_disposable_v3_windows_head"
const KEYS := ["format","layout_version","reader_version","record_version","profile","namespace","source_digest","epoch","sequence","commit_id","record_sha256","record_bytes"]
var root := ""
var profile := ""
var scope := ""
var source: CombatCharacterDefinitionResource
var executable := ""
var executable_hash := ""
var guard: CharacterSaveStorage
var diagnostic_hook: Callable
var fault := ""
var _first_attempt := ""
var _empty_owned := false

func _init(path: String, definition: CombatCharacterDefinitionResource, identity: String, namespace_id: String, exe: String, digest: String) -> void:
	var p := path.replace("\\","/").simplify_path()
	var parent := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests")
	var e := exe.replace("\\","/").simplify_path()
	if OS.get_name() != "Windows" or OS.has_feature("web") or p.get_base_dir() != parent or not p.get_file().begins_with("minimal46i1_"): return
	if definition == null or not CharacterSaveStorage._valid_id(identity) or namespace_id not in ["normal","dev_normal"]: return
	if not e.begins_with(OS.get_environment("TEMP").replace("\\","/").path_join("arena46i1_")) or e.get_file() != "safe_head_replace.exe" or not V3.V6._hash(digest) or FileAccess.get_sha256(e) != digest: return
	root = p; profile = identity; scope = namespace_id; source = definition.duplicate(true)
	executable = e; executable_hash = digest
	guard = CharacterSaveStorage.new(root.path_join("ownership"))

func valid() -> bool:
	return not root.is_empty() and guard != null and FileAccess.get_sha256(executable) == executable_hash

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"state":"recovery_required","reason":reason,"details":details,"durable_power_loss_guaranteed":false}

func acquire() -> Dictionary:
	if not valid(): return fail("invalid_disposable_windows_context")
	var virgin := not DirAccess.dir_exists_absolute(root) or (DirAccess.get_files_at(root).is_empty() and DirAccess.get_directories_at(root).is_empty())
	var lease := guard.acquire_writer(profile)
	if lease.success: _empty_owned = virgin
	return lease

func release(owner: String) -> Dictionary:
	_empty_owned = false
	return guard.release_writer(profile,owner) if valid() else fail("invalid_disposable_windows_context")

func _owned(owner: String) -> bool:
	return valid() and guard._owns_writer(profile,owner)

func _read(name: String, limit: int) -> Dictionary:
	if not valid() or name.get_file() != name: return fail("invalid_disposable_windows_context")
	var f := FileAccess.open(root.path_join(name),FileAccess.READ)
	if f == null: return fail("file_missing",{"name":name})
	if f.get_length() > limit: f.close(); return fail("file_size_limit")
	var data := f.get_buffer(f.get_length()); var error := f.get_error(); f.close()
	var text := data.get_string_from_utf8()
	return {"success":true,"text":text} if error == OK and text.to_utf8_buffer() == data else fail("invalid_file_bytes")

func _write(name: String, text: String) -> bool:
	if not valid() or name.get_file() != name: return false
	var f := FileAccess.open(root.path_join(name),FileAccess.WRITE)
	if f == null: return false
	var ok := f.store_string(text); f.flush(); var error := f.get_error(); f.close()
	var read := _read(name,maxi(65536,V3.V1.MAX_FILE_BYTES))
	return ok and error == OK and read.success and read.text == text

func _step(at: String) -> bool:
	if diagnostic_hook.is_valid(): diagnostic_hook.call(at)
	return fault != at

func _head_text(snapshot: RefCounted, text: String) -> String:
	var b: Dictionary = snapshot.copy()
	var h := {"format":FORMAT,"layout_version":1,"reader_version":3,"record_version":3,"profile":profile,"namespace":scope,"source_digest":b.source_digest,"epoch":b.epoch,"sequence":b.sequence,"commit_id":b.last_operation_id,"record_sha256":text.sha256_text(),"record_bytes":text.to_utf8_buffer().size()}
	var body := JSON.stringify(h,"",true,true)
	return JSON.stringify({"body":body,"sha256":body.sha256_text()},"",true,true)

func _head() -> Dictionary:
	var raw := _read("head.bin",65536)
	if not raw.success: return fail("acknowledged_head_missing",raw)
	if not Scan.scan_json(raw.text,65536).success: return fail("invalid_head_json")
	var outer: Variant = JSON.parse_string(raw.text)
	if not outer is Dictionary or not Scan.keys(outer,["body","sha256"]) or not outer.body is String or outer.sha256 != outer.body.sha256_text() or not Scan.scan_json(outer.body,65536).success: return fail("invalid_head_checksum")
	var h: Variant = V3.Contract._normalize_json_numbers(JSON.parse_string(outer.body))
	if not h is Dictionary or not Scan.keys(h,KEYS) or h.format != FORMAT or h.layout_version != 1 or h.reader_version != 3 or h.record_version != 3 or h.profile != profile or h.namespace != scope or h.source_digest != V3.V6.digest(source.to_dictionary()): return fail("unsupported_or_conflicting_head")
	if not V3.V6._uint(h.sequence) or h.sequence < 1 or not h.epoch is String or h.epoch.is_empty() or not h.commit_id is String or h.commit_id.is_empty() or not V3.V6._hash(h.record_sha256) or not V3.V6._uint(h.record_bytes) or h.record_bytes > V3.V1.MAX_FILE_BYTES: return fail("invalid_head_fields")
	if JSON.stringify(h,"",true,true) != outer.body or JSON.stringify(outer,"",true,true) != raw.text: return fail("noncanonical_head")
	return {"success":true,"head":h,"head_text":raw.text}

func _data_names() -> Array[String]:
	var names: Array[String] = []
	for n: String in DirAccess.get_files_at(root):
		if (n.begins_with("current_") or n.begins_with("replica_")) and n.ends_with(".json"): names.append(n)
	return names

func load_current() -> Dictionary:
	if not valid(): return fail("invalid_disposable_windows_context")
	var started := Time.get_ticks_usec()
	if not DirAccess.dir_exists_absolute(root): return {"success":true,"empty":true,"head_text":""}
	# A missing head in a used directory is never proof of a new character, even
	# if both data files are gone. Only a genuinely empty root is virgin.
	if not FileAccess.file_exists(root.path_join("head.bin")) and DirAccess.get_files_at(root).is_empty() and DirAccess.get_directories_at(root).is_empty(): return {"success":true,"empty":true,"head_text":""}
	var selected := _head()
	if not selected.success: return selected
	var h: Dictionary = selected.head
	var c := _read("current_"+h.record_sha256+".json",V3.V1.MAX_FILE_BYTES)
	var r := _read("replica_"+h.record_sha256+".json",V3.V1.MAX_FILE_BYTES)
	var good_c: bool = c.success and c.text.to_utf8_buffer().size() == h.record_bytes and c.text.sha256_text() == h.record_sha256
	var good_r: bool = r.success and r.text.to_utf8_buffer().size() == h.record_bytes and r.text.sha256_text() == h.record_sha256
	if not good_c and not good_r: return fail("both_latest_copies_damaged")
	var text: String = c.text if good_c else r.text
	if good_c and good_r and c.text != r.text: return fail("latest_replica_conflict")
	var decoded := V3.decode(text,source,profile,scope)
	if not decoded.success: return fail("selected_record_invalid",decoded)
	if _head_text(decoded.snapshot,text) != selected.head_text: return fail("selected_record_head_mismatch")
	var fresh := _head()
	if not fresh.success or fresh.head_text != selected.head_text: return fail("head_changed_during_readback")
	return selected.merged({"empty":false,"text":text,"snapshot":decoded.snapshot,"repair_current":not good_c,"repair_replica":not good_r,"cold_readback_us":Time.get_ticks_usec()-started})

func _stage_pair(name: String, text: String) -> bool:
	var pending := name.get_slice("_",0)+".pending"
	if fault == "disk_full_"+pending: return false # Explicit injected I/O failure only.
	if not _write(pending,text) or not _step("staged_"+pending): return false
	if FileAccess.file_exists(root.path_join(name)):
		var existing := _read(name,V3.V1.MAX_FILE_BYTES)
		if not existing.success or existing.text != text: return false
		return DirAccess.remove_absolute(root.path_join(pending)) == OK
	# Destination is absent under ownership. Never use Godot replacement rename.
	return DirAccess.rename_absolute(root.path_join(pending),root.path_join(name)) == OK

func publish(text: String, expected: String, owner: String) -> Dictionary:
	if not _owned(owner): return fail("writer_ownership_required")
	var started := Time.get_ticks_usec()
	var candidate := V3.decode(text,source,profile,scope)
	if not candidate.success: return fail("invalid_candidate",candidate)
	var head_text := _head_text(candidate.snapshot,text)
	var digest := text.sha256_text()
	var current := load_current()
	if current.success and not current.get("empty",false) and current.head_text == head_text and current.text == text:
		if current.repair_current or current.repair_replica: return fail("exact_retry_requires_repair")
		return current.merged({"exact_retry":true,"publication_us":Time.get_ticks_usec()-started})
	if not current.success:
		# Only an existing in-memory first attempt can resume its own unacknowledged
		# pair. Cold missing-head admission NEVER picks one of these files.
		if expected != "" or (not _empty_owned and _first_attempt != digest) or FileAccess.file_exists(root.path_join("head.bin")): return current
		for n: String in _data_names():
			if n not in ["current_"+digest+".json","replica_"+digest+".json"]: return fail("unknown_unacknowledged_data")
	else:
		if current.head_text != expected: return fail("stale_expected_head")
		if not current.get("empty",false):
			if current.repair_current or current.repair_replica: return fail("repair_required_before_publication")
			var extension := V3.validate_extension(current.snapshot.copy(),candidate.snapshot.copy(),source,profile,scope)
			if not extension.success: return fail("invalid_candidate_extension",extension)
	var validation_us := Time.get_ticks_usec()-started
	if expected.is_empty(): _first_attempt = digest
	if not _step("before_pair"): return fail("injected_before_pair")
	if not _stage_pair("current_"+digest+".json",text): return fail("current_stage_failed")
	if not _step("current_published"): return fail("injected_current_published")
	if not _stage_pair("replica_"+digest+".json",text): return fail("replica_stage_failed")
	if not _step("replica_published"): return fail("injected_replica_published")
	if fault == "disk_full_head" or not _write("stage.bin",head_text) or (not expected.is_empty() and not _write("expected.bin",expected)): return fail("head_stage_failed")
	if not _step("head_staged"): return fail("injected_head_staged")
	# The existing outer lease spans pair staging, native CAS and readback.
	var before := _head() if not expected.is_empty() else {"success":not FileAccess.file_exists(root.path_join("head.bin")),"head_text":""}
	if not before.success or before.head_text != expected: return fail("head_changed_before_native")
	if not _step("before_native"): return fail("injected_before_native")
	var output: Array = []
	var native_started := Time.get_ticks_usec()
	var exit_code := OS.execute(executable,["first" if expected.is_empty() else "replace",root,"none"],output,true)
	var native_us := Time.get_ticks_usec()-native_started
	var response: Variant = JSON.parse_string(str(output[0])) if output.size() == 1 else null
	if not _step("after_native"): return fail("injected_response_lost",{"exit_code":exit_code})
	# Regardless of a native response, only full independent current/head/pair
	# readback can establish this exact commit. Unknown results remain pending.
	var loaded := load_current()
	if not loaded.success or loaded.get("empty",true) or loaded.head_text != head_text or loaded.text != text or loaded.repair_current or loaded.repair_replica: return fail("publication_unverified",{"native":response,"readback":loaded})
	if not _step("after_readback"): return fail("injected_readback_response_lost")
	return loaded.merged({"native":response,"native_exit":exit_code,"validation_us":validation_us,"native_us":native_us,"publication_us":Time.get_ticks_usec()-started,"exact_retry":false})

func maintain(owner: String, expected: String) -> Dictionary:
	if not _owned(owner): return fail("writer_ownership_required")
	var loaded := load_current()
	if not loaded.success or loaded.get("empty",true) or loaded.head_text != expected or loaded.repair_current or loaded.repair_replica: return fail("maintenance_head_unverified")
	if not _step("before_maintenance"): return fail("injected_before_maintenance")
	var keep := ["current_"+loaded.head.record_sha256+".json","replica_"+loaded.head.record_sha256+".json"]
	for name: String in _data_names():
		var suffix := name.trim_prefix("current_").trim_prefix("replica_").trim_suffix(".json")
		if name not in keep and V3.V6._hash(suffix) and DirAccess.remove_absolute(root.path_join(name)) != OK: return fail("bounded_cleanup_failed")
	for name: String in ["current.pending","replica.pending","repair.pending","stage.bin","expected.bin"]:
		if FileAccess.file_exists(root.path_join(name)) and DirAccess.remove_absolute(root.path_join(name)) != OK: return fail("staging_cleanup_failed")
	if not _step("after_maintenance"): return fail("injected_after_maintenance")
	return {"success":true,"retained_character_files":3}

func recover() -> Dictionary:
	var acquired := acquire()
	if not acquired.success: return acquired
	var result := _recover_owned(acquired.owner)
	var released := release(acquired.owner)
	return result if released.success else fail("recovery_release_failed")

func _recover_owned(owner: String) -> Dictionary:
	if not _owned(owner): return fail("writer_ownership_required")
	var started := Time.get_ticks_usec()
	var loaded := load_current()
	if not loaded.success or loaded.get("empty",true): return loaded
	for prefix: String in ["current","replica"]:
		if not loaded["repair_"+prefix]: continue
		var dest := root.path_join(prefix+"_"+loaded.head.record_sha256+".json")
		if not _write("repair.pending",loaded.text): return fail("repair_stage_failed")
		var fresh := _head()
		if not fresh.success or fresh.head_text != loaded.head_text: return fail("head_changed_before_repair")
		# Only the proven-bad copy is removed; the exact other selected copy and
		# head stay intact throughout repair. Never delete an intact authority.
		if FileAccess.file_exists(dest) and DirAccess.remove_absolute(dest) != OK: return fail("damaged_copy_removal_failed")
		if DirAccess.rename_absolute(root.path_join("repair.pending"),dest) != OK: return fail("exact_repair_failed")
	var verified := load_current()
	if not verified.success or verified.head_text != loaded.head_text or verified.repair_current or verified.repair_replica: return fail("repair_readback_failed")
	return verified.merged({"recovery_us":Time.get_ticks_usec()-started})
