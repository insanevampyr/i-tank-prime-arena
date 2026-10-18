class_name CombatReadinessModel
extends RefCounted

const CombatAction = preload("res://scripts/combat/combat_action_instance.gd")

const STATE_READY := "ready"
const STATE_ATTACKING := "attacking"
const STATE_STAGGERED := "staggered"
const STATE_BLOCKED := "blocked"
const STATE_NO_TARGET := "no_target"
const STATE_OUT_OF_RANGE := "out_of_range"
const STATE_RUNNING := "running"
const STATE_RECOVERING := "recovering"
const STATE_RETRY := "retry"

const RUNNING_RETRY_DURATION_US := 5_000_000


static func get_attack_readiness(session: ArenaCombatSession, presentation_available: bool = true) -> Dictionary:
	if session == null or session.simulation == null:
		return _state(STATE_BLOCKED, "BLOCKED", "NO AUTHORITY", 0.0, 0, 0, "session_unavailable")
	var now_us := session.simulation.clock.get_elapsed_us()
	var player_state := session.get_actor_state(PrimeV3VerticalSliceFixture.PLAYER_ID)
	if player_state == null:
		return _state(STATE_BLOCKED, "BLOCKED", "NO ACTOR", 0.0, 0, 0, "attacker_unavailable")
	if not presentation_available:
		return _state(STATE_BLOCKED, "BLOCKED", "FOCUS LOST", 0.0, 0, 0, "presentation_unavailable")

	var active_attack_id := session.get_active_player_attack_id()
	if not active_attack_id.is_empty() and session.is_player_attack_in_flight():
		var attack := session.simulation.get_attack(active_attack_id)
		var action := null if attack == null or attack.action_instance_id.is_empty() else session.simulation.get_action(attack.action_instance_id)
		if action != null and action.status == CombatAction.STATUS_IN_PROGRESS:
			var timing := get_action_progress(action, now_us)
			return _state(
				STATE_ATTACKING,
				"ATTACKING",
				_format_seconds(int(timing["remaining_us"])),
				float(timing["progress"]),
				int(timing["remaining_us"]),
				int(timing["total_us"]),
				"action_in_progress"
			)
		return _state(STATE_ATTACKING, "ATTACKING", "RESOLVING", 1.0, 0, 0, "attack_resolution_in_progress")

	var stagger_remaining_us := maxi(0, player_state.critical_stagger_until_us - now_us)
	if stagger_remaining_us > 0:
		return _state(
			STATE_STAGGERED,
			"STAGGERED",
			_format_seconds(stagger_remaining_us),
			1.0 - float(stagger_remaining_us) / 500_000.0,
			stagger_remaining_us,
			500_000,
			"actor_critically_staggered"
		)
	if not session.is_encounter_active():
		var encounter_reason := "encounter_complete" if session.get_encounter_state() != ArenaCombatSession.ENCOUNTER_READY else "encounter_not_running"
		return _state(STATE_BLOCKED, "BLOCKED", "RESET" if encounter_reason == "encounter_complete" else "START", 0.0, 0, 0, encounter_reason)
	if player_state.current_hpc == null or int(player_state.current_hpc) <= 0:
		return _state(STATE_BLOCKED, "BLOCKED", "DEFEATED", 0.0, 0, 0, "attacker_defeated")
	if _has_incapacitating_condition(player_state.conditions):
		return _state(STATE_BLOCKED, "BLOCKED", "INCAPACITATED", 0.0, 0, 0, "attacker_incapacitated")
	if player_state.conditions.has("prone"):
		return _state(STATE_BLOCKED, "BLOCKED", "STAND FIRST", 0.0, 0, 0, "actor_prone")
	if not player_state.current_action_instance_id.is_empty():
		return _state(STATE_BLOCKED, "BLOCKED", "ACTION ACTIVE", 0.0, 0, 0, "actor_action_in_progress")
	var legality := session.get_attack_legality()
	if legality.get("success", false):
		var approach_required := bool(legality.get("approach_required", false))
		return _state(STATE_READY, "READY", "APPROACH" if approach_required else "", 1.0, 0, 0, "legal_approach_attack" if approach_required else "legal")
	var reason := String(legality.get("reason", "attack_illegal"))
	match reason:
		"no_target_selected", "invalid_target", "target_defeated":
			return _state(STATE_NO_TARGET, "NO TARGET", "", 0.0, 0, 0, reason)
		"target_out_of_range":
			return _state(STATE_OUT_OF_RANGE, "OUT OF RANGE", "", 0.0, 0, 0, reason)
		"line_of_sight_blocked":
			return _state(STATE_OUT_OF_RANGE, "NO LINE OF SIGHT", "", 0.0, 0, 0, reason)
		"actor_critically_staggered":
			return _state(STATE_STAGGERED, "STAGGERED", "", 0.0, 0, 0, reason)
		_:
			return _state(STATE_BLOCKED, "BLOCKED", _short_reason(reason), 0.0, 0, 0, reason)


