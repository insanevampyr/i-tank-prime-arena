class_name Task36ARewardsAndLootTests
extends RefCounted

const Ledger = preload("res://scripts/rewards/arena_reward_ledger.gd")
const RewardCatalog = preload("res://scripts/rewards/prime_v3_reward_catalog.gd")
const DropResolver = preload("res://scripts/rewards/prime_v3_random_drop_resolver.gd")
const Advancement = preload("res://scripts/rewards/prime_v3_advancement_catalog.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const BossFixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_verified_creature_xp_and_exactly_once()
	_test_test_mode_suppresses_rewards_and_rng()
	_test_normal_session_processes_actual_defeat_event()
	_test_official_drop_charts_and_nested_rolls()
	_test_seeded_drop_repeatability_and_variation()
	_test_book_rarity_reroll_and_unfinished_boundaries()
	_test_ground_loot_collection_and_possession_separation()
	_test_downtime_collection_and_wave_continuity()
	_test_existing_boss_spear_is_not_duplicated()
	_test_normal_and_test_mode_ui_boundaries()
	_test_reward_session_callbacks_do_not_retain_session()
	_test_advancement_cost_foundation_does_not_spend()
	_test_snapshot_and_two_client_convergence()
	return _failures


func _test_reward_session_callbacks_do_not_retain_session() -> void:
	var session: ArenaCombatSession = ArenaCombatSession.new(36_009, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	_expect_true(
		session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false).get("success", false),
		"Reward ownership cleanup fixture must initialize."
	)
	_expect_true(session.configure_reward_mode(Ledger.MODE_NORMAL).get("success", false), "Reward ownership cleanup fixture must bind callbacks.")
	var session_reference: WeakRef = weakref(session)
	session = null
	_expect_true(session_reference.get_ref() == null, "Simulation callbacks must not retain their owning Arena session.")


func _test_verified_creature_xp_and_exactly_once() -> void:
	var simulation := _make_simulation(36_001)
	var ledger := Ledger.new()
	_expect_true(ledger.configure(Ledger.MODE_NORMAL, &"player", 11).get("success", false), "Normal reward mode must configure.")
	ledger.begin_wave("wave_1")
	var fixtures := [
		["wave_1", "wave_1_common_goblin_01", 10],
		["wave_2", "wave_2_common_spadoodle_01", 30],
		["wave_3", "wave_3_common_skelly_01", 50],
		["wave_3", "wave_3_hades_combat_follower_01", 100],
		["wave_4", "wave_4_mini_gargoyle_swarmer_01", 500],
	]
	for fixture: Array in fixtures:
		ledger.begin_wave(fixture[0])
		var actor_id := StringName(fixture[1])
		var equipment := PackedStringArray(["prime_v3_hades_follower_short_sword"]) if String(actor_id).contains("hades") else PackedStringArray()
		_expect_true(simulation.register_actor(_make_actor(actor_id, equipment)).get("success", false), "Reward test creature must register.")
		simulation.get_actor_state(actor_id).current_hpc = 0
		var result := ledger.process_defeat(simulation, actor_id, "defeat:%s" % String(actor_id))
		_expect_true(result.get("success", false), "%s reward must resolve." % actor_id)
		_expect_equal(result.get("xp"), fixture[2], "%s must award its approved Arena XP." % actor_id)
		_expect_equal(
			ledger.process_defeat(simulation, actor_id, "duplicate:%s" % String(actor_id)).get("reason"),
			"reward_already_processed",
			"Each defeated actor must produce exactly one reward award."
		)
	_expect_equal(ledger.earned_xp, 690, "The five approved Arena entries must total 690 XP when defeated once each.")
	_expect_equal(ledger.spent_xp, 0, "Awarding XP must never spend it or auto-level the player.")
	_expect_equal(ledger.to_dictionary().get("unspent_xp"), 690, "Unspent XP must equal earned minus spent XP.")
	ledger.begin_wave("wave_5")
	var boss := _make_actor(&"wave_5_rare_human_warrior_1")
	_expect_true(simulation.register_actor(boss).get("success", false), "The isolated boss reward gate actor must register.")
	simulation.get_actor_state(boss.actor_id).current_hpc = 0
	var blocked := ledger.process_defeat(simulation, boss.actor_id, "defeat:boss")
	_expect_true(blocked.get("blocked", false), "The protected boss reward must fail closed instead of fabricating XP or drops.")
	_expect_equal(ledger.earned_xp, 690, "A blocked boss source must not change XP.")
	_expect_equal(ledger.current_wave_earned_xp, 0, "Wave 5 must show no fabricated current-wave XP while its source value is blocked.")


func _test_test_mode_suppresses_rewards_and_rng() -> void:
	var simulation := _make_simulation(36_002)
	var actor := _make_actor(&"wave_1_common_goblin_01")
	simulation.register_actor(actor)
	simulation.get_actor_state(actor.actor_id).current_hpc = 0
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_TEST, &"player", 11)
	var draws_before := simulation.random.get_draw_count()
	var result := ledger.process_defeat(simulation, actor.actor_id, "test_mode_defeat")
	_expect_true(result.get("suppressed", false), "Developer TEST MODE must explicitly suppress permanent rewards.")
	_expect_equal(ledger.earned_xp, 0, "TEST MODE must not award permanent XP.")
	_expect_equal(simulation.random.get_draw_count(), draws_before, "TEST MODE suppression must not consume reward RNG.")
	_expect_equal(simulation.get_world_items_snapshot().size(), 0, "TEST MODE must not create permanent treasure.")


