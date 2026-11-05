extends RefCounted

const Contract = preload("res://scripts/combat/life_state_history_contract.gd")
const Evaluator = preload("res://scripts/combat/dead_attribute_evaluator.gd")
var failures: Array[String] = []
var assertions := 0
var approvals := {}
var observed_heads := {}

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)

func _authority(kind: String, record: Dictionary, identity: Dictionary) -> bool:
	if kind == "empty_head": return not observed_heads.has(Contract.fingerprint(identity))
	if kind == "current_head": return observed_heads.get(Contract.fingerprint(identity)) == Contract.fingerprint(record)
	return approvals.has(Contract.fingerprint({"kind":kind,"record":record,"identity":identity}))

func _approve(kind: String, record: Dictionary, identity: Dictionary) -> void:
	approvals[Contract.fingerprint({"kind":kind,"record":record,"identity":identity})] = true

func _fixture(expc: int = 5000, undead: bool = false) -> Dictionary:
	var attributes := {}
	for name: String in Evaluator.PRIMARIES: attributes[name] = 10
	if undead:
		var source: CombatCharacterDefinitionResource = load("res://data/characters/prime_v3_common_skelly.tres")
		attributes = source.attributes.duplicate(true)
	var identity := {"profile_id":"prod_isolated","namespace":"normal","character_id":"isolated_skelly" if undead else "isolated_living","rules_revision":"prime_v3_owner_dead_v2","history_id":"fixture_history"}
	var origin := {"classification":{"kind":"authored_undead" if undead else "living","source_ref":"isolated authored fixture" if not undead else "data/characters/prime_v3_common_skelly.tres","authored_attributes":attributes.duplicate(true),"initial_zero_exceptions":["wis","int"] if undead else []},
		"attributes":{"permanent":attributes.duplicate(true),"effective":attributes.duplicate(true)},"available_expc":expc}
	_approve("origin",origin,identity)
	var created := Contract.create(identity,origin,_authority)
	check(created.success,"Valid isolated origin must initialize without changing an actor.")
	return created.get("history",{})

func _event(history: Dictionary, kind: String, data: Dictionary) -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	var sequence: int = state.sequence+1
	return {"event_id":Contract._prefix(history.identity)+"/event/"+str(sequence),"sequence":sequence,"parent_hash":state.head_hash,
		"order":{"timestamp_us":sequence*100,"resolution_index":sequence},"kind":kind,"data":data.duplicate(true)}

func _attribute_event(history: Dictionary, values: Dictionary, kind: String = "permanent") -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	var before: Dictionary = state.attributes
	var after := before.duplicate(true)
	for attribute: String in values:
		after.effective[attribute] = values[attribute]
		if kind == "permanent": after.permanent[attribute] = values[attribute]
	var sources := [{"source_id":"fixture/source/"+str(history.events.size()+1),"source_ref":"explicit verified fixture mutation","kind":"permanent" if kind == "permanent" else "temporary","attributes":values.keys()}]
	if kind == "effect_expiration":
		for source: Dictionary in state.active_sources.values():
			if source.attributes == values.keys():
				sources = [source.duplicate(true)]
				break
	return _event(history,"attributes",{"change_kind":kind,"before":before.duplicate(true),"after":after,"sources":sources})

func _added(history: Dictionary, event: Dictionary) -> Dictionary:
	_approve("event",event,history.identity)
	var result := Contract.append(history,event,_authority)
	check(result.success,"Authorized valid event must append: "+str(result.get("reason","")))
	return result.get("history",history)

func _receipt_event(history: Dictionary, attribute: String, suffix: String) -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	var before: Dictionary = state.attributes
	var after := before.duplicate(true)
	after.permanent[attribute] = 1
	after.effective[attribute] = 1
	var prefix := Contract._prefix(history.identity)
	return _event(history,"emergency_receipt",{"change_kind":"recovery","before":before.duplicate(true),"after":after,
		"sources":[{"source_id":prefix+"/source/"+suffix,"source_ref":"externally committed fixture receipt; no live purchase","kind":"permanent","attributes":[attribute]}],
		"receipt":{"transaction_id":prefix+"/transaction/"+suffix,"debit_receipt_id":prefix+"/debit/"+suffix,"attribute":attribute,"cost_expc":2000,"expc_before":state.available_expc,"expc_after":state.available_expc-2000}})

func _resurrection_event(history: Dictionary, suffix: String = "one") -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	return _event(history,"resurrection",{"effect_id":"externally_verified_fixture_effect","authorization_id":Contract._prefix(history.identity)+"/authorization/"+suffix,"death_event_id":state.deaths.back().event_id})

func _reject(history: Dictionary, event: Dictionary, reason: String) -> void:
	var before := history.duplicate(true)
	_approve("event",event,history.identity) # Structural/accounting checks must still reject trusted malformed requests.
	var result := Contract.append(history,event,_authority)
	check(not result.success and result.reason == reason,"Reject without partial application: "+reason+"; actual="+str(result.get("reason","")))
	check(history == before and not result.has("state") and not result.has("history"),"Failed replay/append cannot expose partial candidate state.")

func run() -> Array[String]:
	for test: Callable in [_test_transitions_and_roundtrip,_test_sources_and_undead,_test_transactions_and_recovery,_test_invalid_and_authority,_test_purity_and_compatibility,_test_durable_pricing,_test_generation_retention,_test_frozen_duration,_test_negative_recovery,_test_recovery_totals,_test_negative_durability]:
		approvals.clear()
		observed_heads.clear()
		test.call()
	print("37C dormant life-state/history: %d assertions; immutable transitions, receipt observation, serialization, recovery classification and replay." % assertions)
	return failures

