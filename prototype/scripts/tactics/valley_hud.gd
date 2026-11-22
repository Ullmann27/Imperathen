extends CanvasLayer

signal requested(action: String, argument: String)
const SafeArea = preload("res://scripts/ui/safe_area.gd")
const INK := Color("#242b27")
const GOLD := Color("#e8c989")
var frame := Control.new()
var top := PanelContainer.new()
var bottom := PanelContainer.new()
var cards := HBoxContainer.new()
var command_row := HBoxContainer.new()
var status := Label.new()
var heading := Label.new()
var pause_button: Button
var group_button: Button
var card_by_id := {}
var marquee := ColorRect.new()

func _ready() -> void:
	add_child(frame)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for panel in [top, bottom]:
		frame.add_child(panel)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(INK,0.94)
		style.border_color = Color("#897951")
		style.border_width_bottom = 1
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		panel.add_theme_stylebox_override("panel",style)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	top.add_child(bar)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color",GOLD)
	heading.clip_text = true
	bar.add_child(heading)
	pause_button = _button(bar,"Pause","pause")
	_button(bar,"Zurück","leave")
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var body := VBoxContainer.new()
	bottom.add_child(body)
	body.add_child(status)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.add_theme_color_override("font_color",GOLD)
	_scroll_row(body,cards)
	_scroll_row(body,command_row)
	group_button = _button(cards,"Gruppe +","multi")
	group_button.toggle_mode = true
	add_child(marquee)
	marquee.visible = false
	marquee.color = Color(0.8,0.68,0.38,0.28)
	marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_resize)
	_resize()

func populate(model) -> void:
	for id in model.squads:
		var s: Dictionary = model.squads[id]
		if s.side == "ally":
			var card := _button(cards,s.name,"select",id)
			card.toggle_mode = true
			card_by_id[id] = card
	_menu(command_row,"Verband",{"talwache_front":"Linienverband","talwache_support":"Unterstützung","talwache":"Gesamte Legion"},"group")
	_menu(command_row,"Formation",model.FORMATIONS,"form")
	_menu(command_row,"Befehl",{"move":"Marschieren","hold":"Halten","attack":"Angriff","attack_move":"Angriffsmarsch","defend":"Verteidigen","flank":"Flanke","retreat":"Rückzug","rally":"Sammeln","reserve":"Reserve","focus_fire":"Feuer bündeln","cease_fire":"Feuer einstellen"},"command")
	_button(command_row,"Tempo","speed")
	_button(command_row,"−","zoom_out")
	_button(command_row,"+","zoom_in")
	_resize()

func refresh(model, selected: Array, paused: bool, rate: float, message: String) -> void:
	var counts := {"ally":0,"enemy":0}
	for s: Dictionary in model.squads.values():
		counts[s.side] += int(s.strength)
		if card_by_id.has(s.id):
			var card: Button = card_by_id[s.id]
			card.set_pressed_no_signal(s.id in selected)
			card.text = "%s · %d" % [s.name,s.strength]
	heading.text = "TALWACHT   ·   %d:%02d   ·   Legion %d   /   Stämme %d" % [floori((model.DEFENCE_SECONDS-model.steps*model.STEP)/60.0),int(model.DEFENCE_SECONDS-model.steps*model.STEP)%60,counts.ally,counts.enemy]
	pause_button.text = "Fortsetzen" if paused else "Pause"
	var outcome_labels := {"victory":"Sieg der Grenzlegion","defeat":"Die Talstraße ist verloren","draw":"Unentschieden"}
	if model.outcome != "ongoing":
		status.text = outcome_labels.get(model.outcome,model.outcome) + "   ·   Zurück zum Bericht"
	else:
		status.text = ("%s×   ·   " % rate) + message
	_resize()

func blocks(p: Vector2) -> bool:
	return top.get_global_rect().has_point(p) or bottom.get_global_rect().has_point(p)

func selection_box(a: Vector2,b: Vector2) -> void:
	var rect := Rect2(a,b-a).abs()
	marquee.position = rect.position
	marquee.size = rect.size
	marquee.visible = rect.size.length_squared() > 25.0

func _resize() -> void:
	var area: Rect2 = SafeArea.for_viewport(get_viewport())
	frame.position = area.position
	frame.size = area.size
	bottom.offset_top = -bottom.get_combined_minimum_size().y

func _button(row: Control,caption: String,action: String,argument := "") -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(44,40)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func(): requested.emit(action,argument))
	row.add_child(button)
	return button

func _scroll_row(body: Control,row: HBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 44
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(scroll)
	scroll.add_child(row)

func _menu(row: Control,caption: String,labels: Dictionary,action: String) -> void:
	var button := MenuButton.new()
	button.text = caption + " ▾"
	button.custom_minimum_size = Vector2(104,40)
	button.focus_mode = Control.FOCUS_NONE
	row.add_child(button)
	var popup := button.get_popup()
	for id in labels:
		popup.add_item(labels[id])
		popup.set_item_metadata(popup.item_count-1,id)
	popup.index_pressed.connect(func(i): requested.emit(action,popup.get_item_metadata(i)))
