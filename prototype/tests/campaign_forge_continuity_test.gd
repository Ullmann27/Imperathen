extends "res://tests/i03_flow_test.gd"
## Continuous production Main from I-00 to the I-05 rest objective.
## Inherits the original I-03 assertions. Travel is fixture placement;
## interactions, film choices and save/continue are actual Main commands.
const ForgeFilm = preload("res://scripts/story/i04_film.gd")
const ForgeVisit = preload("res://scripts/story/i04_workshop.gd")
const MissionFilm = preload("res://scripts/story/mission_cinematics.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")

func _play_expected(expected: String, finish_transition := true) -> bool:
	if not check(game.screen == "playing" and _stage() == expected, "Connected objective: " + expected):
		return false
	var view: Dictionary = Childhood.view(game.model.data)
	_place(view.point)
	var npc := str(view.get("target_npc", ""))
	if not npc.is_empty() and not bool(Childhood.relationship(game.model.data, npc).get("met", false)):
		var met: Dictionary = game._command("village_talk", {"npc_id":npc, "choice":"meet"})
		if not check(bool(met.get("ok", false)), "Meet actual actor: " + npc):
			return false
	var result: Dictionary = game._command("village_childhood_action", {"action_id":expected})
	await frames(4)
	if not check(bool(result.get("ok", false)), "Actual command " + expected + ": " + str(result.get("message", ""))):
		return false
	if finish_transition and game.screen == "opening":
		await _finish_film()
	return failures.is_empty()

func _test_farewell() -> void:
	await super._test_farewell()
	if not failures.is_empty():
		return
	var memories: Array = _sp().i03_events.duplicate(true)
	var world_id: String = str(game.model.data.world_id)
	if not check(_stage() == "deliver_food" and game.model.data.village.childhood.carried.has("family_parcel"), "Marcus' story leaves the actual family order to deliver"):
		return
	if not await _play_expected("deliver_food"):
		return
	check(not game.model.data.village.childhood.carried.has("family_parcel"), "Julia receives the actual order")
	if not await _play_expected("woodcutter_request"):
		return
	if not await _play_expected("collect_kindling"):
		return
	check(game.model.data.village.childhood.carried.has("kindling_bundle"), "A real delivered bundle is required")
	if not await _play_expected("deliver_kindling", false):
		return
	if not check(game.screen == "opening" and game.opening_sequence.id == ForgeFilm.VID_A and _stage() == "i04_work", "Kindling delivery opens Sextus' introduction"):
		return
	check(not game.model.data.village.childhood.carried.has("kindling_bundle"), "Sextus has the bundle, no duplicate")
	var money: int = int(game.model.data.resources.denarii)
	var wood: int = int(game.model.data.resources.wood)
	var start_events: Array = _sp().i04_events.duplicate(true)
	game.opening_overlay._request_skip()
	await frames(3)
	if not check(game._film_choice_open(_beat()) and str(_beat().choice_step) == "i04_work" and _sp().i04_events == start_events, "Skip does not decide the work"):
		return
	if not await _press_choice("i04_watch"):
		return
	if not check(_stage() == "i04_topic" and _sp().i04_events == ["I-04.work.watch"] and str(game.opening_sequence.get("chain_to", "")) == ForgeFilm.VID_B, "Actual watch choice rebuilds the next film edge"):
		return
	_play_film()
	if not check(bool(_beat().get("final", false)), "First film reaches its real final handoff"):
		return
	var final_index: int = game.opening_index
	game._show_menu()
	game._continue_game()
	await frames(6)
	if not check(game.screen == "opening" and game.opening_sequence.id == ForgeFilm.VID_A and game.opening_index == final_index and _sp().i04_events == ["I-04.work.watch"], "Continue restores the saved final beat and work choice"):
		return
	game.opening_overlay._request_advance()
	await frames(6)
	if not check(game.screen == "opening" and game.opening_sequence.id == ForgeFilm.VID_B and _stage() == "i04_topic", "Final handoff chains into the anvil talk"):
		return
	var checkpoint: Dictionary = Checkpoint.read(world_id)
	check(checkpoint.get("sequence_id", "") == ForgeFilm.VID_B and not bool(checkpoint.get("completed", true)), "New film replaces the old checkpoint")
	game.opening_overlay._request_skip()
	await frames(3)
	if not check(game._film_choice_open(_beat()) and str(_beat().choice_step) == "i04_topic" and _sp().i04_events == ["I-04.work.watch"], "Second skip waits for the topic choice"):
		return
	game._show_menu()
	game._continue_game()
	await frames(6)
	if not check(game.screen == "opening" and game.opening_sequence.id == ForgeFilm.VID_B and game._film_choice_open(_beat()) and _sp().i04_events == ["I-04.work.watch"], "Continue restores the second film without inventing a topic"):
		return
	if not await _press_choice("i04_topic_father"):
		return
	check(_sp().i04_events == ["I-04.work.watch", "I-04.topic.father"] and _sp().i04s == "complete", "One real topic completes the visit")
	await _finish_film()
	check(_stage() == "apprentice_permission" and str(ForgeVisit.hook_lines(game.model.data, "apprentice_permission")).contains("hingesehen"), "Father remembers the actual decision")
	check(int(game.model.data.resources.denarii) == money and int(game.model.data.resources.wood) == wood and not Combat.service_gear(game.model.data), "No imaginary wages, wood or service gear")
	if not await _play_expected("apprentice_permission"):
		return
	if not await _play_expected("smith_trial", false):
		return
	if not check(game.screen == "opening" and game.opening_sequence.id == MissionFilm.PREFIX + "smith_trial", "Agreed trial opens the bridge to the next day"):
		return
	var lines: Array = game.opening_sequence.beats.map(func(b): return str(b.get("line_id", "")))
	check(lines.has("I04_C_LESSON_FATHER"), "Sextus' farewell remembers the chosen subject")
	await _finish_film()
	check(_stage() == "rest_first" and int(game.model.data.player.age) == 12, "I-05 begins with conscious rest, not an age jump")
	check(str(game.model.data.world_id) == world_id and _sp().i03_events == memories and Childhood.validate(game.model.data).is_empty(), "Same valid campaign and Marcus memories")
	if failures.is_empty():
		print("CAMPAIGN_FORGE_CONTINUITY_PASS")
