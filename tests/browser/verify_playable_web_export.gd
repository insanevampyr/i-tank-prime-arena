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
	var scene := (ResourceLoader.load("res://scenes/test_arena.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).get_state()
	var visible_lines := 0
	for index in range(scene.get_node_count()):
		if String(scene.get_node_path(index)).trim_prefix("./") != "HUD/UI/CombatStatus": continue
		for property in range(scene.get_node_property_count(index)):
			if scene.get_node_property_name(index, property) == &"max_lines_visible": visible_lines = scene.get_node_property_value(index, property)
	if visible_lines < 5:
		fail("Web export clips the persistence status line; re-export the corrected scene.")
		return
	print("PASS: ordinary Web PCK includes playable async persistence, recovery callbacks and visible storage status.")
	quit()

func fail(reason: String) -> void:
	push_error(reason)
	quit(1)
