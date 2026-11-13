@tool
extends EditorPlugin

class BuildExport extends EditorExportPlugin:
	const INPUTS := ["project.godot","export_presets.cfg","icon.svg","scripts","scenes","data","assets","addons"]
	var exported := {}

	func _get_name() -> String: return "ArenaBuildIdentification"

	static func input_path(path: String) -> bool:
		for prefix: String in ["tmp/","character saves/","builds/",".godot/",".git/","tests/","docs/",".github/"]:
			if path.begins_with(prefix): return false
		return path != "assets/Rare Human Warrior (Boss).doc" and not path.ends_with(".itankbackup.json")

	static func git(arguments: Array) -> Dictionary:
		var output: Array = []
		var code := OS.execute("git",PackedStringArray(["--no-optional-locks","-C",ProjectSettings.globalize_path("res://")]+arguments),output,true)
		return {"success":code == 0,"text":"".join(output)}

	static func collect() -> Dictionary:
		var head := git(["rev-parse","HEAD"])
		var files := git(["-c","core.quotepath=false","ls-files","--cached","--others","--exclude-standard","--"]+INPUTS)
		var status := git(["status","--porcelain=v1","--untracked-files=all","--"]+INPUTS+[":(exclude)assets/Rare Human Warrior (Boss).doc",":(exclude,glob)**/*.itankbackup.json"])
		if not head.success or not files.success or not status.success:
			return {"success":false,"reason":"Git/source identity unavailable; export cannot be identified."}
		var manifest := {}
		for line: String in files.text.split("\n",false):
			var path := line.trim_suffix("\r")
			if path.begins_with('"'):
				var decoded: Variant = JSON.parse_string(path)
				if not decoded is String: return {"success":false,"reason":"Unsupported export input filename."}
				path = decoded
			if not input_path(path): continue
			var absolute := ProjectSettings.globalize_path("res://"+path)
			if not FileAccess.file_exists(absolute):
				manifest[path] = "deleted"
				continue
			var digest := FileAccess.get_sha256(absolute)
			if digest.is_empty(): return {"success":false,"reason":"Cannot fingerprint export input: "+path}
			manifest[path] = digest
		return {"success":true,"format":"itank_arena_build","version":1,"git_commit":head.text.strip_edges(),"dirty":not status.text.strip_edges().is_empty(),"source_sha256":JSON.stringify(manifest,"",true,true).sha256_text(),"source_files":manifest}

	func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
		exported = collect()
		if not exported.success:
			get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR,"Build identification",exported.reason)
			return
		exported.erase("success")
		exported["exported_utc"] = Time.get_datetime_string_from_system(true)+"Z"
		exported["debug"] = is_debug
		exported["features"] = Array(features)
		exported["godot"] = Engine.get_version_info().get("string","")
		add_file("res://build/export_identity.json",JSON.stringify(exported,"",true,true).to_utf8_buffer(),false)
		print("BUILD_EXPORT: ",exported.git_commit.left(7),"+wip." if exported.dirty else "+src.",exported.source_sha256.left(12))

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		# Editor-only tooling is never loaded by the exported game.
		if path.begins_with("res://addons/build_identification/"): skip()

	func _export_end() -> void:
		if not exported.has("source_sha256"): return
		var after := collect()
		if not after.success or after.git_commit != exported.git_commit or after.source_sha256 != exported.source_sha256 or after.dirty != exported.dirty:
			get_export_platform().add_message(EditorExportPlatform.EXPORT_MESSAGE_ERROR,"Build identification","Working tree changed during export; discard this artifact and export again.")

var build_export := BuildExport.new()

func _enter_tree() -> void: add_export_plugin(build_export)
func _exit_tree() -> void: remove_export_plugin(build_export)
