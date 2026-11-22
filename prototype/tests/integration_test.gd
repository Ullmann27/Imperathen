extends SceneTree
## Run through tools/check_prototype.py so this test never replaces a player's save.

const EntryScene = preload("res://main.tscn")
var failures: Array[String] = []
var checks := 0
var game


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Run integration tests with tools/check_prototype.py; an isolated save directory is required.")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	game = EntryScene.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.screen == "intro", "The actual main scene begins with the intro")
	game.ui._finish_intro()
	_check(game.screen == "menu", "Skipping the intro opens the real main menu")
	game.ui.action_requested.emit("new_game", {})
	_check(game.screen == "playing", "New game starts an active world through the UI signal")
	_check(int(game.model.data.player.age) == 12, "A new life starts as a child")
	_check(FileAccess.file_exists(game.SAVE_PATH), "New game creates a real save")
	var before: int = game.model.data.resources.wood
	game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_check(game.model.data.resources.wood == before, "The shared command gateway rejects distant gathering")
	_move_fixture(Vector3(-8, 1, 2))
	for attempt in range(3):
		game.ui.action_requested.emit("interact", {})
	_check(game.model.data.resources.wood == 12, "Three real world interactions produce twelve finite wood")
	_move_fixture(Vector3(-3, 1, 4))
	game.ui.action_requested.emit("interact", {})
	_check(game.screen == "dialog", "The nearby companion opens a modal dialogue")
	var frozen_time: float = game.model.data.world_seconds
	game._process(20.0)
	_check(game.model.data.world_seconds == frozen_time, "A companion dialogue pauses simulation time")
	game.ui.action_requested.emit("companion_help", {"choice": "help"})
	_check(game.model.data.companion.trust == 20 and game.model.data.resources.wood == 8, "Helping the companion spends actual wood and persists trust")
	_move_fixture(Vector3(8, 1, 8))
	game.ui.action_requested.emit("build", {})
	_check(game.mode == "city", "The build action switches camera mode")
	game.world._update_camera(0.016)
	var build_pixel: Vector2 = game.world.get_node("WorldCamera").unproject_position(Vector3(8, 0.04, 5))
	var touch := InputEventScreenTouch.new()
	touch.index = 54
	touch.position = build_pixel
	touch.pressed = true
	game.world._unhandled_input(touch)
	touch = InputEventScreenTouch.new()
	touch.index = 54
	touch.position = build_pixel
	touch.pressed = false
	game.world._unhandled_input(touch)
	game.world.set_build_mode(false)
	_check(game.model.data.buildings.size() == 1 and game.model.data.resources.wood == 0, "A legal build creates one paid work site")
	if game.model.data.buildings.is_empty():
		push_error("Touch construction failed; remaining scenario cannot run.")
		quit(1)
		return
	game.ui.action_requested.emit("pause", {})
	game._process(30.0)
	_check(game.model.data.buildings[0].progress == 0.0, "Construction does not advance while paused")
	game.ui.action_requested.emit("resume", {})
	game._process(13.0)
	_check(game.model.data.buildings[0].completed, "Nearby player work completes construction")
	_check(game.world.get_node("PlayerBuildings").get_child_count() == 1, "The finished domain building appears in the 3D world")
	var place: Vector3 = game.world.get_player_position()
	for view in ["map", "city", "person"]:
		game.ui.action_requested.emit("mode_" + view, {})
	_check(game.world.get_player_position().is_equal_approx(place), "All three camera modes preserve the same person and world")
	_move_fixture(Vector3(0, 1, -7))
	game.ui.action_requested.emit("train", {})
	_check(game.model.data.player.age == 18 and game.model.data.companion.age == 18, "Training advances both childhood companions consistently")
	for hit in range(3):
		game.ui.action_requested.emit("attack", {})
		await _wait_physics(48)
	_check(game.model.data.progress.training_complete, "Actual attack input completes the three timed training hits")
	for recruit in range(3):
		game.ui.action_requested.emit("recruit", {})
	_check(game.model.data.squad.alive == 3 and game.model.data.resources.denarii == 15, "Three recruits consume their defined costs")
	game.ui.action_requested.emit("skirmish", {})
	_check(game.model.data.encounter.active, "The UI starts the encounter only after preparation")
	for opponent in range(3):
		var foe: Dictionary = game.model.data.encounter.enemies[opponent]
		_move_fixture(Vector3(float(foe.x), 1, float(foe.z) + 2.0))
		for strike in range(2):
			game.ui.action_requested.emit("attack", {})
			await _wait_physics(48)
	_check(game.model.data.progress.skirmish_won, "Real world attack signals defeat the finite persistent enemies")
	_check(game.screen == "dialog", "The last enemy hit automatically opens the consequence dialogue")
	_check(game.model.data.story.choices.size() == 2, "The consequence dialogue offers two actual branches")
	game.ui.action_requested.emit("story_choice", {"choice": "invalid-choice"})
	_check(game.screen == "dialog" and game.model.data.story.choices.size() == 2, "A rejected story choice reopens the valid dialogue instead of soft-locking it")
	game.ui.action_requested.emit("story_choice", {"choice": "protect"})
	_check(game.model.data.story.choice == "protect" and game.model.data.companion.trust == 25, "The branch changes trust and becomes a committed fact")
	_check(not game.model.data.progress.career_terminal, "Finishing this prototype chapter does not cap the eventual career")
	game.ui.action_requested.emit("quality_changed", {"profile": "low"})
	_check(game.world.get_quality_profile() == "low" and root.msaa_3d == Viewport.MSAA_DISABLED, "UI quality changes reach the actual world viewport")
	game.ui.action_requested.emit("quality_changed", {"profile": "balanced"})
	game.ui.action_requested.emit("save", {})
	game.ui.action_requested.emit("save", {})
	var saved_position: Array = game.model.data.player.position.duplicate()
	var output := FileAccess.open(game.SAVE_PATH, FileAccess.WRITE)
	output.store_string("intentional-corruption-for-integration-test")
	output.close()
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	_check(game.screen == "playing", "Continue recovers a valid backup when the main save is damaged")
	_check(game.model.data.story.choice == "protect", "Backup recovery preserves the committed story branch")
	var expected_position := Vector3(saved_position[0], saved_position[1], saved_position[2])
	_check(game.world.get_player_position().is_equal_approx(expected_position), "Loading reapplies the saved position to the visible world")
	game.ui.action_requested.emit("move_axis", {"x": 1.0, "y": 0.0})
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.screen == "paused" and game.model._read_save(ProjectSettings.globalize_path(game.SAVE_PATH)).ok, "Application suspension pauses the world and writes a validated save")
	place = game.world.get_player_position()
	await _wait_physics(10)
	_check(game.world.get_player_position().is_equal_approx(place), "Pausing cancels held touch movement")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("INTEGRATION_PASS: %d checks; real scene, UI/world command path, construction, story, combat, save recovery, pause" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _move_fixture(position: Vector3) -> void:
	game.world.get_node("Player").global_position = position
	game.world.get_node("Player").velocity = Vector3.ZERO
	game.model.set_player_position(position)
	game._refresh()


func _wait_physics(frames: int) -> void:
	for frame in range(frames):
		await physics_frame


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
