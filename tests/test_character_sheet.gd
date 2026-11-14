extends RefCounted

const Sheet = preload("res://scripts/ui/character_sheet_projection.gd")
const Playable = preload("res://tests/test_playable_vaelis_persistence.gd")
const Fixture = preload("res://scripts/combat/prime_v3_vertical_slice_fixture.gd")
var failures: Array[String] = []
var assertions := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message)

func stat(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if row.id == id: return row
	return {}

func session() -> ArenaCombatSession:
	var result := ArenaCombatSession.new(42,null,Fixture.ENCOUNTER_WAVE_ONE_GOBLINS,Fixture.PLAYER_CHARACTER_VAELIS)
	check(result.initialize_wave_one_goblins(Vector2i(8_000_000,5_000_000),Vector2i(12_000_000,5_000_000),false).success,"Initialize disposable actual wave fixture.")
	result.configure_reward_mode("normal")
	return result

func run() -> Array[String]:
	projection()
	presentation_corrections()
	window()
	layout()
	check(replay(true) == replay(false),"Inspection must preserve actual combat outcomes, RNG, event ordering and authoritative snapshot.")
	print("42A character sheet: %d assertions." % assertions)
	return failures

func projection() -> void:
	var s := session()
	var actor := s.simulation.get_actor_definition(&"player")
	var state := s.get_actor_state(&"player")
	var source := actor.source_character_definition.to_dictionary()
	s._reward_ledger.earned_xp = 6000 # Disposable fixture funds; no player data or publication.
	var purchase := s.request_character_advancement(&"attribute",&"dex","sheet_dex",{"allocation":"dt","expected_current_value":9,"expected_cost":3000})
	check(purchase.success,"Existing READY transaction supplies purchased DEX fixture.")
	state.current_hpc = 7
	state.resources.mana = 5
	var before := s.get_state_snapshot()
	var ledger := s.get_reward_state()
	var model := Sheet.capture(s)
	check(model.success and model.primaries.size() == 10,"All ten primary attributes are present.")
	check(stat(model.primaries,"DEX") == {"id":"DEX","name":"Dexterity","original":9,"permanent":10,"effective":10,"group":"DEX"},"DEX original/permanent/effective preserve the accepted 9->10 progression.")
	check(stat(model.derived,"ACC").permanent == 9 and stat(model.derived,"ACC").effective == 9,"DEX 10 retains exact ACC 9.")
	check(stat(model.derived,"DT").permanent == actor.source_character_definition.combat_stats.dt+1,"The explicitly selected DT point is displayed.")
	check(stat(model.derived,"DP").permanent == actor.source_character_definition.combat_stats.dp,"DP allocation is unchanged.")
	check(stat(model.derived,"DT").effective == s.simulation.get_effective_actor_combat_stat(&"player","dt"),"Equipment-adjusted Dodge comes from live combat, never a UI formula.")
	check(stat(model.derived,"MSL").effective == null,"Missing live derived values are not filled from the chart.")
	check(stat(model.resources,"HPC").current == 7 and stat(model.resources,"MANA").current == 5,"Current resources are not confused with maxima.")
	check(model.purchases == ledger.purchase_records,"Exact advancement receipts are projected without reinterpretation.")
	check(model.resistances.size() == 2 and stat(model.resistances,"TB").name == "Tolerance Bonus","SR/TB remain independent and correctly named.")
	check(model.skills.any(func(row): return row.title == "Balance" and row.status == "VERIFIED CHECK"),"Verified Balance data is distinguished from unintegrated Skills.")
	check(model.skills.any(func(row): return row.title == "Languages" and row.status == "RECORDED PROFICIENCY"),"Source-linked languages are included.")
	check(model.specials.any(func(row): return row.title == "Force Bolt") and model.specials.any(func(row): return row.title == "Force Shield"),"Known Specials are sourced from character knowledge.")
	check(not model.specials.any(func(row): return row.title == "Resurrect"),"Catalog membership cannot invent known Specials.")
	check(model.equipment.size() == 2 and model.equipment.all(func(row): return row.status == "EQUIPPED | CARRIED 0"),"Vaelis's two equipped weapons remain visible with zero loose carried copies; no armor or shield is invented.")
	check(Sheet.capture(s) == model and s.get_state_snapshot() == before and s.get_reward_state() == ledger and actor.source_character_definition.to_dictionary() == source,"Repeated projection is deterministic, read-only and consumes no events, RNG, resources or receipts.")
	state.timed_stat_effects["sheet_dex"] = {"stat_modifiers":{"dex":2},"source_ref":"TEST ONLY verified DEX fixture","source_action_instance_id":"sheet_effect","expires_at_us":10000000}
	model = Sheet.capture(s)
	check(stat(model.primaries,"DEX").effective == 12 and stat(model.primaries,"DEX").permanent == 10,"Source-qualified temporary DEX is isolated from permanent progression.")
	check(stat(model.derived,"ACC").effective == s.simulation.get_effective_actor_combat_stat(&"player","acc"),"Temporary ACC is read through the authoritative getter.")
	state.timed_stat_effects.clear()
	check(stat(Sheet.capture(s).primaries,"DEX").effective == 10,"Expiry returns to the purchased value without losing allocation points.")
	check(s.request_character_advancement(&"attribute",&"dex","sheet_dex_second",{"allocation":"dp","expected_current_value":10,"expected_cost":3000}).success,"The other explicit allocation choice uses the same accepted transaction.")
	model = Sheet.capture(s)
	check(stat(model.primaries,"DEX").original == 9 and stat(model.primaries,"DEX").permanent == 11 and stat(model.derived,"ACC").effective == 10,"The sheet follows the exact next ACC boundary at DEX 11 without overwriting original identity.")
	var guard := ArenaCombatSession.new(42)
	check(guard.initialize(Vector2i(8_000_000,5_000_000),Vector2i(12_000_000,5_000_000),false).success,"Initialize authored Guard fixture.")
	var guard_actor := guard.simulation.get_actor_definition(&"player")
	var guard_before := guard.get_state_snapshot()
	var unknown := Sheet.capture(guard)
	check(unknown.equipment.any(func(row): return str(row.details).contains("TAL by damage type")),"Guard's actual location-specific armor protection is presented.")
	check(unknown.equipment.any(func(row): return str(row.details).contains("SHP")),"Guard's actual shield remaining SHP is supplied by the live defense profile.")
	check(stat(unknown.derived,"DT").permanent != stat(unknown.derived,"DT").effective,"Guard's actual armor penalty is separate from permanent allocation.")
	check(unknown.success and not unknown.skills.any(func(row): return row.title == "Balance" and row.status == "VERIFIED CHECK"),"Unknown actor proficiency must not be labeled explicitly untrained.")
	check(guard.get_state_snapshot() == guard_before,"Authored NPC/fixture exceptions are preserved.")
	guard_actor.attributes.erase("wis")
	check(stat(Sheet.capture(guard).primaries,"WIS").permanent == null,"Incomplete primary data remains unavailable.")
	check(not Sheet.capture(null).success,"Missing session fails closed.")

func equipment_button(sheet: CharacterSheetWindow, entry_id: String) -> Button:
	for i in range(sheet.model.equipment.size()):
		if sheet.model.equipment[i].get("entry_id") == entry_id:
			return sheet.content.find_child("Entry%s" % i,true,false) as Button
	return null

func presentation_corrections() -> void:
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Presentation corrections use a nonpersistent Vaelis fixture.")
	var s := c._session
	var actor := s.simulation.get_actor_definition(&"player")
	var state := s.get_actor_state(&"player")
	state.inventory_quantities["prime_v3_hades_follower_short_sword"] = 1
	state.inventory_quantities["prime_v3_gold"] = 455 # Prior balance in this disposable fixture.
	var created := s.simulation.create_ground_loot_item("sheet_gold_drop",{"definition_id":"prime_v3_gold","display_name":"100 Gold","item_kind":"currency","quantity":100},state.position_microfeet,&"player",s.simulation.get_resolved_events()[0].event_id)
	check(created.success and s.simulation.collect_ground_loot_item(&"player","sheet_gold_drop","sheet_gold_pickup").success,"An ordinary 100-Gold pickup extends the fixture's prior balance.")
	var inventory := s.get_player_inventory_entries()
	check(inventory.any(func(row): return row.definition_id == "prime_v3_gold" and row.display_name == "100 Gold" and row.quantity == 555),"Regression fixture reproduces a drop caption beside an aggregate quantity.")
	var before := s.get_state_snapshot()
	var rewards := s.get_reward_state()
	var source := actor.source_character_definition.to_dictionary()
	c.open_character_sheet()
	var sheet := c._character_sheet
	sheet.select_tab(3)
	var gold: Dictionary = sheet.model.equipment.filter(func(row): return row.get("entry_id") == "prime_v3_gold").front() if sheet.model.equipment.any(func(row): return row.get("entry_id") == "prime_v3_gold") else {}
	check(gold.get("title") == "Gold" and gold.get("status") == "BALANCE | 555 GOLD","Gold uses the authoritative aggregate, never the individual drop caption.")
	var loose := -1
	var equipped := -1
	for i in range(sheet.model.equipment.size()):
		var row: Dictionary = sheet.model.equipment[i]
		if row.title != "Short Sword": continue
		if String(row.status).begins_with("EQUIPPED"): equipped = i
		else: loose = i
	check(loose >= 0 and equipped >= 0,"Actual catalog equipment includes two distinct items named Short Sword.")
	if loose >= 0 and equipped >= 0:
		var button := sheet.content.find_child("Entry%s" % equipped,true,false) as Button
		button.button_pressed = true
		sheet.select_tab(0)
		sheet.select_tab(3)
		var loose_button := sheet.content.find_child("Entry%s" % loose,true,false) as Button
		var equipped_button := sheet.content.find_child("Entry%s" % equipped,true,false) as Button
		check(equipped_button.button_pressed and not loose_button.button_pressed,"Returning to Equipment preserves only the individually expanded sword.")
		loose_button.button_pressed = true
		equipped_button.button_pressed = false
		sheet.select_tab(1)
		sheet.select_tab(3)
		loose_button = sheet.content.find_child("Entry%s" % loose,true,false) as Button
		equipped_button = sheet.content.find_child("Entry%s" % equipped,true,false) as Button
		check(loose_button.button_pressed and not equipped_button.button_pressed,"Collapsing an equipped item does not collapse the identically named inventory item.")
		check(sheet.model.equipment[loose].get("entry_id") == "prime_v3_hades_follower_short_sword" and sheet.model.equipment[equipped].get("entry_id") == "prime_v3_short_sword","Equipment entry identities come from existing unique definition IDs.")
		if sheet.model.equipment[loose].has("entry_id"):
			sheet.model.equipment[loose].title = "Renamed display label"
			sheet.model.equipment.reverse()
			sheet.select_tab(0)
			sheet.select_tab(3)
			check(equipment_button(sheet,"prime_v3_hades_follower_short_sword").button_pressed and not equipment_button(sheet,"prime_v3_short_sword").button_pressed,"Presentation renaming/reordering cannot reassign expansion state.")
			sheet.refresh(true)
			check(equipment_button(sheet,"prime_v3_hades_follower_short_sword").button_pressed and not equipment_button(sheet,"prime_v3_short_sword").button_pressed,"Authoritative refresh retains the independent expansion choices.")
	check(s.get_state_snapshot() == before and s.get_reward_state() == rewards and actor.source_character_definition.to_dictionary() == source,"Presentation corrections leave RNG, events, XP, purchases, equipment, inventory and source identity unchanged.")
	check(s._playable_persistence == null,"No save, backup or browser storage is opened by the corrections fixture.")
	sheet.close_sheet()
	state.inventory_quantities["prime_v3_gold"] = 0
	var zero_gold: Array = Sheet.capture(s).equipment.filter(func(row): return row.get("entry_id") == "prime_v3_gold")
	check(zero_gold.size() == 1 and zero_gold[0].status == "BALANCE | 0 GOLD","An explicit zero aggregate remains zero without using the prior loot caption.")
	var valid := Sheet.capture(s)
	check(valid.subtitle.ends_with("Level 1") and valid.profile[0].rows.any(func(row): return row[0] == "Level" and row[1] == 1),"Valid levels retain their original values in the header and Profile tab.")
	helper._free(scene)
	var guard := ArenaCombatSession.new(42)
	guard.initialize(Vector2i(8_000_000,5_000_000),Vector2i(12_000_000,5_000_000),false)
	var sentinel := guard.get_state_snapshot()
	var unknown := Sheet.capture(guard)
	check(unknown.subtitle.ends_with("Level not available") and unknown.profile[0].rows.any(func(row): return row[0] == "Level" and row[1] == null),"An unavailable level is represented consistently without exposing Level -1.")
	check(guard.simulation.get_actor_definition(&"player").level == -1 and guard.get_state_snapshot() == sentinel,"The internal level sentinel and all authoritative state are preserved.")

func window() -> void:
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	check(c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS).success,"Actual playable scene admits only a nonpersistent fixture.")
	c._on_inventory_toggle_pressed()
	var action: Button = c._rewards_panel.find_child("ViewCharacterSheet",true,false)
	check(action != null and action.visible and scene.get_node("HUD/UI/CombatInventory").text == "CHARACTER MENU","Character management exposes the renamed menu and sheet action.")
	var before := c._session.get_state_snapshot()
	var rewards := c._session.get_reward_state()
	var touch_visible := c._touch_controls.visible
	action.pressed.emit()
	var sheet := c._character_sheet
	check(sheet.visible and sheet.tab_buttons.size() == 5 and sheet.close_button.has_focus(),"Window opens with five tabs and safe GUI focus.")
	check(not c._touch_controls.visible and c._touch_controls.get_movement_vector() == Vector2.ZERO,"Opening clears and hides touch movement to prevent input leakage.")
	var player = scene.get_node("PlaceholderPlayer")
	check(player.resolve_keyboard_direction(Vector2.RIGHT,Vector2.DOWN,c.get_viewport().gui_get_focus_owner() != null) == Vector2.ZERO and not player.resolve_keyboard_run(true,c.get_viewport().gui_get_focus_owner() != null),"Sheet focus blocks the actual player's keyboard movement and run intent.")
	for i in range(5):
		sheet.tab_buttons[i].pressed.emit()
		check(sheet.active_tab == i and sheet.content.get_child_count() > 0,"Tab %s renders reusable content." % i)
	sheet.show_help("DEX")
	check(sheet.help_layer.visible and not sheet.help_details.visible and sheet.help_quick.text.contains("Dexterity"),"Click/tap pins quick help without forcing details.")
	sheet.help_panel.find_children("*","Button",true,false).back().pressed.emit()
	check(sheet.help_details.visible and sheet.help_details.text.contains("DEX 9 and 10"),"View Details opens source-backed DEX explanation.")
	sheet.handle_escape()
	check(not sheet.help_layer.visible and sheet.visible,"Escape first dismisses help while retaining the sheet.")
	sheet.show_help("TB")
	var click := InputEventMouseButton.new()
	click.pressed = true
	sheet.help_layer.get_child(0).gui_input.emit(click)
	check(not sheet.help_layer.visible,"Outside click dismisses pinned help.")
	for i in range(50):
		sheet.move_focus(i >= 25)
		check(sheet.is_ancestor_of(c.get_viewport().gui_get_focus_owner()),"Keyboard focus cannot escape to underlying gameplay/management controls.")
	for key: Key in [KEY_SPACE,KEY_R,KEY_Q,KEY_TAB,KEY_F4]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		c._input(event)
		c._unhandled_input(event)
	check(c._session.get_state_snapshot() == before and c._session.get_reward_state() == rewards and c._attack_input_is_blocked_by_ui(),"Sheet input cannot attack, reset, cast, cycle targets, spend or publish.")
	check(c._session._playable_persistence == null,"This UI fixture never accesses owner profiles.")
	sheet.close_button.pressed.emit()
	check(not sheet.visible and c._touch_controls.visible == touch_visible,"Visible X closes the window and restores prior touch-control visibility.")
	c.open_character_sheet()
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	c._input(escape)
	check(not sheet.visible,"Controller Escape closes the window.")
	check(c._backup_actions != null and c._advancement_option != null and c._inventory_option != null,"Existing save/load, equipment and advancement controls remain installed.")
	helper._free(scene)

