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
const TouchPad = preload("res://scripts/ui/touch_pad.gd")
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
var _state: Dictionary = {}
var _overlay: ColorRect
var _root: Control


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
	title_box.add_child(title)
	money_label = _label("", 18)
	title_box.add_child(money_label)
	line.add_child(_button("Beutel", func(): inventory_requested.emit()))
	line.add_child(_button("Sichern", func(): save_requested.emit()))
	line.add_child(_button("Laden", func(): load_requested.emit()))
	quality = OptionButton.new()
	quality.custom_minimum_size = Vector2(150, 48)
	for name in ["Leicht", "Ausgewogen", "Hoch", "Sehr hoch"]:
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
	_overlay.color = Color(0.025, 0.032, 0.04, 0.60)
	_root.add_child(_overlay)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.anchor_left = 0.14
	modal.anchor_top = 0.14
	modal.anchor_right = 0.86
	modal.anchor_bottom = 0.90
	_overlay.add_child(modal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_margin(modal, 20).add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	modal_title = _label("", 24)
	modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(modal_title)
	heading.add_child(_button("Schließen", close))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	contents = VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 10)
	scroll.add_child(contents)
	_overlay.hide()
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
	label.add_theme_font_size_override("font_size", size)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(100, 50)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	return button


func _apply_theme() -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("182024")
	panel.border_color = Color("aa885a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(9)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var button := StyleBoxFlat.new()
	button.bg_color = Color("38413f")
	button.border_color = Color("90774d")
	button.set_border_width_all(1)
	button.set_corner_radius_all(6)
	button.content_margin_left = 14
	button.content_margin_right = 14
	theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate() as StyleBoxFlat
	hover.bg_color = Color("51594d")
	theme.set_stylebox("hover", "Button", hover)
	var pressed := button.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("6d6146")
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_color("font_color", "Label", Color("f3ead8"))
	theme.set_color("font_color", "Button", Color("f3ead8"))
	_root.theme = theme


func update_state(state: Dictionary) -> void:
	_state = state
	money_label.text = "%d Denare · %d Jahre" % [int(state.resources.denarii), int(state.player.age)]
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
	var view: Dictionary = Trade.view(_state, shop_id)
	if inventory_open:
		modal_title.text = "Dein Beutel"
		var skills: Dictionary = view.get("skills", {})
		var bonuses: Dictionary = view.get("equipment_bonuses", {})
		var learned := _label("Erfahrung aus Einsätzen: Kampf %d · Abwehr %d · Kommando %d" % [int(skills.get("combat", 0)), int(skills.get("defense", 0)), int(skills.get("command", 0))], 18)
		learned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(learned)
		var equipment := _label("Ausrüstung: Angriff +%d · Schutz +%d · Kommando +%d" % [int(bonuses.get("attack", 0)), int(bonuses.get("defense", 0)), int(bonuses.get("command", 0))], 18)
		equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(equipment)
		contents.add_child(HSeparator.new())
		var item_count := 0
		for item: Dictionary in view.get("inventory", []):
			item_count += 1
			var row := HBoxContainer.new()
			var label := _label("%s × %d" % [item.name, int(item.quantity)], 18)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(label)
			if item.get("can_consume", false):
				row.add_child(_button("Verbrauchen", func(): command_requested.emit("city_consume", {"item_id":item.item_id})))
			if item.get("can_equip", false):
				var b := _button("Angelegt" if item.get("equipped", false) else "Anlegen", func(): command_requested.emit("city_equip", {"item_id":item.item_id}))
				b.disabled = item.get("equipped", false)
				row.add_child(b)
			contents.add_child(row)
		if item_count == 0:
			contents.add_child(_label("Dein Beutel ist leer.", 18))
		return
	modal_title.text = "Handel"
	for shop: Dictionary in view.get("shops", []):
		if shop.id == shop_id:
			modal_title.text = shop.name
	for offer: Dictionary in view.get("offers", []):
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		var label := _label("%s · %d Denare" % [offer.name, int(offer.price)], 20)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		card.add_child(_label("Vorrat: %d · In deinem Beutel: %d" % [int(offer.stock), int(offer.owned)], 16))
		var row := HBoxContainer.new()
		var buy := _button("Kaufen", func(): command_requested.emit("city_buy", {"shop_id":shop_id, "item_id":offer.item_id, "quantity":1}))
		buy.disabled = not bool(offer.get("can_buy", false))
		row.add_child(buy)
		var sell := _button("Verkaufen · %d" % int(offer.sell_price), func(): command_requested.emit("city_sell", {"shop_id":shop_id, "item_id":offer.item_id, "quantity":1}))
		sell.disabled = not bool(offer.get("can_sell", false))
		row.add_child(sell)
		card.add_child(row)
		if not str(offer.get("reason", "")).is_empty():
			var reason := _label(str(offer.reason), 16)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(reason)
		contents.add_child(card)
	if shop_id == "armorer":
		contents.add_child(HSeparator.new())
		var service: Dictionary = view.get("service", {})
		var service_button := _button("Grundausrüstung erhalten · kostenlos", func(): command_requested.emit("city_issue_service", {"shop_id":"armorer"}))
		service_button.disabled = not bool(service.get("eligible", false))
		contents.add_child(service_button)
		var note := _label(str(service.get("reason", "Die Ausgabe folgt der abgeschlossenen erwachsenen Ausbildung.")), 16)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(note)
		for reward: Dictionary in view.get("rewards", []):
			var button := _button(str(reward.get("name", reward.get("id", "Belohnung"))), func(): command_requested.emit("city_claim_reward", {"shop_id":"armorer", "reward_id":str(reward.get("reward_id", reward.get("id", "")))}))
			button.disabled = not bool(reward.get("eligible", false))
			contents.add_child(button)
			var reason := _label(str(reward.get("reason", "")), 16)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			contents.add_child(reason)

