class_name Task35JPersistentWavesAndSpearMarkerTests
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
	_test_complete_persistent_wave_circuit()
	_test_invalid_transition_requests_leave_wave_state_unchanged()
	_test_retirement_interrupts_actions_targeting_prior_wave()
	_test_same_seed_transition_replay_and_two_client_sync()
	_test_dropped_spear_marker_is_presentation_only()
	return _failures


func _test_complete_persistent_wave_circuit() -> void:
	var session := _make_normal_session(35_501, Fixture.PLAYER_CHARACTER_VAELIS)
	if session == null:
		return
	session.set_opponent_behavior_enabled(false)
	var simulation_id := session.simulation.get_instance_id()
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 5
	player.resources["mana"] = 11
	var preserved_resources := player.resources.duplicate(true)
	var preserved_inventory := player.inventory_quantities.duplicate(true)
	var preserved_abilities := player.ability_daily_remaining.duplicate(true)
	var preserved_equipment := player.equipment_refs.duplicate()
	var previous_rng_draw_count := int(session.simulation.random.get_draw_count())
	var retired_ids := PackedStringArray()

	for wave_number in range(1, 6):
		_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_%d" % wave_number, "Normal mode must reach Wave %d in sequence." % wave_number)
		var active_ids := session.get_targetable_enemy_ids()
		_expect_true(not active_ids.is_empty(), "Wave %d must contain its real registered enemies." % wave_number)
		_match_wave_count(wave_number, active_ids.size())
		for actor_id: String in active_ids:
			session.get_actor_state(StringName(actor_id)).current_hpc = 0
			retired_ids.append(actor_id)
		session.advance_by(1)
		_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Defeating every Wave %d enemy must enter safe downtime." % wave_number)
		_expect_equal(session.get_targetable_enemy_ids().size(), 0, "Downtime must expose no living target from the retired wave.")
		_expect_equal(player.current_hpc, 5, "Wave transitions must preserve current player HPC.")
		_expect_equal(player.resources, preserved_resources, "Wave transitions must preserve Mana and applicable AP.")
		_expect_equal(player.inventory_quantities, preserved_inventory, "Wave transitions must preserve inventory quantities.")
		_expect_equal(player.ability_daily_remaining, preserved_abilities, "Wave transitions must preserve Ability uses.")
		_expect_equal(player.equipment_refs, preserved_equipment, "Wave transitions must preserve equipped item ownership.")
		var advance := session.request_next_wave()
		_expect_true(advance.get("success", false), "One legal NEXT WAVE request must advance Wave %d." % wave_number)
		_expect_equal(session.simulation.get_instance_id(), simulation_id, "NEXT WAVE must retain the original CombatSimulation instance.")
		_expect_true(not session.request_next_wave().get("success", false), "A duplicate NEXT WAVE request must be rejected without another transition.")
		if wave_number < 5:
			_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_RUNNING, "Wave %d must resume active combat after registration." % (wave_number + 1))
			_expect_equal(session.get_arena_wave_state().get("current_wave_id"), "wave_%d" % (wave_number + 1), "NEXT WAVE must activate the immediate next roster.")
			_expect_true(int(session.simulation.random.get_draw_count()) > previous_rng_draw_count, "Quantity and arriving Initiative must continue the same authoritative RNG stream.")
			previous_rng_draw_count = int(session.simulation.random.get_draw_count())
		else:
			_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_PLAYER_VICTORY, "Final acknowledgement must complete the run without a Wave 6.")

	for actor_id: String in retired_ids:
		_expect_true(session.simulation.is_actor_retired(StringName(actor_id)), "Prior-wave enemy %s must remain historically present but retired." % actor_id)
		var attack := session.simulation.start_action(StringName(actor_id), CombatActionDefinition.new(&"retired_probe", 1), "retired_probe_%s" % actor_id)
		_expect_equal(attack.get("reason"), "actor_retired", "A retired enemy must not initiate a new ordinary action.")
	var snapshot := session.simulation.get_state_snapshot()
	_expect_equal(snapshot.get("schema_version"), 12, "Persistent waves must retain the schema-12 snapshot contract.")
	_expect_true((snapshot.get("retired_actor_ids", []) as Array).size() == retired_ids.size(), "The snapshot must distinguish the retired historical roster from active actors.")
	_assert_monotonic_event_history(session)


