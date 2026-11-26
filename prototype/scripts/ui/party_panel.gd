extends RefCounted
## Touch wheel and individual folio. All decisions return to the campaign command handler.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const Portrait = preload("res://scripts/ui/party_portrait.gd")
const ORDERS := {"follow":"Folgen", "wait":"Warten", "assist":"Helfen", "home":"Heimweg"}
const TASKS := {"guide":"Weg zeigen", "carry":"Last tragen", "watch":"Ausblick halten", "aid":"Beistehen"}
const LESSONS := {"perception":"Wahrnehmung", "endurance":"Ausdauer"}
const SPECIALITIES := {"healing":"Heilkunde", "navigation":"Ortskenntnis"}
const ITEMS := {"walking_staff":"Wanderstab", "wool_cloak":"Wollumhang", "leather_belt":"Ledergürtel", "linen_tunic":"Leinentunika", "bronze_brooch":"Bronzefibel"}


class BronzeWheel extends Control:
	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(center.x, center.y) * 0.68
		draw_circle(center, radius, Color("211e19ed"), true, -1.0, true)
		draw_arc(center, radius, 0, TAU, 96, Style.BRONZE, 2.0, true)
		draw_arc(center, radius - 6, 0, TAU, 96, Color(Style.AURUM, .36), 1.0, true)
		for index in 4:
			var axis := Vector2.from_angle(TAU * index / 4 + PI / 4)
			draw_line(center + axis * 24.0, center + axis * (radius - 8.0), Color(Style.BRONZE, .45), 1.0, true)


static func _button(ui, parent: Control, title: String, callback: Callable, primary := false) -> Button:
	var button: Button = ui._list_button(title, callback, primary)
	button.custom_minimum_size.y = Style.TOUCH_MIN
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.name = title.validate_node_name()
	parent.add_child(button)
	return button


static func _picker(parent: Control, members: Array, selected: String, all: bool, callback: Callable) -> OptionButton:
	var picker := OptionButton.new()
	picker.name = "PartyTarget"
	picker.custom_minimum_size.y = Style.TOUCH_MIN
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.style_plaque_button(picker, false, 17)
	if all:
		picker.add_item("Alle Mitreisenden")
		picker.set_item_metadata(0, "all")
	for person: Dictionary in members:
		var index := picker.item_count
		picker.add_item(str(person.name))
		picker.set_item_metadata(index, person.actor_uid)
		if str(person.actor_uid) == selected:
			picker.select(index)
	if all:
		var leaders := {}
		for person: Dictionary in members:
			if person.has("deputy"):
				leaders[person.deputy] = true
		for person: Dictionary in members:
			if leaders.has(person.actor_uid):
				var index := picker.item_count
				picker.add_item("Gruppe um " + str(person.name))
				picker.set_item_metadata(index,"group:" + str(person.actor_uid))
				if selected == picker.get_item_metadata(index):
					picker.select(index)
	picker.item_selected.connect(func(index: int): callback.call(str(picker.get_item_metadata(index))))
	parent.add_child(picker)
	return picker


static func _members(data: Dictionary) -> Array:
	var joined: Array = []
	for person: Dictionary in data.get("members", []):
		if person.get("status", "") == "active":
			joined.append(person)
	return joined


static func show_wheel(ui, data: Dictionary) -> void:
	ui._open_screen("party_wheel", true)
	var column: VBoxContainer = ui._modal("GEFOLGSCHAFT", "Um Hilfe bitten", "", 500)
	var members := _members(data)
	if members.is_empty():
		_text(column, "Du reist allein. Sprich in Valdora mit Marcus oder Silvanus über einen gemeinsamen Weg.")
	else:
		var selector := _picker(column, members, ui.party_target, true, func(value: String): ui.party_target = value)
		ui.party_target = str(selector.get_item_metadata(selector.selected))
		var wheel := BronzeWheel.new()
		wheel.name = "OrderWheel"
		wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wheel.custom_minimum_size.y = 226
		wheel.resized.connect(wheel.queue_redraw)
		column.add_child(wheel)
		var slots := {"follow":Vector2(.5,.12), "wait":Vector2(.78,.5), "home":Vector2(.5,.88), "assist":Vector2(.22,.5)}
		for order: String in ORDERS:
			var button := _button(ui, wheel, ORDERS[order], func(): ui._emit("party_command", {"command":"party_order", "args":{"actor_uid":ui.party_target, "order":order}}))
			button.name = "Order_" + order
			button.set_anchors_preset(Control.PRESET_TOP_LEFT)
			button.anchor_left = slots[order].x
			button.anchor_right = slots[order].x
			button.anchor_top = slots[order].y
			button.anchor_bottom = slots[order].y
			button.offset_left = -58
			button.offset_right = 58
			button.offset_top = -24
			button.offset_bottom = 24
	var controls := _flow(column)
	if not members.is_empty() or not data.get("allegiance",{}).is_empty():
		_button(ui, controls, "Gefährten ansehen", ui._emit.bind("party_folio", {}), true)
	_button(ui, controls, "Zurück ins Spiel", ui._emit.bind("resume", {}))


