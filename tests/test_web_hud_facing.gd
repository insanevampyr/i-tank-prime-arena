class_name WebHudFacingTests
extends RefCounted

const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
const ResponsiveLayout = preload("res://scripts/ui/arena_responsive_layout.gd")
const Session = preload("res://scripts/combat/arena_combat_session.gd")
const ArenaBattlefield = preload("res://scripts/combat/arena_battlefield.gd")
const TwoClientSyncHarness = preload("res://scripts/sync/two_client_sync_harness.gd")

var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	_test_web_export_filter_is_narrow_and_required_sources_exist()
	_test_hud_regions_and_clipping_at_supported_resolutions()
	_test_authoritative_movement_facing()
	_test_facing_replay_and_two_client_convergence()
	_test_always_visible_facing_and_reset()
	_test_seeded_goblin_facing_markers()
	return _failures


func _test_web_export_filter_is_narrow_and_required_sources_exist() -> void:
	var presets := ConfigFile.new()
	var load_error := presets.load("res://export_presets.cfg")
	_expect_equal(load_error, OK, "The Web export preset must remain readable.")
	if load_error != OK:
		return
	_expect_equal(String(presets.get_value("preset.0", "export_filter", "")), "all_resources", "The Web preset must retain dependency-safe all-resource export behavior.")
	var excluded := String(presets.get_value("preset.0", "exclude_filter", ""))
	_expect_true(excluded.split(",").has("tmp/*"), "The Web preset must narrowly exclude project-local temporary artifacts.")
	_expect_true(excluded.split(",").has("tests/*"), "The published Web PCK must exclude development-only regression scripts.")
	_expect_true(excluded.split(",").has("docs/*") and excluded.split(",").has(".github/*"), "The published Web PCK must exclude documentation and workflow sources.")
	for required_path in [
		"res://scenes/test_arena.tscn",
		"res://scripts/combat/arena_combat_session.gd",
		"res://scripts/creatures/common_goblin_fixture.gd",
		"res://data/characters/prime_v3_common_goblin.tres",
	]:
		_expect_true(FileAccess.file_exists(required_path), "Required Web content must remain available: %s" % required_path)


func _test_hud_regions_and_clipping_at_supported_resolutions() -> void:
	for viewport_size in [
		Vector2(800.0, 450.0),
		Vector2(960.0, 540.0),
		Vector2(1152.0, 648.0),
		Vector2(1920.0, 1080.0),
		Vector2(2544.0, 1262.0),
	]:
		var layout := ResponsiveLayout.calculate_layout(viewport_size, viewport_size)
		var status: Rect2 = layout["combat_status_rect"]
		var results: Rect2 = layout["combat_log_rect"]
		var attack: Rect2 = layout["attack_readiness_rect"]
		var run: Rect2 = layout["run_readiness_rect"]
		_expect_rect_inside(status, viewport_size, "combat status at %s" % viewport_size)
		_expect_rect_inside(results, viewport_size, "recent results at %s" % viewport_size)
		_expect_rect_inside(attack, viewport_size, "ATTACK readiness at %s" % viewport_size)
		_expect_rect_inside(run, viewport_size, "RUN readiness at %s" % viewport_size)
		_expect_true(not status.intersects(results), "Combat status and recent results must remain in separate HUD lanes at %s." % viewport_size)
		_expect_true(not attack.intersects(run), "Readiness controls must remain distinct at %s." % viewport_size)
		_expect_true(results.size.x <= 460.01, "Recent results must remain in a bounded right-side column at %s." % viewport_size)
		var battlefield := ResponsiveLayout.calculate_battlefield_presentation(viewport_size)
		var arena_rect: Rect2 = battlefield["arena_rect"]
		_expect_rect_inside(arena_rect, viewport_size, "responsive 44 x 23-foot battlefield at %s" % viewport_size)

	var scene := _make_scene()
	if scene == null:
		return
	var status_label := scene.get_node("HUD/UI/CombatStatus") as Label
	var results_label := scene.get_node("HUD/UI/CombatLog") as RichTextLabel
	_expect_true(status_label.clip_text, "Combat status text must be clipped to its bounded panel.")
	_expect_equal(status_label.autowrap_mode, TextServer.AUTOWRAP_OFF, "Combat status must keep deliberate rows instead of wrapping target names.")
	# 36K-Fix1 retains the four combat rows and exposes persistence on row five.
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var lines := status_label.text.split("\n")
	_expect_equal(status_label.max_lines_visible, 5, "The compact HUD must expose the approved persistence row.")
	_expect_equal(lines.size(), 5, "The summary must contain four combat rows followed by persistence/message feedback.")
	if lines.size() == 5:
		for index in range(4):
			_expect_true(lines[index].begins_with(["READY | ", "PLAYER: HPC ", "TARGET: ", "RANGE: "][index]), "Combat row %d must retain its content and order." % (index + 1))
		_expect_true(lines[4].begins_with(controller._browser_status_text() + " | "), "Persistence status must precede long messages so horizontal clipping cannot hide it.")
	_expect_true(status_label.is_visible_in_tree() and status_label.clip_contents, "The summary must remain visible inside its bounded backdrop.")
	_expect_equal(status_label.get_visible_line_count(), 5, "The actual label must display all five rows without hiding persistence feedback.")
	_expect_true(status_label.get_theme_stylebox("normal") is StyleBoxFlat, "Combat status must use a distinct bounded backdrop.")
	_expect_true(results_label.scroll_active and results_label.scroll_following, "Recent results must scroll inside its own bounded region.")
	_expect_true(results_label.get_theme_stylebox("normal") is StyleBoxFlat, "Recent results must use a distinct bounded backdrop.")
	_expect_equal(ArenaCombatController.compact_actor_name(&"wave_1_common_goblin_04"), "GOBLIN 4", "Long authoritative Goblin IDs need a concise presentation name.")
	_free_scene(scene)


