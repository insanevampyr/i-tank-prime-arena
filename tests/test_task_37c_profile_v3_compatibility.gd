extends "res://tests/test_task_37c_death_multiplayer_lifecycle.gd"

const Profile = preload("res://scripts/rewards/profile_v3_compatibility.gd")
const Legacy = preload("res://scripts/rewards/character_save_contract.gd")
var profile_heads := {}

func _authority(kind: String, record: Dictionary, identity: Dictionary) -> bool:
	if kind == "v3_expected_head": return profile_heads.get(identity.profile_id) == Contract.fingerprint(record)
	if kind == "v3_current_document": return profile_heads.get(identity.profile_id) == record.get("payload_digest")
	return super._authority(kind,record,identity)

func run() -> Array[String]:
	for test: Callable in [_test_legacy,_test_v3_roundtrip,_test_missing_and_conflicting,_test_publication_and_rollback,_test_party_completion,_test_progression_gate,_test_run_rebase,_test_resurrection_and_frozen,_test_final_wave_and_survivor]:
		approvals.clear()
		observed_heads.clear()
		profile_heads.clear()
		test.call()
	print("37C dormant Profile V3 compatibility: %d assertions; immutable V2 anchors, linked receipts, closed-exchange outcomes and publication simulation." % assertions)
	return failures

func _root(name: String = "v3_fixture") -> Dictionary:
	# Synthetic, independently attested contract fixture; NOT a new production character.
	var history := _participant(name)
	var identity: Dictionary = history.identity
	var attributes: Dictionary = history.origin.attributes.permanent.duplicate(true)
	var anchor := {"character_id":identity.profile_id,"definition_id":identity.character_id,"rules_revision":identity.rules_revision,"generation":1,
		"base_attributes":attributes,"xp":{"earned":12000,"spent":0,"unspent":12000},"purchases":[],"items":[],"secured_checkpoints":[],"settlements":[],"profile_namespace":"normal",
		"permanent":{"level":1,"growth":[],"resource_maxima":{"mana":120},"ability_allowances":{},"equipment_refs":[],"inventory_quantities":{},"xp_baseline":{"expm":12000,"expc":12000,"earned":0,"spent":0},"award_receipts":[]},
		"lineage":{"profile_id":identity.profile_id,"definition_id":identity.character_id,"rules_revision":identity.rules_revision,"run_id":"fixture_legacy_run","mode_history":["normal"],"baseline_digest":Contract.fingerprint(attributes)}}
	for definition: String in ["fixture_starting_potion","fixture_shield"]:
		var shield: bool = definition == "fixture_shield"
		var item := {"instance_id":identity.profile_id+"/original/"+definition,"definition_id":definition,"quantity":1 if shield else 2,"provenance":{"origin_id":"isolated_original_"+definition,"source_ref":"isolated registered fixture, not production items"},"equipped_slots":["shield"] if shield else [],"mutable_state":{"shp":7,"usable":true} if shield else {}}
		anchor.items.append(item)
		anchor.settlements.append(_typed_receipt(identity,"fixture_legacy_run","wave_1",definition,"item",{"instance_id":item.instance_id,"definition_id":definition,"quantity":item.quantity,"provenance_digest":Contract.fingerprint(item.provenance)}))
	anchor.permanent.equipment_refs = ["fixture_shield"]
	anchor.permanent.inventory_quantities = {"fixture_starting_potion":2}
	var encoded := Legacy.encode(anchor)
	check(encoded.success and Legacy.decode(encoded.text).version == 2,"Isolated source fixture is a valid existing V2 document.")
	_approve("v3_anchor",anchor,identity)
	profile_heads[identity.profile_id] = Contract.fingerprint({"legacy_anchor":encoded.text.sha256_text(),"generation":1})
	return {"history":history,"anchor":anchor,"document":encoded.text}

func _typed_receipt(identity: Dictionary, run: String, wave: String, claim: String, kind: String, content: Dictionary) -> Dictionary:
	return {"version":1,"receipt_id":"/".join([identity.profile_id,run,wave,claim]),"profile_id":identity.profile_id,"run_id":run,"wave_id":wave,"claim_id":claim,"kind":kind,"content":content}