static func show_folio(ui, data: Dictionary, figures: Dictionary, feedback: String) -> void:
	ui._open_screen("party_folio", true)
	var members := _members(data)
	var column: VBoxContainer = ui._modal("GEFOLGSCHAFT", "Deine Gefährten", "", 780)
	if not feedback.is_empty():
		_text(column, feedback)
	if members.is_empty():
		_show_allegiance(ui,column,data)
		_text(column, "Zurzeit reist niemand mit dir.")
		_button(ui, column, "Zurück ins Spiel", ui._emit.bind("resume", {}))
		return
	var picker := _picker(column, members, ui.party_target, false, func(value: String):
		ui.party_target = value
		ui._emit("party_folio", {}))
	var uid := str(picker.get_item_metadata(picker.selected))
	ui.party_target = uid
	var person: Dictionary = members[picker.selected]
	var row := BoxContainer.new()
	row.vertical = ui._area().x < 520.0
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	if is_instance_valid(figures.get(uid)):
		var portrait := Portrait.new()
		portrait.name = "PartyPortrait"
		row.add_child(portrait)
		portrait.build(figures[uid])
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	_text(details, "%s · %d Jahre" % [person.name, int(person.age)], 22)
	_text(details, str(person.get("personality", "")))
	_text(details, "Vertrauen %s  ·  Moral %s  ·  Gesundheit %s" % [person.trust, person.morale, person.health])
	var location = person.get("location", "")
	if location is Array and location.size() >= 2:
		location = "Valdora · %.0f / %.0f" % [location[0], location[-1]]
	_text(details, str(location))
	_text(details, "Proviant für %d Tage  ·  %d Denare pro Tag" % [int(person.rations), int(person.wage)])
	var order := str(person.get("order", ""))
	var task := str(person.get("assignment", ""))
	_text(details, "%s · %s" % [ORDERS.get(order, "Übt am Platz" if order == "train" else order), TASKS.get(task, "Ohne Aufgabe")])
	column.add_child(Kit.heading("Aufgaben"))
	var tasks := _flow(column)
	for id: String in TASKS:
		var give := _action(ui, tasks, TASKS[id], "party_assign", {"actor_uid":uid,"assignment":id})
		give.disabled = id == task
	if members.size() > 1:
		var teams := _flow(column)
		for other: Dictionary in members:
			if other.actor_uid != uid and not other.has("deputy") and other.order != "home":
				var delegate := _action(ui,teams,"Mit " + str(other.name) + " reisen","party_delegate",{"actor_uid":uid,"leader_uid":other.actor_uid})
				delegate.disabled = person.get("deputy","") == other.actor_uid
		if person.has("deputy"):
			_action(ui,teams,"Direkt mit mir reisen","party_delegate",{"actor_uid":uid,"leader_uid":"player"})
	column.add_child(Kit.heading("Gepäck und Proviant"))
	var gear := _flow(column)
	_action(ui, gear, "Eine Ration geben", "party_supply", {"actor_uid":uid,"quantity":1})
	var equipment: Dictionary = person.get("equipment", {})
	var options: Array = person.get("items", []).duplicate()
	for value in equipment.values():
		if value not in options:
			options.append(value)
	for value in options:
		var id := str(value)
		if ITEMS.has(id):
			var label := str(ITEMS[id]) + (" zurücknehmen" if value in equipment.values() else " geben")
			_action(ui, gear, label, "party_equip", {"actor_uid":uid,"item_id":id})
	column.add_child(Kit.heading("Am Übungsplatz"))
	var skills: Dictionary = person.get("skills", {})
	var skill_lines := PackedStringArray()
	for id: String in skills:
		if int(skills[id]) > 0:
			skill_lines.append("%s %d" % [LESSONS.get(id, SPECIALITIES.get(id, id.capitalize())), int(skills[id])])
	if not skill_lines.is_empty():
		_text(column, " · ".join(skill_lines))
	var training := _flow(column)
	for skill: String in LESSONS:
		_action(ui, training, str(LESSONS[skill]) + " üben", "party_train", {"actor_uid":uid,"skill":skill})
	var memories: Array = person.get("memories", [])
	if not memories.is_empty():
		column.add_child(Kit.heading("Gemeinsame Erinnerungen"))
		for memory in memories.slice(-3):
			if memory is String:
				_text(column, memory)
			elif memory is Dictionary:
				_text(column, str(memory.get("text", memory.get("label", ""))))
	_show_allegiance(ui,column,data)
	var controls := _flow(column)
	_button(ui, controls, "Befehlsrad", ui._emit.bind("party_wheel", {}))
	_action(ui, controls, "Getrennte Wege vereinbaren", "party_dismiss", {"actor_uid":uid})
	_button(ui, controls, "Zurück ins Spiel", ui._emit.bind("resume", {}), true)


static func _show_allegiance(ui, column: Control, data: Dictionary) -> void:
	var view: Dictionary = data.get("allegiance",{})
	if view.is_empty():
		return
	column.add_child(Kit.heading("Öffentliche Zugehörigkeit · " + str(view.label)))
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = Style.TOUCH_MIN
	Style.style_plaque_button(picker,false,17)
	for choice: Dictionary in view.options:
		picker.add_item(str(choice.label))
	column.add_child(picker)
	var reason := Style.label("",16,Style.CHARTA)
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reason)
	var submit := _button(ui,column,"Entscheidung bestätigen",func():
		var choice: Dictionary = view.options[picker.selected]
		ui._emit("party_command",{"command":choice.cmd,"args":{"target":choice.target}}))
	var select := func(i: int):
		var why: String = view.options[i].reason
		reason.text = why
		submit.disabled = not why.is_empty()
	picker.item_selected.connect(select)
	select.call(picker.selected)


static func _action(ui, parent: Control, title: String, command: String, args: Dictionary) -> Button:
	return _button(ui, parent, title, ui._emit.bind("party_command", {"command":command,"args":args}))


static func _flow(column: Control) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	column.add_child(flow)
	return flow


static func _text(parent: Control, value: String, size := 16) -> void:
	if value.is_empty():
		return
	var label := Style.label(value, size, Style.AURUM_LIGHT if size >= 20 else Style.CHARTA, size >= 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