func _test_normal_session_processes_actual_defeat_event() -> void:
	var session := ArenaCombatSession.new(36_005, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	_expect_true(
		session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false).get("success", false),
		"Normal reward integration encounter must initialize."
	)
	_expect_true(session.configure_reward_mode(Ledger.MODE_NORMAL).get("success", false), "Normal mode must attach to the initialized encounter.")
	_expect_true(session.start_encounter().get("success", false), "Normal reward integration encounter must start.")
	var target_id := StringName(session.get_targetable_enemy_ids()[0])
	session.select_target(target_id)
	session.simulation.apply_authoritative_position(target_id, Vector2i(22_000_000, 12_000_000), 180_000)
	for attempt in range(20):
		if int(session.get_actor_state(target_id).current_hpc) <= 0:
			break
		var request := session.request_player_attack("task36a_%d" % attempt)
		if request.get("success", false):
			session.advance_by(2_500_000)
		else:
			session.advance_by(100_000)
	_expect_true(int(session.get_actor_state(target_id).current_hpc) <= 0, "Focused combat must genuinely defeat one Common Goblin.")
	_expect_equal(session.get_reward_state().get("earned_xp"), 10, "An actual physical-damage defeat event must award exactly 10 Arena Goblin XP.")
	var award_events := 0
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == "reward_xp_awarded" and event.source_actor_id == target_id:
			award_events += 1
	_expect_equal(award_events, 1, "The real session event pipeline must emit one XP award for the defeated Goblin.")


func _test_official_drop_charts_and_nested_rolls() -> void:
	var no_drop := _resolve_scripted("C", [3], 11)
	_expect_equal(no_drop.get("status"), "no_drop", "C roll 3 must preserve the official X result.")
	var c_gold := _resolve_scripted("C", [14, 1, 20], 11)
	_expect_equal(c_gold.get("items", [])[0].get("quantity"), 210, "C roll 14 must resolve official 2d20 x10 gold.")
	_expect_equal(c_gold.get("rolls", []).size(), 3, "Nested C gold dice must retain each authoritative roll.")
	var armor := _resolve_scripted("A", [6, 1, 10, 4], 11)
	var armor_item: Dictionary = armor.get("items", [])[0]
	_expect_equal(armor_item.get("item_kind"), "armor", "A random-item result must continue into the armor subchart.")
	_expect_equal(armor_item.get("armor_chart_die"), "d10", "The controlling Arena correction must use d10 for the ten-entry armor chart.")
	_expect_equal(armor_item.get("enchantment_level"), 4, "Armor enchantment must preserve the official d4 subroll.")
	var potion := _resolve_scripted("PS", [1, 6], 11)
	_expect_equal(potion.get("items", [])[0].get("display_name"), "Healing Potion", "PS potion results must resolve the official potion chart.")
	var shield := _resolve_scripted("RI", [4, 7, 2], 11)
	_expect_equal(shield.get("items", [])[0].get("display_name"), "Small Shield", "RI must resolve Random Item then Shield subcharts.")
	var unsupported_dice := _resolve_scripted("DICE", [], 11)
	_expect_equal(unsupported_dice.get("reason"), "unsupported_drop_code", "No separate named Dice Drop procedure may be invented when the supplied V3 material defines no such drop code.")
	_expect_equal(unsupported_dice.get("rolls", []).size(), 0, "An unsupported Dice Drop must fail before consuming authoritative RNG.")


