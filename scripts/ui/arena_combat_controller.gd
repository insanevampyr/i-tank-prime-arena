class_name ArenaCombatController
extends Node

const Session = preload("res://scripts/combat/arena_combat_session.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const EventPresenter = preload("res://scripts/ui/arena_combat_event_presenter.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const ReadinessModel = preload("res://scripts/ui/combat_readiness_model.gd")
const EncounterTranscript = preload("res://scripts/ui/arena_encounter_transcript.gd")
const LogExporter = preload("res://scripts/ui/arena_log_exporter.gd")
const HitLocations = preload("res://scripts/combat/combat_hit_location_catalog.gd")

const MAX_PLAYER_LOG_LINES := 8
const MAX_DEBUG_LOG_LINES := 48
const TARGET_PICK_RADIUS_PIXELS := 40.0
const BASE_WORLD_PIXELS_PER_FOOT := 24.0

@export var combat_seed: int = ArenaCombatSession.DEFAULT_SEED
@export var player_path: NodePath
@export var opponent_path: NodePath
@export var touch_controls_path: NodePath
@export var player_hpc_label_path: NodePath
@export var opponent_hpc_label_path: NodePath
@export var combat_status_path: NodePath
@export var event_log_path: NodePath
@export var developer_debug_path: NodePath
@export var target_indicator_path: NodePath
@export var encounter_button_path: NodePath
@export var encounter_selector_path: NodePath
@export var seed_label_path: NodePath
@export var seed_input_path: NodePath
@export var seed_apply_button_path: NodePath
@export var debug_button_path: NodePath
@export var attack_readiness_path: NodePath
@export var run_readiness_path: NodePath
@export var log_button_path: NodePath
@export var transcript_panel_path: NodePath
@export var transcript_body_path: NodePath
@export var transcript_feedback_path: NodePath
@export var close_log_button_path: NodePath
@export var copy_log_button_path: NodePath
@export var save_log_button_path: NodePath
@export var floating_combat_text_path: NodePath

var _session: ArenaCombatSession
var _delta_us_remainder: float = 0.0
var _event_cursor: int = 0
var _event_history_generation: int = -1
var _log_lines: Array[String] = []
var _debug_log_lines: Array[String] = []
var _applied_displacement_event_ids: Dictionary = {}
var _pending_player_displacement_event_ids: Array[String] = []
var _cached_transcript_text := ""
var _cached_transcript_event_count: int = -1
var _cached_transcript_history_generation: int = -1
var _transcript_view_event_count: int = -1
var _transcript_view_history_generation: int = -1
var _event_batch_read_count: int = 0
var _last_event_batch_size: int = 0
var _transcript_build_count: int = 0
var _last_ui_message := "Press START to begin the deterministic test encounter."
var _initial_player_position_feet := Vector2.ZERO
var _initial_opponent_position_feet := Vector2.ZERO
var _last_opponent_behavior_status := ""
var _application_has_focus := true
var _last_attack_readiness: Dictionary = {}
var _last_run_readiness: Dictionary = {}
var _web_copy_pending := false
var _encounter_fixture_id: StringName = Fixture.ENCOUNTER_MEDIUM_GUARDS
var _goblin_visuals: Dictionary = {}

@onready var _player: PlaceholderPlayer = get_node_or_null(player_path)
@onready var _opponent: Node2D = get_node_or_null(opponent_path)
@onready var _touch_controls: MobileTouchControls = get_node_or_null(touch_controls_path)
@onready var _player_hpc_label: Label = get_node_or_null(player_hpc_label_path)
@onready var _opponent_hpc_label: Label = get_node_or_null(opponent_hpc_label_path)
@onready var _combat_status: Label = get_node_or_null(combat_status_path)
@onready var _event_log: RichTextLabel = get_node_or_null(event_log_path)
@onready var _developer_debug: RichTextLabel = get_node_or_null(developer_debug_path)
@onready var _target_indicator: Line2D = get_node_or_null(target_indicator_path)
@onready var _encounter_button: Button = get_node_or_null(encounter_button_path)
@onready var _encounter_selector: Button = get_node_or_null(encounter_selector_path)
@onready var _seed_label: Label = get_node_or_null(seed_label_path)
@onready var _seed_input: LineEdit = get_node_or_null(seed_input_path)
@onready var _seed_apply_button: Button = get_node_or_null(seed_apply_button_path)
@onready var _debug_button: Button = get_node_or_null(debug_button_path)
@onready var _attack_readiness = get_node_or_null(attack_readiness_path)
@onready var _run_readiness = get_node_or_null(run_readiness_path)
@onready var _log_button: Button = get_node_or_null(log_button_path)
@onready var _transcript_panel: Control = get_node_or_null(transcript_panel_path)
@onready var _transcript_body: RichTextLabel = get_node_or_null(transcript_body_path)
@onready var _transcript_feedback: Label = get_node_or_null(transcript_feedback_path)
@onready var _close_log_button: Button = get_node_or_null(close_log_button_path)
@onready var _copy_log_button: Button = get_node_or_null(copy_log_button_path)
@onready var _save_log_button: Button = get_node_or_null(save_log_button_path)
@onready var _floating_combat_text: ArenaFloatingCombatText = get_node_or_null(floating_combat_text_path)


func _ready() -> void:
	assert(_player != null, "Playable combat requires the existing player node.")
	assert(_opponent != null, "Playable combat requires the opponent presentation node.")
	_place_initial_combatants()
	_initial_player_position_feet = _player.position / _player.pixels_per_foot
	_initial_opponent_position_feet = _opponent.position / _player.pixels_per_foot
	_prepare_encounter_fixture()
	_player.set_authoritative_movement_resolver(_resolve_player_movement)
	if _encounter_button != null and not _encounter_button.pressed.is_connected(_on_encounter_button_pressed):
		_encounter_button.pressed.connect(_on_encounter_button_pressed)
	if _encounter_selector != null and not _encounter_selector.pressed.is_connected(_on_encounter_selector_pressed):
		_encounter_selector.pressed.connect(_on_encounter_selector_pressed)
	if _seed_input != null:
		_seed_input.text = str(combat_seed)
		if not _seed_input.text_submitted.is_connected(_on_seed_text_submitted):
			_seed_input.text_submitted.connect(_on_seed_text_submitted)
	if _seed_apply_button != null and not _seed_apply_button.pressed.is_connected(_on_seed_apply_pressed):
		_seed_apply_button.pressed.connect(_on_seed_apply_pressed)
	if _debug_button != null and not _debug_button.pressed.is_connected(_on_debug_button_pressed):
		_debug_button.pressed.connect(_on_debug_button_pressed)
	if _log_button != null and not _log_button.pressed.is_connected(_on_log_button_pressed):
		_log_button.pressed.connect(_on_log_button_pressed)
	if _close_log_button != null and not _close_log_button.pressed.is_connected(_on_close_log_button_pressed):
		_close_log_button.pressed.connect(_on_close_log_button_pressed)
	if _copy_log_button != null and not _copy_log_button.pressed.is_connected(_on_copy_log_button_pressed):
		_copy_log_button.pressed.connect(_on_copy_log_button_pressed)
	if _save_log_button != null and not _save_log_button.pressed.is_connected(_on_save_log_button_pressed):
		_save_log_button.pressed.connect(_on_save_log_button_pressed)
	_process_new_events()
	_update_combat_movement_lock()
	_update_presentation()
	_poll_web_copy_status()


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
	_poll_web_copy_status()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_has_focus = false
		if _touch_controls != null:
			_touch_controls.reset_input()
		if is_node_ready():
			_update_presentation()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_has_focus = true
		if is_node_ready():
			_update_presentation()


func _input(event: InputEvent) -> void:
	if _session == null or not _session.is_encounter_active():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_cycle_enemy(-1 if event.shift_pressed else 1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER:
			_request_attack("keyboard")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_TAB:
			_cycle_enemy(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
		elif location_number_for_key_event(event) > 0:
			_select_location_by_number(location_number_for_key_event(event))
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R:
			_reset_encounter()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F3:
			set_debug_overlay_visible(not is_debug_overlay_visible())
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F4:
			set_transcript_visible(not is_transcript_visible())
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_target_at(event.position, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		_select_target_at(event.position, false)


func get_combat_session_for_testing() -> ArenaCombatSession:
	return _session


func request_pointer_action_for_testing(screen_position: Vector2, desktop_click: bool) -> Dictionary:
	return _select_target_at(screen_position, desktop_click)


func set_world_presentation_pixels_per_foot(pixels_per_foot: float) -> void:
	if _player == null or pixels_per_foot <= 0.0:
		return
	_player.pixels_per_foot = pixels_per_foot
	var actor_scale := Vector2.ONE * (pixels_per_foot / BASE_WORLD_PIXELS_PER_FOOT)
	_player.scale = actor_scale
	if _opponent != null:
		_opponent.scale = actor_scale
	if _target_indicator != null:
		_target_indicator.scale = actor_scale
	for visual: Variant in _goblin_visuals.values():
		if is_instance_valid(visual):
			(visual as Node2D).scale = actor_scale
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID) if _session != null else null
	if player_state != null:
		_player.apply_authoritative_combat_position(_microfeet_to_feet(player_state.position_microfeet))
	if _session != null:
		_refresh_non_player_actor_positions()


func press_encounter_control_for_testing() -> void:
	_on_encounter_button_pressed()


func select_encounter_fixture_for_testing(encounter_fixture_id: StringName) -> Dictionary:
	return _select_encounter_fixture(encounter_fixture_id)


func set_seed_text_for_testing(seed_text: String) -> Dictionary:
	return _apply_selected_seed(seed_text)


func get_seed_ui_state_for_testing() -> Dictionary:
	return {
		"selected_seed": combat_seed,
		"authoritative_seed": _authoritative_seed(),
		"label": "" if _seed_label == null else _seed_label.text,
		"input": "" if _seed_input == null else _seed_input.text,
		"input_disabled": true if _seed_input == null else not _seed_input.editable,
		"apply_disabled": true if _seed_apply_button == null else _seed_apply_button.disabled,
		"input_visible": false if _seed_input == null else _seed_input.visible,
		"apply_visible": false if _seed_apply_button == null else _seed_apply_button.visible,
		"input_has_focus": false if _seed_input == null else _seed_input.has_focus(),
		"apply_has_focus": false if _seed_apply_button == null else _seed_apply_button.has_focus(),
	}


func set_debug_overlay_visible(visible: bool) -> void:
	if _developer_debug != null:
		_developer_debug.visible = visible
	if _debug_button != null:
		_debug_button.text = "CLOSE" if visible else "DEBUG"


func is_debug_overlay_visible() -> bool:
	return _developer_debug != null and _developer_debug.visible


func set_transcript_visible(visible: bool) -> void:
	if _transcript_panel != null:
		_transcript_panel.visible = visible
	if _log_button != null:
		_log_button.text = "CLOSE LOG" if visible else "FULL LOG"
	if visible:
		_refresh_transcript_view()


func is_transcript_visible() -> bool:
	return _transcript_panel != null and _transcript_panel.visible


func get_attack_readiness_for_testing() -> Dictionary:
	return _last_attack_readiness.duplicate(true)


func get_run_readiness_for_testing() -> Dictionary:
	return _last_run_readiness.duplicate(true)


func get_last_ui_message_for_testing() -> String:
	return _last_ui_message


func select_location_for_testing(number: int) -> Dictionary:
	return _select_location_by_number(number)


func get_transcript_text_for_testing() -> String:
	_ensure_transcript_cache()
	return _cached_transcript_text


func get_event_consumption_metrics_for_testing() -> Dictionary:
	return {
		"event_cursor": _event_cursor,
		"event_history_generation": _event_history_generation,
		"event_batch_read_count": _event_batch_read_count,
		"last_event_batch_size": _last_event_batch_size,
		"transcript_build_count": _transcript_build_count,
		"cached_transcript_event_count": _cached_transcript_event_count,
	}


func get_actor_label_rects_for_testing() -> Array[Rect2]:
	return [
		Rect2(_player_hpc_label.global_position, _player_hpc_label.size),
		Rect2(_opponent_hpc_label.global_position, _opponent_hpc_label.size),
	]


func set_application_focus_for_testing(has_focus: bool) -> void:
	_application_has_focus = has_focus
	_update_presentation()


func _on_debug_button_pressed() -> void:
	set_debug_overlay_visible(not is_debug_overlay_visible())


func _on_log_button_pressed() -> void:
	set_transcript_visible(not is_transcript_visible())


func _on_close_log_button_pressed() -> void:
	set_transcript_visible(false)


func _on_copy_log_button_pressed() -> void:
	var result := LogExporter.request_copy(_build_transcript_text())
	_web_copy_pending = bool(result.get("pending", false))
	_set_transcript_feedback(
		"Copy requested. If the browser denies clipboard access, use SAVE LOG."
		if result.get("success", false) and _web_copy_pending
		else ("Full encounter log copied." if result.get("success", false) else "Copy failed: %s" % _friendly_reason(String(result.get("reason", "unknown"))))
	)


func _on_save_log_button_pressed() -> void:
	var result := LogExporter.save_text(_build_transcript_text(), _authoritative_seed(), _session.get_resolved_event_count())
	if not result.get("success", false):
		_set_transcript_feedback("Save failed: %s" % _friendly_reason(String(result.get("reason", "unknown"))))
	elif OS.has_feature("web"):
		_set_transcript_feedback("Browser download requested: %s" % String(result.get("filename", "encounter log")))
	else:
		_set_transcript_feedback("Saved full log to %s" % String(result.get("path", result.get("filename", "encounter log"))))


func _request_attack(input_source: String) -> Dictionary:
	if _session.is_actor_prone(Fixture.PLAYER_ID):
		var stand_result := _session.request_player_stand(input_source)
		_last_ui_message = (
			"Standing action executing (one Act)."
			if stand_result.get("success", false)
			else "Stand illegal: %s" % _friendly_reason(String(stand_result.get("reason", "rejected")))
		)
		return stand_result
	var declaration_legality := _session.get_attack_legality()
	var result := _session.request_player_attack(input_source)
	if result.get("success", false):
		var action := _session.simulation.get_action(String(result.get("action_instance_id", "")))
		var duration_us := 0 if action == null else action.final_effect_due_at_us - action.started_at_us
		var at_value := 0 if action == null else action.at_at_start
		var location_name := HitLocations.get_display_name(_session.get_selected_target_location())
		_last_ui_message = (
			"Approach attack started (%.3f s at AT %d). Reach 3 ft with clear line of sight before resolution."
			% [float(duration_us) / 1_000_000.0, at_value]
			if declaration_legality.get("approach_required", false)
			else "Battle Axe action executing at %s (%.3f s at AT %d)." % [location_name, float(duration_us) / 1_000_000.0, at_value]
		)
	else:
		_last_ui_message = "Attack illegal: %s" % _friendly_reason(String(result.get("reason", "rejected")))
	return result


func _on_encounter_button_pressed() -> void:
	if _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY:
		_player.reset_for_encounter(_initial_player_position_feet)
		_opponent.position = _initial_opponent_position_feet * _player.pixels_per_foot
		var start_result := _session.start_encounter()
		_last_ui_message = "Encounter started. Opening Initiative is authoritative." if start_result.get("success", false) else "Start blocked: %s" % _friendly_reason(String(start_result.get("reason", "rejected")))
	else:
		_reset_encounter()
	_update_presentation()


func _on_encounter_selector_pressed() -> void:
	var cycle := [Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS]
	var current_index := cycle.find(_encounter_fixture_id)
	var next_fixture: StringName = cycle[posmod(current_index + 1, cycle.size())]
	_select_encounter_fixture(next_fixture)


func _on_seed_apply_pressed() -> void:
	if _seed_input != null:
		_apply_selected_seed(_seed_input.text)


func _on_seed_text_submitted(seed_text: String) -> void:
	_apply_selected_seed(seed_text)


func _apply_selected_seed(seed_text: String) -> Dictionary:
	if _session != null and _session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY:
		_last_ui_message = "Seed change blocked: RESET the active encounter first."
		_update_presentation()
		return {"success": false, "reason": "seed_change_requires_ready_state"}
	var parsed := _parse_seed_text(seed_text)
	if not parsed.get("success", false):
		_last_ui_message = "Seed invalid: enter a signed 64-bit integer."
		_update_presentation()
		return parsed
	var previous_seed := combat_seed
	combat_seed = int(parsed["seed"])
	var result := _select_encounter_fixture(_encounter_fixture_id)
	if not result.get("success", false):
		combat_seed = previous_seed
		return result
	if _seed_input != null:
		_seed_input.text = str(combat_seed)
		_seed_input.release_focus()
	_last_ui_message = "Authoritative seed %d selected. Press START; RESET will reuse this seed." % combat_seed
	_update_presentation()
	return {"success": true, "seed": combat_seed}


static func _parse_seed_text(seed_text: String) -> Dictionary:
	var normalized := seed_text.strip_edges()
	if normalized.is_empty() or not normalized.is_valid_int() or not _fits_signed_64_bit(normalized):
		return {"success": false, "reason": "invalid_seed"}
	return {"success": true, "seed": normalized.to_int()}


static func _fits_signed_64_bit(value: String) -> bool:
	var digits := value
	var negative := false
	if digits.begins_with("-") or digits.begins_with("+"):
		negative = digits.begins_with("-")
		digits = digits.substr(1)
	digits = digits.trim_prefix("0")
	if digits.is_empty():
		return true
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() != limit.length():
		return digits.length() < limit.length()
	for index in range(digits.length()):
		var digit := digits.unicode_at(index)
		var maximum_digit := limit.unicode_at(index)
		if digit != maximum_digit:
			return digit < maximum_digit
	return true


func _select_encounter_fixture(encounter_fixture_id: StringName) -> Dictionary:
	if _session != null and _session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY:
		return {"success": false, "reason": "encounter_selection_requires_ready_state"}
	if not [Fixture.ENCOUNTER_MEDIUM_GUARDS, Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS].has(encounter_fixture_id):
		return {"success": false, "reason": "unsupported_encounter_fixture"}
	_encounter_fixture_id = encounter_fixture_id
	_player.reset_for_encounter(_initial_player_position_feet)
	_opponent.position = _initial_opponent_position_feet * _player.pixels_per_foot
	_event_cursor = 0
	_event_history_generation = -1
	_log_lines.clear()
	_debug_log_lines.clear()
	_applied_displacement_event_ids.clear()
	_pending_player_displacement_event_ids.clear()
	_invalidate_transcript_cache()
	if _floating_combat_text != null:
		_floating_combat_text.clear()
	var result := _prepare_encounter_fixture()
	if result.get("success", false):
		_last_ui_message = "%s selected. Press START." % _session.get_encounter_display_name()
	_update_combat_movement_lock()
	_update_presentation()
	return result


func _prepare_encounter_fixture() -> Dictionary:
	_session = ArenaCombatSession.new(combat_seed, null, _encounter_fixture_id)
	_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	_session.set_opponent_behavior_enabled(true)
	var setup := (
		_session.initialize_wave_one_goblins(_node_position_microfeet(_player), _node_position_microfeet(_opponent), false)
		if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_ONE_GOBLINS
		else _session.initialize(_node_position_microfeet(_player), _node_position_microfeet(_opponent), false)
	)
	if not setup.get("success", false):
		_last_ui_message = "Combat fixture blocked: %s" % String(setup.get("reason", "unknown setup failure"))
		return setup
	_session.select_target(_session.get_targetable_enemy_ids()[0])
	_rebuild_encounter_visuals()
	_append_log(
		"Synthetic Small Guard size test ready; Guard statistics/loadout are reused and no printed creature identity is claimed."
		if _encounter_fixture_id == Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD
		else ("Wave 1 Common Goblins ready. The seeded 1d4 count is authoritative." if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_ONE_GOBLINS else "Verified Prime V3 Guard fixture ready.")
	)
	var running_validation := _player.configure_authoritative_actor_profile(Fixture.make_guard_actor(Fixture.PLAYER_ID, "Player Guard Fixture"))
	if not running_validation.get("success", false):
		_last_ui_message = "Running fixture blocked: %s" % _friendly_reason(String(running_validation.get("reason", "unresolved running profile")))
		return running_validation
	return setup


func _reset_encounter() -> void:
	_player.reset_for_encounter(_initial_player_position_feet)
	_opponent.position = _initial_opponent_position_feet * _player.pixels_per_foot
	if _touch_controls != null:
		_touch_controls.reset_input()
	var result := _session.reset_encounter(false)
	_event_cursor = 0
	_event_history_generation = -1
	_log_lines.clear()
	_debug_log_lines.clear()
	_applied_displacement_event_ids.clear()
	_pending_player_displacement_event_ids.clear()
	_invalidate_transcript_cache()
	_web_copy_pending = false
	if _floating_combat_text != null:
		_floating_combat_text.clear()
	_delta_us_remainder = 0.0
	if result.get("success", false):
		_session.select_target(_session.get_targetable_enemy_ids()[0])
		_rebuild_encounter_visuals()
		_append_log("Encounter reset: fixtures, clock, RNG and presentation restored.")
		_last_ui_message = "Reset complete with seed %d. Press START for the identical seeded encounter." % _authoritative_seed()
	else:
		_last_ui_message = "Reset blocked: %s" % _friendly_reason(String(result.get("reason", "rejected")))
	_process_new_events()
	_update_combat_movement_lock()
	_update_presentation()


func _select_target_at(screen_position: Vector2, request_desktop_attack: bool) -> Dictionary:
	for actor_id: String in _session.get_targetable_enemy_ids():
		var visual := _get_enemy_visual(StringName(actor_id))
		var pick_radius := TARGET_PICK_RADIUS_PIXELS if visual == null else TARGET_PICK_RADIUS_PIXELS * maxf(1.0, visual.global_transform.get_scale().x)
		if visual != null and is_pointer_over_target(screen_position, visual.global_position, pick_radius):
			var selection := _select_enemy(StringName(actor_id))
			if request_desktop_attack and selection.get("success", false):
				var attack_result := _request_attack("mouse_click")
				_update_presentation()
				return {"selection": selection, "attack": attack_result}
			_update_presentation()
			return {"selection": selection, "attack": null}
	_session.clear_target()
	_last_ui_message = "No target selected. Click/tap an enemy to select it."
	_update_presentation()
	return {"selection": {"success": true, "target_id": ""}, "attack": null}


static func is_pointer_over_target(screen_position: Vector2, target_position: Vector2, radius_pixels: float) -> bool:
	return radius_pixels >= 0.0 and screen_position.distance_to(target_position) <= radius_pixels


func _select_opponent() -> Dictionary:
	return _select_enemy(Fixture.OPPONENT_ID)


func _select_enemy(actor_id: StringName) -> Dictionary:
	var result := _session.select_target(actor_id)
	if result.get("success", false):
		var display_name := String(actor_id).replace("_", " ").to_upper()
		_last_ui_message = "%s selected." % display_name.capitalize()
		_present_local_selection(actor_id, "TARGET: %s" % display_name)
	else:
		_last_ui_message = "Target unavailable: %s" % _friendly_reason(String(result.get("reason", "invalid target")))
	_update_presentation()
	return result


func _cycle_enemy(direction: int) -> Dictionary:
	var result := _session.cycle_target(direction)
	if result.get("success", false):
		var target_id := StringName(result["target_id"])
		_last_ui_message = "%s selected." % String(target_id).replace("_", " ").capitalize()
		_present_local_selection(target_id, "TARGET: %s" % String(target_id).replace("_", " ").to_upper())
	else:
		_last_ui_message = "Target unavailable: %s" % _friendly_reason(String(result.get("reason", "invalid target")))
	_update_presentation()
	return result


func _select_location_by_number(number: int) -> Dictionary:
	var result := _session.select_target_location_by_number(number)
	if result.get("success", false):
		var location_id := StringName(result["target_location"])
		var display_name := HitLocations.get_display_name(location_id)
		_last_ui_message = "Aim selected: %s." % display_name
		var feedback_actor := _session.get_selected_target_id()
		if feedback_actor == &"":
			feedback_actor = Fixture.PLAYER_ID
		_present_local_selection(feedback_actor, "AIM: %s" % display_name)
	_update_presentation()
	return result


func _present_local_selection(actor_id: StringName, text: String) -> void:
	if _floating_combat_text != null:
		_floating_combat_text.present_local_selection(actor_id, text)


static func location_number_for_key_event(event: InputEventKey) -> int:
	if event == null:
		return 0
	var top_row := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
	var keypad := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]
	for code: Key in [event.physical_keycode, event.keycode]:
		var top_index := top_row.find(code)
		if top_index >= 0:
			return top_index + 1
		var keypad_index := keypad.find(code)
		if keypad_index >= 0:
			return keypad_index + 1
	return 0


func _process_new_events() -> void:
	var batch := _session.get_resolved_events_since(_event_cursor, _event_history_generation)
	if not batch.get("success", false):
		_event_cursor = 0
		_event_history_generation = -1
		batch = _session.get_resolved_events_since(_event_cursor, _event_history_generation)
	if not batch.get("success", false):
		return
	_event_history_generation = int(batch.get("history_generation", _event_history_generation))
	_event_cursor = int(batch.get("next_cursor", _event_cursor))
	var events: Array = batch.get("events", [])
	_event_batch_read_count += 1
	_last_event_batch_size = events.size()
	if not events.is_empty():
		_invalidate_transcript_cache()
	for event: CombatEvent in events:
		if _floating_combat_text != null:
			_floating_combat_text.present_authoritative_event(event)
		_queue_player_dodge_displacement(event)
		_update_last_message_for_event(event)
		var line := EventPresenter.format_event(event)
		if not line.is_empty():
			_append_debug_log(line)
			if EventPresenter.is_player_facing_event(event):
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
		"physical_attack_final_legality_failed":
			var final_reason := String(payload.get("reason", "final legality failed"))
			_last_ui_message = "%s attack finished, but %s; ACC was not rolled." % [actor_name, _friendly_reason(final_reason)]


func _apply_authoritative_combat_displacements() -> void:
	_refresh_non_player_actor_positions()
	if _pending_player_displacement_event_ids.is_empty():
		return
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return
	_player.apply_authoritative_combat_position(_microfeet_to_feet(player_state.position_microfeet))
	for event_id: String in _pending_player_displacement_event_ids:
		_applied_displacement_event_ids[event_id] = true
	_pending_player_displacement_event_ids.clear()


func _refresh_non_player_actor_positions() -> void:
	var opponent_state := _session.get_actor_state(Fixture.OPPONENT_ID)
	if opponent_state != null:
		_opponent.position = _microfeet_to_pixels(opponent_state.position_microfeet)
	for actor_id: String in _goblin_visuals:
		var goblin_state := _session.get_actor_state(StringName(actor_id))
		var goblin_visual := _goblin_visuals[actor_id] as Node2D
		if goblin_state != null and goblin_visual != null:
			goblin_visual.position = _microfeet_to_pixels(goblin_state.position_microfeet)
			goblin_visual.visible = goblin_state.current_hpc != null and int(goblin_state.current_hpc) > 0
			var goblin_label := goblin_visual.get_node_or_null("Label") as Label
			if goblin_label != null:
				goblin_label.text = _format_hpc(goblin_state.current_hpc, _session.get_actor_max_hpm(StringName(actor_id)))


func _rebuild_encounter_visuals() -> void:
	for visual: Variant in _goblin_visuals.values():
		if is_instance_valid(visual):
			(visual as Node).queue_free()
	_goblin_visuals.clear()
	if _encounter_fixture_id != Fixture.ENCOUNTER_WAVE_ONE_GOBLINS:
		_opponent.visible = true
		return
	_opponent.visible = false
	for actor_id: String in _session.get_targetable_enemy_ids():
		var state := _session.get_actor_state(StringName(actor_id))
		if state == null:
			continue
		var visual := Node2D.new()
		visual.name = "CommonGoblin_%s" % actor_id
		visual.position = _microfeet_to_pixels(state.position_microfeet)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([Vector2(-13, -13), Vector2(13, -13), Vector2(13, 13), Vector2(-13, 13)])
		body.color = Color("#32864A")
		visual.add_child(body)
		var glyph := Label.new()
		glyph.name = "Glyph"
		glyph.position = Vector2(-13, -15)
		glyph.size = Vector2(26, 30)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 18)
		glyph.add_theme_color_override("font_color", Color("#FFFFFF"))
		glyph.text = "G"
		visual.add_child(glyph)
		var label := Label.new()
		label.position = Vector2(-42, -48)
		label.size = Vector2(84, 34)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.72, 1.0))
		label.name = "Label"
		label.text = _format_hpc(state.current_hpc, _session.get_actor_max_hpm(StringName(actor_id)))
		visual.add_child(label)
		visual.scale = Vector2.ONE * (_player.pixels_per_foot / BASE_WORLD_PIXELS_PER_FOOT)
		get_parent().add_child(visual)
		_goblin_visuals[actor_id] = visual


