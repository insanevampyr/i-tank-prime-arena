extends "res://tests/test_task_37c_life_state_history.gd"

func run() -> Array[String]:
	for test: Callable in [_test_notification_and_decision,_test_combat_and_resurrection,_test_departure_and_rewards,_test_discard_and_ack,_test_final_and_hpc,_test_rollback_publication,_test_checkpoint_and_party_constraints]:
		approvals.clear()
		observed_heads.clear()
		test.call()
	print("37C dormant death/multiplayer lifecycle: %d assertions; explicit decisions, source-specific completion, reward exclusion and checkpoint discard." % assertions)
	return failures

func _participant(name: String) -> Dictionary:
	var history := _fixture(12000)
	history.identity.profile_id = "prod_"+name
	history.identity.character_id = "fixture_"+name
	_approve("origin",history.origin,history.identity)
	return history

func _begin(history: Dictionary, suffix: String = "one", wave: String = "wave_3") -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	var owned := {"source_profile_digest":"fixture_already_verified_profile","inventory":{"fixture_starting_potion":2},"equipment":{"fixture_shield":{"shp":7}},"resources":{"hpc":8,"mana":120}}
	var reference := {"contract":"CharacterWaveCheckpoint/v1","phase":"entry","profile_id":history.identity.profile_id,"run_id":"fixture_existing_run","wave_id":wave,"generation":1,"document_digest":"a".repeat(64),"event_count":state.sequence,"history_head":state.head_hash}
	_approve("checkpoint",reference,history.identity)
	return _added(history,_event(history,"attempt_begin",{"attempt_id":Contract._prefix(history.identity)+"/attempt/"+suffix,"team_id":"fixture_team","checkpoint":reference,"owned_state":owned}))

func _decision(history: Dictionary, attribute: String, suffix: String, choice: String = "restore_one") -> Dictionary:
	return _event(history,"restoration_decision",{"request_id":Contract._prefix(history.identity)+"/decision/"+suffix,"actor_profile_id":history.identity.profile_id,"choice":choice,"attribute":attribute})

func _purchase(history: Dictionary, attribute: String, suffix: String) -> Dictionary:
	var requested := _decision(history,attribute,suffix)
	history = _added(history,requested)
	var receipt := _step_receipt(history,attribute,suffix,2000)
	receipt.data.receipt.decision_id = requested.data.request_id
	return _added(history,receipt)

func _outcome(history: Dictionary, final: bool = false) -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	return _added(history,_event(history,"wave_outcome",{"attempt_id":state.active_attempt.attempt_id,"team_won":true,"final_wave":final,"outcome_ref":"externally_verified_team_victory"}))

func _rollback_event(history: Dictionary, reason: String) -> Dictionary:
	var attempt: Dictionary = Contract.replay(history,_authority).state.active_attempt
	return _event(history,"attempt_rollback",{"attempt_id":attempt.attempt_id,"checkpoint_digest":attempt.checkpoint.document_digest,"reason":reason,"outcome_ref":attempt.outcome.get("outcome_ref","") if reason in ["departure_after_victory","final_wave_dead"] else ""})

func _completion(history: Dictionary, phase: String = "combat") -> Dictionary:
	var event := _resurrection_event(history)
	event.data.effect_id = "prime_v3_resurrect_p301"
	event.data.completion = {"definition_id":"prime_v3_resurrect_p301","source_ref":"ITank Prime V3 printed p.301; verified exact fixture completion","caster_profile_id":"prod_teammate","target_profile_id":history.identity.profile_id,"caster_life":"alive","context":phase,"action_instance_id":"normal/prod_teammate/fixture_run/action/cast_"+str(history.events.size()),"completed_acts":4,"mana_spent":50,"caster_mana_before":120,"caster_mana_after":70,"corpse_age_seconds":60,"touch_verified":true,"prerequisites_verified":true}
	return event

