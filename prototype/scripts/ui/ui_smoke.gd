extends SceneTree
## Headless behavior/layout checks. tools/check_prototype.py supplies disposable user data.

var _ui: CanvasLayer
var _events: Array[Dictionary] = []
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Run the UI smoke test through tools/check_prototype.py with isolated user data.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	_ui = load("res://scripts/ui/game_ui.gd").new()
	root.add_child(_ui)
	_ui.action_requested.connect(func(action: String, payload: Dictionary): _events.append({"action": action, "payload": payload}))
	await _frames()
	_ui.show_intro()
	await _frames()
	_check(_ui.get("_view_state") == "intro", "intro opens")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	_ui._unhandled_input(enter)
	_ui._unhandled_input(enter)
	_check(_count("intro_finished") == 1, "intro skip emits once")
	_ui.show_menu(false)
	await _frames()
	_check(_button("Fortsetzen").disabled, "continue unavailable without save")
	_button("Neues Leben").pressed.emit()
	_check(_events.back().action == "new_game", "new game delegates to root")
	_ui.show_menu(true)
	await _frames()
	_check(not _button("Fortsetzen").disabled, "continue available with save")
	_button("Einstellungen").pressed.emit()
	await _frames()
	_check(_ui.get("_view_state") == "settings", "settings open")
	var touch_setting: CheckButton = _ui.get("_screen").find_child("TouchControlsSetting", true, false)
	touch_setting.button_pressed = true
	_ui.set("_ui_scale", 1.25)
	_ui.set("_reduce_motion", true)
	_ui.set("_volume", 0.35)
	_ui._apply_scale(_ui.get("_root"))
	var quality: OptionButton = _ui.get("_screen").find_child("QualitySetting", true, false)
	quality.select(2)
	quality.item_selected.emit(2)
	_check(_events.back().action == "quality_changed" and _events.back().payload.profile == "high", "quality selection routes real profile")
	_ui._save_settings()
	_ui.set("_touch_enabled", false)
	_ui.set("_ui_scale", 1.0)
	_ui.set("_quality", "low")
	_ui._load_settings()
	_check(_ui.get("_touch_enabled") and is_equal_approx(_ui.get("_ui_scale"), 1.25), "touch and scale persisted")
	_check(_ui.get("_reduce_motion") and is_equal_approx(_ui.get("_volume"), 0.35), "motion and audio persisted")
	_check(_ui.get_quality() == "high", "quality getter restores persisted profile")
	var model = load("res://scripts/domain/world_model.gd").new()
	model.new_game()
	var state: Dictionary = model.data.duplicate(true)
	state.resources.wood = 12
	_ui.show_game(state)
	await _frames()
	_check(_ui.get("_screen").mouse_filter == Control.MOUSE_FILTER_IGNORE, "empty HUD permits world input")
	_check(_ui.get("_hud_labels").wood.text == "12  Holz", "actual resource display")
	_check(not _ui.get("_action_buttons").build.disabled and _ui.get("_action_buttons").train.disabled, "button prerequisites")
	_check_layout(Vector2(1280, 720), "1280x720 touch at 125 percent")
	var pad: Control = _ui.get("_touch_pad")
	var center := pad.get_global_rect().get_center()
	_touch(7, true, center + Vector2(30, -20))
	_check(pad.get("touch_index") == 7, "analog captures native touch index")
	_check(_axis().x > 0 and _axis().y < 0, "analog reports forward-right axis")
	var attack: Button = _ui.get("_touch_actions")[1]
	var attack_center := attack.get_global_rect().get_center()
	var attacks_before := _count("attack")
	_touch(9, true, attack_center)
	_check(_count("attack") == attacks_before + 1 and pad.get("touch_index") == 7, "second finger attacks without stealing movement")
	_touch(9, false, attack_center)
	_check(pad.get("touch_index") == 7, "unrelated release preserves analog capture")
	_drag(7, center + Vector2(400, -240))
	_check(_axis().length() <= 1.0001 and _axis().length() > 0.99, "drag outside clamps analog length")
	_touch(7, false, center + Vector2(400, -240))
	_check(_axis().is_zero_approx() and pad.get("touch_index") == -1, "outside release resets motion")
	_touch(11, true, center + Vector2(-40, 0))
	_ui.show_pause()
	_check(_axis().is_zero_approx(), "modal opening clears movement")
	await _frames()
	_button("Weiterspielen").pressed.emit()
	_check(_events.back().action == "resume", "pause return action")
	_ui.show_game(state)
	await _frames()
	pad = _ui.get("_touch_pad")
	center = pad.get_global_rect().get_center()
	_touch(12, true, center + Vector2(20, 30))
	_ui.set_mode("city")
	_check(_axis().is_zero_approx() and not pad.visible, "mode switch resets and hides movement pad")
	_ui.set_build_active(true)
	await _frames()
	var cancel: Button = _ui.get("_cancel_build_button")
	_check(cancel.visible, "build cancel visibly available")
	_touch(13, true, cancel.get_global_rect().get_center())
	_check(_events.back().action == "cancel_build" and not cancel.visible, "native cancel touch routes command")
	_touch(13, false, cancel.get_global_rect().get_center())
	_ui.set_build_active(true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_ui._unhandled_input(escape)
	_check(_events.back().action == "cancel_build" and not _ui.get("_build_active"), "Escape cancels an active build instead of opening pause")
	_ui.set_mode("person")
	await _frames()
	pad = _ui.get("_touch_pad")
	center = pad.get_global_rect().get_center()
	_touch(14, true, center + Vector2(30, 0))
	pad.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_check(_axis().is_zero_approx() and pad.get("touch_index") == -1, "focus loss clears held touch")
	var interact: Button = _ui.get("_touch_actions")[0]
	_touch(15, true, interact.get_global_rect().get_center())
	_check(_events.back().action == "interact", "native interact touch routes command")
	_touch(15, false, interact.get_global_rect().get_center())
	root.size = Vector2i(960, 540)
	await _frames()
	await _frames()
	_check_layout(Vector2(960, 540), "960x540 touch at 125 percent")
	_check(_ui.get("_compact_layout"), "compact HUD selected on smaller viewport")
	_button("Chronik").pressed.emit()
	await _frames()
	_check(_ui.get("_view_state") == "journal" and _events.back().action == "pause", "journal asks root to pause")
	_check(_find_scroll(_ui.get("_screen")) != null, "compact journal is scrollable")
	_ui.show_dialog("Marcus", "Eine Entscheidung mit Folgen.", [{"label": "Holz teilen", "action": "companion_help"}, {"label": "Ablehnen", "action": "companion_decline"}])
	await _frames()
	_button("Holz teilen").pressed.emit()
	_check(_events.back().action == "companion_help", "companion action preserved")
	_ui.show_dialog("Der Morgen danach", "Eine Entscheidung. ".repeat(30), [{"id": "protect", "label": "Ich werde diesen Menschen zuerst Nahrung und Schutz geben, auch wenn die Angreifer dadurch entkommen könnten."}])
	await _frames()
	var choice := _button("Ich werde diesen Menschen zuerst Nahrung und Schutz geben, auch wenn die Angreifer dadurch entkommen könnten.")
	_check(choice.autowrap_mode != TextServer.AUTOWRAP_OFF, "long choices wrap")
	choice.pressed.emit()
	_check(_events.back().action == "story_choice" and _events.back().payload.choice == "protect", "story id maps to payload")
	var scroll := _find_scroll(_ui.get("_screen"))
	_check(scroll != null and scroll.follow_focus, "long modal scroll follows focus")
	_ui.show_dialog("Abschnitt abgeschlossen", "Deine Chronik bleibt bestehen.", [])
	await _frames()
	_check(_button("Zurück ins Spiel") != null, "empty choices retain exit")
	_ui.notify("Spielstand gespeichert.")
	_check(_ui.get("_toast_panel").visible, "notification visible")
	await _check_android_lifecycle(state)
	_ui.set("_touch_enabled", false)
	_ui.set("_ui_scale", 1.0)
	_ui.set("_quality", "balanced")
	_ui.set("_reduce_motion", false)
	_ui._save_settings()
	_ui.queue_free()
	await _frames()
	await create_timer(0.15).timeout
	if _failures.is_empty():
		print("UI_SMOKE_PASS checks=", _checks, " native touch/back/background/safe-area/resize/persistence checks; headless, no device or visual performance claim")
	else:
		for failure in _failures:
			push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _frames() -> void:
	await process_frame
	await process_frame
	await process_frame


func _check_android_lifecycle(state: Dictionary) -> void:
	_ui.show_game(state)
	_ui.set_mode("person")
	_ui.set_build_active(false)
	await _frames()
	var pad: Control = _ui.get("_touch_pad")
	var center := pad.get_global_rect().get_center()
	_touch(31, true, center + Vector2(35, -10))
	_ui.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(_axis().is_zero_approx() and pad.get("touch_index") == -1, "app background clears native capture")
	var movement_events := _count("move_axis")
	_drag(31, center + Vector2(100, -60))
	_check(_count("move_axis") == movement_events, "stale background drag cannot restart movement")
	_ui.show_pause()
	var resumes := _count("resume")
	_ui.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await _frames()
	_check(_ui.get("_view_state") == "pause" and _count("resume") == resumes, "app resume retains pause instead of resuming combat")
	_ui._show_settings("pause")
	await _frames()
	_check(_ui.handle_back() and _ui.get("_view_state") == "pause", "Android back from settings returns to pause")
	_check(_count("resume") == resumes, "leaving settings does not resume world")
	_ui.handle_back()
	_check(_events.back().action == "resume", "Android back resumes from pause")
	_ui.show_menu(true)
	await _frames()
	var quits := _count("quit")
	_ui.handle_back()
	_check(_ui.get("_view_state") == "confirm" and _count("quit") == quits, "Android back at main menu confirms instead of quitting")
	root.size = Vector2i(1200, 900)
	await _frames()
	await _frames()
	_check(_ui.get("_view_state") == "confirm", "tablet resize preserves confirmation")
	_ui.handle_back()
	_check(_ui.get("_view_state") == "menu" and _count("quit") == quits, "resized confirmation keeps original return screen")
	var choices := [{"id": "protect", "label": "Beim Dorf bleiben"}, {"id": "pursue", "label": "Die Angreifer verfolgen"}]
	_ui.show_dialog("Ein offener Entschluss", "Diese Wahl darf beim Falten des Geräts nicht verschwinden.", choices)
	var decisions := _count("story_choice")
	_ui.handle_back()
	_check(_ui.get("_view_state") == "dialog" and _count("story_choice") == decisions, "Android back cannot fabricate or discard a story choice")
	root.size = Vector2i(960, 540)
	await _frames()
	await _frames()
	_check(_ui.get("_view_state") == "dialog" and _button("Beim Dorf bleiben") != null, "fold-size transition retains live dialog options")
	_check(_count("story_choice") == decisions, "dialog resize does not choose an answer")
	_check_modal_bounds(Rect2(Vector2.ZERO, Vector2(960, 540)), "resized dialog")
	var screen_transform := Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2.ZERO)
	var safe: Rect2 = _ui._safe_rect_from_display(Rect2(96, 48, 1728, 936), screen_transform, Vector2(960, 540))
	_check(safe.is_equal_approx(Rect2(48, 24, 864, 468)), "physical display insets map to logical viewport coordinates")
	_check(_ui._safe_rect_from_display(Rect2(), screen_transform, Vector2(960, 540)).is_equal_approx(Rect2(0, 0, 960, 540)), "missing display safe area falls back to full viewport")
	_ui._apply_safe_rect(safe)
	_ui.show_game(state)
	_ui.set_mode("person")
	await _frames()
	_check_layout_region(safe, "landscape with cutout and navigation insets")
	pad = _ui.get("_touch_pad")
	var objective: Control = _ui.get("_hud_labels").objective_title.get_parent().get_parent()
	_check(not objective.get_global_rect().intersects(pad.get_global_rect()), "compact objective does not cover movement pad inside safe area")
	center = pad.get_global_rect().get_center()
	_touch(41, true, center + Vector2(0, -35))
	_check(_axis().y < 0 and absf(_axis().x) < 0.01, "touch coordinates remain correct after safe-area offset")
	_touch(41, false, center)
	_ui.show_dialog("Sichere Bildschirmfläche", "Auch eine lange Antwort bleibt zwischen Kameraausschnitt und Systemleiste erreichbar.", choices)
	await _frames()
	_check_modal_bounds(safe, "dialog inside display safe area")
	_ui._apply_safe_rect(Rect2(Vector2.ZERO, Vector2(960, 540)))
	root.size = Vector2i(1200, 900)
	await _frames()
	await _frames()
	_ui.show_game(state)
	await _frames()
	_check_layout(Vector2(1200, 900), "tablet landscape at 125 percent")
	_check("WASD" not in _ui.get("_hud_labels").controls.text and "Linksklick" not in _ui.get("_hud_labels").controls.text, "mobile guidance does not require keyboard or mouse")


