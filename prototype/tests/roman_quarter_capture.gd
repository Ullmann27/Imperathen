extends SceneTree
## Captures the new quarter in its actual city traversal scene using one renderer.

const City := preload("res://scripts/world/city_exploration.gd")
const STREET_CAMERA := Vector3(28.5, 2.35, 11.35)
const STREET_FOCUS := Vector3(28.8, 1.65, -1.2)
var _output := ""
var _failed := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless":
		printerr("Use a graphics renderer and pass one writable output directory after --")
		quit(2)
		return
	_output = args[0]
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		quit(2)
		return
	_run.call_deferred()


func _frame(city: Node3D, filename: String, eye: Vector3, aim: Vector3, lens: float) -> void:
	city.camera.position = eye
	city.camera.fov = lens
	city.camera.look_at(aim)
	for i in 4:
		await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(_output.path_join(filename + ".png")) != OK:
		_failed = true
		printerr("Screenshot write failed for ", filename)
	print(JSON.stringify({"capture": filename, "camera": str(eye), "target": str(aim), "fov": lens,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "profile": city.profile, "jdn": city.world_jdn}))


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1120, 630)
	var city := City.new()
	city.persist = false
	city.profile = "very_high"
	root.add_child(city)
	if not city.city_available or not is_instance_valid(city.quarter):
		printerr("Actual RomanCity and the installed district are required")
		quit(2)
		return
	city.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in city.get_children():
		if child is CanvasLayer:
			child.hide()
	city.figure.hide()
	city.quarter.hide()
	await _frame(city, "01-Vorher", STREET_CAMERA, STREET_FOCUS, 57.0)
	city.quarter.show()
	await _frame(city, "02-Strasse", STREET_CAMERA, STREET_FOCUS, 57.0)
	await _frame(city, "03-Schmiede", Vector3(33.03, 1.78, -2.3), Vector3(37.6, 1.15, -3.0), 72.0)
	await _frame(city, "04-Taberna", Vector3(33.07, 1.65, 2.27), Vector3(37.24, 1.26, 3.36), 69.0)
	await _frame(city, "05-Wachstafel", Vector3(36.52, 1.68, 2.99), Vector3(37.19, 1.33, 3.28), 46.0)
	await _frame(city, "06-Brunnen", Vector3(26.3, 1.56, -2.35), Vector3(22.51, 1.03, -4.34), 48.0)
	await _frame(city, "07-Kreuzung", Vector3(28.4, 2.15, -7.7), Vector3(28.0, 1.52, -17.7), 61.0)
	await _frame(city, "08-Stallhof", Vector3(27.85, 2.40, -29.3), Vector3(38.2, 1.44, -29.2), 67.0)
	city.free()
	await process_frame
	quit(1 if _failed else 0)
