class_name PlaceholderPlayer
extends CharacterBody2D

const PrimeMovementModel = preload("res://scripts/movement/prime_movement_model.gd")
const DeterministicCombatRng = preload("res://scripts/combat/deterministic_rng.gd")

const HALF_SIZE: float = 16.0
const INTENTIONAL_STOP_GRACE_US: int = 100_000

# Test-profile values only; these do not define Aren or Garrick.
@export var test_base_mr: int = 30
@export var test_effective_spd: int = 10
@export var test_effective_end: int = 10
@export var test_running_skill_investment: int = 3
@export var test_skill_check_modifier: int = 0
@export var test_roll_bonus: int = 0
@export var test_rng_seed: int = 1_337

# Presentation conversion only. Canonical movement remains measured in feet.
@export var pixels_per_foot: float = 24.0
@export var movement_debug_label_path: NodePath

var _movement: PrimeMovementModel
var _movement_rng: DeterministicCombatRng
var _delta_us_remainder: float = 0.0
var _stationary_intent_us: int = 0
var _run_was_held: bool = false

@onready var _movement_debug_label: Label = get_node_or_null(movement_debug_label_path)


func _ready() -> void:
	assert(pixels_per_foot > 0.0, "Visual pixels-per-foot scale must be positive.")
	_movement_rng = DeterministicCombatRng.new(test_rng_seed)
	_movement = PrimeMovementModel.new(
		test_base_mr,
		test_effective_spd,
		test_effective_end,
		test_running_skill_investment,
		test_skill_check_modifier,
		test_roll_bonus,
		_movement_rng
	)
	_movement.position_feet = position / pixels_per_foot
	_update_debug_label()


func _physics_process(delta: float) -> void:
	_delta_us_remainder += delta * 1_000_000.0
	var delta_us := floori(_delta_us_remainder)
	_delta_us_remainder -= float(delta_us)

	var direction := Vector2.ZERO
	direction.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	direction.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var run_held := Input.is_physical_key_pressed(KEY_SHIFT)

	if not run_held and _run_was_held:
		_movement.stop_running(PrimeMovementModel.RunningEndReason.SHIFT_RELEASED)
	if direction.is_zero_approx():
		_stationary_intent_us += delta_us
		if _stationary_intent_us >= INTENTIONAL_STOP_GRACE_US:
			_movement.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)
	else:
		_stationary_intent_us = 0
		if run_held and not _movement.is_running():
			_movement.request_running()

	_movement.advance(delta_us, direction)
	_keep_inside_viewport()
	position = _movement.position_feet * pixels_per_foot
	_run_was_held = run_held
	_update_debug_label()


func _keep_inside_viewport() -> void:
	var viewport_size_feet := get_viewport_rect().size / pixels_per_foot
	var half_size_feet := HALF_SIZE / pixels_per_foot
	_movement.position_feet.x = clampf(
		_movement.position_feet.x,
		half_size_feet,
		viewport_size_feet.x - half_size_feet
	)
	_movement.position_feet.y = clampf(
		_movement.position_feet.y,
		half_size_feet,
		viewport_size_feet.y - half_size_feet
	)


func _update_debug_label() -> void:
	if _movement_debug_label == null:
		return
	var maintenance_text := "--"
	if _movement.is_running_automatic() and _movement.is_running():
		maintenance_text = "automatic (%.2f s to interval)" % _seconds(_movement.get_time_until_next_maintenance_us())
	elif _movement.is_running():
		maintenance_text = "%.2f s" % _seconds(_movement.get_time_until_next_maintenance_us())

	_movement_debug_label.text = (
		"Current MR: %d ft / 5 s\nRunning bonus: +%d MR\nRunning: %s\nLast check: %s\nNext maintenance: %s\nMaximum duration: %.2f s\nRecovery remaining: %.2f s\nRetry cooldown: %.2f s\nVisual scale: %.1f px / ft"
		% [
			_movement.get_effective_mr(),
			_movement.get_running_bonus_mr() if _movement.is_running() else 0,
			"active" if _movement.is_running() else "inactive",
			_movement.get_last_check_result_name(),
			maintenance_text,
			_seconds(_movement.get_max_running_duration_us()),
			_seconds(_movement.get_recovery_remaining_us()),
			_seconds(_movement.get_running_retry_cooldown_us()),
			pixels_per_foot,
		]
	)


func _seconds(value_us: int) -> float:
	return float(value_us) / 1_000_000.0
