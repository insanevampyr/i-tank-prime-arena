extends RefCounted

const Storage = preload("res://scripts/rewards/character_save_storage.gd")
const Contract = preload("res://scripts/rewards/character_save_contract.gd")
const Fixtures = preload("res://tests/test_task_36d_character_save_contract.gd")
var _failures: Array[String] = []


func run() -> Array[String]:
	_failures.clear()
	var root := OS.get_cache_dir().path_join("itank-storage-tests").path_join("case_%s_%s" % [OS.get_process_id(), Time.get_ticks_usec()])
	var storage := Storage.new(root)
	var payload: Dictionary = Fixtures.new()._fixture()
	payload.character_id = "profile_a"
	_expect(storage.read_profile("profile_a").get("reason") == "save_missing", "Missing save must be explicit.")
	_expect(not storage.write_profile("../outside", payload, "first").get("success", false), "Traversal must be rejected.")
	_expect(storage.write_profile("profile_a", payload, "first").get("success", false), "Initial write must succeed.")
	var loaded := storage.read_profile("profile_a")
	_expect(loaded.get("payload") == payload, "XP, purchases, SHP and provenance must roundtrip unchanged.")
	_expect(loaded.get("document") == Contract.encode(payload).text, "Written document must match canonical serialization exactly.")
	_expect(storage.write_profile("profile_a", payload, "first").get("reason") == "duplicate_transaction", "Duplicate transaction must be rejected durably.")
	var next := payload.duplicate(true)
	next.generation = 2
	var invalid := next.duplicate(true)
	invalid.xp.unspent = -1
	_expect(not storage.write_profile("profile_a", invalid, "invalid").get("success", false), "Malformed candidates must not overwrite valid data.")
	var lock_path := root.path_join("profile_a/writer.lock")
	DirAccess.make_dir_absolute(lock_path)
	_expect(storage.write_profile("profile_a", next, "locked").get("reason") == "writer_locked", "Another local writer or stale lock must block writes.")
	DirAccess.remove_absolute(lock_path)
	_expect(storage.write_profile("profile_a", next, "second").get("success", false), "Sequential generation must succeed.")
	_expect(not storage.write_profile("profile_a", payload, "stale").get("success", false), "Stale generation must be rejected.")
	var other := payload.duplicate(true)
	other.character_id = "profile_b"
	_expect(storage.write_profile("profile_b", other, "first").get("success", false), "Profiles must have independent transaction namespaces.")
	var directory := root.path_join("profile_a")
	_write(directory.path_join("write.pending"), "interrupted")
	var third := next.duplicate(true)
	third.generation = 3
	_expect(storage.write_profile("profile_a", third, "third").get("reason") == "incomplete_write_requires_review", "Incomplete temporary write must block publication.")
	_expect(storage.read_profile("profile_a").get("payload") == next, "Incomplete write must preserve valid active generation.")
	_write(directory.path_join("generation_0000000000000002.json"), "corrupt")
	var recovered := storage.read_profile("profile_a")
	_expect(recovered.get("success", false) and recovered.get("recovered_previous_generation", false) and recovered.get("payload") == payload, "Corrupt current generation must expose valid backup recovery.")
	_expect(not storage.write_profile("profile_a", third, "repair").get("success", false), "Corrupt history must block writes until reviewed.")
	_write(directory.path_join("generation_0000000000000001.json"), "corrupt")
	_expect(storage.read_profile("profile_a").get("reason") == "no_valid_generation", "Corrupt backup must never become blank progression.")
	var future_envelope: Dictionary = JSON.parse_string(Contract.encode(other).text)
	future_envelope.version = 2
	_write(root.path_join("profile_b/generation_0000000000000002.json"), JSON.stringify({"storage_version": 1, "transaction_id": "future", "document": JSON.stringify(future_envelope)}))
	_expect(storage.read_profile("profile_b").get("reason") == "unsupported_format_or_version", "Future character version must prevent downgrade.")
	# Remove only explicitly created files inside this unique cache test root.
	for profile: String in ["profile_a", "profile_b"]:
		var path := root.path_join(profile)
		var dir := DirAccess.open(path)
		if dir != null:
			for name: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(root)
	return _failures


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Isolated fault fixture could not be written.")
		return
	file.store_string(text)
	file.close()


func _expect(value: bool, message: String) -> void:
	if not value: _failures.append(message)
