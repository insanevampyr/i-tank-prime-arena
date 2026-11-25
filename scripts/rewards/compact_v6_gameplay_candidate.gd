extends RefCounted

# DORMANT S2 observer. No production caller, storage access or publication.
# The trusted host supplies the actual playable service, not an imported flag.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Strip = preload("res://scripts/rewards/legacy_to_compact_v6_prototype.gd")
const FixedCredit = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
var _service: WeakRef
var _session: WeakRef
var _simulation: WeakRef
var _source_digest := ""
var _identity := {}
var _parent := {}
var _facts: Array = []
var _cursor := 0
var _start := 0
var _pending: Prepared
var _canceled := false
var _failure := ""
var _credit_proposal := {}
var _credit_quote := {}
var _credit_approval := ""
var _credit_runtime_pin := ""
var _credit_reader: Callable
var _checked: RefCounted

func attach_checked(context: RefCounted) -> Dictionary:
	if _pending!=null or _checked!=null or context.get_script()!=load("res://scripts/rewards/compact_v6_checked_operation.gd"): return _fail("invalid_checked_context")
	var result: Dictionary=context.attach(self)
	if result.success: _checked=context
	return result

class Prepared extends RefCounted:
	# Strings are owned values; assignment after initialization is ignored.
	# Copies returned to callers cannot mutate the sealed operation.
	var _bytes := "":
		set(value):
			if _bytes.is_empty(): _bytes = value
	var _digest := "":
		set(value):
			if _digest.is_empty(): _digest = value
	func _init(body: Dictionary) -> void:
		_bytes = JSON.stringify(body,"",true,true)
		_digest = _bytes.sha256_text()
	func copy() -> Dictionary:
		return CharacterSaveContract._normalize_json_numbers(JSON.parse_string(_bytes))
	func bytes() -> String: return _bytes
	func digest() -> String: return _digest

func _init(service: PlayableCharacterPersistence, parent: Dictionary = {}) -> void:
	if service == null:
		_failure = "trusted_playable_context_required"
		return
	_service = weakref(service)
	_identity = {"profile_id":service.profile_id,"namespace":service.mode,"run_id":service.run_id}
	_source_digest = V6.digest(service.source.to_dictionary()) if service.source != null else ""
	_parent = parent.duplicate(true)
	if parent.is_empty():
		if service.generation != 0: _failure = "existing_profile_requires_verified_compact_parent"
	else:
		var checked := V6.validate(parent,service.source)
		if not checked.success: _failure = "invalid_compact_parent"
		elif V6._projection(parent) != CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).get("text","")).get("payload",{}): _failure = "parent_projection_mismatch"

func head() -> Dictionary:
	if _parent.is_empty(): return {"format":0,"epoch":null,"sequence":0,"digest":null}
	return {"format":6,"epoch":_parent.head.epoch,"sequence":_parent.head.sequence,"digest":V6.digest(_parent)}

# Called explicitly by an isolated host at the existing ingest boundary.
# This reads the resolved order; stable_sequence/IDs are never sorted.
func observe(session: ArenaCombatSession) -> Dictionary:
	var valid := _context(session)
	if not valid.success: return valid
	var batch := session.simulation.get_resolved_events_from(_cursor)
	if not batch.success: return _fail("unsupported_event_cursor")
	for event: CombatEvent in batch.events: _facts.append(event.to_dictionary())
	_cursor = batch.next_cursor
	return {"success":true}

func cancel() -> Dictionary:
	if _checked!=null: _checked.cancel()
	_canceled = true
	_pending = null
	_facts = []
	_credit_proposal = {}; _credit_quote = {}; _credit_approval = ""
	_credit_runtime_pin = ""
	_credit_reader = Callable()
	return _fail("candidate_canceled")

