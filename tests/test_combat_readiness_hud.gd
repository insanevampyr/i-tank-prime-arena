extends RefCounted

const Readiness = preload("res://scripts/ui/combat_readiness_model.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Session = preload("res://scripts/combat/arena_combat_session.gd")
const PrimeMovement = preload("res://scripts/movement/prime_movement_model.gd")

const PLAYER_POSITION := Vector2i(20_000_000, 12_000_000)
const OPPONENT_POSITION := Vector2i(23_000_000, 12_000_000)

var _failures: Array[String] = []


class FixedRollSource extends RefCounted:
	var roll: int

	func _init(value: int) -> void:
		roll = value

	func next_int(_minimum: int, _maximum: int) -> int:
		return roll

	func get_draw_count() -> int:
		return 1


func run() -> Array[String]:
	_test_authoritative_attack_progress()
	_test_attack_readiness_states_and_interruption()
	_test_running_readiness_states()
	_test_movement_running_and_attack_concurrency()
	_test_scene_reset_focus_and_indicators()
	_test_responsive_indicator_layout()
	return _failures


func _test_authoritative_attack_progress() -> void:
	var expected := {2: 2_500_000, 10: 500_000, 12: 416_667}
	for at_value: int in expected:
		var simulation := CombatSimulation.new(1900 + at_value)
		var actor_id := StringName("readiness_at_%d" % at_value)
		simulation.register_actor(_make_actor(actor_id, at_value))
		var result := simulation.start_action(actor_id, CombatActionDefinition.new(&"readiness_action", 1), "readiness_%d" % at_value)
		_expect_true(result.get("success", false), "AT %d readiness fixture must start." % at_value)
		var action := simulation.get_action(String(result.get("action_instance_id", "")))
		var start := Readiness.get_action_progress(action, 0)
		_expect_equal(start["total_us"], expected[at_value], "ATTACK countdown must use the exact AT %d scheduled duration." % at_value)
		_expect_equal(start["remaining_us"], expected[at_value], "ATTACK countdown must initially show the full AT %d interval." % at_value)
		var halfway_us: int = int(expected[at_value]) / 2
		var halfway := Readiness.get_action_progress(action, halfway_us)
		_expect_equal(halfway["remaining_us"], int(expected[at_value]) - halfway_us, "ATTACK remaining time must be derived from the authoritative due timestamp.")
		_expect_true(float(halfway["progress"]) > 0.49 and float(halfway["progress"]) < 0.51, "Fractional AT progress must not use a hardcoded 2.5-second timer.")


func _test_attack_readiness_states_and_interruption() -> void:
	var session := _legal_player_session()
	_expect_equal(Readiness.get_attack_readiness(session)["state"], Readiness.STATE_READY, "A legal idle player attack must show READY.")
	session.clear_target()
	_expect_equal(Readiness.get_attack_readiness(session)["state"], Readiness.STATE_NO_TARGET, "A missing selection must show NO TARGET without changing authority.")
	session.select_target(Fixture.OPPONENT_ID)
	var started := session.request_player_attack("readiness")
	_expect_true(started.get("success", false), "The readiness fixture attack must start legally.")
	var attacking := Readiness.get_attack_readiness(session)
	_expect_equal(attacking["state"], Readiness.STATE_ATTACKING, "An executing ordinary attack must show ATTACKING.")
	_expect_equal(attacking["total_us"], 2_500_000, "The AT 2 fixture must expose its actual 2.5-second action interval.")
	session.advance_by(1_000_000)
	_expect_equal(Readiness.get_attack_readiness(session)["remaining_us"], 1_500_000, "Attack countdown must follow simulation time, not frames.")

	var action_id := String(started.get("action_instance_id", ""))
	var player_state := session.get_actor_state(Fixture.PLAYER_ID)
	player_state.critical_stagger_until_us = session.simulation.clock.get_elapsed_us() + 500_000
	if not player_state.conditions.has("critical_stagger"):
		player_state.conditions.append("critical_stagger")
	session.simulation.schedule_interruption(action_id, session.simulation.clock.get_elapsed_us(), Fixture.OPPONENT_ID, "critical_stagger")
	session.advance_by(1)
	var staggered := Readiness.get_attack_readiness(session)
	_expect_equal(staggered["state"], Readiness.STATE_STAGGERED, "Critical Stagger must replace the interrupted attack countdown immediately.")
	_expect_true(int(staggered["remaining_us"]) < 500_000, "Stagger readiness must use the authoritative remaining duration.")

	var out_of_range := ArenaCombatSession.new(1)
	out_of_range.initialize(PLAYER_POSITION, Vector2i(30_000_000, 12_000_000))
	out_of_range.select_target(Fixture.OPPONENT_ID)
	var approach_ready := Readiness.get_attack_readiness(out_of_range)
	_expect_equal(approach_ready["state"], Readiness.STATE_READY, "Current distance must not turn approach-attack declaration into OUT OF RANGE.")
	_expect_equal(approach_ready["value_text"], "APPROACH", "The indicator may communicate required approach while remaining READY.")

	var completed := _legal_player_session()
	_expect_true(completed.request_player_attack("completion").get("success", false), "Completion readiness fixture must start.")
	completed.advance_by(2_500_000)
	completed.get_actor_state(Fixture.OPPONENT_ID).set_position(OPPONENT_POSITION, 0)
	var after_completion := Readiness.get_attack_readiness(completed)
	_expect_true(after_completion["state"] != Readiness.STATE_ATTACKING, "A completed action must stop its countdown immediately.")
	_expect_true(String(after_completion.get("reason", "")) != "cooldown", "Ordinary attack completion must not fabricate an extra cooldown.")

	var restricted := _legal_player_session()
	var restricted_state := restricted.get_actor_state(Fixture.PLAYER_ID)
	restricted_state.conditions = PackedStringArray(["prone"])
	_expect_equal(Readiness.get_attack_readiness(restricted)["reason"], "actor_prone", "Prone must block an ordinary attack until standing.")
	restricted_state.conditions = PackedStringArray(["incapacitated"])
	_expect_equal(Readiness.get_attack_readiness(restricted)["reason"], "attacker_incapacitated", "Recorded incapacitation must block ordinary attacks.")
	restricted_state.conditions = PackedStringArray()
	restricted_state.current_hpc = 0
	_expect_equal(Readiness.get_attack_readiness(restricted)["reason"], "attacker_defeated", "Defeat must block ordinary attacks.")

	var waiting := _opponent_opening_session()
	_expect_true(Readiness.get_attack_readiness(waiting)["reason"] != "opening_initiative_wait", "A lower opening rank must not create a false readiness block under independent Initiative.")


func _test_running_readiness_states() -> void:
	var movement := PrimeMovement.new(11, 12, 10, 3, 0, 0)
	var ready := Readiness.get_running_readiness(movement.to_dictionary())
	_expect_equal(ready["state"], Readiness.STATE_READY, "The automatic three-investment fixture must show Running READY.")
	_expect_true(ready["automatic"], "Running readiness must expose the fixture's authoritative automatic proficiency.")
	_expect_equal(ready["effective_mr"], 11, "READY must show armor-adjusted walking MR before Running activates.")
	_expect_equal(movement.request_running(), PrimeMovement.RunningRequestResult.ACTIVATED, "Automatic Running must activate without a roll.")
	movement.advance(2_000_000, Vector2.RIGHT)
	var active := Readiness.get_running_readiness(movement.to_dictionary())
	_expect_equal(active["state"], Readiness.STATE_RUNNING, "Active Running must show RUNNING.")
	_expect_equal(active["remaining_us"], 48_000_000, "END 10 Running readiness must count down from the exact 50-second cap.")
	_expect_equal(active["effective_mr"], 17, "Active Running readiness must expose armor-adjusted MR 17.")
	movement.stop_running(PrimeMovement.RunningEndReason.SHIFT_RELEASED)
	var recovery := Readiness.get_running_readiness(movement.to_dictionary())
	_expect_equal(recovery["state"], Readiness.STATE_RECOVERING, "Voluntary stop must retain and display recovery debt.")
	_expect_equal(recovery["remaining_us"], 2_000_000, "Recovery countdown must equal actual Running time.")
	movement.advance(1_000_000, Vector2.ZERO)
	_expect_equal(Readiness.get_running_readiness(movement.to_dictionary())["remaining_us"], 1_000_000, "Standing must recover Running debt at 100 percent.")
	movement.advance(1_000_000, Vector2.RIGHT)
	_expect_equal(Readiness.get_running_readiness(movement.to_dictionary())["remaining_us"], 500_000, "Walking must recover Running debt at 50 percent.")

	var failed := PrimeMovement.new(12, 12, 10, 0, 0, 0, FixedRollSource.new(20))
	_expect_equal(failed.request_running(), PrimeMovement.RunningRequestResult.COOLDOWN, "A natural 20 fixture must enter the existing retry restriction.")
	var retry := Readiness.get_running_readiness(failed.to_dictionary())
	_expect_equal(retry["state"], Readiness.STATE_RETRY, "A failed Running check must show RETRY.")
	_expect_equal(retry["remaining_us"], 5_000_000, "RETRY must use the existing five-second restriction exactly.")
	var blocked := Readiness.get_running_readiness(movement.to_dictionary(), {"reason": "actor_prone", "label": "PRONE"})
	_expect_equal(blocked["state"], Readiness.STATE_BLOCKED, "A concurrent authoritative restriction must prevent false Running READY.")

	var endurance := PrimeMovement.new(12, 12, 10, 3, 0, 0)
	endurance.request_running()
	endurance.advance(50_000_000, Vector2.RIGHT)
	var capped := Readiness.get_running_readiness(endurance.to_dictionary())
	_expect_equal(capped["state"], Readiness.STATE_RECOVERING, "The exact END x 5-second boundary must end Running and enter recovery.")
	_expect_equal(capped["remaining_us"], 50_000_000, "The duration cap must preserve equal authoritative recovery debt.")


func _test_movement_running_and_attack_concurrency() -> void:
	var session := _legal_player_session()
	var started := session.request_player_attack("moving_attack")
	_expect_true(started.get("success", false), "The player must begin a legal attack before concurrent movement.")
	var movement := PrimeMovement.new(12, 12, 10, 3, 0, 0)
	_expect_equal(movement.request_running(), PrimeMovement.RunningRequestResult.ACTIVATED, "The verified automatic Running path must remain available during the attack fixture.")
	var displacement := movement.advance(500_000, Vector2.UP)
	var player_state := session.get_actor_state(Fixture.PLAYER_ID)
	var destination := player_state.position_microfeet + Vector2i(
		roundi(displacement.x * PrimeMovement.POSITION_UNITS_PER_FOOT),
		roundi(displacement.y * PrimeMovement.POSITION_UNITS_PER_FOOT)
	)
	var moved := session.request_player_movement(destination, movement.get_effective_mr())
	_expect_true(moved.get("success", false), "Legal Running movement must remain authoritative while an ordinary attack executes.")
	_expect_true(session.is_player_attack_in_flight(), "Movement and Running must not cancel the executing attack without a verified restriction.")
	session.advance_by(2_500_000)
	_expect_true(not _has_player_acc_event(session), "Final out-of-range or obstruction legality must fail before ACC after movement leaves reach.")

	var approaching := _player_opening_session(Vector2i(20_000_000, 12_000_000), Vector2i(26_000_000, 12_000_000))
	_expect_equal(Readiness.get_attack_readiness(approaching)["state"], Readiness.STATE_READY, "An ordinary Battle Axe attack must be READY to declare before reaching three-foot reach.")
	var approach_attack := approaching.request_player_attack("approach_during_execution")
	_expect_true(approach_attack.get("success", false), "The player must begin the approach-attack outside reach.")
	var approach_move := approaching.request_player_movement(Vector2i(23_000_000, 12_000_000), 12)
	_expect_true(approach_move.get("success", false), "Player approach during AT execution must use the existing authoritative movement transaction.")
	approaching.advance_by(2_500_000)
	_expect_true(_has_player_acc_event(approaching), "A Battle Axe approach-attack that reaches legal final geometry must proceed to ACC.")

	var failed_approach := _player_opening_session(Vector2i(20_000_000, 12_000_000), Vector2i(26_000_000, 12_000_000))
	_expect_true(failed_approach.request_player_attack("failed_approach").get("success", false), "An outside-reach declaration must still begin when the player does not approach.")
	failed_approach.advance_by(2_500_000)
	_expect_true(not _has_player_acc_event(failed_approach), "A player still outside Battle Axe reach at resolution must fail without ACC.")

	var two_way := _legal_player_session()
	two_way.set_opponent_behavior_enabled(true)
	var player_attack := two_way.request_player_attack("two_way")
	var opponent_attack_id := two_way.get_active_opponent_attack_id()
	_expect_true(player_attack.get("success", false) and not opponent_attack_id.is_empty(), "Both combatants must use the same legal concurrent attack pipeline.")
	var player_action := two_way.simulation.get_action(String(player_attack.get("action_instance_id", "")))
	var opponent_attack := two_way.simulation.get_attack(opponent_attack_id)
	var opponent_action := null if opponent_attack == null else two_way.simulation.get_action(opponent_attack.action_instance_id)
	_expect_true(player_action != null and opponent_action != null, "Both ordinary attacks must expose authoritative actions.")
	if player_action != null and opponent_action != null:
		_expect_equal(player_action.at_at_start, opponent_action.at_at_start, "Player and scripted opponent must use identical fixture AT rules.")
		_expect_equal(player_action.final_effect_due_at_us - player_action.started_at_us, opponent_action.final_effect_due_at_us - opponent_action.started_at_us, "Player and enemy attacks must use the same duration calculation.")


func _test_scene_reset_focus_and_indicators() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for readiness HUD integration test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var attack_indicator = scene.get_node("HUD/UI/AttackReadiness")
	var run_indicator = scene.get_node("HUD/UI/RunReadiness")
	_expect_equal(attack_indicator.get_readiness_for_testing()["state"], Readiness.STATE_BLOCKED, "The pre-start ATTACK indicator must not show stale READY.")
	_expect_equal(run_indicator.get_readiness_for_testing()["state"], Readiness.STATE_BLOCKED, "The pre-start RUN indicator must not show stale READY.")
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_attack_readiness_for_testing()["state"], Readiness.STATE_READY, "START must restore actual attack readiness.")
	_expect_equal(controller.get_run_readiness_for_testing()["state"], Readiness.STATE_READY, "START must restore actual Running readiness.")
	controller.set_application_focus_for_testing(false)
	_expect_equal(controller.get_attack_readiness_for_testing()["reason"], "presentation_unavailable", "Focus loss must not leave a stale ATTACK READY display.")
	_expect_equal(controller.get_run_readiness_for_testing()["reason"], "presentation_unavailable", "Focus loss must not leave a stale RUN READY display.")
	controller.set_application_focus_for_testing(true)
	controller.press_encounter_control_for_testing()
	_expect_equal(controller.get_attack_readiness_for_testing()["state"], Readiness.STATE_BLOCKED, "RESET must clear the old attack countdown and return to pre-start readiness.")
	_expect_equal(controller.get_run_readiness_for_testing()["state"], Readiness.STATE_BLOCKED, "RESET must clear Running readiness state and recovery presentation.")
	scene.free()


