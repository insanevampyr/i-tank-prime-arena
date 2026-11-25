extends SceneTree
const Windows = preload("res://scripts/rewards/compact_v6_windows_storage.gd")
const Credit = preload("res://scripts/rewards/character_expc_credit.gd")
class CrashRoute extends Windows:
	var cut := ""
	func _rename(a: String, b: String) -> bool:
		var ok := super._rename(a,b)
		if ok and ((cut == "record" and a.ends_with("record.pending")) or (cut == "fence" and a.ends_with("fence.pending")) or (cut == "route" and b.ends_with("route.json"))):
			print("45S_SELF_CRASH "+cut+" pid="+str(OS.get_process_id()))
			OS.kill(OS.get_process_id())
		return ok
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not Windows.allowed(args[0]) or args[1] not in ["record","fence","route","incremental"]: quit(2); return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Credit.BASELINE).source
	if args[1] == "incremental":
		var base := Windows.new(args[0],source,Credit.PROFILE,"dev_normal")
		var activated := CharacterPersistenceCoordinator.new(base.guard).activate_compact(base,func(q):return {"confirmed":true,"binding":base.V6.digest(q)})
		if not activated.success: quit(4); return
		PlayableCharacterPersistence.test_nonpersistent = false
		var host := preload("res://tests/compact_v6_windows_host.gd").new()
		var f: Dictionary = host.native_start(args[0],"dev_normal",null,activated.record)
		if not f.success: quit(5); return
		var crash := CrashRoute.new(args[0],f.service.source,Credit.PROFILE,"dev_normal"); crash.guard = f.service.storage
		f.service.route = crash
		if not f.session.request_next_wave().success: quit(6); return
		crash.cut = "route"
		preload("res://tests/test_historical_vaelis_admission.gd").new().helper._defeat_wave(f.session)
		print("45S_UNEXPECTED_SURVIVAL incremental"); quit(7); return
	var route := CrashRoute.new(args[0],source,Credit.PROFILE,"dev_normal"); route.cut = args[1]
	var result := CharacterPersistenceCoordinator.new(route.guard).activate_compact(route,func(q):return {"confirmed":true,"binding":route.V6.digest(q)})
	print("45S_UNEXPECTED_SURVIVAL "+str(result)); quit(3)
