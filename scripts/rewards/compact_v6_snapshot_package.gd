extends RefCounted
# Dormant 45W Architecture B package only. No storage, coordinator, wallet or
# playable admission. A valid local package is not authorization to earn/spend.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Scan = preload("res://scripts/rewards/character_backup_contract.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const FORMAT := "itank_arena_snapshot_ledger"
const VERSION := 1
const HEAD_FORMAT := "itank_arena_snapshot_head"
const HEAD_VERSION := 2
const RECEIPTS_FORMAT := "itank_arena_snapshot_receipts"
const MAX_BYTES := 24 * 1024 * 1024
const MAX_RECEIPT_BYTES := 4 * 1024 * 1024
const MAX_RECEIPTS := 4096
const STATE_KEYS := ["profile","namespace","source_digest","rules_revision","epoch","sequence","record_parent_digest","record_digest","record_sha256","ledger_digest","evidence_digest","checkpoint_digest","current_digest","journal_digest","operation_count","id_count"]

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details,"restore_authorized":false}
static func canonical(value: Variant) -> String: return JSON.stringify(value,"",true,true)

static func _json(text: String, limit: int) -> Dictionary:
	if not Scan.scan_json(text,limit).success: return fail("invalid_json_or_limit")
	var parser := JSON.new()
	if parser.parse(text) != OK: return fail("invalid_json")
	var v: Variant = Contract._normalize_json_numbers(parser.data)
	if not v is Dictionary or canonical(v) != text: return fail("noncanonical_json")
	return {"success":true,"value":v}

static func _boundary(r: Dictionary) -> bool:
	return r.current.has_all(["recovery","run_history","equipment_state"]) and r.current.recovery is Dictionary and not r.current.recovery.is_empty() and r.current.run_history is Array and not r.current.run_history.is_empty() and r.current.equipment_state is Dictionary

static func _state(r: Dictionary, text: String) -> Dictionary:
	return {"profile":r.current.character_id,"namespace":r.current.profile_namespace,"source_digest":r.source_digest,"rules_revision":r.current.rules_revision,"epoch":r.head.epoch,"sequence":r.head.sequence,"record_parent_digest":r.head.parent_digest,"record_digest":V6.digest(r),"record_sha256":text.sha256_text(),"ledger_digest":V6.digest(r.applied_ids),"evidence_digest":V6.digest(r.evidence),"checkpoint_digest":V6.digest(r.current.get("recovery",{})),"current_digest":V6.digest(r.current),"journal_digest":V6.digest(r.recent_journal),"operation_count":r.operations.size(),"id_count":r.applied_ids.size()}

static func _entry(kind: String, state: Dictionary, operation: Dictionary, parent: Variant) -> Dictionary:
	var body := {"kind":kind,"state":state,"operation":operation,"parent":parent}
	return {"body":body,"digest":V6.digest(body)}

static func _parent(entry: Dictionary) -> Dictionary:
	var s: Dictionary = entry.body.state
	return {"epoch":s.epoch,"sequence":s.sequence,"record_digest":s.record_digest,"record_sha256":s.record_sha256,"receipt_digest":entry.digest,"operation_id":entry.body.operation.id,"request_digest":entry.body.operation.request_digest}

static func _manifest(state: Dictionary, entries: Array) -> Dictionary:
	return state.merged({"format":FORMAT,"version":VERSION,"receipt_count":entries.size(),"receipt_tip":entries.back().digest,"receipts_digest":V6.digest(entries)})

static func _text(manifest: Dictionary, record_json: String, entries: Array) -> String:
	var body := canonical(manifest)+"\n"+record_json+"\n"+canonical({"format":RECEIPTS_FORMAT,"version":1,"entries":entries})+"\n"
	return body+canonical({"kind":"integrity","sha256":body.sha256_text()})+"\n"

static func _head(m: Dictionary, text: String) -> Dictionary:
	return {"format":HEAD_FORMAT,"version":HEAD_VERSION,"package_format":FORMAT,"package_version":VERSION,"profile":m.profile,"namespace":m.namespace,"source_digest":m.source_digest,"rules_revision":m.rules_revision,"epoch":m.epoch,"sequence":m.sequence,"record_digest":m.record_digest,"record_sha256":m.record_sha256,"package_sha256":text.sha256_text(),"manifest_digest":V6.digest(m),"receipt_tip":m.receipt_tip,"replica":{"identity":[m.profile,m.namespace,m.epoch,m.sequence,"latest_exact_replica"],"sha256":text.sha256_text()}}

