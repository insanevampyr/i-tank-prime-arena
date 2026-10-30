extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var _failures: Array[String] = []

class UncertainStorage extends CharacterSaveStorage:
	var uncertain := false
	var attempts := 0
	func _init(path: String) -> void: super(path)
	func write_profile(profile: String, payload: Dictionary, transaction: String) -> Dictionary:
		if uncertain:
			attempts += 1
			return {"success":true}
		return super.write_profile(profile,payload,transaction)

func run() -> Array[String]:
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("playable_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	PlayableCharacterPersistence.test_storage = CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_run_id = "run_playable_test"
	_test_playable_load(root)
	_test_developer_progression(root)
	_test_inventory_and_failures(root)
	PlayableCharacterPersistence.test_nonpersistent = true
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_run_id = ""
	assert(root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests")+"/playable_"))
	_remove_fixture(root)
	return _failures

func _scene() -> Node:
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene

func _free(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()

func _test_playable_load(root: String) -> void:
	var scene := _scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var selected := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Actual playable selection must admit Vaelis: %s / %s" % [selected,controller._last_ui_message])
	if not selected.get("success",false):
		_free(scene)
		return
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	_expect(session.get_character_persistence_status().persistent,"Actual desktop session must acknowledge its first checkpoint.")
	_expect(session.get_actor_state(&"player").inventory_quantities.prime_v3_gold == 75,"Play starts with exactly the authored 75 Gold.")
	var initial := session.get_actor_state(&"player").to_dictionary()
	var first_ids: Array = session._playable_persistence.items.duplicate(true)
	var first_profile: Dictionary = session._playable_persistence._prior.duplicate(true)
	_expect(first_profile.run_history == ["run_playable_test"] and first_profile.recovery.run_id == first_profile.run_history[0],"Wave recovery binds an explicit authorized run history.")
	var invalid_run := first_profile.duplicate(true)
	invalid_run.recovery.run_id = "foreign_run"
	_expect(not CharacterSaveContract.validate(invalid_run).success,"A recovery checkpoint cannot silently substitute a different run identity.")
	controller._on_encounter_button_pressed()
	# An interrupted wave must discard these uncheckpointed resource expenditures.
	session.get_actor_state(&"player").current_hpc = 2
	session.get_actor_state(&"player").resources.mana = 1
	_free(scene)

	scene = _scene()
	controller = scene.get_node("CombatController")
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Exit/reopen must load the actual playable profile: %s / %s" % [selected,controller._last_ui_message])
	if not selected.get("success",false):
		_free(scene)
		return
	session = controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	var state := session.get_actor_state(&"player")
	_expect(state.current_hpc == initial.current_hpc and state.resources == initial.resources,"Wave-1 retry restores its exact entry resources, not the interrupted state.")
	_expect(session._playable_persistence.items == first_ids,"Exit/reload never duplicates or replaces starter instances.")
	controller._on_encounter_button_pressed()
	for attempt in range(5):
		if state.persistent_damage_shields.has("force_shield"): break
		var cast := session.request_player_special(VaelisForceFixture.FORCE_SHIELD_ID)
		if not cast.get("success",false): break
		session.advance_by(5000000)
	_expect(state.persistent_damage_shields.has("force_shield"),"Entry fixture must complete an ordinary source-legal Force Shield cast.")
	# Partially absorbed protection fixture isolates exact checkpoint capacity;
	# actual absorption/knockback calculations remain covered by the Force suite.
	if state.persistent_damage_shields.has("force_shield"): state.persistent_damage_shields.force_shield.capacity = 13
	# Deterministic defeat fixture exercises the real wave lifecycle and writer.
	var model := controller._player._movement
	model.request_running()
	model.advance(1000000,Vector2.UP)
	var move := session.request_player_movement(Vector2i(roundi(model.position_feet.x*1000000),roundi(model.position_feet.y*1000000)),model.get_effective_mr())
	_expect(move.get("success",false),"Entry-recovery fixture must spend MR through legal authoritative movement.")
	controller._player.apply_authoritative_combat_position(Vector2(session.get_actor_state(&"player").position_microfeet)/1000000.0)
	session.advance_by(1000000)
	model.stop_running()
	for id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Actual wave completion must reach safe downtime.")
	state.current_hpc = 4
	state.resources.mana = 6
	state.resources.blood = 7
	var changed := session._checkpoint_character("character_changed")
	_expect(changed.get("success",false),"Safe post-wave checkpoint must commit exact current resources: %s" % changed)
	var next := session.request_next_wave()
	_expect(next.get("success",false),"NEXT WAVE must secure a coherent wave-entry generation: %s" % next)
	var entry_resources := state.resources.duplicate(true)
	var entry_hpc: int = state.current_hpc
	var entry_shields := state.persistent_damage_shields.duplicate(true)
	var rng := session.simulation.random.wave_entry_state()
	var entry_motion := controller._player.capture_wave_entry_motion()
	var spent_mr := session._player_movement_spent_microfeet
	state.current_hpc = 1
	state.resources.mana = 0
	_free(scene)
	scene = _scene()
	controller = scene.get_node("CombatController")
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Wave-2 entry must load through selection: %s / %s" % [selected,controller._last_ui_message])
	if selected.get("success",false):
		session = controller.get_combat_session_for_testing()
		state = session.get_actor_state(&"player")
		_expect(session._current_reward_wave_id() == "wave_2" and state.current_hpc == entry_hpc and state.resources == entry_resources,"Interrupted wave restarts its exact identity/HPC/Mana/Blood without a free refill.")
		_expect(session.simulation.random.wave_entry_state() == rng,"Recovery uses the entry RNG state without rerolling historical growth or wave quantities.")
		_expect(state.persistent_damage_shields == entry_shields and state.persistent_damage_shields.get("force_shield",{}).get("capacity") == 13,"Exact remaining Force Shield protection survives downtime, NEXT WAVE and interrupted-wave recovery.")
		_expect(controller._player.capture_wave_entry_motion() == entry_motion and session._player_movement_spent_microfeet == spent_mr,"Running recovery/cooldown and MR expenditure survive entry recovery without a free allowance.")
		_expect(session.get_state_snapshot().schema_version == 12,"Playable persistence does not change schema 12.")
	var storage := CharacterSaveStorage.new(root)
	_expect(storage.read_profile("prod_vaelis_thorn").get("success",false),"Actual game path must leave a verifiable profile generation.")
	var restored_snapshot := session.simulation.get_state_snapshot()
	_free(scene)
	scene = _scene()
	controller = scene.get_node("CombatController")
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false) and controller.get_combat_session_for_testing().simulation.get_state_snapshot() == restored_snapshot,"Repeated same-seed entry hydration yields identical authoritative schema-12 snapshots.")
	_free(scene)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/playable_persistence_process_probe.gd","--","--profile-test-root="+root]),output,true)
	_expect(code == 0 and str(output).contains("PROCESS_PROFILE_VERIFIED") and not str(output).contains("SCRIPT ERROR") and not str(output).contains("leaked at exit") and not str(output).contains("resources still in use"),"A separate Godot process must reload through actual character selection without resource warnings: %s" % output)

func _defeat_wave(session: ArenaCombatSession) -> void:
	session.set_opponent_behavior_enabled(false)
	if session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY: session.start_encounter()
	var origin := session.get_actor_state(&"player").position_microfeet
	for id: String in session.get_targetable_enemy_ids():
		session.select_target(StringName(id))
		session.simulation.apply_authoritative_spatial_position(StringName(id),origin+Vector2i(1000000,0),0,180000)
		# Wounded source combatants isolate persistence from a full balance playtest;
		# the killing ACC/defense/damage and XP event still resolve through combat.
		session.get_actor_state(StringName(id)).current_hpc = 1
		var last_request: Dictionary = {}
		for attempt in range(100):
			if int(session.get_actor_state(StringName(id)).current_hpc) <= 0: break
			# Successful Dodge legally displaces a target; re-establish the focused
			# fixture before the next Act rather than bypassing final reach checks.
			session.simulation.apply_authoritative_spatial_position(StringName(id),session.get_actor_state(&"player").position_microfeet+Vector2i(1000000,0),0,180000)
			if session.is_actor_prone(&"player"):
				session.request_player_stand("persistence_stand")
				session.advance_by(5000000)
			var request := session.request_player_attack("persistence_combat")
			last_request = request
			session.advance_by(5000000 if request.get("success",false) else 100000)
		_expect(int(session.get_actor_state(StringName(id)).current_hpc) <= 0,"Source physical combat must actually defeat %s (%s)." % [id,last_request])
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME,"Actual physical defeats must complete the wave.")

