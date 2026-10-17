class_name PlayableDifferentSizeCombatTests
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Session = preload("res://scripts/combat/arena_combat_session.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const EventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(22_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_default_encounter_unchanged()
	_test_directional_playable_attacks_and_logging()
	_test_all_locations_and_declaration_locking()
	_test_existing_protection_and_multipliers()
	_test_scene_selector_and_reset()
	_test_replay_and_two_client_convergence()
	return _failures


func _test_default_encounter_unchanged() -> void:
	var session := _player_opening_session(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	var player_definition := _actor_definition(session, Fixture.PLAYER_ID)
	var opponent_definition := _actor_definition(session, Fixture.OPPONENT_ID)
	_expect_equal(player_definition.get("size_category"), "medium", "Default player must remain Medium.")
	_expect_equal(opponent_definition.get("size_category"), "medium", "Default opponent must remain Medium.")
	var started := session.request_player_attack("task29_default")
	_expect_true(started.get("success", false), "Default Medium-versus-Medium encounter must still accept the ordinary attack.")
	if started.get("success", false):
		var attack := session.simulation.get_attack(String(started["attack_instance_id"]))
		_expect_equal(attack.size_relationship, HitLocations.SAME_SIZE_RELATIONSHIP, "Default duel must retain the same-size relationship.")
		_expect_equal(attack.location_acc_modifier, 0, "Default torso attack must retain No Change.")
		_expect_equal(attack.acc_target, 12, "Default Guard torso ACC target must remain 12.")


func _test_directional_playable_attacks_and_logging() -> void:
	var session := _player_opening_session(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	var opponent_definition := _actor_definition(session, Fixture.OPPONENT_ID)
	_expect_equal(opponent_definition.get("actor_kind"), "arena_synthetic_size_test_fixture", "Different-size opponent must be explicitly synthetic.")
	_expect_equal(opponent_definition.get("size_category"), "small", "Synthetic opponent must be authoritatively Small.")
	session.set_opponent_behavior_enabled(true)
	var started := session.request_player_attack("task29_directional")
	_expect_true(started.get("success", false), "Medium player must declare against the synthetic Small opponent.")
	if not started.get("success", false):
		return
	var player_attack := session.simulation.get_attack(String(started["attack_instance_id"]))
	_expect_equal(player_attack.size_relationship, &"medium_to_small", "Player attack must use the Medium-to-Small row.")
	_expect_equal(player_attack.location_acc_modifier, -3, "Medium-to-Small torso must use Prime modifier -3.")
	_expect_equal(player_attack.acc_target, 9, "Guard ACC 12 with Medium-to-Small torso -3 must produce target 9.")
	var opponent_attack := session.simulation.get_attack(session.get_active_opponent_attack_id())
	_expect_true(opponent_attack != null, "Opponent must exercise the reverse directional relationship when opening eligibility releases it.")
	if opponent_attack != null:
		_expect_equal(opponent_attack.size_relationship, &"small_to_medium", "Opponent attack must use the distinct Small-to-Medium row.")
		_expect_equal(opponent_attack.location_acc_modifier, -1, "Small-to-Medium torso must use Prime modifier -1.")
		_expect_equal(opponent_attack.acc_target, 11, "Guard ACC 12 with Small-to-Medium torso -1 must produce target 11.")
	var declared := _find_event(session, "physical_attack_declared", Fixture.PLAYER_ID)
	_expect_true(declared != null, "Directional declaration must be authoritative log data.")
	if declared != null:
		_expect_equal(declared.payload.get("size_relationship"), "medium_to_small", "Declaration log must carry its locked relationship.")
		_expect_equal(declared.payload.get("location_acc_modifier"), -3, "Declaration log must carry its locked location modifier.")
		_expect_equal(declared.payload.get("acc_target"), 9, "Declaration log must carry its final ACC target.")
		var formatted := EventPresenter.format_event(declared)
		_expect_true(formatted.contains("medium -> small") and formatted.contains("medium_to_small") and formatted.contains("location ACC -3"), "Presented combat log must display authoritative directional data.")


func _test_all_locations_and_declaration_locking() -> void:
	var expected := {
		&"head": 0, &"neck": -1, &"torso": -3, &"shoulders_upper_arms": -2,
		&"elbows": -3, &"hands": -4, &"groin_upper_legs": -5,
		HitLocations.LOCATION_8_KNEE: -6, HitLocations.LOCATION_8_LOWER_LEG: -6, &"feet": -7,
	}
	for location_id: StringName in expected:
		var session := _player_opening_session(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
		_expect_true(session.select_target_location(location_id).get("success", false), "%s must remain selectable." % String(location_id))
		var started := session.request_player_attack("task29_%s" % String(location_id))
		_expect_true(started.get("success", false), "%s must remain declaration-legal." % String(location_id))
		if started.get("success", false):
			var attack := session.simulation.get_attack(String(started["attack_instance_id"]))
			_expect_equal(attack.target_location, location_id, "%s must lock at declaration." % String(location_id))
			_expect_equal(attack.location_acc_modifier, expected[location_id], "%s must use the Medium-to-Small chart row." % String(location_id))
	var locked := _player_opening_session(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	locked.select_target_location(HitLocations.LOCATION_8_KNEE)
	var locked_start := locked.request_player_attack("task29_locked_knee")
	locked.select_target_location(&"head")
	if locked_start.get("success", false):
		var attack := locked.simulation.get_attack(String(locked_start["attack_instance_id"]))
		_expect_equal(attack.target_location, HitLocations.LOCATION_8_KNEE, "Mid-action selection changes must not alter the declared Knee target.")
		_expect_equal(attack.size_relationship, &"medium_to_small", "Mid-action selection changes must not alter the declared size relationship.")


func _test_existing_protection_and_multipliers() -> void:
	var protection := Fixture.make_damage_protection_profile(Fixture.OPPONENT_ID)
	_expect_equal(protection.armors.size(), 1, "Synthetic fixture must reuse the existing single Plate torso definition.")
	if protection.armors.size() == 1:
		var armor := protection.armors[0]
		_expect_true(armor.covered_locations.has("torso"), "Plate TAL must remain torso-specific.")
		_expect_true(not armor.covered_locations.has("head") and not armor.covered_locations.has("neck"), "Torso Plate must not gain head or neck coverage from size.")
	var damage := Fixture.make_attack_definition().physical_damage
	_expect_equal(damage.get_location_multiplier(&"head").get("numerator"), 3, "Head multiplier numerator must remain 3.")
	_expect_equal(damage.get_location_multiplier(&"head").get("denominator"), 2, "Head multiplier denominator must remain 2.")
	_expect_equal(damage.get_location_multiplier(&"neck").get("numerator"), 3, "Neck multiplier numerator must remain 3.")
	_expect_equal(damage.get_location_multiplier(&"neck").get("denominator"), 2, "Neck multiplier denominator must remain 2.")


func _test_scene_selector_and_reset() -> void:
	for viewport_size: Vector2 in [Vector2(1152.0, 648.0), Vector2(800.0, 360.0)]:
		var metrics := ResponsiveLayout.calculate_layout(viewport_size, viewport_size)
		var selector_rect: Rect2 = metrics["encounter_selector_rect"]
		_expect_true(Rect2(Vector2.ZERO, viewport_size).encloses(selector_rect), "Duel selector must remain inside the %s viewport." % viewport_size)
		_expect_true(not selector_rect.intersects(metrics["log_button_rect"]), "Duel selector must not overlap FULL LOG at %s." % viewport_size)
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 29 selector test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var selected := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	_expect_true(selected.get("success", false), "READY scene must permit selecting the synthetic Small duel.")
	_expect_equal(controller.get_combat_session_for_testing().get_encounter_fixture_id(), Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD, "Scene selector must rebuild the requested fixture.")
	controller.press_encounter_control_for_testing()
	var blocked := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	_expect_equal(blocked.get("reason"), "encounter_selection_requires_ready_state", "Duel selection must be locked after START.")
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_combat_session_for_testing().get_encounter_fixture_id(), Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD, "RESET must preserve the selected duel variant.")
	scene.free()


func _test_replay_and_two_client_convergence() -> void:
	var seed_value := _find_player_opening_seed(Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	var first := _session(seed_value, Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	var second := _session(seed_value, Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	first.set_opponent_behavior_enabled(true)
	second.set_opponent_behavior_enabled(true)
	first.request_player_attack("task29_replay")
	second.request_player_attack("task29_replay")
	first.advance_by(2_500_000)
	second.advance_by(2_500_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "Different-size duel must replay to identical authoritative state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "Different-size duel must replay to an identical event stream.")

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority := ArenaCombatSession.new(seed_value, harness.authority.simulation, Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD)
	authority.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	authority.set_opponent_behavior_enabled(true)
	authority.request_player_attack("task29_sync")
	authority.advance_by(2_500_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Different-size event delivery must converge after duplicate and out-of-order input.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "Different-size clients must match the authority digest.")


func _player_opening_session(encounter_fixture_id: StringName) -> ArenaCombatSession:
	var seed_value := _find_player_opening_seed(encounter_fixture_id)
	_expect_true(seed_value > 0, "A deterministic player-opening seed must exist for %s." % String(encounter_fixture_id))
	return _session(seed_value, encounter_fixture_id)


func _find_player_opening_seed(encounter_fixture_id: StringName) -> int:
	for seed_value in range(1, 500):
		var session := _session(seed_value, encounter_fixture_id)
		if session.get_actor_state(Fixture.PLAYER_ID) != null and int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) == 0:
			return seed_value
	return 0


func _session(seed_value: int, encounter_fixture_id: StringName) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value, null, encounter_fixture_id)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initialized := session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	_expect_true(initialized.get("success", false), "%s must initialize." % String(encounter_fixture_id))
	return session


func _actor_definition(session: ArenaCombatSession, actor_id: StringName) -> Dictionary:
	for actor: Dictionary in session.get_state_snapshot().get("actors", []):
		var definition: Dictionary = actor.get("definition", {})
		if definition.get("actor_id") == String(actor_id):
			return definition
	return {}


func _find_event(session: ArenaCombatSession, event_type: String, source_id: StringName) -> CombatEvent:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == source_id:
			return event
	return null


func _serialize_events(events: Array) -> Array:
	var serialized: Array = []
	for event: CombatEvent in events:
		serialized.append(event.to_dictionary())
	return serialized


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