func _test_notification_and_decision() -> void:
	var history := _begin(_participant("victim"))
	history = _added(history,_attribute_event(history,{"str":-3,"wis":0}))
	var original := history.duplicate(true)
	var notice := Contract.death_notification(history,_authority)
	check(notice.success and notice.cause_kind == "dead_attribute" and notice.affected_attributes == ["str","wis"],"Notification reports every causal lethal attribute.")
	check(notice.options.size() == 2 and notice.options[0].to_positive.total_cost_expc == 8000 and notice.options[1].next_cost_expc == 2000 and notice.can_restore_one,"Notification reports exact recovery price and personal affordability.")
	check(notice.can_choose_not_now and notice.can_revisit and not notice.countdown and not notice.spends_expc and notice.spectate and not notice.normal_actions_allowed,"Notification offers a nonspending deferred decision with no timer or normal actions.")
	check(notice.resurrection_explanation.contains("does not resurrect") and notice.resurrection_explanation.contains("Another character"),"Recovery and legitimate separate resurrection remain explicit.")
	check(history == original and Contract.death_notification(history,_authority) == notice,"Presentation query is deterministic and immutable.")
	_reject(history,_step_receipt(history,"str","unrequested",2000),"explicit_restoration_decision_required")
	var foreign := _decision(history,"str","foreign")
	foreign.data.actor_profile_id = "prod_teammate"
	_reject(history,foreign,"invalid_restoration_decision")
	var not_now := _decision(history,"","later","not_now")
	history = _added(history,not_now)
	check(Contract.replay(history,_authority).state.available_expc == 12000 and Contract.death_notification(history,_authority).can_restore_one,"Not Now spends nothing and may be revisited while dead.")
	_reject(history,not_now,"duplicate_event")
	history = _purchase(history,"str","minus_two")
	var state: Dictionary = Contract.replay(history,_authority).state
	check(state.available_expc == 10000 and state.attributes.permanent.str == -2 and state.life == "dead" and state.pending_restoration.is_empty(),"A later explicit decision permits exactly one receipt without revival.")
	_reject(history,_step_receipt(history,"str","no_second_decision",2000),"explicit_restoration_decision_required")
	var insufficient := _participant("poor")
	insufficient.origin.available_expc = 1999
	_approve("origin",insufficient.origin,insufficient.identity)
	insufficient = _begin(insufficient)
	insufficient = _added(insufficient,_attribute_event(insufficient,{"wis":0}))
	check(not Contract.death_notification(insufficient,_authority).can_restore_one,"Unaffordable restoration remains explained but unavailable.")
	_reject(insufficient,_decision(insufficient,"wis","poor"),"insufficient_expc")

