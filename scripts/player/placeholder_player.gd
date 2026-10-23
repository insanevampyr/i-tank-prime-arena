class_name PlaceholderPlayer
extends CharacterBody2D

const PrimeMovementModel = preload("res://scripts/movement/prime_movement_model.gd")
const DeterministicCombatRng = preload("res://scripts/combat/deterministic_rng.gd")
const ArenaPlayerInputIntent = preload("res://scripts/input/arena_player_input_intent.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")

const HALF_SIZE: float = 16.0
const INTENTIONAL_STOP_GRACE_US: int = 100_000
const FORCE_SHIELD_COLOR := Color(0.35, 0.9, 1.0, 0.82)
const FORCE_SHIELD_GLOW_COLOR := Color(0.35, 0.9, 1.0, 0.24)

# Test-profile values only; these do not define Aren or Garrick.
@export var test_base_mr: int = 11
@export var test_effective_spd: int = 12
@export var test_effective_end: int = 10
@export var test_running_skill_investment: int = Fixture.PLAYER_RUNNING_SKILL_INVESTMENT
@export var test_skill_check_modifier: int = Fixture.PLAYER_RUNNING_SCM
@export var test_roll_bonus: int = 0
@export var test_rng_seed: int = Fixture.PLAYER_RUNNING_RNG_SEED

# Presentation conversion only. Canonical movement remains measured in feet.
@export var pixels_per_foot: float = 24.0
@export var movement_debug_label_path: NodePath
@export var touch_controls_path: NodePath

var _movement: PrimeMovementModel
var _movement_rng: DeterministicCombatRng
var _delta_us_remainder: float = 0.0
var _stationary_intent_us: int = 0
var _run_was_held: bool = false
var _combat_movement_locked: bool = false
var _authoritative_movement_resolver: Callable
var _force_shield_visual_active: bool = false

@onready var _movement_debug_label: Label = get_node_or_null(movement_debug_label_path)
@onready var _touch_controls: Node = get_node_or_null(touch_controls_path)


func _ready() -> void:
	assert(pixels_per_foot > 0.0, "Visual pixels-per-foot scale must be positive.")
	_reset_movement_model(position / pixels_per_foot)
	_update_debug_label()
	queue_redraw()


func _draw() -> void:
	if not _force_shield_visual_active:
		return
	draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 48, FORCE_SHIELD_GLOW_COLOR, 5.0, true)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 48, FORCE_SHIELD_COLOR, 2.0, true)


func reset_for_encounter(position_feet: Vector2) -> void:
	_reset_movement_model(position_feet)
	position = position_feet * pixels_per_foot
	_update_debug_label()


func _reset_movement_model(position_feet: Vector2) -> void:
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
	_movement.position_feet = position_feet
	_delta_us_remainder = 0.0
	_stationary_intent_us = 0
	_run_was_held = false
	_combat_movement_locked = false


func _physics_process(delta: float) -> void:
	_delta_us_remainder += delta * 1_000_000.0
	var delta_us := floori(_delta_us_remainder)
	_delta_us_remainder -= float(delta_us)

	var wasd_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var arrow_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	)
	var viewport := get_viewport()
	var keyboard_blocked := viewport != null and viewport.gui_get_focus_owner() != null
	var desktop_direction := resolve_keyboard_direction(wasd_direction, arrow_direction, keyboard_blocked)
	var touch_direction: Vector2 = Vector2.ZERO if _touch_controls == null else _touch_controls.get_movement_vector()
	var direction := ArenaPlayerInputIntent.combine_movement(desktop_direction, touch_direction)
	var touch_run_held: bool = false if _touch_controls == null else _touch_controls.is_run_held()
	var keyboard_run_held := resolve_keyboard_run(Input.is_physical_key_pressed(KEY_SHIFT), keyboard_blocked)
	var run_held := ArenaPlayerInputIntent.combine_run(keyboard_run_held, touch_run_held)
	if _movement.is_prone():
		run_held = false
	if _combat_movement_locked:
		direction = Vector2.ZERO
		run_held = false

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
	if _authoritative_movement_resolver.is_valid():
		var desired_microfeet := Vector2i(
			roundi(_movement.position_feet.x * PrimeMovementModel.POSITION_UNITS_PER_FOOT),
			roundi(_movement.position_feet.y * PrimeMovementModel.POSITION_UNITS_PER_FOOT)
		)
		var movement_result: Dictionary = _authoritative_movement_resolver.call(desired_microfeet, _movement.get_effective_mr())
		var authoritative_microfeet: Vector2i = movement_result.get("position_microfeet", desired_microfeet)
		_movement.position_feet = Vector2(authoritative_microfeet) / float(PrimeMovementModel.POSITION_UNITS_PER_FOOT)
	position = _movement.position_feet * pixels_per_foot
	_run_was_held = run_held
	_update_debug_label()


