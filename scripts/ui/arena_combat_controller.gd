class_name ArenaCombatController
extends Node

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const EventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")

const MAX_LOG_LINES := 12
const TARGET_PICK_RADIUS_PIXELS := 40.0

@export var combat_seed: int = ArenaCombatSession.DEFAULT_SEED
@export var player_path: NodePath
@export var opponent_path: NodePath
@export var touch_controls_path: NodePath
@export var player_hpc_label_path: NodePath
@export var opponent_hpc_label_path: NodePath
@export var combat_status_path: NodePath
@export var event_log_path: NodePath
@export var target_indicator_path: NodePath
@export var encounter_button_path: NodePath

var _session: ArenaCombatSession
var _delta_us_remainder: float = 0.0
var _event_cursor: int = 0
var _log_lines: Array[String] = []
var _applied_displacement_event_ids: Dictionary = {}
var _last_ui_message := "Press START to begin the deterministic test encounter."
var _initial_player_position_pixels := Vector2.ZERO
var _initial_opponent_position_pixels := Vector2.ZERO

@onready var _player: PlaceholderPlayer = get_node_or_null(player_path)
@onready var _opponent: Node2D = get_node_or_null(opponent_path)
@onready var _touch_controls: MobileTouchControls = get_node_or_null(touch_controls_path)
@onready var _player_hpc_label: Label = get_node_or_null(player_hpc_label_path)
@onready var _opponent_hpc_label: Label = get_node_or_null(opponent_hpc_label_path)
@onready var _combat_status: Label = get_node_or_null(combat_status_path)
@onready var _event_log: RichTextLabel = get_node_or_null(event_log_path)
@onready var _target_indicator: Line2D = get_node_or_null(target_indicator_path)
@onready var _encounter_button: Button = get_node_or_null(encounter_button_path)


func _ready() -> void:
	assert(_player != null, "Playable combat requires the existing player node.")
	assert(_opponent != null, "Playable combat requires the opponent presentation node.")
	_place_initial_combatants()
	_initial_player_position_pixels = _player.position
	_initial_opponent_position_pixels = _opponent.position
	_session = ArenaCombatSession.new(combat_seed)
	_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_session.set_opponent_behavior_enabled(true)
	var setup := _session.initialize(_node_position_microfeet(_player), _node_position_microfeet(_opponent), false)
	if not setup.get("success", false):
		_last_ui_message = "Combat fixture blocked: %s" % String(setup.get("reason", "unknown setup failure"))
	else:
		_session.select_target(Fixture.OPPONENT_ID)
		_append_log("Verified Prime V3 fixture ready; no production character data is claimed.")
	_player.set_authoritative_movement_resolver(_resolve_player_movement)
	if _encounter_button != null and not _encounter_button.pressed.is_connected(_on_encounter_button_pressed):
		_encounter_button.pressed.connect(_on_encounter_button_pressed)
	_process_new_events()
	_update_combat_movement_lock()
	_update_presentation()


func _physics_process(delta: float) -> void:
	if _session == null:
		return
	if _touch_controls != null and _touch_controls.consume_attack_requested():
		_request_attack("touch")
	_delta_us_remainder += delta * 1_000_000.0
	var delta_us := floori(_delta_us_remainder)
	_delta_us_remainder -= float(delta_us)
	_session.advance_by(delta_us)
	_process_new_events()
	_apply_authoritative_combat_displacements()
	_update_combat_movement_lock()
	_update_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER:
			_request_attack("keyboard")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			_select_opponent()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			_reset_encounter()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_target_at(event.position)
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		_select_target_at(event.position)


func get_combat_session_for_testing() -> ArenaCombatSession:
	return _session


func _request_attack(input_source: String) -> void:
	if _session.is_actor_prone(Fixture.PLAYER_ID):
		var stand_result := _session.request_player_stand(input_source)
		_last_ui_message = (
			"Standing action executing (one Act)."
			if stand_result.get("success", false)
			else "Stand illegal: %s" % _friendly_reason(String(stand_result.get("reason", "rejected")))
		)
		return
	var result := _session.request_player_attack(input_source)
	if result.get("success", false):
		_last_ui_message = "Battle Axe action executing (one Act at AT 2 = 2.5 s)."
	else:
		_last_ui_message = "Attack illegal: %s" % _friendly_reason(String(result.get("reason", "rejected")))


