extends "res://tests/test_task_37c_profile_v3_compatibility.gd"

const Disk = preload("res://tests/profile_v3_disposable_storage.gd")
var directories: Array[String] = []

func run() -> Array[String]:
	for test: Callable in [_disk_roundtrip,_interruption_matrix,_committed_and_attempt_spending,_corruption,_source_and_conflicts,_frozen_disk,_multiplayer_disk,_wipe_disk]:
		approvals.clear()
		observed_heads.clear()
		profile_heads.clear()
		test.call()
	_cleanup()
	print("Disposable roots: %d beneath %s; fixture cleanup checked." % [directories.size(),OS.get_cache_dir().path_join("itank-storage-tests")])
	print("37C disposable V3 disk storage: %d assertions; real flush/close/rename/readback, injected interruptions, recovery and independent profiles." % assertions)
	return failures

func _admit(disk: RefCounted, root: Dictionary) -> void:
	var anchor: Dictionary = root.anchor
	var identity := {"profile_id":anchor.character_id,"character_id":anchor.definition_id,"rules_revision":anchor.rules_revision,"namespace":anchor.profile_namespace,"history_id":""}
	_approve("disk_anchor",{"document":root.document},identity)
	check(disk.initialize_anchor(anchor.character_id,root.document).success,"Disposable anchor is source-verified and actually written once.")

func _disk(root: Dictionary) -> RefCounted:
	var path := OS.get_cache_dir().path_join("itank-storage-tests").path_join("v3_case_%s_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec(),directories.size()])
	check(not DirAccess.dir_exists_absolute(path),"Test directory must be fresh, never owner data.")
	directories.append(path)
	var disk := Disk.new(path,_authority)
	_admit(disk,root)
	return disk

func _path(disk: RefCounted, profile: String, name: String) -> String:
	return disk._root.path_join(profile).path_join(name)

func _raw(path: String, text: String) -> void:
	var root := path.get_base_dir().get_base_dir().replace("\\","/").simplify_path()
	check(directories.has(root) or directories.has(path.get_base_dir().get_base_dir()),"Fault injection is restricted to this test's created directory.")
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file != null,"Injected disposable file must open.")
	if file == null: return
	file.store_string(text)
	file.flush()
	check(file.get_error() == OK,"Injected disposable file flush succeeds.")
	file.close()

func _count(disk: RefCounted, profile: String) -> int:
	return DirAccess.open(disk._root.path_join(profile)).get_files().size()

func _first(root: Dictionary) -> Dictionary:
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"str":-2}))
	history = _purchase(history,"str","one")
	return _payload(root,history)

func _observe(disk: RefCounted, profile: String) -> void:
	# Bind the inherited fixture's next-generation authority to ACTUAL fresh disk
	# readback, rather than its earlier in-memory simulated publication helper.
	var read: Dictionary = disk.inspect(profile)
	check(read.success and not read.records.is_empty(),"Fixture head observation requires a real published generation.")
	if not read.success or read.records.is_empty(): return
	check(disk.reconcile(profile,read.records.back()).success,"Fixture authority follows exact current disk acknowledgement.")
	var payload: Dictionary = read.payload
	_approve("head",payload.history_binding,payload.life_history.identity)
	observed_heads[Contract.fingerprint(payload.life_history.identity)] = Contract.fingerprint(payload.history_binding)
	profile_heads[profile] = Contract.fingerprint(payload)

