extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_event_ordering()
	_test_deterministic_replay()
	_test_round_boundaries()
	_test_timestamp_ties()
	_test_event_schema_reserves_future_fields()
	return _failures


func _test_event_ordering() -> void:
	var simulation := CombatSimulation.new(1001)
	simulation.schedule_event(2_000_000, &"later", 99)
	simulation.schedule_event(1_000_000, &"lower_init", 4)
	simulation.schedule_event(1_000_000, &"higher_init", 12)
	var ordered := simulation.event_queue.drain()
	_expect_equal(String(ordered[0].event_type), "higher_init", "Earlier timestamps must sort before later timestamps, with higher INIT first.")
	_expect_equal(String(ordered[1].event_type), "lower_init", "Lower INIT must follow higher INIT at the same timestamp.")
	_expect_equal(String(ordered[2].event_type), "later", "Later timestamps must remain later regardless of INIT.")


func _test_deterministic_replay() -> void:
	var first := CombatSimulation.new(8675309)
	var second := CombatSimulation.new(8675309)
	for index in range(8):
		var first_roll := first.roll_int(1, 20)
		var second_roll := second.roll_int(1, 20)
		first.schedule_event(index * 250_000, &"rng_sample", 5, &"tester", &"", {"roll": first_roll})
		second.schedule_event(index * 250_000, &"rng_sample", 5, &"tester", &"", {"roll": second_roll})
	_expect_equal(first.event_queue.snapshot(), second.event_queue.snapshot(), "Equal seeds and inputs must produce identical event streams.")


func _test_round_boundaries() -> void:
	var clock := CombatClock.new()
	_expect_equal(clock.get_round_index_at(0), 0, "Timestamp zero must be in round zero.")
	_expect_equal(clock.get_round_index_at(4_999_999), 0, "The final microsecond before five seconds must remain in round zero.")
	_expect_equal(clock.get_round_index_at(5_000_000), 1, "Exactly five seconds must begin round one.")
	_expect_equal(clock.get_round_index_at(10_000_000), 2, "Exactly ten seconds must begin round two.")
	clock.advance(5_000_000)
	_expect_equal(clock.get_round_index(), 1, "Advancing the clock by five seconds must cross one boundary.")
	_expect_equal(clock.get_round_offset_us_at(5_000_001), 1, "Round offsets must remain exact in integer microseconds.")


func _test_timestamp_ties() -> void:
	var simulation := CombatSimulation.new(7)
	var first_created := simulation.schedule_event(3_000_000, &"first_created", 8)
	var second_created := simulation.schedule_event(3_000_000, &"second_created", 8)
	var highest_init := simulation.schedule_event(3_000_000, &"highest_init", 9)
	var ordered := simulation.event_queue.drain()
	_expect_equal(ordered[0].event_id, highest_init.event_id, "Higher INIT must be the first simultaneous-event tie-breaker.")
	_expect_equal(ordered[1].event_id, first_created.event_id, "Stable creation order must break a remaining timestamp and INIT tie.")
	_expect_equal(ordered[2].event_id, second_created.event_id, "The stable fallback must not reorder equal-priority events.")
	_expect_true(first_created.event_id != second_created.event_id, "Every scheduled event must receive a unique identifier.")


func _test_event_schema_reserves_future_fields() -> void:
	var simulation := CombatSimulation.new(11)
	var event := simulation.schedule_event(
		1_250_000,
		&"future_interrupt_candidate",
		6,
		&"actor_a",
		&"actor_b",
		{"phase": "declared"},
		"event_ancestor",
		PackedStringArray(["event_dependency"]),
		{"mana": 3}
	)
	_expect_equal(event.parent_event_id, "event_ancestor", "Events must retain an optional causal parent.")
	_expect_equal(event.dependency_event_ids, PackedStringArray(["event_dependency"]), "Events must retain dependency identifiers without resolving them.")
	_expect_equal(event.resource_commitments, {"mana": 3}, "Events must retain resource commitments without spending them.")


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
