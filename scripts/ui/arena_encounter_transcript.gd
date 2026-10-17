class_name ArenaEncounterTranscript
extends RefCounted

const SCHEMA_VERSION := 1
const FIXTURE_ID := "prime_v3_guard_battle_axe_vertical_slice"


static func build_text(session: ArenaCombatSession, seed_value: int, build_version: String) -> String:
	if session == null:
		return ""
	var events := session.get_resolved_events()
	var lines := PackedStringArray([
		"ITank Prime: Arena - Authoritative Encounter Transcript",
		"Build: %s" % build_version,
		"Godot: %s" % Engine.get_version_info().get("string", "unknown"),
		"Seed: %d" % seed_value,
		"Fixture: %s (%s)" % [FIXTURE_ID, String(session.get_encounter_fixture_id())],
		"Transcript schema: %d" % SCHEMA_VERSION,
		"Simulation schema: %s" % session.simulation.get_state_snapshot().get("schema_version", "unknown"),
		"Retention: complete current encounter; RESET starts a new transcript",
		"Event count: %d" % events.size(),
		"",
	])
	for event: CombatEvent in events:
		lines.append(format_authoritative_event(event))
	return "\n".join(lines) + "\n"


static func format_authoritative_event(event: CombatEvent) -> String:
	if event == null:
		return ""
	var source := "-" if String(event.source_actor_id).is_empty() else String(event.source_actor_id)
	var target := "-" if String(event.target_actor_id).is_empty() else String(event.target_actor_id)
	var parent := "-" if event.parent_event_id.is_empty() else event.parent_event_id
	return "[%09.3f] id=%s seq=%d init=%d type=%s actor=%s target=%s parent=%s deps=%s resources=%s payload=%s" % [
		float(event.timestamp_us) / 1_000_000.0,
		event.event_id,
		event.stable_sequence,
		event.initiative,
		String(event.event_type),
		source,
		target,
		parent,
		JSON.stringify(Array(event.dependency_event_ids)),
		JSON.stringify(event.resource_commitments),
		JSON.stringify(event.payload),
	]
