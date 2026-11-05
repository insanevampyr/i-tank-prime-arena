class_name LifeStateHistoryContract
extends RefCounted

# Dormant, in-memory prototype. Never a playable save or a transaction executor.
const Evaluator = preload("res://scripts/combat/dead_attribute_evaluator.gd")
const Prices = preload("res://scripts/rewards/prime_v3_advancement_catalog.gd")
const FORMAT := "itank_life_history_prototype"
const VERSION := 1
const MAX_EVENTS := 4096
const MAX_BYTES := 8 * 1024 * 1024
const SAFE_INTEGER := 9007199254740991
const ATTEMPT_FIELDS := ["life","attributes","available_expc","permanent_high_water","source_remaining_us","effect_clock_frozen","authored_exceptions","active_sources","deaths","resurrections","receipts","resurrection_barriers","attribute_eligible","owned_state","reward_receipts","wave_outcomes"]

static func create(identity: Dictionary, origin: Dictionary, authority: Callable) -> Dictionary:
	var history := {"format":FORMAT,"version":VERSION,"identity":identity.duplicate(true),"origin":origin.duplicate(true),"events":[]}
	var result := replay(history, authority)
	if not result.success: return result
	return {"success":true,"history":history,"state":result.state}

static func replay(history: Dictionary, authority: Callable) -> Dictionary:
	if not _keys(history,["format","version","identity","origin","events"]) or history.format != FORMAT or typeof(history.version) != TYPE_INT or history.version != VERSION: return _fail("unsupported_history")
	if not history.identity is Dictionary or not _identity(history.identity): return _fail("invalid_identity")
	if not history.origin is Dictionary or not _keys(history.origin,["classification","attributes","available_expc"]): return _fail("invalid_origin")
	if not history.events is Array or history.events.size() > MAX_EVENTS: return _fail("invalid_event_history")
	if not _authorized(authority,"origin",history.origin,history.identity): return _fail("origin_authority_required")
	var origin: Dictionary = history.origin
	if not _integer(origin.available_expc,0): return _fail("invalid_origin_expc")
	var initial := Evaluator.evaluate({"phase":"creation","life_before":"living","change_kind":"initial","classification":origin.classification,"before":origin.attributes,"after":origin.attributes,"available_expc":origin.available_expc})
	if not initial.success: return _fail("invalid_or_unresolved_origin")
	var state := {"life":"alive","attributes":origin.attributes.duplicate(true),"available_expc":origin.available_expc,
		"active_attempt":{},"discarded_attempts":[],"closed_attempt_ids":[],"owned_state":{},"reward_receipts":[],"wave_outcomes":[],"participation":"member","pending_restoration":{},"decisions":[],
		"permanent_high_water":origin.attributes.permanent.duplicate(true),"source_remaining_us":{},"effect_clock_frozen":false,
		"authored_exceptions":origin.classification.initial_zero_exceptions.duplicate(),"active_sources":{},"deaths":[],"resurrections":[],"receipts":[],
		"resurrection_barriers":[],"attribute_eligible":true,"last_order":{},"last_event_id":"","sequence":0,
		"head_hash":fingerprint({"identity":history.identity,"origin":origin})}
	var identities := {}
	for event: Variant in history.events:
		if not event is Dictionary: return _fail("invalid_event")
		var result := _apply(state,event,history,identities,authority)
		if not result.success: return result
	# Eligibility describes this contract's barriers only, never authorization to revive.
	return {"success":true,"state":state,"action_performed":false,"ledger_writes":0}

static func append(history: Dictionary, event: Dictionary, authority: Callable) -> Dictionary:
	var prior := replay(history,authority)
	if not prior.success: return prior
	for recorded: Dictionary in history.events:
		if recorded.event_id == event.get("event_id"): return _fail("duplicate_event" if recorded == event else "event_identity_conflict")
	var candidate := history.duplicate(true)
	candidate.events.append(event.duplicate(true))
	var result := replay(candidate,authority)
	if not result.success: return result
	return {"success":true,"history":candidate,"state":result.state,"action_performed":false,"ledger_writes":0}

# Lost-ack inspection only. This never applies an absent event or retries a debit.
static func reconcile(history: Dictionary, event: Dictionary, authority: Callable) -> Dictionary:
	var checked := replay(history,authority)
	if not checked.success: return checked
	for recorded: Dictionary in history.events:
		if recorded.event_id == event.get("event_id"):
			return {"success":true,"status":"recorded","state":checked.state} if recorded == event else _fail("event_identity_conflict")
	var candidate := append(history,event,authority)
	return {"success":true,"status":"not_recorded"} if candidate.success else candidate

# Audit history is never truncated. Authorized attempt rollback is a NEW event;
# it restores its checkpoint projection while retaining spent/voided identities.
static func compare_recovery(current: Dictionary, candidate: Dictionary, authority: Callable) -> Dictionary:
	for history: Dictionary in [current,candidate]:
		var checked := replay(history,authority)
		if not checked.success: return checked
	if current.identity != candidate.identity or current.origin != candidate.origin: return _fail("recovery_identity_or_origin_conflict")
	for index in range(mini(current.events.size(),candidate.events.size())):
		if current.events[index] != candidate.events[index]: return _fail("divergent_recovery_history")
	var status := "exact" if current.events.size() == candidate.events.size() else ("extension" if current.events.size() < candidate.events.size() else "explicit_attempt_rollback_required")
	return {"success":true,"classification":status,"applied":false}

