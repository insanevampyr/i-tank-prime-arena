extends RefCounted

# Dormant coordinator-owned prototype. Only disposable cache contexts may open.
# Runtime rules remain in the original session/ledger/service. No storage API.
const Codec = preload("res://scripts/rewards/minimal_character_snapshot.gd")
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const Gate = preload("res://scripts/rewards/character_capture_gate.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")
const V3 = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
const Requests = preload("res://scripts/rewards/temporary_character_requests.gd")
const SCOPES := ["operation","award","purchase","growth","settlement","item_origin","credit","development","run"]
var _current: RefCounted
var _source: CombatCharacterDefinitionResource
var _service: PlayableCharacterPersistence
var _session: ArenaCombatSession
var _player: PlaceholderPlayer
# Optional scene factory for the explicitly selected disposable playable route.
var _player_factory: Callable
var _gate: RefCounted
var _lookup: Dictionary = {}
var _ids: Dictionary = {}
var _cursor := 0
var _revision := 0
var _pending: Dictionary = {}
var _last_simulated := ""
var _closed := false
var _inside_checkpoint := false
var _auto_simulate := false
var _metrics: Dictionary = {}
var _admission_cold_us := 0
var _v3 := false
var _requests: RefCounted
var _transition: Dictionary = {}
var _root := ""
var _windows_route: RefCounted
var _windows_head := ""
var _windows_automatic := false
var _windows_last_result: Dictionary = {}
var _browser_route: RefCounted
var _browser_head := ""
var _browser_phase := ""
var _browser_job := ""
var _browser_owner := ""
var _browser_text := ""
var _browser_target := ""
var _browser_pending := false
var _browser_cancel := false
var _browser_started := 0
var _browser_capture_started := 0
var _browser_automatic := false
var _browser_result: Dictionary = {}
var _browser_metrics: Dictionary = {}
var _browser_next: Dictionary = {}
var _browser_transition_dispatch := false

func admit(text: String, source: CombatCharacterDefinitionResource, profile: String, scope: String, root: String, version: int = 1, player_factory: Callable = Callable()) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("minimal_requires_main_thread")
	var allowed := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_").replace("\\","/")
	if not root.replace("\\","/").simplify_path().begins_with(allowed): return fail("disposable_minimal_context_required")
	_root = root
	var started := Time.get_ticks_usec()
	if version not in [1,3]: return fail("minimal_unsupported_codec")
	_v3 = version == 3
	if player_factory.is_valid() and not _v3: return fail("playable_factory_requires_v3")
	_player_factory = player_factory
	var cold := V3.decode(text,source,profile,scope) if _v3 else Codec.decode(text,source,profile,scope)
	if not cold.success: return cold
	_current = cold.snapshot
	_source = source.duplicate(true)
	_metrics["cold_decode_us"] = Time.get_ticks_usec()-started
	_admission_cold_us = _metrics.cold_decode_us
	var b: Dictionary = _current.copy()
	if _v3:
		_lookup = V3.identities(b).ids
	else:
		for key: String in SCOPES: _ids[key] = []
		for row: Dictionary in b.lifetime_ids:
			_lookup[JSON.stringify([row.scope,row.id])] = row.record_digest
			_ids[row.scope].append(row.duplicate(true))
	var payload: Dictionary = _current.projection()
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",scope,payload.lineage.baseline_digest)
	if not starter.success or V6.digest(starter.source.to_dictionary()) != b.source_digest: return fail("admission_source_mismatch")
	return _open_runtime(starter,payload,false,{},ArenaRewardLedger.resolve_run_policy(scope))

func _open_runtime(starter: Dictionary, payload: Dictionary, new_run: bool, authorization: Dictionary, requested: Dictionary, opened_service: PlayableCharacterPersistence = null) -> Dictionary:
	var b: Dictionary = _current.copy()
	var scope: String = payload.profile_namespace
	var profile: String = payload.character_id
	var root: String = _service.storage._root if _service != null else _root
	_service = opened_service if opened_service != null else PlayableCharacterPersistence.new()
	_service.storage = CharacterSaveStorage.new(root)
	_service.source = _source
	_service.profile_id = profile; _service.mode = scope
	# Admission only: original hydration/derived-state rules, never a history
	# archive, file read or routine proposal. END witness is derived, not supplied.
	var chronology := V6._chronology(payload,b.evidence,_source)
	if not chronology.success: return chronology
	_service._endurance_history = {"success":true,"source_digest":b.source_digest,"head_digest":V6.digest(payload),"generation":payload.generation,"end":chronology.end,"growth":chronology.growth}
	var opened := _service._open_existing_verified(starter,payload,b.last_operation_id,new_run,authorization,requested) if opened_service == null else {"success":true}
	if not opened.success: return opened
	if new_run: _transition = {"run":_service.run_id,"runs":_service._runs.duplicate(),"policy":_service._run_policy_history.duplicate(true)}
	_service.items = payload.recovery.ledger.profile_ownership.items.duplicate(true)
	var finished := _service._finish_verified_open(starter)
	if not finished.success: return finished
	var wave: int = 1 if new_run else int(payload.recovery.wave_id.trim_prefix("wave_"))
	var encounters := [PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_ONE_GOBLINS,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_TWO_SPADOODLES,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_FOUR_GARGOYLES,PrimeV3VerticalSliceFixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR]
	_session = ArenaCombatSession.new(String(payload.recovery.seed).to_int(),null,encounters[wave-1],&"vaelis_thorn")
	_session._playable_persistence = _service
	_session._run_reward_policy = _service.get_run_reward_policy()
	_session._entry_bootstrap = _service.recovery.duplicate(true)
	_session.simulation.wave_entry_opening = _service.recovery.get("opening",{}).duplicate(true)
	for row: Dictionary in _service.recovery.get("roster",[]):
		for i in range(row.dice_results.size()): _session._entry_dice.append({"value":int(row.dice_results[i]),"rng_draw_index":int(row.rng_draw_indices[i])})
	_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initializer: String = ["initialize_wave_one_goblins","initialize_wave_two_spadoodles","initialize_wave_three_skelly_hades","initialize_wave_four_gargoyles","initialize_wave_five_rare_human_warrior"][wave-1]
	var initialized: Dictionary = _session.call(initializer,Vector2i(14000000,8000000),Vector2i(17000000,8000000),false)
	if not initialized.success: return initialized
	var made: Variant = _player_factory.call() if _player_factory.is_valid() else Player.new()
	if not made is PlaceholderPlayer or made.get_script() != Player or made._character_capture_gate != null: return fail("fresh_playable_player_required")
	_player = made
	_player.reset_for_encounter(Vector2(14,8))
	var configured := _player.configure_authoritative_actor_profile(_session.simulation.get_actor_definition(&"player"))
	if not configured.success or (not new_run and not _player.restore_wave_entry_motion(_service.recovery.movement)): return fail("admission_movement_unavailable")
	_session.player_movement_boundary_provider = _player.capture_wave_entry_motion
	_session.player_speed_profile_refresher = _player.refresh_permanent_speed_profile
	_session.player_endurance_profile_refresher = _player.refresh_permanent_endurance_profile
	_session.configure_reward_mode(scope)
	if new_run:
		_service._minimal_transactions = weakref(self)
		_gate = Gate.new()
		var bound_new: Dictionary = _gate.bind(_session,_player)
		if not bound_new.success: return bound_new
		_cursor = _session.simulation.get_resolved_event_count()
	var finalized := _session.finalize_playable_persistence()
	if not finalized.success and not (new_run and not _pending.is_empty()): return finalized
	_service._minimal_transactions = weakref(self)
	if not new_run:
		_gate = Gate.new()
		var bound: Dictionary = _gate.bind(_session,_player)
		if not bound.success: return bound
	if _v3:
		_requests = Requests.new()
		var request_admission: Dictionary = _requests.admit_aggregate(self)
		if not request_admission.success: return request_admission
		if not _pending.is_empty():
			var sealed: Dictionary = _requests.seal_aggregate_capture(self,_pending.capture,_pending.operation)
			if not sealed.success: return sealed
	if not new_run: _cursor = _session.simulation.get_resolved_event_count()
	if new_run and _browser_automatic and not _pending.is_empty(): return begin_browser()
	if new_run and _windows_automatic and not _pending.is_empty(): return publish_windows()
	_simulation_status("admitted_simulation_only")
	return {"success":true,"state":"admitted_simulation_only","durable":false}

