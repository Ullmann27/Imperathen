extends SceneTree
## The production entry path, using an isolated campaign and presentation checkpoint.

const Entry = preload("res://main.tscn")
const Checkpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
var failures: Array[String] = []
var checks := 0
var game


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use tools/check_prototype.py: an isolated user directory is required.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	await process_frame
	_check(game.screen == "opening" and game.opening_sequence.id == "first_day", "New Life starts the authored opening through the production UI path")
	_check(FileAccess.file_exists(game.SAVE_PATH), "The campaign is saved before its introduction")
	var campaign: String = JSON.stringify(game.model.data)
	var player: Vector3 = game.world.get_player_position()
	game._process(2.0)
	_check(JSON.stringify(game.model.data) == campaign and game.world.get_player_position() == player, "Cinematic playback changes neither simulation nor player position")
	game.ui.action_requested.emit("attack", {})
	game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_check(JSON.stringify(game.model.data) == campaign, "Hidden gameplay input cannot enter through either command gateway")
	root.go_back_requested.emit()
	var paused_time: float = game.opening_elapsed
	var paused_camera: Transform3D = game.opening_director.camera.global_transform
	game._process(50.0)
	_check(game.opening_paused and game.opening_elapsed == paused_time and game.opening_director.camera.global_transform == paused_camera, "Android Back pauses the cinematic clock and camera")
	game.opening_overlay._request_advance()
	root.go_back_requested.emit()
	game.opening_overlay._request_advance()
	_check(not game.opening_paused and game.opening_index == 1, "Paused Advance cannot lock the same subtitle after resuming")
	game.opening_overlay._toggle_reading()
	game._process(100.0)
	_check(game.opening_manual and game.opening_index == 1, "Reading mode holds the chosen subtitle after its camera travel completes")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.opening_paused, "Application suspension holds the opening instead of skipping unseen lines")
	var checkpoint: Dictionary = Checkpoint.read(str(game.model.data.world_id))
	_check(checkpoint.get("index", -1) == 1 and not bool(checkpoint.get("completed", true)), "Suspension checkpoints the current scene against this campaign identity")
	var world_id: String = game.model.data.world_id
	game._show_menu()
	await process_frame
	game._continue_game()
	_check(game.screen == "opening" and game.opening_index == 1 and game.model.data.world_id == world_id, "Continue restores the pending scene for the same saved life")
	# The campaign loader represents JSON strategy numbers as floats. Compare
	# parsed values so 2 and 2.0 do not mask or imitate a gameplay change.
	_check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(campaign), "Continuing the opening introduces no age jump, payment or repeated rewards")
	game.opening_overlay._request_skip()
	_check(game.screen == "opening" and bool(game.opening_sequence.beats[game.opening_index].final), "Skip presents the first objective and waits for explicit player control")
	_check(game.opening_director.camera.global_transform.is_equal_approx(game.world.get_node("WorldCamera").global_transform), "The objective holds the exact eventual gameplay camera")
	game._process(500.0)
	_check(game.screen == "opening", "Even a long idle interval cannot auto-confirm the first objective")
	game.opening_overlay._request_advance()
	_check(game.screen == "playing" and game.world.get_node("WorldCamera").current and game.world.get("_active"), "Explicit acceptance returns the ordinary camera and movement")
	_check(game.model.data.companion.choice == "" and game.model.data.resources.wood == 0, "Skipping does not choose help, decline or collect materials")
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing", "A completed introduction is not forced again on Continue")
	_check(Checkpoint.read("another-life").is_empty(), "The sidecar cannot attach an introduction to another save")

	_move(Vector3(-3, 1, 4))
	game.world.action_requested.emit("companion_interact", {})
	var choices: Array = game.ui.get("_dialog_data").choices
	_check(game.screen == "dialog" and not bool(choices[0].enabled), "A resource-poor player sees the actual help requirement")
	game.ui.action_requested.emit("companion_help", {})
	_check(game.screen == "dialog" and game.model.data.companion.choice == "", "An invalid help attempt keeps the dialogue available without a choice")
	game.ui.action_requested.emit("resume", {})
	_move(Vector3(-8, 1, 2))
	for count in 3:
		game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_move(Vector3(-3, 1, 4))
	game.world.action_requested.emit("companion_interact", {})
	game.ui.action_requested.emit("companion_help", {})
	_check(game.model.data.resources.wood == 8 and game.model.data.companion.trust == 20, "The real dialogue commits exactly its stated cost and relationship change")
	_move(Vector3(8, 1, 4))
	game.world.action_requested.emit("build", {"x": 8.0, "z": 4.0})
	game._process(13.0)
	_check(game.model.data.buildings[0].completed, "The opening leads into a real completed shelter")
	_move(Vector3(0, 1, -7))
	var blocked_save := ProjectSettings.globalize_path(game.SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_recursive_absolute(blocked_save) == OK, "A disposable blocked save path can exercise real persistence failure")
	game.world.action_requested.emit("train", {})
	_check(game.screen == "paused" and not game.pending_opening.is_empty() and game.model.data.player.age == 18, "A failed campaign write pauses the transition instead of concealing a save error behind the montage")
	DirAccess.remove_absolute(blocked_save)
	game._resume()
	_check(game.screen == "opening" and game.opening_sequence.id == "adulthood", "The shared world-input path also triggers the confirmed age montage")
	_check(game.model.data.player.age == 18 and game.model.data.companion.age == 18 and game.opening_sequence.beats[1].text.contains("geteilt"), "Adult memory matches the committed childhood choice")
	var adult_state: String = JSON.stringify(game.model.data)
	game._show_menu()
	game._continue_game()
	_check(game.screen == "opening" and game.opening_sequence.id == "adulthood" and JSON.stringify(game.model.data) == adult_state, "Adult continuation cannot apply the six-year jump twice")
	game._opening_skip()
	_check(game.opening_sequence.beats[game.opening_index].advance_label == "Zur Ausbildung", "Adult handoff points to training, not the already completed first day")
	game._opening_next()
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing" and game.model.data.player.age == 18, "Completed adult transition resumes as ordinary gameplay")

	var file := FileAccess.open(Checkpoint.PATH, FileAccess.WRITE)
	file.store_string("broken-checkpoint")
	file.close()
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing", "A corrupt optional presentation marker never blocks a valid campaign")
	var invalid_marker := {"version": 1, "world_id": game.model.data.world_id,
		"sequence_id": "adulthood", "index": 1.5, "completed": false}
	file = FileAccess.open(Checkpoint.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid_marker))
	file.close()
	_check(Checkpoint.read(str(game.model.data.world_id)).is_empty(), "A fractional scene index is rejected instead of truncated")
	_check(Checkpoint.write(world_id, "first_day", -1, false) == ERR_INVALID_PARAMETER, "Invalid scene positions are rejected before writing")
	game.queue_free()
	await process_frame
	print("OPENING_FLOW_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	print("OPENING_FLOW_PASS" if failures.is_empty() else "OPENING_FLOW_FAIL")
	quit(0 if failures.is_empty() else 1)


func _move(position: Vector3) -> void:
	game.world.get_node("Player").position = position
	game.model.set_player_position(position)
	game.world.sync_state(game.model.data)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
