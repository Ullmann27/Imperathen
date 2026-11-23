extends SceneTree
## Real Main -> New Game -> Opening rendering. No AI images or offline render substitutes.

const ReviewDirector = preload("res://scripts/cinematic/opening_director.gd")

var output := ""
var record_motion := false
var skip_stills := false
var motion_fps := 18
var motion_seconds_per_shot := 0.0
var motion_profile := "very_high"
var game
var failures: Array[String] = []
var report := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty():
		printerr("A graphical viewport, isolated user settings and output directory are required.")
		quit(2)
		return
	output = args[0]
	record_motion = "--motion" in args
	skip_stills = "--skip-stills" in args
	var fps_index := args.find("--motion-fps")
	if fps_index >= 0 and fps_index + 1 < args.size():
		motion_fps = clampi(args[fps_index + 1].to_int(), 12, 30)
	var length_index := args.find("--motion-seconds-per-shot")
	if length_index >= 0 and length_index + 1 < args.size():
		motion_seconds_per_shot = maxf(0.0, args[length_index + 1].to_float())
	var profile_index := args.find("--motion-profile")
	if profile_index >= 0 and profile_index + 1 < args.size() and args[profile_index + 1] in ["low", "balanced", "high", "very_high"]:
		motion_profile = args[profile_index + 1]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game.ui.origin_id = "italia"
	game._start_new_game()
	await process_frame
	if game.screen != "opening":
		failures.append("The production New Game path did not enter the opening")
		_write_report()
		game.free()
		quit(1)
		return
	game._opening_set_paused(true)
	game.set_process(false)
	game.world.set_physics_process(false)
	game.opening_director.set_process(false)
	game.ui._toast_panel.hide()
	var original_state: String = JSON.stringify(game.model.data)
	var original_player: Vector3 = game.world.get_player_position()
	report = {"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"android_device_test": false, "hardware_fps_claim": false,
		"source": "Production Main scene -> New Game -> opening, sampled deterministically",
		"captures": [], "state_before_sha256": original_state.sha256_text()}
	game.ui.set_quality(motion_profile if skip_stills else "very_high")
	if game.world.has_method("set_presentation_time"):
		game.world.set_presentation_time(4.0)
	var capture_sizes: Array = [] if skip_stills else [Vector2i(1280, 720), Vector2i(1024, 1024)]
	if skip_stills and FileAccess.file_exists(output.path_join("stills-pass.json")):
		report["retained_stills_receipt"] = "stills-pass.json"
	for size: Vector2i in capture_sizes:
		root.size = size
		for frame in 5:
			await process_frame
		for index in game.opening_sequence.beats.size():
			if size.x == 1024 and index != 2:
				continue
			if size.x == 1280 and index in [1, 3]:
				continue
			_present(index, 0.08 if index == 4 else 0.55)
			await _capture("%dx%d-%02d-%s" % [size.x, size.y, index + 1, game.opening_sequence.beats[index].get("shot_id", "objective")], index)
	if record_motion:
		game.ui.set_quality(motion_profile)
		root.size = Vector2i(1280, 720)
		for frame in 5:
			await process_frame
		await _record_motion()
	if JSON.stringify(game.model.data) != original_state or game.world.get_player_position() != original_player:
		failures.append("Rendering the opening changed gameplay state or player position")
	report["state_after_sha256"] = JSON.stringify(game.model.data).sha256_text()
	report["player_unchanged"] = game.world.get_player_position() == original_player
	game._opening_skip()
	await process_frame
	if game.screen != "opening" or game.opening_index != game.opening_sequence.beats.size() - 1:
		failures.append("Skip from the opening did not preserve the final objective card")
	game._opening_next()
	await process_frame
	if game.screen != "playing":
		failures.append("Continue from the objective card did not restore the playable game")
	if not game.world.get_node("WorldCamera").current:
		failures.append("Skip did not restore the gameplay camera")
	report["skip_to_gameplay"] = game.screen == "playing"
	if game.screen == "playing":
		await _review_confirmed_repair()
	_write_report()
	game.free()
	quit(0 if failures.is_empty() else 1)


func _present(index: int, normalized_time: float) -> void:
	var beat: Dictionary = game.opening_sequence.beats[index]
	game.opening_index = index
	game.opening_overlay.present(beat, index, game.opening_sequence.beats.size())
	game.opening_overlay.set_paused(false)
	game.opening_overlay.set_progress(normalized_time)
	var shot: String = beat.get("shot_id", "player")
	game.opening_director.play(shot, float(beat.get("duration", 6.0)), false)
	game.opening_director.set_paused(true)
	game.opening_director.set_process(false)
	# Existing rigs keep their authored anatomy and exported idle animation.
	for actor: Node in get_nodes_in_group("village_people"):
		if game.world.is_ancestor_of(actor):
			actor.refresh_lod(game.opening_director.camera)
			actor.sample_pose("idle", 0.25)
	game.opening_director.sample(shot, 1.0 if bool(beat.get("final", false)) else normalized_time)


func _capture(label: String, index: int) -> void:
	for frame in 4:
		await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		failures.append("The real viewport produced no usable image: " + label)
	var pose: Dictionary = game.opening_director.snapshot()
	var actors: Array[Dictionary] = []
	for actor: Node in get_nodes_in_group("village_people"):
		if game.world.is_ancestor_of(actor):
			actors.append({"role": actor.role, "age": actor.age, "asset": actor.active_model_path, "lod": actor.detail, "clip": actor.clip})
	report.captures.append({"file": label + ".png", "pixels": [root.size.x, root.size.y],
		"beat_index": index, "shot_id": pose.shot_id, "position": str(pose.position),
		"camera_transform": str(pose.transform), "fov": pose.fov,
		"quality": "very_high", "scale_3d": root.scaling_3d_scale, "actors": actors})
	print("OPENING_CAPTURE ", label)