func _test_developer_progression(root: String) -> void:
	var scene := _scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller._encounter_selector_index = 8
	var selected := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Developer Vaelis must use its own playable profile: %s" % controller._last_ui_message)
	if not selected.get("success",false):
		_free(scene)
		return
	var session := controller.get_combat_session_for_testing()
	_defeat_wave(session)
	var collected := session.collect_all_ground_loot()
	_expect(collected.get("success",false),"Collected drops must pass the authoritative inventory transaction.")
	_expect(session.get_character_persistence_status().persistent,"Real XP/growth/collected-item checkpoint must be verified: %s" % session.get_character_persistence_status())
	var earned := int(session.get_reward_state().earned_xp)
	for receipt: Dictionary in session._playable_persistence.receipts:
		if receipt.kind == "xp": _expect(receipt.run_id == session._playable_persistence.run_id and receipt.wave_id == "wave_1","Gameplay settlements identify their real run and wave explicitly.")
	var growth: Array = session._playable_persistence._prior.permanent.growth.duplicate(true)
	var owned: Array = session._playable_persistence._prior.items.duplicate(true)
	var hpm: int = session.get_actor_max_hpm(&"player")
	_expect(earned > 0 and not growth.is_empty() and hpm > 9,"Developer combat must genuinely award XP and recorded HPM growth.")
	_free(scene)
	scene = _scene()
	controller = scene.get_node("CombatController")
	controller._encounter_selector_index = 8
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Earned progression must cold-load into playable downtime: %s" % controller._last_ui_message)
	if selected.get("success",false):
		session = controller.get_combat_session_for_testing()
		_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME and session.get_reward_state().earned_xp == earned and session.get_actor_max_hpm(&"player") == hpm,"Reload restores secured XP/HPM and downtime without replaying rewards.")
		_expect(session._playable_persistence._prior.permanent.growth == growth and session._playable_persistence.items == owned,"Original rolls and collected item identities/provenance remain exact.")
		for receipt: Dictionary in session._playable_persistence.receipts:
			if receipt.kind in ["item","currency"]: _expect(session._playable_persistence._world_claims.has(receipt.content.instance_id),"Cold reload retains every acquisition claim, including consumed instances.")
		_expect(session.collect_all_ground_loot().get("collected_count",0) == 0,"Reopening rewards cannot collect an already secured item again.")
		for wave in range(2,5):
			var advanced := session.request_next_wave()
			_expect(advanced.get("success",false),"Developer NEXT WAVE must secure source progression: %s" % advanced)
			if not advanced.get("success",false): break
			_defeat_wave(session)
		if session.get_reward_state().unspent_xp >= 2000:
			var purchased := session.request_character_advancement(&"special_resistance",&"sr","persistent_purchase")
			_expect(purchased.get("success",false) and purchased.get("persistence",{}).get("success",false),"Actual purchase must deduct/secure EXPC once: %s" % purchased)
			var xp: Dictionary = session._playable_persistence._prior.xp.duplicate(true)
			var purchases: Array = session._playable_persistence._prior.purchases.duplicate(true)
			_free(scene)
			scene = _scene()
			controller = scene.get_node("CombatController")
			controller._encounter_selector_index = 8
			selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
			_expect(selected.get("success",false),"Purchased character must cold-load: %s" % controller._last_ui_message)
			if selected.get("success",false):
				session = controller.get_combat_session_for_testing()
				_expect(session._playable_persistence._prior.xp == xp and session._playable_persistence._prior.purchases == purchases and session.simulation.get_actor_definition(&"player").get_base_combat_stat("sr") == 2,"EXPM/EXPC, costs and applied SR must restore without repurchasing.")
				_test_new_run(controller,session)
	var storage := CharacterSaveStorage.new(root)
	_expect(storage.read_profile("prod_vaelis_thorn").payload.profile_namespace == "normal" and storage.read_profile("dev_vaelis_thorn").payload.profile_namespace == "dev_normal","Developer combat never changes production profile lineage.")
	_free(scene)

