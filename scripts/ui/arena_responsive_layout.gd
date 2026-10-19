class_name ArenaResponsiveLayout
extends Node

const MobileTouchControlsClass = preload("res://scripts/ui/mobile_touch_controls.gd")

const WORLD_PRESENTATION_EXTENT_FEET := Vector2(48.0, 27.0)

@export var title_path: NodePath
@export var instructions_path: NodePath
@export var seed_label_path: NodePath
@export var seed_input_path: NodePath
@export var seed_apply_button_path: NodePath
@export var movement_debug_path: NodePath
@export var orientation_warning_path: NodePath
@export var combat_status_path: NodePath
@export var combat_log_path: NodePath
@export var developer_debug_path: NodePath
@export var encounter_button_path: NodePath
@export var encounter_selector_path: NodePath
@export var debug_button_path: NodePath
@export var attack_readiness_path: NodePath
@export var run_readiness_path: NodePath
@export var log_button_path: NodePath
@export var transcript_panel_path: NodePath
@export var battlefield_path: NodePath
@export var combat_controller_path: NodePath

@onready var _title: Label = get_node_or_null(title_path)
@onready var _instructions: Label = get_node_or_null(instructions_path)
@onready var _seed_label: Label = get_node_or_null(seed_label_path)
@onready var _seed_input: LineEdit = get_node_or_null(seed_input_path)
@onready var _seed_apply_button: Button = get_node_or_null(seed_apply_button_path)
@onready var _movement_debug: Label = get_node_or_null(movement_debug_path)
@onready var _orientation_warning: Label = get_node_or_null(orientation_warning_path)
@onready var _combat_status: Label = get_node_or_null(combat_status_path)
@onready var _combat_log: RichTextLabel = get_node_or_null(combat_log_path)
@onready var _developer_debug: RichTextLabel = get_node_or_null(developer_debug_path)
@onready var _encounter_button: Button = get_node_or_null(encounter_button_path)
@onready var _encounter_selector: Button = get_node_or_null(encounter_selector_path)
@onready var _debug_button: Button = get_node_or_null(debug_button_path)
@onready var _attack_readiness: Control = get_node_or_null(attack_readiness_path)
@onready var _run_readiness: Control = get_node_or_null(run_readiness_path)
@onready var _log_button: Button = get_node_or_null(log_button_path)
@onready var _transcript_panel: Control = get_node_or_null(transcript_panel_path)
@onready var _battlefield: ArenaBattlefieldView = get_node_or_null(battlefield_path)
@onready var _combat_controller: ArenaCombatController = get_node_or_null(combat_controller_path)

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
	var seed_y := instructions_rect.end.y + line_gap
	var seed_height := (28.0 if compact else 32.0) / canvas_scale
	var seed_gap := (6.0 if compact else 8.0) / canvas_scale
	var seed_label_width := (92.0 if compact else 108.0) / canvas_scale
	var seed_input_width := (116.0 if compact else 132.0) / canvas_scale
	var seed_button_width := (64.0 if compact else 72.0) / canvas_scale
	var seed_label_rect := Rect2(margin, seed_y, seed_label_width, seed_height)
	var seed_input_rect := Rect2(seed_label_rect.end.x + seed_gap, seed_y, seed_input_width, seed_height)
	var seed_apply_button_rect := Rect2(seed_input_rect.end.x + seed_gap, seed_y, seed_button_width, seed_height)
	var encounter_button_size := Vector2((104.0 if compact else 120.0) / canvas_scale, (48.0 if compact else 52.0) / canvas_scale)
	var encounter_button_rect := Rect2(
		safe_size.x - margin - encounter_button_size.x,
		title_rect.position.y,
		encounter_button_size.x,
		encounter_button_size.y
	)
	var toolbar_gap := (12.0 if compact else 16.0) / canvas_scale
	var debug_button_size := Vector2((108.0 if compact else 124.0) / canvas_scale, encounter_button_size.y)
	var debug_button_rect := Rect2(
		encounter_button_rect.position.x - toolbar_gap - debug_button_size.x,
		encounter_button_rect.position.y,
		debug_button_size.x,
		debug_button_size.y
	)
	var log_button_size := Vector2((116.0 if compact else 132.0) / canvas_scale, encounter_button_size.y)
	var log_button_rect := Rect2(
		debug_button_rect.position.x - toolbar_gap - log_button_size.x,
		encounter_button_rect.position.y,
		log_button_size.x,
		log_button_size.y
	)
	var selector_button_size := Vector2((104.0 if compact else 132.0) / canvas_scale, encounter_button_size.y)
	var selector_button_rect := Rect2(
		log_button_rect.position.x - toolbar_gap - selector_button_size.x,
		encounter_button_rect.position.y,
		selector_button_size.x,
		selector_button_size.y
	)
	var debug_y := seed_label_rect.end.y + ((6.0 if compact else 14.0) / canvas_scale)
	var touch_layout := MobileTouchControlsClass.calculate_layout(safe_size, safe_display_size)
	var debug_bottom_limit: float = touch_layout["control_top"] - (10.0 / canvas_scale)
	var debug_width := minf(safe_size.x * 0.5, (520.0 / canvas_scale))
	var debug_height := (44.0 if compact else 56.0) / canvas_scale
	var debug_rect := Rect2(margin, debug_y, debug_width, debug_height)
	var combat_gap := (12.0 / canvas_scale)
	var combat_status_height := (92.0 if compact else 112.0) / canvas_scale
	var combat_x := margin
	# Keep the player-facing status inside the left HUD lane. The battlefield's
	# actor labels enter the center lane first on compact landscape viewports.
	var combat_width := minf(debug_width, safe_size.x * 0.28)
	var combat_y := debug_rect.end.y + line_gap
	var readiness_size := Vector2((104.0 if compact else 116.0) / canvas_scale, (100.0 if compact else 112.0) / canvas_scale)
	var readiness_gap := (6.0 if compact else 10.0) / canvas_scale
	var readiness_pair_width := readiness_size.x * 2.0 + readiness_gap
	var combat_log_min_x := maxf(safe_size.x * 0.72, combat_x + combat_width + combat_gap)
	var combat_log_available_width := safe_size.x - margin - combat_log_min_x
	var combat_log_width := minf(460.0 / canvas_scale, combat_log_available_width)
	combat_log_width = maxf(120.0 / canvas_scale, combat_log_width)
	var combat_log_x := safe_size.x - margin - combat_log_width
	var readiness_y := debug_y
	var attack_readiness_rect := Rect2(combat_log_x, readiness_y, readiness_size.x, readiness_size.y)
	var run_readiness_rect := Rect2(attack_readiness_rect.end.x + readiness_gap, readiness_y, readiness_size.x, readiness_size.y)
	var readiness_log_gap := 24.0 / canvas_scale
	var combat_log_y := readiness_y + readiness_size.y + readiness_log_gap
	if portrait:
		attack_readiness_rect.position = Vector2(margin, debug_rect.end.y + line_gap)
		run_readiness_rect.position = Vector2(attack_readiness_rect.end.x + readiness_gap, attack_readiness_rect.position.y)
		combat_x = margin
		combat_width = safe_size.x - margin * 2.0
		combat_y = attack_readiness_rect.end.y + combat_gap
		combat_log_x = margin
		combat_log_width = combat_width
		combat_log_y = combat_y + combat_status_height + readiness_log_gap
	var combat_status_rect := Rect2(combat_x, combat_y, combat_width, combat_status_height)
	var combat_log_rect := Rect2(
		combat_log_x,
		combat_log_y,
		combat_log_width,
		maxf(42.0 / canvas_scale, debug_bottom_limit - combat_log_y)
	)
	var developer_debug_rect := Rect2(
		margin,
		debug_y,
		safe_size.x - margin * 2.0,
		maxf(42.0 / canvas_scale, debug_bottom_limit - debug_y)
	)
	var transcript_panel_rect := Rect2(
		margin,
		seed_label_rect.end.y + line_gap,
		safe_size.x - margin * 2.0,
		maxf(120.0 / canvas_scale, debug_bottom_limit - seed_label_rect.end.y - line_gap)
	)
	return {
		"viewport_size": safe_size,
		"display_size": safe_display_size,
		"canvas_scale": canvas_scale,
		"compact": compact,
		"portrait": portrait,
		"title_rect": title_rect,
		"instructions_rect": instructions_rect,
		"seed_label_rect": seed_label_rect,
		"seed_input_rect": seed_input_rect,
		"seed_apply_button_rect": seed_apply_button_rect,
		"movement_debug_rect": debug_rect,
		"orientation_warning_rect": warning_rect,
		"combat_status_rect": combat_status_rect,
		"combat_log_rect": combat_log_rect,
		"developer_debug_rect": developer_debug_rect,
		"encounter_button_rect": encounter_button_rect,
		"encounter_selector_rect": selector_button_rect,
		"debug_button_rect": debug_button_rect,
		"log_button_rect": log_button_rect,
		"transcript_panel_rect": transcript_panel_rect,
		"attack_readiness_rect": attack_readiness_rect,
		"run_readiness_rect": run_readiness_rect,
		"title_font_size": maxi(1, roundi((18.0 if compact else 22.0) / canvas_scale)),
		"instructions_font_size": maxi(1, roundi((12.0 if compact else 16.0) / canvas_scale)),
		"debug_font_size": maxi(1, roundi((11.0 if compact else 15.0) / canvas_scale)),
		"warning_font_size": maxi(1, roundi(14.0 / canvas_scale)),
		"combat_font_size": maxi(1, roundi((11.0 if compact else 14.0) / canvas_scale)),
		"touch_control_top": touch_layout["control_top"],
	}


