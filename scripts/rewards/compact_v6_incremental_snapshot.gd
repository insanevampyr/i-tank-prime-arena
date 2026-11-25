extends RefCounted

# Dormant, in-memory S2/S3 -> Architecture B observer. No storage/writer API.
# The trusted host supplies a fresh acknowledged-head/ownership reader; a flag
# or imported head is not permission. The original coordinator remains required.
const S2 = preload("res://scripts/rewards/compact_v6_gameplay_candidate.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Package = preload("res://scripts/rewards/compact_v6_snapshot_package.gd")
const Credit = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")

class Operation extends RefCounted:
	var _body := "":
		set(value):
			if _body.is_empty(): _body = value
	var _package := "":
		set(value):
			if _package.is_empty(): _package = value
	var _head := "":
		set(value):
			if _head.is_empty(): _head = value
	func _init(body: Dictionary, package_text: String, head_text: String) -> void:
		_body = JSON.stringify(body,"",true,true); _package = package_text; _head = head_text
	func copy() -> Dictionary:
		return {"seal":CharacterSaveContract._normalize_json_numbers(JSON.parse_string(_body)),"text":_package,"replica":_package,"head_text":_head}
	func digest() -> String: return _body.sha256_text()

# Private admission/operation state. No getter exposes its mutable map/record.
class Context extends RefCounted:
	var pin := {}
	var record := {}
	var ids := {}
	var text := ""
	var head_text := ""
	var owner := ""

var _service: WeakRef
var _reader: Callable
var _ctx: Context
var _s2: RefCounted
var _pending: Operation
var _s2_pending: RefCounted
var _new_ids := {}
var _failure := ""
var _capture_ms := 0.0
var _movement_at_capture := ""
var _checked: RefCounted
var admission_metrics := {}

# Explicit dormant opt-in. Admission is FULL again; this accepts no caller
# proof/verified flag. A new process must establish its own cold authority.
func enable_checked() -> Dictionary:
	var fresh:=_fresh()
	if not fresh.success: return fresh
	if _pending!=null or _checked!=null: return fail("checked_operation_already_started")
	var service: PlayableCharacterPersistence=_service.get_ref()
	var context: RefCounted=load("res://scripts/rewards/compact_v6_checked_operation.gd").new(service,self,_ctx.text,_ctx.head_text)
	var attached: Dictionary=_s2.attach_checked(context)
	if attached.success: _checked=context
	return attached

func _init(service: PlayableCharacterPersistence, acknowledged_reader: Callable) -> void:
	var started := Time.get_ticks_usec()
	if service == null or service.source == null or not acknowledged_reader.is_valid():
		_failure = "trusted_context_and_reader_required"; return
	_service = weakref(service); _reader = acknowledged_reader
	var actual := _read()
	if not actual.success: _failure = actual.reason; return
	_ctx = Context.new(); _ctx.owner = actual.owner
	_ctx.pin = {"service":str(service.get_instance_id()),"source":str(service.source.get_instance_id()),"source_digest":V6.digest(service.source.to_dictionary()),"profile":service.profile_id,"namespace":service.mode,"run":service.run_id,"rules":PlayableCharacterAdmission.RULES}
	if actual.head_text.is_empty() and actual.text.is_empty():
		if service.generation != 0: _failure = "acknowledged_parent_required"; return
	else:
		var cold := Package.cold_verify(actual.head_text,actual.text,service.source,service.profile_id,service.mode)
		if not cold.success: _failure = "cold_parent_rejected"; return
		_ctx.record = cold.record; _ctx.text = actual.text; _ctx.head_text = actual.head_text
		for row: Dictionary in cold.record.applied_ids: _ctx.ids[_key(row)] = Package.canonical(row)
	_s2 = S2.new(service,_ctx.record)
	if not _s2._failure.is_empty(): _failure = _s2._failure
	admission_metrics = {"cold_admission_ms":float(Time.get_ticks_usec()-started)/1000.0,"ids":_ctx.ids.size(),"replica_repair_needed":actual.replica != actual.text}

func _key(row: Dictionary) -> String: return Package.canonical([row.scope,row.id])
func _read() -> Dictionary:
	if not _reader.is_valid(): return fail("acknowledged_reader_unavailable")
	var value: Variant = _reader.call()
	if not value is Dictionary or not value.get("success",false): return fail("acknowledged_reader_unavailable")
	for field: String in ["owner","head_text","text","replica"]:
		if not value.get(field) is String: return fail("invalid_acknowledged_read")
	if value.owner.is_empty(): return fail("ownership_unavailable")
	if value.has("other_head") and value.other_head != value.head_text: return fail("conflicting_head_authority")
	return value

func _invalidate(reason: String) -> Dictionary:
	_failure = reason
	if _s2 != null: _s2.cancel()
	return fail(reason)

func _fresh(allow_candidate: bool = false) -> Dictionary:
	if not _failure.is_empty(): return fail(_failure)
	var service: PlayableCharacterPersistence = _service.get_ref()
	if service == null or service.source == null: return _invalidate("trusted_context_lost")
	var pin := {"service":str(service.get_instance_id()),"source":str(service.source.get_instance_id()),"source_digest":V6.digest(service.source.to_dictionary()),"profile":service.profile_id,"namespace":service.mode,"run":service.run_id,"rules":PlayableCharacterAdmission.RULES}
	if pin != _ctx.pin: return _invalidate("identity_source_or_rules_changed")
	var actual := _read()
	if not actual.success: return _invalidate(actual.reason)
	if actual.owner != _ctx.owner: return _invalidate("ownership_changed")
	if actual.head_text == _ctx.head_text and actual.text == _ctx.text: return actual
	if allow_candidate and _pending != null and actual.text == _pending._package and actual.head_text == _pending._head and _acknowledged():
		return actual.merged({"already_applied":true})
	return _invalidate("acknowledged_parent_or_bytes_changed")

func head() -> String: return _ctx.head_text if _ctx != null else ""
func current_copy() -> Dictionary: return _ctx.record.duplicate(true) if _ctx != null else {}

func observe(session: ArenaCombatSession) -> Dictionary:
	var started := Time.get_ticks_usec()
	var fresh := _fresh()
	if not fresh.success: return fresh
	var result: Dictionary = _s2.observe(session)
	if result.success:
		if not session.player_movement_boundary_provider.is_valid(): return _invalidate("movement_checkpoint_provider_required")
		_movement_at_capture = V6.digest(session.player_movement_boundary_provider.call())
	_capture_ms += float(Time.get_ticks_usec()-started)/1000.0
	return result

func prepare(expected_head: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	var fresh := _fresh(true)
	if not fresh.success: return fresh
	if expected_head != head(): return fail("stale_expected_package_head")
	if _pending != null:
		var existing := check(_pending,expected_head)
		return {"success":true,"prepared":_pending,"exact_retry":true,"already_applied":fresh.get("already_applied",false)} if existing.success else existing
	var service: PlayableCharacterPersistence = _service.get_ref()
	if _ctx.ids.has(Package.canonical(["operation",service._prepared.get("transaction_id","")])): return fail("reused_operation_id")
	var proposed: Dictionary = _s2.prepare(_s2.head())
	if not proposed.success: return proposed
	return _seal(proposed,started)

func prepare_credit(session: ArenaCombatSession, expected_head: String, confirmation: Callable = Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var fresh := _fresh(true)
	if not fresh.success: return fresh
	if expected_head != head(): return fail("stale_expected_package_head")
	if _pending != null:
		if _s2._credit_proposal.is_empty(): return fail("candidate_operation_in_flight")
		return prepare(expected_head)
	# S3's existing storage-free observer mode: X separately pins the exact W
	# head before/after consent. No old S4 route or invented v1 storage head.
	var proposed: Dictionary = _s2.prepare_credit(session,_s2.head(),confirmation)
	if not proposed.success or proposed.get("no_op",false): return proposed
	fresh = _fresh()
	if not fresh.success: return fresh
	return _seal(proposed,started)

func _seal(proposed: Dictionary, started: int) -> Dictionary:
	var memory := OS.get_static_memory_usage()
	var service: PlayableCharacterPersistence = _service.get_ref()
	var body: Dictionary = proposed.prepared.copy()
	var session: ArenaCombatSession = _s2._session.get_ref()
	if session == null or not session.player_movement_boundary_provider.is_valid(): return _invalidate("movement_checkpoint_provider_required")
	# Session snapshots omit the external player Running model. Pin its actual
	# ingest-boundary state too; never grant a stale checkpoint fresh authority.
	if _s2._credit_proposal.is_empty() and (_movement_at_capture.is_empty() or V6.digest(session.player_movement_boundary_provider.call()) != _movement_at_capture): return _invalidate("movement_changed_after_capture")
	var checkpoint_runtime: String = _s2._credit_runtime(session)
	# S2 already fully validates these exact canonical bytes; keep that oracle.
	var record: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(body.candidate_text).payload_json))
	var ids_started := Time.get_ticks_usec()
	var ids := _delta(record)
	if not ids.success: return ids
	var ids_ms := float(Time.get_ticks_usec()-ids_started)/1000.0
	var built: Dictionary = Package.build_checked(_checked,_s2,proposed.prepared) if _checked!=null else Package.build(body.candidate_text,service.source,service.profile_id,service.mode,_ctx.text,_ctx.head_text)
	if not built.success: return built
	var fresh := _fresh()
	if not fresh.success: return fresh
	var recheck_started := Time.get_ticks_usec()
	var rechecked: Dictionary = _s2.check(proposed.prepared,_s2.head())
	if not rechecked.success: return _invalidate(String(rechecked.get("reason","source_authority_changed")))
	if _s2._credit_runtime(session) != checkpoint_runtime: return _invalidate("checkpoint_runtime_changed")
	var recheck_ms := float(Time.get_ticks_usec()-recheck_started)/1000.0
	var stamp := {"parent_head_sha256":head().sha256_text(),"owner":_ctx.owner,"pin":_ctx.pin,"checkpoint_runtime":checkpoint_runtime,"checkpoint_digest":V6.digest(record.current.recovery),"s2_digest":proposed.prepared.digest(),"package_sha256":built.text.sha256_text(),"head_sha256":built.head_text.sha256_text(),"candidate_sha256":body.candidate_digest,"operation":record.operations.back()}
	_pending = Operation.new(stamp,built.text,built.head_text)
	_s2_pending = proposed.prepared; _new_ids = ids.appended
	return {"success":true,"prepared":_pending,"metrics":{"capture_ms":_capture_ms,"s2":proposed.get("metrics",{}),"id_and_prefix_ms":ids_ms,"package_ms":built.build_ms,"package_stages":built.metrics,"seal_authority_recheck_ms":recheck_ms,"preparation_ms":float(Time.get_ticks_usec()-started)/1000.0,"new_ids":_new_ids.size(),"ids":record.applied_ids.size(),"package_bytes":built.package_bytes,"replica_bytes":built.replica_bytes,"native_live_delta":OS.get_static_memory_usage()-memory,"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}}

func _delta(record: Dictionary) -> Dictionary:
	var found := {}; var appended := {}
	for row: Dictionary in record.applied_ids:
		var key := _key(row); var binding := Package.canonical(row)
		if found.has(key): return fail("duplicate_lifetime_identity")
		found[key] = binding
		if _ctx.ids.has(key):
			if _ctx.ids[key] != binding: return fail("immutable_lifetime_binding_changed")
		else: appended[key] = binding
	for key: String in _ctx.ids:
		if not found.has(key): return fail("missing_lifetime_identity")
	if not _ctx.record.is_empty():
		if Package.canonical(record.operations.slice(0,_ctx.record.operations.size())) != Package.canonical(_ctx.record.operations): return fail("original_operations_changed")
		for field: String in ["awards","purchases","growth","settlements","order"]:
			if Package.canonical(record.evidence[field].slice(0,_ctx.record.evidence[field].size())) != Package.canonical(_ctx.record.evidence[field]): return fail("permanent_evidence_prefix_changed")
	return {"success":true,"appended":appended}

func check(operation: Operation, expected_head: String) -> Dictionary:
	var fresh := _fresh(true)
	if not fresh.success: return fresh
	if operation == null or operation != _pending: return fail("foreign_prepared_operation")
	if expected_head != head(): return fail("stale_expected_package_head")
	var seal: Dictionary = operation.copy().seal
	if _s2._session == null or _s2._session.get_ref() == null or _s2._credit_runtime(_s2._session.get_ref()) != seal.checkpoint_runtime: return _invalidate("checkpoint_runtime_changed")
	if seal.pin != _ctx.pin or seal.owner != _ctx.owner or seal.parent_head_sha256 != head().sha256_text() or seal.s2_digest != _s2_pending.digest() or seal.package_sha256 != operation._package.sha256_text() or seal.head_sha256 != operation._head.sha256_text(): return _invalidate("sealed_context_or_bytes_changed")
	var checked: Dictionary = _s2.check(_s2_pending,_s2.head())
	if not checked.success: return _invalidate(String(checked.get("reason","source_authority_changed")))
	return {"success":true,"already_applied":fresh.get("already_applied",false)}

func _acknowledged() -> bool:
	if _s2_pending == null: return false
	var service: PlayableCharacterPersistence = _service.get_ref()
	var request: Dictionary = _s2._credit_proposal if not _s2._credit_proposal.is_empty() else service._prepared
	return service._last_ack and service._prepared == request and service._prior == request.payload and service.generation == request.payload.generation

func adopt(operation: Operation) -> Dictionary:
	var checked := check(operation,head())
	if not checked.success: return checked
	var fresh := _fresh(true)
	if not fresh.success or not fresh.get("already_applied",false) or not _acknowledged(): return fail("exact_acknowledged_package_readback_required")
	var adopted: Dictionary = _s2.adopt(_s2_pending)
	if not adopted.success: return adopted
	_ctx.record = _s2.current_copy(); _ctx.text = operation._package; _ctx.head_text = operation._head
	_ctx.ids.merge(_new_ids)
	_pending = null; _s2_pending = null; _new_ids = {}; _capture_ms = 0.0; _movement_at_capture = ""
	return {"success":true,"restore_authorized":false,"publication_performed":false}

func cancel() -> Dictionary: return _invalidate("operation_canceled")
func fail(reason: String) -> Dictionary: return {"success":false,"reason":reason,"restore_authorized":false,"publication_performed":false}
