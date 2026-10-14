class_name PrimeMovementModel
extends RefCounted

const RunningSkillCheckRule = preload("res://scripts/movement/running_skill_check.gd")

enum RunningCheckResult {
	NOT_ATTEMPTED,
	SUCCESS,
	FAILURE,
	CRITICAL_SUCCESS,
	CRITICAL_FAILURE,
	AUTOMATIC_SUCCESS,
}

enum RunningRequestResult {
	ACTIVATED,
	ALREADY_RUNNING,
	COOLDOWN,
	RECOVERY_REQUIRED,
}

enum RunningEndReason {
	NONE,
	SHIFT_RELEASED,
	INTENTIONAL_STOP,
	MAINTENANCE_FAILURE,
	DURATION_CAP,
}

const ROUND_DURATION_US: int = 5_000_000
const RUNNING_MAINTENANCE_INTERVAL_US: int = 5_000_000
const RUNNING_RETRY_COOLDOWN_US: int = 5_000_000
const MAX_RUNNING_DIRECTION_CHANGE_RADIANS: float = deg_to_rad(45.0)
const POSITION_UNITS_PER_FOOT: int = 1_000_000
const RECOVERY_UNITS_PER_MICROSECOND: int = 2

var base_mr: int
var effective_spd: int
var effective_end: int
var running_skill_investment: int
var skill_check_modifier: int
var roll_bonus: int
var position_feet: Vector2 = Vector2.ZERO

var _roll_source: Object
var _movement_modifier_mr: int = 0
var _is_running: bool = false
var _running_elapsed_us: int = 0
var _next_maintenance_at_us: int = RUNNING_MAINTENANCE_INTERVAL_US
var _recovery_remaining_units: int = 0
var _running_retry_cooldown_us: int = 0
var _last_check_result: RunningCheckResult = RunningCheckResult.NOT_ATTEMPTED
var _last_check_evidence: Dictionary = {}
var _last_end_reason: RunningEndReason = RunningEndReason.NONE
var _last_run_duration_us: int = 0
var _running_check_sequence: int = 0
var _last_movement_direction: Vector2 = Vector2.ZERO


func _init(
	p_base_mr: int,
	p_effective_spd: int,
	p_effective_end: int,
	p_running_skill_investment: int = 0,
	p_skill_check_modifier: int = 0,
	p_roll_bonus: int = 0,
	p_roll_source: Object = null
) -> void:
	assert(p_base_mr >= 0, "Base MR cannot be negative.")
	assert(p_effective_spd >= 0, "Effective SPD cannot be negative.")
	assert(p_effective_end > 0, "Effective END must be positive for Running.")
	assert(p_running_skill_investment >= 0, "Running Skill investment cannot be negative.")
	assert(p_roll_bonus >= 0, "Roll Bonus cannot be negative.")
	if not RunningSkillCheckRule.is_automatic(p_running_skill_investment):
		assert(p_roll_source != null and p_roll_source.has_method("next_int"), "Nonautomatic Running requires an authoritative d20 source.")

	base_mr = p_base_mr
	effective_spd = p_effective_spd
	effective_end = p_effective_end
	running_skill_investment = p_running_skill_investment
	skill_check_modifier = p_skill_check_modifier
	roll_bonus = p_roll_bonus
	_roll_source = p_roll_source


func set_movement_modifier_mr(value: int) -> void:
	_movement_modifier_mr = value


func set_effective_spd(value: int) -> void:
	assert(value >= 0, "Effective SPD cannot be negative.")
	effective_spd = value


func get_walking_mr() -> int:
	return maxi(0, base_mr + _movement_modifier_mr)


func get_running_bonus_mr() -> int:
	return floori(float(effective_spd) / 2.0)


func get_effective_mr() -> int:
	if _is_running:
		return get_walking_mr() + get_running_bonus_mr()
	return get_walking_mr()


func get_speed_feet_per_second() -> float:
	return float(get_effective_mr()) / 5.0


func get_running_check_target() -> int:
	return RunningSkillCheckRule.get_target(effective_end, skill_check_modifier, running_skill_investment)


func is_running_automatic() -> bool:
	return RunningSkillCheckRule.is_automatic(running_skill_investment)


