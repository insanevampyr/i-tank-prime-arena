class_name ArenaCombatEventPresenter
extends RefCounted


static func is_player_facing_event(event: CombatEvent) -> bool:
	if event == null:
		return false
	return String(event.event_type) in [
		"physical_attack_declared",
		"physical_attack_accuracy_resolved",
		"physical_attack_final_legality_failed",
		"physical_defense_attempted",
		"physical_defense_resolved",
		"physical_damage_resolved",
		"critical_trigger_recorded",
		"critical_stagger_applied",
		"critical_prone_applied",
		"critical_reaction_started",
		"actor_stood_from_prone",
		"critical_effect_unavailable",
		"critical_effect_blocked",
		"physical_attack_interrupted",
		"action_interrupted",
		"called_shot_prepared",
		"timed_stat_effect_applied",
		"verified_healing_resolved",
		"rage_knockback_resolved",
		"verified_special_damage_resolved",
		"ability_use_committed",
		"ability_resources_midnight_refreshed",
		"verified_special_completion_failed",
		"reward_xp_awarded",
		"reward_drop_resolved",
		"reward_source_blocked",
		"reward_advancement_purchased",
		"ground_loot_created",
		"ground_loot_collected",
		"consumable_healing_resolved", "consumable_mana_resolved", "consumable_completion_failed",
	]