func _test_seeded_drop_repeatability_and_variation() -> void:
	var first := _resolve_seeded_creature_drop(36_100)
	var replay := _resolve_seeded_creature_drop(36_100)
	_expect_equal(replay, first, "Independent reward runs with the same seed must produce identical rolls, items and provenance.")
	var distinct_results := {}
	for seed_value in range(36_100, 36_116):
		distinct_results[JSON.stringify(_resolve_seeded_creature_drop(seed_value).get("drop_resolutions", []))] = true
	_expect_true(distinct_results.size() > 1, "Different seeds must produce more than one verified Gargoyle drop sequence across a bounded sample.")


func _test_book_rarity_reroll_and_unfinished_boundaries() -> void:
	var book := _resolve_scripted("BK", [1, 13, 1, 1, 6], 1)
	_expect_equal(book.get("status"), "resolved", "An ineligible book rarity must reroll until a legal rarity is obtained.")
	_expect_equal(book.get("items", [])[0].get("rarity"), "common", "Level 1 must reject Uncommon and accept Common book rarity.")
	_expect_equal(book.get("items", [])[0].get("field_level"), 6, "Book field level must use the official per-entry die.")
	var blocked_book := _resolve_scripted("BK", [1], -1)
	_expect_equal(blocked_book.get("reason"), "player_level_required_before_book_rarity_roll", "Unknown player level must block only Book completion without inventing eligibility.")
	_expect_equal(blocked_book.get("rolls", []).size(), 1, "A blocked Book must not consume unsupported rarity rolls.")
	var reincarnation := _resolve_scripted("PS", [2, 19], 11)
	_expect_equal(reincarnation.get("reason"), "reincarnation_scroll_chart_unfinished", "The unfinished Reincarnation chart must retain an explicit intermediate result.")


func _test_ground_loot_collection_and_possession_separation() -> void:
	var simulation := _make_simulation(36_003)
	var hades := _make_actor(&"wave_3_hades_combat_follower_01", PackedStringArray(["prime_v3_hades_follower_short_sword"]))
	simulation.register_actor(hades)
	var hades_state := simulation.get_actor_state(hades.actor_id)
	hades_state.hand_occupancy_authoritative = true
	hades_state.hand_occupancy["right"] = "prime_v3_hades_follower_short_sword"
	hades_state.position_microfeet = Vector2i(1_000_000, 0)
	hades_state.current_hpc = 0
	var possession: Dictionary = RewardCatalog.get_possessions("hades_combat_follower")[0]
	var transfer := simulation.transfer_defeated_actor_possession_to_ground(hades.actor_id, "loot:hades:sword", possession, "defeat:hades")
	_expect_true(transfer.get("success", false), "A source-verified carried Short Sword must transfer to an authoritative ground item.")
	_expect_true(not hades_state.equipment_refs.has("prime_v3_hades_follower_short_sword"), "Transferred possessions must no longer remain equipped on the defeated creature.")
	var collect := simulation.collect_ground_loot_item(&"player", "loot:hades:sword", "collect:1")
	_expect_true(collect.get("success", false), "A living player inside verified one-foot pickup reach must collect ground loot.")
	_expect_equal(simulation.get_actor_state(&"player").inventory_quantities.get("prime_v3_hades_follower_short_sword"), 1, "Collected equipment must persist in authoritative player inventory.")
	_expect_equal(simulation.collect_ground_loot_item(&"player", "loot:hades:sword", "collect:2").get("reason"), "ground_loot_not_collectible", "Collected loot must not duplicate.")
	var item := simulation.get_world_item("loot:hades:sword")
	_expect_equal(item.get("collection_status"), "collected", "World-item history must retain collection status and provenance.")