func _test_authoritative_movement_facing() -> void:
	_expect_equal(Session.facing_millidegrees_for_displacement(Vector2i(1, 0), 17), 0, "Positive X movement must face right.")
	_expect_equal(Session.facing_millidegrees_for_displacement(Vector2i(0, 1), 17), 90_000, "Positive Y movement must face down in Godot world coordinates.")
	_expect_equal(Session.facing_millidegrees_for_displacement(Vector2i(-1, 0), 17), 180_000, "Negative X movement must face left.")
	_expect_equal(Session.facing_millidegrees_for_displacement(Vector2i(0, -1), 17), 270_000, "Negative Y movement must face up.")
	_expect_equal(Session.facing_millidegrees_for_displacement(Vector2i.ZERO, 361_000), 1_000, "No movement must retain and normalize the prior authoritative facing.")

	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.press_encounter_control_for_testing()
	var session := controller.get_combat_session_for_testing()
	var player_state := session.get_actor_state(Fixture.PLAYER_ID)
	var first := session.request_player_movement(player_state.position_microfeet + Vector2i(1_000_000, 0), 12)
	_expect_true(first.get("success", false), "Authoritative player movement must remain legal for the facing regression.")
	_expect_equal(player_state.facing_millidegrees, 0, "Authoritative player state must face the accepted movement direction.")
	var second := session.request_player_movement(player_state.position_microfeet + Vector2i(0, 1_000_000), 12)
	_expect_true(second.get("success", false), "A second legal movement direction must remain accepted.")
	_expect_equal(player_state.facing_millidegrees, 90_000, "Authoritative facing must update after the movement direction changes.")
	_free_scene(scene)


