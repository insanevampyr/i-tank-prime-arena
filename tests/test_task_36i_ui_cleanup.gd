extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var _failures: Array[String] = []

func run() -> Array[String]:
	_test_overlay_lifecycle()
	_test_toolbar_geometry()
	_expect(_multi_wave_refresh() == _multi_wave_refresh(), "Multi-wave refresh events, snapshots and digests must replay exactly.")
	return _failures

func _multi_wave_refresh() -> Dictionary:
	var session := ArenaCombatSession.new(3681, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS, Fixture.PLAYER_CHARACTER_VAELIS)
	session.set_opponent_behavior_enabled(false)
	session.initialize_wave_one_goblins(Vector2i(20_000_000,12_000_000),Vector2i(24_000_000,12_000_000),false)
	session.configure_reward_mode(ArenaRewardLedger.MODE_DEV_NORMAL)
	session.start_encounter()
	var player := session.get_actor_state(&"player")
	var actor := session.simulation.get_actor_definition(&"player")
	# Isolated applicable-AP/daily-use fixture; no production character changes.
	actor.resource_maxima.ap = 4
	player.resources.ap = 1
	player.ability_daily_maxima = {"fixture_ability":2}
	player.ability_daily_remaining = {"fixture_ability":0}
	for wave in range(1,5):
		var request := session.request_player_attack("refresh:pending:%s" % wave)
		_expect(request.get("success",false), "Wave %s fixture must commit a pending ordinary attack." % wave)
		if wave == 2:
			var growth := session.simulation.apply_character_experience_award(&"player","fixture:level",900,900,0)
			_expect(growth.get("success",false) and session.get_actor_max_hpm(&"player") > 9 and actor.resource_maxima.mana > 20, "Refresh fixture must actually increase HPM/Mana maxima through leveling.")
		for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
		session.advance_by(1)
		_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Each wave must enter actual downtime.")
		player.current_hpc = 3
		player.resources.mana = 1
		player.resources.ap = 1
		player.ability_daily_remaining.fixture_ability = 0
		var action_before := session.simulation.get_action(request.get("action_instance_id","")).to_dictionary()
		var rewards_before := session.get_reward_state()
		var state_before := player.to_dictionary()
		var clock_before := session.simulation.clock.get_elapsed_us()
		var rng_before := session.simulation.random.get_draw_count()
		var refreshed := session.request_developer_character_refresh("refresh:wave:%s" % wave)
		_expect(refreshed.get("success",false), "Wave %s pending-action downtime refresh must succeed, got %s." % [wave,refreshed])
		_expect(player.current_hpc == session.get_actor_max_hpm(&"player") and player.resources.mana == actor.resource_maxima.mana and player.resources.ap == 4 and player.ability_daily_remaining.fixture_ability == 2, "Wave %s refresh must restore current maxima and daily uses." % wave)
		_expect(session.simulation.get_action(request.action_instance_id).to_dictionary() == action_before, "Refresh must neither cancel nor complete paused actions.")
		for key in ["progression","equipment_refs","inventory_quantities","conditions","persistent_damage_shields"]:
			_expect(player.to_dictionary().get(key) == state_before.get(key), "Refresh must preserve %s." % key)
		_expect(session.get_reward_state() == rewards_before and session.simulation.clock.get_elapsed_us() == clock_before and session.simulation.random.get_draw_count() == rng_before, "Refresh preserves rewards, RNG and frozen time.")
		_expect(session.request_developer_character_refresh("refresh:repeat:%s" % wave).get("success",false), "Existing repeat refresh permission must remain legal.")
		var snap := session.simulation.get_state_snapshot()
		_expect(not session.request_developer_character_refresh("refresh:wave:%s" % wave).get("success",false) and session.simulation.get_state_snapshot() == snap, "Duplicate refresh ID must remain idempotent.")
		_expect(session.request_next_wave().get("success",false), "Refresh must not prevent explicit NEXT WAVE.")
	var snapshot := session.simulation.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(3681)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(snapshot.schema_version == 12 and harness.compare_clients().get("success",false) and harness.client_a.get_state_snapshot() == snapshot, "Multi-wave refresh must preserve schema-12 two-client convergence.")
	var events: Array = []
	for event: CombatEvent in session.get_resolved_events(): events.append(event.to_dictionary())
	return {"snapshot":snapshot,"events":events,"digest":SyncStateDigest.compute(snapshot)}

