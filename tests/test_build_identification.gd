extends RefCounted

const Exporter = preload("res://addons/build_identification/plugin.gd")
var failures: Array[String] = []
var assertions := 0

func run() -> Array[String]:
	var source := {"scripts/example.gd":"source bytes".sha256_text()}
	var value := {"format":"itank_arena_build","version":1,"git_commit":"a".repeat(40),"dirty":true,"source_files":source,"source_sha256":JSON.stringify(source,"",true,true).sha256_text()}
	check(ArenaBuildIdentity.describe(value) == "BUILD aaaaaaa+wip."+String(value.source_sha256).left(12),"Uncommitted builds explicitly identify WIP plus exact source digest.")
	value.dirty = false
	check(ArenaBuildIdentity.describe(value).contains("+src.") and not ArenaBuildIdentity.describe(value).contains("+wip."),"Clean-source label remains distinct.")
	value.source_files["scripts/example.gd"] = "different bytes".sha256_text()
	check(ArenaBuildIdentity.describe(value).contains("UNVERIFIED"),"Inconsistent build/source metadata cannot identify a verified commit.")
	for invalid: Dictionary in [{},{"git_commit":"a".repeat(40)},value.merged({"dirty":"false"},true),value.merged({"version":2},true)]:
		check(ArenaBuildIdentity.describe(invalid).contains("UNVERIFIED"),"Missing/malformed metadata must never pretend to be a clean commit.")
	var collected := Exporter.BuildExport.collect()
	var repository_status: Array = []
	var status_code := OS.execute("git", PackedStringArray(["--no-optional-locks", "-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain=v1", "--untracked-files=all", "--"] + Exporter.BuildExport.INPUTS + [":(exclude)assets/Rare Human Warrior (Boss).doc", ":(exclude,glob)**/*.itankbackup.json"]), repository_status, true)
	check(status_code == 0 and collected.success and collected.git_commit.length() == 40 and collected.dirty == not "".join(repository_status).strip_edges().is_empty(), "Build metadata matches the actual clean or dirty state of export inputs.")
	check(collected.source_files.has("scripts/ui/arena_build_identity.gd") and collected.source_files.has("scripts/ui/arena_combat_controller.gd"),"The exported identity covers its own implementation and actual runtime sources.")
	for protected: String in ["assets/Rare Human Warrior (Boss).doc","character saves/save.json","tmp/owner.txt","builds/web/index.pck"]:
		check(not Exporter.BuildExport.input_path(protected) and not collected.source_files.has(protected),"Protected/generated data is excluded before any content hashing.")
	check(collected == Exporter.BuildExport.collect(),"Repeated metadata collection is deterministic without source changes.")
	var scene := (load("res://scenes/test_arena.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	var snapshot := c._session.get_state_snapshot()
	check(c._build_identity_label.is_visible_in_tree() and c._build_identity_label.text == ArenaBuildIdentity.label() and c._build_identity_label.mouse_filter == Control.MOUSE_FILTER_IGNORE,"READY shows the actual embedded identity without capturing gameplay input.")
	var original_size: Vector2i = scene.get_viewport().size
	for size: Vector2i in [Vector2i(1600,900),Vector2i(1000,650),Vector2i(640,360)]:
		scene.get_viewport().size = size
		var responsive: ArenaResponsiveLayout = scene
		responsive._apply_layout(Vector2(size),Vector2(size)*0.625)
		check(c._build_identity_label.offset_top < c._build_identity_label.offset_bottom and c._build_identity_label.offset_bottom < 0 and c._build_identity_label.anchor_bottom == 1.0 and c._build_identity_label.get_theme_font_size("font_size")*0.625 >= 11.0,"Build identification stays above the bottom edge with readable physical font size.")
	scene.get_viewport().size = original_size
	c._on_dev_tools_pressed()
	check(c._build_identity_label.visible and c._build_transcript_text().contains(ArenaBuildIdentity.transcript_header()),"DEV visibility cannot hide READY identity, and FULL LOG includes identical metadata.")
	check(c._session.get_state_snapshot() == snapshot,"Build presentation and log reads do not change combat, RNG or persistence.")
	c._on_encounter_button_pressed(); c._update_presentation()
	check(not c._build_identity_label.visible,"Compact label is limited to READY.")
	scene.get_parent().remove_child(scene); scene.free()
	print("39W Fix6 build identification: %d assertions." % assertions)
	return failures

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)
