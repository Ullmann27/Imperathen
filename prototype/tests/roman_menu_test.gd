extends SceneTree
## Title sequence and Roman main menu: skipping, first-start rule, button
## functions, layout and music wiring. Headless; no visual or audio quality claim.

const UIScript = preload("res://scripts/ui/game_ui.gd")
const RomanStyle = preload("res://scripts/ui/roman_style.gd")
const Intro = preload("res://scripts/ui/imperial_intro.gd")

var _ui: CanvasLayer
var _events: Array[String] = []
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Run through tools/check_prototype.py with isolated user data.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	_ui = _new_ui()
	await _frames()
	await _check_first_start_and_tap_skip()
	await _check_short_card_after_first_start()
	await _check_natural_end_and_keys()
	await _check_timeline()
	await _check_trailer_and_profiles()
	await _check_menu_buttons()
	await _check_menu_layout()
	await _check_menu_look()
	await _check_settings_and_music()
	print("ROMAN_MENU checks=%d failures=%d %s" % [_checks, _failures.size(), _failures])
	if _failures.is_empty():
		print("ROMAN_MENU_PASS headless intro/menu/music wiring; no visual or audio quality claim")
	quit(0 if _failures.is_empty() else 1)


func _new_ui() -> CanvasLayer:
	if is_instance_valid(_ui):
		_ui.queue_free()
	var ui: CanvasLayer = UIScript.new()
	root.add_child(ui)
	ui.action_requested.connect(func(action: String, _payload: Dictionary): _events.append(action))
	return ui


func _check_first_start_and_tap_skip() -> void:
	_events.clear()
	_ui.show_intro()
	await _frames()
	var intro: Control = _ui.get("_intro_node")
	_check(_ui.get("_view_state") == "intro" and intro is Intro, "intro screen opens with the title sequence")
	_check(_ui.intro_is_full() and is_equal_approx(intro.duration, Intro.FULL_DURATION), "first start plays the complete sequence")
	_check(_find(_ui.get("_screen"), "IntroSkip") is Button, "visible skip button exists")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(640, 360)
	intro._gui_input(touch)
	intro._gui_input(touch)
	_check(_count("intro_finished") == 1, "a tap skips the intro exactly once")
	var config := ConfigFile.new()
	_check(config.load(UIScript.SETTINGS_PATH) == OK and bool(config.get_value("interface", "intro_seen", false)),
		"first viewing is remembered on the device")


func _check_short_card_after_first_start() -> void:
	_ui = _new_ui()
	await _frames()
	_events.clear()
	_ui.show_intro()
	await _frames()
	var intro: Control = _ui.get("_intro_node")
	_check(not _ui.intro_is_full() and is_equal_approx(intro.duration, Intro.SHORT_DURATION), "later starts show the short title card")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	intro._gui_input(click)
	_check(_count("intro_finished") == 1, "a click skips the short card")


func _check_natural_end_and_keys() -> void:
	_events.clear()
	_ui.set("_always_intro", true)
	_ui.show_intro()
	await _frames()
	var intro: Control = _ui.get("_intro_node")
	_check(_ui.intro_is_full(), "setting forces the complete sequence")
	intro.set_process(false)
	for step in range(int(Intro.FULL_DURATION / 0.1) + 3):
		intro.advance(0.1)
	_check(_count("intro_finished") == 1, "complete sequence ends by itself and hands over once")
	for keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
		_events.clear()
		_ui.show_intro()
		await _frames()
		var key := InputEventKey.new()
		key.keycode = keycode
		key.pressed = true
		_ui._unhandled_input(key)
		_ui._unhandled_input(key)
		_check(_count("intro_finished") == 1, "key %s skips once" % OS.get_keycode_string(keycode))
	_events.clear()
	_ui.show_intro()
	await _frames()
	_check(_ui.handle_back() and _count("intro_finished") == 1, "Android back skips the intro")
	_events.clear()
	_ui.set("_reduce_motion", true)
	_ui.show_intro()
	await _frames()
	_check(not _ui.intro_is_full(), "reduced motion shows the calm title card instead of the sweep")
	_ui._finish_intro()
	_ui.set("_reduce_motion", false)
	_ui.set("_always_intro", false)


