extends RefCounted
## View-only panels: every consequential choice returns through the WorldModel.

const Economy = preload("res://scripts/domain/village_economy.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const NpcBehavior = preload("res://scripts/domain/npc_behavior.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const WorldClock = preload("res://scripts/domain/world_clock.gd")
const AGE_WORDS := {12: "zwölf", 13: "dreizehn", 14: "vierzehn", 15: "fünfzehn", 16: "sechzehn", 17: "siebzehn"}

const TAB_GLYPHS := {"overview": "village", "work": "projects", "people": "family", "map": "map"}


## Regional map drawn like a surveyor's tablet: inked ground, bronze frame,
## roads as engraved lines, the inhabited village gilded, planned places pale.
class RegionalMap extends Control:
	var position_world := Vector3.ZERO
	var places: Array = []
	var roads: Array = []
	func _ready() -> void:
		custom_minimum_size = Vector2(260, 300)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func point(world: Array) -> Vector2:
		return Vector2(18, 14) + Vector2((float(world[0]) + 16000) / 32000.0, (float(world[2]) + 16000) / 32000.0) * (size - Vector2(36, 28))
	func _draw() -> void:
		var frame := Rect2(Vector2.ZERO, size)
		draw_rect(frame, Color(0.085, 0.07, 0.052))
		# Survey grid: eight by eight fields of four kilometres.
		var field := Rect2(Vector2(18, 14), size - Vector2(36, 28))
		draw_rect(field, Color(0.13, 0.115, 0.085))
		for index in range(0, 9):
			var x := field.position.x + field.size.x * index / 8.0
			var y := field.position.y + field.size.y * index / 8.0
			draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), Color(Style.BRONZE, 0.13), 1.0)
			draw_line(Vector2(field.position.x, y), Vector2(field.end.x, y), Color(Style.BRONZE, 0.13), 1.0)
		draw_rect(frame.grow(-0.5), Color(Style.BRONZE, 0.85), false, 1.0)
		draw_rect(frame.grow(-4.5), Color(Style.BRONZE_DEEP, 0.9), false, 1.0)
		var font := Style.display_font(600, 1)
		var lookup := {}
		for place: Dictionary in places:
			lookup[place.id] = place.position
		for road: Dictionary in roads:
			if road.get("id", "") == Footpath.ROAD_ID:
				continue
			if lookup.has(road.get("from", "")) and lookup.has(road.get("to", "")):
				var from := point(lookup[road.from])
				var to := point(lookup[road.to])
				draw_line(from, to, Color(0.03, 0.02, 0.015, 0.7), 4.0, true)
				draw_line(from, to, Color(Style.BRONZE, 0.75), 1.6, true)
		var surveyed := PackedVector2Array()
		for waypoint: Array in Footpath.map_points():
			surveyed.append(point(waypoint))
		draw_polyline(surveyed, Style.AERUGO.lightened(0.25), 2.2, true)
		for place: Dictionary in places:
			var at := point(place.position)
			var inhabited: bool = place.id == "home_village"
			var workplace: bool = place.get("content_status", "") == "visible_workplace"
			if inhabited:
				draw_circle(at, 10.0, Color(Style.AURUM, 0.18))
				Style.draw_diamond(self, at, 7.5, Color(0.05, 0.03, 0.02, 0.9))
				Style.draw_diamond(self, at, 6.0, Style.AURUM)
			elif workplace:
				draw_circle(at, 4.2, Style.AERUGO.lightened(0.25))
			else:
				draw_circle(at, 4.0, Color(0.05, 0.04, 0.03, 0.9))
				draw_circle(at, 2.8, Color(Style.STONE, 0.9))
			if inhabited or workplace or place.kind in ["town", "port", "fort"]:
				var caption := str(place.name)
				var caption_size := 13 if inhabited else 11
				var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
				var origin := at + Vector2(9, -6)
				if workplace:
					origin.y -= 7.0
				if origin.x + width > size.x - 8.0:
					origin.x = at.x - 9.0 - width
				draw_string_outline(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, 3, Color(0.03, 0.02, 0.01, 0.9))
				draw_string(font, origin, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Style.AURUM_LIGHT if inhabited else Style.CHARTA_MUTED)
		var player := point([position_world.x, position_world.y, position_world.z])
		draw_circle(player, 9.0, Color(Style.AERUGO, 0.22))
		draw_arc(player, 6.0, 0.0, TAU, 24, Style.AERUGO, 1.4, true)
		draw_circle(player, 2.4, Style.AURUM_LIGHT)
		# North mark and scale: the field is 32 km wide.
		var north := Vector2(size.x - 26.0, 30.0)
		draw_line(north + Vector2(0, 12), north + Vector2(0, -8), Style.AURUM, 1.2, true)
		draw_colored_polygon(PackedVector2Array([north + Vector2(0, -13), north + Vector2(-4.5, -4), north + Vector2(4.5, -4)]), Style.AURUM)
		draw_string(font, north + Vector2(-4.5, 25), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Style.AURUM)
		var bar := field.size.x / 4.0
		var base := Vector2(field.position.x + 8.0, field.end.y - 10.0)
		draw_line(base, base + Vector2(bar, 0), Style.CHARTA_MUTED, 1.2, true)
		draw_line(base + Vector2(0, -4), base + Vector2(0, 4), Style.CHARTA_MUTED, 1.2)
		draw_line(base + Vector2(bar, -4), base + Vector2(bar, 4), Style.CHARTA_MUTED, 1.2)
		draw_string(font, base + Vector2(6, -6), "8 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.CHARTA_MUTED)


## The world date of the save (one clock for HUD, atlas and this panel).
static func _date(data: Dictionary) -> String:
	var time := WorldClock.view(data)
	return str(time.date_label) if not time.is_empty() else WorldCalendar.format_year(int(data.get("village", {}).get("history", {}).get("start_year", 100)))


static func _age_word(age: int) -> String:
	return str(AGE_WORDS.get(age, "%d Jahre alt" % age))


## Thin bronze meter for a condition or a running project.
class Meter extends Control:
	var value := 0.0
	var tint := Style.AURUM
	func _ready() -> void:
		custom_minimum_size.y = 8
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		var track := Rect2(0, 1, size.x, size.y - 2)
		draw_rect(track, Color(0.03, 0.022, 0.016, 0.9))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(value, 0.0, 1.0), track.size.y)), tint)
		draw_rect(track, Color(Style.BRONZE, 0.75), false, 1.0)


