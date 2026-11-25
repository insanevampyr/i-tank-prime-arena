extends RefCounted

# Dormant cold codec only. No executable context, admission, writer or migration.
const V1 = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const V6 = V1.V6
const Profiles = V1.Profiles
const Contract = V1.Contract
const Credit = V1.Credit
const VERSION := 3
const READER_VERSION := 3
const KEYS := ["epoch","sequence","last_operation_id","source_digest","current","evidence","recent_journal"]
const EVIDENCE := ["awards","purchases","growth","settlements","credit","order","item_debits"]
const LEDGER := ["mode","player_actor_id","player_level","current_wave_id","current_wave_earned_xp","earned_xp","spent_xp","unspent_xp","processed_actor_ids","next_world_item_sequence","spending_available","spending_blocked_reason"]
const DEBIT := ["run_id","request_id","event_id","kind","definition_id","selection"]
const CURRENT := ["character_id","definition_id","rules_revision","generation","base_attributes","xp","items","secured_checkpoints","permanent","lineage","profile_namespace","recovery","equipment_state","run_history"]

class Record extends RefCounted:
	var _json := "":
		set(value):
			if _json.is_empty(): _json = value
	var _membership: Dictionary
	func _init(text: String, membership: Dictionary) -> void:
		_json = text; _membership = membership.duplicate(true)
	func json() -> String: return _json
	func copy() -> Dictionary: return Contract._normalize_json_numbers(JSON.parse_string(_json))
	func projection() -> Dictionary: return preload("res://scripts/rewards/minimal_character_snapshot_v3.gd").projection(copy())
	# Exact membership is not authority to execute a command or publish a save.
	func transaction(scope: String, id: String, binding: String) -> Dictionary:
		if not V1._id(scope) or id.is_empty() or id.length() > 4096 or not V6._hash(binding): return V1.fail("snapshot_v3_invalid_lookup")
		var key := JSON.stringify([scope,id])
		if not _membership.has(key): return {"success":true}
		return V1.fail("snapshot_v3_duplicate_transaction" if _membership[key] == binding else "snapshot_v3_conflicting_transaction")

# Assemble explicit supplied facts only; missing command/origin IDs are never inferred.
static func assemble(current: Dictionary, evidence: Dictionary, epoch: String, commit_id: String, journal: Array, source: CombatCharacterDefinitionResource) -> Dictionary:
	return {"epoch":epoch,"sequence":current.get("generation",0),"last_operation_id":commit_id,"source_digest":V6.digest(source.to_dictionary()) if source != null else "","current":current.duplicate(true),"evidence":evidence.duplicate(true),"recent_journal":journal.duplicate(true)}

static func projection(body: Dictionary) -> Dictionary:
	var payload := V6._projection(body)
	var terminal: Array = body.current.items.duplicate(true)
	payload.items = terminal.filter(func(item: Dictionary): return item.quantity > 0)
	payload.recovery.ledger["profile_ownership"] = {"profile_id":payload.character_id,"profile_namespace":payload.profile_namespace,"run_id":payload.recovery.run_id,"items":terminal}
	return payload

static func binding(body: Dictionary, scope: String, fact: Variant) -> String:
	return V6.digest({"epoch":body.epoch,"profile":body.current.character_id,"namespace":body.current.profile_namespace,"source":body.source_digest,"rules":body.current.rules_revision,"scope":scope,"fact":fact})

