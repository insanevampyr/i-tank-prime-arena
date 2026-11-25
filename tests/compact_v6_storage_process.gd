extends SceneTree
const Fixtures = preload("res://tests/compact_v6_storage_fixtures.gd")
const Disk = preload("res://tests/compact_v6_disposable_store.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or not Disk.allowed(args[1]): quit(2); return
	var result := {}
	if args[0] == "fixtures": result = Fixtures.build(args[1])
	elif args[0] == "ids": result = Fixtures.make_thousand(args[1])
	else:
		var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",Fixtures.Credit.BASELINE).source
		var adapter: GDScript = preload("res://tests/compact_v6_backup_store.gd") if args[0].ends_with("_portable") else Disk
		var store: RefCounted = adapter.new(args[1],source,"dev_vaelis_thorn","dev_normal")
		if args[0] in ["load","load_portable"]: result = store.load_current()
		elif args[0] in ["orphan","orphan_portable"] and args.size() == 3 and Disk.allowed(args[2]) and args[2].replace("\\","/").simplify_path().begins_with(args[1].replace("\\","/").simplify_path()+"/"):
			var text := FileAccess.get_file_as_string(args[2])
			var current: Dictionary = store.load_current()
			result = store.publish(text,{"sequence":current.head.sequence,"digest":current.head.digest},"orphan_writer")
	var compact := result.duplicate()
	compact.erase("record"); compact.erase("text")
	print("45M_PROCESS "+JSON.stringify(compact))
	quit(0 if result.get("success",false) or args[0] in ["orphan","orphan_portable"] else 1)
