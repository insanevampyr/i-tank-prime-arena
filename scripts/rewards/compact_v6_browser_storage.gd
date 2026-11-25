extends RefCounted
# Dormant S5 only. No production DB default and no playable dispatch.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Portable = preload("res://scripts/rewards/compact_v6_portable.gd")
const PREFIX := "itank-arena-test-36k-45t-"
var database := ""
var profile := ""
var scope := ""
var source: CombatCharacterDefinitionResource
var guard: CharacterSaveStorage # Always null: no filesystem surrogate.
var owner := ""
var _seal := ""
var _bridge: JavaScriptObject
var _handle := ""
var _transport: Callable
var _snapshot := {}
var _matched := false
var _job := ""
var _operation := ""
var _arguments := {}

static func allowed(name: String) -> bool:
	return name.begins_with(PREFIX) and name.validate_node_name() == name and name.to_lower() == name and name.replace("-","").is_valid_identifier()

func _init(name: String, definition: CombatCharacterDefinitionResource, identity: String, save_namespace: String, test_transport: Callable = Callable()) -> void:
	if not allowed(name) or definition == null or not CharacterSaveStorage._valid_id(identity) or save_namespace not in ["normal","dev_normal"]: return
	database = name; _seal = name; profile = identity; scope = save_namespace; source = definition; _transport = test_transport
	if _transport.is_valid() or not OS.has_feature("web"): return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/rewards/character_browser_store.js"),true)
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/rewards/compact_v6_browser_store.js"),true)
	_bridge = JavaScriptBridge.get_interface("ArenaCompactV6Browser")
	_handle = str(_bridge.create(name)) if _bridge != null else ""

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"state":"recovery_required","reason":reason,"details":details}

func valid_context() -> bool:
	return allowed(database) and database == _seal and source != null and guard == null and scope in ["normal","dev_normal"] and CharacterSaveStorage._valid_id(profile) and (_transport.is_valid() or (OS.has_feature("web") and not _handle.is_empty()))

func begin(operation: String, arguments: Dictionary = {}) -> Dictionary:
	if not valid_context(): return fail("disposable_browser_context_required")
	if not _job.is_empty(): return fail("operation_in_flight")
	_arguments = arguments.duplicate(true); _arguments.profile = profile; _operation = operation
	if operation in ["publish","repair","release"]: _matched = false
	var response: Dictionary
	if _transport.is_valid(): response = _transport.call("begin",{"operation":operation,"arguments":_arguments})
	else:
		var job := str(_bridge.request(_handle,operation,JSON.stringify(_arguments,"",true,true)))
		response = {"success":false,"state":"pending","job":job} if not job.is_empty() else fail("browser_queue_unavailable")
	if response.get("state") != "pending" or str(response.get("job","")).is_empty(): return fail("queued_operation_cannot_acknowledge")
	_job = response.job
	return response

func poll(job: String) -> Dictionary:
	if not valid_context() or job != _job or job.is_empty(): return fail("stale_browser_callback")
	var response: Variant = _transport.call("poll",{"job":job}) if _transport.is_valid() else JSON.parse_string(str(_bridge.poll(_handle,job)))
	response = CharacterSaveContract._normalize_json_numbers(response)
	if not response is Dictionary or response.get("state") not in ["pending","verified_committed","recovery_required","failed","unavailable"]: return fail("invalid_browser_response")
	if response.state == "pending": return response
	_job = ""
	if response.get("success",false):
		if _operation == "match" and _arguments.get("route") == _snapshot.get("route") and _arguments.get("blobs") == _snapshot.get("blobs") and _arguments.get("legacy_head") == _snapshot.get("legacy_head") and _arguments.get("legacy_rows") == _snapshot.get("legacy_rows") and _arguments.get("legacy_receipts") == _snapshot.get("legacy_receipts"): _matched = true
		if _operation == "acquire": owner = _arguments.owner
		elif _operation == "transfer": owner = _arguments.next_owner
		elif _operation == "release": owner = ""
	return response

func accept_snapshot(raw: Dictionary) -> Dictionary:
	if not valid_context() or not raw.get("success",false) or not raw.has_all(["route","blobs","legacy_head","legacy_rows","legacy_receipts"]): return fail("unverified_browser_snapshot")
	_matched = false
	_snapshot = raw.duplicate(true)
	return load_current()