func _test_invalid_transition_requests_leave_wave_state_unchanged() -> void:
	var session := _make_normal_session(35_505, Fixture.PLAYER_CHARACTER_GUARD)
	if session == null:
		return
	session.set_opponent_behavior_enabled(false)
	var early_snapshot := session.get_arena_wave_state()
	_expect_true(not session.request_next_wave().get("success", false), "NEXT WAVE must reject an early request while Wave 1 remains active.")
	_expect_equal(session.get_arena_wave_state(), early_snapshot, "An early NEXT WAVE request must not partially modify wave state.")
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	player.current_hpc = 0
	var defeated_snapshot := session.get_arena_wave_state()
	_expect_equal(session.request_next_wave().get("reason"), "player_not_eligible_for_next_wave", "A defeated player must be unable to advance from downtime.")
	_expect_equal(session.get_arena_wave_state(), defeated_snapshot, "A defeated-player rejection must not retire the roster or advance the wave.")


func _test_retirement_interrupts_actions_targeting_prior_wave() -> void:
	var session := _make_normal_session(35_504, Fixture.PLAYER_CHARACTER_GUARD)
	if session == null:
		return
	session.set_opponent_behavior_enabled(false)
	var target_ids := session.get_targetable_enemy_ids()
	_expect_true(not target_ids.is_empty(), "Retirement coverage requires one active Wave 1 target.")
	if target_ids.is_empty():
		return
	var selected := session.select_target(StringName(target_ids[0]))
	_expect_true(selected.get("success", false), "Retirement coverage must select the active target.")
	var request := session.request_player_attack("task_35j_retirement_probe")
	_expect_true(request.get("success", false), "Retirement coverage must begin one ordinary attack before downtime.")
	if not request.get("success", false):
		return
	var action_instance_id := String(request.get("action_instance_id", ""))
	for actor_id: String in target_ids:
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_encounter_state(), Session.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "A completed Wave 1 must enter downtime while the committed player action is still pending.")
	var advance := session.request_next_wave()
	_expect_true(advance.get("success", false), "NEXT WAVE must retire the prior roster and register Wave 2.")
	var action: CombatActionInstance = session.simulation.get_action(action_instance_id)
	_expect_true(action != null and action.status == CombatActionInstance.STATUS_INTERRUPTED, "Retiring the target roster must interrupt a pending action aimed at it.")
	for pending_event: Dictionary in session.simulation.get_state_snapshot().get("pending_events", []):
		_expect_true(String(pending_event.get("payload", {}).get("action_instance_id", "")) != action_instance_id, "Retirement must remove every queued completion event for the interrupted action.")
	var saw_interrupt_due := false
	var saw_interrupted := false
	for event: CombatEvent in session.get_resolved_events():
		if String(event.payload.get("action_instance_id", "")) != action_instance_id:
			continue
		if event.event_type == &"action_interrupt_due":
			saw_interrupt_due = true
		elif event.event_type == &"action_interrupted":
			saw_interrupted = true
	_expect_true(saw_interrupt_due and saw_interrupted, "Retirement interruption must preserve both causal and result records in authoritative history.")
	_assert_monotonic_event_history(session)


func _test_same_seed_transition_replay_and_two_client_sync() -> void:
	var first := _make_normal_session(35_502, Fixture.PLAYER_CHARACTER_GUARD)
	var second := _make_normal_session(35_502, Fixture.PLAYER_CHARACTER_GUARD)
	if first == null or second == null:
		return
	first.set_opponent_behavior_enabled(false)
	second.set_opponent_behavior_enabled(false)
	_advance_one_wave(first)
	_advance_one_wave(second)
	_expect_equal(_event_signature(first), _event_signature(second), "Same-seed Wave 1-to-2 transitions must preserve event IDs, ordering and payloads.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Same-seed persistent transitions must produce identical authoritative snapshots.")

	var harness := TwoClientSyncHarness.new(35_503)
	var authority := Session.new(35_503, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_GUARD)
	authority.configure_battlefield(Battlefield.create_task16_test_arena())
	authority.set_opponent_behavior_enabled(false)
	var setup := authority.initialize_wave_one_goblins(PLAYER_POSITION, ENEMY_POSITION, true)
	_expect_true(setup.get("success", false), "Persistent-wave synchronization authority must initialize Wave 1.")
	if setup.get("success", false):
		_advance_one_wave(authority)
		harness.deliver_in_order(harness.authority.publish_current_events())
		_expect_true(harness.compare_clients().get("success", false), "Transition history and snapshot must converge on both simulated clients.")
		_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave-transition state digest must match the authoritative replica.")


