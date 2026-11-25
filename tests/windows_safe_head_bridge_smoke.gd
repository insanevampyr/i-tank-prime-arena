extends SceneTree

# Direct native-executable smoke only, never attached to playable persistence.
var assertions := 0
var failures: Array[String] = []

func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok: failures.append(text)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_name() != "Windows" or args.size() != 2: quit(2); return
	var exe := args[0].replace("\\","/").simplify_path()
	var allowed := OS.get_environment("TEMP").replace("\\","/").path_join("arena46i1_")
	if not exe.begins_with(allowed) or exe.get_file() != "safe_head_replace.exe" or FileAccess.get_sha256(exe) != args[1]:
		quit(3); return
	var directory := OS.get_cache_dir().path_join("itank-storage-tests/minimal46i1_godot_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	check(DirAccess.make_dir_recursive_absolute(directory) == OK,"Only dedicated disposable sentinel directory")
	write(directory,"stage.bin","OLD")
	invoke(exe,directory,"first")
	check(FileAccess.get_file_as_string(directory.path_join("head.bin")) == "OLD","First head is exact")
	write(directory,"expected.bin","OLD"); write(directory,"stage.bin","NEW")
	invoke(exe,directory,"replace")
	check(FileAccess.get_file_as_string(directory.path_join("head.bin")) == "NEW","Replaced head is exact")
	write(directory,"verify.bin","NEW")
	invoke(exe,directory,"verify")
	print("46I1_GODOT_BRIDGE: %d assertions; failures %s" % [assertions,str(failures)])
	quit(0 if failures.is_empty() else 1)

func write(directory: String, name: String, value: String) -> void:
	var file := FileAccess.open(directory.path_join(name),FileAccess.WRITE)
	if file == null: failures.append("Disposable fixture write failed"); return
	file.store_string(value); file.close()

func invoke(exe: String, directory: String, mode: String) -> void:
	var output: Array = []
	var code := OS.execute(exe,[mode,directory,"none"],output,true)
	var value: Variant = JSON.parse_string(str(output[0])) if output.size() == 1 else null
	check(code == 0 and value is Dictionary and value.get("state") == ("exact" if mode == "verify" else "published_verified"),"Direct OS.execute without shell: "+mode+": "+str(output))