## Sizes follow the menu text scale. Twenty and above is a display heading.
static func _text(ui, column: Control, value: String, size := 16, muted := false) -> Label:
	var display := size >= 20
	var label: Label = Style.label(value, size, Style.AURUM_LIGHT if display else Style.CHARTA_MUTED if muted else Style.CHARTA, display, 1)
	label.set_meta("base_font_size", size)
	label.add_theme_font_size_override("font_size", roundi(size * ui._ui_scale))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	return label


## Inset card inside the tablet. It passes touches on, so a swipe that starts
## on a card still scrolls the panel.
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


static func _plaque(ui, button: Button, primary := false, active := false) -> void:
	Style.style_plaque_button(button, primary, roundi(float(button.get_meta("base_font_size", 15)) * ui._ui_scale), active)
	button.custom_minimum_size.y = maxf(Style.TOUCH_MIN, button.custom_minimum_size.y)


## A value with its engraved glyph, e.g. the village stock.
static func _chip(ui, row: Control, glyph: String, value: String, caption: String) -> void:
	var chip := HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_constant_override("separation", 5)
	chip.tooltip_text = caption
	row.add_child(chip)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(glyph, roundi(20 * maxf(1.0, ui._screen_scale)), 1.5)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.self_modulate = Style.AURUM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(icon)
	var label: Label = _text(ui, chip, "%s %s" % [value, caption], 15)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF


static func _action(ui, column: Control, label: String, command: String, args: Dictionary = {}, enabled := true) -> Button:
	var button: Button = ui._button(label, ui._emit.bind("village_command", {"command":command, "args":args}), false, 15)
	_plaque(ui, button)
	# Let the enclosing scroll container capture a swipe and cancel the press.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.set_meta("village_focus_id", command + ":" + JSON.stringify(args))
	column.add_child(button)
	return button


