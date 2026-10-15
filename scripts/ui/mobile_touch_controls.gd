class_name MobileTouchControls
extends Control

const NO_TOUCH: int = -1
const MIN_TOUCH_DIAMETER: float = 96.0
const MAX_JOYSTICK_DIAMETER: float = 160.0
const MAX_RUN_DIAMETER: float = 144.0
const MAX_ATTACK_DIAMETER: float = 144.0
const JOYSTICK_DEAD_ZONE: float = 0.16
const NARROW_WEB_MAX_WIDTH: float = 960.0

@export var force_visible_for_testing: bool = false
@export var show_on_narrow_web: bool = true

var _layout_size: Vector2 = Vector2(1152.0, 648.0)
var _display_size: Vector2 = Vector2(1152.0, 648.0)
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = MIN_TOUCH_DIAMETER * 0.5
var _joystick_activation_rect: Rect2 = Rect2()
var _run_center: Vector2 = Vector2.ZERO
var _run_radius: float = MIN_TOUCH_DIAMETER * 0.5
var _attack_center: Vector2 = Vector2.ZERO
var _attack_radius: float = MIN_TOUCH_DIAMETER * 0.5
var _joystick_touch_index: int = NO_TOUCH
var _run_touch_index: int = NO_TOUCH
var _attack_touch_index: int = NO_TOUCH
var _movement_vector: Vector2 = Vector2.ZERO
var _knob_position: Vector2 = Vector2.ZERO
var _run_held: bool = false
var _attack_requested: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	set_process(true)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_viewport_size(get_viewport_rect().size, Vector2(DisplayServer.window_get_size()))


