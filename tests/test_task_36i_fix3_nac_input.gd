extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const Force = preload("res://scripts/combat/vaelis_force_fixture.gd")
const MouseTests = preload("res://tests/test_mouse_hold_arrow_movement.gd")
const ForceTests = preload("res://tests/test_vaelis_force_magic.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	_test_input(false)
	_test_input(true)
	for casting in [false,true]:
		_expect(_concurrent(casting) == _concurrent(casting), "Concurrent NAC events and snapshot digests must replay exactly.")
	return _failures

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)

func _press(controller: ArenaCombatController, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = position
	event.pressed = pressed
	controller._input(event)
	if pressed: controller._unhandled_input(event)

func _test_input(rapid: bool) -> void:
	var scene := MouseTests.new()._make_ready_scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	var session := controller.get_combat_session_for_testing()
	session.set_opponent_behavior_enabled(false)
	controller.press_encounter_control_for_testing()
	session.get_actor_state(&"player").position_microfeet = Vector2i(20_000_000,5_000_000)
	session.get_actor_state(Fixture.OPPONENT_ID).position_microfeet = Vector2i(22_000_000,5_000_000)
	session.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 2000
	controller.update_presentation_for_testing()
	var player := session.get_actor_state(&"player")
	_expect(not session.get_player_nac_automation().get("automatic_enabled",true), "Input fixture must have automatic NAC OFF.")
	if rapid:
		for _index in range(5):
			_press(controller, controller._get_enemy_visual(Fixture.OPPONENT_ID).global_position, true)
			_press(controller, Vector2.ZERO, false)
		_expect(player.nac_uses_this_round == 5 and player.resources.mana == 10, "Five distinct immediate clicks must produce five NACs costing exactly 10 Mana.")
		_press(controller, controller._get_enemy_visual(Fixture.OPPONENT_ID).global_position, true)
		_expect(player.resources.mana == 10, "Rejected sixth click must not spend Mana.")
	else:
		var point := controller._get_enemy_visual(Fixture.OPPONENT_ID).global_position
		_press(controller, point, true)
		_expect(player.nac_uses_this_round == 1 and player.resources.mana == 18, "Single physical press costs exactly two Mana.")
		for _frame in range(30): controller._advance_session_with_attack_hold(1_000)
		_expect(player.nac_uses_this_round == 1 and player.resources.mana == 18, "Holding across frames must not submit additional NACs.")
		_press(controller, point, true)
		_expect(player.nac_uses_this_round == 1, "Duplicate pressed event without release is not another physical click.")
		_press(controller, point, false)
		_press(controller, controller._get_enemy_visual(Fixture.OPPONENT_ID).global_position, true)
		_expect(player.nac_uses_this_round == 2 and player.resources.mana == 16, "Release then press permits another immediate NAC.")
	_expect(player.automatic_nac_uses_this_round == 0, "Manual input must not enable automation.")
	scene.get_parent().remove_child(scene)
	scene.free()

func _concurrent(casting: bool) -> Dictionary:
	var session := ForceTests.new()._session(34_102,Vector2i(22_000_000,12_000_000))
	session.set_opponent_behavior_enabled(false)
	session.get_actor_state(Fixture.OPPONENT_ID).current_hpc = 2000
	var ordinary := session.request_player_special(Force.FORCE_SHIELD_ID) if casting else session.request_player_attack("concurrent:sword")
	_expect(ordinary.get("success",false), "Ordinary physical/casting action must actually start.")
	var state := session.get_actor_state(&"player")
	var action := session.simulation.get_action(state.current_action_instance_id)
	if action == null:
		_expect(false,"Concurrent fixture needs an active ordinary action.")
		return {}
	var timing := action.to_dictionary()
	var mana_before := int(state.resources.mana)
	for _index in range(2):
		_expect(session.request_player_special(Force.FORCE_BOLT_ID).get("success",false), "Legal NAC must work during attack or ordinary spellcast.")
		_expect(action.to_dictionary() == timing and state.current_action_instance_id == action.action_instance_id, "NAC cannot cancel, advance, delay or replace the ordinary action.")
	_expect(state.resources.mana == mana_before - 4, "Concurrent NACs retain two-Mana cost; Shield retains four-Mana cost.")
	var sim := session.simulation
	var request := sim.start_nac_projectile_special(&"player",Fixture.OPPONENT_ID,Force.make_force_bolt_attack_definition(Fixture.VAELIS_WAND_REF),"nac:deduplicate",Force.FORCE_BOLT_ID,2,&"torso",true)
	_expect(request.get("success",false), "Explicit-ID NAC must be accepted during ordinary action.")
	var before := sim.get_state_snapshot()
	var duplicate := sim.start_nac_projectile_special(&"player",Fixture.OPPONENT_ID,Force.make_force_bolt_attack_definition(Fixture.VAELIS_WAND_REF),"nac:deduplicate",Force.FORCE_BOLT_ID,2,&"torso",true)
	_expect(duplicate.get("reason") == "duplicate_request" and sim.get_state_snapshot() == before, "Duplicate ID must not mutate events, resources or RNG.")
	session.advance_by(action.final_effect_due_at_us - sim.clock.get_elapsed_us())
	_expect(action.to_dictionary().final_effect_due_at_us == timing.final_effect_due_at_us and action.status == CombatActionInstance.STATUS_COMPLETED, "Ordinary action must complete at its original boundary.")
	var snapshot := sim.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(34_102)
	harness.authority.simulation = sim
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(snapshot.schema_version == 12 and harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == snapshot, "Concurrent NACs retain schema-12 convergence.")
	var events: Array = []
	for event: CombatEvent in session.get_resolved_events(): events.append(event.to_dictionary())
	return {"events":events,"snapshot":snapshot,"digest":SyncStateDigest.compute(snapshot)}
