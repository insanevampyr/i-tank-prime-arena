class_name CharacterBackupContract
extends RefCounted

const FORMAT := "itank_arena_character_backup"
const VERSION := 1
const MAX_BYTES := 16 * 1024 * 1024
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
	var head: Dictionary = checked.records.back()
	var payload: Dictionary = checked.payload
	var body := {"profile_id":payload.character_id,"namespace":save_namespace,"definition_id":payload.definition_id,"rules_revision":payload.rules_revision,"created_utc":created_utc,"head_generation":head.generation,"head_transaction_id":head.transaction_id,"generations":checked.records}
	var body_json := JSON.stringify(body,"",true,true)
	var text := JSON.stringify({"format":FORMAT,"backup_version":VERSION,"body_json":body_json,"sha256":body_json.sha256_text()},"",true,true)
	var decoded := decode(text,save_namespace)
	if not decoded.success: return decoded
	decoded["text"] = text
	return decoded

static func decode(text: String, expected_namespace: String) -> Dictionary:
	if expected_namespace not in ["normal","dev_normal"]: return fail("unsupported_namespace")
	var scan := scan_json(text)
	if not scan.success: return scan
	var outer: Variant = JSON.parse_string(text)
	if not outer is Dictionary or not keys(outer,["format","backup_version","body_json","sha256"]): return fail("invalid_backup_container")
	if outer.format != FORMAT or outer.backup_version != VERSION: return fail("unsupported_backup_version")
	if not outer.body_json is String or not outer.sha256 is String or outer.body_json.sha256_text() != outer.sha256: return fail("backup_checksum_mismatch")
	scan = scan_json(outer.body_json)
	if not scan.success: return scan
	var body: Variant = Contract._normalize_json_numbers(JSON.parse_string(outer.body_json))
	var fields := ["profile_id","namespace","definition_id","rules_revision","created_utc","head_generation","head_transaction_id","generations"]
	if not body is Dictionary or not keys(body,fields): return fail("invalid_backup_manifest")
	if JSON.stringify(body,"",true,true) != outer.body_json: return fail("noncanonical_backup_body")
	if body.namespace != expected_namespace: return fail("namespace_mismatch")
	if not valid_date(body.created_utc): return fail("invalid_backup_date")
	if not body.generations is Array: return fail("invalid_generation_record")
	for row: Variant in body.generations:
		if not row is Dictionary or not keys(row,["generation","transaction_id","document"]): return fail("invalid_generation_record")
	var checked := validate_history({"success":true,"generations":body.generations,"writer_locked":false,"pending_write":false},expected_namespace)
	if not checked.success: return checked
	var payload: Dictionary = checked.payload
	var head: Dictionary = checked.records.back()
	if body.profile_id != payload.character_id or body.definition_id != payload.definition_id or body.rules_revision != payload.rules_revision or body.head_generation != head.generation or body.head_transaction_id != head.transaction_id: return fail("backup_manifest_head_mismatch")
	return {"success":true,"manifest":body,"history":checked.records,"payload":payload,"preview":preview(payload,body.created_utc),"backup_digest":outer.sha256}

static func validate_history(history: Dictionary, save_namespace: String) -> Dictionary:
	if save_namespace not in ["normal","dev_normal"]: return fail("unsupported_namespace")
	if not history.get("success",false) or history.get("writer_locked",false) or history.get("pending_write",false): return fail("destination_corrupt_or_uncertain")
	var rows: Variant = history.get("generations")
	if not rows is Array or rows.is_empty() or rows.size() > MAX_GENERATIONS: return fail("invalid_or_oversized_generation_history")
	var starter := Admission.prepare_starter(&"vaelis_thorn",save_namespace)
	if not starter.success: return fail(starter.get("reason","source_unavailable"))
	var transactions := {}
	var records: Array = []
	var previous := {}
	var total := 0
	for index in range(rows.size()):
		var row: Variant = rows[index]
		if not row is Dictionary or not row.get("document") is String or not row.get("transaction_id") is String or not CharacterSaveStorage._valid_id(row.transaction_id): return fail("invalid_generation_record")
		total += row.document.to_utf8_buffer().size()
		if total > MAX_BYTES: return fail("backup_size_limit")
		var scan := scan_json(row.document)
		if not scan.success: return scan
		var envelope: Variant = JSON.parse_string(row.document)
		if not envelope is Dictionary or not envelope.get("payload_json") is String: return fail("invalid_character_document")
		scan = scan_json(envelope.payload_json)
		if not scan.success: return scan
		var decoded := Contract.decode(row.document)
		if not decoded.success: return fail(decoded.get("reason","invalid_character_document"))
		if decoded.get("version") != 2: return fail("unsupported_character_version")
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
		var verifier := func(operation: String, requested: String) -> Dictionary:
			return {"authorized":operation == "hydrate" and requested == binding,"binding":requested,"lineage":lineage}
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
		previous = payload
	return {"success":true,"records":records,"payload":previous}

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
static func scan_json(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return fail("backup_size_limit")
	var stack: Array = []
	var tokens := 0
	var index := 0
	while index < text.length():
		var ch := text[index]
		if ch == '"':
			var begin := index
			index += 1
			while index < text.length() and text[index] != '"':
				if text[index] == "\\": index += 1
				index += 1
			if index >= text.length(): return fail("truncated_json")
			if not stack.is_empty() and stack.back().object and stack.back().key:
				var key: Variant = JSON.parse_string(text.substr(begin,index-begin+1))
				if not key is String: return fail("invalid_json_key")
				if stack.back().seen.has(key): return fail("duplicate_json_key")
				stack.back().seen[key] = true
				stack.back().key = false
		elif ch in ["{","["]:
			stack.append({"object":ch == "{","key":true,"seen":{}})
			if stack.size() > MAX_DEPTH: return fail("backup_depth_limit")
		elif ch in ["}","]"]:
			if stack.is_empty(): return fail("invalid_json_nesting")
			stack.pop_back()
		elif ch == "," and not stack.is_empty(): stack.back().key = true
		if ch in ["{","[","}","]",",",":"]:
			tokens += 1
			if tokens > MAX_TOKENS: return fail("backup_structure_limit")
		index += 1
	if not stack.is_empty(): return fail("truncated_json")
	return {"success":true}

static func keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)

static func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":String(reason)}
