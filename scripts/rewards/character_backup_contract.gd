class_name CharacterBackupContract
extends RefCounted

const FORMAT := "itank_arena_character_backup"
const VERSION := 1
const MAX_GENERATION_BYTES := 16 * 1024 * 1024
# Complete history gets 2x the former budget (the audited g168 was 16,315,722
# bytes). A valid JSON document can at most double when quoted as a JSON string:
# quotes, backslashes and legal whitespace controls each become two bytes.
const MAX_HISTORY_BYTES := 32 * 1024 * 1024
# 4096 rows, each with a <=64-character ASCII transaction ID, plus the fixed
# source-verified manifest fit below 1 MiB, independently of document contents.
const MAX_MANIFEST_BYTES := 1024 * 1024
const MAX_BODY_BYTES := 2 * MAX_HISTORY_BYTES + MAX_MANIFEST_BYTES
# The canonical body is quoted once more; fixed outer fields need <1 KiB.
const MAX_FILE_BYTES := 2 * MAX_BODY_BYTES + 1024
const MAX_DEPTH := 64
const MAX_TOKENS := 500000
const MAX_GENERATIONS := 4096
const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")

# Limits are file-safety bounds, never inventory/progression rules. Oversized
# histories fail explicitly; no generation, item or receipt is omitted.
static func create(history: Dictionary, save_namespace: String, created_utc: String) -> Dictionary:
	var checked := validate_history(history,save_namespace)
	if not checked.success: return checked
	return _encode_checked(checked,save_namespace,created_utc)

# Operation-private, fully validated immutable strings/records only. Imported
# bytes NEVER enter here without validate_history. Native JSON encoding creates
# the exact canonical container: no parsing/second source replay is necessary.
static func _encode_checked(checked: Dictionary, save_namespace: String, created_utc: String) -> Dictionary:
	if not checked.get("success",false) or not valid_date(created_utc): return fail("invalid_backup_date")
	if checked.payload.get("profile_namespace") != save_namespace: return fail("namespace_mismatch")
	var head: Dictionary = checked.records.back()
	var payload: Dictionary = checked.payload
	var body := {"profile_id":payload.character_id,"namespace":save_namespace,"definition_id":payload.definition_id,"rules_revision":payload.rules_revision,"created_utc":created_utc,"head_generation":head.generation,"head_transaction_id":head.transaction_id,"generations":checked.records}
	var body_json := JSON.stringify(body,"",true,true)
	if not check_size(body_json.to_utf8_buffer().size(),MAX_BODY_BYTES).success: return fail("backup_size_limit")
	var digest := body_json.sha256_text()
	var text := JSON.stringify({"format":FORMAT,"backup_version":VERSION,"body_json":body_json,"sha256":digest},"",true,true)
	if not check_size(text.to_utf8_buffer().size(),MAX_FILE_BYTES).success: return fail("backup_size_limit")
	var output := _finish_manifest(body,checked,digest)
	if output.success: output["text"] = text
	return output

static func decode(text: String, expected_namespace: String) -> Dictionary:
	if expected_namespace not in ["normal","dev_normal"]: return fail("unsupported_namespace")
	var scan := scan_json(text,MAX_FILE_BYTES)
	if not scan.success: return scan
	var outer: Variant = JSON.parse_string(text)
	if not outer is Dictionary or not outer.get("body_json") is String: return fail("invalid_backup_container")
	scan = scan_json(outer.body_json,MAX_BODY_BYTES)
	if not scan.success: return scan
	var parsed := _parse_scanned_manifest(outer,expected_namespace)
	if not parsed.success: return parsed
	var checked := validate_history({"success":true,"generations":parsed.manifest.generations},expected_namespace)
	if not checked.success: return checked
	return _finish_manifest(parsed.manifest,checked,outer.sha256)