func _get_enemy_visual(actor_id: StringName) -> Node2D:
	if actor_id == Fixture.OPPONENT_ID:
		return _opponent
	return _goblin_visuals.get(String(actor_id)) as Node2D


func _queue_player_dodge_displacement(event: CombatEvent) -> void:
	if String(event.event_type) != "physical_defense_attempted" or _applied_displacement_event_ids.has(event.event_id):
		return
	var attempt: Dictionary = event.payload.get("attempt", {})
	if attempt.get("defense_type", "") == "dodge" and attempt.get("success", false) and event.source_actor_id == Fixture.PLAYER_ID:
		_pending_player_displacement_event_ids.append(event.event_id)


func _update_combat_movement_lock() -> void:
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
	if player_state == null:
		return
	_player.set_prone(player_state.conditions.has("prone"))
	_player.set_combat_movement_locked(
		not _session.is_encounter_active()
		or player_state.current_hpc == null
		or int(player_state.current_hpc) <= 0
		or player_state.critical_stagger_until_us > _session.simulation.clock.get_elapsed_us()
	)


func _update_presentation() -> void:
	if _session == null:
		return
	var player_state := _session.get_actor_state(Fixture.PLAYER_ID)
	var selected_target_id := _session.get_selected_target_id()
	var opponent_state := _session.get_actor_state(selected_target_id if selected_target_id != &"" else Fixture.OPPONENT_ID)
	if player_state == null:
		return
	match _session.get_encounter_state():
		ArenaCombatSession.ENCOUNTER_PLAYER_VICTORY:
			_last_ui_message = "VICTORY: the opponent fixture is defeated. Press RESET."
		ArenaCombatSession.ENCOUNTER_PLAYER_DEFEAT:
			_last_ui_message = "DEFEAT: the player fixture is defeated. Press RESET."
		ArenaCombatSession.ENCOUNTER_DOUBLE_DEFEAT:
			_last_ui_message = "DOUBLE DEFEAT: both fixtures reached zero HPC. Press RESET."
	if _player_hpc_label != null:
		_player_hpc_label.text = "PLAYER\n%s%s" % [_format_hpc(player_state.current_hpc, _session.get_actor_max_hpm(Fixture.PLAYER_ID)), _condition_suffix(player_state)]
	if _opponent_hpc_label != null:
		var opponent_label := "SYNTHETIC SMALL*" if _session.get_encounter_fixture_id() == Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD else ("COMMON GOBLIN" if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_ONE_GOBLINS else "OPPONENT")
		_opponent_hpc_label.text = "%s\n%s%s" % [opponent_label, "HPC -- / --" if opponent_state == null else _format_hpc(opponent_state.current_hpc, _session.get_actor_max_hpm(selected_target_id if selected_target_id != &"" else Fixture.OPPONENT_ID)), "" if opponent_state == null else _condition_suffix(opponent_state)]
	_update_actor_label_layout()
	if _target_indicator != null:
		var target_visual := _get_enemy_visual(selected_target_id)
		_target_indicator.visible = opponent_state != null and target_visual != null and int(opponent_state.current_hpc) > 0
		if target_visual != null:
			_target_indicator.global_position = target_visual.global_position
	var legality := _session.get_attack_legality()
	var movement := _player.get_movement_state_for_testing()
	_last_attack_readiness = ReadinessModel.get_attack_readiness(_session, _application_has_focus)
	_last_run_readiness = ReadinessModel.get_running_readiness(movement, _get_running_blocker(player_state), _application_has_focus)
	if _attack_readiness != null:
		_attack_readiness.set_readiness(_last_attack_readiness)
	if _run_readiness != null:
		_run_readiness.set_readiness(_last_run_readiness)
	var distance_text := "--" if opponent_state == null else "%.2f ft / %.2f ft" % [float(legality.get("distance_microfeet", _distance_microfeet(player_state, opponent_state))) / 1_000_000.0, float(legality.get("maximum_range_microfeet", 3_000_000)) / 1_000_000.0]
	var readiness := (
		"APPROACH"
		if legality.get("success", false) and legality.get("approach_required", false)
		else ("LEGAL" if legality.get("success", false) else _friendly_reason(String(legality.get("reason", "blocked"))).to_upper())
	)
	var opponent_behavior := _session.get_opponent_behavior_status()
	if opponent_behavior != _last_opponent_behavior_status:
		_last_opponent_behavior_status = opponent_behavior
		if opponent_behavior.begins_with("approach_blocked_"):
			var blocked_line := "Opponent approach blocked: %s." % _friendly_reason(opponent_behavior.trim_prefix("approach_blocked_"))
			_last_ui_message = blocked_line
			_append_log(blocked_line)
	if _combat_status != null:
		_combat_status.text = (
			"%s | %s | TARGET: %s\nBATTLE AXE: %s | Range %s\n%s"
			% [
				_session.get_encounter_state().replace("_", " ").to_upper(),
				_session.get_encounter_display_name(),
				"None" if selected_target_id == &"" else String(selected_target_id).replace("_", " ").capitalize(),
				readiness,
				distance_text,
				_last_ui_message,
			]
		)
	if _encounter_button != null:
		_encounter_button.text = "START" if _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY else "RESET"
		_encounter_button.disabled = false
	if _encounter_selector != null:
		_encounter_selector.text = "WAVE 1" if _encounter_fixture_id == Fixture.ENCOUNTER_WAVE_ONE_GOBLINS else ("DUEL M/S*" if _session.get_encounter_fixture_id() == Fixture.ENCOUNTER_SYNTHETIC_SMALL_GUARD else "DUEL M/M")
		_encounter_selector.disabled = _session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY
	var seed_editable := _session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_READY
	if _seed_label != null:
		_seed_label.text = "SEED %d" % _authoritative_seed()
	if _seed_input != null:
		if not seed_editable and _seed_input.has_focus():
			_seed_input.release_focus()
		_seed_input.visible = seed_editable
		_seed_input.editable = seed_editable
	if _seed_apply_button != null:
		if not seed_editable and _seed_apply_button.has_focus():
			_seed_apply_button.release_focus()
		_seed_apply_button.visible = seed_editable
		_seed_apply_button.disabled = not seed_editable
	if _event_log != null:
		_event_log.text = "\n[b]RECENT RESULTS[/b]  (FULL LOG / F4 for complete transcript)\n" + "\n".join(PackedStringArray(_log_lines))
		_event_log.scroll_to_line(maxi(0, _event_log.get_line_count() - 1))
	if is_transcript_visible():
		_refresh_transcript_view()
	if _developer_debug != null and _developer_debug.visible:
		_developer_debug.text = (
			"[b]DEVELOPER OVERLAY - F3 TO CLOSE[/b]\n"
			+ "Clock %.3f s | Round %d | Events %d\n" % [
				float(_session.simulation.clock.get_elapsed_us()) / 1_000_000.0,
				_session.simulation.clock.get_round_index() + 1,
				_session.get_resolved_event_count(),
			]
			+ "Opponent driver: %s | Path rebuilds: %d\n" % [opponent_behavior, _session.get_opponent_path_rebuild_count_for_testing()]
			+ "Opponent movement: %s\n" % JSON.stringify(_session.get_state_snapshot().get("opponent_movement", {}))
			+ "Player action: %s | Opponent action: %s\n" % [
				_session.get_active_player_attack_status(), _session.get_active_opponent_attack_status(),
			]
			+ "Attack readiness: %s | %s | reason %s\n" % [
				_last_attack_readiness.get("status_text", "?"), _last_attack_readiness.get("value_text", ""),
				_last_attack_readiness.get("reason", "?"),
			]
			+ "Run readiness: %s | %s | reason %s | recovery %.3f s | retry %.3f s\n" % [
				_last_run_readiness.get("status_text", "?"), _last_run_readiness.get("value_text", ""),
				_last_run_readiness.get("reason", "?"),
				float(_last_run_readiness.get("recovery_remaining_us", 0)) / 1_000_000.0,
				float(_last_run_readiness.get("retry_remaining_us", 0)) / 1_000_000.0,
			]
			+ "Running target %s | investment %s | SCM %s | RB %s | last %s\n\n" % [
				movement.get("running_check_target", "?"), movement.get("running_skill_investment", "?"),
				movement.get("skill_check_modifier", "?"), movement.get("roll_bonus", "?"),
				movement.get("last_check_result", "?"),
			]
			+ "[b]AUTHORITATIVE EVENT DETAIL[/b]\n" + "\n".join(PackedStringArray(_debug_log_lines))
		)


