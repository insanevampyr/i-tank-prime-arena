extends RefCounted

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Presenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const TouchControls = preload("res://scripts/ui/mobile_touch_controls.gd")

const PLAYER_POSITION := Vector2i.ZERO
const OPPONENT_POSITION := Vector2i(3_000_000, 0)

var _failures: Array[String] = []
var _damage_seed: int = 0


func run() -> Array[String]:
	_test_target_selection_and_range()
	_test_equipment_legality_and_single_flight()
	_test_at_timing_interruption_and_integrated_resolution()
	_test_long_running_clock_attack_timing()
	_test_critical_event_presentation()
	_test_defeated_target_handling()
	_test_keyboard_and_touch_intent_paths()
	_test_replay_and_two_client_convergence()
	return _failures


func _test_target_selection_and_range() -> void:
	var default_session := _make_session(ArenaCombatSession.DEFAULT_SEED)
	_expect_true(default_session.request_player_attack("default_seed_probe").get("success", false), "The shipped deterministic seed must make the player immediately eligible under opening Initiative.")
	var session := _session_with_legal_opening()
	_expect_true(session.select_target(Fixture.OPPONENT_ID)["success"], "The visible opponent must be a selectable legal target.")
	var invalid := session.select_target(&"missing_actor")
	_expect_equal(invalid.get("reason"), "invalid_target", "Unknown scene targets must fail closed.")
	session.select_target(Fixture.OPPONENT_ID)
	_expect_true(session.get_attack_legality()["success"], "The initial three-foot fixture placement must be inside Battle Axe range.")
	session.update_player_position(Vector2i(-1_000_000, 0))
	_expect_equal(session.get_attack_legality().get("reason"), "target_out_of_range", "A target beyond the verified three-foot Battle Axe range must be rejected.")


func _test_equipment_legality_and_single_flight() -> void:
	var simulation := CombatSimulation.new(1)
	var unequipped := Fixture.make_guard_actor(Fixture.PLAYER_ID, "Unequipped fixture")
	unequipped.equipment_refs.erase(String(Fixture.WEAPON_REF))
	simulation.register_actor(unequipped)
	simulation.register_actor(Fixture.make_guard_actor(Fixture.OPPONENT_ID, "Target fixture"))
	simulation.apply_authoritative_position(Fixture.PLAYER_ID, PLAYER_POSITION, 0)
	simulation.apply_authoritative_position(Fixture.OPPONENT_ID, OPPONENT_POSITION, 0)
	simulation.begin_combat()
	var illegal := simulation.start_physical_attack(
		Fixture.PLAYER_ID, Fixture.OPPONENT_ID, Fixture.make_attack_definition(), "unequipped", &"torso", true
	)
	_expect_equal(illegal.get("reason"), "weapon_not_equipped", "The vertical slice must not attack through an unequipped weapon reference.")

	var session := _session_with_legal_opening()
	var first := session.request_player_attack("keyboard")
	_expect_true(first.get("success", false), "A legal equipped Battle Axe attack must enter the authoritative action pipeline.")
	var duplicate := session.request_player_attack("keyboard")
	_expect_equal(duplicate.get("reason"), "attack_in_progress", "Repeated input must not create a duplicate in-flight attack.")