func prepare(expected_head: Dictionary) -> Dictionary:
	var prepare_started := Time.get_ticks_usec()
	var memory_before := OS.get_static_memory_usage()
	var session: ArenaCombatSession = _session.get_ref() if _session != null else null
	var context := _context(session)
	if not context.success: return context
	if expected_head != head(): return _fail("stale_compact_head")
	var service: PlayableCharacterPersistence = _service.get_ref()
	var proposal: Dictionary = service._prepared
	if proposal.is_empty(): return _fail("authorized_checkpoint_required")
	if _pending != null:
		var existing := check(_pending,expected_head)
		return {"success":true,"prepared":_pending,"exact_retry":true} if existing.success else existing
	var start := Time.get_ticks_usec()
	var authorized := Coordinator._authorize(proposal,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify)
	if not authorized.success: return _fail("checkpoint_authority_rejected",authorized)
	var authorization_ms := float(Time.get_ticks_usec()-start)/1000.0
	var facts_started := Time.get_ticks_usec()
	# Use the existing contract's decoded numeric representation (for example
	# movement direction 0.0 -> 0), exactly as a cold legacy read does.
	var original: Dictionary = CharacterSaveContract.decode(proposal.document).payload
	var before: Dictionary = V6._projection(_parent) if not _parent.is_empty() else {}
	if proposal.expected_generation != int(before.get("generation",0)) or original.generation != proposal.expected_generation+1: return _fail("unsupported_checkpoint_generation_gap")
	if original.profile_namespace != service.mode or original.character_id != service.profile_id or original.recovery.run_id != service.run_id: return _fail("profile_or_run_mismatch")
	if original.get("expc_credits") != before.get("expc_credits"): return _fail("unsupported_post_conversion_credit")
	var observed := _unchanged_events(session)
	if not observed.success: return observed
	var order := _ordered_delta(original,before,service)
	if not order.success: return order
	var causal_ms := float(Time.get_ticks_usec()-facts_started)/1000.0
	var assembly_started := Time.get_ticks_usec()
	var evidence := {"awards":original.permanent.award_receipts,"purchases":original.purchases,"growth":original.permanent.growth,"settlements":original.settlements,"credit":original.get("expc_credits"),"credit_predecessor":V6.materialize_credit_predecessor(_parent) if not _parent.is_empty() else null,"order":_parent.get("evidence",{}).get("order",[]).duplicate(true)}
	evidence.order.append_array(order.entries)
	var binding := _binding_for(original,service)
	var operations: Array = _parent.get("operations",[]).duplicate(true)
	operations.append({"id":proposal.transaction_id,"request_digest":V6.digest(binding)})
	var next_head: Dictionary = {"epoch":"native_"+V6.digest([binding.identity,_source_digest,original.lineage,original.run_history,proposal.transaction_id]),"sequence":1,"parent_digest":null} if _parent.is_empty() else _parent.head.duplicate(true)
	if not _parent.is_empty():
		next_head.sequence += 1
		next_head.parent_digest = V6.digest(_parent)
	var record := V6.assemble(Strip.Conversion.strip(original),evidence,operations,next_head,service.source,int(_parent.get("compact_version",1)))
	var construction_ms := float(Time.get_ticks_usec()-start)/1000.0
	var assembly_ms := float(Time.get_ticks_usec()-assembly_started)/1000.0
	start = Time.get_ticks_usec()
	var encoded: Dictionary = _checked.encode_candidate(self,record) if _checked!=null else V6.encode(record,service.source)
	if not encoded.success: return _fail("candidate_validation_rejected",encoded)
	var full_encode_ms := float(Time.get_ticks_usec()-start)/1000.0
	var extension_started := Time.get_ticks_usec()
	if not _parent.is_empty() and _checked==null:
		var extension := V6.validate_extension(_parent,record,service.source)
		if not extension.success: return _fail("candidate_extension_rejected",extension)
	var validation_ms := float(Time.get_ticks_usec()-start)/1000.0
	var extension_ms := float(Time.get_ticks_usec()-extension_started)/1000.0
	if V6._projection(record) != original: return _fail("projection_equivalence_failed")
	start = Time.get_ticks_usec()
	_pending = Prepared.new({"binding":binding,"candidate_text":encoded.text,"candidate_digest":encoded.text.sha256_text()})
	if _checked!=null:
		var bound: Dictionary=_checked.bind(self,_pending)
		if not bound.success: return bound
	return {"success":true,"prepared":_pending,"metrics":{"authorization_ms":authorization_ms,"causal_ms":causal_ms,"assembly_ms":assembly_ms,"full_encode_ms":full_encode_ms,"extension_ms":extension_ms,"construction_ms":construction_ms,"validation_encode_ms":validation_ms,"seal_ms":float(Time.get_ticks_usec()-start)/1000.0,"total_prepare_ms":float(Time.get_ticks_usec()-prepare_started)/1000.0,"bytes":encoded.text.to_utf8_buffer().size(),"sealed_bytes":_pending.bytes().to_utf8_buffer().size(),"facts":_facts.size(),"lifetime_ids":record.applied_ids.size(),"operations":operations.size(),"awards":evidence.awards.size(),"purchases":evidence.purchases.size(),"growth":evidence.growth.size(),"items":original.items.size(),"native_live_delta":OS.get_static_memory_usage()-memory_before,"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}}

func _binding_for(original: Dictionary, service: PlayableCharacterPersistence) -> Dictionary:
	var proposal: Dictionary=service._prepared
	var session: ArenaCombatSession=_session.get_ref()
	return {
		"version":1,
		"identity":{"profile_id":service.profile_id,"namespace":service.mode},
		"rules":original.rules_revision,"source_digest":_source_digest,
		"expected_head":head(),"operation_id":proposal.transaction_id,
		"request_id":proposal.transaction_id,"legacy_prepared_digest":V6.digest(proposal),
		"events_json":JSON.stringify(_facts,"",true,true),
		"event_start":_start,"event_end":_cursor,
		"projection_digest":V6.digest(original),"run_policy":service.get_run_reward_policy(),
		"runtime_digest":V6.digest(session.get_state_snapshot()),
	}

# Recheck the privately owned handle against current authority, never a flag.
func check(prepared: Prepared, expected_head: Dictionary) -> Dictionary:
	var session: ArenaCombatSession = _session.get_ref() if _session != null else null
	var valid := _context(session)
	if not valid.success: return valid
	if prepared == null or prepared != _pending or prepared.bytes().sha256_text() != prepared.digest(): return _fail("foreign_or_changed_prepared_operation")
	var body := prepared.copy()
	if body.candidate_text.sha256_text() != body.candidate_digest: return _fail("candidate_bytes_changed")
	if body.binding.get("kind") == FixedCredit.FORMAT: return _check_credit(prepared,expected_head)
	if body.binding.event_start != _start or body.binding.event_end != _cursor or body.binding.events_json != JSON.stringify(_facts,"",true,true): return _fail("captured_operation_changed")
	var service: PlayableCharacterPersistence = _service.get_ref()
	if expected_head != head() or body.binding.expected_head != expected_head: return _fail("stale_compact_head")
	if body.binding.run_policy != service.get_run_reward_policy(): return _fail("run_policy_changed")
	if V6.digest(service._prepared) != body.binding.legacy_prepared_digest: return _fail("checkpoint_request_changed")
	if V6.digest(session.get_state_snapshot()) != body.binding.runtime_digest: return _fail("runtime_changed_after_preparation")
	var events := _unchanged_events(session)
	if not events.success: return events
	var authorized := Coordinator._authorize(service._prepared,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify)
	if not authorized.success: return _fail("checkpoint_authority_rejected",authorized)
	if _checked!=null: return _checked.matches(self,prepared)
	var decoded := V6.decode(body.candidate_text,service.source)
	if not decoded.success: return decoded
	if decoded.record.operations.back() != {"id":body.binding.operation_id,"request_digest":V6.digest(body.binding)}: return _fail("operation_binding_changed")
	if V6._projection(decoded.record) != CharacterSaveContract.decode(service._prepared.document).payload: return _fail("projection_equivalence_failed")
	return V6.validate_extension(_parent,decoded.record,service.source) if not _parent.is_empty() else {"success":true}

# Advances only this observer after the existing service's coordinator ack.
# S4 additionally verifies native readback through adopt_compact(); this method
# itself never publishes or acknowledges storage.
func adopt(prepared: Prepared) -> Dictionary:
	var checked := check(prepared,head())
	if not checked.success: return checked
	var service: PlayableCharacterPersistence = _service.get_ref()
	var proposal: Dictionary = _credit_proposal if not _credit_proposal.is_empty() else service._prepared
	if not service._last_ack or service._prepared != proposal or service._prior != proposal.payload or service.generation != proposal.payload.generation: return _fail("verified_legacy_acknowledgement_required")
	return _adopt_current(prepared,service)

func _adopt_current(prepared: Prepared, service: PlayableCharacterPersistence) -> Dictionary:
	if _checked!=null:
		var adopted: Dictionary=_checked.adopt_record(self,prepared)
		if not adopted.success: return adopted
		_parent=adopted.record
	else: _parent = V6.decode(prepared.copy().candidate_text,service.source).record
	_pending = null
	_facts = []
	_start = _cursor
	_credit_proposal = {}; _credit_quote = {}; _credit_approval = ""
	_credit_runtime_pin = ""
	_credit_reader = Callable()
	return {"success":true}

# Dormant fixed maintenance proposal. Confirmation is a trusted host callback,
# never an imported flag. This method changes no service, actor or storage.
func prepare_credit(session: ArenaCombatSession, expected_head: Dictionary, confirmation: Callable = Callable(), readback: Callable = Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var context := _context(session)
	if not context.success: return context
	if expected_head != head() or _parent.is_empty(): return _fail("stale_compact_head")
	if _parent.evidence.credit != null: return {"success":true,"no_op":true,"reason":"credit_already_applied"}
	if _pending != null:
		if _credit_proposal.is_empty(): return _fail("candidate_operation_in_flight")
		var existing := check(_pending,expected_head)
		return {"success":true,"prepared":_pending,"exact_retry":true,"already_applied":existing.get("already_applied",false)} if existing.success else existing
	var service: PlayableCharacterPersistence = _service.get_ref()
	var eligible := session.get_character_advancement_eligibility()
	if not eligible.success: return eligible
	var prior: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).get("text","")).get("payload",{})
	if prior != V6._projection(_parent) or service.generation != prior.get("generation"): return _fail("credit_parent_service_mismatch")
	var owned: Dictionary = service._verify("hydrate",Profiles.fingerprint(service._prior))
	if not owned.get("authorized",false): return _fail("credit_parent_authority_unavailable")
	var state := session.get_actor_state(&"player")
	if state.current_hpc != prior.recovery.player.current_hpc or state.resources != prior.recovery.player.resources: return _fail("credit_requires_acknowledged_resources")
	if not session.player_movement_boundary_provider.is_valid(): return _fail("credit_movement_boundary_unavailable")
	var movement: Variant = CharacterSaveContract._normalize_json_numbers(session.player_movement_boundary_provider.call())
	if movement != prior.recovery.movement: return _fail("credit_requires_acknowledged_movement")
	_credit_reader = readback
	var storage := _credit_storage("")
	if not storage.success: return storage
	var offered := FixedCredit.quote(_parent,service.source,storage.get("head"),load("res://scripts/rewards/compact_character_v6_prototype.gd"))
	if not offered.success or offered.get("no_op",false): return offered
	var runtime := _credit_runtime(session)
	if not confirmation.is_valid(): return _fail("expc_credit_confirmation_required",{"quote":offered.quote})
	var approval: Variant = confirmation.call(offered.quote.duplicate(true))
	if not approval is Dictionary or not approval.get("confirmed",false) or approval.get("binding") != V6.digest(offered.quote): return _fail("expc_credit_confirmation_required")
	if not _context(session).success or _credit_runtime(session) != runtime: return _fail("credit_context_changed_during_confirmation")
	var fresh := _credit_storage("")
	if not fresh.success or fresh.get("head") != offered.quote.storage: return _fail("stale_credit_storage_head")
	var built := FixedCredit.build(_parent,service.source,offered.quote,runtime,load("res://scripts/rewards/compact_character_v6_prototype.gd"))
	if not built.success: return built
	_credit_proposal = built.prepared
	_credit_quote = offered.quote.duplicate(true)
	_credit_approval = V6.digest(offered.quote)
	_credit_runtime_pin = runtime
	var authorized := Coordinator._authorize(_credit_proposal,service.source,service.profile_id,PlayableCharacterAdmission.RULES,credit_authority)
	if not authorized.success: return _fail("credit_coordinator_authority_rejected",authorized)
	_pending = Prepared.new({"binding":built.binding,"candidate_text":built.text,"candidate_digest":built.text.sha256_text()})
	if _checked!=null:
		var bound: Dictionary=_checked.bind(self,_pending,true)
		if not bound.success: return bound
	return {"success":true,"prepared":_pending,"quote":_credit_quote.duplicate(true),"metrics":{"prepare_ms":float(Time.get_ticks_usec()-started)/1000.0,"record_bytes":built.text.to_utf8_buffer().size(),"proof_bytes":JSON.stringify(built.record.evidence.credit_predecessor,"",true,true).to_utf8_buffer().size(),"native_static":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}}

# Operation-local permit for the ORIGINAL coordinator. Not a second writer.
func credit_authority(operation: String, binding: String) -> Dictionary:
	var denied := {"authorized":false,"binding":binding}
	var session: ArenaCombatSession = _session.get_ref() if _session != null else null
	if not _context(session).success or _credit_proposal.is_empty() or _credit_approval.is_empty() or _credit_approval != V6.digest(_credit_quote): return denied
	if _credit_runtime(session) != _credit_runtime_pin: return denied
	var stored := _credit_storage(_pending.copy().candidate_text if _pending != null else "")
	if not stored.success: return denied
	var service: PlayableCharacterPersistence = _service.get_ref()
	var parent := V6.validate(_parent,service.source)
	if not parent.success or _credit_quote.parent != FixedCredit.token(_parent,load("res://scripts/rewards/compact_character_v6_prototype.gd")): return denied
	var expected := FixedCredit.proposal(_parent,service.source,load("res://scripts/rewards/compact_character_v6_prototype.gd"))
	if not expected.success or expected.prepared != _credit_proposal or _credit_runtime(session) != _credit_runtime_pin: return denied
	var payload := V6._projection(_parent)
	var current: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(service._prior).get("text","")).get("payload",{})
	if current != payload and (not service._last_ack or current != _credit_proposal.payload or service._prepared != _credit_proposal): return denied
	var permitted: bool = (operation == "commit" and binding == Profiles.fingerprint(_credit_proposal)) or (operation == "hydrate" and binding == Profiles.fingerprint(_credit_proposal.payload))
	var proof := {"success":true,"source_digest":_parent.source_digest,"head_digest":V6.digest(payload),"generation":payload.generation,"end":parent.actor.attributes.end,"growth":parent.end_growth}
	return {"authorized":permitted,"binding":binding,"lineage":payload.lineage,"previous_payload":payload,"endurance_history":proof}