# Owner recovery prices below1; ordinary catalog prices above. No live authority.
static func recovery_price(attribute: String, permanent_value: Variant) -> Dictionary:
	if not Evaluator.DEAD_AT_ZERO.has(attribute): return _unsupported("unsupported_recovery_attribute")
	if not _integer(permanent_value,-SAFE_INTEGER): return _fail("invalid_permanent_recovery_score")
	var cost: Variant = Evaluator.RECOVERY_COST if permanent_value < 1 else Prices.attribute_cost(permanent_value)
	if permanent_value >= 35: return _unsupported("recovery_outside_verified_range")
	return {"success":true,"cost_expc":cost,"from":permanent_value,"to":permanent_value+1,"source_ref":"owner-approved permanent recovery below1" if permanent_value < 1 else Prices.PURCHASE_SOURCE_REF,"purchase_authorized":false}

# Cost estimate only. Every applied point still requires its own authorized receipt.
# Aggregate the constant negative band to avoid an unbounded loop or int overflow.
static func recovery_total(attribute: String, current: Variant, target: Variant, available_expc: Variant) -> Dictionary:
	if typeof(current) != TYPE_INT or current < -SAFE_INTEGER or not _integer(target,-SAFE_INTEGER) or target <= current or target > 35 or not _integer(available_expc,0): return _fail("invalid_recovery_total")
	if not Evaluator.DEAD_AT_ZERO.has(attribute): return _unsupported("unsupported_recovery_attribute")
	var below_steps: int = maxi(0,mini(target,1)-current)
	if below_steps > SAFE_INTEGER / Evaluator.RECOVERY_COST: return _unsupported("recovery_total_outside_serializable_range")
	var total: int = below_steps*Evaluator.RECOVERY_COST
	var affordable_points: int = mini(below_steps,available_expc / Evaluator.RECOVERY_COST)
	var remaining: int = available_expc-affordable_points*Evaluator.RECOVERY_COST
	var prefix_affordable: bool = affordable_points == below_steps
	for score in range(maxi(current,1),target):
		var price := recovery_price(attribute,score)
		if not price.success: return price
		var cost: int = price.cost_expc
		if total > SAFE_INTEGER-cost: return _unsupported("recovery_total_outside_serializable_range")
		total += cost
		if prefix_affordable and remaining >= cost:
			affordable_points += 1
			remaining -= cost
		else: prefix_affordable = false
	return {"success":true,"from":current,"to":target,"point_count":target-current,"total_cost_expc":total,
		"affordable":available_expc >= total,"affordable_points":affordable_points,"affordable_target":current+affordable_points,
		"expc_after_affordable_steps":remaining,"operation":"quote_only","batch_purchase_authorized":false}

# Proposal/ack validation only. The existing coordinator remains the sole future
# publisher, committing this head WITH the profile and entry checkpoint.
static func prepare_generation(current: Dictionary, previous: Dictionary, candidate: Dictionary, expected_generation: int, transaction_id: String, authority: Callable) -> Dictionary:
	var checked := replay(candidate,authority)
	if not checked.success: return checked
	var old := replay(previous,authority)
	if not old.success: return old
	var publications: Array = []
	if current.is_empty():
		if expected_generation != 0 or not previous.events.is_empty(): return _fail("initial_generation_requires_origin")
		if not _authorized(authority,"empty_head",{},previous.identity): return _fail("destination_not_verified_empty")
	else:
		var verified := verify_generation(previous,current,authority)
		if not verified.success: return verified
		if not _authorized(authority,"current_head",current,previous.identity): return _fail("stale_generation_head")
		if expected_generation != current.generation: return _fail("stale_generation")
		publications = current.publication_ids.duplicate()
	if not _integer(expected_generation,0) or expected_generation >= SAFE_INTEGER: return _fail("invalid_generation")
	var seen := {}
	for id: String in publications: seen[id] = true
	if not _claim(transaction_id,_prefix(candidate.identity),seen): return _fail("duplicate_or_invalid_publication_identity")
	var continuity := compare_recovery(previous,candidate,authority)
	if not continuity.success: return continuity
	if continuity.classification not in ["exact","extension"]: return _fail("durable_history_rollback_prohibited")
	for source_id: String in checked.state.active_sources:
		if not checked.state.source_remaining_us.has(source_id): return _unsupported("temporary_duration_unverified")
	publications.append(transaction_id)
	var binding := {"version":1,"identity":candidate.identity.duplicate(true),"generation":expected_generation+1,
		"transaction_id":transaction_id,"publication_ids":publications,"previous_binding_hash":fingerprint(current),
		"event_count":candidate.events.size(),"event_head":checked.state.head_hash,"history_digest":fingerprint(candidate)}
	return {"success":true,"prepared":{"expected_binding":current.duplicate(true),"binding":binding,"history":candidate.duplicate(true)},"published":false}

static func verify_generation(history: Dictionary, binding: Dictionary, authority: Callable) -> Dictionary:
	var checked := inspect_generation_binding(history,binding,authority)
	if not checked.success: return checked
	if not _authorized(authority,"head",binding,history.identity): return _fail("generation_acknowledgement_unverified")
	return checked

# Candidate inspection is not an acknowledgement or storage publication.
static func inspect_generation_binding(history: Dictionary, binding: Dictionary, authority: Callable) -> Dictionary:
	var checked := replay(history,authority)
	if not checked.success: return checked
	for source_id: String in checked.state.active_sources:
		if not checked.state.source_remaining_us.has(source_id): return _unsupported("temporary_duration_unverified")
	if not _keys(binding,["version","identity","generation","transaction_id","publication_ids","previous_binding_hash","event_count","event_head","history_digest"]) or typeof(binding.version) != TYPE_INT or binding.version != 1: return _fail("invalid_generation_binding")
	if binding.identity != history.identity or not _integer(binding.generation,1) or not _integer(binding.event_count,0) or binding.event_count != history.events.size() or binding.event_head != checked.state.head_hash or binding.history_digest != fingerprint(history): return _fail("generation_head_conflict")
	if not binding.previous_binding_hash is String or binding.previous_binding_hash.length() != 64 or not binding.publication_ids is Array or binding.publication_ids.size() != binding.generation: return _fail("invalid_generation_history")
	if binding.generation == 1 and binding.previous_binding_hash != fingerprint({}): return _fail("initial_binding_parent_conflict")
	var seen := {}
	for id: Variant in binding.publication_ids:
		if not _claim(id,_prefix(history.identity),seen): return _fail("duplicate_or_invalid_publication_identity")
	if binding.publication_ids.back() != binding.transaction_id: return _fail("publication_identity_conflict")
	return {"success":true,"state":checked.state}

