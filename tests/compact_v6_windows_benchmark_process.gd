extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var result := preload("res://tests/compact_v6_windows_benchmark.gd").new().run()
	print("45S_BENCH "+JSON.stringify(result))
	quit(0 if result.success else 1)