func _snapshot(histories: Dictionary, exchange: String = "externally_verified_team_victory", enemies: bool = true, final: bool = false) -> Dictionary:
	var rows: Array = []
	var team := "fixture_team"
	var wave := "wave_3"
	var keys := histories.keys()
	keys.sort()
	for id: String in keys:
		var history: Dictionary = histories[id]
		var state: Dictionary = Contract.replay(history,_authority).state
		if not state.active_attempt.is_empty():
			team = state.active_attempt.team_id
			wave = state.active_attempt.checkpoint.wave_id
		rows.append({"profile_id":id,"namespace":history.identity.namespace,"generation":2,"event_head":state.head_hash,"life":state.life,"participation":state.participation})
	return {"team_id":team,"wave_id":wave,"exchange_id":exchange,"closed":true,"enemies_defeated":enemies,"final_wave":final,"participants":rows}

func _payload(root: Dictionary, history: Dictionary, previous: Dictionary = {}, completion_evidence: Dictionary = {}, gates: Array = []) -> Dictionary:
	var old_history: Dictionary = root.history if previous.is_empty() else previous.life_history
	var old_binding: Dictionary = {} if previous.is_empty() else previous.history_binding
	var prepared := _prepare(old_history,old_binding,history,"profile_"+str(1 if old_binding.is_empty() else old_binding.generation+1))
	var payload := {"prototype_version":3,"anchor_document":root.document,"anchor_sha256":root.document.sha256_text(),"generation":root.anchor.generation+prepared.binding.generation,
		"life_history":history.duplicate(true),"history_binding":prepared.binding,"settlement_links":[],"completion_links":[],"gate_links":gates.duplicate(true)}
	var prefix: Dictionary = history.duplicate(true)
	prefix.events = []
	for event: Dictionary in history.events:
		var before: Dictionary = Contract.replay(prefix,_authority).state
		if event.kind in ["attempt_begin","owned_state","reward_receipt"]: _approve("v3_ownership",event,history.identity)
		if event.kind == "reward_receipt": _approve("v3_reward_progression",event,history.identity)
		if event.kind == "attributes": _approve("v3_attribute_effect",event,history.identity)
		if event.kind == "wave_outcome" and completion_evidence.has(event.event_id):
			var snapshot: Dictionary = completion_evidence[event.event_id].duplicate(true)
			_approve("v3_exchange",snapshot,history.identity)
			for row: Dictionary in snapshot.participants: _approve("v3_peer_head",row,history.identity)
			payload.completion_links.append({"event_id":event.event_id,"evidence":snapshot})
		if event.kind in ["emergency_receipt","reward_receipt"]:
			var checkpoint: Dictionary = before.active_attempt.checkpoint
			var receipts: Array = []
			if event.kind == "emergency_receipt": receipts.append(_typed_receipt(history.identity,checkpoint.run_id,checkpoint.wave_id,"purchase_"+str(event.sequence),"purchase",{"purchase_id":event.data.receipt.transaction_id,"cost":event.data.receipt.cost_expc}))
			else:
				receipts.append(_typed_receipt(history.identity,checkpoint.run_id,checkpoint.wave_id,"xp_"+str(event.sequence),"xp",{"award_id":event.data.receipt_id,"amount":event.data.expc_after-event.data.expc_before}))
				if event.data.owned_before != event.data.owned_after: receipts.append(_typed_receipt(history.identity,checkpoint.run_id,checkpoint.wave_id,"gold_"+str(event.sequence),"currency",{"instance_id":event.data.receipt_id+"/currency","definition_id":"isolated_currency","quantity":17,"provenance_digest":Contract.fingerprint(event)}))
			for receipt: Dictionary in receipts: _approve("v3_settlement",receipt,history.identity)
			_approve("v3_ownership_settlement",{"event":event,"receipts":receipts},history.identity)
			payload.settlement_links.append({"event_id":event.event_id,"receipts":receipts})
		prefix.events.append(event.duplicate(true))
	for gate: Dictionary in gates:
		if gate.kind == "new_run": _approve("v3_run_rebase",gate.evidence,history.identity)
		else:
			_approve("v3_exchange",gate.evidence,history.identity)
			for row: Dictionary in gate.evidence.participants: _approve("v3_peer_head",row,history.identity)
	return payload