func _on_encounter_button_pressed() -> void:
	if _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY:
		_player.reset_for_encounter(_initial_player_position_pixels / _player.pixels_per_foot)
		_opponent.position = _initial_opponent_position_pixels
		var start_result := _session.start_encounter()
		_last_ui_message = "Encounter started. Opening Initiative is authoritative." if start_result.get("success", false) else "Start blocked: %s" % _friendly_reason(String(start_result.get("reason", "rejected")))
	else:
		_reset_encounter()
	_update_presentation()


func _reset_encounter() -> void:
	_player.reset_for_encounter(_initial_player_position_pixels / _player.pixels_per_foot)
	_opponent.position = _initial_opponent_position_pixels
	if _touch_controls != null:
		_touch_controls.reset_input()
	var result := _session.reset_encounter(false)
	_event_cursor = 0
	_log_lines.clear()
	_applied_displacement_event_ids.clear()
	_delta_us_remainder = 0.0
	if result.get("success", false):
		_session.select_target(Fixture.OPPONENT_ID)
		_append_log("Encounter reset: fixtures, clock, RNG and presentation restored.")
		_last_ui_message = "Reset complete. Press START for the identical seeded encounter."
	else:
		_last_ui_message = "Reset blocked: %s" % _friendly_reason(String(result.get("reason", "rejected")))
	_process_new_events()
	_update_combat_movement_lock()


func _select_target_at(screen_position: Vector2) -> void:
	if screen_position.distance_to(_opponent.global_position) <= TARGET_PICK_RADIUS_PIXELS:
		_select_opponent()
	else:
		_session.clear_target()
		_last_ui_message = "No legal target selected. Tap/click the opponent."
	_update_presentation()


func _select_opponent() -> void:
	var result := _session.select_target(Fixture.OPPONENT_ID)
	if result.get("success", false):
		_last_ui_message = "Opponent selected."
	else:
		_last_ui_message = "Target unavailable: %s" % _friendly_reason(String(result.get("reason", "invalid target")))
	_update_presentation()


func _process_new_events() -> void:
	var events := _session.get_resolved_events()
	while _event_cursor < events.size():
		var event: CombatEvent = events[_event_cursor]
		_event_cursor += 1
		_update_last_message_for_event(event)
		var line := EventPresenter.format_event(event)
		if not line.is_empty():
			_append_log(line)


func _update_last_message_for_event(event: CombatEvent) -> void:
	var payload := event.payload
	var actor_name := "Player" if event.source_actor_id == Fixture.PLAYER_ID else "Opponent"
	match String(event.event_type):
		"physical_attack_accuracy_resolved":
			if not payload.get("accuracy_success", false):
				_last_ui_message = "%s ACC check failed; the attack missed." % actor_name
		"physical_defense_resolved":
			var defense := String(payload.get("successful_defense_type", ""))
			if not defense.is_empty():
				_last_ui_message = "%s defense stopped the attack: %s." % [actor_name, defense.replace("_", " ")]
		"physical_damage_resolved":
			var target_name := "Player" if event.target_actor_id == Fixture.PLAYER_ID else "Opponent"
			_last_ui_message = "%s received %s HPC damage." % [target_name, payload.get("final_damage", "?")]
		"physical_attack_interrupted", "action_interrupted":
			_last_ui_message = "%s action interrupted: %s." % [actor_name, String(payload.get("reason", "interrupted")).replace("_", " ")]


func _apply_authoritative_combat_displacements() -> void:
	var opponent_state := _session.get_actor_state(Fixture.OPPONENT_ID)
	if opponent_state != null:
		_opponent.position = _microfeet_to_pixels(opponent_state.position_microfeet)
	var events := _session.get_resolved_events()
	for index in range(_event_cursor - 1, -1, -1):
		var event: CombatEvent = events[index]
		if _applied_displacement_event_ids.has(event.event_id):
			continue
		if String(event.event_type) != "physical_defense_attempted":
			continue
		var attempt: Dictionary = event.payload.get("attempt", {})
		if attempt.get("defense_type", "") == "dodge" and attempt.get("success", false) and event.source_actor_id == Fixture.PLAYER_ID:
			var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
			_player.apply_authoritative_combat_position(_microfeet_to_feet(player_state.position_microfeet))
			_applied_displacement_event_ids[event.event_id] = true
		break


func _update_combat_movement_lock() -> void:
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return
	_player.set_combat_movement_locked(
		not _session.is_encounter_active()
		or player_state.current_hpc == null
		or int(player_state.current_hpc) <= 0
		or player_state.conditions.has("prone")
		or player_state.critical_stagger_until_us > _session.simulation.clock.get_elapsed_us()
	)


