extends SceneTree
## Real MainScene village and dialogue views, using disposable user paths.
const EntryScene = preload("res://main.tscn")
var game
var output := ""
var captures: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty():
		printerr("A graphical viewport, isolated settings and an output directory are required.")
		quit(2)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	game = EntryScene.instantiate()
	root.add_child(game)
	await _frames(8)
	game.ui._touch_enabled = true
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	await _frames(8)
	if game.screen != "playing":
		failures.append("The actual New Life action did not enter the village")
		_finish()
		return
	game.set_process(false)
	game.world.set_active(false)
	game.world.set_physics_process(false)
	# These four views share the same production camera and simulation snapshot.
	for profile: String in ["low", "balanced", "high", "very_high"]:
		game.ui.set_quality(profile)
		await _capture("village-" + profile, "Production starting view with touch controls")
	game.ui.set_quality("high")
	game.ui.visible = false
	_set_camera(Vector3(52, 55, 43), Vector3(12, 0, -9), 55.0)
	await _capture("village-overview", "Review camera over the actual expanded settlement; HUD hidden")
	_set_camera(Vector3(1, 8, -9), Vector3(9, 1, -33), 62.0)
	await _capture("north-quarter", "Review camera showing the northern neighbourhood; HUD hidden")
	_set_camera(Vector3(-3, 2.8, 28), Vector3(7.4, 1, 23), 60.0)
	await _capture("wagon-yard", "Review camera showing the wagon yard and residents; HUD hidden")
	game.ui.visible = true
	game.world.set_physics_process(true)
	await _talk("livia", Vector3(-14, 1, 6.6))
	await _talk("aulus", Vector3(4, 1, -22.4))
	_finish()


func _talk(npc_id: String, player_position: Vector3) -> void:
	if game.screen == "frontier_dialog":
		game.ui.action_requested.emit("frontier_close", {})
	game.world._player.position = player_position
	game.world._player.velocity = Vector3.ZERO
	game.model.set_player_position(player_position)
	game.world.action_requested.emit("frontier_talk", {"npc_id": npc_id})
	await _frames(18)
	if game.screen != "frontier_dialog":
		failures.append("Actual dialogue did not open: " + npc_id)
		return
	await _capture("dialogue-" + npc_id, "Production conversation camera and UI; childhood meeting")


func _set_camera(position: Vector3, target: Vector3, fov: float) -> void:
	game.world._camera.global_position = position
	game.world._camera.look_at(target)
	game.world._camera.fov = fov


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _capture(label: String, purpose: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		failures.append("Empty or unsaved viewport: " + label)
	captures.append({"file": label + ".png", "purpose": purpose,
		"profile": game.ui.get_quality(), "screen": game.screen,
		"world_seconds": game.model.data.world_seconds,
		"output_pixels": [root.size.x, root.size.y],
		"camera_transform": str(game.world._camera.global_transform),
		"camera_fov": game.world._camera.fov})


func _finish() -> void:
	var report := {"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "android_device_test": false,
		"environment": "Actual production MainScene on a desktop software renderer; no phone FPS claim",
		"resident_count": game.world.population.actors.size(), "captures": captures,
		"errors": failures}
	var file := FileAccess.open(output.path_join("runtime-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("FRONTIER_GRAPHICS_REVIEW ", JSON.stringify(failures))
	game.free()
	quit(0 if failures.is_empty() else 1)
