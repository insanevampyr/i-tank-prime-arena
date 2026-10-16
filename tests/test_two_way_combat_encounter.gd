extends RefCounted

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const PLAYER_POSITION := Vector2i.ZERO
const OPPONENT_POSITION := Vector2i(3_000_000, 0)

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_fixture_validation()
	_test_encounter_control_layout()
	_test_opening_and_overlapping_attacks()
	_test_out_of_range_and_restrictions()
	_test_prone_standing_and_stagger_interruptions()
	_test_damage_victory_defeat_and_terminal_stop()
	_test_reset_and_duplicate_protection()
	_test_replay_critical_chains_and_two_client_convergence()
	return _failures


func _test_encounter_control_layout() -> void:
	var metrics := ArenaResponsiveLayout.calculate_layout(Vector2(800.0, 360.0), Vector2(800.0, 360.0))
	var button: Rect2 = metrics["encounter_button_rect"]
	_expect_true(button.position.x >= 0.0 and button.position.y >= 0.0 and button.end.x <= 800.0 and button.end.y <= 360.0, "The mouse/touch START/RESET control must remain inside a landscape phone viewport.")
	_expect_true(button.size.x >= 96.0 and button.size.y >= 48.0, "The encounter control must provide a mobile-usable touch target.")


func _test_fixture_validation() -> void:
	var actor := Fixture.make_guard_actor(&"validation", "Validation fixture")
	var valid := Fixture.validate_combatant_fixture(
		actor,
		Fixture.make_defense_profile(&"validation"),
		Fixture.make_damage_protection_profile(&"validation"),
		Fixture.make_attack_definition()
	)
	_expect_true(valid.get("success", false), "Both combatants' verified fixture attributes, derived values and equipment requirements must validate before combat.")
	_expect_true(valid.get("battle_axe_two_handed", false), "STR 16 must use the Battle Axe two-handed because Prime requires STR 24 for one-handed use.")
	_expect_true(valid.get("buckler_preserves_two_free_hands", false), "The verified Metal Buckler row must preserve the two free hands required by the Battle Axe fixture.")
	actor.attributes["str"] = 11
	var invalid := Fixture.validate_combatant_fixture(
		actor,
		Fixture.make_defense_profile(&"validation"),
		Fixture.make_damage_protection_profile(&"validation"),
		Fixture.make_attack_definition()
	)
	_expect_equal(invalid.get("reason"), "battle_axe_strength_requirement_not_met", "An under-strength fixture must fail closed before registration.")


func _test_opening_and_overlapping_attacks() -> void:
	var session := _make_two_way_session(ArenaCombatSession.DEFAULT_SEED)
	_expect_equal(session.get_opponent_behavior_label(), "task15_deterministic_test_opponent", "Opponent behavior must be explicitly labeled as a controlled fixture, not general AI.")
	_expect_equal(session.get_opponent_behavior_status(), "blocked_opening_initiative_wait", "The lower opening rank must wait without an invented real-time delay.")
	var player_start := session.request_player_attack("keyboard")
	_expect_true(player_start.get("success", false), "The opening-eligible player must be able to declare the first legal action.")
	_expect_true(session.is_opponent_attack_in_flight(), "After the first opening declaration, the opponent must start its independently legal action at the same simulation timestamp.")
	var opponent_attack := session.simulation.get_attack(session.get_active_opponent_attack_id())
	_expect_true(opponent_attack != null and opponent_attack.attacker_id == Fixture.OPPONENT_ID, "The scripted opponent must submit the ordinary attack through the shared authoritative attack pipeline.")
	if opponent_attack != null:
		var player_attack := session.simulation.get_attack(String(player_start.get("attack_instance_id", "")))
		_expect_equal(opponent_attack.declared_at_us, player_attack.declared_at_us, "Opening declarations must allow legal concurrent action execution instead of artificial alternating turns.")
	session.advance_by(2_500_000)
	_expect_true(_has_event_from(session, "physical_attack_accuracy_resolved", Fixture.PLAYER_ID), "The overlapping player action must reach authoritative ACC.")
	_expect_true(_has_event_from(session, "physical_attack_accuracy_resolved", Fixture.OPPONENT_ID), "The overlapping opponent action must reach authoritative ACC when not legally interrupted.")