func _disk_roundtrip() -> void:
	var root := _root("disk_roundtrip")
	var disk := _disk(root)
	var payload := _first(root)
	var original := payload.duplicate(true)
	var saved: Dictionary = disk.publish(root.anchor.character_id,payload,1,payload.history_binding.transaction_id)
	check(saved.success and saved.state == "filesystem_verified" and not saved.power_loss_durability_proven,"Real filesystem acknowledgement follows publication and fresh exact readback; no power-loss claim.")
	var reopened := Disk.new(disk._root,_authority)
	var read := reopened.inspect(root.anchor.character_id,2)
	check(read.success and read.payload == original and read.generation == 2 and read.records.size() == 1,"Fresh adapter reconstructs exact profile, head and receipts from disk.")
	check(read.records[0].document == Profile.encode(payload,_authority).text and FileAccess.get_file_as_string(_path(disk,root.anchor.character_id,"anchor.v2")) == root.document,"Canonical document and original V2 anchor bytes are unchanged.")
	var state: Dictionary = Profile.validate(read.payload,_authority).state
	check(state.available_expc == 10000 and state.life == "dead" and state.attributes.permanent.str == -1,"One actual durable receipt debits 2,000 once and never revives.")
	var before_count := _count(disk,root.anchor.character_id)
	for repeat: int in 3:
		check(reopened.publish(root.anchor.character_id,payload,1,payload.history_binding.transaction_id).success,"Exact retry reconciles the same immutable file.")
		check(reopened.reconcile(root.anchor.character_id,read.records[0]).success,"Repeated read acknowledgement causes no second debit.")
	check(_count(disk,root.anchor.character_id) == before_count and payload == original,"Duplicate acknowledgements/publications neither create files nor mutate inputs.")
	var lease: Dictionary = disk._guard.acquire_writer(root.anchor.character_id)
	check(lease.success and not reopened.publish(root.anchor.character_id,payload,1,payload.history_binding.transaction_id).success,"Independent adapters cannot acquire the same cooperative directory writer lock.")
	check(not reopened.reconcile(root.anchor.character_id,read.records[0]).success,"Standalone acknowledgement cannot race a cooperating profile writer.")
	check(not reopened._guard.release_writer(root.anchor.character_id,lease.owner).success,"A reopened adapter cannot steal or release a prior writer's lock.")
	check(disk._guard.release_writer(root.anchor.character_id,lease.owner).success,"Owning writer can release its own disposable lock.")
	check(not Disk.new("user://character_documents",_authority).initialize_anchor(root.anchor.character_id,root.document).success,"Production user directory cannot be selected by this harness.")
	check(not disk.initialize_anchor("../escape",root.document).success,"Traversal is rejected before file construction.")

