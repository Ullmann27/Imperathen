extends SceneTree
## Real Godot viewport of the isolated rider module, not a production-village capture.

const Raiders = preload("res://scripts/world/childhood_raiders.gd")
var output := ""
var failures: Array[String] = []
var captures: Array[Dictionary] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.is_empty():
		printerr("A graphical viewport and an output directory are required.")
		quit(2)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("17202c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("9aabc0")
	environment.environment.ambient_light_energy = 0.75
	scene.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38,-25,0)
	moon.light_color = Color("dce3e9")
	moon.light_energy = 1.6
	moon.shadow_enabled = true
	scene.add_child(moon)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180,300)
	ground.mesh = plane
	ground.position = Vector3(0,-0.02,-100)
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("514d40")
	earth.roughness = 0.95
	ground.material_override = earth
	scene.add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(22,21,-34)
	camera.fov = 53.0
	scene.add_child(camera)
	camera.look_at(Vector3(0,1.3,-87))
	camera.current = true
	var riders := Raiders.new()
	scene.add_child(riders)
	var data := {"village":{"enabled":true, "childhood":{"night_raid":{
		"phase":"approach", "elapsed":32.0, "seed":1731, "decision":"pending",
		"support_confirmed":false, "support_kind":"", "consequences_applied":false, "outcome":""}}}}
	for profile: String in ["low", "very_high"]:
		riders.sync_state(data, profile)
		await _capture("raiders-" + profile, riders, camera, "Identical saved arrival state and camera; isolated module comparison")
	data.village.childhood.night_raid.elapsed = 24.0
	var sample: Dictionary = Raiders.sample_riders(data.village.childhood.night_raid)[0]
	camera.position = sample.position + Vector3(3.3,3.1,4.1)
	camera.look_at(sample.position + Vector3(0,1.5,-0.1))
	camera.fov = 47.0
	riders.sync_state(data, "very_high")
	await _capture("rider-detail", riders, camera, "Saved approach at 24 seconds; original horse, seated rider and jointed legs")
	var report := {"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"context":"Isolated production rider module in an authored review stage. No full-village, Android hardware, FPS or historical event claim.",
		"android_device_test":false, "captures":captures, "errors":failures}
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ") + "\n")
	file.close()
	print("CHILDHOOD_RAIDERS_REVIEW ", JSON.stringify(failures))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _capture(label: String, riders: Node3D, camera: Camera3D, purpose: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(output.path_join(label + ".png")) != OK:
		failures.append("Empty or unsaved viewport: " + label)
	captures.append({"file":label + ".png", "purpose":purpose,
		"snapshot":riders.debug_snapshot(), "camera_position":str(camera.position),
		"camera_transform":str(camera.transform), "camera_fov":camera.fov,
		"output_pixels":[root.size.x,root.size.y]})
