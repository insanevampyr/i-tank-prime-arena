class_name ArenaReadinessIndicator
extends Control

const Readiness = preload("res://scripts/ui/combat_readiness_model.gd")

enum IndicatorKind {
	ATTACK,
	RUN,
}

const READY_COLOR := Color(0.25, 0.85, 0.48, 1.0)
const ACTIVE_COLOR := Color(0.3, 0.72, 1.0, 1.0)
const WAIT_COLOR := Color(1.0, 0.72, 0.2, 1.0)
const BLOCKED_COLOR := Color(0.95, 0.3, 0.3, 1.0)
const TRACK_COLOR := Color(0.24, 0.29, 0.35, 1.0)
const PANEL_COLOR := Color(0.045, 0.06, 0.08, 0.9)
const TEXT_COLOR := Color(0.9, 0.94, 0.98, 1.0)

@export var indicator_kind: IndicatorKind = IndicatorKind.ATTACK

var _readiness := {
	"state": Readiness.STATE_BLOCKED,
	"status_text": "BLOCKED",
	"value_text": "START",
	"progress": 0.0,
	"remaining_us": 0,
	"total_us": 0,
	"reason": "initializing",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_readiness(value: Dictionary) -> void:
	if _readiness == value:
		return
	_readiness = value.duplicate(true)
	queue_redraw()


func get_readiness_for_testing() -> Dictionary:
	return _readiness.duplicate(true)


func _draw() -> void:
	var value := String(_readiness.get("value_text", ""))
	var show_value := not value.is_empty() and size.y >= 68.0
	var center := Vector2(size.x * 0.5, minf(size.y * (0.25 if show_value else 0.34), 24.0 if show_value else 31.0))
	var radius := minf(19.0 if show_value else 23.0, minf(size.x * (0.22 if show_value else 0.28), size.y * (0.21 if show_value else 0.27)))
	var color := _state_color(String(_readiness.get("state", Readiness.STATE_BLOCKED)))
	draw_circle(center, radius + 7.0, PANEL_COLOR)
	draw_arc(center, radius + 3.0, -PI * 0.5, PI * 1.5, 48, TRACK_COLOR, 5.0, true)
	var progress := clampf(float(_readiness.get("progress", 0.0)), 0.0, 1.0)
	if progress > 0.0:
		draw_arc(center, radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, color, 5.0, true)
	if indicator_kind == IndicatorKind.ATTACK:
		_draw_swords(center, color)
	else:
		_draw_footprints(center, color)

	var font := ThemeDB.fallback_font
	var font_size := maxi(9, mini(12, roundi(size.y * 0.13)))
	var title := (
		"ATTACK HOLD"
		if indicator_kind == IndicatorKind.ATTACK and bool(_readiness.get("hold_active", false))
		else ("ATTACK" if indicator_kind == IndicatorKind.ATTACK else "RUN")
	)
	var status := String(_readiness.get("status_text", "BLOCKED"))
	if not value.is_empty() and not show_value:
		match String(_readiness.get("state", Readiness.STATE_BLOCKED)):
			Readiness.STATE_ATTACKING, Readiness.STATE_RUNNING:
				status = "ACTIVE %s" % value
			Readiness.STATE_STAGGERED:
				status = "STAGGER %s" % value
			Readiness.STATE_RECOVERING:
				status = "RECOVER %s" % value
			Readiness.STATE_RETRY:
				status = "RETRY %s" % value
	var bottom_baseline := size.y - 10.0
	var status_baseline := bottom_baseline - (12.0 if show_value else 0.0)
	var title_baseline := status_baseline - 12.0
	_draw_centered_text(font, title, Vector2(0.0, title_baseline), font_size, TEXT_COLOR)
	_draw_centered_text(font, status, Vector2(0.0, status_baseline), font_size - 1, color)
	if show_value:
		_draw_centered_text(font, value, Vector2(0.0, bottom_baseline), maxi(8, font_size - 2), TEXT_COLOR)


func _draw_swords(center: Vector2, color: Color) -> void:
	draw_line(center + Vector2(-10, 10), center + Vector2(10, -10), color, 4.0, true)
	draw_line(center + Vector2(-10, -10), center + Vector2(10, 10), color, 4.0, true)
	draw_line(center + Vector2(-12, 5), center + Vector2(-5, 12), color, 3.0, true)
	draw_line(center + Vector2(5, 12), center + Vector2(12, 5), color, 3.0, true)


func _draw_footprints(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-7, 6), 5.0, color)
	draw_circle(center + Vector2(6, -6), 5.0, color)
	draw_circle(center + Vector2(-10, -1), 2.2, color)
	draw_circle(center + Vector2(9, -13), 2.2, color)


func _draw_centered_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, position.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _state_color(state: String) -> Color:
	match state:
		Readiness.STATE_READY:
			return READY_COLOR
		Readiness.STATE_ATTACKING, Readiness.STATE_RUNNING:
			return ACTIVE_COLOR
		Readiness.STATE_RECOVERING, Readiness.STATE_RETRY:
			return WAIT_COLOR
		_:
			return BLOCKED_COLOR