func _test_downtime_collection_and_wave_continuity() -> void:
	var session := ArenaCombatSession.new(36_006, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	_expect_true(session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false).get("success", false), "Downtime loot fixture must initialize.")
	_expect_true(session.configure_reward_mode(Ledger.MODE_NORMAL).get("success", false), "Downtime loot fixture must use NORMAL rewards.")
	_expect_true(session.start_encounter().get("success", false), "Downtime loot fixture must start.")
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	var near_definition := {"definition_id": "task36a_near_item", "display_name": "Near Item", "item_kind": "possession", "quantity": 1}
	var far_definition := {"definition_id": "task36a_far_item", "display_name": "Far Item", "item_kind": "possession", "quantity": 1}
	_expect_true(session.simulation.create_ground_loot_item("loot:near", near_definition, player.position_microfeet, &"", "task36a:near").get("success", false), "A legal battlefield item must be created at the player's position.")
	_expect_true(session.simulation.create_ground_loot_item("loot:far", far_definition, Vector2i(31_500_000, 12_000_000), &"", "task36a:far").get("success", false), "A legal uncollected item must be created beyond the center wall.")
	_expect_equal(session.collect_ground_loot("loot:near").get("reason"), "loot_collection_requires_between_wave_downtime", "Active combat must not permit the downtime collection action.")
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Defeating every Wave 1 actor must enter downtime before collection.")
	_expect_true(session.collect_ground_loot("loot:near").get("success", false), "Loot at legal pickup contact must be collected during downtime.")
	_expect_equal(player.inventory_quantities.get("task36a_near_item"), 1, "Collected loot must enter the authoritative player inventory exactly once.")
	_expect_equal(session.collect_ground_loot("loot:near").get("reason"), "ground_loot_not_collectible", "A collected world item must reject duplicate collection.")
	_expect_equal(session.collect_ground_loot("loot:far").get("reason"), "world_item_out_of_pickup_reach", "Loot across the center wall must not be remotely collected.")
	_expect_true(session.request_next_wave().get("success", false), "One explicit NEXT WAVE request must advance the normal run.")
	_expect_equal(session.get_actor_state(Fixture.PLAYER_ID).inventory_quantities.get("task36a_near_item"), 1, "Collected inventory must persist into the next wave.")
	var far_item := session.simulation.get_world_item("loot:far")
	_expect_equal(far_item.get("collection_status"), "uncollected", "Uncollected battlefield loot must survive a wave transition.")
	_expect_equal(session.get_reward_state().get("current_wave_id"), "wave_2", "Wave advancement must reset the current-wave reward window without losing cumulative state.")
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must reconstruct the selected fixture without carrying encounter rewards.")
	_expect_true(session.configure_reward_mode(Ledger.MODE_NORMAL).get("success", false), "RESET reward state must be explicitly reconfigured for NORMAL mode.")
	_expect_equal(session.get_reward_state().get("earned_xp"), 0, "RESET must clear temporary run reward accounting rather than duplicate prior awards.")
	_expect_equal(session.get_ground_loot().size(), 0, "RESET must remove prior encounter world items from the reconstructed fixture.")

	var defeat_session := ArenaCombatSession.new(36_008, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	defeat_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	defeat_session.set_opponent_behavior_enabled(false)
	defeat_session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false)
	defeat_session.configure_reward_mode(Ledger.MODE_NORMAL)
	defeat_session.start_encounter()
	defeat_session.get_actor_state(Fixture.PLAYER_ID).current_hpc = 0
	defeat_session.advance_by(1)
	_expect_equal(defeat_session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_DEFEAT, "Player defeat must terminate the active run before any unsupported reward progression.")
	_expect_equal(defeat_session.get_reward_state().get("earned_xp"), 0, "An interrupted run with no qualifying enemy defeat must award no XP.")