func _context() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("minimal_requires_main_thread")
	if _closed or _current == null: return fail("minimal_context_closed")
	if _session._playable_persistence != _service or not _gate._attached(): return _binding_failure("minimal_runtime_binding_changed")
	var b: Dictionary = _current.copy()
	if _service.source == null: return _binding_failure("minimal_identity_or_source_changed")
	if _service.profile_id != b.current.character_id or _service.mode != b.current.profile_namespace or V6.digest(_source.to_dictionary()) != b.source_digest or V6.digest(_service.source.to_dictionary()) != b.source_digest: return _binding_failure("minimal_identity_or_source_changed")
	var run: String = _transition.get("run",b.current.recovery.run_id)
	var runs: Array = _transition.get("runs",b.current.run_history)
	var policy: Dictionary = _transition.get("policy",b.current.get("run_reward_policy",{}))
	if _service.generation != b.sequence or _service.run_id != run or _service._lineage != b.current.lineage or _service._runs != runs: return _binding_failure("minimal_admitted_context_changed")
	if _service._run_policy_history != policy: return _binding_failure("minimal_run_policy_changed")
	return {"success":true}

func _binding_failure(reason: String) -> Dictionary:
	if _v3: _closed = true
	return fail(reason)

func checkpoint(service: PlayableCharacterPersistence, session: ArenaCombatSession, phase: String, source_started_us: int) -> Dictionary:
	var context := _context()
	if not context.success: return context
	if service != _service or session != _session: return fail("foreign_checkpoint_source")
	_inside_checkpoint = true
	var result := _prepare_checkpoint(phase,source_started_us)
	_inside_checkpoint = false
	if _v3 and not result.success and result.get("state") != "prepared_not_saved" and not _owned_storage_pending(result):
		_closed = true
		_simulation_status("unsupported_source_requires_readmission")
	return result

func _owned_storage_pending(result: Dictionary) -> bool:
	if _pending.is_empty(): return false
	if _browser_route != null and result.get("state") == "pending" and not _browser_phase.is_empty() and result.get("job") == _browser_job: return true
	return _windows_route != null and _pending.uncertain and result.get("pending_storage_operation","") == _pending.operation

