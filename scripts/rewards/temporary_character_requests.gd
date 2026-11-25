extends RefCounted

# Dormant, in-process request ownership only. No wallet, writer or save format.
const Codec = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const Gate = preload("res://scripts/rewards/character_capture_gate.gd")

class Context extends RefCounted:
	var _owner: WeakRef
	var _state := "open"
	var _tickets: Dictionary = {}
	var _results: Dictionary = {}
	var _json := "":
		set(value):
			if _json.is_empty(): _json = value
	func _init(owner: RefCounted, text: String) -> void: _owner = weakref(owner); _json = text
	func json() -> String: return _json
	func retire() -> void:
		_state = "retired"
		# Only this new volatile request/reply memo is released. Original source
		# accepted-ID maps and all saved lifetime evidence remain untouched.
		_tickets.clear(); _results.clear()

class Request extends RefCounted:
	var _context: WeakRef
	var _completion_used := false
	var _json := "":
		set(value):
			if _json.is_empty(): _json = value
	func _init(context: RefCounted, text: String) -> void: _context = weakref(context); _json = text
	func json() -> String: return _json
	func copy() -> Dictionary: return Codec.Contract._normalize_json_numbers(JSON.parse_string(_json))

var _session: WeakRef
var _service: WeakRef
var _gate: RefCounted
var _identity: Dictionary
var _context: RefCounted
var _window := 0
var _head := 0
var _pending: Dictionary = {}
var _dispatch: RefCounted
var _closed := false
var _invalid := false
var _source_calls := 0
var _aggregate: WeakRef

# 46H: same issued handles, owned by the existing disposable aggregate. The
# actual owner/current record/gate are checked; no caller verification flag.
func admit_aggregate(owner: RefCounted) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or owner == null or not is_instance_of(owner,load("res://scripts/rewards/minimal_character_transactions.gd")) or not owner._v3 or owner._requests != self or owner._current == null: return fail("temporary_aggregate_owner_required")
	var session: ArenaCombatSession = owner._session
	var service: PlayableCharacterPersistence = owner._service
	var allowed := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_").replace("\\","/")
	if session == null or service == null or service.storage == null or not service.storage._root.replace("\\","/").simplify_path().begins_with(allowed) or session._playable_persistence != service or service._minimal_transactions == null or service._minimal_transactions.get_ref() != owner: return fail("temporary_aggregate_binding_mismatch")
	if owner._gate == null or not owner._gate._attached() or owner._gate._item_context_required: return fail("temporary_gate_binding_mismatch")
	var b: Dictionary = owner._current.copy()
	_session = weakref(session); _service = weakref(service); _gate = owner._gate; _aggregate = weakref(owner)
	_identity = {"profile":service.profile_id,"namespace":service.mode,"epoch":b.epoch,"run":service.run_id,"policy":service.get_run_reward_policy(),"source_digest":b.source_digest,"lineage_digest":Codec.V6.digest(service._lineage),"rules":b.current.rules_revision,"admission":get_instance_id()}
	_new_context()
	return _gate.attach_item_context(self)

func seal_aggregate_capture(owner: RefCounted, capture: RefCounted, operation_id: String) -> Dictionary:
	if not _bound() or _aggregate == null or _aggregate.get_ref() != owner or not _pending.is_empty() or owner._pending.get("capture") != capture or not _aggregate_fresh(capture): return fail("temporary_aggregate_capture_mismatch")
	_context._state = "sealed"
	_pending = {"capture":capture,"text":capture.json(),"window":_context,"parent":_head,"id":operation_id,"uncertain":false}
	_new_context()
	return {"success":true,"durable":false}

func _aggregate_fresh(capture: RefCounted) -> bool:
	if _gate.is_current(capture): return true
	var owner: RefCounted = _aggregate.get_ref() if _aggregate != null else null
	return owner != null and owner._inside_checkpoint and owner._pending.get("capture") == capture and owner._pending.get("gate_revision") == _gate.revision() and _gate.last_capture() == capture and _gate._attached() and not _gate._locked()

