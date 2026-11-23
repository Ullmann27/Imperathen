extends SceneTree
## Actual production VillagePerson viewport images; no Android performance claim.
const Person := preload("res://scripts/visuals/village_person.gd")
const IDENTITIES := ["legionary", "officer", "spearman", "archer", "civilian_man", "civilian_woman", "elder"]
var stage: Node3D
var camera: Camera3D
var figure: Person
var output := ""
var captures: Array[Dictionary] = []
var failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty():
		printerr("A graphical viewport, isolated settings and output directory are required.")
		quit(2)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.06, 0.075, 0.085)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.70, 0.79, 0.88)
	world.environment.ambient_light_energy = 0.35
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 154, 0)
	key.light_color = Color(1.0, 0.89, 0.78)
	key.light_energy = 0.65
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.3, 2.2, -2.4)
	fill.light_color = Color(0.72, 0.81, 1.0)
	fill.light_energy = 0.30
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(6, 6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.14, 0.15)
	material.roughness = 0.95
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.current = true
	stage.add_child(camera)
	figure = Person.new()
	stage.add_child(figure)
	figure.position.y = 0.9
	figure.set_process(false)
	figure.profile = "very_high"
	root.get_node("RuntimeDisplay").apply_quality("very_high")
	figure.configure("resident", "italia", 28)
	for identity: String in IDENTITIES:
		figure.configure_appearance(identity, 0)
		figure._reload(0)
		figure.sample_pose("idle", 0.25)
		camera.position = Vector3(0.70, 1.14, -3.65)
		camera.look_at(Vector3(0, 0.95, 0))
		camera.fov = 34
		await _capture(identity + "-full", identity, "idle")
		if identity in ["legionary", "civilian_woman", "elder"]:
			camera.position = Vector3(0.22, 1.62, -1.12)
			camera.look_at(Vector3(0, 1.57, 0))
			camera.fov = 30
			await _capture(identity + "-face", identity, "idle")
		camera.position = Vector3(0.70, 1.14, -3.65)
		camera.look_at(Vector3(0, 0.95, 0))
		camera.fov = 34
		if identity in ["legionary", "civilian_woman", "archer"]:
			var action := "shoot" if identity == "archer" else "march"
			figure.sample_pose(action, 0.62 if action == "shoot" else 0.32)
			await _capture(identity + "-" + action, identity, action)
	var report := {"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "android_device_test": false,
		"environment": "Controlled Godot studio with the production VillagePerson actor; not a village screenshot",
		"profile": "very_high", "captures": captures, "errors": failures}
	var file := FileAccess.open(output.path_join("runtime-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("FRONTIER_GRAPHICS_REVIEW ", JSON.stringify(failures))
	stage.free()
	quit(0 if failures.is_empty() else 1)


func _capture(label: String, identity: String, action: String) -> void:
	for frame in 4:
		await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		failures.append("Empty viewport: " + label)
	if figure.active_model_path != "res://assets/characters/frontier_%s_0.glb" % identity:
		failures.append("Wrong model: " + label)
	captures.append({"file": label + ".png", "identity": identity, "asset": figure.active_model_path,
		"action": action, "lod": figure.detail, "output_pixels": [root.size.x, root.size.y],
		"camera_transform": str(camera.global_transform), "camera_fov": camera.fov})
