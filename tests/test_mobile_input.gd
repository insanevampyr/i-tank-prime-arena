extends RefCounted

const ArenaPlayerInputIntentClass = preload("res://scripts/input/arena_player_input_intent.gd")
const MobileTouchControlsClass = preload("res://scripts/ui/mobile_touch_controls.gd")
const ArenaResponsiveLayoutClass = preload("res://scripts/ui/arena_responsive_layout.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_desktop_input_is_preserved()
	_test_touch_joystick_direction_and_release()
	_test_multitouch_movement_and_running()
	_test_multitouch_movement_running_and_attack()
	_test_cancel_and_focus_reset_clear_input()
	_test_resize_clears_active_touches()
	_test_android_sized_layouts_stay_inside_viewport()
	_test_touch_targets_survive_canvas_scaling()
	_test_portrait_layout_recommends_landscape()
	return _failures


func _test_desktop_input_is_preserved() -> void:
	var desktop := Vector2(1.0, -1.0)
	_expect_equal(
		ArenaPlayerInputIntentClass.combine_movement(desktop, Vector2.ZERO),
		desktop,
		"Desktop-only movement must pass through unchanged."
	)
	_expect_true(ArenaPlayerInputIntentClass.combine_run(true, false), "Desktop Shift must still request Running.")
	_expect_true(ArenaPlayerInputIntentClass.combine_run(false, true), "Touch RUN must use the same Running intent.")


func _test_touch_joystick_direction_and_release() -> void:
	var controls: Control = _make_controls(Vector2(800.0, 360.0))
	var layout: Dictionary = controls.get_layout_snapshot()
	var center: Vector2 = layout["joystick_center"]
	var radius: float = layout["joystick_radius"]
	_expect_true(controls.handle_touch(1, true, center), "The lower-left joystick must capture a touch.")
	_expect_true(controls.handle_drag(1, center + Vector2(radius, 0.0)), "The captured joystick finger must accept drag updates.")
	_expect_true(controls.get_movement_vector().x > 0.99, "A full-right joystick drag must produce rightward movement intent.")
	_expect_true(controls.handle_touch(1, false, center + Vector2(radius, 0.0)), "The joystick must release its captured finger.")
	_expect_true(controls.get_movement_vector().is_zero_approx(), "Releasing the joystick must clear movement intent.")
	controls.free()


func _test_multitouch_movement_and_running() -> void:
	var controls: Control = _make_controls(Vector2(915.0, 412.0))
	var layout: Dictionary = controls.get_layout_snapshot()
	var joystick_center: Vector2 = layout["joystick_center"]
	var joystick_radius: float = layout["joystick_radius"]
	var run_center: Vector2 = layout["run_center"]
	controls.handle_touch(3, true, joystick_center)
	controls.handle_drag(3, joystick_center + Vector2(0.0, -joystick_radius))
	controls.handle_touch(8, true, run_center)
	_expect_true(controls.get_movement_vector().y < -0.99, "One finger must retain joystick movement while another holds RUN.")
	_expect_true(controls.is_run_held(), "A second simultaneous finger must hold RUN.")
	controls.handle_touch(3, false, joystick_center)
	_expect_true(controls.is_run_held(), "Releasing movement must not release a separately tracked RUN finger.")
	controls.handle_touch(8, false, run_center)
	_expect_true(not controls.is_run_held(), "Releasing the RUN finger must clear only RUN.")
	controls.free()


func _test_multitouch_movement_running_and_attack() -> void:
	var controls: Control = _make_controls(Vector2(915.0, 412.0))
	var layout: Dictionary = controls.get_layout_snapshot()
	controls.handle_touch(1, true, layout["joystick_center"])
	controls.handle_drag(1, layout["joystick_center"] + Vector2(layout["joystick_radius"], 0.0))
	controls.handle_touch(2, true, layout["run_center"])
	controls.handle_touch(3, true, layout["attack_center"])
	_expect_true(controls.get_movement_vector().x > 0.99, "Movement must remain active while RUN and ATTACK use separate fingers.")
	_expect_true(controls.is_run_held(), "RUN must remain held during a simultaneous ATTACK touch.")
	_expect_true(controls.consume_attack_requested(), "ATTACK must emit through the same one-shot action-intent boundary.")
	_expect_true(not controls.consume_attack_requested(), "One ATTACK press must not duplicate its action intent.")
	controls.reset_input()
	_expect_true(not controls.consume_attack_requested(), "Focus/reset must clear an unconsumed ATTACK intent.")
	controls.free()


func _test_cancel_and_focus_reset_clear_input() -> void:
	var controls: Control = _make_controls(Vector2(800.0, 360.0))
	var layout: Dictionary = controls.get_layout_snapshot()
	var run_center: Vector2 = layout["run_center"]
	controls.handle_touch(2, true, run_center)
	controls.handle_touch(2, false, run_center, true)
	_expect_true(not controls.is_run_held(), "A browser-canceled touch must not leave RUN held.")
	var joystick_center: Vector2 = layout["joystick_center"]
	controls.handle_touch(4, true, joystick_center + Vector2(layout["joystick_radius"], 0.0))
	controls.handle_touch(5, true, run_center)
	controls.reset_input()
	_expect_true(controls.get_movement_vector().is_zero_approx(), "Focus-loss reset must clear movement.")
	_expect_true(not controls.is_run_held(), "Focus-loss reset must clear RUN.")
	controls.free()


func _test_resize_clears_active_touches() -> void:
	var controls: Control = _make_controls(Vector2(800.0, 360.0))
	var layout: Dictionary = controls.get_layout_snapshot()
	controls.handle_touch(1, true, layout["joystick_center"] + Vector2(layout["joystick_radius"], 0.0))
	controls.handle_touch(2, true, layout["run_center"])
	controls.set_viewport_size_for_testing(Vector2(360.0, 800.0))
	_expect_true(controls.get_movement_vector().is_zero_approx(), "Rotation or resize must clear stale joystick input.")
	_expect_true(not controls.is_run_held(), "Rotation or resize must clear stale RUN input.")
	controls.free()


func _test_android_sized_layouts_stay_inside_viewport() -> void:
	var sizes := [Vector2(800.0, 360.0), Vector2(915.0, 412.0), Vector2(1280.0, 720.0)]
	for viewport_size: Vector2 in sizes:
		var touch_layout := MobileTouchControlsClass.calculate_layout(viewport_size)
		_assert_circle_inside(touch_layout["joystick_center"], touch_layout["joystick_radius"], viewport_size, "joystick")
		_assert_circle_inside(touch_layout["run_center"], touch_layout["run_radius"], viewport_size, "RUN")
		_assert_circle_inside(touch_layout["attack_center"], touch_layout["attack_radius"], viewport_size, "ATTACK")
		_expect_true(touch_layout["joystick_radius"] * 2.0 >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "Joystick target must remain at least 96 logical pixels.")
		_expect_true(touch_layout["run_radius"] * 2.0 >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "RUN target must remain at least 96 logical pixels.")
		_expect_true(touch_layout["attack_radius"] * 2.0 >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "ATTACK target must remain at least 96 logical pixels.")
		var separation: float = touch_layout["joystick_center"].distance_to(touch_layout["run_center"])
		_expect_true(separation > touch_layout["joystick_radius"] + touch_layout["run_radius"], "Touch controls must not overlap.")
		_expect_true(touch_layout["attack_center"].distance_to(touch_layout["run_center"]) >= touch_layout["attack_radius"] + touch_layout["run_radius"], "ATTACK and RUN targets must not overlap.")
		var ui_layout := ArenaResponsiveLayoutClass.calculate_layout(viewport_size)
		var debug_rect: Rect2 = ui_layout["movement_debug_rect"]
		_expect_true(debug_rect.end.y <= float(ui_layout["touch_control_top"]), "Status information must remain above touch controls.")


func _test_portrait_layout_recommends_landscape() -> void:
	var layout := ArenaResponsiveLayoutClass.calculate_layout(Vector2(360.0, 800.0))
	_expect_true(layout["portrait"], "Portrait viewport must be identified for the landscape recommendation.")
	var warning_rect: Rect2 = layout["orientation_warning_rect"]
	_expect_true(warning_rect.size.y > 0.0, "Portrait layout must reserve visible space for the orientation warning.")
	var touch_layout := MobileTouchControlsClass.calculate_layout(Vector2(360.0, 800.0))
	_assert_circle_inside(touch_layout["joystick_center"], touch_layout["joystick_radius"], Vector2(360.0, 800.0), "portrait joystick")
	_assert_circle_inside(touch_layout["run_center"], touch_layout["run_radius"], Vector2(360.0, 800.0), "portrait RUN")
	_assert_circle_inside(touch_layout["attack_center"], touch_layout["attack_radius"], Vector2(360.0, 800.0), "portrait ATTACK")


func _test_touch_targets_survive_canvas_scaling() -> void:
	var logical_size := Vector2(1152.0, 2073.6)
	var display_size := Vector2(360.0, 648.0)
	var layout := MobileTouchControlsClass.calculate_layout(logical_size, display_size)
	var canvas_scale: float = layout["canvas_scale"]
	_expect_true(layout["joystick_radius"] * 2.0 * canvas_scale >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "Scaled joystick target must remain at least 96 display pixels.")
	_expect_true(layout["run_radius"] * 2.0 * canvas_scale >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "Scaled RUN target must remain at least 96 display pixels.")
	_expect_true(layout["attack_radius"] * 2.0 * canvas_scale >= MobileTouchControlsClass.MIN_TOUCH_DIAMETER, "Scaled ATTACK target must remain at least 96 display pixels.")
	var ui_layout := ArenaResponsiveLayoutClass.calculate_layout(logical_size, display_size)
	var debug_rect: Rect2 = ui_layout["movement_debug_rect"]
	_expect_true(debug_rect.end.y <= float(ui_layout["touch_control_top"]), "Scaled status layout must remain above touch controls.")


func _make_controls(viewport_size: Vector2) -> Control:
	var controls: Control = MobileTouchControlsClass.new()
	controls.set_viewport_size_for_testing(viewport_size)
	return controls


func _assert_circle_inside(center: Vector2, radius: float, viewport_size: Vector2, label: String) -> void:
	_expect_true(center.x - radius >= 0.0, "%s must remain inside the left edge." % label)
	_expect_true(center.y - radius >= 0.0, "%s must remain inside the top edge." % label)
	_expect_true(center.x + radius <= viewport_size.x, "%s must remain inside the right edge." % label)
	_expect_true(center.y + radius <= viewport_size.y, "%s must remain inside the bottom edge." % label)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
