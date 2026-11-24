extends SceneTree
## The visible behavior summary must preserve authored choices and domain state.

const Main := preload("res://scripts/main.gd")
const Model := preload("res://scripts/domain/world_model.gd")
const UI := preload("res://scripts/ui/game_ui.gd")
const Life := preload("res://scripts/story/village_life.gd")
const Behavior := preload("res://scripts/domain/npc_behavior.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 540)
	var model := Model.new()
	model.new_game("italia", true, true)
	var session := Main.new()
	session.model = model
	var ui := UI.new()
	root.add_child(ui)
	await process_frame
	var before := JSON.stringify(model.data)
	var original: Dictionary = Life.dialogue(model.data, "julia")
	var view: Dictionary = Behavior.view(model.data, "julia")
	var shown: Dictionary = session._npc_dialog("julia")
	_check(not view.is_empty() and not original.get("choices", []).is_empty(), "Real childhood and behavior data exist together")
	_check(shown.get("choices") == original.get("choices"), "The authored mother choices and their commands survive behavior decoration")
	_check(str(shown.text).contains(str(original.text)) and str(shown.text).begins_with(str(view.greeting)), "The actual activity greeting accompanies the authored story")
	ui.show_village_dialog(shown)
	await process_frame
	_check(str(ui._frontier_dialog_data.text) == str(shown.text), "The actual dialog widget receives the behavior greeting")
	ui.show_village_panel(model.data, "people")
	await process_frame
	_check(_labels(ui).contains("Gerade: "), "The people panel displays current activities")
	var merchant: Dictionary = Behavior.view(model.data, "cassia")
	_check(not _labels(ui).contains("Interesse: " + str(merchant.interest_label)), "The panel does not invent familiarity with unmet merchants")
	_check(_labels(ui).contains("Interesse: " + str(view.interest_label)), "The child's existing family relationship remains known")
	_check(JSON.stringify(model.data) == before, "Viewing people or dialogue changes no relationship, need, item or quest")
	var at := Life.actor_position(model.data, "cassia")
	model.set_player_position(Vector3(at.x, 0.92, at.y))
	_check(model.execute("village_talk", {"npc_id":"cassia", "choice":"meet"}).ok, "The merchant is met through the actual domain command")
	before = JSON.stringify(model.data)
	ui.show_village_panel(model.data, "people")
	await process_frame
	_check(_labels(ui).contains("Interesse: " + str(merchant.interest_label)), "Known interests become visible after an actual encounter")
	_check(JSON.stringify(model.data) == before, "The visible interest remains a read-only projection")
	var ambient := {"text":"Der Markt ist heute geöffnet.", "choices":[]}
	var decorated: Dictionary = session._dialog_with_behavior(ambient, "livia")
	_check(str(decorated.text).contains(str(ambient.text)), "Ambient dialogue retains its own authored line")
	_check(str(ambient.text) == "Der Markt ist heute geöffnet.", "Decoration leaves the original dialogue object unchanged")
	model.new_game("italia", true)
	_check(session._npc_dialog("decimus") == Life.dialogue(model.data, "decimus"), "Legacy saves retain their existing conversation")
	ui.queue_free()
	session.free()
	await process_frame
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("NPC_BEHAVIOR_UI_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("NPC_BEHAVIOR_UI_PASS" if failures.is_empty() else "NPC_BEHAVIOR_UI_FAIL")
	quit(0 if failures.is_empty() else 1)


func _labels(ui: CanvasLayer) -> String:
	var values: PackedStringArray = []
	for label: Label in ui._screen.find_children("*", "Label", true, false):
		values.append(label.text)
	return "\n".join(values)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
