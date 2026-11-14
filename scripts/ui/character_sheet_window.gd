class_name CharacterSheetWindow
extends Control

const SheetData = preload("res://scripts/ui/character_sheet_projection.gd")
const Help = preload("res://scripts/ui/character_sheet_help.gd")
const TABS := ["ATTRIBUTES","SKILLS","SPECIALS","EQUIPMENT","PROFILE"]
const INK := Color("11151e")
const CARD := Color("1c2431")
const GOLD := Color("d6b77b")
const TEXT := Color("e6e4de")
const MUTED := Color("a6b2c2")
const ACCENT := Color("8dd2bf")
var controller: Node
var model := {}
var active_tab := 0
var panel: PanelContainer
var close_button: Button
var tab_buttons: Array[Button] = []
var scroll: ScrollContainer
var content: VBoxContainer
var help_layer: Control
var help_panel: PanelContainer
var help_quick: Label
var help_details: Label
var help_title: Label
var title: Label
var subtitle: Label
var context: Label
var footer: Label
var _expanded := {}
var _refresh_elapsed := 0.0
var _last_size := Vector2.ZERO
var _last_display := Vector2.ZERO
var _scale := 1.0
var _touch_was_visible := false
var _prior_focus: Control

func setup(host: Node) -> void:
	controller = host
	name = "CharacterSheet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.03,0.05,0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = PanelContainer.new()
	panel.name = "SheetWindow"
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",10)
	panel.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(names)
	names.add_child(_label("ITANK PRIME / CHARACTER",12,GOLD))
	title = _label("Character",24,TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	names.add_child(title)
	subtitle = _label("",14,MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	subtitle.clip_text = true
	names.add_child(subtitle)
	var read_only := _label("READ ONLY",12,GOLD)
	read_only.autowrap_mode = TextServer.AUTOWRAP_OFF
	read_only.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(read_only)
	close_button = _button("X",close_sheet)
	close_button.name = "CloseCharacterSheet"
	close_button.tooltip_text = "Close character sheet (Escape)"
	close_button.custom_minimum_size = Vector2(44,44)
	heading.add_child(close_button)
	var tabs := HBoxContainer.new()
	tabs.name = "SheetTabs"
	body.add_child(tabs)
	for i in range(TABS.size()):
		var button := _button(TABS[i],select_tab.bind(i))
		button.name = "Tab"+TABS[i].capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		tab_buttons.append(button)
	context = _label("",13,ACCENT)
	context.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(context)
	scroll = ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "SheetContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	footer = _label("Inspect only. Manage equipment and progression in CHARACTER MENU.",12,MUTED)
	footer.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.clip_text = true
	body.add_child(footer)
	_make_help()
	hide()
	set_process(false)

func open_sheet() -> void:
	if visible: return
	_prior_focus = get_viewport().gui_get_focus_owner()
	controller._clear_attack_hold_intent()
	if controller._touch_controls != null:
		_touch_was_visible = controller._touch_controls.visible
		controller._touch_controls.reset_input()
		controller._touch_controls.hide()
	show()
	_layout()
	refresh(true)
	close_button.grab_focus()
	set_process(true)

func close_sheet() -> void:
	if not visible: return
	help_layer.hide()
	hide()
	set_process(false)
	controller._clear_attack_hold_intent()
	if controller._touch_controls != null:
		controller._touch_controls.reset_input()
		controller._touch_controls.visible = _touch_was_visible
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused): focused.release_focus()
	if is_instance_valid(_prior_focus) and _prior_focus.is_visible_in_tree(): _prior_focus.grab_focus()

func handle_escape() -> void:
	if help_layer.visible:
		help_layer.hide()
		close_button.grab_focus()
	else: close_sheet()

func move_focus(backwards: bool) -> void:
	# Keep keyboard navigation inside the modal, including after a live refresh.
	var scope: Control = help_panel if help_layer.visible else panel
	var controls: Array[Control] = []
	for node: Node in scope.find_children("*","Control",true,false):
		var control := node as Control
		if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree(): continue
		if control is BaseButton and control.disabled: continue
		controls.append(control)
	if controls.is_empty(): return
	var index := controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(index+(-1 if backwards else 1),controls.size())].grab_focus()