func _prepare_checkpoint(phase: String, started: int) -> Dictionary:
	if _v3 and not _pending.is_empty(): return {"success":true,"state":"checkpoint_deferred_pending_readback","durable":false}
	var source_work_us := Time.get_ticks_usec()-started
	var acquired: Dictionary = _gate.acquire_service_checkpoint(_service,_session,phase)
	if not acquired.success: return acquired
	var boundary := _service._capture(_session,phase)
	if not boundary.success:
		acquired.lease.cancel()
		return boundary
	var batch := _session.simulation.get_resolved_events_from(_cursor)
	if not batch.success:
		acquired.lease.cancel()
		return fail("minimal_event_cursor_changed")
	var facts: Array = []
	for event: CombatEvent in batch.events: facts.append(event.to_dictionary())
	var captured: Dictionary = _gate.collect(acquired.lease)
	if not captured.success: return captured
	var binding := V6.digest({"phase":phase,"checkpoint":boundary.checkpoint,"facts":facts,"profile":_service.profile_id,"namespace":_service.mode,"run":_service.run_id})
	if not _pending.is_empty():
		if binding != _pending.binding: return fail("pending_checkpoint_binding_changed")
		# Same authorized source facts/checkpoint, not replacement candidate bytes.
		# Refresh only the current-state witness for this exact retry.
		_pending.capture = captured.capture
		_pending.gate_revision = _gate.revision()
		return _prepared_result(true)
	var before: Dictionary = _current.copy()
	# Exact already-simulated checkpoint retry is a no-op, not another operation.
	if boundary.checkpoint == before.current.recovery and facts.is_empty(): return {"success":true,"state":"simulated_checkpoint_unchanged","durable":false}
	var body: Dictionary = before.duplicate(true)
	var checked := _append_events(body,facts)
	if not checked.success: return checked
	var state := _session.get_actor_state(&"player")
	var actor := _session.simulation.get_actor_definition(&"player")
	var ledger := _session.get_reward_state()
	var c: Dictionary = body.current
	c.generation += 1
	# Match the existing codec reader's JSON numeric representation once for
	# this new checkpoint (including negative sentinels), not lifetime history.
	c.recovery = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.stringify(boundary.checkpoint,"",true,true)))
	c.equipment_state = {"hands":state.hand_occupancy.duplicate(true),"handling":state.weapon_handling.duplicate(true)}
	c.items = _service.items.duplicate(true) if _v3 else _service.items.filter(func(item: Dictionary): return item.quantity > 0).duplicate(true)
	if _service.receipts.slice(0,body.evidence.settlements.size()) != body.evidence.settlements: return fail("settlement_prefix_changed")
	body.evidence.settlements = _service.receipts.duplicate(true)
	c.run_history = _service._runs.duplicate()
	if _service._run_policy_history.is_empty(): c.erase("run_reward_policy")
	else: c["run_reward_policy"] = _service._run_policy_history.duplicate(true)
	if phase != "entry":
		var secured := "%s/%s/%s" % [_service.profile_id,_service.run_id,_session._current_reward_wave_id()]
		if not c.secured_checkpoints.has(secured): c.secured_checkpoints.append(secured)
	c.permanent.level = state.progression.get("level",actor.level)
	c.permanent.resource_maxima = actor.resource_maxima.duplicate(true)
	c.permanent.ability_allowances = actor.ability_allowances.duplicate(true)
	c.permanent.equipment_refs = Array(state.equipment_refs)
	c.permanent.inventory_quantities = state.inventory_quantities.duplicate(true)
	c.permanent.xp_baseline = {"expm":_source.progression_policy.initial_expm,"expc":_source.progression_policy.initial_expc,"earned":ledger.earned_xp,"spent":ledger.spent_xp}
	if state.progression.has("development"): c.permanent["development"] = state.progression.development.duplicate(true)
	c.xp = {"earned":int(_source.progression_policy.initial_expm)+int(ledger.earned_xp),"spent":int(ledger.spent_xp),"unspent":int(_source.progression_policy.initial_expc)+int(ledger.earned_xp)+int(ledger.get("expc_credit_total",0))-int(ledger.spent_xp)}
	var expected: Dictionary = before.current.xp.duplicate(true)
	for row: Dictionary in body.evidence.awards.slice(before.evidence.awards.size()): expected.earned += row.xp; expected.unspent += row.xp
	for row: Dictionary in body.evidence.purchases.slice(before.evidence.purchases.size()): expected.spent += row.cost; expected.unspent -= row.cost
	if expected != c.xp: return fail("unrepresented_accounting_change")
	if (c.run_history != before.current.run_history or c.get("run_reward_policy") != before.current.get("run_reward_policy")) and (not _v3 or _transition.is_empty()): return fail("new_run_requires_cold_admission")
	if _v3: _compact_current(c)
	var unchanged: Dictionary = c.duplicate(true)
	unchanged.generation = before.current.generation
	if JSON.stringify(unchanged,"",true,true) == JSON.stringify(before.current,"",true,true) and JSON.stringify(body.evidence,"",true,true) == JSON.stringify(before.evidence,"",true,true):
		_cursor = int(batch.next_cursor)
		return {"success":true,"state":"simulated_checkpoint_unchanged","durable":false}
	var operation := "checkpoint_%s" % c.generation
	var result := _seal(body,operation,binding,captured.capture,int(batch.next_cursor),started)
	_metrics["original_source_ingest_receipts_us"] = source_work_us
	return result

func _append_events(body: Dictionary, facts: Array) -> Dictionary:
	var positions := {}; var events := {}; var seen := {}
	for event: Dictionary in facts:
		if events.has(event.event_id): return fail("duplicate_source_event")
		positions[event.event_id] = events.size(); events[event.event_id] = event
	for event: Dictionary in facts:
		var row := {}; var kind := ""; var id := ""
		# v1 retains acquisition origins and terminal quantities, but has no
		# independently cold-verifiable per-use/equipment command-ID evidence.
		# Never substitute a checkpoint wrapper/hash for those original IDs.
		if not _v3 and event.source_actor_id == "player" and event.event_type in ["downtime_consumable_used","consumable_healing_resolved","consumable_mana_resolved","downtime_equipment_changed"]:
			_closed = true
			return fail("minimal_v1_command_identity_evidence_unavailable")
		if _v3 and event.source_actor_id == "player" and event.event_type in ["downtime_consumable_used","consumable_healing_resolved","consumable_mana_resolved"]:
			var debit := _original_debit(event)
			if not debit.success: return debit
			var original_id: String = JSON.stringify([_service.run_id,debit.fact.request_id])
			var effect_id: String = JSON.stringify([_service.run_id,debit.fact.event_id])
			if _lookup.has(JSON.stringify(["item_use",original_id])) or _lookup.has(JSON.stringify(["item_use_event",effect_id])): return fail("reused_irreversible_consumption")
			body.evidence.item_debits.append(debit.fact)
		match event.event_type:
			"reward_xp_awarded":
				if event.target_actor_id != "player": continue
				kind = "award"; row = _service._awards.get(event.event_id,{}).duplicate(true); id = row.get("award_id","")
				var parent: String = event.parent_event_id
				if not events.has(parent) or positions[parent] >= positions[event.event_id] or event.payload.get("defeat_event_id") != parent: return fail("award_causality_missing")
				var original: CombatEvent
				for live: CombatEvent in _session.simulation.get_resolved_events_from(_cursor).events:
					if live.event_id == parent: original = live; break
				if original == null or not _session._is_reward_eligible_defeat(original,PackedStringArray([event.payload.actor_id])): return fail("award_defeat_not_authorized")
			"reward_advancement_purchased":
				if event.source_actor_id != "player": continue
				kind = "purchase"; id = _service._purchases.get(event.payload.get("request_id",""),"")
				row = {"purchase_id":id}
				for key: String in Profiles.purchase_fields(event.payload): row[key] = event.payload[key]
			"reward_character_level_gained":
				if event.source_actor_id != "player": continue
				kind = "growth"; id = _service._growth.get("%s:%s" % [event.payload.get("award_id",""),event.payload.level],"")
				if not events.has(event.parent_event_id) or events[event.parent_event_id].event_type != "reward_xp_awarded" or positions[event.parent_event_id] >= positions[event.event_id]: return fail("growth_causality_missing")
				row = {"growth_id":id}
				for key: String in Profiles.HISTORY_FIELDS: row[key] = event.payload[key]
			_: continue
		var key := JSON.stringify([kind,id])
		if id.is_empty() or seen.has(key) or _lookup.has(key): return fail("reused_or_missing_lifetime_fact")
		seen[key] = true
		body.evidence[{"award":"awards","purchase":"purchases","growth":"growth"}[kind]].append(row)
		body.evidence.order.append({"kind":kind,"id":id})
	return {"success":true}

