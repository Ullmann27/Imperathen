extends SceneTree
## Deterministic production-actor studio review. Desktop captures, never phone FPS.

const Person := preload("res://scripts/visuals/village_person.gd")
var stage: Node3D
var actor: Node3D
var camera: Camera3D
var output := ""
var captures: Array = []
var actor_script := "res://scripts/visuals/village_person.gd"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.is_empty() or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated real viewport and output folder are required")
		quit(2)
		return
	output = args[0]
	for arg: String in args:
		if arg.begins_with("--actor-script="):
			actor_script = arg.trim_prefix("--actor-script=")
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("26363c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bfcedd")
	environment.ambient_light_energy = 0.40
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 138, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	ground.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("68756a")
	material.roughness = 0.9
	ground.material_override = material
	stage.add_child(ground)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 32
	actor = (load(actor_script) as Script).new()
	stage.add_child(actor)
	actor.position.y = 0.9
	actor.configure("player", "italia", 12)
	actor.profile = "very_high"
	actor._check_lod = 10000.0
	actor.set_process(false)
	root.get_node("RuntimeDisplay").apply_quality("very_high")
	if "--metrics-only" in OS.get_cmdline_user_args():
		_write_report(await _measure())
		return
	for shot in [["idle_front", "idle", 0.25, 0.08], ["idle_side", "idle", 0.25, 1.45], ["walk_front", "march", 0.22, 0.35], ["walk_side", "march", 0.22, 1.45], ["run_side", "run", 0.22, 1.45]]:
		_camera(float(shot[3]))
		actor.sample_pose(shot[1], shot[2])
		await _capture(shot[0])
	if actor.has_method("sample_combat"):
		_camera(0.65)
		for technique: String in ["jab_left", "jab_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right", "headbutt", "front_kick", "side_kick", "high_kick"]:
			actor.sample_combat(technique, 0.45)
			await _capture(technique)
		actor.sample_combat("jab_right", 0.41)
		var hand_skeleton: Skeleton3D = actor.body.find_children("*", "Skeleton3D", true, false)[0]
		var fist := hand_skeleton.global_transform * hand_skeleton.get_bone_global_pose(hand_skeleton.find_bone("Hand_R")).origin
		camera.position = fist + Vector3(-0.22, 0.14, -0.46)
		camera.look_at(fist + Vector3(0, 0.0, -0.04))
		await _capture("fist_close")
		_camera(0.65)
		actor.cancel_action()
		for level in 4:
			actor._reload(level)
			actor._check_lod = 10000.0
			actor.sample_pose("march", 0.22)
			await _capture("walk_lod_%d" % level)
		actor._reload(0)
		actor._check_lod = 10000.0
	if "--motion" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
		_camera(0.85)
		for frame in 240:
			var time := float(frame) / 30.0
			if time < 2.0:
				actor.sample_pose("march", fmod(time * 1.45 / 1.04, 1.0))
			elif time < 4.0:
				actor.sample_pose("run", fmod((time - 2.0) * 3.8 / 2.0, 1.0))
			elif actor.has_method("sample_combat"):
				if time < 4.62:
					actor.sample_combat("jab_left", (time - 4.0) / 0.62)
				elif time < 5.44:
					actor.sample_combat("hook_right", (time - 4.62) / 0.82)
				elif time < 6.34:
					actor.sample_combat("uppercut_left", (time - 5.44) / 0.90)
				elif time < 7.64:
					actor.sample_combat("high_kick", (time - 6.34) / 1.30)
				else:
					actor.sample_pose("idle", time - 7.64)
			else:
				actor.sample_pose("train", fmod(time - 4.0, 1.0))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("frames/frame-%04d.png" % frame))
	_write_report(await _measure())


func _measure() -> Dictionary:
	if actor.has_method("cancel_action"):
		actor.cancel_action()
	actor.configure("player", "italia", 12)
	actor._reload(0)
	actor._check_lod = 10000.0
	actor.reset_motion()
	actor.drive(1.45)
	_camera(0.85)
	for warmup in 60:
		actor._process(1.0 / 60.0)
	var samples: Array[float] = []
	for sample in 600:
		var started := Time.get_ticks_usec()
		actor._process(1.0 / 60.0)
		samples.append(float(Time.get_ticks_usec() - started))
	for frame in 4:
		await RenderingServer.frame_post_draw
	samples.sort()
	var total := 0.0
	for sample: float in samples:
		total += sample
	var meshes := actor.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.visible and mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
	return {"scenario": "One child player, LOD0, very_high, fixed studio/camera, 1.45 m/s walking; same original assets", "cpu_scope": "600 synchronous actor._process calls after 60 warmup calls, dt=1/60; excludes rendering, physics, loading, and OS frame pacing", "cpu_mean_us": total / samples.size(), "cpu_median_us": samples[300], "cpu_p95_us": samples[570], "actor_nodes": actor.find_children("*", "", true, false).size() + 1, "actor_meshes": meshes.size(), "actor_visible_triangles": triangles, "scene_draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "scene_rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), "resolution": [root.size.x, root.size.y], "measured_fps": false, "phone_temperature_measured": false}


func _write_report(cost: Dictionary) -> void:
	var report := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "android_device_test": false, "actor_script": actor_script, "source": "Actual production VillagePerson in a fixed Godot studio", "captures": captures, "cost": cost}
	var file := FileAccess.open(output.path_join("motion-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	stage.free()
	print("CHARACTER_MOTION_REVIEW_PASS")
	quit(0)


func _camera(angle: float) -> void:
	var target := Vector3(0, 0.80, 0)
	camera.position = target + Vector3(0, 0.07, -3.9).rotated(Vector3.UP, angle)
	camera.look_at(target)


func _capture(label: String) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(label + ".png")) != OK:
		printerr("Capture failed: " + label)
		quit(2)
		return
	var skeleton: Skeleton3D = actor.body.find_children("*", "Skeleton3D", true, false)[0]
	var bones := {}
	for bone in skeleton.get_bone_count():
		var point := skeleton.get_bone_global_pose(bone).origin
		var rest := skeleton.get_bone_global_rest(bone)
		bones[skeleton.get_bone_name(bone)] = {"position": [point.x, point.y, point.z], "rest_position": [rest.origin.x, rest.origin.y, rest.origin.z], "rest_direction": [rest.basis.y.x, rest.basis.y.y, rest.basis.y.z]}
	captures.append({"file": label + ".png", "asset": actor.active_model_path, "lod": actor.detail, "camera": str(camera.transform), "bones": bones})
