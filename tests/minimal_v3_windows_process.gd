extends SceneTree
const Store = preload("res://scripts/rewards/minimal_v3_windows_storage.gd")
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() != 8 or a[0] not in ["verify","crash","hold"]: quit(2); return
	var starter := PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn",a[2],a[3])
	if not starter.success: quit(3); return
	var profile := "prod_vaelis_thorn" if a[2] == "normal" else "dev_vaelis_thorn"
	var route := Store.new(a[1],starter.source,profile,a[2],a[4],a[5])
	if not route.valid(): quit(4); return
	var loaded := route.load_current()
	if not loaded.success or loaded.get("empty",true): print(loaded); quit(5); return
	if a[0] == "verify": print("46I_COLD "+loaded.text.sha256_text()); quit(0); return
	if a[0] == "hold":
		var lease := route.acquire()
		if not lease.success: quit(6); return
		var marker := FileAccess.open(route.root.path_join("writer_held"),FileAccess.WRITE); marker.store_string("held"); marker.close()
		var until := Time.get_ticks_msec()+10000
		while not FileAccess.file_exists(route.root.path_join("release_writer")) and Time.get_ticks_msec() < until: OS.delay_msec(5)
		route.release(lease.owner); quit(0); return
	var c := CharacterPersistenceCoordinator.new(null)
	var own_root := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46i_child_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	if not c.admit_minimal_snapshot_v3(loaded.text,starter.source,profile,a[2],own_root).success or not c.attach_minimal_windows(a[1],a[4],a[5]).success: quit(7); return
	var owner: RefCounted = c._minimal_owner
	owner._session.configure_player_nac_automation({"profile":"Defensive" if owner._session.get_player_nac_automation().get("profile") != "Defensive" else "Aggressive"})
	owner._service.checkpoint(owner._session,loaded.snapshot.copy().current.recovery.phase)
	if c.minimal_view().pending_text.is_empty(): print("NO_CHANGED_CHECKPOINT"); c.close_minimal_prototype(); quit(8); return
	# Single immutable expected test output outside the publication directory.
	var path := a[7].replace("\\","/").simplify_path()
	if not path.begins_with(OS.get_cache_dir().replace("\\","/").path_join("itank-storage-tests/minimal46c2_46i_")): quit(9); return
	var expected := FileAccess.open(path,FileAccess.WRITE); expected.store_string(c.minimal_view().pending_text); expected.close()
	owner._windows_route.diagnostic_hook = func(at: String):
		if at != a[6]: return
		var marker := FileAccess.open(route.root.path_join("crash_reached"),FileAccess.WRITE); marker.store_string(at); marker.close()
		OS.kill(OS.get_process_id())
		var returned := FileAccess.open(route.root.path_join("kill_returned"),FileAccess.WRITE); returned.store_string("unexpected"); returned.close()
	var result := c.publish_minimal_windows()
	print("CRASH_DID_NOT_OCCUR "+str(result)); quit(10)
