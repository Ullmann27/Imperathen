extends CanvasLayer
signal leave_requested
signal acted(command: String, target: String)
const Atlas = preload("res://scripts/strategy/atlas_data.gd")
const Rules = preload("res://scripts/strategy/season_campaign.gd")
const Safe = preload("res://scripts/ui/safe_area.gd")
var data: Dictionary
var can_act := true
var demo := false
var young := false
var selected := "italia"
var frame := Control.new()
var globe = preload("res://scripts/strategy/globe.gd").new()
var panel := PanelContainer.new()
var sheet := VBoxContainer.new()
var list := OptionButton.new()
var date := Label.new()
var title := Label.new()
var description := Label.new()
var stock := Label.new()
var journal := Label.new()
var message := Label.new()
var actions := HFlowContainer.new()
var stories := VBoxContainer.new()
var title_bar := HBoxContainer.new()

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#10232b")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	frame.add_child(globe)
	frame.add_child(panel)
	frame.add_child(title_bar)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#26332f")
	background.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",background)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroller)
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation",9)
	scroller.add_child(sheet)
	title_bar.add_child(date)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date.add_theme_font_size_override("font_size",20)
	_button(title_bar,"Zurück",func(): leave_requested.emit())
	sheet.add_child(list)
	list.fit_to_longest_item = false
	for id in Atlas.REGIONS:
		list.add_item(Atlas.REGIONS[id].name)
		list.set_item_metadata(list.item_count-1,id)
	list.item_selected.connect(func(i): _select(list.get_item_metadata(i),true))
	globe.region_selected.connect(_select.bind(false))
	for label in [title,description,stock,journal,message]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sheet.add_child(label)
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_color",Color("#e8c88c"))
	message.add_theme_color_override("font_color",Color("#fdce81"))
	sheet.add_child(stories)
	sheet.add_child(actions)
	for item in [["harvest","Ernten"],["store","Einlagern"],["supply","Reisevorrat"],["campaign","Gebiet übernehmen"],["mission","Winterauftrag"],["mandate","Mandat erweitern"],["advance","Nächste Jahreszeit"]]:
		_button(actions,item[1],_command.bind(item[0]))
	get_viewport().size_changed.connect(_layout)
	_layout()
	_select(selected,true)
	print("IMPERATHEN_ATLAS_READY")

func _layout() -> void:
	var area := Safe.for_viewport(get_viewport())
	frame.position = area.position
	frame.size = area.size
	title_bar.position = Vector2(12,4)
	title_bar.size = Vector2(area.size.x-24,44)
	if area.size.x >= area.size.y*1.12:
		var width := clampf(area.size.x*0.35,285,495)
		globe.position = Vector2(0,51)
		globe.size = Vector2(area.size.x-width,area.size.y-51)
		panel.position = Vector2(area.size.x-width,51)
		panel.size = Vector2(width,area.size.y-51)
	else:
		var height := area.size.y*0.44
		globe.position = Vector2(0,51)
		globe.size = Vector2(area.size.x,height)
		panel.position = Vector2(0,height+51)
		panel.size = Vector2(area.size.x,area.size.y-height-51)

func _button(parent: Control,text: String,callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	parent.add_child(b)

func _select(id: String,rotate: bool) -> void:
	selected = id
	list.select(Atlas.REGIONS.keys().find(id))
	if rotate:
		globe.focus_region(id)
	refresh()

func _command(cmd: String) -> void:
	acted.emit(cmd,selected)

func refresh(feedback := "") -> void:
	var info: Dictionary = Rules.region_info(data,selected)
	var season: Dictionary = Rules.summary(data)
	var region: Dictionary = Atlas.REGIONS[selected]
	var year: int = 94 if young else season.year
	date.text = "Weltkugel   ·   %s %d n. Chr.%s" % [season.season,year,"   ·   Freies Szenario" if demo else ""]
	title.text = region.name
	description.text = region.note
	stock.text = "%s · %d/%d Gebiete\nKorn %d   ·   Speicher %d/%d   ·   Reisevorrat %d\nUnruhe %d   ·   Saisonaktionen %d" % [season.mandate_name,data.owned.size(),Atlas.REGIONS.size(),data.grain,data.stores,season.winter_need,data.supply,data.unrest,data.actions]
	journal.text = "Auftrag · %s\n%s" % [Atlas.REGIONS[data.mission.target].name, data.last_event]
	var route := "Eigenes Gebiet" if info.owned else ("Übernahme kostet %d Reisevorräte" % info.cost if info.reachable else "Kein Anschluss an dein Gebiet")
	message.text = "\n".join(PackedStringArray([route,season.warning,feedback])).strip_edges()
	if not can_act:
		message.text = "Erkundung · Regionale Aufträge werden nach der Dorfverteidigung zugänglich."
	actions.visible = can_act
	stories.visible = can_act
	for b in stories.get_children():
		stories.remove_child(b)
		b.queue_free()
	if not season.story_title.is_empty():
		journal.text += "\n" + season.story_title + " · " + season.story_text
	for option in Rules.story_options(data):
		_button(stories,option.label,func(): acted.emit("story",option.id))
	globe.show_routes(selected,data.owned)
