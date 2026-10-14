extends SceneTree

const CombatFoundationTests = preload("res://tests/test_combat_foundation.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var suite := CombatFoundationTests.new()
	var failures := suite.run()
	if failures.is_empty():
		print("PASS: combat foundation tests")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	print("FAIL: %d combat foundation test(s)" % failures.size())
	quit(1)
