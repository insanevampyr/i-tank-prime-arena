extends RefCounted

# Dormant record/cold codec only. No writer, admission permit or gameplay caller.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Receipts = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Scan = preload("res://scripts/rewards/character_backup_contract.gd")
const FORMAT := "itank_arena_character_snapshot"
const VERSION := 1
const READER_VERSION := 1
const MAX_BODY_BYTES := 16 * 1024 * 1024
const MAX_FILE_BYTES := 24 * 1024 * 1024
const MAX_STRING_BYTES := 1024 * 1024
const MAX_ENTRIES := 50000
const MAX_VALUES := 500000
const MAX_DEPTH := 48
const KEYS := ["epoch","sequence","last_operation_id","source_digest","current","evidence","operations","lifetime_ids","recent_journal"]
const EVIDENCE := ["awards","purchases","growth","settlements","credit","order"]

class Record extends RefCounted:
	# A result owns immutable JSON. No caller receives an internal Dictionary.
	# No API accepts this object as a substitute for cold validation/authority.
	var _json := "":
		set(value):
			if _json.is_empty(): _json=value
	func _init(text: String) -> void: _json=text
	func json() -> String: return _json
	func copy() -> Dictionary:
		return CharacterSaveContract._normalize_json_numbers(JSON.parse_string(_json))
	func projection() -> Dictionary:
		return preload("res://scripts/rewards/compact_character_v6_prototype.gd")._projection(copy())

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}

