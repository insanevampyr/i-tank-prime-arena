extends Node
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var probe := preload("res://tests/disposable_v3_playable_probe.gd").new()
	add_child(probe)
	var result: Dictionary = await probe.run()
	result["native_live"] = OS.get_static_memory_usage()
	result["native_peak"] = OS.get_static_memory_peak_usage()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.arena46kResult="+JSON.stringify(result,"",true,true),true)
	else:
		var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"",true,true));file.close()
	print("46K_RELEASE_RESULT ",JSON.stringify(result))
	if not OS.has_feature("web"):get_tree().quit(0 if result.success else 1)