func _test_responsive_indicator_layout() -> void:
	for size: Vector2 in [Vector2(800, 360), Vector2(915, 412), Vector2(1280, 720), Vector2(360, 800)]:
		var layout := ResponsiveLayout.calculate_layout(size)
		var attack: Rect2 = layout["attack_readiness_rect"]
		var run: Rect2 = layout["run_readiness_rect"]
		var log: Rect2 = layout["combat_log_rect"]
		_expect_true(not attack.intersects(run), "ATTACK and RUN readiness indicators must not overlap.")
		_expect_true(not attack.intersects(log) and not run.intersects(log), "Readiness indicators must not cover combat results.")
		_expect_true(log.position.y - run.end.y >= 16.0 / float(layout["canvas_scale"]), "Combat results must retain readable vertical separation from readiness text.")
		_expect_true(attack.position.x >= 0.0 and attack.position.y >= 0.0 and attack.end.x <= size.x and attack.end.y <= size.y, "ATTACK indicator must remain inside the viewport.")
		_expect_true(run.position.x >= 0.0 and run.position.y >= 0.0 and run.end.x <= size.x and run.end.y <= size.y, "RUN indicator must remain inside the viewport.")
		_expect_true(attack.end.y <= float(layout["touch_control_top"]) and run.end.y <= float(layout["touch_control_top"]), "Readiness indicators must stay above mobile touch controls at %s: ATTACK bottom %.2f, RUN bottom %.2f, touch top %.2f." % [size, attack.end.y, run.end.y, float(layout["touch_control_top"])])