func _test_transitions_and_roundtrip() -> void:
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		for kind: String in ["permanent","temporary"]:
			for value: int in [0,-2]:
				var history := _fixture()
				history = _added(history,_attribute_event(history,{attribute:value},kind))
				var result := Contract.replay(history,_authority)
				check(result.success and result.state.life == "dead" and result.state.deaths.size() == 1 and result.state.deaths[0].attributes == [attribute],"Every lethal crossing records exact cause once.")
				check(result.state.attributes.effective[attribute] == value and result.state.resurrection_barriers == [attribute],"Signed lethal values remain exact in state and barriers.")
				var encoded := Contract.encode(history,_authority)
				var decoded := Contract.decode(encoded.text,_authority)
				check(decoded.success and decoded.history == history and decoded.state == result.state,"Permanent/temporary loss and death roundtrip, including negative scores.")
				check(Contract.encode(decoded.history,_authority).text == encoded.text,"Repeated serialization must be canonical and exact.")
	for attribute: String in ["spd","dex","luk","app","man"]:
		var history := _fixture()
		history = _added(history,_attribute_event(history,{attribute:-1}))
		check(Contract.replay(history,_authority).state.life == "alive","No invented lethal rule for other primaries.")
	var history := _fixture()
	history = _added(history,_attribute_event(history,{"str":0,"wis":0}))
	var state: Dictionary = Contract.replay(history,_authority).state
	check(state.deaths.size() == 1 and state.deaths[0].attributes == ["str","wis"] and state.resurrection_barriers == ["str","wis"],"Simultaneous mutation records one death and every causal primary in fixed order.")
	_reject(history,_resurrection_event(history),"resurrection_not_eligible")
	history = _added(history,_receipt_event(history,"str","str_recovery"))
	history = _added(history,_receipt_event(history,"wis","wis_recovery"))
	state = Contract.replay(history,_authority).state
	check(state.life == "dead" and state.attribute_eligible and state.available_expc == 1000 and state.receipts.size() == 2,"Authorized isolated receipts preserve affordability and never revive.")
	var resurrect := _resurrection_event(history)
	check(not Contract.append(history,resurrect,_authority).success,"A self-asserted resurrection effect is not authorization.")
	var unrelated := resurrect.duplicate(true)
	unrelated.data.death_event_id = "unrelated_death"
	_reject(history,unrelated,"resurrection_not_eligible")
	history = _added(history,resurrect)
	state = Contract.replay(history,_authority).state
	check(state.life == "alive" and state.resurrections.size() == 1 and state.available_expc == 1000,"Only externally authorized explicit resurrection changes life, without a resource grant.")
	_reject(history,resurrect,"duplicate_event")
	_reject(history,_resurrection_event(history,"while_alive"),"resurrection_not_eligible")
	history = _added(history,_attribute_event(history,{"wis":-1},"temporary"))
	history = _added(history,_attribute_event(history,{"wis":1},"effect_expiration"))
	state = Contract.replay(history,_authority).state
	check(state.life == "dead" and state.attribute_eligible and state.deaths.size() == 2,"Explicit penalty expiration removes barrier, never a previous death.")
	_reject(history,_resurrection_event(history),"invalid_or_duplicate_resurrection_authority")
	history = _added(history,_resurrection_event(history,"two"))
	check(Contract.replay(history,_authority).state.resurrections.size() == 2,"Distinct externally authorized resurrection can occur after a distinct death.")
	var positive := _fixture()
	positive = _added(positive,_attribute_event(positive,{"wis":0}))
	positive = _added(positive,_attribute_event(positive,{"wis":2},"temporary"))
	state = Contract.replay(positive,_authority).state
	check(state.life == "dead" and state.attributes.permanent.wis == 0 and state.attribute_eligible,"Permanent zero/effective positive permits attribute eligibility but does not revive.")
	positive = _added(positive,_resurrection_event(positive))
	positive = _added(positive,_attribute_event(positive,{"wis":0},"effect_expiration"))
	check(Contract.replay(positive,_authority).state.deaths.size() == 2,"Expiration after resurrection re-evaluates the actual effective threshold.")