# Internal phase boundary: callers have already lexically checked both strings.
static func _parse_scanned_manifest(outer: Dictionary, expected_namespace: String) -> Dictionary:
	if not outer is Dictionary or not keys(outer,["format","backup_version","body_json","sha256"]): return fail("invalid_backup_container")
	if outer.format != FORMAT or outer.backup_version != VERSION: return fail("unsupported_backup_version")
	if not outer.body_json is String or not outer.sha256 is String or outer.body_json.sha256_text() != outer.sha256: return fail("backup_checksum_mismatch")
	var body: Variant = Contract._normalize_json_numbers(JSON.parse_string(outer.body_json))
	var fields := ["profile_id","namespace","definition_id","rules_revision","created_utc","head_generation","head_transaction_id","generations"]
	if not body is Dictionary or not keys(body,fields): return fail("invalid_backup_manifest")
	if JSON.stringify(body,"",true,true) != outer.body_json: return fail("noncanonical_backup_body")
	if body.namespace != expected_namespace: return fail("namespace_mismatch")
	if not valid_date(body.created_utc): return fail("invalid_backup_date")
	if not body.generations is Array: return fail("invalid_generation_record")
	for row: Variant in body.generations:
		if not row is Dictionary or not keys(row,["generation","transaction_id","document"]): return fail("invalid_generation_record")
	return {"success":true,"manifest":body}

static func _finish_manifest(body: Dictionary, checked: Dictionary, digest: String) -> Dictionary:
	var payload: Dictionary = checked.payload
	var head: Dictionary = checked.records.back()
	if body.profile_id != payload.character_id or body.definition_id != payload.definition_id or body.rules_revision != payload.rules_revision or body.head_generation != head.generation or body.head_transaction_id != head.transaction_id: return fail("backup_manifest_head_mismatch")
	return {"success":true,"manifest":body,"history":checked.records,"payload":payload,"preview":preview(payload,body.created_utc),"backup_digest":digest}

static func begin_history_validation(history: Dictionary, save_namespace: String) -> Dictionary:
	if save_namespace not in ["normal","dev_normal"]: return fail("unsupported_namespace")
	if not history.get("success",false) or history.get("writer_locked",false) or history.get("pending_write",false): return fail("destination_corrupt_or_uncertain")
	var rows: Variant = history.get("generations")
	if not rows is Array or rows.is_empty() or rows.size() > MAX_GENERATIONS: return fail("invalid_or_oversized_generation_history")
	var starter := Admission.prepare_starter(&"vaelis_thorn",save_namespace)
	if not starter.success: return fail(starter.get("reason","source_unavailable"))
	var frozen: Array = []
	for row: Variant in rows:
		if not row is Dictionary: return fail("invalid_generation_record")
		var copy := {"document":row.get("document"),"transaction_id":row.get("transaction_id")}
		if row.has("generation"): copy["generation"] = row.generation
		frozen.append(copy)
	return {"success":true,"state":"pending","rows":frozen,"namespace":save_namespace,"starter":starter,"transactions":{},"records":[],"previous":{},"total":0,"cursor":0,"source_resources":CombatDefinitionCatalog.load_default_fixture_catalog()}