func _test_combat_and_resurrection() -> void:
	var dead := _begin(_participant("victim"))
	var living := _begin(_participant("teammate"))
	dead = _added(dead,_attribute_event(dead,{"wis":0}))
	var histories := {"prod_victim":dead,"prod_teammate":living}
	var view := Contract.party_view(histories,false,false,_authority)
	check(view.success and view.combat_continues and view.members.prod_teammate.normal_actions_allowed and not view.members.prod_victim.normal_actions_allowed,"Surviving teammates keep fighting while dead players spectate.")
	check(view.members.prod_victim.spectator and view.members.prod_victim.restoration_available and not view.members.prod_victim.wave_rewards_eligible,"Dead players retain restoration access, never ordinary actions or rewards.")
	check(not view.members.prod_victim.reward_participation_allowed and view.members.prod_teammate.reward_participation_allowed,"Death excludes kill/loot/reward participation during combat as well as wave-completion rewards.")
	dead = _purchase(dead,"wis","recover")
	var resurrection := _completion(dead)
	for pair: Array in [["completed_acts",1],["mana_spent",0],["caster_mana_before",49],["caster_mana_after",71],["corpse_age_seconds",259201],["touch_verified",false],["prerequisites_verified",false]]:
		var bad := resurrection.duplicate(true)
		bad.data.completion[pair[0]] = pair[1]
		_reject(dead,bad,"resurrection_action_or_cost_incomplete")
	var unknown := resurrection.duplicate(true)
	unknown.data.completion.definition_id = "unverified_variant"
	_reject(dead,unknown,"resurrection_definition_unverified")
	_reject(dead,_resurrection_event(dead),"verified_resurrection_completion_required")
	var dead_caster := resurrection.duplicate(true)
	dead_caster.data.completion.caster_life = "dead"
	_reject(dead,dead_caster,"invalid_resurrection_actor")
	var before: Dictionary = Contract.replay(dead,_authority).state
	dead = _added(dead,resurrection)
	var after: Dictionary = Contract.replay(dead,_authority).state
	check(after.life == "alive" and after.available_expc == before.available_expc and after.owned_state == before.owned_state,"Source-verified completion changes prototype life only; no invented resource or free action grant.")
	check(after.resurrections.back().authorization.completion.completed_acts == 4 and after.resurrections.back().authorization.completion.mana_spent == 50,"Spent Acts/Mana evidence survives the resurrection record.")
	histories.prod_victim = dead
	view = Contract.party_view(histories,false,false,_authority)
	check(view.free_actions_granted == 0 and view.members.prod_victim.normal_actions_allowed,"Resurrection restores legal participation without an extra turn.")
	dead = _added(dead,_attribute_event(dead,{"wis":0}))
	dead = _outcome(dead)
	living = _outcome(living)
	histories = {"prod_victim":dead,"prod_teammate":living}
	view = Contract.party_view(histories,true,false,_authority)
	check(view.team_won and view.phase == "between_waves" and not view.next_wave_allowed and view.blocked_by_dead_members == ["prod_victim"],"Team victory carries a dead member into downtime and blocks the next wave.")
	dead = _purchase(dead,"wis","between_recover")
	var cast := _completion(dead,"between_waves")
	cast.data.authorization_id += "_between"
	var replay_cast := cast.duplicate(true)
	replay_cast.data.completion.action_instance_id = resurrection.data.completion.action_instance_id
	_reject(dead,replay_cast,"duplicate_resurrection_action")
	dead = _added(dead,cast)
	_reject(dead,_reward_event(dead),"dead_player_reward_excluded")
	histories.prod_victim = dead
	view = Contract.party_view(histories,true,false,_authority)
	check(view.next_wave_allowed and view.reward_eligible == ["prod_teammate"],"Between-wave resurrection unblocks progression but cannot retroactively earn the missed wave rewards.")

func _reward_event(history: Dictionary) -> Dictionary:
	var state: Dictionary = Contract.replay(history,_authority).state
	var owned: Dictionary = state.owned_state.duplicate(true)
	owned["observed_wave_currency"] = 17
	return _event(history,"reward_receipt",{"attempt_id":state.active_attempt.attempt_id,"outcome_event_id":state.active_attempt.outcome.event_id,"receipt_id":Contract._prefix(history.identity)+"/reward/already_authorized","expc_before":state.available_expc,"expc_after":state.available_expc+100,"owned_before":state.owned_state.duplicate(true),"owned_after":owned,"source_ref":"externally authorized isolated ledger result, not a reward formula"})

