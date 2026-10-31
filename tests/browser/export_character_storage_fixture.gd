extends SceneTree

func _initialize() -> void:
	var factory := preload("res://tests/test_character_browser_storage.gd").new()
	var fixtures := {}
	for mode: String in ["normal","dev_normal"]:
		var fixture := factory.fixture("prod_browser_fixture" if mode == "normal" else "dev_browser_fixture",mode)
		var documents: Array = [fixture.prepared.document]
		for generation: int in [2,3]:
			fixture.payload.generation = generation
			documents.append(CharacterSaveContract.encode(fixture.payload).text)
		fixtures[mode] = documents
	var file := FileAccess.open("res://tests/browser/character_storage_fixture.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot export isolated browser fixture")
		quit(1)
		return
	file.store_string(JSON.stringify(fixtures,"",true,true)+"\n")
	file.close()
	quit(0)