func _credit_storage(candidate_text: String) -> Dictionary:
	if not _credit_reader.is_valid(): return {"success":true,"head":null}
	var actual: Variant = _credit_reader.call()
	if not actual is Dictionary or not actual.get("success",false) or not actual.get("text") is String or not actual.get("head") is Dictionary: return _fail("credit_storage_readback_unavailable")
	var service: PlayableCharacterPersistence = _service.get_ref()
	var decoded := V6.decode(actual.text,service.source)
	if not decoded.success or actual.head.get("digest") != actual.text.sha256_text(): return _fail("credit_storage_readback_invalid")
	var storage_check := FixedCredit.quote(_parent,service.source,actual.head,load("res://scripts/rewards/compact_character_v6_prototype.gd")) if decoded.record == _parent else {}
	if decoded.record == _parent and storage_check.get("success",false): return {"success":true,"head":actual.head}
	if not candidate_text.is_empty() and actual.text == candidate_text:
		if _credit_quote.get("storage") is Dictionary and actual.head.get("previous") != _credit_quote.storage.digest: return _fail("credit_storage_parent_mismatch")
		if actual.head.get("profile") == service.profile_id and actual.head.get("namespace") == service.mode and actual.head.get("epoch") == decoded.record.head.epoch and actual.head.get("sequence") == decoded.record.head.sequence: return {"success":true,"already_applied":true,"head":actual.head}
	return _fail("stale_credit_storage_head")

