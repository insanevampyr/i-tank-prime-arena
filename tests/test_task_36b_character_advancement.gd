class_name Task36BCharacterAdvancementTests
extends RefCounted

const Advancement = preload("res://scripts/rewards/prime_v3_advancement_catalog.gd")
const Ledger = preload("res://scripts/rewards/arena_reward_ledger.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_printed_costs_and_blocked_categories()
	_test_atomic_sr_purchase_and_state_preservation()
	_test_downtime_reset_and_test_mode_boundaries()
	_test_snapshot_replay_and_two_client_convergence()
	_test_minimal_downtime_interface()
	return _failures


func _test_printed_costs_and_blocked_categories() -> void:
	_expect_equal(Advancement.attribute_cost(1), 2_000, "Current values 1-5 must cost 2,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(6), 3_000, "Current values 6-10 must cost 3,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(11), 5_000, "Current values 11-15 must cost 5,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(16), 7_000, "Current values 16-20 must cost 7,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(21), 8_000, "Current values 21-30 must cost 8,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(31), 10_000, "Current values 31+ must cost 10,000 EXPC.")
	_expect_equal(Advancement.attribute_cost(0), null, "The printed chart does not define a zero-to-one cost.")
	_expect_equal(Advancement.field_level_cost(&"hsf", 1), 500, "HSF level one must retain the printed cost.")
	_expect_equal(Advancement.field_level_cost(&"osf", 13), 39_000, "OSF level thirteen must retain the printed cost.")
	var actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	var options := Advancement.build_actor_purchase_options(actor)
	var sr := _find_option(options, "special_resistance", "sr")
	_expect_true(sr.get("available", false), "Vaelis SR 1 must be the one fully source-supported purchase category.")
	_expect_equal(sr.get("cost"), 2_000, "Vaelis SR 1 to 2 must cost 2,000 EXPC.")
	var tb := _find_option(options, "talent_bonus", "tb")
	_expect_equal(tb.get("blocked_reason"), "purchase_cost_unresolved", "Vaelis TB 0 must fail closed because p. 102 begins at current value 1.")
	var dex := _find_option(options, "attribute", "dex")
	_expect_equal(dex.get("blocked_reason"), "dex_increase_requires_authoritative_dt_dp_allocation_choice", "DEX must remain blocked without a DT/DP allocation choice.")
	var skill := _find_option(options, "skill", "verified_skill")
	_expect_equal(skill.get("blocked_reason"), "skills_use_s_number_investments_no_verified_expc_purchase_rule", "Skills must not fabricate an EXPC price from S-number rules.")
	var osf := _find_option(options, "osf", "verified_osf")
	_expect_true(String(osf.get("blocked_reason", "")).contains("ss_check"), "OSF must expose its unresolved SS/training transaction gate.")


func _test_atomic_sr_purchase_and_state_preservation() -> void:
	var fixture := _make_rewarded_vaelis_simulation(36_200)
	var simulation: CombatSimulation = fixture["simulation"]
	var ledger: ArenaRewardLedger = fixture["ledger"]
	var player := simulation.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 5
	player.resources["mana"] = 7
	player.conditions.append("prone")
	player.inventory_quantities["task36b_kept_item"] = 2
	var equipment_before := player.equipment_refs.duplicate()
	var before_rng := simulation.random.get_draw_count()
	var purchase := ledger.purchase_advancement(simulation, "advance:sr:1", &"special_resistance", &"sr")
	_expect_true(purchase.get("success", false), "A valid SR purchase must execute atomically.")
	_expect_equal(simulation.get_actor_definition(Fixture.PLAYER_ID).get_base_combat_stat("sr"), 2, "The authoritative player definition must receive purchased SR.")
	_expect_equal(ledger.spent_xp, 2_000, "A successful SR purchase must deduct exactly its printed cost.")
	_expect_equal(ledger.earned_xp, 2_000, "EXPM/earned XP must not be reduced by spending EXPC.")
	_expect_equal(player.current_hpc, 5, "Advancement must not heal sustained HPC damage.")
	_expect_equal(player.resources.get("mana"), 7, "Advancement must not refill spent Mana.")
	_expect_true(player.conditions.has("prone"), "Advancement must preserve conditions.")
	_expect_equal(player.equipment_refs, equipment_before, "Advancement must preserve equipped items.")
	_expect_equal(player.inventory_quantities.get("task36b_kept_item"), 2, "Advancement must preserve inventory.")
	_expect_equal(simulation.random.get_draw_count(), before_rng, "A deterministic SR purchase must consume no RNG.")
	_expect_true(not String(purchase.get("purchase", {}).get("event_id", "")).is_empty(), "A successful purchase must append a stable authoritative event identifier.")
	var purchase_event_count := 0
	for event: CombatEvent in simulation.get_resolved_events():
		if event.event_type == &"reward_advancement_purchased":
			purchase_event_count += 1
	_expect_equal(purchase_event_count, 1, "A successful purchase must append exactly one ordered advancement event.")
	var digest_after := Digest.compute(simulation.get_state_snapshot())
	var duplicate := ledger.purchase_advancement(simulation, "advance:sr:1", &"special_resistance", &"sr")
	_expect_equal(duplicate.get("reason"), "duplicate_advancement_request", "A delivered purchase request must execute exactly once.")
	_expect_equal(Digest.compute(simulation.get_state_snapshot()), digest_after, "Duplicate delivery must not mutate authoritative state.")
	var insufficient := ledger.purchase_advancement(simulation, "advance:sr:2", &"special_resistance", &"sr")
	_expect_equal(insufficient.get("reason"), "insufficient_xp", "A second purchase without sufficient EXPC must fail without spending.")
	_expect_equal(ledger.purchase_records.size(), 1, "Purchase history must contain exactly one immutable successful transaction.")
	var invalid := ledger.purchase_advancement(simulation, "advance:fake", &"attribute", &"fake")
	_expect_equal(invalid.get("reason"), "invalid_advancement_target", "Unknown advancement targets must fail closed.")
	_expect_equal(ledger.spent_xp, 2_000, "Rejected purchases must not change spent XP.")


func _test_downtime_reset_and_test_mode_boundaries() -> void:
	var session := _make_wave_four_vaelis_session(7, Ledger.MODE_NORMAL)
	_expect_equal(session.get_targetable_enemy_ids().size(), 4, "Seed 7 must provide the four-Gargoyle XP fixture.")
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 6
	player.resources["mana"] = 8
	for actor_id: String in session.get_targetable_enemy_ids():
		var state := session.get_actor_state(StringName(actor_id))
		state.current_hpc = 0
		session._reward_ledger.process_defeat(session.simulation, StringName(actor_id), "task36b:defeat:%s" % actor_id)
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Advancement must be available only after genuine wave victory enters downtime.")
	var result := session.request_character_advancement(&"special_resistance", &"sr", "task36b:session:sr")
	_expect_true(result.get("success", false), "A NORMAL-mode downtime request must purchase verified SR.")
	_expect_equal(player.current_hpc, 6, "Downtime advancement must preserve sustained damage.")
	_expect_equal(player.resources.get("mana"), 8, "Downtime advancement must preserve spent resources.")
	_expect_true(session.reset_encounter(false).get("success", false), "RESET must reconstruct the temporary run fixture.")
	_expect_true(session.configure_reward_mode(Ledger.MODE_NORMAL).get("success", false), "The reset fixture must reconfigure NORMAL rewards explicitly.")
	_expect_equal(session.simulation.get_actor_definition(Fixture.PLAYER_ID).get_base_combat_stat("sr"), 1, "RESET must clear temporary advancement until persistence is implemented.")
	_expect_equal(session.get_reward_state().get("spent_xp"), 0, "RESET must clear temporary purchase accounting.")

	var test_session := _make_wave_four_vaelis_session(7, Ledger.MODE_TEST)
	for actor_id: String in test_session.get_targetable_enemy_ids():
		test_session.get_actor_state(StringName(actor_id)).current_hpc = 0
	test_session.advance_by(1)
	var test_purchase := test_session.request_character_advancement(&"special_resistance", &"sr", "task36b:test:sr")
	_expect_equal(test_purchase.get("reason"), "test_mode_advancement_prohibited", "TEST MODE must never grant temporary or permanent advancement.")
	_expect_equal(test_session.simulation.get_actor_definition(Fixture.PLAYER_ID).get_base_combat_stat("sr"), 1, "TEST MODE rejection must leave SR unchanged.")


func _test_snapshot_replay_and_two_client_convergence() -> void:
	var first := _make_rewarded_vaelis_simulation(36_201)
	var second := _make_rewarded_vaelis_simulation(36_201)
	for fixture: Dictionary in [first, second]:
		var ledger: ArenaRewardLedger = fixture["ledger"]
		var simulation: CombatSimulation = fixture["simulation"]
		_expect_true(ledger.purchase_advancement(simulation, "replay:sr", &"special_resistance", &"sr").get("success", false), "Replay fixture purchase must succeed.")
	_expect_equal(first["simulation"].get_state_snapshot(), second["simulation"].get_state_snapshot(), "Same-seed rewards and purchases must replay identically.")
	_expect_equal(first["simulation"].get_state_snapshot().get("schema_version"), 12, "Advancement must preserve schema-12 compatibility.")

	var harness := TwoClientSyncHarness.new(36_202)
	var authority_simulation := harness.authority.simulation
	var player_actor := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	authority_simulation.register_actor(player_actor)
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_NORMAL, Fixture.PLAYER_ID, player_actor.level)
	_award_four_gargoyles(authority_simulation, ledger)
	_expect_true(ledger.purchase_advancement(authority_simulation, "sync:sr", &"special_resistance", &"sr").get("success", false), "Authoritative synchronization purchase must succeed.")
	var snapshot := authority_simulation.get_state_snapshot()
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge after advancement.")
	_expect_equal(harness.client_a.get_state_snapshot(), snapshot, "The complete advancement definition, event and ledger snapshot must replicate.")


func _test_minimal_downtime_interface() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 36B advancement-interface coverage.")
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	_expect_true(controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).get("success", false), "The advancement UI fixture must select Vaelis before START.")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()
	_expect_true(controller.is_rewards_panel_visible_for_testing(), "NORMAL downtime must expose the combined rewards and advancement panel.")
	_expect_true(controller.get_rewards_panel_text_for_testing().contains("CHARACTER ADVANCEMENT"), "The downtime panel must identify the advancement interface.")
	_expect_true(controller.get_advancement_option_count_for_testing() >= 1, "The interface must expose Vaelis's supported SR purchase without unresolved placeholder categories.")
	_expect_true(controller.get_advancement_purchase_button_disabled_for_testing(), "A selected unavailable or unaffordable purchase must disable confirmation.")
	tree.root.remove_child(scene)
	scene.free()


