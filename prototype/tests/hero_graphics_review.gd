extends SceneTree
## Real production player and material review in an isolated Godot studio.
## This is an engine viewport capture, not an Android benchmark or village capture.

const Person := preload("res://scripts/visuals/village_person.gd")
const PROFILES := ["low", "balanced", "high", "very_high"]

class LegacyReviewPerson:
	extends "res://scripts/visuals/village_person.gd"
	func _path(level: int) -> String:
		return _legacy_path(level)

var output := ""
var require_hero := true
var record_motion := false
var stage: Node3D
var figure: Node3D
var camera: Camera3D
var report := {}
var failures: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty():
		printerr("A real graphical viewport, isolated test settings and output directory are required.")
		quit(2)
		return
	output = args[0]
	require_hero = not ("--baseline" in args)
	record_motion = "--motion" in args
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	_setup_lighting()
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	figure = Person.new() if require_hero else LegacyReviewPerson.new()
	stage.add_child(figure)
	figure.position.y = 0.9
	figure.configure("player", "italia", 12)
	report = {
		"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"output_pixels": [root.size.x, root.size.y],
		"android_device_test": false,
		"environment": "Controlled Godot studio with the production VillagePerson actor; not a village screenshot",
		"actor_script": "res://scripts/visuals/village_person.gd",
		"legacy_asset_forced_for_comparison": not require_hero,
		"captures": [],
	}
	for profile: String in PROFILES:
		_apply(profile)
		_portrait(12, 0.18)
		await _capture("child-" + profile, profile, 12, "idle")
	_apply("very_high")
	for item in [["child-front", 12, 0.0], ["child-profile", 12, 1.48], ["adult-front", 22, 0.0], ["adult-three-quarter", 22, 0.55], ["adult-profile", 22, 1.48]]:
		_portrait(item[1], item[2])
		await _capture(item[0], "very_high", item[1], "idle")
	if require_hero:
		_portrait(12, 0.18)
		# Show identical framing for each exported asset, independently of the
		# normal distance selection. This makes decimation defects reviewable.
		for level in 4:
			figure._reload(level)
			figure._check_lod = 1000.0
			figure.sample_pose("idle", 0.25)
			await _capture("asset-lod-" + str(level), "very_high", 12, "idle")
		figure._reload(0)
		figure._check_lod = 1000.0
		# Advance the actual facial controller deterministically, without moving
		# the body. This records its blink, not a manually painted closed eye.
		for years: int in [12, 22]:
			_portrait(years, 0.18)
			var blink_found := false
			for step in 840:
				figure._face.advance(1.0 / 120.0, "idle", 0)
				if _face_weight("Blink_L") > 0.85:
					blink_found = true
					break
			if not blink_found:
				failures.append("The facial controller did not produce a visible blink at age " + str(years))
			await _capture("child-blink" if years == 12 else "adult-blink", "very_high", years, "idle + natural blink")
		_portrait(12, 0.18)
		figure._face.pose("talk", 0.05, 0)
		await _capture("child-talking", "very_high", 12, "idle body + talk face")
		figure._check_lod = 0.0
	for years: int in [12, 22]:
		figure.configure("player", "italia", years)
		var ground: Vector3 = figure.global_position - Vector3.UP * 0.9
		var facing: Vector3 = -figure.global_basis.z
		camera.global_position = ground + Vector3.UP * 0.95 + facing.rotated(Vector3.UP, 0.28) * 3.6
		camera.look_at(ground + Vector3.UP * (0.82 if years < 18 else 0.92))
		camera.fov = 34
		figure.refresh_lod(camera)
		figure.sample_pose("idle", 0.25)
		await _capture("full-body-" + str(years), "very_high", years, "idle")
	if record_motion:
		DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
		figure.configure("player", "italia", 22)
		for frame in 72:
			figure.sample_pose("march", float(frame % 24) / 24.0)
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			if shot == null or shot.is_empty() or shot.save_png(output.path_join("motion/frame-%04d.png" % frame)) != OK:
				failures.append("Empty motion frame " + str(frame))
		report["motion"] = {"frames": 72, "playback_fps": 24, "action": "march", "source": "Production player GLB animation sampled at exact times", "measured_device_fps": false}
	report["errors"] = failures
	var file := FileAccess.open(output.path_join("runtime-review.json"), FileAccess.WRITE)
	if file == null:
		printerr("Could not write runtime review report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("HERO_GRAPHICS_REVIEW ", JSON.stringify(failures))
	stage.free()
	quit(0 if failures.is_empty() else 1)


func _setup_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.065, 0.079, 0.089)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.78, 0.88)
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, 154, 0)
	sun.light_color = Color(1.0, 0.89, 0.77)
	sun.light_energy = 0.50
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 8.0
	stage.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.4, 2.2, -2.4)
	fill.light_color = Color(0.70, 0.80, 1.0)
	fill.light_energy = 0.25
	fill.omni_range = 5.0
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(6, 6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.14, 0.15)
	material.roughness = 0.94
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)


func _apply(profile: String) -> void:
	root.get_node("RuntimeDisplay").apply_quality(profile)
	figure.profile = profile


func _portrait(years: int, angle: float) -> void:
	figure.configure("player", "italia", years)
	var ground: Vector3 = figure.global_position - Vector3.UP * 0.9
	var eye_height := 1.40 if years < 18 else 1.58
	var target := ground + Vector3.UP * eye_height
	var facing: Vector3 = -figure.global_basis.z
	camera.global_position = target + facing.rotated(Vector3.UP, angle) * 1.04 + Vector3.UP * 0.015
	camera.look_at(target)
	camera.fov = 32
	figure.refresh_lod(camera)
	figure.sample_pose("idle", 0.25)


func _capture(label: String, profile: String, years: int, action: String) -> void:
	for i in 5:
		await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(label + ".png")) != OK:
		failures.append("Empty viewport capture: " + label)
	var active_path: String = figure.active_model_path
	if require_hero and not "hero_quality_" in active_path:
		failures.append("Player used a legacy model: " + active_path)
	var skeletons: Array[Node] = figure.body.find_children("*", "Skeleton3D", true, false)
	var bones: int = skeletons[0].get_bone_count() if not skeletons.is_empty() else 0
	report.captures.append({"file": label + ".png", "profile": profile, "age": years,
		"asset": active_path, "lod": figure.detail, "action": action, "bones": bones,
		"camera_transform": str(camera.global_transform), "camera_fov": camera.fov,
		"scale_3d": root.scaling_3d_scale, "forced_asset_lod": label.begins_with("asset-lod-"),
		"face_weights": {"Blink_L": _face_weight("Blink_L"), "Blink_R": _face_weight("Blink_R"),
			"JawOpen": _face_weight("JawOpen"), "Smile": _face_weight("Smile"), "BrowDown": _face_weight("BrowDown")}})
	print("HERO_CAPTURE ", label, " ", active_path)


func _face_weight(shape_name: String) -> float:
	for mesh: MeshInstance3D in figure.body.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh:
			continue
		var slot := mesh.find_blend_shape_by_name(shape_name)
		if slot >= 0:
			return mesh.get_blend_shape_value(slot)
	return 0.0
