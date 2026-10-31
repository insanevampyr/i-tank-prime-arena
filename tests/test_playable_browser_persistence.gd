extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []

# Native host-state tests only. Actual IndexedDB acceptance is a separate Web
# scene using the identical controller/session and real JavaScriptBridge.
class Backend extends RefCounted:
	var histories := {}
	var locks := {}
	var jobs := {}
	var sequence := 0
	func transport(method: String, value: Dictionary) -> Dictionary:
		if method == "begin":
			sequence += 1
			var job := str(sequence)
			jobs[job] = value.duplicate(true)
			# Native browser release executes synchronously before its Promise ack.
			if value.operation == "release": jobs[job]["released"] = execute(value.operation,value.arguments)
			return {"success":false,"state":"pending","job":job}
		var request: Dictionary = jobs.get(value.job,{})
		if request.is_empty(): return result("unavailable","unknown_job")
		jobs.erase(value.job)
		return request.released if request.has("released") else execute(request.operation,request.arguments)
	func result(state: String, reason: String = "") -> Dictionary:
		return {"success":state == "verified_committed","state":state,"reason":reason}
	func execute(operation: String, args: Dictionary) -> Dictionary:
		var profile: String = args.profile
		if operation == "acquire":
			if locks.has(profile): return result("unavailable","profile_in_use")
			locks[profile] = args.owner
			return result("verified_committed")
		if operation in ["release","transfer"]:
			if locks.get(profile) != args.owner: return result("unavailable","writer_lock_required")
			if operation == "transfer": locks[profile] = args.next_owner
			else: locks.erase(profile)
			return result("verified_committed")
		var history: Array = histories.get(profile,[])
		if operation == "inspect": return {"success":true,"state":"verified_committed","missing":history.is_empty(),"generations":history.duplicate(true)}
		if operation in ["publish","reconcile"]:
			for record: Dictionary in history:
				if record.transaction_id == args.transaction_id:
					if record.document != args.document: return result("failed","transaction_conflict")
					return {"success":true,"state":"verified_committed","generation":record.generation,"latest_generation":history.size(),"document":record.document,"transaction_id":record.transaction_id}
			if operation == "reconcile": return result("failed","transaction_not_found")
			if locks.get(profile) != args.owner: return result("unavailable","writer_lock_required")
			if history.size() != args.expected_generation: return result("failed","stale_generation")
			if args.get("fault") in ["abort","quota"]: return result("failed","injected_write_failure")
			var decoded := CharacterSaveContract.decode(args.document)
			if not decoded.success: return result("recovery_required","invalid_document")
			history.append({"generation":decoded.payload.generation,"transaction_id":args.transaction_id,"document":args.document})
			histories[profile] = history
			if args.get("fault") == "lost_ack": return result("recovery_required","acknowledgement_lost")
			return {"success":true,"state":"verified_committed","generation":history.size(),"latest_generation":history.size(),"document":args.document,"transaction_id":args.transaction_id}
		return result("failed","unknown_operation")