func _check_timeline() -> void:
	_ui.set("_always_intro", true)
	_ui.show_intro()
	await _frames()
	var intro: Control = _ui.get("_intro_node")
	intro.set_process(false)
	var eagle: TextureRect = _find(intro, "Aquila")
	var reveal: Control = _find(intro, "TitleReveal")
	var blood = _find(intro, "BloodTrail")
	var sword: Sprite2D = _find(intro, "Gladius")
	var motto: Label = _find(intro, "Motto")
	var camera: Control = _find(intro, "Camera")
	var near: Node2D = _find(intro, "NearCohort")
	_check(_find(intro, "FarCohort") != null and near != null and _find(intro, "NearStandards") != null, "legion cohorts and standards are on stage")
	_check(_find(intro, "BannerLeft") != null and _find(intro, "BannerRight") != null, "red and gold banners frame the sequence")
	var bar: ColorRect = _find(intro, "Letterbox0")
	_check(bar != null and bar.size.y > 40.0, "landscape uses cinemascope bars")
	intro.advance(0.2)
	_check(near.modulate.a < 0.05, "black opening before the first drum hit")
	intro.advance(0.5)
	var low := eagle.position.y
	_check(near.modulate.a > 0.9, "first hit reveals the marching legion")
	_check(reveal.size.x <= 0.5 and blood.reveal <= 0.5, "title and blood are hidden before the blade passes")
	intro.advance(Intro.SWEEP_START + 0.3 - intro.elapsed)
	_check(sword.visible and reveal.size.x > 1.0 and reveal.size.x < _find(intro, "Title").size.x, "blade mid-sweep reveals part of the title")
	_check(blood.reveal > 1.0 and blood.reveal < blood.length, "blood trail follows the blade")
	_check(_find(intro, "GladiusBlur0").visible and _find(intro, "BladeStreak").strength > 0.0, "blade carries a motion-blur trail")
	var push_before := camera.scale.x
	intro.advance(Intro.SWEEP_END + 0.03 - intro.elapsed)
	_check(camera.position.length() > 1.0 and camera.scale.x > push_before, "impact shakes and punches the camera")
	_check((_find(intro, "Flash") as ColorRect).color.a > 0.05, "impact flash")
	intro.advance(4.5 - intro.elapsed)
	_check(eagle.position.y < low - 20.0, "eagle rises behind the title")
	_check(not sword.visible and is_equal_approx(reveal.size.x, _find(intro, "Title").size.x), "full title after the cut, blade gone")
	_check(blood.reveal >= blood.length - 0.5, "blood trail spans the whole cut")
	intro.advance(Intro.MOTTO_WORDS[0] + 0.05 - intro.elapsed)
	_check(motto.visible_characters == 4, "VENI lands on the first drum hit")
	intro.advance(Intro.MOTTO_WORDS[1] + 0.05 - intro.elapsed)
	_check(motto.visible_characters == 11, "VIDI lands on the second drum hit")
	intro.advance(Intro.MOTTO_WORDS[2] + 0.2 - intro.elapsed)
	_check(motto.text == "VENI · VIDI · VICI" and motto.modulate.a > 0.99 and motto.visible_characters == -1, "motto is shown in full")
	_check(_find(intro, "Title").text == "IMPERATHEN", "title text")
	root.size = Vector2i(720, 1280)
	await _frames()
	var skip: Button = _find(_ui.get("_screen"), "IntroSkip")
	_check(skip != null and skip.size.y >= 46.0 and Rect2(Vector2.ZERO, Vector2(720, 1280)).encloses(skip.get_global_rect()), "skip button stays reachable in portrait")
	_check(intro.get_rect().size.x <= 720.5 and reveal.position.x >= 0 and reveal.get_global_rect().end.x <= 720.5, "intro relayouts for portrait without restarting")
	_check(bar.size.y < 0.5, "portrait phones use the full height (no bars)")
	root.size = Vector2i(1280, 720)
	await _frames()
	_ui._finish_intro()
	_ui.set("_always_intro", false)