func _compact_current(c: Dictionary) -> void:
	var ledger := {}
	for key: String in V3.LEDGER+["xp_multiplier","expc_credit_total"]:
		if c.recovery.ledger.has(key): ledger[key] = c.recovery.ledger[key]
	c.recovery.ledger = ledger
	if c.permanent.has("development"):
		var kept: Array = []; var preferences := {}
		for row: Dictionary in c.permanent.development.commands:
			if row.kind == "preferences": preferences = row
			else: kept.append(row)
		if not preferences.is_empty(): kept.append(preferences)
		c.permanent.development.commands = kept
		c.recovery.player.development = c.permanent.development.duplicate(true)

func _original_debit(event: Dictionary) -> Dictionary:
	var payload: Dictionary = event.payload
	var id: String = payload.get("request_id","")
	if id.is_empty():
		var action: CombatActionInstance = _session.simulation.get_action(payload.get("action_instance_id",""))
		if action == null or action.actor_id != &"player" or action.status != CombatActionInstance.STATUS_COMPLETED or action.final_event_id != event.parent_event_id: return fail("consumption_original_action_unavailable")
		id = action.request_id
	if _requests == null: return fail("consumption_issued_context_unavailable")
	# The actual source accepted this request through the bound issued handle.
	# A callback or a new wrapper cannot invent its original identity.
	var issued := false
	var windows: Array = [_requests._context]
	if not _requests._pending.is_empty(): windows.append(_requests._pending.window)
	for window: RefCounted in windows:
		if window._tickets.has(id) and window._tickets[id].copy().intent.kind == "use": issued = true
	if not issued: return fail("consumption_issued_request_missing")
	return {"success":true,"fact":{"run_id":_service.run_id,"request_id":id,"event_id":event.event_id,"kind":"consume","definition_id":payload.inventory_id,"selection":payload.ownership_selection.duplicate(true)}}