func _test_new_run(controller: ArenaCombatController, session: ArenaCombatSession) -> void:
	session.set_opponent_behavior_enabled(false)
	var history: Array = session._playable_persistence._prior.permanent.growth.duplicate(true)
	var purchases: Array = session._playable_persistence._prior.purchases.duplicate(true)
	var owned: Array = session._playable_persistence._prior.items.duplicate(true)
	var balances: Dictionary = session._playable_persistence._prior.xp.duplicate(true)
	_expect(session.request_next_wave().get("success",false),"Purchased profile must enter Wave 5 without refilling.")
	# Lifecycle-only fixture for the boss; its combat mechanics have separate suites.
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	_expect(session.request_next_wave().get("success",false) and session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY,"A completed circuit must secure a final coherent checkpoint.")
	PlayableCharacterPersistence.test_run_id = "run_playable_next"
	controller._on_encounter_button_pressed()
	var next := controller.get_combat_session_for_testing()
	_expect(next._playable_persistence._prior.run_history == ["run_playable_test","run_playable_next"],"NEW RUN appends its own identity without relabeling prior settlements.")
	var altered_history: Dictionary = next._playable_persistence._prior.duplicate(true)
	altered_history.run_history.reverse()
	_expect(not CharacterSaveContract.validate_replacement(next._playable_persistence._prior,altered_history).success,"Prior run identities cannot be reordered or replaced.")
	_expect(next.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY and next._current_reward_wave_id() == "wave_1","Explicit NEW RUN restarts Wave 1; it is not interrupted-wave recovery.")
	_expect(next._playable_persistence._prior.xp == balances and next._playable_persistence._prior.purchases == purchases and next._playable_persistence._prior.permanent.growth == history and next._playable_persistence.items == owned,"NEW RUN retains permanent XP/purchases/rolls/ownership without replay or duplicate grants.")
	var player := next.get_actor_state(&"player")
	_expect(player.current_hpc == next.get_actor_max_hpm(&"player") and player.resources == next.simulation.get_actor_definition(&"player").resource_maxima,"Only explicit NEW RUN restores current applicable maxima.")
	_expect(player.ability_daily_remaining == player.ability_daily_maxima,"Applicable daily allowances initialize once at NEW RUN.")
	_defeat_wave(next)
	_expect(next.get_character_persistence_status().persistent and next._playable_persistence._prior.xp.earned > balances.earned,"A later run can secure fresh earned XP without colliding with prior-run actor/event identities.")
	var second_run_awards := 0
	for receipt: Dictionary in next._playable_persistence.receipts:
		if receipt.kind == "xp" and receipt.run_id == "run_playable_next": second_run_awards += 1
	_expect(second_run_awards == next._arena_wave_state_machine.get_resolved_roster()[0].resolved_count,"Every second-run defeat has exactly one settlement under its real run identity.")

