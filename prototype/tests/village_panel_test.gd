extends SceneTree
## Keep the player's location and input focus in actual long village panels.

const UI = preload("res://scripts/ui/game_ui.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
var failures: Array[String] = []
var checks := 0
var ui

class WorldInputProbe extends Node:
	var touches := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			touches += 1


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Village panel tests require disposable user directories.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var model = Model.new()
	model.new_game("italia", true)
	model.set_player_position(Vector3(2, 1, 9))
	_check(model.execute("village_talk", {"npc_id":"decimus", "choice":"meet"}).ok, "Meet the actual steward")
	_check(model.execute("village_request_work").ok, "Obtain the actual work permission")
	ui = UI.new()
	root.add_child(ui)
	await _frames()
	ui.show_village_panel(model.data, "work")
	await _frames()
	var scroll := _scroll()
	_check(scroll != null and scroll.scroll_vertical == 0, "A new work tab opens at its heading, not the bottom")
	_check(_focus_id() == "tab:work", "Keyboard and controller start on the active tab")
	var selector := _selector("assignment:fabius")
	_check(selector != null and not selector.disabled, "Fabius has an actual available selector")
	scroll.ensure_control_visible(selector)
	selector.grab_focus()
	await _frames()
	var previous := scroll.scroll_vertical
	_check(previous > 0, "The assignment list requires a real nonzero scroll offset")
	_check(model.execute("village_assign", {"resident_id":"fabius", "workplace_id":"woodcamp"}).ok, "The selected worker is assigned through real rules")
	ui.show_village_panel(model.data, "work")
	await _frames()
	_check(_scroll().scroll_vertical == previous, "A worker change preserves the current scroll position")
	_check(_focus_id() == "assignment:fabius", "A rebuilt worker control retains keyboard and controller focus")
	_check(_selector("assignment:fabius").get_item_text(_selector("assignment:fabius").selected) == "Holzfällerlager", "The rebuilt selector reflects the real assignment")
	ui.show_village_panel(model.data, "map")
	await _frames()
	_check(_scroll().scroll_vertical == 0 and _focus_id() == "tab:map", "Changing tab starts its new content at the top")
	ui.notify("Eine alte Meldung darf das Gespräch nicht verdecken.")
	var dialog := Life.dialogue(model.data, "decimus")
	dialog["feedback"] = "Du hilfst beim Wiederaufbau."
	ui.show_village_dialog(dialog)
	await _frames()
	_check(not ui.get("_toast_panel").visible, "The conversation removes the overlapping old toast")
	var feedback: Label = ui.get("_screen").find_child("ConversationFeedback", true, false)
	_check(feedback != null and feedback.text == dialog.feedback, "Conversation outcomes remain readable inside the actual dialogue")
	ui.notify("Alte Nachricht")
	ui.show_village_panel(model.data, "overview")
	await _frames()
	_check(not ui.get("_toast_panel").visible, "A new village panel clears stale overlays")
	root.size = Vector2i(540, 960)
	await _frames()
	ui.show_village_panel(model.data, "work")
	await _frames()
	_check(_scroll().scroll_vertical == 0, "The narrow work panel also opens at the beginning")
	await _native_scroll_regression(model)
	ui.queue_free()
	await _frames()
	print("VILLAGE_PANEL_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("VILLAGE_PANEL_PASS" if failures.is_empty() else "VILLAGE_PANEL_FAIL")
	quit(0 if failures.is_empty() else 1)


func _native_scroll_regression(model) -> void:
	# Desktop Godot enables its touchscreen ScrollContainer path through this
	# switch; actual input below remains native touch/drag, as on Android.
	var old_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	var world_probe := WorldInputProbe.new()
	root.add_child(world_probe)
	var requests: Array[String] = []
	var route := func(action: String, payload: Dictionary):
		requests.append(action)
		if action == "village_panel":
			ui.show_village_panel(model.data, str(payload.get("tab", "overview")))
	ui.action_requested.connect(route)
	for viewport: Vector2i in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = viewport
		await _frames()
		ui.show_village_panel(model.data, "overview")
		await _frames()
		var tab: Button
		for candidate: Node in ui.get("_screen").find_children("*", "Button", true, false):
			if str(candidate.get_meta("village_focus_id", "")) == "tab:work":
				tab = candidate as Button
		_check(tab != null, "The work tab is available at %s" % viewport)
		if tab == null:
			continue
		await _native_tap(tab.get_global_rect().get_center())
		await _frames()
		_check(ui.get("_village_tab") == "work", "Native touch opens the actual work tab at %s" % viewport)
		var scroll := _scroll()
		var selector := _selector("assignment:aelia")
		_check(scroll != null and selector != null and not selector.disabled, "The enabled Aelia selector exists at %s" % viewport)
		if scroll == null or selector == null:
			continue
		_check(selector.mouse_filter == Control.MOUSE_FILTER_STOP, "The popup selector retains its own press/release at %s" % viewport)
		_check(not _inside_scroll(selector, scroll), "Aelia initially requires a real scroll at %s" % viewport)
		var initial_y := selector.get_global_rect().get_center().y
		var before_state := JSON.stringify(model.data)
		requests.clear()
		world_probe.touches = 0
		var swipes := 0
		for attempt in 14:
			if _inside_scroll(selector, scroll):
				break
			var bounds := scroll.get_global_rect()
			var start := bounds.position + bounds.size * Vector2(0.82, 0.80)
			var finish := bounds.position + bounds.size * Vector2(0.82, 0.25)
			await _native_swipe(start, finish)
			swipes += 1
			await _frames()
		print("VILLAGE_TOUCH_SCROLL viewport=%s swipes=%d offset=%d initial_y=%.2f final_y=%.2f world_touches=%d actions=%s" % [viewport, swipes, scroll.scroll_vertical, initial_y, selector.get_global_rect().get_center().y, world_probe.touches, requests])
		_check(scroll.scroll_vertical > 0 and selector.get_global_rect().get_center().y < initial_y, "A native card swipe moves actual work content at %s" % viewport)
		_check(_inside_scroll(selector, scroll), "Native swipes reveal Aelia inside the clipped panel at %s" % viewport)
		_check(requests.is_empty() and JSON.stringify(model.data) == before_state, "Scrolling triggers no repairs, tab changes or worker assignment at %s" % viewport)
		_check(world_probe.touches == 0, "The modal consumes native touch before underlying world input at %s" % viewport)
		var repair := _visible_repair_button(scroll)
		_check(repair != null, "A real enabled repair button is visible for the cancellation check at %s" % viewport)
		if repair != null:
			requests.clear()
			world_probe.touches = 0
			var previous_offset := scroll.scroll_vertical
			var start := repair.get_global_rect().get_center()
			var finish := Vector2(start.x, maxf(scroll.get_global_rect().position.y + 16.0, start.y - 180.0))
			await _native_swipe(start, finish)
			await _frames()
			print("VILLAGE_BUTTON_SWIPE viewport=%s offset_before=%d offset_after=%d world_touches=%d actions=%s" % [viewport, previous_offset, scroll.scroll_vertical, world_probe.touches, requests])
			_check(scroll.scroll_vertical > previous_offset, "A native swipe beginning on an enabled repair button scrolls at %s" % viewport)
			_check(requests.is_empty() and JSON.stringify(model.data) == before_state, "An enabled repair button cancels its command when dragged at %s" % viewport)
			_check(world_probe.touches == 0, "The repair-button swipe stays inside the modal at %s" % viewport)
	ui.action_requested.disconnect(route)
	world_probe.queue_free()
	Input.emulate_touch_from_mouse = old_emulation
	await _frames()


func _inside_scroll(control: Control, scroll: ScrollContainer) -> bool:
	return root.get_visible_rect().has_point(control.get_global_rect().get_center()) and scroll.get_global_rect().has_point(control.get_global_rect().get_center())


func _visible_repair_button(scroll: ScrollContainer) -> Button:
	var found: Button
	for candidate: Node in ui.get("_screen").find_children("*", "Button", true, false):
		if not candidate.disabled and str(candidate.get_meta("village_focus_id", "")).begins_with("village_repair:") and _inside_scroll(candidate, scroll):
			var center: Vector2 = candidate.get_global_rect().get_center()
			if center.y > scroll.get_global_rect().position.y + 70.0 and (found == null or center.y > found.get_global_rect().get_center().y):
				found = candidate as Button
	return found


func _native_tap(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = down
		event.position = point
		Input.parse_input_event(event)
		await process_frame


func _native_swipe(start: Vector2, finish: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = start
	Input.parse_input_event(touch)
	await process_frame
	var previous := start
	# Thirty-six native drag samples match the emulator's 600 ms swipe at 60 Hz.
	for sample in range(1, 37):
		var point := start.lerp(finish, float(sample) / 36.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point
		drag.relative = point - previous
		drag.screen_relative = drag.relative
		drag.velocity = drag.relative * 60.0
		drag.screen_velocity = drag.velocity
		Input.parse_input_event(drag)
		previous = point
		await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = finish
	touch.pressed = false
	Input.parse_input_event(touch)
	await process_frame


func _frames() -> void:
	for index in 5:
		await process_frame


func _scroll() -> ScrollContainer:
	var values: Array[Node] = ui.get("_screen").find_children("*", "ScrollContainer", true, false)
	return values[0] as ScrollContainer if not values.is_empty() else null


func _selector(id: String) -> OptionButton:
	for control: Node in ui.get("_screen").find_children("*", "OptionButton", true, false):
		if control.get_meta("village_focus_id", "") == id:
			return control as OptionButton
	return null


func _focus_id() -> String:
	var owner: Control = root.gui_get_focus_owner()
	return str(owner.get_meta("village_focus_id", "")) if is_instance_valid(owner) else ""


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
