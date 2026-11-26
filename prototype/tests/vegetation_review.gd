extends SceneTree
## Reproducible Valdora vegetation and landscape shots through the real game
## path (main.tscn -> new life -> village), identical before and after the
## vegetation change. Six fixed views per quality profile:
##   path         third-person game camera on the village lane (I-01 exterior)
##   overview     elevated view over the village toward the west and north
##   stream       along the brook from the east bank near the bridge
##   west_edge    over the brook to the western wood edge
##   north_hills  from the north gate toward the backdrop hills (sight line)
##   south_fields beyond the southern palisade toward fields and the lagoon side
##   meadow       eye height in the meadow south-west of the village, toward the fen
## Writes <label>-<shot>-<profile>.png and <label>-vegetation-<profiles>.json with render
## counters (draw calls, primitives, objects, memory) and, when present, the
## vegetation layer's own instance and triangle counts per profile.
## Frame times come from whatever renderer runs the script (often software):
## relative indicators between shots, never device performance.
## Usage: --script res://tests/vegetation_review.gd ++ <out_dir> [label] [frames] [profiles,csv] [shots,csv] [wind_frames]
## With wind_frames > 0 every listed shot is also captured as a sequence
## <label>-<shot>-<profile>-wind<NN>.png, 0.1 s of wind time apart (the wind
## time is pinned, so the sequence is the same on every run).

