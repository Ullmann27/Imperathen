extends "res://tests/i01_flow_test.gd"
## Rerender the first production table shot, without playing a whole capture suite.

func _run() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A real display and --capture-dir are required.")
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.size = size
	game = Entry.instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_physics_process(false)
	game.ui._touch_enabled = true
	game.ui._finish_intro()
	RenderingServer.render_loop_enabled = false
	await _start()
	if check(str(_beat().id) == "i01_a_table", "Actual first table beat"):
		await capture("prima-family-table")
	RenderingServer.render_loop_enabled = true
	game._release_opening()
	game.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
