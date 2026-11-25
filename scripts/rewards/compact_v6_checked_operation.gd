extends RefCounted
# Dormant operation-local proof ownership. No persisted flag or dictionary permit.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")

class State extends RefCounted:
	var record := "":
		set(v):
			if record.is_empty(): record = v
	var text := "":
		set(v):
			if text.is_empty(): text = v
	var package_text := "":
		set(v):
			if package_text.is_empty(): package_text = v
	var head := "":
		set(v):
			if head.is_empty(): head = v
	var receipts := "":
		set(v):
			if receipts.is_empty(): receipts = v
	func _init(r: String, t: String, p: String, h: String, entries: String) -> void:
		record=r; text=t; package_text=p; head=h; receipts=entries

var _service: WeakRef
var _issuer: WeakRef
var _host: WeakRef
var _pin := ""
var _state: State
var _candidate: State
var _built: State
var _prepared: WeakRef
var _prepared_digest := ""
var _runtime_pin := ""
var _failed := ""

func _init(service: PlayableCharacterPersistence, host: RefCounted, text: String, head: String) -> void:
	if not is_instance_of(host,load("res://scripts/rewards/compact_v6_incremental_snapshot.gd")): reject("checked_host_required"); return
	_service=weakref(service); _host=weakref(host); _pin=_identity(service)
	if text.is_empty() and head.is_empty():
		if service.generation != 0: reject("checked_parent_required"); return
		_state=State.new("","","","","[]")
	else:
		var cold: Dictionary = load("res://scripts/rewards/compact_v6_snapshot_package.gd").cold_verify(head,text,service.source,service.profile_id,service.mode)
		if not cold.success: reject("checked_cold_parent_rejected"); return
		_state=State.new(V6.digest(cold.record),cold.record_json,text,head,JSON.stringify(cold.receipts,"",true,true))

func _identity(s: PlayableCharacterPersistence) -> String:
	return JSON.stringify([str(s.get_instance_id()),str(s.source.get_instance_id()),s.profile_id,s.mode,s.run_id,PlayableCharacterAdmission.RULES,V6.digest(s.source.to_dictionary())])
func reject(reason: String) -> Dictionary:
	_failed=reason
	return {"success":false,"reason":reason}
func attach(issuer: RefCounted) -> Dictionary:
	if _issuer != null or not _failed.is_empty(): return reject("checked_context_already_bound_or_invalid")
	_issuer=weakref(issuer)
	return guard(issuer)
func guard(issuer: RefCounted) -> Dictionary:
	if not _failed.is_empty(): return {"success":false,"reason":_failed}
	var s: PlayableCharacterPersistence = _service.get_ref()
	if _issuer == null or _issuer.get_ref()!=issuer or s==null or s.source==null or _identity(s)!=_pin: return reject("checked_owner_or_source_changed")
	if (issuer._parent.is_empty() and not _state.record.is_empty()) or (not issuer._parent.is_empty() and V6.digest(issuer._parent)!=_state.record): return reject("checked_parent_changed")
	var host: RefCounted=_host.get_ref() if _host!=null else null
	var actual: Variant = host._fresh(true) if host!=null and host._s2==issuer else null
	if not actual is Dictionary or not actual.get("success",false): return reject("checked_fresh_authority_unavailable")
	if actual.text==_state.package_text and actual.head_text==_state.head: return {"success":true}
	if _built!=null and actual.text==_built.package_text and actual.head_text==_built.head and actual.get("already_applied",false): return {"success":true}
	return reject("checked_acknowledged_head_changed")

# Full candidate encode/semantic proof ONCE; parent already proved at admission
# or exact acknowledged adoption. Public V6 validate_extension remains full.
func encode_candidate(issuer: RefCounted, record: Dictionary) -> Dictionary:
	var valid:=guard(issuer)
	if not valid.success: return valid
	if _candidate!=null or _prepared!=null: return reject("checked_operation_already_proved")
	var s: PlayableCharacterPersistence = _service.get_ref()
	var original: Dictionary=CharacterSaveContract.decode(s._prepared.document).payload
	if V6._projection(record)!=original: return reject("checked_projection_changed")
	var before: Dictionary=V6._projection(issuer._parent) if not issuer._parent.is_empty() else {}
	var order: Dictionary=issuer._ordered_delta(original,before,s)
	if not order.success or record.evidence.order!=issuer._parent.get("evidence",{}).get("order",[])+order.get("entries",[]): return reject("checked_causal_order_changed")
	var encoded:=V6.encode(record,s.source)
	if not encoded.success: return encoded
	if not issuer._parent.is_empty():
		var extension:=V6._extension_rules(issuer._parent,record,s.source)
		if not extension.success: return extension
	_candidate=State.new(V6.digest(record),encoded.text,"","","")
	return encoded

