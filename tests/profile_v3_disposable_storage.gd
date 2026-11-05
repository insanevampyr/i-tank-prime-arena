extends RefCounted

# Test-only disk transport. Never registered with playable persistence.
const Storage = preload("res://scripts/rewards/character_save_storage.gd")
const Profile = preload("res://scripts/rewards/profile_v3_compatibility.gd")
const Life = preload("res://scripts/combat/life_state_history_contract.gd")
const Legacy = preload("res://scripts/rewards/character_save_contract.gd")
const MAX_RECORD_BYTES := 24 * 1024 * 1024
const FAULTS := ["","before_staging","partial_stage","after_stage","after_rename","lost_ack","readback_mismatch"]
var _root := ""
var _source: Callable
var _guard: CharacterSaveStorage
var _observed := {}
var _verified_prepared := {}
var _verified_readback := {}

func _init(directory: String, authority: Callable) -> void:
	var candidate := directory.replace("\\","/").simplify_path()
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests")+"/"
	if candidate.begins_with(allowed) and candidate.get_file().begins_with("v3_case_"):
		_root = candidate
		_guard = Storage.new(_root)
	_source = authority

func _authorization(kind: String, record: Dictionary, identity: Dictionary) -> bool:
	if kind == "v3_expected_head": return _observed.get(identity.profile_id) == Life.fingerprint(record)
	if kind == "v3_current_document": return _observed.get(identity.profile_id) == record.get("payload_digest")
	if kind == "v3_committed_readback": return record.get("prepared") == _verified_prepared and record.get("readback") == _verified_readback and not _verified_prepared.is_empty()
	return Life._authorized(_source,kind,record,identity)

func _valid(profile: String) -> bool:
	return not _root.is_empty() and Storage._valid_id(profile) and (profile.begins_with("prod_") or profile.begins_with("dev_")) and _source.is_valid() and not OS.has_feature("web")

func _fail(reason: String, verified: Array = []) -> Dictionary:
	return {"success":false,"reason":reason,"recovery_required":true,"verified_prefix":verified.duplicate(true),"power_loss_durability_proven":false}

func _directory(profile: String) -> String:
	return _root.path_join(profile)

func _generation(profile: String, generation: int) -> String:
	return _directory(profile).path_join("generation_%016d.json" % generation)

