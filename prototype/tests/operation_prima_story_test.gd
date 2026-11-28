extends SceneTree
## Focused regressions for I-01 choice films, atomic event commits and the
## household denar handoff.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const I01Film = preload("res://scripts/story/i01_film.gd")

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_choice_reactions()
	_test_duplicate_event_is_atomic()
	_test_household_denarius()
	print("OPERATION_PRIMA_STORY_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("OPERATION_PRIMA_STORY_PASS" if failures.is_empty() else "OPERATION_PRIMA_STORY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _new_world() -> Variant:
	var model: Variant = WorldModel.new()
	model.new_game("italia", true, true, false, true)
	return model


func _act(model: Variant, action: String) -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":action})


func _at(data: Dictionary, point: Vector2) -> void:
	data.player.position = [point.x, 1.35, point.y]


func _test_choice_reactions() -> void:
	var expected: Dictionary = {
		"i01_talk":"I01_A_REACT_TALK",
		"i01_help":"I01_A_REACT_HELP",
		"i01_yard":"I01_A_REACT_YARD"}
	for action: String in expected:
		var model: Variant = _new_world()
		var data: Dictionary = model.data
		var before := JSON.stringify(data)
		var film: Dictionary = I01Film.vid_a(data)
		var choice_index: int = -1
		var has_reaction: bool = false
		for index: int in range(film.beats.size()):
			var beat: Dictionary = film.beats[index]
			if str(beat.get("id", "")) == "i01_a_choice":
				choice_index = index
			if str(beat.get("id", "")) == "i01_a_react":
				has_reaction = true
		_check(choice_index == 3, "VID-A pauses at the first choice")
		_check(not has_reaction, "An unresolved choice does not imply a help reaction")
		_check(JSON.stringify(data) == before, "Building VID-A does not mutate saved state")
		var chosen: Dictionary = I01.apply(data, action)
		_check(bool(chosen.get("ok", false)), "I-01 choice commits: " + action)
		var rebuilt: Dictionary = I01Film.vid_a(data)
		var reaction: Dictionary = rebuilt.beats.back()
		_check(str(reaction.get("line_id", "")) == str(expected[action]), "VID-A reaction follows the stored choice: " + action)


func _test_duplicate_event_is_atomic() -> void:
	var model: Variant = _new_world()
	var data: Dictionary = model.data.duplicate(true)
	_check(bool(I01.apply(data, "i01_help").get("ok", false)), "Help path starts before placing cups")
	_at(data, I01.POINTS.home_shelf + Vector2(0.7, 0.0))
	_check(bool(I01.apply(data, "i01_take_cups").get("ok", false)), "All cups are taken together")
	_at(data, I01.POINTS.home_table)
	_check(bool(I01.apply(data, "i01_place_julia").get("ok", false)), "Julia's cup is placed")
	_check(bool(I01.apply(data, "i01_place_silvanus").get("ok", false)), "Silvanus' cup is placed")
	var duplicate: Dictionary = data.duplicate(true)
	duplicate.village.childhood.screenplay.i01_events.append("I-01.cups.table")
	var before := JSON.stringify(duplicate)
	var rejected: Dictionary = I01.apply(duplicate, "i01_place_player")
	_check(not bool(rejected.get("ok", false)), "A conflicting completion event is rejected")
	_check(JSON.stringify(duplicate) == before, "Rejected multi-event action changes neither cups nor history")


func _test_household_denarius() -> void:
	var model: Variant = _new_world()
	_check(int(model.data.resources.denarii) == 0, "Regular I-01 begins with no spendable denarii")
	_check(bool(_act(model, "i01_yard").get("ok", false)), "The yard path commits")
	_at(model.data, I01.POINTS.home_table)
	_check(bool(_act(model, "i01_meal").get("ok", false)), "The family meal proceeds without player help")
	_check(bool(_act(model, "i01_topic_workshop").get("ok", false)), "The table conversation completes I-01")
	_check(str(model.data.village.childhood.screenplay.i01) == "complete", "I-01 completion is saved")
	_check(int(model.data.resources.denarii) == 0, "I-01 completion does not turn household funds into pocket money")
	_check(str(Childhood.view(model.data).get("stage", "")) == "mother_morning", "The next beat is the family handoff, not an early I-02 task")
	var handoff: Dictionary = _act(model, "mother_morning")
	_check(bool(handoff.get("ok", false)), "Julia makes the household denar available for the errand")
	_check(model.data.village.childhood.carried.has("household_coin"), "The reserved denar remains a carried household token")
	_check(int(model.data.resources.denarii) == 0, "The earmarked household token never enters the player's spendable balance")
