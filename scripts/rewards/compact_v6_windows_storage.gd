extends RefCounted

# Dormant S4. No default production root; only explicitly constructed cache tests.
# Filesystem transport, not a mutation authority. The existing coordinator owns
# preparation, authorization, the lease, publication and acknowledgement.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Portable = preload("res://scripts/rewards/compact_v6_portable.gd")
const Scan = preload("res://scripts/rewards/character_backup_contract.gd")
var root := ""
var profile := ""
var scope := ""
var source: CombatCharacterDefinitionResource
var guard: CharacterSaveStorage
var directory := ""
var objects := ""

static func allowed(path: String) -> bool:
	var p := path.replace("\\","/").simplify_path()
	return p.is_absolute_path() and p.to_lower().begins_with(OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45s_").to_lower()) and not OS.has_feature("web")

func _init(path: String, definition: CombatCharacterDefinitionResource, identity: String, save_namespace: String) -> void:
	if not allowed(path) or definition == null or not CharacterSaveStorage._valid_id(identity) or save_namespace not in ["normal","dev_normal"]: return
	root = path.replace("\\","/").simplify_path(); source = definition; profile = identity; scope = save_namespace
	directory = root.path_join(profile); objects = directory.path_join("compact")
	guard = CharacterSaveStorage.new(root)

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"state":"recovery_required","details":details,"durable_power_loss_guaranteed":false}

func valid_context() -> bool:
	return allowed(root) and guard != null and guard._root == root and CharacterSaveStorage._valid_id(profile) and scope in ["normal","dev_normal"] and source != null and directory == root.path_join(profile) and objects == directory.path_join("compact")

func _write(path: String, text: String) -> bool:
	if not valid_context() or not path.simplify_path().begins_with(directory+"/"): return false
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null: return false
	f.store_string(text); f.flush(); var err := f.get_error(); f.close()
	return err == OK and FileAccess.get_file_as_string(path) == text

func _rename(a: String, b: String) -> bool:
	return valid_context() and a.simplify_path().begins_with(directory+"/") and b.simplify_path().begins_with(directory+"/") and DirAccess.rename_absolute(a,b) == OK

func _read(path: String, limit: int = Portable.MAX_BYTES) -> Dictionary:
	if not valid_context() or not path.simplify_path().begins_with(directory+"/"): return fail("invalid_disposable_root")
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null: return fail("file_missing")
	if f.get_length() > limit: f.close(); return fail("file_size_limit")
	var b := f.get_buffer(f.get_length()); var err := f.get_error(); f.close()
	var text := b.get_string_from_utf8()
	return {"success":true,"text":text} if err == OK and text.to_utf8_buffer() == b else fail("invalid_file_bytes")

func _pack(body: Dictionary) -> String:
	var text := V6.digest(body) # Envelope digest is not authority.
	return JSON.stringify({"body":JSON.stringify(body,"",true,true),"sha256":text},"",true,true)

func _unpack(text: String) -> Dictionary:
	if not Scan.scan_json(text,V6.MAX_BYTES).success: return fail("invalid_manifest_json")
	var v: Variant = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(text))
	if not v is Dictionary or not Scan.keys(v,["body","sha256"]) or not v.body is String or v.sha256 != v.body.sha256_text() or not Scan.scan_json(v.body,V6.MAX_BYTES).success: return fail("manifest_integrity_failed")
	var body: Variant = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(v.body))
	return {"success":true,"body":body} if body is Dictionary and JSON.stringify(body,"",true,true) == v.body else fail("invalid_manifest")

func acquire() -> Dictionary:
	if not valid_context(): return fail("invalid_disposable_root")
	var outer := guard.acquire_writer(profile)
	if not outer.success: return outer
	if DirAccess.make_dir_recursive_absolute(directory) != OK or DirAccess.make_dir_absolute(directory.path_join("writer.lock")) != OK:
		guard.release_writer(profile,outer.owner)
		return fail("legacy_writer_locked")
	return outer

func release(owner: String) -> Dictionary:
	if not guard._owns_writer(profile,owner): return fail("writer_ownership_required")
	if DirAccess.remove_absolute(directory.path_join("writer.lock")) != OK: return fail("inner_writer_release_failed")
	return guard.release_writer(profile,owner)

func legacy_owned(owner: String) -> Dictionary:
	if not guard._owns_writer(profile,owner) or not DirAccess.dir_exists_absolute(directory.path_join("writer.lock")): return fail("writer_ownership_required")
	var h := guard.inspect_profile(profile)
	# Both locks are ours. No other failed history/pending condition is removed.
	h.writer_locked = false
	return h

