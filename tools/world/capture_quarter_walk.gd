extends "res://tests/quarter_street_walk_test.gd"
## Renders the existing traversal while leaving the walking controller untouched.
var output: String
var city_view: City
var ticks := 0
var shot := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() != 1:
		quit(2)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i.ZERO
	RenderingServer.render_loop_enabled = false
	process_frame.connect(_capture)
	super()

func _capture() -> void:
	if not is_instance_valid(city_view):
		for child in root.get_children():
			if child is City:
				city_view = child
		return
	if not is_instance_valid(city_view.player) or not is_instance_valid(city_view.camera):
		return
	ticks += 1
	var v := city_view.player.velocity
	if v.x * v.x + v.z * v.z > 0.05:
		city_view._yaw = rotate_toward(city_view._yaw, atan2(-v.x,-v.z), 0.035)
	if ticks % 15 != 0:
		return
	RenderingServer.force_draw(false, 1.0 / 60.0)
	var img := root.get_texture().get_image()
	if img == null or img.save_jpg(output.path_join("%05d.jpg" % shot), .90) != OK:
		printerr("Kein gültiges Einzelbild")
		quit(1)
		return
	shot += 1
