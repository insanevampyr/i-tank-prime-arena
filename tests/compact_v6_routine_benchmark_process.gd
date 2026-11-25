extends SceneTree
func _initialize() -> void: call_deferred("execute")
func execute() -> void:
	var result: Dictionary = load("res://tests/compact_v6_routine_benchmark.gd").new().run_bench()
	print("45U_BENCH "+JSON.stringify(result))
	quit(0 if result.success else 1)