static func acknowledge_generation(prepared: Dictionary, readback_history: Dictionary, readback_binding: Dictionary, authority: Callable) -> Dictionary:
	if not _keys(prepared,["expected_binding","binding","history"]) or prepared.history != readback_history or prepared.binding != readback_binding: return _fail("generation_readback_mismatch")
	var previous: Variant = prepared.expected_binding
	if not previous is Dictionary or readback_binding.get("previous_binding_hash") != fingerprint(previous): return _fail("generation_parent_conflict")
	var expected: int = 0 if previous.is_empty() else int(previous.get("generation",-1))
	if readback_binding.get("generation") != expected+1: return _fail("generation_sequence_conflict")
	var verified := verify_generation(readback_history,readback_binding,authority)
	if not verified.success: return verified
	if not _authorized(authority,"current_head",readback_binding,readback_history.identity): return _fail("stale_generation_head")
	return verified

static func retain_for_boundary(current: Dictionary, entry: Dictionary, binding: Dictionary, boundary: String, authority: Callable) -> Dictionary:
	if boundary not in ["reload","interrupted_wave","retry","return","crash"]: return _fail("unsupported_recovery_boundary")
	var verified := verify_generation(current,binding,authority)
	if not verified.success: return verified
	if not _authorized(authority,"current_head",binding,current.identity): return _fail("stale_generation_head")
	var comparison := compare_recovery(current,entry,authority)
	if not comparison.success: return comparison
	if comparison.classification == "extension": return _fail("entry_ahead_of_acknowledged_head")
	if boundary in ["retry","return","interrupted_wave"] and comparison.classification != "exact": return _fail("explicit_attempt_rollback_required")
	return {"success":true,"history":current.duplicate(true),"retained_state":verified.state,"generation":binding.generation,"boundary":boundary,"wave_rebase_required":true,"applied":false}

# Read-only player-facing state, not a live modal or a purchase command.
static func death_notification(history: Dictionary, authority: Callable) -> Dictionary:
	var checked := replay(history,authority)
	if not checked.success: return checked
	var state: Dictionary = checked.state
	if state.life != "dead" or state.deaths.is_empty(): return _fail("notification_requires_death")
	var cause: Dictionary = state.deaths.back()
	var options: Array = []
	for attribute: String in Evaluator.DEAD_AT_ZERO:
		var permanent: int = state.attributes.permanent[attribute]
		if permanent >= 1 or permanent >= state.permanent_high_water[attribute]: continue
		var total := recovery_total(attribute,permanent,1,state.available_expc)
		if not total.success: return total
		options.append({"attribute":attribute,"permanent":permanent,"effective":state.attributes.effective[attribute],"next_value":permanent+1,"next_cost_expc":Evaluator.RECOVERY_COST,"affordable":state.available_expc >= Evaluator.RECOVERY_COST,"to_positive":total})
	return {"success":true,"cause_kind":cause.get("cause_kind","dead_attribute"),"cause_event_id":cause.event_id,"affected_attributes":cause.attributes.duplicate(),"options":options,
		"available_expc":state.available_expc,"resurrection_barriers":state.resurrection_barriers.duplicate(),"attribute_eligible":state.attribute_eligible,
		"explanation":"Your character died from lethal attributes." if cause.get("cause_kind","dead_attribute") == "dead_attribute" else "Your character died from an externally verified HPC cause. This does not itself require attribute recovery.",
		"recovery_explanation":"No attribute restoration is required for this HPC death." if options.is_empty() and cause.get("cause_kind") == "hpc" else "Each permanent point starting below 1 costs 2,000 EXPC. Temporary penalties cannot be purchased away.",
		"resurrection_explanation":"Spending EXPC does not resurrect you. Another character must complete a legitimate resurrection effect.",
		"can_restore_one":not options.filter(func(option: Dictionary) -> bool: return option.affordable).is_empty(),"can_choose_not_now":true,"can_revisit":true,"countdown":false,"spectate":true,"normal_actions_allowed":false,"spends_expc":false}

# Policy-only projection. No XP formula, payout, turn, timer or team mutation.
static func classify_party_completion(alive_count: int, enemies_defeated: bool) -> String:
	return "defeat" if alive_count == 0 else ("victory" if enemies_defeated else "combat")

