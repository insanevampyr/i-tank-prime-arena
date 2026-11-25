extends CharacterBrowserPersistence
# Dormant asynchronous route; existing Coordinator remains the sole mutation
# authority. No playable caller constructs this class.
const Route = preload("res://scripts/rewards/compact_v6_browser_storage.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Portable = preload("res://scripts/rewards/compact_v6_portable.gd")
var route: RefCounted
var adapter: RefCounted
var candidate: RefCounted
var expected: Variant
var confirmation: Callable
var kind := ""
var phase := ""
var job := ""
var status := {}
var request := {}
var text := ""
var capsule := ""
var incoming := ""
var target := {}
var before := {}
var raw := {}
var publication := {}
var measures := {}
var started := 0
var _request_seal := ""
var canceled := false
var fault := "" # Disposable route only, no live fault interface.

func _init() -> void: super(null)

func begin_compact(p_route: RefCounted, p_adapter: RefCounted, p_candidate: RefCounted, p_expected: Variant) -> Dictionary:
	if p_adapter == null or p_candidate == null or not is_instance_of(p_adapter,load("res://scripts/rewards/compact_v6_gameplay_candidate.gd")) or not is_instance_of(p_candidate,load("res://scripts/rewards/compact_v6_gameplay_candidate.gd").Prepared): return Route.fail("compact_owned_candidate_required")
	if not phase.is_empty(): return Route.fail("operation_in_flight")
	adapter = p_adapter; candidate = p_candidate
	request = adapter.publication_request(candidate)
	if not request.get("success",false): return request
	_request_seal = V6.digest(_request_binding())
	return _begin(p_route,"live",p_expected)

func begin_activation(p_route: RefCounted, consent: Callable) -> Dictionary:
	if not phase.is_empty() or not consent.is_valid(): return Route.fail("explicit_activation_confirmation_required")
	confirmation = consent
	return _begin(p_route,"activation",null)

func begin_restore(p_route: RefCounted, portable: String, p_expected: Variant, consent: Callable) -> Dictionary:
	if not phase.is_empty() or not consent.is_valid(): return Route.fail("explicit_restore_confirmation_required")
	incoming = portable; confirmation = consent
	return _begin(p_route,"restore",p_expected)

func begin_load(p_route: RefCounted, repair: bool = false) -> Dictionary:
	return _begin(p_route,"repair" if repair else "load",null)

func cancel_before_publication() -> Dictionary:
	if phase.is_empty(): return Route.fail("no_pending_operation")
	canceled = true
	# Drain the original callback. Publication may already have committed; its
	# readback must still reconcile, never become an implicit rollback.
	return {"success":false,"state":"pending","reason":"cancellation_requested"}

func _begin(p_route: RefCounted, operation: String, p_expected: Variant) -> Dictionary:
	if not phase.is_empty(): return Route.fail("operation_in_flight")
	if p_route == null or not is_instance_of(p_route,Route) or not p_route.valid_context() or p_route.owner.is_empty(): return Route.fail("disposable_browser_writer_required")
	route = p_route; kind = operation; expected = p_expected; measures = {}; publication = {}; canceled = false; started = Time.get_ticks_usec()
	return _dispatch("snapshot",{})

func _dispatch(operation: String, args: Dictionary) -> Dictionary:
	phase = operation
	var response: Dictionary = route.begin(operation,args)
	if response.get("state") != "pending": phase = ""; status = response; return status
	job = response.job; status = response
	return response

func poll_compact() -> Dictionary:
	if phase.is_empty(): return status.duplicate(true)
	var response: Dictionary = route.poll(job)
	if response.get("state") == "pending": return response
	if phase == "publish":
		publication = response
		return _dispatch("snapshot",{}) # Abort/uncertainty NEVER authorize replay.
	if not response.get("success",false): return _complete(response)
	if phase == "repair": return _dispatch("snapshot",{})
	if phase == "snapshot":
		if canceled and publication.is_empty(): return _complete(Route.fail("canceled_before_publication"))
		var t := Time.get_ticks_usec()
		var loaded: Dictionary = route.accept_snapshot(response)
		measures["semantic_ms"] = measures.get("semantic_ms",0.0)+float(Time.get_ticks_usec()-t)/1000.0
		measures["idb_snapshot_ms"] = measures.get("idb_snapshot_ms",0.0)+response.get("transaction_ms",0.0)
		if not loaded.get("success",false): return _complete(loaded)
		raw = route.raw_copy()
		if kind in ["load","repair"]:
			if loaded.get("empty",false): return _complete(loaded)
			if loaded.exact_recovery_needed:
				if kind != "repair": return _complete(Route.fail("exact_recovery_required"))
				return _dispatch("repair",{"owner":route.owner,"text":loaded.text,"expected_route":loaded.route,"expected_capsule":_blob(raw,"capsule",loaded.route.capsule_digest)})
			return _dispatch("match",_match_arguments())
		if not publication.is_empty():
			if loaded.get("empty",false) or loaded.exact_recovery_needed or loaded.text != text or loaded.capsule_text != capsule or loaded.route != target: return _complete(Route.fail("compact_publication_unverified",publication))
			return _dispatch("match",_match_arguments())
		before = loaded
		var built := _prepare()
		if not built.get("success",false): return _complete(built)
		if not before.get("empty",false) and before.text == text:
			publication = {"success":true,"already_applied":true}
			return _dispatch("match",_match_arguments())
		var args := {"owner":route.owner,"text":text,"capsule":capsule,"route":target,"route_json":JSON.stringify(target,"",true,true),"route_digest":V6.digest(target),"expected_route":raw.route,"legacy_head":raw.legacy_head,"legacy_rows":raw.legacy_rows,"legacy_receipts":raw.legacy_receipts,"expected_record":null,"expected_capsule":null,"fault":fault}
		if raw.route != null:
			args.expected_record = _blob(raw,"record",raw.route.digest); args.expected_capsule = _blob(raw,"capsule",raw.route.capsule_digest)
		return _dispatch("publish",args)
	if phase == "match":
		var loaded: Dictionary = route.load_current()
		if kind in ["load","repair"]: return _complete(loaded.merged({"readback_verified":true}))
		if kind == "live":
			var authority := _authority()
			if not authority.success: return _complete(authority)
		var result := {"success":true,"state":"verified_committed","format":6,"generation":loaded.record.current.generation,"latest_generation":loaded.record.current.generation,"transaction_id":request.proposal.transaction_id if kind == "live" else loaded.record.operations.back().id,"request_digest":V6.digest(request.proposal) if kind == "live" else loaded.record.operations.back().request_digest,"candidate_digest":loaded.text.sha256_text(),"route_digest":loaded.route_digest,"head":loaded.head,"already_applied":publication.get("already_applied",false) or not publication.get("success",false),"metrics":measures.merged({"total_ms":float(Time.get_ticks_usec()-started)/1000.0,"transport":publication}),"durable_power_loss_guaranteed":false}
		return _complete(result)
	return _complete(Route.fail("unknown_compact_phase"))

func _request_binding() -> Dictionary:
	return {"proposal":request.get("proposal"),"candidate_text":request.get("candidate_text"),"logical_parent":request.get("logical_parent"),"adapter_digest":request.get("adapter_digest"),"profile":request.get("profile"),"namespace":request.get("namespace")}

func _authority() -> Dictionary:
	var current: Dictionary = adapter.publication_request(candidate)
	if not current.get("success",false): return current
	request = current
	if V6.digest(_request_binding()) != _request_seal or request.source != route.source or request.profile != route.profile or request.namespace != route.scope: return Route.fail("compact_request_or_identity_changed")
	return Coordinator._authorize(request.proposal,request.source,request.profile,request.rules,request.verifier)

func _prepare() -> Dictionary:
	var t := Time.get_ticks_usec()
	var history: Array = []
	var legacy: Dictionary = {"count":raw.legacy_count,"digest":V6.digest([])} if before.get("empty",false) else before.route.legacy
	if not before.get("empty",false) and before.exact_recovery_needed: return Route.fail("compact_recovery_required")
	if kind == "live":
		var authority := _authority()
		if not authority.success: return authority
		text = request.candidate_text
		var d := V6.decode(text,route.source)
		if not d.success: return d
		if V6._projection(d.record) != Contract.decode(request.proposal.document).payload: return Route.fail("compact_projection_mismatch")
		if not before.get("empty",false) and before.text == text:
			capsule = before.capsule_text; target = before.route
			return {"success":true}
		if before.get("empty",false):
			if expected != null or raw.legacy_head != null or not raw.legacy_rows.is_empty() or not raw.legacy_receipts.is_empty() or request.logical_parent.format != 0 or d.record.head.sequence != 1: return Route.fail("compact_initial_boundary_invalid")
		else:
			if Route.token(before) != expected or request.logical_parent != {"format":6,"epoch":before.record.head.epoch,"sequence":before.record.head.sequence,"digest":V6.digest(before.record)}: return Route.fail("stale_compact_storage_head")
			var previous := V6._projection(before.record)
			if request.proposal.expected_generation != previous.generation or request.proposal.expected_checkpoints != previous.secured_checkpoints: return Route.fail("compact_checkpoint_comparison_failed")
			for proof: Dictionary in [Coordinator._validate_continuity(previous,request.proposal.payload),Coordinator._validate_new_items(previous,request.proposal.payload)]:
				if not proof.success: return proof
			var step := Portable.transition(before.record,d.record,route.source)
			if not step.success: return step
			history = before.history.duplicate(true); history.append(step.transition)
	elif kind == "activation":
		if not before.get("empty",false) or raw.legacy_head == null: return Route.fail("verified_legacy_source_required")
		var transport := raw.duplicate(true); transport.generations = raw.legacy_rows; transport.missing = false
		var inspection := Browser.inspection(transport,route.profile)
		if not inspection.success: return inspection
		if raw.legacy_receipts.size() != raw.legacy_rows.size() or raw.legacy_rows.back() != raw.legacy_head: return Route.fail("legacy_head_or_receipt_mismatch")
		var records := CharacterSaveStorage.history_records(inspection)
		for i in range(raw.legacy_rows.size()):
			var row: Dictionary = raw.legacy_rows[i]
			var matches: Array = raw.legacy_receipts.filter(func(r): return r.transaction_id == row.transaction_id)
			if matches.size() != 1 or matches[0].document != row.document or matches[0].generation != i+1 or matches[0].expected_generation != i: return Route.fail("legacy_receipt_mismatch")
		var converted: Dictionary = load("res://scripts/rewards/legacy_to_compact_v6_prototype.gd").convert(records,route.scope)
		if not converted.success: return converted
		if converted.record.source_digest != V6.digest(route.source.to_dictionary()) or converted.record.current.character_id != route.profile: return Route.fail("conversion_source_mismatch")
		text = converted.text; legacy = {"count":records.size(),"digest":V6.digest(records)}
		var quote := {"kind":"explicit_compact_browser_activation","profile":route.profile,"namespace":route.scope,"source_digest":converted.record.source_digest,"legacy":legacy,"candidate_digest":text.sha256_text()}
		var consent: Variant = confirmation.call(quote.duplicate(true))
		if not consent is Dictionary or consent.get("confirmed") != true or consent.get("binding") != V6.digest(quote): return Route.fail("activation_not_confirmed")
	elif kind == "restore":
		var pack := Portable.decode(incoming,route.source)
		if not pack.success: return pack
		if pack.preview.profile != route.profile or pack.preview.namespace != route.scope or (before.get("empty",false) and raw.legacy_head != null): return Route.fail("restore_identity_or_legacy_conflict")
		if Route.token(before) != expected: return Route.fail("stale_restore_head")
		var relationship := Portable.relationship(pack,{} if before.get("empty",false) else before.record,"" if before.get("empty",false) else before.text.sha256_text(),route.source)
		if not relationship.success: return relationship
		var binding := Portable.confirmation(incoming.sha256_text(),expected,route.profile,route.scope)
		var consent: Variant = confirmation.call({"binding":binding,"preview":pack.preview})
		if not consent is Dictionary or consent.get("confirmed") != true or consent.get("binding") != binding: return Route.fail("restore_not_confirmed")
		text = pack.text; history = pack.history
	var packed := Portable.export_record(text,history,route.source)
	if not packed.success: return packed
	capsule = packed.text
	var record: Dictionary = packed.record if packed.has("record") else V6.decode(text,route.source).record
	var previous: Variant = null
	var checked := Portable.decode(capsule,route.source)
	if not checked.previous.is_empty(): previous = V6.encode(checked.previous,route.source).text.sha256_text()
	target = {"version":1,"active_format":6,"minimum_reader":2,"profile":route.profile,"namespace":route.scope,"source_digest":record.source_digest,"rules_revision":record.current.rules_revision,"epoch":record.head.epoch,"sequence":record.head.sequence,"logical_digest":V6.digest(record),"digest":text.sha256_text(),"previous":previous,"capsule_digest":capsule.sha256_text(),"operation_id":record.operations.back().id,"request_digest":record.operations.back().request_digest,"legacy":legacy}
	measures.prepare_ms = float(Time.get_ticks_usec()-t)/1000.0
	return {"success":true}

func _blob(snapshot: Dictionary, blob_kind: String, digest: String) -> Variant:
	for row: Dictionary in snapshot.blobs:
		if row.kind == blob_kind and row.digest == digest: return row
	return null

func _match_arguments() -> Dictionary:
	return {"route":raw.route,"blobs":raw.blobs,"legacy_head":raw.legacy_head,"legacy_rows":raw.legacy_rows,"legacy_receipts":raw.legacy_receipts}

func _complete(value: Dictionary) -> Dictionary:
	phase = ""; job = ""; status = value.duplicate(true)
	return status