func _fence(hint: String = "") -> Dictionary:
	if not valid_context(): return fail("invalid_disposable_root")
	var matches: Array[String] = []
	for name: String in DirAccess.get_files_at(directory):
		if not name.begins_with("generation_") or not name.ends_with(".json"): continue
		if hint.is_empty() or name == hint: matches.append(name)
	matches.sort()
	if matches.is_empty(): return fail("compact_fence_missing_or_conflicting")
	matches = [matches.back()]
	var raw := _read(directory.path_join(matches[0]))
	if not raw.success or not Scan.scan_json(raw.text,V6.MAX_BYTES).success: return fail("invalid_compact_fence")
	var w: Variant = JSON.parse_string(raw.text)
	if not w is Dictionary or not Scan.keys(w,["storage_version","transaction_id","document"]) or w.storage_version != 1 or w.transaction_id != "compact_v6_fence" or not w.document is String: return fail("invalid_compact_fence")
	var e: Variant = JSON.parse_string(w.document)
	if not e is Dictionary or not Scan.keys(e,["format","version","payload_json","sha256"]) or e.format != CharacterSaveContract.FORMAT or e.version != 6 or not e.payload_json is String or e.sha256 != e.payload_json.sha256_text(): return fail("invalid_compact_fence")
	var b: Variant = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(e.payload_json))
	if not b is Dictionary or not Scan.keys(b,["format","version","profile","namespace","source_digest","initial_route_digest","legacy"]) or b.format != "compact_windows_fence" or b.version != 1 or b.profile != profile or b.namespace != scope or b.source_digest != V6.digest(source.to_dictionary()) or not b.legacy is Dictionary or not Scan.keys(b.legacy,["count","digest"]) or not V6._uint(b.legacy.count) or not V6._hash(b.legacy.digest) or not V6._hash(b.initial_route_digest) or matches[0] != "generation_%016d.json" % (b.legacy.count+1): return fail("compact_fence_identity_failed")
	return {"success":true,"body":b,"digest":raw.text.sha256_text(),"file":matches[0]}

func _manifest() -> Dictionary:
	var raw := _read(objects.path_join("route.json"),V6.MAX_BYTES)
	if not raw.success: return fail("compact_route_missing")
	var p := _unpack(raw.text)
	if not p.success: return p
	var m: Dictionary = p.body
	if not Scan.keys(m,["version","active_format","profile","namespace","source_digest","rules_revision","epoch","sequence","logical_digest","digest","previous","capsule_digest","operation_id","request_digest","fence_digest","fence_file"]) or m.version != 1 or m.active_format != 6 or m.profile != profile or m.namespace != scope or m.source_digest != V6.digest(source.to_dictionary()) or m.rules_revision != PlayableCharacterAdmission.RULES or not m.epoch is String or m.epoch.is_empty() or not V6._uint(m.sequence) or m.sequence < 1 or not CharacterSaveStorage._valid_id(m.operation_id) or not m.fence_file is String or m.fence_file.get_file() != m.fence_file: return fail("compact_route_identity_failed")
	for field: String in ["logical_digest","digest","capsule_digest","request_digest","fence_digest"]:
		if not V6._hash(m[field]): return fail("invalid_compact_route_digest")
	if m.previous != null and not V6._hash(m.previous): return fail("invalid_previous_digest")
	var fence := _fence(m.fence_file)
	if not fence.success or fence.digest != m.fence_digest: return fail("compact_fence_changed",fence)
	return {"success":true,"route":m,"route_digest":raw.text.sha256_text()}

static func token(loaded: Dictionary) -> Variant:
	if loaded.get("empty",false): return null
	if not loaded.get("success",false): return {"unverified":true}
	var m: Dictionary = loaded.route
	return {"format":6,"epoch":m.epoch,"sequence":m.sequence,"digest":m.digest,"logical_digest":m.logical_digest,"route_digest":loaded.route_digest}