func _publish(payload: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var expected: int = Legacy.decode(payload.anchor_document).payload.generation if previous.is_empty() else previous.generation
	var result := Profile.prepare(previous,payload,expected,payload.history_binding.transaction_id,_authority)
	check(result.success and not result.published,"Coordinator simulation prepares a source-verified candidate without I/O.")
	if not result.success: return {}
	var readback := {"document":result.prepared.document,"transaction_id":result.prepared.transaction_id,"generation":payload.generation,"transaction_completed":true}
	profile_heads[payload.life_history.identity.profile_id] = Contract.fingerprint(payload)
	_approve("v3_committed_readback",{"prepared":result.prepared,"readback":readback},payload.life_history.identity)
	check(Profile.acknowledge(result.prepared,readback,_authority).success,"Exact completed-transaction fixture readback is verified.")
	profile_heads[payload.life_history.identity.profile_id] = Contract.fingerprint(payload)
	_approve("head",payload.history_binding,payload.life_history.identity)
	observed_heads[Contract.fingerprint(payload.life_history.identity)] = Contract.fingerprint(payload.history_binding)
	return result.prepared

func _test_legacy() -> void:
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","normal")
	check(starter.success,"Existing authored starter can be prepared in memory without saving.")
	var document: String = starter.prepared.document
	var copy: Dictionary = starter.prepared.payload.duplicate(true)
	var inspected := Profile.inspect_legacy(document)
	check(inspected.success and inspected.status == "legacy_extension_absent" and inspected.preserved_document == document and inspected.payload == copy and not inspected.migrated,"Actual V2 starter is accepted read-only without migration, relabeling or rewriting.")
	var v1: Dictionary = preload("res://tests/test_task_36d_character_save_contract.gd").new()._fixture()
	check(Profile.inspect_legacy(Legacy.encode(v1).text).success,"Existing V1 fixtures remain readable; no V3 history is invented.")
	var root := _root()
	var unknown: Dictionary = JSON.parse_string(root.document)
	var body: Dictionary = Legacy.decode(root.document).payload
	body["unknown_legacy_extension"] = {"original":"must survive"}
	unknown.payload_json = Contract.canonical(body)
	unknown.sha256 = unknown.payload_json.sha256_text()
	var text := Contract.canonical(unknown)
	var preserved := Profile.inspect_legacy(text)
	check(not preserved.success and preserved.preserved_document == text,"Unknown unsupported legacy fields are quarantined verbatim, never stripped to force acceptance.")
	check(starter.prepared.payload == copy,"Legacy inspection never mutates the original profile.")
	var opaque := v1.duplicate(true)
	opaque.items[0].mutable_state["unknown_annotation"] = {"preserve":"verbatim"}
	var original: String = Legacy.encode(opaque).text
	check(Profile.inspect_legacy(original).preserved_document == original,"Allowed opaque legacy metadata is preserved exactly without destructive normalization.")

func _test_v3_roundtrip() -> void:
	var root := _root()
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"str":-3,"wis":0}))
	history = _purchase(history,"str","negative_step")
	var payload := _payload(root,history)
	var preserved := payload.duplicate(true)
	var checked := Profile.validate(payload,_authority)
	check(checked.success and checked.state.life == "dead" and checked.state.attributes.permanent.str == -2 and checked.ledger_projection.available_expc == 10000,"V3 preserves death, signed permanent loss and the one-wallet receipt balance.")
	var encoded := Profile.encode(payload,_authority)
	var decoded := Profile.decode(encoded.text,_authority)
	check(decoded.success and decoded.payload == payload and decoded.state == checked.state and Profile.encode(decoded.payload,_authority).text == encoded.text,"Canonical V3 envelope roundtrips without rerolling or modifying history.")
	check(payload == preserved and checked.legacy_document == root.document,"V3 validation preserves its immutable V2 anchor byte for byte.")
	check(not Legacy.decode(encoded.text).success,"Production Save Contract V2 still rejects version3; no activation occurred.")
	check(checked.storage_writes == 0 and Profile.validate(payload,Callable()).success == false,"No writes or authority-free acceptance.")