func _test_out_of_range_and_restrictions() -> void:
	var out_of_range := ArenaCombatSession.new(1)
	_expect_true(out_of_range.initialize(PLAYER_POSITION, Vector2i(4_000_000, 0)).get("success", false), "Out-of-range fixture setup must initialize.")
	out_of_range.set_opponent_behavior_enabled(true)
	_expect_true(out_of_range.request_player_attack("unlock_simultaneous_opening").get("success", false), "The opening-eligible player must declare before the opponent's simultaneous rank is unlocked.")
	_expect_equal(out_of_range.get_opponent_behavior_status(), "approach_blocked_unverified_path", "The opponent must block an unauthored approach path rather than teleport or ignore terrain.")
	_expect_true(out_of_range.is_opponent_attack_in_flight(), "The opponent may declare outside reach even when movement remains blocked by unauthored navigation.")
	out_of_range.advance_by(2_500_000)
	_expect_true(not _has_event_from(out_of_range, "physical_attack_accuracy_resolved", Fixture.OPPONENT_ID), "A blocked opponent still outside reach at resolution must not roll ACC.")

	var unaware := ArenaCombatSession.new(1)
	unaware.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	unaware.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"unaware", PackedStringArray())
	unaware.set_opponent_behavior_enabled(true)
	_expect_equal(unaware.get_opponent_behavior_status(), "blocked_unaware", "An unaware opponent must not initiate an ordinary scripted attack.")

	var unequipped := ArenaCombatSession.new(1)
	unequipped.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	unequipped.get_actor_state(Fixture.OPPONENT_ID).equipment_refs.erase(String(Fixture.WEAPON_REF))
	unequipped.set_opponent_behavior_enabled(true)
	_expect_equal(unequipped.get_opponent_behavior_status(), "blocked_weapon_not_equipped", "Opponent attacks must fail closed when the verified weapon is not equipped.")


func _test_prone_standing_and_stagger_interruptions() -> void:
	var stand_seed := _find_seed_with_opponent_opening_rank_zero()
	_expect_true(stand_seed > 0, "A deterministic fixture seed must place the opponent in the first opening rank for standing coverage.")
	if stand_seed > 0:
		var standing := ArenaCombatSession.new(stand_seed)
		standing.initialize(PLAYER_POSITION, OPPONENT_POSITION)
		standing.simulation.set_actor_defense_state(Fixture.OPPONENT_ID, &"aware", PackedStringArray(["prone"]))
		standing.set_opponent_behavior_enabled(true)
		_expect_equal(standing.get_opponent_behavior_status(), "standing", "A prone opponent must choose the legal one-Act standing action before attacking.")
		standing.advance_by(2_500_000)
		_expect_true(not standing.get_actor_state(Fixture.OPPONENT_ID).conditions.has("prone"), "The opponent's AT 2 standing action must remove prone after exactly one Act.")
		_expect_true(_has_event_from(standing, "actor_stood_from_prone", Fixture.OPPONENT_ID), "Legal opponent standing must be recorded for presentation and replay.")

	var interrupted := _make_two_way_session(1)
	var player_start := interrupted.request_player_attack("stagger_fixture")
	var player_action_id := String(player_start.get("action_instance_id", ""))
	var opponent_attack := interrupted.simulation.get_attack(interrupted.get_active_opponent_attack_id())
	var opponent_action_id := "" if opponent_attack == null else opponent_attack.action_instance_id
	interrupted.simulation.schedule_interruption(player_action_id, 500_000, Fixture.OPPONENT_ID, "critical_stagger")
	interrupted.simulation.schedule_interruption(opponent_action_id, 500_000, Fixture.PLAYER_ID, "critical_stagger")
	interrupted.advance_by(500_000)
	_expect_equal(interrupted.simulation.get_action(player_action_id).status, CombatActionInstance.STATUS_INTERRUPTED, "Critical Stagger-compatible interruption must cancel the player's unfinished action.")
	_expect_equal(interrupted.simulation.get_action(opponent_action_id).status, CombatActionInstance.STATUS_INTERRUPTED, "Critical Stagger-compatible interruption must cancel the opponent's unfinished action.")


func _test_damage_victory_defeat_and_terminal_stop() -> void:
	var opponent_damage_seed := _find_two_way_damage_seed(Fixture.OPPONENT_ID)
	var player_damage_seed := _find_two_way_damage_seed(Fixture.PLAYER_ID)
	_expect_true(opponent_damage_seed > 0, "A deterministic two-way seed must exercise opponent ACC, defenses, TAL, NAL, damage and player HPC.")
	_expect_true(player_damage_seed > 0, "A deterministic two-way seed must exercise player damage and opponent HPC.")
	if opponent_damage_seed > 0:
		var defeat := _make_two_way_session(opponent_damage_seed)
		defeat.get_actor_state(Fixture.PLAYER_ID).current_hpc = 1
		defeat.request_player_attack("defeat_fixture")
		defeat.advance_by(2_500_000)
		_expect_equal(defeat.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_DEFEAT, "Opponent damage that reduces player HPC to zero must declare player defeat.")
		var attack_count: int = defeat.get_state_snapshot()["attacks"].size()
		defeat.advance_by(5_000_000)
		_expect_equal(defeat.get_state_snapshot()["attacks"].size(), attack_count, "The opponent must take no further actions after player defeat.")
		_expect_equal(defeat.get_attack_legality().get("reason"), "attacker_defeated", "A defeated player must not initiate another action.")
	if player_damage_seed > 0:
		var victory := _make_two_way_session(player_damage_seed)
		victory.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 1
		victory.request_player_attack("victory_fixture")
		victory.advance_by(2_500_000)
		_expect_equal(victory.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY, "Player damage that reduces opponent HPC to zero must declare victory.")
		_expect_equal(victory.get_attack_legality().get("reason"), "target_defeated", "A defeated opponent must reject further attacks.")