func _format_hpc(current_hpc: Variant, maximum_hpm: Variant) -> String:
	return "HPC %s / %s" % ["--" if current_hpc == null else current_hpc, "--" if maximum_hpm == null else maximum_hpm]


func update_presentation_for_testing() -> void:
	_update_presentation()


func _get_running_blocker(player_state: CombatActorState) -> Dictionary:
	if not _session.is_encounter_active():
		return {"reason": "encounter_not_running", "label": "START"}
	if player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		return {"reason": "player_defeated", "label": "DEFEATED"}
	if player_state.conditions.has("incapacitated") or player_state.conditions.has("unconscious"):
		return {"reason": "player_incapacitated", "label": "INCAPACITATED"}
	var stagger_remaining_us := maxi(0, player_state.critical_stagger_until_us - _session.simulation.clock.get_elapsed_us())
	if stagger_remaining_us > 0:
		return {"reason": "critical_stagger", "label": "STAGGERED", "remaining_us": stagger_remaining_us, "total_us": 500_000}
	if player_state.conditions.has("prone"):
		return {"reason": "actor_prone", "label": "PRONE"}
	return {}


func _append_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > MAX_PLAYER_LOG_LINES:
		_log_lines.pop_front()


func _append_debug_log(line: String) -> void:
	_debug_log_lines.append(line)
	while _debug_log_lines.size() > MAX_DEBUG_LOG_LINES:
		_debug_log_lines.pop_front()