func _test_sources_and_undead() -> void:
	var history := _fixture()
	var event := _attribute_event(history,{"wis":0})
	event.data.sources = []
	_reject(history,event,"attribute_sources_incomplete")
	event = _attribute_event(history,{"wis":0})
	event.data.sources[0].kind = "temporary"
	_reject(history,event,"attribute_sources_incomplete")
	event = _attribute_event(history,{"wis":0},"temporary")
	event.data.after.permanent.wis = 0
	_reject(history,event,"temporary_change_altered_permanent")
	var active := _added(history,_attribute_event(history,{"wis":0},"temporary"))
	var repeated := _attribute_event(active,{"wis":-1},"temporary")
	repeated.data.sources = active.events[0].data.sources.duplicate(true)
	_reject(active,repeated,"temporary_source_already_active")
	var expiration := _attribute_event(active,{"wis":10},"effect_expiration")
	var expired := _added(active,expiration)
	check(Contract.replay(expired,_authority).state.active_sources.is_empty(),"Explicit expiration retires the exact active source without running a timer.")
	var missing := _attribute_event(history,{"wis":9},"effect_expiration")
	_reject(history,missing,"expiration_source_history_conflict")
	var wrong := expiration.duplicate(true)
	wrong.data.sources[0].source_ref = "different source"
	_reject(active,wrong,"expiration_source_history_conflict")
	var mixed := _attribute_event(history,{"str":0})
	mixed.data.after.effective.wis = 0
	mixed.data.sources.append({"source_id":"fixture/mixed_wis","source_ref":"verified simultaneous temporary mutation","kind":"temporary","attributes":["wis"]})
	var simultaneous := _added(history,mixed)
	var mixed_state: Dictionary = Contract.replay(simultaneous,_authority).state
	check(mixed_state.deaths[0].attributes == ["str","wis"] and mixed_state.attributes.permanent.wis == 10 and mixed_state.active_sources.has("fixture/mixed_wis"),"One atomic event can retain distinct permanent and temporary causal sources.")
	simultaneous = _added(simultaneous,_attribute_event(simultaneous,{"wis":10},"effect_expiration"))
	check(Contract.replay(simultaneous,_authority).state.resurrection_barriers == ["str"],"Expiring one source does not erase an independent permanent barrier.")
	history = _fixture(5000,true)
	check(Contract.replay(history,_authority).state.life == "alive","Actual Skelly initial authored zeros remain admitted.")
	history = _added(history,_attribute_event(history,{"str":0}))
	var state: Dictionary = Contract.replay(history,_authority).state
	check(state.life == "dead" and state.resurrection_barriers == ["str"],"Full history proves unchanged authored WIS/INT exceptions after a separate death.")
	history = _added(history,_receipt_event(history,"str","undead_str"))
	history = _added(history,_resurrection_event(history))
	history = _added(history,_attribute_event(history,{"wis":1},"temporary"))
	history = _added(history,_attribute_event(history,{"wis":0},"effect_expiration"))
	state = Contract.replay(history,_authority).state
	check(state.life == "dead" and state.deaths.size() == 2 and state.resurrection_barriers == ["wis"] and state.authored_exceptions == ["int"],"A subsequent positive-to-zero transition retires immunity; untouched INT remains protected.")
	var encoded := Contract.encode(history,_authority)
	check(Contract.decode(encoded.text,_authority).state == state,"Authored-exception retirement and death evidence survive roundtrip.")

func _test_transactions_and_recovery() -> void:
	var entry := _fixture()
	var failed_wave := _added(entry,_attribute_event(entry,{"str":0}))
	var event := _receipt_event(failed_wave,"str","recovery")
	_approve("event",event,failed_wave.identity)
	check(Contract.reconcile(failed_wave,event,_authority).status == "not_recorded","Interrupted before publication is absent, not a debit or automatic retry.")
	var committed := _added(failed_wave,event)
	var encoded := Contract.encode(committed,_authority)
	var reopened := Contract.decode(encoded.text,_authority)
	check(reopened.success and reopened.state.available_expc == 3000 and reopened.state.attributes.permanent.str == 1 and reopened.state.life == "dead","Isolated reload preserves permanent recovery, receipt balance and death.")
	check(Contract.reconcile(reopened.history,event,_authority).status == "recorded","Lost acknowledgement reconciles an exact recorded event without a second application.")
	_reject(reopened.history,event,"duplicate_event")
	var conflict := event.duplicate(true)
	conflict.data.receipt.expc_after = 2999
	check(not Contract.reconcile(reopened.history,conflict,_authority).success,"Lost-ack payload conflict cannot be treated as exact retry.")
	var entry_reloaded: Dictionary = Contract.decode(Contract.encode(entry,_authority).text,_authority).history
	for boundary: String in ["RETRY","RETURN","crash"]:
		var classified := Contract.compare_recovery(reopened.history,entry_reloaded,_authority)
		check(classified.success and classified.classification == "explicit_attempt_rollback_required" and not classified.applied,boundary+" needs an authorized discard event rather than truncating audit history.")
	check(Contract.compare_recovery(committed,reopened.history,_authority).classification == "exact","Reload of the same committed boundary is exact.")
	check(Contract.compare_recovery(entry,committed,_authority).classification == "extension","History extension can be classified without publishing it.")
	var divergent := _added(entry,_attribute_event(entry,{"end":0}))
	check(not Contract.compare_recovery(committed,divergent,_authority).success,"Divergent histories never merge.")
	var developer := entry.duplicate(true)
	developer.identity.namespace = "dev_normal"
	developer.identity.profile_id = "dev_isolated"
	_approve("origin",developer.origin,developer.identity)
	check(Contract.replay(developer,_authority).success and not Contract.compare_recovery(entry,developer,_authority).success,"NORMAL/DEV identities stay separate.")
	var limited := _fixture(1999)
	limited = _added(limited,_attribute_event(limited,{"str":0}))
	_reject(limited,_receipt_event(limited,"str","poor"),"emergency_receipt_accounting_mismatch")
	var negative := _added(entry,_attribute_event(entry,{"str":-1}))
	_reject(negative,_receipt_event(negative,"str","negative_jump"),"unsupported_emergency_recovery")
	var temporary := _added(entry,_attribute_event(entry,{"str":0},"temporary"))
	_reject(temporary,_receipt_event(temporary,"str","temporary"),"temporary_penalty_not_purchasable")
	var dead_again := _added(committed,_attribute_event(committed,{"str":0}))
	_reject(dead_again,_receipt_event(dead_again,"str","recovery"),"duplicate_or_invalid_receipt_identity")
	var bad_receipt := _receipt_event(failed_wave,"str","wrong_price")
	bad_receipt.data.receipt.cost_expc = 1000
	bad_receipt.data.receipt.expc_after = 4000
	_reject(failed_wave,bad_receipt,"emergency_receipt_accounting_mismatch")
	check(not Contract.decode(encoded.text.left(encoded.text.length()/2),_authority).success,"Interrupted/truncated serialization fails closed.")
	check(Contract.replay(entry,_authority).state.available_expc == 5000,"Rejected and interrupted transactions leave the supplied prior boundary unchanged.")