func _seal_v3(body: Dictionary, operation: String, binding: String, captured: RefCounted, cursor: int, started: int) -> Dictionary:
	var construction := Time.get_ticks_usec()
	body.sequence = body.current.generation; body.last_operation_id = operation
	body.recent_journal.append({"sequence":body.sequence,"id":operation,"request_digest":binding})
	body.recent_journal = body.recent_journal.slice(maxi(0,body.recent_journal.size()-20))
	var index := V3.identities(body)
	if not index.success: return index
	for key: String in _lookup:
		if index.ids.get(key) != _lookup[key]: return fail("immutable_lifetime_binding_changed")
	var before_encode := Time.get_ticks_usec()
	var encoded := V3.encode(body,_source,_service.profile_id,_service.mode)
	var after_encode := Time.get_ticks_usec()
	if not encoded.success: return encoded
	_pending = {"operation":operation,"binding":binding,"snapshot":encoded.snapshot,"text":encoded.text,"capture":captured,"gate_revision":_gate.revision(),"revision":_revision,"cursor":cursor,"groups":{},"lookup":index.ids,"uncertain":false,"started_us":started}
	if _requests != null:
		var sealed: Dictionary = _requests.seal_aggregate_capture(self,captured,operation)
		if not sealed.success: _pending = {}; return sealed
	_metrics = {"construction_us":before_encode-construction,"authorization_and_capture_us":construction-started,"codec_encode_us":after_encode-before_encode,"total_prepare_us":after_encode-started,"bytes":encoded.text.to_utf8_buffer().size(),"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}
	_simulation_status("prepared_not_saved")
	# An issued source command must finish caching its original result before
	# retiring its window. No acknowledgement is invented during that dispatch.
	# NEW RUN binds/seals its genuine new request owner after original bootstrap.
	if _browser_automatic and _requests != null and _requests._dispatch == null: return begin_browser()
	if _windows_automatic and _requests != null and _requests._dispatch == null: return publish_windows()
	if _auto_simulate and (_requests == null or _requests._dispatch == null): return simulate_ack(_pending.text)
	return _prepared_result(false)

func after_item_dispatch(requests: RefCounted) -> void:
	if _v3 and requests == _requests and not _pending.is_empty():
		if _browser_automatic and _browser_phase.is_empty(): begin_browser()
		elif _windows_automatic: publish_windows()
		elif _auto_simulate: simulate_ack(_pending.text)

func request_context() -> RefCounted:
	return _requests.current() if _v3 and _requests != null and _context().success else null

func issue_item(context: RefCounted, kind: String, definition: String, operation: String, id: String) -> Dictionary:
	return _requests.issue(context,kind,definition,operation,id) if _context().success and _v3 and _requests != null else fail("minimal_v3_request_context_required")

func execute_item(ticket: RefCounted) -> Dictionary:
	if not _context().success or not _v3 or _requests == null: return fail("minimal_v3_request_context_required")
	return _requests.execute(ticket)

func authorize_item_dispatch(requests: RefCounted, ticket: RefCounted) -> Dictionary:
	if requests != _requests or not _context().success: return fail("minimal_v3_request_context_required")
	var window: RefCounted = _requests._ticket_context(ticket)
	if window == null: return fail("temporary_context_expired")
	if window != null:
		var intent: Dictionary = ticket.copy().intent
		var key := JSON.stringify(["item_use",JSON.stringify([_service.run_id,intent.id])])
		if intent.kind == "use" and not window._results.has(intent.id) and (_lookup.has(key) or _pending.get("lookup",{}).has(key)): return fail("reused_irreversible_consumption")
	return {"success":true}

func cancel_item(ticket: RefCounted) -> Dictionary:
	return _requests.cancel_request(ticket) if _context().success and _v3 and _requests != null else fail("minimal_v3_request_context_required")

func _seal(body: Dictionary, operation: String, binding: String, captured: RefCounted, cursor: int, started: int) -> Dictionary:
	if _v3: return _seal_v3(body,operation,binding,captured,cursor,started)
	var construction := Time.get_ticks_usec()
	body.sequence = body.current.generation
	body.last_operation_id = operation
	body.operations.append({"id":operation,"request_digest":binding})
	body.recent_journal = body.operations.slice(maxi(0,body.operations.size()-20)).duplicate(true)
	# Existing ID contract defines grouped canonical order; do not invent a new
	# persistent index/format. Full ID rebuilding is an explicitly measured
	# residual cost in this partial prototype, not an incremental hashing claim.
	var groups: Dictionary = _ids.duplicate(true)
	var lookup: Dictionary = _lookup.duplicate(true)
	var all: Array = V6._ids(body)
	# The cold codec remains the independent full binding oracle. This initial
	# path retains its exact ID reconstruction cost; no correctness shortcut.
	for row: Dictionary in all:
		var key := JSON.stringify([row.scope,row.id])
		if lookup.has(key):
			if lookup[key] != row.record_digest: return fail("immutable_lifetime_binding_changed")
		else: lookup[key] = row.record_digest; groups[row.scope].append(row.duplicate(true))
	if all.size() != lookup.size(): return fail("duplicate_or_removed_lifetime_id")
	body.lifetime_ids = all
	var before_encode := Time.get_ticks_usec()
	var encoded := Codec.encode(body,_source,_service.profile_id,_service.mode)
	var after_encode := Time.get_ticks_usec()
	if not encoded.success: return encoded
	_pending = {"operation":operation,"binding":binding,"snapshot":encoded.snapshot,"text":encoded.text,"capture":captured,"gate_revision":_gate.revision(),"revision":_revision,"cursor":cursor,"groups":groups,"lookup":lookup,"uncertain":false}
	_metrics = {"construction_us":before_encode-construction,"authorization_and_capture_us":construction-started,"codec_encode_us":after_encode-before_encode,"total_prepare_us":after_encode-started,"bytes":encoded.text.to_utf8_buffer().size(),"native_live":OS.get_static_memory_usage(),"native_peak":OS.get_static_memory_peak_usage()}
	_simulation_status("prepared_not_saved")
	if _auto_simulate: return simulate_ack(_pending.text)
	return _prepared_result(false)

func _prepared_result(retry: bool) -> Dictionary:
	return {"success":false,"state":"prepared_not_saved","reason":"minimal_simulated_readback_required","operation_id":_pending.operation,"exact_retry":retry,"durable":false}

func prepare(operation: Variant, revision: Variant) -> Dictionary:
	var context := _context()
	if not context.success: return context
	if typeof(operation) != TYPE_STRING or typeof(revision) != TYPE_INT or _pending.is_empty() or operation != _pending.operation or revision != _revision: return fail("minimal_request_or_revision_mismatch")
	return {"success":true,"state":"prepared_not_saved","durable":false,"text":_pending.text,"operation_id":_pending.operation,"revision":_revision,"current_runtime":_fresh(),"metrics":_metrics.duplicate(true)}

func _fresh() -> bool:
	if _pending.is_empty() or _pending.gate_revision != _gate.revision() or not _gate._attached(): return false
	return _inside_checkpoint or _gate.is_current(_pending.capture)

func simulate_unknown() -> Dictionary:
	var context := _context()
	if not context.success: return context
	if _pending.is_empty() or not _fresh(): return fail("stale_capture_before_simulated_publication")
	if _v3 and _requests != null:
		var marked: Dictionary = _requests.unknown(_pending.capture)
		if not marked.success: return marked
	_pending.uncertain = true
	_simulation_status("simulated_unknown_not_saved")
	return {"success":true,"state":"simulated_unknown_not_saved","durable":false}

func simulate_ack(text: String) -> Dictionary:
	if _windows_route != null: return fail("windows_readback_owns_acknowledgement")
	if _browser_route != null: return fail("browser_readback_owns_acknowledgement")
	var adopted := _adopt_pending(text)
	if adopted.success: _simulation_status("simulated_adopted_not_saved")
	return adopted.merged({"durable":false,"state":adopted.get("state","simulated_adopted_not_saved" if adopted.success else "blocked")})

# Common in-memory bookkeeping, never storage proof. The owned Windows/browser
# publication methods attach acknowledgement only after their exact readback.
func _adopt_pending(text: String) -> Dictionary:
	var context := _context()
	if not context.success: return context
	if _pending.is_empty(): return {"success":text == _last_simulated and not text.is_empty(),"state":"already_simulated","durable":false}
	if text != _pending.text or _pending.revision != _revision: return fail("simulated_readback_mismatch")
	var fresh := _fresh()
	if not fresh and not _pending.uncertain: return fail("stale_capture_before_simulated_publication")
	if _v3 and _requests != null:
		var retired: Dictionary = _requests.acknowledge(_pending.capture,_pending.capture.json())
		if not retired.success: return retired
	# No gameplay effect is run here. Ordinary effects already occurred once in
	# the engine; this acknowledges only the isolated in-memory record.
	_current = _pending.snapshot; _last_simulated = _pending.text
	_cursor = _pending.cursor; _lookup = _pending.lookup; _ids = _pending.groups
	_revision += 1
	_service._prior = _current.projection() # Original rule-port read view, no encode/archive.
	_service.generation = _current.copy().sequence
	_service.recovery = _service._prior.recovery.duplicate(true)
	if _v3:
		var temporal := V6._chronology(_service._prior,_current.copy().evidence,_source)
		_service._endurance_history = {"success":true,"source_digest":_current.copy().source_digest,"head_digest":V6.digest(_service._prior),"generation":_service.generation,"end":temporal.end,"growth":temporal.growth}
	_pending = {}
	_transition = {}
	return {"success":true,"current_runtime":fresh,"revision":_revision}

func has_pending() -> bool: return (not _pending.is_empty() and not _v3) or _closed

# Explicit disposable route only. No playable caller selects these methods.
func attach_windows(path: String, exe: String, digest: String) -> Dictionary:
	if not _context().success or not _v3 or _auto_simulate or _windows_route != null: return fail("windows_owner_unavailable")
	var route: RefCounted = load("res://scripts/rewards/minimal_v3_windows_storage.gd").new(path,_source,_service.profile_id,_service.mode,exe,digest)
	if not route.valid(): return fail("invalid_disposable_windows_context")
	var loaded: Dictionary = route.load_current()
	if not loaded.success: return loaded
	if not loaded.get("empty",false):
		var encoded := V3.encode(_current.copy(),_source,_service.profile_id,_service.mode)
		if not encoded.success or encoded.text != loaded.text: return fail("windows_admitted_head_mismatch")
		if loaded.repair_current or loaded.repair_replica: return fail("windows_repair_required")
	_windows_route = route; _windows_head = loaded.head_text
	return {"success":true,"state":"disposable_windows_attached","durable":false}

func publish_windows() -> Dictionary:
	var checked := _context()
	if not checked.success: return checked
	if not _v3 or _auto_simulate or _windows_route == null or not _windows_route.valid(): return fail("windows_owner_unavailable")
	if _requests == null: return fail("windows_request_owner_unavailable")
	if _requests._dispatch != null: return fail("temporary_request_in_flight")
	var pending := not _pending.is_empty()
	var capture_started: int = _pending.get("started_us",0)
	var owned_operation: String = _pending.get("operation","")
	var text := ""
	if pending:
		if not _pending.uncertain:
			if not _fresh(): return fail("stale_capture_before_windows_attempt")
			var marked: Dictionary = _requests.unknown(_pending.capture)
			if not marked.success: return marked
			_pending.uncertain = true
		text = _pending.text
	else:
		var encoded := V3.encode(_current.copy(),_source,_service.profile_id,_service.mode)
		if not encoded.success: return encoded
		text = encoded.text
	var started := Time.get_ticks_usec()
	var lease: Dictionary = _windows_route.acquire()
	if not lease.success: return lease.merged({"pending_storage_operation":owned_operation}) if pending else lease
	var published: Dictionary = _windows_route.publish(text,_windows_head,lease.owner)
	var result := published
	if not published.success and pending: result["pending_storage_operation"] = owned_operation
	if published.success:
		# Publication has read back the descriptor AND both exact selected copies
		# under ownership, including full cold semantics. Never consume a caller's
		# 'verified' dictionary or call the public simulated-ack API here.
		var rechecked: Dictionary = _windows_route.load_current()
		if not rechecked.success or rechecked.get("empty",true) or rechecked.head_text != published.head_text or rechecked.text != text or rechecked.repair_current or rechecked.repair_replica:
			result = fail("windows_ack_readback_unverified")
		else:
			var adopted: Dictionary = _adopt_pending(text) if pending else {"success":true}
			if not adopted.success: result = adopted
			else:
				_windows_head = rechecked.head_text
				_service._status = {"persistent":false,"state":"disposable_windows_verified","text":"Disposable Windows checkpoint verified"}
				var cleaned: Dictionary = _windows_route.maintain(lease.owner,_windows_head)
				result = adopted.merged({"durable":true,"state":"disposable_windows_verified","durable_power_loss_guaranteed":false,"head_text":_windows_head,"exact_retry":published.exact_retry,"storage_metrics":{"publication_us":published.publication_us,"native_us":published.get("native_us",0),"validation_us":published.get("validation_us",0),"readback_us":rechecked.cold_readback_us},"maintenance_required":not cleaned.success,"acknowledged_save_us":Time.get_ticks_usec()-started})
	var released: Dictionary = _windows_route.release(lease.owner)
	if not released.success: result["lock_release_failed"] = true
	if result.success: result["capture_to_ack_us"] = Time.get_ticks_usec()-capture_started if capture_started > 0 else 0
	if result.success and (pending or _windows_last_result.is_empty()): _windows_last_result = result.duplicate(true)
	return result

func automatic_windows(enabled: bool) -> Dictionary:
	if not _context().success or _windows_route == null or not _pending.is_empty(): return fail("windows_owner_unavailable")
	_windows_automatic = enabled
	return {"success":true,"durable":false}

func attach_browser(route: RefCounted) -> Dictionary:
	if not _context().success or not _v3 or _auto_simulate or _windows_route != null or _browser_route != null: return fail("browser_owner_unavailable")
	if route == null or route.get_script() != load("res://scripts/rewards/minimal_v3_browser_storage.gd") or not route.valid() or route.profile != _service.profile_id or route.scope != _service.mode or V6.digest(route.source.to_dictionary()) != V6.digest(_source.to_dictionary()): return fail("foreign_browser_route")
	var loaded: Dictionary = route.take_loaded()
	if not loaded.get("success",false): return fail("browser_cold_read_required")
	if not loaded.get("empty",false) and (loaded.snapshot.json() != _current.json() or loaded.repair_current or loaded.repair_replica): return fail("browser_admitted_head_mismatch")
	_browser_route = route; _browser_head = loaded.head_text
	_browser_owner = "owner_"+Crypto.new().generate_random_bytes(12).hex_encode()
	return {"success":true,"state":"disposable_browser_attached","durable":false}

func automatic_browser(enabled: bool) -> Dictionary:
	if not _context().success or _browser_route == null or not _pending.is_empty() or not _browser_phase.is_empty(): return fail("browser_owner_unavailable")
	_browser_automatic = enabled; return {"success":true,"durable":false}

func _browser_send(phase: String, op: String, args: Dictionary = {}) -> Dictionary:
	_browser_phase = phase
	var queued: Dictionary = _browser_route.begin(op,args)
	_browser_job = queued.get("job","")
	return queued

func begin_browser() -> Dictionary:
	if not _context().success or _browser_route == null or not _v3 or _auto_simulate: return fail("browser_owner_unavailable")
	if not _browser_phase.is_empty(): return fail("browser_operation_in_flight")
	if _requests == null or _requests._dispatch != null: return fail("temporary_request_in_flight")
	_browser_pending = not _pending.is_empty(); var snapshot: RefCounted = _current
	if _browser_pending:
		if not _pending.uncertain:
			if not _fresh(): return fail("stale_capture_before_browser_attempt")
			var attempted: Dictionary = _requests.unknown(_pending.capture)
			if not attempted.success: return attempted
			_pending.uncertain = true
		_browser_text = _pending.text; snapshot = _pending.snapshot
	else:
		var encoded := V3.encode(_current.copy(),_source,_service.profile_id,_service.mode)
		if not encoded.success: return encoded
		_browser_text = encoded.text
	_browser_target = _browser_route.head_text(snapshot,_browser_text)
	_browser_started = Time.get_ticks_usec(); _browser_capture_started = _pending.get("started_us",0)
	_browser_cancel = false; _browser_result = {}; _browser_metrics = {}
	return _browser_send("acquire","acquire",{"owner":_browser_owner})

func _browser_failure(reason: String, detail: Dictionary = {}) -> Dictionary:
	_browser_result = fail(reason).merged({"details":detail})
	return _browser_send("release","release",{"owner":_browser_owner})

func poll_browser() -> Dictionary:
	if _browser_route == null or _browser_phase.is_empty(): return _browser_result.duplicate(true) if not _browser_result.is_empty() else fail("browser_operation_missing")
	var response: Dictionary = _browser_route.poll(_browser_job)
	if response.get("state") == "pending": return response
	if _browser_phase == "release":
		_browser_phase = ""; _browser_job = ""; _browser_text = ""; _browser_target = ""
		if not response.get("success",false): _browser_result["lock_release_failed"] = true
		if _browser_result.get("success",false) and not _browser_next.is_empty(): return _continue_browser_next()
		return _browser_result.duplicate(true)
	if not response.get("success",false):
		if _browser_phase == "acquire": _browser_phase = ""; _browser_result = response; return response
		return _browser_failure(response.get("reason","browser_storage_failed"),response)
	if not _context().success: return _browser_failure("browser_runtime_binding_changed")
	if _browser_cancel and _browser_phase in ["acquire","inspect"]:
		_browser_result = {"success":false,"state":"canceled","reason":"canceled_before_publication_pending_retained","durable":false}
		return _browser_send("release","release",{"owner":_browser_owner})
	match _browser_phase:
		"acquire": return _browser_send("inspect","snapshot")
		"inspect":
			var inspected: Dictionary = _browser_route.decode_snapshot(response)
			if not inspected.success: return _browser_failure(inspected.get("reason","invalid_current"))
			var exact: bool = not inspected.get("empty",false) and inspected.head_text == _browser_target and inspected.text == _browser_text and not inspected.repair_current and not inspected.repair_replica
			if exact: return _browser_send("readback","snapshot")
			if inspected.head_text != _browser_head: return _browser_failure("stale_expected_head")
			if not inspected.get("empty",false):
				if inspected.repair_current or inspected.repair_replica: return _browser_failure("repair_required")
				var candidate := V3.decode(_browser_text,_source,_service.profile_id,_service.mode)
				if not candidate.success: return _browser_failure("invalid_candidate")
				var extension := V3.validate_extension(inspected.snapshot.copy(),candidate.snapshot.copy(),_source,_service.profile_id,_service.mode)
				if not extension.success: return _browser_failure(extension.get("reason","invalid_extension"))
			return _browser_send("publish","publish",{"owner":_browser_owner,"expected":_browser_head,"head":_browser_target,"text":_browser_text})
		"publish":
			_browser_metrics["transaction_ms"] = response.get("transaction_ms",0)
			return _browser_send("readback","snapshot")
		"readback":
			var started := Time.get_ticks_usec()
			var verified: Dictionary = _browser_route.decode_snapshot(response)
			_browser_metrics["cold_readback_us"] = Time.get_ticks_usec()-started
			if not verified.success or verified.get("empty",true) or verified.text != _browser_text or verified.head_text != _browser_target or verified.repair_current or verified.repair_replica: return _browser_failure("browser_readback_unverified")
			return _browser_send("match","match",{"raw":response.row})
		"match":
			var adopted: Dictionary = _adopt_pending(_browser_text) if _browser_pending else {"success":true}
			if not adopted.success: return _browser_failure(adopted.get("reason","browser_ack_rejected"))
			_browser_head = _browser_target
			_browser_metrics["total_browser_us"] = Time.get_ticks_usec()-_browser_started
			_browser_metrics["capture_to_ack_us"] = Time.get_ticks_usec()-_browser_capture_started if _browser_capture_started > 0 else 0
			_browser_metrics["prepare"] = _metrics.duplicate(true)
			_browser_result = adopted.merged({"success":true,"state":"disposable_browser_verified","durable":true,"durable_power_loss_guaranteed":false,"metrics":_browser_metrics.duplicate(true)})
			_service._status = {"persistent":false,"state":"disposable_browser_verified","text":"Disposable browser checkpoint verified"}
			return _browser_send("release","release",{"owner":_browser_owner})
	return _browser_failure("unknown_browser_phase")

func cancel_browser() -> Dictionary:
	if _browser_phase not in ["acquire","inspect"] or not _browser_next.is_empty(): return fail("browser_attempt_requires_reconciliation")
	_browser_cancel = true
	return {"success":true,"state":"cancel_requested","durable":false}

func next_browser_wave() -> Dictionary:
	if not _browser_next.is_empty() or not _browser_phase.is_empty() or not _pending.is_empty() or not _browser_automatic or not _matched_runtime().success: return fail("browser_secured_downtime_required")
	_browser_next = {"session":_session,"opponent":_session._opponent_behavior_enabled}
	return _start_browser_next_source()

func _start_browser_next_source() -> Dictionary:
	_browser_transition_dispatch = true
	var result := _session.request_next_wave()
	_browser_transition_dispatch = false
	if _browser_phase.is_empty(): _browser_next = {}; return result
	_browser_next["entry"] = _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_WAVE_TRANSITION_BLOCKED
	_browser_next["revision"] = _gate.revision()
	_browser_next["binding"] = V6.digest({"session":_session.get_state_snapshot(),"movement":_player.capture_wave_entry_motion()})
	return {"success":false,"state":"pending","reason":"original_wave_checkpoint_pending"}

func _continue_browser_next() -> Dictionary:
	if _browser_next.session != _session or _browser_next.revision != _gate.revision() or _browser_next.binding != V6.digest({"session":_session.get_state_snapshot(),"movement":_player.capture_wave_entry_motion()}): return fail("browser_transition_runtime_changed_reload_required")
	if not _browser_next.entry:
		# Original call stopped before registering/rolling the new wave. Retry
		# that original API only after its actual prior checkpoint is secured.
		return _start_browser_next_source()
	if _current.copy().current.recovery.phase != "entry" or _current.copy().current.recovery.wave_id != _session._current_reward_wave_id(): return fail("browser_transition_entry_mismatch")
	# Same post-readback continuation as the existing browser controller; never
	# install an old session/resource snapshot. The original request already
	# registered this exact entry and stopped solely for its pending checkpoint.
	var mutation: RefCounted = _gate.enter_mutation()
	if mutation == null: return fail("character_capture_in_progress")
	_session._encounter_state = ArenaCombatSession.ENCOUNTER_RUNNING
	_session._encounter_active = true
	var opponent: bool = _browser_next.opponent
	_browser_next = {}
	if opponent: _session._run_opponent_behavior()
	return _browser_result.duplicate(true)

func command_guard(kind: String) -> Dictionary:
	if not _browser_next.is_empty() and not _browser_transition_dispatch: return fail("browser_wave_transition_pending")
	var checked := _context()
	if not checked.success: return checked
	if not _v3 and kind in ["equipment","consumption"]: return fail("minimal_v1_command_identity_evidence_unavailable")
	return {"success":true}

func _matched_runtime() -> Dictionary:
	var checked := _context()
	if not checked.success: return checked
	if not _v3 or not _pending.is_empty(): return fail("minimal_operation_pending")
	var body: Dictionary = _current.copy()
	var lease: Dictionary = _gate.acquire(body.current.recovery.phase)
	if not lease.success: return lease
	var live := _service._capture(_session,body.current.recovery.phase)
	lease.lease.cancel()
	if not live.success: return live
	var c: Dictionary = body.current.duplicate(true)
	c.recovery = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.stringify(live.checkpoint,"",true,true)))
	c.items = _service.items.duplicate(true)
	_compact_current(c)
	if c != body.current: return fail("minimal_current_checkpoint_required")
	var player := _session.get_actor_state(&"player")
	if player.progression.get("expc") != body.current.xp.unspent or player.progression.get("expm") != body.current.xp.earned: return fail("credit_wallet_not_acknowledged")
	return {"success":true}