func _test_existing_boss_spear_is_not_duplicated() -> void:
	var simulation := _make_simulation(36_007)
	var boss_result := BossFixture.instantiate_foundation_actor()
	var boss: CombatActorDefinition = boss_result.get("actor")
	_expect_true(boss != null and simulation.register_actor(boss).get("success", false), "The accepted boss foundation must register for possession de-duplication coverage.")
	if boss == null:
		return
	var boss_state := simulation.get_actor_state(boss.actor_id)
	boss_state.position_microfeet = Vector2i(2_000_000, 0)
	boss_state.equipment_refs.erase(String(BossFixture.WEAPON_REF))
	for hand: String in ["left", "right"]:
		if String(boss_state.hand_occupancy.get(hand, "")) == String(BossFixture.WEAPON_REF):
			boss_state.hand_occupancy[hand] = ""
	var spear_definition: Dictionary = RewardCatalog.get_possessions("rare_human_warrior_boss")[0]
	_expect_true(simulation.create_ground_loot_item("boss:existing_spear", spear_definition, boss_state.position_microfeet, boss.actor_id, "boss:throw").get("success", false), "The already released spear must exist once in authoritative world state.")
	boss_state.current_hpc = 0
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_NORMAL, &"player", 11)
	var result := ledger.process_defeat(simulation, boss.actor_id, "boss:defeat")
	_expect_true(result.get("blocked", false), "Unknown protected boss XP/drop data must remain blocked while verified possessions are processed.")
	var spear_count := 0
	var potion_quantity := 0
	for item: Dictionary in simulation.get_world_items_snapshot():
		if String(item.get("equipment_ref", "")) == String(BossFixture.WEAPON_REF):
			spear_count += 1
		if String(item.get("item_definition", {}).get("definition_id", "")) == "health_potion":
			potion_quantity += int(item.get("quantity", 0))
	_expect_equal(spear_count, 1, "Boss defeat must reclassify the existing dropped spear instead of duplicating it.")
	_expect_equal(potion_quantity, 2, "Remaining source-backed boss consumables must transfer with their authoritative quantity rather than one fabricated item.")
	_expect_equal(boss_state.inventory_quantities.get("health_potion"), 0, "Transferred consumables must no longer remain in the defeated actor inventory.")


func _test_normal_and_test_mode_ui_boundaries() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 36A reward-interface coverage.")
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	var session := controller.get_combat_session_for_testing()
	_expect_equal(session.get_reward_state().get("mode"), Ledger.MODE_NORMAL, "The default NORMAL Wave 1 launcher must enable persistent within-run rewards.")
	controller.press_encounter_control_for_testing()
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()
	_expect_true(controller.is_rewards_panel_visible_for_testing(), "Victory downtime automatically opens rewards once (Task 36I-Fix2).")
	_expect_true(controller.get_rewards_panel_text_for_testing().contains("WAVE REWARDS"), "The downtime interface must expose wave and cumulative reward accounting.")
	tree.root.remove_child(scene)
	scene.free()
	var test_scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(test_scene)
	var test_controller := test_scene.get_node("CombatController") as ArenaCombatController
	var selected := test_controller.select_test_wave_for_testing(1)
	_expect_true(selected.get("success", false), "Developer TEST MODE Wave 1 must remain selectable after RESET.")
	_expect_equal(test_controller.get_combat_session_for_testing().get_reward_state().get("mode"), Ledger.MODE_TEST, "Developer TEST MODE must be isolated from permanent rewards.")
	tree.root.remove_child(test_scene)
	test_scene.free()


func _test_advancement_cost_foundation_does_not_spend() -> void:
	_expect_equal(Advancement.attribute_cost(5), 2_000, "Attribute value 5 must use the V3 1-5 cost bracket.")
	_expect_equal(Advancement.attribute_cost(6), 3_000, "Attribute value 6 must use the V3 6-10 cost bracket.")
	_expect_equal(Advancement.attribute_cost(31), 10_000, "Attribute value 31+ must use the V3 terminal cost bracket.")
	_expect_equal(Advancement.field_level_cost(&"hsf", 14), 28_000, "HSF level 14+ must cost target level x2000.")
	_expect_equal(Advancement.field_level_cost(&"osf", 14), 42_000, "OSF level 14+ must cost target level x3000.")
	var preview := Advancement.make_purchase_preview(&"attribute", &"str", 10, 11)
	_expect_equal(preview.get("cost"), 3_000, "Purchase previews must expose exact verified cost without spending XP.")
	_expect_true(not preview.get("available", true), "Task 36A must not activate incomplete advancement purchases or automatic leveling.")


