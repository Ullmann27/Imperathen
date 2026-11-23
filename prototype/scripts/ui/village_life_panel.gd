extends RefCounted
## View-only panels: every consequential choice returns through the WorldModel.

const Economy = preload("res://scripts/domain/village_economy.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")

class RegionalMap extends Control:
	var position_world := Vector3.ZERO
	var places: Array = []
	var roads: Array = []
	func _ready() -> void:
		custom_minimum_size = Vector2(420, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func point(world: Array) -> Vector2:
		return Vector2(18, 14) + Vector2((float(world[0]) + 16000) / 32000.0, (float(world[2]) + 16000) / 32000.0) * (size - Vector2(36, 28))
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("263631"))
		for x in range(1, 8):
			draw_line(Vector2(size.x * x / 8.0, 0), Vector2(size.x * x / 8.0, size.y), Color(0.7, 0.7, 0.5, 0.08))
		for z in range(1, 8):
			draw_line(Vector2(0, size.y * z / 8.0), Vector2(size.x, size.y * z / 8.0), Color(0.7, 0.7, 0.5, 0.08))
		var lookup := {}
		for place: Dictionary in places:
			lookup[place.id] = place.position
		for road: Dictionary in roads:
			if lookup.has(road.get("from", "")) and lookup.has(road.get("to", "")):
				draw_line(point(lookup[road.from]), point(lookup[road.to]), Color("6e7654"), 2.0, true)
		for place: Dictionary in places:
			var at := point(place.position)
			var inhabited: bool = place.id == "home_village"
			draw_circle(at, 5 if inhabited else 3, Color("e7c082") if inhabited else Color("858b72"))
			if inhabited or place.kind in ["town", "port", "fort"]:
				draw_string(ThemeDB.fallback_font, at + Vector2(6, -5), str(place.name), HORIZONTAL_ALIGNMENT_LEFT, 140, 13, Color("e6dfca"))
		var player := point([position_world.x, position_world.y, position_world.z])
		draw_circle(player, 8, Color(0.4, 0.85, 0.85, 0.25))
		draw_circle(player, 3, Color("9fe0d8"))


static func _text(ui, column: VBoxContainer, value: String, size := 16, muted := false) -> void:
	var label: Label = ui._label(value, size, ui.MUTED if muted else ui.CREAM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)


static func _action(ui, column: VBoxContainer, label: String, command: String, args: Dictionary = {}, enabled := true) -> Button:
	var button: Button = ui._button(label, ui._emit.bind("village_command", {"command":command, "args":args}), false, 15)
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
	tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(tabs)
	var active_tab: Button
	for entry in [["overview", "Dorfleben"], ["work", "Arbeit & Versorgung"], ["people", "Menschen & Berufe"], ["map", "Region"]]:
		var button: Button = ui._button(entry[1], ui._emit.bind("village_panel", {"tab":entry[0]}), entry[0] == tab, 14)
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.set_meta("village_focus_id", "tab:" + str(entry[0]))
		tabs.add_child(button)
		if entry[0] == tab:
			active_tab = button
	if not str(data.get("village_feedback", "")).is_empty():
		_text(ui, column, str(data.village_feedback), 15)
	if tab == "work":
		_work(ui, column, data, economy)
	elif tab == "people":
		_people(ui, column, data, life)
	elif tab == "map":
		_map(ui, column, data)
	else:
		_overview(ui, column, data, economy, life)
	var close: Button = ui._button("Zurück ins Dorf", ui._emit.bind("resume", {}), true)
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