static func token(loaded: Dictionary) -> Variant:
	if loaded.get("empty",false): return null
	if not loaded.get("success",false): return {"unverified":true}
	var r: Dictionary = loaded.route
	return {"format":6,"epoch":r.epoch,"sequence":r.sequence,"digest":r.digest,"logical_digest":r.logical_digest,"route_digest":loaded.route_digest}

func load_current() -> Dictionary:
	if not valid_context() or _snapshot.is_empty(): return fail("fresh_browser_snapshot_required")
	if _snapshot.route == null:
		if not _snapshot.blobs.is_empty(): return fail("missing_route_with_compact_data")
		return {"success":true,"empty":true,"legacy":_snapshot.duplicate(true)}
	var m: Variant = _snapshot.route
	if not m is Dictionary or not CharacterBackupContract.keys(m,["version","active_format","minimum_reader","profile","namespace","source_digest","rules_revision","epoch","sequence","logical_digest","digest","previous","capsule_digest","operation_id","request_digest","legacy"]): return fail("invalid_compact_route")
	if m.version != 1 or m.active_format != 6 or m.minimum_reader != 2 or m.profile != profile or m.namespace != scope or m.source_digest != V6.digest(source.to_dictionary()) or m.rules_revision != PlayableCharacterAdmission.RULES or not m.epoch is String or m.epoch.is_empty() or not V6._uint(m.sequence) or m.sequence < 1 or not CharacterSaveStorage._valid_id(m.operation_id): return fail("compact_route_identity_failed")
	for field: String in ["logical_digest","digest","capsule_digest","request_digest"]:
		if not V6._hash(m[field]): return fail("invalid_compact_route_digest")
	if m.previous != null and not V6._hash(m.previous): return fail("invalid_previous_digest")
	if not m.legacy is Dictionary or not CharacterBackupContract.keys(m.legacy,["count","digest"]) or not V6._uint(m.legacy.count) or not V6._hash(m.legacy.digest) or m.legacy.count != _snapshot.legacy_count: return fail("legacy_binding_mismatch")
	var capsule := _blob("capsule",m.capsule_digest)
	if not capsule.success: return fail("compact_capsule_damaged")
	var p := Portable.decode(capsule.text,source)
	if not p.success or p.text.sha256_text() != m.digest or V6.digest(p.record) != m.logical_digest or p.record.head.epoch != m.epoch or p.record.head.sequence != m.sequence or p.record.current.character_id != profile or p.record.current.profile_namespace != scope or p.record.current.rules_revision != m.rules_revision or p.record.operations.back().id != m.operation_id or p.record.operations.back().request_digest != m.request_digest: return fail("compact_capsule_head_mismatch",p)
	var previous: Variant = null if p.previous.is_empty() else V6.encode(p.previous,source).get("text","").sha256_text()
	if previous != m.previous: return fail("compact_previous_binding_mismatch")
	var record := _blob("record",m.digest)
	return {"success":true,"text":p.text,"record":p.record,"route":m.duplicate(true),"route_digest":V6.digest(m),"head":{"version":1,"profile":profile,"namespace":scope,"epoch":m.epoch,"sequence":m.sequence,"digest":m.digest,"previous":m.previous},"history":p.history,"capsule_text":capsule.text,"exact_recovery_needed":not record.success or record.get("text") != p.text,"activation_pending":false}

func _blob(kind: String, digest: String) -> Dictionary:
	var found: Array = []
	for row: Variant in _snapshot.blobs:
		if row is Dictionary and row.get("profile") == profile and row.get("kind") == kind and row.get("digest") == digest: found.append(row)
	if found.size() != 1 or not found[0].get("text") is String or found[0].text.sha256_text() != digest: return fail("blob_missing_or_damaged")
	return {"success":true,"text":found[0].text}

func readback_verified() -> bool: return _matched and not owner.is_empty()
func raw_copy() -> Dictionary: return _snapshot.duplicate(true)
func close() -> void:
	if _bridge != null and not _handle.is_empty(): _bridge.close(_handle)