func _test_dropped_spear_marker_is_presentation_only() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 35J spear-marker coverage.")
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	tree.root.add_child(scene)
	var controller := scene.get_node("CombatController") as ArenaCombatController
	var selected := controller.select_test_wave_for_testing(5)
	_expect_true(selected.get("success", false), "Spear-marker coverage must launch the existing Wave 5 fixture.")
	if not selected.get("success", false):
		tree.root.remove_child(scene)
		scene.free()
		return
	controller.update_presentation_for_testing()
	_expect_equal(controller.get_dropped_spear_marker_count_for_testing(), 0, "An equipped spear must not have a battlefield marker.")
	var session := controller.get_combat_session_for_testing()
	var boss := session.get_actor_state(BossFixture.ACTOR_ID)
	var player := session.get_actor_state(Fixture.PLAYER_ID)
	session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(4_000_000, 4_000_000), 0)
	session.simulation.apply_authoritative_position(BossFixture.ACTOR_ID, Vector2i(22_000_000, 4_000_000), 180_000)
	player.current_hpc = 1_000
	boss.resources["ap"] = 0
	for ability_id: String in boss.ability_daily_remaining.keys():
		boss.ability_daily_remaining[ability_id] = 0
	controller.press_encounter_control_for_testing()
	session.advance_by(2_500_000)
	var items := session.simulation.get_world_items_snapshot()
	_expect_equal(items.size(), 1, "The existing authoritative throw path must produce one dropped spear for marker coverage.")
	if not items.is_empty():
		var item: Dictionary = items[0]
		var item_id := String(item.get("world_item_id", ""))
		var before := session.simulation.get_state_snapshot()
		controller.update_presentation_for_testing()
		controller.update_presentation_for_testing()
		_expect_equal(controller.get_dropped_spear_marker_count_for_testing(), 1, "Repeated redraws must not duplicate the dropped-spear marker.")
		var position: Array = item.get("position_microfeet", [])
		var expected_pixels := Vector2(float(position[0]), float(position[1])) / 1_000_000.0 * 24.0
		_expect_equal(controller.get_dropped_spear_marker_position_for_testing(item_id), expected_pixels, "The marker must use the exact authoritative landing coordinate.")
		_expect_equal(session.simulation.get_state_snapshot(), before, "Rendering the marker must not mutate simulation state or RNG.")
		session.simulation.apply_authoritative_position(BossFixture.ACTOR_ID, Vector2i(int(position[0]), int(position[1])), 0, 0)
		session.advance_by(1)
		session.advance_by(2_500_000)
		controller.update_presentation_for_testing()
		_expect_equal(session.simulation.get_world_items_snapshot().size(), 0, "Legal retrieval must remove the authoritative dropped item.")
		_expect_equal(controller.get_dropped_spear_marker_count_for_testing(), 0, "The marker must disappear immediately after retrieval.")
	controller.press_encounter_control_for_testing()
	controller.update_presentation_for_testing()
	_expect_equal(controller.get_dropped_spear_marker_count_for_testing(), 0, "A fresh Test Mode RESET must clear dropped-spear presentation.")
	tree.root.remove_child(scene)
	scene.free()


func _make_normal_session(seed_value: int, character_id: StringName) -> ArenaCombatSession:
	var session := Session.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, character_id)
	session.configure_battlefield(Battlefield.create_task16_test_arena())
	var setup := session.initialize_wave_one_goblins(PLAYER_POSITION, ENEMY_POSITION, true)
	if not setup.get("success", false):
		_failures.append("Normal five-wave setup failed: %s" % setup.get("reason", "unknown"))
		return null
	return session


func _advance_one_wave(session: ArenaCombatSession) -> void:
	for actor_id: String in session.get_targetable_enemy_ids():
		session.get_actor_state(StringName(actor_id)).current_hpc = 0
	session.advance_by(1)
	var result := session.request_next_wave()
	_expect_true(result.get("success", false), "Deterministic transition helper must advance one completed wave.")


func _match_wave_count(wave_number: int, count: int) -> void:
	match wave_number:
		1:
			_expect_true(count >= 2 and count <= 8, "Wave 1 must retain seeded 2d4 Goblins.")
		2:
			_expect_true(count >= 1 and count <= 3, "Wave 2 must retain seeded 1d3 Spadoodles.")
		3:
			_expect_true(count >= 2 and count <= 3, "Wave 3 must retain 1d2 Skellys plus one Hades follower.")
		4:
			_expect_true(count >= 1 and count <= 4, "Wave 4 must retain seeded 1d4 Gargoyles.")
		5:
			_expect_equal(count, 1, "Wave 5 must contain exactly one Rare Human Warrior.")


func _assert_monotonic_event_history(session: ArenaCombatSession) -> void:
	var previous_sequence := -1
	var event_ids := {}
	for event: CombatEvent in session.get_resolved_events():
		_expect_true(event.stable_sequence > previous_sequence, "Resolved event sequence must remain strictly monotonic across waves.")
		_expect_true(not event_ids.has(event.event_id), "Resolved event identifiers must remain unique across waves.")
		previous_sequence = event.stable_sequence
		event_ids[event.event_id] = true


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		result.append(event.to_dictionary())
	return result


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
