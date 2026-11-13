class_name ArenaBuildIdentity
extends RefCounted

const PATH := "res://build/export_identity.json"
static var _cached: Dictionary = {}

static func metadata() -> Dictionary:
	if _cached.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cached = value if value is Dictionary else {"verified":false}
	return _cached.duplicate(true)

static func describe(value: Dictionary) -> String:
	if value.get("format") != "itank_arena_build" or value.get("version") != 1 or not value.get("git_commit") is String or not value.get("source_sha256") is String or not value.get("dirty") is bool or not value.get("source_files") is Dictionary:
		return "BUILD UNEXPORTED / UNVERIFIED"
	var commit: String = value.git_commit
	var digest: String = value.source_sha256
	if commit.length() != 40 or not commit.is_valid_hex_number(false) or digest.length() != 64 or not digest.is_valid_hex_number(false) or JSON.stringify(value.source_files,"",true,true).sha256_text() != digest:
		return "BUILD UNEXPORTED / UNVERIFIED"
	return "BUILD %s%s%s" % [commit.left(7),"+wip." if value.dirty else "+src.",digest.left(12)]

static func label() -> String: return describe(metadata())

static func transcript_header() -> String:
	var value := metadata()
	return "%s\nBuild commit: %s\nBuild source SHA-256: %s\nExport UTC: %s" % [describe(value),value.get("git_commit","unverified"),value.get("source_sha256","unverified"),value.get("exported_utc","unexported")]
