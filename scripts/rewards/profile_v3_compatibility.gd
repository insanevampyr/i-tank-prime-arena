class_name ProfileV3Compatibility
extends RefCounted

# Dormant candidate validator and acknowledgement simulation. No I/O or gameplay.
const Legacy = preload("res://scripts/rewards/character_save_contract.gd")
const Life = preload("res://scripts/combat/life_state_history_contract.gd")
const Receipt = preload("res://scripts/rewards/character_settlement_receipt.gd")
const FIELDS := ["prototype_version","anchor_document","anchor_sha256","generation","life_history","history_binding","settlement_links","completion_links","gate_links"]

static func inspect_legacy(document: String) -> Dictionary:
	var checked := Legacy.decode(document)
	if not checked.success: return {"success":false,"status":"unsupported_legacy_preserved","preserved_document":document,"details":checked}
	return {"success":true,"status":"legacy_extension_absent","preserved_document":document,"payload":checked.payload.duplicate(true),"version":checked.version,"migrated":false}

static func validate(payload: Dictionary, authority: Callable) -> Dictionary:
	if not Life._keys(payload,FIELDS) or typeof(payload.prototype_version) != TYPE_INT or payload.prototype_version != 3: return _fail("unsupported_prototype_profile")
	if not payload.anchor_document is String or payload.anchor_sha256 != payload.anchor_document.sha256_text(): return _fail("anchor_integrity_mismatch")
	var legacy := inspect_legacy(payload.anchor_document)
	if not legacy.success or legacy.version != 2: return _fail("verified_v2_anchor_required")
	var anchor: Dictionary = legacy.payload
	if not payload.life_history is Dictionary or not payload.history_binding is Dictionary: return _fail("life_extension_required")
	var checked := Life.inspect_generation_binding(payload.life_history,payload.history_binding,authority)
	if not checked.success: return checked
	var history: Dictionary = payload.life_history
	var identity: Dictionary = history.identity
	if anchor.character_id != identity.profile_id or anchor.definition_id != identity.character_id or anchor.rules_revision != identity.rules_revision or anchor.get("profile_namespace") != identity.namespace: return _fail("anchor_identity_or_namespace_conflict")
	if not Life._integer(payload.generation,1) or payload.generation != anchor.generation+payload.history_binding.generation: return _fail("profile_generation_rebase_conflict")
	if history.origin.available_expc != anchor.xp.unspent or history.origin.classification.authored_attributes != anchor.base_attributes: return _fail("anchor_baseline_conflict")
	# Real integration must delegate this attestation to existing projection/hydration
	# and source definitions. A file cannot attest its own legal baseline or items.
	if not Life._authorized(authority,"v3_anchor",anchor,identity): return _fail("anchor_definition_or_history_unverified")
	var settlements := _index(payload.settlement_links)
	var completions := _index(payload.completion_links)
	var gates := _index(payload.gate_links)
	if not settlements.success or not completions.success or not gates.success: return _fail("duplicate_or_missing_event_link")
	var ids := {}
	var effects := {}
	for receipt: Variant in anchor.get("settlements",[]):
		var valid := _receipt_identity(receipt,identity,ids,effects)
		if not valid.success: return valid
	var prefix := history.duplicate(true)
	prefix.events = []
	var used_settlements := {}
	var used_completions := {}
	var used_gates := {}
	var exchanges := {}
	var last_run := ""
	var last_wave := ""
	var last_outcome := {}
	for event: Dictionary in history.events:
		var before := Life.replay(prefix,authority)
		if not before.success: return before
		if event.kind == "attributes" and not Life._authorized(authority,"v3_attribute_effect",event,identity): return _fail("attribute_effect_rule_unverified")
		if event.kind == "attempt_begin":
			var checkpoint: Dictionary = event.data.checkpoint
			var run_changed: bool = not last_run.is_empty() and checkpoint.run_id != last_run
			var next_wave: bool = not last_outcome.is_empty() and checkpoint.wave_id != last_wave and not run_changed
			if run_changed or next_wave:
				if not gates.links.has(event.event_id): return _fail("progression_evidence_required")
				var gate: Dictionary = gates.links[event.event_id]
				if not Life._keys(gate,["event_id","kind","evidence"]): return _fail("invalid_progression_link")
				var valid := _gate(gate,identity,before.state,checkpoint,last_run,last_wave,last_outcome,run_changed,authority)
				if not valid.success: return valid
				used_gates[event.event_id] = true
			last_run = checkpoint.run_id
			last_wave = checkpoint.wave_id
		if event.kind == "resurrection" and not event.data.has("completion"): return _fail("verified_resurrection_completion_required")
		if event.kind == "wave_outcome":
			if not completions.links.has(event.event_id): return _fail("closed_exchange_evidence_required")
			var link: Dictionary = completions.links[event.event_id]
			if not Life._keys(link,["event_id","evidence"]): return _fail("invalid_completion_link")
			var snapshot := _party_snapshot(link.evidence,identity,before.state,authority)
			if not snapshot.success: return snapshot
			var evidence: Dictionary = link.evidence
			if evidence.team_id != before.state.active_attempt.team_id or evidence.wave_id != before.state.active_attempt.checkpoint.wave_id or evidence.exchange_id != event.data.outcome_ref or evidence.final_wave != event.data.final_wave: return _fail("completion_context_conflict")
			if snapshot.result == "combat" or event.data.team_won != (snapshot.result == "victory"): return _fail("team_wipe_or_victory_conflict")
			if exchanges.has(evidence.exchange_id): return _fail("duplicate_combat_completion")
			exchanges[evidence.exchange_id] = Life.fingerprint(evidence)
			used_completions[event.event_id] = true
			last_outcome = evidence.duplicate(true)
		if event.kind in ["emergency_receipt","reward_receipt"]:
			if not settlements.links.has(event.event_id): return _fail("ledger_receipt_link_required")
			if event.kind == "emergency_receipt" and (before.state.active_attempt.is_empty() or not event.data.receipt.has("decision_id")): return _fail("attempt_and_player_decision_required")
			var link: Dictionary = settlements.links[event.event_id]
			if not Life._keys(link,["event_id","receipts"]) or not link.receipts is Array or link.receipts.is_empty(): return _fail("invalid_settlement_link")
			var valid := _settlements(event,link,before.state,identity,ids,effects,authority)
			if not valid.success: return valid
			used_settlements[event.event_id] = true
		if event.kind in ["owned_state","attempt_begin","reward_receipt"]:
			if not Life._authorized(authority,"v3_ownership",event,identity): return _fail("ownership_projection_unverified")
		prefix.events.append(event.duplicate(true))
	if used_settlements.size() != settlements.links.size() or used_completions.size() != completions.links.size() or used_gates.size() != gates.links.size(): return _fail("orphaned_event_link")
	var active_cost := 0
	var awards := 0
	for receipt: Dictionary in checked.state.receipts: active_cost += int(receipt.cost_expc)
	for receipt: Dictionary in checked.state.reward_receipts: awards += int(receipt.expc_after)-int(receipt.expc_before)
	if anchor.xp.unspent+awards-active_cost != checked.state.available_expc: return _fail("single_wallet_accounting_conflict")
	return {"success":true,"status":"candidate_validated_not_published","state":checked.state,"legacy_document":payload.anchor_document,"ledger_projection":{"anchor_expc":anchor.xp.unspent,"active_awards":awards,"active_recovery_cost":active_cost,"available_expc":checked.state.available_expc},"storage_writes":0}