func _test_departure_and_rewards() -> void:
	var dead := _begin(_participant("victim"))
	var living := _begin(_participant("teammate"))
	dead = _added(dead,_attribute_event(dead,{"str":-1}))
	dead = _purchase(dead,"str","zero")
	dead = _outcome(dead)
	living = _outcome(living)
	_reject(dead,_reward_event(dead),"dead_player_reward_excluded")
	living = _added(living,_reward_event(living))
	_reject(living,_rollback_event(living,"retry"),"successful_living_attempt_cannot_be_discarded")
	var state: Dictionary = Contract.replay(living,_authority).state
	living = _added(living,_event(living,"attempt_commit",{"attempt_id":state.active_attempt.attempt_id,"outcome_ref":state.active_attempt.outcome.outcome_ref}))
	var untouched := living.duplicate(true)
	dead = _added(dead,_rollback_event(dead,"departure_after_victory"))
	state = Contract.replay(dead,_authority).state
	check(state.life == "alive" and state.available_expc == 12000 and state.attributes.permanent.str == 10 and state.participation == "left","Dead departure is a personal failed attempt restoring its checkpoint attributes and EXPC.")
	var view := Contract.party_view({"prod_victim":dead,"prod_teammate":living},true,false,_authority)
	check(view.success and view.next_wave_allowed and view.reward_eligible == ["prod_teammate"] and not view.members.has("prod_victim"),"Departure removes the dead progression gate without paying that player rewards.")
	check(living == untouched and Contract.replay(living,_authority).state.available_expc == 12100 and Contract.replay(living,_authority).state.owned_state.observed_wave_currency == 17,"Survivor's independently committed XP/currency remains exact and untouched.")

func _test_discard_and_ack() -> void:
	for reason: String in ["retry","restart","return"]:
		var history := _participant("victim")
		history = _added(history,_attribute_event(history,{"str":0}))
		history = _added(history,_step_receipt(history,"str","pre_checkpoint",2000))
		history = _added(history,_resurrection_event(history)) # Legacy externally authorized completed effect, outside attempt.
		var prior: Dictionary = Contract.replay(history,_authority).state
		var origin := history.duplicate(true)
		history = _begin(history)
		history = _added(history,_attribute_event(history,{"str":-1,"wis":0}))
		history = _purchase(history,"str","attempt_spend")
		var state: Dictionary = Contract.replay(history,_authority).state
		var owned: Dictionary = state.owned_state.duplicate(true)
		owned.inventory.fixture_starting_potion = 1
		owned.equipment.fixture_shield.shp = 2
		history = _added(history,_event(history,"owned_state",{"attempt_id":state.active_attempt.attempt_id,"before":state.owned_state.duplicate(true),"after":owned,"source_ref":"verified fixture consumption and shield wear"}))
		var proposed := _rollback_event(history,reason)
		_approve("event",proposed,history.identity)
		check(Contract.reconcile(history,proposed,_authority).status == "not_recorded","Interrupted discard is not an applied refund.")
		var rolled := _added(history,proposed)
		state = Contract.replay(rolled,_authority).state
		check(state.life == prior.life and state.attributes == prior.attributes and state.available_expc == prior.available_expc and state.receipts == prior.receipts,"Discard restores only attempt changes and preserves the pre-checkpoint recovery transaction.")
		check(state.owned_state.inventory.fixture_starting_potion == 2 and state.owned_state.equipment.fixture_shield.shp == 7 and state.owned_state.resources == {"hpc":8,"mana":120},"Discard returns exact verified inventory/equipment/resource snapshot, not an invented refill.")
		check(state.discarded_attempts.size() == 1 and state.discarded_attempts[0].voided_purchase_ids.size() == 1 and rolled.events.size() == history.events.size()+1,"Rollback appends an audit record; it never deletes the spent identity or old event history.")
		_reject(rolled,proposed,"duplicate_event")
		var repeated := _event(rolled,"attempt_rollback",proposed.data)
		_reject(rolled,repeated,"active_attempt_required")
		var encoded := Contract.encode(rolled,_authority)
		check(Contract.decode(encoded.text,_authority).state == state and Contract.reconcile(rolled,proposed,_authority).status == "recorded","Crash/reload and lost acknowledgement preserve one cancellation with no duplicated refund.")
		# The publication stays a monotonic generation despite a lower net spent projection.
		var empty := _participant("other_unused")
		check(not Contract.compare_recovery(empty,rolled,_authority).success,"Another profile cannot receive or roll back this history.")
		check(origin.events.size() < rolled.events.size(),"Pre-match committed history remains present as the exact audit prefix.")

