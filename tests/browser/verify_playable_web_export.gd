extends SceneTree

# Run in a disposable Godot process after export. Inspect the exported controller,
# not the source tree or the synthetic browser fixture. Never opens save storage.
func _initialize() -> void:
	var pack := "res://builds/web/index.pck"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): pack = argument.trim_prefix("--pack=")
	if not ProjectSettings.load_resource_pack(pack, true):
		fail("Cannot mount exported PCK: %s" % pack)
		return
	if not FileAccess.file_exists("res://scripts/rewards/character_browser_store.js") or not FileAccess.file_exists("res://assets/Character Choices/Vaelis_Thorn_Elven_Fighter_Force_Mage_Arena_Character_Data.json"):
		fail("Web export is missing required browser storage/authored character data.")
		return
	var controller := ResourceLoader.load("res://scripts/ui/arena_combat_controller.gd", "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if controller == null:
		fail("Cannot inspect exported combat controller.")
		return
	var methods: Array[String] = []
	for method: Dictionary in controller.get_script_method_list(): methods.append(String(method.name))
	for required: String in ["_begin_browser_load", "_begin_browser_next_wave", "_poll_browser_persistence", "_on_return_to_wave_one_pressed"]:
		if not methods.has(required):
			fail("Stale Web export: missing %s. Re-export the ordinary Web preset before browser acceptance." % required)
			return
	var development := ResourceLoader.load("res://scripts/combat/character_development.gd", "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	var engine := ResourceLoader.load("res://scripts/combat/combat_simulation.gd", "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	var engine_methods: Array[String] = []
	if engine != null:
		for method: Dictionary in engine.get_script_method_list(): engine_methods.append(String(method.name))
	if development == null or not engine_methods.has("request_character_development") or not engine_methods.has("_resolve_defensive_nacs"):
		fail("Stale Web export: missing Task 37A live development/defensive NAC integration.")
		return
	var actor_script := ResourceLoader.load("res://scripts/combat/combat_actor_definition.gd", "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	var strength_method := false
	if actor_script != null:
		for method: Dictionary in actor_script.get_script_method_list():
			if method.name == "apply_verified_strength_advancement": strength_method = true
	if not strength_method:
		fail("Stale Web export: missing Task 37B permanent STR implementation.")
		return
	var session_script := ResourceLoader.load("res://scripts/combat/arena_combat_session.gd", "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	var safe_management := false
	if session_script != null:
		for method: Dictionary in session_script.get_script_method_list():
			if method.name == "get_character_advancement_eligibility": safe_management = true
	if not safe_management:
		fail("Stale Web export: missing shared READY advancement eligibility.")
		return
	var scene := (ResourceLoader.load("res://scenes/test_arena.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).get_state()
	var visible_lines := 0
	for index in range(scene.get_node_count()):
		if String(scene.get_node_path(index)).trim_prefix("./") != "HUD/UI/CombatStatus": continue
		for property in range(scene.get_node_property_count(index)):
			if scene.get_node_property_name(index, property) == &"max_lines_visible": visible_lines = scene.get_node_property_value(index, property)
	if visible_lines < 5:
		fail("Web export clips the persistence status line; re-export the corrected scene.")
		return
	call_deferred("verify_backup_controls")

func verify_backup_controls() -> void:
	var scene: Node = load("res://scenes/test_arena.tscn").instantiate()
	root.add_child(scene)
	var controller = scene.get_node("CombatController")
	controller.set_physics_process(false)
	controller._on_inventory_toggle_pressed()
	await process_frame
	var controls = controller._rewards_label.get_parent().get_node_or_null("CharacterBackupControls")
	var valid: bool = controls != null and controls.is_visible_in_tree() and controls.get_index() == 1
	if valid:
		valid = controls.get_node("ExportBackup").text == "SAVE CHARACTER" and controls.get_node("PreviewRestoreBackup").text == "LOAD CHARACTER" and controller._backup_actions._dialog.title == "Save / Load Character"
	scene.free()
	if not valid:
		fail("Exported playable scene must expose current backup controls in READY character management.")
		return
	print("PASS: ordinary Web PCK includes permanent STR, live development/defensive NAC integration, async persistence, storage status and visible READY Save/Load controls.")
	quit()

func fail(reason: String) -> void:
	push_error(reason)
	quit(1)
