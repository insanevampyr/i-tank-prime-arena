extends RefCounted

# Dormant Pass B. In-memory records only; no filesystem, storage writer,
# coordinator replacement, migration activation or live admission callers.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Equivalence = preload("res://scripts/rewards/compact_v6_equivalence.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Backup = preload("res://scripts/rewards/character_backup_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
# Prototype input budget, separate from the manual-backup transport budget.
# Per-document scanner bounds, receipt/source checks and continuity are intact.
const MAX_ARCHIVE_BYTES := 256 * 1024 * 1024

static func begin(rows: Array, save_namespace: String) -> Conversion:
	return Conversion.new(rows,save_namespace)

static func convert(rows: Array, save_namespace: String) -> Dictionary:
	var job := begin(rows,save_namespace)
	for iteration in range(rows.size()+4):
		if job.result.get("state") != "pending": return job.result
		job.step()
	if job.result.get("state") != "pending": return job.result
	job.cancel()
	return {"success":false,"state":"failed","reason":"conversion_step_budget_exceeded"}

class Conversion extends RefCounted:
	var result: Dictionary = {"success":false,"state":"pending","stage":"validate","progress":0}
	var source: CombatCharacterDefinitionResource
	var _rows: Array
	var _namespace: String
	var _manifest: Array = []
	var _operations: Array = []
	var _previous := {}
	var _proof := {}
	var _actor: CombatActorDefinition
	var _starter := {}
	var _source_resources: CombatDefinitionCatalog
	var _order: Array = []
	var _credit_basis: Variant = null
	var _record := {}
	var _text := ""
	var _cursor := 0
	var _started: int
	var _metrics := {"legacy_validation_ms":0.0,"conversion_ms":0.0,"independent_verification_ms":0.0,"source_binding_ms":0.0}
	var _comparison := {}

	func _init(rows: Array, save_namespace: String) -> void:
		_started = Time.get_ticks_usec()
		_rows = rows
		_namespace = save_namespace
		if save_namespace not in ["normal","dev_normal"] or rows.is_empty() or rows.size() > Backup.MAX_GENERATIONS:
			_fail("unsupported_namespace_or_history_size"); return
		var start := Time.get_ticks_usec()
		# Same operation-scoped resource ownership used by the existing backup
		# validator. This caches source assets, never validation decisions.
		_source_resources = CombatDefinitionCatalog.load_default_fixture_catalog()
		var bytes := 0
		for row: Variant in rows:
			if not row is Dictionary or not Backup.keys(row,["generation","transaction_id","document"]) or not row.document is String or not row.transaction_id is String or not CharacterSaveStorage._valid_id(row.transaction_id) or typeof(row.generation) != TYPE_INT:
				_fail("invalid_generation_record"); return
			var size: int = row.document.to_utf8_buffer().size()
			bytes += size
			if size > Backup.MAX_GENERATION_BYTES or bytes > MAX_ARCHIVE_BYTES:
				_fail("prototype_archive_size_limit"); return
			_manifest.append([row.generation,row.transaction_id,row.document.sha256_text()])
		_metrics.source_binding_ms = float(Time.get_ticks_usec()-start)/1000.0
		_metrics["legacy_bytes"] = bytes

	func cancel() -> Dictionary:
		if result.get("state") == "pending":
			result = {"success":false,"state":"canceled","reason":"conversion_canceled"}
			_release()
		return result

	func step() -> Dictionary:
		if result.get("state") != "pending": return result
		match result.stage:
			"validate":
				if _rows.size() != _manifest.size() or not _unchanged(_cursor): return _fail("source_changed_during_conversion")
				var start := Time.get_ticks_usec()
				var valid := _validate_row(_rows[_cursor])
				_metrics.legacy_validation_ms += float(Time.get_ticks_usec()-start)/1000.0
				if not valid.success: return _fail(valid.reason,valid.get("details",{}))
				_cursor += 1
				result.progress = _cursor
				if _cursor == _rows.size(): result.stage = "convert"
			"convert":
				var start := Time.get_ticks_usec()
				var evidence := {"awards":_previous.permanent.award_receipts,"purchases":_previous.purchases,"growth":_previous.permanent.growth,"settlements":_previous.settlements,"credit":_previous.get("expc_credits"),"credit_predecessor":_credit_basis,"order":_order}
				if _credit_basis != null: _deduplicate_credit_ledger()
				var head := {"epoch":"legacy_"+V6.digest(_operations),"sequence":1,"parent_digest":null,"legacy_operation_count":_operations.size()}
				_record = V6.assemble(strip(_previous),evidence,_operations,head,source)
				var encoded := V6.encode(_record,source)
				_metrics.conversion_ms = float(Time.get_ticks_usec()-start)/1000.0
				if not encoded.success: return _fail("compact_conversion_rejected",encoded)
				_text = encoded.text
				result.stage = "verify"
			"verify":
				var start := Time.get_ticks_usec()
				_comparison = Equivalence.compare(_record,_previous,_actor,_proof,source,_rows)
				_metrics.independent_verification_ms = float(Time.get_ticks_usec()-start)/1000.0
				if not _comparison.success:
					if _rows.size() != _manifest.size(): return _fail("source_changed_during_conversion")
					for index in range(_rows.size()):
						if not _unchanged(index): return _fail("source_changed_during_conversion")
					return _fail(_comparison.reason,_comparison.get("details",{}))
				result.stage = "source_check"
			"source_check":
				var start := Time.get_ticks_usec()
				if _rows.size() != _manifest.size(): return _fail("source_changed_during_conversion")
				for index in range(_rows.size()):
					if not _unchanged(index): return _fail("source_changed_during_conversion")
				_metrics.source_binding_ms += float(Time.get_ticks_usec()-start)/1000.0
				_metrics["total_ms"] = float(Time.get_ticks_usec()-_started)/1000.0
				_metrics["compact_bytes"] = _text.to_utf8_buffer().size()
				_metrics["native_static_at_completion"] = OS.get_static_memory_usage()
				_metrics["native_process_peak"] = OS.get_static_memory_peak_usage()
				result = {"success":true,"state":"complete","record":_record,"text":_text,"comparison":_comparison,"metrics":_metrics,"source_archive_digest":V6.digest(_manifest),"generation_count":_manifest.size()}
				_release()
		return result

	func _unchanged(index: int) -> bool:
		if index >= _rows.size() or not _rows[index] is Dictionary: return false
		var row: Dictionary = _rows[index]
		return Backup.keys(row,["generation","transaction_id","document"]) and row.get("document") is String and [row.get("generation"),row.get("transaction_id"),row.document.sha256_text()] == _manifest[index]

	func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
		result = {"success":false,"state":"failed","reason":reason,"generation":_cursor+1,"details":details}
		_release()
		return result

	func _release() -> void:
		# Assign, never clear the caller-owned array or any of its records.
		_rows = []; _previous = {}; _proof = {}; _actor = null
		_order = []; _operations = []; _credit_basis = null; _record = {}; _text = ""
		_source_resources = null; _starter = {}

	func _validate_row(row: Dictionary) -> Dictionary:
		for operation: Dictionary in _operations:
			if operation.id == row.transaction_id: return {"success":false,"reason":"duplicate_transaction"}
		var scanned := Backup.scan_json(row.document)
		if not scanned.success: return scanned
		var envelope: Variant = JSON.parse_string(row.document)
		if not envelope is Dictionary or not envelope.get("payload_json") is String: return {"success":false,"reason":"invalid_character_document"}
		scanned = Backup.scan_json(envelope.payload_json)
		if not scanned.success: return scanned
		var decoded := Contract.decode(row.document)
		if not decoded.success: return {"success":false,"reason":decoded.get("reason","invalid_character_document"),"details":decoded}
		if decoded.version not in [2,4,5]: return {"success":false,"reason":"unsupported_legacy_version"}
		var payload: Dictionary = decoded.payload
		if payload.generation != _cursor+1 or row.generation != payload.generation: return {"success":false,"reason":"generation_gap"}
		if _starter.is_empty():
			_starter = Admission.prepare_starter(&"vaelis_thorn",_namespace,String(payload.get("lineage",{}).get("baseline_digest","")))
			if not _starter.success: return _starter
			source = _starter.source
		var starter: Dictionary = _starter
		if payload.character_id != starter.profile_id or payload.profile_namespace != _namespace or payload.lineage != starter.prepared.payload.lineage or payload.rules_revision != Admission.RULES or payload.definition_id != String(source.definition_id): return {"success":false,"reason":"profile_source_or_namespace_mismatch"}
		if not payload.has_all(["recovery","equipment_state","run_history"]): return {"success":false,"reason":"unsupported_missing_playable_checkpoint"}
		if _cursor == 0 and (not payload.purchases.is_empty() or not payload.permanent.growth.is_empty() or not payload.permanent.award_receipts.is_empty() or payload.has("expc_credits")): return {"success":false,"reason":"unsupported_missing_creation_prefix"}
		var receipts := Coordinator._validate_receipts(payload)
		if not receipts.success: return receipts
		if not _previous.is_empty():
			for checked: Dictionary in [Contract.validate_replacement(_previous,payload),Coordinator._validate_continuity(_previous,payload)]:
				if not checked.success: return checked
		var ownership := Coordinator._validate_new_items(_previous,payload)
		if not ownership.success: return ownership
		var end_proof := {}
		if EnduranceGrowthHistory.has_purchases(payload):
			end_proof = EnduranceGrowthHistory.extend(source,payload,_previous,_proof)
			if not end_proof.success: return end_proof
		var binding := Profiles.fingerprint(payload)
		var verifier := func(op: String,requested: String): return {"authorized":op == "hydrate" and requested == binding,"binding":requested,"lineage":starter.prepared.payload.lineage,"endurance_history":end_proof}
		var hydrated := Profiles.hydrate(payload,source,starter.profile_id,Admission.RULES,verifier)
		if not hydrated.success: return hydrated
		var battlefield := ArenaBattlefield.create_task16_test_arena()
		if payload.recovery.battlefield_digest != Profiles.fingerprint(battlefield.to_dictionary()): return {"success":false,"reason":"checkpoint_battlefield_mismatch"}
		var position: Array = payload.recovery.player_position
		if not battlefield.is_position_legal(&"player",Vector2i(position[0],position[1]),{}).legal: return {"success":false,"reason":"checkpoint_position_illegal"}
		var extracted := _extract_order(payload)
		if not extracted.success: return extracted
		_operations.append({"id":row.transaction_id,"request_digest":row.document.sha256_text(),"binding_kind":"legacy_document"})
		_previous = payload; _actor = hydrated.actor_definition; _proof = end_proof
		return {"success":true}

	func _extract_order(payload: Dictionary) -> Dictionary:
		var old_p: Dictionary = _previous.get("permanent",{})
		var awards: Array = payload.permanent.award_receipts.slice(old_p.get("award_receipts",[]).size())
		var purchases: Array = payload.purchases.slice(_previous.get("purchases",[]).size())
		var growth: Array = payload.permanent.growth.slice(old_p.get("growth",[]).size())
		if not purchases.is_empty() and (not awards.is_empty() or not growth.is_empty()): return {"success":false,"reason":"unsupported_ambiguous_purchase_award_order"}
		if payload.has("expc_credits") and not _previous.has("expc_credits"):
			var approve := func(binding: Dictionary): return {"confirmed":true,"binding":Credit.digest(binding)}
			# Pure expected-delta calculation, never storage publication or a UI
			# grant. The real predecessor was fully validated by the prior step.
			var expected := Credit.prepare(_previous,approve)
			if not expected.success or expected.payload != payload: return {"success":false,"reason":"unsupported_credit_with_other_mutations"}
			var counts := {"awards":old_p.award_receipts.size(),"purchases":_previous.purchases.size(),"growth":old_p.growth.size(),"settlements":_previous.settlements.size(),"order":_order.size()}
			_credit_basis = {"format":"compact_legacy_credit_basis_v1","current":strip(_previous),"counts":counts}
			_order.append({"kind":"credit","id":Credit.GRANT_ID})
		var matched := 0
		for award: Dictionary in awards:
			_order.append({"kind":"award","id":award.award_id})
			for record: Dictionary in growth:
				if record.growth_id.begins_with(award.award_id+"/level_"):
					_order.append({"kind":"growth","id":record.growth_id}); matched += 1
		if matched != growth.size(): return {"success":false,"reason":"unsupported_missing_causal_growth_id"}
		for purchase: Dictionary in purchases: _order.append({"kind":"purchase","id":purchase.purchase_id})
		return {"success":true}

	func _deduplicate_credit_ledger() -> void:
		var ledger: Dictionary = _credit_basis.current.recovery.ledger
		var current: Dictionary = _previous.recovery.ledger
		var removed_bytes := 0
		for key: String in ["awards","purchase_records","drop_resolutions"]:
			var old: Variant = ledger.get(key)
			var now: Variant = current.get(key)
			if old is Array and now is Array and not old.is_empty() and old == now.slice(0,old.size()):
				var reference := {"v6_current_ledger_prefix":old.size()}
				removed_bytes += JSON.stringify(old,"",true,true).to_utf8_buffer().size()-JSON.stringify(reference).to_utf8_buffer().size()
				ledger[key] = reference
		_metrics["deduplicated_credit_ledger_bytes"] = removed_bytes

	static func strip(payload: Dictionary) -> Dictionary:
		var current := payload.duplicate(true)
		for key: String in ["purchases","settlements","expc_credits"]: current.erase(key)
		current.permanent.erase("growth"); current.permanent.erase("award_receipts")
		return current
