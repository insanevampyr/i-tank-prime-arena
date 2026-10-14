extends RefCounted

const PrimeMovementModel = preload("res://scripts/movement/prime_movement_model.gd")
const RunningSkillCheckRule = preload("res://scripts/movement/running_skill_check.gd")
const CombatEventEnvelopeClass = preload("res://scripts/sync/combat_event_envelope.gd")
const ObservedCombatClientClass = preload("res://scripts/sync/observed_combat_client.gd")
const SynchronizationReportClass = preload("res://scripts/sync/synchronization_report.gd")

var _failures: Array[String] = []


class FixedRollSource:
	extends RefCounted

	var _rolls: Array = []
	var draw_count: int = 0

	func _init(rolls: Array) -> void:
		_rolls = rolls.duplicate()

	func next_int(min_inclusive: int, max_inclusive: int) -> int:
		assert(not _rolls.is_empty(), "Test roll source exhausted.")
		var value: int = _rolls.pop_front()
		assert(value >= min_inclusive and value <= max_inclusive, "Test roll is outside the requested range.")
		draw_count += 1
		return value


func run() -> Array[String]:
	_test_mr_distance_over_five_seconds()
	_test_running_skill_formula_and_rb()
	_test_running_skill_success_and_failure()
	_test_automatic_running_proficiency()
	_test_running_bonus_rounding_and_nonstacking()
	_test_five_second_maintenance_boundaries()
	_test_maintenance_failure_ends_running()
	_test_end_based_maximum_duration()
	_test_maximum_precedes_simultaneous_maintenance()
	_test_standing_recovery_full_rate()
	_test_walking_recovery_half_rate()
	_test_mixed_standing_and_walking_recovery()
	_test_failure_cooldown_and_recovery_are_independent()
	_test_shift_release_and_intentional_stop()
	_test_direction_changes_preserve_continuity()
	_test_single_zero_input_does_not_stop_running()
	_test_movement_modifiers_update_effective_speed()
	_test_repeated_simulation_is_reproducible()
	_test_two_clients_observe_same_authoritative_movement_state()
	return _failures


func _test_mr_distance_over_five_seconds() -> void:
	var model := PrimeMovementModel.new(30, 10, 10, 3)
	model.advance(PrimeMovementModel.ROUND_DURATION_US, Vector2.RIGHT)
	_expect_float(model.position_feet.x, 30.0, "MR must equal feet traveled over exactly five seconds.")


func _test_running_skill_formula_and_rb() -> void:
	_expect_equal(RunningSkillCheckRule.get_target(10, 1, 0), 5, "Untrained Running must apply its -2 modifier plus the general -4 untrained penalty and SCM.")
	_expect_equal(RunningSkillCheckRule.get_target(10, 1, 1), 9, "One Running investment must use END -2 plus SCM.")
	_expect_equal(RunningSkillCheckRule.get_target(10, 1, 2), 10, "The second Running investment must raise the skill modifier by one.")
	_expect_true(RunningSkillCheckRule.is_automatic(3), "Three Running investments must qualify as automatic.")

	var rb_success := RunningSkillCheckRule.resolve(10, 10, 0, 1, 2, "activation", 0)
	_expect_equal(rb_success["adjusted_roll"], 8, "RB must beneficially reduce a roll-under Running result.")
	_expect_true(rb_success["success"], "RB-adjusted roll at the target must succeed.")
	var natural_one := RunningSkillCheckRule.resolve(1, 1, -20, 1, 5, "activation", 1)
	_expect_equal(natural_one["result"], "critical_success", "Natural 1 must remain critical success regardless of target or RB.")
	var natural_twenty := RunningSkillCheckRule.resolve(20, 30, 20, 1, 10, "activation", 2)
	_expect_equal(natural_twenty["result"], "critical_failure", "Natural 20 must remain critical failure regardless of target or RB.")


