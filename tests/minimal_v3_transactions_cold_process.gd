extends SceneTree
const Codec = preload("res://scripts/rewards/minimal_character_snapshot_v3.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3: quit(2); return
	var path := args[0].replace("\\","/").simplify_path()
	var allowed := OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/minimal46c2_46h_")
	if not path.begins_with(allowed) or args[1] not in ["normal","dev_normal"]: quit(3); return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",args[1],args[2]).source
	var profile := "prod_vaelis_thorn" if args[1] == "normal" else "dev_vaelis_thorn"
	var c := CharacterPersistenceCoordinator.new(null)
	var result := c.admit_minimal_snapshot_v3(FileAccess.get_file_as_string(path.path_join("record.json")),source,profile,args[1],path.path_join("owned"))
	if not result.success: print(result); quit(4); return
	var a: RefCounted = c._minimal_owner
	var before: Dictionary = a._session.get_state_snapshot()
	var issued := c.issue_temporary_request(c.temporary_context(),"use","health_potion","","downtime_use")
	if not issued.success or c.execute_temporary_request(issued.request).get("reason") != "reused_irreversible_consumption" or a._requests.status().source_calls != 0 or before != a._session.get_state_snapshot(): quit(5); return
	c.close_minimal_prototype()
	print("46H_COLD_PASS"); quit(0)
