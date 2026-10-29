extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	var session := controller.get_combat_session_for_testing()
	var position := session.get_actor_state(&"player").position_microfeet
	for index in range(200):
		var created := session.simulation.create_ground_loot_item("36f:%s" % index, {"definition_id": "prime_v3_gold", "display_name": "5 Gold", "category": "currency", "quantity": 5}, position, &"", "isolated:36f", {})
		if not created.get("success", false): failures.append("Profiling loot fixture failed creation.")
	controller.update_presentation_for_testing()
	var authoritative_before := SyncStateDigest.compute(session.get_state_snapshot())
	var started := Time.get_ticks_usec()
	for index in range(100):
		# Reproduce the two removed presentation costs with identical fixture data.
		CombatDefinitionCatalog.load_default_fixture_catalog().get_weapon(&"prime_v3_battle_axe")
		controller._marker_refresh_key = ""
		controller.update_presentation_for_testing()
	print("METRIC Task36F legacy-read reproduction 100 updates us=", Time.get_ticks_usec() - started)
	started = Time.get_ticks_usec()
	for index in range(100): controller.update_presentation_for_testing()
	print("METRIC Task36F 200-loot 100 presentation updates us=", Time.get_ticks_usec() - started)
	if SyncStateDigest.compute(session.get_state_snapshot()) != authoritative_before: failures.append("Presentation/cache profiling must not mutate authoritative events, RNG or snapshots.")
	var marker: Node2D = controller._world_item_markers["36f:0"]
	var click := controller.request_pointer_action_for_testing(marker.global_position, true)
	if click.get("loot", {}).get("reason") != "loot_collection_requires_between_wave_downtime": failures.append("Combat/ready loot clicks must fail without initiating attacks.")
	controller.press_encounter_control_for_testing()
	var combat_click := controller.request_pointer_action_for_testing(marker.global_position, true)
	if combat_click.get("loot", {}).get("reason") != "combat_pickup_requirements_unverified" or combat_click.get("attack") != null: failures.append("Combat loot clicks must fail closed explicitly without attacking.")
	for actor_id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()
	var before := int(session.get_actor_state(&"player").inventory_quantities.get("prime_v3_gold", 0))
	click = controller.request_pointer_action_for_testing(marker.global_position, true)
	if not click.get("loot", {}).get("success", false) or click.get("attack") != null: failures.append("Legal loot click must collect exactly one stable item without attack.")
	if int(session.get_actor_state(&"player").inventory_quantities.get("prime_v3_gold", 0)) != before + 5: failures.append("Stacked loot click must collect one entry only.")
	if not controller.get_last_ui_message_for_testing().begins_with("Collected 5 Gold"): failures.append("Collection feedback must use actual currency quantity.")
	if ArenaCombatController.format_inventory_entry({"definition_id": "prime_v3_gold", "quantity": 246, "display_name": "5 Gold"}) != "Gold: 246": failures.append("Gold presentation must aggregate without obsolete denomination.")
	if ArenaCombatController.format_inventory_entry({"equipped": true, "quantity": 0, "display_name": "Axe"}) != "Axe — EQUIPPED": failures.append("Equipped label must not imply zero ownership.")
	var player := session.get_actor_state(&"player")
	var position_before := player.position_microfeet
	var actions_before: int = session.simulation.get_state_snapshot().get("actions", []).size()
	var second_click := controller.request_pointer_action_for_testing(marker.global_position, true)
	if not second_click.get("loot", {}).get("success", false): failures.append("Second click must collect the next distinct stacked record.")
	if session.simulation.get_world_item("36f:0").get("state") != "collected": failures.append("Collected stable identity must remain recorded.")
	if session.collect_ground_loot("36f:0").get("success", false): failures.append("A collected identity must not be collected twice.")
	if player.position_microfeet != position_before or session.simulation.get_state_snapshot().get("actions", []).size() != actions_before: failures.append("Loot clicks must not move or schedule actions.")
	# Move only the isolated authoritative fixture to verify UI rejection; no
	# gameplay movement allowance or downtime rule is introduced by the test.
	player.position_microfeet += Vector2i(3_000_000, 0)
	var failed := controller.request_pointer_action_for_testing(marker.global_position, true)
	if failed.get("loot", {}).get("success", false) or controller.get_last_ui_message_for_testing() != "Move closer to collect.": failures.append("Out-of-range click must reject with proximity feedback.")
	player.position_microfeet = position_before
	var original_battlefield := session.get_battlefield()
	var blocked_position := position_before + Vector2i(800_000, 0)
	var created := session.simulation.create_ground_loot_item("00wall", {"definition_id": "prime_v3_gold", "display_name": "Gold", "item_kind": "gold", "quantity": 6}, blocked_position, &"", "isolated:wall", {})
	if not created.get("success", false): failures.append("Wall fixture loot must be created legally before inserting isolated test geometry.")
	session._battlefield = ArenaBattlefield.new(original_battlefield.bounds_microfeet, [{"id": "thin-test-wall", "rect_microfeet": Rect2i(position_before + Vector2i(400_000, -1_000_000), Vector2i(100_000, 2_000_000))}])
	controller.update_presentation_for_testing()
	var wall_marker: Node2D = controller._world_item_markers["00wall"]
	var wall_click := controller.request_pointer_action_for_testing(wall_marker.global_position, true)
	if wall_click.get("loot", {}).get("success", false) or controller.get_last_ui_message_for_testing() != "Path blocked.": failures.append("Within-reach pickup through solid cover must reject with blocked feedback.")
	if session.simulation.get_world_item("00wall").get("state") != "dropped": failures.append("Blocked pickup must preserve ground ownership.")
	session._battlefield = original_battlefield
	var clock_before := session.simulation.clock.get_elapsed_us()
	var resources_before := player.resources.duplicate(true)
	var hpc_before: Variant = player.current_hpc
	player.position_microfeet = Vector2i(40_000_000, 12_000_000)
	var batch := session.collect_all_ground_loot("36f:batch")
	if not batch.get("success", false) or batch.get("collected_count") != 199: failures.append("COLLECT ALL must collect remaining stacked/distant/wall-separated loot.")
	var quantity_after_batch := int(player.inventory_quantities.get("prime_v3_gold", 0))
	if quantity_after_batch != before + 1006: failures.append("Batch must preserve exact original quantities.")
	var digest_after_batch := SyncStateDigest.compute(session.get_state_snapshot())
	if session.collect_all_ground_loot("36f:batch").get("reason") != "duplicate_request": failures.append("Replayed batch request must reject.")
	if SyncStateDigest.compute(session.get_state_snapshot()) != digest_after_batch: failures.append("Replayed batch must mutate no state/history.")
	if session.simulation.clock.get_elapsed_us() != clock_before or player.resources != resources_before or player.current_hpc != hpc_before: failures.append("Batch must not advance time or restore resources.")
	var xp_before: Variant = session.get_reward_state().get("earned_xp")
	if not session.request_next_wave().get("success", false): failures.append("NEXT WAVE must remain usable.")
	if session.get_reward_state().get("earned_xp") != xp_before or int(player.inventory_quantities.get("prime_v3_gold", 0)) != quantity_after_batch: failures.append("XP and collected inventory must persist through NEXT WAVE.")
	controller._reset_encounter()
	if int(session.get_actor_state(&"player").inventory_quantities.get("prime_v3_gold", 0)) != 0: failures.append("RESET must clear temporary clicked loot.")
	tree.root.remove_child(scene)
	scene.free()
	_profile_encounters(tree)
	var first := _batch_replay(361)
	var second := _batch_replay(361)
	if first != second: failures.append("Batch snapshots and full history must replay deterministically.")
	return failures


