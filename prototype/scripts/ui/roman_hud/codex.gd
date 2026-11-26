extends RefCounted
## "Dein Lebensweg": chronicle, equipment and bag, abilities and people in one
## tabbed tablet. View only - every consequential change keeps going through
## the WorldModel (market, dialogue, village panel). It shows only what the
## saved state actually knows (HB 3.0: Charakterblatt "nur soweit bekannt").
## A child sees no weapon slot and no troop or morale (HB 3.0 S. 13 and S. 44).

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const CombatActions = preload("res://scripts/domain/combat_actions.gd")
const Trade = preload("res://scripts/city_trade.gd")
const TradeCatalog = preload("res://scripts/city_trade_catalog.gd")

const RaidInvestigation = preload("res://scripts/story/raid_investigation.gd")
const TABS := [["chronicle", "Chronik", "chronicle"], ["equipment", "Ausrüstung", "pouch"], ["abilities", "Fähigkeiten", "ability"], ["people", "Menschen", "family"]]
const SLOT_NAMES := {"head": "Kopf", "body": "Körper", "belt": "Gürtel", "hand": "In der Hand", "weapon": "Waffe", "shield": "Schild"}


static func build(ui, state: Dictionary, tab: String) -> Dictionary:
	var screen: Control = ui._screen
	var area: Vector2 = ui._area()
	var reduce_motion: bool = ui._reduce_motion
	var margin := clampf(minf(area.x, area.y) * 0.04, 10.0, 40.0)
	var panel := PanelContainer.new()
	panel.name = "LifeCodex"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Style.plaque(true, Vector4(22, 16, 22, 16), 0.92))
	var width := minf(area.x - margin * 2.0, 1080.0)
	panel.position = Vector2((area.x - width) * 0.5, margin)
	panel.size = Vector2(width, area.y - margin * 2.0)
	screen.add_child(panel)
	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	# Header: kicker, title of the open tab and the way back to the game.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	titles.add_child(Style.kicker("DEIN LEBENSWEG", Style.TYPE_MICRO + 1))
	var tabs := TABS.duplicate(true)
	var case_view := RaidInvestigation.view(state)
	if case_view.visible:
		tabs.append(["investigation","Ermittlungen","chronicle"])
	elif tab == "investigation":
		tab = "chronicle"
	var tab_title := "Chronik"
	for entry: Array in tabs:
		if entry[0] == tab:
			tab_title = entry[1]
	var heading := Style.label(tab_title, 28 if area.y >= 560 else 22, Style.AURUM_LIGHT, true, 2)
	heading.name = "CodexTitle"
	titles.add_child(heading)
	var resume := Button.new()
	resume.text = "Weiterspielen"
	resume.name = "CodexResume"
	Style.style_plaque_button(resume, true, Style.TYPE_CAPTION + 1)
	resume.custom_minimum_size = Vector2(0, Style.TOUCH_MIN)
	resume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(func():
		ui._play_click()
		ui._emit("resume"))
	header.add_child(resume)
	# Tab rail.
	var rail := HFlowContainer.new()
	rail.name = "CodexTabs"
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	rail.add_theme_constant_override("h_separation", 6)
	rail.add_theme_constant_override("v_separation", 6)
	layout.add_child(rail)
	var active_tab: Button
	for entry: Array in tabs:
		var id: String = entry[0]
		var button := Button.new()
		button.text = entry[1]
		button.name = "CodexTab_" + id
		button.icon = Icons.texture(entry[2], roundi(18 * maxf(1.0, ui._screen_scale)), 1.6)
		button.expand_icon = false
		Style.style_plaque_button(button, false, Style.TYPE_CAPTION + 1, id == tab)
		button.custom_minimum_size = Vector2(0, Style.TOUCH_MIN)
		button.set_meta("codex_tab", id)
		button.pressed.connect(func():
			ui._play_click()
			ui._show_journal(false, id))
		rail.add_child(button)
		if id == tab:
			active_tab = button
	layout.add_child(Kit.Rule.new())
	var scroll := ScrollContainer.new()
	scroll.name = "CodexScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var two_columns := width >= 760.0
	match tab:
		"equipment": _equipment(column, state, two_columns)
		"abilities": _abilities(column, state, two_columns)
		"people": _people(ui, column, state)
		"investigation": _investigation(column, case_view)
		_: _chronicle(ui, column, state)
	Style.reveal(panel, reduce_motion, 0.0, Vector2.ZERO)
	Style.reveal(column, reduce_motion, 0.08, Vector2.ZERO)
	return {"panel": panel, "scroll": scroll, "resume": resume, "tab": active_tab}


