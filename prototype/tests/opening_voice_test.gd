extends SceneTree
## Verifies the production prologue plays only an exact recording, and that
## menu, film pause and continuing from a checkpoint own its lifetime.

const Entry = preload("res://main.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	var voice = game.opening_voice
	check(voice.is_active() and voice.current.get("line_id") == "I-00.i00_detail", "I-00 starts the correct recording")
	game._opening_set_paused(true)
	check(is_instance_valid(voice._player) and voice._player.stream_paused and not voice.is_processing(), "Pause stops the stream and phoneme clock")
	game._opening_set_paused(false)
	check(is_instance_valid(voice._player) and not voice._player.stream_paused and voice.is_processing(), "Resume restarts the same stream")
	game._opening_next()
	check(voice.current.get("line_id") == "I-00.i00_legions", "Advancing replaces the previous line")
	game._opening_skip()
	check(not voice.is_active() and voice._player == null, "Skipping to handoff removes the previous line")
	game._show_menu()
	check(not voice.is_active(), "Returning to menu leaves no voice playing")
	game.free()
	await process_frame
	for error in failures:
		printerr(error)
	print("OPENING_VOICE_PASS" if failures.is_empty() else "OPENING_VOICE_FAILED")
	quit(0 if failures.is_empty() else 1)
