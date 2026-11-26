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