# Rebuilt, process-local exact index. There is no duplicated durable ID table.
static func identities(body: Dictionary) -> Dictionary:
	var result := {}
	for pair: Array in [["award","awards","award_id"],["purchase","purchases","purchase_id"],["growth","growth","growth_id"],["settlement","settlements","receipt_id"]]:
		for row: Dictionary in body.evidence[pair[1]]:
			var added := _put(result,pair[0],row[pair[2]],binding(body,pair[0],row))
			if not added.success: return added
	for row: Dictionary in body.evidence.settlements:
		if row.kind in ["item","currency"]:
			var added := _put(result,"item_origin",row.content.instance_id,binding(body,"item_origin",row))
			if not added.success: return added
	for row: Dictionary in body.evidence.item_debits:
		for scope: String in ["item_use","item_use_event"]:
			var id := JSON.stringify([row.run_id,row.request_id if scope == "item_use" else row.event_id])
			var added := _put(result,scope,id,binding(body,scope,row))
			if not added.success: return added
	if body.evidence.credit != null:
		var row: Dictionary = body.evidence.credit.records[0]
		var added := _put(result,"credit",row.grant_id,binding(body,"credit",row))
		if not added.success: return added
	for command: Dictionary in body.current.permanent.get("development",{}).get("commands",[]):
		if command.kind == "preferences": continue # One current preference, not a lifetime effect.
		var added := _put(result,"development",command.id,binding(body,"development",command))
		if not added.success: return added
	var policy := _multipliers(projection(body))
	for run: String in body.current.run_history:
		var added := _put(result,"run",run,binding(body,"run",{"run_id":run,"xp_multiplier":policy[run]}))
		if not added.success: return added
	return {"success":true,"ids":result}

static func _put(ids: Dictionary, scope: String, id: String, digest: String) -> Dictionary:
	var key := JSON.stringify([scope,id])
	if ids.has(key): return V1.fail("snapshot_v3_duplicate_identity",{"scope":scope,"id":id})
	ids[key] = digest
	return {"success":true}