func _test_missing_and_conflicting() -> void:
	var root := _root()
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"wis":0}))
	history = _purchase(history,"wis","recovery")
	var good := _payload(root,history)
	check(Profile.validate(good,_authority).success,"Independent valid receipt-linked fixture is accepted.")
	for field: String in Profile.FIELDS:
		var bad := good.duplicate(true)
		bad.erase(field)
		check(not Profile.validate(bad,_authority).success,"Every proposed V3 field is explicit.")
	for field: String in ["event_head","history_digest"]:
		var bad := good.duplicate(true)
		bad.history_binding[field] = "0".repeat(64)
		check(not Profile.validate(bad,_authority).success,"Conflicting event/history heads fail closed.")
	var bad := good.duplicate(true)
	bad.history_binding.previous_binding_hash = "0".repeat(64)
	check(not Profile.validate(bad,_authority).success,"The first relative binding must descend from the verified empty history-binding root.")
	bad = good.duplicate(true)
	bad.settlement_links = []
	check(not Profile.validate(bad,_authority).success,"Every emergency debit requires a linked existing receipt.")
	bad = good.duplicate(true)
	bad.settlement_links.append(bad.settlement_links[0].duplicate(true))
	check(not Profile.validate(bad,_authority).success,"Duplicate link identities fail closed.")
	bad = good.duplicate(true)
	bad.settlement_links[0].receipts.append(bad.settlement_links[0].receipts[0].duplicate(true))
	check(not Profile.validate(bad,_authority).success,"Duplicated transaction/receipt identities cannot create a payout.")
	bad = good.duplicate(true)
	bad.generation = 1
	check(not Profile.validate(bad,_authority).success,"Profile generation must explicitly include its immutable anchor offset.")
	bad = good.duplicate(true)
	bad.anchor_sha256 = "0".repeat(64)
	check(not Profile.validate(bad,_authority).success,"Anchor corruption is rejected.")
	bad = good.duplicate(true)
	bad.life_history.events.reverse()
	check(not Profile.validate(bad,_authority).success,"Reordered network/history events cannot be replayed as a valid sequence.")
	check(not Profile.decode("x".repeat(Contract.MAX_BYTES+1),_authority).success,"Oversized input is rejected before JSON parsing.")

func _test_publication_and_rollback() -> void:
	var root := _root()
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"str":-1}))
	history = _purchase(history,"str","attempt_purchase")
	var first := _payload(root,history)
	var prepared := _publish(first)
	check(first.generation == 2 and first.history_binding.generation == 1,"First V3 generation rebases on the existing V2 generation without reset.")
	var rollback := _rollback_event(history,"restart")
	check(not Contract.append(history,rollback,_authority).success,"Unapproved historical rollback cannot be accepted.")
	var restored := _added(history,rollback)
	var second := _payload(root,restored,first)
	var plan := Profile.prepare(first,second,2,second.history_binding.transaction_id,_authority)
	check(plan.success,"Authorized cancellation advances the same generation chain despite net EXPC restoration.")
	var pending := {"document":plan.prepared.document,"transaction_id":plan.prepared.transaction_id,"generation":3,"transaction_completed":false}
	var malformed: Dictionary = plan.prepared.duplicate(true)
	malformed.expected_generation = "2"
	check(not Profile.acknowledge(malformed,pending,_authority).success,"Malformed acknowledgement counters fail closed without arithmetic coercion.")
	check(not Profile.acknowledge(plan.prepared,pending,_authority).success,"Queued/interrupted transaction is not a committed acknowledgement.")
	pending.transaction_completed = true
	check(not Profile.acknowledge(plan.prepared,pending,_authority).success,"An unverified success flag is insufficient.")
	_publish(second,first)
	_approve("v3_committed_readback",{"prepared":plan.prepared,"readback":pending},second.life_history.identity)
	check(Profile.acknowledge(plan.prepared,pending,_authority).success and Profile.acknowledge(plan.prepared,pending,_authority).success,"Repeated exact acknowledgement observes one commit; it does not execute another refund.")
	var state: Dictionary = Profile.validate(second,_authority).state
	check(state.available_expc == 12000 and state.life == "alive" and state.discarded_attempts.size() == 1 and second.settlement_links == first.settlement_links,"Restart restores attempt EXPC/death while preserving the old receipt and cancellation history.")
	check(not Profile.prepare(first,second,2,second.history_binding.transaction_id,_authority).success,"Stale previously committed storage head fails even with a matching old expected number.")
	var stale := second.duplicate(true)
	stale.life_history = root.history.duplicate(true)
	check(not Profile.prepare(second,stale,3,stale.history_binding.transaction_id,_authority).success,"Replacing history with an old checkpoint is not authorized rollback.")
	check(not Profile.prepare_cohort([first,second]).success,"No multi-profile atomic publisher is invented.")
	check(prepared.document == Profile.encode(first,_authority).text,"Crash/readback keeps the original immutable document exact.")
	var old_readback := {"document":prepared.document,"transaction_id":prepared.transaction_id,"generation":first.generation,"transaction_completed":true}
	check(not Profile.acknowledge(prepared,old_readback,_authority).success,"A committed historical generation cannot be promoted over the latest pointer.")
	var forged := second.duplicate(true)
	forged.life_history = root.history.duplicate(true)
	forged.settlement_links = []
	forged.generation = second.generation+1
	forged.history_binding.generation += 1
	forged.history_binding.event_count = 0
	forged.history_binding.event_head = Contract.replay(root.history,_authority).state.head_hash
	forged.history_binding.history_digest = Contract.fingerprint(root.history)
	forged.history_binding.previous_binding_hash = Contract.fingerprint(second.history_binding)
	forged.history_binding.transaction_id = Contract._prefix(root.history.identity)+"/publication/unauthorized_reset"
	forged.history_binding.publication_ids.append(forged.history_binding.transaction_id)
	check(Profile.validate(forged,_authority).success,"A historical prefix may be structurally valid; it is not authorized current-state replacement.")
	check(Profile.prepare(second,forged,second.generation,forged.history_binding.transaction_id,_authority).get("reason") == "unauthorized_history_rollback","Coordinator continuity rejects a fabricated newer generation that truncates history.")

