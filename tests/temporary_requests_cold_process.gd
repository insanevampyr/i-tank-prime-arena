extends SceneTree
const Owner = preload("res://scripts/rewards/temporary_character_requests.gd")
const Q = preload("res://tests/test_compact_v6_gameplay_candidate.gd")
const Player = preload("res://scripts/player/placeholder_player.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1: quit(2); return
	var allowed := OS.get_cache_dir().path_join("itank-storage-tests/temporary46f_").replace("\\","/")
	var root := args[0].replace("\\","/").simplify_path()
	if not root.begins_with(allowed): quit(3); return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("cold_restart.json")))
	if not String(data.storage_root).replace("\\","/").simplify_path().begins_with(allowed): quit(4); return
	var f := Q.new().start(CharacterSaveStorage.new(data.storage_root),"dev_normal",null,{},false)
	if not f.success: quit(5); return
	var p := Player.new();p.reset_for_encounter(Vector2(14,8))
	p.configure_authoritative_actor_profile(f.session.simulation.get_actor_definition(&"player"));p.restore_wave_entry_motion(f.movement.wave_entry_state())
	f.session.player_movement_boundary_provider=p.capture_wave_entry_motion
	var c := CharacterPersistenceCoordinator.new(null)
	var opened := c.bind_temporary_requests(f.session,p,data.snapshot_text)
	if not opened.success: print(opened);p.free();quit(6);return
	var before: Dictionary = f.session.get_state_snapshot(); var revision: int=f.session._character_capture_gate.revision()
	var forged := Owner.Request.new(c.temporary_context(),data.old_request)
	var accepted: Dictionary=f.session.simulation._accepted_request_ids.duplicate(true)
	if c.execute_temporary_request(forged).success or f.session.request_player_inventory_equip(&"prime_v3_short_wand","shared_raw").success: p.free();quit(7);return
	if f.session.get_state_snapshot()!=before or f.session._character_capture_gate.revision()!=revision or f.session.simulation._accepted_request_ids!=accepted or c.temporary_request_status().source_calls!=0: p.free();quit(8);return
	var issued := c.issue_temporary_request(c.temporary_context(),"equip","prime_v3_short_wand","","cold_current_equip")
	if not issued.success or not c.execute_temporary_request(issued.request).success: p.free();quit(9);return
	if not c.close_temporary_requests().success: p.free();quit(10);return
	p.free();print("46F_COLD_PASS");quit(0)
