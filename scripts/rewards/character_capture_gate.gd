extends RefCounted

# Dormant, main-thread mutation/capture coordination only. No save authority,
# aggregate, publication, acknowledgement or cross-process ownership.
var _revision: int = 0
var _active_mutations: int = 0
var _lease: WeakRef
var _session: WeakRef
var _player: WeakRef
var _participants: Array = []
var _binding: int = 0
var _last_capture: RefCounted
var _captured_revision: int = -1
var _binding_invalid := false
var _item_context_required := false
var _item_context_owner: WeakRef

# Opt-in 46F only. A retired/disposed owner must not reopen raw-ID entry.
func attach_item_context(owner: RefCounted) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id() or not _attached() or _locked() or _active_mutations != 0: return _fail("temporary_gate_busy")
	if _item_context_required or owner == null or not is_instance_of(owner,load("res://scripts/rewards/temporary_character_requests.gd")) or owner._gate != self: return _fail("temporary_gate_owner_invalid")
	_item_context_required = true; _item_context_owner = weakref(owner)
	return {"success":true}

func item_entry(caller: Object, request_id: String) -> Dictionary:
	if not _item_context_required: return {"success":true}
	var owner: RefCounted = _item_context_owner.get_ref()
	return {"success":true} if owner != null and owner.allow_entry(caller,request_id) else _fail("temporary_issued_request_required")

func item_completion(caller: Object, request_id: String, parent: String, action: RefCounted = null, kind: String = "handling") -> bool:
	if not _item_context_required: return true
	var owner: RefCounted = _item_context_owner.get_ref()
	return owner != null and owner.allow_completion(caller,request_id,parent,action,kind)

class Mutation extends RefCounted:
	var _gate: RefCounted
	func _init(gate: RefCounted) -> void: _gate = gate
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _gate != null:
			_gate._end_mutation()

class Lease extends RefCounted:
	var _gate: RefCounted
	func _init(gate: RefCounted) -> void: _gate = gate
	func cancel() -> void:
		if _gate != null: _gate.cancel(self)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _gate != null: _gate.cancel(self)

class Capture extends RefCounted:
	var _json: String = "":
		set(value):
			if _json.is_empty(): _json = value
	func _init(text: String) -> void: _json = text
	func copy() -> Dictionary: return JSON.parse_string(_json)
	func json() -> String: return _json

func bind(session: RefCounted, player: Node) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _fail("capture_requires_main_thread")
	if _active_mutations != 0 or _locked(): return _fail("character_capture_busy")
	if session == null or player == null or session.simulation == null or player._movement == null: return _fail("capture_participants_unavailable")
	if session.player_movement_boundary_provider != Callable(player,"capture_wave_entry_motion"): return _fail("capture_provider_mismatch")
	if _session != null: return _fail("capture_gate_already_bound")
	var parts: Array = [session,session.simulation,session.simulation.clock,session.simulation.random,session._reward_ledger,player,player._movement,player._movement._roll_source]
	parts.append(session.simulation.get_actor_state(&"player"))
	parts.append(session.simulation.get_actor_definition(&"player"))
	if session._playable_persistence != null: parts.append(session._playable_persistence)
	for part: Object in parts:
		if part == null: return _fail("capture_participants_unavailable")
		var supported := false
		for property: Dictionary in part.get_property_list():
			if property.name == "_character_capture_gate": supported = true; break
		if not supported: return _fail("capture_participant_unsupported")
		if part._character_capture_gate != null: return _fail("capture_participant_already_bound")
	_session = weakref(session); _player = weakref(player); _binding += 1
	for part: Object in parts:
		part._character_capture_gate = self
		_participants.append(weakref(part))
	return {"success":true}

# A local scope releases on every return and error-unwind. Conservatively count
# admitted mutation attempts, including failed/no-op ones; never consume RNG.
func enter_mutation() -> RefCounted:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return null
	if _locked(): return null
	_revision += 1
	_active_mutations += 1
	return Mutation.new(self)

func _end_mutation() -> void:
	_active_mutations -= 1

# Original safe checkpoint seam only. Capture right here, before NEXT WAVE or
# AI can continue. A later mutation makes this historical capture stale; never
# move a downtime request to command return and label the newer state as entry.
func checkpoint_boundary(session: RefCounted, boundary: String) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	if _session == null or session != _session.get_ref() or _locked() or _active_mutations == 0: return
	if boundary == "next_wave_entry":
		if not session._authorized_entry_write: return
	elif boundary == "run_completed":
		if session.get_encounter_state() != "player_victory": return
	elif session.get_encounter_state() != "between_wave_downtime": return
	if not _attached(): return
	var lease := Lease.new(self)
	_lease = weakref(lease)
	_collect_now()
	cancel(lease)

func last_capture() -> RefCounted:
	return _last_capture if OS.get_thread_caller_id() == OS.get_main_thread_id() else null

func _locked() -> bool:
	return _lease != null and _lease.get_ref() != null