func _test_inventory_and_failures(root: String) -> void:
	var scene := _scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var selected := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	if not selected.get("success",false):
		_expect(false,"Inventory recovery fixture must load: %s" % controller._last_ui_message)
		_free(scene)
		return
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	controller._on_encounter_button_pressed()
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	# Source-valid item fixtures go through the actual ground creation/collection
	# transactions. They do not change production drop tables or item statistics.
	var origin := session.simulation.record_reward_event(&"reward_persistence_item_fixture",&"player",&"player",{})
	for ref: String in ["health_potion","prime_v3_metal_buckler"]:
		session.simulation.create_ground_loot_item("fixture_"+ref,{"definition_id":ref,"quantity":10 if ref == "health_potion" else 1,"display_name":ref,"item_kind":"potion" if ref == "health_potion" else "equipment","source_ref":"PRIME-V3 pp. 120, 137; isolated source item fixture"},session.get_actor_state(&"player").position_microfeet,&"player",origin.event_id)
	_expect(session.collect_all_ground_loot().get("success",false),"Actual loot collection must establish item instances before use.")
	_expect(session.request_player_weapon_handling(Fixture.VAELIS_WAND_REF,"stow","stow_fixture").get("success",false),"Stowing frees a legal potion hand through the shared engine.")
	var player := session.get_actor_state(&"player")
	player.current_hpc = 3
	var potion := session.request_player_inventory_consumable_use(&"health_potion","potion_fixture")
	_expect(potion.get("success",false) and potion.get("persistence",{}).get("success",false) and player.inventory_quantities.health_potion == 9,"Verified potion resolution consumes exactly one original stack unit and saves.")
	var rng := session.simulation.random.get_draw_count()
	_expect(not session.request_player_inventory_consumable_use(&"health_potion","potion_fixture").success and session.simulation.random.get_draw_count() == rng,"Repeated potion request cannot consume or roll twice.")
	_expect(session.request_player_inventory_unequip(Fixture.VAELIS_WAND_REF,"unstow_to_inventory").get("success",false),"Unequipping must retain the original Wand instance.")
	_expect(session.request_player_inventory_equip(Fixture.VAELIS_WAND_REF,"equip_original_wand").get("success",false),"Re-equipping uses the same original instance.")
	_expect(session.request_player_inventory_equip(&"prime_v3_metal_buckler","equip_buckler").get("success",false),"Verified arm-mounted Buckler may be equipped without fabricating ownership.")
	_test_shield_wear(session)
	var remaining_potions: int = session.get_actor_state(&"player").inventory_quantities.health_potion
	var snapshots: Array = session._playable_persistence._prior.items.duplicate(true)
	var before := session.simulation.get_state_snapshot()
	var rejected := session.configure_reward_mode("dev_normal")
	_expect(not rejected.success and session.simulation.get_state_snapshot() == before,"A live production profile cannot switch into developer lineage.")
	var harness := TwoClientSyncHarness.new(7)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().success and harness.client_a.get_state_snapshot() == session.simulation.get_state_snapshot(),"Actual persistent inventory state must converge through schema-12 synchronization.")
	_free(scene)
	scene = _scene()
	controller = scene.get_node("CombatController")
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false),"Equipped/consumed source instances must cold-load: %s" % controller._last_ui_message)
	if selected.get("success",false):
		session = controller.get_combat_session_for_testing()
		_expect(session._playable_persistence.items == snapshots and session.get_actor_state(&"player").inventory_quantities.health_potion == remaining_potions,"Consumption, original instances and equipped references survive exit/reload exactly.")
		_expect(session.simulation.get_defense_profile(&"player").shield_block.current_shp < 20,"Shield damage must not refill on cold restoration.")
		var generation: int = session._playable_persistence.generation
		controller._reset_encounter()
		_expect(CharacterSaveStorage.new(root).read_profile("prod_vaelis_thorn").payload.generation == generation and session._playable_persistence == null,"RESET is ephemeral and never deletes or overwrites a saved character.")
	_free(scene)
	# Failed write must freeze required transitions, without any blind retry.
	var fault := UncertainStorage.new(root)
	PlayableCharacterPersistence.test_storage = fault
	scene = _scene()
	controller = scene.get_node("CombatController")
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	if selected.get("success",false):
		session = controller.get_combat_session_for_testing()
		fault.uncertain = true
		session.get_actor_state(&"player").current_hpc = maxi(1,int(session.get_actor_max_hpm(&"player"))-1)
		var failed := session._checkpoint_character("character_changed")
		_expect(not failed.success and not session.get_character_persistence_status().persistent,"Unverifiable write cannot claim a saved checkpoint.")
		var locked_state := session.get_state_snapshot()
		_expect(not session.collect_all_ground_loot().success and not session.request_next_wave().success,"Uncertain save blocks further mutations and wave advancement.")
		_expect(session.get_state_snapshot() == locked_state and fault.attempts == 1,"Blocked retries do not mutate simulation or issue another write.")
	_free(scene)
	PlayableCharacterPersistence.test_storage = CharacterSaveStorage.new(root)
	var storage := CharacterSaveStorage.new(root)
	var directory := root.path_join("prod_vaelis_thorn")
	var dir := DirAccess.open(directory)
	var names := dir.get_files()
	names.sort()
	var file_path := directory.path_join(names[-1])
	var file := FileAccess.open(file_path,FileAccess.WRITE)
	file.store_string("test-corrupt-latest-generation")
	file.close()
	scene = _scene()
	controller = scene.get_node("CombatController")
	var guard := controller.get_combat_session_for_testing().get_state_snapshot()
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(not selected.success and controller.get_combat_session_for_testing().get_state_snapshot() == guard,"Corrupt load rejects atomically; original Guard simulation remains intact.")
	_expect(FileAccess.get_file_as_string(file_path) == "test-corrupt-latest-generation" and not storage.inspect_profile("prod_vaelis_thorn").success,"Corrupt generation is preserved, never silently replaced.")
	_free(scene)
	scene = _scene()
	controller = scene.get_node("CombatController")
	controller._developer_test_mode = true
	var files_before := dir.get_files().size()
	selected = controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect(selected.get("success",false) and controller.get_combat_session_for_testing()._playable_persistence == null and dir.get_files().size() == files_before,"TEST remains playable and cannot read/replace a corrupt production profile.")
	_free(scene)