func _scene() -> Node:
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	return scene

func _free(scene: Node) -> void:
	scene.get_parent().remove_child(scene)
	scene.free()

func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)

func _test_overlay_lifecycle() -> void:
	var scene := _scene()
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	for _index in range(8): controller._on_encounter_selector_pressed()
	controller.get_combat_session_for_testing().set_opponent_behavior_enabled(false)
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	_expect(not controller.is_rewards_panel_visible_for_testing(), "START must leave overlay closed.")
	controller._update_rewards_panel(true)
	_expect(not controller.is_rewards_panel_visible_for_testing(), "Content refresh cannot open overlay.")
	controller._on_inventory_toggle_pressed()
	_expect(controller.is_rewards_panel_visible_for_testing(), "Combat inventory must explicitly open.")
	controller.press_encounter_control_for_testing()
	_expect(not controller.is_rewards_panel_visible_for_testing(), "RESET must close inventory.")
	controller.get_combat_session_for_testing().set_opponent_behavior_enabled(false)
	controller.press_encounter_control_for_testing()
	session = controller.get_combat_session_for_testing()
	_expect(not controller.is_rewards_panel_visible_for_testing(), "START after RESET must remain closed.")
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_BETWEEN_WAVE_DOWNTIME, "Fixture must reach genuine downtime state.")
	_expect(controller.is_rewards_panel_visible_for_testing(), "Victory downtime must open rewards once (Fix2 owner supersession).")
	var before := session.simulation.get_state_snapshot()
	var events_before := session.get_resolved_events().size()
	var rng_before := session.simulation.random.get_draw_count()
	scene.get_node("HUD/UI/CombatInventory").emit_signal("pressed")
	_expect(not controller.is_rewards_panel_visible_for_testing(), "Player can dismiss automatic victory rewards.")
	scene.get_node("HUD/UI/CombatInventory").emit_signal("pressed")
	_expect(controller.is_rewards_panel_visible_for_testing(), "Existing inventory button opens downtime rewards.")
	_expect(controller._developer_refresh_button.is_visible_in_tree() and not controller._developer_refresh_button.disabled, "DEV refresh remains accessible in explicitly opened downtime.")
	var selected := mini(1, controller._inventory_entries.size() - 1)
	controller._inventory_option.select(selected)
	var item_before: Dictionary = controller._selected_inventory_entry().duplicate(true)
	var choices_before := controller._advancement_options.duplicate(true)
	for index in range(controller._advancement_option.item_count):
		var label := controller._advancement_option.get_item_text(index)
		_expect(label.contains(" -> ") and not label.contains("→"), "Actual purchase dropdown must use ASCII arrow.")
	_expect(controller._advancement_option.item_count > 0, "Vaelis SR option must actually be exercised.")
	controller._on_inventory_toggle_pressed()
	controller._update_rewards_panel(true)
	_expect(not controller.is_rewards_panel_visible_for_testing(), "Dismissed overlay must stay closed on refresh.")
	controller._on_inventory_toggle_pressed()
	_expect(controller._selected_inventory_entry() == item_before and controller._advancement_options == choices_before, "Dismiss/reopen preserves selection and advancement options.")
	_expect(session.simulation.get_state_snapshot() == before and session.get_resolved_events().size() == events_before and session.simulation.random.get_draw_count() == rng_before, "Presentation cannot mutate authority, events, rewards, inventory or RNG.")
	_expect(before.schema_version == 12, "Snapshot schema remains 12.")
	var harness := TwoClientSyncHarness.new(1)
	harness.authority.simulation = session.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	_expect(harness.compare_clients().get("success", false) and harness.client_a.get_state_snapshot() == before, "Presentation preserves two-client snapshot convergence.")
	controller.press_encounter_control_for_testing()
	_expect(session.get_encounter_state() == ArenaCombatSession.ENCOUNTER_RUNNING and not controller.is_rewards_panel_visible_for_testing(), "NEXT WAVE closes overlay and advances normally.")
	for id: String in session.get_targetable_enemy_ids(): session.get_actor_state(StringName(id)).current_hpc = 0
	session.advance_by(1)
	controller.update_presentation_for_testing()
	_expect(controller.is_rewards_panel_visible_for_testing(), "Wave 2 victory must automatically reopen rewards.")
	controller._on_inventory_toggle_pressed()
	controller._update_rewards_panel(true)
	_expect(not controller.is_rewards_panel_visible_for_testing(), "Wave 2 refresh must respect player dismissal.")
	controller._reset_encounter()
	_expect(not controller.is_rewards_panel_visible_for_testing(), "RESET from dismissed downtime must stay closed.")
	_free(scene)

