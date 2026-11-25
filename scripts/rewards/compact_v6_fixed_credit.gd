extends RefCounted

# Dormant S3 fixed transition. No storage calls, UI, wallet or publication.
# codec is supplied to avoid a preload cycle with the full V6 validator.
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const FORMAT := "compact_native_fixed_expc_credit"
const VERSION := 1
const COUNT_FIELDS := ["awards","purchases","growth","settlements","order","operations"]

static func transaction_id() -> String:
	return "expc_credit_"+Credit.GRANT_ID.replace("-","")

static func token(parent: Dictionary, codec: GDScript) -> Dictionary:
	return {"format":6,"epoch":parent.head.epoch,"sequence":parent.head.sequence,"digest":codec.digest(parent)}

static func counts(parent: Dictionary) -> Dictionary:
	var result := {"operations":parent.operations.size()}
	for field: String in COUNT_FIELDS:
		if field != "operations": result[field] = parent.evidence[field].size()
	return result

static func quote(parent: Dictionary, source: CombatCharacterDefinitionResource, storage: Variant, codec: GDScript) -> Dictionary:
	var checked: Dictionary = codec.validate(parent,source)
	if not checked.success: return checked
	var payload: Dictionary = codec._projection(parent)
	if payload.get("character_id") != Credit.PROFILE or payload.get("profile_namespace") != "dev_normal" or payload.get("lineage",{}).get("baseline_digest") != Credit.BASELINE: return fail("expc_credit_profile_mismatch")
	if parent.evidence.credit != null: return {"success":true,"no_op":true,"reason":"credit_already_applied"}
	if parent.compact_version != 1: return fail("unsupported_credit_parent_version")
	var binding := {}
	# Ask the ORIGINAL contract for its exact quote, without approving a grant.
	var offered := Credit.prepare(payload,func(value: Dictionary):
		binding.merge(value,true)
		return {"confirmed":false,"binding":""}
	)
	if offered.get("reason") != "expc_credit_confirmation_required" or binding.is_empty(): return offered
	if storage != null:
		if not storage is Dictionary or not codec._keys(storage,["version","profile","namespace","epoch","sequence","digest","previous"]) or storage.version != 1 or storage.profile != Credit.PROFILE or storage.namespace != "dev_normal" or storage.epoch != parent.head.epoch or storage.sequence != parent.head.sequence or (storage.previous != null and not codec._hash(storage.previous)): return fail("invalid_credit_storage_head")
		var encoded: Dictionary = codec.encode(parent,source)
		if not encoded.success or storage.digest != encoded.text.sha256_text(): return fail("credit_storage_digest_mismatch")
	var witness := {"current":parent.current,"counts":counts(parent),"head":parent.head}
	return {"success":true,"quote":{
		"version":VERSION,"identity":{"profile_id":Credit.PROFILE,"namespace":"dev_normal"},
		"source_digest":parent.source_digest,"rules_revision":payload.rules_revision,
		"parent":token(parent,codec),"parent_compact_version":parent.compact_version,
		"storage":storage,"grant":{"grant_id":Credit.GRANT_ID,"amount":Credit.AMOUNT,"expm_change":0,"request_id":transaction_id()},
		"accounting":parent.accounting.duplicate(true),"credit_status":"absent",
		"predecessor_digest":codec.digest(witness),"legacy_binding":binding,
	}}

static func proposal(parent: Dictionary, source: CombatCharacterDefinitionResource, codec: GDScript) -> Dictionary:
	# Verification-only expected delta. This is NOT an owner approval or permit.
	# Real preparation separately requires the exact trusted confirmation callback.
	var payload: Dictionary = codec._projection(parent)
	var credit := Credit.prepare(payload,func(value: Dictionary): return {"confirmed":true,"binding":Credit.digest(value)})
	if not credit.success or credit.get("no_op",false): return fail("credit_already_applied")
	return Coordinator.prepare(credit.payload,credit.payload.settlements,credit.transaction_id,payload.generation,payload.secured_checkpoints)

static func binding(quote_value: Dictionary, prepared: Dictionary, runtime_digest: String, codec: GDScript) -> Dictionary:
	return {"kind":FORMAT,"quote":quote_value.duplicate(true),"legacy_prepared_digest":codec.digest(prepared),"runtime_digest":runtime_digest}

