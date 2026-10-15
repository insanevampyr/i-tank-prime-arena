class_name ArenaCombatEventPresenter
extends RefCounted


static func format_event(event: CombatEvent) -> String:
	if event == null:
		return ""
	var seconds := float(event.timestamp_us) / 1_000_000.0
	var prefix := "[%05.2f] " % seconds
	var payload := event.payload
	match String(event.event_type):
		"opening_initiative_rolled":
			return prefix + "%s Initiative: d10 %s + INIT %s = %s" % [
				_display_actor(event.source_actor_id), payload.get("natural_d10", "?"),
				payload.get("base_init", "?"), payload.get("total", "?"),
			]
		"action_started":
			return prefix + "%s action due at %.2f s (%s Act at AT %s)." % [
				_display_actor(event.source_actor_id),
				float(payload.get("final_effect_due_at_us", 0)) / 1_000_000.0,
				payload.get("required_acts", "?"),
				payload.get("at_at_start", "?"),
			]
		"action_progressed":
			return prefix + "Action progress %s / %s Acts." % [payload.get("completed_acts", "?"), payload.get("required_acts", "?")]
		"action_completed":
			return prefix + "%s action completed." % _display_actor(event.source_actor_id)
		"physical_attack_declared":
			return prefix + "%s begins Battle Axe attack on torso." % _display_actor(event.source_actor_id)
		"physical_attack_accuracy_resolved":
			var outcome := "HIT" if payload.get("accuracy_success", false) else "MISS"
			return prefix + "%s ACC d20 %s vs %s: %s%s" % [
				_display_actor(event.source_actor_id), payload.get("natural_d20", "?"), payload.get("acc_target", "?"), outcome,
				_critical_suffix(payload),
			]
		"physical_defense_attempted":
			var attempt: Dictionary = payload.get("attempt", {})
			return prefix + "%s %s d20 %s vs %s: %s%s" % [
				_display_actor(event.source_actor_id), _pretty_name(String(attempt.get("defense_type", "defense"))),
				attempt.get("natural_roll", "?"), attempt.get("final_target", "?"),
				"SUCCESS" if attempt.get("success", false) else "failed", _critical_suffix(attempt),
			]
		"physical_defense_ineligible":
			var skipped: Dictionary = payload.get("attempt", {})
			return prefix + "%s unavailable: %s" % [
				_pretty_name(String(skipped.get("defense_type", "defense"))),
				_pretty_name(String(skipped.get("eligibility_reason", "ineligible"))),
			]
		"physical_defense_resolved":
			var defense := String(payload.get("successful_defense_type", ""))
			return prefix + (
				"%s defense held: %s." % [_display_actor(event.source_actor_id), _pretty_name(defense)]
				if not defense.is_empty()
				else "%s defenses exhausted; damage follows." % _display_actor(event.source_actor_id)
			)
		"physical_damage_resolved":
			return prefix + "%s deals %s HPC to %s (%s -> %s), TAL %s, NAL %s." % [
				_display_actor(event.source_actor_id), payload.get("final_damage", "?"), _display_actor(event.target_actor_id),
				payload.get("hpc_before", "?"), payload.get("hpc_after", "?"),
				payload.get("armor_tal", "?"), payload.get("natural_armor_level", "?"),
			]
		"critical_trigger_recorded":
			var record: Dictionary = payload.get("critical_record", {})
			return prefix + "CRITICAL %s - %s: %s [%s]" % [
				String(record.get("result_kind", "")).to_upper(),
				String(record.get("rarity", "")).capitalize(),
				_pretty_name(String(record.get("outcome_id", "pending outcome"))),
				_pretty_name(String(record.get("consequence_status", "selected"))),
			]
		"critical_stagger_applied":
			return prefix + "%s receives Critical Stagger for 0.5 seconds." % _display_actor(event.source_actor_id)
		"critical_prone_applied":
			return prefix + "%s is PRONE; standing costs one Act." % _display_actor(event.source_actor_id)
		"critical_reaction_started":
			return prefix + "%s Critical Reaction attack started." % _display_actor(event.source_actor_id)
		"actor_stood_from_prone":
			return prefix + "%s completed the legal one-Act stand." % _display_actor(event.source_actor_id)
		"critical_effect_unavailable", "critical_effect_blocked":
			return prefix + "Critical effect %s: %s." % [
				"PENDING/UNAVAILABLE" if String(event.event_type) == "critical_effect_unavailable" else "BLOCKED",
				_pretty_name(String(payload.get("reason", "verified prerequisite unavailable"))),
			]
		"physical_attack_interrupted", "action_interrupted":
			return prefix + "Action INTERRUPTED: %s." % _pretty_name(String(payload.get("reason", "interrupted")))
	return ""


static func _critical_suffix(payload: Dictionary) -> String:
	if payload.get("critical_success", false):
		return " (critical success)"
	if payload.get("critical_failure", false):
		return " (critical failure)"
	return ""


static func _pretty_name(value: String) -> String:
	return value.replace("_", " ").capitalize()


static func _display_actor(actor_id: StringName) -> String:
	if actor_id == PrimeV3VerticalSliceFixture.PLAYER_ID:
		return "Player"
	if actor_id == PrimeV3VerticalSliceFixture.OPPONENT_ID:
		return "Opponent"
	return String(actor_id).capitalize()