func _test_invalid_and_authority() -> void:
	var history := _fixture()
	check(not Contract.replay(history,Callable()).success,"Missing external authority fails closed.")
	check(not Contract.replay(history,func(_kind: String,_record: Dictionary,_identity: Dictionary) -> String: return "true").success,"Truth-like values are not authorization.")
	for key: String in history:
		var bad := history.duplicate(true)
		bad.erase(key)
		check(not Contract.replay(bad,_authority).success,"Every history field must be present.")
	var event := _attribute_event(history,{"str":0})
	check(not Contract.append(history,event,_authority).success,"Unapproved attribute mutation cannot enter history.")
	var fields := {"sequence":2,"parent_hash":"bad","event_id":"unscoped","kind":"hpc_death"}
	for field: String in fields:
		var bad := event.duplicate(true)
		bad[field] = fields[field]
		check(not Contract.append(history,bad,_authority).success,"Invalid event identity/order/kind fails closed.")
	for value: Variant in [null,"0",false,0.5,36]:
		var bad := event.duplicate(true)
		bad.data.after.effective.str = value
		_approve("event",bad,history.identity)
		check(not Contract.append(history,bad,_authority).success,"Malformed or unsupported primary value fails closed.")
	var bad := event.duplicate(true)
	bad.data.before.permanent.str = 9
	_reject(history,bad,"attribute_history_conflict")
	bad = event.duplicate(true)
	bad.data.after.effective.erase("wis")
	_reject(history,bad,"invalid_attribute_snapshot")
	var dead := _added(history,event)
	var changed := event.duplicate(true)
	changed.data.after.effective.str = -1
	_reject(dead,changed,"event_identity_conflict")
	var duplicate_history := dead.duplicate(true)
	duplicate_history.events.append(event.duplicate(true))
	check(not Contract.replay(duplicate_history,_authority).success,"Duplicate records inside a supplied history fail closed.")
	var out_of_order := _attribute_event(dead,{"wis":0})
	out_of_order.order.resolution_index = 1
	_reject(dead,out_of_order,"event_order_conflict")
	var missing := dead.duplicate(true)
	missing.events[0].sequence = 2
	check(not Contract.replay(missing,_authority).success,"Missing causal sequence cannot be inferred.")
	var encoded := Contract.encode(dead,_authority)
	var envelope: Dictionary = JSON.parse_string(encoded.text)
	envelope.body += " "
	check(not Contract.decode(JSON.stringify(envelope),_authority).success,"Tampering fails checksum validation.")
	var future := history.duplicate(true)
	future.version = 2
	check(not Contract.replay(future,_authority).success,"Unsupported future prototype versions fail closed.")
	var future_body := Contract.canonical(future)
	check(not Contract.decode(Contract.canonical({"body":future_body,"sha256":future_body.sha256_text()}),_authority).success,"A valid checksum does not authorize a future version.")
	var nested: Dictionary = {"extra":null}
	for index in range(20): nested = {"extra":nested}
	var nested_body := Contract.canonical(nested)
	check(not Contract.decode(Contract.canonical({"body":nested_body,"sha256":nested_body.sha256_text()}),_authority).success,"Excess nesting fails closed before recursive normalization can grow unbounded.")
	var untrusted := history.duplicate(true)
	untrusted.origin.available_expc = 99999
	check(not Contract.replay(untrusted,_authority).success,"Changing origin balances cannot manufacture an authorized history.")
	var unsupported_origin := history.duplicate(true)
	unsupported_origin.origin.classification.authored_attributes.wis = 0
	unsupported_origin.origin.attributes.permanent.wis = 0
	unsupported_origin.origin.attributes.effective.wis = 0
	_approve("origin",unsupported_origin.origin,unsupported_origin.identity)
	check(not Contract.replay(unsupported_origin,_authority).success,"An unqualified living creation zero cannot be legitimized by external approval alone.")
	bad = _resurrection_event(dead)
	bad.data.death_event_id = "unrelated_death"
	_reject(dead,bad,"resurrection_not_eligible")
	var same_time := _attribute_event(dead,{"wis":0})
	same_time.order.timestamp_us = event.order.timestamp_us
	var same_time_history := _added(dead,same_time)
	check(Contract.replay(same_time_history,_authority).state.deaths.size() == 1,"Distinct same-time changes preserve authoritative resolution order; already-dead actors do not die twice.")

func _test_purity_and_compatibility() -> void:
	var history := _fixture()
	var event := _attribute_event(history,{"wis":0},"temporary")
	_approve("event",event,history.identity)
	var history_copy := history.duplicate(true)
	var event_copy := event.duplicate(true)
	var result := Contract.append(history,event,_authority)
	check(history == history_copy and event == event_copy,"Append does not mutate input history or event.")
	var copy: Dictionary = result.history.duplicate(true)
	var replayed := Contract.replay(result.history,_authority)
	check(replayed == Contract.replay(result.history,_authority) and result.history == copy,"Repeated replay is deterministic and read-only.")
	replayed.state.attributes.permanent.wis = 23
	check(result.history == copy,"Returned state shares no mutable input references.")
	var simulation := CombatSimulation.new(37)
	simulation.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(&"vaelis_thorn"))
	var before := simulation.get_state_snapshot()
	var encoded := Contract.encode(result.history,_authority)
	var decoded := Contract.decode(encoded.text,_authority)
	check(decoded.success and simulation.get_state_snapshot() == before and before.schema_version == 12,"Pure serialization cannot change combat/RNG/events or simulation schema12.")
	check(result.ledger_writes == 0 and not result.action_performed and replayed.ledger_writes == 0,"No real ledger writes or actions are executed.")
	check(not CharacterSaveContract.validate(result.history).success,"Prototype is not an accepted production Save Contract V2 document.")
	var mutated := Contract.replay(result.history,func(_kind: String,record: Dictionary,identity: Dictionary) -> bool:
		record.clear()
		identity.clear()
		return true)
	check(mutated.success and result.history == copy,"Authority callback receives copies, never mutable history internals.")