func _check_modal_bounds(region: Rect2, description: String) -> void:
	var scroll := _find_scroll(_ui.get("_screen"))
	_check(scroll != null and region.encloses(scroll.get_parent().get_global_rect()), description + " outer panel stays inside safe area")


func _check(value: bool, description: String) -> void:
	_checks += 1
	if not value:
		_failures.append(description)


func _count(action: String) -> int:
	var count := 0
	for event in _events:
		if event.action == action:
			count += 1
	return count


func _axis() -> Vector2:
	for index in range(_events.size() - 1, -1, -1):
		if _events[index].action == "move_axis":
			return Vector2(float(_events[index].payload.x), float(_events[index].payload.y))
	return Vector2.ZERO


func _touch(index: int, pressed: bool, position: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	root.push_input(event, true)


func _drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	root.push_input(event, true)


func _button(caption: String, node: Node = null) -> Button:
	if node == null:
		node = _ui.get("_screen")
	if node is Button and node.text == caption:
		return node
	for child in node.get_children():
		var result := _button(caption, child)
		if result != null:
			return result
	return null


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var result := _find_scroll(child)
		if result != null:
			return result
	return null


func _check_layout(viewport_size: Vector2, description: String) -> void:
	_check_layout_region(Rect2(Vector2.ZERO, viewport_size), description)


func _check_layout_region(region: Rect2, description: String) -> void:
	var controls: Array[Control] = []
	_collect_controls(_ui.get("_screen"), controls)
	for control in controls:
		if not control.is_visible_in_tree():
			continue
		if control is Button or control is PanelContainer or control == _ui.get("_touch_pad"):
			var rect: Rect2 = control.get_global_rect()
			_check(region.grow(0.5).encloses(rect), "%s: %s within usable area: %s" % [description, control.name, rect])


func _collect_controls(node: Node, target: Array[Control]) -> void:
	if node is Control:
		target.append(node)
	for child in node.get_children():
		_collect_controls(child, target)
