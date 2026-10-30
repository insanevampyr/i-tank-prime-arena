extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Force = preload("res://scripts/combat/vaelis_force_fixture.gd")
const PersistenceTests = preload("res://tests/test_playable_vaelis_persistence.gd")
var _failures: Array[String] = []

class FaultStorage extends CharacterSaveStorage:
	var reject_writes := false
	func _init(path: String) -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		if reject_writes: return {"success":false,"reason":"fixture_write_denied"}
		return super.write_profile(profile,payload,transaction)

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("playable_fix1_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableCharacterPersistence.test_run_id = "run_next_wave_fix"
	var first := _exercise(root.path_join("first"),false)
	var replay := _exercise(root.path_join("replay"),false)
	_expect(first == replay,"Same-seed playable NEXT WAVE events and digests must replay exactly.")
	_exercise(root.path_join("failure"),true)
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_run_id = ""
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/playable_fix1_"))
	PersistenceTests.new()._remove_fixture(root)
	return _failures

func _exercise(root: String, fail_write: bool) -> Dictionary:
	var storage := FaultStorage.new(root)
	PlayableCharacterPersistence.test_storage = storage
	var scene := PersistenceTests.new()._scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.combat_seed = 1
	controller._encounter_selector_index = 8
	var selected := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"DEV NORMAL must load via actual character selection.")
	if not selected.get("success",false):
		PersistenceTests.new()._free(scene)
		return {}
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	controller.press_encounter_control_for_testing()
	var ids := session.get_targetable_enemy_ids()
	for index in range(ids.size()-1): _defeat_actor(session,StringName(ids[index]))
	var target := StringName(ids[-1])
	_position_target(session,target)
	session.get_actor_state(target).current_hpc = 1
	var attack := session.request_player_attack("last_enemy_sword")
	_expect(attack.get("success",false),"The last-enemy fixture must commit a real ordinary physical Act.")
	var player := session.get_actor_state(&"player")
	var pending_id := player.current_action_instance_id
	for attempt in range(5):
		if session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME: break
		_position_target(session,target)
		session.request_player_special(Force.FORCE_BOLT_ID)
		session.advance_by(1)
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"A real concurrent NAC kill must complete Wave 1.")
	_expect(not pending_id.is_empty(),"Reproduction must include an ordinary Act committed before the final NAC kill.")
	_expect(player.current_action_instance_id.is_empty() and session.simulation.get_action(pending_id).interruption_reason == "wave_combatant_retired","Existing retirement must settle the obsolete enemy-targeting action before safe projection.")
	controller.update_presentation_for_testing()
	_expect(controller.is_rewards_panel_visible_for_testing(),"Victory must display downtime rewards.")
	_expect(session.get_character_persistence_status().persistent,"A concurrent final kill must secure victory without bypassing pending-action validation.")
	controller._on_collect_loot_pressed()
	controller._on_developer_refresh_pressed()
	# Spending fixtures distinguish approved explicit DEV refresh from an
	# unauthorized refill performed by NEXT WAVE itself.
	player.current_hpc = maxi(1,int(session.get_actor_max_hpm(&"player"))-2)
	player.resources.mana = 5
	var resources := player.resources.duplicate(true)
	var hpc: int = player.current_hpc
	var shields := player.persistent_damage_shields.duplicate(true)
	var rewards := session.get_reward_state()
	var inventory_before := player.inventory_quantities.duplicate(true)
	var generation_before: int = session._playable_persistence.generation
	var clock_before := session.simulation.clock.get_elapsed_us()
	storage.reject_writes = fail_write
	controller._encounter_button.pressed.emit()
	if fail_write:
		_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME and session._current_reward_wave_id() == "wave_1","Rejected checkpoint must not advance the wave.")
		_expect(controller.is_rewards_panel_visible_for_testing() and not controller._encounter_button.disabled,"Rejected NEXT WAVE must retain visible, actionable downtime controls.")
		_expect(controller.get_last_ui_message_for_testing().contains("fixture write denied"),"The actual checkpoint failure must remain visible after presentation refresh: %s" % controller.get_last_ui_message_for_testing())
		controller.update_presentation_for_testing()
		_expect(controller.get_last_ui_message_for_testing().contains("fixture write denied"),"Repeated UI refresh must not erase the checkpoint error.")
		_expect(storage.read_profile("dev_vaelis_thorn").payload.generation == generation_before,"A rejected checkpoint cannot replace the last verified generation.")
	else:
		_expect(session._current_reward_wave_id() == "wave_2" and session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_RUNNING,"Button NEXT WAVE must secure the checkpoint and activate Wave 2.")
		_expect(not controller.is_rewards_panel_visible_for_testing(),"Rewards close only after successful advancement.")
		_expect(not session.get_targetable_enemy_ids().is_empty(),"Wave 2 enemies must exist and have scene visuals.")
		for id: String in session.get_targetable_enemy_ids(): _expect(controller._get_enemy_visual(StringName(id)) != null,"Every arriving enemy must have a visual.")
		_expect(player.current_hpc == hpc and player.resources == resources and player.persistent_damage_shields == shields,"NEXT WAVE cannot refill HPC/Mana or change protection.")
		var saved := storage.read_profile("dev_vaelis_thorn")
		_expect(saved.get("success",false) and saved.payload.recovery.wave_id == "wave_2" and saved.payload.profile_namespace == "dev_normal","Playable transition must publish a valid isolated DEV Wave-2 entry.")
		_expect(not storage.read_profile("prod_vaelis_thorn").get("success",false),"DEV transition cannot publish a production profile.")
		var before := session.simulation.get_state_snapshot()
		session.request_next_wave()
		_expect(session.simulation.get_state_snapshot() == before,"Repeated NEXT WAVE cannot mutate the active wave or duplicate rewards.")
	_expect(session.get_reward_state().earned_xp == rewards.earned_xp and player.inventory_quantities == inventory_before,"Advancement cannot award extra XP or inventory.")
	_expect(session.simulation.clock.get_elapsed_us() == clock_before,"Saving and NEXT WAVE must not advance combat time or effect durations.")
	var snapshot := session.simulation.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(1)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(snapshot.schema_version == 12 and harness.compare_clients().success and harness.client_a.get_state_snapshot() == snapshot,"The actual transition must preserve schema-12 two-client convergence.")
	var events: Array = []
	for event: CombatEvent in session.get_resolved_events(): events.append(event.to_dictionary())
	var result := {"events":events,"digest":SyncStateDigest.compute(snapshot)}
	PersistenceTests.new()._free(scene)
	if not fail_write:
		# Reopen the scene through the same playable DEV selection path, not a
		# storage-only mock or a direct hydrated-actor assignment.
		scene = PersistenceTests.new()._scene()
		controller = scene.get_node("CombatController")
		controller._encounter_selector_index = 8
		var reopened := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
		_expect(reopened.get("success",false),"DEV Wave-2 entry must reopen through playable selection.")
		if reopened.get("success",false):
			var restored := controller.get_combat_session_for_testing()
			var restored_player := restored.get_actor_state(&"player")
			_expect(restored._current_reward_wave_id() == "wave_2" and restored_player.current_hpc == hpc and restored_player.resources == resources and restored_player.inventory_quantities == inventory_before and restored.get_reward_state().earned_xp == rewards.earned_xp,"Desktop reload must preserve the new entry and its exact resources, inventory and XP.")
		PersistenceTests.new()._free(scene)
	return result

func _defeat_actor(session: ArenaCombatSession, target: StringName) -> void:
	session.get_actor_state(target).current_hpc = 1
	for attempt in range(80):
		if int(session.get_actor_state(target).current_hpc) <= 0: return
		_position_target(session,target)
		var request := session.request_player_attack("fixture_sword")
		session.advance_by(5000000 if request.get("success",false) else 100000)
	_expect(false,"Source physical combat must defeat the wounded fixture enemy.")

func _position_target(session: ArenaCombatSession, target: StringName) -> void:
	session.select_target(target)
	session.simulation.apply_authoritative_spatial_position(target,session.get_actor_state(&"player").position_microfeet+Vector2i(1000000,0),0,180000)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
