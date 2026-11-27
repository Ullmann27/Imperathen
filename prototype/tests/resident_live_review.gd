extends SceneTree
## Close-ups of named residents in the real village (new game, opening skipped
## through its own controls), with the playable camera's lighting and scenery.
## ++ <output> [profile,profile] [id,id,...]

const PROFILES := ["low", "balanced", "high", "very_high"]
var output := ""
var profiles: Array = ["balanced", "very_high"]
var ids: Array = ["julia", "silvanus", "sextus", "cassia", "aurelia", "decimus", "nerva", "livia", "priscilla", "fabius"]
var game
var report := {"captures": [], "errors": []}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory and output path are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		profiles = Array(args[1].split(",", false)).filter(func(p): return p in PROFILES)
	if args.size() > 2:
		ids = Array(args[2].split(",", false))
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _figure(id: String) -> Node3D:
	for path: String in ["VillageLife/Resident_" + id + "/Figure"]:
		var node = game.world.get_node_or_null(path)
		if node:
			return node
	for node: Node in game.world.find_children(id, "", true, false):
		var figure := node.get_node_or_null("Figure") as Node3D
		if figure:
			return figure
	return null


func _run() -> void:
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game._start_new_game()
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		game._opening_next()
		await process_frame
	for i in 12: await physics_frame
	game._refresh()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world._camera_initialized = false
	game.world._update_camera(0)
	game.ui.hide()
	game.world.set_presentation_time(4.0)
	Engine.time_scale = 0
	var camera: Camera3D = game.world._camera
	for profile: String in profiles:
		game.ui.set_quality(profile)
		for id: String in ids:
			var figure := _figure(id)
			if figure == null or not figure.is_visible_in_tree():
				report.errors.append("missing or hidden resident " + id)
				continue
			figure.sample_pose("idle", 0.25)
			var ground: Vector3 = figure.global_position - Vector3.UP * 0.9
			var facing: Vector3 = -figure.global_basis.z
			var rig := figure.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var head: Vector3 = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Head")).origin
			var target := head + Vector3.UP * 0.07
			camera.fov = 34
			camera.position = target + facing.normalized() * 1.05 + facing.cross(Vector3.UP).normalized() * 0.18 + Vector3(0, 0.03, 0)
			camera.look_at(target, Vector3.UP)
			figure.refresh_lod(camera)
			figure.sample_pose("idle", 0.25)
			for i in 4:
				await RenderingServer.frame_post_draw
			var name := "live-%s-%s-%dx%d.png" % [id, profile, root.size.x, root.size.y]
			var saved := root.get_texture().get_image().save_png(output.path_join(name))
			if saved != OK:
				report.errors.append("could not save " + name)
				continue
			report.captures.append({"id": id, "profile": profile, "file": name, "model": figure.active_model_path,
				"lod": figure.detail, "ground": str(ground)})
	var file := FileAccess.open(output.path_join("live-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("RESIDENT_LIVE_REVIEW ", JSON.stringify(report.errors))
	game.free()
	quit(0 if report.errors.is_empty() else 1)