func _test_party_completion() -> void:
	var expected_defeat := {}
	for order: Array in [["victim","teammate"],["teammate","victim"]]:
		var root := _root("victim")
		var other := _root("teammate")
		var party := {"prod_victim":_begin(root.history),"prod_teammate":_begin(other.history)}
		check(not Contract.party_view(party,true,false,_authority).success,"Enemy-first delivery cannot grant an early victory without completion evidence.")
		for name: String in order:
			var id := "prod_"+name
			party[id] = _added(party[id],_event(party[id],"hpc_death",{"source_event_id":Contract._prefix(party[id].identity)+"/damage/simultaneous","source_ref":"verified closed-exchange death"}))
		var defeat := Contract.party_view(party,true,false,_authority)
		if expected_defeat.is_empty(): expected_defeat = defeat.duplicate(true)
		check(defeat == expected_defeat and Contract.party_view(party,false,false,_authority).team_defeated,"Player-first or enemy-first closure and either player-death order produce identical all-party defeat.")
		var snapshot := _snapshot(party,"wipe_exchange")
		var history: Dictionary = party.prod_victim
		var outcome := _event(history,"wave_outcome",{"attempt_id":Contract.replay(history,_authority).state.active_attempt.attempt_id,"team_won":false,"final_wave":false,"outcome_ref":"wipe_exchange"})
		history = _added(history,outcome)
		var payload := _payload(root,history,{}, {outcome.event_id:snapshot})
		check(Profile.validate(payload,_authority).success and not Contract.replay(history,_authority).state.wave_outcomes.back().reward_eligible,"Either death order validates defeat with zero victory rewards despite final-enemy death.")
		var unfinished := payload.duplicate(true)
		unfinished.completion_links[0].evidence.closed = false
		check(not Profile.validate(unfinished,_authority).success,"Enemy-first evidence cannot authorize completion before the whole exchange closes.")
		var duplicate := payload.duplicate(true)
		duplicate.completion_links.append(duplicate.completion_links[0].duplicate(true))
		check(not Profile.validate(duplicate,_authority).success,"Duplicate combat-completion evidence cannot pay or advance twice.")
		var bad_history: Dictionary = party.prod_victim
		var false_win := outcome.duplicate(true)
		false_win.data.team_won = true
		bad_history = _added(bad_history,false_win)
		check(not Profile.validate(_payload(root,bad_history,{}, {false_win.event_id:snapshot}),_authority).success,"An all-party victory claim is rejected, never repaired into free rewards.")
		check(Contract.party_view(party,true,false,_authority).team_defeated and not Contract.party_view(party,true,false,_authority).next_wave_allowed,"Lifecycle itself gives wipe priority without requiring a fabricated victory event.")
		_reject(history,_event(history,"wave_outcome",outcome.data),"wave_outcome_conflict")
	var root := _root("victim")
	var other := _root("teammate")
	var dead := _begin(root.history)
	var alive := _begin(other.history)
	dead = _added(dead,_attribute_event(dead,{"wis":0}))
	var evidence := _snapshot({"prod_victim":dead,"prod_teammate":alive})
	dead = _outcome(dead)
	var id: String = dead.events.back().event_id
	check(Profile.validate(_payload(root,dead,{}, {id:evidence}),_authority).success,"A successful team may preserve a dead, reward-excluded teammate between waves.")
	var departed := _added(dead,_rollback_event(dead,"departure_after_victory"))
	check(Profile.validate(_payload(root,departed,{}, {id:evidence}),_authority).state.participation == "left","Personal departure validates its own rollback without rewriting the surviving profile.")
	check(other.history.events.is_empty(),"Surviving teammate source/profile is untouched by another character's publication.")