static func party_view(histories: Dictionary, enemies_defeated: bool, final_wave: bool, authority: Callable) -> Dictionary:
	if histories.is_empty(): return _fail("party_required")
	var alive: Array = []
	var dead: Array = []
	var rewards: Array = []
	var members := {}
	var party_id := ""
	var wave_id := ""
	var outcome_ref := ""
	var save_namespace := ""
	var missing_outcome := false
	var declared_defeat := false
	var ids := histories.keys()
	for id: Variant in ids:
		if not id is String: return _fail("party_profile_identity_conflict")
	ids.sort()
	for id: Variant in ids:
		if not id is String or not histories[id] is Dictionary or histories[id].get("identity",{}).get("profile_id") != id: return _fail("party_profile_identity_conflict")
		var checked := replay(histories[id],authority)
		if not checked.success: return checked
		var state: Dictionary = checked.state
		if state.participation == "left": continue
		if save_namespace.is_empty(): save_namespace = histories[id].identity.namespace
		elif histories[id].identity.namespace != save_namespace: return _fail("party_namespace_conflict")
		var context: Dictionary = state.active_attempt
		if context.is_empty():
			if not enemies_defeated or state.wave_outcomes.is_empty(): return _fail("party_attempt_required")
			context = state.wave_outcomes.back()
		var member_wave: String = context.get("wave_id",context.get("checkpoint",{}).get("wave_id",""))
		if party_id.is_empty():
			party_id = context.team_id
			wave_id = member_wave
		elif context.team_id != party_id or member_wave != wave_id: return _fail("party_context_conflict")
		if state.life == "alive": alive.append(id)
		else: dead.append(id)
		var eligible := false
		if enemies_defeated:
			var outcome: Dictionary = context.get("outcome",{}) if not state.active_attempt.is_empty() else context
			if outcome.is_empty(): missing_outcome = true
			else:
				if outcome.final_wave != final_wave: return _fail("party_outcome_conflict")
				if outcome_ref.is_empty(): outcome_ref = outcome.outcome_ref
				elif outcome.outcome_ref != outcome_ref: return _fail("party_outcome_conflict")
				if not outcome.team_won: declared_defeat = true
				eligible = outcome.reward_eligible and state.life == "alive"
				if eligible: rewards.append(id)
		members[id] = {"normal_actions_allowed":not enemies_defeated and state.life == "alive","spectator":state.life == "dead","restoration_available":state.life == "dead","reward_participation_allowed":state.life == "alive","wave_rewards_eligible":eligible}
	if members.is_empty(): return _fail("active_party_required")
	if classify_party_completion(alive.size(),enemies_defeated) == "defeat" or declared_defeat:
		for member: Dictionary in members.values():
			member.wave_rewards_eligible = false
			member.normal_actions_allowed = false
			member.reward_participation_allowed = false
		return {"success":true,"members":members,"living":alive,"dead":dead,"combat_continues":false,"team_won":false,"team_defeated":true,"phase":"defeat","reward_eligible":[],"next_wave_allowed":false,"attempt_rollbacks_required":members.keys(),"automatic_resurrection":false,"free_actions_granted":0}
	if enemies_defeated and missing_outcome: return _fail("verified_wave_outcome_required")
	return {"success":true,"members":members,"living":alive,"dead":dead,"combat_continues":not enemies_defeated and not alive.is_empty(),"team_won":enemies_defeated,
		"team_defeated":false,"phase":"complete" if enemies_defeated and final_wave else ("between_waves" if enemies_defeated else "combat"),"reward_eligible":rewards,
		"next_wave_allowed":enemies_defeated and not final_wave and dead.is_empty(),"blocked_by_dead_members":dead.duplicate(),"final_wave_rollbacks_required":dead.duplicate() if enemies_defeated and final_wave else [],"automatic_resurrection":false,"free_actions_granted":0}

static func encode(history: Dictionary, authority: Callable) -> Dictionary:
	var checked := replay(history,authority)
	if not checked.success: return checked
	var body := canonical(history)
	var text := canonical({"body":body,"sha256":body.sha256_text()})
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("history_too_large")
	return {"success":true,"text":text}

static func decode(text: String, authority: Callable) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("history_too_large")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary or not _keys(parser.data,["body","sha256"]): return _fail("invalid_envelope")
	var envelope: Dictionary = parser.data
	if not envelope.body is String or not envelope.sha256 is String or envelope.body.sha256_text() != envelope.sha256: return _fail("checksum_mismatch")
	if parser.parse(envelope.body) != OK or not parser.data is Dictionary: return _fail("invalid_history_json")
	var history: Dictionary = _json_integers(parser.data)
	if canonical(history) != envelope.body: return _fail("noncanonical_history")
	var checked := replay(history,authority)
	if not checked.success: return checked
	return {"success":true,"history":history,"state":checked.state}

