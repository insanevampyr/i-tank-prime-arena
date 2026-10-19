class_name ArenaPlayerInputIntent
extends RefCounted


static func combine_keyboard_movement(wasd_direction: Vector2, arrow_direction: Vector2) -> Vector2:
	return (wasd_direction + arrow_direction).limit_length(1.0)


static func combine_movement(desktop_direction: Vector2, touch_direction: Vector2) -> Vector2:
	if desktop_direction.is_zero_approx():
		return touch_direction.limit_length(1.0)
	if touch_direction.is_zero_approx():
		return desktop_direction
	return (desktop_direction.normalized() + touch_direction.normalized()).limit_length(1.0)


static func combine_run(desktop_held: bool, touch_held: bool) -> bool:
	return desktop_held or touch_held