func _step_receipt(history: Dictionary, attribute: String, suffix: String, expected_cost: int) -> Dictionary:
	var event := _receipt_event(history,attribute,suffix)
	for layer: String in ["permanent","effective"]:
		event.data.after[layer][attribute] = event.data.before[layer][attribute]+1
	event.data.receipt.cost_expc = expected_cost
	event.data.receipt.expc_after = event.data.receipt.expc_before-expected_cost
	return event

func _test_durable_pricing() -> void:
	# Independent literal expectations: owner below1 recovery; existing p.102 bands.
	for row: Array in [[-5,2000],[-4,2000],[-3,2000],[-2,2000],[-1,2000],[0,2000],[1,2000],[5,2000],[6,3000],[10,3000],[11,5000],[16,7000]]:
		var quote := Contract.recovery_price("str",row[0])
		check(quote.success and quote.cost_expc == row[1] and not quote.purchase_authorized,"Known restoration steps reuse exact prices without authorizing spending.")
	var negative := _fixture(10000)
	negative = _added(negative,_attribute_event(negative,{"str":-1}))
	var step := _step_receipt(negative,"str","negative_to_zero",2000)
	negative = _added(negative,step)
	check(Contract.replay(negative,_authority).state.attributes.permanent.str == 0 and Contract.replay(negative,_authority).state.available_expc == 8000,"Negative-to-zero step is charged2000 and never free.")
	negative = _added(negative,_step_receipt(negative,"str","zero_to_one",2000))
	check(Contract.replay(negative,_authority).state.attributes.permanent.str == 1 and Contract.replay(negative,_authority).state.available_expc == 6000 and Contract.replay(negative,_authority).state.life == "dead","A separate zero-to-one receipt is charged2000 and cannot revive.")
	var history := _fixture(15000)
	history = _added(history,_attribute_event(history,{"str":0,"wis":0}))
	history = _added(history,_step_receipt(history,"str","zero_one",2000))
	check(not Contract.replay(history,_authority).state.attribute_eligible,"Restoring one primary does not remove another lethal barrier.")
	history = _added(history,_step_receipt(history,"wis","wis_one",2000))
	var state: Dictionary = Contract.replay(history,_authority).state
	check(state.life == "dead" and state.attribute_eligible and state.available_expc == 11000,"Purchases may precede eligibility evaluation but cannot revive.")
	history = _added(history,_step_receipt(history,"str","one_two",2000))
	check(Contract.replay(history,_authority).state.attributes.permanent.str == 2,"Restoration of a second lost point uses its ordinary verified price.")
	var high := _fixture(10000)
	high = _added(high,_attribute_event(high,{"str":6,"wis":0}))
	_reject(high,_step_receipt(high,"str","discount",2000),"emergency_receipt_accounting_mismatch")
	high = _added(high,_step_receipt(high,"str","six_seven",3000))
	check(Contract.replay(high,_authority).state.available_expc == 7000,"Higher priced lost point is not discounted by emergency state.")
	var penalized := _fixture(5000)
	penalized = _added(penalized,_attribute_event(penalized,{"str":0}))
	penalized = _added(penalized,_attribute_event(penalized,{"str":-2},"temporary"))
	var correction := _step_receipt(penalized,"str","base_only",2000)
	var erase_penalty := correction.duplicate(true)
	erase_penalty.data.after.effective.str = 1
	_reject(penalized,erase_penalty,"unsupported_emergency_recovery")
	penalized = _added(penalized,correction)
	state = Contract.replay(penalized,_authority).state
	check(state.attributes.permanent.str == 1 and state.attributes.effective.str == -1 and state.active_sources.size() == 1 and not state.attribute_eligible,"Buying a permanently lost point preserves the entire temporary penalty and its source.")
	var only_temporary := _fixture()
	only_temporary = _added(only_temporary,_attribute_event(only_temporary,{"str":0},"temporary"))
	_reject(only_temporary,_step_receipt(only_temporary,"str","no_loss",3000),"temporary_penalty_not_purchasable")
	var insufficient := _fixture(2999)
	insufficient = _added(insufficient,_attribute_event(insufficient,{"str":6,"wis":0}))
	_reject(insufficient,_step_receipt(insufficient,"str","poor",3000),"emergency_receipt_accounting_mismatch")

func _prepare(previous: Dictionary, current: Dictionary, candidate: Dictionary, suffix: String) -> Dictionary:
	var generation: int = 0 if current.is_empty() else current.generation
	var proposal := Contract.prepare_generation(current,previous,candidate,generation,Contract._prefix(candidate.identity)+"/publication/"+suffix,_authority)
	check(proposal.success and not proposal.published,"Valid generation proposal is prepared, never published by this contract.")
	return proposal.get("prepared",{})

func _ack(prepared: Dictionary) -> Dictionary:
	_approve("head",prepared.binding,prepared.history.identity)
	observed_heads[Contract.fingerprint(prepared.history.identity)] = Contract.fingerprint(prepared.binding)
	var result := Contract.acknowledge_generation(prepared,prepared.history,prepared.binding,_authority)
	check(result.success,"Exact externally verified generation readback acknowledges the candidate.")
	return prepared.binding.duplicate(true)

