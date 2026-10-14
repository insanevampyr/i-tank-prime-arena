extends RefCounted

var _failures: Array[String] = []


func run() -> Array[String]:
	_test_simultaneous_timestamps_and_init_order()
	_test_init_tie_uses_stable_fallback()
	_test_duplicate_delivery_is_idempotent()
	_test_out_of_order_delivery_converges()
	_test_digest_is_canonical_and_matches_authority()
	_test_disagreement_produces_clear_report()
	return _failures


func _test_simultaneous_timestamps_and_init_order() -> void:
	var harness := TwoClientSyncHarness.new(101)
	harness.authority.schedule_event(2_000_000, &"low_init", 4)
	harness.authority.schedule_event(2_000_000, &"high_init", 12)
	var envelopes := harness.authority.publish_resolved_events()
	harness.deliver_in_order(envelopes)
	var transcript := harness.client_a.get_transcript()
	_expect_equal(transcript[0]["combat_event"]["event_type"], "high_init", "Higher INIT must lead simultaneous authoritative events.")
	_expect_equal(transcript[1]["combat_event"]["event_type"], "low_init", "Lower INIT must follow at the same timestamp.")
	_expect_true(harness.compare_clients()["success"], "Both clients must agree after simultaneous timestamp delivery.")


func _test_init_tie_uses_stable_fallback() -> void:
	var harness := TwoClientSyncHarness.new(202)
	harness.authority.schedule_event(3_000_000, &"created_first", 8)
	harness.authority.schedule_event(3_000_000, &"created_second", 8)
	var envelopes := harness.authority.publish_resolved_events()
	harness.deliver_in_order(envelopes)
	var transcript := harness.client_b.get_transcript()
	_expect_equal(transcript[0]["combat_event"]["event_type"], "created_first", "Stable creation order must break a timestamp and INIT tie.")
	_expect_equal(transcript[1]["combat_event"]["event_type"], "created_second", "Equal-priority events must retain the deterministic fallback order.")


func _test_duplicate_delivery_is_idempotent() -> void:
	var harness := TwoClientSyncHarness.new(303)
	harness.authority.schedule_event(1_000_000, &"single_event", 5)
	var envelopes := harness.authority.publish_resolved_events()
	harness.client_a.receive(envelopes[0])
	harness.client_a.receive(envelopes[0])
	harness.client_b.receive(envelopes[0])
	_expect_equal(harness.client_a.get_applied_event_count(), 1, "Identical duplicate delivery must not apply an event twice.")
	_expect_true(not harness.client_a.has_failure(), "An identical duplicate must not create a synchronization failure.")
	_expect_true(harness.compare_clients()["success"], "Duplicate delivery to one client must preserve convergence.")


func _test_out_of_order_delivery_converges() -> void:
	var harness := TwoClientSyncHarness.new(404)
	for index in range(4):
		harness.authority.schedule_event(index * 500_000, StringName("event_%d" % index), 5)
	var envelopes := harness.authority.publish_resolved_events()
	for envelope: CombatEventEnvelope in envelopes:
		harness.client_a.receive(envelope)
	for index in range(envelopes.size() - 1, -1, -1):
		harness.client_b.receive(envelopes[index])
	_expect_equal(harness.client_b.get_applied_event_count(), 4, "Out-of-order events must remain buffered until their sequence gap closes.")
	_expect_true(harness.compare_clients()["success"], "Out-of-order delivery must converge to the authoritative sequence.")


func _test_digest_is_canonical_and_matches_authority() -> void:
	var left := {"beta": 2, "alpha": {"second": false, "first": true}}
	var right := {"alpha": {"first": true, "second": false}, "beta": 2}
	_expect_equal(SyncStateDigest.compute(left), SyncStateDigest.compute(right), "Digest input must not depend on dictionary insertion order.")

	var harness := TwoClientSyncHarness.new(454)
	harness.authority.schedule_event(750_000, &"authoritative_observation", 7, &"source", &"target", left)
	var envelopes := harness.authority.publish_resolved_events()
	harness.deliver_in_order(envelopes)
	_expect_equal(harness.client_a.get_state_digest(), harness.authority.get_state_digest(), "A complete observer transcript must match the authoritative digest.")
	_expect_equal(harness.client_b.get_state_digest(), harness.authority.get_state_digest(), "Both complete observers must match the authoritative digest.")


func _test_disagreement_produces_clear_report() -> void:
	var harness := TwoClientSyncHarness.new(505)
	harness.authority.schedule_event(0, &"first", 5)
	harness.authority.schedule_event(1, &"second", 5)
	var envelopes := harness.authority.publish_resolved_events()
	harness.client_a.receive(envelopes[0])
	harness.client_a.receive(envelopes[1])
	harness.client_b.receive(envelopes[0])
	var report := harness.compare_clients()
	_expect_true(not report["success"], "A missing authoritative event must fail client comparison.")
	_expect_true(report["message"].contains("Synchronization failure"), "A disagreement report must identify synchronization failure explicitly.")
	_expect_true(report["message"].contains("client_b"), "A disagreement report must identify the mismatching client.")
	_expect_true(report["message"].contains("digest"), "A disagreement report must include digest evidence.")


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