static func _apply(state: Dictionary, event: Dictionary, history: Dictionary, identities: Dictionary, authority: Callable) -> Dictionary:
	if not _keys(event,["event_id","sequence","parent_hash","order","kind","data"]): return _fail("invalid_event_fields")
	if typeof(event.sequence) != TYPE_INT or event.sequence != state.sequence+1: return _fail("event_sequence_gap")
	var prefix := _prefix(history.identity)
	if event.event_id != prefix+"/event/"+str(event.sequence) or event.parent_hash != state.head_hash: return _fail("event_identity_or_parent_conflict")
	if identities.has(event.event_id): return _fail("event_identity_conflict")
	identities[event.event_id] = true
	if not event.order is Dictionary or not _keys(event.order,["timestamp_us","resolution_index"]) or not _integer(event.order.timestamp_us,0) or not _integer(event.order.resolution_index,0): return _fail("invalid_event_order")
	if not state.last_order.is_empty() and (event.order.timestamp_us < state.last_order.timestamp_us or event.order.resolution_index <= state.last_order.resolution_index): return _fail("event_order_conflict")
	if not event.data is Dictionary or event.kind not in ["attributes","emergency_receipt","resurrection","effect_time","hpc_death","attempt_begin","attempt_rollback","attempt_commit","owned_state","wave_outcome","reward_receipt","restoration_decision"]: return _fail("unsupported_event_kind")
	if not _authorized(authority,"event",event,history.identity): return _fail("event_authority_required")
	var data: Dictionary = event.data
	if event.kind in ["attempt_begin","attempt_rollback","attempt_commit","owned_state","wave_outcome","reward_receipt","restoration_decision"]:
		if event.kind == "attempt_begin" and (not data.get("checkpoint") is Dictionary or not _authorized(authority,"checkpoint",data.checkpoint,history.identity)): return _fail("checkpoint_reference_authority_required")
		var lifecycle := _lifecycle_event(state,event,history.identity,identities)
		if not lifecycle.success: return lifecycle
	elif event.kind == "hpc_death":
		if not _keys(data,["source_event_id","source_ref"]) or not _text(data.source_ref) or not _claim(data.source_event_id,prefix,identities): return _fail("invalid_hpc_death_evidence")
		if state.life != "alive": return _fail("already_dead")
		state.life = "dead"
		state.deaths.append({"event_id":event.event_id,"cause_kind":"hpc","attributes":[],"sources":[data.duplicate(true)]})
	elif event.kind == "effect_time":
		if not _keys(data,["elapsed_us","frozen"]) or typeof(data.frozen) != TYPE_BOOL: return _fail("invalid_effect_time")
		state.effect_clock_frozen = data.frozen
		var aged := _age_sources(state,data.elapsed_us,false)
		if not aged.success: return aged
	elif event.kind == "resurrection":
		if not _keys(data,["effect_id","authorization_id","death_event_id"]+(["completion"] if data.has("completion") else [])) or not _text(data.effect_id) or not _claim(data.authorization_id,prefix,identities): return _fail("invalid_or_duplicate_resurrection_authority")
		if state.life != "dead" or not state.attribute_eligible or state.deaths.is_empty() or data.death_event_id != state.deaths.back().event_id: return _fail("resurrection_not_eligible")
		if not state.active_attempt.is_empty() or data.has("completion"):
			var completion := _resurrection_completion(state,data,history.identity)
			if not completion.success: return completion
			var action_key := "resurrection_action:"+String(data.completion.action_instance_id)
			if identities.has(action_key): return _fail("duplicate_resurrection_action")
			identities[action_key] = true
		# The trusted external verifier owns every other source-specific prerequisite.
		state.life = "alive"
		state.resurrections.append({"event_id":event.event_id,"authorization":data.duplicate(true)})
	else:
		var keys := ["change_kind","before","after","sources"]
		if event.kind == "emergency_receipt": keys.append("receipt")
		if data.has("effect_elapsed_us"): keys.append("effect_elapsed_us")
		if not _keys(data,keys) or data.change_kind not in ["permanent","temporary","recovery","effect_expiration"]: return _fail("invalid_attribute_event")
		if data.before != state.attributes or not data.after is Dictionary or not _keys(data.after,["permanent","effective"]): return _fail("attribute_history_conflict")
		for layer: String in ["permanent","effective"]:
			if not Evaluator._attributes(data.after[layer]).is_empty(): return _fail("invalid_attribute_snapshot")
			for score: int in data.after[layer].values():
				if score < -SAFE_INTEGER: return _fail("attribute_outside_serializable_range")
		if data.after == data.before: return _fail("empty_attribute_change")
		if data.change_kind in ["temporary","effect_expiration"] and data.after.permanent != data.before.permanent: return _fail("temporary_change_altered_permanent")
		if data.change_kind == "recovery" and state.life != "dead": return _fail("recovery_requires_death")
		if not _sources(data): return _fail("attribute_sources_incomplete")
		if data.has("effect_elapsed_us"):
			if data.change_kind != "effect_expiration": return _fail("elapsed_time_requires_expiration")
			var aged := _age_sources(state,data.effect_elapsed_us,true)
			if not aged.success: return aged
		var source_result := _source_lifecycle(state,data)
		if not source_result.success: return source_result
		if event.kind == "emergency_receipt":
			var receipt_result := _receipt(state,data,prefix,identities)
			if not receipt_result.success: return receipt_result
		var classification: Dictionary = history.origin.classification.duplicate(true)
		classification.initial_zero_exceptions = state.authored_exceptions.duplicate()
		if state.life == "alive":
			var evaluated := Evaluator.evaluate({"phase":"transition","life_before":"living","change_kind":data.change_kind,"classification":classification,"before":data.before,"after":data.after,"available_expc":state.available_expc})
			if not evaluated.success: return _fail("unresolved_attribute_transition")
			if evaluated.death_transition:
				var causes: Array = []
				for attribute: String in Evaluator.DEAD_AT_ZERO:
					if data.before.effective[attribute] > 0 and data.after.effective[attribute] <= 0: causes.append(attribute)
				state.life = "dead"
				state.deaths.append({"event_id":event.event_id,"cause_kind":"dead_attribute","attributes":causes,"sources":data.sources.duplicate(true)})
		# History proves untouched authored zeros; retire their exceptions forever
		# once they become positive. No blanket immunity on a later return to zero.
		for attribute: String in state.authored_exceptions.duplicate():
			if data.after.permanent[attribute] != 0 or data.after.effective[attribute] != 0: state.authored_exceptions.erase(attribute)
		state.attributes = data.after.duplicate(true)
		for attribute: String in Evaluator.PRIMARIES:
			state.permanent_high_water[attribute] = maxi(state.permanent_high_water[attribute],data.after.permanent[attribute])
		state.resurrection_barriers = []
		for attribute: String in Evaluator.DEAD_AT_ZERO:
			if data.after.effective[attribute] <= 0 and not state.authored_exceptions.has(attribute): state.resurrection_barriers.append(attribute)
		state.attribute_eligible = state.resurrection_barriers.is_empty()
		for source_id: String in state.source_remaining_us:
			if state.source_remaining_us[source_id] == 0: return _fail("effect_expiration_snapshot_required")
	state.sequence = event.sequence
	state.last_event_id = event.event_id
	state.last_order = event.order.duplicate(true)
	state.head_hash = fingerprint(event)
	return {"success":true}

