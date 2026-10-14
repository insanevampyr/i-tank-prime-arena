extends SceneTree

const CombatFoundationTests = preload("res://tests/test_combat_foundation.gd")
const SyncFoundationTests = preload("res://tests/test_sync_foundation.gd")
const PrimeMovementTests = preload("res://tests/test_prime_movement.gd")
const CombatActorActionTests = preload("res://tests/test_combat_actor_actions.gd")
const PhysicalAttackTests = preload("res://tests/test_physical_attacks.gd")
const PhysicalDefenseTests = preload("res://tests/test_physical_defenses.gd")
const PhysicalDamageTests = preload("res://tests/test_physical_damage.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var suites := [
		{"name": "combat foundation", "instance": CombatFoundationTests.new()},
		{"name": "two-client synchronization", "instance": SyncFoundationTests.new()},
		{"name": "Prime movement", "instance": PrimeMovementTests.new()},
		{"name": "combat actor and action", "instance": CombatActorActionTests.new()},
		{"name": "opening initiative and physical attack", "instance": PhysicalAttackTests.new()},
		{"name": "physical defense", "instance": PhysicalDefenseTests.new()},
		{"name": "physical damage", "instance": PhysicalDamageTests.new()},
	]
	var failure_count := 0
	for suite: Dictionary in suites:
		var failures: Array[String] = suite["instance"].run()
		if failures.is_empty():
			print("PASS: %s tests" % suite["name"])
			continue
		for failure: String in failures:
			push_error("%s: %s" % [suite["name"], failure])
		failure_count += failures.size()

	if failure_count == 0:
		print("PASS: all test suites")
		quit(0)
		return

	print("FAIL: %d test assertion(s)" % failure_count)
	quit(1)