func _build_transcript_text() -> String:
	_ensure_transcript_cache()
	return _cached_transcript_text


func _refresh_transcript_view() -> void:
	if _transcript_body == null:
		return
	_ensure_transcript_cache()
	if _transcript_view_history_generation != _cached_transcript_history_generation or _transcript_view_event_count != _cached_transcript_event_count:
		_transcript_body.text = _cached_transcript_text
		_transcript_view_history_generation = _cached_transcript_history_generation
		_transcript_view_event_count = _cached_transcript_event_count


func _ensure_transcript_cache() -> void:
	if _session == null:
		return
	var event_count := _session.get_resolved_event_count()
	var history_generation := _session.get_resolved_event_history_generation()
	if _cached_transcript_history_generation == history_generation and _cached_transcript_event_count == event_count:
		return
	var build_version := String(ProjectSettings.get_setting("application/config/version", "development"))
	_cached_transcript_text = EncounterTranscript.build_text(_session, _authoritative_seed(), build_version)
	_cached_transcript_history_generation = history_generation
	_cached_transcript_event_count = event_count
	_transcript_build_count += 1


func _authoritative_seed() -> int:
	if _session == null:
		return combat_seed
	return _session.simulation.random.get_seed_value()


func _invalidate_transcript_cache() -> void:
	_cached_transcript_text = ""
	_cached_transcript_event_count = -1
	_cached_transcript_history_generation = -1
	_transcript_view_event_count = -1
	_transcript_view_history_generation = -1


