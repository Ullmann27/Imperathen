extends SceneTree
## Identical-camera captures of the original youth in Valdora (Band I start)
## for each installed outfit. Run in a disposable user directory under a
## graphical display: --script res://tests/youth_outfit_review.gd -- <output>
## Optional --capture-on-demand omits unobserved rasterization and timing
## sampling; the original camera/pose and six drawn warm-up frames remain.
## The same scene, state, light, pose and cameras are used for every outfit;
## only configure_meshy_youth(true, outfit) differs.

const Person = preload("res://scripts/visuals/village_person.gd")
const OUTFITS := ["armoured", "civil"]
const VIEWS := {
	# label: [azimuth degrees from the face direction, distance m, eye height m, target height m, fov, clip, phase]
	"front": [0.0, 3.1, 1.05, 0.80, 34.0, "idle", 0.25],
	"three_quarter": [38.0, 3.1, 1.15, 0.82, 34.0, "idle", 0.25],
	"side": [90.0, 3.1, 1.05, 0.80, 34.0, "idle", 0.25],
	"face": [12.0, 0.78, 1.40, 1.36, 30.0, "idle", 0.25],
	"walk": [55.0, 3.4, 1.10, 0.80, 34.0, "march", 0.30],
}
var output := ""
var game
var errors: Array[String] = []
var report := {}
var capture_on_demand := false
var original_render_loop := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory and output path are required.")
		quit(2)
		return
	output = args[0]
	capture_on_demand = "--capture-on-demand" in args
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	if "--studio" in OS.get_cmdline_user_args():
		await _run_studio()
		return
	original_render_loop = RenderingServer.render_loop_enabled
	if capture_on_demand:
		RenderingServer.render_loop_enabled = false
	print("YOUTH_PHASE instantiate")
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game._start_new_game()
	print("YOUTH_PHASE opening")
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		if str(game.opening_sequence.id) == "childhood_home":
			var beat: Dictionary = game.opening_sequence.beats[game.opening_index]
			if game._film_choice_open(beat):
				game.opening_overlay.choice_requested.emit("i01_help")
				game._opening_skip()
		game._opening_next()
		await process_frame
	if game.screen != "playing":
		errors.append("Opening did not hand over to play: " + str(game.screen))
		printerr("YOUTH_OUTFIT_REVIEW ", JSON.stringify(errors))
		RenderingServer.render_loop_enabled = original_render_loop
		game.free()
		quit(1)
		return
	print("YOUTH_PHASE playing")
	for i in 12: await physics_frame
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world.set_presentation_time(4.0)
	game.ui.hide()
	Engine.time_scale = 0
	game.ui.set_quality("high")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var figure: Person = game.world.get_node("Player/Figure")
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.far = 300.0
	game.world.add_child(camera)
	camera.make_current()
	var ground: Vector3 = figure.global_position - Vector3.UP * 0.9
	var facing: Vector3 = (-figure.global_basis.z).normalized()
	var sun: DirectionalLight3D = game.world._sun
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(), "resolution": [root.size.x, root.size.y],
		"capture_mode": "on_demand" if capture_on_demand else "continuous",
		"run_id": OS.get_environment("GITHUB_RUN_ID"), "source_revision": OS.get_environment("GITHUB_SHA"),
		"timing_note": "No timing samples in on-demand mode; not a device performance benchmark.",
		"quality_profile": "high", "presentation_time_s": 4.0, "state_childhood": game.model.data.has("village") and game.model.data.village.has("childhood"),
		"start_year": game.model.data.get("village", {}).get("history", {}).get("start_year", null),
		"selected_outfit_by_game": figure.youth_outfit, "player_ground": str(ground), "facing": str(facing),
		"sun": {"transform": str(sun.global_transform), "energy": sun.light_energy, "color": sun.light_color.to_html()},
		"outfits": {}}
	var environment: Environment = camera.get_world_3d().environment if camera.get_world_3d() else null
	if environment:
		report["environment"] = {"tonemap": environment.tonemap_mode, "ambient_energy": environment.ambient_light_energy,
			"background": environment.background_mode}
	for outfit in OUTFITS:
		if not Person.youth_outfit_installed(outfit):
			errors.append("Outfit not installed: " + outfit)
			continue
		figure.configure_meshy_youth(true, outfit)
		var entry := {"captures": {}, "loaded": {}}
		for view: String in VIEWS:
			var spec: Array = VIEWS[view]
			var direction := facing.rotated(Vector3.UP, deg_to_rad(float(spec[0])))
			camera.fov = float(spec[4])
			camera.global_position = ground + direction * float(spec[1]) + Vector3.UP * float(spec[2])
			camera.look_at(ground + Vector3.UP * float(spec[3]), Vector3.UP)
			figure.refresh_lod(camera)
			figure.sample_pose(String(spec[5]), float(spec[6]))
			print("YOUTH_CAPTURE_BEGIN ", outfit, " ", view)
			if capture_on_demand:
				RenderingServer.render_loop_enabled = true
			await _settle()
			var timing: Dictionary = {}
			if not capture_on_demand:
				timing = await _measure(12)
			else:
				await RenderingServer.frame_post_draw
			var path := output.path_join("%s_%s.png" % [outfit, view])
			var shot := root.get_texture().get_image()
			if capture_on_demand:
				RenderingServer.render_loop_enabled = false
			if shot == null or shot.is_empty() or shot.get_size() != root.size or shot.save_png(path) != OK:
				errors.append("Invalid or empty capture " + path)
				continue
			var digest := FileAccess.get_sha256(path)
			if digest.length() != 64:
				errors.append("Missing image digest " + path)
				continue
			print("YOUTH_CAPTURE_SAVED ", outfit, " ", view, " ", digest)
			entry.captures[view] = {"file": path.get_file(), "sha256": digest, "size": [shot.get_width(), shot.get_height()], "camera": str(camera.global_transform), "fov": camera.fov,
				"lod": figure.detail, "model": figure.active_model_path, "clip": spec[5], "phase": spec[6], "timing": timing}
			entry.loaded[figure.active_model_path] = FileAccess.get_sha256(figure.active_model_path)
		entry.motion_report = Person.MESHY_YOUTH_OUTFITS[outfit].motion
		entry.motion_report_sha256 = FileAccess.get_sha256(Person.MESHY_YOUTH_OUTFITS[outfit].motion)
		entry.static_memory_mib = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
		entry.video_memory_mib = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		entry.texture_memory_mib = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		report.outfits[outfit] = entry
	report.errors = errors
	var file := FileAccess.open(output.path_join("youth-outfit-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("YOUTH_OUTFIT_REVIEW ", JSON.stringify(errors))
	Engine.time_scale = 1
	RenderingServer.render_loop_enabled = original_render_loop
	game.free()
	quit(0 if errors.is_empty() else 1)


# Neutral, unoccluded asset evidence. Separate from the actual gameplay
# captures: neither this camera nor this lighting enters the shipped game.
func _run_studio() -> void:
	original_render_loop = RenderingServer.render_loop_enabled
	if capture_on_demand:
		RenderingServer.render_loop_enabled = false
	var stage := Node3D.new()
	root.add_child(stage)
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.65
	world_environment.environment = env
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -35, 0)
	key.light_energy = 1.15
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 135, 0)
	fill.light_energy = 0.35
	stage.add_child(fill)
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.30, 0.33)
	mat.roughness = 0.95
	ground_mesh.material_override = mat
	stage.add_child(ground_mesh)
	var figure := Person.new()
	stage.add_child(figure)
	figure.position = Vector3(0, 0.9, 0)
	figure.configure("player", "italia", 12)
	figure.profile = "high"
	figure.set_process(false)
	figure.set_physics_process(false)
	var camera := Camera3D.new()
	camera.near = 0.05
	camera.far = 30.0
	stage.add_child(camera)
	camera.make_current()
	var studio_views := VIEWS.duplicate(true)
	studio_views["attack"] = [38.0, 3.6, 1.10, 0.80, 34.0, "attack", 0.50]
	var facing := (-figure.global_basis.z).normalized()
	var previous_hashes := {}
	var captures := {}
	for outfit: String in OUTFITS:
		if not Person.youth_outfit_installed(outfit) or not figure.configure_meshy_youth(true, outfit):
			errors.append("Studio outfit unavailable: " + outfit)
			continue
		figure._reload(0)
		figure._check_lod = 100000.0
		if figure.detail != 0 or figure.active_model_path != figure.youth_path(0):
			errors.append("Studio model mismatch: " + outfit)
			continue
		var outfit_captures := {}
		for view: String in studio_views:
			var spec: Array = studio_views[view]
			var direction := facing.rotated(Vector3.UP, deg_to_rad(float(spec[0])))
			camera.fov = float(spec[4])
			camera.global_position = direction * float(spec[1]) + Vector3.UP * float(spec[2])
			camera.look_at(Vector3.UP * float(spec[3]), Vector3.UP)
			figure.sample_pose(String(spec[5]), float(spec[6]))
			if capture_on_demand:
				RenderingServer.render_loop_enabled = true
			await _settle()
			var shot := root.get_texture().get_image()
			if capture_on_demand:
				RenderingServer.render_loop_enabled = false
			var path := output.path_join("%s_%s.png" % [outfit, view])
			if shot == null or shot.is_empty() or shot.get_size() != root.size or shot.save_png(path) != OK:
				errors.append("Invalid studio capture: " + path)
				continue
			var digest := FileAccess.get_sha256(path)
			if digest.length() != 64:
				errors.append("Missing studio image digest: " + path)
				continue
			if previous_hashes.get(view, "") == digest:
				errors.append("Different outfits produced identical studio frame: " + view)
			previous_hashes[view] = digest
			outfit_captures[view] = {"file": path.get_file(), "sha256": digest,
				"size": [shot.get_width(), shot.get_height()], "model": figure.active_model_path,
				"model_sha256": FileAccess.get_sha256(figure.active_model_path), "lod": figure.detail,
				"camera": str(camera.global_transform), "fov": camera.fov, "clip": spec[5], "phase": spec[6]}
			print("YOUTH_STUDIO_CAPTURE ", outfit, " ", view, " ", digest)
		captures[outfit] = outfit_captures
	if captures.size() != OUTFITS.size():
		errors.append("Incomplete studio outfits")
	for outfit: String in captures:
		if captures[outfit].size() != studio_views.size():
			errors.append("Incomplete studio views: " + outfit)
	var receipt := {"run_id": OS.get_environment("GITHUB_RUN_ID"), "source_revision": OS.get_environment("GITHUB_SHA"),
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"mode": "neutral_studio_not_gameplay", "quality_profile": "high", "outfits": captures, "errors": errors,
		"visual_acceptance": false, "device_acceptance": false}
	var file := FileAccess.open(output.path_join("youth-studio-review.json"), FileAccess.WRITE)
	if file == null:
		errors.append("Could not write studio receipt")
	else:
		file.store_string(JSON.stringify(receipt, "  ") + "\n")
		file.close()
	print("YOUTH_STUDIO_REVIEW ", JSON.stringify(errors))
	RenderingServer.render_loop_enabled = original_render_loop
	stage.free()
	quit(0 if errors.is_empty() else 1)


func _settle() -> void:
	for i in 6: await RenderingServer.frame_post_draw


func _measure(frames: int) -> Dictionary:
	var rid := root.get_viewport_rid()
	var wall := []
	var cpu := []
	var gpu := []
	var previous := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	wall.sort()
	cpu.sort()
	gpu.sort()
	return {"wall_ms_p50": wall[frames / 2], "viewport_cpu_ms_p50": cpu[frames / 2], "viewport_gpu_ms_p50": gpu[frames / 2],
		"draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"visible_primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)}
