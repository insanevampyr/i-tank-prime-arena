# Frozen pre-45P full oracle. Original SHA-256: ca1149824b5157dc0564028746965c2c94f536d3acab2d215354919f8d0f4b7d
extends RefCounted

# DORMANT proof contract. Only isolated tests/conversion call it; no live
# storage, session or playable contract callers.
# Rule resources are supplied by the trusted test host, never instantiated from
# an imported declaration of authority. Local hashes prove integrity, not earning.
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Coordinator = preload("res://tests/oracles/character_coordinator_linear_45p.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const FORMAT := "itank_arena_compact_character_pass_a"
const VERSION := 6
const MAX_BYTES := 16 * 1024 * 1024
const KEYS := ["format","compact_version","source_digest","head","current","evidence","operations","applied_ids","recent_journal","accounting"]
const EVIDENCE_KEYS := ["awards","purchases","growth","settlements","credit","credit_predecessor","order"]

static func digest(value: Variant) -> String:
	return JSON.stringify(value,"",true,true).sha256_text()

# Assemble an explicitly supplied isolated fixture. This is NOT an archive
# converter: it reads no generation archive and infers no historical order.
static func assemble(current: Dictionary, evidence: Dictionary, operations: Array, head: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var record := {"format":FORMAT,"compact_version":1,"source_digest":digest(source.to_dictionary()),"head":head.duplicate(true),"current":current.duplicate(true),"evidence":evidence.duplicate(true),"operations":operations.duplicate(true)}
	record["applied_ids"] = _ids(record)
	record["recent_journal"] = operations.slice(maxi(0,operations.size()-20)).duplicate(true)
	record["accounting"] = _accounting(record,source)
	return record

static func encode(record: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var checked := validate(record,source)
	if not checked.success: return checked
	var body := JSON.stringify(record,"",true,true)
	var text := JSON.stringify({"format":Contract.FORMAT,"version":VERSION,"payload_json":body,"sha256":body.sha256_text()},"",true,true)
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("prototype_size_limit")
	return {"success":true,"text":text}

static func decode(text: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	# Reuse the bounded duplicate-key/depth/token scanner, including in release.
	if not Backup.scan_json(text,MAX_BYTES).success: return _fail("invalid_envelope_json")
	var outer: Variant = Contract._normalize_json_numbers(JSON.parse_string(text))
	if not outer is Dictionary or not _keys(outer,["format","version","payload_json","sha256"]): return _fail("invalid_envelope")
	if outer.format != Contract.FORMAT or typeof(outer.version) != TYPE_INT or outer.version != VERSION: return _fail("unsupported_version")
	if not outer.payload_json is String or not outer.sha256 is String or outer.payload_json.sha256_text() != outer.sha256: return _fail("checksum_mismatch")
	if not Backup.scan_json(outer.payload_json,MAX_BYTES).success: return _fail("invalid_record_json")
	var record: Variant = Contract._normalize_json_numbers(JSON.parse_string(outer.payload_json))
	if not record is Dictionary: return _fail("invalid_record")
	var checked := validate(record,source)
	if not checked.success: return checked
	# One canonical representation; fractional, unsafe or non-finite numbers
	# cannot be silently rounded into different evidence by the JSON normalizer.
	if JSON.stringify(record,"",true,true) != outer.payload_json: return _fail("noncanonical_record")
	return {"success":true,"record":record}

static func validate(record: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	if not _keys(record,KEYS) or record.format != FORMAT or typeof(record.compact_version) != TYPE_INT or record.compact_version != 1: return _fail("unsupported_record")
	if source == null or record.source_digest != digest(source.to_dictionary()): return _fail("source_mismatch")
	if not record.head is Dictionary: return _fail("invalid_head")
	var legacy_count: Variant = record.head.get("legacy_operation_count",0)
	if not _keys(record.head,["epoch","sequence","parent_digest"]+(["legacy_operation_count"] if record.head.has("legacy_operation_count") else [])) or not _uint(legacy_count) or not record.head.epoch is String or record.head.epoch.is_empty() or not _uint(record.head.sequence) or record.head.sequence < 1: return _fail("invalid_head")
	if record.head.sequence == 1:
		if record.head.parent_digest != null: return _fail("invalid_parent")
	elif not _hash(record.head.parent_digest): return _fail("invalid_parent")
	if not record.current is Dictionary or not record.evidence is Dictionary or not _keys(record.evidence,EVIDENCE_KEYS): return _fail("invalid_sections")
	var e: Dictionary = record.evidence
	if e.credit != null and not e.credit is Dictionary: return _fail("invalid_credit_evidence")
	for field: String in ["awards","purchases","growth","settlements","order"]:
		if not e[field] is Array: return _fail("invalid_evidence")
	for field: String in ["awards","purchases","growth","settlements"]:
		for row: Variant in e[field]:
			if not row is Dictionary: return _fail("invalid_evidence_row")
	for row: Dictionary in e.awards:
		if not _keys(row,["award_id","xp"]) or not row.award_id is String or not _uint(row.xp): return _fail("invalid_award_row")
	for row: Dictionary in e.purchases:
		if not _keys(row,Profiles.purchase_fields(row)+["purchase_id"]): return _fail("invalid_purchase_row")
		for field: String in ["purchase_id","purchase_kind","target_id","source_ref"]:
			if not row[field] is String: return _fail("invalid_purchase_row")
		for field: String in ["value_before","value_after","cost"]:
			if not _uint(row[field]): return _fail("invalid_purchase_row")
	for row: Dictionary in e.growth:
		if not _keys(row,Profiles.HISTORY_FIELDS+["growth_id"]) or not row.growth_id is String or not row.resource is String: return _fail("invalid_growth_row")
		for field: String in Profiles.HISTORY_FIELDS:
			if field != "resource" and not _uint(row[field]): return _fail("invalid_growth_number")
	if not record.operations is Array or record.operations.is_empty() or not record.applied_ids is Array or not record.recent_journal is Array: return _fail("missing_lifetime_ids")
	var op_ids := {}
	for operation: Variant in record.operations:
		if not operation is Dictionary or not _keys(operation,["id","request_digest"]+(["binding_kind"] if operation.has("binding_kind") else [])) or not operation.id is String or operation.id.is_empty() or not _hash(operation.request_digest) or op_ids.has(operation.id): return _fail("duplicate_or_invalid_operation")
		if operation.has("binding_kind") and operation.binding_kind != "legacy_document": return _fail("unsupported_operation_binding")
		op_ids[operation.id] = true
	if legacy_count > 0:
		if legacy_count > record.operations.size() or record.operations.size() != legacy_count+record.head.sequence-1: return _fail("operation_sequence_mismatch")
		for operation: Dictionary in record.operations.slice(0,legacy_count):
			if operation.get("binding_kind") != "legacy_document": return _fail("missing_legacy_document_binding")
		if record.head.epoch != "legacy_"+digest(record.operations.slice(0,legacy_count)): return _fail("legacy_epoch_mismatch")
	elif record.operations.size() != record.head.sequence: return _fail("operation_sequence_mismatch")
	if record.recent_journal != record.operations.slice(maxi(0,record.operations.size()-20)): return _fail("journal_mismatch")
	# The current snapshot cannot smuggle in a second competing lifetime ledger.
	if record.current.has("purchases") or record.current.has("settlements") or record.current.has("expc_credits") or not record.current.get("permanent") is Dictionary: return _fail("duplicated_lifetime_evidence")
	if record.current.permanent.has("growth") or record.current.permanent.has("award_receipts"): return _fail("duplicated_lifetime_evidence")
	var permanent: Dictionary = record.current.permanent
	if not permanent.has_all(["level","equipment_refs"]) or not _uint(permanent.level) or not permanent.equipment_refs is Array: return _fail("invalid_current_permanent_state")
	for ref: Variant in permanent.equipment_refs:
		if not ref is String or ref.is_empty(): return _fail("invalid_current_equipment")
	var payload := _projection(record)
	var contract := Contract.validate(payload)
	if not contract.success: return _fail("invalid_current_contract",contract)
	var receipt_result := Coordinator._validate_receipts(payload)
	if not receipt_result.success: return _fail("invalid_receipts",receipt_result)
	var ids := _ids(record)
	var seen := {}
	for row: Dictionary in ids:
		var key := JSON.stringify([row.scope,row.id])
		if seen.has(key): return _fail("duplicate_lifetime_id")
		seen[key] = true
	if record.applied_ids != ids: return _fail("lifetime_id_binding_mismatch")
	# Always verify source amounts, even on old permanent-only test profiles.
	var multipliers := Profiles.run_xp_multipliers(payload) if payload.has("run_reward_policy") else {}
	for award: Dictionary in e.awards:
		var award_check := Profiles.validate_playable_xp_award(payload,award,multipliers)
		if not award_check.success: return _fail("invalid_award",award_check)
	var credit := Credit.inspect(payload)
	if not credit.success: return credit
	if credit.total > 0:
		if not e.credit_predecessor is Dictionary or e.credit_predecessor.is_empty(): return _fail("missing_credit_predecessor")
		var basis: Dictionary = e.credit_predecessor
		var historical: bool = basis.get("format") == "compact_legacy_credit_basis_v1"
		if historical:
			var expanded := _historical_credit_basis(record,source)
			if not expanded.success: return expanded
			basis = expanded.payload
		else:
			# Original Pass A fixtures retain their creation-baseline proof.
			if not Contract.validate(basis).success or basis.has("expc_credits") or not basis.get("permanent") is Dictionary: return _fail("unsupported_credit_predecessor")
			for list: Variant in [basis.get("purchases"),basis.permanent.get("growth"),basis.permanent.get("award_receipts")]:
				if not list is Array or not list.is_empty(): return _fail("unsupported_credit_predecessor")
		if basis.character_id != payload.character_id or basis.lineage != payload.lineage or basis.base_attributes != source.attributes or not Credit.continuity(basis,payload).success: return _fail("invalid_credit_binding")
		if not historical:
			var basis_verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":basis.lineage}
			if not Profiles.hydrate(basis,source,basis.character_id,basis.rules_revision,basis_verifier).success: return _fail("invalid_credit_source")
	elif e.credit != null or e.credit_predecessor != null: return _fail("unexpected_credit_evidence")
	var temporal := _chronology(payload,e,source)
	if not temporal.success: return temporal
	var expected_accounting := _accounting(record,source)
	for value: Variant in expected_accounting.values():
		if not _uint(value): return _fail("unsupported_accounting_range")
	if record.accounting != expected_accounting or expected_accounting.expc_available < 0 or payload.xp != {"earned":expected_accounting.expm_total,"spent":expected_accounting.spent_expc,"unspent":expected_accounting.expc_available}: return _fail("accounting_mismatch")
	var proof := {"success":true,"source_digest":digest(source.to_dictionary()),"head_digest":digest(payload),"generation":payload.generation,"end":temporal.end,"growth":temporal.growth}
	# This evidence is constructed by the rule replay above, never accepted as an
	# imported 'verified' flag or a digest-only assertion of event-time END.
	var verifier := func(_op: String,binding: String): return {"authorized":true,"binding":binding,"lineage":payload.lineage,"endurance_history":proof}
	var hydrated := Profiles.hydrate(payload,source,payload.character_id,payload.rules_revision,verifier)
	if not hydrated.success: return _fail("projection_rejected",hydrated)
	return {"success":true,"actor":hydrated.actor_definition,"accounting":expected_accounting,"end_growth":temporal.growth}

# Pure continuity proof, NOT a storage coordinator or an authorization to commit.
static func validate_extension(previous: Dictionary, candidate: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	for record: Dictionary in [previous,candidate]:
		var checked := validate(record,source)
		if not checked.success: return checked
	if candidate.head.epoch != previous.head.epoch or candidate.head.sequence != previous.head.sequence+1 or candidate.head.parent_digest != digest(previous): return _fail("stale_or_conflicting_head")
	if candidate.operations.slice(0,previous.operations.size()) != previous.operations: return _fail("operation_history_changed")
	var a := _projection(previous)
	var b := _projection(candidate)
	if a.character_id != b.character_id or a.lineage != b.lineage or a.profile_namespace != b.profile_namespace or a.base_attributes != b.base_attributes or candidate.source_digest != previous.source_digest: return _fail("identity_changed")
	if b.generation != a.generation+1: return _fail("generation_discontinuity")
	var replacement := Contract.validate_replacement(a,b)
	if not replacement.success: return replacement
	for field: String in ["awards","purchases","growth","settlements","order"]:
		if candidate.evidence[field].slice(0,previous.evidence[field].size()) != previous.evidence[field]: return _fail("evidence_history_changed")
	if previous.evidence.credit != candidate.evidence.credit or previous.evidence.credit_predecessor != candidate.evidence.credit_predecessor: return _fail("credit_history_changed")
	if previous.applied_ids != candidate.applied_ids.slice(0,previous.applied_ids.size()):
		# ID registry is grouped by scope, not append order; compare exact membership.
		for row: Dictionary in previous.applied_ids:
			if not candidate.applied_ids.has(row): return _fail("lifetime_id_history_changed")
	var continuity := Coordinator._validate_continuity(a,b)
	if not continuity.success: return continuity
	var ownership := Coordinator._validate_new_items(a,b)
	if not ownership.success: return ownership
	return {"success":true}

static func _projection(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.current.duplicate(true)
	var e: Dictionary = record.evidence
	result["purchases"] = e.purchases.duplicate(true)
	result["settlements"] = e.settlements.duplicate(true)
	result.permanent["growth"] = e.growth.duplicate(true)
	result.permanent["award_receipts"] = e.awards.duplicate(true)
	if e.credit != null: result["expc_credits"] = e.credit.duplicate(true)
	return result

# A historical credit keeps the exact predecessor projection as prefix
# references, not a trusted verification flag or another generation archive.
static func _historical_credit_basis(record: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var basis: Dictionary = record.evidence.credit_predecessor
	if not _keys(basis,["format","current","counts"]) or not basis.current is Dictionary or not basis.counts is Dictionary or not _keys(basis.counts,["awards","purchases","growth","settlements","order"]): return _fail("invalid_historical_credit_basis")
	var current: Dictionary = basis.current.duplicate(true)
	if not current.get("recovery") is Dictionary or not current.recovery.get("ledger") is Dictionary: return _fail("invalid_credit_checkpoint")
	var evidence := {"credit":null,"credit_predecessor":null}
	for key: String in basis.counts:
		var count: Variant = basis.counts[key]
		if not _uint(count) or count > record.evidence[key].size(): return _fail("invalid_credit_prefix_count")
		evidence[key] = record.evidence[key].slice(0,count).duplicate(true)
	if not _uint(current.get("generation")) or current.generation < 1 or current.generation != record.evidence.credit.records[0].after_generation or current.generation >= record.operations.size(): return _fail("unsupported_credit_predecessor_generation")
	# Only these known ledger arrays may reference an identical current prefix.
	var ledger: Variant = current.get("recovery",{}).get("ledger",{})
	var main_ledger: Variant = record.current.get("recovery",{}).get("ledger",{})
	if not ledger is Dictionary or not main_ledger is Dictionary: return _fail("invalid_credit_checkpoint")
	for key: String in ["awards","purchase_records","drop_resolutions"]:
		var value: Variant = ledger.get(key)
		if value is Dictionary:
			if not _keys(value,["v6_current_ledger_prefix"]) or not _uint(value.v6_current_ledger_prefix) or not main_ledger.get(key) is Array or value.v6_current_ledger_prefix > main_ledger[key].size(): return _fail("invalid_credit_ledger_reference")
			ledger[key] = main_ledger[key].slice(0,value.v6_current_ledger_prefix).duplicate(true)
	var operations: Array = record.operations.slice(0,current.generation)
	for operation: Dictionary in operations:
		if operation.get("binding_kind") != "legacy_document": return _fail("missing_credit_document_bindings")
	var head := {"epoch":"legacy_"+digest(operations),"sequence":1,"parent_digest":null,"legacy_operation_count":operations.size()}
	var prefix := assemble(current,evidence,operations,head,source)
	var checked := validate(prefix,source)
	if not checked.success: return _fail("historical_credit_prefix_rejected",checked)
	return {"success":true,"payload":_projection(prefix)}

static func _accounting(record: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var earned := 0
	var spent := 0
	for row: Dictionary in record.evidence.awards: earned += int(row.xp)
	for row: Dictionary in record.evidence.purchases: spent += int(row.cost)
	var credit := 0 if record.evidence.credit == null else Credit.AMOUNT
	var policy: Dictionary = source.progression_policy
	return {"initial_expm":int(policy.initial_expm),"initial_expc":int(policy.initial_expc),"earned_award_xp":earned,"credit_expc":credit,"spent_expc":spent,"expm_total":int(policy.initial_expm)+earned,"expc_available":int(policy.initial_expc)+earned+credit-spent}

static func _ids(record: Dictionary) -> Array:
	var result: Array = []
	for row: Dictionary in record.operations:
		result.append({"scope":"operation","id":row.id,"record_digest":digest(row)})
	for pair: Array in [["award","awards","award_id"],["purchase","purchases","purchase_id"],["growth","growth","growth_id"],["settlement","settlements","receipt_id"]]:
		for row: Dictionary in record.evidence[pair[1]]:
			result.append({"scope":pair[0],"id":row.get(pair[2],""),"record_digest":digest(row)})
	# Keep every acquisition origin even when the acquired instance is consumed.
	for receipt: Dictionary in record.evidence.settlements:
		if receipt.get("kind") in ["item","currency"]:
			var content: Dictionary = receipt.get("content",{})
			result.append({"scope":"item_origin","id":content.get("instance_id",""),"record_digest":digest(receipt)})
	if record.evidence.credit != null:
		for row: Dictionary in record.evidence.credit.get("records",[]):
			result.append({"scope":"credit","id":row.get("grant_id",""),"record_digest":digest(row)})
	for command: Dictionary in record.current.permanent.get("development",{}).get("commands",[]):
		result.append({"scope":"development","id":command.id,"record_digest":digest(command)})
	for run: String in record.current.get("run_history",[]):
		result.append({"scope":"run","id":run,"record_digest":digest(run)})
	return result

static func _chronology(payload: Dictionary, e: Dictionary, source: CombatCharacterDefinitionResource) -> Dictionary:
	var rows := {}
	for pair: Array in [["award","awards","award_id"],["purchase","purchases","purchase_id"],["growth","growth","growth_id"]]:
		for row: Dictionary in e[pair[1]]:
			rows[JSON.stringify([pair[0],row[pair[2]]])] = row
	if e.credit != null: rows[JSON.stringify(["credit",Credit.GRANT_ID])] = e.credit.records[0]
	if e.order.size() != rows.size(): return _fail("missing_or_duplicate_chronology")
	var seen := {}
	var cursors := {"award":0,"purchase":0,"growth":0}
	var actor: CombatActorDefinition = source.instantiate_actor(&"profile_candidate",source.display_name,PackedStringArray(payload.permanent.equipment_refs))
	if actor == null or not PrimeV3LevelCatalog.validate(actor.progression_policy,actor).is_empty(): return _fail("unsupported_creation")
	var earned := int(actor.progression_policy.initial_expm)
	var balance := int(actor.progression_policy.initial_expc)
	var level := actor.level
	var growth := {}
	for entry: Variant in e.order:
		if not entry is Dictionary or not _keys(entry,["kind","id"]) or not entry.kind is String or not entry.id is String: return _fail("invalid_chronology")
		var key := JSON.stringify([entry.kind,entry.id])
		if not rows.has(key) or seen.has(key): return _fail("unknown_or_duplicate_chronology")
		seen[key] = true
		var row: Dictionary = rows[key]
		if entry.kind != "credit":
			var field := "awards" if entry.kind == "award" else "purchases" if entry.kind == "purchase" else "growth"
			if e[field][cursors[entry.kind]] != row: return _fail("conflicting_evidence_order")
			cursors[entry.kind] += 1
		match entry.kind:
			"award":
				if level != PrimeV3LevelCatalog.level_for(actor.progression_policy.exp_type,earned): return _fail("missing_prior_growth")
				earned += row.xp
				balance += row.xp
			"credit": balance += Credit.AMOUNT
			"purchase":
				if level != PrimeV3LevelCatalog.level_for(actor.progression_policy.exp_type,earned): return _fail("purchase_growth_order_ambiguous")
				var preview := PrimeV3AdvancementCatalog.make_purchase_preview(StringName(row.purchase_kind),StringName(row.target_id),row.value_before,row.value_after,String(row.get("allocation","")))
				if not preview.available or row.cost != preview.cost or row.source_ref != preview.source_ref or balance < row.cost: return _fail("unaffordable_or_invalid_purchase")
				var applied := {}
				if row.purchase_kind == "attribute":
					match row.target_id:
						"end": applied = actor.apply_verified_endurance_advancement(row.value_before,row.value_after)
						"wis": applied = actor.apply_verified_wisdom_advancement(row.value_before,row.value_after)
						"str": applied = actor.apply_verified_strength_advancement(row.value_before,row.value_after,false)
						"dex": applied = actor.apply_verified_dexterity_advancement(row.value_before,row.value_after,String(row.get("allocation","")))
						"spd": applied = actor.apply_verified_speed_advancement(row.value_before,row.value_after)
						_: return _fail("unsupported_prototype_purchase")
				else: applied = actor.apply_verified_resistance_advancement(row.target_id,row.value_before,row.value_after)
				if not applied.success: return _fail("purchase_rejected",applied)
				balance -= row.cost
			"growth":
				var terms := CharacterLevelProgression.growth_terms(actor)
				if row.prior_level != level or row.level != level+1 or row.level > PrimeV3LevelCatalog.level_for(actor.progression_policy.exp_type,earned) or row.threshold != PrimeV3LevelCatalog.threshold(actor.progression_policy.exp_type,row.level): return _fail("growth_level_mismatch")
				if row.hit_die_sides != terms.die or row.die_flat_bonus != terms.flat or row.roll < 1 or row.roll > terms.die or row.hpb != terms.hpb or row.wisdom != terms.wisdom: return _fail("event_time_growth_mismatch")
				if row.hpm_before != actor.get_combat_stat("hpm") or row.hpm_increase != row.roll+terms.flat+terms.hpb or row.hpm_after != row.hpm_before+row.hpm_increase: return _fail("hpm_growth_mismatch")
				if row.resource != terms.resource or row.maximum_before != actor.resource_maxima.get(terms.resource,0) or row.maximum_increase != terms.resource_gain or row.maximum_after != row.maximum_before+row.maximum_increase: return _fail("resource_growth_mismatch")
				growth[row.growth_id] = {"end":actor.attributes.end,"hpb":terms.hpb,"record_digest":digest(row)}
				actor.progression_hpm_increase += row.hpm_increase
				actor.apply_equipment_stat_modifiers({})
				actor.resource_maxima[terms.resource] = row.maximum_after
				level += 1
	if level != payload.permanent.level or level != PrimeV3LevelCatalog.level_for(actor.progression_policy.exp_type,earned): return _fail("missing_growth")
	return {"success":true,"end":actor.attributes.end,"growth":growth}

static func _keys(value: Dictionary, expected: Array) -> bool:
	return value.size() == expected.size() and value.has_all(expected)

static func _uint(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= Contract.MAX_SAFE_INTEGER

static func _hash(value: Variant) -> bool:
	return value is String and value.length() == 64 and value == value.to_lower() and value.is_valid_hex_number(false)

static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