func _make_rewarded_vaelis_simulation(seed: int) -> Dictionary:
	var simulation := CombatSimulation.new(seed)
	var player := Fixture.make_player_actor(Fixture.PLAYER_CHARACTER_VAELIS)
	simulation.register_actor(player)
	simulation.set_world_item_landing_resolver(func(_item: Dictionary, _position: Vector2i) -> bool: return true)
	var ledger := Ledger.new()
	ledger.configure(Ledger.MODE_NORMAL, Fixture.PLAYER_ID, player.level)
	_award_four_gargoyles(simulation, ledger)
	return {"simulation": simulation, "ledger": ledger}


func _award_four_gargoyles(simulation: CombatSimulation, ledger: ArenaRewardLedger) -> void:
	ledger.begin_wave("wave_4")
	for index in range(4):
		var actor_id := StringName("wave_4_mini_gargoyle_swarmer_%02d" % (index + 1))
		var actor := _make_reward_actor(actor_id)
		simulation.register_actor(actor)
		simulation.get_actor_state(actor_id).current_hpc = 0
		ledger.process_defeat(simulation, actor_id, "task36b:reward:%02d" % (index + 1))


func _make_wave_four_vaelis_session(seed: int, mode: String) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES, Fixture.PLAYER_CHARACTER_VAELIS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_four_gargoyles(Vector2i(20_000_000, 12_000_000), Vector2i(24_000_000, 12_000_000), false)
	session.configure_reward_mode(mode)
	session.start_encounter()
	return session


func _make_reward_actor(actor_id: StringName) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id, &"task_36b_reward_fixture", String(actor_id),
		{"str": 10, "end": 10, "spd": 10, "dex": 10, "wis": 10, "int": 10, "wit": 10, "man": 10, "luk": 10, "app": 10},
		{"hpm": 10, "acc": 10, "at": 1, "init": 1, "mr": 10, "nal": 0, "dt": 0, "dp": 0, "physical_soak": 0},
		{}, PackedStringArray(), {}, {}, PackedStringArray(), &"small", {}, {}, 11
	)


func _find_option(options: Array[Dictionary], purchase_kind: String, target_id: String) -> Dictionary:
	for option: Dictionary in options:
		if String(option.get("purchase_kind", "")) == purchase_kind \
		and String(option.get("target_id", "")) == target_id:
			return option
	return {}


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