static func build(parent: Dictionary, source: CombatCharacterDefinitionResource, quote_value: Dictionary, runtime_digest: String, codec: GDScript) -> Dictionary:
	var checked := quote(parent,source,quote_value.get("storage"),codec)
	if not checked.success or checked.get("quote") != quote_value: return fail("credit_quote_changed")
	var prepared := proposal(parent,source,codec)
	if not prepared.success: return prepared
	var bound := binding(quote_value,prepared.prepared,runtime_digest,codec)
	var evidence: Dictionary = parent.evidence.duplicate(true)
	evidence.credit = prepared.prepared.payload.expc_credits.duplicate(true)
	evidence.credit_predecessor = {"format":FORMAT,"version":VERSION,"current":parent.current.duplicate(true),"counts":counts(parent),"parent_head":parent.head.duplicate(true),"binding":bound}
	evidence.order.append({"kind":"credit","id":Credit.GRANT_ID})
	var operations: Array = parent.operations.duplicate(true)
	operations.append({"id":transaction_id(),"request_digest":codec.digest(bound)})
	var head: Dictionary = parent.head.duplicate(true)
	head.sequence += 1; head.parent_digest = codec.digest(parent)
	var current: Dictionary = prepared.prepared.payload.duplicate(true)
	for field: String in ["purchases","settlements","expc_credits"]: current.erase(field)
	current.permanent.erase("growth"); current.permanent.erase("award_receipts")
	var record: Dictionary = codec.assemble(current,evidence,operations,head,source,2)
	var encoded: Dictionary = codec.encode(record,source)
	if not encoded.success: return encoded
	var extension: Dictionary = codec.validate_extension(parent,record,source)
	if not extension.success: return extension
	return {"success":true,"record":record,"text":encoded.text,"prepared":prepared.prepared,"binding":bound}

static func verify(record: Dictionary, source: CombatCharacterDefinitionResource, codec: GDScript) -> Dictionary:
	var proof: Variant = record.evidence.credit_predecessor
	if not proof is Dictionary or not codec._keys(proof,["format","version","current","counts","parent_head","binding"]) or proof.format != FORMAT or typeof(proof.version) != TYPE_INT or proof.version != VERSION or not proof.current is Dictionary or not proof.counts is Dictionary or not proof.parent_head is Dictionary or not proof.binding is Dictionary: return fail("invalid_native_credit_proof")
	var b: Dictionary = proof.binding
	if not codec._keys(b,["kind","quote","legacy_prepared_digest","runtime_digest"]) or b.kind != FORMAT or not b.quote is Dictionary or not codec._hash(b.runtime_digest) or not codec._hash(b.legacy_prepared_digest): return fail("invalid_native_credit_binding")
	if not codec._keys(proof.counts,COUNT_FIELDS): return fail("invalid_native_credit_counts")
	var e := {"credit":null,"credit_predecessor":null}
	for field: String in COUNT_FIELDS:
		var n: Variant = proof.counts[field]
		var values: Array = record.operations if field == "operations" else record.evidence[field]
		if not codec._uint(n) or n > values.size(): return fail("invalid_native_credit_counts")
		if field != "operations": e[field] = values.slice(0,n).duplicate(true)
	if proof.counts.operations < 1 or proof.counts.operations >= record.operations.size(): return fail("missing_native_credit_operation")
	if not proof.current.get("permanent") is Dictionary: return fail("invalid_native_credit_current")
	var shape := Contract.validate(codec._projection({"current":proof.current,"evidence":e}))
	if not shape.success: return fail("invalid_native_credit_current",shape)
	var ops: Array = record.operations.slice(0,proof.counts.operations).duplicate(true)
	var parent: Dictionary = codec.assemble(proof.current,e,ops,proof.parent_head,source,1)
	var quoted := quote(parent,source,b.quote.get("storage"),codec)
	if not quoted.success or quoted.get("quote") != b.quote: return fail("native_credit_predecessor_rejected",quoted)
	if record.head.epoch != parent.head.epoch or record.head.sequence-parent.head.sequence != record.operations.size()-proof.counts.operations: return fail("native_credit_head_mismatch")
	if record.operations.size() == proof.counts.operations+1 and record.head.parent_digest != codec.digest(parent): return fail("native_credit_head_mismatch")
	var expected := proposal(parent,source,codec)
	if not expected.success or b != binding(quoted.quote,expected.prepared,b.runtime_digest,codec): return fail("native_credit_request_binding_mismatch")
	if record.evidence.credit != expected.prepared.payload.expc_credits: return fail("native_credit_record_mismatch")
	if record.operations[proof.counts.operations] != {"id":transaction_id(),"request_digest":codec.digest(b)}: return fail("native_credit_operation_mismatch")
	if proof.counts.order >= record.evidence.order.size() or record.evidence.order[proof.counts.order] != {"kind":"credit","id":Credit.GRANT_ID}: return fail("native_credit_chronology_mismatch")
	return {"success":true,"parent":parent,"payload":codec._projection(parent),"prepared":expected.prepared}

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