func new_run(multiplier: int, confirmation: Callable) -> Dictionary:
	var checked := _matched_runtime()
	if not checked.success: return checked
	var requested := ArenaRewardLedger.resolve_run_policy(_service.mode,multiplier)
	if not requested.success: return requested
	var authorization := _session.get_abandon_run_authorization()
	if not authorization.success: return authorization
	var quote := {"checkpoint":authorization.checkpoint,"xp_multiplier":multiplier,"snapshot_digest":_current.json().sha256_text()}
	var revision: int = _gate.revision()
	if not confirmation.is_valid(): return fail("minimal_new_run_confirmation_required")
	var consent: Variant = confirmation.call(quote.duplicate(true))
	if not consent is Dictionary or consent.get("confirmed") != true or consent.get("binding") != V6.digest(quote): return fail("minimal_new_run_confirmation_required")
	if not _context().success or _gate.revision() != revision or not _matched_runtime().success: return fail("minimal_new_run_head_changed")
	var payload: Dictionary = _current.projection()
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",_service.mode,payload.lineage.baseline_digest)
	# Exercise the ORIGINAL run/policy authorization before retiring anything.
	var probe := PlayableCharacterPersistence.new()
	probe.source = _source; probe.profile_id = _service.profile_id; probe.mode = _service.mode; probe._endurance_history = _service._endurance_history.duplicate(true)
	var opened := probe._open_existing_verified(starter,payload,_current.copy().last_operation_id,true,authorization.checkpoint,requested)
	if not opened.success: return opened
	var closed: Dictionary = _requests.close()
	if not closed.success: return closed
	_player.free(); _requests = null
	# The original service allocated this real run ID exactly once. Reuse that
	# authorized service; never invent/rebind an ID or touch global test settings.
	var restored := _open_runtime(starter,payload,true,authorization.checkpoint,requested,probe)
	if not restored.success and not _owned_storage_pending(restored): _closed = true
	return restored