func _batch_replay(seed_value: int) -> Dictionary:
	var harness := TwoClientSyncHarness.new(seed_value)
	var simulation := harness.authority.simulation
	simulation.register_actor(PrimeV3VerticalSliceFixture.make_player_actor(PrimeV3VerticalSliceFixture.PLAYER_CHARACTER_GUARD))
	simulation.set_arena_wave_state_snapshot({"state": "between_wave_downtime"})
	simulation.set_world_item_landing_resolver(func(_item: Dictionary, _position: Vector2i) -> bool: return true)
	simulation.create_ground_loot_item("isolated:batch", {"definition_id": "prime_v3_gold", "quantity": 6}, Vector2i(40_000_000, 12_000_000), &"", "isolated:origin", {"source_kind": "test"})
	var result := simulation.collect_all_downtime_loot(&"player", "isolated:request")
	assert(result.get("success", false))
	var snapshot := simulation.get_state_snapshot()
	harness.deliver_in_order(harness.authority.publish_current_events())
	assert(harness.compare_clients().get("success", false))
	assert(harness.client_a.get_state_snapshot() == snapshot)
	return snapshot


func _profile_encounters(tree: SceneTree) -> void:
	for character: StringName in [&"uncommon_guard", &"vaelis_thorn"]:
		for wave in [1, 3, 4]:
			var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
			tree.root.add_child(scene)
			var controller := scene.get_node("CombatController") as ArenaCombatController
			var selected := controller.select_player_character_for_testing(character)
			if not selected.get("success", false):
				print("METRIC Task36F profile skipped invalid character=", character)
				tree.root.remove_child(scene)
				scene.free()
				continue
			controller.select_test_wave_for_testing(wave)
			controller.press_encounter_control_for_testing()
			var session := controller.get_combat_session_for_testing()
			var initial_events := session.get_resolved_event_count()
			var memory_before := OS.get_static_memory_usage()
			var simulation_us := 0
			var events_us := 0
			var presentation_us := 0
			for tick in range(40):
				var start := Time.get_ticks_usec()
				session.advance_by(50_000)
				simulation_us += Time.get_ticks_usec() - start
				start = Time.get_ticks_usec()
				controller._process_new_events()
				events_us += Time.get_ticks_usec() - start
				start = Time.get_ticks_usec()
				controller.update_presentation_for_testing()
				presentation_us += Time.get_ticks_usec() - start
			var start := Time.get_ticks_usec()
			controller.get_transcript_text_for_testing()
			var transcript_us := Time.get_ticks_usec() - start
			var builds_before: int = controller.get_event_consumption_metrics_for_testing().get("transcript_build_count", 0)
			start = Time.get_ticks_usec()
			for index in range(20): controller.get_transcript_text_for_testing()
			var cached_log_us := Time.get_ticks_usec() - start
			start = Time.get_ticks_usec()
			for index in range(20):
				session.get_reward_state()
				session.get_player_inventory_entries()
			var inventory_copy_us := Time.get_ticks_usec() - start
			print("METRIC Task36F char=%s wave=%s cached_log20_us=%s inventory_reward20_us=%s additional_log_builds=%s" % [character, wave, cached_log_us, inventory_copy_us, int(controller.get_event_consumption_metrics_for_testing().get("transcript_build_count", 0)) - builds_before])
			for actor_id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(actor_id)).current_hpc = 0
			session.advance_by(1)
			controller._session.configure_reward_mode("normal")
			controller.update_presentation_for_testing()
			start = Time.get_ticks_usec()
			for tick in range(100): controller.update_presentation_for_testing()
			print("METRIC Task36F char=%s wave=%s sim2s_us=%s presenter_us=%s presentation40_us=%s events=%s transcript_us=%s downtime100_us=%s static_memory_delta=%s rebuilds=%s" % [character, wave, simulation_us, events_us, presentation_us, session.get_resolved_event_count()-initial_events, transcript_us, Time.get_ticks_usec()-start, OS.get_static_memory_usage()-memory_before, session.get_goblin_path_rebuild_counts_for_testing()])
			tree.root.remove_child(scene)
			scene.free()