func _test_toolbar_geometry() -> void:
	var scene := _scene()
	var layout := scene as ArenaResponsiveLayout
	_expect(layout != null, "Real responsive layout must be present.")
	if layout == null:
		_free(scene)
		return
	var ui := scene.get_node("HUD/UI") as Control
	# Isolated geometry fixture: emulate each parent viewport synchronously.
	ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var buttons: Array[Button] = [ui.get_node("EncounterSelector"), ui.get_node("LogButton"), ui.get_node("DebugButton"), ui.get_node("EncounterButton")]
	buttons[0].text = "DEV NORMAL — XP ×10"
	for display in [Vector2(1650, 928), Vector2(1152, 648), Vector2(960, 540), Vector2(800, 450), Vector2(800, 360), Vector2(915, 412), Vector2(390, 844)]:
		# Include stretched browser canvas and unscaled viewports.
		var viewport: Vector2 = Vector2(1152, 648) if display.x == 1650 else display
		if display == Vector2(800, 360):
			viewport = Vector2(1152, 518.4)
		ui.size = viewport
		for encounter_text in ["RESET", "NEXT WAVE"]:
			buttons[3].text = encounter_text
			layout._apply_layout(viewport, display)
			var touch_layout := MobileTouchControls.calculate_layout(viewport, display)
			for indicator_name in ["AttackReadiness", "RunReadiness"]:
				var indicator: Control = ui.get_node(indicator_name)
				_expect(indicator.get_rect().end.y <= float(touch_layout.control_top), "Actual %s must stay above touch controls at %s (%s)." % [indicator_name, display, encounter_text])
				for button: Button in buttons:
					_expect(not indicator.get_rect().intersects(button.get_rect()), "Readiness must not overlap the retained toolbar at %s." % display)
			for index in range(buttons.size()):
				var button := buttons[index]
				var rect := button.get_rect()
				_expect(rect.position.x >= 0 and rect.end.x <= viewport.x + 0.01 and rect.position.y >= 0 and rect.end.y <= viewport.y, "Toolbar must fit viewport %s: %s %s." % [display, button.name, rect])
				_expect(button.size.x >= button.get_combined_minimum_size().x and button.size.y >= button.get_combined_minimum_size().y, "Actual text minimum must fit %s at %s." % [button.name,display])
				_expect(button.is_visible_in_tree() and button.mouse_filter != Control.MOUSE_FILTER_IGNORE and button.pressed.get_connections().size() > 0, "Toolbar controls remain visible and connected.")
				_expect(not rect.intersects((ui.get_node("Title") as Control).get_rect()), "Toolbar must not cover title at %s." % display)
				_expect(not rect.intersects((ui.get_node("CombatInventory") as Control).get_rect()), "Explicit inventory toggle cannot cover toolbar at %s." % display)
				for other in range(index + 1, buttons.size()):
					_expect(not rect.intersects(buttons[other].get_rect()), "Actual buttons cannot overlap at %s: %s / %s." % [display,button.name,buttons[other].name])
	_free(scene)
