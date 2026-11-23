extends SceneTree
## Authored story must agree with the real command costs, origins and saved choices.

const Opening = preload("res://scripts/story/opening_story.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Origins = preload("res://scripts/strategy/origins.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_origins_and_non_mutating_dialogues()
	_test_dialogue_costs_and_rejected_help()
	_test_confirmed_age_transition_and_saved_memory()
	_test_independent_presentation_data()
	print("OPENING_STORY_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("OPENING_STORY_PASS" if failures.is_empty() else "OPENING_STORY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_origins_and_non_mutating_dialogues() -> void:
	for origin_id: String in Origins.PEOPLES:
		var model = Model.new()
		model.new_game(origin_id)
		var before := JSON.stringify(model.data)
		var sequence: Dictionary = Opening.sequence(origin_id)
		var dialog: Dictionary = Opening.companion_dialog(model.data)
		var friend: String = Origins.PEOPLES[origin_id].companion
		_check(sequence.origin_id == origin_id and sequence.beats.size() == 5, "Every existing origin has a complete five-shot opening: " + origin_id)
		_check(str(sequence.beats[2].speaker) == friend and str(dialog.title).contains(friend), "The opening and dialogue use the actual companion: " + origin_id)
		var valid_beats := true
		var ids := {}
		var duration := 0.0
		for beat: Dictionary in sequence.beats:
			valid_beats = valid_beats and beat.has_all(["id", "shot_id", "speaker", "role", "text", "duration", "chapter", "location"])
			valid_beats = valid_beats and beat.shot_id in Opening.SHOT_IDS and not ids.has(beat.id)
			valid_beats = valid_beats and str(beat.text).length() > 0 and str(beat.text).length() <= 200
			valid_beats = valid_beats and float(beat.duration) >= 2.0 + str(beat.text).length() / 17.0
			ids[beat.id] = true
			duration += float(beat.duration)
		_check(valid_beats and duration >= 35.0 and duration <= 50.0, "Shots are identifiable, readable and bounded in duration: " + origin_id)
		_check(Opening.adulthood(model.data).is_empty() and JSON.stringify(model.data) == before, "Looking at any opening cannot age a child or mutate its state: " + origin_id)
		if origin_id != "italia":
			var presented := JSON.stringify([sequence, dialog])
			_check(not presented.contains("Marcus") and not presented.contains("Livia") and not presented.contains("Rom"), "Regional dialogue does not borrow Roman characters or a Roman destiny: " + origin_id)
	_check(Opening.sequence("missing_origin").origin_id == "italia", "Unknown presentation origin uses the same safe default as WorldModel")


func _test_dialogue_costs_and_rejected_help() -> void:
	var model = Model.new()
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	var before := JSON.stringify(model.data)
	var dialog: Dictionary = Opening.companion_dialog(model.data)
	_check(not bool(dialog.choices[0].enabled) and not str(dialog.choices[0].reason).is_empty(), "Help explains the four-wood requirement before input")
	_check(bool(dialog.choices[1].enabled) and dialog.choices[2].action == "resume", "Decline and returning later remain available without resources")
	var rejected: Dictionary = model.execute("choose_companion", {"choice": "help"})
	_check(not rejected.ok and JSON.stringify(model.data) == before, "Unavailable help cannot spend resources or make a permanent choice")
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	_check(model.execute("gather", {"node_id": "timber_0"}).ok, "The spoken requirement can be met at the actual nearby wood source")
	dialog = Opening.companion_dialog(model.data)
	_check(bool(dialog.choices[0].enabled) and model.data.resources.wood == Opening.HELP_WOOD, "One real gathering action enables help for its advertised cost")
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	var accepted: Dictionary = model.execute("choose_companion", {"choice": "help"})
	_check(accepted.ok and model.data.resources.wood == 0 and model.data.companion.trust == 20, "The actual help outcome agrees with the dialogue, without extra rewards")
	dialog = Opening.companion_dialog(model.data)
	_check(dialog.choices.size() == 1 and dialog.choices[0].action == "resume" and dialog.text == Opening.companion_reply(model.data), "Reopening an answered conversation recalls the result without reoffering payment")


func _test_confirmed_age_transition_and_saved_memory() -> void:
	for choice: String in ["help", "decline"]:
		var model = Model.new()
		model.set_player_position(Vector3(-8.0, 1.0, 2.0))
		for index in (3 if choice == "help" else 2):
			_check(model.execute("gather", {"node_id": "timber_0"}).ok, "Gather enough real material for the " + choice + " path")
		model.set_player_position(Vector3(-3.0, 1.0, 4.0))
		_check(model.execute("choose_companion", {"choice": choice}).ok, "The " + choice + " conversation is a real completed choice")
		_check(model.execute("build", {"x": 8.0, "z": 4.0}).ok, "The narrated eastern building area permits the first shelter")
		model.set_player_position(Vector3(8.0, 1.0, 4.0))
		model.advance(Model.HUT_SECONDS)
		_check(model.data.buildings[0].completed and Opening.adulthood(model.data).is_empty(), "Finishing a shelter alone does not trigger the age montage")
		model.set_player_position(Vector3(0.0, 1.0, -7.0))
		_check(model.execute("train").ok, "The adult montage is unlocked through the existing validated training command")
		var sequence: Dictionary = Opening.adulthood(model.data)
		_check(sequence.get("beats", []).size() == 3 and model.data.player.age == 18 and model.data.companion.age == 18, "Both people are adults before the three-beat montage is presented")
		_check(str(sequence.beats[0].role).contains("Sechs Jahre") and str(sequence.beats[0].role).contains("18 Jahre"), "The montage labels the time jump explicitly")
		var expected := "geteilt" if choice == "help" else "eigenes Dach"
		_check(str(sequence.beats[1].text).contains(expected), "The adult recollection follows the actual earlier choice: " + choice)
		var before := JSON.stringify(model.data)
		Opening.adulthood(model.data)
		_check(JSON.stringify(model.data) == before, "Replaying the montage cannot age anyone twice or modify rewards")
		var path := "user://opening_story_%s_%s.json" % [choice, Time.get_ticks_usec()]
		_check(model.save_game(path).ok, "Save the confirmed " + choice + " path")
		var restored = Model.new()
		var loaded: Dictionary = restored.load_game(path)
		_check(loaded.ok and Opening.adulthood(restored.data) == sequence, "Saved companion memory produces the same adult sequence after reload")
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			var absolute := ProjectSettings.globalize_path(path + suffix)
			if FileAccess.file_exists(absolute):
				DirAccess.remove_absolute(absolute)


func _test_independent_presentation_data() -> void:
	var first: Dictionary = Opening.sequence("italia")
	first.beats[0].text = "Changed by a consumer"
	first.beats.clear()
	var second: Dictionary = Opening.sequence("italia")
	_check(second.beats.size() == 5 and second.beats[0].text != "Changed by a consumer", "A UI consumer cannot corrupt subsequent opening sequences")
	var model = Model.new()
	var dialog: Dictionary = Opening.companion_dialog(model.data)
	dialog.choices[0].enabled = true
	_check(not Opening.companion_dialog(model.data).choices[0].enabled, "A stale UI cannot persist an enabled help choice into the story catalogue")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
