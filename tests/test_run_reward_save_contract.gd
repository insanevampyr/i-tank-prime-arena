extends RefCounted

const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Profiles = preload("res://scripts/rewards/character_profile_projection.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
const Admission = preload("res://scripts/rewards/playable_character_admission.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const LEGACY := "run_legacy"
const FIRST := "run_first"
const SECOND := "run_second"
const GOBLIN := "wave_1_common_goblin_01"
var _failures: Array[String] = []
var _assertions := 0


func run() -> Array[String]:
	var originals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/browser/character_storage_fixture.json"))
	for mode: String in ["normal", "dev_normal"]:
		for document: String in originals[mode]:
			var decoded := Contract.decode(document)
			_expect(decoded.success and decoded.version == 2 and Contract.encode(decoded.payload).text == document, "Frozen %s V2 document must re-encode byte-for-byte." % mode)
		_test_mixed_history(mode)
	print("39S run reward save contract: %d assertions." % _assertions)
	return _failures


func _test_mixed_history(mode: String) -> void:
	var starter := Admission.prepare_starter(Fixture.PLAYER_CHARACTER_VAELIS, mode)
	_expect(starter.success, "Use verified authored Vaelis data.")
	if not starter.success: return
	var base: Dictionary = starter.prepared.payload
	var sim := CombatSimulation.new(361)
	sim.register_actor(starter.actor)
	var state := sim.get_actor_state(&"player")
	state.inventory_quantities = starter.state.inventory_quantities.duplicate(true)
	state.hand_occupancy = starter.state.hand_occupancy.duplicate(true)
	state.hand_occupancy_authoritative = true
	var ledger: ArenaRewardLedger = starter.ledger
	var checkpoints := [_entry(mode, 1), _entry(mode, 2)]
	if checkpoints[0].is_empty() or checkpoints[1].is_empty(): return
	var f := {"starter": starter, "base": base, "sim": sim, "ledger": ledger, "state": state, "awards": {}, "receipts": base.settlements.duplicate(true)}
	var legacy_multiplier := 1 if mode == "normal" else 10
	var first_multiplier := 10 if mode == "normal" else 1
	var runs: Array = [LEGACY]
	_award(f, LEGACY, 10 * legacy_multiplier)
	var legacy := _document(f, 3, runs, [], checkpoints[1], legacy_multiplier)
	if legacy.is_empty(): return
	var legacy_bytes: String = Contract.encode(legacy).text
	var legacy_candidate := _hydrate(f, Contract.decode(legacy_bytes).payload)
	_expect(legacy_candidate.success and legacy.recovery.phase == "entry" and legacy.recovery.wave_id == "wave_2", "An unfinished legacy run must hydrate at its original policy.")
	_expect(Contract.encode(Contract.decode(legacy_bytes).payload).text == legacy_bytes, "Legacy recovery checkpoint must roundtrip unchanged.")

	runs.append(FIRST)
	var entries: Array = [{"run_id": FIRST, "xp_multiplier": first_multiplier}]
	var first_entry := _document(f, 4, runs, entries, checkpoints[0], first_multiplier)
	if first_entry.is_empty(): return
	_expect(Contract.validate_replacement(legacy, first_entry).success, "First V4 generation extends the V2 run prefix at Wave 1 entry.")
	_expect(first_entry.permanent.award_receipts == legacy.permanent.award_receipts and first_entry.settlements == legacy.settlements, "Admission preserves every original award and receipt.")
	_award(f, FIRST, 10 * first_multiplier)
	var first_awarded := _document(f, 5, runs, entries, checkpoints[1], first_multiplier)
	if first_awarded.is_empty(): return
	_expect(Contract.validate_replacement(first_entry, first_awarded).success, "Same-run checkpoint keeps the admitted policy.")
	runs.append(SECOND)
	entries.append({"run_id": SECOND, "xp_multiplier": legacy_multiplier})
	var second_entry := _document(f, 6, runs, entries, checkpoints[0], legacy_multiplier)
	if second_entry.is_empty(): return
	_expect(Contract.validate_replacement(first_awarded, second_entry).success, "Second V4 run appends a different policy without reclassifying existing runs.")
	_award(f, SECOND, 10 * legacy_multiplier)
	var mixed := _document(f, 7, runs, entries, checkpoints[1], legacy_multiplier)
	if mixed.is_empty(): return
	_expect(Contract.validate_replacement(second_entry, mixed).success, "Mixed history accepts the next checkpoint in its own run.")
	_expect(Profiles.run_xp_multipliers(mixed) == {LEGACY: legacy_multiplier, FIRST: first_multiplier, SECOND: legacy_multiplier}, "Both namespaces must resolve each award under its actual run.")
	_expect(mixed.xp.earned == 10 * (legacy_multiplier * 2 + first_multiplier), "Prior awards keep their original values.")
	_test_rejections(f, legacy, first_entry, first_awarded, second_entry, mixed)


func _entry(mode: String, wave: int) -> Dictionary:
	var fixture_id := Fixture.ENCOUNTER_WAVE_ONE_GOBLINS if wave == 1 else Fixture.ENCOUNTER_WAVE_TWO_SPADOODLES
	var session := ArenaCombatSession.new(361, null, fixture_id, Fixture.PLAYER_CHARACTER_VAELIS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	session.set_opponent_behavior_enabled(false)
	var start := Vector2i(20_000_000, 7_000_000)
	var enemy := Vector2i(24_000_000, 7_000_000)
	var setup := session.initialize_wave_one_goblins(start, enemy, false) if wave == 1 else session.initialize_wave_two_spadoodles(start, enemy, false)
	_expect(setup.success and session.configure_reward_mode(mode).success, "Isolated Wave %d checkpoint source initializes." % wave)
	if not setup.success: return {}
	var actor := session.simulation.get_actor_definition(&"player")
	var motion := PrimeMovementModel.new(int(actor.get_combat_stat("mr")), actor.attributes.spd, actor.attributes.end, int(actor.get_combat_stat("running_skill_investment")), int(actor.get_combat_stat("running_scm")), int(actor.get_combat_stat("rb")), DeterministicCombatRng.new(361))
	session.player_movement_boundary_provider = motion.wave_entry_state
	var service := PlayableCharacterPersistence.new()
	service.run_id = LEGACY
	var captured := service._capture(session, "entry")
	_expect(captured.success, "Use a real isolated Wave %d checkpoint template: %s." % [wave, captured.get("reason", "")])
	return captured.get("checkpoint", {})


func _award(f: Dictionary, run_id: String, amount: int) -> void:
	var profile: String = f.base.character_id
	var id := "%s/starter_admission/%s/wave_1/defeat/%s" % [profile, run_id, GOBLIN]
	f.ledger.earned_xp += amount
	var result: Dictionary = f.sim.apply_character_experience_award(&"player", id, amount, f.ledger.earned_xp, 0)
	_expect(result.success, "Isolated fixture records the earned XP and actual growth rolls.")
	if result.success: f.ledger.player_level = result.level
	f.awards[id] = {"award_id": id, "xp": amount}
	f.receipts.append({"version": 1, "receipt_id": "%s/%s/wave_1/xp_fixture" % [profile, run_id], "profile_id": profile, "run_id": run_id, "wave_id": "wave_1", "claim_id": "xp_fixture", "kind": "xp", "content": {"award_id": id, "amount": amount}})


func _document(f: Dictionary, generation: int, runs: Array, entries: Array, checkpoint: Dictionary, active_multiplier: int) -> Dictionary:
	var evidence: Dictionary = f.base.lineage.merged({
		"generation": generation, "profile_namespace": f.base.profile_namespace, "run_history": runs,
		"items": f.base.items, "award_receipts": f.awards, "growth_ids": {}, "purchase_ids": {}, "secured_checkpoints": [],
	})
	for row: Dictionary in f.state.progression.history:
		evidence.growth_ids["%s:%d" % [row.award_id, row.level]] = row.award_id + "/level_" + str(row.level)
	var ledger: Dictionary = f.ledger.to_dictionary()
	if not entries.is_empty():
		evidence.run_reward_policy = {"legacy_run_count": 1, "runs": entries}
		ledger.xp_multiplier = active_multiplier
	var verifier := func(operation: String, binding: String) -> Dictionary:
		return evidence.merged({"authorized": true, "binding": binding}) if operation == "project" else {"authorized": true, "binding": binding, "lineage": f.base.lineage}
	var before: Dictionary = f.sim.get_state_snapshot()
	var projected := Profiles.project(f.starter.source, f.starter.actor, f.state, ledger, f.starter.defense, verifier)
	_expect(projected.success and f.sim.get_state_snapshot() == before, "Projection must validate policy and preserve combat state: %s." % projected.get("reason", ""))
	if not projected.success: return {}
	var payload: Dictionary = projected.payload
	payload.recovery = checkpoint.duplicate(true)
	payload.recovery.run_id = runs.back()
	payload.recovery.ledger = ledger
	payload.settlements = f.receipts.duplicate(true)
	var encoded := Contract.encode(payload)
	_expect(encoded.success, "Completed checkpoint must encode.")
	if not encoded.success: return {}
	var decoded := Contract.decode(encoded.text)
	_expect(decoded.success and decoded.version == (2 if entries.is_empty() else 4), "Envelope version follows presence of the immutable policy: %s." % decoded.get("reason", ""))
	if not decoded.success: return {}
	_expect(_hydrate(f, decoded.payload).success, "Full checkpoint must hydrate with its own policy and recorded growth.")
	_expect(_prepare(decoded.payload).success, "Complete XP receipts must pass coordinator preparation.")
	return decoded.payload


func _test_rejections(f: Dictionary, legacy: Dictionary, first_entry: Dictionary, first_awarded: Dictionary, second_entry: Dictionary, mixed: Dictionary) -> void:
	var bad := mixed.duplicate(true)
	bad.run_reward_policy.runs.pop_back()
	_expect(not Contract.validate(bad).success, "Every nonlegacy run requires a policy.")
	bad = mixed.duplicate(true)
	bad.run_reward_policy.runs[1] = bad.run_reward_policy.runs[0].duplicate(true)
	_expect(not Contract.validate(bad).success, "Duplicate and reassigned run IDs reject.")
	for multiplier: Variant in [0, 2, 10.0, "10", true]:
		bad = mixed.duplicate(true)
		bad.run_reward_policy.runs[0].xp_multiplier = multiplier
		_expect(not Contract.validate(bad).success, "Malformed policy multiplier rejects.")
	bad = first_entry.duplicate(true)
	bad.run_reward_policy.legacy_run_count = 0
	bad.run_reward_policy.runs.push_front({"run_id": LEGACY, "xp_multiplier": 1})
	_expect(not Contract.validate_replacement(legacy, bad).success, "A V2 run cannot be retroactively assigned a policy.")
	bad = second_entry.duplicate(true)
	bad.run_reward_policy.runs[0].xp_multiplier = 11 - bad.run_reward_policy.runs[0].xp_multiplier
	_expect(not Contract.validate_replacement(first_awarded, bad).success, "An admitted multiplier is immutable.")
	bad = first_awarded.duplicate(true)
	bad.generation = first_entry.generation
	_expect(not Contract.validate_replacement(legacy, bad).success, "A later wave cannot introduce a policy.")
	bad = legacy.duplicate(true)
	bad.recovery.phase = "downtime"
	_expect(not Contract.validate_replacement(bad, first_entry).success, "Downtime alone cannot authorize a new run.")
	bad = mixed.duplicate(true)
	bad.run_reward_policy.runs[1].xp_multiplier = 11 - bad.run_reward_policy.runs[1].xp_multiplier
	bad.recovery.ledger.xp_multiplier = bad.run_reward_policy.runs[1].xp_multiplier
	_expect(_hydrate(f, bad).get("reason") == "recovery_award_value_unverified" and not _prepare(bad).success, "Changed policy cannot reinterpret already earned XP.")
	bad = mixed.duplicate(true)
	bad.recovery.ledger.xp_multiplier = 11 - bad.recovery.ledger.xp_multiplier
	_expect(_hydrate(f, bad).get("reason") == "run_reward_policy_ledger_mismatch", "Recovery cannot use a multiplier different from the durable policy.")
	bad = mixed.duplicate(true)
	bad.permanent.award_receipts[-1].xp += 1
	bad.settlements[-1].content.amount += 1
	_expect(_prepare(bad).get("reason") == "recovery_award_value_unverified", "Matching altered award and settlement amounts still fail the catalog and policy.")
	bad = mixed.duplicate(true)
	bad.settlements[-1].content.amount += 1
	_expect(_prepare(bad).get("reason") == "xp_settlement_missing_or_mismatched", "An inconsistent settlement amount rejects.")
	bad = mixed.duplicate(true)
	bad.settlements[-1].wave_id = "wave_2"
	bad.settlements[-1].receipt_id = bad.settlements[-1].receipt_id.replace("/wave_1/", "/wave_2/")
	_expect(not _prepare(bad).success, "Receipt wave must match the durable award.")
	bad = mixed.duplicate(true)
	bad.erase("run_reward_policy")
	bad.generation += 1
	_expect(Contract.validate_replacement(mixed, bad).get("reason") == "run_reward_profile_downgrade", "V4 cannot downgrade to V2.")
	bad = mixed.duplicate(true)
	bad.erase("recovery")
	_expect(_prepare(bad).get("reason") == "verified_run_boundary_required", "Projection without recovery cannot be prepared for publication.")
	for version: Variant in [1, 2, 3, 5, "4", 4.5, true, null]:
		var envelope: Dictionary = JSON.parse_string(Contract.encode(mixed).text)
		envelope.version = version
		_expect(Contract.decode(JSON.stringify(envelope)).get("reason") == "unsupported_format_or_version", "A V4 payload cannot decode under an unsupported or mismatched version.")
	var wrong_envelope: Dictionary = JSON.parse_string(Contract.encode(legacy).text)
	wrong_envelope.version = 4
	_expect(not Contract.decode(JSON.stringify(wrong_envelope)).success, "V4 requires explicit policy evidence.")
	var prepared := _prepare(mixed)
	if prepared.success:
		var coordinator := Coordinator.new(null)
		_expect(coordinator.commit(prepared.prepared, f.starter.source, mixed.character_id, mixed.rules_revision).reason == "trusted_authority_unavailable", "V4 commit still requires trusted authority before accessing storage.")
		_expect(coordinator.reconcile(prepared.prepared, f.starter.source, mixed.character_id, mixed.rules_revision).reason == "trusted_authority_unavailable", "V4 reconciliation also requires trusted authority.")


func _prepare(payload: Dictionary) -> Dictionary:
	return Coordinator.prepare(payload, payload.settlements, "isolated_policy", payload.generation - 1, [])


func _hydrate(f: Dictionary, payload: Dictionary) -> Dictionary:
	var verifier := func(_operation: String, binding: String) -> Dictionary:
		return {"authorized": true, "binding": binding, "lineage": f.base.lineage}
	return Profiles.hydrate(payload, f.starter.source, payload.character_id, payload.rules_revision, verifier)


func _expect(value: bool, message: String) -> void:
	_assertions += 1
	if not value: _failures.append(message)