func is_running() -> bool:
	return _is_running


func get_running_elapsed_us() -> int:
	return _running_elapsed_us


func get_max_running_duration_us() -> int:
	return effective_end * ROUND_DURATION_US


func get_time_until_next_maintenance_us() -> int:
	if not _is_running:
		return 0
	return maxi(0, _next_maintenance_at_us - _running_elapsed_us)


func get_recovery_remaining_us() -> int:
	return ceili(float(_recovery_remaining_units) / float(RECOVERY_UNITS_PER_MICROSECOND))


func get_running_retry_cooldown_us() -> int:
	return _running_retry_cooldown_us


func get_last_check_result() -> RunningCheckResult:
	return _last_check_result


func get_last_check_result_name() -> String:
	return RunningCheckResult.keys()[_last_check_result].to_lower()


func get_last_check_evidence() -> Dictionary:
	return _last_check_evidence.duplicate(true)


func get_last_end_reason() -> RunningEndReason:
	return _last_end_reason


func get_last_end_reason_name() -> String:
	return RunningEndReason.keys()[_last_end_reason].to_lower()


func get_last_run_duration_us() -> int:
	return _last_run_duration_us


func request_running() -> RunningRequestResult:
	if _is_running:
		return RunningRequestResult.ALREADY_RUNNING
	if _running_retry_cooldown_us > 0:
		return RunningRequestResult.COOLDOWN
	if _recovery_remaining_units > 0:
		return RunningRequestResult.RECOVERY_REQUIRED

	_last_end_reason = RunningEndReason.NONE
	if is_running_automatic():
		_last_check_result = RunningCheckResult.AUTOMATIC_SUCCESS
		_last_check_evidence = {
			"check_kind": "activation",
			"result": "automatic_success",
			"skill_investment": running_skill_investment,
			"source": "PRIME-V3 pp. 67, 69, 105-106",
		}
		_begin_running()
		return RunningRequestResult.ACTIVATED

	var evidence := _perform_running_check("activation")
	if evidence["success"]:
		_begin_running()
		return RunningRequestResult.ACTIVATED
	_running_retry_cooldown_us = RUNNING_RETRY_COOLDOWN_US
	return RunningRequestResult.COOLDOWN


func stop_running(reason: RunningEndReason = RunningEndReason.INTENTIONAL_STOP) -> void:
	assert(reason == RunningEndReason.SHIFT_RELEASED or reason == RunningEndReason.INTENTIONAL_STOP, "External stops must be intentional or a Shift release.")
	if not _is_running:
		return
	_end_running(reason)


func advance(delta_us: int, requested_direction: Vector2) -> Vector2:
	assert(delta_us >= 0, "Movement advancement cannot be negative.")
	if delta_us == 0:
		return Vector2.ZERO

	var remaining_us := delta_us
	var total_displacement := Vector2.ZERO
	var direction := Vector2.ZERO if requested_direction.is_zero_approx() else requested_direction.normalized()

	while remaining_us > 0:
		if not _is_running:
			total_displacement += _advance_not_running(remaining_us, direction)
			remaining_us = 0
			continue

		var until_maintenance := _next_maintenance_at_us - _running_elapsed_us
		var until_maximum := get_max_running_duration_us() - _running_elapsed_us
		var running_step_us: int = mini(remaining_us, mini(until_maintenance, until_maximum))
		if running_step_us > 0:
			total_displacement += _advance_position(running_step_us, direction)
			_running_elapsed_us += running_step_us
			_recovery_remaining_units += running_step_us * RECOVERY_UNITS_PER_MICROSECOND
			remaining_us -= running_step_us

		# The approved duration cap wins when it shares a timestamp with maintenance.
		if _running_elapsed_us >= get_max_running_duration_us():
			_end_running(RunningEndReason.DURATION_CAP)
			continue

		if _running_elapsed_us >= _next_maintenance_at_us:
			_next_maintenance_at_us += RUNNING_MAINTENANCE_INTERVAL_US
			if is_running_automatic():
				continue
			var evidence := _perform_running_check("maintenance")
			if not evidence["success"]:
				_end_running(RunningEndReason.MAINTENANCE_FAILURE)
				_running_retry_cooldown_us = RUNNING_RETRY_COOLDOWN_US

	return total_displacement