func _check_credit(prepared: Prepared, expected_head: Dictionary) -> Dictionary:
	if expected_head != head(): return _fail("stale_compact_head")
	var body := prepared.copy()
	if _credit_proposal.is_empty() or body.binding.quote != _credit_quote or _credit_approval != V6.digest(_credit_quote): return _fail("credit_confirmation_binding_changed")
	if V6.digest(_credit_proposal) != body.binding.legacy_prepared_digest: return _fail("credit_request_changed")
	var session: ArenaCombatSession = _session.get_ref()
	if _credit_runtime(session) != body.binding.runtime_digest: return _fail("credit_runtime_changed")
	var storage := _credit_storage(body.candidate_text)
	if not storage.success: return storage
	var service: PlayableCharacterPersistence = _service.get_ref()
	var authorized := Coordinator._authorize(_credit_proposal,service.source,service.profile_id,PlayableCharacterAdmission.RULES,credit_authority)
	if not authorized.success: return _fail("credit_coordinator_authority_rejected",authorized)
	if _checked!=null: return _checked.matches(self,prepared).merged({"already_applied":storage.get("already_applied",false)})
	var decoded := V6.decode(body.candidate_text,service.source)
	if not decoded.success: return decoded
	var valid := V6.validate_extension(_parent,decoded.record,service.source)
	if not valid.success: return valid
	return {"success":true,"already_applied":storage.get("already_applied",false)}