static func _validate_history_row(job: Dictionary, row: Variant, index: int) -> Dictionary:
	var save_namespace: String = job.namespace
	var starter: Dictionary = job.starter
	var transactions: Dictionary = job.transactions
	var records: Array = job.records
	var previous: Dictionary = job.previous
	var total: int = job.total
	if not row is Dictionary or not row.get("document") is String or not row.get("transaction_id") is String or not CharacterSaveStorage._valid_id(row.transaction_id): return fail("invalid_generation_record")
	total += row.document.to_utf8_buffer().size()
	if not check_size(total,MAX_HISTORY_BYTES).success: return fail("backup_size_limit")
	var scan := scan_json(row.document)
	if not scan.success: return scan
	var envelope: Variant = JSON.parse_string(row.document)
	if not envelope is Dictionary or not envelope.get("payload_json") is String: return fail("invalid_character_document")
	scan = scan_json(envelope.payload_json)
	if not scan.success: return scan
	var decoded := Contract.decode(row.document)
	if not decoded.success: return fail(decoded.get("reason","invalid_character_document"))
	if decoded.get("version") not in [Contract.PROFILE_VERSION, Contract.RUN_REWARD_PROFILE_VERSION, Contract.EXPC_CREDIT_PROFILE_VERSION]: return fail("unsupported_character_version")
	var payload: Dictionary = decoded.payload
	if index == 0:
		var baseline := String(payload.get("lineage",{}).get("baseline_digest",""))
		if baseline.is_empty(): return fail("profile_baseline_missing")
		starter = Admission.prepare_starter(&"vaelis_thorn",save_namespace,baseline)
		if not starter.success: return fail(starter.get("reason","unsupported_authored_baseline"))
	if payload.generation != index+1 or row.get("generation",payload.generation) != payload.generation: return fail("generation_gap")
	if transactions.has(row.transaction_id): return fail("duplicate_transaction")
	transactions[row.transaction_id] = true
	if payload.character_id != starter.profile_id or payload.get("profile_namespace") != save_namespace or payload.definition_id != String(starter.source.definition_id) or payload.rules_revision != Admission.RULES or payload.get("lineage") != starter.prepared.payload.lineage: return fail("profile_source_or_namespace_mismatch")
	if not payload.has_all(["recovery","equipment_state","run_history"]): return fail("playable_checkpoint_required")
	var prepared := Coordinator.prepare(payload,payload.get("settlements",[]),row.transaction_id,index,previous.get("secured_checkpoints",[]))
	if not prepared.success: return fail(prepared.get("reason","invalid_receipts"))
	# Approved unsigned local-file policy: bind ONLY this isolated candidate
	# to the independently verified authored lineage. This is not a signature.
	var binding := Profiles.fingerprint(payload)
	var lineage: Dictionary = starter.prepared.payload.lineage.duplicate(true)
	var end_proof := {}
	if EnduranceGrowthHistory.has_purchases(payload):
		end_proof = EnduranceGrowthHistory.extend(starter.source,payload,previous,job.get("endurance_history",{}))
		if not end_proof.success: return fail(end_proof.reason)
	var verifier := func(operation: String, requested: String) -> Dictionary:
		return {"authorized":operation == "hydrate" and requested == binding,"binding":requested,"lineage":lineage,"endurance_history":end_proof}
	var hydrated := Profiles.hydrate(payload,starter.source,starter.profile_id,Admission.RULES,verifier)
	if not hydrated.success: return fail(hydrated.get("reason","invalid_character"))
	if not previous.is_empty():
		for result: Dictionary in [Contract.validate_replacement(previous,payload),Coordinator._validate_continuity(previous,payload)]:
			if not result.success: return fail(result.get("reason","history_conflict"))
	var items := Coordinator._validate_new_items(previous,payload)
	if not items.success: return fail(items.get("reason","invalid_item_ownership"))
	var battlefield := ArenaBattlefield.create_task16_test_arena()
	if payload.recovery.battlefield_digest != Profiles.fingerprint(battlefield.to_dictionary()): return fail("checkpoint_battlefield_mismatch")
	var position: Array = payload.recovery.player_position
	if not battlefield.is_position_legal(&"player",Vector2i(position[0],position[1]),{}).legal: return fail("checkpoint_position_illegal")
	records.append({"generation":int(payload.generation),"transaction_id":row.transaction_id,"document":row.document})
	job.endurance_history = end_proof
	job.previous = payload
	job.starter = starter
	job.total = total
	return {"success":true}

static func step_history_validation(job: Dictionary) -> Dictionary:
	if not job.get("success",false): return job
	var result := _validate_history_row(job,job.rows[job.cursor],job.cursor)
	if not result.success: return result
	job.cursor += 1
	if job.cursor == job.rows.size(): return {"success":true,"records":job.records,"payload":job.previous}
	return {"success":false,"state":"pending","stage":"Validating history","progress":job.cursor,"total":job.rows.size()}

static func validate_history(history: Dictionary, save_namespace: String) -> Dictionary:
	var job := begin_history_validation(history,save_namespace)
	if not job.success: return job
	while true:
		var result := step_history_validation(job)
		if result.get("state") != "pending": return result
	return fail("invalid_generation_history")

# A host-owned validated snapshot is reusable only while EVERY original record
# byte and all publication/preview metadata remain identical. This is a change
# detector, never authentication or a substitute for initial full validation.
static func snapshot_digest(backup: Dictionary) -> String:
	if not backup.get("success",false) or not backup.get("manifest") is Dictionary or not backup.get("history") is Array or not backup.get("payload") is Dictionary or not backup.get("preview") is Dictionary: return ""
	if backup.manifest.get("generations") != backup.history: return ""
	var records: Array = []
	for row: Variant in backup.history:
		if not row is Dictionary or not keys(row,["generation","transaction_id","document"]) or typeof(row.generation) != TYPE_INT or not row.transaction_id is String or not row.document is String: return ""
		records.append([row.generation,row.transaction_id,row.document.sha256_text()])
	var header: Dictionary = backup.manifest.duplicate()
	header.erase("generations")
	return Profiles.fingerprint({"header":header,"records":records,"payload":backup.payload,"preview":backup.preview,"body_digest":backup.get("backup_digest")})

