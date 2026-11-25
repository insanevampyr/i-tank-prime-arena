extends SceneTree
func _initialize() -> void:
	if OS.get_environment("ARENA45X_UIDS") == "1":
		for i in range(3): print(ResourceUID.id_to_text(ResourceUID.create_id()))
		quit(0); return
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: quit(2); return
	var dir := args[0].replace("\\","/").simplify_path()
	var prefix := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/compact45x_")
	if not dir.begins_with(prefix) or dir.get_file() != "restart": quit(3); return
	var context: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("context.json")))
	if not context.legacy_root.replace("\\","/").simplify_path().begins_with(dir.get_base_dir()+"/"): quit(4); return
	var test := preload("res://tests/test_compact_v6_incremental_snapshot.gd").new()
	if OS.get_environment("ARENA45Y_CHECKED")=="1": test=load("res://tests/test_compact_v6_validation_reuse.gd").new()
	var witness := test.Witness.new(); witness.value = context.witness
	test.witnesses[context.legacy_root] = witness
	var record: Dictionary = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(JSON.parse_string(context.witness.text.split("\n")[1]).payload_json))
	var f: Dictionary = test.start(context.legacy_root,context.scope,null,record)
	if not f.get("success",false): print("45X_RESTART_FAIL "+str(f)); quit(5); return
	var before: String = f.service.observer.head()
	var helper := preload("res://tests/test_historical_vaelis_admission.gd").new().helper
	helper._defeat_wave(f.session)
	var acquired: Dictionary = f.session.collect_all_ground_loot()
	if acquired.success and f.service.errors.is_empty() and helper._failures.is_empty() and f.service.observer.head() != before:
		print("45X_RESTART_OK "+f.service.observer.head().sha256_text()); quit(0)
	else: print("45X_RESTART_FAIL "+str(f.service.errors)); quit(6)