func _test_running_skill_success_and_failure() -> void:
	var success := PrimeMovementModel.new(20, 8, 10, 1, 0, 0, FixedRollSource.new([8]))
	_expect_equal(success.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "A natural roll at the verified Running target must activate Running.")
	_expect_true(success.is_running(), "Successful activation must immediately enable Running.")

	var failure := PrimeMovementModel.new(20, 8, 10, 1, 0, 0, FixedRollSource.new([9]))
	_expect_equal(failure.request_running(), PrimeMovementModel.RunningRequestResult.COOLDOWN, "A roll above the Running target must fail activation and begin cooldown.")
	_expect_true(not failure.is_running(), "Failed activation must not grant the Running bonus.")
	_expect_equal(failure.get_running_retry_cooldown_us(), 5_000_000, "Failed activation must impose a five-second retry cooldown.")


func _test_automatic_running_proficiency() -> void:
	var model := PrimeMovementModel.new(20, 9, 2, 3)
	_expect_equal(model.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "Automatic Running must bypass activation rolls.")
	model.advance(5_000_000, Vector2.RIGHT)
	_expect_true(model.is_running(), "Automatic Running must bypass the five-second maintenance roll before its duration cap.")
	_expect_equal(model.get_last_check_result(), PrimeMovementModel.RunningCheckResult.AUTOMATIC_SUCCESS, "Automatic Running must report automatic success without fabricating a die result.")


func _test_running_bonus_rounding_and_nonstacking() -> void:
	var model := PrimeMovementModel.new(20, 7, 10, 3)
	model.request_running()
	_expect_equal(model.get_running_bonus_mr(), 3, "Running bonus must floor odd effective SPD divided by two.")
	_expect_equal(model.get_effective_mr(), 23, "Running bonus must be added once to walking MR.")
	model.request_running()
	model.request_running()
	_expect_equal(model.get_effective_mr(), 23, "Repeated Running requests must not stack the bonus.")


func _test_five_second_maintenance_boundaries() -> void:
	var rolls := FixedRollSource.new([8, 8])
	var model := PrimeMovementModel.new(20, 8, 2, 1, 8, 0, rolls)
	model.request_running()
	model.advance(4_999_999, Vector2.RIGHT)
	_expect_equal(rolls.draw_count, 1, "Maintenance must not roll before five continuous seconds.")
	_expect_equal(model.get_time_until_next_maintenance_us(), 1, "Maintenance timer must preserve the exact microsecond boundary.")
	model.advance(1, Vector2.RIGHT)
	_expect_equal(rolls.draw_count, 2, "Maintenance must roll exactly at five continuous seconds.")
	_expect_true(model.is_running(), "Successful maintenance must preserve Running.")
	_expect_equal(model.get_time_until_next_maintenance_us(), 5_000_000, "Successful maintenance must schedule the next five-second boundary.")


func _test_maintenance_failure_ends_running() -> void:
	var model := PrimeMovementModel.new(20, 8, 2, 1, 8, 0, FixedRollSource.new([8, 9]))
	model.request_running()
	model.advance(5_000_000, Vector2.RIGHT)
	_expect_true(not model.is_running(), "Failed maintenance must end Running immediately.")
	_expect_equal(model.get_last_end_reason(), PrimeMovementModel.RunningEndReason.MAINTENANCE_FAILURE, "Maintenance failure must be recorded as the end reason.")
	_expect_equal(model.get_recovery_remaining_us(), 5_000_000, "Maintenance failure must retain recovery equal to actual Running time.")
	_expect_equal(model.get_running_retry_cooldown_us(), 5_000_000, "Maintenance failure must also start the five-second cooldown.")


