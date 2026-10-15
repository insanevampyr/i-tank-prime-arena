class_name ArenaResponsiveLayout
extends Node

const MobileTouchControlsClass = preload("res://scripts/ui/mobile_touch_controls.gd")

@export var title_path: NodePath
@export var instructions_path: NodePath
@export var movement_debug_path: NodePath
@export var orientation_warning_path: NodePath
@export var combat_status_path: NodePath
@export var combat_log_path: NodePath
@export var encounter_button_path: NodePath

@onready var _title: Label = get_node_or_null(title_path)
@onready var _instructions: Label = get_node_or_null(instructions_path)
@onready var _movement_debug: Label = get_node_or_null(movement_debug_path)
@onready var _orientation_warning: Label = get_node_or_null(orientation_warning_path)
@onready var _combat_status: Label = get_node_or_null(combat_status_path)
@onready var _combat_log: RichTextLabel = get_node_or_null(combat_log_path)
@onready var _encounter_button: Button = get_node_or_null(encounter_button_path)

var _last_viewport_size: Vector2 = Vector2.ZERO
var _last_display_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_process(true)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_layout(get_viewport().get_visible_rect().size, Vector2(DisplayServer.window_get_size()))


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var display_size := Vector2(DisplayServer.window_get_size())
	if not viewport_size.is_equal_approx(_last_viewport_size) or not display_size.is_equal_approx(_last_display_size):
		_apply_layout(viewport_size, display_size)


static func calculate_layout(viewport_size: Vector2, display_size: Vector2 = Vector2.ZERO) -> Dictionary:
	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var safe_display_size := safe_size if display_size.is_zero_approx() else Vector2(maxf(display_size.x, 1.0), maxf(display_size.y, 1.0))
	var canvas_scale := minf(safe_display_size.x / safe_size.x, safe_display_size.y / safe_size.y)
	canvas_scale = maxf(canvas_scale, 0.001)
	var compact := safe_display_size.y < 500.0 or safe_display_size.x < 900.0
	var portrait := safe_display_size.y > safe_display_size.x
	var margin := (12.0 if compact else 32.0) / canvas_scale
	var title_height := (24.0 if compact else 32.0) / canvas_scale
	var line_gap := (4.0 if compact else 6.0) / canvas_scale
	var warning_height := (22.0 / canvas_scale) if portrait else 0.0
	var title_rect := Rect2(margin, (10.0 if compact else 24.0) / canvas_scale, safe_size.x - margin * 2.0, title_height)
	var next_y := title_rect.end.y + line_gap
	var warning_rect := Rect2(margin, next_y, safe_size.x - margin * 2.0, warning_height)
	if portrait:
		next_y = warning_rect.end.y + line_gap
	var instructions_height := (20.0 if compact else 26.0) / canvas_scale
	var instructions_rect := Rect2(margin, next_y, safe_size.x - margin * 2.0, instructions_height)
	var encounter_button_size := Vector2((104.0 if compact else 120.0) / canvas_scale, (48.0 if compact else 52.0) / canvas_scale)
	var encounter_button_rect := Rect2(
		safe_size.x - margin - encounter_button_size.x,
		title_rect.position.y,
		encounter_button_size.x,
		encounter_button_size.y
	)
	var debug_y := instructions_rect.end.y + ((6.0 if compact else 14.0) / canvas_scale)
	var touch_layout := MobileTouchControlsClass.calculate_layout(safe_size, safe_display_size)
	var debug_bottom_limit: float = touch_layout["control_top"] - (10.0 / canvas_scale)
	var debug_width := minf(safe_size.x - margin * 2.0, (360.0 if compact else 500.0) / canvas_scale)
	var debug_height := maxf(72.0 / canvas_scale, debug_bottom_limit - debug_y)
	var debug_rect := Rect2(margin, debug_y, debug_width, debug_height)
	var combat_gap := (12.0 / canvas_scale)
	var combat_status_height := (82.0 if compact else 110.0) / canvas_scale
	var combat_x := margin + debug_width + combat_gap
	var combat_width := maxf(120.0 / canvas_scale, safe_size.x - combat_x - margin)
	var combat_y := debug_y
	if portrait:
		debug_height = minf(debug_height, 168.0 / canvas_scale)
		debug_rect.size.y = debug_height
		combat_x = margin
		combat_width = safe_size.x - margin * 2.0
		combat_y = debug_rect.end.y + combat_gap
	var combat_status_rect := Rect2(combat_x, combat_y, combat_width, combat_status_height)
	var combat_log_y := combat_status_rect.end.y + line_gap
	var combat_log_rect := Rect2(
		combat_x,
		combat_log_y,
		combat_width,
		maxf(42.0 / canvas_scale, debug_bottom_limit - combat_log_y)
	)
	return {
		"viewport_size": safe_size,
		"display_size": safe_display_size,
		"canvas_scale": canvas_scale,
		"compact": compact,
		"portrait": portrait,
		"title_rect": title_rect,
		"instructions_rect": instructions_rect,
		"movement_debug_rect": debug_rect,
		"orientation_warning_rect": warning_rect,
		"combat_status_rect": combat_status_rect,
		"combat_log_rect": combat_log_rect,
		"encounter_button_rect": encounter_button_rect,
		"title_font_size": maxi(1, roundi((18.0 if compact else 22.0) / canvas_scale)),
		"instructions_font_size": maxi(1, roundi((12.0 if compact else 16.0) / canvas_scale)),
		"debug_font_size": maxi(1, roundi((11.0 if compact else 15.0) / canvas_scale)),
		"warning_font_size": maxi(1, roundi(14.0 / canvas_scale)),
		"combat_font_size": maxi(1, roundi((11.0 if compact else 14.0) / canvas_scale)),
		"touch_control_top": touch_layout["control_top"],
	}