func _process(delta: float) -> void:
	var size_now := get_viewport_rect().size
	var display_now := Vector2(DisplayServer.window_get_size())
	if size_now != _last_size or display_now != _last_display:
		_layout()
		_render()
	# Containers settle wrapped-text minimum sizes after layout; keep the
	# window fitted rather than retaining its first, pre-layout minimum height.
	var margin := (10.0 if _last_display.y < 500 else 24.0)/_scale
	panel.size = _last_size-Vector2(margin,margin)*2
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus): close_button.grab_focus()
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0.0
		refresh()

func refresh(force: bool = false) -> void:
	var next := SheetData.capture(controller._session)
	if not force and next == model: return
	model = next
	title.text = String(model.get("name","Character information unavailable"))
	subtitle.text = String(model.get("subtitle",""))
	context.text = "COMBAT CONTINUES WHILE VIEWING" if model.get("combat_active",false) else "CHARACTER RECORD | INSPECTION ONLY"
	_render()

func select_tab(index: int) -> void:
	if index < 0 or index >= TABS.size(): return
	active_tab = index
	scroll.scroll_vertical = 0
	_render()

func _layout() -> void:
	_last_size = get_viewport_rect().size
	_last_display = Vector2(DisplayServer.window_get_size())
	_scale = maxf(0.1,minf(_last_display.x/maxf(1,_last_size.x),_last_display.y/maxf(1,_last_size.y)))
	var margin := (10.0 if _last_display.y < 500 else 24.0)/_scale
	panel.position = Vector2(margin,margin)
	panel.size = _last_size-Vector2(margin,margin)*2
	var skin := Theme.new()
	skin.default_font_size = roundi(14/_scale)
	for type: String in ["Label","Button"]: skin.set_color("font_color",type,TEXT)
	skin.set_color("font_hover_color","Button",GOLD)
	skin.set_color("font_focus_color","Button",GOLD)
	skin.set_stylebox("normal","Button",_style(Color("253043"),Color("536073"),8))
	skin.set_stylebox("hover","Button",_style(Color("303d50"),GOLD,8))
	skin.set_stylebox("pressed","Button",_style(Color("3b352b"),GOLD,8))
	skin.set_stylebox("focus","Button",_style(Color(0,0,0,0),GOLD,0))
	panel.theme = skin
	help_panel.theme = skin
	for label: Node in find_children("*","Label",true,false):
		if label.has_meta("sheet_font"): label.add_theme_font_size_override("font_size",roundi(float(label.get_meta("sheet_font"))/_scale))
	panel.add_theme_stylebox_override("panel",_style(INK,Color("947849"),14))
	help_panel.add_theme_stylebox_override("panel",_style(INK,GOLD,16))
	title.add_theme_font_size_override("font_size",roundi(22/_scale))
	subtitle.add_theme_font_size_override("font_size",roundi(13/_scale))
	context.add_theme_font_size_override("font_size",roundi(12/_scale))
	footer.add_theme_font_size_override("font_size",roundi(11/_scale))
	close_button.custom_minimum_size = Vector2(44,40)/_scale
	for button: Button in tab_buttons:
		button.custom_minimum_size.y = 38/_scale
		button.add_theme_font_size_override("font_size",roundi(12/_scale))
	var help_size := Vector2(minf(650/_scale,_last_size.x-40/_scale),minf(350/_scale,_last_size.y-40/_scale))
	help_panel.position = (_last_size-help_size)/2
	help_panel.size = help_size

