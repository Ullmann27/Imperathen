extends SceneTree
## Captures the walkable world's HUD and the strategy atlas of a new campaign
## from the production Main scene, to judge the shown world date (D-045).
## Run with a display (xvfb-run) and isolated user data:
## godot --path prototype --resolution 1280x720 --script <this file> -- <out_dir> <prefix>
## Uses only entry points that exist on older branches too, so the same
## script renders the state before and after a change.

var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://world_date_review"
	var prefix := args[1] if args.size() > 1 else "world_date"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_game = load("res://main.tscn").instantiate()
	root.add_child(_game)
	for frame in 20:
		await process_frame
	_game.ui._finish_intro()
	await process_frame
	_game._start_new_game()
	var guard := 0
	while _game.screen == "opening" and guard < 8:
		guard += 1
		await process_frame
		_game._opening_skip()
		_game._opening_next()
		await process_frame
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("%s/%s_hud.png" % [out_dir, prefix])
	print("WORLD_DATE_REVIEW screen=", _game.screen, " hud_time=", _game.ui._hud_labels["time"].text, " | hud_age=", _game.ui._hud_labels["age"].text)
	_game._open_atlas(false)
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("%s/%s_atlas.png" % [out_dir, prefix])
	print("WORLD_DATE_REVIEW atlas_header=", _game.atlas.date.text, " | region=", _game.atlas.title.text, " | note=", _game.atlas.description.text)
	_game.atlas._select("germania", true)
	for frame in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("%s/%s_atlas_germania.png" % [out_dir, prefix])
	print("WORLD_DATE_REVIEW tribal=", str(_game.atlas.tribal.text).left(400).replace("\n", " / "))
	print("WORLD_DATE_REVIEW_DONE ", prefix, " ", root.get_visible_rect().size, " renderer=", RenderingServer.get_current_rendering_method(), " driver=", RenderingServer.get_video_adapter_name(), " ", RenderingServer.get_video_adapter_api_version())
	quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("WORLD_DATE_REVIEW_SHOT ", path)
