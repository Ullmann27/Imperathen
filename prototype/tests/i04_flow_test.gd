extends SceneTree
## I-04 through the production Main scene: continue at the authored delivery
## step, reach VID-A, skip to its choice, and resume that checkpoint.

const Entry = preload("res://main.tscn")
const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I04Film = preload("res://scripts/story/i04_film.gd")
const Support = preload("res://tests/i03_support.gd")

var game: Variant
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("I-04 flow requires isolated settings and saves.")
		quit(2)
		return
	_run.call_deferred()


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("I04_FLOW_FAIL: " + message)
	return condition


func frames(count := 4) -> void:
	for _index in count:
		await process_frame


func _stage(model: Variant) -> String:
	return str(Childhood.view(model.data).get("stage", ""))


func _play_fixture_stage(model: Variant) -> Dictionary:
	var view: Dictionary = Childhood.view(model.data)
	var stage := str(view.get("stage", ""))
	if stage.begins_with("i03_"):
		return Support.play_stage(model)
	var point: Vector2 = view.get("point", Vector2.ZERO)
	model.set_player_position(Vector3(point.x, 1.35, point.y))
	var npc := str(view.get("target_npc", ""))
	if not npc.is_empty() and not bool(Childhood.relationship(model.data, npc).get("met", false)):
		model.execute("village_talk", {"npc_id":npc, "choice":"meet"})
	view = Childhood.view(model.data)
	var actions: Array = view.get("actions", [])
	if actions.is_empty():
		return {"ok":false, "message":"No action for campaign step " + stage}
	var action := "basket_check" if stage == "i02_basket" else str(actions[0].get("payload", {}).get("action_id", ""))
	if action.is_empty():
		return {"ok":false, "message":"No action id for campaign step " + stage}
	return model.execute("village_childhood_action", {"action_id":action})


func _campaign_before_workshop() -> Variant:
	var model: Variant = WorldModel.new()
	model.new_game("italia", true, true, false, true)
	for _index in 90:
		var stage := _stage(model)
		if stage == "deliver_kindling":
			return model
		var result: Dictionary = _play_fixture_stage(model)
		if not check(bool(result.get("ok", false)), "Campaign fixture reaches the workshop from " + stage + ": " + str(result.get("message", ""))):
			return null
	check(false, "Campaign fixture reaches the authored kindling delivery step")
	return null


func _new_main() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	await frames(2)
	game.set_process(false)
	game.set_physics_process(false)
	game.ui._touch_enabled = true
	game.ui._finish_intro()


func _press_choice(action_id: String) -> bool:
	var button: Button = game.opening_overlay.find_child("OpeningChoice_" + action_id, true, false)
	if not check(button != null and button.is_visible_in_tree(), "Main displays the authored choice " + action_id):
		return false
	button.pressed.emit()
	await frames(4)
	return true


