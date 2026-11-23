extends SceneTree
## Matching production-world views. Output is engine imagery, never a phone benchmark.
const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
var output := ""
var baseline := false
var captures: Array[Dictionary] = []
var errors: Array[String] = []
var world

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	output = args[0]
	baseline = args.has("--baseline")
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()

func _run() -> void:
	var model = Model.new()
	if baseline:
		model.new_game("italia", true)
	else:
		model.call("new_game", "italia", true, true)
	world = World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_quality("balanced")
	world.set_active(false)
	world.set_physics_process(false)
	for shot in [
		["family-street", Vector3(3, 7, 36), Vector3(-5, 1.2, 23), Vector3(-5, 1, 29)],
		["family-room", Vector3(-5, 2.15, 26.5), Vector3(-5, 1.15, 22.8), Vector3(-5, 1.3, 25.6)],
		["neighbourhood", Vector3(16, 22, 45), Vector3(-5, 0, 20), Vector3(-5, 1, 29)]]:
		world._player.position = shot[3]
		if world.has_method("update_childhood_presentation"):
			world.update_childhood_presentation()
		world._camera.position = shot[1]
		world._camera.look_at(shot[2])
		world._camera.fov = 62
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if picture == null or picture.is_empty() or picture.save_png(output.path_join(shot[0] + ".png")) != OK:
			errors.append(shot[0])
		captures.append({"file":shot[0] + ".png", "camera_position":[shot[1].x,shot[1].y,shot[1].z],
			"look_at":[shot[2].x,shot[2].y,shot[2].z], "fov":62, "pixels":[root.size.x,root.size.y]})
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"baseline":baseline,"android_device_test":false,
		"source_state":"legacy village" if baseline else "new childhood", "captures":captures,"errors":errors}
	var file := FileAccess.open(output.path_join("review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ") + "\n")
	file.close()
	world.free()
	print("CHILDHOOD_RENDER_REVIEW ",JSON.stringify(errors))
	quit(0 if errors.is_empty() else 1)