static func _receipt(state: Dictionary, data: Dictionary, prefix: String, identities: Dictionary) -> Dictionary:
	var receipt: Variant = data.receipt
	if not receipt is Dictionary or not _keys(receipt,["transaction_id","debit_receipt_id","attribute","cost_expc","expc_before","expc_after"]+(["decision_id"] if receipt.has("decision_id") else [])): return _fail("invalid_emergency_receipt")
	if state.life != "dead" or data.change_kind != "recovery" or not Evaluator.DEAD_AT_ZERO.has(receipt.attribute): return _fail("emergency_recovery_not_applicable")
	var base: int = data.before.permanent[receipt.attribute]
	if base >= state.permanent_high_water[receipt.attribute]: return _fail("temporary_penalty_not_purchasable")
	var price := recovery_price(receipt.attribute,base)
	if not price.success: return price
	if not state.active_attempt.is_empty():
		var decision: Dictionary = state.pending_restoration
		if decision.is_empty() or receipt.get("decision_id") != decision.request_id or decision.attribute != receipt.attribute or decision.expected_permanent != base or decision.expected_expc != state.available_expc or decision.death_event_id != state.deaths.back().event_id: return _fail("explicit_restoration_decision_required")
	if not _integer(receipt.cost_expc,0) or receipt.cost_expc != price.cost_expc or not _integer(receipt.expc_before,0) or not _integer(receipt.expc_after,0) or receipt.expc_before != state.available_expc or receipt.expc_before < receipt.cost_expc or receipt.expc_after != receipt.expc_before-receipt.cost_expc: return _fail("emergency_receipt_accounting_mismatch")
	var expected: Dictionary = data.before.duplicate(true)
	for layer: String in ["permanent","effective"]:
		expected[layer][receipt.attribute] += 1
	if expected != data.after: return _fail("unsupported_emergency_recovery")
	if not _claim(receipt.transaction_id,prefix,identities) or not _claim(receipt.debit_receipt_id,prefix,identities): return _fail("duplicate_or_invalid_receipt_identity")
	# Projection of an EXTERNALLY committed fixture receipt; no ledger is called.
	state.available_expc = receipt.expc_after
	state.receipts.append(receipt.duplicate(true))
	state.pending_restoration = {}
	return {"success":true}