static func calculate_battlefield_presentation(viewport_size: Vector2) -> Dictionary:
	var safe_size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var pixels_per_foot := minf(
		safe_size.x / WORLD_PRESENTATION_EXTENT_FEET.x,
		safe_size.y / WORLD_PRESENTATION_EXTENT_FEET.y
	)
	return {
		"pixels_per_foot": pixels_per_foot,
		"arena_rect": Rect2(
			Vector2(2.0, 2.0) * pixels_per_foot,
			Vector2(44.0, 23.0) * pixels_per_foot
		),
	}


func _on_viewport_size_changed() -> void:
	_apply_layout(get_viewport().get_visible_rect().size, Vector2(DisplayServer.window_get_size()))


func _apply_layout(viewport_size: Vector2, display_size: Vector2 = Vector2.ZERO) -> void:
	_last_viewport_size = viewport_size
	_last_display_size = viewport_size if display_size.is_zero_approx() else display_size
	var metrics := calculate_layout(viewport_size, display_size)
	var battlefield_metrics := calculate_battlefield_presentation(viewport_size)
	var pixels_per_foot := float(battlefield_metrics["pixels_per_foot"])
	if _battlefield != null:
		_battlefield.pixels_per_foot = pixels_per_foot
		_battlefield.queue_redraw()
	if _combat_controller != null:
		_combat_controller.set_world_presentation_pixels_per_foot(pixels_per_foot, viewport_size)
	_apply_control_rect(_title, metrics["title_rect"])
	_apply_control_rect(_instructions, metrics["instructions_rect"])
	_apply_control_rect(_seed_label, metrics["seed_label_rect"])
	_apply_control_rect(_seed_input, metrics["seed_input_rect"])
	_apply_control_rect(_seed_apply_button, metrics["seed_apply_button_rect"])
	_apply_control_rect(_movement_debug, metrics["movement_debug_rect"])
	_apply_control_rect(_orientation_warning, metrics["orientation_warning_rect"])
	_apply_control_rect(_combat_status, metrics["combat_status_rect"])
	_apply_control_rect(_combat_log, metrics["combat_log_rect"])
	_apply_control_rect(_developer_debug, metrics["developer_debug_rect"])
	_apply_control_rect(_encounter_button, metrics["encounter_button_rect"])
	_apply_control_rect(_encounter_selector, metrics["encounter_selector_rect"])
	_apply_control_rect(_debug_button, metrics["debug_button_rect"])
	_apply_control_rect(_attack_readiness, metrics["attack_readiness_rect"])
	_apply_control_rect(_run_readiness, metrics["run_readiness_rect"])
	_apply_control_rect(_log_button, metrics["log_button_rect"])
	_apply_control_rect(_transcript_panel, metrics["transcript_panel_rect"])
	if _title != null:
		_title.add_theme_font_size_override("font_size", metrics["title_font_size"])
	if _instructions != null:
		_instructions.add_theme_font_size_override("font_size", metrics["instructions_font_size"])
		_instructions.text = (
			"START | Move: WASD/touch | Run: Shift/RUN | Attack | F3 debug | F4 log"
			if metrics["compact"]
			else "START; WASD/touch moves; Shift/RUN runs; click attacks once; hold Space/Enter or touch ATTACK; R resets; F3 debug; F4 full log"
		)
	if _seed_label != null:
		_seed_label.add_theme_font_size_override("font_size", metrics["instructions_font_size"])
	if _seed_input != null:
		_seed_input.add_theme_font_size_override("font_size", metrics["instructions_font_size"])
	if _seed_apply_button != null:
		_seed_apply_button.add_theme_font_size_override("font_size", metrics["instructions_font_size"])
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
	if _developer_debug != null:
		_developer_debug.add_theme_font_size_override("normal_font_size", metrics["debug_font_size"])
		_developer_debug.add_theme_font_size_override("bold_font_size", metrics["debug_font_size"])


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size
