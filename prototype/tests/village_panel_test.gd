extends SceneTree
## Keep the player's location and input focus in actual long village panels.

const UI = preload("res://scripts/ui/game_ui.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
var failures: Array[String] = []
var checks := 0
var ui


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
	ui.queue_free()
	await _frames()
	print("VILLAGE_PANEL_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("VILLAGE_PANEL_PASS" if failures.is_empty() else "VILLAGE_PANEL_FAIL")
	quit(0 if failures.is_empty() else 1)


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