func _on_viewport_size_changed() -> void:
	_apply_layout(get_viewport().get_visible_rect().size, Vector2(DisplayServer.window_get_size()))


func _apply_layout(viewport_size: Vector2, display_size: Vector2 = Vector2.ZERO) -> void:
	_last_viewport_size = viewport_size
	_last_display_size = viewport_size if display_size.is_zero_approx() else display_size
	var metrics := calculate_layout(viewport_size, display_size)
	_apply_control_rect(_title, metrics["title_rect"])
	_apply_control_rect(_instructions, metrics["instructions_rect"])
	_apply_control_rect(_movement_debug, metrics["movement_debug_rect"])
	_apply_control_rect(_orientation_warning, metrics["orientation_warning_rect"])
	_apply_control_rect(_combat_status, metrics["combat_status_rect"])
	_apply_control_rect(_combat_log, metrics["combat_log_rect"])
	_apply_control_rect(_encounter_button, metrics["encounter_button_rect"])
	if _title != null:
		_title.add_theme_font_size_override("font_size", metrics["title_font_size"])
	if _instructions != null:
		_instructions.add_theme_font_size_override("font_size", metrics["instructions_font_size"])
		_instructions.text = (
			"START first | Move: WASD/touch | Run: Shift/RUN | Action: Space/ATTACK | R: reset"
			if metrics["compact"]
			else "START the encounter; WASD/touch moves; Shift/RUN runs; select target; Space/Enter/ATTACK acts; R resets"
		)
	if _movement_debug != null:
		_movement_debug.add_theme_font_size_override("font_size", metrics["debug_font_size"])
	if _orientation_warning != null:
		_orientation_warning.add_theme_font_size_override("font_size", metrics["warning_font_size"])
		_orientation_warning.visible = metrics["portrait"]
	if _combat_status != null:
		_combat_status.add_theme_font_size_override("font_size", metrics["combat_font_size"])
	if _combat_log != null:
		_combat_log.add_theme_font_size_override("normal_font_size", metrics["combat_font_size"])
		_combat_log.add_theme_font_size_override("bold_font_size", metrics["combat_font_size"])


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size
