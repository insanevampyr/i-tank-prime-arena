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
const ArmorPenaltyTests = preload("res://tests/test_armor_penalties.gd")
const NineLocationTargetingTests = preload("res://tests/test_nine_location_targeting.gd")
const SizeBasedTargetingTests = preload("res://tests/test_size_based_targeting.gd")
const PlayableDifferentSizeCombatTests = preload("res://tests/test_playable_different_size_combat.gd")
const PresentationEventConsumptionTests = preload("res://tests/test_presentation_event_consumption.gd")
const FiveWaveEncounterFrameworkTests = preload("res://tests/test_five_wave_encounter_framework.gd")
const CommonGoblinWaveTests = preload("res://tests/test_common_goblin_wave.gd")
const WavePerformanceHpcTests = preload("res://tests/test_wave_performance_hpc.gd")
const IndependentInitiativePursuitLabelTests = preload("res://tests/test_independent_initiative_pursuit_labels.gd")
const GoblinWallNavigationTests = preload("res://tests/test_goblin_wall_navigation.gd")
const GoblinWallNavigationSeedControlsTests = preload("res://tests/test_goblin_wall_navigation_seed_controls.gd")
const SeedFocusTargetHudTests = preload("res://tests/test_seed_focus_target_hud.gd")
const MovementCongestionPresentationTests = preload("res://tests/test_movement_congestion_presentation.gd")


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var suites := [
		{"name": "Task 31J movement congestion and presentation", "instance": MovementCongestionPresentationTests.new()},
		{"name": "Task 31I seed focus, target cycling and HUD layout", "instance": SeedFocusTargetHudTests.new()},
		{"name": "Task 31H wall navigation and seed controls", "instance": GoblinWallNavigationSeedControlsTests.new()},
		{"name": "Task 31G Goblin wall navigation", "instance": GoblinWallNavigationTests.new()},
		{"name": "Task 31E independent Initiative, pursuit and labels", "instance": IndependentInitiativePursuitLabelTests.new()},
		{"name": "Task 31D Wave performance and HPC presentation", "instance": WavePerformanceHpcTests.new()},
		{"name": "Task 31C Common Goblin Wave 1", "instance": CommonGoblinWaveTests.new()},
		{"name": "Task 31B deterministic five-wave framework", "instance": FiveWaveEncounterFrameworkTests.new()},
		{"name": "Task 30 presentation event consumption", "instance": PresentationEventConsumptionTests.new()},
		{"name": "Task 29 playable different-size combat", "instance": PlayableDifferentSizeCombatTests.new()},
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
		{"name": "Task 25 armor penalties", "instance": ArmorPenaltyTests.new()},
		{"name": "Task 27 nine-location targeting", "instance": NineLocationTargetingTests.new()},
		{"name": "Task 28 size-based targeting", "instance": SizeBasedTargetingTests.new()},
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
