extends SceneTree
func _initialize() -> void:
	if OS.get_environment("ARENA45W_UIDS") == "1":
		for i in range(3): print(ResourceUID.id_to_text(ResourceUID.create_id()))
		quit(0); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: quit(2); return
	var root := args[0].replace("\\","/").simplify_path()
	if not root.begins_with(OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45w_restart_")): quit(3); return
	var context: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("context.txt")))
	var trusted := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",context.scope,context.baseline)
	if not trusted.success or trusted.profile_id != context.profile: quit(4); return
	var module: GDScript = load("res://scripts/rewards/compact_v6_snapshot_package.gd")
	var checked: Dictionary = module.cold_verify(FileAccess.get_file_as_string(root.path_join("head.txt")),FileAccess.get_file_as_string(root.path_join("current.txt")),trusted.source,context.profile,context.scope)
	var repaired: Dictionary = module.recover(FileAccess.get_file_as_string(root.path_join("head.txt")),"damaged",FileAccess.get_file_as_string(root.path_join("replica.txt")),trusted.source,context.profile,context.scope)
	if checked.success and repaired.success and repaired.text.sha256_text() == checked.package_sha256:
		print("45W_RESTART_OK "+checked.package_sha256); quit(0)
	else: print("45W_RESTART_FAIL "+str(checked)); quit(5)
