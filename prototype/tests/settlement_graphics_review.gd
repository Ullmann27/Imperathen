extends SceneTree
## Production world/people viewport review with explicitly positioned cameras.
## Still renders do not measure Android or physical-phone performance.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var output := ""
var world: Node3D
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var profile := "balanced"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or OS.get_cmdline_user_args().is_empty():
		printerr("A graphical viewport, isolated user settings and an output directory are required.")
		quit(2)
		return
	output = OS.get_cmdline_user_args()[0]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			profile = argument.trim_prefix("--quality=")
	DirAccess.make_dir_recursive_absolute(output)
	print("SETTLEMENT_REVIEW_STAGE script_ready profile=",profile)
	_run.call_deferred()


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	print("SETTLEMENT_REVIEW_STAGE model_ready")
	world = World.new()
	world._quality_profile = profile
	world.population.profile = profile
	root.add_child(world)
	print("SETTLEMENT_REVIEW_STAGE world_added")
	world.set_quality(profile)
	world.setup(model.data)
	print("SETTLEMENT_REVIEW_STAGE world_configured")
	world.set_quality(profile)
	world.set_active(true)
	world.set_physics_process(false)
	world.scenery.set_presentation_time(14.0)
	# Let the actual production capsule settle, then keep the photograph still.
	world.get_node("Player").position = Vector3(-12,1.35,11.7)
	for frame in 25:
		await physics_frame
		world._move_player(1.0/60.0)
	world._figure.rotation.y = PI*.52
	world.population.advance_to(25.0,true)
	print("SETTLEMENT_REVIEW_STAGE floor_settled")
	await _capture("01-family-interior",Vector3(-10.65,2.15,12.6),Vector3(-12.8,1.05,10.4),72)
	await _capture("02-family-doorstep",Vector3(-18.0,2.6,17.8),Vector3(-13.5,1.25,11.8),66)
	world.get_node("Player").position = Vector3(31.85,.91,-26.5)
	world._figure.rotation.y = -PI*.5
	await _capture("03-village-forge",Vector3(28.9,2.7,-22.4),Vector3(34.2,1.05,-26.2),63)
	world.get_node("Player").position = Vector3(21.2,.91,26.4)
	world._figure.rotation.y = -PI*.6
	await _capture("04-market-homes",Vector3(12.0,5.8,33.0),Vector3(25.2,1.25,22.4),64)
	await _capture("05-residential-street",Vector3(28.5,2.4,10.8),Vector3(35.1,1.35,-15.5),68)
	await _capture("06-settlement-overview",Vector3(56,34,49),Vector3(12,0,-8),64)
	var report := {
		"engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"output_pixels":[root.size.x,root.size.y],
		"android_device_test":false,
		"presentation":"Actual production World, assets and people; fixed review cameras and explicit player repositioning",
		"houses":world.regional.house_count,"ambient_residents":world.population.actors.size(),
		"economic_residents":world.village_life_world.actors.size(),
		"family_floor_height":Layout.HOUSE_FLOOR,"captures":captures,"errors":failures,
		"quality":profile,
	}
	var file := FileAccess.open(output.path_join("settlement-review.json"),FileAccess.WRITE)
	if file == null:
		failures.append("Could not write render report")
	else:
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
	world.free()
	print("SETTLEMENT_GRAPHICS_REVIEW ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)


func _capture(title: String, at: Vector3, target: Vector3, field_of_view: float) -> void:
	var camera: Camera3D = world._camera
	camera.current = true
	camera.position = at
	camera.look_at(target)
	camera.fov = field_of_view
	for person: Node3D in get_nodes_in_group("village_people"):
		person.refresh_lod(camera)
	for frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(title+".png")) != OK:
		failures.append("Missing viewport capture: "+title)
	else:
		captures.append({"file":title+".png","camera":[at.x,at.y,at.z],"target":[target.x,target.y,target.z],"fov":field_of_view})
		print("SETTLEMENT_REVIEW_CAPTURE ",title)