func _legal_player_session() -> ArenaCombatSession:
	return _player_opening_session(PLAYER_POSITION, OPPONENT_POSITION)


func _player_opening_session(player_position: Vector2i, opponent_position: Vector2i) -> ArenaCombatSession:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(player_position, opponent_position).get("success", false):
			continue
		if int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) == 0:
			return session
	_failures.append("No deterministic legal player-opening seed was found for readiness tests.")
	return ArenaCombatSession.new(1)


func _opponent_opening_session() -> ArenaCombatSession:
	for seed_value in range(1, 500):
		var session := ArenaCombatSession.new(seed_value)
		if not session.initialize(PLAYER_POSITION, OPPONENT_POSITION).get("success", false):
			continue
		if int(session.get_actor_state(Fixture.PLAYER_ID).opening_order_rank) > 0:
			return session
	_failures.append("No deterministic opponent-opening seed was found for readiness tests.")
	return ArenaCombatSession.new(1)


func _make_actor(actor_id: StringName, at_value: int) -> CombatActorDefinition:
	return CombatActorDefinition.new(
		actor_id,
		&"player",
		"Readiness Timing Fixture",
		{"str": 10, "spd": 10, "end": 10},
		{"hpm": 20, "acc": 10, "at": at_value, "init": 5, "mr": 10, "nal": 0, "rb": 0},
		{},
		PackedStringArray(),
		{},
		{}
	)


func _has_player_acc_event(session: ArenaCombatSession) -> bool:
	for event: CombatEvent in session.get_resolved_events():
		if String(event.event_type) == "physical_attack_accuracy_resolved" and event.source_actor_id == Fixture.PLAYER_ID:
			return true
	return false


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