func to_dictionary() -> Dictionary:
	return {
		"base_mr": base_mr,
		"effective_spd": effective_spd,
		"effective_end": effective_end,
		"movement_modifier_mr": _movement_modifier_mr,
		"running_skill_investment": running_skill_investment,
		"skill_check_modifier": skill_check_modifier,
		"roll_bonus": roll_bonus,
		"running_check_target": get_running_check_target(),
		"position_microfeet": [
			roundi(position_feet.x * POSITION_UNITS_PER_FOOT),
			roundi(position_feet.y * POSITION_UNITS_PER_FOOT),
		],
		"is_running": _is_running,
		"running_elapsed_us": _running_elapsed_us,
		"maximum_running_duration_us": get_max_running_duration_us(),
		"next_maintenance_at_us": _next_maintenance_at_us,
		"recovery_remaining_units": _recovery_remaining_units,
		"running_retry_cooldown_us": _running_retry_cooldown_us,
		"last_check_result": get_last_check_result_name(),
		"last_check_evidence": _last_check_evidence.duplicate(true),
		"last_end_reason": get_last_end_reason_name(),
		"last_run_duration_us": _last_run_duration_us,
		"running_check_sequence": _running_check_sequence,
	}


func _begin_running() -> void:
	_is_running = true
	_running_elapsed_us = 0
	_next_maintenance_at_us = RUNNING_MAINTENANCE_INTERVAL_US
	_last_run_duration_us = 0
	_last_movement_direction = Vector2.ZERO


func _end_running(reason: RunningEndReason) -> void:
	_last_run_duration_us = _running_elapsed_us
	_is_running = false
	_running_elapsed_us = 0
	_next_maintenance_at_us = RUNNING_MAINTENANCE_INTERVAL_US
	_last_end_reason = reason
	_last_movement_direction = Vector2.ZERO


func _perform_running_check(check_kind: String) -> Dictionary:
	var raw_roll: int = _roll_source.next_int(1, 20)
	var evidence := RunningSkillCheckRule.resolve(
		raw_roll,
		effective_end,
		skill_check_modifier,
		running_skill_investment,
		roll_bonus,
		check_kind,
		_running_check_sequence
	)
	_running_check_sequence += 1
	_last_check_evidence = evidence.duplicate(true)
	match evidence["result"]:
		"critical_success":
			_last_check_result = RunningCheckResult.CRITICAL_SUCCESS
		"critical_failure":
			_last_check_result = RunningCheckResult.CRITICAL_FAILURE
		"success":
			_last_check_result = RunningCheckResult.SUCCESS
		_:
			_last_check_result = RunningCheckResult.FAILURE
	return evidence


func _advance_not_running(delta_us: int, direction: Vector2) -> Vector2:
	_running_retry_cooldown_us = maxi(0, _running_retry_cooldown_us - delta_us)
	var recovery_credit_units := delta_us * RECOVERY_UNITS_PER_MICROSECOND
	if not direction.is_zero_approx():
		recovery_credit_units = delta_us
	_recovery_remaining_units = maxi(0, _recovery_remaining_units - recovery_credit_units)
	return _advance_position(delta_us, direction)


func _advance_position(delta_us: int, requested_direction: Vector2) -> Vector2:
	if requested_direction.is_zero_approx():
		return Vector2.ZERO
	var direction := _limit_running_direction_change(requested_direction)
	var distance_feet := get_speed_feet_per_second() * (float(delta_us) / 1_000_000.0)
	var displacement := direction * distance_feet
	position_feet += displacement
	_last_movement_direction = direction
	return displacement


func _limit_running_direction_change(requested_direction: Vector2) -> Vector2:
	if not _is_running or _last_movement_direction.is_zero_approx():
		return requested_direction
	var angle := _last_movement_direction.angle_to(requested_direction)
	if absf(angle) <= MAX_RUNNING_DIRECTION_CHANGE_RADIANS:
		return requested_direction
	return _last_movement_direction.rotated(
		clampf(angle, -MAX_RUNNING_DIRECTION_CHANGE_RADIANS, MAX_RUNNING_DIRECTION_CHANGE_RADIANS)
	).normalized()