static func _party_snapshot(value: Variant, identity: Dictionary, subject: Dictionary, authority: Callable) -> Dictionary:
	if not value is Dictionary or not Life._keys(value,["team_id","wave_id","exchange_id","closed","enemies_defeated","final_wave","participants"]): return _fail("invalid_party_evidence")
	if not Life._text(value.team_id) or not Life._text(value.exchange_id) or typeof(value.closed) != TYPE_BOOL or not value.closed or typeof(value.enemies_defeated) != TYPE_BOOL or typeof(value.final_wave) != TYPE_BOOL or not value.participants is Array or value.participants.is_empty(): return _fail("closed_exchange_evidence_required")
	var ids := {}
	var found_subject := false
	var alive := 0
	var members := 0
	for row: Variant in value.participants:
		if not row is Dictionary or not Life._keys(row,["profile_id","namespace","generation","event_head","life","participation"]): return _fail("invalid_participant_head")
		if not Life._text(row.profile_id) or not row.profile_id.is_valid_identifier() or not row.profile_id.begins_with("prod_" if identity.namespace == "normal" else "dev_") or ids.has(row.profile_id) or row.namespace != identity.namespace or not Life._integer(row.generation,1) or not row.event_head is String or row.event_head.length() != 64 or not row.event_head.is_valid_hex_number(false) or row.life not in ["alive","dead"] or row.participation not in ["member","left"]: return _fail("duplicate_or_conflicting_participant")
		ids[row.profile_id] = true
		if not Life._authorized(authority,"v3_peer_head",row,identity): return _fail("participant_head_unverified")
		if row.profile_id == identity.profile_id:
			found_subject = true
			if row.event_head != subject.head_hash or row.life != subject.life or row.participation != subject.participation: return _fail("completion_subject_head_conflict")
		if row.participation == "member":
			members += 1
			if row.life == "alive": alive += 1
	if not found_subject: return _fail("subject_participant_missing")
	if members == 0: return _fail("active_party_required")
	if not Life._authorized(authority,"v3_exchange",value,identity): return _fail("closed_exchange_authority_required")
	return {"success":true,"result":Life.classify_party_completion(alive,value.enemies_defeated),"alive":alive}

