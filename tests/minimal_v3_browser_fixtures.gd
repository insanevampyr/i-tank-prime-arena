extends SceneTree
const H = preload("res://tests/test_minimal_v3_transactions.gd")
const V3 = H.Codec
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size()!=1 or not a[0].replace("\\","/").begins_with(OS.get_environment("TEMP").replace("\\","/").path_join("arena46j-")): quit(2); return
	var out := a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var root := OS.get_cache_dir().path_join("itank-storage-tests/minimal46c2_46j_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	PlayableCharacterPersistence.test_nonpersistent = false
	for mode: String in ["normal","dev_normal"]:
		var q := H.Q.new(); var f := q.start(CharacterSaveStorage.new(root.path_join(mode)),mode,1 if mode=="normal" else 10)
		if not f.success: print(f); quit(3); return
		var g := H.G.new(); var body: Dictionary = g.pack(f.service.records.back())
		var encoded := V3.encode(body,f.service.source,body.current.character_id,mode)
		if not encoded.success: print(encoded); quit(4); return
		write(out.path_join(mode+".json"),encoded.text)
		# Match the real verified-reload admission boundary. Fresh creation has
		# an additional creation event and is not the same command history.
		f = q.start(f.service.storage,mode,null,f.service.records.back(),true)
		if not f.success: print(f); quit(11); return
		var h := H.new(); h.root = root
		var c := h.admit(f.service.compact_parent,f.service.source,mode)
		if c._minimal_owner == null: print(h.failures); quit(12); return
		c.simulate_minimal_automatic_checkpoints(true)
		var p := H.P.new(); var control := H.P.new()
		p._defeat_wave(f.session); f.session.collect_all_ground_loot()
		control._defeat_wave(c._minimal_owner._session); c._minimal_owner._session.collect_all_ground_loot()
		h.compare(c,f,"native_original_vs_owned_"+mode)
		if not h.failures.is_empty() or not q.failures.is_empty(): print(h.failures); print(q.failures); quit(13); return
		# Original gameplay/evidence are independently compared above; recent
		# journal bindings use the genuine owned-command capture, not old legacy
		# proposal fingerprints. Browser must match these exact bytes as well.
		var expected: Dictionary = h.body(c)
		write(out.path_join(mode+"_oracle.json"),JSON.stringify({"body":expected,"simulation":f.session.get_state_snapshot(),"source_oracle_assertions":h.assertions},"",true,true))
		c.close_minimal_prototype()
	var history := H.H.new(); history.root=root.path_join("historical")
	var f: Dictionary = history.make_history("dev_normal",V3.Credit.BASELINE,2,"source")
	if not f.get("success",false): print(f); quit(5); return
	var converted := H.Convert.convert(f.records,"dev_normal")
	if not converted.success or not converted.comparison.success: print(converted); quit(6); return
	var source: CombatCharacterDefinitionResource = PlayableCharacterAdmission.prepare_starter(&"vaelis_thorn","dev_normal",V3.Credit.BASELINE).source
	var body: Dictionary = H.G.new().pack(converted.record)
	var encoded := V3.encode(body,source,V3.Credit.PROFILE,"dev_normal")
	if not encoded.success: print(encoded); quit(7); return
	write(out.path_join("historical.json"),encoded.text)
	var w := H.W.new(); var raw := w.current_from_cache("compact45s_bench_25204_2215533/inventory")
	if raw.is_empty(): quit(8); return
	source = w.trusted(raw).source
	var decoded := V3.V6.decode(raw,source)
	if not decoded.success: print(decoded); quit(9); return
	body=H.G.new().pack(decoded.record);encoded=V3.encode(body,source,V3.Credit.PROFILE,"dev_normal")
	if not encoded.success: print(encoded); quit(10); return
	write(out.path_join("stress1005.json"),encoded.text)
	print("46J_FIXTURES_SOURCE_VERIFIED"); quit(0)
func write(path: String,text: String) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE); f.store_string(text); f.close()
