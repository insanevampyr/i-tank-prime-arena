extends SceneTree
const Bench = preload("res://tests/compact_v6_performance.gd")
const Store = preload("res://tests/compact_v6_backup_store.gd")
const Trace = preload("res://tests/compact_v6_perf_trace.gd")
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or not Store.allowed(args[1]): quit(2); return
	var root: String = args[1]
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",preload("res://scripts/rewards/character_expc_credit.gd").BASELINE).source
	var result := {}
	if args[0] == "build": result = Bench.build(root,source,args[2])
	elif args[0] == "sample":
		var name: String = args[2]
		var request := {"kind":"perf_history" if name.begins_with("chain") else "perf_sample","samples":3 if name.begins_with("chain") else 5,"text":FileAccess.get_file_as_string(root.path_join(name+".json"))}
		if name.begins_with("chain"): request.history = CharacterSaveContract._normalize_json_numbers(JSON.parse_string(FileAccess.get_file_as_string(root.path_join(name+".history"))))
		result = Bench.sample(request,source)
	else: result = workflow(root,source)
	print("45P_RESULT "+JSON.stringify(result,"",true,true))
	quit(0 if result.get("success",false) else 1)
func workflow(root: String, source: CombatCharacterDefinitionResource) -> Dictionary:
	var rows := {}; var text := FileAccess.get_file_as_string(root.path_join("ops1000.json"))
	Trace.reset()
	for i in range(3):
		var s := Store.new(root.path_join("workflow_%d_%d" % [OS.get_process_id(),i]),source,"dev_vaelis_thorn","dev_normal")
		var initial := s.publish(text,null)
		if not initial.success: return initial
		var start := Time.get_ticks_usec(); var candidate := Bench.next(initial.record,"workflow_next",source)
		add(rows,"construct",start); start = Time.get_ticks_usec()
		var encoded := Bench.V6.encode(candidate,source); add(rows,"encode",start)
		start = Time.get_ticks_usec()
		var saved := s.publish(encoded.text,{"sequence":initial.head.sequence,"digest":initial.head.digest});add(rows,"save",start)
		if not saved.success: return saved
		start = Time.get_ticks_usec(); var loaded := s.load_current();add(rows,"load",start)
		if not loaded.success: return loaded
		start = Time.get_ticks_usec(); var exported := s.export_file(s.root.path_join("export.v6backup"));add(rows,"export",start)
		if not exported.success: return exported
		var portable := FileAccess.get_file_as_string(s.root.path_join("export.v6backup"))
		start = Time.get_ticks_usec();var preview := Bench.Portable.decode(portable,source);add(rows,"preview",start)
		if not preview.success: return preview
		var d := Store.new(root.path_join("restore_%d_%d" % [OS.get_process_id(),i]),source,"dev_vaelis_thorn","dev_normal")
		start = Time.get_ticks_usec();var restored := d.restore(portable,null,Bench.Portable.confirmation(portable.sha256_text(),null,d.profile,d.save_namespace));add(rows,"restore",start)
		if not restored.success: return restored
		DirAccess.remove_absolute(d._file(restored.head.digest))
		start = Time.get_ticks_usec();var recovered := d.recover();add(rows,"recovery",start)
		if not recovered.success or recovered.text != encoded.text: return {"success":false,"reason":"workflow_state_changed"}
	var summary := {}
	for key: String in rows: summary[key] = Bench.stats(rows[key])
	var trace := Trace.snapshot(); Trace.enabled = false
	return {"success":true,"kind":"workflow","samples":summary,"trace":trace}
func add(rows: Dictionary, key: String, started: int) -> void:
	if not rows.has(key): rows[key] = []
	rows[key].append(float(Time.get_ticks_usec()-started)/1000.0)