static func _gate(link: Dictionary, identity: Dictionary, subject: Dictionary, checkpoint: Dictionary, previous_run: String, previous_wave: String, outcome: Dictionary, run_changed: bool, authority: Callable) -> Dictionary:
	if run_changed:
		if link.kind != "new_run" or not link.evidence is Dictionary or not Life._keys(link.evidence,["previous_run","next_run","wave_id","subject_head"]): return _fail("explicit_run_rebase_required")
		if link.evidence.previous_run != previous_run or link.evidence.next_run != checkpoint.run_id or link.evidence.wave_id != "wave_1" or checkpoint.wave_id != "wave_1" or link.evidence.subject_head != subject.head_hash: return _fail("run_rebase_conflict")
		return {"success":true} if Life._authorized(authority,"v3_run_rebase",link.evidence,identity) else _fail("run_rebase_unverified")
	if link.kind != "next_wave": return _fail("invalid_progression_kind")
	var checked := _party_snapshot(link.evidence,identity,subject,authority)
	if not checked.success: return checked
	if checked.result != "victory" or link.evidence.exchange_id != outcome.exchange_id or link.evidence.wave_id != previous_wave or checkpoint.wave_id != "wave_"+str(int(previous_wave.trim_prefix("wave_"))+1): return _fail("next_wave_context_conflict")
	for row: Dictionary in link.evidence.participants:
		if row.participation == "member" and row.life == "dead": return _fail("dead_teammate_blocks_advancement")
	return {"success":true}