static func _overview(ui, column: VBoxContainer, data: Dictionary, economy: Dictionary, life: Dictionary) -> void:
	if Childhood.enabled(data):
		var chapter:=Childhood.view(data)
		_text(ui,column,str(chapter.get("title","Ein Morgen zu Hause")),22)
		_text(ui,column,str(chapter.get("objective","")),18)
		_text(ui,column,"Dorftag %d · Du bist zwölf. Der nächste Tag beginnt, wenn du zu Hause bewusst schlafen gehst."%int(chapter.get("day",1)),15,true)
		if not chapter.get("carried",[]).is_empty():
			_text(ui,column,"Bei dir: "+", ".join(chapter.carried),16)
		_text(ui,column,"Deine Lehre: "+str(chapter.get("apprenticeship","none")).replace("none","noch offen").replace("smith","bei Sextus"),16)
		_text(ui,column,"Deine Mutter Julia und dein Vater Silvanus warten an eurem Haus. Die Karte zeigt das Ziel deines nächsten Auftrags. Zum Kennenlernen und Helfen gehst du zu den Menschen.",15,true)
		_text(ui,column,"Ansehen wächst durch gehaltene Zusagen. Decimus führt das Dorf; deine Aufgaben gehören zu deinem eigenen Lebensweg.",15,true)
		return
	_text(ui, column, str(life.get("objective", "Lerne Decimus und deine Nachbarn kennen.")), 18)
	_text(ui, column, "Dorftag %d · %d Menschen im Aufbau · Vorrat: %d Holz / %d Stein / %d Getreide / %d Denare" % [economy.get("day", 1), economy.get("people", []).size(), data.resources.wood, data.resources.stone, data.resources.grain, data.resources.denarii])
	_text(ui, column, "Ein Dorftag dauert in dieser Prüfphase zwei Spielminuten; Gespräche und Pausen halten ihn an.", 13, true)
	var history: Dictionary = life.get("history", {})
	_text(ui, column, "Historischer Rahmen: %s n. Chr. · %s. Dorf und Bewohner sind eigene fiktionale Figuren." % [history.get("current_year", 100), life.get("ruler", "Historischer Rahmen")], 14, true)
	_text(ui, column, str(economy.get("last_report", "")), 15)
	var stats: Dictionary = data.get("village", {}).get("attributes", {})
	_text(ui, column, "Mut %s · Kampf %s · Scharfsinn %s · Taktik %s" % [stats.get("courage", 0), stats.get("combat", 0), stats.get("insight", 0), stats.get("tactics", 0)], 17)
	_text(ui, column, "Erfahrung entsteht durch gültige Treffer, abgewehrte Angriffe, Aufklärung, Warnung und Rettung. Ein Gespräch kann nur einmal dieselbe Vertrauenswirkung haben.", 14, true)
	_action(ui, column, "Mit Decimus den Wiederaufbau vereinbaren", "village_request_work", {}, bool(data.village.social.npcs.get("decimus", {}).get("met", false)))
	_text(ui, column, "Zum Kennenlernen gehst du direkt zu den Menschen. Der Dorfplan zeigt ihre Aufgaben; E beziehungsweise Interagieren beginnt das Gespräch.", 14, true)