func _test_final_and_hpc() -> void:
	var dead := _begin(_participant("victim"),"final","wave_5")
	var living := _begin(_participant("teammate"),"final","wave_5")
	dead = _added(dead,_event(dead,"hpc_death",{"source_event_id":Contract._prefix(dead.identity)+"/damage/lethal","source_ref":"externally verified HPC death, not inferred from HPC<=0"}))
	var notice := Contract.death_notification(dead,_authority)
	check(notice.cause_kind == "hpc" and notice.options.is_empty() and not notice.can_restore_one and notice.available_expc == 12000,"HPC death alone has no2000 EXPC restoration charge.")
	check(notice.affected_attributes.is_empty() and notice.recovery_explanation.contains("No attribute restoration"),"HPC and lethal-attribute death remain distinct in notification data.")
	dead = _outcome(dead,true)
	living = _outcome(living,true)
	_reject(dead,_reward_event(dead),"dead_player_reward_excluded")
	var cast := _completion(dead,"between_waves")
	_reject(dead,cast,"final_wave_dead_rollback_required")
	var view := Contract.party_view({"prod_victim":dead,"prod_teammate":living},true,true,_authority)
	check(view.team_won and view.phase == "complete" and view.final_wave_rollbacks_required == ["prod_victim"] and view.reward_eligible == ["prod_teammate"],"Final-wave victory excludes the dead member's completion rewards and requires their personal rollback.")
	dead = _added(dead,_rollback_event(dead,"final_wave_dead"))
	var state: Dictionary = Contract.replay(dead,_authority).state
	check(state.life == "alive" and state.available_expc == 12000 and state.receipts.is_empty() and state.participation == "left","Final-wave personal failure restores the checkpoint without forced EXPC spending.")
	check(Contract.replay(living,_authority).state.life == "alive","Living teammate state is never rolled back by another member's final failure.")

func _test_rollback_publication() -> void:
	var origin := _participant("victim")
	var history := _begin(origin)
	history = _added(history,_attribute_event(history,{"str":-3}))
	history = _purchase(history,"str","failed_spend")
	var first := _ack(_prepare(origin,{},history,"failed_attempt"))
	var before: Dictionary = Contract.replay(history,_authority).state
	check(before.available_expc == 10000 and before.life == "dead","An attempt-scoped purchase may already have a verified durable generation.")
	var rollback := _rollback_event(history,"retry")
	var forged := rollback.duplicate(true)
	forged.data.checkpoint_digest = "b".repeat(64)
	_reject(history,forged,"rollback_checkpoint_conflict")
	check(not Contract.append(history,rollback,_authority).success,"A rollback cannot be inferred or performed without external authorization.")
	var restored := _added(history,rollback)
	var proposal := _prepare(history,first,restored,"discard_attempt")
	check(not Contract.acknowledge_generation(proposal,restored,proposal.binding,_authority).success,"Interrupted rollback publication is not acknowledged as a refund.")
	check(Contract.verify_generation(history,first,_authority).state.available_expc == 10000,"The last verified generation remains exact while discard acknowledgement is uncertain.")
	check(Contract.reconcile(history,rollback,_authority).status == "not_recorded","Before publication, recovery never fabricates a cancellation.")
	var second := _ack(proposal)
	check(second.generation == 2 and restored.events.slice(0,history.events.size()) == history.events,"A compensating discard is a monotonic new generation retaining the audit prefix.")
	var serialized := Contract.canonical({"history":restored,"binding":second})
	var reopened: Dictionary = Contract._json_integers(JSON.parse_string(serialized))
	var verified := Contract.verify_generation(reopened.history,reopened.binding,_authority)
	check(verified.success and verified.state.life == "alive" and verified.state.available_expc == 12000 and verified.state.attributes.permanent.str == 10 and verified.state.discarded_attempts.size() == 1,"Crash/reload restores checkpoint state with exactly one cancellation record.")
	check(Contract.acknowledge_generation(proposal,reopened.history,reopened.binding,_authority).success and Contract.reconcile(reopened.history,rollback,_authority).status == "recorded","Lost acknowledgement reconciles the exact rollback, not a second refund.")
	_reject(reopened.history,_event(reopened.history,"attempt_rollback",rollback.data),"active_attempt_required")
	check(not Contract.prepare_generation(first,history,restored,1,Contract._prefix(origin.identity)+"/publication/stale_discard",_authority).success,"Stale generation cannot republish a rollback over a newer acknowledged head.")
	var repeated := _begin(restored,"second")
	repeated = _added(repeated,_attribute_event(repeated,{"str":-3}))
	var decision := _decision(repeated,"str","new_attempt")
	repeated = _added(repeated,decision)
	var stale_purchase := _step_receipt(repeated,"str","failed_spend",2000)
	stale_purchase.data.receipt.decision_id = decision.data.request_id
	_reject(repeated,stale_purchase,"duplicate_or_invalid_receipt_identity")
	var fresh := _step_receipt(repeated,"str","fresh_attempt_purchase",2000)
	fresh.data.receipt.decision_id = decision.data.request_id
	repeated = _added(repeated,fresh)
	check(Contract.replay(repeated,_authority).state.available_expc == 10000,"A genuinely new authorized attempt can make a distinct purchase; old IDs remain unusable.")
	check(Contract.encode(reopened.history,_authority).text == Contract.encode(restored,_authority).text,"Compensating history serialization remains canonical and deterministic.")