static func compare(backup: Dictionary, destination: Dictionary, save_namespace: String) -> String:
	if not backup.get("success",false) or backup.manifest.namespace != save_namespace: return "unsupported_namespace_or_version"
	if not destination.get("success",false) or destination.get("writer_locked",false) or destination.get("pending_write",false): return "corrupt_or_uncertain_destination"
	if destination.get("generations",[]).is_empty():
		return "corrupt_or_uncertain_destination" if destination.get("profile_directory_exists",false) else "empty_destination"
	var checked := validate_history(destination,save_namespace)
	if not checked.success:
		return "unsupported_namespace_or_version" if checked.get("reason") in ["unsupported_format_or_version","unsupported_character_version","profile_source_or_namespace_mismatch"] else "corrupt_or_uncertain_destination"
	var local: Array = checked.records
	var imported: Array = backup.history
	for index in range(mini(local.size(),imported.size())):
		if local[index] != imported[index]: return "divergent_history"
	if local.size() == imported.size(): return "exact_match"
	return "destination_exact_prefix" if local.size() < imported.size() else "backup_older_than_destination"

static func preview(payload: Dictionary, created_utc: String) -> Dictionary:
	var equipment: Array[String] = []
	var catalog := CombatDefinitionCatalog.load_default_fixture_catalog()
	for ref: String in payload.permanent.equipment_refs:
		var definition: Resource = catalog.get_weapon(StringName(ref))
		if definition == null: definition = catalog.get_shield(StringName(ref))
		if definition == null: definition = catalog.get_armor(StringName(ref))
		var label: String = definition.display_name if definition != null else ref
		for item: Dictionary in payload.items:
			if item.definition_id == ref and not item.equipped_slots.is_empty() and item.mutable_state.has("shp"): label += " (SHP %s)" % item.mutable_state.shp
		equipment.append(label)
	var inventory: Array[String] = []
	var gold := 0
	for item: Dictionary in payload.items:
		var definition: Resource = catalog.get_weapon(StringName(item.definition_id))
		if definition == null: definition = catalog.get_shield(StringName(item.definition_id))
		if definition == null: definition = catalog.get_armor(StringName(item.definition_id))
		var item_name: String = definition.display_name if definition != null else String(item.definition_id).trim_prefix("prime_v3_").capitalize()
		inventory.append("%s x%s" % [item_name.left(40),item.quantity])
		if item.definition_id == "prime_v3_gold": gold += int(item.quantity)
	return {"character":"Vaelis Thorn","profile_id":payload.character_id,"namespace":payload.profile_namespace,"level":payload.permanent.level,"xp":payload.xp.duplicate(true),"equipment":equipment,"inventory":inventory,"gold":gold,"backup_version":VERSION,"generation":payload.generation,"created_utc":created_utc,"checkpoint":{"phase":payload.recovery.phase,"wave_id":payload.recovery.wave_id,"run_id":payload.recovery.run_id},"integrity":"locally validated unsigned backup; not authenticated"}

static func valid_date(value: Variant) -> bool:
	if not value is String or value.length() != 20 or value[10] != "T" or value[19] != "Z": return false
	for index in range(19):
		if index in [4,7]:
			if value[index] != "-": return false
		elif index in [13,16]:
			if value[index] != ":": return false
		elif index != 10 and not "0123456789".contains(value[index]): return false
	var stamp: String = value.trim_suffix("Z")
	var year: int = stamp.substr(0,4).to_int()
	var month: int = stamp.substr(5,2).to_int()
	var day: int = stamp.substr(8,2).to_int()
	if year < 1 or month < 1 or month > 12 or day < 1 or stamp.substr(11,2).to_int() > 23 or stamp.substr(14,2).to_int() > 59 or stamp.substr(17,2).to_int() > 59: return false
	var days := [31,29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28,31,30,31,30,31,31,30,31,30,31]
	if day > days[month-1]: return false
	return Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_datetime_string(stamp)) == stamp

