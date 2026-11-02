extends SceneTree

# Explicit disposable native GUI acceptance; never opens real player profiles.
var scene: Node
func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--36l-isolated"):
		push_error("Use -- --36l-isolated for the disposable backup GUI fixture.")
		quit(1)
		return
	var root := OS.get_cache_dir().path_join("itank-storage-tests/manual_backup_%s_%s" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_storage = CharacterSaveStorage.new(root)
	PlayableCharacterPersistence.test_nonpersistent = false
	call_deferred("prepare")

func prepare() -> void:
	DisplayServer.window_set_title("Arena 36L disposable desktop backup acceptance")
	scene = (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	controller.set_physics_process(false)
	controller._encounter_selector_index = 8
	var selected := controller.select_player_character_for_testing(&"vaelis_thorn")
	if not selected.success:
		push_error(str(selected))
		quit(1)
		return
	controller._backup_actions.open_actions()
	print("Disposable profile root: ",PlayableCharacterPersistence.test_storage._root)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--36l-output="):
			var path := argument.trim_prefix("--36l-output=").replace("\\","/").simplify_path()
			var allowed := OS.get_environment("TEMP").replace("\\","/").simplify_path()+"/itank-36l-"
			if not path.begins_with(allowed):
				push_error("Disposable backup output must be TEMP/itank-36l-*.itankbackup.json")
				quit(1)
				return
			controller._backup_actions._on_action(&"export")
			controller._backup_actions._picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			controller._backup_actions._file_selected(path)
			var written: Dictionary = controller._backup_actions.last_result
			print("Desktop backup output: ",written)
			quit(0 if written.get("verified",false) else 1)

func _finalize() -> void:
	if is_instance_valid(scene): scene.free()
	PlayableCharacterPersistence.test_storage = null
	PlayableCharacterPersistence.test_nonpersistent = true
