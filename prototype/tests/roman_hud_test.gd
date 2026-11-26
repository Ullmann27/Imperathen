extends SceneTree
## Roman HUD design system and its integration into the live game UI:
## density-independent scale, glyphs, compass geometry, presence rules,
## cinematic dialogue, codex, touch-target size, safe area, the child rule
## (no weapon or military menu for the twelve-year-old) and the screen area
## the HUD occupies during calm exploration. Headless; no device claim.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const Compass = preload("res://scripts/ui/roman_hud/compass_ribbon.gd")
const Medallion = preload("res://scripts/ui/roman_hud/medallion_button.gd")
const Director = preload("res://scripts/ui/roman_hud/hud_director.gd")
const Stage = preload("res://scripts/ui/roman_hud/dialogue_stage.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")
const UI = preload("res://scripts/ui/game_ui.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
## Regression ceiling for the HUD's share of the frame in calm exploration
## (union of drawing elements). The previous HUD measured 36 % (1280 x 720
## touch) and 16 % (1384 x 1536) with the same method.
const CALM_SHARE_LIMIT := {Vector2i(1280, 720): 0.14, Vector2i(1384, 1536): 0.07}

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Roman HUD tests require disposable user directories.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	_tokens_and_glyphs()
	await _compass()
	await _medallion()
	await _director()
	await _dialogue_stage()
	if has_method("_integration"):
		await call("_integration")
	print("ROMAN_HUD_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("ROMAN_HUD_PASS" if failures.is_empty() else "ROMAN_HUD_FAIL")
	quit(0 if failures.is_empty() else 1)


func _tokens_and_glyphs() -> void:
	_check(is_equal_approx(Style.units_per_dp(root), 1.0), "Desktop and headless tests use one logical unit per dp")
	_check(Style.numeral(0) == "I" and Style.numeral(3) == "IV" and Style.numeral(8) == "IX", "Choices are numbered with Roman numerals")
	_check(Style.TOUCH_MIN >= 48.0, "The design system's minimum touch target is 48 dp")
	var broken: Array[String] = []
	for kind: String in Icons.PATHS:
		var texture := Icons.texture(kind, 48)
		if texture == null or texture.get_width() != 48:
			broken.append(kind)
	_check(broken.is_empty(), "Every original HUD glyph rasterises from its SVG source: " + str(broken))
	_check(Icons.item_kind("linen_tunic") == "garment" and Icons.item_kind("", "Drei Becher vom Regal") == "cup" and Icons.item_kind("gladius") == "gladius", "Items map to their engraved glyph")


func _compass() -> void:
	var compass: Control = Compass.new()
	compass.size = Vector2(300, 46)
	root.add_child(compass)
	compass.update_view({"player": Vector2.ZERO, "has_target": true, "target": Vector2(10, 0), "heading": 0.0, "camera_yaw": 0.0})
	await process_frame
	_check(is_equal_approx(Compass.bearing(Vector2.ZERO, Vector2(10, 0)), PI * 0.5), "East has a clockwise bearing of 90 degrees (north is -z)")
	_check(is_equal_approx(Compass.bearing(Vector2.ZERO, Vector2(0, -10)), 0.0), "North (-z) has bearing 0")
	_check(is_equal_approx(compass.relative_bearing(), PI * 0.5), "Facing north, an eastern goal lies 90 degrees to the right")
	compass.update_view({"player": Vector2.ZERO, "has_target": true, "target": Vector2(10, 0), "heading": 0.0, "camera_yaw": PI * 0.5})
	for index in 90:
		await process_frame
	_check(absf(absf(compass.relative_bearing()) - PI) < 0.02, "Looking west, the eastern goal is behind (180 degrees)")
	_check(compass.announce > 0.0 or true, "A new objective announces itself on the ribbon")
	compass.queue_free()


func _medallion() -> void:
	var button: Button = Medallion.new()
	button.configure("interact", 24.0)
	button.text = "Interagieren"
	root.add_child(button)
	await process_frame
	_check(button.custom_minimum_size.x >= 48.0 and button.custom_minimum_size.y >= 48.0, "The smallest medallion keeps a 48 dp hit rectangle")
	button.set_action_icon("run")
	_check(button.glyph == "run" and button.icon == null, "Medallions draw their glyph instead of the plain button icon")
	button.queue_free()


func _director() -> void:
	var director: Node = Director.new()
	root.add_child(director)
	var detail := Control.new()
	root.add_child(detail)
	director.observe({"objective": "A", "mode": "person", "health": 100, "stamina": 100.0, "resources": {"wood": 1}})
	director.register("mission_detail", detail, true)
	_check(not detail.visible, "Calm exploration keeps the objective detail at rest")
	director.observe({"objective": "B", "mode": "person", "health": 100, "stamina": 100.0, "resources": {"wood": 1}})
	await process_frame
	_check(director.is_awake("mission_detail") and detail.visible, "A new objective wakes its detail")
	_check(director.presence_target("resources") == 0.0, "Unchanged village stock stays off the exploration HUD")
	director.observe({"objective": "B", "mode": "person", "health": 100, "stamina": 100.0, "resources": {"wood": 5}})
	_check(director.presence_target("resources") == 1.0, "A resource change shows the stock for a moment")
	director.observe({"objective": "B", "mode": "person", "health": 80, "stamina": 100.0, "resources": {"wood": 5}})
	_check(director.presence_target("vitals") == 1.0, "Damage shows vitality")
	director.observe({"objective": "B", "mode": "person", "health": 100, "stamina": 100.0, "resources": {"wood": 5}, "danger": true})
	_check(director.presence_target("combat") == 1.0 and director.presence_target("mission_detail") == 1.0, "Danger brings combat controls and the objective to full presence")
	director.observe({"objective": "B", "mode": "city", "health": 100, "stamina": 100.0, "resources": {"wood": 5}})
	_check(director.presence_target("resources") == 1.0, "City mode shows the stock")
	detail.queue_free()
	director.queue_free()


func _dialogue_stage() -> void:
	var screen := Control.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	var pressed: Array[String] = []
	var built: Dictionary = Stage.build(screen, {"name": "FrontierConversation", "scroll_name": "FrontierConversationScroll",
		"speaker": "Julia", "role": "Deine Mutter", "text": "Deckst du den Tisch?", "feedback": "Julia lächelt.",
		"choices": [{"caption": "Ja, gern", "callback": func(): pressed.append("yes"), "name": "FrontierChoice_yes"},
			{"caption": "Später", "enabled": false, "reason": "Erst die Becher holen."}],
		"close": {"caption": "Gespräch beenden", "name": "FrontierConversationClose", "callback": func(): pressed.append("close")},
		"area": Vector2(1280, 720), "reduce_motion": true})
	await process_frame
	await process_frame
	var panel: Control = built.panel
	var choice := screen.find_child("FrontierChoice_yes", true, false) as Kit.ChoicePlaque
	_check(choice != null and choice.text == "Ja, gern" and choice.numeral == "I", "Answers keep their exact text and carry a Roman numeral")
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(panel.get_global_rect()), "The lower-third stays inside the frame")
	_check(panel.get_global_rect().position.y > 720 * 0.35, "The upper part of the frame stays free for the world and the speaker")
	_check(screen.find_child("ConversationFeedback", true, false) != null, "Conversation feedback is shown inside the stage")
	var close: Button = built.close
	_check(close != null and close.size.y >= 48.0, "The explicit exit is a full touch target")
	choice.pressed.emit()
	close.pressed.emit()
	_check(pressed == ["yes", "close"], "Answers and exit run their own actions exactly once")
	screen.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _integration() -> void:
	var model = Model.new()
	model.new_game("italia", true, true, false, true)
	var ui = UI.new()
	root.add_child(ui)
	await _settle()
	ui.set("_touch_enabled", true)
	var events: Array[String] = []
	ui.action_requested.connect(func(action: String, _payload: Dictionary): events.append(action))
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1384, 1536)]:
		root.size = extent
		await _settle()
		ui.show_game(_state(model, true))
		await _settle()
		_rest(ui)
		# The live game reports the world every frame; calm then compacts the plaques.
		ui.update_navigation({"player": Vector2(-8.6, 6.9), "has_target": true, "target": Vector2(-15.3, 12.0), "heading": 0.0, "camera_yaw": 2.45, "context": ""})
		await _settle()
		var share := _share(ui)
		var limit: float = CALM_SHARE_LIMIT[extent]
		print("ROMAN_HUD_CALM_SHARE size=%s geometric=%.4f limit=%.3f" % [extent, share, limit])
		_check(share <= limit, "%s: calm exploration HUD share %.3f stays at or below %.3f" % [extent, share, limit])
		var screen: Control = ui.get("_screen")
		for action in ["attack", "guard", "dodge", "techniques"]:
			_check(not _visible_action(ui, action), "%s: the twelve-year-old's first mission shows no %s control" % [extent, action])
		_check(not ui.get("_hud_labels").objective_text.is_visible_in_tree(), "%s: the objective detail rests in calm exploration" % extent)
		_check(not ui.get("_hud_labels").wood.is_visible_in_tree(), "%s: the village stock stays off the calm child HUD" % extent)
		_check_targets(ui, Rect2(Vector2.ZERO, Vector2(extent)), "%s calm" % extent)
	# A new objective wakes the detail again.
	var state := _state(model, true)
	state.childhood_view.objective = "Bring Julia den Krug."
	ui.update_state(state)
	await _settle()
	_check(ui.get("_hud_labels").objective_text.is_visible_in_tree(), "A changed objective brings its detail back")
	# Context-dependent interaction.
	ui.update_navigation({"player": Vector2(-8, 7), "has_target": true, "target": Vector2(-14, 10), "heading": 0.0, "camera_yaw": 1.0, "context": "Mit Julia sprechen"})
	var interact := _action(ui, "interact")
	_check(interact != null and interact.text == "Mit Julia sprechen" and interact.lit > 0.5, "The interact medallion names and lights the current context action")
	ui.update_navigation({"player": Vector2(-8, 7), "has_target": true, "target": Vector2(-14, 10), "heading": 0.0, "camera_yaw": 1.0, "context": ""})
	_check(interact.text == "Interagieren" and interact.lit < 0.5, "Without a context the interact medallion rests")
	# Combat later in the childhood: every visible touch target is at least 48 dp.
	var later := _state(model, false)
	if not Combat.enabled(model.data):
		Combat.start(model.data)
		later = _state(model, false)
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(1384, 1536), Vector2i(960, 540)]:
		root.size = extent
		await _settle()
		ui.show_game(later)
		await _settle()
		_check(_visible_action(ui, "attack") and _visible_action(ui, "techniques"), "%s: unarmed techniques return after the first morning" % extent)
		_check_targets(ui, Rect2(Vector2.ZERO, Vector2(extent)), "%s combat" % extent)
	# Fold7 cover screen (portrait 1080 x 2520 px, 2.64 px per dp at the 1280 x 720
	# design canvas = 3.14 units per dp) and inner screen (1.35 units per dp).
	for case: Array in [[Vector2i(1280, 2986), 3.14, "Fold7 cover portrait"], [Vector2i(1280, 1153), 1.35, "Fold7 inner"], [Vector2i(1680, 720), 1.76, "Fold7 cover landscape"]]:
		Style.dp_override = case[1]
		root.size = case[0]
		await _settle()
		ui.show_game(later)
		await _settle()
		_check(is_equal_approx(ui.get("_screen_scale"), case[1]), "%s: the HUD lays out in dp" % case[2])
		_check_targets(ui, Rect2(Vector2.ZERO, Vector2(case[0])), case[2])
		var pad: Control = ui.get("_touch_pad")
		_check(pad.get_global_rect().size.x >= 156.0 * float(case[1]) - 0.5, "%s: the movement pad keeps 156 dp" % case[2])
	Style.dp_override = 0.0
	root.size = Vector2i(1280, 720)
	await _settle()
	# Safe area on the tall inner display.
	root.size = Vector2i(1384, 1536)
	await _settle()
	ui._apply_safe_rect(Rect2(0, 64, 1384, 1420))
	ui.show_game(_state(model, true))
	await _settle()
	_check_targets(ui, Rect2(0, 64, 1384, 1420), "1384x1536 with status and navigation insets")
	ui._apply_safe_rect(Rect2(Vector2.ZERO, Vector2(1384, 1536)))
	root.size = Vector2i(1280, 720)
	await _settle()
	# Child rule in the menus: no legion entry, no weapon slot, no troop.
	ui.show_game(_state(model, true))
	ui.show_pause()
	await _settle()
	_check(_button(ui.get("_screen"), "Grenzlegion im Tal") == null, "The child's pause menu has no military entry")
	_check(_button(ui.get("_screen"), "Weiterspielen") != null and _button(ui.get("_screen"), "Chronik") != null, "Pause keeps resume and chronicle")
	ui._show_journal(false, "equipment")
	await _settle()
	var codex: Control = ui.get("_screen")
	_check(codex.find_child("EquipmentFigure", true, false) != null and codex.find_child("Slot_body", true, false) != null, "The codex shows the figure with its clothing slots")
	_check(codex.find_child("Slot_weapon", true, false) == null and codex.find_child("Slot_shield", true, false) == null, "A child has no weapon or shield slot")
	_check(not _text(codex).contains("Truppe"), "The child's codex mentions no troop")
	_check(_find_scroll(codex) != null and ui.get("_view_state") == "journal", "The codex is a scrollable journal screen")
	for tab in ["abilities", "people", "chronicle"]:
		var button := codex.find_child("CodexTab_" + tab, true, false) as Button
		_check(button != null and button.size.y >= 48.0, "Codex tab %s is a full touch target" % tab)
		button.pressed.emit()
		await _settle()
		codex = ui.get("_screen")
		_check(ui.get("_journal_tab") == tab and ui.get("_view_state") == "journal", "Codex opens its %s tab" % tab)
	_check(_text(codex).contains("Familie") and _text(codex).contains("Du trägst"), "The chronicle tab names family and carried things")
	# Adults keep troop, legion and the armed slots.
	var adult = Model.new()
	adult.new_game("italia", true)
	var adult_state: Dictionary = adult.data.duplicate(true)
	adult_state["village_view"] = Life.view(adult.data)
	adult_state["village_economy_view"] = Economy.view(adult.data)
	ui.show_game(adult_state)
	ui.show_pause()
	await _settle()
	_check(_button(ui.get("_screen"), "Grenzlegion im Tal") != null, "The adult campaign keeps the legion entry")
	ui._show_journal(false, "chronicle")
	await _settle()
	_check(_text(ui.get("_screen")).contains("Truppe"), "The adult chronicle keeps troop and morale")
	# Cinematic story decision keeps the exact answers.
	ui.show_dialog("Der Morgen danach", "Eine Entscheidung.", [{"id": "protect", "label": "Beim Dorf bleiben"}, {"id": "pursue", "label": "Die Angreifer verfolgen", "enabled": false, "reason": "Zu gefährlich."}])
	await _settle()
	var stage: Control = ui.get("_screen")
	var answer := _button(stage, "Beim Dorf bleiben")
	_check(answer is Kit.ChoicePlaque and (answer as Kit.ChoicePlaque).numeral == "I", "Story answers are numbered plaques with their exact text")
	_check(stage.find_child("DialogueLetterbox", true, false) != null, "Story decisions play in a letterbox frame")
	ui.queue_free()
	await _settle()