# Bounded lexical precheck also rejects duplicate keys (including escaped aliases)
# before Godot's JSON parser could silently keep only their final value.
static func check_size(byte_count: int, limit: int) -> Dictionary:
	return {"success":true} if byte_count >= 0 and byte_count <= limit else fail("backup_size_limit")

class JsonScan extends RefCounted:
	# Native bounded runs replace per-character GDScript work inside JSON strings
	# and legal whitespace. Key decoding, duplicate/depth/token checks stay below.
	static var string_run: RegEx
	static var space_run: RegEx
	var text: String
	var cursor := 0
	var stack: Array = []
	var tokens := 0
	var in_string := false
	var escaped := false
	var key_string := false
	var string_start := 0
	var result := {"success":false,"state":"pending"}
	func _init(value: String, limit: int) -> void:
		text = value
		if string_run == null:
			string_run = RegEx.new()
			string_run.compile(r'\G(?:[^"\\]|\\[\s\S]){1,8192}+')
			space_run = RegEx.new()
			space_run.compile(r'\G[ \t\r\n]{1,16384}+')
		# Required initialization must execute in release builds, where assert()
		# expressions are removed. Never search an uncompiled regex.
		if not string_run.is_valid() or not space_run.is_valid():
			result = CharacterBackupContract.fail("backup_scanner_unavailable")
			return
		if not CharacterBackupContract.check_size(text.to_utf8_buffer().size(),limit).success: result = CharacterBackupContract.fail("backup_size_limit")
	var next_backslash := -2
	func step(budget: int = 32768) -> Dictionary:
		if result.get("state") != "pending": return result
		var stop := mini(text.length(),cursor+maxi(1,budget))
		while cursor < stop:
			var code := text.unicode_at(cursor)
			if in_string and not escaped:
				if next_backslash == -2 or (next_backslash >= 0 and next_backslash < cursor): next_backslash = text.find("\\",cursor)
				var quote := text.find('"',cursor)
				if next_backslash == -1 or (quote >= 0 and quote < next_backslash):
					cursor = mini(stop,text.length() if quote < 0 else quote)
				else:
					# A bounded native run handles escaped pairs. Its small subject
					# avoids per-token work/copies against the complete large file.
					var segment := text.substr(cursor,mini(16384,stop-cursor))
					var matched := string_run.search(segment)
					if matched != null: cursor += matched.get_end()
				if cursor >= stop: break
				code = text.unicode_at(cursor)
			elif not in_string and (code == 32 or code == 9 or code == 10 or code == 13):
				var matched := space_run.search(text.substr(cursor,mini(16384,stop-cursor)))
				if matched != null: cursor += matched.get_end()
				if cursor >= stop: break
				code = text.unicode_at(cursor)
			if in_string:
				if escaped: escaped = false
				elif code == 92: escaped = true
				elif code == 34:
					in_string = false
					if key_string:
						var key: Variant = JSON.parse_string(text.substr(string_start,cursor-string_start+1))
						if not key is String: return finish("invalid_json_key")
						if stack.back().seen.has(key): return finish("duplicate_json_key")
						stack.back().seen[key] = true
						stack.back().key = false
			elif code == 34:
				in_string = true
				string_start = cursor
				key_string = not stack.is_empty() and stack.back().object and stack.back().key
			else:
				if code == 123 or code == 91:
					stack.append({"object":code == 123,"key":true,"seen":{}})
					if stack.size() > CharacterBackupContract.MAX_DEPTH: return finish("backup_depth_limit")
				elif code == 125 or code == 93:
					if stack.is_empty(): return finish("invalid_json_nesting")
					stack.pop_back()
				elif code == 44 and not stack.is_empty(): stack.back().key = true
				if code == 123 or code == 91 or code == 125 or code == 93 or code == 44 or code == 58:
					tokens += 1
					if tokens > CharacterBackupContract.MAX_TOKENS: return finish("backup_structure_limit")
			cursor += 1
		if cursor == text.length():
			if in_string or not stack.is_empty(): return finish("truncated_json")
			result = {"success":true}
		return result
	func finish(reason: String) -> Dictionary:
		result = CharacterBackupContract.fail(reason)
		return result

static func scan_json(text: String, max_bytes: int = MAX_GENERATION_BYTES) -> Dictionary:
	var scan := JsonScan.new(text,max_bytes)
	while scan.result.get("state") == "pending": scan.step()
	return scan.result

static func keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":String(reason)}