static func show(ui, data: Dictionary, tab := "overview") -> void:
	var previous_scroll := -1
	var previous_focus := ""
	if ui._view_state == "village" and ui._village_tab == tab and is_instance_valid(ui._screen):
		var old_scrolls: Array[Node] = ui._screen.find_children("*", "ScrollContainer", true, false)
		if not old_scrolls.is_empty():
			previous_scroll = old_scrolls[0].scroll_vertical
		var focused: Control = ui.get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and ui._screen.is_ancestor_of(focused):
			previous_focus = str(focused.get_meta("village_focus_id", ""))
	ui._open_screen("village", true)
	ui._village_tab = tab
	var economy: Dictionary = Economy.view(data)
	var life: Dictionary = Life.view(data)
	var column: VBoxContainer = ui._modal("DEIN LEBEN IM DORF", "Deine Familie und die Nachbarn" if Childhood.enabled(data) else "Wiederaufbau unter Decimus", "Du bist Bewohner. Vertrauen, Arbeit und gemeinsame Entscheidungen bestimmen deinen Einfluss.", 880)
	var tabs := HFlowContainer.new()
	tabs.name = "VillageTabs"
	tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	column.add_child(tabs)
	var active_tab: Button
	for entry in [["overview", "Dorfleben"], ["work", "Arbeit & Versorgung"], ["people", "Menschen & Berufe"], ["map", "Region"]]:
		var button: Button = ui._button(entry[1], ui._emit.bind("village_panel", {"tab":entry[0]}), entry[0] == tab, 14)
		_plaque(ui, button, false, entry[0] == tab)
		button.icon = Icons.texture(str(TAB_GLYPHS[entry[0]]), roundi(18 * maxf(1.0, ui._screen_scale)), 1.6)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 18)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.set_meta("village_focus_id", "tab:" + str(entry[0]))
		tabs.add_child(button)
		if entry[0] == tab:
			active_tab = button
	if not str(data.get("village_feedback", "")).is_empty():
		var notice := _card(column, true)
		notice.get_parent().name = "VillageFeedback"
		_text(ui, notice, str(data.village_feedback), 15)
	if tab == "work":
		_work(ui, column, data, economy)
	elif tab == "people":
		_people(ui, column, data, life)
	elif tab == "map":
		_map(ui, column, data)
	else:
		_overview(ui, column, data, economy, life)
	var close: Button = ui._button("Zurück ins Dorf", ui._emit.bind("resume", {}), true)
	_plaque(ui, close, true)
	close.mouse_filter = Control.MOUSE_FILTER_PASS
	close.set_meta("village_focus_id", "close")
	column.add_child(close)
	_restore_position.call_deferred(column, active_tab, previous_scroll, previous_focus)


static func _restore_position(column: VBoxContainer, active_tab: Button, offset: int, focus_id: String) -> void:
	if not is_instance_valid(column) or not column.is_inside_tree():
		return
	var scroll := column.get_parent() as ScrollContainer
	if scroll == null:
		return
	var target: Control = active_tab if offset < 0 else null
	if not focus_id.is_empty():
		for control: Node in column.find_children("*", "Control", true, false):
			if str(control.get_meta("village_focus_id", "")) == focus_id:
				target = control as Control
				break
	# Rebuilding a selector must retain the player's place in a long work list.
	# Initial entry instead focuses its tab, keeping the overview visible.
	scroll.follow_focus = false
	if is_instance_valid(target):
		target.grab_focus()
	scroll.scroll_vertical = maxi(0, offset)
	scroll.follow_focus = true


static func _flow(column: Control, separation := 14) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("h_separation", separation)
	row.add_theme_constant_override("v_separation", 8)
	column.add_child(row)
	return row


