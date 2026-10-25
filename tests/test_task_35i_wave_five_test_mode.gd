class_name Task35IWaveFiveTestModeTests
extends RefCounted

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Battlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const BossFixture = preload("res://scripts/creatures/rare_human_warrior_fixture.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const ENEMY_POSITION := Vector2i(23_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_all_five_waves_launch_directly()
	_test_test_mode_selector_and_fresh_reset()
	_test_wave_five_boss_foundation_and_ai()
	_test_live_boss_healing_and_combat_ability_selection()
	_test_live_throw_landing_retrieval_and_fallback_boundary()
	_test_wave_five_victory_and_player_defeat()
	_test_normal_next_wave_preserves_resources_and_reports_spawn_gate()
	_test_wave_one_frame_partition_snapshot_convergence()
	_test_replay_snapshot_and_two_client_convergence()
	return _failures


func _test_all_five_waves_launch_directly() -> void:
	for wave_number in range(1, 6):
		var session := _make_wave_session(35_900 + wave_number, wave_number, false)
		_expect_true(session != null, "TEST MODE Wave %d must initialize the real encounter fixture." % wave_number)
		if session == null:
			continue
		var wave_state := session.get_arena_wave_state()
		_expect_equal(wave_state.get("current_wave_id"), "wave_%d" % wave_number, "Direct Wave %d launch must initialize that authoritative wave." % wave_number)
		_expect_equal(wave_state.get("state"), "active_combat", "Direct Wave %d launch must activate its registered actors." % wave_number)
		var enemy_count := session.get_targetable_enemy_ids().size()
		match wave_number:
			1:
				_expect_true(enemy_count >= 2 and enemy_count <= 8, "Wave 1 direct launch must retain seeded 2d4 Goblins.")
			2:
				_expect_true(enemy_count >= 1 and enemy_count <= 3, "Wave 2 direct launch must retain seeded 1d3 Spadoodles.")
			3:
				_expect_true(enemy_count >= 2 and enemy_count <= 3, "Wave 3 direct launch must retain 1d2 Skellys plus one Hades follower.")
			4:
				_expect_true(enemy_count >= 1 and enemy_count <= 4, "Wave 4 direct launch must retain seeded 1d4 Gargoyles.")
			5:
				_expect_equal(enemy_count, 1, "Wave 5 direct launch must create exactly one Rare Human Warrior.")


func _test_test_mode_selector_and_fresh_reset() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 35I Test Mode UI coverage.")
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	_expect_equal(controller.get_test_mode_state_for_testing().get("enabled"), false, "Normal Arena startup must remain outside developer Test Mode.")
	_expect_equal(controller.get_combat_session_for_testing().get_arena_wave_state().get("current_wave_id"), "wave_1", "Normal Arena startup must begin at Wave 1.")
	for wave_number in range(1, 6):
		var selection := controller.select_test_wave_for_testing(wave_number)
		_expect_true(selection.get("success", false), "The in-scene TEST MODE selector must launch Wave %d." % wave_number)
		_expect_equal(controller.get_combat_session_for_testing().get_arena_wave_state().get("current_wave_id"), "wave_%d" % wave_number, "The selected TEST MODE wave must be authoritative, not presentation-only.")
	var vaelis := controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	_expect_true(vaelis.get("success", false), "TEST MODE must preserve character selection.")
	controller.select_test_wave_for_testing(5)
	var session := controller.get_combat_session_for_testing()
	var initial_player := session.get_actor_state(Fixture.PLAYER_ID).to_dictionary()
	controller.press_encounter_control_for_testing()
	session.get_actor_state(Fixture.PLAYER_ID).current_hpc = 1
	session.get_actor_state(Fixture.PLAYER_ID).resources["mana"] = 0
	controller.press_encounter_control_for_testing()
	var reset_player := controller.get_combat_session_for_testing().get_actor_state(Fixture.PLAYER_ID)
	_expect_equal(reset_player.current_hpc, initial_player.get("current_hpc"), "TEST MODE restart must restore fixture HPC from a fresh temporary session.")
	_expect_equal(reset_player.resources.get("mana"), initial_player.get("resources", {}).get("mana"), "TEST MODE restart must restore fixture Mana without duplicating inventory.")
	_expect_equal(controller.get_combat_session_for_testing().simulation.get_state_snapshot().get("world_items", []).size(), 0, "TEST MODE restart must clear prior temporary world items.")
	_expect_equal(controller.get_combat_session_for_testing().get_targetable_enemy_ids().size(), 1, "TEST MODE restart must not retain stale actors.")
	tree.root.remove_child(scene)
	scene.free()


func _test_wave_five_boss_foundation_and_ai() -> void:
	var session := _make_wave_session(35_910, 5, false)
	if session == null:
		return
	var boss := session.get_actor_state(BossFixture.ACTOR_ID)
	var definition := session.simulation.get_actor_definition(BossFixture.ACTOR_ID)
	_expect_equal(definition.get_combat_stat("hpm"), 200, "Wave 5 must load the official boss HPM 200 fixture.")
	_expect_equal(definition.get_combat_stat("mr"), 12, "Wave 5 must use effective MR 12.")
	_expect_equal(definition.get_combat_stat("dt"), 8, "Wave 5 must use effective DT 8 after armor penalties.")
	_expect_equal(definition.get_combat_stat("dp"), 2, "Wave 5 must use effective projectile Dodge 2 after armor penalties.")
	_expect_equal(definition.get_combat_stat("nal"), 1, "Wave 5 must keep racial NAL +1 separate from Scale TAL.")
	_expect_equal(boss.resources.get("mana"), 24, "Wave 5 boss must start with source Mana 24.")
	_expect_equal(boss.resources.get("ap"), 12, "Wave 5 boss must start with source AP 12.")
	_expect_equal(boss.inventory_quantities.get("health_potion"), 2, "Wave 5 boss must start with exactly two Health Potions.")
	_expect_true(boss.hand_occupancy.get("left") == String(BossFixture.WEAPON_REF) and boss.hand_occupancy.get("right") == String(BossFixture.WEAPON_REF), "Wave 5 must begin with the two-handed Boar Spear legally equipped.")
	_expect_true(session.start_encounter().get("success", false), "Wave 5 must start through the ordinary encounter control boundary.")
	_expect_true(session.get_opponent_behavior_status().begins_with("wave_five_boss_"), "The committed boss AI must execute in the live encounter loop.")
	_expect_true(_event_types(session).has("tactical_action_selected"), "Live Wave 5 AI must retain authoritative tactical-decision evidence.")
	_expect_true(session.get_opponent_behavior_status().contains("called_shot"), "At a legal full-health spear opportunity, live Wave 5 AI must select its verified Called Shot when eligible.")


func _test_live_boss_healing_and_combat_ability_selection() -> void:
	var healing := _make_wave_session(35_917, 5, false)
	if healing != null:
		var boss := healing.get_actor_state(BossFixture.ACTOR_ID)
		boss.current_hpc = 180
		var ap_before := int(boss.resources.get("ap", 0))
		var uses_before := boss.ability_daily_remaining.duplicate(true)
		_expect_true(healing.start_encounter().get("success", false), "The injured-boss live fixture must start.")
		_expect_true(healing.get_opponent_behavior_status().contains("rejuvenating_mist"), "A materially injured live boss must select verified Rejuvenating Mist when legal.")
		healing.advance_by(2_500_000)
		_expect_true(int(boss.current_hpc) > 180 and int(boss.current_hpc) <= 200, "Live Rejuvenating Mist must change authoritative boss HPC without exceeding HPM.")
		_expect_true(
			int(boss.resources.get("ap", 0)) < ap_before or boss.ability_daily_remaining != uses_before,
			"Live Combat Ability execution must spend its verified daily use before AP fallback."
		)

	var rage := Session.new(35_918, null, Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR, Fixture.PLAYER_CHARACTER_GUARD)
	rage.configure_battlefield(Battlefield.create_task16_test_arena())
	rage.set_opponent_behavior_enabled(true)
	var rage_setup := rage.initialize_wave_five_rare_human_warrior(Vector2i(4_000_000, 4_000_000), Vector2i(14_000_000, 4_000_000), false)
	_expect_true(rage_setup.get("success", false), "The live Rage decision fixture must initialize outside spear reach.")
	if rage_setup.get("success", false):
		_expect_true(rage.start_encounter().get("success", false), "The live Rage decision fixture must start.")
		_expect_true(rage.get_opponent_behavior_status().contains("rage"), "A legal offensive setup outside reach must allow the boss AI to choose verified Rage.")


func _test_live_throw_landing_retrieval_and_fallback_boundary() -> void:
	var session := Session.new(35_911, null, Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR, Fixture.PLAYER_CHARACTER_GUARD)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var setup := session.initialize_wave_five_rare_human_warrior(Vector2i(4_000_000, 4_000_000), Vector2i(22_000_000, 4_000_000), false)
	_expect_true(setup.get("success", false), "The live throw fixture must initialize at the exact 18-foot boundary.")
	if not setup.get("success", false):
		return
	var boss := session.get_actor_state(BossFixture.ACTOR_ID)
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 1_000
	boss.resources["ap"] = 0
	for ability_id: String in boss.ability_daily_remaining.keys():
		boss.ability_daily_remaining[ability_id] = 0
	_expect_true(session.start_encounter().get("success", false), "The live throw encounter must start.")
	_expect_true(session.get_opponent_behavior_status().contains("throw_spear"), "The live boss must submit a legal source-verified throw when pursuit cannot reach before effect.")
	session.advance_by(2_500_000)
	var world_items: Array = session.simulation.get_state_snapshot().get("world_items", [])
	_expect_equal(world_items.size(), 1, "A completed live throw must create exactly one authoritative spear world item.")
	if world_items.is_empty():
		return
	var item: Dictionary = world_items[0]
	_expect_equal(item.get("state"), "dropped", "The live thrown spear must resolve to a deterministic dropped state.")
	_expect_true(not boss.equipment_refs.has(String(BossFixture.WEAPON_REF)), "A dropped spear must be unavailable for melee and weapon Block.")
	var item_position: Variant = item.get("position_microfeet")
	if item_position is Vector2i:
		session.simulation.apply_authoritative_position(BossFixture.ACTOR_ID, item_position, 0, 0)
		session.advance_by(1)
		_expect_true(session.get_opponent_behavior_status().contains("retrieve_spear"), "The live boss must schedule the one-Act retrieval when in legal pickup reach.")
		session.advance_by(2_500_000)
		_expect_equal(session.simulation.get_state_snapshot().get("world_items", []).size(), 0, "Completed live retrieval must remove the world item rather than duplicate the spear.")
		_expect_true(boss.equipment_refs.has(String(BossFixture.WEAPON_REF)), "Completed live retrieval must restore exactly one equipped spear.")


func _test_wave_five_victory_and_player_defeat() -> void:
	var victory := _make_wave_session(35_912, 5, true)
	if victory != null:
		victory.get_actor_state(BossFixture.ACTOR_ID).current_hpc = 0
		victory.advance_by(1)
		_expect_equal(victory.get_encounter_state(), Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Defeating the Wave 5 boss must enter the approved final safe downtime.")
		var completion := victory.request_next_wave()
		_expect_true(completion.get("success", false), "Final NEXT WAVE acknowledgement must complete the circuit exactly once.")
		_expect_equal(victory.get_encounter_state(), Session.ENCOUNTER_PLAYER_VICTORY, "Wave 5 completion must end in a clear completed-run victory state.")
		_expect_true(not victory.request_next_wave().get("success", false), "A completed circuit must reject duplicate advancement into Wave 6.")
	var defeat := _make_wave_session(35_913, 5, true)
	if defeat != null:
		defeat.get_actor_state(Fixture.PLAYER_ID).current_hpc = 0
		defeat.advance_by(1)
		_expect_equal(defeat.get_encounter_state(), Session.ENCOUNTER_PLAYER_DEFEAT, "Wave 5 must preserve ordinary authoritative player defeat.")


func _test_normal_next_wave_preserves_resources_and_reports_spawn_gate() -> void:
	var session := _make_wave_session(35_914, 1, true)
	if session == null:
		return
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 7
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Normal Wave 1 victory must enter safe downtime.")
	var before := player.to_dictionary()
	var advance := session.request_next_wave()
	_expect_true(advance.get("success", false), "The legal NEXT WAVE action must authorize one state-machine advancement.")
	_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_2", "Normal progression must select Wave 2 in sequence.")
	_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_WAVE_TRANSITION_BLOCKED, "Until a combat-safe actor-registration seam exists, normal progression must explicitly block rather than reset the simulation.")
	_expect_equal(player.to_dictionary(), before, "The blocked spawn seam must not restore or discard player resources.")


func _test_wave_one_frame_partition_snapshot_convergence() -> void:
	var coarse := _make_wave_session(35_914, 1, true)
	var fine := _make_wave_session(35_914, 1, true)
	if coarse == null or fine == null:
		return
	coarse.set_opponent_behavior_enabled(false)
	fine.set_opponent_behavior_enabled(false)
	coarse.advance_by(5_000_000)
	for _step in range(100):
		fine.advance_by(50_000)
	_expect_equal(_event_signature(coarse), _event_signature(fine), "Wave 1 frame partitioning must preserve authoritative event history.")
	_expect_equal(coarse.get_state_snapshot(), fine.get_state_snapshot(), "Wave 1 frame partitioning must not increment authoritative revision for unchanged wave snapshots.")


func _test_replay_snapshot_and_two_client_convergence() -> void:
	var first := _make_wave_session(35_915, 5, true)
	var second := _make_wave_session(35_915, 5, true)
	if first == null or second == null:
		return
	first.advance_by(3_000_000)
	second.advance_by(3_000_000)
	_expect_equal(_event_signature(first), _event_signature(second), "Same-seed live Wave 5 sessions must retain identical authoritative history.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Same-seed live Wave 5 snapshots, including AI diagnostics, must match.")
	_expect_equal(first.simulation.get_state_snapshot().get("schema_version"), 12, "Wave 5 must preserve schema-12 authoritative snapshots.")

	var harness := TwoClientSyncHarness.new(35_916)
	var authority := Session.new(35_916, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR, Fixture.PLAYER_CHARACTER_GUARD)
	authority.configure_battlefield(Battlefield.create_task16_test_arena())
	authority.set_opponent_behavior_enabled(true)
	var setup := authority.initialize_wave_five_rare_human_warrior(PLAYER_POSITION, ENEMY_POSITION, true)
	_expect_true(setup.get("success", false), "The synchronization authority must initialize live Wave 5.")
	if setup.get("success", false):
		authority.advance_by(3_000_000)
		harness.deliver_in_order(harness.authority.publish_current_events())
		_expect_true(harness.compare_clients().get("success", false), "Wave 5 authoritative events must converge on two simulated clients.")
		_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave 5 authoritative and client state digests must match.")


func _make_wave_session(seed_value: int, wave_number: int, start_active: bool) -> ArenaCombatSession:
	var fixture_id := _wave_fixture(wave_number)
	var session := Session.new(seed_value, null, fixture_id, Fixture.PLAYER_CHARACTER_GUARD)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	var result: Dictionary
	match wave_number:
		1:
			result = session.initialize_wave_one_goblins(PLAYER_POSITION, ENEMY_POSITION, start_active)
		2:
			result = session.initialize_wave_two_spadoodles(PLAYER_POSITION, ENEMY_POSITION, start_active)
		3:
			result = session.initialize_wave_three_skelly_hades(PLAYER_POSITION, ENEMY_POSITION, start_active)
		4:
			result = session.initialize_wave_four_gargoyles(PLAYER_POSITION, ENEMY_POSITION, start_active)
		5:
			result = session.initialize_wave_five_rare_human_warrior(PLAYER_POSITION, ENEMY_POSITION, start_active)
	if not result.get("success", false):
		_failures.append("Wave %d setup failed: %s" % [wave_number, result.get("reason", "unknown")])
		return null
	return session


static func _wave_fixture(wave_number: int) -> StringName:
	return [
		Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,
		Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES,
		Fixture.ENCOUNTER_WAVE_THREE_SKELLY_HADES,
		Fixture.ENCOUNTER_WAVE_FOUR_GARGOYLES,
		Fixture.ENCOUNTER_WAVE_FIVE_RARE_HUMAN_WARRIOR,
	][wave_number - 1]


static func _event_types(session: ArenaCombatSession) -> PackedStringArray:
	var result := PackedStringArray()
	for event: CombatEvent in session.get_resolved_events():
		result.append(String(event.event_type))
	return result


static func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		result.append(event.to_dictionary())
	return result


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