static func get_action_progress(action: CombatActionInstance, now_us: int) -> Dictionary:
	if action == null:
		return {"total_us": 0, "elapsed_us": 0, "remaining_us": 0, "progress": 0.0}
	var total_us := maxi(0, action.final_effect_due_at_us - action.started_at_us)
	var elapsed_us := clampi(now_us - action.started_at_us, 0, total_us)
	var remaining_us := maxi(0, action.final_effect_due_at_us - now_us)
	return {
		"total_us": total_us,
		"elapsed_us": elapsed_us,
		"remaining_us": remaining_us,
		"progress": 1.0 if total_us == 0 else clampf(float(elapsed_us) / float(total_us), 0.0, 1.0),
	}


static func get_running_readiness(movement: Dictionary, combat_blocker: Dictionary = {}, presentation_available: bool = true) -> Dictionary:
	if movement.is_empty():
		return _state(STATE_BLOCKED, "BLOCKED", "NO MOVEMENT", 0.0, 0, 0, "movement_unavailable")
	if not presentation_available:
		return _state(STATE_BLOCKED, "BLOCKED", "FOCUS LOST", 0.0, 0, 0, "presentation_unavailable")
	if not combat_blocker.is_empty():
		return _state(
			STATE_BLOCKED,
			"BLOCKED",
			String(combat_blocker.get("label", "UNAVAILABLE")),
			0.0,
			int(combat_blocker.get("remaining_us", 0)),
			int(combat_blocker.get("total_us", 0)),
			String(combat_blocker.get("reason", "combat_restricted"))
		)

	var running_elapsed_us := int(movement.get("running_elapsed_us", 0))
	var maximum_us := int(movement.get("maximum_running_duration_us", 0))
	var recovery_remaining_us := int(movement.get("recovery_remaining_us", 0))
	var retry_remaining_us := int(movement.get("running_retry_cooldown_us", 0))
	if movement.get("is_running", false):
		var remaining_us := maxi(0, maximum_us - running_elapsed_us)
		return _with_running_detail(_state(
			STATE_RUNNING,
			"RUNNING",
			_format_seconds(remaining_us),
			1.0 if maximum_us <= 0 else clampf(float(running_elapsed_us) / float(maximum_us), 0.0, 1.0),
			remaining_us,
			maximum_us,
			"running_active"
		), movement)
	if retry_remaining_us > 0:
		return _with_running_detail(_state(
			STATE_RETRY,
			"RETRY",
			_format_seconds(retry_remaining_us),
			clampf(1.0 - float(retry_remaining_us) / float(RUNNING_RETRY_DURATION_US), 0.0, 1.0),
			retry_remaining_us,
			RUNNING_RETRY_DURATION_US,
			"running_retry_cooldown"
		), movement)
	if recovery_remaining_us > 0:
		var recovery_total_us := maxi(recovery_remaining_us, int(movement.get("last_run_duration_us", recovery_remaining_us)))
		return _with_running_detail(_state(
			STATE_RECOVERING,
			"RECOVERING",
			_format_seconds(recovery_remaining_us),
			clampf(1.0 - float(recovery_remaining_us) / float(recovery_total_us), 0.0, 1.0),
			recovery_remaining_us,
			recovery_total_us,
			"running_recovery_required"
		), movement)
	return _with_running_detail(_state(STATE_READY, "READY", "MR %d" % int(movement.get("walking_mr", 0)), 1.0, 0, 0, "legal"), movement)


static func _state(
	state: String,
	status_text: String,
	value_text: String,
	progress: float,
	remaining_us: int,
	total_us: int,
	reason: String
) -> Dictionary:
	return {
		"state": state,
		"status_text": status_text,
		"value_text": value_text,
		"progress": clampf(progress, 0.0, 1.0),
		"remaining_us": maxi(0, remaining_us),
		"total_us": maxi(0, total_us),
		"reason": reason,
	}


static func _with_running_detail(snapshot: Dictionary, movement: Dictionary) -> Dictionary:
	snapshot["walking_mr"] = int(movement.get("walking_mr", 0))
	snapshot["running_bonus_mr"] = int(movement.get("running_bonus_mr", 0))
	snapshot["effective_mr"] = int(movement.get("effective_mr", 0))
	snapshot["maximum_running_duration_us"] = int(movement.get("maximum_running_duration_us", 0))
	snapshot["recovery_remaining_us"] = int(movement.get("recovery_remaining_us", 0))
	snapshot["retry_remaining_us"] = int(movement.get("running_retry_cooldown_us", 0))
	snapshot["automatic"] = bool(movement.get("running_automatic", false))
	snapshot["running_check_target"] = int(movement.get("running_check_target", 0))
	return snapshot


static func _has_incapacitating_condition(conditions: PackedStringArray) -> bool:
	return conditions.has("incapacitated") or conditions.has("unconscious")


static func _format_seconds(value_us: int) -> String:
	return "%.1fs" % (float(maxi(0, value_us)) / 1_000_000.0)


static func _short_reason(reason: String) -> String:
	return reason.replace("actor_", "").replace("attacker_", "").replace("encounter_", "").replace("_", " ").to_upper()