static func _overview(ui, column: VBoxContainer, data: Dictionary, economy: Dictionary, life: Dictionary) -> void:
	if Childhood.enabled(data):
		var chapter := Childhood.view(data)
		var today := _card(column, true)
		today.add_child(Style.kicker("%s  ·  DORFTAG %d  ·  DU BIST %s" % [_date(data), int(chapter.get("day", 1)), _age_word(int(data.player.age))]))
		_text(ui, today, str(chapter.get("title", "Ein Morgen zu Hause")), 22)
		_text(ui, today, str(chapter.get("objective", "")), 18)
		_text(ui, today, "Der nächste Tag beginnt, wenn du zu Hause bewusst schlafen gehst.", 14, true)
		if not chapter.get("carried", []).is_empty():
			column.add_child(Kit.heading("Bei dir"))
			_text(ui, column, ", ".join(chapter.carried), 16)
		column.add_child(Kit.heading("Lehre und Fähigkeiten"))
		_text(ui, column, "Deine Lehre: " + str(chapter.get("apprenticeship", "none")).replace("none", "noch offen").replace("smith", "bei Sextus"), 16)
		_abilities(ui, column, data)
		column.add_child(Kit.heading("Dein Dorf"))
		_text(ui, column, "Deine Mutter Julia und dein Vater Silvanus warten an eurem Haus. Die Karte zeigt das Ziel deines nächsten Auftrags. Zum Kennenlernen und Helfen gehst du zu den Menschen.", 15, true)
		_text(ui, column, "Ansehen wächst durch gehaltene Zusagen. Decimus führt das Dorf; deine Aufgaben gehören zu deinem eigenen Lebensweg.", 15, true)
		return
	var today := _card(column, true)
	today.add_child(Style.kicker("DORFTAG %d  ·  %d MENSCHEN IM AUFBAU" % [int(economy.get("day", 1)), economy.get("people", []).size()]))
	_text(ui, today, str(life.get("objective", "Lerne Decimus und deine Nachbarn kennen.")), 18)
	if not str(economy.get("last_report", "")).is_empty():
		_text(ui, today, str(economy.get("last_report", "")), 15, true)
	column.add_child(Kit.heading("Vorrat"))
	var stock := _flow(column, 18)
	stock.name = "VillageStock"
	for entry: Array in [["wood", "wood", "Holz"], ["stone", "stone", "Stein"], ["grain", "grain", "Getreide"], ["denarii", "coin", "Denare"]]:
		_chip(ui, stock, entry[1], str(int(data.resources.get(entry[0], 0))), entry[2])
	_text(ui, column, "Ein Dorftag dauert in dieser Prüfphase zwei Spielminuten; Gespräche und Pausen halten ihn an.", 13, true)
	var history: Dictionary = life.get("history", {})
	_text(ui, column, "Historischer Rahmen: %s · %s. Dorf und Bewohner sind eigene fiktionale Figuren." % [history.get("year_label", WorldCalendar.format_year(int(history.get("current_year", 100)))), life.get("ruler", "Historischer Rahmen")], 14, true)
	column.add_child(Kit.heading("Anlagen"))
	var stats: Dictionary = data.get("village", {}).get("attributes", {})
	var row := _flow(column, 10)
	row.name = "VillageAttributes"
	for pair: Array in [["courage", "Mut"], ["combat", "Kampf"], ["insight", "Scharfsinn"], ["tactics", "Taktik"]]:
		var stat := _card(row)
		stat.get_parent().custom_minimum_size = Vector2(118, 0)
		stat.add_child(Style.kicker(str(pair[1]).to_upper()))
		_text(ui, stat, str(stats.get(pair[0], 0)), 24)
	_abilities(ui, column, data)
	_text(ui, column, "Erfahrung entsteht durch gültige Treffer, abgewehrte Angriffe, Aufklärung, Warnung und Rettung. Ein Gespräch kann nur einmal dieselbe Vertrauenswirkung haben.", 14, true)
	_action(ui, column, "Mit Decimus den Wiederaufbau vereinbaren", "village_request_work", {}, bool(data.village.social.npcs.get("decimus", {}).get("met", false)))
	_text(ui, column, "Zum Kennenlernen gehst du direkt zu den Menschen. Der Dorfplan zeigt ihre Aufgaben; E beziehungsweise Interagieren beginnt das Gespräch.", 14, true)


static func _abilities(ui, column: Control, data: Dictionary) -> void:
	var earned: Array[String] = Abilities.names(data)
	_text(ui, column, "Erlernte Fähigkeiten: " + (", ".join(earned) if not earned.is_empty() else "noch keine"), 16)
	for id in data.get("village", {}).get("abilities", {}).get("earned", []):
		_text(ui, column, "· " + str(Abilities.entry(str(id)).get("effect_text", "")), 14, true)