func _test_end_based_maximum_duration() -> void:
	var model := PrimeMovementModel.new(20, 8, 2, 3)
	model.request_running()
	_expect_equal(model.get_max_running_duration_us(), 10_000_000, "Maximum Running duration must equal END times five seconds.")
	model.advance(9_999_999, Vector2.RIGHT)
	_expect_true(model.is_running(), "Running must remain active before the END-based maximum.")
	model.advance(1, Vector2.RIGHT)
	_expect_true(not model.is_running(), "Running must end exactly at the END-based maximum.")
	_expect_equal(model.get_last_end_reason(), PrimeMovementModel.RunningEndReason.DURATION_CAP, "The maximum duration must produce the duration-cap reason.")
	_expect_equal(model.get_recovery_remaining_us(), 10_000_000, "Duration-cap recovery must equal actual Running time.")


func _test_maximum_precedes_simultaneous_maintenance() -> void:
	var rolls := FixedRollSource.new([8, 20])
	var model := PrimeMovementModel.new(20, 8, 1, 1, 9, 0, rolls)
	model.request_running()
	model.advance(5_000_000, Vector2.RIGHT)
	_expect_equal(rolls.draw_count, 1, "The END-based cap must suppress a maintenance roll at the same timestamp.")
	_expect_equal(model.get_last_end_reason(), PrimeMovementModel.RunningEndReason.DURATION_CAP, "Duration cap must win simultaneous maintenance timing.")
	_expect_equal(model.get_running_retry_cooldown_us(), 0, "A duration cap must not fabricate a failed-check cooldown.")


func _test_standing_recovery_full_rate() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.request_running()
	model.advance(2_000_000, Vector2.RIGHT)
	model.stop_running()
	_expect_equal(model.get_recovery_remaining_us(), 2_000_000, "Stopping must preserve recovery equal to actual Running time.")
	model.advance(2_000_000, Vector2.ZERO)
	_expect_equal(model.get_recovery_remaining_us(), 0, "Standing must restore recovery at 100 percent.")


func _test_walking_recovery_half_rate() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.request_running()
	model.advance(2_000_000, Vector2.RIGHT)
	model.stop_running()
	model.advance(2_000_000, Vector2.RIGHT)
	_expect_equal(model.get_recovery_remaining_us(), 1_000_000, "Two seconds walking must clear one second of recovery.")
	model.advance(2_000_000, Vector2.RIGHT)
	_expect_equal(model.get_recovery_remaining_us(), 0, "Walking must clear recovery at exactly 50 percent.")


func _test_mixed_standing_and_walking_recovery() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.request_running()
	model.advance(4_000_000, Vector2.RIGHT)
	model.stop_running()
	model.advance(1_000_000, Vector2.ZERO)
	model.advance(4_000_000, Vector2.RIGHT)
	_expect_equal(model.get_recovery_remaining_us(), 1_000_000, "Mixed standing and walking credits must combine without rounding loss.")
	model.advance(1_000_000, Vector2.ZERO)
	_expect_equal(model.get_recovery_remaining_us(), 0, "Final standing credit must clear mixed recovery exactly.")


func _test_failure_cooldown_and_recovery_are_independent() -> void:
	var model := PrimeMovementModel.new(20, 8, 2, 1, 8, 0, FixedRollSource.new([8, 9, 8]))
	model.request_running()
	model.advance(5_000_000, Vector2.RIGHT)
	model.advance(5_000_000, Vector2.RIGHT)
	_expect_equal(model.get_running_retry_cooldown_us(), 0, "Walking must let failed-check cooldown expire with simulation time.")
	_expect_equal(model.get_recovery_remaining_us(), 2_500_000, "Cooldown expiry must not erase recovery debt.")
	_expect_equal(model.request_running(), PrimeMovementModel.RunningRequestResult.RECOVERY_REQUIRED, "Outstanding recovery must block Shift tapping after cooldown.")
	model.advance(2_500_000, Vector2.ZERO)
	_expect_equal(model.request_running(), PrimeMovementModel.RunningRequestResult.ACTIVATED, "Running may restart only after both cooldown and recovery expire.")