func admit(session: ArenaCombatSession, player: Node, text: String) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("temporary_requires_main_thread")
	if session == null or player == null or session._playable_persistence == null: return fail("temporary_original_admission_required")
	var service: PlayableCharacterPersistence = session._playable_persistence
	var allowed := OS.get_cache_dir().path_join("itank-storage-tests/temporary46f_").replace("\\","/")
	if service.storage == null or not service.storage._root.replace("\\","/").simplify_path().begins_with(allowed) or service._minimal_transactions != null: return fail("temporary_disposable_original_service_required")
	var cold := Codec.decode(text,service.source,service.profile_id,service.mode)
	if not cold.success: return cold
	var b: Dictionary = cold.snapshot.copy()
	if cold.snapshot.projection() != Codec.Contract._normalize_json_numbers(JSON.parse_string(JSON.stringify(service._prior,"",true,true))): return fail("temporary_admitted_head_mismatch")
	if not service.mutation_guard().success: return fail("temporary_original_service_pending")
	var original_admission := false
	for event: CombatEvent in session.get_resolved_events():
		if event.event_type == &"reward_character_profile_applied" and event.source_actor_id == &"player":
			original_admission = event.payload.get("profile_id") == service.profile_id and event.payload.get("profile_namespace") == service.mode and event.payload.get("run_id") == service.run_id
	if not original_admission or not session._entry_bootstrap.is_empty(): return fail("temporary_original_admission_incomplete")
	var gate: RefCounted = session._character_capture_gate
	var created := gate == null
	if gate == null:
		gate = Gate.new()
		var bound: Dictionary = gate.bind(session,player)
		if not bound.success: return bound
	elif not gate._attached() or gate._session.get_ref() != session or gate._player.get_ref() != player:
		return fail("temporary_gate_binding_mismatch")
	if gate._item_context_required: return fail("temporary_admission_already_bound")
	var lease: Dictionary = gate.acquire(b.current.recovery.phase)
	if not lease.success:
		if created: gate.unbind()
		return lease
	# The original loader rebuilds volatile ledger event maps on cold resume.
	# Its independently validated saved view above establishes identity; the
	# actual gate establishes a safe live boundary, not an archived-ledger replay.
	lease.lease.cancel()
	_session = weakref(session); _service = weakref(service); _gate = gate
	_identity = {"profile":service.profile_id,"namespace":service.mode,"epoch":b.epoch,"run":service.run_id,"policy":service.get_run_reward_policy(),"source_digest":b.source_digest,"lineage_digest":Codec.V6.digest(service._lineage),"rules":b.current.rules_revision,"admission":get_instance_id()}
	_new_context()
	var attached: Dictionary = gate.attach_item_context(self)
	if not attached.success: return attached
	return {"success":true,"durable":false}

func _bound() -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or _closed or _invalid: return false
	if _session == null or _service == null: return false
	var s: ArenaCombatSession = _session.get_ref(); var service: PlayableCharacterPersistence = _service.get_ref()
	var matches: bool = s != null and service != null and s._playable_persistence == service and _gate._attached() and s.simulation._inventory_instance_resolver == Callable(service,"select_instances") and service.profile_id == _identity.profile and service.mode == _identity.namespace and service.run_id == _identity.run and service._prior.get("character_id") == _identity.profile and service._prior.get("profile_namespace") == _identity.namespace and service._prior.get("rules_revision") == _identity.rules and service.get_run_reward_policy() == _identity.policy and s.get_run_reward_policy() == _identity.policy and Codec.V6.digest(service._lineage) == _identity.lineage_digest and service.source != null and Codec.V6.digest(service.source.to_dictionary()) == _identity.source_digest
	if not matches: _invalid = true
	if matches and _aggregate != null:
		var owner: RefCounted = _aggregate.get_ref()
		matches = owner != null and not owner._closed and owner._requests == self and owner._service == service and owner._session == s and owner._gate == _gate
		if not matches: _invalid = true
	return matches

func _new_context() -> void:
	_window += 1
	_context = Context.new(self,JSON.stringify(_identity.merged({"window":_window}),"",true,true))

func current() -> RefCounted:
	return _context if _bound() else null

func _issued(context: RefCounted) -> bool:
	return context is Context and context._owner.get_ref() == self and (context == _context or (not _pending.is_empty() and context == _pending.window)) and context._state != "retired"