func _test_checkpoint_and_party_constraints() -> void:
	var origin := _participant("victim")
	var opened := _begin(origin)
	var wrong: Dictionary = opened.events.back().duplicate(true)
	wrong.data.checkpoint.document_digest = "b".repeat(64)
	_reject(origin,wrong,"checkpoint_reference_authority_required")
	wrong = opened.events.back().duplicate(true)
	wrong.data.checkpoint.contract = "invented_match_checkpoint"
	_approve("checkpoint",wrong.data.checkpoint,origin.identity)
	_reject(origin,wrong,"checkpoint_reference_conflict")
	check(not Contract.party_view({1:opened},false,false,_authority).success,"Malformed member identities fail closed before sorting.")
	var second := _begin(_participant("teammate"))
	var mixed := {"prod_victim":opened,"prod_teammate":second}
	var preserved := mixed.duplicate(true)
	check(Contract.party_view(mixed,false,false,_authority) == Contract.party_view(mixed,false,false,_authority) and mixed == preserved,"Repeated party projections are deterministic and never mutate either character.")
	opened = _added(opened,_event(opened,"hpc_death",{"source_event_id":Contract._prefix(opened.identity)+"/damage/wipe_one","source_ref":"externally verified HPC death"}))
	second = _added(second,_event(second,"hpc_death",{"source_event_id":Contract._prefix(second.identity)+"/damage/wipe_two","source_ref":"externally verified HPC death"}))
	opened = _outcome(opened)
	second = _outcome(second)
	var tie := Contract.party_view({"prod_victim":opened,"prod_teammate":second},true,false,_authority)
	check(tie.success and tie.team_defeated and not tie.team_won and tie.reward_eligible.is_empty() and not tie.next_wave_allowed,"Owner ruling: all-party wipe is defeat despite final-enemy death.")
	var already_won := _outcome(mixed.prod_victim)
	already_won = _added(already_won,_event(already_won,"hpc_death",{"source_event_id":Contract._prefix(already_won.identity)+"/damage/after_resolved_win","source_ref":"externally verified later death"}))
	var resolved := Contract.party_view({"prod_victim":already_won,"prod_teammate":second},true,false,_authority)
	check(resolved.success and resolved.team_defeated and not resolved.team_won and not resolved.next_wave_allowed,"A prior provisional victory cannot override all-party defeat; committed history is not modified by this query.")