func _set_transcript_feedback(message: String) -> void:
	if _transcript_feedback != null:
		_transcript_feedback.text = message


func _poll_web_copy_status() -> void:
	if not _web_copy_pending or not OS.has_feature("web"):
		return
	var status := LogExporter.poll_web_copy_status()
	if status == "pending" or status == "unknown":
		return
	_web_copy_pending = false
	match status:
		"success":
			_set_transcript_feedback("Full encounter log copied.")
		"denied":
			_set_transcript_feedback("Clipboard permission was denied. Use SAVE LOG instead.")
		_:
			_set_transcript_feedback("Clipboard API is unavailable. Use SAVE LOG instead.")


func _update_actor_label_layout() -> void:
	if _player_hpc_label == null or _opponent_hpc_label == null:
		return
	var crowded := _player.global_position.distance_to(_opponent.global_position) < 150.0
	if crowded:
		_player_hpc_label.position = Vector2(-138.0, -62.0)
		_player_hpc_label.size = Vector2(116.0, 44.0)
		_opponent_hpc_label.position = Vector2(22.0, -62.0)
		_opponent_hpc_label.size = Vector2(126.0, 44.0)
	else:
		_player_hpc_label.position = Vector2(-60.0, -62.0)
		_player_hpc_label.size = Vector2(120.0, 44.0)
		_opponent_hpc_label.position = Vector2(-65.0, -62.0)
		_opponent_hpc_label.size = Vector2(130.0, 44.0)


func _place_initial_combatants() -> void:
	_player.position = Vector2(20.0, 12.0) * _player.pixels_per_foot
	_player.apply_authoritative_combat_position(_player.position / _player.pixels_per_foot)
	_opponent.position = Vector2(23.0, 12.0) * _player.pixels_per_foot


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
	var player_facing := {
		"opening_initiative_wait": "waiting for opening Initiative",
		"attack_in_progress": "an ordinary attack is already executing",
		"actor_critically_staggered": "Critical Stagger prevents the action",
		"actor_prone": "stand before attacking",
		"no_target_selected": "no target selected",
		"target_out_of_range_at_resolution": "the target was outside weapon reach at final resolution",
		"line_of_sight_blocked_at_resolution": "line of sight was blocked at final resolution",
		"encounter_not_running": "press START before acting",
		"attacker_defeated": "the attacker is defeated",
		"target_defeated": "the target is defeated",
	}
	return String(player_facing.get(reason, reason.replace("_", " ")))