static func _text(column: Control, value: String, size := Style.TYPE_BODY, color := Style.CHARTA) -> Label:
	var item := Style.label(value, size, color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(item)
	return item


static func _card(column: Control, accent := false) -> VBoxContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.022, 0.016, 0.55)
	box.border_color = Color(Style.AURUM, 0.5) if accent else Color(0.55, 0.42, 0.25, 0.45)
	box.set_border_width_all(1)
	box.border_width_left = 3 if accent else 1
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", box)
	column.add_child(card)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	return inner


# --- Chronik ----------------------------------------------------------------

static func _chronicle(ui, column: VBoxContainer, state: Dictionary) -> void:
	var objective: Array = ui._objective(state)
	var player: Dictionary = state.get("player", {})
	var companion: Dictionary = state.get("companion", {})
	var current := _card(column, true)
	current.add_child(Style.kicker("DEIN NÄCHSTER SCHRITT"))
	var title := Style.label(str(objective[0]), Style.TYPE_TITLE, Style.CHARTA, true, 1)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current.add_child(title)
	_text(current, str(objective[1]), Style.TYPE_BODY, Style.CHARTA_MUTED)
	var life := _card(column)
	life.add_child(Style.kicker("LEBEN"))
	var companion_line := "%s: %s" % [ui._companion_name(state), "Vertrauen %+d" % int(companion.get("trust", 0)) if bool(companion.get("met", false)) else "noch nicht kennengelernt"]
	if Childhood.enabled(state):
		# A child has a family and carries things - no troop, no morale.
		var child_view: Dictionary = state.get("childhood_view", {})
		var carried: Array = child_view.get("carried", [])
		var stock: Dictionary = state.get("resources", {})
		_text(life, "%d Jahre · Leben %d / 100" % [int(player.get("age", 12)), int(player.get("health", 100))], Style.TYPE_LEAD)
		_text(life, ui._family_line(state).replace("\n", " · "))
		_text(life, companion_line, Style.TYPE_BODY, Style.CHARTA_MUTED)
		_text(life, "Du trägst: " + (", ".join(carried) if not carried.is_empty() else "nichts"))
		_text(life, "Vorrat des Hauses: %d Holz · %d Getreide · Denare: %d" % [int(stock.get("wood", 0)), int(stock.get("grain", 0)), int(stock.get("denarii", 0))], Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED)
	else:
		var squad: Dictionary = state.get("squad", {})
		_text(life, "%d Jahre · Leben %d / 100" % [int(player.get("age", 12)), int(player.get("health", 100))], Style.TYPE_LEAD)
		_text(life, "Truppe: %d / %d am Leben · Moral %d" % [int(squad.get("alive", 0)), int(squad.get("recruits", 0)), int(squad.get("morale", 0))])
		_text(life, companion_line, Style.TYPE_BODY, Style.CHARTA_MUTED)
	var report: String = ui._region_report()
	if not report.is_empty():
		_text(_card(column), report)
	var portraits := _card(column)
	portraits.add_child(Style.kicker("GESICHTER DEINES WEGES"))
	ui._add_journal_portraits(portraits)
	var entries: Array = state.get("chronicle", [])
	if not entries.is_empty():
		column.add_child(Kit.heading("Chronik"))
		for index in range(entries.size() - 1, -1, -1):
			var entry: Variant = entries[index]
			var line := str(entry.get("text", "")) if entry is Dictionary else str(entry)
			if line.is_empty():
				continue
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 10)
			column.add_child(row)
			var mark := Style.label("◆", Style.TYPE_MICRO, Color(Style.AURUM, 0.8))
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(mark)
			var text := Style.label(line, Style.TYPE_BODY, Style.CHARTA_MUTED)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text)
	column.add_child(Kit.heading("Bedienung"))
	var controls := "Links bewegen. Rechts im freien Bild umsehen. Gehen und Laufen mit der Temposchaltfläche wechseln. Unter Techniken eine Bewegung wählen, dann mit Schlag ausführen. Vorhaben öffnet Bau und Ausbildung. Der Kompass oben zeigt dein Ziel; antippen öffnet die Ortskarte." if ui._touch_enabled else "WASD bewegen · E interagieren · Linksklick / Leertaste kämpfen · B bauen · Tab Stadt · M Karte · Kompass anklicken: Ortskarte"
	_text(column, controls, Style.TYPE_CAPTION + 1, Style.BRONZE.lightened(0.25))


# --- Ausrüstung -------------------------------------------------------------