func _check_trailer_and_profiles() -> void:
	var trailer := load(Intro.TRAILER_PATH) as AudioStreamOggVorbis
	_check(trailer != null and not trailer.loop and trailer.get_length() >= Intro.FULL_DURATION, "trailer sound covers the complete sequence once")
	_ui.set("_always_intro", true)
	_ui.show_intro()
	await _frames()
	_check(not _ui.get("_music_wanted"), "menu theme waits while the trailer sound plays")
	_ui._finish_intro()
	_ui.set("_always_intro", false)
	_ui.show_intro()
	await _frames()
	_check(_ui.get("_music_wanted"), "short title card goes straight into the menu theme")
	_ui._finish_intro()
	var amounts := {}
	for profile in ["low", "high"]:
		var intro: Control = Intro.new()
		intro.set_quality(profile)
		root.add_child(intro)
		intro.play(true, false)
		amounts[profile] = {"embers": (_find(intro, "Embers") as CPUParticles2D).amount, "far": _find(intro, "FarCohort") != null}
		intro.queue_free()
	await _frames()
	_check(amounts.low.embers < amounts.high.embers and not amounts.low.far and amounts.high.far, "effect density follows the graphics profile")
	var calm: Control = Intro.new()
	root.add_child(calm)
	calm.set_process(false)
	calm.play(true, true)
	calm.advance(1.5)
	var camera: Control = _find(calm, "Camera")
	_check(not calm.full and is_equal_approx(camera.scale.x, 1.0) and camera.position.length() < 0.01 and not (_find(calm, "Embers") as CPUParticles2D).emitting, "reduced motion: no camera moves, shake or particles")
	calm.queue_free()
	await _frames()


func _check_menu_buttons() -> void:
	var expected := {
		"Fortsetzen": "continue", "Neues Leben": "new_game", "Stadt frei erkunden": "city_exploration", "Talgefecht erproben": "valley_demo",
		"Weltkugel erkunden": "atlas_demo", "Figuren": "@gallery", "Einstellungen": "@settings", "Spiel beenden": "@confirm",
	}
	_ui.show_menu(true)
	await _frames()
	var buttons: Array[Button] = []
	_collect_buttons(_ui.get("_screen"), buttons)
	_check(buttons.size() == expected.size(), "menu has exactly the functional buttons: %s" % [buttons.map(func(b): return b.text)])
	var city: Button = _find(_ui.get("_screen"), "FreeCityExploration") as Button
	_check(city != null and city.text == "Stadt frei erkunden" and not city.disabled, "free city test entry is visible, correctly named and usable")
	for caption: String in expected.keys():
		_ui.show_menu(true)
		await _frames()
		var button := _find_button(_ui.get("_screen"), caption)
		if button == null:
			_check(false, "menu button exists: " + caption)
			continue
		_check(button.get_theme_stylebox("normal") is RomanStyle.TabulaBox, caption + " uses the Roman tabula style")
		_check(button.get_theme_font("font") is FontVariation and (button.get_theme_font("font") as FontVariation).base_font.resource_path.ends_with("Cinzel-Variable.ttf"), caption + " uses Cinzel")
		_events.clear()
		button.pressed.emit()
		await _frames()
		var target: String = expected[caption]
		if target.begins_with("@"):
			_check(_ui.get("_view_state") == target.substr(1), caption + " opens " + target.substr(1))
		else:
			_check(_events.has(target), caption + " requests " + target)
	_ui.show_menu(false)
	await _frames()
	var resume := _find_button(_ui.get("_screen"), "Fortsetzen")
	_check(resume.disabled and resume.tooltip_text != "", "continue without a save is disabled and explains why")


func _check_menu_layout() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(720, 1280), Vector2i(1080, 2340)]:
		root.size = size
		_ui.set("_touch_enabled", size.x != 1280)
		_ui.show_menu(true)
		await _frames()
		var label := "%dx%d" % [size.x, size.y]
		var scroll: ScrollContainer = _find(_ui.get("_screen"), "MenuScroll")
		var bar := scroll.get_v_scroll_bar()
		_check(bar.max_value <= scroll.size.y + 1.0, label + ": menu fits without scrolling")
		var buttons: Array[Button] = []
		_collect_buttons(_ui.get("_screen"), buttons)
		var safe := Rect2(Vector2.ZERO, Vector2(size)).grow(0.5)
		for button in buttons:
			_check(safe.encloses(button.get_global_rect()), "%s: %s inside the screen" % [label, button.text])
			_check(button.size.y >= 46.0, "%s: %s is a comfortable touch target (%.0f px)" % [label, button.text, button.size.y])
		var title: Label = _find(_ui.get("_screen"), "MenuTitle")
		_check(title.get_global_rect().end.x <= size.x and title.get_global_rect().position.y >= 0, label + ": title visible")
		var decor: Control = _find(_ui.get("_screen"), "MenuDecor")
		for item: Control in decor.get_children():
			for button in buttons:
				_check(not item.get_global_rect().intersects(button.get_global_rect()), "%s: %s keeps clear of %s" % [label, item.name, button.text])
		if size == Vector2i(1280, 720):
			_check(decor.get_child_count() >= 1 and _find(decor, "MenuBanner0") is Control, label + ": a legion banner flies beside the tablet")
	_ui.set("_touch_enabled", false)
	root.size = Vector2i(1280, 720)
	await _frames()