# S3 has already fully encoded and extension-verified its typed fixed proof.
# No result is consumable until it is bound to the actual S2-owned pending ref.
func bind(issuer: RefCounted, prepared: RefCounted, credit: bool = false) -> Dictionary:
	var valid:=guard(issuer)
	if not valid.success: return valid
	if _prepared!=null: return reject("checked_operation_already_bound")
	if issuer._pending!=prepared: return reject("checked_foreign_prepared")
	var b: Dictionary=prepared.copy()
	var s: PlayableCharacterPersistence=_service.get_ref()
	if credit:
		if issuer._credit_proposal.is_empty(): return reject("checked_credit_authority_missing")
		var cold:=V6.decode(b.candidate_text,s.source)
		if not cold.success or V6._projection(cold.record)!=issuer._credit_proposal.payload: return reject("checked_credit_proof_mismatch")
		var extension:=V6._extension_rules(issuer._parent,cold.record,s.source)
		if not extension.success: return reject("checked_credit_extension_mismatch")
		_candidate=State.new(V6.digest(cold.record),b.candidate_text,"","","")
	if _candidate==null or b.candidate_text!=_candidate.text: return reject("checked_candidate_not_proved")
	var r: Dictionary=CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(_candidate.text).payload_json))
	if not credit and b.binding!=issuer._binding_for(CharacterSaveContract.decode(s._prepared.document).payload,s): return reject("checked_original_binding_changed")
	var request: Dictionary=issuer._credit_proposal if credit else s._prepared
	if r.operations.back()!={"id":request.transaction_id,"request_digest":V6.digest(b.binding)}: return reject("checked_operation_binding_changed")
	_prepared=weakref(prepared); _prepared_digest=prepared.digest()
	_runtime_pin=issuer._credit_runtime(issuer._session.get_ref())
	return matches(issuer,prepared)

func matches(issuer: RefCounted, prepared: RefCounted) -> Dictionary:
	var valid:=guard(issuer)
	if not valid.success: return valid
	if _prepared==null or _prepared.get_ref()!=prepared or issuer._pending!=prepared or prepared.digest()!=_prepared_digest: return reject("checked_prepared_identity_changed")
	var b: Dictionary=prepared.copy()
	if _candidate==null or b.candidate_text!=_candidate.text or b.candidate_digest!=_candidate.text.sha256_text(): return reject("checked_candidate_bytes_changed")
	var s: PlayableCharacterPersistence=_service.get_ref()
	var session: ArenaCombatSession=issuer._session.get_ref() if issuer._session!=null else null
	if session==null or issuer._credit_runtime(session)!=_runtime_pin: return reject("checked_runtime_changed")
	if not issuer._credit_proposal.is_empty():
		if V6.digest(issuer._credit_proposal)!=b.binding.legacy_prepared_digest or b.binding.quote!=issuer._credit_quote or issuer._credit_approval!=V6.digest(issuer._credit_quote): return reject("checked_credit_request_changed")
	else:
		if V6.digest(s._prepared)!=b.binding.legacy_prepared_digest or b.binding.expected_head!=issuer.head() or b.binding.run_policy!=s.get_run_reward_policy(): return reject("checked_request_changed")
		if b.binding.event_start!=issuer._start or b.binding.event_end!=issuer._cursor or b.binding.events_json!=JSON.stringify(issuer._facts,"",true,true): return reject("checked_events_changed")
		var events: Dictionary=issuer._unchanged_events(session)
		if not events.success: return reject("checked_live_events_changed")
		var binding:=CharacterProfileProjection.fingerprint(s._prepared)
		var permit: Dictionary=s._verify("commit",binding)
		if not permit.get("authorized",false) or permit.get("binding")!=binding: return reject("checked_gameplay_permit_lost")
	return {"success":true}

func package_input(issuer: RefCounted, prepared: RefCounted) -> Dictionary:
	var valid:=matches(issuer,prepared)
	if not valid.success: return valid
	# Copies reconstructed from privately owned immutable bytes, never aliases.
	var r: Dictionary=CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(_candidate.text).payload_json))
	return {"success":true,"record":r,"text":_candidate.text,"entries":CharacterSaveContract._normalize_json_numbers(JSON.parse_string(_state.receipts))}

func remember_package(issuer: RefCounted, prepared: RefCounted, built: Dictionary) -> Dictionary:
	var valid:=matches(issuer,prepared)
	if not valid.success: return valid
	# Called only by W's checked constructor; require its exact record frame and
	# head digest. This stores immutable bytes, no caller 'verified' property.
	var frames: PackedStringArray=built.text.split("\n")
	var head: Dictionary=JSON.parse_string(built.head_text).body
	if frames.size()!=5 or frames[1]!=_candidate.text or head.package_sha256!=built.text.sha256_text(): return reject("checked_package_binding_changed")
	_built=State.new(_candidate.record,_candidate.text,built.text,built.head_text,JSON.stringify(JSON.parse_string(frames[2]).entries,"",true,true))
	return {"success":true}

func adopt_record(issuer: RefCounted, prepared: RefCounted) -> Dictionary:
	var valid:=matches(issuer,prepared)
	if not valid.success: return valid
	var actual: Dictionary=_host.get_ref()._fresh(true)
	if _built==null or not actual.get("already_applied",false) or actual.text!=_built.package_text or actual.head_text!=_built.head: return reject("checked_exact_acknowledgement_required")
	var r: Dictionary=CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(_candidate.text).payload_json))
	_state=_built; _candidate=null; _built=null; _prepared=null; _prepared_digest=""; _runtime_pin=""
	return {"success":true,"record":r}

func cancel() -> void: reject("checked_context_canceled")