func _test_snapshot_and_two_client_convergence() -> void:
	var harness := TwoClientSyncHarness.new(36_004)
	var simulation := harness.authority.simulation
	_configure_simulation(simulation)
	var actor := _make_actor(&"wave_1_common_goblin_01")
	simulation.register_actor(actor)
	simulation.get_actor_state(actor.actor_id).current_hpc = 0
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_NORMAL, &"player", 11)
	ledger.begin_wave("wave_1")
	_expect_true(ledger.process_defeat(simulation, actor.actor_id, "sync:defeat").get("success", false), "Reward processing must complete before snapshot publication.")
	var snapshot := simulation.get_state_snapshot()
	_expect_equal(snapshot.get("schema_version"), 12, "Reward additions must preserve the existing schema-12 compatibility contract.")
	_expect_equal(snapshot.get("reward_state", {}).get("earned_xp"), 10, "Authoritative reward state must be included additively in snapshots.")
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge on reward events and state.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Reward state must preserve authoritative replay digest convergence.")
	_expect_equal(harness.client_a.get_state_snapshot(), snapshot, "An observing client must restore the complete additive schema-12 reward snapshot exactly.")


func _resolve_scripted(code: String, values: Array[int], player_level: int) -> Dictionary:
	var cursor := {"index": 0}
	var resolver := DropResolver.new(func(minimum: int, maximum: int) -> int:
		var index := int(cursor["index"])
		if index >= values.size():
			return minimum
		var value := values[index]
		cursor["index"] = index + 1
		return clampi(value, minimum, maximum)
	)
	return resolver.resolve(code, player_level)


func _resolve_seeded_creature_drop(seed_value: int) -> Dictionary:
	var simulation := _make_simulation(seed_value)
	var actor := _make_actor(&"wave_4_mini_gargoyle_swarmer_01")
	simulation.register_actor(actor)
	simulation.get_actor_state(actor.actor_id).current_hpc = 0
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_NORMAL, &"player", 11)
	ledger.begin_wave("wave_4")
	ledger.process_defeat(simulation, actor.actor_id, "seeded:defeat")
	return {
		"drop_resolutions": ledger.to_dictionary().get("drop_resolutions", []),
		"world_items": simulation.get_world_items_snapshot(),
		"rng_draw_count": simulation.random.get_draw_count(),
	}


func _make_simulation(seed: int) -> CombatSimulation:
	var simulation := CombatSimulation.new(seed)
	_configure_simulation(simulation)
	return simulation


func _configure_simulation(simulation: CombatSimulation) -> void:
	if simulation.get_actor_state(&"player") == null:
		simulation.register_actor(_make_actor(&"player"))
	simulation.get_actor_state(&"player").position_microfeet = Vector2i.ZERO
	simulation.set_world_item_landing_resolver(func(_item: Dictionary, _position: Vector2i) -> bool: return true)
	var simulation_reference: WeakRef = weakref(simulation)
	simulation.set_world_item_pickup_resolver(func(actor_id: StringName, item: Dictionary) -> bool:
		var active_simulation: CombatSimulation = simulation_reference.get_ref()
		var state: CombatActorState = null if active_simulation == null else active_simulation.get_actor_state(actor_id)
		return state != null and state.position_microfeet.distance_to(item.get("position_microfeet", Vector2i(99_000_000, 0))) <= 1_000_000.0
	)


func _make_actor(actor_id: StringName, equipment: PackedStringArray = PackedStringArray()) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id, &"task_36a_fixture", String(actor_id),
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 10, "acc": 10, "at": 1, "init": 1, "mr": 10, "nal": 0, "dt": 0, "dp": 0, "physical_soak": 0},
		{}, equipment, {}, {}, PackedStringArray(), &"medium", {}, {}, 11
	)


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