static func _work(ui, column: VBoxContainer, data: Dictionary, economy: Dictionary) -> void:
	if Childhood.enabled(data):
		_text(ui, column, "Das Dorf arbeitet bereits. Du kannst bei den Menschen Aufgaben übernehmen; die Arbeitsplätze verteilen die Erwachsenen.", 17)
		column.add_child(Kit.heading("Arbeitsplätze"))
		for place: Dictionary in economy.get("workplaces", []):
			var site := _card(column)
			_text(ui, site, "%s · %d Menschen arbeiten hier" % [place.name, place.available], 17)
			_text(ui, site, "In Betrieb" if str(place.reason).is_empty() else str(place.reason), 14, true)
		return
	var permit: bool = economy.get("authority", {}).get("work_permit", false)
	_text(ui, column, "Jede Person kann nur einen Arbeitsplatz oder Verteidigungsdienst übernehmen. Nahrung und Gesundheit entscheiden, wer tatsächlich arbeiten kann.", 15)
	if not permit:
		var hint := _card(column, true)
		_text(ui, hint, "Sprich mit Decimus und vereinbare zuerst die Mithilfe beim Wiederaufbau.", 15)
	column.add_child(Kit.heading("Arbeitsplätze"))
	for place: Dictionary in economy.get("workplaces", []):
		# Cards share the modal's scroll gesture; its outer boundary still blocks the world.
		var inner := _card(column)
		inner.add_theme_constant_override("separation", 8)
		_text(ui, inner, "%s · %d/%d arbeitsfähig · Zustand %d %%" % [place.name, place.available, place.required, place.condition], 18)
		var condition := Meter.new()
		condition.value = float(place.condition) / 100.0
		condition.tint = Style.AURUM if int(place.condition) >= 60 else Style.MINIUM
		inner.add_child(condition)
		_text(ui, inner, "In Betrieb" if place.reason.is_empty() else str(place.reason), 14, true)
		if not place.project.is_empty():
			var progress := Meter.new()
			progress.name = "ProjectProgress"
			progress.value = float(place.project_progress)
			progress.tint = Style.AERUGO
			inner.add_child(progress)
		var cost: Dictionary = place.get("repair_cost", {})
		_action(ui, inner, "Wiederaufbauen · %d Holz / %d Stein" % [cost.get("wood", 0), cost.get("stone", 0)], "village_repair", {"workplace_id":place.id}, permit and int(place.condition) < 100 and place.project.is_empty())
	column.add_child(Kit.heading("Einwohner zuweisen"))
	for person: Dictionary in economy.get("people", []):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var label: Label = _text(ui, row, "%s · Hunger %d/3" % [Childhood.display_name(data, str(person.id), str(person.name)), person.hunger], 14)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if int(person.hunger) >= 2:
			label.add_theme_color_override("font_color", Style.MINIUM.lightened(0.35))
		var select := OptionButton.new()
		# Popup selectors own their press/release; swipes can begin on the adjacent label.
		select.mouse_filter = Control.MOUSE_FILTER_STOP
		select.set_meta("village_focus_id", "assignment:" + str(person.id))
		select.set_meta("base_font_size", 14)
		select.custom_minimum_size = Vector2(176, Style.TOUCH_MIN)
		Style.style_plaque_button(select, false, roundi(14 * ui._ui_scale))
		var in_militia: bool = data.village.get("militia", []).has(person.id)
		select.disabled = not permit or not person.alive or in_militia
		var ids := ["idle", "farm", "woodcamp", "quarry", "trade", "watchpost", "defense"]
		var labels := ["Frei / Erholen", "Dorffelder", "Holzfällerlager", "Steinbruch", "Handelsplatz", "Stadtposten", "Verteidigung"]
		if person.assignment == "defense":
			ids = ["defense", "return"]
			labels = ["Verteidigungsdienst", "Zur bisherigen Arbeit"]
		if in_militia:
			ids = ["defense"]
			labels = ["In deiner Truppe" if person.alive else "Gefallen"]
		for caption in labels:
			select.add_item(caption)
		select.selected = maxi(0, ids.find(str(person.assignment)))
		row.add_child(select)
		var id := str(person.id)
		select.item_selected.connect(func(index: int):
			if ids[index] in ["return", "defense"]:
				ui._emit("village_command", {"command":"village_shift", "args":{"resident_id":id, "duty":ids[index]}})
			else:
				ui._emit("village_command", {"command":"village_assign", "args":{"resident_id":id, "workplace_id":ids[index]}})
		)
	column.add_child(Kit.heading("Versorgung"))
	_action(ui, column, "Notvorrat beim Händler kaufen", "village_buy_food", {}, permit)
	_action(ui, column, "Dorffelder neu aussäen · 4 Getreide", "village_resow", {}, permit)
	_text(ui, column, "Saatgut und Essen getrennt einplanen: Zur Aussaat kommen die Rationen bis zur nächsten Ernte. Bei 14 lebenden Einwohnern brauchst du dafür mindestens 18 Getreide ohne weitere Verluste.", 14, true)