func _test_at_timing_interruption_and_integrated_resolution() -> void:
	var timing := _session_with_legal_opening()
	var started := timing.request_player_attack("keyboard")
	var attack_id := String(started.get("attack_instance_id", ""))
	timing.advance_by(2_499_999)
	_expect_equal(timing.simulation.get_attack(attack_id).status, CombatAttackInstance.STATUS_EXECUTING, "AT 2 must occupy the full 2.5-second Act interval.")
	timing.advance_by(1)
	_expect_true(timing.simulation.get_attack(attack_id).status != CombatAttackInstance.STATUS_EXECUTING, "The authoritative effect point must occur exactly at 2.5 seconds.")

	var interrupted := _session_with_legal_opening()
	var interrupted_start := interrupted.request_player_attack("keyboard")
	var interrupted_attack_id := String(interrupted_start.get("attack_instance_id", ""))
	interrupted.simulation.schedule_interruption(
		String(interrupted_start.get("action_instance_id", "")), 1_000_000, Fixture.OPPONENT_ID, "task14_test_interruption"
	)
	interrupted.advance_by(1_000_000)
	_expect_equal(interrupted.simulation.get_attack(interrupted_attack_id).status, CombatAttackInstance.STATUS_INTERRUPTED, "A valid pre-effect interruption must cancel the executing attack.")

	_damage_seed = _find_seed_with_opponent_damage()
	_expect_true(_damage_seed > 0, "A deterministic fixture seed must reach ACC, defenses, TAL, NAL and HPC damage.")
	if _damage_seed <= 0:
		return
	var resolved := _make_session(_damage_seed)
	var hpc_before := int(resolved.get_actor_state(Fixture.OPPONENT_ID).current_hpc)
	var result := resolved.request_player_attack("keyboard")
	resolved.advance_by(2_500_000)
	var attack := resolved.simulation.get_attack(String(result.get("attack_instance_id", "")))
	_expect_equal(attack.status, CombatAttackInstance.STATUS_DAMAGE_RESOLVED, "A hit that exhausts legal defenses must complete the existing damage pipeline.")
	_expect_true(int(resolved.get_actor_state(Fixture.OPPONENT_ID).current_hpc) < hpc_before, "Integrated damage must reduce authoritative opponent HPC.")
	_expect_true(_has_event(resolved, "physical_attack_accuracy_resolved"), "Integrated resolution must record ACC.")
	_expect_true(_has_event(resolved, "physical_defense_resolved"), "Integrated resolution must record the configured defense priority result.")
	_expect_true(_has_event(resolved, "physical_damage_resolved"), "Integrated resolution must record TAL, NAL and HPC damage.")


func _test_long_running_clock_attack_timing() -> void:
	var shipped := _make_session(ArenaCombatSession.DEFAULT_SEED)
	var shipped_start := shipped.request_player_attack("shipped_seed_completion")
	_expect_true(shipped_start.get("success", false), "The shipped deterministic seed must start the vertical-slice attack.")
	_expect_equal(shipped.get_active_player_attack_status(), CombatAttackInstance.STATUS_EXECUTING, "The HUD adapter must expose the authoritative executing phase.")
	shipped.advance_by(2_500_000)
	_expect_true(not shipped.is_player_attack_in_flight(), "The shipped deterministic seed must not leave the vertical slice stuck after its 2.5-second action interval.")
	_expect_equal(shipped.get_active_player_attack_status(), "idle", "The HUD adapter must return to idle after authoritative finalization.")

	var session := _session_with_legal_opening()
	session.advance_by(8_700_000_000)
	var started := session.request_player_attack("long_running_clock")
	_expect_true(started.get("success", false), "A legal attack must still start after a long-running Web session.")
	if not started.get("success", false):
		return
	var attack_id := String(started.get("attack_instance_id", ""))
	session.advance_by(2_500_000)
	_expect_true(
		session.simulation.get_attack(attack_id).status != CombatAttackInstance.STATUS_EXECUTING,
		"AT 2 must still finalize after 2.5 seconds when the deterministic clock is already several hours old."
	)


func _test_critical_event_presentation() -> void:
	var critical_session: ArenaCombatSession = null
	for seed_value in range(1, 10_000):
		var candidate := _make_session(seed_value)
		var start := candidate.request_player_attack("keyboard")
		if not start.get("success", false):
			continue
		candidate.advance_by(2_500_000)
		if _has_event(candidate, "critical_trigger_recorded"):
			critical_session = candidate
			break
	_expect_true(critical_session != null, "The deterministic fixture must expose an approved critical record for presentation testing.")
	if critical_session == null:
		return
	for event: CombatEvent in critical_session.get_resolved_events():
		if String(event.event_type) != "critical_trigger_recorded":
			continue
		var line := Presenter.format_event(event)
		_expect_true(line.contains("CRITICAL"), "The combat log must identify a critical trigger explicitly.")
		_expect_true(line.contains("Common") or line.contains("Uncommon") or line.contains("Rare"), "The combat log must show the authoritative critical rarity.")
		var record: Dictionary = event.payload.get("critical_record", {})
		_expect_true(line.contains(String(record.get("outcome_id", "")).replace("_", " ").capitalize()), "The combat log must show the selected approved critical outcome.")
		break
	var blocked := CombatEvent.new(
		"blocked_fixture", 0, 0, 0, &"critical_effect_blocked", Fixture.PLAYER_ID, Fixture.OPPONENT_ID,
		"", PackedStringArray(), {"reason": "verified prerequisite unavailable"}
	)
	_expect_true(Presenter.format_event(blocked).contains("BLOCKED"), "Unavailable approved effects must be visible rather than fabricated.")