func issue(context: RefCounted, kind: String, definition: String, operation: String, request_id: String) -> Dictionary:
	if not _bound() or not _issued(context): return fail("temporary_context_expired")
	if _dispatch != null or _gate._locked() or _gate._active_mutations != 0: return fail("temporary_runtime_busy")
	if not kind in ["equip","unequip","handling","use"] or definition.is_empty() or request_id.is_empty(): return fail("temporary_request_invalid")
	var intent := {"kind":kind,"definition":definition,"operation":operation,"id":request_id}
	if context._tickets.has(request_id):
		var original: Dictionary = context._tickets[request_id].copy()
		if original.intent != intent: return fail("temporary_request_binding_conflict")
		return {"success":true,"request":context._tickets[request_id],"exact_retry":true,"durable":false}
	if context != _context or context._state != "open": return fail("temporary_context_sealed")
	var ticket := Request.new(context,JSON.stringify({"context":context.json(),"revision":_gate.revision(),"intent":intent},"",true,true))
	context._tickets[request_id] = ticket
	return {"success":true,"request":ticket,"exact_retry":false,"durable":false}

func _ticket_context(ticket: RefCounted) -> RefCounted:
	if not ticket is Request: return null
	var context: RefCounted = ticket._context.get_ref()
	# Reject unissued objects before parsing any caller-created bytes.
	if not _issued(context) or not context._tickets.values().has(ticket): return null
	return context

func execute(ticket: RefCounted) -> Dictionary:
	if not _bound(): return fail("temporary_context_expired")
	var context := _ticket_context(ticket)
	if context == null: return fail("temporary_context_expired")
	var body: Dictionary = ticket.copy(); var id: String = body.intent.id
	if context._results.has(id): return {"success":context._results[id].get("success",false),"result":context._results[id].duplicate(true),"exact_retry":true,"durable":false}
	if context != _context or context._state != "open": return fail("temporary_context_sealed")
	if _aggregate != null:
		var owner: RefCounted = _aggregate.get_ref()
		if owner == null: return fail("temporary_context_expired")
		var permitted: Dictionary = owner.authorize_item_dispatch(self,ticket)
		if not permitted.success: return permitted
	if _dispatch != null: return fail("temporary_request_in_flight")
	if body.revision != _gate.revision(): return fail("temporary_request_revision_stale")
	_dispatch = ticket
	_source_calls += 1
	var s: ArenaCombatSession = _session.get_ref(); var result := {}
	match body.intent.kind:
		"equip": result = s.request_player_inventory_equip(StringName(body.intent.definition),id)
		"unequip": result = s.request_player_inventory_unequip(StringName(body.intent.definition),id)
		"handling": result = s.request_player_weapon_handling(StringName(body.intent.definition),body.intent.operation,id)
		"use": result = s.request_player_inventory_consumable_use(StringName(body.intent.definition),id)
	_dispatch = null
	context._results[id] = result.duplicate(true)
	if _aggregate != null:
		var owner: RefCounted = _aggregate.get_ref()
		if owner != null: owner.after_item_dispatch(self)
	return {"success":result.get("success",false),"result":result.duplicate(true),"exact_retry":false,"durable":false}

func allow_entry(caller: Object, request_id: String) -> bool:
	return _bound() and _dispatch != null and (caller == _session.get_ref() or caller == _session.get_ref().simulation) and _ticket_context(_dispatch) == _context and _dispatch.copy().intent.id == request_id

func allow_completion(caller: Object, request_id: String, parent: String, action: RefCounted = null, kind: String = "handling") -> bool:
	if allow_entry(caller,request_id): return _dispatch.copy().intent.kind == kind
	if not _bound() or caller != _session.get_ref().simulation: return false
	var windows: Array = [_context]
	if not _pending.is_empty(): windows.append(_pending.window)
	for window: RefCounted in windows:
		if not _issued(window) or not window._tickets.has(request_id) or not window._results.has(request_id): continue
		var ticket: RefCounted = window._tickets[request_id]
		if ticket.copy().intent.kind != kind: return false
		var action_id: String = window._results[request_id].get("action_instance_id","")
		var original: CombatActionInstance = _session.get_ref().simulation.get_action(action_id)
		if original == null or (action != null and action != original) or original.actor_id != &"player" or original.request_id != request_id or original.status != CombatActionInstance.STATUS_COMPLETED or original.final_event_id != parent or ticket._completion_used: return false
		ticket._completion_used = true
		return true
	return false

