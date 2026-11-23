extends SceneTree
## Reproducible graphical fixture: same authored props, cameras and quality.
const Dressing = preload("res://scripts/world/village/frontier_dressing.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
var output := ""
var scene: Node3D
var camera: Camera3D
var report := {}

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or OS.get_cmdline_user_args().is_empty():
		printerr("Isolated run and output directory required")
		quit(2)
		return
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()

func run() -> void:
	Engine.max_fps = 0
	root.msaa_3d = Viewport.MSAA_2X
	root.scaling_3d_scale = 1.0
	scene = Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("879ba4")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b7c5cc")
	environment.environment.ambient_light_energy = .65
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color(1, .88, .69)
	sun.light_energy = .7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	scene.add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(140, 140)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("6e7051")
	ground.material_override = ground_material
	scene.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 54
	camera.near = .1
	camera.far = 150
	scene.add_child(camera)
	camera.current = true
	var started := Time.get_ticks_usec()
	var dressing := Dressing.new()
	scene.add_child(dressing)
	dressing.build()
	dressing.set_quality("balanced")
	report = {"engine": Engine.get_version_info().string, "adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(),
		"output_px": [root.size.x, root.size.y], "profile": "balanced", "sample_frames": 60,
		"scope": "Isolated unchanged authored frontier props; desktop render counters. Software GPU timings and frame times are not phone FPS, battery or heat measurements.",
		"construction_ms": (Time.get_ticks_usec()-started)/1000.0, "geometry": census(dressing), "views": {}}
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	if DisplayServer.get_name() != "headless":
		for view in [
			{"name":"wagon", "from":Vector3(11, 3, 30), "to":Vector3(7.4, 1, 24)},
			{"name":"garden", "from":Vector3(49, 5, 12), "to":Vector3(43.5, .2, 5)},
			{"name":"street", "from":Vector3(25, 17, 27), "to":Vector3(23, 0, -3)}]:
			camera.position = view.from
			camera.look_at(view.to)
			report.views[view.name] = await sample()
			root.get_texture().get_image().save_png(output.path_join(view.name+".png"))
	dressing.free()
	var actor := Person.new()
	actor.name = "MotionReview"
	scene.add_child(actor)
	actor.configure("player", "italia", 12)
	actor.position.y = .9
	actor.set_process(false)
	actor._reload(0)
	camera.position = Vector3(2.7, 1.6, 3.5)
	camera.look_at(Vector3(0, .85, 0))
	var skeleton: Skeleton3D = actor.body.find_children("*", "Skeleton3D", true, false)[0]
	report.motion = []
	for action: String in ["idle", "march", "run"]:
		for fraction: float in [0.0, .25, .5, .75]:
			actor.sample_pose(action, fraction)
			var pose := {"clip":action, "phase":fraction, "joints":{}}
			for bone: String in ["Arm_L", "Forearm_L", "Hand_L", "Arm_R", "Forearm_R", "Hand_R", "Spine", "Head", "Foot_L", "Foot_R"]:
				var point := skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
				pose.joints[bone] = [point.x, point.y, point.z]
			report.motion.append(pose)
			if DisplayServer.get_name() != "headless":
				for frame in 3: await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("motion-%s-%d.png" % [action, roundi(fraction*100)]))
	report.unarmed = {}
	if actor.has_method("cue_unarmed"):
		for action: String in ["jab_left", "jab_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right", "headbutt", "front_kick", "side_kick", "high_kick"]:
			if not actor.call("cue_unarmed", action): continue
			actor.sample_pose(action, .4)
			var pose := {}
			for bone: String in ["Hand_L", "Hand_R", "Foot_R", "Head"]:
				var point := skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
				pose[bone] = [point.x, point.y, point.z]
			report.unarmed[action] = {"duration":actor.animator.current_animation_length, "phase":.4, "joints":pose}
			if DisplayServer.get_name() != "headless":
				for frame in 3: await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("unarmed-"+action+".png"))
	if actor.has_method("set_loaned_gear"):
		actor.sample_pose("idle", .25)
		actor.call("set_loaned_gear", true)
		report.borrowed_gear = {"attachments":actor.body.find_children("LoanedPractice*", "BoneAttachment3D", true, false).size()}
		if DisplayServer.get_name() != "headless":
			for frame in 3: await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("borrowed-practice-gear.png"))
	var file := FileAccess.open(output.path_join("probe.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ")+"\n")
	file.close()
	scene.free()
	await process_frame
	print("VILLAGE_RENDER_PROBE_PASS ", JSON.stringify(report.geometry))
	quit()

func census(parent: Node) -> Dictionary:
	var mesh_count := 0
	var batches := 0
	var instances := 0
	var triangles := 0
	var meshes := {}
	var materials := {}
	for node: Node in parent.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh
		var count := 1
		if node is MeshInstance3D:
			mesh_count += 1
			mesh = node.mesh
		elif node is MultiMeshInstance3D:
			batches += 1
			mesh = node.multimesh.mesh
			count = node.multimesh.instance_count
			instances += count
		else:
			continue
		if not mesh: continue
		meshes[mesh.get_instance_id()] = true
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			var indices: int = 0 if arrays[Mesh.ARRAY_INDEX] == null else arrays[Mesh.ARRAY_INDEX].size()
			triangles += count * (indices if indices > 0 else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var material: Material = node.material_override if node.material_override else mesh.surface_get_material(surface)
			if material: materials[material.get_instance_id()] = true
	return {"mesh_nodes":mesh_count, "multimesh_nodes":batches, "batched_instances":instances,
		"unique_mesh_resources":meshes.size(), "unique_materials":materials.size(), "authored_triangles":triangles,
		"collision_shapes":parent.find_children("*", "CollisionShape3D", true, false).size()}

func sample() -> Dictionary:
	for warmup in 12: await RenderingServer.frame_post_draw
	var wall := []
	var cpu := []
	var gpu := []
	var calls := []
	var primitives := []
	var rid := root.get_viewport_rid()
	var previous := Time.get_ticks_usec()
	for frame in 60:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append((now-previous)/1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	return {"frame_ms":quantiles(wall), "viewport_cpu_ms":quantiles(cpu), "viewport_gpu_ms":quantiles(gpu),
		"draw_calls":quantiles(calls), "visible_primitives":quantiles(primitives)}

func quantiles(values: Array) -> Dictionary:
	values.sort()
	return {"p50":values[ceili(values.size()*.50)-1], "p95":values[ceili(values.size()*.95)-1]}
