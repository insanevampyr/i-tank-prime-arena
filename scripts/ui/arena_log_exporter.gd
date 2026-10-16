class_name ArenaLogExporter
extends RefCounted

const WEB_COPY_STATUS_KEY := "__itankArenaCopyStatus"


static func request_copy(text: String) -> Dictionary:
	if text.is_empty():
		return {"success": false, "reason": "empty_transcript"}
	if OS.has_feature("web"):
		var escaped_text := JSON.stringify(text)
		var script := (
			"window.%s='pending';" % WEB_COPY_STATUS_KEY
			+ "if(navigator.clipboard&&navigator.clipboard.writeText){"
			+ "navigator.clipboard.writeText(%s).then(()=>window.%s='success').catch(()=>window.%s='denied');"
			% [escaped_text, WEB_COPY_STATUS_KEY, WEB_COPY_STATUS_KEY]
			+ "}else{window.%s='unavailable';}" % WEB_COPY_STATUS_KEY
		)
		JavaScriptBridge.eval(script, true)
		return {"success": true, "pending": true, "reason": "web_clipboard_requested"}
	DisplayServer.clipboard_set(text)
	return {"success": true, "pending": false, "reason": "desktop_clipboard_set"}


static func poll_web_copy_status() -> String:
	if not OS.has_feature("web"):
		return "not_web"
	var value: Variant = JavaScriptBridge.eval("window.%s||'unknown'" % WEB_COPY_STATUS_KEY, true)
	return String(value)


static func save_text(text: String, seed_value: int, event_count: int) -> Dictionary:
	if text.is_empty():
		return {"success": false, "reason": "empty_transcript"}
	var filename := "itank-arena-seed-%d-events-%d.txt" % [seed_value, event_count]
	if OS.has_feature("web"):
		# The explicit button press supplies the browser user gesture. A Blob URL is
		# used instead of assuming every Web shell exposes download_buffer equally.
		var base64_text := Marshalls.raw_to_base64(text.to_utf8_buffer())
		var script := (
			"(()=>{const b=atob(%s);const u=new Uint8Array(b.length);" % JSON.stringify(base64_text)
			+ "for(let i=0;i<b.length;i++)u[i]=b.charCodeAt(i);"
			+ "const o=URL.createObjectURL(new Blob([u],{type:'text/plain;charset=utf-8'}));"
			+ "const a=document.createElement('a');a.href=o;a.download=%s;document.body.appendChild(a);" % JSON.stringify(filename)
			+ "a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(o),1000);})();"
		)
		JavaScriptBridge.eval(script, true)
		return {"success": true, "reason": "browser_download_requested", "filename": filename}
	var directory := "user://encounter_logs"
	var absolute_directory := ProjectSettings.globalize_path(directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return {"success": false, "reason": "log_directory_unavailable", "error": directory_error}
	var path := "%s/%s" % [directory, filename]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "log_file_unavailable", "error": FileAccess.get_open_error()}
	file.store_string(text)
	file.close()
	return {
		"success": true,
		"reason": "desktop_log_saved",
		"filename": filename,
		"path": ProjectSettings.globalize_path(path),
	}