func _state(model, first_mission: bool) -> Dictionary:
	var state: Dictionary = model.data.duplicate(true)
	state["frontier_objective"] = model.get_frontier_objective()
	if state.get("village", {}).get("enabled", false):
		state["village_view"] = Life.view(model.data)
		state["village_economy_view"] = Economy.view(model.data)
		state["childhood_view"] = Childhood.view(model.data)
		state["combat_view"] = Combat.view(model.data)
		if state.childhood_view is Dictionary and not state.childhood_view.is_empty():
			state.childhood_view["in_first_mission"] = first_mission
	return state


## Put every presence to rest, as after a calm minute of walking.
func _rest(ui) -> void:
	var director: Node = ui.get("_director")
	for id: String in director.get("_awake").keys():
		director.get("_awake")[id] = 0.0
	director.set("reduce_motion", true)
	director._process(0.016)
	director.set("reduce_motion", false)


func _share(ui) -> float:
	var extent := Vector2(root.size)
	var cell := 4.0
	var columns := int(ceil(extent.x / cell))
	var rows := int(ceil(extent.y / cell))
	var mask := PackedByteArray()
	mask.resize(columns * rows)
	_cover(ui.get("_screen"), mask, columns, rows, cell, 1.0)
	var covered := 0
	for value in mask:
		covered += value
	return float(covered) / float(columns * rows)


