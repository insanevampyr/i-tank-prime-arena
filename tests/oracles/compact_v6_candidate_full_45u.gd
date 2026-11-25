extends RefCounted
# Frozen pre-45U check() oracle. Receiver qualification is the only adaptation.
const V6 = preload("res://scripts/rewards/compact_character_v6_prototype.gd")
const FixedCredit = preload("res://scripts/rewards/compact_v6_fixed_credit.gd")
const Coordinator = preload("res://scripts/rewards/character_persistence_coordinator.gd")
static func check(owner: RefCounted, prepared: RefCounted, expected_head: Dictionary) -> Dictionary:
	var session: ArenaCombatSession = owner._session.get_ref() if owner._session != null else null
	var valid: Dictionary = owner._context(session)
	if not valid.success: return valid
	if prepared == null or prepared != owner._pending or prepared.bytes().sha256_text() != prepared.digest(): return owner._fail("foreign_or_changed_prepared_operation")
	var body: Dictionary = prepared.copy()
	if body.candidate_text.sha256_text() != body.candidate_digest: return owner._fail("candidate_bytes_changed")
	if body.binding.get("kind") == FixedCredit.FORMAT: return owner._check_credit(prepared,expected_head)
	if body.binding.event_start != owner._start or body.binding.event_end != owner._cursor or body.binding.events_json != JSON.stringify(owner._facts,"",true,true): return owner._fail("captured_operation_changed")
	var service: PlayableCharacterPersistence = owner._service.get_ref()
	if expected_head != owner.head() or body.binding.expected_head != expected_head: return owner._fail("stale_compact_head")
	if body.binding.run_policy != service.get_run_reward_policy(): return owner._fail("run_policy_changed")
	if V6.digest(service._prepared) != body.binding.legacy_prepared_digest: return owner._fail("checkpoint_request_changed")
	if V6.digest(session.get_state_snapshot()) != body.binding.runtime_digest: return owner._fail("runtime_changed_after_preparation")
	var events: Dictionary = owner._unchanged_events(session)
	if not events.success: return events
	var authorized := Coordinator._authorize(service._prepared,service.source,service.profile_id,PlayableCharacterAdmission.RULES,service._verify)
	if not authorized.success: return owner._fail("checkpoint_authority_rejected",authorized)
	var decoded := V6.decode(body.candidate_text,service.source)
	if not decoded.success: return decoded
	if decoded.record.operations.back() != {"id":body.binding.operation_id,"request_digest":V6.digest(body.binding)}: return owner._fail("operation_binding_changed")
	if V6._projection(decoded.record) != CharacterSaveContract.decode(service._prepared.document).payload: return owner._fail("projection_equivalence_failed")
	return V6.validate_extension(owner._parent,decoded.record,service.source) if not owner._parent.is_empty() else {"success":true}

