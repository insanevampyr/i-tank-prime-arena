extends SceneTree

const CombatFoundationTests = preload("res://tests/test_combat_foundation.gd")
const SyncFoundationTests = preload("res://tests/test_sync_foundation.gd")
const PrimeMovementTests = preload("res://tests/test_prime_movement.gd")
const CombatActorActionTests = preload("res://tests/test_combat_actor_actions.gd")
const PhysicalAttackTests = preload("res://tests/test_physical_attacks.gd")
const PhysicalDefenseTests = preload("res://tests/test_physical_defenses.gd")
const PhysicalDamageTests = preload("res://tests/test_physical_damage.gd")
const CriticalFoundationTests = preload("res://tests/test_critical_foundation.gd")
const CriticalConsequenceTests = preload("res://tests/test_critical_consequences.gd")
const MobileInputTests = preload("res://tests/test_mobile_input.gd")
const PlayableCombatIntegrationTests = preload("res://tests/test_playable_combat_integration.gd")
const TwoWayCombatEncounterTests = preload("res://tests/test_two_way_combat_encounter.gd")
const BattlefieldMovementTests = preload("res://tests/test_battlefield_movement.gd")
const ProneCombatMovingTargetTests = preload("res://tests/test_prone_combat_and_moving_targets.gd")
const CombatUsabilityTests = preload("res://tests/test_combat_usability.gd")
const CombatReadinessHudTests = preload("res://tests/test_combat_readiness_hud.gd")
const PlaytestQualityTests = preload("res://tests/test_playtest_quality.gd")
const FloatingCombatTextTests = preload("res://tests/test_floating_combat_text.gd")
const CharacterEquipmentFoundationTests = preload("res://tests/test_character_equipment_foundation.gd")


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
		{"name": "critical foundation", "instance": CriticalFoundationTests.new()},
		{"name": "approved critical consequences", "instance": CriticalConsequenceTests.new()},
		{"name": "mobile input and responsive layout", "instance": MobileInputTests.new()},
		{"name": "playable combat integration", "instance": PlayableCombatIntegrationTests.new()},
		{"name": "two-way combat encounter", "instance": TwoWayCombatEncounterTests.new()},
		{"name": "battlefield movement and approach", "instance": BattlefieldMovementTests.new()},
		{"name": "prone combat and moving-target accuracy", "instance": ProneCombatMovingTargetTests.new()},
		{"name": "combat usability and pursuit", "instance": CombatUsabilityTests.new()},
		{"name": "combat readiness HUD", "instance": CombatReadinessHudTests.new()},
		{"name": "Task 20 playtest quality", "instance": PlaytestQualityTests.new()},
		{"name": "Task 21 floating combat text", "instance": FloatingCombatTextTests.new()},
		{"name": "Task 22 character and equipment foundation", "instance": CharacterEquipmentFoundationTests.new()},
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
