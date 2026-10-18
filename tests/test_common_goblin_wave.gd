class_name CommonGoblinWaveTests
extends RefCounted

const ArenaCombatSession = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ArenaWaveStateMachine = preload("res://scripts/combat/arena_wave_state_machine.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const CommonGoblinFixture = preload("res://scripts/creatures/common_goblin_fixture.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const GOBLIN_POSITION := Vector2i(24_000_000, 12_000_000)

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_source_backed_definition_and_size_ruling()
	_test_all_seeded_wave_counts_spawn_independent_goblins()
	_test_targeting_and_size_acc_are_directional()
	_test_two_fists_resolve_within_one_goblin_act()
	_test_interruption_cancels_both_pending_fists()
	_test_defeat_before_resolution_prevents_fist_accuracy_rolls()
	_test_defeated_goblin_cannot_declare_another_act()
	_test_wave_victory_requires_all_active_goblins()
	_test_reset_replay_and_two_client_convergence()
	return _failures


func _test_source_backed_definition_and_size_ruling() -> void:
	var actor := CommonGoblinFixture.make_actor(&"source_goblin", "Source Goblin")
	_expect_true(actor != null, "Common Goblin source definition must instantiate.")
	if actor == null:
		return
	_expect_equal(actor.size_category, &"small", "Common Goblin must use the owner-approved Small category.")
	_expect_equal(actor.get_combat_stat("hpm"), 1, "Goblin HPM must match the supplied source.")
	_expect_equal(actor.get_combat_stat("at"), 1, "Goblin AT must match the supplied source.")
	_expect_equal(actor.get_combat_stat("mr"), 6, "Goblin MR must match the supplied source.")
	_expect_equal(actor.get_combat_stat("acc"), 7, "Goblin ACC must match the supplied source.")
	_expect_equal(actor.get_combat_stat("init"), 3, "Goblin INIT must match the supplied source.")
	_expect_true(String(actor.field_sources.get("size_category", "")).contains("designer-approved"), "Goblin size must be identified as a designer ruling, not a printed source value.")
	var attack := CommonGoblinFixture.make_attack_definition(HitLocations.get_same_size_attack_profile())
	_expect_equal(attack.strikes_per_act if attack != null else 0, 2, "Common Goblin fists must retain the approved two independent strikes per Act.")


func _test_all_seeded_wave_counts_spawn_independent_goblins() -> void:
	var observed_counts := {}
	for seed in range(1, 256):
		var session := _ready_wave_session(seed, false)
		var state := session.get_arena_wave_state()
		var count := int(state.get("resolved_roster", [])[0].get("resolved_count", 0))
		observed_counts[count] = true
		_expect_equal(session.get_targetable_enemy_ids().size(), count, "Wave 1 must register every seeded Goblin as an independently targetable enemy.")
		var ids := session.get_targetable_enemy_ids()
		for actor_id: String in ids:
			var actor_state := session.get_actor_state(StringName(actor_id))
			_expect_true(actor_state != null and actor_state.current_hpc == 1, "Each Goblin must retain independent HPM/HPC state.")
		if observed_counts.size() == 4:
			break
	_expect_equal(observed_counts.size(), 4, "The seeded 1d4 contract must exercise all four legal Wave 1 spawn quantities.")


func _test_targeting_and_size_acc_are_directional() -> void:
	var session := _ready_wave_session(31_301, true)
	var target_id := session.get_targetable_enemy_ids()[0]
	_expect_true(session.select_target(StringName(target_id)).get("success", false), "A live Goblin must be selectable.")
	_expect_true(session.select_target_location_by_number(1).get("success", false), "Existing nine-location selection must remain available against Goblins.")
	var player_attack := session.request_player_attack("test")
	_expect_true(player_attack.get("success", false), "The Guard must be able to declare the existing legal approach-capable attack against a Goblin.")
	var player_declared := _last_event_of_type(session, "physical_attack_declared")
	_expect_equal(player_declared.payload.get("size_relationship"), "medium_to_small", "Guard-to-Goblin attacks must use Prime's Medium-to-Small directional relationship.")
	_expect_equal(player_declared.payload.get("location_acc_modifier"), 0, "Medium-to-Small head modifier must use the verified directional chart.")

	# Use a separate encounter for the reverse direction so the player attack above
	# cannot defeat the Goblin before its legal scripted declaration.
	var reverse_session := _ready_wave_session(31_304, true)
	var reverse_target := _opening_goblin_id(reverse_session)
	var move := reverse_session.simulation.apply_authoritative_position(StringName(reverse_target), PLAYER_POSITION + Vector2i(1_000_000, 0), 0)
	_expect_true(move.get("success", false), "Focused Goblin test position must remain legal.")
	for unused in range(100):
		reverse_session.advance_by(100_000)
	var goblin_declared: Variant = _last_event_of_type_with_goblin_source(reverse_session, "physical_attack_declared")
	_expect_true(goblin_declared != null, "A Goblin in verified fist reach must declare through the scripted legal-attack path. Status: %s" % reverse_session.get_opponent_behavior_status())
	if goblin_declared != null:
		_expect_equal(goblin_declared.payload.get("size_relationship"), "small_to_medium", "Goblin-to-Guard attacks must use Prime's reverse Small-to-Medium directional relationship.")


func _test_two_fists_resolve_within_one_goblin_act() -> void:
	# This fixed seed is already exercised by the reverse-direction behavior test
	# above and produces a legal scripted Goblin declaration after opening INIT.
	var session := _ready_wave_session(31_304, true)
	var goblin_id := _opening_goblin_id(session)
	_expect_true(
		session.simulation.apply_authoritative_position(goblin_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 0).get("success", false),
		"Focused fist test position must remain legal."
	)
	var declarations := _advance_until_two_declarations(session, goblin_id)
	_expect_true(declarations.size() >= 2, "An eligible Goblin must declare two fist strikes during its one completed Act.")
	if declarations.size() < 2:
		return
	var first: CombatEvent = declarations[0]
	var second: CombatEvent = declarations[1]
	_expect_equal(first.payload.get("action_instance_id"), second.payload.get("action_instance_id"), "Both Goblin fists must belong to one action instance, not two Acts.")
	_expect_equal(first.payload.get("strike_index"), 1, "First Goblin fist must retain stable strike index 1.")
	_expect_equal(second.payload.get("strike_index"), 2, "Second Goblin fist must retain stable strike index 2.")
	_expect_equal(first.payload.get("strikes_per_act"), 2, "Goblin declaration must record the approved two-strike Act contract.")
	var action := _action_snapshot(session, String(first.payload.get("action_instance_id", "")))
	_expect_equal(action.get("required_acts"), 1, "Two Goblin fists must not add an ordinary Act.")
	_expect_equal(action.get("at_at_start"), 1, "Goblin two-fist action must preserve source AT 1.")
	# The declarations occur when the AT-1 action begins; advance exactly to its
	# authoritative final-effect timestamp before inspecting the ACC records.
	session.simulation.advance_to(int(action.get("final_effect_due_at_us", session.simulation.clock.get_elapsed_us())))
	var accuracy_events := _events_for_source(session, "physical_attack_accuracy_resolved", goblin_id)
	_expect_true(accuracy_events.size() >= 2, "Each Goblin fist must independently resolve ACC after the same Act completes.")
	if accuracy_events.size() >= 2:
		_expect_equal(accuracy_events[0].payload.get("strike_index"), 1, "First Goblin fist ACC record must remain distinct.")
		_expect_equal(accuracy_events[1].payload.get("strike_index"), 2, "Second Goblin fist ACC record must remain distinct.")


func _test_defeated_goblin_cannot_declare_another_act() -> void:
	var session := _ready_wave_session(31_306, true)
	var goblin_id := StringName(session.get_targetable_enemy_ids()[0])
	var goblin_state := session.get_actor_state(goblin_id)
	goblin_state.current_hpc = 0
	for unused in range(120):
		session.advance_by(100_000)
	_expect_equal(
		_events_for_source(session, "physical_attack_declared", goblin_id).size(),
		0,
		"A defeated Goblin must not declare a new fist action or posthumous attack."
	)


func _test_defeat_before_resolution_prevents_fist_accuracy_rolls() -> void:
	var session := _ready_wave_session(31_304, true)
	var goblin_id := _opening_goblin_id(session)
	_expect_true(session.simulation.apply_authoritative_position(goblin_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 0).get("success", false), "Defeat-resolution fist test position must remain legal.")
	var declarations := _advance_until_two_declarations(session, goblin_id)
	if declarations.size() < 2:
		_failures.append("Focused Goblin defeat-resolution test requires the two pending fist declarations.")
		return
	var action_id := String(declarations[0].payload.get("action_instance_id", ""))
	session.get_actor_state(goblin_id).current_hpc = 0
	var action := _action_snapshot(session, action_id)
	session.simulation.advance_to(int(action.get("final_effect_due_at_us", session.simulation.clock.get_elapsed_us())))
	_expect_equal(_events_for_source(session, "physical_attack_accuracy_resolved", goblin_id).size(), 0, "A Goblin defeated before its Act resolves must not roll either pending fist ACC check.")
	var final_legality_failures := _events_for_source(session, "physical_attack_final_legality_failed", goblin_id)
	_expect_true(final_legality_failures.size() >= 2, "Both pending Goblin fists must terminate through the existing final-legality boundary after source defeat.")


func _test_interruption_cancels_both_pending_fists() -> void:
	var session := _ready_wave_session(31_304, true)
	var goblin_id := _opening_goblin_id(session)
	_expect_true(session.simulation.apply_authoritative_position(goblin_id, PLAYER_POSITION + Vector2i(1_000_000, 0), 0).get("success", false), "Interrupted fist test position must remain legal.")
	var declarations := _advance_until_two_declarations(session, goblin_id)
	if declarations.size() < 2:
		_failures.append("Focused Goblin interruption test requires the two pending fist declarations.")
		return
	var action_id := String(declarations[0].payload.get("action_instance_id", ""))
	var interruption := session.simulation.schedule_interruption(
		action_id,
		session.simulation.clock.get_elapsed_us() + 1,
		Fixture.PLAYER_ID,
		"test_interruption"
	)
	_expect_true(interruption.get("success", false), "A valid interruption must schedule against the Goblin's in-progress Act.")
	session.advance_by(1)
	var interrupted_count := 0
	for attack: Dictionary in session.simulation.get_state_snapshot().get("attacks", []):
		if String(attack.get("action_instance_id", "")) == action_id and String(attack.get("status", "")) == "interrupted":
			interrupted_count += 1
	_expect_equal(interrupted_count, 2, "Interrupting one Goblin Act must cancel both pending fist strikes without posthumous ACC rolls.")


func _test_wave_victory_requires_all_active_goblins() -> void:
	var session := _ready_wave_session(31_302, true)
	var ids := session.get_targetable_enemy_ids()
	for index in range(ids.size() - 1):
		session.get_actor_state(StringName(ids[index])).current_hpc = 0
		var interim := session.evaluate_current_wave_victory()
		_expect_true(interim.get("success", false), "Wave state must observe current authoritative Goblin states.")
		_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_ACTIVE, "Wave 1 must not declare victory while any Goblin remains alive.")
	session.get_actor_state(StringName(ids[ids.size() - 1])).current_hpc = 0
	session.advance_by(1)
	_expect_equal(session.get_arena_wave_state().get("state"), ArenaWaveStateMachine.STATE_VICTORY_DETECTED, "Wave 1 victory must occur only after every active Goblin is defeated.")
	_expect_equal(session.get_encounter_state(), ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY, "Wave 1 victory must end the playable Wave 1 encounter without advancing unsupported Wave 2.")