func _process(_delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var display_size := Vector2(DisplayServer.window_get_size())
	if not viewport_size.is_equal_approx(_layout_size) or not display_size.is_equal_approx(_display_size):
		_apply_viewport_size(viewport_size, display_size)


func _exit_tree() -> void:
	reset_input()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_input()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := false
	if event is InputEventScreenTouch:
		handled = handle_touch(event.index, event.pressed, event.position, event.canceled)
	elif event is InputEventScreenDrag:
		handled = handle_drag(event.index, event.position)
	if handled:
		get_viewport().set_input_as_handled()


func get_movement_vector() -> Vector2:
	return _movement_vector


func is_run_held() -> bool:
	return _run_held


func consume_attack_requested() -> bool:
	var requested := _attack_requested
	_attack_requested = false
	return requested


func handle_touch(index: int, pressed: bool, position: Vector2, canceled: bool = false) -> bool:
	if canceled or not pressed:
		return _release_touch(index)

	if index == _joystick_touch_index:
		_update_joystick(position)
		return true
	if index == _run_touch_index:
		return true
	if index == _attack_touch_index:
		return true

	if _attack_touch_index == NO_TOUCH and position.distance_to(_attack_center) <= _attack_radius:
		_attack_touch_index = index
		_attack_requested = true
		queue_redraw()
		return true
	if _run_touch_index == NO_TOUCH and position.distance_to(_run_center) <= _run_radius:
		_run_touch_index = index
		_run_held = true
		queue_redraw()
		return true
	if _joystick_touch_index == NO_TOUCH and _joystick_activation_rect.has_point(position):
		_joystick_touch_index = index
		_update_joystick(position)
		return true
	return false


func handle_drag(index: int, position: Vector2) -> bool:
	if index == _joystick_touch_index:
		_update_joystick(position)
		return true
	if index == _run_touch_index:
		return true
	if index == _attack_touch_index:
		return true
	return false


func reset_input() -> void:
	_joystick_touch_index = NO_TOUCH
	_run_touch_index = NO_TOUCH
	_attack_touch_index = NO_TOUCH
	_movement_vector = Vector2.ZERO
	_knob_position = _joystick_center
	_run_held = false
	_attack_requested = false
	queue_redraw()


func set_viewport_size_for_testing(viewport_size: Vector2) -> void:
	force_visible_for_testing = true
	_apply_viewport_size(viewport_size, viewport_size)


func get_layout_snapshot() -> Dictionary:
	var metrics := calculate_layout(_layout_size, _display_size)
	metrics["joystick_activation_rect"] = _joystick_activation_rect
	return metrics


static func calculate_layout(viewport_size: Vector2, display_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var safe_display_size := safe_size if display_size.is_zero_approx() else Vector2(maxf(display_size.x, 1.0), maxf(display_size.y, 1.0))
	var canvas_scale := minf(safe_display_size.x / safe_size.x, safe_display_size.y / safe_size.y)
	canvas_scale = maxf(canvas_scale, 0.001)
	var display_short_side := minf(safe_display_size.x, safe_display_size.y)
	var margin := clampf(display_short_side * 0.05, 12.0, 32.0) / canvas_scale
	var joystick_diameter := clampf(display_short_side * 0.28, MIN_TOUCH_DIAMETER, MAX_JOYSTICK_DIAMETER) / canvas_scale
	var run_diameter := clampf(display_short_side * 0.24, MIN_TOUCH_DIAMETER, MAX_RUN_DIAMETER) / canvas_scale
	var attack_diameter := clampf(display_short_side * 0.24, MIN_TOUCH_DIAMETER, MAX_ATTACK_DIAMETER) / canvas_scale
	var joystick_radius := joystick_diameter * 0.5
	var run_radius := run_diameter * 0.5
	var attack_radius := attack_diameter * 0.5
	var joystick_center := Vector2(margin + joystick_radius, safe_size.y - margin - joystick_radius)
	var run_center := Vector2(safe_size.x - margin - run_radius, safe_size.y - margin - run_radius)
	var attack_center := Vector2(run_center.x - run_radius - attack_radius - (12.0 / canvas_scale), safe_size.y - margin - attack_radius)
	return {
		"viewport_size": safe_size,
		"display_size": safe_display_size,
		"canvas_scale": canvas_scale,
		"margin": margin,
		"joystick_center": joystick_center,
		"joystick_radius": joystick_radius,
		"run_center": run_center,
		"run_radius": run_radius,
		"attack_center": attack_center,
		"attack_radius": attack_radius,
		"control_top": minf(joystick_center.y - joystick_radius, minf(run_center.y - run_radius, attack_center.y - attack_radius)),
	}


func _on_viewport_size_changed() -> void:
	_apply_viewport_size(get_viewport_rect().size, Vector2(DisplayServer.window_get_size()))


func _apply_viewport_size(viewport_size: Vector2, display_size: Vector2 = Vector2.ZERO) -> void:
	reset_input()
	_layout_size = Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	_display_size = _layout_size if display_size.is_zero_approx() else Vector2(maxf(display_size.x, 1.0), maxf(display_size.y, 1.0))
	var metrics := calculate_layout(_layout_size, _display_size)
	_joystick_center = metrics["joystick_center"]
	_joystick_radius = metrics["joystick_radius"]
	_run_center = metrics["run_center"]
	_run_radius = metrics["run_radius"]
	_attack_center = metrics["attack_center"]
	_attack_radius = metrics["attack_radius"]
	_knob_position = _joystick_center
	var activation_radius := _joystick_radius * 1.45
	_joystick_activation_rect = Rect2(
		_joystick_center - Vector2.ONE * activation_radius,
		Vector2.ONE * activation_radius * 2.0
	)
	visible = _should_be_visible()
	queue_redraw()


func _should_be_visible() -> bool:
	if force_visible_for_testing or DisplayServer.is_touchscreen_available():
		return true
	return show_on_narrow_web and OS.has_feature("web") and _display_size.x <= NARROW_WEB_MAX_WIDTH


func _release_touch(index: int) -> bool:
	var handled := false
	if index == _joystick_touch_index:
		_joystick_touch_index = NO_TOUCH
		_movement_vector = Vector2.ZERO
		_knob_position = _joystick_center
		handled = true
	if index == _run_touch_index:
		_run_touch_index = NO_TOUCH
		_run_held = false
		handled = true
	if index == _attack_touch_index:
		_attack_touch_index = NO_TOUCH
		handled = true
	if handled:
		queue_redraw()
	return handled


func _update_joystick(position: Vector2) -> void:
	var displacement := position - _joystick_center
	var normalized_distance := displacement.length() / _joystick_radius
	if normalized_distance <= JOYSTICK_DEAD_ZONE:
		_movement_vector = Vector2.ZERO
		_knob_position = _joystick_center
	else:
		_movement_vector = (displacement / _joystick_radius).limit_length(1.0)
		_knob_position = _joystick_center + _movement_vector * (_joystick_radius * 0.58)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var base_color := Color(0.12, 0.19, 0.27, 0.72)
	var outline_color := Color(0.45, 0.72, 0.86, 0.9)
	var active_color := Color(0.2, 0.72, 0.88, 0.9)
	var knob_color := active_color if not _movement_vector.is_zero_approx() else Color(0.37, 0.52, 0.62, 0.82)
	draw_circle(_joystick_center, _joystick_radius, base_color)
	draw_arc(_joystick_center, _joystick_radius, 0.0, TAU, 64, outline_color, 3.0, true)
	draw_circle(_knob_position, _joystick_radius * 0.35, knob_color)

	var run_color := active_color if _run_held else base_color
	draw_circle(_run_center, _run_radius, run_color)
	draw_arc(_run_center, _run_radius, 0.0, TAU, 64, outline_color, 3.0, true)
	var attack_color := active_color if _attack_touch_index != NO_TOUCH else base_color
	draw_circle(_attack_center, _attack_radius, attack_color)
	draw_arc(_attack_center, _attack_radius, 0.0, TAU, 64, outline_color, 3.0, true)

	var font := ThemeDB.fallback_font
	var canvas_scale := maxf(minf(_display_size.x / _layout_size.x, _display_size.y / _layout_size.y), 0.001)
	var label_size := maxi(17, roundi(clampf(minf(_display_size.x, _display_size.y) * 0.052, 17.0, 26.0) / canvas_scale))
	_draw_centered_text(font, "MOVE", _joystick_center + Vector2(0.0, -_joystick_radius - 10.0), label_size - 3, outline_color)
	_draw_centered_text(font, "RUN", _run_center + Vector2(0.0, float(label_size) * 0.35), label_size, Color.WHITE)
	_draw_centered_text(
		font,
		"ATTACK",
		_attack_center + Vector2(0.0, float(label_size) * 0.35),
		maxi(14, label_size - 3),
		Color.WHITE
	)


func _draw_centered_text(font: Font, text: String, baseline_center: Vector2, font_size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	draw_string(
		font,
		Vector2(baseline_center.x - text_size.x * 0.5, baseline_center.y),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
