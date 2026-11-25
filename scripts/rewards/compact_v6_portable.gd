extends RefCounted

# Dormant Pass D. Deltas encode recovery/ancestry; they NEVER authorize a game
# command. Both endpoints and every transition must pass the existing V6 rules.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Scan = preload("res://scripts/rewards/character_backup_contract.gd")
const FORMAT := "itank_arena_compact_portable"
const MAX_BYTES := 34 * 1024 * 1024
const MAX_HISTORY_BYTES := 16 * 1024 * 1024
const MAX_TRANSITIONS := 4096

static func fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}

static func canonical(value: Variant) -> String:
	return JSON.stringify(value,"",true,true)

static func history_text(history: Array) -> String:
	return canonical({"version":1,"transitions":history})

static func _diff(a: Variant, b: Variant, path: Array, changes: Array) -> void:
	if typeof(a) == typeof(b) and a == b: return
	if a is Dictionary and b is Dictionary:
		var keys: Array = a.keys()
		for key: Variant in b:
			if not keys.has(key): keys.append(key)
		keys.sort()
		for key: String in keys:
			if a.has(key) and b.has(key): _diff(a[key],b[key],path+[key],changes)
			else: changes.append({"kind":"field","path":path+[key],"before":{"exists":a.has(key),"value":a.get(key)},"after":{"exists":b.has(key),"value":b.get(key)}})
	elif a is Array and b is Array:
		var prefix := 0
		while prefix < mini(a.size(),b.size()) and a[prefix] == b[prefix]: prefix += 1
		var suffix := 0
		while suffix < mini(a.size(),b.size())-prefix and a[a.size()-1-suffix] == b[b.size()-1-suffix]: suffix += 1
		changes.append({"kind":"array","path":path,"index":prefix,"before_count":a.size(),"after_count":b.size(),"removed":a.slice(prefix,a.size()-suffix),"added":b.slice(prefix,b.size()-suffix)})
	else: changes.append({"kind":"field","path":path,"before":{"exists":true,"value":a},"after":{"exists":true,"value":b}})

static func transition(before: Dictionary, after: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var valid := V6.validate_extension(before,after,source)
	if not valid.success: return valid
	var changes: Array = []
	_diff(before,after,[],changes)
	var step := {"version":1,"epoch":after.head.epoch,"sequence":after.head.sequence,"parent":V6.digest(before),"record":V6.digest(after),"operation_id":after.operations.back().id,"changes":changes}
	return {"success":true,"transition":step}

static func apply(record: Dictionary, step: Dictionary, reverse: bool, source: CombatCharacterDefinitionResource) -> Dictionary:
	if not Scan.keys(step,["version","epoch","sequence","parent","record","operation_id","changes"]) or step.version != 1 or not step.changes is Array or step.changes.size() > 4096 or not V6._hash(step.parent) or not V6._hash(step.record) or step.epoch != record.head.epoch or not V6._uint(step.sequence): return fail("invalid_transition")
	if V6.digest(record) != (step.record if reverse else step.parent): return fail("transition_endpoint_mismatch")
	var output := record.duplicate(true)
	var changes: Array = step.changes.duplicate(true)
	if reverse: changes.reverse()
	for change: Variant in changes:
		if not change is Dictionary or not change.get("path") is Array or change.path.is_empty() or change.path.size() > 64: return fail("invalid_delta_path")
		var parent: Variant = output
		for i in range(change.path.size()-1):
			var key: Variant = change.path[i]
			if not key is String or not parent is Dictionary or not parent.has(key): return fail("missing_delta_parent")
			parent = parent[key]
		var key: Variant = change.path.back()
		if not key is String or not parent is Dictionary: return fail("invalid_delta_parent")
		if change.get("kind") == "array":
			if not Scan.keys(change,["kind","path","index","before_count","after_count","removed","added"]) or not parent.get(key) is Array or not change.removed is Array or not change.added is Array or not V6._uint(change.index) or not V6._uint(change.before_count) or not V6._uint(change.after_count): return fail("invalid_array_delta")
			var old: Array = change.added if reverse else change.removed
			var new: Array = change.removed if reverse else change.added
			var array: Array = parent[key]
			if array.size() != (change.after_count if reverse else change.before_count) or change.index > array.size() or change.index+old.size() > array.size() or array.slice(change.index,change.index+old.size()) != old: return fail("array_delta_precondition_failed")
			parent[key] = array.slice(0,change.index)+new+array.slice(change.index+old.size())
		else:
			if not Scan.keys(change,["kind","path","before","after"]) or change.kind != "field" or not change.before is Dictionary or not change.after is Dictionary: return fail("invalid_field_delta")
			var old: Dictionary = change.after if reverse else change.before
			var new: Dictionary = change.before if reverse else change.after
			if not Scan.keys(old,["exists","value"]) or not Scan.keys(new,["exists","value"]) or not old.exists is bool or not new.exists is bool or parent.has(key) != old.exists or (old.exists and (typeof(parent[key]) != typeof(old.value) or parent[key] != old.value)): return fail("field_delta_precondition_failed")
			if new.exists: parent[key] = new.value
			else: parent.erase(key)
	if V6.digest(output) != (step.parent if reverse else step.record): return fail("reconstructed_digest_mismatch")
	var after: Dictionary = record if reverse else output
	if after.head.sequence != step.sequence or after.operations.back().id != step.operation_id: return fail("transition_identity_mismatch")
	var valid := V6.validate_extension(output,record,source) if reverse else V6.validate_extension(record,output,source)
	if not valid.success: return fail("transition_rule_rejected",valid)
	return {"success":true,"record":output}

static func verify_history(record: Dictionary, history: Array, source: CombatCharacterDefinitionResource) -> Dictionary:
	if history.size() > MAX_TRANSITIONS or history.size() != record.head.sequence-1 or history_text(history).to_utf8_buffer().size() > MAX_HISTORY_BYTES: return fail("missing_or_oversized_ancestry")
	var cursor: Dictionary = record
	var previous: Dictionary = {}
	for i in range(history.size()-1,-1,-1):
		if not history[i] is Dictionary: return fail("invalid_transition")
		var restored := apply(cursor,history[i],true,source)
		if not restored.success: return restored
		cursor = restored.record
		if previous.is_empty(): previous = cursor
	if cursor.head.sequence != 1 or cursor.head.parent_digest != null: return fail("ancestry_baseline_missing")
	return {"success":true,"previous":previous}

static func export_record(text: String, history: Array, source: CombatCharacterDefinitionResource) -> Dictionary:
	var decoded := V6.decode(text,source)
	if not decoded.success: return decoded
	var envelope: Variant = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(text))
	if canonical(envelope) != text: return fail("unsupported_noncanonical_record_transport")
	var proof := verify_history(decoded.record,history,source)
	if not proof.success: return proof
	var record: Dictionary = decoded.record
	var header := {"format":FORMAT,"version":1,"profile":record.current.character_id,"namespace":record.current.profile_namespace,"epoch":record.head.epoch,"sequence":record.head.sequence,"document_digest":text.sha256_text(),"transition_count":history.size(),"authored_source":source.to_dictionary()}
	var lines := PackedStringArray([canonical(header),text])
	for step: Dictionary in history: lines.append(canonical(step))
	var body := "\n".join(lines)+"\n"
	var portable := body+canonical({"kind":"integrity","sha256":body.sha256_text()})+"\n"
	if portable.to_utf8_buffer().size() > MAX_BYTES: return fail("portable_size_limit")
	return {"success":true,"text":portable,"record":record,"history":history.duplicate(true),"preview":preview(record)}

