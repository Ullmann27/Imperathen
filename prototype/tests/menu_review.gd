extends SceneTree
## Captures real runtime screenshots of the intro and the main menu.
## Run with a display (e.g. xvfb-run) and isolated user data:
## godot --path prototype --resolution 1280x720 --script res://tests/menu_review.gd -- <out_dir> <prefix> [intro_times...]
## Intro times (seconds) capture frames of the intro before it is skipped.

var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://menu_review"
	var prefix := args[1] if args.size() > 1 else "menu"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_game = load("res://main.tscn").instantiate()
	root.add_child(_game)
	var started := Time.get_ticks_msec()
	for index in range(2, args.size()):
		var target := float(args[index])
		while (Time.get_ticks_msec() - started) / 1000.0 < target:
			await process_frame
		await RenderingServer.frame_post_draw
		_save("%s/%s_intro_%04.1fs.png" % [out_dir, prefix, target])
	_game.ui._finish_intro()
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	_save("%s/%s.png" % [out_dir, prefix])
	print("MENU_REVIEW_DONE ", prefix, " ", root.get_visible_rect().size)
	quit()


func _save(path: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("MENU_REVIEW_SHOT ", path)