static func equipment_view(state: Dictionary) -> Dictionary:
	var child := Childhood.enabled(state) and int(state.get("player", {}).get("age", 12)) < 18
	var slots := {}
	var bag: Array[Dictionary] = []
	var trade: Dictionary = Trade.view(state) if Trade.enabled(state) else {}
	var equipped_ids := {}
	if not trade.is_empty() and trade.get("error", "") == "":
		var equipment: Dictionary = state.village.city_trade.get("equipment", {})
		for slot: String in equipment:
			var id := str(equipment[slot])
			if id.is_empty() or not TradeCatalog.ITEMS.has(id):
				continue
			if child and slot in ["weapon", "shield"]:
				continue
			slots[slot] = {"name": str(TradeCatalog.ITEMS[id].name), "glyph": Icons.item_kind(id), "detail": _bonus_text(TradeCatalog.ITEMS[id])}
			equipped_ids[id] = true
		for item: Dictionary in trade.get("inventory", []):
			var detail := "angelegt" if equipped_ids.has(str(item.item_id)) else ""
			var catalog: Dictionary = TradeCatalog.ITEMS.get(str(item.item_id), {})
			if int(catalog.get("health", 0)) > 0 or float(catalog.get("stamina", 0.0)) > 0.0:
				detail = "Stärkt: +%d Leben · +%d Ausdauer" % [int(catalog.get("health", 0)), roundi(float(catalog.get("stamina", 0.0)))]
			bag.append({"name": str(item.name), "quantity": int(item.quantity), "glyph": Icons.item_kind(str(item.item_id), str(item.name)), "detail": detail})
	if not child and CombatActions.service_gear(state):
		if not slots.has("weapon"):
			slots["weapon"] = {"name": "Gladius", "glyph": "gladius", "detail": "Dienstausrüstung"}
		if not slots.has("shield"):
			slots["shield"] = {"name": "Scutum", "glyph": "shield", "detail": "Dienstausrüstung"}
	if Childhood.enabled(state):
		var view: Dictionary = state.get("childhood_view", {})
		for name: String in view.get("loaned_items", []):
			var key := "head" if name.to_lower().contains("helm") else "hand_loan"
			if key == "head":
				slots["head"] = {"name": name, "glyph": "helmet", "detail": "geliehen für die Wachhilfe"}
			else:
				bag.append({"name": name, "quantity": 1, "glyph": Icons.item_kind("", name), "detail": "geliehen für die Wachhilfe"})
		var carried: Array = view.get("carried", [])
		if not carried.is_empty():
			slots["hand"] = {"name": ", ".join(carried), "glyph": Icons.item_kind("", ", ".join(carried)), "detail": "trägst du gerade"}
	var order: Array = ["head", "body", "belt", "hand"] if child else ["head", "body", "belt", "weapon", "shield", "hand"]
	return {"child": child, "slots": slots, "order": order, "bag": bag, "market": not trade.is_empty()}


static func _bonus_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	for pair: Array in [["attack", "Angriff"], ["defense", "Schutz"], ["command", "Kommando"]]:
		if int(item.get(pair[0], 0)) > 0:
			parts.append("%s +%d" % [pair[1], int(item[pair[0]])])
	return " · ".join(parts)