static func _lifecycle_event(state: Dictionary, event: Dictionary, identity: Dictionary, identities: Dictionary) -> Dictionary:
	var data: Dictionary = event.data
	var prefix := _prefix(identity)
	if event.kind == "restoration_decision":
		if not _keys(data,["request_id","actor_profile_id","choice","attribute"]) or data.actor_profile_id != identity.profile_id or state.life != "dead" or not _claim(data.request_id,prefix,identities): return _fail("invalid_restoration_decision")
		if data.choice == "not_now":
			if data.attribute != "": return _fail("invalid_not_now")
			state.pending_restoration = {}
		elif data.choice == "restore_one":
			if not Evaluator.DEAD_AT_ZERO.has(data.attribute): return _fail("invalid_restoration_attribute")
			var base: int = state.attributes.permanent[data.attribute]
			if base >= state.permanent_high_water[data.attribute]: return _fail("temporary_penalty_not_purchasable")
			var price := recovery_price(data.attribute,base)
			if not price.success: return price
			if state.available_expc < price.cost_expc: return _fail("insufficient_expc")
			state.pending_restoration = {"request_id":data.request_id,"attribute":data.attribute,"expected_permanent":base,"expected_expc":state.available_expc,"death_event_id":state.deaths.back().event_id}
		else: return _fail("invalid_restoration_choice")
		state.decisions.append({"event_id":event.event_id,"decision":data.duplicate(true)})
		return {"success":true}
	if event.kind == "attempt_begin":
		if state.life != "alive": return _fail("dead_participant_cannot_start_attempt")
		if not _keys(data,["attempt_id","team_id","checkpoint","owned_state"]) or not state.active_attempt.is_empty() or state.participation != "member" or not _text(data.team_id) or not data.owned_state is Dictionary or not _claim(data.attempt_id,prefix,identities): return _fail("invalid_attempt_begin")
		var checkpoint: Variant = data.checkpoint
		if not checkpoint is Dictionary or not _keys(checkpoint,["contract","phase","profile_id","run_id","wave_id","generation","document_digest","event_count","history_head"]): return _fail("verified_wave_entry_reference_required")
		if checkpoint.contract != "CharacterWaveCheckpoint/v1" or checkpoint.phase != "entry" or checkpoint.profile_id != identity.profile_id or not _text(checkpoint.run_id) or not checkpoint.run_id.is_valid_identifier() or checkpoint.wave_id not in ["wave_1","wave_2","wave_3","wave_4","wave_5"] or not _integer(checkpoint.generation,1) or not checkpoint.document_digest is String or checkpoint.document_digest.length() != 64 or not checkpoint.document_digest.is_valid_hex_number(false) or not _integer(checkpoint.event_count,0) or checkpoint.event_count != state.sequence or checkpoint.history_head != state.head_hash: return _fail("checkpoint_reference_conflict")
		# Authority must match the digest to the actual acknowledged wave-entry
		# checkpoint and its validated equipment/inventory/resource projection.
		state.owned_state = data.owned_state.duplicate(true)
		var baseline := {}
		for field: String in ATTEMPT_FIELDS: baseline[field] = _copy_value(state[field])
		state.active_attempt = {"attempt_id":data.attempt_id,"team_id":data.team_id,"checkpoint":checkpoint.duplicate(true),"baseline":baseline,"outcome":{}}
		state.pending_restoration = {}
		return {"success":true}
	if state.active_attempt.is_empty() or data.get("attempt_id") != state.active_attempt.attempt_id: return _fail("active_attempt_required")
	var attempt: Dictionary = state.active_attempt
	if event.kind == "owned_state":
		if not _keys(data,["attempt_id","before","after","source_ref"]) or data.before != state.owned_state or not data.after is Dictionary or not _text(data.source_ref): return _fail("owned_state_conflict")
		state.owned_state = data.after.duplicate(true)
	elif event.kind == "wave_outcome":
		if not _keys(data,["attempt_id","team_won","final_wave","outcome_ref"]) or typeof(data.team_won) != TYPE_BOOL or typeof(data.final_wave) != TYPE_BOOL or not _text(data.outcome_ref) or not attempt.outcome.is_empty() or data.final_wave != (attempt.checkpoint.wave_id == "wave_5"): return _fail("wave_outcome_conflict")
		var outcome := {"event_id":event.event_id,"attempt_id":attempt.attempt_id,"team_id":attempt.team_id,"run_id":attempt.checkpoint.run_id,"wave_id":attempt.checkpoint.wave_id,"final_wave":data.final_wave,"outcome_ref":data.outcome_ref,"team_won":data.team_won,"life_at_completion":state.life,"reward_eligible":data.team_won and state.life == "alive"}
		attempt.outcome = outcome.duplicate(true)
		state.wave_outcomes.append(outcome)
	elif event.kind == "reward_receipt":
		if not _keys(data,["attempt_id","outcome_event_id","receipt_id","expc_before","expc_after","owned_before","owned_after","source_ref"]): return _fail("invalid_reward_receipt")
		if attempt.outcome.is_empty() or not attempt.outcome.reward_eligible or state.life != "alive" or data.outcome_event_id != attempt.outcome.event_id: return _fail("dead_player_reward_excluded")
		if not _integer(data.expc_before,0) or not _integer(data.expc_after,0) or data.expc_before != state.available_expc or data.expc_after < data.expc_before or data.owned_before != state.owned_state or not data.owned_after is Dictionary or not _text(data.source_ref) or not _claim(data.receipt_id,prefix,identities): return _fail("invalid_reward_receipt")
		# Observe already-authorized ledger results; never calculate or distribute rewards.
		state.available_expc = data.expc_after
		state.owned_state = data.owned_after.duplicate(true)
		state.reward_receipts.append(data.duplicate(true))
	elif event.kind == "attempt_commit":
		if not _keys(data,["attempt_id","outcome_ref"]) or attempt.outcome.is_empty() or not attempt.outcome.team_won or data.outcome_ref != attempt.outcome.outcome_ref or state.life != "alive": return _fail("living_successful_attempt_required")
		state.closed_attempt_ids.append(attempt.attempt_id)
		state.active_attempt = {}
		state.pending_restoration = {}
	elif event.kind == "attempt_rollback":
		if not _keys(data,["attempt_id","checkpoint_digest","reason","outcome_ref"]) or data.checkpoint_digest != attempt.checkpoint.document_digest or data.reason not in ["retry","restart","return","departure_after_victory","final_wave_dead"]: return _fail("rollback_checkpoint_conflict")
		if not attempt.outcome.is_empty() and attempt.outcome.team_won and state.life == "alive": return _fail("successful_living_attempt_cannot_be_discarded")
		if data.reason in ["departure_after_victory","final_wave_dead"]:
			if state.life != "dead" or attempt.outcome.is_empty() or not attempt.outcome.team_won or data.outcome_ref != attempt.outcome.outcome_ref or (data.reason == "final_wave_dead" and not attempt.outcome.final_wave): return _fail("dead_successful_wave_required")
		elif data.outcome_ref != "": return _fail("unexpected_rollback_outcome")
		var voided: Array = []
		for receipt: Dictionary in state.receipts.slice(attempt.baseline.receipts.size()): voided.append(receipt.transaction_id)
		var discarded := {"event_id":event.event_id,"attempt_id":attempt.attempt_id,"reason":data.reason,"checkpoint":attempt.checkpoint.duplicate(true),"voided_purchase_ids":voided,"discarded_head":state.head_hash}
		for field: String in ATTEMPT_FIELDS: state[field] = _copy_value(attempt.baseline[field])
		state.discarded_attempts.append(discarded)
		state.closed_attempt_ids.append(attempt.attempt_id)
		state.active_attempt = {}
		state.pending_restoration = {}
		if data.reason in ["departure_after_victory","final_wave_dead"]: state.participation = "left"
	else: return _fail("unsupported_lifecycle_event")
	return {"success":true}

# One verified source definition only. Other resurrection variants require their
# own evidence/validator; four Acts is NOT a universal resurrection rule.
static func _resurrection_completion(state: Dictionary, data: Dictionary, identity: Dictionary) -> Dictionary:
	var completion: Variant = data.get("completion")
	var fields := ["definition_id","source_ref","caster_profile_id","target_profile_id","caster_life","context","action_instance_id","completed_acts","mana_spent","caster_mana_before","caster_mana_after","corpse_age_seconds","touch_verified","prerequisites_verified"]
	if not completion is Dictionary or not _keys(completion,fields): return _fail("verified_resurrection_completion_required")
	if completion.definition_id != "prime_v3_resurrect_p301": return _unsupported("resurrection_definition_unverified")
	if data.effect_id != completion.definition_id: return _fail("resurrection_definition_conflict")
	if not _text(completion.source_ref) or not _text(completion.action_instance_id) or completion.target_profile_id != identity.profile_id or completion.caster_profile_id == identity.profile_id or not _text(completion.caster_profile_id) or completion.caster_life != "alive": return _fail("invalid_resurrection_actor")
	var outcome: Dictionary = state.active_attempt.get("outcome",{})
	if not outcome.is_empty() and outcome.final_wave: return _fail("final_wave_dead_rollback_required")
	var context := "combat" if outcome.is_empty() else "between_waves"
	if completion.context != context or not _integer(completion.completed_acts,0) or completion.completed_acts != 4 or not _integer(completion.mana_spent,0) or completion.mana_spent != 50 or not _integer(completion.caster_mana_before,50) or not _integer(completion.caster_mana_after,0) or completion.caster_mana_after != completion.caster_mana_before-50 or not _integer(completion.corpse_age_seconds,0) or completion.corpse_age_seconds > 72*60*60 or typeof(completion.touch_verified) != TYPE_BOOL or not completion.touch_verified or typeof(completion.prerequisites_verified) != TYPE_BOOL or not completion.prerequisites_verified: return _fail("resurrection_action_or_cost_incomplete")
	return {"success":true,"free_actions_granted":0}