## Where someone is, seen from the player: distance and compass direction.
static func _whereabouts(data: Dictionary, target: Vector2) -> String:
	var position: Array = data.get("player", {}).get("position", [0.0, 0.0, 0.0])
	var offset := target - Vector2(float(position[0]), float(position[2]))
	var distance := offset.length()
	if distance < 3.0:
		return "Gleich bei dir"
	# +x is east and +z is south, as on the regional map.
	var names := ["Osten", "Südosten", "Süden", "Südwesten", "Westen", "Nordwesten", "Norden", "Nordosten"]
	var sector := posmod(roundi(offset.angle() / (TAU / 8.0)), 8)
	return "Etwa %d m von dir, im %s" % [roundi(distance), names[sector]]


static func _people(ui, column: VBoxContainer, data: Dictionary, life: Dictionary) -> void:
	_text(ui, column, "Berufe lernst du bei Menschen, die dich kennen. Ihre Sorgen, dein Verhalten und deine Hilfe bestimmen die Beziehung.", 15)
	var own := _card(column, true)
	own.add_child(Style.kicker("DEIN BERUF"))
	_text(ui, own, "Dein Beruf: " + str(life.get("profession", "Noch keine Lehre")), 18)
	column.add_child(Kit.heading("Menschen im Dorf"))
	for npc: Dictionary in Life.npc_catalog(data):
		var bond: Dictionary = Life.relationship(data, npc.id)
		var card := _card(column)
		card.get_parent().name = "Person_" + str(npc.id)
		var header := HBoxContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_constant_override("separation", 12)
		card.add_child(header)
		var title: Label = _text(ui, header, "%s · %s" % [npc.name, npc.role], 19)
		title.add_theme_font_override("font", Style.display_font(600, 1))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not Life.is_available(data, str(npc.id)):
			_text(ui, card, "Für Gespräche nicht verfügbar", 14, true)
			continue
		var met := bool(bond.get("met", false))
		var trust := int(bond.get("trust", 0))
		var standing: Label = _text(ui, header, "Noch nicht kennengelernt" if not met else "Vertrauen %+d%s" % [trust, " · verbündet" if bond.get("ally", false) else ""], 14, true)
		standing.autowrap_mode = TextServer.AUTOWRAP_OFF
		standing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if met and trust != 0:
			standing.add_theme_color_override("font_color", Style.AERUGO if trust > 0 else Style.MINIUM.lightened(0.35))
		var behavior: Dictionary = NpcBehavior.view(data, str(npc.id))
		if not behavior.is_empty():
			var activity := str(behavior.get("activity_label", ""))
			var reason := str(behavior.get("reason", ""))
			if not activity.is_empty():
				_text(ui, card, "Gerade: " + activity, 15)
			if met:
				var interest := str(behavior.get("interest_label", ""))
				if not interest.is_empty():
					_text(ui, card, "Interesse: " + interest, 14, true)
				if not reason.is_empty():
					_text(ui, card, reason, 14, true)
				var neighbors: Array = NpcBehavior.social_neighbors(data, str(npc.id))
				for index in mini(3, neighbors.size()):
					var neighbor: Dictionary = neighbors[index]
					_text(ui, card, "%s · %s" % [neighbor.name, neighbor.label], 14, true)
		_text(ui, card, _whereabouts(data, Life.actor_position(data, npc.id)), 13, true)


static func _map(ui, column: VBoxContainer, data: Dictionary) -> void:
	var position: Array = data.player.position
	var map := RegionalMap.new()
	map.name = "RegionalMap"
	map.position_world = Vector3(position[0], position[1], position[2])
	map.places = Plan.points_of_interest()
	map.roads = Plan.roads()
	column.add_child(map)
	_text(ui, column, "32 × 32 km · neun Regionen · Gelände wird in Sektoren geladen", 18)
	_text(ui, column, "Aktueller Ort: %s · %.0f / %.0f m" % [Plan.region_label(map.position_world), position[0], position[2]], 14)
	var distance := String.num(Footpath.length_m() / 1000.0, 2).replace(".", ",")
	_text(ui, column, "Osttor – Alter Steinbruch · %s km. Der Erdweg beginnt am Osttor. Der Steinbruch ist als sichtbarer Arbeitsplatz erreichbar." % distance, 14)
	_text(ui, column, "Goldene Raute: bewohntes Grenzdorf. Türkise Linie: erkundbare Trasse zum Steinbruch. Blasse Orte und Verbindungen: geplante Siedlungen und Straßen.", 14, true)