func _test_shield_wear(session: ArenaCombatSession) -> void:
	session.set_opponent_behavior_enabled(false)
	_expect(session.request_next_wave().get("success",false),"Shield fixture must enter the next real wave.")
	var defender := session.simulation.get_defense_profile(&"player")
	var old_priority := defender.priority.duplicate()
	# Legal defense preference fixture; all source rolls/targets/damage remain real.
	defender.priority = PackedStringArray(["shield_block","dodge","weapon_block","physical_soak"])
	session.request_player_weapon_handling(Fixture.VAELIS_WAND_REF,"stow","free_healing_hand")
	var enemy := StringName(session.get_targetable_enemy_ids()[0])
	for attempt in range(40):
		var player := session.get_actor_state(&"player")
		if defender.shield_block.current_shp < 20 or int(player.current_hpc) <= 0: break
		if session.is_actor_prone(&"player"):
			session.request_player_stand("wear_stand")
			session.advance_by(5000000)
		if int(player.current_hpc) < int(session.get_actor_max_hpm(&"player")):
			var heal := session.request_player_inventory_consumable_use(&"health_potion","wear_heal_%s" % attempt)
			if heal.get("success",false): session.advance_by(10000000)
		session.simulation.apply_authoritative_spatial_position(enemy,player.position_microfeet+Vector2i(1000000,0),0,180000)
		var attack := session._request_actor_attack(enemy,&"player","wear_attack")
		if attack.get("success",false): session.advance_by(5000000)
	defender.priority = old_priority
	_expect(defender.shield_block.current_shp < 20,"Real shield defense must spend authoritative SHP before persistence is tested.")
	_defeat_wave(session)
	var wear: int = defender.shield_block.current_shp
	_expect(session.request_player_inventory_unequip(&"prime_v3_metal_buckler","store_worn_buckler").get("success",false),"Tracked damaged shield may be carried without losing its condition.")
	_expect(session.request_player_inventory_equip(&"prime_v3_metal_buckler","reequip_worn_buckler").get("success",false),"Re-equipping uses the original worn shield instance.")
	_expect(session.simulation.get_defense_profile(&"player").shield_block.current_shp == wear,"Equipment changes cannot repair SHP.")

func _remove_fixture(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var dir := DirAccess.open(path)
	for name: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name: String in dir.get_directories(): _remove_fixture(path.path_join(name))
	DirAccess.remove_absolute(path)

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
