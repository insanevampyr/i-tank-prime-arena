extends SceneTree

# Standalone diagnostic, not a save adapter. Never opens a character record.
# Reproduces the actual Windows replacement prerequisite before 46I routing.
var assertions := 0
var failures: Array[String] = []
var observations: Dictionary = {}
var test_root := ""

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func write_exact(name: String, text: String) -> bool:
	var path := test_root.path_join(name)
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null: return false
	if not f.store_string(text): f.close(); return false
	f.flush()
	var error := f.get_error()
	f.close()
	return error == OK and FileAccess.get_file_as_bytes(path) == text.to_utf8_buffer()

func _initialize() -> void:
	if OS.get_name() != "Windows" or OS.has_feature("web"):
		print("46I_PRIMITIVE_UNSUPPORTED_PLATFORM"); quit(2); return
	test_root = OS.get_cache_dir().path_join("itank-storage-tests/minimal46i_primitive_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	check(DirAccess.make_dir_recursive_absolute(test_root) == OK,"Create only unique disposable OS-cache directory")
	if not failures.is_empty(): finish(); return
	var head := test_root.path_join("head.json")
	var pending := test_root.path_join("head.pending")
	check(write_exact("head.json","old acknowledged head"),"Initial acknowledged bytes independently read back")
	check(write_exact("head.pending","new staged head"),"Staged bytes independently read back")
	var started := Time.get_ticks_usec()
	var ordinary := DirAccess.rename_absolute(pending,head)
	observations.ordinary_rename_error = ordinary
	observations.ordinary_rename_us = Time.get_ticks_usec()-started
	check(ordinary == OK and FileAccess.get_file_as_string(head) == "new staged head","Ordinary replacement succeeds when unblocked")

	check(write_exact("head.json","old acknowledged head"),"Reset only disposable acknowledgement sentinel")
	check(write_exact("head.pending","new staged head"),"Create independently readable staged replacement")
	var held := FileAccess.open(pending,FileAccess.READ)
	check(held != null,"Hold actual staged source open using Windows FileAccess")
	if held != null:
		started = Time.get_ticks_usec()
		var blocked := DirAccess.rename_absolute(pending,head)
		observations.blocked_source_rename_error = blocked
		observations.blocked_source_rename_us = Time.get_ticks_usec()-started
		observations.head_exists_after_blocked_rename = FileAccess.file_exists(head)
		observations.source_exists_after_blocked_rename = FileAccess.file_exists(pending)
		check(blocked != OK,"Locked-source move genuinely fails")
		check(not FileAccess.file_exists(head),"CONFIRMED SAFETY BLOCKER: failed replacement deleted acknowledged destination")
		check(FileAccess.get_file_as_string(pending) == "new staged head","Failed replacement leaves staged bytes, not committed authority")
		held.close()

	check(write_exact("head.json","old acknowledged head"),"Prepare missing-source error sentinel")
	var missing := test_root.path_join("never_created.pending")
	var missing_error := DirAccess.rename_absolute(missing,head)
	observations.missing_source_rename_error = missing_error
	observations.head_exists_after_missing_source = FileAccess.file_exists(head)
	check(missing_error != OK and not FileAccess.file_exists(head),"CONFIRMED: missing-source replacement also deletes destination before failing")
	observations.gdscript_backup_save_exposed = ClassDB.class_has_method(&"FileAccess",&"set_backup_save")
	check(not observations.gdscript_backup_save_exposed,"Internal engine safe-save switch is not a script API")

	var guard := CharacterSaveStorage.new(test_root.path_join("lock_probe"))
	var first := guard.acquire_writer("disposable_46i")
	check(first.success,"Original exclusive writer acquired in isolated directory")
	if first.success:
		var contender := CharacterSaveStorage.new(test_root.path_join("lock_probe"))
		check(not contender.acquire_writer("disposable_46i").success,"Original lock rejects competing instance")
		check(not contender.release_writer("disposable_46i",first.owner).success,"Copied owner token is not process-local ownership")
		check(guard.release_writer("disposable_46i",first.owner).success,"Actual owner releases its lock")
		var abandoned := guard.acquire_writer("stale_46i")
		check(abandoned.success,"Create disposable retained lock")
		if abandoned.success:
			guard = null
			check(not contender.acquire_writer("stale_46i").success,"Unknown stale lock is retained and fails closed; never stolen")
	finish()

func finish() -> void:
	observations.engine = Engine.get_version_info()
	observations.root = test_root
	observations.scope = "Native Windows primitive diagnostics only, not v3 publication or durable-save latency"
	print("46I_PRIMITIVE "+JSON.stringify(observations))
	print("46I primitive diagnostics: %d assertions; failures %s" % [assertions,str(failures)])
	quit(0 if failures.is_empty() else 1)