func _test_defeated_target_handling() -> void:
	if _damage_seed <= 0:
		_damage_seed = _find_seed_with_opponent_damage()
	if _damage_seed <= 0:
		return
	var session := _make_session(_damage_seed)
	session.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 1
	var started := session.request_player_attack("keyboard")
	session.advance_by(2_500_000)
	_expect_true(started.get("success", false), "The final legal attack must start before defeat.")
	_expect_true(int(session.get_actor_state(Fixture.OPPONENT_ID).current_hpc) <= 0, "The existing damage pipeline must expose defeated HPC without loot or EXP behavior.")
	_expect_equal(session.get_attack_legality().get("reason"), "target_defeated", "Further attacks against the defeated opponent must be rejected.")


func _test_keyboard_and_touch_intent_paths() -> void:
	var controls: MobileTouchControls = TouchControls.new()
	controls.set_viewport_size_for_testing(Vector2(800.0, 360.0))
	var layout := controls.get_layout_snapshot()
	_expect_true(controls.handle_touch(7, true, layout["attack_center"]), "The lower-right ATTACK target must capture touch input.")
	_expect_true(controls.consume_attack_requested(), "Touch ATTACK must emit one action intent.")
	_expect_true(not controls.consume_attack_requested(), "Touch ATTACK must be edge-triggered, not a held duplicate stream.")
	controls.handle_touch(7, false, layout["attack_center"])
	controls.free()

	var seed_value := _find_seed_with_legal_opening()
	var keyboard := _make_session(seed_value)
	var touch := _make_session(seed_value)
	var keyboard_start := keyboard.request_player_attack("keyboard")
	var touch_start := touch.request_player_attack("touch")
	keyboard.advance_by(2_500_000)
	touch.advance_by(2_500_000)
	var keyboard_attack := keyboard.simulation.get_attack(String(keyboard_start.get("attack_instance_id", "")))
	var touch_attack := touch.simulation.get_attack(String(touch_start.get("attack_instance_id", "")))
	_expect_equal(touch_attack.natural_roll, keyboard_attack.natural_roll, "Keyboard and touch must enter the same authoritative ACC/RNG pathway.")
	_expect_equal(touch_attack.status, keyboard_attack.status, "Keyboard and touch must produce the same combat resolution status.")
	_expect_equal(touch.get_actor_state(Fixture.OPPONENT_ID).current_hpc, keyboard.get_actor_state(Fixture.OPPONENT_ID).current_hpc, "Keyboard and touch must produce the same authoritative HPC result.")


func _test_replay_and_two_client_convergence() -> void:
	if _damage_seed <= 0:
		_damage_seed = _find_seed_with_opponent_damage()
	if _damage_seed <= 0:
		return
	var first := _make_session(_damage_seed)
	var second := _make_session(_damage_seed)
	first.request_player_attack("keyboard")
	second.request_player_attack("keyboard")
	first.advance_by(2_500_000)
	second.advance_by(2_500_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "The playable fixture must replay to an identical authoritative state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "The playable fixture event log must replay deterministically.")

	var harness := TwoClientSyncHarness.new(_damage_seed)
	var authority_session := ArenaCombatSession.new(_damage_seed, harness.authority.simulation)
	authority_session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	authority_session.select_target(Fixture.OPPONENT_ID)
	authority_session.request_player_attack("keyboard")
	authority_session.advance_by(2_500_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients()["success"], "Both simulated clients must converge after out-of-order and duplicate vertical-slice delivery.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The playable authority and complete observer digest must match.")


func _session_with_legal_opening() -> ArenaCombatSession:
	return _make_session(_find_seed_with_legal_opening())


func _make_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	var initialized := session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	_expect_true(initialized.get("success", false), "The source-verified vertical-slice fixture must initialize.")
	return session


func _find_seed_with_legal_opening() -> int:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		var result := session.request_player_attack("seed_probe")
		if result.get("success", false):
			return seed_value
	return 0


func _find_seed_with_opponent_damage() -> int:
	for seed_value in range(1, 10_000):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		var result := session.request_player_attack("damage_probe")
		if not result.get("success", false):
			continue
		session.advance_by(2_500_000)
		var attack := session.simulation.get_attack(String(result.get("attack_instance_id", "")))
		if attack != null and attack.status == CombatAttackInstance.STATUS_DAMAGE_RESOLVED:
			return seed_value
	return 0


func _has_event(session: ArenaCombatSession, event_type: String) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type:
			return true
	return false


func _serialize_events(events: Array) -> Array:
	var result: Array = []
	for event: CombatEvent in events:
		result.append(event.to_dictionary())
	return result


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
