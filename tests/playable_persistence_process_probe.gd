extends SceneTree

func _initialize() -> void:
	call_deferred("_verify_profile")

func _verify_profile() -> void:
	var directory := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-test-root="): directory = argument.trim_prefix("--profile-test-root=")
	var allowed := OS.get_cache_dir().path_join("itank-storage-tests").simplify_path()+"/playable_"
	if not directory.replace("\\","/").simplify_path().begins_with(allowed):
		quit(2)
		return
	PlayableCharacterPersistence.test_storage = CharacterSaveStorage.new(directory)
	PlayableCharacterPersistence.test_nonpersistent = false
	var saved := PlayableCharacterPersistence.test_storage.read_profile("prod_vaelis_thorn")
	if not saved.get("success",false):
		quit(3)
		return
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var controller: ArenaCombatController = scene.get_node("CombatController")
	var selected := controller.select_player_character_for_testing(&"vaelis_thorn")
	var good: bool = selected.get("success",false)
	if good:
		var session := controller.get_combat_session_for_testing()
		good = session.get_character_persistence_status().persistent and session.get_actor_state(&"player").current_hpc == saved.payload.recovery.player.current_hpc and session.get_actor_state(&"player").resources == saved.payload.recovery.player.resources and session._playable_persistence.items == saved.payload.items and session._playable_persistence._prior.permanent.growth == saved.payload.permanent.growth
		for field: String in CharacterWaveCheckpoint.PLAYER_FIELDS:
			var actual: Variant = session.get_actor_state(&"player").get(field)
			if actual is PackedStringArray: actual = Array(actual)
			good = good and actual == saved.payload.recovery.player[field]
	root.remove_child(scene)
	scene.free()
	PlayableCharacterPersistence.test_storage = null
	if good: print("PROCESS_PROFILE_VERIFIED")
	quit(0 if good else 4)
