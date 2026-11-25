extends RefCounted

# Dormant successor. The v1 reader and every playable route remain unchanged.
const V1 = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const Commands = preload("res://scripts/rewards/snapshot_command_evidence.gd")
const VERSION := 2
const READER_VERSION := 2

class Record extends V1.Record:
	func command_request(request_id: String, binding: String) -> Dictionary:
		if not V1._id(request_id) or not V1.V6._hash(binding): return {"success":false,"reason":"invalid_command_identity_or_binding"}
		for row: Dictionary in copy().lifetime_ids:
			if row.scope == "item_command" and row.id == request_id:
				return {"success":false,"reason":"duplicate_command" if row.record_digest == binding else "conflicting_command_binding"}
		return {"success":true}

static func command_binding(body: Dictionary, fact: Dictionary) -> String:
	return V1.V6.digest({"epoch":body.epoch,"profile_id":body.current.character_id,"namespace":body.current.profile_namespace,"rules":body.current.rules_revision,"source_digest":body.source_digest,"run_id":body.command_evidence.run_id,"fact":fact})

static func ids(body: Dictionary) -> Array:
	var result: Array = V1.V6._ids(body)
	for fact: Dictionary in body.command_evidence.facts:
		if fact.event_type != "ground_loot_collected":
			result.append({"scope":"item_command","id":fact.request_id,"record_digest":command_binding(body,fact)})
	return result

static func validate(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if not V1._plain(body,0,[0]): return V1.fail("snapshot_field_limit_or_non_json_value")
	var owned: Dictionary = V1.Contract._normalize_json_numbers(body)
	if not V1.V6._keys(owned,V1.KEYS+["command_evidence"]) or not owned.command_evidence is Dictionary: return V1.fail("snapshot_v2_fields")
	if not Commands.structure(owned.command_evidence).success: return V1.fail("snapshot_command_structure")
	var base: Dictionary = owned.duplicate(true)
	base.erase("command_evidence")
	if not base.lifetime_ids is Array: return V1.fail("snapshot_v2_lifetime_fields")
	base.lifetime_ids = []
	for row: Variant in owned.lifetime_ids:
		if not row is Dictionary or not V1.V6._keys(row,["scope","id","record_digest"]) or not row.scope is String: return V1.fail("snapshot_v2_lifetime_fields")
		if row.scope != "item_command": base.lifetime_ids.append(row)
	var original := V1.validate(base,source,profile,scope)
	if not original.success: return original
	var checked := Commands.validate(owned,source)
	if not checked.success: return checked
	if owned.lifetime_ids != ids(owned): return V1.fail("snapshot_v2_lifetime_binding_mismatch")
	var text := JSON.stringify(owned,"",true,true)
	if text.to_utf8_buffer().size() > V1.MAX_BODY_BYTES: return V1.fail("snapshot_body_limit")
	return {"success":true,"format_version":2,"snapshot":Record.new(text)}

static func encode(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var checked := validate(body,source,profile,scope)
	if not checked.success: return checked
	var text: String = checked.snapshot.json()
	var envelope := JSON.stringify({"format":V1.FORMAT,"version":VERSION,"reader_version":READER_VERSION,"body_json":text,"sha256":text.sha256_text()},"",true,true)
	if envelope.to_utf8_buffer().size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	return {"success":true,"format_version":2,"text":envelope,"snapshot":checked.snapshot}

# Pure comparison, not permission to publish or to perform a gameplay effect.
# Both inputs undergo independent cold verification; no trusted-record flag.
static func validate_extension(previous: Dictionary, candidate: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var before := validate(previous,source,profile,scope)
	if not before.success: return before
	var after := validate(candidate,source,profile,scope)
	if not after.success: return after
	var a: Dictionary = before.snapshot.copy(); var b: Dictionary = after.snapshot.copy()
	if a.epoch != b.epoch or a.source_digest != b.source_digest or a.current.lineage != b.current.lineage or a.command_evidence.run_id != b.command_evidence.run_id or b.sequence < a.sequence: return V1.fail("command_extension_identity")
	if b.sequence == a.sequence: return {"success":true,"exact_retry":true} if before.snapshot.json() == after.snapshot.json() else V1.fail("command_same_sequence_conflict")
	if b.operations.slice(0,a.operations.size()) != a.operations or b.command_evidence.facts.slice(0,a.command_evidence.facts.size()) != a.command_evidence.facts: return V1.fail("command_immutable_prefix_changed")
	for key: String in ["awards","purchases","growth","settlements","order"]:
		if b.evidence[key].slice(0,a.evidence[key].size()) != a.evidence[key]: return V1.fail("command_progression_prefix_changed")
	if a.evidence.credit != b.evidence.credit: return V1.fail("command_credit_extension_not_supported")
	var bindings := {}
	for row: Dictionary in b.lifetime_ids: bindings[JSON.stringify([row.scope,row.id])] = row.record_digest
	for row: Dictionary in a.lifetime_ids:
		if bindings.get(JSON.stringify([row.scope,row.id])) != row.record_digest: return V1.fail("command_immutable_lifetime_binding_changed")
	return {"success":true,"exact_retry":false}

static func decode_bytes(bytes: PackedByteArray, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if bytes.size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	if not V1._utf8(bytes): return V1.fail("snapshot_invalid_utf8")
	return decode(bytes.get_string_from_utf8(),source,profile,scope)

static func decode(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if text.to_utf8_buffer().size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	if not V1.Scan.scan_json(text,V1.MAX_FILE_BYTES).success: return V1.fail("snapshot_envelope_json")
	var parser := JSON.new()
	if parser.parse(text) != OK: return V1.fail("snapshot_envelope_json")
	var outer: Variant = V1.Contract._normalize_json_numbers(parser.data)
	if not outer is Dictionary or not V1.V6._keys(outer,["format","version","reader_version","body_json","sha256"]): return V1.fail("snapshot_envelope_fields")
	if outer.get("version") == 1:
		var legacy := V1.decode(text,source,profile,scope)
		if legacy.success: legacy["format_version"] = 1; legacy["command_coverage"] = "unknown_read_only"
		return legacy
	if outer.format != V1.FORMAT or typeof(outer.version) != TYPE_INT or outer.version != VERSION or typeof(outer.reader_version) != TYPE_INT or outer.reader_version != READER_VERSION: return V1.fail("snapshot_unsupported_version")
	if not outer.body_json is String or not V1.V6._hash(outer.sha256): return V1.fail("snapshot_integrity_fields")
	if outer.body_json.to_utf8_buffer().size() > V1.MAX_BODY_BYTES: return V1.fail("snapshot_body_limit")
	if outer.sha256 != outer.body_json.sha256_text(): return V1.fail("snapshot_checksum_mismatch")
	if JSON.stringify(outer,"",true,true) != text: return V1.fail("snapshot_noncanonical_envelope")
	if not V1.Scan.scan_json(outer.body_json,V1.MAX_BODY_BYTES).success or parser.parse(outer.body_json) != OK: return V1.fail("snapshot_body_json")
	var body: Variant = V1.Contract._normalize_json_numbers(parser.data)
	if not body is Dictionary or not V1._plain(body,0,[0]): return V1.fail("snapshot_field_limit_or_non_json_value")
	if JSON.stringify(body,"",true,true) != outer.body_json: return V1.fail("snapshot_noncanonical_body")
	return validate(body,source,profile,scope)
