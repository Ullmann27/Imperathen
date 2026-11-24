extends SceneTree
## Godot viewport captures and a larger live formation benchmark. Run in a disposable user directory.

const PROFILES := ["low", "balanced", "high", "very_high"]
const Valley = preload("res://scripts/tactics/valley_scene.gd")
var output: String
var game
var display
var report := {}
var errors: Array[String] = []
var frames := 32


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory and output path are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		frames = clampi(args[1].to_int(), 2, 600)
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	display = root.get_node("RuntimeDisplay")
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"output_pixels": [root.size.x, root.size.y], "frames_per_measurement": frames,
		"village": {}, "valley": {}, "large_battle": {}}
	game.ui._finish_intro()
	game._start_new_game()
	# New Life chains I-00 into the family opening. Leave every opening through
	# its own skip/confirm path so the captures show the playable village camera.
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		game._opening_next()
		await process_frame
	if game.screen != "playing":
		errors.append("Opening did not hand over to play: " + str(game.screen))
	# Let the capsule settle onto the floor, then checkpoint through the game's normal save API.
	for i in 12: await physics_frame
	game._refresh()
	game._save(false)
	game._continue_game()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world._camera_initialized = false
	game.world._update_camera(0)
	game._refresh()
	game.ui._toast_panel.hide()
	var snapshot: String = JSON.stringify(game.model.data)
	var play_camera: Camera3D = game.world._camera
	report.village_state = {"world_sha256": snapshot.sha256_text(), "save_sha256": FileAccess.get_sha256(game.SAVE_PATH),
		"age": game.model.data.player.age, "world_seconds": game.model.data.world_seconds, "sun": str(game.world._sun.transform),
		"camera": str(play_camera.global_transform), "player": str(game.world.get_player_position())}
	game.world.set_presentation_time(4.0)
	Engine.time_scale = 0
	for profile in PROFILES:
		_apply(profile)
		for path in ["Player/Figure", "Marcus/Figure", "TrainingGround/Mentor/Figure"]:
			var figure = game.world.get_node(path)
			figure.refresh_lod(play_camera)
			figure.sample_pose("idle", 0.25)
		await _settle()
		report.village[profile] = await _measure()
		_capture("village-" + profile)
		if snapshot != JSON.stringify(game.model.data) or report.village_state.camera != str(play_camera.global_transform):
			errors.append("Village state or camera changed in " + profile)
	game.ui.hide()
	await _portrait("child", game.world.get_node("Player/Figure"), 1.22, play_camera)
	var mentor: Node3D = game.world.get_node("TrainingGround/Mentor/Figure")
	if mentor.is_visible_in_tree():
		await _portrait("trainer", mentor, 1.40, play_camera)
	# In the village chapter the legacy mentor is hidden; show a visible resident instead.
	var resident: Node3D = null
	for id in ["julia", "silvanus", "sextus", "cassia"]:
		var candidate = game.world.get_node_or_null("VillageLife/Resident_" + id + "/Figure")
		if candidate != null and candidate.is_visible_in_tree():
			resident = candidate
			report["close_resident"] = id
			break
	if resident != null:
		await _portrait("resident", resident, 1.62, play_camera)
	else:
		errors.append("No visible village resident for a close-up")
	game._show_menu()
	game._open_valley(true)
	var valley = game.valley
	valley.focus = Vector2(-3, 3.0)
	valley.distance = 21
	valley.azimuth = 0.32
	valley._place_camera()
	var field_snapshot: String = JSON.stringify(valley.model.snapshot())
	report.valley_state = {"simulation_sha256": field_snapshot.sha256_text(), "steps": valley.model.steps,
		"camera": str(valley.camera.global_transform), "initial_soldiers": 60}
	for profile in PROFILES:
		_apply(profile)
		await _settle()
		report.valley[profile] = await _measure()
		_capture("valley-" + profile)
		if JSON.stringify(valley.model.snapshot()) != field_snapshot:
			errors.append("Valley simulation changed in " + profile)
	valley.hud.hide()
	var chosen = valley.actors.get("valley_guard_00")
	if chosen:
		await _portrait("soldier", chosen, 1.41, valley.camera)
	else:
		errors.append("Front-rank soldier missing")
	Engine.time_scale = 1
	game._leave_valley()
	game.world.hide()
	game.ui.hide()
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	await _large_battle()
	report.errors = errors
	var file := FileAccess.open(output.path_join("viewport.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("LIVE_GRAPHICS_REVIEW ", JSON.stringify(errors))
	game.free()
	quit(0 if errors.is_empty() else 1)


func _apply(profile: String) -> void:
	# Use the same handler as the selector in Options.
	game.ui.set_quality(profile)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _portrait(label: String, figure: Node3D, eye_height: float, camera: Camera3D) -> void:
	var ground := figure.global_position
	var facing: Vector3
	if figure.has_method("sample_pose"):
		figure.sample_pose("idle", 0.25)
		ground.y -= 0.9
		facing = -figure.global_basis.z
	else:
		facing = figure.global_basis.z
	var target := ground + Vector3.UP * eye_height
	camera.position = target + facing.normalized() * 1.25 + Vector3(0.14, 0.04, 0.09)
	camera.look_at(target, Vector3.UP)
	var original_fov := camera.fov
	camera.fov = 40
	if figure.has_method("refresh_lod"):
		figure.refresh_lod(camera)
		figure.sample_pose("idle", 0.25)
	await _settle()
	_capture("close-" + label)
	camera.fov = original_fov


func _large_battle() -> void:
	var valley = Valley.new()
	# Larger copies of the six scenario cohorts go through the production model, AI, animation and LOD paths.
	for s: Dictionary in valley.model.squads.values().duplicate():
		valley.model._add_squad(s.id, s.name, s.side, s.kind, s.formation, Vector2(s.x, s.z), s.strength * 3)
	root.add_child(valley)
	valley.focus = Vector2(0, 1.5)
	valley.distance = 40
	valley._place_camera()
	valley._select("valley_guard", false)
	valley._issue("move", Vector2(-7, 4))
	valley.paused = false
	# Continuous run. Each interval starts at a later tick; these are workload observations.
	for profile in PROFILES:
		_apply(profile)
		valley.set_quality(profile)
		await _settle()
		var first_step: int = valley.model.steps
		var stats := await _measure()
		stats.initial_strength = 180
		stats.start_step = first_step
		stats.end_step = valley.model.steps
		if display._units.x + display._units.y > int(valley.render_profiles[profile].review_limits.animated_valley_actors):
			errors.append("Rig budget exceeded in " + profile)
		stats.remaining = 0
		for s: Dictionary in valley.model.squads.values():
			stats.remaining += int(s.strength)
		stats.near_mid_far = [display._units.x, display._units.y, display._units.z]
		report.large_battle[profile] = stats
		if valley.model.steps <= first_step or valley.model.outcome != "ongoing":
			errors.append("Expected active large battle during " + profile)
	valley.free()


func _settle() -> void:
	for i in 5: await RenderingServer.frame_post_draw


func _measure() -> Dictionary:
	var rid := root.get_viewport_rid()
	var wall := []
	var cpu := []
	var gpu := []
	var calls := []
	var primitives := []
	var previous := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	return {"wall_ms": _percentiles(wall), "mean_fps": 1000.0 * frames / float(wall.reduce(func(a,b): return a+b)),
		"viewport_cpu_ms": _percentiles(cpu), "viewport_gpu_ms": _percentiles(gpu),
		"draw_calls": _percentiles(calls), "visible_primitives": _percentiles(primitives),
		"rss_mib": display._resident_memory_kib()/1024.0, "render_scale": root.scaling_3d_scale,
		"texture_bytes_reported": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)}


func _percentiles(values: Array) -> Dictionary:
	values.sort()
	return {"p50": values[ceili(values.size()*0.50)-1], "p95": values[ceili(values.size()*0.95)-1],
		"p99": values[ceili(values.size()*0.99)-1]}


func _capture(label: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		errors.append("Empty viewport capture: " + label)
