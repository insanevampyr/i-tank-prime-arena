class_name CombatFloatingTextMapper
extends RefCounted

## Translates already-resolved authoritative events into brief presentation intents.
## This class neither schedules events nor reads or mutates simulation state.


static func messages_for_event(event: CombatEvent) -> Array[Dictionary]:
	if event == null:
		return []
	var payload := event.payload
	match String(event.event_type):
		"physical_attack_accuracy_resolved":
			if payload.get("critical_success", false) or payload.get("critical_failure", false):
				# The following critical record supplies the approved, selected outcome.
				return []
			return [_message(event.source_actor_id, "HIT!" if payload.get("accuracy_success", false) else "MISS!", "neutral", 2)]
		"physical_defense_attempted":
			var attempt: Dictionary = payload.get("attempt", {})
			if attempt.get("success", false) or attempt.get("critical_success", false) or attempt.get("critical_failure", false):
				return []
			return [_message(event.source_actor_id, "%s FAILED" % _defense_name(String(attempt.get("defense_type", "DEFENSE"))), "failure", 1)]
		"physical_defense_resolved":
			var defense_type := String(payload.get("successful_defense_type", ""))
			if defense_type.is_empty():
				return []
			return [_message(event.source_actor_id, "%s!" % _defense_name(defense_type), "defense", 4)]
		"physical_damage_resolved":
			var final_damage := int(payload.get("final_damage", 0))
			if final_damage <= 0:
				return []
			var result := [_message(event.target_actor_id, "-%d HPC" % final_damage, "damage", 5)]
			if int(payload.get("hpc_after", 1)) <= 0:
				result.append(_message(event.target_actor_id, "DEFEATED!", "defeat", 7))
			return result
		"critical_trigger_recorded":
			var record: Dictionary = payload.get("critical_record", {})
			var result_kind := String(record.get("result_kind", ""))
			var outcome := _pretty_name(String(record.get("outcome_id", "")))
			var headline := "CRIT HIT!" if result_kind == "success" else "CRIT FAIL!"
			return [_message(event.source_actor_id, headline if outcome.is_empty() else "%s %s" % [headline, outcome], "critical_success" if result_kind == "success" else "critical_failure", 6)]
		"critical_perfect_evasion_applied":
			return [_message(event.source_actor_id, "PERFECT EVASION!", "critical_success", 6)]
		"critical_stagger_applied":
			return [_message(_affected_actor(event), "STAGGER!", "failure", 6)]
		"critical_prone_applied":
			return [_message(_affected_actor(event), "PRONE!", "failure", 6)]
		"critical_reaction_started":
			return [_message(event.source_actor_id, "CRITICAL REACTION!", "critical_success", 5)]
		"physical_attack_interrupted":
			return [_message(event.source_actor_id, "INTERRUPTED!", "failure", 5)]
		"action_interrupted":
			return [_message(event.target_actor_id if not event.target_actor_id.is_empty() else event.source_actor_id, "INTERRUPTED!", "failure", 5)]
		"actor_stood_from_prone":
			return [_message(event.source_actor_id, "STANDING", "neutral", 2)]
	return []


static func _message(actor_id: StringName, text: String, category: String, priority: int) -> Dictionary:
	return {"actor_id": actor_id, "text": text, "category": category, "priority": priority}


static func _affected_actor(event: CombatEvent) -> StringName:
	var actor_id := String(event.payload.get("affected_actor_id", ""))
	if not actor_id.is_empty():
		return StringName(actor_id)
	return event.source_actor_id


static func _defense_name(defense_type: String) -> String:
	match defense_type:
		"dodge":
			return "DODGE"
		"weapon_block":
			return "WEAPON BLOCK"
		"shield_block":
			return "SHIELD BLOCK"
		"physical_soak":
			return "SOAK"
	return _pretty_name(defense_type).to_upper()


static func _pretty_name(value: String) -> String:
	return value.replace("_", " ").capitalize()