func _write(path: String, text: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return _fail("output_unavailable")
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return _fail("write_failed")
	return {"success":true}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return _fail("file_missing")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return _fail("read_failed")
	if file.get_length() > MAX_RECORD_BYTES:
		file.close()
		return _fail("file_size_limit")
	var text := file.get_as_text()
	var error := file.get_error()
	file.close()
	if error != OK: return _fail("read_failed")
	return {"success":true,"text":text}

func _anchor(profile: String) -> Dictionary:
	var read := _read(_directory(profile).path_join("anchor.v2"))
	if not read.success: return read
	var legacy := Legacy.decode(read.text)
	if not legacy.success or legacy.version != 2 or legacy.payload.character_id != profile: return _fail("invalid_or_foreign_anchor")
	var identity := {"profile_id":profile,"character_id":legacy.payload.definition_id,"rules_revision":legacy.payload.rules_revision,"namespace":legacy.payload.get("profile_namespace"),"history_id":""}
	# The exact history identity is checked by the V3 candidate. Anchor initialization
	# additionally requires explicit test-source authorization; checksum is not trust.
	if not Life._authorized(_source,"disk_anchor",{"document":read.text},identity): return _fail("anchor_source_unverified")
	return {"success":true,"document":read.text,"generation":int(legacy.payload.generation)}

func initialize_anchor(profile: String, document: String) -> Dictionary:
	if not _valid(profile): return _fail("disposable_root_or_identity_required")
	var lease := _guard.acquire_writer(profile)
	if not lease.success: return lease
	var result := _initialize_locked(profile,document)
	if not _guard.release_writer(profile,lease.owner).success: return _fail("writer_release_failed")
	return result

func _initialize_locked(profile: String, document: String) -> Dictionary:
	var decoded := Legacy.decode(document)
	if not decoded.success or decoded.version != 2 or decoded.payload.character_id != profile: return _fail("invalid_or_foreign_anchor")
	var identity := {"profile_id":profile,"character_id":decoded.payload.definition_id,"rules_revision":decoded.payload.rules_revision,"namespace":decoded.payload.get("profile_namespace"),"history_id":""}
	if not Life._authorized(_source,"disk_anchor",{"document":document},identity): return _fail("anchor_source_unverified")
	var directory := _directory(profile)
	if DirAccess.dir_exists_absolute(directory): return _fail("anchor_destination_exists")
	if DirAccess.make_dir_absolute(directory) != OK: return _fail("directory_create_failed")
	var staged := directory.path_join("anchor.pending")
	var write := _write(staged,document)
	if not write.success: return write
	if _read(staged).get("text") != document: return _fail("anchor_readback_mismatch")
	if DirAccess.rename_absolute(staged,directory.path_join("anchor.v2")) != OK: return _fail("anchor_publish_failed")
	return _anchor(profile)

func _record(path: String) -> Dictionary:
	var read := _read(path)
	if not read.success: return read
	var parser := JSON.new()
	if parser.parse(read.text) != OK or not parser.data is Dictionary: return _fail("invalid_transport_json")
	var wrapper: Dictionary = Life._json_integers(parser.data)
	if not Life._keys(wrapper,["transport_version","prepared","sha256"]) or wrapper.transport_version != 1 or not wrapper.prepared is Dictionary or Life.fingerprint(wrapper.prepared) != wrapper.sha256: return _fail("transport_integrity_failed")
	var prepared: Dictionary = wrapper.prepared
	if not Life._keys(prepared,["expected_digest","expected_generation","transaction_id","payload","document"]) or not prepared.document is String or not prepared.payload is Dictionary: return _fail("invalid_prepared_record")
	var decoded := Profile.decode(prepared.document,_authorization)
	if not decoded.success or decoded.get("payload") != prepared.payload: return _fail("profile_integrity_or_source_failed")
	return {"success":true,"prepared":prepared,"text":read.text}

func inspect(profile: String, minimum_generation: int = 0) -> Dictionary:
	if not _valid(profile): return _fail("disposable_root_or_identity_required")
	if not DirAccess.dir_exists_absolute(_directory(profile)): return _fail("profile_missing")
	var anchor := _anchor(profile)
	if not anchor.success: return anchor
	var directory := DirAccess.open(_directory(profile))
	if directory == null: return _fail("directory_unavailable")
	var names: Array[String] = []
	for name: String in directory.get_files():
		if name.begins_with("generation_") and name.ends_with(".json"): names.append(name)
	names.sort()
	var records: Array = []
	var current := {}
	var transactions := {}
	for name: String in names:
		var record := _record(_directory(profile).path_join(name))
		if not record.success: return _fail(record.reason,records)
		var prepared: Dictionary = record.prepared
		var candidate: Dictionary = prepared.payload
		if candidate.anchor_document != anchor.document or candidate.life_history.identity.profile_id != profile: return _fail("profile_or_anchor_conflict",records)
		var expected: int = anchor.generation if current.is_empty() else int(current.generation)
		if name != "generation_%016d.json" % int(candidate.generation) or candidate.generation != expected+1 or transactions.has(prepared.transaction_id): return _fail("generation_gap_or_duplicate_transaction",records)
		_observed[profile] = Life.fingerprint({"legacy_anchor":anchor.document.sha256_text(),"generation":anchor.generation} if current.is_empty() else current)
		var plan := Profile.prepare(current,candidate,expected,prepared.transaction_id,_authorization)
		if not plan.success or plan.prepared != prepared: return _fail("history_or_preparation_conflict",records)
		transactions[prepared.transaction_id] = true
		records.append(prepared)
		current = candidate
	var actual: int = anchor.generation if current.is_empty() else int(current.generation)
	if actual < minimum_generation: return _fail("acknowledged_generation_missing",records)
	_observed[profile] = Life.fingerprint({"legacy_anchor":anchor.document.sha256_text(),"generation":anchor.generation} if current.is_empty() else current)
	return {"success":true,"records":records,"payload":current.duplicate(true),"generation":actual,"anchor":anchor.document,"pending_write":FileAccess.file_exists(_directory(profile).path_join("write.pending")) or FileAccess.file_exists(_directory(profile).path_join("anchor.pending")),"writer_locked":DirAccess.dir_exists_absolute(_root.path_join(profile+".writer.lock"))}

func publish(profile: String, candidate: Dictionary, expected_generation: int, transaction: String, fault: String = "") -> Dictionary:
	if not _valid(profile) or fault not in FAULTS: return _fail("disposable_root_identity_or_fault_invalid")
	var lease := _guard.acquire_writer(profile)
	if not lease.success: return lease
	var result := _publish_locked(profile,candidate,expected_generation,transaction,fault)
	if not _guard.release_writer(profile,lease.owner).success: return _fail("writer_release_failed")
	return result

func _publish_locked(profile: String, candidate: Dictionary, expected_generation: int, transaction: String, fault: String) -> Dictionary:
	var history: Variant = candidate.get("life_history")
	if not history is Dictionary or not history.get("identity") is Dictionary or history.identity.get("profile_id") != profile: return _fail("wrong_profile_publication")
	var before := inspect(profile)
	if not before.success: return before
	if before.pending_write: return _fail("incomplete_staging_requires_review")
	for prior: Dictionary in before.records:
		if prior.transaction_id == transaction:
			if prior.payload != candidate or prior.expected_generation != expected_generation: return _fail("transaction_payload_conflict")
			return _reconcile_locked(profile,prior)
	var plan := Profile.prepare(before.payload,candidate,expected_generation,transaction,_authorization)
	if not plan.success: return plan
	if fault == "before_staging": return _fail("injected_before_staging")
	var prepared: Dictionary = plan.prepared
	var text := Life.canonical({"transport_version":1,"prepared":prepared,"sha256":Life.fingerprint(prepared)})
	var pending := _directory(profile).path_join("write.pending")
	var write := _write(pending,text.left(text.length()/2) if fault == "partial_stage" else text)
	if not write.success: return write
	if fault in ["partial_stage","after_stage"]: return _fail("injected_unpublished_interruption")
	var staged := _record(pending)
	if not staged.success or staged.prepared != prepared: return _fail("staged_verification_failed")
	var destination := _generation(profile,int(candidate.generation))
	if FileAccess.file_exists(destination): return _fail("generation_exists")
	# Same-directory publication of a NEW immutable file; no overwrite fallback.
	if DirAccess.rename_absolute(pending,destination) != OK: return _fail("publish_rename_failed")
	if fault in ["after_rename","lost_ack"]: return _fail("injected_published_acknowledgement_lost")
	if fault == "readback_mismatch": return _fail("injected_readback_mismatch")
	return _reconcile_locked(profile,prepared)

func reconcile(profile: String, prepared: Dictionary) -> Dictionary:
	if not _valid(profile): return _fail("disposable_root_or_identity_required")
	# Serialize exact head observation against cooperative publishers. Publication
	# already owns this guard and calls the private path to avoid nested locking.
	var lease := _guard.acquire_writer(profile)
	if not lease.success: return lease
	var result := _reconcile_locked(profile,prepared)
	if not _guard.release_writer(profile,lease.owner).success: return _fail("writer_release_failed")
	return result

func _reconcile_locked(profile: String, prepared: Dictionary) -> Dictionary:
	var current := inspect(profile)
	if not current.success: return current
	if current.pending_write: return _fail("incomplete_staging_requires_review")
	if current.records.is_empty() or current.records.back() != prepared: return _fail("not_current_committed_transaction")
	# A new file open, not the buffer used by the write/staging check.
	var read := _record(_generation(profile,int(current.generation)))
	if not read.success or read.prepared != prepared: return _fail("fresh_readback_mismatch")
	var readback := {"document":prepared.document,"transaction_id":prepared.transaction_id,"generation":current.generation,"transaction_completed":true}
	_verified_prepared = prepared.duplicate(true)
	_verified_readback = readback.duplicate(true)
	var acknowledged := Profile.acknowledge(prepared,readback,_authorization)
	_verified_prepared.clear()
	_verified_readback.clear()
	if not acknowledged.success: return acknowledged
	return {"success":true,"state":"filesystem_verified","generation":current.generation,"document":readback.document,"transaction_id":readback.transaction_id,"power_loss_durability_proven":false,"multi_profile_atomic":false}

func publish_cohort(_candidates: Array) -> Dictionary:
	return Profile.prepare_cohort(_candidates)