func _test_shift_release_and_intentional_stop() -> void:
	var shift_release := PrimeMovementModel.new(20, 8, 10, 3)
	shift_release.request_running()
	shift_release.advance(1_000_000, Vector2.RIGHT)
	shift_release.stop_running(PrimeMovementModel.RunningEndReason.SHIFT_RELEASED)
	_expect_true(not shift_release.is_running(), "Shift release must end Running.")
	_expect_equal(shift_release.get_last_end_reason(), PrimeMovementModel.RunningEndReason.SHIFT_RELEASED, "Shift release must be distinguishable in state.")
	_expect_equal(shift_release.request_running(), PrimeMovementModel.RunningRequestResult.RECOVERY_REQUIRED, "Shift tapping must not bypass accrued recovery.")

	var intentional_stop := PrimeMovementModel.new(20, 8, 10, 3)
	intentional_stop.request_running()
	intentional_stop.advance(1_000_000, Vector2.RIGHT)
	intentional_stop.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)
	_expect_equal(intentional_stop.get_last_end_reason(), PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP, "Intentional movement stop must be recorded separately.")


func _test_direction_changes_preserve_continuity() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.request_running()
	model.advance(1_000_000, Vector2.RIGHT)
	var before_turn := model.position_feet
	model.advance(1_000_000, Vector2.UP)
	var turn_displacement := model.position_feet - before_turn
	_expect_true(model.is_running(), "A direction change must not end Running.")
	_expect_true(turn_displacement.x > 0.0 and turn_displacement.y < 0.0, "A sharp Running turn must be limited to a continuous legal 45-degree adjustment.")


func _test_single_zero_input_does_not_stop_running() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.request_running()
	model.advance(16_667, Vector2.ZERO)
	_expect_true(model.is_running(), "A dropped zero-input frame must not be interpreted as an intentional stop.")


func _test_movement_modifiers_update_effective_speed() -> void:
	var model := PrimeMovementModel.new(20, 8, 10, 3)
	model.set_movement_modifier_mr(-3)
	_expect_equal(model.get_effective_mr(), 17, "Walking movement modifiers must update effective MR.")
	model.request_running()
	_expect_equal(model.get_effective_mr(), 21, "Running must use current modified MR plus one SPD-derived bonus.")
	model.set_effective_spd(11)
	_expect_equal(model.get_effective_mr(), 22, "Running bonus must update from current effective SPD.")


func _test_repeated_simulation_is_reproducible() -> void:
	var first := PrimeMovementModel.new(24, 9, 3, 1, 7, 1, FixedRollSource.new([9, 9]))
	var second := PrimeMovementModel.new(24, 9, 3, 1, 7, 1, FixedRollSource.new([9, 9]))
	first.request_running()
	second.request_running()
	first.advance(6_000_000, Vector2.RIGHT)
	second.advance(6_000_000, Vector2.RIGHT)
	_expect_equal(SyncStateDigest.compute(first.to_dictionary()), SyncStateDigest.compute(second.to_dictionary()), "Equal authoritative rolls and movement inputs must reproduce the same Running state.")


func _test_two_clients_observe_same_authoritative_movement_state() -> void:
	var authority := PrimeMovementModel.new(24, 9, 3, 1, 7, 1, FixedRollSource.new([9, 9]))
	authority.request_running()
	authority.advance(6_000_000, Vector2.RIGHT)
	var envelope := CombatEventEnvelopeClass.new(0, {
		"event_type": "authoritative_movement_state",
		"movement_state": authority.to_dictionary(),
	})
	var client_a := ObservedCombatClientClass.new("movement_client_a")
	var client_b := ObservedCombatClientClass.new("movement_client_b")
	client_a.receive(envelope)
	client_b.receive(envelope)
	var report := SynchronizationReportClass.compare_clients([client_a, client_b])
	_expect_true(report["success"], "Two passive clients must converge on the same authoritative movement snapshot.")
	_expect_equal(client_a.get_state_digest(), client_b.get_state_digest(), "Both clients must report the same movement-state transcript digest.")


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_float(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