func _attached() -> bool:
	if _binding_invalid: return false
	if _session == null or _player == null: return false
	var session: RefCounted = _session.get_ref(); var player: Node = _player.get_ref()
	if session == null or player == null: return _invalidate_binding()
	if session.simulation == null or player._movement == null: return _invalidate_binding()
	var actual: Array = [session,session.simulation,session.simulation.clock,session.simulation.random,session._reward_ledger,player,player._movement,player._movement._roll_source]
	actual.append(session.simulation.get_actor_state(&"player"))
	actual.append(session.simulation.get_actor_definition(&"player"))
	if session._playable_persistence != null: actual.append(session._playable_persistence)
	if actual.size() != _participants.size() or session.player_movement_boundary_provider != Callable(player,"capture_wave_entry_motion"): return _invalidate_binding()
	for i in range(actual.size()):
		if actual[i] != _participants[i].get_ref() or actual[i]._character_capture_gate != self: return _invalidate_binding()
	return true

func _invalidate_binding() -> bool:
	_binding_invalid = true
	_revision += 1
	return false

func acquire(phase: String) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _fail("capture_requires_main_thread")
	if not _attached(): return _fail("capture_binding_changed")
	if _locked() or _active_mutations != 0: return _fail("character_capture_busy")
	var session: RefCounted = _session.get_ref()
	var player: Object = session.get_actor_state(&"player")
	if player == null or not player.current_action_instance_id.is_empty(): return _fail("capture_player_action_pending")
	var state: String = session.get_encounter_state()
	if (phase == "entry" and state != "ready") or (phase == "downtime" and state != "between_wave_downtime") or (phase == "complete" and state != "player_victory") or phase not in ["entry","downtime","complete"]: return _fail("capture_requires_safe_boundary")
	# This is a capture permit only, not permission to publish a wave entry.
	var lease := Lease.new(self)
	_lease = weakref(lease)
	return {"success":true,"lease":lease}

func collect(lease: RefCounted) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _fail("capture_requires_main_thread")
	if not _locked() or _lease.get_ref() != lease: return _fail("capture_lease_mismatch")
	if not _attached():
		cancel(lease)
		return _fail("capture_binding_changed")
	var result: RefCounted = _collect_now()
	cancel(lease)
	return {"success":true,"capture":result}

# The original service has already checked the checkpoint phase and normalized
# genuine new receipts. This narrow seam permits its enclosing command scope;
# it does not accept a supplied snapshot, phase flag or verification result.
func acquire_service_checkpoint(service: RefCounted, session: RefCounted, phase: String) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _fail("capture_requires_main_thread")
	if not _attached() or _session.get_ref() != session or session._playable_persistence != service: return _fail("capture_binding_changed")
	if _locked() or _active_mutations == 0: return _fail("checkpoint_command_required")
	if phase == "entry":
		if not session._authorized_entry_write: return _fail("checkpoint_requires_wave_entry_boundary")
	elif phase == "downtime":
		if session.get_encounter_state() != "between_wave_downtime": return _fail("checkpoint_requires_authoritative_downtime")
	elif phase == "complete":
		if session.get_encounter_state() != "player_victory": return _fail("checkpoint_requires_completed_circuit")
	else: return _fail("capture_requires_safe_boundary")
	if not session.get_actor_state(&"player").current_action_instance_id.is_empty(): return _fail("capture_player_action_pending")
	var lease := Lease.new(self)
	_lease = weakref(lease)
	return {"success":true,"lease":lease}

func _collect_now() -> RefCounted:
	var session: RefCounted = _session.get_ref(); var player: Node = _player.get_ref()
	# No await, resolver, signal or caller callback is executed here. Both
	# snapshots are collected synchronously with all bound mutation APIs locked.
	var state: Dictionary = {"session":session.get_state_snapshot(),"ledger":session.get_reward_state(),"movement":player.capture_wave_entry_motion()}
	var result := Capture.new(JSON.stringify(state,"",true,true))
	_last_capture = result
	_captured_revision = _revision
	return result

func capture(phase: String) -> Dictionary:
	var acquired := acquire(phase)
	if not acquired.success: return acquired
	return collect(acquired.lease)

func cancel(lease: RefCounted) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	if _lease != null and _lease.get_ref() == lease: _lease = null

func is_current(capture: RefCounted) -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return false
	return capture is Capture and _last_capture == capture and _captured_revision == _revision and _attached() and not _locked() and _active_mutations == 0

func unbind() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return _fail("capture_requires_main_thread")
	if _item_context_required: return _fail("temporary_admission_cannot_be_unbound")
	if _locked() or _active_mutations != 0: return _fail("character_capture_busy")
	for reference: WeakRef in _participants:
		var part: Object = reference.get_ref()
		if part != null and part._character_capture_gate == self: part._character_capture_gate = null
	_participants.clear(); _session = null; _player = null; _last_capture = null
	_binding_invalid = false
	_revision += 1; _binding += 1
	return {"success":true}

func revision() -> int: return _revision

func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason}