func _update_presentation() -> void:
	if _session == null:
		return
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
	var opponent_state := _session.get_actor_state(Fixture.OPPONENT_ID)
	if player_state == null or opponent_state == null:
		return
	match _session.get_encounter_state():
		ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY:
			_last_ui_message = "VICTORY: the opponent fixture is defeated. Press RESET."
		ArenaCombatSession.ENCOUNTER_PLAYER_DEFEAT:
			_last_ui_message = "DEFEAT: the player fixture is defeated. Press RESET."
		ArenaCombatSession.ENCOUNTER_DOUBLE_DEFEAT:
			_last_ui_message = "DOUBLE DEFEAT: both fixtures reached zero HPC. Press RESET."
	if _player_hpc_label != null:
		_player_hpc_label.text = "PLAYER\nHPC %s / 100%s" % [player_state.current_hpc, _condition_suffix(player_state)]
	if _opponent_hpc_label != null:
		_opponent_hpc_label.text = "OPPONENT\nHPC %s / 100%s" % [opponent_state.current_hpc, _condition_suffix(opponent_state)]
	if _target_indicator != null:
		_target_indicator.visible = _session.get_selected_target_id() == Fixture.OPPONENT_ID and int(opponent_state.current_hpc) > 0
		_target_indicator.global_position = _opponent.global_position
	var legality := _session.get_attack_legality()
	var distance_text := "%.2f ft / 3 ft" % (float(legality.get("distance_microfeet", _distance_microfeet(player_state, opponent_state))) / 1_000_000.0)
	var readiness := "LEGAL" if legality.get("success", false) else _friendly_reason(String(legality.get("reason", "blocked"))).to_upper()
	if _combat_status != null:
		_combat_status.text = (
			"ENCOUNTER: %s | SELECTED: %s\nBattle Axe: %s | Range %s\nPlayer: %s | Opponent: %s\nTime %.2f s | Round %d\n%s"
			% [
				_session.get_encounter_state().replace("_", " ").to_upper(),
				"Opponent" if _session.get_selected_target_id() == Fixture.OPPONENT_ID else "None",
				readiness,
				distance_text,
				_session.get_active_player_attack_status().replace("_", " "),
				_session.get_opponent_behavior_status().replace("_", " "),
				float(_session.simulation.clock.get_elapsed_us()) / 1_000_000.0,
				_session.simulation.clock.get_round_index() + 1,
				_last_ui_message,
			]
		)
	if _encounter_button != null:
		_encounter_button.text = "START" if _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY else "RESET"
		_encounter_button.disabled = false
	if _event_log != null:
		_event_log.text = "[b]AUTHORITATIVE COMBAT LOG[/b]\n" + "\n".join(PackedStringArray(_log_lines))
		_event_log.scroll_to_line(maxi(0, _event_log.get_line_count() - 1))


func _append_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()


func _place_initial_combatants() -> void:
	_player.position = Vector2(20.0, 7.0) * _player.pixels_per_foot
	_player.apply_authoritative_combat_position(_player.position / _player.pixels_per_foot)
	_opponent.position = Vector2(23.0, 7.0) * _player.pixels_per_foot


func _resolve_player_movement(desired_microfeet: Vector2i, effective_mr: int) -> Dictionary:
	if _session == null:
		return {"success": false, "reason": "session_unavailable", "position_microfeet": desired_microfeet}
	return _session.request_player_movement(desired_microfeet, effective_mr)


func _node_position_microfeet(node: Node2D) -> Vector2i:
	return Vector2i(
		roundi(node.position.x / _player.pixels_per_foot * 1_000_000.0),
		roundi(node.position.y / _player.pixels_per_foot * 1_000_000.0)
	)


func _microfeet_to_pixels(value: Vector2i) -> Vector2:
	return Vector2(value) / 1_000_000.0 * _player.pixels_per_foot


func _microfeet_to_feet(value: Vector2i) -> Vector2:
	return Vector2(value) / 1_000_000.0


func _distance_microfeet(left: CombatActorState, right: CombatActorState) -> int:
	return roundi(Vector2(right.position_microfeet - left.position_microfeet).length())


func _condition_suffix(state: CombatActorState) -> String:
	if state.current_hpc != null and int(state.current_hpc) <= 0:
		return " [DEFEATED]"
	if state.conditions.has("prone"):
		return " [PRONE]"
	if state.critical_stagger_until_us > _session.simulation.clock.get_elapsed_us():
		return " [STAGGERED]"
	return ""


func _friendly_reason(reason: String) -> String:
	return reason.replace("_", " ")