func _test_always_visible_facing_and_reset() -> void:
	var scene := _make_scene()
	if scene == null:
		return
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var player := scene.get_node("PlaceholderPlayer") as Node2D
	var player_label := scene.get_node("PlaceholderPlayer/HPC") as Label
	var player_marker := scene.get_node("PlaceholderPlayer/FacingMarker") as Polygon2D
	var opponent_marker := scene.get_node("Opponent/FacingMarker") as Polygon2D
	_expect_true(player_marker.visible and opponent_marker.visible, "Living Guard facing indicators must be visible during ordinary gameplay.")
	_expect_marker_clear_of_actor_and_hpc(player_marker, player_label, "player")
	controller.set_world_presentation_pixels_per_foot(40.0)
	var scaled_tip_distance := player_marker.to_global(player_marker.polygon[1]).distance_to(player.global_position)
	_expect_true(is_equal_approx(scaled_tip_distance, 38.0 * 40.0 / 24.0), "The facing marker offset must scale with the responsive actor presentation.")
	var event_count := controller.get_combat_session_for_testing().get_resolved_event_count()
	controller.set_debug_overlay_visible(true)
	_expect_true(player_marker.visible and opponent_marker.visible, "Opening DEBUG must not change always-visible facing indicators.")
	controller.set_debug_overlay_visible(false)
	_expect_true(player_marker.visible and opponent_marker.visible, "Closing DEBUG must not hide facing indicators.")
	controller.set_transcript_visible(true)
	_expect_true(player_marker.visible and opponent_marker.visible, "Opening FULL LOG must not change facing-indicator visibility.")
	controller.set_transcript_visible(false)
	_expect_equal(controller.get_combat_session_for_testing().get_resolved_event_count(), event_count, "DEBUG and FULL LOG presentation must not append authoritative events.")
	var opponent_state := controller.get_combat_session_for_testing().get_actor_state(Fixture.OPPONENT_ID)
	opponent_state.facing_millidegrees = 225_000
	controller.update_presentation_for_testing()
	_expect_true(is_equal_approx(opponent_marker.rotation_degrees, 225.0), "The marker must render the actor's authoritative facing value.")
	opponent_state.current_hpc = 0
	controller.update_presentation_for_testing()
	_expect_true(not opponent_marker.visible, "Defeated actors must not display facing indicators.")

	controller.press_encounter_control_for_testing()
	controller.press_encounter_control_for_testing()
	_expect_true(player_marker.visible and opponent_marker.visible, "RESET must reconstruct always-visible living actor facing indicators.")
	_expect_true(is_equal_approx(player_marker.rotation_degrees, ArenaCombatController.facing_rotation_degrees(controller.get_combat_session_for_testing().get_actor_state(Fixture.PLAYER_ID).facing_millidegrees)), "RESET must render the reconstructed authoritative facing.")
	_free_scene(scene)


func _test_facing_replay_and_two_client_convergence() -> void:
	var first := _make_active_wave_session(3)
	var second := _make_active_wave_session(3)
	if first == null or second == null:
		return
	var destination := Vector2i(20_000_000, 13_000_000)
	_expect_true(first.request_player_movement(destination, 12).get("success", false), "The first deterministic replay must accept the facing movement.")
	_expect_true(second.request_player_movement(destination, 12).get("success", false), "The second deterministic replay must accept the same facing movement.")
	_expect_equal(_event_signature(first), _event_signature(second), "The same seeded facing movement must produce an identical authoritative history.")
	_expect_equal(first.get_state_snapshot(), second.get_state_snapshot(), "The same seeded facing movement must produce an identical authoritative snapshot.")

	var harness := TwoClientSyncHarness.new(3)
	var authority_session := Session.new(3, harness.authority.simulation, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	authority_session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var initialized := authority_session.initialize_wave_one_goblins(Vector2i(20_000_000, 12_000_000), Vector2i(23_000_000, 12_000_000), true)
	_expect_true(initialized.get("success", false), "The synchronized facing regression must initialize Wave 1.")
	if not initialized.get("success", false):
		return
	_expect_true(authority_session.request_player_movement(destination, 12).get("success", false), "The authority must accept the synchronized facing movement.")
	var envelopes := harness.authority.publish_current_events()
	harness.deliver_in_order(envelopes)
	_expect_true(harness.compare_clients().get("success", false), "Both simulated clients must converge after authoritative facing changes.")
	_expect_equal(harness.authority.get_state_digest(), harness.client_a.get_state_digest(), "Facing state and event history must retain the authoritative replay digest.")


func _test_seeded_goblin_facing_markers() -> void:
	for seed_and_count in [[1, 3], [3, 4]]:
		var scene := _make_scene()
		if scene == null:
			return
		var controller: ArenaCombatController = scene.get_node("CombatController")
		_expect_true(controller.set_seed_text_for_testing(str(seed_and_count[0])).get("success", false), "The seeded facing regression requires a valid READY seed.")
		_expect_true(controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_WAVE_ONE_GOBLINS).get("success", false), "Wave 1 must remain selectable for seeded facing coverage.")
		var session := controller.get_combat_session_for_testing()
		var goblin_ids := session.get_targetable_enemy_ids()
		_expect_equal(goblin_ids.size(), seed_and_count[1], "The facing presentation must support the seeded Goblin count.")
		var event_count := session.get_resolved_event_count()
		controller.update_presentation_for_testing()
		for actor_id: String in goblin_ids:
			var visual := controller._get_enemy_visual(StringName(actor_id))
			var marker := visual.get_node_or_null("FacingMarker") as Polygon2D if visual != null else null
			_expect_true(marker != null and marker.visible, "Every living seeded Goblin must receive an always-visible facing marker.")
			if marker != null:
				var state := session.get_actor_state(StringName(actor_id))
				_expect_true(is_equal_approx(marker.rotation_degrees, ArenaCombatController.facing_rotation_degrees(state.facing_millidegrees)), "Goblin marker orientation must come from authoritative facing.")
				_expect_marker_clear_of_actor_and_hpc(marker, visual.get_node("Label") as Label, "Goblin")
		controller.set_debug_overlay_visible(true)
		controller.set_debug_overlay_visible(false)
		for actor_id: String in goblin_ids:
			var visual := controller._get_enemy_visual(StringName(actor_id))
			var marker := visual.get_node_or_null("FacingMarker") as Polygon2D
			_expect_true(marker.visible, "DEBUG toggling must not affect seeded Goblin facing indicators.")
		_expect_equal(session.get_resolved_event_count(), event_count, "Facing presentation for seeded actors must not alter authoritative history.")
		if not goblin_ids.is_empty():
			var first_state := session.get_actor_state(StringName(goblin_ids[0]))
			first_state.current_hpc = 0
			controller.update_presentation_for_testing()
			var first_visual := controller._get_enemy_visual(StringName(goblin_ids[0]))
			var first_marker := first_visual.get_node_or_null("FacingMarker") as Polygon2D
			_expect_true(not first_marker.visible, "A defeated Goblin's marker must be hidden.")
		_free_scene(scene)