func _run() -> void:
	var fixture: Variant = _campaign_before_workshop()
	if fixture == null:
		_finish()
		return
	await _new_main()
	var saved: Dictionary = fixture.save_game(game.SAVE_PATH)
	if not check(bool(saved.get("ok", false)), "The campaign fixture saves through the ordinary save format"):
		_finish()
		return
	game._continue_game()
	await frames(4)
	if not check(game.screen == "playing" and _stage(game.model) == "deliver_kindling", "Main Continue restores the campaign at the delivery step"):
		_finish()
		return

	var view: Dictionary = Childhood.view(game.model.data)
	var point: Vector2 = view.get("point", Vector2.ZERO)
	var player: Node3D = game.world.get_node("Player")
	player.position = Vector3(point.x, 1.35, point.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)
	var npc := str(view.get("target_npc", ""))
	if not npc.is_empty() and not bool(Childhood.relationship(game.model.data, npc).get("met", false)):
		var meeting: Dictionary = game._command("village_talk", {"npc_id":npc, "choice":"meet"})
		check(bool(meeting.get("ok", false)), "Main can meet the workshop target")
	view = Childhood.view(game.model.data)
	var actions: Array = view.get("actions", [])
	if not check(not actions.is_empty(), "The delivery step exposes an authored action"):
		_finish()
		return
	var payload: Dictionary = actions[0].get("payload", {})
	var delivery_action := str(payload.get("action_id", ""))
	var delivered: Dictionary = game._command("village_childhood_action", {"action_id":delivery_action})
	if not check(bool(delivered.get("ok", false)), "Main commits the authored delivery action: " + str(delivered.get("message", ""))):
		_finish()
		return
	await frames(4)
	if not check(game.screen == "opening" and str(game.opening_sequence.get("id", "")) == I04Film.VID_A, "Main opens I-04 VID-A from the campaign delivery"):
		_finish()
		return

	game._opening_skip()
	await frames(4)
	var beat: Dictionary = game.opening_sequence.beats[game.opening_index]
	if not check(game._film_choice_open(beat) and str(beat.get("choice_step", "")) == "i04_work", "Skipping VID-A stops at the unresolved workshop choice"):
		_finish()
		return
	var before_choice := JSON.stringify(game.model.data.village.childhood.screenplay)
	check(game.model.data.village.childhood.screenplay.i04_work == "", "Skipping the film leaves the work choice uncommitted")
	if not check(bool(game._save(false).get("ok", false)), "Main saves the unresolved VID-A choice"):
		_finish()
		return

	game.queue_free()
	await frames(2)
	await _new_main()
	game._continue_game()
	await frames(4)
	if not check(game.screen == "opening" and str(game.opening_sequence.get("id", "")) == I04Film.VID_A, "Continue restores the I-04 film checkpoint"):
		_finish()
		return
	beat = game.opening_sequence.beats[game.opening_index]
	check(game._film_choice_open(beat) and str(beat.get("choice_step", "")) == "i04_work", "Continue restores the same unresolved workshop choice")
	check(JSON.stringify(game.model.data.village.childhood.screenplay) == before_choice, "Continue preserves the screenplay without inventing a choice")
	check(game.model.data.village.childhood.screenplay.i04_work == "", "The work choice remains uncommitted after Continue")

	if await _press_choice("i04_watch"):
		var chosen: Dictionary = game.model.data.village.childhood.screenplay
		check(chosen.i04_work == "watch", "The Main choice commits the watch-first route")
		check(chosen.i04_events.count("I-04.work.watch") == 1, "The work choice is recorded once")
		check(str(game.opening_sequence.get("chain_to", "")) == I04Film.VID_B and _stage(game.model) == "i04_topic", "Main reconstructs the VID-B handoff from the saved choice")

		game._opening_skip()
		await frames(2)
		game._opening_next()
		await frames(4)
		check(game.screen == "opening" and str(game.opening_sequence.get("id", "")) == I04Film.VID_B, "Finishing VID-A chains into the workshop's second film")
		game._opening_skip()
		await frames(4)
		beat = game.opening_sequence.beats[game.opening_index]
		if check(game._film_choice_open(beat) and str(beat.get("choice_step", "")) == "i04_topic", "VID-B stops at the authored smithing topic choice"):
			var choices: Array = beat.get("choices", [])
			var topic_action := str(choices[0].get("action_id", "")) if not choices.is_empty() else ""
			if not check(not topic_action.is_empty(), "VID-B offers an authored topic action"):
				_finish()
				return
			if await _press_choice(topic_action):
				chosen = game.model.data.village.childhood.screenplay
				check(not str(chosen.get("i04_topic", "")).is_empty(), "The Main topic choice is recorded")
				check(chosen.i04_events.count("I-04.topic." + str(chosen.i04_topic)) == 1, "The topic decision is recorded once")
				game._opening_skip()
				await frames(2)
				game._opening_next()
				await frames(4)
				check(game.screen == "playing" and _stage(game.model) != "i04_topic", "Completing VID-B returns control to the campaign")

	_finish()


func _finish() -> void:
	print("I04_FLOW_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("I04_FLOW_PASS" if failures.is_empty() else "I04_FLOW_FAIL")
	quit(0 if failures.is_empty() else 1)
