extends CanvasLayer
## Reusable market UI. The session owns every mutation and all persistence.
signal command_requested(command: String, arguments: Dictionary)
signal closed
signal save_requested
signal load_requested
signal quality_requested(profile: String)
signal interact_requested
signal inventory_requested

const Trade = preload("res://scripts/city_trade.gd")
const TradeCatalog = preload("res://scripts/city_trade_catalog.gd")
const TouchPad = preload("res://scripts/ui/touch_pad.gd")
## Same Roman visual language as the game HUD: ink and bronze plaques,
## Cinzel headings, engraved item glyphs (original SVG drawing).
const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const QUALITY_IDS := ["low", "balanced", "high", "very_high"]
var pad: Control
var modal: PanelContainer
var contents: VBoxContainer
var status: Label
var money_label: Label
var hint_label: Label
var interact_button: Button
var modal_title: Label
var quality: OptionButton
var shop_id := ""
var inventory_open := false
var embedded_city := false
var shop_sites: Dictionary = {}
var _state: Dictionary = {}
var _overlay: ColorRect
var _root: Control
var modal_kicker: Label
var modal_purse: Label


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 14
	top.offset_bottom = 92
	_root.add_child(top)
	var margin := _margin(top, 12)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	margin.add_child(line)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title_box)
	var title := _label("Marktviertel", 22)
	title.add_theme_font_override("font", Style.display_font(700, 2))
	title.add_theme_color_override("font_color", Style.AURUM_LIGHT)
	title_box.add_child(title)
	money_label = _label("", 18)
	title_box.add_child(money_label)
	line.add_child(_button("Beutel", func(): inventory_requested.emit(), "pouch"))
	line.add_child(_button("Sichern", func(): save_requested.emit(), "save"))
	line.add_child(_button("Laden", func(): load_requested.emit(), "back"))
	quality = OptionButton.new()
	quality.custom_minimum_size = Vector2(150, 48)
	for name in ["Leicht", "Ausgewogen", "Hoch", "Ultra"]:
		quality.add_item(name)
	quality.select(1)
	quality.item_selected.connect(func(index: int): quality_requested.emit(QUALITY_IDS[index]))
	line.add_child(quality)
	pad = TouchPad.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad.position = Vector2(18, -222)
	pad.size = Vector2(196, 196)
	_root.add_child(pad)
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bottom.offset_left = -420
	bottom.offset_right = -24
	bottom.offset_top = -182
	bottom.offset_bottom = -24
	bottom.add_theme_constant_override("separation", 8)
	_root.add_child(bottom)
	hint_label = _label("Zu einem Geschäft gehen", 18)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(hint_label)
	interact_button = _button("Ansprechen", func(): interact_requested.emit())
	bottom.add_child(interact_button)
	status = _label("Gehen: Stick oder WASD · Umschauen: rechts ziehen · E: ansprechen", 16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 230
	status.offset_right = -450
	status.offset_top = -100
	status.offset_bottom = -24
	_root.add_child(status)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.03, 0.022, 0.016, 0.64)
	_root.add_child(_overlay)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.anchor_left = 0.12
	modal.anchor_top = 0.1
	modal.anchor_right = 0.88
	modal.anchor_bottom = 0.92
	modal.add_theme_stylebox_override("panel", Style.plaque(true, Vector4(4, 4, 4, 4), 0.95))
	_overlay.add_child(modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_margin(modal, 20).add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	box.add_child(heading)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	heading.add_child(titles)
	modal_kicker = Style.kicker("MARKTVIERTEL", 11)
	titles.add_child(modal_kicker)
	modal_title = _label("", 26)
	modal_title.add_theme_font_override("font", Style.display_font(700, 2))
	modal_title.add_theme_color_override("font_color", Style.AURUM_LIGHT)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(modal_title)
	modal_purse = _label("", 16)
	modal_purse.add_theme_color_override("font_color", Style.CHARTA_MUTED)
	modal_purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(modal_purse)
	var closer := _button("Schließen", close, "close")
	closer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(closer)
	box.add_child(Kit.Rule.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	contents = VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	_overlay.hide()
	if embedded_city:
		top.hide()
		bottom.hide()
		pad.hide()
		status.reparent(box)
		status.text = ""
		status.custom_minimum_size.y = 28
	_apply_theme()


func _margin(parent: Node, pixels: int) -> MarginContainer:
	var node := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, pixels)
	parent.add_child(node)
	return node


func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Style.body_font())
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(value: String, action: Callable, glyph := "", primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(100, 50)
	Style.style_plaque_button(button, primary, 16)
	if not glyph.is_empty():
		button.icon = Icons.texture(glyph, 20, 1.6)
	button.pressed.connect(action)
	return button


func _apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font = Style.body_font()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", Style.plaque(false, Vector4(12, 10, 12, 10), 0.9))
	var plain := Button.new()
	Style.style_plaque_button(plain, false, 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "Button", plain.get_theme_stylebox(state))
	plain.free()
	theme.set_color("font_color", "Label", Style.CHARTA)
	theme.set_color("font_color", "Button", Style.CHARTA)
	theme.set_color("font_disabled_color", "Button", Color(0.62, 0.6, 0.55, 0.8))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Style.BRONZE
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	_root.theme = theme


func update_state(state: Dictionary) -> void:
	_state = state
	money_label.text = "%d Denare · %d Jahre" % [int(state.resources.denarii), int(state.player.age)]
	if is_instance_valid(modal_purse):
		modal_purse.text = "Börse · %d Denare" % int(state.resources.denarii)
	if is_open():
		_refresh_contents()


func set_nearest(name: String, distance: float) -> void:
	interact_button.disabled = name.is_empty() or distance > 3.0
	interact_button.text = "Ansprechen" if name.is_empty() else name
	hint_label.text = "Zu einem Geschäft gehen" if name.is_empty() else "%s · %.1f m" % [name, distance]


func notify(message: String) -> void:
	status.text = message


func is_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible


func open_shop(id: String) -> void:
	shop_id = id
	inventory_open = false
	_overlay.show()
	pad.reset()
	pad.hide()
	_refresh_contents()


func open_inventory() -> void:
	shop_id = ""
	inventory_open = true
	_overlay.show()
	pad.reset()
	pad.hide()
	_refresh_contents()


func close() -> void:
	_overlay.hide()
	pad.reset()
	if not embedded_city:
		pad.show()
	shop_id = ""
	inventory_open = false
	closed.emit()


func _clear_contents() -> void:
	for child in contents.get_children():
		contents.remove_child(child)
		child.queue_free()


func _refresh_contents() -> void:
	_clear_contents()
	var view: Dictionary = Trade.view(_state, shop_id, shop_sites)
	if _state.has("resources") and is_instance_valid(modal_purse):
		modal_purse.text = "Börse · %d Denare" % int(_state.resources.denarii)
	if inventory_open:
		modal_kicker.text = "DEIN BESITZ"
		modal_title.text = "Dein Beutel"
		var skills: Dictionary = view.get("skills", {})
		var bonuses: Dictionary = view.get("equipment_bonuses", {})
		var learned := _label("Erfahrung aus Einsätzen: Kampf %d · Abwehr %d · Kommando %d" % [int(skills.get("combat", 0)), int(skills.get("defense", 0)), int(skills.get("command", 0))], 16)
		learned.add_theme_color_override("font_color", Style.CHARTA_MUTED)
		learned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(learned)
		var equipment := _label("Ausrüstung: Angriff +%d · Schutz +%d · Kommando +%d" % [int(bonuses.get("attack", 0)), int(bonuses.get("defense", 0)), int(bonuses.get("command", 0))], 16)
		equipment.add_theme_color_override("font_color", Style.AURUM)
		equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(equipment)
		contents.add_child(Kit.heading("Gegenstände"))
		var item_count := 0
		for item: Dictionary in view.get("inventory", []):
			item_count += 1
			var detail := "angelegt" if item.get("equipped", false) else ""
			var catalog: Dictionary = TradeCatalog.ITEMS.get(str(item.item_id), {})
			if not str(catalog.get("slot", "")).is_empty() and detail.is_empty():
				detail = {"body": "Kleidung", "belt": "Gürtel", "weapon": "Waffe", "shield": "Schild"}.get(str(catalog.slot), "")
			elif int(catalog.get("health", 0)) > 0 or float(catalog.get("stamina", 0.0)) > 0.0:
				detail = "Stärkt: +%d Leben · +%d Ausdauer" % [int(catalog.get("health", 0)), roundi(float(catalog.get("stamina", 0.0)))]
			var row := _item_row("%s × %d" % [item.name, int(item.quantity)], detail, Icons.item_kind(str(item.item_id), str(item.name)), bool(item.get("equipped", false)))
			if item.get("can_consume", false):
				row.add_child(_button("Verbrauchen", func(): command_requested.emit("city_consume", {"item_id":item.item_id}), "food"))
			if item.get("can_equip", false):
				var b := _button("Ablegen" if item.get("equipped", false) else "Anlegen", func(): command_requested.emit("city_equip", {"item_id":item.item_id}), "garment")
				# The domain command toggles the equipped item; disabling this button
				# would prevent players from unequipping (and then selling) their gear.
				row.add_child(b)
		if item_count == 0:
			var empty := _label("Dein Beutel ist leer.", 18)
			empty.add_theme_color_override("font_color", Style.CHARTA_MUTED)
			contents.add_child(empty)
		return
	modal_kicker.text = "HANDEL"
	modal_title.text = "Handel"
	for shop: Dictionary in view.get("shops", []):
		if shop.id == shop_id:
			modal_title.text = shop.name
	for offer: Dictionary in view.get("offers", []):
		var row := _item_row("%s · %d Denare" % [offer.name, int(offer.price)], "Vorrat: %d · In deinem Beutel: %d" % [int(offer.stock), int(offer.owned)], Icons.item_kind(str(offer.item_id), str(offer.name)), false)
		var card := row.get_parent().get_parent() as Control
		var buy := _button("Kaufen", func(): command_requested.emit("city_buy", {"shop_id":shop_id, "item_id":offer.item_id, "quantity":1}), "coin", true)
		buy.disabled = not bool(offer.get("can_buy", false))
		row.add_child(buy)
		var sell := _button("Verkaufen · %d" % int(offer.sell_price), func(): command_requested.emit("city_sell", {"shop_id":shop_id, "item_id":offer.item_id, "quantity":1}))
		sell.disabled = not bool(offer.get("can_sell", false))
		row.add_child(sell)
		if not str(offer.get("reason", "")).is_empty():
			var reason := _label(str(offer.reason), 15)
			reason.add_theme_color_override("font_color", Style.CHARTA_MUTED)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			(card.get_child(0) as VBoxContainer).add_child(reason)
	if shop_id == "armorer":
		contents.add_child(Kit.heading("Dienstausgabe"))
		var service: Dictionary = view.get("service", {})
		var service_button := _button("Grundausrüstung erhalten · kostenlos", func(): command_requested.emit("city_issue_service", {"shop_id":"armorer"}), "shield")
		service_button.disabled = not bool(service.get("eligible", false))
		contents.add_child(service_button)
		var note := _label(str(service.get("reason", "Die Ausgabe folgt der abgeschlossenen erwachsenen Ausbildung.")), 16)
		note.add_theme_color_override("font_color", Style.CHARTA_MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(note)
		for reward: Dictionary in view.get("rewards", []):
			var button := _button(str(reward.get("name", reward.get("id", "Belohnung"))), func(): command_requested.emit("city_claim_reward", {"shop_id":"armorer", "reward_id":str(reward.get("reward_id", reward.get("id", "")))}), "laurel")
			button.disabled = not bool(reward.get("eligible", false))
			contents.add_child(button)
			var reason := _label(str(reward.get("reason", "")), 16)
			reason.add_theme_color_override("font_color", Style.CHARTA_MUTED)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			contents.add_child(reason)


## Item card: engraved glyph tile, name and detail, actions on the right.
## Returns the action row so callers append their buttons to it.
func _item_row(title: String, detail: String, glyph: String, highlighted: bool) -> HBoxContainer:
	var card := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.054, 0.04, 0.82)
	box.border_color = Style.AURUM if highlighted else Color(0.6, 0.46, 0.27, 0.6)
	box.set_border_width_all(1)
	box.border_width_left = 3 if highlighted else 1
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", box)
	contents.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var tile := TextureRect.new()
	tile.texture = Icons.texture(glyph, 40, 1.5)
	tile.custom_minimum_size = Vector2(40, 40)
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.self_modulate = Style.AURUM_LIGHT
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	var label := _label(title, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(label)
	if not detail.is_empty():
		var sub := _label(detail, 14)
		sub.add_theme_color_override("font_color", Style.AURUM if highlighted else Style.CHARTA_MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		names.add_child(sub)
	return row
