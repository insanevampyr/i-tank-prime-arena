class_name PresentationEventConsumptionTests
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const Session = preload("res://scripts/combat/arena_combat_session.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(23_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_incremental_cursor_preserves_authoritative_history()
	_test_floating_text_filters_non_presentable_events()
	_test_transcript_cache_refreshes_only_when_history_changes()
	_test_sync_convergence_is_unchanged()
	return _failures


func _test_incremental_cursor_preserves_authoritative_history() -> void:
	var session := _session(301)
	var initial_events := _serialize_events(session.get_resolved_events())
	var initial_digest := Digest.compute(session.get_state_snapshot())
	var initial_batch := session.get_resolved_events_since(0, -1)
	_expect_true(initial_batch.get("success", false), "A fresh presentation cursor must read initial authoritative history.")
	_expect_equal(_serialize_events(initial_batch.get("events", [])), initial_events, "Initial cursor delivery must retain every authoritative ID, timestamp and ordering.")
	var cursor := int(initial_batch.get("next_cursor", -1))
	var generation := int(initial_batch.get("history_generation", -1))
	session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(20_100_000, 12_000_000), 0)
	session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(20_200_000, 12_000_000), 0)
	var tail := session.get_resolved_events_since(cursor, generation)
	_expect_true(tail.get("success", false) and (tail.get("events", []) as Array).size() == 2, "An unchanged cursor must retrieve only two newly appended movement events.")
	_expect_true(int(tail.get("next_cursor", -1)) == session.get_resolved_event_count(), "Cursor reads must advance to the exact authoritative event count.")
	_expect_equal(initial_digest, Digest.compute(_session(301).get_state_snapshot()), "Inspecting an append-only cursor must not mutate seeded initial state or RNG history.")
	var old_generation := generation
	session.reset_encounter(false)
	var reset_batch := session.get_resolved_events_since(int(tail.get("next_cursor", 0)), old_generation)
	_expect_true(reset_batch.get("success", false) and reset_batch.get("generation_changed", false), "Reset must invalidate a stale presentation cursor and restart at the new history.")
	_expect_equal(_serialize_events(reset_batch.get("events", [])), _serialize_events(session.get_resolved_events()), "Reset cursor recovery must retain complete new-encounter history.")


func _test_floating_text_filters_non_presentable_events() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for presentation filtering test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var layer: ArenaFloatingCombatText = scene.get_node("FloatingCombatText")
	for index in range(20):
		layer.present_authoritative_event(_event("position_%d" % index, &"actor_position_changed", {}))
	_expect_equal(layer.get_presented_event_id_count_for_testing(), 0, "Movement-only events must not grow floating-text duplicate bookkeeping.")
	var damage := _event("damage_once", &"physical_damage_resolved", {"final_damage": 5, "hpc_after": 95})
	layer.present_authoritative_event(damage)
	layer.present_authoritative_event(damage)
	_expect_true(layer.get_presented_event_id_count_for_testing() == 1 and layer.get_active_messages_for_testing().size() == 1, "A presentable combat event must remain duplicate-safe without suppressing its feedback.")
	scene.free()


func _test_transcript_cache_refreshes_only_when_history_changes() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for transcript-cache test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.set_transcript_visible(true)
	var first_metrics := controller.get_event_consumption_metrics_for_testing()
	var first_text := controller.get_transcript_text_for_testing()
	controller.call("_update_presentation")
	controller.call("_update_presentation")
	_expect_equal(controller.get_event_consumption_metrics_for_testing().get("transcript_build_count"), first_metrics.get("transcript_build_count"), "FULL LOG must not rebuild an unchanged transcript every presentation frame.")
	var session := controller.get_combat_session_for_testing()
	session.simulation.apply_authoritative_position(Fixture.PLAYER_ID, Vector2i(20_100_000, 12_000_000), 0)
	var new_event_id := (session.get_resolved_events().back() as CombatEvent).event_id
	controller.call("_process_new_events")
	var changed_text := controller.get_transcript_text_for_testing()
	_expect_true(changed_text.contains("id=%s" % new_event_id), "FULL LOG cache must refresh when an authoritative event is appended.")
	_expect_true(int(controller.get_event_consumption_metrics_for_testing().get("transcript_build_count", 0)) == int(first_metrics.get("transcript_build_count", 0)) + 1, "Appending history must trigger exactly one transcript rebuild on the next read.")
	controller.call("_on_copy_log_button_pressed")
	controller.call("_on_save_log_button_pressed")
	_expect_equal(controller.get_transcript_text_for_testing(), changed_text, "COPY LOG and SAVE LOG must use the complete current cached transcript.")
	controller.press_encounter_control_for_testing()
	controller.press_encounter_control_for_testing()
	var reset_text := controller.get_transcript_text_for_testing()
	_expect_true(not reset_text.contains("id=%s" % new_event_id), "RESET must invalidate cached output rather than retaining old encounter events.")
	_expect_true(not first_text.is_empty(), "The initial FULL LOG cache must remain complete and readable.")
	scene.free()


func _test_sync_convergence_is_unchanged() -> void:
	var harness := TwoClientSyncHarness.new(302)
	harness.authority.schedule_event(100, &"presentation_cursor_regression", 4, Fixture.PLAYER_ID)
	harness.authority.schedule_event(100, &"presentation_cursor_regression", 3, Fixture.OPPONENT_ID)
	var envelopes := harness.authority.publish_resolved_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_true(harness.compare_clients().get("success", false), "Presentation-only cursor changes must not affect duplicate/out-of-order two-client convergence.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Presentation-only changes must not alter authoritative replay digest.")


func _session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var result := session.initialize(PLAYER_POSITION, OPPONENT_POSITION, false)
	_expect_true(result.get("success", false), "Cursor fixture session must initialize.")
	return session


func _event(event_id: String, event_type: StringName, payload: Dictionary) -> CombatEvent:
	return CombatEvent.new(event_id, 10, 4, 1, event_type, Fixture.PLAYER_ID, Fixture.OPPONENT_ID, "", PackedStringArray(), payload, {})


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
