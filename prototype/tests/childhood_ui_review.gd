extends SceneTree
## Two actual production entry screens; not a full gameplay or Android benchmark.
const Entry = preload("res://main.tscn")
var output := ""
var errors: Array[String] = []
var game

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	if not output.is_absolute_path() or DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var settings := ConfigFile.new()
	settings.set_value("input","touch_controls",true)
	settings.save("user://imperathen_ui.cfg")
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game",{})
	game._opening_skip()
	game._opening_next()
	game.world._update_camera(0.0)
	game.ui.update_childhood_navigation(game.world.childhood_navigation())
	if game.screen != "playing" or game.model.data.village.childhood.scene_id != "family_morning":
		errors.append("New life did not reach the first family objective")
	await _capture("01-childhood-hud")
	game.world.action_requested.emit("childhood_interact",{"npc_id":"julia"})
	game.world._update_camera(0.0)
	if game.screen != "childhood_dialog":
		errors.append("The actual initial player could not converse with Julia")
	await _capture("02-julia-dialogue")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"android_device_test":false,
		"scope":"Actual Main new-life HUD and first Julia dialogue with touch-control preference", "errors":errors}
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	game.free()
	await process_frame
	print("CHILDHOOD_UI_REVIEW ",JSON.stringify(errors))
	quit(0 if errors.is_empty() else 1)

func _capture(name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(output.path_join(name+".png")) != OK:
		errors.append("Could not save "+name)