func run() -> Array[String]:
	var backend := Backend.new()
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableBrowserPersistence.test_factory = func() -> CharacterBrowserStorage: return CharacterBrowserStorage.new(backend.transport)
	var scene := make_scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	var guard := c._session
	c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	check(c._session == guard and c._browser_transition_blocked(),"Selection must retain old session while loading.")
	check(not c._player.is_physics_processing(),"Pending I/O must also pause the independent Running/recovery movement model.")
	pump(c,false)
	check(c._web_operation.get("phase") == "confirmation" and backend.histories.is_empty(),"Missing profile requires explicit confirmation, without starter publication.")
	c._web_creation_dialog.get_ok_button().pressed.emit()
	pump(c)
	check(c._web_operation.is_empty() and c._session._playable_persistence is PlayableBrowserPersistence,"Actual selection/confirmation must produce acknowledged playable Vaelis.")
	if not c._web_operation.is_empty():
		check(false,"Admission failed: %s" % c._web_operation)
		finish(scene)
		return failures
	var session := c._session
	check(session._playable_persistence.generation == 1 and session.get_actor_state(&"player").inventory_quantities.prime_v3_gold == 75,"Exactly one source-backed starter grant.")
	c._update_presentation()
	check(c._combat_status.max_lines_visible >= c._combat_status.get_line_count(),"Actual HUD must expose the persistence status line rather than clip it.")
	check(c._combat_status.text.get_slice("\n",4).begins_with("Progress saved"),"Persistence acknowledgement must precede long HUD messages so horizontal clipping cannot hide it.")
	c._on_encounter_button_pressed()
	session.set_opponent_behavior_enabled(false)
	session.get_actor_state(&"player").current_hpc = 3
	session.get_actor_state(&"player").resources.mana = 7
	session._playable_persistence.browser.inject_test_fault("lost_ack")
	defeat_wave(session)
	pump(c)
	check(not session._playable_persistence._last_ack and session._playable_persistence.status().text == "Recovery required","A lost acknowledgement must not display saved progress.")
	var published_count: int = backend.histories["prod_vaelis_thorn"].size()
	c._on_encounter_button_pressed(); pump(c)
	check(session._playable_persistence._last_ack and backend.histories["prod_vaelis_thorn"].size() == published_count,"Retained exact checkpoint reconciles without duplicate publication/rewards.")
	check(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME and session._playable_persistence._last_ack,"Wave rewards/downtime must publish a verified boundary.")
	var before := session.get_state_snapshot()
	var saved_generation := session._playable_persistence.generation
	# The candidate uses the same lease but cannot mutate or replace downtime.
	session._playable_persistence.browser.inject_test_fault("abort")
	c._on_encounter_button_pressed()
	check(c._session == session and session.get_state_snapshot() == before,"Pending NEXT WAVE must preserve complete old authoritative history/RNG/state.")
	c._collect_loot_button.pressed.emit()
	c._nac_auto_toggle.button_pressed = true
	c._apply_nac_settings_from_ui()
	check(session.get_state_snapshot() == before,"GUI loot/NAC callbacks cannot mutate the old actor while a candidate is pending.")
	pump(c)
	check(c._web_operation.get("phase") == "failed" and c._session == session and session.get_state_snapshot() == before,"Failed entry publication retains exact old session.")
	c._physics_process(10.0)
	check(session.get_state_snapshot() == before,"Pending/failed transition cannot tick simulation or effect clocks.")
	check(backend.histories["prod_vaelis_thorn"].size() == saved_generation,"Failed entry does not move durable generation.")
	c._on_encounter_button_pressed()
	pump(c)
	check(c._web_operation.is_empty() and c._session != session and c._session._current_reward_wave_id() == "wave_2","Same exact proposal can retry and safely activate Wave 2.")
	check(c._session.get_actor_state(&"player").current_hpc == 3 and c._session.get_actor_state(&"player").resources.mana == 7,"NEXT WAVE does not refill resources.")
	check(c._session.simulation.get_resolved_event_count() >= session.simulation.get_resolved_event_count(),"Candidate preserves accumulated authoritative history.")
	var entry: Dictionary = c._session._playable_persistence._prior.duplicate(true)
	c._session.get_actor_state(&"player").current_hpc = 0
	c._session.advance_by(1)
	c._update_presentation()
	check(c._encounter_button.text == "RETRY WAVE" and c._encounter_button.is_visible_in_tree() and c._return_wave_one_button.is_visible_in_tree(),"Persistent defeat exposes both actual recovery buttons.")
	c._on_encounter_button_pressed()
	pump(c)
	check(c._session._current_reward_wave_id() == "wave_2" and c._session.get_actor_state(&"player").current_hpc == 3,"RETRY restores exact secured entry, no refill.")
	c._on_encounter_button_pressed()
	c._session.set_opponent_behavior_enabled(false)
	c._session.get_actor_state(&"player").current_hpc = 0
	c._session.advance_by(1)
	c._on_return_to_wave_one_pressed()
	pump(c)
	check(c._session._current_reward_wave_id() == "wave_1" and c._session._playable_persistence._prior.xp == entry.xp,"RETURN preserves secured XP and starts Wave 1.")
	var first_run: String = entry.recovery.run_id
	check(c._session._playable_persistence.run_id != first_run,"New circuit has unique reward/run identity.")
	for iteration in range(2):
		var old_record: Dictionary = c._session._playable_persistence._prior.duplicate(true)
		var old_run: String = c._session._playable_persistence.run_id
		c._on_encounter_button_pressed()
		c._session.set_opponent_behavior_enabled(false)
		c._session.get_actor_state(&"player").current_hpc = 0
		c._session.advance_by(1)
		c._on_return_to_wave_one_pressed(); pump(c)
		check(c._session._playable_persistence.run_id != old_run and c._session._playable_persistence._prior.items == old_record.items and c._session._playable_persistence._prior.xp == old_record.xp,"Repeated legitimate RETURN creates a new run without replaying rewards/starters.")
	# Compare the public contract representation after its documented JSON-number
	# normalization, rather than Godot-only int/float Variant storage types.
	var retained: Dictionary = CharacterSaveContract.decode(CharacterSaveContract.encode(c._session._playable_persistence._prior).text).payload
	finish(scene)
	scene = make_scene(); c = scene.get_node("CombatController")
	c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS); pump(c)
	check(c._session._playable_persistence._prior == retained,"Exit/reload restores exact complete canonical profile and wave entry.")
	var harness := TwoClientSyncHarness.new(1)
	var batch := c._session.simulation.get_resolved_events_from(0)
	var sync_snapshot := c._session.simulation.get_state_snapshot()
	var envelopes: Array = []
	for event: CombatEvent in batch.events: envelopes.append(CombatEventEnvelope.new(envelopes.size(),event.to_dictionary(),sync_snapshot))
	harness.deliver_in_order(envelopes)
	check(harness.compare_clients().success and c._session.get_state_snapshot().schema_version == 12,"Actual loaded session converges under schema 12.")
	check(c._session.simulation.get_resolved_event_count() == batch.next_cursor,"Sync verification must not consume a playable ownership stream.")
	var normal_count: int = backend.histories["prod_vaelis_thorn"].size()
	c._encounter_selector.pressed.emit()
	check(c._session._playable_persistence == null and c._session._reward_mode == "test","Actual TEST selection remains nonpersistent.")
	pump(c)
	for index in range(7): c._encounter_selector.pressed.emit()
	pump(c)
	check(c._encounter_selector_index == 8 and c._session._playable_persistence != null and c._session._playable_persistence.profile_id == "dev_vaelis_thorn","Pending mode selection cannot revert the authorized DEV namespace: %s / %s / %s" % [c._encounter_selector_index,c._web_operation,c._last_ui_message])
	check(backend.histories["prod_vaelis_thorn"].size() == normal_count and backend.histories.get("dev_vaelis_thorn",[]).size() == 1,"TEST/DEV selection cannot rewrite NORMAL progression.")
	if c._session._playable_persistence != null:
		c._session.set_opponent_behavior_enabled(false)
		c._on_encounter_button_pressed()
		for wave_number in range(1,6):
			check(c._session._current_reward_wave_id() == "wave_%s" % wave_number,"Browser candidate integrates every approved wave.")
			defeat_wave(c._session); pump(c)
			c._on_encounter_button_pressed(); pump(c)
		check(c._session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY and c._session._playable_persistence._prior.recovery.phase == "complete","Wave 5 completion publishes the complete-circuit checkpoint.")
		var completed_xp: Dictionary = c._session._playable_persistence._prior.xp.duplicate(true)
		c._on_encounter_button_pressed(); pump(c)
		check(c._session._current_reward_wave_id() == "wave_1" and c._session._playable_persistence._prior.xp == completed_xp,"Post-completion NEW RUN retains secured character progression.")
	var other := make_scene()
	var other_controller: ArenaCombatController = other.get_node("CombatController")
	other_controller._encounter_selector_index = 8
	other_controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS); pump(other_controller)
	check(other_controller._web_operation.get("phase") == "failed" and other_controller._session._player_character_id == Fixture.PLAYER_CHARACTER_GUARD,"Competing host preserves its old nonpersistent session.")
	other_controller._update_presentation()
	check(other_controller._encounter_button.text == "RETRY STORAGE" and other_controller._combat_status.max_lines_visible >= other_controller._combat_status.get_line_count() and other_controller._combat_status.text.contains("Character currently open in another tab"),"Unavailable storage remains actionable and its status is not clipped.")
	finish(other)
	finish(scene)
	if not backend.histories.has("dev_vaelis_thorn"):
		PlayableBrowserPersistence.test_factory = Callable()
		PlayableCharacterPersistence.test_nonpersistent = true
		return failures
	backend.histories["dev_vaelis_thorn"][0].document = "corrupt fixture"
	scene = make_scene(); c = scene.get_node("CombatController")
	c._encounter_selector_index = 8
	c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS); pump(c)
	check(c._web_operation.get("phase") == "failed" and c._web_operation.service.status().text == "Recovery required","Corruption is not missing and must never create a new starter.")
	c._on_character_selector_pressed(); pump(c)
	check(c._session._player_character_id == Fixture.PLAYER_CHARACTER_GUARD and c._web_operation.is_empty(),"Unsupported storage can safely return to nonpersistent Guard without deleting data.")
	finish(scene)
	PlayableBrowserPersistence.test_factory = Callable()
	PlayableCharacterPersistence.test_nonpersistent = true
	return failures

func make_scene() -> Node:
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	scene.get_node("CombatController").set_physics_process(false)
	return scene

func pump(c: ArenaCombatController, confirm: bool = true) -> void:
	for index in range(100):
		c._poll_browser_persistence()
		if c._web_operation.get("phase") == "confirmation":
			if not confirm: return
			c._web_creation_dialog.get_ok_button().pressed.emit()
		if c._web_operation.get("phase") == "failed": return
		if c._session._playable_persistence is PlayableBrowserPersistence and c._session._playable_persistence._browser_result.get("state") in ["failed","unavailable","recovery_required"]: return
		if not c._browser_transition_blocked(): return
	check(false,"Asynchronous test boundary did not settle: %s" % c._web_operation)

func defeat_wave(session: ArenaCombatSession) -> void:
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)

func finish(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