func _test_reset_replay_and_two_client_convergence() -> void:
	var first := _ready_wave_session(31_303, false)
	var first_signature := _event_signature(first)
	_expect_true(first.reset_encounter(false).get("success", false), "Wave 1 reset must rebuild the same seeded encounter.")
	_expect_equal(_event_signature(first), first_signature, "Wave 1 reset must preserve the complete deterministic event history.")

	var harness := TwoClientSyncHarness.new(31_304)
	var authority_session := ArenaCombatSession.new(31_304, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_expect_true(authority_session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, false).get("success", false), "External authority must initialize the Common Goblin wave.")
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Wave 1 authoritative history must converge for both simulated clients.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Wave 1 replay must preserve the authoritative digest.")


func _ready_wave_session(seed: int, start_active: bool) -> ArenaCombatSession:
	var session := ArenaCombatSession.new(seed, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(true)
	_expect_true(session.initialize_wave_one_goblins(PLAYER_POSITION, GOBLIN_POSITION, start_active).get("success", false), "Common Goblin wave fixture must initialize.")
	return session


func _opening_goblin_id(session: ArenaCombatSession) -> StringName:
	var opening_event := _last_event_of_type(session, "opening_initiative_resolved")
	if opening_event == null:
		return &""
	var opening_order: Array = opening_event.payload.get("opening_order", [])
	if opening_order.is_empty():
		return &""
	return StringName(opening_order[0].get("actor_id", ""))


func _advance_until_two_declarations(session: ArenaCombatSession, goblin_id: StringName) -> Array[CombatEvent]:
	for unused in range(100):
		var declarations := _events_for_source(session, "physical_attack_declared", goblin_id)
		if declarations.size() >= 2:
			return declarations
		session.advance_by(100_000)
	return _events_for_source(session, "physical_attack_declared", goblin_id)


func _last_event_of_type(session: ArenaCombatSession, event_type: String) -> CombatEvent:
	for index in range(session.get_resolved_events().size() - 1, -1, -1):
		var event: CombatEvent = session.get_resolved_events()[index]
		if String(event.event_type) == event_type:
			return event
	return null


func _events_for_source(session: ArenaCombatSession, event_type: String, source_actor_id: StringName) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == event_type and event.source_actor_id == source_actor_id:
			events.append(event)
	return events


func _action_snapshot(session: ArenaCombatSession, action_instance_id: String) -> Dictionary:
	for action: Dictionary in session.simulation.get_state_snapshot().get("actions", []):
		if String(action.get("action_instance_id", "")) == action_instance_id:
			return action
	return {}


func _last_event_of_type_for_source(session: ArenaCombatSession, event_type: String, source_actor_id: StringName) -> Variant:
	for index in range(session.get_resolved_events().size() - 1, -1, -1):
		var event: CombatEvent = session.get_resolved_events()[index]
		if String(event.event_type) == event_type and event.source_actor_id == source_actor_id:
			return event
	return null


func _last_event_of_type_with_goblin_source(session: ArenaCombatSession, event_type: String) -> Variant:
	for index in range(session.get_resolved_events().size() - 1, -1, -1):
		var event: CombatEvent = session.get_resolved_events()[index]
		if String(event.event_type) == event_type and String(event.source_actor_id).begins_with("wave_1_common_goblin_"):
			return event
	return null


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append(event.to_dictionary())
	return signature


func _expect_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])
