extends SceneTree
# Test-only fresh-process reader. Only a known disposable fixture root is read.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=5: quit(2);return
	var root:=args[0].replace("\\","/").simplify_path()
	var allowed:=OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/minimal46b_")
	if not root.begins_with(allowed) or not args[2] in ["normal","dev_normal"]: quit(2);return
	var starter:=PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",args[2],args[3])
	if not starter.success or starter.profile_id!=args[1]: quit(2);return
	var bytes:=FileAccess.get_file_as_bytes(root.path_join("cold.json"))
	var result:=preload("res://scripts/rewards/minimal_character_snapshot.gd").decode_bytes(bytes,starter.source,args[1],args[2])
	if not result.success or bytes.get_string_from_utf8().sha256_text()!=args[4]: quit(3);return
	print("46B_COLD_PROCESS_PASS")
	quit(0)
