extends SceneTree
## Fixed-camera framebuffer captures of the amphitheatre, before and after.
## "before" loads the legacy RomanCity GLB; "after" loads the reworked showcase.
## Images come from Mesa/Xvfb and are visual QA references, NOT device captures.
const CAMERAS := "res://assets/monuments/colosseum/capture_cameras.json"
const LEGACY_CITY := "res://assets/world/roman_city_test.glb"
const SHOWCASE := "res://scripts/monuments/colosseum_showcase.gd"
const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("A real OpenGL/Xvfb viewport is required.")
		quit(2)
		return
	_run.call_deferred()


func _rig(parent: Node) -> void:
	# One neutral daylight rig for both modes so the comparison is fair.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.45, 0.68)
	sky_material.sky_horizon_color = Color(0.72, 0.80, 0.88)
	sky_material.ground_horizon_color = Color(0.62, 0.60, 0.55)
	sky_material.ground_bottom_color = Color(0.30, 0.28, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.80, 0.78, 0.74)
	environment.ambient_light_sky_contribution = 0.45
	environment.ambient_light_energy = 0.55
	environment.tonemap_white = 4.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world)


func _run() -> void:
	var mode := OS.get_environment("COLOSSEUM_CAPTURE_MODE")
	var folder := OS.get_environment("COLOSSEUM_CAPTURE_OUTPUT")
	var profile := OS.get_environment("COLOSSEUM_CAPTURE_PROFILE")
	if profile.is_empty():
		profile = "high"
	if mode not in ["before", "after"] or folder.is_empty():
		printerr("COLOSSEUM_CAPTURE_MODE=before|after and COLOSSEUM_CAPTURE_OUTPUT are required.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMERAS))
	if not data is Dictionary:
		printerr("Camera file unreadable.")
		quit(2)
		return
	root.size = SIZE
	var stage := Node3D.new()
	root.add_child(stage)
	var centre := Vector3.ZERO
	if mode == "before":
		var packed := load(LEGACY_CITY) as PackedScene
		if packed == null:
			printerr("Legacy city GLB is not installed; build it with tools/world/build_roman_test_city.py.")
			quit(1)
			return
		stage.add_child(packed.instantiate())
		var c: Array = data.legacy_city_centre
		centre = Vector3(c[0], c[1], c[2])
		_rig(stage)
	else:
		var script := load(SHOWCASE) as GDScript
		if script == null:
			printerr("Showcase script missing.")
			quit(1)
			return
		var showcase: Node3D = script.new()
		showcase.set("profile", profile)
		showcase.set("external_lighting", true)
		showcase.set("spawn_people", OS.get_environment("COLOSSEUM_CAPTURE_PEOPLE") == "1")
		stage.add_child(showcase)
		_rig(stage)
	var camera := Camera3D.new()
	camera.near = 0.1
	camera.far = 1500.0
	stage.add_child(camera)
	camera.current = true
	for i in 12:
		await process_frame
	var shots: Array = []
	var failures: Array[String] = []
	for entry: Dictionary in data.cameras:
		var p: Array = entry.position
		var t: Array = entry.target
		camera.position = centre + Vector3(p[0], p[1], p[2])
		camera.look_at(centre + Vector3(t[0], t[1], t[2]), Vector3.UP)
		camera.fov = float(entry.fov)
		for i in 6:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != SIZE:
			failures.append(str(entry.id) + ": no complete framebuffer")
			continue
		var low := 1.0
		var high := 0.0
		for y in range(36, 685, 65):
			for x in range(48, 1225, 92):
				var luma := image.get_pixel(x, y).get_luminance()
				low = minf(low, luma)
				high = maxf(high, luma)
		if high - low < 0.05:
			failures.append(str(entry.id) + ": framebuffer is uniform")
		var path := folder.path_join("%s_%s_%s.png" % [mode, profile, entry.id])
		image.save_png(path)
		shots.append({
			"id": entry.id, "file": path.get_file(),
			"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		})
	var report := {
		"mode": mode, "profile": profile, "resolution": [SIZE.x, SIZE.y],
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"engine": Engine.get_version_info().string,
		"source_commit": OS.get_environment("COLOSSEUM_CAPTURE_COMMIT"),
		"texture_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		"buffer_memory_bytes": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		"static_memory_bytes": OS.get_static_memory_usage(),
		"device_confirmed": false,
		"shots": shots, "failures": failures,
	}
	var file := FileAccess.open(folder.path_join("%s_%s_report.json" % [mode, profile]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("COLOSSEUM_CAPTURE ", JSON.stringify(report))
	if failures.is_empty():
		print("COLOSSEUM_CAPTURE_PASS")
	quit(0 if failures.is_empty() else 1)