static func _seal_head(body: Dictionary) -> String:
	return canonical({"body":body,"sha256":V6.digest(body)})

# Root wraps a fully verified V6 snapshot; it does not invent absent old commit
# receipts. An anchor may begin at sequence >1 and proves no earlier path.
static func build(record_json: String, source: CombatCharacterDefinitionResource, profile: String, scope: String, parent_package: String = "", parent_head: String = "") -> Dictionary:
	var started := Time.get_ticks_usec()
	var checked := V6.decode(record_json,source)
	if not checked.success: return checked
	var candidate_validation_ms := float(Time.get_ticks_usec()-started)/1000.0
	var r: Dictionary = checked.record
	if not _boundary(r): return fail("current_checkpoint_evidence_required")
	if r.current.character_id != profile or r.current.profile_namespace != scope or r.current.rules_revision != PlayableCharacterAdmission.RULES: return fail("target_identity_or_rules_mismatch")
	var outer := _json(record_json,V6.MAX_BYTES)
	if not outer.success: return outer
	var entries: Array = []
	var parent_started := Time.get_ticks_usec()
	if not parent_package.is_empty() or not parent_head.is_empty():
		var prior := cold_verify(parent_head,parent_package,source,profile,scope)
		if not prior.success: return fail("parent_not_verified",prior)
		var extension := V6.validate_extension(prior.record,r,source)
		if not extension.success: return extension
		entries = prior.receipts.duplicate(true)
	var parent_validation_ms := float(Time.get_ticks_usec()-parent_started)/1000.0
	return _pack_verified(r,record_json,entries,started,candidate_validation_ms,parent_validation_ms)

# Only the owned operation capability can select this path. Public cold and
# untrusted build APIs continue full semantic verification above/below.
static func build_checked(context: RefCounted, issuer: RefCounted, prepared: RefCounted) -> Dictionary:
	var started:=Time.get_ticks_usec()
	if context==null or context.get_script()!=load("res://scripts/rewards/compact_v6_checked_operation.gd"): return fail("owned_checked_operation_required")
	var input: Dictionary=context.package_input(issuer,prepared)
	if not input.success: return input
	var r: Dictionary=input.record
	if not _boundary(r): return fail("current_checkpoint_evidence_required")
	var built:=_pack_verified(r,input.text,input.entries,started,0.0,0.0)
	if not built.success: return built
	var bound: Dictionary=context.remember_package(issuer,prepared,built)
	return built if bound.success else bound

static func _pack_verified(r: Dictionary, record_json: String, entries: Array, started: int, candidate_validation_ms: float, parent_validation_ms: float) -> Dictionary:
	var state:=_state(r,record_json)
	var parent: Variant=null if entries.is_empty() else _parent(entries.back())
	var receipt_started := Time.get_ticks_usec()
	if entries.size() >= MAX_RECEIPTS: return fail("receipt_limit")
	entries.append(_entry("anchor" if parent == null else "commit",state,r.operations.back().duplicate(true),parent))
	var m := _manifest(state,entries)
	var receipt_ms := float(Time.get_ticks_usec()-receipt_started)/1000.0
	var encoding_started := Time.get_ticks_usec()
	if canonical(m).to_utf8_buffer().size() > 65536: return fail("manifest_limit")
	var text := _text(m,record_json,entries)
	if text.to_utf8_buffer().size() > MAX_BYTES or canonical({"format":RECEIPTS_FORMAT,"version":1,"entries":entries}).to_utf8_buffer().size() > MAX_RECEIPT_BYTES: return fail("package_limit")
	var head := _seal_head(_head(m,text))
	if head.to_utf8_buffer().size() > 16384: return fail("head_limit")
	return {"success":true,"text":text,"replica":text,"head_text":head,"package_bytes":text.to_utf8_buffer().size(),"replica_bytes":text.to_utf8_buffer().size(),"receipt_bytes":canonical(entries).to_utf8_buffer().size(),"build_ms":float(Time.get_ticks_usec()-started)/1000.0,"metrics":{"candidate_validation_ms":candidate_validation_ms,"parent_validation_ms":parent_validation_ms,"receipt_ms":receipt_ms,"encoding_ms":float(Time.get_ticks_usec()-encoding_started)/1000.0},"restore_authorized":false}