# Explicit fact assembly, not conversion, verification, grant or publication.
static func assemble(current: Dictionary, evidence: Dictionary, operations: Array, epoch: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	var body := {"epoch":epoch,"sequence":current.get("generation",0),"last_operation_id":operations.back().get("id","") if not operations.is_empty() else "","source_digest":V6.digest(source.to_dictionary()) if source!=null else "","current":current.duplicate(true),"evidence":evidence.duplicate(true),"operations":operations.duplicate(true),"lifetime_ids":[],"recent_journal":operations.slice(maxi(0,operations.size()-20)).duplicate(true)}
	# The exact existing scoped bindings retain every original ID. No ancestry.
	if source!=null and evidence.has_all(EVIDENCE): body.lifetime_ids=V6._ids(body)
	return body

static func validate(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if not _plain(body,0,[0]): return fail("snapshot_field_limit_or_non_json_value")
	var owned: Dictionary=Contract._normalize_json_numbers(body)
	var checked:=_check(owned,source,profile,scope)
	if not checked.success: return checked
	var text:=JSON.stringify(owned,"",true,true)
	if text.to_utf8_buffer().size()>MAX_BODY_BYTES: return fail("snapshot_body_limit")
	return {"success":true,"snapshot":Record.new(text)}

static func encode(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var checked:=validate(body,source,profile,scope)
	if not checked.success: return checked
	var text: String=checked.snapshot.json()
	var envelope:=JSON.stringify({"format":FORMAT,"version":VERSION,"reader_version":READER_VERSION,"body_json":text,"sha256":text.sha256_text()},"",true,true)
	if envelope.to_utf8_buffer().size()>MAX_FILE_BYTES: return fail("snapshot_file_limit")
	return {"success":true,"text":envelope,"snapshot":checked.snapshot}

static func decode_bytes(bytes: PackedByteArray, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if bytes.size()>MAX_FILE_BYTES: return fail("snapshot_file_limit")
	if not _utf8(bytes): return fail("snapshot_invalid_utf8")
	var text:=bytes.get_string_from_utf8()
	if text.to_utf8_buffer()!=bytes: return fail("snapshot_invalid_utf8")
	return decode(text,source,profile,scope)

static func decode(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if text.to_utf8_buffer().size()>MAX_FILE_BYTES: return fail("snapshot_file_limit")
	if not Scan.scan_json(text,MAX_FILE_BYTES).success: return fail("snapshot_envelope_json")
	var parser:=JSON.new()
	if parser.parse(text)!=OK: return fail("snapshot_envelope_json")
	var outer: Variant=Contract._normalize_json_numbers(parser.data)
	if not outer is Dictionary or not V6._keys(outer,["format","version","reader_version","body_json","sha256"]): return fail("snapshot_envelope_fields")
	if outer.format!=FORMAT or typeof(outer.version)!=TYPE_INT or outer.version!=VERSION or typeof(outer.reader_version)!=TYPE_INT or outer.reader_version!=READER_VERSION: return fail("snapshot_unsupported_version")
	if not outer.body_json is String or not V6._hash(outer.sha256): return fail("snapshot_integrity_fields")
	if outer.body_json.to_utf8_buffer().size()>MAX_BODY_BYTES: return fail("snapshot_body_limit")
	if outer.sha256!=outer.body_json.sha256_text(): return fail("snapshot_checksum_mismatch")
	if JSON.stringify(outer,"",true,true)!=text: return fail("snapshot_noncanonical_envelope")
	if not Scan.scan_json(outer.body_json,MAX_BODY_BYTES).success: return fail("snapshot_body_json")
	if parser.parse(outer.body_json)!=OK: return fail("snapshot_body_json")
	var body: Variant=Contract._normalize_json_numbers(parser.data)
	if not body is Dictionary or not _plain(body,0,[0]): return fail("snapshot_field_limit_or_non_json_value")
	if JSON.stringify(body,"",true,true)!=outer.body_json: return fail("snapshot_noncanonical_body")
	var checked:=_check(body,source,profile,scope)
	if not checked.success: return checked
	return {"success":true,"snapshot":Record.new(outer.body_json)}

static func _check(b: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if not V6._keys(b,KEYS): return fail("snapshot_fields")
	if source==null or not V6._hash(b.source_digest) or b.source_digest!=V6.digest(source.to_dictionary()): return fail("snapshot_source_mismatch")
	var identity:=PlayableCharacterAdmission.profile_identity(source.definition_id,scope)
	if not identity.get("success",false) or identity.profile_id!=profile or scope not in ["normal","dev_normal"]: return fail("snapshot_target_mismatch")
	if not b.epoch is String or b.epoch.is_empty() or b.epoch.length()>256 or not V6._uint(b.sequence) or b.sequence<1 or not b.last_operation_id is String: return fail("snapshot_commit_identity")
	if not b.current is Dictionary or not b.evidence is Dictionary or not V6._keys(b.evidence,EVIDENCE): return fail("snapshot_sections")
	var c: Dictionary=b.current; var e: Dictionary=b.evidence
	for key: String in ["character_id","profile_namespace","rules_revision"]:
		if not c.get(key) is String: return fail("snapshot_identity_or_generation")
	if not V6._uint(c.get("generation")): return fail("snapshot_identity_or_generation")
	if c.get("character_id")!=profile or c.get("profile_namespace")!=scope or c.get("rules_revision")!=PlayableCharacterAdmission.RULES or c.get("generation")!=b.sequence: return fail("snapshot_identity_or_generation")
	if not c.get("permanent") is Dictionary or not c.get("recovery") is Dictionary or not c.get("run_history") is Array or not c.get("equipment_state") is Dictionary: return fail("snapshot_checkpoint_required")
	var p: Dictionary=c.permanent
	if not p.has_all(["level","resource_maxima","ability_allowances","equipment_refs","inventory_quantities","xp_baseline"]) or not V6._uint(p.level) or p.level<1 or not p.equipment_refs is Array or not p.resource_maxima is Dictionary or not p.ability_allowances is Dictionary or not p.inventory_quantities is Dictionary or not p.xp_baseline is Dictionary: return fail("snapshot_permanent_fields")
	for ref: Variant in p.equipment_refs:
		if not _id(ref): return fail("snapshot_permanent_fields")
	if not c.get("lineage") is Dictionary or not V6._keys(c.lineage,Profiles.LINEAGE_FIELDS): return fail("snapshot_lineage_fields")
	for key: String in Profiles.LINEAGE_FIELDS:
		if key!="mode_history" and not _id(c.lineage[key]): return fail("snapshot_lineage_fields")
	if not c.lineage.mode_history is Array: return fail("snapshot_lineage_fields")
	for mode: Variant in c.lineage.mode_history:
		if not mode is String: return fail("snapshot_lineage_fields")
	for key: String in ["purchases","settlements","expc_credits"]:
		if c.has(key): return fail("snapshot_duplicated_evidence")
	if c.permanent.has("growth") or c.permanent.has("award_receipts"): return fail("snapshot_duplicated_evidence")
	for key: String in ["awards","purchases","growth","settlements","order"]:
		if not e[key] is Array or e[key].size()>MAX_ENTRIES: return fail("snapshot_evidence_limit")
	for key: String in ["awards","purchases","growth","settlements"]:
		for row: Variant in e[key]:
			if not row is Dictionary: return fail("snapshot_evidence_row")
	for row: Dictionary in e.awards:
		if not V6._keys(row,["award_id","xp"]) or not _id(row.award_id) or not V6._uint(row.xp): return fail("snapshot_award_row")
	for row: Dictionary in e.purchases:
		if not V6._keys(row,Profiles.purchase_fields(row)+["purchase_id"]): return fail("snapshot_purchase_row")
		for key: String in ["purchase_id","purchase_kind","target_id","source_ref"]:
			if not _id(row[key]): return fail("snapshot_purchase_row")
		for key: String in ["value_before","value_after","cost"]:
			if not V6._uint(row[key]): return fail("snapshot_purchase_row")
	for row: Dictionary in e.growth:
		if not V6._keys(row,Profiles.HISTORY_FIELDS+["growth_id"]) or not _id(row.growth_id) or not _id(row.resource): return fail("snapshot_growth_row")
		for key: String in Profiles.HISTORY_FIELDS:
			if key!="resource" and not V6._uint(row[key]): return fail("snapshot_growth_row")
	if e.credit!=null and not e.credit is Dictionary: return fail("snapshot_credit_row")
	if not b.operations is Array or b.operations.is_empty() or b.operations.size()>MAX_ENTRIES or b.operations.size()!=b.sequence or not b.recent_journal is Array or not b.lifetime_ids is Array: return fail("snapshot_operation_sequence")
	var seen: Dictionary={}
	for op: Variant in b.operations:
		if not op is Dictionary or not V6._keys(op,["id","request_digest"]+(["binding_kind"] if op.has("binding_kind") else [])) or not _id(op.id) or not V6._hash(op.request_digest) or seen.has(op.id): return fail("snapshot_duplicate_or_invalid_operation")
		if op.has("binding_kind") and op.binding_kind!="legacy_document": return fail("snapshot_operation_binding")
		seen[op.id]=true
	if b.last_operation_id!=b.operations.back().id or b.recent_journal!=b.operations.slice(maxi(0,b.operations.size()-20)): return fail("snapshot_journal_or_last_operation")
	# Projection reconstructs only the essential legacy-shaped rule input. It
	# does not reconstruct a previous character or call the old V6 verifier.
	var payload:=V6._projection(b)
	var contract:=Contract.validate(payload)
	if not contract.success: return fail("snapshot_current_contract",contract)
	var receipts:=Receipts._validate_receipts(payload)
	if not receipts.success: return fail("snapshot_receipts",receipts)
	var ownership:=_ownership(payload)
	if not ownership.success: return ownership
	var expected_ids:=V6._ids(b)
	seen={}
	for row: Dictionary in expected_ids:
		if not _id(row.id): return fail("snapshot_invalid_lifetime_id")
		var key:=JSON.stringify([row.scope,row.id])
		if seen.has(key): return fail("snapshot_duplicate_lifetime_id")
		seen[key]=true
	if b.lifetime_ids!=expected_ids: return fail("snapshot_lifetime_binding_mismatch")
	var multipliers:=Profiles.run_xp_multipliers(payload) if payload.has("run_reward_policy") else {}
	for row: Dictionary in e.awards:
		var award:=Profiles.validate_playable_xp_award(payload,row,multipliers)
		if not award.success: return fail("snapshot_award_source",award)
	# The unchanged fixed-credit contract checks its exact target, source
	# baseline, amount and predecessor generation reference. Its original
	# head_digest is retained as a reference, NOT proof of honest local play.
	var credit:=Credit.inspect(payload)
	if not credit.success: return fail("snapshot_credit",credit)
	if credit.total>0:
		var row: Dictionary=e.credit.records[0]
		# The full lifetime operation list supplies the original grant position;
		# no pre-credit state, fake predecessor or historical hash replay needed.
		if b.operations[row.after_generation].id!="expc_credit_"+Credit.GRANT_ID.replace("-",""): return fail("snapshot_credit_operation_binding")
	var temporal:=V6._chronology(payload,e,source)
	if not temporal.success: return fail("snapshot_chronology",temporal)
	var accounting:=V6._accounting(b,source)
	for value: Variant in accounting.values():
		if not V6._uint(value): return fail("snapshot_accounting_range")
	if payload.xp!={"earned":accounting.expm_total,"spent":accounting.spent_expc,"unspent":accounting.expc_available}: return fail("snapshot_accounting")
	var proof: Dictionary={"success":true,"source_digest":b.source_digest,"head_digest":V6.digest(payload),"generation":payload.generation,"end":temporal.end,"growth":temporal.growth}
	# Derived here from full original chronology, never an imported proof flag.
	var verifier:=func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":payload.lineage,"endurance_history":proof}
	var hydrated:=Profiles.hydrate(payload,source,profile,PlayableCharacterAdmission.RULES,verifier)
	if not hydrated.success: return fail("snapshot_projection",hydrated)
	return {"success":true}

static func _ownership(payload: Dictionary) -> Dictionary:
	var terminal: Variant=payload.recovery.get("ledger",{}).get("profile_ownership")
	if not terminal is Dictionary or not V6._keys(terminal,["profile_id","profile_namespace","run_id","items"]) or not terminal.items is Array: return fail("snapshot_terminal_ownership_required")
	for key: String in ["profile_id","profile_namespace","run_id"]:
		if not _id(terminal[key]): return fail("snapshot_ownership_identity")
	if terminal.profile_id!=payload.character_id or terminal.profile_namespace!=payload.profile_namespace or terminal.run_id!=payload.recovery.run_id: return fail("snapshot_ownership_identity")
	var acquisitions: Dictionary={}
	for receipt: Dictionary in payload.settlements:
		if receipt.kind in ["item","currency"]: acquisitions[receipt.content.instance_id]=true
	var seen: Dictionary={};var current: Array=[]
	for row: Variant in terminal.items:
		if not row is Dictionary or not V6._keys(row,["instance_id","definition_id","quantity","provenance","equipped_slots","mutable_state"]) or not _id(row.instance_id) or not _id(row.definition_id) or not V6._uint(row.quantity) or not row.provenance is Dictionary or not row.equipped_slots is Array or not row.mutable_state is Dictionary: return fail("snapshot_terminal_item")
		if not V6._keys(row.provenance,["origin_id","source_ref"]) or not _id(row.provenance.origin_id) or not _id(row.provenance.source_ref): return fail("snapshot_terminal_item")
		for slot: Variant in row.equipped_slots:
			if not _id(slot): return fail("snapshot_terminal_item")
		if seen.has(row.instance_id) or not acquisitions.has(row.instance_id): return fail("snapshot_terminal_item_identity")
		seen[row.instance_id]=true
		if row.quantity>0: current.append(row)
	# Missing terminal rows cannot be invented as consumed items. Preserve every
	# original acquisition, including explicit zero-quantity rows, on cold load.
	if seen.size()!=acquisitions.size(): return fail("snapshot_consumption_evidence_unavailable")
	if current!=payload.items: return fail("snapshot_current_ownership_mismatch")
	var checked:=Receipts._validate_new_items({},payload.merged({"items":terminal.items},true))
	return {"success":true} if checked.success else fail("snapshot_item_origin",checked)

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length()<=1024

# Validate byte sequences before Godot decodes them, avoiding replacement or
# engine Unicode errors on untrusted files. Includes overlong/surrogate bounds.
static func _utf8(bytes: PackedByteArray) -> bool:
	var i:=0
	while i<bytes.size():
		var c: int=bytes[i];i+=1
		if c<128: continue
		var more:=0;var lower:=128;var upper:=191
		if c>=194 and c<=223: more=1
		elif c>=224 and c<=239:
			more=2
			if c==224: lower=160
			if c==237: upper=159
		elif c>=240 and c<=244:
			more=3
			if c==240: lower=144
			if c==244: upper=143
		else: return false
		if i+more>bytes.size() or bytes[i]<lower or bytes[i]>upper: return false
		for n in range(1,more):
			if bytes[i+n]<128 or bytes[i+n]>191: return false
		i+=more
	return true

static func _plain(value: Variant, depth: int, count: Array) -> bool:
	count[0]+=1
	if depth>MAX_DEPTH or count[0]>MAX_VALUES: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL: return true
		TYPE_INT: return value>=-Contract.MAX_SAFE_INTEGER and value<=Contract.MAX_SAFE_INTEGER
		TYPE_FLOAT: return is_finite(value) and absf(value)<=Contract.MAX_SAFE_INTEGER
		TYPE_STRING: return value.to_utf8_buffer().size()<=MAX_STRING_BYTES and value.to_utf8_buffer().get_string_from_utf8()==value
		TYPE_ARRAY:
			if value.size()>MAX_ENTRIES: return false
			for child: Variant in value:
				if not _plain(child,depth+1,count): return false
			return true
		TYPE_DICTIONARY:
			if value.size()>MAX_ENTRIES: return false
			for key: Variant in value:
				if not key is String or key.length()>1024 or not _plain(value[key],depth+1,count): return false
			return true
	return false