func _test_progression_gate() -> void:
	var root := _root("victim")
	var other := _root("teammate")
	var own := _begin(root.history)
	var teammate := _begin(other.history)
	teammate = _added(teammate,_attribute_event(teammate,{"wis":0}))
	var completion := _snapshot({"prod_victim":own,"prod_teammate":teammate})
	own = _outcome(own)
	var event_id: String = own.events.back().event_id
	var state: Dictionary = Contract.replay(own,_authority).state
	own = _added(own,_event(own,"attempt_commit",{"attempt_id":state.active_attempt.attempt_id,"outcome_ref":state.active_attempt.outcome.outcome_ref}))
	var before := own.duplicate(true)
	own = _begin(own,"next","wave_4")
	var gate_id: String = own.events.back().event_id
	var snapshot := _snapshot({"prod_victim":before,"prod_teammate":teammate})
	var gates := [{"event_id":gate_id,"kind":"next_wave","evidence":snapshot}]
	var blocked := Profile.validate(_payload(root,own,{}, {event_id:completion},gates),_authority)
	check(not blocked.success and blocked.reason == "dead_teammate_blocks_advancement","A verified successful wave cannot advance with an unresolved dead teammate.")
	check(not Profile.validate(_payload(root,own,{}, {event_id:completion}),_authority).success,"Missing multiplayer progression evidence fails closed.")
	teammate = _outcome(teammate)
	teammate = _added(teammate,_rollback_event(teammate,"departure_after_victory"))
	var departed_snapshot := _snapshot({"prod_victim":before,"prod_teammate":teammate})
	var allowed_gate := [{"event_id":gate_id,"kind":"next_wave","evidence":departed_snapshot}]
	check(Profile.validate(_payload(root,own,{}, {event_id:completion},allowed_gate),_authority).success,"Verified personal departure removes the progression block without rolling back the survivor.")

func _test_run_rebase() -> void:
	var root := _root()
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"str":0}))
	history = _added(history,_rollback_event(history,"return"))
	var first := _payload(root,history)
	_publish(first)
	var before: Dictionary = Contract.replay(history,_authority).state
	var next_history := _begin(history,"new_run","wave_1")
	var begin: Dictionary = next_history.events.back().duplicate(true)
	begin.data.checkpoint.run_id = "explicit_new_run"
	_approve("checkpoint",begin.data.checkpoint,history.identity)
	next_history = _added(history,begin)
	var link := {"event_id":begin.event_id,"kind":"new_run","evidence":{"previous_run":"fixture_existing_run","next_run":"explicit_new_run","wave_id":"wave_1","subject_head":before.head_hash}}
	var candidate := _payload(root,next_history,first,{},[link])
	check(Profile.validate(candidate,_authority).success and candidate.generation == 3 and candidate.anchor_sha256 == first.anchor_sha256,"Explicit run rebasing preserves global generations, profile identity and original receipts/anchor.")
	check(not Profile.validate(_payload(root,next_history,first),_authority).success,"Changing runs without source-qualified rebase evidence is rejected.")
	var wrong := candidate.duplicate(true)
	wrong.generation = 1
	check(not Profile.validate(wrong,_authority).success,"A new run cannot reset the character's durable generation.")