static func format_event(event: CombatEvent) -> String:
	if event == null:
		return ""
	var seconds := float(event.timestamp_us) / 1_000_000.0
	var prefix := "[%05.2f] " % seconds
	var payload := event.payload
	match String(event.event_type):
		"consumable_healing_resolved":
			return prefix + "%s drinks Health Potion: HPC %s → %s; %s remaining." % [_display_actor(event.source_actor_id), payload.get("hpc_before"), payload.get("hpc_after"), payload.get("quantity_after")]
		"consumable_mana_resolved":
			return prefix + "%s drinks Mana Potion: Mana %s → %s; %s remaining." % [_display_actor(event.source_actor_id), payload.get("mana_before"), payload.get("mana_after"), payload.get("quantity_after")]
		"consumable_completion_failed":
			return prefix + "Potion incomplete: %s." % payload.get("reason", "unavailable")
		"opening_initiative_rolled":
			return prefix + "%s Initiative: d10 %s + INIT %s = %s" % [
				_display_actor(event.source_actor_id), payload.get("natural_d10", "?"),
				payload.get("base_init", "?"), payload.get("total", "?"),
			]
		"action_started":
			return prefix + "%s begins %s; due at %.2f s (%s Act at AT %s)." % [
				_display_actor(event.source_actor_id),
				_action_display_name(String(payload.get("action_definition_id", "action"))),
				float(payload.get("final_effect_due_at_us", 0)) / 1_000_000.0,
				payload.get("required_acts", "?"),
				payload.get("at_at_start", "?"),
			]
		"action_progressed":
			return prefix + "Action progress %s / %s Acts." % [payload.get("completed_acts", "?"), payload.get("required_acts", "?")]
		"action_completed":
			return prefix + "%s completed %s." % [_display_actor(event.source_actor_id), _action_display_name(String(payload.get("action_definition_id", "action")))]
		"physical_attack_declared":
			var strike_label := ""
			var strikes_per_act := int(payload.get("strikes_per_act", 1))
			if strikes_per_act > 1:
				strike_label = " %s/%s" % [payload.get("strike_index", "?"), strikes_per_act]
			return prefix + "%s begins %s attack%s on %s [%s -> %s; %s; location ACC %s; final target %s]." % [
				_display_actor(event.source_actor_id),
				_weapon_display_name(String(payload.get("weapon_ref", "weapon"))),
				strike_label,
				_pretty_name(String(payload.get("target_location", "torso"))),
				String(payload.get("attacker_size_category", "?")),
				String(payload.get("target_size_category", "?")),
				String(payload.get("size_relationship", "unresolved")),
				payload.get("location_acc_modifier", "?"),
				payload.get("acc_target", "?"),
			]
		"physical_attack_accuracy_resolved":
			if String(payload.get("automatic_accuracy_reason", "")) == "called_shot":
				return prefix + "%s Called Shot is automatically accurate at %s; legal defenses still apply." % [
					_display_actor(event.source_actor_id), _pretty_name(String(payload.get("target_location", "target"))),
				]
			var outcome := "HIT" if payload.get("accuracy_success", false) else "MISS"
			return prefix + "%s ACC d20 %s vs %s (%s -> %s; %s; location %s): %s%s" % [
				_display_actor(event.source_actor_id), payload.get("natural_d20", "?"), payload.get("acc_target", "?"),
				String(payload.get("attacker_size_category", "?")), String(payload.get("target_size_category", "?")),
				String(payload.get("size_relationship", "unresolved")), payload.get("location_acc_modifier", "?"),
				outcome, _critical_suffix(payload),
			]
		"physical_attack_final_legality_failed":
			return prefix + "%s attack cannot connect at resolution: %s (ACC not rolled)." % [
				_display_actor(event.source_actor_id),
				_pretty_name(String(payload.get("reason", "final legality failed"))),
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
			return prefix + "%s deals %s HPC to %s (%s -> %s), roll+SB %s+%s, multiplied %s, TAL %s, NAL %s." % [
				_display_actor(event.source_actor_id), payload.get("final_damage", "?"), _display_actor(event.target_actor_id),
				payload.get("hpc_before", "?"), payload.get("hpc_after", "?"),
				payload.get("weapon_rolls", []), payload.get("strength_bonus", "?"), payload.get("multiplied_total", "?"),
				payload.get("armor_tal", "?"), payload.get("natural_armor_level", "?"),
			]
		"reward_xp_awarded":
			return prefix + "%s awards %s XP; cumulative %s, available %s." % [
				_display_actor(event.source_actor_id), payload.get("xp", "?"),
				payload.get("cumulative_earned_xp", "?"), payload.get("unspent_xp", "?"),
			]
		"reward_drop_resolved":
			return prefix + "%s drop %s: %s (%s)." % [
				_display_actor(event.source_actor_id), payload.get("drop_code", "?"),
				_pretty_name(String(payload.get("result_kind", "result"))),
				_pretty_name(String(payload.get("status", "unknown"))),
			]
		"reward_source_blocked":
			return prefix + "%s reward blocked: %s." % [
				_display_actor(event.source_actor_id), _pretty_name(String(payload.get("reason", "source unresolved"))),
			]
		"reward_advancement_purchased":
			return prefix + "%s advances %s from %s to %s for %s XP; available %s." % [
				_display_actor(event.source_actor_id), String(payload.get("target_id", "stat")).to_upper(),
				payload.get("value_before", "?"), payload.get("value_after", "?"),
				payload.get("cost", "?"), payload.get("unspent_xp", "?"),
			]
		"ground_loot_created":
			var item_definition: Dictionary = payload.get("item_definition", {})
			return prefix + "%s dropped at %s." % [item_definition.get("display_name", "Loot"), payload.get("position_microfeet", [])]
		"ground_loot_collected":
			var item_definition: Dictionary = payload.get("item_definition", {})
			return prefix + "%s collects %s x%s." % [
				_display_actor(event.source_actor_id), item_definition.get("display_name", "Loot"), payload.get("quantity", 1),
			]
		"actor_resources_committed":
			return prefix + "%s commits %s; resources now %s." % [_display_actor(event.source_actor_id), payload.get("resource_commitments", {}), payload.get("resources_after", {})]
		"ability_use_committed":
			return prefix + "%s commits %s using %s: daily %s -> %s/%s; AP %s -> %s." % [
				_display_actor(event.source_actor_id), _action_display_name(String(payload.get("ability_id", "ability"))),
				_pretty_name(String(payload.get("payment_kind", "resource"))),
				payload.get("daily_before", "?"), payload.get("daily_after", "?"), payload.get("daily_maximum", "?"),
				payload.get("ap_before", "?"), payload.get("ap_after", "?"),
			]
		"ability_resources_midnight_refreshed":
			return prefix + "%s midnight refresh: daily %s -> %s; AP %s -> %s." % [
				_display_actor(event.source_actor_id), payload.get("daily_uses_before", {}), payload.get("daily_uses_after", {}),
				payload.get("ap_before", "?"), payload.get("ap_after", "?"),
			]
		"verified_special_completion_failed":
			return prefix + "%s Special has no effect: %s; held component preserved." % [
				_display_actor(event.source_actor_id), _pretty_name(String(payload.get("reason", "completion prerequisite failed"))),
			]
		"timed_stat_effect_applied":
			return prefix + "%s activates %s: %s -> %s; expires at %.2f s." % [_display_actor(event.target_actor_id), _pretty_name(String(payload.get("effect_id", "effect"))), payload.get("stats_before", {}), payload.get("stats_after", {}), float(payload.get("expires_at_us", 0)) / 1_000_000.0]
		"timed_stat_effect_expired":
			return prefix + "%s expires: %s -> %s." % [_pretty_name(String(payload.get("effect_id", "effect"))), payload.get("stats_before", {}), payload.get("stats_after", {})]
		"called_shot_prepared":
			return prefix + "%s prepares Called Shot at %s for the next Act." % [_display_actor(event.source_actor_id), _pretty_name(String(payload.get("target_location", "target")))]
		"called_shot_consumed":
			return prefix + "%s Called Shot applies to %s strike(s) in this Act." % [_display_actor(event.source_actor_id), payload.get("applied_strike_count", 0)]
		"verified_healing_resolved":
			return prefix + "%s Rejuvenating Mist rolls %s + %s and restores %s to %s (%s -> %s/%s)." % [_display_actor(event.source_actor_id), payload.get("rolls", []), payload.get("flat_bonus", "?"), payload.get("rolled_healing", "?"), _display_actor(event.target_actor_id), payload.get("hpc_before", "?"), payload.get("hpc_after", "?"), payload.get("hpc_max", "?")]
		"rage_knockback_resolved":
			return prefix + "%s Rage hit knocks %s %s ft%s." % [_display_actor(event.source_actor_id), _display_actor(event.target_actor_id), float(payload.get("resolved_distance_microfeet", 0)) / 1_000_000.0, " (collision-limited)" if payload.get("blocked", false) else ""]
		"verified_special_damage_resolved":
			return prefix + "%s %s damage: %s x %s/%s = %s HPC to %s." % [_display_actor(event.source_actor_id), String(payload.get("special_field", "special")).capitalize(), payload.get("otherwise_applicable_damage", "?"), payload.get("field_multiplier_numerator", "?"), payload.get("field_multiplier_denominator", "?"), payload.get("final_damage", "?"), _display_actor(event.target_actor_id)]
		"tactical_action_selected":
			return prefix + "%s tactical choice: %s for %s (HPC %s, daily %s, AP %s); rejected %s." % [_display_actor(event.source_actor_id), _pretty_name(String(payload.get("selected_action", "normal_attack"))), _display_actor(event.target_actor_id), payload.get("hpc", "?"), payload.get("ability_daily_remaining", {}), payload.get("ap_remaining", "?"), payload.get("rejected_alternatives", [])]
		"material_gathered":
			return prefix + "%s gathers %s from %s into the %s hand." % [_display_actor(event.source_actor_id), _pretty_name(String(payload.get("material_id", "material"))), _pretty_name(String(payload.get("surface_id", "surface"))), String(payload.get("hand", "?"))]
		"special_material_consumed":
			return prefix + "%s consumes held %s; the %s hand is now free." % [_display_actor(event.source_actor_id), _pretty_name(String(payload.get("material_id", "material"))), String(payload.get("hand", "?"))]
		"hand_item_equipped":
			return prefix + "%s equips %s in the %s hand after one Act." % [_display_actor(event.source_actor_id), _weapon_display_name(String(payload.get("equipment_ref", "item"))), String(payload.get("hand", "?"))]
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


static func _weapon_display_name(weapon_ref: String) -> String:
	# The authoritative declaration already carries its actual weapon reference.
	# Strip catalog namespaces only for presentation; never substitute actor data.
	var label := weapon_ref.trim_prefix("prime_v3_")
	if label.begins_with("common_goblin_"):
		label = label.trim_prefix("common_goblin_")
	return _pretty_name(label)


static func _action_display_name(action_definition_id: String) -> String:
	var label := action_definition_id.trim_prefix("prime_v3_hades_combat_follower_")
	if label.begins_with("physical_attack:"):
		label = label.trim_prefix("physical_attack:")
	return _pretty_name(label)


static func _display_actor(actor_id: StringName) -> String:
	if actor_id == PrimeV3VerticalSliceFixture.PLAYER_ID:
		return "Player"
	if actor_id == PrimeV3VerticalSliceFixture.OPPONENT_ID:
		return "Opponent"
	return String(actor_id).capitalize()