func _interruption_matrix() -> void:
	for fault: String in ["before_staging","partial_stage","after_stage","after_rename","lost_ack","readback_mismatch"]:
		var root := _root("fault_"+fault)
		var disk := _disk(root)
		var first := _first(root)
		check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Initial verified generation precedes fault injection.")
		_observe(disk,root.anchor.character_id)
		var history := _added(first.life_history,_rollback_event(first.life_history,"restart"))
		var second := _payload(root,history,first)
		var original_path: String = disk._generation(root.anchor.character_id,2)
		var original_bytes := FileAccess.get_file_as_string(original_path)
		var failed: Dictionary = disk.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id,fault)
		check(not failed.success,"Injected interruption cannot report an acknowledged write: "+fault)
		var reopened := Disk.new(disk._root,_authority)
		var observed := reopened.inspect(root.anchor.character_id,2)
		var committed: bool = fault in ["after_rename","lost_ack","readback_mismatch"]
		check(observed.success and observed.generation == (3 if committed else 2),"Reopen selects only a fully published generation: "+fault)
		check(FileAccess.get_file_as_string(original_path) == original_bytes,"Failure never overwrites the previous immutable generation.")
		for repeat: int in 2:
			var again := Disk.new(disk._root,_authority).inspect(root.anchor.character_id,2)
			check(again == observed,"Repeated recovery is deterministic: "+fault)
		if committed:
			check(reopened.reconcile(root.anchor.character_id,observed.records.back()).success,"Lost acknowledgement is recovered from exact disk content.")
			check(reopened.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Post-publication retry observes the same cancellation.")
			check(Profile.validate(observed.payload,_authority).state.available_expc == 12000 and observed.payload.settlement_links.size() == 1,"Rollback restores attempt spending once and retains its historical receipt.")
			check(not reopened.reconcile(root.anchor.character_id,observed.records[0]).success,"A formerly acknowledged old generation cannot replace the current head.")
		elif fault != "before_staging":
			check(observed.pending_write and not reopened.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Unpublished partial/complete staging blocks writes and is never auto-promoted.")
			check(FileAccess.file_exists(_path(disk,root.anchor.character_id,"write.pending")),"Interrupted evidence remains intact until explicit fixture cleanup.")
		else:
			check(not observed.pending_write and reopened.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Failure before staging can safely retry under its original identity.")

func _committed_and_attempt_spending() -> void:
	var root := _root("precheckpoint")
	var disk := _disk(root)
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"wis":0}))
	history = _purchase(history,"wis","committed")
	history = _added(history,_completion(history))
	var completion := _snapshot({root.anchor.character_id:history})
	history = _outcome(history)
	var outcome_id: String = history.events.back().event_id
	var attempt: Dictionary = Contract.replay(history,_authority).state.active_attempt
	history = _added(history,_event(history,"attempt_commit",{"attempt_id":attempt.attempt_id,"outcome_ref":attempt.outcome.outcome_ref}))
	var first := _payload(root,history,{}, {outcome_id:completion})
	check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Completed pre-checkpoint recovery is committed before the next attempt.")
	_observe(disk,root.anchor.character_id)
	var gate_snapshot := _snapshot({root.anchor.character_id:history})
	history = _begin(history,"next","wave_4")
	var gates := [{"event_id":history.events.back().event_id,"kind":"next_wave","evidence":gate_snapshot}]
	history = _added(history,_attribute_event(history,{"str":0}))
	history = _purchase(history,"str","discardable")
	var second := _payload(root,history,first,{outcome_id:completion},gates)
	check(disk.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Separate authorized attempt debit publishes without conflating prior spending.")
	_observe(disk,root.anchor.character_id)
	history = _added(history,_rollback_event(history,"restart"))
	var third := _payload(root,history,second,{outcome_id:completion},gates)
	check(not disk.publish(root.anchor.character_id,third,3,third.history_binding.transaction_id,"lost_ack").success,"Rollback publication can lose acknowledgement without being replayed as another refund.")
	var reopened := Disk.new(disk._root,_authority)
	var read := reopened.inspect(root.anchor.character_id,4)
	var state: Dictionary = Profile.validate(read.payload,_authority).state
	check(state.available_expc == 10000 and state.attributes.permanent.wis == 1 and state.attributes.permanent.str == 10 and state.life == "alive","Disk rollback restores only the later attempt; earlier 2,000 spending and permanent recovery survive.")
	check(read.payload.settlement_links.size() == 2 and state.receipts.size() == 1 and state.discarded_attempts.size() == 1,"Cancelled receipt IDs remain in audit history without an active second debit.")
	check(reopened.reconcile(root.anchor.character_id,read.records.back()).success and reopened.reconcile(root.anchor.character_id,read.records.back()).success,"Repeated post-crash reconciliation neither refunds twice nor erases prior spending.")
	check(not reopened.reconcile(root.anchor.character_id,read.records[0]).success,"Stale pre-checkpoint acknowledgement cannot erase later committed cancellation history.")

func _corruption() -> void:
	for fault: String in ["empty","partial","truncated","checksum","future"]:
		var root := _root("corrupt_"+fault)
		var disk := _disk(root)
		var first := _first(root)
		check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Valid previous generation is available for inspection.")
		var source_path: String = disk._generation(root.anchor.character_id,2)
		var original := FileAccess.get_file_as_string(source_path)
		var bad := ""
		if fault == "partial": bad = "{"
		if fault == "truncated": bad = original.left(original.length()/2)
		if fault in ["checksum","future"]:
			var parsed: Dictionary = JSON.parse_string(original)
			if fault == "checksum": parsed.sha256 = "0".repeat(64)
			else: parsed.transport_version = 999
			bad = JSON.stringify(parsed)
		_raw(disk._generation(root.anchor.character_id,3),bad)
		var reopened := Disk.new(disk._root,_authority)
		var rejected := reopened.inspect(root.anchor.character_id)
		check(not rejected.success and rejected.verified_prefix.size() == 1,"Corrupt/future suffix fails closed while exposing the verified prior prefix: "+fault)
		check(reopened.inspect(root.anchor.character_id) == rejected and FileAccess.get_file_as_string(source_path) == original,"Repeated failed recovery preserves every original generation.")
		check(not reopened.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Corrupt history cannot be hidden by an exact old retry.")
	var root := _root("missing")
	var disk := _disk(root)
	check(disk.inspect("prod_absent").get("reason") == "profile_missing","Missing profile is explicit, never initialized by a read.")
	var first := _first(root)
	check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Missing-file fixture first publishes valid data.")
	_observe(disk,root.anchor.character_id)
	var second := _payload(root,_added(first.life_history,_rollback_event(first.life_history,"restart")),first)
	check(disk.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Second generation exists before fault simulation.")
	var last_path: String = disk._generation(root.anchor.character_id,3)
	check(DirAccess.rename_absolute(last_path,_path(disk,root.anchor.character_id,"removed_head.fixture")) == OK,"Only the disposable newest file is moved for missing-head injection.")
	check(disk.inspect(root.anchor.character_id,3).get("reason") == "acknowledged_generation_missing","An externally known acknowledged head cannot silently downgrade when its file is missing.")
	check(DirAccess.rename_absolute(_path(disk,root.anchor.character_id,"removed_head.fixture"),last_path) == OK,"Disposable newest generation can be restored exactly.")
	check(DirAccess.rename_absolute(disk._generation(root.anchor.character_id,2),_path(disk,root.anchor.character_id,"removed_middle.fixture")) == OK,"Disposable middle generation is moved to simulate a gap.")
	check(not disk.inspect(root.anchor.character_id).success,"Missing middle generation prevents accepting a valid-looking newest document.")
	_raw(_path(disk,root.anchor.character_id,"anchor.v2"),"corrupt")
	check(not disk.inspect(root.anchor.character_id).success,"Corrupt anchor prevents reconstruction; no blank replacement is created.")

func _source_and_conflicts() -> void:
	var root := _root("source")
	var other := _root("other")
	var disk := _disk(root)
	_admit(disk,other)
	var first := _first(root)
	check(not disk.publish(other.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Wrong-profile publication is rejected before staging.")
	var denied := func(kind: String, record: Dictionary, identity: Dictionary) -> bool:
		return false if kind == "v3_attribute_effect" else _authority(kind,record,identity)
	var without_source := Disk.new(disk._root,denied)
	check(not without_source.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Missing source evidence cannot become trusted merely because a checksum is valid.")
	check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Correct profile and source publish normally.")
	_observe(disk,root.anchor.character_id)
	var second := _payload(root,_added(first.life_history,_rollback_event(first.life_history,"restart")),first)
	var before_count := _count(disk,root.anchor.character_id)
	check(not disk.publish(root.anchor.character_id,second,1,second.history_binding.transaction_id).success,"Stale expected generation is rejected against actual disk history.")
	check(not disk.publish(root.anchor.character_id,second,2,first.history_binding.transaction_id).success,"A different payload cannot reuse a committed transaction identity.")
	var duplicate := second.duplicate(true)
	duplicate.settlement_links.append(duplicate.settlement_links[0].duplicate(true))
	check(not disk.publish(root.anchor.character_id,duplicate,2,duplicate.history_binding.transaction_id).success,"Duplicate recovery receipt linkage cannot be published.")
	var truncated := second.duplicate(true)
	truncated.life_history.events.pop_back()
	check(not disk.publish(root.anchor.character_id,truncated,2,truncated.history_binding.transaction_id).success,"Conflicting history head is rejected before writing.")
	check(not disk.publish(root.anchor.character_id,{"life_history":1},2,"malformed").success,"Malformed identity structure fails closed without a script error.")
	var forged := first.duplicate(true)
	forged.life_history = root.history.duplicate(true)
	forged.settlement_links = []
	forged.generation = 3
	forged.history_binding.generation = 2
	forged.history_binding.event_count = 0
	forged.history_binding.event_head = Contract.replay(root.history,_authority).state.head_hash
	forged.history_binding.history_digest = Contract.fingerprint(root.history)
	forged.history_binding.previous_binding_hash = Contract.fingerprint(first.history_binding)
	forged.history_binding.transaction_id = Contract._prefix(root.history.identity)+"/publication/forged_reset"
	forged.history_binding.publication_ids.append(forged.history_binding.transaction_id)
	check(Profile.validate(forged,_authority).success,"Source-attested old prefix can be structurally valid without being authorized rollback.")
	check(disk.publish(root.anchor.character_id,forged,2,forged.history_binding.transaction_id).get("reason") == "unauthorized_history_rollback","Disk continuity rejects a correctly hashed newer generation that truncates committed history.")
	var recovered := _purchase(first.life_history,"str","recovery_two")
	recovered = _purchase(recovered,"str","recovery_three")
	recovered = _added(recovered,_completion(recovered))
	var missing_completion := _payload(root,recovered,first)
	missing_completion.life_history.events.back().data.erase("completion")
	_approve("event",missing_completion.life_history.events.back(),recovered.identity)
	check(disk.publish(root.anchor.character_id,missing_completion,2,missing_completion.history_binding.transaction_id).get("reason") == "verified_resurrection_completion_required","An authorized event label without verified resurrection completion cannot reach disk.")
	check(_count(disk,root.anchor.character_id) == before_count,"All rejected source/identity/history requests create zero generation/staging files.")
	var no_source := Disk.new(disk._root,Callable())
	check(not no_source.inspect(root.anchor.character_id).success,"Reopen without source validation fails closed.")

func _frozen_disk() -> void:
	var root := _root("frozen_disk")
	var disk := _disk(root)
	var history := _begin(root.history)
	history = _added(history,_attribute_event(history,{"wis":0}))
	var temporary := _attribute_event(history,{"wis":2},"temporary")
	temporary.data.sources[0].remaining_duration_us = 5000
	var source: String = temporary.data.sources[0].source_id
	history = _added(history,temporary)
	history = _added(history,_event(history,"effect_time",{"elapsed_us":999999,"frozen":true}))
	var first := _payload(root,history)
	check(disk.publish(root.anchor.character_id,first,1,first.history_binding.transaction_id).success,"Frozen source-qualified duration is written to a real generation.")
	var reopened := Disk.new(disk._root,_authority)
	var read := reopened.inspect(root.anchor.character_id,2)
	var state: Dictionary = Profile.validate(read.payload,_authority).state
	check(state.source_remaining_us[source] == 5000 and state.effect_clock_frozen and state.attribute_eligible and state.life == "dead","Disk reload preserves frozen duration and effective eligibility without resurrection or wall-clock aging.")
	var resources: Dictionary = state.owned_state.resources.duplicate(true)
	_observe(reopened,root.anchor.character_id)
	history = _added(history,_event(history,"effect_time",{"elapsed_us":1000,"frozen":false}))
	var second := _payload(root,history,first)
	check(reopened.publish(root.anchor.character_id,second,2,second.history_binding.transaction_id).success,"Only explicit authorized resumed encounter time ages the source.")
	var again := Disk.new(disk._root,_authority).inspect(root.anchor.character_id,3)
	var resumed: Dictionary = Profile.validate(again.payload,_authority).state
	check(resumed.source_remaining_us[source] == 4000 and not resumed.effect_clock_frozen and resumed.life == "dead" and resumed.owned_state.resources == resources,"Resumed duration roundtrips without refilling resources or reviving the character.")

func _multiplayer_disk() -> void:
	var root := _root("dead_disk")
	var peer := _root("survivor_disk")
	var disk := _disk(root)
	_admit(disk,peer)
	var dead := _begin(root.history)
	var living := _begin(peer.history)
	dead = _added(dead,_attribute_event(dead,{"wis":0}))
	dead = _purchase(dead,"wis","personal")
	var evidence := _snapshot({root.anchor.character_id:dead,peer.anchor.character_id:living})
	dead = _outcome(dead)
	living = _outcome(living)
	var dead_outcome: String = dead.events.back().event_id
	var peer_outcome: String = living.events.back().event_id
	living = _added(living,_reward_event(living))
	var attempt: Dictionary = Contract.replay(living,_authority).state.active_attempt
	living = _added(living,_event(living,"attempt_commit",{"attempt_id":attempt.attempt_id,"outcome_ref":attempt.outcome.outcome_ref}))
	var winner := _payload(peer,living,{}, {peer_outcome:evidence})
	var loser := _payload(root,dead,{}, {dead_outcome:evidence})
	check(not disk.publish_cohort([winner,loser]).success and disk.inspect(peer.anchor.character_id).generation == 1,"Cross-profile publication stays fail-closed and writes neither participant.")
	check(disk.publish(peer.anchor.character_id,winner,1,winner.history_binding.transaction_id).success,"Survivor's independent verified rewards publish once.")
	var winner_bytes := FileAccess.get_file_as_string(disk._generation(peer.anchor.character_id,2))
	check(not disk.publish(root.anchor.character_id,loser,1,loser.history_binding.transaction_id,"after_rename").success,"Another participant may lose an acknowledgement independently; no cohort success is claimed.")
	var reopened := Disk.new(disk._root,_authority)
	var lost := reopened.inspect(root.anchor.character_id,2)
	var dead_state: Dictionary = Profile.validate(lost.payload,_authority).state
	check(dead_state.life == "dead" and dead_state.reward_receipts.is_empty() and dead_state.available_expc == 10000,"Dead teammate persists death and only their own authorized spending, with no victory rewards.")
	check(reopened.reconcile(root.anchor.character_id,lost.records.back()).success,"Dead participant's exact lost acknowledgement can reconcile independently.")
	_observe(reopened,root.anchor.character_id)
	var view := Contract.party_view({root.anchor.character_id:dead,peer.anchor.character_id:living},true,false,_authority)
	check(view.team_won and not view.next_wave_allowed and view.reward_eligible == [peer.anchor.character_id],"Successful team carries a dead teammate but cannot advance.")
	dead = _added(dead,_rollback_event(dead,"departure_after_victory"))
	var departure := _payload(root,dead,loser,{dead_outcome:evidence})
	check(not reopened.publish(root.anchor.character_id,departure,2,departure.history_binding.transaction_id,"before_staging").success,"Interrupted personal departure preserves the last verified state.")
	check(reopened.publish(root.anchor.character_id,departure,2,departure.history_binding.transaction_id).success,"Authorized personal rollback appends cancellation and restores pre-attempt state.")
	for repeat: int in 2:
		var recovered := Disk.new(disk._root,_authority).inspect(root.anchor.character_id,3)
		var state: Dictionary = Profile.validate(recovered.payload,_authority).state
		check(state.participation == "left" and state.available_expc == 12000 and state.life == "alive","Repeated departure recovery cannot duplicate a refund.")
		check(FileAccess.get_file_as_string(disk._generation(peer.anchor.character_id,2)) == winner_bytes and Profile.validate(disk.inspect(peer.anchor.character_id).payload,_authority).state.available_expc == 12100,"Personal rollback cannot erase or duplicate independently acknowledged survivor rewards.")

func _wipe_disk() -> void:
	var root := _root("wipe_a")
	var peer := _root("wipe_b")
	var disk := _disk(root)
	_admit(disk,peer)
	var party := {root.anchor.character_id:_begin(root.history),peer.anchor.character_id:_begin(peer.history)}
	for id: String in party:
		party[id] = _added(party[id],_event(party[id],"hpc_death",{"source_event_id":Contract._prefix(party[id].identity)+"/damage/wipe","source_ref":"verified simultaneous final-exchange fixture"}))
	var evidence := _snapshot(party,"wipe_final_enemy")
	var candidates: Array = []
	for data: Dictionary in [root,peer]:
		var history: Dictionary = party[data.anchor.character_id]
		var outcome := _event(history,"wave_outcome",{"attempt_id":Contract.replay(history,_authority).state.active_attempt.attempt_id,"team_won":false,"final_wave":false,"outcome_ref":"wipe_final_enemy"})
		history = _added(history,outcome)
		candidates.append(_payload(data,history,{}, {outcome.event_id:evidence}))
	check(not disk.publish_cohort(candidates).success,"Simultaneous wipe cannot bypass the multi-profile atomicity restriction.")
	check(not disk.publish(root.anchor.character_id,candidates[0],1,candidates[0].history_binding.transaction_id,"lost_ack").success,"First defeat record can commit with an interrupted acknowledgement.")
	check(not disk.publish(peer.anchor.character_id,candidates[1],1,candidates[1].history_binding.transaction_id,"partial_stage").success,"Second defeat record can remain incomplete; no fake all-or-nothing outcome is claimed.")
	for repeat: int in 2:
		var reopened := Disk.new(disk._root,_authority)
		var read := reopened.inspect(root.anchor.character_id,2)
		check(reopened.reconcile(root.anchor.character_id,read.records.back()).success,"Repeated reconciliation observes one published defeat.")
		var state: Dictionary = Profile.validate(read.payload,_authority).state
		check(state.wave_outcomes.back().team_won == false and state.reward_receipts.is_empty() and state.available_expc == 12000,"Final-enemy defeat never overrides durable all-party defeat or awards XP.")
		var pending := reopened.inspect(peer.anchor.character_id,1)
		check(pending.success and pending.pending_write and pending.generation == 1,"Other participant retains their verified anchor and incomplete evidence.")
	var view := Contract.party_view(party,true,false,_authority)
	check(view.team_defeated and view.reward_eligible.is_empty() and not view.next_wave_allowed,"Final-enemy simultaneous wipe remains defeat with no wave advancement.")

func _cleanup() -> void:
	# Only newly created cache roots, only immediate files and profile directories.
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests")+"/"
	for path: String in directories:
		var absolute := path.replace("\\","/").simplify_path()
		check(absolute.begins_with(allowed) and absolute.get_file().begins_with("v3_case_"),"Cleanup target is verified inside the isolated cache boundary.")
		if not absolute.begins_with(allowed) or not absolute.get_file().begins_with("v3_case_"): continue
		var directory := DirAccess.open(absolute)
		if directory == null: continue
		for profile: String in directory.get_directories():
			check(CharacterSaveStorage._valid_id(profile),"Cleanup enumerates only this fixture's profile directories.")
			if not CharacterSaveStorage._valid_id(profile): continue
			var child := absolute.path_join(profile)
			var files := DirAccess.open(child)
			for name: String in files.get_files(): check(DirAccess.remove_absolute(child.path_join(name)) == OK,"Disposable fixture file cleanup succeeds.")
			check(DirAccess.remove_absolute(child) == OK,"Disposable profile directory cleanup succeeds.")
		check(DirAccess.remove_absolute(absolute) == OK and not DirAccess.dir_exists_absolute(absolute),"Disposable root cleanup leaves no test profile behind.")