func _test_generation_retention() -> void:
	var origin := _fixture()
	var prepared := _prepare(origin,{},origin,"first")
	check(not Contract.acknowledge_generation(prepared,prepared.history,prepared.binding,_authority).success,"Queued generation is not a verified save acknowledgement.")
	var first := _ack(prepared)
	var lost := _added(origin,_attribute_event(origin,{"str":0}))
	var receipt := _receipt_event(lost,"str","durable")
	var recovered := _added(lost,receipt)
	var second_proposal := _prepare(origin,first,recovered,"second")
	var first_copy := first.duplicate(true)
	check(not Contract.acknowledge_generation(second_proposal,recovered,second_proposal.binding,_authority).success and first == first_copy,"Interrupted/unacknowledged publication leaves the old verified generation intact.")
	var second := _ack(second_proposal)
	check(not Contract.prepare_generation(first,origin,recovered,1,Contract._prefix(origin.identity)+"/publication/old_head",_authority).success,"A historically acknowledged head cannot pose as the latest durable head.")
	check(not Contract.prepare_generation({},origin,recovered,0,Contract._prefix(origin.identity)+"/publication/false_empty",_authority).success,"An occupied destination cannot be reinitialized as a new profile.")
	var serialized := Contract.canonical({"history":recovered,"binding":second})
	var reopened: Dictionary = Contract._json_integers(JSON.parse_string(serialized))
	check(Contract.verify_generation(reopened.history,reopened.binding,_authority).success,"Exact history head and publication identities survive isolated serialization.")
	check(Contract.acknowledge_generation(second_proposal,reopened.history,reopened.binding,_authority).success and Contract.reconcile(reopened.history,receipt,_authority).status == "recorded","Lost acknowledgement reconciles exact history, never spends again.")
	for boundary: String in ["reload","interrupted_wave","retry","return","crash"]:
		var result := Contract.retain_for_boundary(reopened.history,origin,reopened.binding,boundary,_authority)
		if boundary in ["retry","return","interrupted_wave"]:
			check(not result.success and result.reason == "explicit_attempt_rollback_required","Discard must restore its explicit checkpoint through an authorized rollback event.")
			check(Contract.retain_for_boundary(reopened.history,origin,reopened.binding,boundary,_authority) == result,"Repeated unapproved discard changes nothing.")
			continue
		check(result.success and not result.applied and result.retained_state.life == "dead" and result.retained_state.attributes.permanent.str == 1 and result.retained_state.available_expc == 3000 and result.retained_state.receipts.size() == 1,"Every recovery boundary retains losses, causal death, completed receipt and exact balance.")
		check(result.history == reopened.history and Contract.retain_for_boundary(reopened.history,origin,reopened.binding,boundary,_authority) == result,"Repeated recovery classification cannot create a transaction or refund.")
	var stale := Contract.prepare_generation(second,recovered,recovered,1,Contract._prefix(recovered.identity)+"/publication/stale",_authority)
	check(not stale.success and stale.reason == "stale_generation","Stale expected generation cannot replace a verified head.")
	check(not Contract.verify_generation(origin,second,_authority).success,"Old history with a newer binding is a conflicting head.")
	check(not Contract.prepare_generation(second,recovered,origin,2,Contract._prefix(origin.identity)+"/publication/rollback",_authority).success,"A new generation cannot authorize history rollback.")
	check(not Contract.prepare_generation(second,recovered,recovered,2,first.transaction_id,_authority).success,"A prior publication identity cannot be replayed as new.")
	var divergent := _added(origin,_attribute_event(origin,{"end":0}))
	check(not Contract.prepare_generation(second,recovered,divergent,2,Contract._prefix(origin.identity)+"/publication/divergent",_authority).success,"Conflicting causal histories cannot be published over the current prefix.")
	var corrupted := second.duplicate(true)
	corrupted.event_head = "0".repeat(64)
	check(not Contract.acknowledge_generation(second_proposal,recovered,corrupted,_authority).success,"Head readback mismatch fails without changing prior data.")
	check(not Contract.retain_for_boundary(origin,recovered,first,"retry",_authority).success,"An entry ahead of the verified head is not silently accepted.")
	var developer := origin.duplicate(true)
	developer.identity.namespace = "dev_normal"
	developer.identity.profile_id = "dev_isolated"
	_approve("origin",developer.origin,developer.identity)
	check(not Contract.verify_generation(developer,first,_authority).success,"Namespace isolation is part of the generation binding.")
	var third_proposal := _prepare(recovered,second,recovered,"third")
	_ack(third_proposal)
	check(not Contract.acknowledge_generation(second_proposal,recovered,second,_authority).success,"A superseded readback cannot be acknowledged as the current generation.")