static func _settlements(event: Dictionary, link: Dictionary, before: Dictionary, identity: Dictionary, ids: Dictionary, effects: Dictionary, authority: Callable) -> Dictionary:
	if before.active_attempt.is_empty(): return _fail("settlement_attempt_scope_required")
	var xp := 0
	var purchases := 0
	var ownership := false
	for receipt: Variant in link.receipts:
		var valid := _receipt_identity(receipt,identity,ids,effects)
		if not valid.success: return valid
		if receipt.run_id != before.active_attempt.checkpoint.run_id or receipt.wave_id != before.active_attempt.checkpoint.wave_id: return _fail("settlement_checkpoint_conflict")
		if event.kind == "emergency_receipt":
			if receipt.kind != "purchase" or receipt.content.purchase_id != event.data.receipt.transaction_id or receipt.content.cost != event.data.receipt.cost_expc: return _fail("purchase_receipt_conflict")
			purchases += 1
		elif receipt.kind == "xp":
			if receipt.content.award_id != event.data.receipt_id: return _fail("reward_identity_conflict")
			xp += int(receipt.content.amount)
		elif receipt.kind in ["item","currency"]: ownership = true
		else: return _fail("reward_receipt_kind_conflict")
		if not Life._authorized(authority,"v3_settlement",receipt,identity): return _fail("ledger_receipt_unverified")
	if event.kind == "emergency_receipt" and (purchases != 1 or link.receipts.size() != 1): return _fail("duplicate_purchase_link")
	if event.kind == "reward_receipt" and xp != event.data.expc_after-event.data.expc_before: return _fail("reward_amount_conflict")
	if event.kind == "reward_receipt" and not Life._authorized(authority,"v3_reward_progression",event,identity): return _fail("ordinary_progression_evidence_unavailable")
	if event.kind == "reward_receipt" and event.data.owned_before != event.data.owned_after:
		if not ownership: return _fail("ownership_settlement_missing")
		if not Life._authorized(authority,"v3_ownership_settlement",{"event":event,"receipts":link.receipts},identity): return _fail("ownership_settlement_unverified")
	return {"success":true}

static func _receipt_identity(value: Variant, identity: Dictionary, ids: Dictionary, effects: Dictionary) -> Dictionary:
	if not value is Dictionary: return _fail("invalid_receipt")
	var valid := Receipt.validate(value)
	if not valid.success: return valid
	var effect := Receipt.effect_id(value)
	if value.profile_id != identity.profile_id or ids.has(value.receipt_id) or effects.has(effect): return _fail("duplicate_or_foreign_receipt")
	ids[value.receipt_id] = true
	effects[effect] = true
	if value.kind in ["item","currency"]:
		var origin := "origin:"+String(value.content.provenance_digest)
		if effects.has(origin): return _fail("duplicate_acquisition_origin")
		effects[origin] = true
	return {"success":true}

static func _index(value: Variant) -> Dictionary:
	if not value is Array or value.size() > Life.MAX_EVENTS: return _fail("invalid_event_links")
	var links := {}
	for row: Variant in value:
		if not row is Dictionary or not Life._text(row.get("event_id")) or links.has(row.event_id): return _fail("duplicate_event_link")
		links[row.event_id] = row
	return {"success":true,"links":links}

static func encode(payload: Dictionary, authority: Callable) -> Dictionary:
	var checked := validate(payload,authority)
	if not checked.success: return checked
	var body := Life.canonical(payload)
	var text := Life.canonical({"format":Legacy.FORMAT,"version":3,"payload_json":body,"sha256":body.sha256_text()})
	if text.to_utf8_buffer().size() > Life.MAX_BYTES: return _fail("prototype_profile_too_large")
	return {"success":true,"text":text}

