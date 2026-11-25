extends SceneTree
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v2.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=6: quit(2); return
	var root := args[0].replace("\\","/").simplify_path()
	if not root.begins_with(OS.get_cache_dir().path_join("itank-storage-tests/commands46d_").replace("\\","/")): quit(3); return
	var source := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",args[2],args[3])
	if not source.success: quit(4); return
	var bytes := FileAccess.get_file_as_bytes(root.path_join("cold_v2.json"))
	if bytes.get_string_from_utf8().sha256_text()!=args[4]: quit(5); return
	var decoded := Codec.decode_bytes(bytes,source.source,args[1],args[2])
	if not decoded.success: print(decoded); quit(6); return
	var facts: Array = decoded.snapshot.copy().command_evidence.facts.filter(func(f): return f.request_id==args[5])
	if facts.size()!=1 or decoded.snapshot.command_request(args[5],Codec.command_binding(decoded.snapshot.copy(),facts[0])).get("reason")!="duplicate_command": quit(7); return
	print("46D_COLD_PROCESS_PASS"); quit(0)