static func _work(ui, column: VBoxContainer, data: Dictionary, economy: Dictionary) -> void:
	if Childhood.enabled(data):
		_text(ui,column,"Das Dorf arbeitet bereits. Du kannst bei den Menschen Aufgaben übernehmen; die Arbeitsplätze verteilen die Erwachsenen.",17)
		for place: Dictionary in economy.get("workplaces",[]):
			_text(ui,column,"%s · %d Menschen arbeiten hier"%( [place.name,place.available]),17)
			_text(ui,column,"In Betrieb" if str(place.reason).is_empty() else str(place.reason),14,true)
		return
	var permit: bool = economy.get("authority", {}).get("work_permit", false)
	_text(ui, column, "Jede Person kann nur einen Arbeitsplatz oder Verteidigungsdienst übernehmen. Nahrung und Gesundheit entscheiden, wer tatsächlich arbeiten kann.", 15)
	if not permit:
		_text(ui, column, "Sprich mit Decimus und vereinbare zuerst die Mithilfe beim Wiederaufbau.", 15)
	for place: Dictionary in economy.get("workplaces", []):
		var card: PanelContainer = ui._panel(false)
		# Cards share the modal's scroll gesture; its outer boundary still blocks the world.
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(card)
		var inner: VBoxContainer = ui._column(8)
		card.add_child(inner)
		_text(ui, inner, "%s · %d/%d arbeitsfähig · Zustand %d %%" % [place.name, place.available, place.required, place.condition], 18)
		_text(ui, inner, "In Betrieb" if place.reason.is_empty() else str(place.reason), 14, true)
		if not place.project.is_empty():
			var progress := ProgressBar.new()
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.value = float(place.project_progress) * 100
			progress.custom_minimum_size.y = 20
			inner.add_child(progress)
		var cost: Dictionary = place.get("repair_cost", {})
		_action(ui, inner, "Wiederaufbauen · %d Holz / %d Stein" % [cost.get("wood", 0), cost.get("stone", 0)], "village_repair", {"workplace_id":place.id}, permit and int(place.condition) < 100 and place.project.is_empty())
	_text(ui, column, "Einwohner zuweisen", 20)
	for person: Dictionary in economy.get("people", []):
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(row)
		var label: Label = ui._label("%s · Hunger %d/3" % [person.name, person.hunger], 14, ui.CREAM)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var select := OptionButton.new()
		# Popup selectors own their press/release; swipes can begin on the adjacent label.
		select.mouse_filter = Control.MOUSE_FILTER_STOP
		select.set_meta("village_focus_id", "assignment:" + str(person.id))
		select.custom_minimum_size = Vector2(160, 46)
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
	_action(ui, column, "Notvorrat beim Händler kaufen", "village_buy_food", {}, permit)
	_action(ui, column, "Dorffelder neu aussäen · 4 Getreide", "village_resow", {}, permit)
	_text(ui, column, "Saatgut und Essen getrennt einplanen: Zur Aussaat kommen die Rationen bis zur nächsten Ernte. Bei 14 lebenden Einwohnern brauchst du dafür mindestens 18 Getreide ohne weitere Verluste.", 14, true)


static func _people(ui, column: VBoxContainer, data: Dictionary, life: Dictionary) -> void:
	_text(ui, column, "Berufe lernst du bei Menschen, die dich kennen. Ihre Sorgen, dein Verhalten und deine Hilfe bestimmen die Beziehung.", 15)
	for npc: Dictionary in Life.npc_catalog(data):
		var bond: Dictionary = Life.relationship(data,npc.id)
		_text(ui, column, "%s · %s" % [npc.name, npc.role], 19)
		if not Life.is_available(data, str(npc.id)):
			_text(ui, column, "Für Gespräche nicht verfügbar", 14, true)
			continue
		_text(ui, column, "Noch nicht kennengelernt" if not bond.get("met", false) else "Vertrauen %+d%s" % [bond.get("trust", 0), " · verbündet" if bond.get("ally", false) else ""], 14, true)
		var position: Vector2 = Life.actor_position(data, npc.id)
		_text(ui, column, "Ort im Dorf: %.0f / %.0f" % [position.x, position.y], 12, true)
	_text(ui, column, "Dein Beruf: " + str(life.get("profession", "Noch keine Lehre")), 18)


static func _map(ui, column: VBoxContainer, data: Dictionary) -> void:
	var position: Array = data.player.position
	var map := RegionalMap.new()
	map.position_world = Vector3(position[0], position[1], position[2])
	map.places = Plan.points_of_interest()
	map.roads = Plan.roads()
	column.add_child(map)
	_text(ui, column, "32 × 32 km · neun Regionen · Gelände wird in Sektoren geladen", 18)
	_text(ui, column, "Heller Ort: bewohntes Grenzdorf. Blasse Orte und Verbindungen: geplante Siedlungen und Straßen. Die große Geländegrundlage ist noch keine vollständig ausgestaltete Spielwelt.", 14, true)
	_text(ui, column, "Aktueller Ort: %s · %.0f / %.0f m" % [Plan.region_label(map.position_world), position[0], position[2]], 14)