static func decode(text: String, authority: Callable) -> Dictionary:
	if text.to_utf8_buffer().size() > Life.MAX_BYTES: return _fail("prototype_profile_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary: return _fail("invalid_profile_json")
	var envelope: Dictionary = parser.data
	if envelope.get("version") in [1,2]: return inspect_legacy(text)
	if not Life._keys(envelope,["format","version","payload_json","sha256"]) or envelope.format != Legacy.FORMAT or envelope.version != 3 or not envelope.payload_json is String or envelope.payload_json.sha256_text() != envelope.sha256: return _fail("unsupported_or_corrupt_profile")
	if parser.parse(envelope.payload_json) != OK or not parser.data is Dictionary: return _fail("invalid_profile_body")
	var payload: Dictionary = Life._json_integers(parser.data)
	if Life.canonical(payload) != envelope.payload_json: return _fail("noncanonical_profile")
	var checked := validate(payload,authority)
	if not checked.success: return checked
	return {"success":true,"payload":payload,"state":checked.state,"status":"prototype_only"}

static func prepare(current: Dictionary, candidate: Dictionary, expected_generation: int, transaction_id: String, authority: Callable) -> Dictionary:
	var checked := validate(candidate,authority)
	if not checked.success: return checked
	var anchor: Dictionary = Legacy.decode(candidate.anchor_document).payload
	if not current.is_empty():
		var prior := validate(current,authority)
		if not prior.success: return prior
	var actual: int = anchor.generation if current.is_empty() else current.generation
	if expected_generation != actual or candidate.generation != actual+1 or transaction_id != candidate.history_binding.transaction_id: return _fail("stale_generation_or_transaction")
	if not current.is_empty():
		if current.anchor_document != candidate.anchor_document: return _fail("anchor_rewrite_prohibited")
		var continuity := Life.compare_recovery(current.life_history,candidate.life_history,authority)
		if not continuity.success or continuity.classification not in ["exact","extension"]: return _fail("unauthorized_history_rollback")
		for field: String in ["settlement_links","completion_links","gate_links"]:
			if candidate[field].slice(0,current[field].size()) != current[field]: return _fail("immutable_links_changed")
		if candidate.history_binding.previous_binding_hash != Life.fingerprint(current.history_binding) or candidate.history_binding.publication_ids.slice(0,current.history_binding.publication_ids.size()) != current.history_binding.publication_ids: return _fail("publication_chain_conflict")
	var expected_record: Dictionary = {"legacy_anchor":candidate.anchor_sha256,"generation":anchor.generation} if current.is_empty() else current
	if not Life._authorized(authority,"v3_expected_head",expected_record, candidate.life_history.identity): return _fail("stale_or_unverified_storage_head")
	var encoded := encode(candidate,authority)
	if not encoded.success: return encoded
	return {"success":true,"prepared":{"expected_digest":Life.fingerprint(expected_record),"expected_generation":actual,"transaction_id":transaction_id,"payload":candidate.duplicate(true),"document":encoded.text},"published":false}

static func acknowledge(prepared: Dictionary, readback: Dictionary, authority: Callable) -> Dictionary:
	if not Life._keys(prepared,["expected_digest","expected_generation","transaction_id","payload","document"]) or not Life._keys(readback,["document","transaction_id","generation","transaction_completed"]): return _fail("invalid_acknowledgement")
	if not Life._integer(prepared.expected_generation,1) or not prepared.payload is Dictionary or not prepared.document is String or not Life._text(prepared.transaction_id) or not readback.document is String or not Life._text(readback.transaction_id) or not Life._integer(readback.generation,1): return _fail("invalid_acknowledgement_fields")
	if typeof(readback.transaction_completed) != TYPE_BOOL or not readback.transaction_completed: return _fail("publication_pending_or_failed")
	if readback.document != prepared.document or readback.transaction_id != prepared.transaction_id or readback.generation != prepared.expected_generation+1: return _fail("exact_readback_mismatch")
	var checked := decode(readback.document,authority)
	if not checked.success or checked.get("payload") != prepared.payload: return _fail("readback_validation_failed")
	if not Life._authorized(authority,"v3_committed_readback",{"prepared":prepared,"readback":readback},prepared.payload.life_history.identity): return _fail("commit_acknowledgement_unverified")
	if not Life._authorized(authority,"v3_current_document",{"payload_digest":Life.fingerprint(prepared.payload),"generation":readback.generation},prepared.payload.life_history.identity): return _fail("acknowledged_generation_not_current")
	return {"success":true,"state":"verified_committed_fixture","generation":readback.generation,"storage_writes":0}

static func prepare_cohort(_candidates: Array) -> Dictionary:
	return _fail("multi_profile_atomic_publication_unavailable")

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason,"storage_writes":0,"gameplay_mutations":0}
