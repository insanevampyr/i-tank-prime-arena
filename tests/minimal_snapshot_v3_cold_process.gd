extends SceneTree
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5: quit(2); return
	var root := args[0].replace("\\","/").simplify_path()
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/snapshot46g_")
	if not root.begins_with(allowed) or not args[2] in ["normal","dev_normal"]: quit(2); return
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",args[2],args[3])
	if not starter.success or starter.profile_id != args[1]: quit(3); return
	var text := FileAccess.get_file_as_string(root.path_join("v3.json"))
	var checked := Codec.decode(text,starter.source,args[1],args[2])
	if not checked.success or text.sha256_text() != args[4]: print(checked); quit(4); return
	var expected: Dictionary = Codec.Contract._normalize_json_numbers(JSON.parse_string(FileAccess.get_file_as_string(root.path_join("expected.json"))))
	if checked.snapshot.projection() != expected: quit(5); return
	var body: Dictionary = checked.snapshot.copy()
	var uses: Array = body.evidence.item_debits
	if uses.is_empty(): quit(6); return
	var key := JSON.stringify([uses[0].run_id,uses[0].request_id])
	if checked.snapshot.transaction("item_use",key,Codec.binding(body,"item_use",uses[0])).success: quit(7); return
	print("46G_COLD_PASS"); quit(0)