static func _equipment(column: VBoxContainer, state: Dictionary, two_columns: bool) -> void:
	var view := equipment_view(state)
	var split: BoxContainer = HBoxContainer.new() if two_columns else VBoxContainer.new()
	split.mouse_filter = Control.MOUSE_FILTER_PASS
	split.add_theme_constant_override("separation", 24)
	column.add_child(split)
	var worn := VBoxContainer.new()
	worn.mouse_filter = Control.MOUSE_FILTER_PASS
	worn.add_theme_constant_override("separation", 8)
	worn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(worn)
	worn.add_child(Kit.heading("Am Körper"))
	var figure_row := HBoxContainer.new()
	figure_row.mouse_filter = Control.MOUSE_FILTER_PASS
	figure_row.add_theme_constant_override("separation", 14)
	worn.add_child(figure_row)
	var doll := Kit.PaperDoll.new()
	doll.name = "EquipmentFigure"
	doll.child = view.child
	doll.custom_minimum_size = Vector2(120, 260)
	figure_row.add_child(doll)
	var slots := VBoxContainer.new()
	slots.name = "EquipmentSlots"
	slots.mouse_filter = Control.MOUSE_FILTER_PASS
	slots.add_theme_constant_override("separation", 6)
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure_row.add_child(slots)
	for slot: String in view.order:
		var item: Dictionary = view.slots.get(slot, {})
		var caption: String = SLOT_NAMES[slot]
		var card := Kit.item_card("%s · %s" % [caption, item.name] if not item.is_empty() else caption, str(item.get("detail", "frei")), str(item.get("glyph", {"head": "helmet", "body": "garment", "belt": "belt", "hand": "interact", "weapon": "gladius", "shield": "shield"}[slot])), item.is_empty())
		card.name = "Slot_" + slot
		slots.add_child(card)
	if view.child:
		_text(worn, "Waffen gehören nicht zu deinem Alltag. Werkzeug und Leihgaben gibt dir ein Erwachsener, wenn eine Aufgabe sie braucht.", Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED)
	var pouch := VBoxContainer.new()
	pouch.name = "EquipmentBag"
	pouch.mouse_filter = Control.MOUSE_FILTER_PASS
	pouch.add_theme_constant_override("separation", 6)
	pouch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(pouch)
	pouch.add_child(Kit.heading("Beutel"))
	var grid := GridContainer.new()
	grid.columns = 2 if two_columns else 1
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	pouch.add_child(grid)
	for item: Dictionary in view.bag:
		var card := Kit.item_card(str(item.name), str(item.get("detail", "")), str(item.glyph), false, int(item.quantity))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
	if view.bag.is_empty():
		_text(pouch, "Dein Beutel ist leer.", Style.TYPE_BODY, Style.CHARTA_MUTED)
	var money := int(state.get("resources", {}).get("denarii", 0))
	if not view.child:
		var coins := Kit.item_card("Denare", "Bargeld", "coin", false, money)
		pouch.add_child(coins)
	_text(pouch, "Kaufen, Verkaufen, Anlegen und Ablegen erledigst du bei den Händlern im Marktviertel." if view.market else "Gegenstände nimmst du in der Welt auf; der Beutel zeigt, was du bei dir hast.", Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED)


# --- Fähigkeiten ------------------------------------------------------------

static func _abilities(column: VBoxContainer, state: Dictionary, two_columns: bool) -> void:
	column.add_child(Kit.heading("Erlernte Fähigkeiten"))
	var earned: Array = state.get("village", {}).get("abilities", {}).get("earned", [])
	if earned.is_empty():
		_text(column, "Noch keine. Fähigkeiten entstehen aus dem, was du tatsächlich tust und hältst.", Style.TYPE_BODY, Style.CHARTA_MUTED)
	for id: Variant in earned:
		var entry: Dictionary = Abilities.entry(str(id))
		if entry.is_empty():
			continue
		var card := Kit.item_card(str(entry.get("name", id)), str(entry.get("effect_text", "")), "ability")
		column.add_child(card)
	var attributes: Dictionary = state.get("village", {}).get("attributes", {})
	if not attributes.is_empty():
		column.add_child(Kit.heading("Anlagen"))
		var row := HFlowContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		column.add_child(row)
		for pair: Array in [["courage", "Mut"], ["combat", "Kampf"], ["insight", "Scharfsinn"], ["tactics", "Taktik"]]:
			var stat := _card(row)
			stat.get_parent().custom_minimum_size = Vector2(130, 0)
			stat.add_child(Style.kicker(str(pair[1]).to_upper()))
			stat.add_child(Style.label(str(int(attributes.get(pair[0], 0))), 26, Style.AURUM_LIGHT, true, 1))
	if Childhood.enabled(state):
		var apprenticeship := str(state.get("childhood_view", {}).get("apprenticeship", "none"))
		column.add_child(Kit.heading("Lehre"))
		_text(column, "Deine Lehre: " + apprenticeship.replace("none", "noch offen").replace("smith", "bei Sextus, dem Dorfschmied"))
	var combat: Dictionary = CombatActions.view(state) if CombatActions.enabled(state) else {}
	if not combat.is_empty():
		column.add_child(Kit.heading("Bewegungen und Techniken"))
		_text(column, "Ausdauer %d / 100 · %d kontrollierte Übungstreffer" % [int(combat.get("stamina", 100)), int(combat.get("practice_hits", 0))], Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED)
		var grid := GridContainer.new()
		grid.columns = 2 if two_columns else 1
		grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		column.add_child(grid)
		for technique: Dictionary in combat.get("techniques", []):
			var available := bool(technique.get("available", false))
			var needed := int(technique.get("practice", 0))
			var detail := "%d Ausdauer" % int(technique.get("cost", 0))
			if not available:
				detail += " · erlernbar ab %d Übungstreffern (%d / %d)" % [needed, mini(int(combat.get("practice_hits", 0)), needed), needed]
			var card := Kit.item_card(str(technique.get("label", technique.get("id", ""))), detail, "gladius" if CombatActions.is_armed(str(technique.get("id", ""))) else "attack", not available)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(card)
	if Trade.enabled(state) and int(state.get("player", {}).get("age", 12)) >= 18:
		var skills: Dictionary = Trade.skills(state)
		column.add_child(Kit.heading("Erfahrung aus Einsätzen"))
		_text(column, "Kampf %d · Abwehr %d · Kommando %d" % [int(skills.get("combat", 0)), int(skills.get("defense", 0)), int(skills.get("command", 0))])