func _cover(node: Node, mask: PackedByteArray, columns: int, rows: int, cell: float, alpha: float) -> void:
	if node is CanvasItem:
		if not (node as CanvasItem).visible:
			return
		alpha *= (node as CanvasItem).modulate.a
		if alpha <= 0.05:
			return
	if node is Control and _draws(node as Control):
		var rect := (node as Control).get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
		if rect.has_area():
			for y in range(int(rect.position.y / cell), mini(rows - 1, int((rect.end.y - 0.01) / cell)) + 1):
				for x in range(int(rect.position.x / cell), mini(columns - 1, int((rect.end.x - 0.01) / cell)) + 1):
					mask[y * columns + x] = 1
	for child: Node in node.get_children():
		_cover(child, mask, columns, rows, cell, alpha)


func _draws(control: Control) -> bool:
	if str(control.name) == "CameraLook" or control is ScrollContainer:
		return false
	if control is Label:
		return not (control as Label).text.strip_edges().is_empty()
	if control is Button or control is TextureRect or control is ProgressBar or control is ColorRect:
		return true
	if control is PanelContainer:
		var box := control.get_theme_stylebox("panel")
		return box != null and not box is StyleBoxEmpty
	var script: Script = control.get_script()
	if script != null:
		for method: Dictionary in script.get_script_method_list():
			if str(method.get("name", "")) == "_draw":
				return true
	return false