func _test_resurrection_and_frozen() -> void:
	var root := _root("victim")
	var other := _root("teammate")
	var history := _begin(root.history)
	var peer := _begin(other.history)
	history = _added(history,_attribute_event(history,{"wis":0}))
	var evidence := _snapshot({"prod_victim":history,"prod_teammate":peer})
	history = _outcome(history)
	var outcome_id: String = history.events.back().event_id
	history = _purchase(history,"wis","between_recovery")
	history = _added(history,_completion(history,"between_waves"))
	var payload := _payload(root,history,{}, {outcome_id:evidence})
	check(Profile.validate(payload,_authority).success and Profile.validate(payload,_authority).state.life == "alive","V3 accepts verified four-Act/50-Mana completion after separately purchased recovery.")
	var bad := payload.duplicate(true)
	bad.life_history.events.back().data.erase("completion")
	_approve("event",bad.life_history.events.back(),bad.life_history.identity)
	check(not Profile.validate(bad,_authority).success,"A resurrection lacking action/cost evidence is rejected before hydration.")
	var frozen_root := _root("frozen")
	var frozen := _begin(frozen_root.history)
	frozen = _added(frozen,_attribute_event(frozen,{"wis":0}))
	var boost := _attribute_event(frozen,{"wis":2},"temporary")
	boost.data.sources[0].remaining_duration_us = 2000
	frozen = _added(frozen,boost)
	frozen = _added(frozen,_event(frozen,"effect_time",{"elapsed_us":999999,"frozen":true}))
	var frozen_payload := _payload(frozen_root,frozen)
	var checked := Profile.validate(frozen_payload,_authority)
	check(checked.success and checked.state.life == "dead" and checked.state.attribute_eligible and checked.state.source_remaining_us[boost.data.sources[0].source_id] == 2000,"Frozen V3 checkpoint keeps duration/effective eligibility without auto-revival.")
	check(Profile.decode(Profile.encode(frozen_payload,_authority).text,_authority).state == checked.state,"Source-qualified duration and dead status survive exact canonical roundtrip.")
	var before := frozen_payload.duplicate(true)
	var simulation := CombatSimulation.new(373)
	simulation.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"))
	var snapshot := simulation.get_state_snapshot()
	Profile.validate(frozen_payload,_authority)
	check(frozen_payload == before and snapshot == simulation.get_state_snapshot() and snapshot.schema_version == 12,"V3 prototype is read-only and cannot mutate schema12, combat or RNG.")

func _test_final_wave_and_survivor() -> void:
	var root := _root("victim")
	var other := _root("teammate")
	var dead := _begin(root.history,"final","wave_5")
	var alive := _begin(other.history,"final","wave_5")
	dead = _added(dead,_event(dead,"hpc_death",{"source_event_id":Contract._prefix(dead.identity)+"/damage/final","source_ref":"externally verified HPC death"}))
	var evidence := _snapshot({"prod_victim":dead,"prod_teammate":alive},"externally_verified_team_victory",true,true)
	dead = _outcome(dead,true)
	alive = _outcome(alive,true)
	var dead_outcome: String = dead.events.back().event_id
	var alive_outcome: String = alive.events.back().event_id
	alive = _added(alive,_reward_event(alive))
	var state: Dictionary = Contract.replay(alive,_authority).state
	alive = _added(alive,_event(alive,"attempt_commit",{"attempt_id":state.active_attempt.attempt_id,"outcome_ref":state.active_attempt.outcome.outcome_ref}))
	var living_payload := _payload(other,alive,{}, {alive_outcome:evidence})
	check(Profile.validate(living_payload,_authority).success,"Existing V1 reward/item receipts join the survivor's independently committed projection.")
	_publish(living_payload)
	var retained := living_payload.duplicate(true)
	dead = _added(dead,_rollback_event(dead,"final_wave_dead"))
	var failed_payload := _payload(root,dead,{}, {dead_outcome:evidence})
	var failed := Profile.validate(failed_payload,_authority)
	check(failed.success and failed.state.life == "alive" and failed.state.participation == "left" and failed.state.available_expc == 12000 and failed.state.reward_receipts.is_empty(),"Final-wave dead rollback preserves the exact pre-attempt profile without completion rewards.")
	check(living_payload == retained and Profile.validate(living_payload,_authority).state.available_expc == 12100,"Dead-member recovery cannot alter the survivor's independently secured rewards.")
	var missing := living_payload.duplicate(true)
	missing.settlement_links[0].receipts.pop_back()
	check(not Profile.validate(missing,_authority).success,"Ownership changes require typed item/currency evidence, not just an XP receipt.")
