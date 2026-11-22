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
	game.ui.action_requested.emit("valley_demo", {})
	_check(game.screen == "valley" and game.valley.actors.size() > 0, "The menu opens the independent valley scenario")
	var scene = game.valley
	var guard: Dictionary = scene.model.squads.valley_guard
	var ally_pixel: Vector2 = scene.camera.unproject_position(scene._surface(Vector2(guard.x,guard.z))+Vector3.UP*0.65)
	_mouse(scene,ally_pixel,MOUSE_BUTTON_LEFT,true)
	_mouse(scene,ally_pixel,MOUSE_BUTTON_LEFT,false)
	_check("valley_guard" in scene.selected, "A projected friendly company is selectable via the PC input path")
	var line_a: Vector2 = scene.camera.unproject_position(scene._surface(Vector2(-9,4)))
	var line_b: Vector2 = scene.camera.unproject_position(scene._surface(Vector2(-4,4)))
	_mouse(scene,line_a,MOUSE_BUTTON_RIGHT,true)
	var motion := InputEventMouseMotion.new()
	motion.position = line_b
	scene._input(motion)
	_check(scene.ghost.multimesh.instance_count == guard.strength, "Dragging previews one attainable slot per soldier")
	_mouse(scene,line_b,MOUSE_BUTTON_RIGHT,false)
	_check(guard.command == "deploy", "Mouse release submits the displayed line")
	var before_pinch := JSON.stringify(scene.model.snapshot())
	var initial_distance: float = scene.distance
	_touch(scene,0,line_a,true)
	_touch(scene,1,line_b,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = line_b+Vector2(75,0)
	scene._input(drag)
	_touch(scene,1,drag.position,false)
	_touch(scene,0,line_a,false)
	_check(scene.distance != initial_distance and before_pinch == JSON.stringify(scene.model.snapshot()), "Two fingers zoom and pan without submitting an order")
	_touch(scene,0,line_a,true)
	scene.pressed_at = Time.get_ticks_msec()-500
	scene._process(0)
	drag.index = 0
	drag.position = line_b
	scene._input(drag)
	_check(scene.gesture == "deploy" and scene.ghost.multimesh.instance_count > 0, "Long touch displays the same planned front")
	_touch(scene,0,line_b,false)
	scene._action("leave")
	_check(game.screen == "menu" and not FileAccess.file_exists(game.SAVE_PATH), "The scenario preview never creates a campaign save")
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
	game.ui.action_requested.emit("valley",{})
	_check(game.screen == "valley","Earned village defence opens the campaign deployment")
	var valley = game.valley
	var initial_time: float = game.model.data.world_seconds
	valley.model.tick(3.0)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var seconds: float = game.model.data.world_seconds
	_check(is_equal_approx(seconds,initial_time+3.0),"Android suspension checkpoints elapsed battle time once")
	var persisted := JSON.stringify(game.model.data.valley.snapshot)
	valley._action("leave")
	_check(game.model.data.world_seconds == seconds,"Returning from a tactical camera does not advance world time twice")
	game._show_menu()
	game._continue_game()
	game._pause()
	game._open_valley(false)
	_check(JSON.stringify(game.valley.model.snapshot()) == persisted or game.valley.model.steps == 15,"A fresh load resumes the same tactical tick")
	var local_population: Dictionary = game.model.data.population.duplicate()
	var retreat := []
	for squad in game.valley.model.squads.values():
		if squad.side == "ally":
			retreat.append(squad.id)
	game.valley.model.order(retreat,"retreat")
	for i in 605:
		game.valley.model.tick(0.2)
	game._valley_finished()
	_check(game.model.data.valley.outcome == "defeat","Retreat transfers loss of the pass to the strategic ledger")
	var history_count: int = game.model.data.chronicle.size()
	game._leave_valley()
	game._show_menu()
	game._continue_game()
	_check(game.model.data.valley.outcome == "defeat" and game.model.data.chronicle.size()==history_count and game.model.data.population==local_population,"Reload preserves the outcome, does not double-book casualties or spend village recruits")
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

func _mouse(scene,p: Vector2,button: MouseButton,down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = button
	event.pressed = down
	scene._input(event)

func _touch(scene,index: int,p: Vector2,down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = p
	event.pressed = down
	scene._input(event)