func _test_reset_and_duplicate_protection() -> void:
	var session := ArenaCombatSession.new(1)
	session.set_opponent_behavior_enabled(true)
	session.initialize(PLAYER_POSITION, OPPONENT_POSITION, false)
	var pristine_snapshot := session.get_state_snapshot()
	var pristine_events := _serialize_events(session.get_resolved_events())
	_expect_true(session.start_encounter().get("success", false), "The explicit encounter control must start a prepared fixture.")
	var first := session.request_player_attack("touch")
	_expect_true(first.get("success", false), "Touch intent must enter the same authoritative two-way encounter pathway.")
	var duplicate := session.request_player_attack("touch")
	_expect_equal(duplicate.get("reason"), "attack_in_progress", "Repeated player input must not create duplicate ordinary actions.")
	session.advance_by(2_500_000)
	_expect_true(session.reset_encounter(false).get("success", false), "Reset must recreate the owned authoritative simulation.")
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_READY, "Reset must return the test encounter to READY.")
	_expect_equal(session.get_state_snapshot(), pristine_snapshot, "Reset must restore actor state, clock, RNG, actions, events and deterministic counters exactly.")
	_expect_equal(_serialize_events(session.get_resolved_events()), pristine_events, "Reset must not leak authoritative events from the previous encounter.")


func _test_replay_critical_chains_and_two_client_convergence() -> void:
	var critical_seed := _find_two_way_critical_reaction_seed()
	_expect_true(critical_seed > 0, "A deterministic two-way seed must execute an approved zero-Act Critical Reaction chain.")
	if critical_seed > 0:
		var critical_session := _make_two_way_session(critical_seed)
		critical_session.request_player_attack("critical_chain")
		critical_session.advance_by(2_500_000)
		_expect_true(_has_event(critical_session, "critical_reaction_started"), "Approved Critical Reactions must execute through the shared authoritative chain in the two-way encounter.")
		_expect_true(_has_critical_reaction_accuracy(critical_session), "A legal Critical Reaction must produce its own causal ACC record without consuming an ordinary Act.")

	var seed_value := _find_two_way_damage_seed(Fixture.OPPONENT_ID)
	if seed_value <= 0:
		return
	var first := _make_two_way_session(seed_value)
	var second := _make_two_way_session(seed_value)
	first.request_player_attack("keyboard")
	second.request_player_attack("keyboard")
	first.advance_by(7_500_000)
	second.advance_by(7_500_000)
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "The scripted encounter must replay to identical two-actor state.")
	_expect_equal(_serialize_events(first.get_resolved_events()), _serialize_events(second.get_resolved_events()), "The scripted encounter and any legal critical chain must reproduce the same causal event transcript.")

	var harness := TwoClientSyncHarness.new(seed_value)
	var authority := ArenaCombatSession.new(seed_value, harness.authority.simulation)
	authority.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	authority.set_opponent_behavior_enabled(true)
	authority.request_player_attack("keyboard")
	authority.advance_by(7_500_000)
	var envelopes := harness.authority.publish_current_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	if not envelopes.is_empty():
		harness.client_b.receive(envelopes[0])
	_expect_true(harness.compare_clients().get("success", false), "Both clients must converge after duplicate and out-of-order two-way encounter delivery.")
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "The complete client and two-way authority digests must match.")


func _make_two_way_session(seed_value: int) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed_value)
	var initialized := session.initialize(PLAYER_POSITION, OPPONENT_POSITION)
	_expect_true(initialized.get("success", false), "The verified two-way fixture must initialize.")
	session.set_opponent_behavior_enabled(true)
	return session


func _find_seed_with_opponent_opening_rank_zero() -> int:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		if int(session.get_actor_state(Fixture.OPPONENT_ID).opening_order_rank) == 0:
			return seed_value
	return 0


func _find_two_way_damage_seed(attacker_id: StringName) -> int:
	for seed_value in range(1, 10_000):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		session.set_opponent_behavior_enabled(true)
		if not session.request_player_attack("seed_probe").get("success", false):
			continue
		session.advance_by(2_500_000)
		for event: CombatEvent in session.get_resolved_events():
			if String(event.event_type) == "physical_damage_resolved" and event.source_actor_id == attacker_id and int(event.payload.get("final_damage", 0)) > 0:
				return seed_value
	return 0


func _find_two_way_critical_reaction_seed() -> int:
	for seed_value in range(1, 5_000):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		session.set_opponent_behavior_enabled(true)
		if not session.request_player_attack("critical_seed_probe").get("success", false):
			continue
		session.advance_by(2_500_000)
		if _has_event(session, "critical_reaction_started"):
			return seed_value
	return 0


func _has_event_from(session: ArenaCombatSession, event_type: String, actor_id: StringName) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == actor_id:
			return true
	return false


func _has_event(session: ArenaCombatSession, event_type: String) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type:
			return true
	return false


func _has_critical_reaction_accuracy(session: ArenaCombatSession) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == "physical_attack_accuracy_resolved" and event.payload.get("critical_reaction", false):
			return true
	return false


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
		_failures.append("%s Expected %s, got %s." % [message, expected, actual])