func _test_frozen_duration() -> void:
	var origin := _fixture()
	var dead := _added(origin,_attribute_event(origin,{"wis":0}))
	var positive := _attribute_event(dead,{"wis":2},"temporary")
	positive.data.sources[0].remaining_duration_us = 1000
	var history := _added(dead,positive)
	var source_id: String = positive.data.sources[0].source_id
	history = _added(history,_event(history,"effect_time",{"elapsed_us":9999999,"frozen":true}))
	check(Contract.replay(history,_authority).state.source_remaining_us[source_id] == 1000,"Frozen encounter time preserves exact remaining duration, independent of elapsed wall time.")
	_reject(history,_attribute_event(history,{"wis":0},"effect_expiration"),"effect_expiration_while_frozen")
	history = _added(history,_event(history,"effect_time",{"elapsed_us":0,"frozen":false}))
	history = _added(history,_event(history,"effect_time",{"elapsed_us":400,"frozen":false}))
	var state: Dictionary = Contract.replay(history,_authority).state
	check(state.source_remaining_us[source_id] == 600 and state.life == "dead" and state.attribute_eligible,"Resumed combat time ages duration without reviving or refilling anything.")
	var encoded := Contract.encode(history,_authority)
	var reloaded := Contract.decode(encoded.text,_authority)
	check(reloaded.success and reloaded.state == state,"Reload preserves remaining duration, source identity and dead state exactly.")
	var head := _ack(_prepare(origin,{},history,"timed"))
	for boundary: String in ["retry","return","crash"]:
		var retained := Contract.retain_for_boundary(history,origin,head,boundary,_authority)
		if boundary in ["retry","return","interrupted_wave"]:
			check(not retained.success and retained.reason == "explicit_attempt_rollback_required","Discarded attempt duration/state requires its verified checkpoint, not unconditional retention.")
			continue
		check(retained.success and retained.retained_state.source_remaining_us[source_id] == 600 and retained.retained_state.life == "dead","Recovery cannot invent expiration or replace current durable death with an alive entry.")
	_reject(history,_event(history,"effect_time",{"elapsed_us":600,"frozen":false}),"effect_expiration_snapshot_required")
	var expiry := _attribute_event(history,{"wis":0},"effect_expiration")
	expiry.data.effect_elapsed_us = 600
	history = _added(history,expiry)
	state = Contract.replay(history,_authority).state
	check(state.source_remaining_us.is_empty() and state.resurrection_barriers == ["wis"] and state.life == "dead","Due expiry and its effective-score change are atomic; eligibility is rechecked.")
	var unknown := _added(origin,_attribute_event(origin,{"str":0},"temporary"))
	check(not Contract.prepare_generation({},origin,unknown,0,Contract._prefix(origin.identity)+"/publication/unknown_duration",_authority).success,"Unknown temporary durations cannot become a trusted durable head.")
	_reject(unknown,_event(unknown,"effect_time",{"elapsed_us":1,"frozen":false}),"temporary_duration_unverified")
	for invalid: Variant in [-1,1.5,"1",null]:
		_reject(history,_event(history,"effect_time",{"elapsed_us":invalid,"frozen":false}),"invalid_effect_elapsed_time")

func _test_negative_recovery() -> void:
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		var history := _fixture(12000)
		history = _added(history,_attribute_event(history,{attribute:-5}))
		var expected_balance := 12000
		for score: int in [-5,-4,-3,-2,-1,0]:
			var receipt := _step_receipt(history,attribute,"point_"+str(score+5),2000)
			history = _added(history,receipt)
			expected_balance -= 2000
			var state: Dictionary = Contract.replay(history,_authority).state
			check(state.attributes.permanent[attribute] == score+1 and state.attributes.effective[attribute] == score+1 and state.available_expc == expected_balance,"Each independently purchased -5 through1 step preserves signed values and charges exactly2000.")
			check(state.life == "dead" and state.attribute_eligible == (score == 0),"Recovery removes a barrier only at positive effective value and never revives.")
			var roundtrip := Contract.decode(Contract.encode(history,_authority).text,_authority)
			check(roundtrip.success and roundtrip.history == history and roundtrip.state == state,"Every signed recovery step serializes and replays identically.")
			_reject(history,receipt,"duplicate_event")
			check(Contract.reconcile(history,receipt,_authority).status == "recorded","Exact receipt replay reconciles without a second debit.")
		check(Contract.replay(history,_authority).state.receipts.size() == 6,"Six separately identified receipts restore -5 to1 for12000 total.")
	var multiple := _fixture(4000)
	multiple = _added(multiple,_attribute_event(multiple,{"str":-1,"wis":-1}))
	multiple = _added(multiple,_step_receipt(multiple,"str","str_zero",2000))
	multiple = _added(multiple,_step_receipt(multiple,"wis","wis_zero",2000))
	var state: Dictionary = Contract.replay(multiple,_authority).state
	check(state.available_expc == 0 and state.resurrection_barriers == ["str","wis"] and state.life == "dead","Partial funding across lethal attributes neither grants free points nor removes remaining barriers.")
	_reject(multiple,_step_receipt(multiple,"str","unfunded",2000),"emergency_receipt_accounting_mismatch")
	var poor := _fixture(1999)
	poor = _added(poor,_attribute_event(poor,{"str":-5}))
	_reject(poor,_step_receipt(poor,"str","poor_negative",2000),"emergency_receipt_accounting_mismatch")
	var malformed := _step_receipt(poor,"str","negative_balance",2000)
	malformed.data.receipt.expc_before = -1
	malformed.data.receipt.expc_after = -2001
	_reject(poor,malformed,"emergency_receipt_accounting_mismatch")
	var modified := _fixture(8000)
	modified = _added(modified,_attribute_event(modified,{"str":-3}))
	var penalty := _attribute_event(modified,{"str":-5},"temporary")
	penalty.data.sources[0].remaining_duration_us = 1000
	modified = _added(modified,penalty)
	var source_id: String = penalty.data.sources[0].source_id
	for score: int in [-3,-2,-1,0]:
		modified = _added(modified,_step_receipt(modified,"str","penalized_"+str(score+3),2000))
		state = Contract.replay(modified,_authority).state
		check(state.attributes.effective.str == state.attributes.permanent.str-2 and state.source_remaining_us[source_id] == 1000,"Permanent restoration never buys away, consumes time from or expires a temporary penalty.")
	check(state.life == "dead" and not state.attribute_eligible and state.attributes.permanent.str == 1 and state.attributes.effective.str == -1,"Full permanent recovery can leave a temporary resurrection barrier in place.")
	var expiry := _attribute_event(modified,{"str":1},"effect_expiration")
	expiry.data.effect_elapsed_us = 1000
	modified = _added(modified,expiry)
	state = Contract.replay(modified,_authority).state
	check(state.life == "dead" and state.attribute_eligible and state.available_expc == 0,"Legitimate explicit expiry removes only the barrier; no revival or refund.")

