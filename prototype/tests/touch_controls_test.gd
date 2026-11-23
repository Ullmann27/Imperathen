extends SceneTree
## Native touch events through the real viewport, with independent world-input probe.

const UI = preload("res://scripts/ui/game_ui.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
var failures: Array[String] = []
var checks := 0
var events: Array[Dictionary] = []
var ui
var model
var probe

class WorldInputProbe extends Node:
	var touches := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			touches += 1


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Touch tests require disposable user directories.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	model = Model.new()
	model.new_game("italia", true)
	if not Combat.enabled(model.data):
		Combat.start(model.data)
	probe = WorldInputProbe.new()
	root.add_child(probe)
	ui = UI.new()
	root.add_child(ui)
	await _frames()
	ui.set("_touch_enabled", true)
	ui.action_requested.connect(func(action: String, payload: Dictionary): events.append({"action": action, "payload": payload.duplicate(true)}))
	ui.show_game(_ui_state())
	await _frames()
	for extent: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(820,480), Vector2i(900,900), Vector2i(480,840), Vector2i(640,360)]:
		root.size = extent
		await _frames()
		ui.show_game(_ui_state())
		await _frames()
		_check_bounds(extent)
	root.size = Vector2i(1280,720)
	await _frames()
	ui.show_game(_ui_state())
	await _frames()
	await _three_fingers()
	await _pinch()
	await _pace()
	await _cancellation()
	await _lifecycle()
	await _techniques()
	await _command_menu()
	# One folded layout with text scaling and a real safe rectangle.
	root.size = Vector2i(960,720)
	await _frames()
	ui.set("_ui_scale", 1.25)
	ui._apply_safe_rect(Rect2(34,16,892,680))
	ui.show_game(_ui_state())
	await _frames()
	_check_controls_inside(Rect2(34,16,892,680), "Fold safe area at text scale 1.25")
	ui.queue_free()
	probe.queue_free()
	await _frames()
	print("TOUCH_CONTROLS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("TOUCH_CONTROLS_PASS" if failures.is_empty() else "TOUCH_CONTROLS_FAIL")
	quit(0 if failures.is_empty() else 1)


func _ui_state() -> Dictionary:
	var state: Dictionary = model.data.duplicate(true)
	state["frontier_objective"] = model.get_frontier_objective()
	state["village_view"] = preload("res://scripts/story/village_life.gd").view(model.data)
	state["village_economy_view"] = preload("res://scripts/domain/village_economy.gd").view(model.data)
	return state


func _check_bounds(extent: Vector2i) -> void:
	var name := str(extent)
	_check_controls_inside(Rect2(Vector2.ZERO, Vector2(extent)), name)
	var pad: Control = ui.get("_touch_pad")
	var screen: Control = ui.get("_screen")
	var actions: Control = screen.get_node("TouchActions")
	var toolbar: Control = screen.get_node("TouchToolbar")
	var objective: Control = screen.get_node("ObjectiveCard")
	_check(not pad.get_global_rect().intersects(actions.get_global_rect()), name + ": movement and action fingers have disjoint targets")
	_check(not pad.get_global_rect().intersects(toolbar.get_global_rect()), name + ": raised pad clears the navigation bar")
	_check(not actions.get_global_rect().intersects(toolbar.get_global_rect()), name + ": actions clear the navigation bar")
	_check(not pad.get_global_rect().intersects(objective.get_global_rect()), name + ": objective does not cover the movement pad")
	_check(not actions.get_global_rect().intersects(objective.get_global_rect()), name + ": objective does not cover action buttons")
	_check(pad.size.x >= 156 and pad.size.y >= 156, name + ": analog capture area remains at least 156 units wide")
	_check(pad.get_global_rect().end.y <= extent.y - 88, name + ": pad is raised from the gesture edge")


func _check_controls_inside(bounds: Rect2, name: String) -> void:
	var screen: Control = ui.get("_screen")
	for id in ["MovementPad", "TouchActions", "TouchToolbar", "ResourceBar", "ObjectiveCard"]:
		var control: Control = screen.get_node(id)
		_check(bounds.grow(1).encloses(control.get_global_rect()), name + ": " + id + " stays inside the usable display")
	for button: Button in ui.get("_touch_actions"):
		if button.is_visible_in_tree():
			_check(button.size.y >= 48, name + ": " + button.name + " retains a 48-unit touch target")
			_check(bounds.grow(1).encloses(button.get_global_rect()), name + ": " + button.name + " remains on screen")


func _three_fingers() -> void:
	var pad: Control = ui.get("_touch_pad")
	var look: Control = ui.get("_touch_look")
	var pad_point: Vector2 = pad.get_global_rect().get_center() + Vector2(0,-38)
	var camera_point := Vector2(800,320)
	var attack_point := _button("attack").get_global_rect().get_center()
	events.clear()
	probe.touches = 0
	await _touch(0,true,pad_point)
	await _touch(1,true,camera_point)
	await _touch(2,true,attack_point)
	_check(pad.touch_index == 0 and pad.axis.y < -0.1, "First native finger keeps analog movement")
	_check(look.contacts.has(1) and look.contacts.size() == 1, "Second native finger owns only camera look")
	_check(_button("attack").touch_index == 2 and _count("attack") == 1, "Third native finger starts exactly one selected attack")
	await _drag(1,camera_point + Vector2(24,10),Vector2(24,10))
	_check(_count("camera_look") == 1 and _last("camera_look").payload == {"x":24.0,"y":10.0}, "Camera drag emits its exact delta once while movement and attack are held")
	await _drag(2,camera_point,Vector2(-30,-30))
	_check(_count("camera_look") == 1 and _count("attack") == 1, "An action finger dragged into the world cannot become a camera or repeat a hit")
	await _drag(1,attack_point,attack_point-camera_point-Vector2(24,10))
	_check(_count("camera_look") == 2 and _count("attack") == 1, "An owned camera finger crossing the attack button cannot press it")
	await _touch(2,false,camera_point)
	_check(pad.touch_index == 0 and look.contacts.has(1), "Releasing attack leaves both other contacts active")
	await _touch(0,false,pad_point)
	_check(pad.axis.is_zero_approx() and look.contacts.has(1), "Releasing movement stops movement without ending the camera contact")
	await _touch(1,false,attack_point)
	_check(look.contacts.is_empty() and probe.touches == 0, "Every claimed move/camera/action event is consumed before world fallback")


func _pinch() -> void:
	events.clear()
	var start_a := Vector2(700,300)
	var start_b := Vector2(900,300)
	await _touch(4,true,start_a)
	await _touch(5,true,start_b)
	await _drag(5,Vector2(940,300),Vector2(40,0))
	_check(_count("camera_zoom") == 1 and is_equal_approx(float(_last("camera_zoom").payload.factor),200.0/240.0), "Two free camera fingers pinch by their real distance ratio")
	_check(_count("camera_look") == 0, "Pinch does not also rotate the camera")
	await _touch(5,false,Vector2(940,300))
	await _drag(4,start_a+Vector2(7,3),Vector2(700,300))
	_check(_last("camera_look").payload == {"x":7.0,"y":3.0}, "Ending a pinch returns to look without using an unrelated stale relative delta")
	await _touch(4,false,start_a+Vector2(7,3))


func _pace() -> void:
	events.clear()
	var pad: Control = ui.get("_touch_pad")
	var point := pad.get_global_rect().get_center() + Vector2(25,0)
	await _touch(7,true,point)
	await _tap(8,_button("pace").get_global_rect().get_center())
	_check(_count("movement_pace") == 1 and _last("movement_pace").payload.running, "A second finger switches from walking to running")
	_check(pad.touch_index == 7 and pad.axis.x > 0, "Changing pace preserves the held movement direction")
	_check(_button("pace").text == "Laufen", "The pace caption displays the active movement mode")
	await _tap(8,_button("pace").get_global_rect().get_center())
	_check(not _last("movement_pace").payload.running and _button("pace").text == "Gehen", "The same reachable control returns to walking")
	await _touch(7,false,point)


func _cancellation() -> void:
	var pad: Control = ui.get("_touch_pad")
	var point := pad.get_global_rect().get_center() + Vector2(0,-30)
	await _touch(9,true,point)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 9
	canceled.pressed = true
	canceled.canceled = true
	canceled.position = point
	root.push_input(canceled,true)
	await process_frame
	_check(pad.touch_index == -1 and pad.axis.is_zero_approx(), "Android cancellation neutralizes a contact even when its pressed bit is still set")
	var button := _button("guard")
	await _touch(9,true,button.get_global_rect().get_center())
	canceled.position = button.get_global_rect().get_center()
	root.push_input(canceled,true)
	await process_frame
	_check(button.touch_index == -1, "Canceled action contacts cannot remain latched")


func _lifecycle() -> void:
	var point: Vector2 = ui.get("_touch_pad").get_global_rect().get_center() + Vector2(35,0)
	await _touch(10,true,point)
	await _touch(11,true,Vector2(800,320))
	await _touch(12,true,_button("guard").get_global_rect().get_center())
	ui.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(ui.get("_touch_pad").axis.is_zero_approx() and ui.get("_touch_look").contacts.is_empty(), "Backgrounding clears both analog and camera captures")
	var cleared := true
	for button: Button in ui.get("_touch_actions"):
		cleared = cleared and button.touch_index == -1
	_check(cleared, "Backgrounding clears every action finger")
	events.clear()
	await _drag(10,point+Vector2(20,0),Vector2(20,0))
	await _drag(11,Vector2(820,320),Vector2(20,0))
	_check(_count("move_axis") == 0 and _count("camera_look") == 0, "Orphaned drags after suspension cannot restart movement or camera")
	await _touch(10,false,point)
	await _touch(11,false,Vector2(820,320))
	await _touch(12,false,_button("guard").get_global_rect().get_center())
	await _touch(14,true,point)
	ui.show_pause()
	await _frames()
	_check(_last("move_axis").payload == {"x":0.0,"y":0.0}, "Opening pause sends the neutral analog axis before freeing gameplay controls")
	ui.show_game(_ui_state())
	await _frames()
	_check(ui.get("_touch_pad").touch_index == -1 and ui.get("_touch_look").contacts.is_empty(), "Returning from pause starts with no retained fingers")


func _techniques() -> void:
	var old_emulation := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	events.clear()
	await _tap(0,_button("techniques").get_global_rect().get_center())
	await _frames()
	var overlay: Control = ui.get("_technique_menu_layer")
	_check(overlay != null and overlay.visible and not ui.get("_touch_pad").visible, "Technique list opens on demand and stops gameplay touch capture")
	var choices := overlay.find_children("Technique_*", "Button", true, false)
	_check(choices.size() == 10, "The menu exposes all ten named techniques without ten permanent action buttons")
	var high: Button = overlay.find_child("Technique_high_kick", true, false)
	_check(high.disabled and high.text.contains("14 Übungstreffern"), "A locked high kick explains its actual learning requirement")
	var scroll: ScrollContainer = overlay.find_child("ChoicesScroll", true, false)
	var before_choices := _count("select_technique")
	for attempt in 3:
		var bounds := scroll.get_global_rect()
		await _native_swipe(bounds.get_center() + Vector2(0, bounds.size.y * 0.25), bounds.get_center() - Vector2(0, bounds.size.y * 0.30))
		await _frames()
	_check(scroll.scroll_vertical > 0 and scroll.get_global_rect().intersects(high.get_global_rect()), "Native swipes reach the lower techniques in the actual ScrollContainer")
	_check(_count("select_technique") == before_choices and overlay.visible, "Scrolling across technique buttons does not accidentally select a move")
	scroll.scroll_vertical = 0
	await _frames()
	var right: Button = overlay.find_child("Technique_jab_right", true, false)
	await _native_tap(right.get_global_rect().get_center())
	await _frames()
	_check(ui.get("_selected_technique") == "jab_right" and not overlay.visible, "A native tap selects the available right straight and closes the list")
	_check(_count("attack") == 0, "Choosing a technique does not itself execute an attack")
	await _tap(2,_button("attack").get_global_rect().get_center())
	_check(_count("attack") == 1 and _last("attack").payload.technique == "jab_right", "The actual attack button submits the selected technique ID")
	Input.emulate_touch_from_mouse = old_emulation


func _command_menu() -> void:
	await _tap(3,ui.get("_screen").get_node("TouchToolbar").find_child("OpenCommands",true,false).get_global_rect().get_center())
	await _frames()
	_check(ui.get("_touch_menu_layer").visible and not ui.get("_screen").get_node("TouchToolbar").visible, "Construction and training are reachable without covering gameplay controls permanently")
	probe.touches = 0
	await _tap(4,Vector2(20,330))
	_check(probe.touches == 0, "Touching the menu backdrop never leaks into world camera handling")
	_check(ui.handle_back() and not ui.get("_touch_menu_layer").visible, "Android Back first closes the open action menu")
	_check(ui.get("_touch_pad").visible, "Closing the menu restores movement with a fresh contact")


func _button(action: String) -> Button:
	for button: Button in ui.get("_touch_actions"):
		if str(button.get_meta("touch_action", "")) == action:
			return button
	return null


func _count(action: String) -> int:
	var result := 0
	for event in events:
		if event.action == action:
			result += 1
	return result


func _last(action: String) -> Dictionary:
	for index in range(events.size()-1,-1,-1):
		if events[index].action == action:
			return events[index]
	return {"action":action,"payload":{}}


func _touch(index: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	root.push_input(event,true)
	await process_frame


func _drag(index: int, point: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = delta
	event.screen_relative = delta
	root.push_input(event,true)
	await process_frame


func _tap(index: int, point: Vector2) -> void:
	await _touch(index,true,point)
	await _touch(index,false,point)


func _native_tap(point: Vector2) -> void:
	for down in [true,false]:
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
	for sample in range(1,25):
		var point := start.lerp(finish,float(sample)/24.0)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point
		drag.relative = point-previous
		drag.screen_relative = drag.relative
		drag.velocity = drag.relative*60.0
		drag.screen_velocity = drag.velocity
		Input.parse_input_event(drag)
		previous = point
		await process_frame
	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = false
	touch.position = finish
	Input.parse_input_event(touch)
	await process_frame


func _frames() -> void:
	for index in 5:
		await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