func _record_motion() -> void:
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	var frame_index := 0
	var lengths: Array[float] = []
	for index in game.opening_sequence.beats.size():
		var beat: Dictionary = game.opening_sequence.beats[index]
		var is_final := bool(beat.get("final", false))
		var full_seconds := 8.0 if is_final else float(beat.get("duration", 6.0))
		var seconds := minf(full_seconds, motion_seconds_per_shot) if motion_seconds_per_shot > 0.0 else full_seconds
		var start_second := (full_seconds - seconds) * 0.5
		lengths.append(seconds)
		_present(index, 0.0)
		var count := ceili(seconds * motion_fps)
		for frame in count:
			var t := (start_second + float(frame) / motion_fps) / full_seconds
			game.opening_overlay.set_progress(t)
			for actor: Node in get_nodes_in_group("village_people"):
				if game.world.is_ancestor_of(actor):
					actor.sample_pose("idle", fposmod(float(frame) / motion_fps * 0.45, 1.0))
			game.opening_director.sample(beat.get("shot_id", "player"), 1.0 if is_final else t)
			if game.world.has_method("set_presentation_time"):
				game.world.set_presentation_time(float(frame_index) / motion_fps)
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			if shot == null or shot.is_empty() or shot.save_png(output.path_join("motion/frame-%05d.png" % frame_index)) != OK:
				failures.append("Missing motion frame " + str(frame_index))
			frame_index += 1
		print("OPENING_MOTION_SHOT ", index, " ", count, " frames")
	report["motion"] = {"frames": frame_index, "playback_fps": motion_fps,
		"seconds": float(frame_index) / motion_fps, "beat_durations": lengths, "quality": motion_profile,
		"excerpt": motion_seconds_per_shot > 0.0, "seconds_per_shot": motion_seconds_per_shot,
		"sampling": "Centered excerpts with authored camera speed" if motion_seconds_per_shot > 0.0 else "Complete authored timeline",
		"captured_from_actual_renderer": true, "real_time_benchmark": false,
		"objective_card_hold_seconds": 8.0 if motion_seconds_per_shot <= 0.0 else minf(8.0, motion_seconds_per_shot),
		"audio": "not captured; existing ambience is not part of this visual review"}


func _write_report() -> void:
	report["errors"] = failures
	var file := FileAccess.open(output.path_join("runtime-review.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	else:
		failures.append("Could not write the runtime review receipt")
	print("OPENING_GRAPHICS_REVIEW ", JSON.stringify(failures))


func _review_confirmed_repair() -> void:
	# The render review reaches the overlap of the wood/companion interaction
	# radii through ordinary touch-axis movement. No state, money, or position
	# is injected into the authoritative model.
	root.size = Vector2i(1280, 720)
	game.ui.set_quality("balanced")
	game.world.set_active(true)
	game.world.set_physics_process(true)
	var target := Vector2(-5.5, 3.0)
	var reached := false
	for tick in 600:
		var position: Vector3 = game.world.get_player_position()
		var offset := target - Vector2(position.x, position.z)
		if offset.length() < 0.24:
			reached = true
			break
		var axis := Vector3(offset.x, 0, offset.y).normalized().rotated(Vector3.UP, -float(game.world._camera_yaw))
		game.world.set_touch_move(Vector2(axis.x, axis.z))
		await physics_frame
	game.world.set_touch_move(Vector2.ZERO)
	game.world.set_active(false)
	game.world.set_physics_process(false)
	if not reached:
		failures.append("Touch-axis movement could not reach the real wood/companion interaction area")
		return
	game.ui.hide()
	var director := ReviewDirector.new()
	game.add_child(director)
	director.setup(game.world)
	director.play("well", 10.0)
	director.set_process(false)
	director.sample("well", 0.55)
	await _capture_repair(director, "well-before-help")
	var before_camera: Transform3D = director.camera.global_transform
	var before_fov: float = director.camera.fov
	var gathered: Dictionary = game._command("gather", {"node_id": "timber_0"})
	var wood_before := int(game.model.data.resources.wood)
	var accepted: Dictionary = game._command("choose_companion", {"choice": "help"})
	var wood_after := int(game.model.data.resources.wood)
	if not gathered.get("ok", false) or not accepted.get("ok", false) or wood_before - wood_after != 4 or game.model.data.companion.choice != "help":
		failures.append("The real gather/companion commands did not produce the confirmed four-wood repair")
	game.ui.hide()
	director.sample("well", 0.55)
	await _capture_repair(director, "well-after-help")
	var same_camera := before_camera.is_equal_approx(director.camera.global_transform) and is_equal_approx(before_fov, director.camera.fov)
	if not same_camera:
		failures.append("The before/after repair camera changed")
	report["repair"] = {"movement": "Production touch-axis input and CharacterBody3D physics",
		"player_position": str(game.world.get_player_position()), "gather_result": gathered,
		"choose_companion_result": accepted, "wood_before_help": wood_before,
		"wood_after_help": wood_after, "choice": game.model.data.companion.choice,
		"trust": game.model.data.companion.trust, "unchanged_camera": same_camera}
	director.finish()
	director.free()


func _capture_repair(director: Node3D, label: String) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		failures.append("The well repair produced no usable viewport image: " + label)
	report.captures.append({"file": label + ".png", "pixels": [root.size.x, root.size.y],
		"shot_id": "well", "quality": "balanced", "purpose": "Before and after the confirmed companion choice",
		"camera_transform": str(director.camera.global_transform), "fov": director.camera.fov,
		"choice": game.model.data.companion.choice, "wood": game.model.data.resources.wood})
	print("OPENING_CAPTURE ", label)