static func decode(text: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES or not text.ends_with("\n"): return fail("invalid_portable_size_or_truncation")
	var lines := text.trim_suffix("\n").split("\n")
	if lines.size() < 3 or lines.size() > MAX_TRANSITIONS+3: return fail("invalid_portable_frames")
	var parsed: Array = []
	for line: String in lines:
		var scan := Scan.scan_json(line,V6.MAX_BYTES)
		if not scan.success: return fail("invalid_portable_json",scan)
		var parser := JSON.new()
		if parser.parse(line) != OK: return fail("invalid_portable_json")
		var value: Variant = CharacterSaveContract._normalize_json_numbers(parser.data)
		if not value is Dictionary or canonical(value) != line: return fail("noncanonical_portable_frame")
		parsed.append(value)
	var header: Dictionary = parsed[0]
	if not Scan.keys(header,["format","version","profile","namespace","epoch","sequence","document_digest","transition_count","authored_source"]) or header.format != FORMAT or header.version != 1 or typeof(header.version) != TYPE_INT: return fail("unsupported_portable_format")
	var footer: Dictionary = parsed.back()
	var body := "\n".join(lines.slice(0,lines.size()-1))+"\n"
	if not Scan.keys(footer,["kind","sha256"]) or footer.kind != "integrity" or footer.sha256 != body.sha256_text(): return fail("portable_checksum_mismatch")
	if source == null or header.authored_source != source.to_dictionary(): return fail("untrusted_authored_source")
	if not V6._uint(header.transition_count) or header.transition_count != lines.size()-3 or lines[1].sha256_text() != header.document_digest: return fail("portable_manifest_mismatch")
	var decoded := V6.decode(lines[1],source)
	if not decoded.success: return decoded
	var record: Dictionary = decoded.record
	if record.current.character_id != header.profile or record.current.profile_namespace != header.namespace or record.head.epoch != header.epoch or record.head.sequence != header.sequence: return fail("portable_identity_mismatch")
	var history: Array = parsed.slice(2,parsed.size()-1)
	var proof := verify_history(record,history,source)
	if not proof.success: return proof
	return {"success":true,"text":lines[1],"record":record,"history":history,"previous":proof.previous,"file_digest":text.sha256_text(),"preview":preview(record)}

static func preview(record: Dictionary) -> Dictionary:
	return {"profile":record.current.character_id,"namespace":record.current.profile_namespace,"level":record.current.permanent.level,"expm":record.accounting.expm_total,"expc":record.accounting.expc_available,"equipment":record.current.permanent.equipment_refs.duplicate(),"sequence":record.head.sequence}

static func relationship(pack: Dictionary, current: Dictionary, current_digest: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	var incoming: Dictionary = pack.record
	if current.is_empty(): return {"success":true,"classification":"empty_destination"}
	if current.current.character_id != incoming.current.character_id or current.current.profile_namespace != incoming.current.profile_namespace: return fail("restore_identity_mismatch")
	if pack.text.sha256_text() == current_digest: return {"success":true,"classification":"identical"}
	if incoming.head.epoch != current.head.epoch: return fail("unrelated_epoch")
	if incoming.head.sequence < current.head.sequence: return fail("older_backup_rejected")
	if incoming.head.sequence == current.head.sequence: return fail("conflicting_same_sequence")
	var cursor: Dictionary = incoming
	while cursor.head.sequence > current.head.sequence:
		var step: Dictionary = pack.history[cursor.head.sequence-2]
		var result := apply(cursor,step,true,source)
		if not result.success: return result
		cursor = result.record
	if cursor != current: return fail("unrelated_or_conflicting_branch")
	return {"success":true,"classification":"verified_descendant"}

static func confirmation(file_digest: String, expected: Variant, profile: String, scope: String) -> String:
	return V6.digest({"kind":"explicit_compact_restore","file_digest":file_digest,"expected_head":expected,"profile":profile,"namespace":scope})