static func validate(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if not V1._plain(body,0,[0]): return V1.fail("snapshot_field_limit_or_non_json_value")
	var b: Dictionary = Contract._normalize_json_numbers(body)
	var shape := _shape(b,source,profile,scope)
	if not shape.success: return shape
	var payload := projection(b)
	var contract := Contract.validate(payload)
	if not contract.success: return V1.fail("snapshot_v3_original_contract",contract)
	var receipts := V1.Receipts._validate_receipts(payload)
	if not receipts.success: return V1.fail("snapshot_v3_original_contract",receipts)
	var ownership := V1._ownership(payload)
	if not ownership.success: return ownership
	var multipliers := _multipliers(payload)
	var multiplier: Variant = payload.recovery.ledger.get("xp_multiplier",ArenaRewardLedger.legacy_xp_multiplier(scope))
	if typeof(multiplier) != TYPE_INT or multiplier != multipliers[payload.recovery.run_id]: return V1.fail("snapshot_v3_current_policy")
	var wave_xp := 0
	for award: Dictionary in b.evidence.awards:
		var check := Profiles.validate_playable_xp_award(payload,award,multipliers)
		if not check.success: return V1.fail("snapshot_v3_award_source",check)
		if check.run_id == payload.recovery.run_id and check.wave_id == payload.recovery.wave_id: wave_xp += award.xp
	if payload.recovery.ledger.current_wave_earned_xp != wave_xp: return V1.fail("snapshot_v3_current_wave_xp")
	var credit := Credit.inspect(payload)
	if not credit.success: return V1.fail("snapshot_v3_credit",credit)
	var temporal := V6._chronology(payload,b.evidence,source)
	if not temporal.success: return V1.fail("snapshot_v3_chronology",temporal)
	var accounting := V6._accounting(b,source)
	for amount: Variant in accounting.values():
		if not V6._uint(amount): return V1.fail("snapshot_v3_accounting_range")
	if payload.xp != {"earned":accounting.expm_total,"spent":accounting.spent_expc,"unspent":accounting.expc_available}: return V1.fail("snapshot_v3_accounting")
	if payload.recovery.ledger.unspent_xp != accounting.expc_available: return V1.fail("snapshot_v3_ledger_balance")
	var conservation := _conservation(b,source)
	if not conservation.success: return conservation
	var membership := identities(b)
	if not membership.success: return membership
	var proof := {"success":true,"source_digest":b.source_digest,"head_digest":V6.digest(payload),"generation":payload.generation,"end":temporal.end,"growth":temporal.growth}
	var verifier := func(_op: String, digest: String): return {"authorized":true,"binding":digest,"lineage":payload.lineage,"endurance_history":proof}
	var actor := Profiles.hydrate(payload,source,profile,PlayableCharacterAdmission.RULES,verifier)
	if not actor.success: return V1.fail("snapshot_v3_projection",actor)
	var text := JSON.stringify(b,"",true,true)
	if text.to_utf8_buffer().size() > V1.MAX_BODY_BYTES: return V1.fail("snapshot_body_limit")
	return {"success":true,"format_version":3,"snapshot":Record.new(text,membership.ids)}

static func _shape(b: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if not V6._keys(b,KEYS): return V1.fail("snapshot_v3_fields")
	if source == null or b.source_digest != V6.digest(source.to_dictionary()): return V1.fail("snapshot_source_mismatch")
	var identity := PlayableCharacterAdmission.profile_identity(source.definition_id,scope)
	if not identity.get("success",false) or identity.profile_id != profile or scope not in ["normal","dev_normal"]: return V1.fail("snapshot_target_mismatch")
	if not V1._id(b.epoch) or b.epoch.length() > 256 or not V6._uint(b.sequence) or b.sequence < 1 or not V1._id(b.last_operation_id): return V1.fail("snapshot_commit_identity")
	if not b.current is Dictionary or not V6._keys(b.current,CURRENT+(["run_reward_policy"] if b.current.has("run_reward_policy") else [])) or not b.evidence is Dictionary or not V6._keys(b.evidence,EVIDENCE): return V1.fail("snapshot_v3_sections")
	var c: Dictionary = b.current; var e: Dictionary = b.evidence
	if c.character_id != profile or c.profile_namespace != scope or c.rules_revision != PlayableCharacterAdmission.RULES or c.generation != b.sequence: return V1.fail("snapshot_identity_or_generation")
	if not c.permanent is Dictionary or not V6._keys(c.permanent,["level","resource_maxima","ability_allowances","equipment_refs","inventory_quantities","xp_baseline"]+(["development"] if c.permanent.has("development") else [])): return V1.fail("snapshot_permanent_fields")
	for key: String in ["resource_maxima","ability_allowances","inventory_quantities","xp_baseline"]:
		if not c.permanent[key] is Dictionary: return V1.fail("snapshot_permanent_fields")
	if not V6._uint(c.permanent.level) or c.permanent.level < 1 or not c.permanent.equipment_refs is Array: return V1.fail("snapshot_permanent_fields")
	for ref: Variant in c.permanent.equipment_refs:
		if not V1._id(ref): return V1.fail("snapshot_permanent_fields")
	if not c.lineage is Dictionary or not V6._keys(c.lineage,Profiles.LINEAGE_FIELDS): return V1.fail("snapshot_lineage_fields")
	for key: String in Profiles.LINEAGE_FIELDS:
		if key != "mode_history" and not V1._id(c.lineage[key]): return V1.fail("snapshot_lineage_fields")
	if not c.lineage.mode_history is Array: return V1.fail("snapshot_lineage_fields")
	if not c.equipment_state is Dictionary or not c.recovery is Dictionary or not c.recovery.get("ledger") is Dictionary or not c.run_history is Array or c.run_history.is_empty() or c.run_history.back() != c.recovery.get("run_id"): return V1.fail("snapshot_checkpoint_required")
	if c.run_history.has(c.lineage.run_id): return V1.fail("snapshot_v3_admission_scope_is_not_a_run")
	var ledger: Dictionary = c.recovery.ledger
	var fields := LEDGER+(["xp_multiplier"] if ledger.has("xp_multiplier") else [])+(["expc_credit_total"] if ledger.has("expc_credit_total") else [])
	if not V6._keys(ledger,fields): return V1.fail("snapshot_v3_checkpoint_ledger_fields")
	for key: String in ["player_level","current_wave_earned_xp","earned_xp","spent_xp","unspent_xp","next_world_item_sequence"]:
		if not V6._uint(ledger[key]): return V1.fail("snapshot_v3_ledger_number")
	if ledger.player_actor_id != "player" or ledger.current_wave_id != c.recovery.get("wave_id") or not ledger.processed_actor_ids is Array or ledger.spending_available != true or ledger.spending_blocked_reason != "": return V1.fail("snapshot_v3_ledger_identity")
	var actors := {}
	for id: Variant in ledger.processed_actor_ids:
		if not V1._id(id) or actors.has(id): return V1.fail("snapshot_v3_ledger_actor")
		actors[id] = true
	if c.permanent.has("development"):
		var development: Variant = c.permanent.development
		if not development is Dictionary or not CharacterDevelopment.inspect(development).success: return V1.fail("snapshot_v3_development")
		var preferences := 0
		for row: Dictionary in development.commands:
			if row.kind == "preferences": preferences += 1
		if preferences > 1: return V1.fail("snapshot_v3_temporary_preference_history")
	for field: String in ["awards","purchases","growth","settlements","order","item_debits"]:
		if not e[field] is Array or e[field].size() > V1.MAX_ENTRIES: return V1.fail("snapshot_evidence_limit")
		for row: Variant in e[field]:
			if not row is Dictionary: return V1.fail("snapshot_evidence_row")
	for row: Dictionary in e.awards:
		if not V6._keys(row,["award_id","xp"]) or not V1._id(row.award_id) or not V6._uint(row.xp): return V1.fail("snapshot_award_row")
	for row: Dictionary in e.purchases:
		if not V6._keys(row,Profiles.purchase_fields(row)+["purchase_id"]): return V1.fail("snapshot_purchase_row")
		for key: String in ["purchase_id","purchase_kind","target_id","source_ref"]:
			if not V1._id(row[key]): return V1.fail("snapshot_purchase_row")
		for key: String in ["value_before","value_after","cost"]:
			if not V6._uint(row[key]): return V1.fail("snapshot_purchase_row")
	for row: Dictionary in e.growth:
		if not V6._keys(row,Profiles.HISTORY_FIELDS+["growth_id"]) or not V1._id(row.growth_id) or not V1._id(row.resource): return V1.fail("snapshot_growth_row")
		for key: String in Profiles.HISTORY_FIELDS:
			if key != "resource" and not V6._uint(row[key]): return V1.fail("snapshot_growth_row")
	for row: Dictionary in e.item_debits:
		if not V6._keys(row,DEBIT) or not row.selection is Array or row.selection.is_empty(): return V1.fail("snapshot_v3_debit_fields")
		for key: String in ["run_id","request_id","event_id","kind","definition_id"]:
			if not V1._id(row[key]): return V1.fail("snapshot_v3_debit_fields")
		for selection: Variant in row.selection:
			if not selection is Dictionary or not V6._keys(selection,["instance_id","quantity"]) or not V1._id(selection.instance_id) or not V6._uint(selection.quantity) or selection.quantity < 1: return V1.fail("snapshot_v3_debit_selection")
	if e.credit != null and not e.credit is Dictionary: return V1.fail("snapshot_credit_row")
	if not c.items is Array: return V1.fail("snapshot_terminal_item")
	for item: Variant in c.items:
		if not item is Dictionary or not V6._keys(item,["instance_id","definition_id","quantity","provenance","equipped_slots","mutable_state"]) or not V1._id(item.instance_id) or not V1._id(item.definition_id) or not V6._uint(item.quantity) or not item.provenance is Dictionary or not item.equipped_slots is Array or not item.mutable_state is Dictionary: return V1.fail("snapshot_terminal_item")
		if item.quantity == 0 and (not item.equipped_slots.is_empty() or not item.mutable_state.is_empty()): return V1.fail("snapshot_v3_terminal_zero_state")
	if not b.recent_journal is Array or b.recent_journal.size() != mini(20,b.sequence): return V1.fail("snapshot_v3_journal_size")
	var seen := {}
	for i in range(b.recent_journal.size()):
		var row: Variant = b.recent_journal[i]
		if not row is Dictionary or not V6._keys(row,["sequence","id","request_digest"]) or not V6._uint(row.sequence) or row.sequence != b.sequence-b.recent_journal.size()+i+1 or not V1._id(row.id) or not V6._hash(row.request_digest) or seen.has(row.id): return V1.fail("snapshot_v3_journal_entry")
		seen[row.id] = true
	if b.recent_journal.back().id != b.last_operation_id: return V1.fail("snapshot_journal_or_last_operation")
	return {"success":true}

static func _multipliers(payload: Dictionary) -> Dictionary:
	if payload.has("run_reward_policy"): return Profiles.run_xp_multipliers(payload)
	var result := {}
	for run: String in payload.run_history: result[run] = ArenaRewardLedger.legacy_xp_multiplier(payload.profile_namespace)
	return result

static func _conservation(b: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var origins := {}; var quantities := {}; var run_indices := {}; var expected := {}
	for i in range(b.current.run_history.size()): run_indices[b.current.run_history[i]] = i
	# Source starters use the original lineage's admission scope, not an Arena run.
	var starter := PlayableCharacterAdmission.prepare_starter(source.definition_id,b.current.profile_namespace,b.current.lineage.baseline_digest)
	if not starter.success: return V1.fail("snapshot_v3_starter_source",starter)
	var starter_receipts: Dictionary = {}
	for receipt: Dictionary in starter.prepared.payload.settlements: starter_receipts[receipt.receipt_id] = receipt
	run_indices[b.current.lineage.run_id] = -1
	for receipt: Dictionary in b.evidence.settlements:
		if receipt.kind in ["item","currency"]:
			if not run_indices.has(receipt.run_id): return V1.fail("snapshot_v3_origin_run")
			if receipt.run_id == b.current.lineage.run_id and starter_receipts.get(receipt.receipt_id) != receipt: return V1.fail("snapshot_v3_starter_origin")
			origins[receipt.content.instance_id] = receipt
			quantities[receipt.content.instance_id] = receipt.content.quantity
	for id: String in starter_receipts:
		if not origins.has(starter_receipts[id].content.instance_id): return V1.fail("snapshot_v3_missing_starter_origin")
	for row: Dictionary in b.evidence.item_debits:
		if row.kind != "consume": return V1.fail("snapshot_v3_unsupported_loss_source")
		if not b.current.run_history.has(row.run_id) or PrimeV3InventoryCatalog.get_verified_consumable(row.definition_id).is_empty(): return V1.fail("snapshot_v3_consumable_source")
		var count := 0; var selections := {}
		for part: Dictionary in row.selection:
			if not origins.has(part.instance_id) or selections.has(part.instance_id): return V1.fail("snapshot_v3_consumption_origin")
			selections[part.instance_id] = true
			var origin: Dictionary = origins[part.instance_id]
			if origin.kind != "item" or origin.content.definition_id != row.definition_id or run_indices[origin.run_id] > run_indices[row.run_id]: return V1.fail("snapshot_v3_consumption_origin")
			quantities[part.instance_id] -= part.quantity; count += part.quantity
			if quantities[part.instance_id] < 0: return V1.fail("snapshot_v3_overconsumption")
		if count != 1: return V1.fail("snapshot_v3_consumption_quantity")
	for item: Dictionary in b.current.items:
		if not quantities.has(item.instance_id) or item.quantity != quantities[item.instance_id]: return V1.fail("snapshot_v3_item_conservation")
		expected[item.instance_id] = true
	if expected.size() != origins.size(): return V1.fail("snapshot_v3_missing_terminal_ownership")
	return {"success":true}

# Comparison only, never a publication or new-effect authorization.
static func validate_extension(previous: Dictionary, candidate: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var a := validate(previous,source,profile,scope)
	if not a.success: return a
	var b := validate(candidate,source,profile,scope)
	if not b.success: return b
	if previous.epoch != candidate.epoch or previous.source_digest != candidate.source_digest or previous.current.lineage != candidate.current.lineage: return V1.fail("snapshot_v3_extension_identity")
	if previous.sequence == candidate.sequence: return {"success":true,"exact_retry":true} if a.snapshot.json() == b.snapshot.json() else V1.fail("snapshot_v3_same_sequence_conflict")
	if candidate.sequence != previous.sequence+1 or previous.last_operation_id == candidate.last_operation_id: return V1.fail("snapshot_v3_extension_sequence")
	if candidate.current.run_history.slice(0,previous.current.run_history.size()) != previous.current.run_history or candidate.current.run_history.size() > previous.current.run_history.size()+1: return V1.fail("snapshot_v3_run_prefix")
	if candidate.recent_journal.slice(0,-1) != previous.recent_journal.slice(maxi(0,previous.recent_journal.size()-19)): return V1.fail("snapshot_v3_journal_prefix")
	for key: String in ["awards","purchases","growth","settlements","order","item_debits"]:
		if candidate.evidence[key].slice(0,previous.evidence[key].size()) != previous.evidence[key]: return V1.fail("snapshot_v3_immutable_fact_changed")
	var old_development: Array = previous.current.permanent.get("development",{}).get("commands",[]).filter(func(row): return row.kind != "preferences")
	var new_development: Array = candidate.current.permanent.get("development",{}).get("commands",[]).filter(func(row): return row.kind != "preferences")
	if new_development.slice(0,old_development.size()) != old_development: return V1.fail("snapshot_v3_permanent_allocation_prefix")
	if candidate.current.has("run_reward_policy"):
		var policy := Contract._validate_run_reward_replacement(projection(previous),projection(candidate))
		if not policy.success: return policy
	elif previous.current.has("run_reward_policy") or candidate.current.run_history != previous.current.run_history:
		return V1.fail("snapshot_v3_run_policy_downgrade")
	var credit := Credit.continuity(projection(previous),projection(candidate))
	if not credit.success: return credit
	var before := identities(previous); var after := identities(candidate)
	for key: String in before.ids:
		if after.ids.get(key) != before.ids[key]: return V1.fail("snapshot_v3_immutable_identity_changed")
	return {"success":true,"exact_retry":false}

static func encode(body: Dictionary, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	var checked := validate(body,source,profile,scope)
	if not checked.success: return checked
	var text: String = checked.snapshot.json()
	var envelope := JSON.stringify({"format":V1.FORMAT,"version":VERSION,"reader_version":READER_VERSION,"body_json":text,"sha256":text.sha256_text()},"",true,true)
	if envelope.to_utf8_buffer().size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	return {"success":true,"format_version":3,"text":envelope,"snapshot":checked.snapshot}

static func decode_bytes(bytes: PackedByteArray, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if bytes.size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	if not V1._utf8(bytes): return V1.fail("snapshot_invalid_utf8")
	return decode(bytes.get_string_from_utf8(),source,profile,scope)

static func decode(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String) -> Dictionary:
	if text.to_utf8_buffer().size() > V1.MAX_FILE_BYTES: return V1.fail("snapshot_file_limit")
	if not V1.Scan.scan_json(text,V1.MAX_FILE_BYTES).success: return V1.fail("snapshot_envelope_json")
	var parser := JSON.new()
	if parser.parse(text) != OK: return V1.fail("snapshot_envelope_json")
	var outer: Variant = Contract._normalize_json_numbers(parser.data)
	if not outer is Dictionary or not V6._keys(outer,["format","version","reader_version","body_json","sha256"]): return V1.fail("snapshot_envelope_fields")
	if outer.format != V1.FORMAT or typeof(outer.version) != TYPE_INT or outer.version != VERSION or typeof(outer.reader_version) != TYPE_INT or outer.reader_version != READER_VERSION: return V1.fail("snapshot_unsupported_version")
	if not outer.body_json is String or not V6._hash(outer.sha256): return V1.fail("snapshot_integrity_fields")
	if outer.body_json.to_utf8_buffer().size() > V1.MAX_BODY_BYTES: return V1.fail("snapshot_body_limit")
	if outer.sha256 != outer.body_json.sha256_text(): return V1.fail("snapshot_checksum_mismatch")
	if JSON.stringify(outer,"",true,true) != text: return V1.fail("snapshot_noncanonical_envelope")
	if not V1.Scan.scan_json(outer.body_json,V1.MAX_BODY_BYTES).success or parser.parse(outer.body_json) != OK: return V1.fail("snapshot_body_json")
	var body: Variant = Contract._normalize_json_numbers(parser.data)
	if not body is Dictionary or not V1._plain(body,0,[0]): return V1.fail("snapshot_field_limit_or_non_json_value")
	if JSON.stringify(body,"",true,true) != outer.body_json: return V1.fail("snapshot_noncanonical_body")
	return validate(body,source,profile,scope)