# --- Menschen ---------------------------------------------------------------

static func people_view(ui, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var companion: Dictionary = state.get("companion", {})
	if bool(companion.get("met", false)):
		result.append({"name": ui._companion_name(state), "role": "Freund und Gefährte", "trust": int(companion.get("trust", 0)), "ally": false, "group": "Freunde"})
	if Childhood.enabled(state):
		var relations: Dictionary = state.get("childhood_view", {}).get("relationships", {})
		for id: String in relations:
			var bond: Dictionary = relations[id]
			if not bool(bond.get("met", false)):
				continue
			var spec: Dictionary = Childhood.EXTRA_NPCS.get(id, Childhood.NEIGHBORS.get(id, Life.NPCS.get(id, {})))
			var group := "Familie" if id in ["julia", "silvanus"] else "Dorf"
			result.append({"name": Childhood.display_name(state, id, str(spec.get("name", id.capitalize()))), "role": str(spec.get("role", "")), "trust": int(bond.get("trust", 0)), "ally": bool(bond.get("ally", false)), "group": group})
	elif state.get("village", {}).get("enabled", false):
		for npc: Dictionary in Life.npc_catalog(state):
			var bond: Dictionary = Life.relationship(state, str(npc.id))
			if bool(bond.get("met", false)):
				result.append({"name": str(npc.name), "role": str(npc.get("role", "")), "trust": int(bond.get("trust", 0)), "ally": bool(bond.get("ally", false)), "group": "Dorf"})
	return result


static func _people(ui, column: VBoxContainer, state: Dictionary) -> void:
	var people := people_view(ui, state)
	if people.is_empty():
		_text(column, "Du hast noch niemanden näher kennengelernt.", Style.TYPE_BODY, Style.CHARTA_MUTED)
		return
	for group: String in ["Familie", "Freunde", "Dorf"]:
		var members: Array[Dictionary] = []
		for person: Dictionary in people:
			if person.group == group:
				members.append(person)
		if members.is_empty():
			continue
		column.add_child(Kit.heading(group))
		for person: Dictionary in members:
			var card := _card(column, group == "Familie")
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)
			var names := VBoxContainer.new()
			names.mouse_filter = Control.MOUSE_FILTER_IGNORE
			names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(names)
			names.add_child(Style.label(str(person.name), Style.TYPE_LEAD, Style.CHARTA, true, 1))
			if not str(person.role).is_empty():
				names.add_child(Style.label(str(person.role), Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED))
			var trust := int(person.trust)
			var bond := Style.label(("Vertrauen %+d" % trust) + (" · verbündet" if person.ally else ""), Style.TYPE_BODY, Style.AERUGO if trust > 0 else Style.CHARTA_MUTED)
			bond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bond)
	_text(column, "Vertrauen wächst durch gehaltene Zusagen und echte Hilfe. Es zeigt nur, was du selbst erlebt hast.", Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED)


static func _investigation(column: VBoxContainer, case_view: Dictionary) -> void:
	var intro := _card(column, true)
	intro.add_child(Style.kicker("ERMITTLUNGEN"))
	_text(intro,str(case_view.title),Style.TYPE_TITLE)
	_text(intro,"Beobachtungen und Aussagen bleiben getrennt. Vergleiche widersprüchliche Hinweise im Gespräch mit Decimus.",Style.TYPE_BODY,Style.CHARTA_MUTED)
	for clue: Dictionary in case_view.clues:
		var card := _card(column)
		card.add_child(Style.kicker("HINWEIS · " + str(clue.reliability).to_upper()))
		_text(card,str(clue.title),Style.TYPE_TITLE)
		_text(card,str(clue.text))
		_text(card,str(clue.source_label),Style.TYPE_CAPTION,Style.CHARTA_MUTED)
	for conclusion: Dictionary in case_view.deductions:
		var card := _card(column,true)
		card.add_child(Style.kicker("SCHLUSSFOLGERUNG · " + str(conclusion.strength).to_upper()))
		_text(card,str(conclusion.title),Style.TYPE_TITLE)
		_text(card,str(conclusion.text))
