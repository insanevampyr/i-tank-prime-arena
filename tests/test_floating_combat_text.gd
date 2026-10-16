extends RefCounted

const Mapper = preload("res://scripts/ui/combat_floating_text_mapper.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Digest = preload("res://scripts/sync/sync_state_digest.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_defense_and_attack_mapping()
	_test_critical_damage_and_condition_ownership()
	_test_simultaneous_and_critical_chain_mapping()
	_test_duplicate_reset_and_layout_safety()
	_test_mapper_is_pure_for_authoritative_state()
	return _failures


func _test_defense_and_attack_mapping() -> void:
	_expect_text(_event("defense_dodge", &"physical_defense_resolved", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"successful_defense_type": "dodge"}), "DODGE!", Fixture.OPPONENT_ID, "A resolved successful Dodge must appear above the defender.")
	_expect_text(_event("defense_weapon", &"physical_defense_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"successful_defense_type": "weapon_block"}), "WEAPON BLOCK!", Fixture.PLAYER_ID, "Weapon Block must remain distinct from Shield Block.")
	_expect_text(_event("defense_shield", &"physical_defense_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"successful_defense_type": "shield_block"}), "SHIELD BLOCK!", Fixture.PLAYER_ID, "Shield Block must remain distinct from Weapon Block.")
	_expect_text(_event("defense_soak", &"physical_defense_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"successful_defense_type": "physical_soak"}), "SOAK!", Fixture.PLAYER_ID, "A resolved Physical Soak must be announced.")
	_expect_text(_event("dodge_failed", &"physical_defense_attempted", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"attempt": {"defense_type": "dodge", "success": false}}), "DODGE FAILED", Fixture.OPPONENT_ID, "A failed Dodge must not be presented as successful.")
	_expect_true(Mapper.messages_for_event(_event("attack_hit", &"physical_attack_accuracy_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"accuracy_success": true}))[0]["text"] == "HIT!", "Ordinary successful ACC must show HIT.")
	_expect_true(Mapper.messages_for_event(_event("attack_miss", &"physical_attack_accuracy_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"accuracy_success": false}))[0]["text"] == "MISS!", "Ordinary failed ACC must show MISS.")


func _test_critical_damage_and_condition_ownership() -> void:
	_expect_text(_event("critical_success", &"critical_trigger_recorded", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"critical_record": {"result_kind": "success", "outcome_id": "potent_strike"}}), "CRIT HIT! Potent Strike", Fixture.PLAYER_ID, "Critical success must use the recorded outcome ID, not an inferred effect.")
	_expect_text(_event("critical_failure", &"critical_trigger_recorded", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"critical_record": {"result_kind": "failure", "outcome_id": "hard_fall"}}), "CRIT FAIL! Hard Fall", Fixture.OPPONENT_ID, "Critical failure must use the recorded table outcome.")
	_expect_text(_event("stagger", &"critical_stagger_applied", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"affected_actor_id": "opponent"}), "STAGGER!", Fixture.OPPONENT_ID, "Critical Stagger must attach to the authoritative affected actor.")
	_expect_text(_event("prone", &"critical_prone_applied", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"affected_actor_id": "player"}), "PRONE!", Fixture.PLAYER_ID, "Prone must attach to the authoritative affected actor.")
	_expect_text(_event("damage", &"physical_damage_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"final_damage": 18, "hpc_after": 42}), "-18 HPC", Fixture.OPPONENT_ID, "Damage text must use only the committed authoritative final damage.")
	var defeat_messages: Array = Mapper.messages_for_event(_event("defeat", &"physical_damage_resolved", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"final_damage": 9, "hpc_after": 0}))
	_expect_true(defeat_messages.size() == 2 and defeat_messages[1]["text"] == "DEFEATED!" and defeat_messages[1]["actor_id"] == Fixture.PLAYER_ID, "A committed zero-HPC result must announce defeat above the damaged target.")
	_expect_text(_event("reaction", &"critical_reaction_started", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {}), "CRITICAL REACTION!", Fixture.OPPONENT_ID, "Nested Critical Reactions must remain actor-owned.")


func _test_simultaneous_and_critical_chain_mapping() -> void:
	var simultaneous_player := _event("simultaneous_player_damage", &"physical_damage_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"final_damage": 6, "hpc_after": 94}, 20)
	var simultaneous_opponent := _event("simultaneous_opponent_damage", &"physical_damage_resolved", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"final_damage": 4, "hpc_after": 96}, 20)
	var player_messages: Array = Mapper.messages_for_event(simultaneous_player)
	var opponent_messages: Array = Mapper.messages_for_event(simultaneous_opponent)
	_expect_true(player_messages[0]["actor_id"] == Fixture.OPPONENT_ID and opponent_messages[0]["actor_id"] == Fixture.PLAYER_ID, "Same-timestamp attacks must retain each committed damage target.")
	var first_reaction := _event("critical_reaction_parent", &"critical_reaction_started", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {}, 21)
	var nested_reaction := _event("critical_reaction_child", &"critical_reaction_started", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {}, 21)
	_expect_true(Mapper.messages_for_event(first_reaction)[0]["actor_id"] == Fixture.PLAYER_ID and Mapper.messages_for_event(nested_reaction)[0]["actor_id"] == Fixture.OPPONENT_ID, "Nested critical-reaction events must remain separately owned and presentable.")


func _test_duplicate_reset_and_layout_safety() -> void:
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for floating combat-text test.")
		scene.free()
		return
	tree.root.add_child(scene)
	var layer: ArenaFloatingCombatText = scene.get_node("FloatingCombatText")
	var first := _event("duplicate_event", &"physical_damage_resolved", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"final_damage": 7, "hpc_after": 93})
	layer.present_authoritative_event(first)
	layer.present_authoritative_event(first)
	_expect_true(layer.get_active_messages_for_testing().size() == 1, "Duplicate delivery must not double-present visual feedback.")
	var out_of_order := _event("earlier_timestamp", &"physical_defense_resolved", Fixture.OPPONENT_ID, Fixture.PLAYER_ID, {"successful_defense_type": "dodge"}, 0)
	layer.present_authoritative_event(out_of_order)
	_expect_true(layer.get_active_messages_for_testing().size() == 2, "Distinct out-of-order delivery must remain independently understandable.")
	layer.present_authoritative_event(_event("failed_weapon", &"physical_defense_attempted", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"attempt": {"defense_type": "weapon_block", "success": false}}))
	layer.present_authoritative_event(_event("failed_shield", &"physical_defense_attempted", Fixture.PLAYER_ID, Fixture.OPPONENT_ID, {"attempt": {"defense_type": "shield_block", "success": false}}))
	var combined := layer.get_active_messages_for_testing()
	_expect_true(combined.size() == 3 and String(combined[2]["text"]) == "DEFENSES FAILED x2", "Same-frame low-priority defense failures must combine instead of overlapping.")
	var player: Node2D = scene.get_node("PlaceholderPlayer")
	player.position = Vector2(5.0, 95.0)
	layer.call("_process", 0.1)
	for message: Dictionary in layer.get_active_messages_for_testing():
		_expect_true(int(message["lane"]) >= 0 and int(message["lane"]) < 3, "Crowded or edge messages must use bounded visual lanes.")
	layer.clear()
	_expect_true(layer.get_active_messages_for_testing().is_empty(), "RESET/clear must remove all pending visual messages.")
	scene.free()


func _test_mapper_is_pure_for_authoritative_state() -> void:
	var session := ArenaCombatSession.new(21)
	session.initialize(Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000))
	var before := Digest.compute(session.get_state_snapshot())
	for event: CombatEvent in session.get_resolved_events():
		Mapper.messages_for_event(event)
	var after := Digest.compute(session.get_state_snapshot())
	_expect_true(before == after, "Floating-text mapping must not mutate combat state, RNG, or synchronization digest.")


func _expect_text(event: CombatEvent, expected_text: String, expected_actor: StringName, message: String) -> void:
	var mapped: Array = Mapper.messages_for_event(event)
	_expect_true(mapped.size() == 1 and mapped[0]["text"] == expected_text and mapped[0]["actor_id"] == expected_actor, message)


func _event(event_id: String, event_type: StringName, source: StringName, target: StringName, payload: Dictionary, timestamp_us: int = 10) -> CombatEvent:
	return CombatEvent.new(event_id, timestamp_us, 4, 1, event_type, source, target, "", PackedStringArray(), payload, {})


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