func _style(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = padding/_scale
	box.content_margin_right = padding/_scale
	box.content_margin_top = padding/_scale
	box.content_margin_bottom = padding/_scale
	return box

func _label(text: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("sheet_font",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",roundi(font_size/_scale))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	return button

func _section(text: String, help_id: String = "STATS") -> void:
	var header := HBoxContainer.new()
	var label := _label(text,13,GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var help := _button("?",show_help.bind(help_id))
	help.tooltip_text = Help.entry(help_id).quick
	help.custom_minimum_size = Vector2(32,28)/_scale
	header.add_child(help)
	content.add_child(header)

func _card(parent: Node) -> VBoxContainer:
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel",_style(CARD,Color("3d4a5b"),10))
	parent.add_child(box)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",6)
	box.add_child(body)
	return body

func _grid(columns: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",roundi(10/_scale))
	grid.add_theme_constant_override("v_separation",roundi(10/_scale))
	content.add_child(grid)
	return grid

func _render() -> void:
	if content == null: return
	var offset := scroll.scroll_vertical
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and content.is_ancestor_of(focus): close_button.grab_focus()
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for i in range(tab_buttons.size()):
		tab_buttons[i].add_theme_stylebox_override("normal",_style(GOLD if i == active_tab else CARD,GOLD if i == active_tab else Color("536073"),8))
		tab_buttons[i].add_theme_color_override("font_color",INK if i == active_tab else MUTED)
	if not model.get("success",false):
		content.add_child(_label(String(model.get("reason","Character information is unavailable."))))
		return
	match active_tab:
		0: _attributes()
		1:
			_section("SKILLS & PROFICIENCIES","SKILLS")
			_entries(model.skills,"No verified skill records are available. Missing information does not mean untrained.")
		2:
			_section("KNOWN SPECIALS & ABILITIES","SPECIALS")
			_entries(model.specials,"Known Specials are not recorded for this character. Catalog entries alone do not establish knowledge.")
		3:
			_section("EQUIPMENT & BELONGINGS","EQUIPMENT")
			_entries(model.equipment,"Equipment information is unavailable.")
		4: _profile()
	scroll.set_deferred("scroll_vertical",offset)

func _attributes() -> void:
	_section("VITAL RESOURCES","RESOURCES")
	var resources := _grid(3 if _last_display.x >= 680 else 2)
	for resource: Dictionary in model.resources:
		var body := _card(resources)
		body.add_child(_label(resource.name.to_upper(),11,MUTED))
		body.add_child(_label("%s / %s" % [SheetData.show_value(resource.current),SheetData.show_value(resource.maximum)],23,ACCENT))
	_section("PRIMARY ATTRIBUTES","STATS")
	content.add_child(_label("ORIGINAL  /  PERMANENT  /  EFFECTIVE     |     -- = no verified value",11,MUTED))
	var primaries := _grid(5 if _last_display.x >= 760 else 3)
	for stat: Dictionary in model.primaries:
		var body := _card(primaries)
		_stat_heading(body,stat)
		_values(body,stat,19)
	_section("DERIVED ATTRIBUTES","STATS")
	var derived := _grid(3 if _last_display.x >= 760 else 2)
	for primary: String in SheetData.Rules.PRIMARY_NAMES:
		var body := _card(derived)
		body.add_child(_label(SheetData.Rules.PRIMARY_NAMES[primary].to_upper(),12,GOLD))
		for stat: Dictionary in model.derived:
			if stat.group != primary: continue
			_stat_heading(body,stat)
			_values(body,stat,14)
	_section("RESISTANCES","STATS")
	var resistances := _grid(2)
	for stat: Dictionary in model.resistances:
		var body := _card(resistances)
		_stat_heading(body,stat)
		_values(body,stat,17)
	_section("CONDITIONS & ACTIVE EFFECTS","RESOURCES")
	_entries(model.effects,"No current conditions or active effects are recorded.")

func _stat_heading(body: VBoxContainer, stat: Dictionary) -> void:
	var row := HBoxContainer.new()
	var text := _label("%s  %s" % [stat.id,stat.name] if stat.id != stat.name else stat.name,12,TEXT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var info := _button("?",show_help.bind(stat.id))
	info.custom_minimum_size = Vector2(28,26)/_scale
	info.tooltip_text = Help.entry(stat.id).quick
	row.add_child(info)
	body.add_child(row)

func _values(body: VBoxContainer, stat: Dictionary, font_size: int) -> void:
	var row := HBoxContainer.new()
	for key: String in ["original","permanent","effective"]:
		var color: Color = MUTED if key == "original" else TEXT
		if key == "permanent" and stat.permanent != null and stat.original != null and stat.permanent != stat.original: color = GOLD
		if key == "effective" and stat.effective != null and stat.effective != stat.permanent: color = ACCENT
		var value := _label(SheetData.show_value(stat[key]),font_size,color)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value)
	body.add_child(row)

func _entries(entries: Array, empty_text: String) -> void:
	if entries.is_empty():
		_card(content).add_child(_label(empty_text,14,MUTED))
		return
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var body := _card(content)
		var key := "%s:%s" % [active_tab,entry.get("entry_id",entry.title)]
		var button := Button.new()
		button.name = "Entry%s" % i
		button.text = ("-  " if _expanded.get(key,false) else "+  ")+String(entry.title)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = _expanded.get(key,false)
		body.add_child(button)
		body.add_child(_label(String(entry.get("status","")),11,ACCENT))
		var detail := VBoxContainer.new()
		detail.visible = button.button_pressed
		for line: Variant in entry.get("details",[]): detail.add_child(_label(str(line),14,TEXT))
		body.add_child(detail)
		button.toggled.connect(func(expanded: bool) -> void:
			_expanded[key] = expanded
			detail.visible = expanded
			button.text = ("-  " if expanded else "+  ")+String(entry.title))

func _profile() -> void:
	_section("IDENTITY & PERSONAL RECORD","EXPM")
	for section: Dictionary in model.profile:
		var body := _card(content)
		body.add_child(_label(section.title.to_upper(),12,GOLD))
		for row: Array in section.rows:
			body.add_child(_label("%s: %s" % [row[0],"Not recorded" if row[1] == null else str(row[1])],14,TEXT if row[1] != null else MUTED))
	_section("ADVANCEMENT PURCHASE HISTORY","EXPC")
	var entries: Array = []
	for purchase: Dictionary in model.purchases:
		entries.append({"title":"%s %s -> %s" % [String(purchase.get("target_id","stat")).to_upper(),purchase.get("value_before","?"),purchase.get("value_after","?")],"status":"%s EXPC%s" % [purchase.get("cost","?")," | +1 "+String(purchase.allocation).to_upper() if purchase.has("allocation") else ""],"details":["Source: "+String(purchase.get("source_ref","Not recorded"))]})
	_entries(entries,"No purchases are recorded.")

func _make_help() -> void:
	help_layer = Control.new()
	help_layer.name = "SheetHelp"
	help_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(help_layer)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			help_layer.hide()
			close_button.grab_focus())
	help_layer.add_child(shade)
	help_panel = PanelContainer.new()
	help_layer.add_child(help_panel)
	var box := VBoxContainer.new()
	help_panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	help_title = _label("Help",20,GOLD)
	help_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(help_title)
	header.add_child(_button("X",func(): help_layer.hide(); close_button.grab_focus()))
	var help_scroll := ScrollContainer.new()
	help_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	help_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(help_scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_scroll.add_child(lines)
	help_quick = _label("",16,TEXT)
	lines.add_child(help_quick)
	help_details = _label("",14,MUTED)
	lines.add_child(help_details)
	var more := _button("VIEW DETAILS",func(): help_details.visible = not help_details.visible)
	box.add_child(more)
	help_layer.hide()

func show_help(id: String) -> void:
	var entry := Help.entry(id)
	help_title.text = entry.title
	help_quick.text = entry.quick
	help_details.text = entry.details
	help_details.hide()
	help_layer.show()
	help_panel.get_child(0).get_child(0).get_child(1).grab_focus()