func _credit_runtime(session: ArenaCombatSession) -> String:
	return V6.digest({"simulation":session.get_state_snapshot(),"movement":session.player_movement_boundary_provider.call() if session.player_movement_boundary_provider.is_valid() else null})

func current_copy() -> Dictionary: return _parent.duplicate(true)

# Dormant S4 handoff to the EXISTING coordinator. A private pending handle and
# current trusted authority are required; raw imported V6 bytes cannot use it.
func publication_request(prepared: Prepared) -> Dictionary:
	var checked := check(prepared,head())
	if not checked.success: return checked
	var service: PlayableCharacterPersistence = _service.get_ref()
	return {"success":true,"source":service.source,"profile":service.profile_id,"namespace":service.mode,"rules":PlayableCharacterAdmission.RULES,"proposal":(_credit_proposal if not _credit_proposal.is_empty() else service._prepared).duplicate(true),"verifier":credit_authority if not _credit_proposal.is_empty() else service._verify,"logical_parent":head(),"candidate_text":prepared.copy().candidate_text,"adapter_digest":prepared.digest()}

func adopt_compact(prepared: Prepared, acknowledgement: Dictionary, route: RefCounted) -> Dictionary:
	var request := publication_request(prepared)
	if not request.success: return request
	var body := prepared.copy()
	var loaded: Dictionary = route.load_current()
	if not loaded.get("success",false) or loaded.get("exact_recovery_needed",true) or loaded.get("text") != body.candidate_text: return _fail("compact_readback_required")
	if acknowledgement.get("format") != 6 or acknowledgement.get("candidate_digest") != body.candidate_digest or acknowledgement.get("route_digest") != loaded.route_digest or acknowledgement.get("request_digest") != V6.digest(request.proposal) or acknowledgement.get("transaction_id") != request.proposal.transaction_id: return _fail("compact_acknowledgement_mismatch")
	var service: PlayableCharacterPersistence = _service.get_ref()
	if not service._last_ack or service._prepared != request.proposal or service.generation != request.proposal.payload.generation or service._prior != V6._projection(loaded.record): return _fail("verified_compact_acknowledgement_required")
	return _adopt_current(prepared,service)