func _expect_marker_clear_of_actor_and_hpc(marker: Polygon2D, hpc_label: Label, actor_label: String) -> void:
	var actor_and_target_outline := Rect2(-24.0, -24.0, 48.0, 48.0)
	var hpc_rect := Rect2(hpc_label.position, hpc_label.size)
	for degrees in [0.0, 90.0, 180.0, 270.0]:
		for point: Vector2 in marker.polygon:
			var rotated := point.rotated(deg_to_rad(degrees))
			_expect_true(not actor_and_target_outline.has_point(rotated), "%s facing marker must remain outside the actor and target-outline footprint." % actor_label)
			_expect_true(not hpc_rect.has_point(rotated), "%s facing marker must remain clear of its HPC label." % actor_label)


func _make_active_wave_session(seed_value: int) -> ArenaCombatSession:
	var session := Session.new(seed_value, null, Fixture.ENCOUNTER_WAVE_ONE_GOBLINS)
	session.configure_battlefield(ArenaBattlefield.create_task16_test_arena())
	var result := session.initialize_wave_one_goblins(
		Vector2i(20_000_000, 12_000_000),
		Vector2i(23_000_000, 12_000_000),
		true
	)
	_expect_true(result.get("success", false), "The deterministic facing fixture must initialize.")
	return session if result.get("success", false) else null


func _event_signature(session: ArenaCombatSession) -> Array[Dictionary]:
	var signature: Array[Dictionary] = []
	for event: CombatEvent in session.get_resolved_events():
		signature.append(event.to_dictionary())
	return signature


func _make_scene() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_failures.append("SceneTree unavailable for Task 31K presentation verification.")
		return null
	var packed: PackedScene = load("res://scenes/test_arena.tscn")
	var scene := packed.instantiate()
	tree.root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var fixture_result := controller.select_encounter_fixture_for_testing(Fixture.ENCOUNTER_MEDIUM_GUARDS)
	_expect_true(fixture_result.get("success", false), "The Task 31K legacy presentation fixture must explicitly select the Guard duel.")
	return scene


func _free_scene(scene: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and scene.get_parent() == tree.root:
		tree.root.remove_child(scene)
	scene.free()


func _expect_rect_inside(rect: Rect2, bounds: Vector2, label: String) -> void:
	_expect_true(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= bounds.x and rect.end.y <= bounds.y, "%s must remain inside the viewport; got %s." % [label, rect])


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s Expected %s, got %s." % [message, str(expected), str(actual)])


func _expect_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