# Complete semantic verification on every invocation. No cached decisions,
# persisted flags, original files, reverse deltas or previous character states.
static func verify_package(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var started := Time.get_ticks_usec()
	if source == null or not CharacterSaveStorage._valid_id(profile) or scope not in ["normal","dev_normal"]: return fail("trusted_target_required")
	if text.to_utf8_buffer().size() > MAX_BYTES or not text.ends_with("\n"): return fail("package_limit_or_truncation")
	var lines := text.trim_suffix("\n").split("\n")
	if lines.size() != 4: return fail("invalid_package_frames")
	var manifest := _json(lines[0],65536)
	var receipts := _json(lines[2],MAX_RECEIPT_BYTES)
	var footer := _json(lines[3],1024)
	if not manifest.success or not receipts.success or not footer.success: return fail("invalid_package_json")
	var m: Dictionary = manifest.value; var chain: Dictionary = receipts.value; var f: Dictionary = footer.value
	if not Scan.keys(m,STATE_KEYS+["format","version","receipt_count","receipt_tip","receipts_digest"]) or m.format != FORMAT or typeof(m.version) != TYPE_INT or m.version != VERSION: return fail("unsupported_package_version")
	if not Scan.keys(f,["kind","sha256"]) or f.kind != "integrity" or f.sha256 != (lines[0]+"\n"+lines[1]+"\n"+lines[2]+"\n").sha256_text(): return fail("package_checksum_mismatch")
	if not Scan.keys(chain,["format","version","entries"]) or chain.format != RECEIPTS_FORMAT or typeof(chain.version) != TYPE_INT or chain.version != 1 or not chain.entries is Array or chain.entries.is_empty() or chain.entries.size() > MAX_RECEIPTS: return fail("invalid_receipt_container")
	if m.profile != profile or m.namespace != scope or m.source_digest != V6.digest(source.to_dictionary()) or m.rules_revision != PlayableCharacterAdmission.RULES: return fail("trusted_identity_source_or_rules_mismatch")
	var current_outer := _json(lines[1],V6.MAX_BYTES)
	if not current_outer.success: return current_outer
	var decoded := V6.decode(lines[1],source)
	if not decoded.success: return fail("current_v6_validation_failed",decoded)
	var r: Dictionary = decoded.record
	if not _boundary(r): return fail("current_checkpoint_evidence_required")
	var facts := _state(r,lines[1])
	for field: String in STATE_KEYS:
		if m[field] != facts[field]: return fail("manifest_current_binding_mismatch",{"field":field})
	var entries: Array = chain.entries
	if not V6._uint(m.receipt_count) or m.receipt_count != entries.size() or m.receipts_digest != V6.digest(entries): return fail("receipt_count_or_digest_mismatch")
	var seen := {}
	for i in range(entries.size()):
		var e: Variant = entries[i]
		if not e is Dictionary or not Scan.keys(e,["body","digest"]) or not e.body is Dictionary or e.digest != V6.digest(e.body) or not Scan.keys(e.body,["kind","state","operation","parent"]) or not e.body.state is Dictionary or not Scan.keys(e.body.state,STATE_KEYS): return fail("invalid_commit_receipt")
		var s: Dictionary = e.body.state
		for field: String in ["profile","namespace","source_digest","rules_revision","epoch"]:
			if s[field] != facts[field]: return fail("receipt_identity_changed")
		for field: String in ["record_digest","record_sha256","ledger_digest","evidence_digest","checkpoint_digest","current_digest","journal_digest"]:
			if not V6._hash(s[field]): return fail("invalid_receipt_digest")
		if not V6._uint(s.sequence) or s.sequence < 1 or not V6._uint(s.operation_count) or s.operation_count < 1 or not V6._uint(s.id_count) or (s.record_parent_digest != null and not V6._hash(s.record_parent_digest)): return fail("invalid_receipt_state")
		if (s.sequence == 1) != (s.record_parent_digest == null): return fail("receipt_record_parent_mismatch")
		var op: Variant = e.body.operation
		var index: int = r.operations.size()-1-(facts.sequence-s.sequence)
		if not op is Dictionary or index < 0 or index >= r.operations.size() or op != r.operations[index] or seen.has(op.id): return fail("receipt_transaction_binding_mismatch")
		seen[op.id] = true
		if i == 0:
			if e.body.kind != "anchor" or e.body.parent != null: return fail("missing_snapshot_anchor")
		else:
			var old: Dictionary = entries[i-1]
			if e.body.kind != "commit" or e.body.parent != _parent(old) or s.sequence != old.body.state.sequence+1 or s.record_parent_digest != old.body.state.record_digest or s.operation_count != old.body.state.operation_count+1 or s.id_count < old.body.state.id_count: return fail("receipt_parent_or_order_mismatch")
	if entries.back().body.state != facts or entries.back().body.operation != r.operations.back() or m.receipt_tip != entries.back().digest: return fail("latest_receipt_mismatch")
	return {"success":true,"record":r,"record_json":lines[1],"projection":V6._projection(r),"manifest":m,"receipts":entries,"package_sha256":text.sha256_text(),"cold_ms":float(Time.get_ticks_usec()-started)/1000.0,"restore_authorized":false}

static func _read_head(text: String) -> Dictionary:
	if text.is_empty(): return fail("head_authority_missing")
	var outer := _json(text,16384)
	if not outer.success: return fail("invalid_head_json")
	var o: Dictionary = outer.value
	if not Scan.keys(o,["body","sha256"]) or not o.body is Dictionary or o.sha256 != V6.digest(o.body): return fail("head_checksum_mismatch")
	var h: Dictionary = o.body
	if not Scan.keys(h,["format","version","package_format","package_version","profile","namespace","source_digest","rules_revision","epoch","sequence","record_digest","record_sha256","package_sha256","manifest_digest","receipt_tip","replica"]) or h.format != HEAD_FORMAT or typeof(h.version) != TYPE_INT or h.version != HEAD_VERSION or h.package_format != FORMAT or typeof(h.package_version) != TYPE_INT or h.package_version != VERSION: return fail("unsupported_head_version")
	return {"success":true,"head":h}

static func cold_verify(head_text: String, text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var h := _read_head(head_text)
	if not h.success: return h
	if h.head.package_sha256 != text.sha256_text(): return fail("head_current_digest_mismatch")
	var checked := verify_package(text,source,profile,scope)
	if not checked.success: return checked
	if h.head != _head(checked.manifest,text): return fail("head_current_or_replica_binding_mismatch")
	return checked.merged({"head":h.head})

# Pure repair decision only: returns exact bytes, performs no publication.
static func recover(head_text: String, current: String, replica: String, source: CombatCharacterDefinitionResource, profile: String, scope: String, other_head: String = "") -> Dictionary:
	var started := Time.get_ticks_usec()
	var head := _read_head(head_text)
	if not head.success: return head
	if not other_head.is_empty() and other_head != head_text: return fail("conflicting_head_authority")
	var primary := cold_verify(head_text,current,source,profile,scope)
	if primary.success:
		return {"success":true,"text":current,"replica":current,"repair_current":false,"repair_replica":replica != current,"package_sha256":current.sha256_text(),"recovery_ms":float(Time.get_ticks_usec()-started)/1000.0,"restore_authorized":false}
	var mirror := cold_verify(head_text,replica,source,profile,scope)
	if not mirror.success: return fail("exact_acknowledged_state_unrecoverable",{"current":primary.reason,"replica":mirror.reason})
	return {"success":true,"text":replica,"replica":replica,"repair_current":true,"repair_replica":false,"package_sha256":replica.sha256_text(),"recovery_ms":float(Time.get_ticks_usec()-started)/1000.0,"restore_authorized":false}

# Diagnostic only. Direct extension is independently checkable using both full
# endpoints. A longer receipt path cannot validate omitted intermediate states.
# NO result from this prototype authorizes an occupied-profile restore.
static func relationship(known_head: String, known: String, incoming_head: String, incoming: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var a := cold_verify(known_head,known,source,profile,scope)
	var b := cold_verify(incoming_head,incoming,source,profile,scope)
	if not a.success or not b.success: return fail("relationship_endpoint_invalid")
	if known_head == incoming_head and known == incoming: return {"success":true,"classification":"exact_installed","restore_authorized":false}
	if a.record.head.epoch != b.record.head.epoch: return fail("unrelated_epoch")
	if b.record.head.sequence < a.record.head.sequence: return fail("older_state_rejected")
	if b.record.head.sequence == a.record.head.sequence: return fail("conflicting_same_sequence")
	if b.receipts.size() <= a.receipts.size() or b.receipts.slice(0,a.receipts.size()) != a.receipts: return fail("missing_or_conflicting_lineage_proof")
	if b.record.head.sequence != a.record.head.sequence+1: return fail("receipt_path_requires_intermediate_semantic_proof",{"structural_path":true})
	var valid := V6.validate_extension(a.record,b.record,source)
	if not valid.success: return fail("invalid_direct_extension",valid)
	return {"success":true,"classification":"verified_direct_extension","restore_authorized":false}