func fixed_credit(confirmation: Callable) -> Dictionary:
	var started := Time.get_ticks_usec()
	var checked := _matched_runtime()
	if not checked.success: return checked
	var eligible := _session.get_character_advancement_eligibility()
	if not eligible.success: return eligible
	var revision: int = _gate.revision()
	var result := V3.Credit.prepare(_current.projection(),confirmation)
	if not result.success or result.get("no_op",false): return result.merged({"durable":false})
	if not _context().success or _gate.revision() != revision or not _matched_runtime().success: return fail("minimal_credit_head_changed")
	var grant: RefCounted = load("res://scripts/rewards/character_expc_grant.gd").new()
	grant._session = _session; grant._service = _service; grant._prepared = {"payload":result.payload,"transaction_id":result.transaction_id}
	var mutation: RefCounted = _gate.enter_mutation()
	if mutation == null: return fail("character_capture_in_progress")
	grant._apply_runtime(result.payload.generation)
	mutation = null
	var body: Dictionary = _current.copy()
	var acquired: Dictionary = _gate.acquire(body.current.recovery.phase)
	if not acquired.success: _closed = true; return acquired
	var live := _service._capture(_session,body.current.recovery.phase)
	if not live.success: acquired.lease.cancel(); _closed = true; return live
	var captured: Dictionary = _gate.collect(acquired.lease)
	if not captured.success: _closed = true; return captured
	body.current.generation = result.payload.generation; body.current.xp = result.payload.xp.duplicate(true)
	body.current.recovery = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.stringify(live.checkpoint,"",true,true)))
	body.evidence.credit = result.payload.expc_credits.duplicate(true)
	body.evidence.order.append({"kind":"credit","id":V3.Credit.GRANT_ID})
	_compact_current(body.current)
	return _seal_v3(body,result.transaction_id,V6.digest(result.payload),captured.capture,_session.simulation.get_resolved_event_count(),started)