func cancel_request(ticket: RefCounted) -> Dictionary:
	if not _bound(): return fail("temporary_context_expired")
	if _dispatch != null: return fail("temporary_request_in_flight")
	var context := _ticket_context(ticket)
	if context == null: return fail("temporary_context_expired")
	var id: String = ticket.copy().intent.id
	if context._results.has(id): return fail("temporary_accepted_request_requires_original_terminal_action")
	context._results[id] = {"success":false,"reason":"temporary_request_canceled"}
	return {"success":true,"durable":false}

func capture(phase: String, operation_id: String) -> Dictionary:
	if not _bound(): return fail("temporary_context_expired")
	if not _pending.is_empty() or _dispatch != null: return fail("temporary_checkpoint_pending")
	if operation_id.is_empty(): return fail("temporary_checkpoint_identity_required")
	var acquired: Dictionary = _gate.acquire(phase)
	if not acquired.success: return acquired
	var service: PlayableCharacterPersistence = _service.get_ref()
	var boundary := service._capture(_session.get_ref(),phase)
	if not boundary.success:
		acquired.lease.cancel(); return boundary
	var captured: Dictionary = _gate.collect(acquired.lease)
	if not captured.success: return captured
	_context._state = "sealed"
	_pending = {"capture":captured.capture,"text":captured.capture.json(),"window":_context,"parent":_head,"id":operation_id,"uncertain":false}
	_new_context()
	return {"success":true,"capture":_pending.capture,"text":_pending.text,"parent":_head,"operation_id":operation_id,"durable":false}

func unknown(capture: RefCounted) -> Dictionary:
	if not _bound() or _pending.is_empty() or _pending.capture != capture or not _aggregate_fresh(capture): return fail("temporary_stale_before_simulated_attempt")
	_pending.uncertain = true
	return {"success":true,"durable":false}

func acknowledge(capture: RefCounted, text: String) -> Dictionary:
	if _dispatch != null: return fail("temporary_request_in_flight")
	if not _bound() or _pending.is_empty() or _pending.capture != capture or text != _pending.text or _pending.parent != _head: return fail("temporary_simulated_readback_mismatch")
	if not _pending.uncertain and not _aggregate_fresh(capture): return fail("temporary_stale_before_simulated_attempt")
	var current: bool = _aggregate_fresh(capture)
	_pending.window.retire()
	_head += 1; _pending = {}
	# No actor/session/service state is installed here. Earlier capture metadata
	# cannot roll back later gameplay or the original writer's newer checkpoint.
	return {"success":true,"current_runtime":current,"head":_head,"durable":false}

func cancel_capture() -> Dictionary:
	if not _bound() or _pending.is_empty(): return fail("temporary_checkpoint_missing")
	if _pending.uncertain: return fail("temporary_uncertain_requires_reconciliation")
	_pending.window.retire(); _pending = {}
	return {"success":true,"durable":false}

func close() -> Dictionary:
	if not _bound(): return fail("temporary_context_expired")
	if not _pending.is_empty() or _dispatch != null: return fail("temporary_checkpoint_pending")
	if _gate._locked() or _gate._active_mutations != 0: return fail("temporary_runtime_busy")
	if not _session.get_ref().get_actor_state(&"player").current_action_instance_id.is_empty(): return fail("temporary_action_pending")
	_context.retire(); _closed = true
	# Leave the gate's fail-closed admission marker on the old runtime. Never
	# unbind it into the ordinary raw-ID route while old callbacks can exist.
	return {"success":true,"durable":false}

func status() -> Dictionary:
	return {"closed":_closed,"pending":not _pending.is_empty(),"uncertain":_pending.get("uncertain",false),"head":_head,"source_calls":_source_calls,"durable":false}

func fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason,"durable":false}