func _test_recovery_totals() -> void:
	# Independent expected totals; no production-price table generates these fixtures.
	for row: Array in [[-5,1,12000],[-3,1,8000],[-5,0,10000],[-5,-2,6000],[0,1,2000],[1,2,2000],[5,7,5000],[9,12,11000]]:
		var quote := Contract.recovery_total("str",row[0],row[1],row[2])
		check(quote.success and quote.total_cost_expc == row[2] and quote.point_count == row[1]-row[0] and quote.affordable and quote.affordable_points == quote.point_count and quote.expc_after_affordable_steps == 0 and not quote.batch_purchase_authorized,"Multi-point estimates sum exact individual prices without rounding, discount or batch authority.")
	for row: Array in [[0,0,-3,0],[1999,0,-3,1999],[2000,1,-2,0],[3999,1,-2,1999],[4000,2,-1,0],[7999,3,0,1999],[8000,4,1,0]]:
		var quote := Contract.recovery_total("wis",-3,1,row[0])
		check(quote.success and quote.total_cost_expc == 8000 and quote.affordable_points == row[1] and quote.affordable_target == row[2] and quote.expc_after_affordable_steps == row[3] and quote.affordable == (row[0] == 8000),"Partial budgets buy only a consecutive whole-point prefix; the quote itself spends nothing.")
	var above := Contract.recovery_total("str",5,7,4999)
	check(above.total_cost_expc == 5000 and above.affordable_points == 1 and above.affordable_target == 6 and above.expc_after_affordable_steps == 2999,"A price-band crossing keeps ordinary advancement pricing and exact remainder.")
	for value: Variant in [null,"-3",-3.5,true]:
		check(not Contract.recovery_price("str",value).success,"Malformed single-point scores cannot be silently repriced through type coercion.")
		check(not Contract.recovery_total("str",value,1,8000).success,"Malformed starting scores cannot be coerced into a price.")
	for value: Variant in [-1,2000.5,"8000",null]:
		check(not Contract.recovery_total("str",-3,1,value).success,"Negative/malformed budgets fail closed.")
	for target: Variant in [-3,-4,36,1.5,null]:
		check(not Contract.recovery_total("str",-3,target,8000).success,"Nonincreasing, unsupported or malformed targets fail closed.")
	check(not Contract.recovery_total("str",-Contract.SAFE_INTEGER,1,0).success,"Unrepresentable totals fail closed without an unbounded per-point loop.")

func _test_negative_durability() -> void:
	var origin := _fixture(12000)
	var lost := _added(origin,_attribute_event(origin,{"str":-3}))
	var first := _ack(_prepare(origin,{},lost,"loss"))
	var partial := _added(lost,_step_receipt(lost,"str","minus_two",2000))
	partial = _added(partial,_step_receipt(partial,"str","minus_one",2000))
	var second_proposal := _prepare(lost,first,partial,"partial")
	var second := _ack(second_proposal)
	var repeated := _step_receipt(partial,"str","minus_one",2000)
	_reject(partial,repeated,"duplicate_or_invalid_receipt_identity")
	var third_receipt := _step_receipt(partial,"str","zero",2000)
	_approve("event",third_receipt,partial.identity)
	check(Contract.reconcile(partial,third_receipt,_authority).status == "not_recorded","Interrupted negative recovery does not imply spending.")
	var to_zero := _added(partial,third_receipt)
	var third_proposal := _prepare(partial,second,to_zero,"zero")
	check(not Contract.acknowledge_generation(third_proposal,to_zero,third_proposal.binding,_authority).success,"An unverified negative-recovery write cannot replace the acknowledged head.")
	for boundary: String in ["reload","retry","return","crash","interrupted_wave"]:
		var retained := Contract.retain_for_boundary(partial,origin,second,boundary,_authority)
		if boundary in ["retry","return","interrupted_wave"]:
			check(not retained.success and retained.reason == "explicit_attempt_rollback_required","Signed recovery can be discarded only through its authorized checkpoint event.")
			continue
		check(retained.success and retained.retained_state.attributes.permanent.str == -1 and retained.retained_state.available_expc == 8000 and retained.retained_state.receipts.size() == 2 and retained.retained_state.life == "dead","Recovery retains exactly completed signed steps and causal death; pending steps are not fabricated.")
	check(not Contract.prepare_generation(first,lost,to_zero,1,Contract._prefix(origin.identity)+"/publication/stale_negative",_authority).success,"A stale generation cannot replay completed negative recovery as new progression.")
	var third := _ack(third_proposal)
	check(Contract.reconcile(to_zero,third_receipt,_authority).status == "recorded" and Contract.acknowledge_generation(third_proposal,to_zero,third,_authority).success,"Ambiguous acknowledgement reconciles the exact negative-to-zero purchase once.")
	var positive := _added(to_zero,_step_receipt(to_zero,"str","positive",2000))
	var fourth := _ack(_prepare(to_zero,third,positive,"positive"))
	var serialized := Contract.canonical({"history":positive,"binding":fourth})
	var reopened: Dictionary = Contract._json_integers(JSON.parse_string(serialized))
	var verified := Contract.verify_generation(reopened.history,reopened.binding,_authority)
	check(verified.success and verified.state.available_expc == 4000 and verified.state.attributes.permanent.str == 1 and verified.state.receipts.size() == 4 and verified.state.attribute_eligible and verified.state.life == "dead","Four durable -3-to1 receipts cost8000 across generation-bound reload with no automatic resurrection.")
	check(Contract.encode(reopened.history,_authority).text == Contract.encode(positive,_authority).text,"Signed recovery history remains canonically identical after generation-bound serialization.")