func cancel() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("minimal_requires_main_thread")
	if not _pending.is_empty() and _pending.uncertain: return fail("uncertain_operation_requires_reconciliation")
	if _closed: return {"success":true,"state":"canceled_requires_readmission","durable":false}
	if _v3:
		if not _session.get_actor_state(&"player").current_action_instance_id.is_empty(): return fail("minimal_action_pending")
		if not _pending.is_empty() and _requests != null:
			var canceled: Dictionary = _requests.cancel_capture()
			if not canceled.success: return canceled
		if _requests != null:
			var closed: Dictionary = _requests.close()
			if not closed.success: return closed
		_pending = {}; _closed = true; _revision += 1
		_simulation_status("canceled_requires_readmission")
		return {"success":true,"state":"canceled_requires_readmission","durable":false}
	var released: Dictionary = _gate.unbind()
	if not released.success: return released
	_pending = {}; _closed = true; _revision += 1
	_simulation_status("canceled_requires_readmission")
	return {"success":true,"state":"canceled_requires_readmission","durable":false}

func view() -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("minimal_requires_main_thread")
	return {"state":"closed" if _closed else "simulation_only","durable":false,"revision":_revision,"admission_cold_us":_admission_cold_us,"profile":_service.profile_id if _service != null else "","namespace":_service.mode if _service != null else "","body_json":_current.json() if _current != null else "","pending_operation":_pending.get("operation",""),"pending_text":_pending.get("text",""),"metrics":_metrics.duplicate(true)}

func simulate_automatic(value: bool) -> Dictionary:
	if _windows_route != null: return fail("windows_readback_owns_acknowledgement")
	if _browser_route != null: return fail("browser_readback_owns_acknowledgement")
	var context := _context()
	if not context.success: return context
	if _closed or has_pending(): return fail("minimal_operation_pending")
	_auto_simulate = value
	return {"success":true,"durable":false}

func _simulation_status(state: String) -> void:
	_service._status = {"persistent":false,"state":state,"reason":"dormant_simulation_only","text":"Simulation only — not saved"}

func dispose() -> Dictionary:
	if not _browser_phase.is_empty(): return fail("browser_publication_pending")
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return fail("minimal_requires_main_thread")
	if _v3 and not _pending.is_empty() and _pending.uncertain: return fail("uncertain_operation_requires_reconciliation")
	if _v3 and _gate != null:
		if not _closed:
			var canceled := cancel()
			if not canceled.success: return canceled
	elif _gate != null:
		var released: Dictionary = _gate.unbind()
		if not released.success: return released
	if _player != null and is_instance_valid(_player):
		if _player.get_parent() != null: _player.queue_free()
		else: _player.free()
	_player = null; _session = null; _service = null; _closed = true
	return {"success":true,"durable":false}

func fail(reason: String) -> Dictionary:
	return {"success":false,"state":"blocked","reason":reason,"durable":false}
