extends MarginContainer

signal closed

const Origins := preload("res://scripts/strategy/origins.gd")
const TROOPS := ["legionary","auxiliary_spear","archer","centurion","signifer","emperor"]
const ORIGIN_IDS := ["italia","germania","han","wa","vistula"]
const FRIENDS := {"italia":"marcus","germania":"albrun","han":"lin","wa":"aki","vistula":"mira"}
const ROLE_NAMES := {"legionary":"Legionär","auxiliary_spear":"Hilfstruppen-Speerträger",
	"archer":"Bogenschütze","centurion":"Zenturio","signifer":"Feldzeichenträger","emperor":"Kaiser"}
const ROLE_INFO := {"legionary":"Infanterie der Legion","auxiliary_spear":"Infanterie der Hilfstruppen",
	"archer":"Fernkampftruppe","centurion":"Offizier der Legion","signifer":"Träger des Feldzeichens","emperor":"Figur des kaiserlichen Hofes"}
const GOLD := Color("#cdaa76")
const CREAM := Color("#f1e6cd")

var origin := "italia"
var age := 12
var from_journal := false
var current_id := "legionary"
var filter := "troops"
var _ids: Array = []
var _filters: Array[String] = []
var _body := BoxContainer.new()
var _stage := PanelContainer.new()
var _image := TextureRect.new()
var _missing := Label.new()
var _section := OptionButton.new()
var _picker := OptionButton.new()
var _title := Label.new()
var _caption := Label.new()
var _details := VBoxContainer.new()


static func arrival_ids(home: String, years: int = 12) -> Array:
	var ids := ["hero_" + home, FRIENDS.get(home,"marcus")]
	if home == "italia" and years >= 18:
		ids.append_array(["adult_italia","adult_marcus"])
	return ids


static func texture(id: String) -> Texture2D:
	var path := "res://assets/portraits/%s.webp" % id
	if ResourceLoader.exists(path,"Texture2D"):
		return load(path) as Texture2D
	return null


static func caption(id: String) -> Dictionary:
	if ROLE_NAMES.has(id):
		return {"name":ROLE_NAMES[id],"context":ROLE_INFO[id]}
	if id in ["adult_italia","adult_marcus"]:
		return {"name":"Hauptfigur aus Italia" if id == "adult_italia" else "Marcus", "context":"Im Erwachsenenalter · Rom / Italien"}
	for home in ORIGIN_IDS:
		var people: Dictionary = Origins.PEOPLES[home]
		if id == "hero_" + home:
			return {"name":"Hauptfigur · %s" % people.name, "context":"Bei der Ankunft · 12 Jahre"}
		if id == FRIENDS[home]:
			return {"name":people.companion,"context":"Bei der Ankunft · %s" % people.name}
	return {"name":"Figur", "context":""}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:
		add_theme_constant_override("margin_" + edge,16)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation",10)
	add_child(frame)
	var header := HBoxContainer.new()
	frame.add_child(header)
	var heading := Label.new()
	heading.text = "Figuren"
	heading.add_theme_font_size_override("font_size",30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var back := _button("Zurück",func(): closed.emit())
	back.name = "GalleryBack"
	header.add_child(back)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",16)
	frame.add_child(_body)
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.size_flags_stretch_ratio = 1.9
	var matte := StyleBoxFlat.new()
	matte.bg_color = Color("#272b28")
	matte.border_color = Color("#645d50")
	matte.set_border_width_all(1)
	_stage.add_theme_stylebox_override("panel",matte)
	_body.add_child(_stage)
	_image.name = "CurrentPortrait"
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_stage.add_child(_image)
	_missing.text = "Bild noch nicht verfügbar"
	_missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stage.add_child(_missing)
	_details.add_theme_constant_override("separation",10)
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(_details)
	_section.name = "PortraitCategory"
	_picker.name = "PortraitChoice"
	for menu in [_section,_picker]:
		menu.fit_to_longest_item = false
		menu.custom_minimum_size.y = 42
		menu.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_details.add_child(menu)
	_filters.assign(["troops","people"])
	_section.add_item("Truppe & Kaiser")
	_section.add_item("Herkunft & Gefährten")
	if from_journal:
		_filters.append("journal")
		_section.add_item("Mein Lebensweg")
	_section.item_selected.connect(func(index: int): _set_filter(_filters[index]))
	_picker.item_selected.connect(func(index: int): _select(index))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override("font_color",CREAM)
	_title.add_theme_font_size_override("font_size",22)
	_details.add_child(_title)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color",GOLD)
	_details.add_child(_caption)
	var navigation := HBoxContainer.new()
	_details.add_child(navigation)
	for spec in [["‹ Vorige",-1],["Nächste ›",1]]:
		var delta := int(spec[1])
		var button := _button(spec[0],func(): _select(posmod(_picker.selected + delta,_ids.size())))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.add_child(button)
	resized.connect(_resize)
	_resize()
	_set_filter(filter, current_id)
	back.grab_focus.call_deferred()


func _button(title: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.pressed.connect(callable)
	return button


func _resize() -> void:
	_body.vertical = size.x < 610 and size.y > size.x
	_details.add_theme_constant_override("separation",5 if size.y < 500 else 10)


func _set_filter(group: String, prefer: String = "") -> void:
	filter = group
	_ids = []
	match filter:
		"troops":
			_ids = TROOPS.duplicate()
		"journal":
			_ids = arrival_ids(origin,age)
		_:
			for home in ORIGIN_IDS:
				_ids.append_array(arrival_ids(home))
			_ids.append_array(["adult_italia","adult_marcus"])
	_section.select(_filters.find(filter))
	_picker.clear()
	for id in _ids:
		var label := String(caption(id).name)
		if id.begins_with("adult_"):
			label += " · erwachsen"
		_picker.add_item(label)
	_select(maxi(0,_ids.find(prefer)))


func _select(index: int) -> void:
	current_id = _ids[index]
	_picker.select(index)
	_image.texture = texture(current_id)
	_missing.visible = _image.texture == null
	if _image.texture != null and OS.is_debug_build() and OS.has_feature("android"):
		RenderingServer.frame_post_draw.connect(_report_drawn.bind(current_id,_image.texture),CONNECT_ONE_SHOT)
	var data := caption(current_id)
	_title.text = data.name
	_caption.text = data.context

func _report_drawn(id: String, shown: Texture2D) -> void:
	if is_visible_in_tree() and current_id == id and _image.texture == shown:
		print("IMPERATHEN_GALLERY_PORTRAIT " + id)