func load_current() -> Dictionary:
	if not valid_context(): return fail("invalid_disposable_root")
	var start := Time.get_ticks_usec()
	if not DirAccess.dir_exists_absolute(directory): return {"success":true,"empty":true}
	var manifest := _manifest()
	if not manifest.success: return manifest
	var m: Dictionary = manifest.route
	var raw := _read(objects.path_join("capsule_"+m.capsule_digest+".v6backup"))
	if not raw.success or raw.text.sha256_text() != m.capsule_digest: return fail("compact_capsule_damaged")
	var p := Portable.decode(raw.text,source)
	if not p.success or p.text.sha256_text() != m.digest or V6.digest(p.record) != m.logical_digest or p.record.head.epoch != m.epoch or p.record.head.sequence != m.sequence or p.record.current.character_id != profile or p.record.current.profile_namespace != scope or p.record.current.rules_revision != m.rules_revision or p.record.operations.back().id != m.operation_id or p.record.operations.back().request_digest != m.request_digest: return fail("compact_capsule_head_mismatch",p)
	var prior: Variant = null if p.previous.is_empty() else V6.encode(p.previous,source).get("text","").sha256_text()
	if prior != m.previous: return fail("compact_previous_binding_mismatch")
	var current := _read(objects.path_join("record_"+m.digest+".v6"),V6.MAX_BYTES)
	var intact: bool = current.success and current.text == p.text
	var fresh := _manifest()
	if not fresh.success or fresh.route_digest != manifest.route_digest: return fail("compact_head_changed_during_validation")
	var head := {"version":1,"profile":profile,"namespace":scope,"epoch":m.epoch,"sequence":m.sequence,"digest":m.digest,"previous":m.previous}
	return manifest.merged({"success":true,"text":p.text,"record":p.record,"head":head,"history":p.history,"capsule_text":raw.text,"exact_recovery_needed":not intact,"activation_pending":FileAccess.file_exists(objects.path_join("activation.pending")),"load_ms":float(Time.get_ticks_usec()-start)/1000.0},true)

func recover() -> Dictionary:
	# Never steal a stale/live legacy lease. Exact bytes can be diagnosed without
	# changing data; repair requires fresh exclusive ownership of both locks.
	var owned := acquire()
	if not owned.success: return owned
	var result := _recover_owned(owned.owner)
	var released := release(owned.owner)
	if not released.success: return fail("compact_recovery_release_failed",released)
	return result

func _recover_owned(owner: String) -> Dictionary:
	if not guard._owns_writer(profile,owner): return fail("writer_ownership_required")
	var loaded := load_current()
	if not loaded.success and loaded.reason == "compact_route_missing":
		var intent := _read(objects.path_join("activation.pending"),V6.MAX_BYTES)
		var fence := _fence()
		if not intent.success or not fence.success or intent.text.sha256_text() != fence.body.initial_route_digest: return loaded
		# Only a still-pending initial activation can finish a missing route.
		# No subsequent operation is allowed while activation.pending exists.
		var parsed := _unpack(intent.text)
		if not parsed.success or parsed.body.get("fence_digest") != "": return fail("invalid_activation_intent")
		parsed.body.fence_digest = fence.digest
		if not _write(objects.path_join("route.pending"),_pack(parsed.body)) or not _rename(objects.path_join("route.pending"),objects.path_join("route.json")): return fail("activation_recovery_publication_failed")
		loaded = load_current()
	if not loaded.success: return loaded
	if loaded.exact_recovery_needed:
		var pending := objects.path_join("repair.pending")
		if not _write(pending,loaded.text) or not _rename(pending,objects.path_join("record_"+loaded.route.digest+".v6")): return fail("exact_repair_failed")
		loaded = load_current()
	if loaded.success and FileAccess.file_exists(objects.path_join("activation.pending")):
		var fence := _fence()
		var intent := _read(objects.path_join("activation.pending"))
		var original: Dictionary = loaded.route.duplicate(true); original.fence_digest = ""
		if not fence.success or not intent.success or _pack(original).sha256_text() != fence.body.initial_route_digest or intent.text.sha256_text() != fence.body.initial_route_digest: return fail("activation_intent_conflict")
		if DirAccess.remove_absolute(objects.path_join("activation.pending")) != OK: return fail("activation_finalization_failed")
	return loaded

