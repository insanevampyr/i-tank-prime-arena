extends RefCounted

const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const Strength = preload("res://tests/test_task_37b_strength.gd")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func run() -> Array[String]:
	var helper := Playable.new()
	var old_storage := PlayableCharacterPersistence.test_storage
	var old_mode := PlayableCharacterPersistence.test_nonpersistent
	var root := OS.get_cache_dir().path_join("itank-storage-tests/ready_STR_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	var storage := CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	PlayableCharacterPersistence.test_nonpersistent = false
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c._encounter_selector_index = 8
	check(c.select_player_character_for_testing(&"vaelis_thorn").success,"Disposable character selection must use the ordinary scene.")
	for wave in range(4):
		c._session.set_opponent_behavior_enabled(false)
		helper._defeat_wave(c._session)
		if c._session.get_reward_state().unspent_xp >= 3000: break
		check(c._session.request_next_wave().success,"Actual rewards must fund the READY purchase.")
	check(c._session.get_reward_state().unspent_xp >= 3000 and helper._failures.is_empty(),"No XP is injected to fund the playable reproduction.")
	check(c._session.request_next_wave().success,"An actual NEXT WAVE must secure an unfinished entry checkpoint.")
	var wave_id: String = c._session._current_reward_wave_id()
	helper._free(scene)
	scene = helper._scene()
	c = scene.get_node("CombatController")
	c._encounter_selector_index = 8
	check(c.select_player_character_for_testing(&"vaelis_thorn").success,"Existing funded character must reload through ordinary playable selection.")
	var session := c._session
	check(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY and session._current_reward_wave_id() == wave_id,"Reloaded unfinished wave must be READY, not downtime or active combat.")
	var resources := session.get_actor_state(&"player").resources.duplicate(true)
	var hpc: Variant = session.get_actor_state(&"player").current_hpc
	var balance: int = session.get_reward_state().unspent_xp
	var history: Array = session._playable_persistence._prior.secured_checkpoints.duplicate()
	var before := session.get_state_snapshot()
	session._encounter_active = true
	session._encounter_state = ArenaCombatSession.ENCOUNTER_RUNNING
	check(session.request_character_advancement(&"attribute",&"str","active").get("reason") == "advancement_requires_safe_character_management","Active combat must remain blocked.")
	session._encounter_active = false
	session._encounter_state = ArenaCombatSession.ENCOUNTER_READY
	check(session.get_state_snapshot() == before,"Rejected active purchase must not spend EXPC or alter events/RNG.")
	var service := session._playable_persistence
	var prepared: Dictionary = service._prepared.duplicate(true)
	var acknowledged: bool = service._last_ack
	service._prepared = {"isolated_pending_write":true}
	service._last_ack = false
	check(session.request_character_advancement(&"attribute",&"str","pending").get("reason") == "persistent_checkpoint_pending" and session.get_state_snapshot() == before,"An unacknowledged storage transaction must block before spending.")
	service._prepared = prepared
	service._last_ack = acknowledged
	session.get_actor_state(&"player").current_action_instance_id = "unresolved_fixture_action"
	check(session.request_character_advancement(&"attribute",&"str","busy").get("reason") == "advancement_requires_resolved_actions","Unresolved action blocks READY advancement.")
	session.get_actor_state(&"player").current_action_instance_id = ""
	c._update_rewards_panel(true)
	c._combat_inventory_open = true
	c._update_rewards_panel(true)
	var selected := -1
	for index in range(c._advancement_options.size()):
		var option: Dictionary = c._advancement_options[index]
		if option.purchase_kind == "attribute" and option.target_id == "str": selected = index
	check(selected >= 0,"The ordinary READY UI must show the verified STR option.")
	if selected >= 0:
		c._advancement_option.select(selected)
		c._advancement_option.item_selected.emit(selected)
		check(not c._purchase_advancement_button.disabled,"READY UI and command must share the same safe-state policy.")
		c._purchase_advancement_button.pressed.emit()
		print("READY_STR_UI_RESULT: "+c._last_ui_message+" | session reason: "+session._last_error)
		check(session.simulation.get_actor_definition(&"player").attributes.str == 10 and session.get_reward_state().unspent_xp == balance-3000,"Existing READY character must purchase STR through the actual button.")
		check(session._playable_persistence._last_ack and session._playable_persistence.recovery.phase == "entry" and session._playable_persistence.recovery.wave_id == wave_id,"READY purchase must durably update the same entry checkpoint.")
		check(session._playable_persistence._prior.secured_checkpoints == history,"READY purchase must not mark the unfinished wave completed.")
		check(session.get_actor_state(&"player").resources == resources and session.get_actor_state(&"player").current_hpc == hpc,"READY purchase cannot refill resources.")
		var original_request := String(session._reward_ledger.purchase_records.back().request_id)
		var purchased := session.get_state_snapshot()
		check(not session.request_character_advancement(&"attribute",&"str",original_request).success and session.get_state_snapshot() == purchased,"Repeated confirmation cannot spend or grant STR twice.")
		var harness := TwoClientSyncHarness.new(1)
		harness.authority.simulation = session.simulation
		harness.deliver_in_order(harness.authority.publish_current_events())
		check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == session.simulation.get_state_snapshot(),"READY purchase converges through existing authoritative two-client replay.")
		helper._free(scene)
		scene = helper._scene()
		c = scene.get_node("CombatController")
		c._encounter_selector_index = 8
		check(c.select_player_character_for_testing(&"vaelis_thorn").success,"Purchased READY profile must reopen through ordinary selection.")
		session = c._session
		check(session.simulation.get_actor_definition(&"player").attributes.str == 10 and session.get_reward_state().unspent_xp == balance-3000 and session._current_reward_wave_id() == wave_id,"Reload retains STR, EXPC and the same unfinished wave.")
		check(session.get_actor_state(&"player").resources == resources and session.get_actor_state(&"player").current_hpc == hpc,"Reload after READY purchase restores exact entry resources.")
		var reloaded := session.get_state_snapshot()
		check(session.request_character_advancement(&"attribute",&"str",original_request).get("reason") == "duplicate_advancement_request" and session.get_state_snapshot() == reloaded,"Durable request identity rejects duplicates after reload.")
		session.set_opponent_behavior_enabled(false)
		helper._defeat_wave(session)
		c._update_presentation()
		c._encounter_button.pressed.emit()
		check(session._current_reward_wave_id() != wave_id and session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_RUNNING,"NEXT WAVE still works through the ordinary button after a READY purchase.")
	helper._free(scene)
	PlayableCharacterPersistence.test_storage = old_storage
	PlayableCharacterPersistence.test_nonpersistent = old_mode
	var unit := Strength.new().setup_actor(37,9,3800)
	check(unit.ledger.purchase_advancement(unit.sim,"owner_balance",&"attribute",&"str").success and unit.ledger.to_dictionary().unspent_xp == 800,"Exact owner balance: 3800 EXPC pays 3000 and leaves 800.")
	return failures