static func _copy_value(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

static func _sources(data: Dictionary) -> bool:
	if not data.sources is Array or data.sources.is_empty(): return false
	var seen := {}
	var permanent := {}
	var effective := {}
	for source: Variant in data.sources:
		if not source is Dictionary or not _keys(source,["source_id","source_ref","kind","attributes"]+(["remaining_duration_us"] if source.has("remaining_duration_us") else [])): return false
		if not _text(source.source_id) or seen.has(source.source_id) or not _text(source.source_ref) or source.kind not in ["permanent","temporary"] or not source.attributes is Array or source.attributes.is_empty(): return false
		if source.has("remaining_duration_us") and (source.kind != "temporary" or not _integer(source.remaining_duration_us,1)): return false
		seen[source.source_id] = true
		var attributes := {}
		for attribute: Variant in source.attributes:
			if not attribute is String or not Evaluator.PRIMARIES.has(attribute) or attributes.has(attribute): return false
			attributes[attribute] = true
			effective[attribute] = true
			if source.kind == "permanent": permanent[attribute] = true
	for attribute: String in Evaluator.PRIMARIES:
		if data.before.permanent[attribute] != data.after.permanent[attribute] and not permanent.has(attribute): return false
		if data.before.effective[attribute] != data.after.effective[attribute] and not effective.has(attribute): return false
	return true

# Only explicit source/time records are consumed; no live clock or timers.
static func _source_lifecycle(state: Dictionary, data: Dictionary) -> Dictionary:
	for source: Dictionary in data.sources:
		if source.kind == "permanent":
			if data.change_kind in ["temporary","effect_expiration"]: return _fail("temporary_source_required")
			continue
		if data.change_kind == "effect_expiration":
			if state.effect_clock_frozen: return _fail("effect_expiration_while_frozen")
			if state.active_sources.get(source.source_id) != source: return _fail("expiration_source_history_conflict")
			if state.source_remaining_us.get(source.source_id,0) > 0: return _fail("effect_not_due")
			state.active_sources.erase(source.source_id)
			state.source_remaining_us.erase(source.source_id)
		else:
			if state.active_sources.has(source.source_id): return _fail("temporary_source_already_active")
			state.active_sources[source.source_id] = source.duplicate(true)
			if source.has("remaining_duration_us"): state.source_remaining_us[source.source_id] = source.remaining_duration_us
	return {"success":true}

static func _age_sources(state: Dictionary, elapsed: Variant, allow_due: bool) -> Dictionary:
	if not _integer(elapsed,0): return _fail("invalid_effect_elapsed_time")
	if state.effect_clock_frozen or elapsed == 0: return {"success":true}
	for source_id: String in state.active_sources:
		if not state.source_remaining_us.has(source_id): return _unsupported("temporary_duration_unverified")
		var remaining: int = state.source_remaining_us[source_id]
		if elapsed > remaining or (elapsed == remaining and not allow_due): return _fail("effect_expiration_snapshot_required")
		state.source_remaining_us[source_id] = remaining-elapsed
	return {"success":true}

static func _identity(value: Dictionary) -> bool:
	if not _keys(value,["profile_id","namespace","character_id","rules_revision","history_id"]): return false
	for field: String in value:
		if not _text(value[field]): return false
	return value.namespace in ["normal","dev_normal"] and value.profile_id.is_valid_identifier() and value.history_id.is_valid_identifier() and value.profile_id.begins_with("prod_" if value.namespace == "normal" else "dev_")

static func _prefix(identity: Dictionary) -> String:
	return identity.namespace+"/"+identity.profile_id+"/"+identity.history_id

static func _claim(value: Variant, prefix: String, seen: Dictionary) -> bool:
	if not _text(value) or not value.begins_with(prefix+"/") or value.length() <= prefix.length()+1 or seen.has(value): return false
	seen[value] = true
	return true

static func _authorized(verifier: Callable, kind: String, record: Dictionary, identity: Dictionary) -> bool:
	if not verifier.is_valid(): return false
	var result: Variant = verifier.call(kind,record.duplicate(true),identity.duplicate(true))
	return typeof(result) == TYPE_BOOL and result

static func canonical(value: Dictionary) -> String:
	return JSON.stringify(value,"",true,true)

static func fingerprint(value: Dictionary) -> String:
	return canonical(value).sha256_text()

static func _json_integers(value: Variant, depth: int = 0) -> Variant:
	if depth > 16: return null
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _json_integers(value[key],depth+1)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_integers(item,depth+1))
		return result
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value) and absf(value) <= SAFE_INTEGER: return int(value)
	return value

static func _integer(value: Variant, minimum: int) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= SAFE_INTEGER

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256

static func _keys(value: Dictionary, fields: Array) -> bool:
	return value.size() == fields.size() and value.has_all(fields)

static func _fail(reason: String) -> Dictionary:
	return {"success":false,"reason":reason,"action_performed":false,"ledger_writes":0}

static func _unsupported(reason: String) -> Dictionary:
	var result := _fail(reason)
	result["status"] = "unsupported"
	return result