func install(text: String, capsule: String, expected: Variant, legacy: Dictionary, owner: String) -> Dictionary:
	if not guard._owns_writer(profile,owner): return fail("writer_ownership_required")
	var start := Time.get_ticks_usec()
	var pack := Portable.decode(capsule,source)
	if not pack.success or pack.text != text or pack.preview.profile != profile or pack.preview.namespace != scope: return fail("invalid_install_proof",pack)
	var current := load_current()
	var activating: bool = not current.success or current.get("empty",false)
	if not activating and token(current) != expected: return fail("stale_compact_storage_head")
	if activating and (expected != null or FileAccess.file_exists(objects.path_join("route.json")) or _fence().success): return fail("unknown_or_existing_compact_route")
	if not activating and (current.exact_recovery_needed or FileAccess.file_exists(objects.path_join("activation.pending"))): return fail("compact_recovery_required")
	if DirAccess.make_dir_recursive_absolute(objects) != OK: return fail("compact_directory_unavailable")
	var d := text.sha256_text(); var c := capsule.sha256_text()
	if activating:
		for name: String in DirAccess.get_files_at(objects):
			if name.begins_with("record_") and name != "record_"+d+".v6": return fail("unknown_unpublished_compact_data")
			if name.begins_with("capsule_") and name != "capsule_"+c+".v6backup": return fail("unknown_unpublished_compact_data")
	var m := {"version":1,"active_format":6,"profile":profile,"namespace":scope,"source_digest":V6.digest(source.to_dictionary()),"rules_revision":PlayableCharacterAdmission.RULES,"epoch":pack.record.head.epoch,"sequence":pack.record.head.sequence,"logical_digest":V6.digest(pack.record),"digest":d,"previous":null if pack.previous.is_empty() else V6.encode(pack.previous,source).text.sha256_text(),"capsule_digest":c,"operation_id":pack.record.operations.back().id,"request_digest":pack.record.operations.back().request_digest,"fence_digest":"","fence_file":"generation_%016d.json" % (legacy.count+1) if activating else current.route.fence_file}
	# Fence refers to initial route without its fence digest to avoid a hash cycle.
	# The initial-route digest commits the packed descriptor with this one field empty.
	var fence_text := ""
	if activating:
		var body := JSON.stringify({"format":"compact_windows_fence","version":1,"profile":profile,"namespace":scope,"source_digest":m.source_digest,"initial_route_digest":_pack(m).sha256_text(),"legacy":legacy},"",true,true)
		var doc := JSON.stringify({"format":CharacterSaveContract.FORMAT,"version":6,"payload_json":body,"sha256":body.sha256_text()},"",true,true)
		fence_text = JSON.stringify({"storage_version":1,"transaction_id":"compact_v6_fence","document":doc},"",true,true)
		m.fence_digest = fence_text.sha256_text()
	else: m.fence_digest = current.route.fence_digest
	var route_text := _pack(m)
	if not _write(objects.path_join("record.pending"),text) or not V6.decode(FileAccess.get_file_as_string(objects.path_join("record.pending")),source).success: return fail("compact_record_stage_failed")
	if not _rename(objects.path_join("record.pending"),objects.path_join("record_"+d+".v6")): return fail("compact_record_publish_failed")
	if not _write(objects.path_join("capsule.pending"),capsule) or not Portable.decode(FileAccess.get_file_as_string(objects.path_join("capsule.pending")),source).success: return fail("compact_capsule_stage_failed")
	if not _rename(objects.path_join("capsule.pending"),objects.path_join("capsule_"+c+".v6backup")): return fail("compact_capsule_publish_failed")
	if activating:
		# Store the descriptor with the empty fence binding, as committed by fence.
		var intent: Dictionary = m.duplicate(true); intent.fence_digest = ""
		if not _write(objects.path_join("activation.pending"),_pack(intent)): return fail("activation_intent_stage_failed")
		if not _write(directory.path_join("fence.pending"),fence_text): return fail("compact_fence_stage_failed")
		var fence_path := directory.path_join("generation_%016d.json" % (legacy.count+1))
		if FileAccess.file_exists(fence_path) or not _rename(directory.path_join("fence.pending"),fence_path): return fail("compact_fence_publication_failed")
	if not _write(objects.path_join("route.pending"),route_text) or not _unpack(FileAccess.get_file_as_string(objects.path_join("route.pending"))).success: return fail("compact_route_stage_failed")
	if not _rename(objects.path_join("route.pending"),objects.path_join("route.json")): return fail("compact_route_publication_failed")
	return {"success":true,"publish_ms":float(Time.get_ticks_usec()-start)/1000.0}

func finalize(owner: String, loaded: Dictionary) -> Dictionary:
	if not guard._owns_writer(profile,owner): return fail("writer_ownership_required")
	if FileAccess.file_exists(objects.path_join("activation.pending")):
		if DirAccess.remove_absolute(objects.path_join("activation.pending")) != OK: return fail("activation_finalization_failed")
	for name: String in DirAccess.get_files_at(objects):
		var keep := ["record_"+loaded.route.digest+".v6","record_"+str(loaded.route.previous)+".v6","capsule_"+loaded.route.capsule_digest+".v6backup"]
		if name in keep: continue
		if (name.begins_with("record_") and name.ends_with(".v6") and V6._hash(name.trim_prefix("record_").trim_suffix(".v6"))) or (name.begins_with("capsule_") and name.ends_with(".v6backup") and V6._hash(name.trim_prefix("capsule_").trim_suffix(".v6backup"))):
			if DirAccess.remove_absolute(objects.path_join(name)) != OK: return fail("compact_technical_retention_failed")
	return {"success":true}