func _context(session: ArenaCombatSession) -> Dictionary:
	if _canceled: return _fail("candidate_canceled")
	if not _failure.is_empty(): return _fail(_failure)
	var service: PlayableCharacterPersistence = _service.get_ref()
	if service == null or session == null or session._playable_persistence != service: return _fail("trusted_playable_context_required")
	if _identity != {"profile_id":service.profile_id,"namespace":service.mode,"run_id":service.run_id}: return _fail("profile_context_changed")
	if service.source == null or V6.digest(service.source.to_dictionary()) != _source_digest: return _fail("trusted_source_changed")
	if _session == null:
		_session = weakref(session)
		_simulation = weakref(session.simulation)
	elif _session.get_ref() != session or _simulation.get_ref() != session.simulation: return _fail("runtime_context_changed")
	return {"success":true}

func _unchanged_events(session: ArenaCombatSession) -> Dictionary:
	var batch := session.simulation.get_resolved_events_from(_start)
	if not batch.success or batch.next_cursor != _cursor: return _fail("unobserved_or_changed_events")
	var actual: Array = []
	for event: CombatEvent in batch.events: actual.append(event.to_dictionary())
	if actual != _facts: return _fail("unobserved_or_changed_events")
	return {"success":true}

func _ordered_delta(payload: Dictionary, before: Dictionary, service: PlayableCharacterPersistence) -> Dictionary:
	var wanted := {}
	for group: Array in [["award",payload.permanent.award_receipts,before.get("permanent",{}).get("award_receipts",[]),"award_id"],["purchase",payload.purchases,before.get("purchases",[]),"purchase_id"],["growth",payload.permanent.growth,before.get("permanent",{}).get("growth",[]),"growth_id"]]:
		if group[1].slice(0,group[2].size()) != group[2]: return _fail("historical_evidence_changed")
		for row: Dictionary in group[1].slice(group[2].size()): wanted[JSON.stringify([group[0],row[group[3]]])] = row
	var entries: Array = []
	var seen := {}
	var events_by_id := {}
	var positions := {}
	var live_events := {}
	var session: ArenaCombatSession = _session.get_ref()
	for event: CombatEvent in session.simulation.get_resolved_events_from(_start).events: live_events[event.event_id] = event
	for event: Dictionary in _facts:
		if events_by_id.has(event.event_id): return _fail("duplicate_resolved_event")
		positions[event.event_id] = events_by_id.size()
		events_by_id[event.event_id] = event
	for event: Dictionary in _facts:
		var kind := ""
		var id := ""
		match event.event_type:
			"reward_xp_awarded":
				if event.target_actor_id != "player": continue
				kind = "award"
				id = service._awards.get(event.event_id,{}).get("award_id","")
			"reward_advancement_purchased":
				if event.source_actor_id != "player": continue
				kind = "purchase"
				id = service._purchases.get(event.payload.get("request_id",""),"")
			"reward_character_level_gained":
				if event.source_actor_id != "player": continue
				kind = "growth"
				id = service._growth.get("%s:%s" % [event.payload.get("award_id",""),event.payload.get("level",0)],"")
			_: continue
		var key := JSON.stringify([kind,id])
		if not wanted.has(key): continue
		if seen.has(key): return _fail("duplicate_causal_fact")
		var row: Dictionary = wanted[key]
		if kind == "award":
			if event.payload.get("xp") != row.xp or event.parent_event_id.is_empty() or not events_by_id.has(event.parent_event_id) or event.payload.get("defeat_event_id") != event.parent_event_id: return _fail("unsupported_award_causality")
			if positions[event.parent_event_id] >= positions[event.event_id] or not session._is_reward_eligible_defeat(live_events[event.parent_event_id],PackedStringArray([event.payload.get("actor_id","")])): return _fail("unsupported_award_causality")
		elif kind == "purchase":
			for field: String in Profiles.purchase_fields(row):
				if event.payload.get(field) != row.get(field): return _fail("purchase_fact_mismatch")
		else:
			if event.parent_event_id != event.payload.get("award_id") or not events_by_id.has(event.parent_event_id) or events_by_id[event.parent_event_id].event_type != "reward_xp_awarded": return _fail("unsupported_growth_causality")
			if positions[event.parent_event_id] >= positions[event.event_id]: return _fail("unsupported_growth_causality")
			for field: String in Profiles.HISTORY_FIELDS:
				if event.payload.get(field) != row.get(field): return _fail("growth_fact_mismatch")
		seen[key] = true
		entries.append({"kind":kind,"id":id})
	if seen.size() != wanted.size(): return _fail("unsupported_missing_ordered_causal_fact")
	return {"success":true,"entries":entries}

func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"success":false,"reason":reason,"details":details}