func layout() -> void:
	for display: Vector2 in [Vector2(1280,720),Vector2(915,412),Vector2(800,360)]:
		for dev: bool in [false,true]:
			var view := Vector2(1280,720)
			var metrics := ArenaResponsiveLayout.calculate_layout(view,display,{},dev)
			var menu: Rect2 = metrics.character_menu_rect
			check(not menu.intersects(metrics.attack_readiness_rect) and not menu.intersects(metrics.run_readiness_rect),"CHARACTER MENU avoids ATTACK/RUN at %s, DEV %s." % [display,dev])
			check(Rect2(Vector2.ZERO,view).encloses(menu),"Menu remains inside desktop/mobile landscape viewport.")

func replay(inspect: bool) -> Dictionary:
	var helper := Playable.new()
	var scene := helper._scene()
	var c: ArenaCombatController = scene.get_node("CombatController")
	c.set_physics_process(false)
	c.select_player_character_for_testing(Fixture.PLAYER_CHARACTER_VAELIS)
	var s := c._session
	s.set_opponent_behavior_enabled(false)
	check(s.start_encounter().success,"Live combat fixture starts.")
	if inspect: c.open_character_sheet()
	var time_before := s.simulation.clock.get_elapsed_us()
	for i in range(5):
		if inspect:
			c._character_sheet.select_tab(i)
			c._character_sheet.refresh(true)
		s.request_player_attack("sheet_replay_%s" % i)
		c._physics_process(0.5) # Actual production frame path, not just a simulation-only advance.
	check(s.simulation.clock.get_elapsed_us() > time_before,"Combat continues during read-only inspection.")
	var snapshot := s.get_state_snapshot()
	var harness := TwoClientSyncHarness.new(42)
	harness.authority.simulation = s.simulation
	harness.deliver_in_order(harness.authority.publish_current_events())
	check(harness.compare_clients().success and harness.client_a.get_state_snapshot() == s.simulation.get_state_snapshot(),"Sheet visibility does not affect simulated-client convergence.")
	helper._free(scene)
	return snapshot