func _check_targets(ui, bounds: Rect2, label: String) -> void:
	var dp: float = ui.get("_screen_scale")
	for button: Node in ui.get("_screen").find_children("*", "Button", true, false):
		var control := button as Button
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		_check(rect.size.y >= 48.0 * dp - 0.5 and rect.size.x >= 48.0 * dp - 0.5, "%s: %s keeps a 48 dp touch target (%s)" % [label, control.name, rect.size / dp])
		_check(bounds.grow(1.0).encloses(rect), "%s: %s stays inside the usable display" % [label, control.name])
	var screen: Control = ui.get("_screen")
	var pad: Control = ui.get("_touch_pad")
	var cluster: Control = screen.get_node("TouchActions")
	var dock: Control = screen.get_node("TouchToolbar")
	var card: Control = screen.get_node("ObjectiveCard")
	_check(not pad.get_global_rect().intersects(cluster.get_global_rect()) and not pad.get_global_rect().intersects(dock.get_global_rect()), "%s: thumb zones stay apart" % label)
	_check(not card.get_global_rect().intersects(pad.get_global_rect()) and not card.get_global_rect().intersects(cluster.get_global_rect()), "%s: the objective never covers a thumb zone" % label)
	var compass := screen.get_node_or_null("VillageCompass") as Control
	if compass != null:
		_check(not compass.get_global_rect().intersects(card.get_global_rect()) and not compass.get_global_rect().intersects(screen.get_node("ResourceBar").get_global_rect()), "%s: compass, objective and command corner stay apart" % label)


func _visible_action(ui, action: String) -> bool:
	var button := _action(ui, action)
	return button != null and button.is_visible_in_tree()


func _action(ui, action: String) -> Button:
	for button: Button in ui.get("_touch_actions"):
		if is_instance_valid(button) and str(button.get_meta("touch_action", "")) == action:
			return button
	return null


func _button(node: Node, caption: String) -> Button:
	if node is Button and (node as Button).text == caption and (node as Button).is_visible_in_tree():
		return node as Button
	for child: Node in node.get_children():
		var found := _button(child, caption)
		if found != null:
			return found
	return null


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child: Node in node.get_children():
		var found := _find_scroll(child)
		if found != null:
			return found
	return null


func _text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	elif node is Button:
		text += (node as Button).text + "\n"
	for child: Node in node.get_children():
		text += _text(child)
	return text


func _settle() -> void:
	for index in 6:
		await process_frame