static func resolve_keyboard_direction(wasd_direction: Vector2, arrow_direction: Vector2, keyboard_blocked: bool) -> Vector2:
	if keyboard_blocked:
		return Vector2.ZERO
	return ArenaPlayerInputIntent.combine_keyboard_movement(wasd_direction, arrow_direction)


static func resolve_keyboard_run(shift_pressed: bool, keyboard_blocked: bool) -> bool:
	return shift_pressed and not keyboard_blocked


func apply_authoritative_combat_position(position_feet: Vector2) -> void:
	if _movement == null:
		return
	_movement.position_feet = position_feet
	position = position_feet * pixels_per_foot


func set_combat_movement_locked(locked: bool) -> void:
	_combat_movement_locked = locked
	if locked and _movement != null:
		_movement.stop_running(PrimeMovementModel.RunningEndReason.INTENTIONAL_STOP)


func set_prone(prone: bool) -> void:
	if _movement != null:
		_movement.set_prone(prone)


func set_authoritative_movement_resolver(resolver: Callable) -> void:
	_authoritative_movement_resolver = resolver


func set_force_shield_visual_active(active: bool) -> void:
	if _force_shield_visual_active == active:
		return
	_force_shield_visual_active = active
	queue_redraw()


func is_force_shield_visual_active_for_testing() -> bool:
	return _force_shield_visual_active


func get_movement_state_for_testing() -> Dictionary:
	return {} if _movement == null else _movement.to_dictionary()


func configure_authoritative_actor_profile(actor_definition: CombatActorDefinition) -> Dictionary:
	if actor_definition == null:
		return {"success": false, "reason": "missing_actor_definition"}
	for field_name: String in ["mr", "rb"]:
		if actor_definition.get_combat_stat(field_name) == null:
			return {"success": false, "reason": "unresolved_running_profile", "field": field_name}
	for field_name: String in ["spd", "end"]:
		if not actor_definition.attributes.has(field_name):
			return {"success": false, "reason": "unresolved_running_profile", "field": field_name}
	test_base_mr = int(actor_definition.get_combat_stat("mr"))
	test_effective_spd = int(actor_definition.attributes["spd"])
	test_effective_end = int(actor_definition.attributes["end"])
	test_roll_bonus = int(actor_definition.get_combat_stat("rb"))
	test_running_skill_investment = int(actor_definition.combat_stats.get("running_skill_investment", Fixture.PLAYER_RUNNING_SKILL_INVESTMENT))
	test_skill_check_modifier = int(actor_definition.combat_stats.get("running_scm", Fixture.PLAYER_RUNNING_SCM))
	if _movement != null:
		_reset_movement_model(_movement.position_feet)
	return validate_running_profile(actor_definition)


func validate_running_profile(actor_definition: CombatActorDefinition) -> Dictionary:
	if actor_definition == null:
		return {"success": false, "reason": "missing_actor_definition"}
	var expected := {
		"base_mr": actor_definition.get_combat_stat("mr"),
		"effective_spd": actor_definition.attributes.get("spd"),
		"effective_end": actor_definition.attributes.get("end"),
		"roll_bonus": actor_definition.get_combat_stat("rb"),
		"running_skill_investment": actor_definition.combat_stats.get("running_skill_investment", Fixture.PLAYER_RUNNING_SKILL_INVESTMENT),
		"skill_check_modifier": actor_definition.combat_stats.get("running_scm", Fixture.PLAYER_RUNNING_SCM),
	}
	var actual := {
		"base_mr": test_base_mr,
		"effective_spd": test_effective_spd,
		"effective_end": test_effective_end,
		"roll_bonus": test_roll_bonus,
		"running_skill_investment": test_running_skill_investment,
		"skill_check_modifier": test_skill_check_modifier,
	}
	for field_name: String in expected:
		if expected[field_name] == null:
			return {"success": false, "reason": "unresolved_running_profile", "field": field_name}
		if actual[field_name] != expected[field_name]:
			return {"success": false, "reason": "running_profile_mismatch", "field": field_name}
	return {"success": true, "profile": actual, "running_target": _movement.get_running_check_target()}


func _update_debug_label() -> void:
	if _movement_debug_label == null:
		return
	var run_state := "ACTIVE" if _movement.is_running() else "READY"
	if _movement.is_prone():
		run_state = "BLOCKED: PRONE"
	elif _movement.get_recovery_remaining_us() > 0:
		run_state = "RECOVERING"
	elif _movement.get_running_retry_cooldown_us() > 0:
		run_state = "RETRY WAIT"
	_movement_debug_label.text = (
		"MOVEMENT  MR %d%s | %s\nRUNNING  %s | Recovery %.1f s | Retry %.1f s"
		% [
			_movement.get_effective_mr(),
			" (+%d)" % _movement.get_running_bonus_mr() if _movement.is_running() else "",
			"PRONE CRAWL" if _movement.is_prone() else "STANDING",
			run_state,
			_seconds(_movement.get_recovery_remaining_us()),
			_seconds(_movement.get_running_retry_cooldown_us()),
		]
	)


func _seconds(value_us: int) -> float:
	return float(value_us) / 1_000_000.0