func _check_menu_look() -> void:
	_ui.show_menu(true)
	await _frames()
	var screen: Control = _ui.get("_screen")
	var title: Label = _find(screen, "MenuTitle")
	_check(title.material is ShaderMaterial and (title.material as ShaderMaterial).shader.resource_path.ends_with("imperial_metal.gdshader"), "menu title is polished metal")
	_check(title.get_theme_font_size("font_size") >= 66, "menu title is larger than before (58 px)")
	_check((_find(screen, "MenuTablet") as PanelContainer).get_theme_stylebox("panel") is RomanStyle.TabletBox, "tablet is marble in a bronze frame")
	_check(_find(screen, "MenuGrade") is ColorRect and _find(screen, "MenuEmbers") is CPUParticles2D, "menu stage grades the village and adds embers")
	_ui.set("_reduce_motion", true)
	_ui.show_menu(true)
	await _frames()
	screen = _ui.get("_screen")
	title = _find(screen, "MenuTitle")
	_check(_find(screen, "MenuEmbers") == null and is_zero_approx(float((title.material as ShaderMaterial).get_shader_parameter("auto_period"))), "reduced motion: no embers, no moving glint")
	_ui.set("_reduce_motion", false)


func _check_settings_and_music() -> void:
	var player: AudioStreamPlayer = _ui.get("_music_player")
	var stream := player.stream as AudioStreamOggVorbis
	_check(stream != null and stream.loop and stream.get_length() > 50.0 and stream.get_length() < 70.0, "menu theme is a looping Ogg Vorbis stream")
	_ui.show_menu(true)
	await _frames()
	_check(_ui.get("_music_wanted"), "music belongs to the main menu")
	_find_button(_ui.get("_screen"), "Einstellungen").pressed.emit()
	await _frames()
	_check(_ui.get("_music_wanted"), "music continues in the menu settings")
	var slider: HSlider = _find(_ui.get("_screen"), "MusicVolumeSetting")
	var toggle: CheckButton = _find(_ui.get("_screen"), "AlwaysIntroSetting")
	_check(slider != null and toggle != null, "settings offer music volume and intro preference")
	slider.value = 0.25
	toggle.button_pressed = true
	var config := ConfigFile.new()
	config.load(UIScript.SETTINGS_PATH)
	_check(is_equal_approx(float(config.get_value("audio", "music", -1.0)), 0.25) and bool(config.get_value("interface", "always_intro", false)), "music volume and intro preference persist")
	toggle.button_pressed = false
	var replay := _find_button(_ui.get("_screen"), "Vorspann jetzt ansehen")
	_check(replay != null, "intro can be watched again from the menu settings")
	_events.clear()
	replay.pressed.emit()
	await _frames()
	_check(_ui.get("_view_state") == "intro" and _ui.intro_is_full(), "replay shows the complete sequence")
	_ui._finish_intro()
	_check(_count("intro_finished") == 1, "replay returns to the menu")
	_ui.show_cinematic()
	_check(not _ui.get("_music_wanted"), "music hands over to the game")


func _frames() -> void:
	for frame in range(4):
		await process_frame


func _check(value: bool, description: String) -> void:
	_checks += 1
	if not value:
		_failures.append(description)
		printerr("FAIL ", description)


func _count(action: String) -> int:
	return _events.count(action)


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _find_button(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var found := _find_button(child, caption)
		if found != null:
			return found
	return null


func _collect_buttons(node: Node, target: Array[Button]) -> void:
	if node is Button and not node is OptionButton and node.is_visible_in_tree():
		target.append(node)
	for child in node.get_children():
		_collect_buttons(child, target)