const SHOTS := ["path", "overview", "stream", "west_edge", "north_hills", "south_fields", "meadow"]
const PATH_POSITION := Vector3(0.9, 0.0, 12.5)
const VIEWS := {
	"overview": [Vector3(31.0, 17.5, 33.0), Vector3(-4.0, 1.0, -9.0)],
	"stream": [Vector3(-23.2, 2.1, 15.0), Vector3(-30.5, 1.6, -22.0)],
	"west_edge": [Vector3(-21.0, 1.75, -4.0), Vector3(-70.0, 5.0, -12.0)],
	"north_hills": [Vector3(2.0, 1.75, -54.0), Vector3(-6.0, 9.0, -120.0)],
	"south_fields": [Vector3(12.0, 2.6, 33.0), Vector3(4.0, 0.8, 75.0)],
	"meadow": [Vector3(-10.0, 1.7, 44.0), Vector3(-17.0, 0.6, 75.0)],
}
var output: String
var label := "vegetation"
var frames := 4
var profiles: Array = ["low", "balanced", "high", "very_high"]
var game
var report := {}
var errors: Array[String] = []
var shots: Array = SHOTS.duplicate()
var wind_frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory and output path are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		label = args[1]
	if args.size() > 2:
		frames = clampi(args[2].to_int(), 2, 120)
	if args.size() > 3:
		profiles = Array(args[3].split(",", false))
	if args.size() > 4 and args[4] != "all":
		shots = Array(args[4].split(",", false)).filter(func(shot: String) -> bool: return shot in SHOTS)
	if args.size() > 5:
		wind_frames = clampi(args[5].to_int(), 0, 60)
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	var started := Time.get_ticks_msec()
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"output_pixels": [root.size.x, root.size.y], "frames_per_measurement": frames,
		"note": "Frame times are relative indicators on this renderer/driver, not device performance.",
		"views": {}, "shots": {}}
	for key: String in VIEWS:
		report.views[key] = {"eye": str(VIEWS[key][0]), "target": str(VIEWS[key][1])}
	report.views["path"] = {"player": str(PATH_POSITION), "yaw": 0.0, "pitch": 0.24, "camera": "game third-person rig"}
	game.ui._finish_intro()
	game._start_new_game()
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		game._opening_next()
		await process_frame
	if game.screen != "playing":
		errors.append("Opening did not hand over to play: " + str(game.screen))
	for i in 12: await physics_frame
	game._refresh()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world._camera_initialized = false
	game.world._update_camera(0)
	game._refresh()
	game.ui._toast_panel.hide()
	game.ui.hide()
	report["load_ms"] = Time.get_ticks_msec() - started
	var world = game.world
	var camera: Camera3D = world._camera
	var start := {"player": world._player.global_position, "yaw": world._camera_yaw, "pitch": world._camera_pitch,
		"camera": camera.global_transform, "fov": camera.fov, "figure_yaw": world._figure.rotation.y}
	report.player_lift = start.player.y - _floor(start.player)
	world.set_presentation_time(4.0)
	Engine.time_scale = 0
	for profile: String in profiles:
		game.ui.set_quality(profile)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		for shot: String in shots:
			_frame(shot, start)
			await _settle()
			var stats := await _measure()
			stats.camera = str(camera.global_transform)
			stats.fov = camera.fov
			stats.vegetation = _vegetation_stats(world)
			if not report.shots.has(shot):
				report.shots[shot] = {}
			report.shots[shot][profile] = stats
			_capture("%s-%s-%s" % [label, shot, profile])
			for index in wind_frames:
				world.set_presentation_time(4.0 + index * .1)
				await _settle()
				_capture("%s-%s-%s-wind%02d" % [label, shot, profile, index])
			world.set_presentation_time(4.0)
			_restore(start)
	report.memory = {"static_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"static_max_mib": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0}
	report.errors = errors
	var file := FileAccess.open(output.path_join("%s-vegetation-%s.json" % [label, "_".join(profiles)]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("VEGETATION_REVIEW ", JSON.stringify(errors))
	Engine.time_scale = 1
	game.free()
	quit(0 if errors.is_empty() else 1)


func _vegetation_stats(world) -> Dictionary:
	var layer = world.get("vegetation")
	if layer == null or not layer.has_method("stats"):
		return {"layer": "absent"}
	return layer.stats()


func _frame(shot: String, start: Dictionary) -> void:
	var world = game.world
	var camera: Camera3D = world._camera
	if shot == "path":
		_place_player(PATH_POSITION, 0.0)
		world._camera_yaw = 0.0
		world._camera_pitch = 0.24
		world._camera_initialized = false
		world._update_camera(0)
	else:
		camera.fov = 62.0
		camera.global_position = VIEWS[shot][0]
		camera.look_at(VIEWS[shot][1], Vector3.UP)
	for figure in root.get_tree().get_nodes_in_group("village_people"):
		if figure.has_method("refresh_lod") and figure.is_visible_in_tree():
			figure.refresh_lod(camera)
	world.population.update_nearby(world.get_player_position(), true)
	var layer = world.get("vegetation")
	if layer != null and layer.has_method("refresh"):
		layer.refresh(camera)


func _place_player(at: Vector3, yaw: float) -> void:
	var world = game.world
	var lift: float = float(report.get("player_lift", 1.0))
	world._player.global_position = Vector3(at.x, _floor(at) + lift, at.z)
	world._figure.rotation.y = yaw


func _floor(at: Vector3) -> float:
	var world = game.world
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 4.0, at.z), Vector3(at.x, at.y - 6.0, at.z), 1, [world._player.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


func _restore(start: Dictionary) -> void:
	var world = game.world
	if not world._village_focus.is_empty():
		world.clear_frontier_focus()
	world._player.global_position = start.player
	world._figure.rotation.y = start.figure_yaw
	world._camera_yaw = start.yaw
	world._camera_pitch = start.pitch
	world._camera.fov = start.fov
	world._camera.global_transform = start.camera


func _settle() -> void:
	for i in 5: await RenderingServer.frame_post_draw


func _measure() -> Dictionary:
	var rid := root.get_viewport_rid()
	var wall := []
	var cpu := []
	var gpu := []
	var calls := []
	var primitives := []
	var objects := []
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
		objects.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	return {"wall_ms_p50": _median(wall), "viewport_cpu_ms_p50": _median(cpu), "viewport_gpu_ms_p50": _median(gpu),
		"draw_calls": _median(calls), "primitives": _median(primitives), "objects": _median(objects),
		"shadow_draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"render_scale": root.scaling_3d_scale,
		"texture_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"video_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0}


func _median(values: Array) -> float:
	values.sort()
	return float(values[values.size() / 2])


func _capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(name + ".png")) != OK:
		errors.append("Empty viewport capture: " + name)
