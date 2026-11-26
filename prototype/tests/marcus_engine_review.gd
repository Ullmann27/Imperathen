extends SceneTree
## Real campaign actor in the world scene, not a concept image. Test camera
## positions and pose samples are explicitly fixtures; no Android FPS claim.
const World := preload("res://scripts/world/game_world.gd")
const Model := preload("res://scripts/domain/world_model.gd")
const Person := preload("res://scripts/visuals/village_person.gd")
var output := ""
var shots: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("MARCUS_REVIEW_REQUIRES_ISOLATED_GRAPHICAL_ENGINE")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _capture(camera: Camera3D, friend: Person, id: String, offset: Vector3, focus: Vector3, fov: float, clip: String, phase: float) -> void:
	var origin := friend.global_position - Vector3.UP * .9
	camera.global_position = origin + offset
	camera.look_at(origin + focus)
	camera.fov = fov
	camera.current = true
	friend._reload(0)
	friend.sample_pose(clip, phase)
	for i in 3:
		await process_frame
		RenderingServer.force_draw(true,1.0/60.0)
	var image := root.get_texture().get_image()
	var target := output.path_join(id + ".png")
	if image == null or image.is_empty() or image.save_png(target) != OK:
		failures.append("Actual viewport image missing: " + id)
		return
	shots.append({"id":id,"model":friend.active_model_path,"clip":clip,"phase":phase,
		"camera_position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],
		"image":target.get_file(),"sha256":FileAccess.get_sha256(target),"size":[image.get_width(),image.get_height()]})

func _run() -> void:
	seed(20261126)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var model := Model.new()
	model.new_game("italia",true,true,false,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_quality("high")
	world.set_active(false)
	world.set_presentation_time(4.0)
	_freeze(world)
	await process_frame
	var friend := world.get_node_or_null("Marcus/Figure") as Person
	var camera := world._camera as Camera3D
	if friend == null or camera == null or not Person.MarcusModel.owns(friend.active_model_path):
		failures.append("Real Marcus is not bound to the new family")
	else:
		# The existing actor remains at his real world position. Only its yaw
		# and camera pose are fixed for reproducible inspection.
		friend.rotation.y = 0.0
		friend.get_parent().show()
		if world._companion_label:
			world._companion_label.hide()
		await _capture(camera,friend,"marcus-village-face",Vector3(.25,1.38,-1.35),Vector3(0,1.30,0),34.0,"idle",.25)
		await _capture(camera,friend,"marcus-village-full",Vector3(1.1,1.62,-3.3),Vector3(0,.78,0),37.0,"idle",.25)
		await _capture(camera,friend,"marcus-village-talk",Vector3(.6,1.40,-1.4),Vector3(0,1.28,0),37.0,"talk",.30)
		await _capture(camera,friend,"marcus-village-walk",Vector3(2.4,1.45,-2.1),Vector3(0,.80,0),38.0,"march",.37)
	var report := {"scope":"actual Godot GameWorld with generated Marcus GLB, fixed review cameras and pose fixtures",
		"android_device_test":false,"quality":"high","renderer":RenderingServer.get_current_rendering_method(),
		"shots":shots,"failures":failures,"passed":failures.is_empty() and shots.size()==4}
	var file := FileAccess.open(output.path_join("marcus-engine-review.json"),FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	world.free()
	await process_frame
	print("MARCUS_ENGINE_REVIEW_PASS" if report.passed else "MARCUS_ENGINE_REVIEW_FAIL")
	quit(0 if report.passed else 1)
