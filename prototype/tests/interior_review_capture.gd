extends SceneTree
## Graphical interior review for every Valdora house: two fixed eye-height views
## per house, per quality profile, with measured draw calls and primitives.
## Requires a real viewport (xvfb-run) and IMPERATHEN_ISOLATED_TEST=1.
## Usage: godot --path prototype --resolution WxH --script res://tests/interior_review_capture.gd -- <out_dir> <label> [profiles] [houses]

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const PROFILE_DATA = preload("res://assets/quality_profiles.json")
# Local house coordinates: door at +Z, floor at Layout.HOUSE_FLOOR.
const VIEWS := {
	"door": [Vector3(0.35, 1.52, 1.95), Vector3(-0.55, 0.62, -1.35)],
	"back": [Vector3(-2.05, 1.58, -1.55), Vector3(1.25, 0.55, 1.05)],
}
const ATRIUM_VIEWS := {
	"door": [Vector3(0.0, 1.65, 3.2), Vector3(0.0, 0.6, -3.0)],
	"back": [Vector3(-3.6, 1.7, -3.6), Vector3(2.5, 0.6, 1.5)],
}
var output := ""
var label := ""
var profiles: Array = ["balanced", "very_high"]
var houses: Array = []
var report := {}
var errors: Array[String] = []
var world: Node3D
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.size() < 2 or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directories, an output path and a label are required.")
		quit(2)
		return
	output = args[0]
	label = args[1]
	if args.size() > 2 and args[2] != "":
		profiles = args[2].split(",")
	if args.size() > 3 and args[3] != "" and args[3] != "all":
		houses = Array(args[3].split(","))
	else:
		for home: Dictionary in Layout.HOMES:
			houses.append(home.id)
		houses.append("AtriumHouse")
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	world = World.new()
	root.add_child(world)
	var started := Time.get_ticks_usec()
	world.setup(model.data)
	var build_ms := (Time.get_ticks_usec() - started) / 1000.0
	world.set_active(true)
	world.set_physics_process(false)
	world.set_process(false)
	world.set_presentation_time(4.0)
	camera = Camera3D.new()
	camera.name = "InteriorReviewCamera"
	camera.near = 0.08
	root.add_child(camera)
	camera.make_current()
	var output_size := root.size
	var portrait := output_size.y > output_size.x
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.fov = 72.0 if portrait else 60.0
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "label": label, "output_pixels": [output_size.x, output_size.y],
		"world_setup_ms": build_ms, "houses": {}}
	for profile: String in profiles:
		_apply(profile)
		for id: String in houses:
			var house := world.get_node_or_null("FrontierVillage/" + id) as Node3D
			if house == null:
				house = _find_house(id)
			if house == null:
				errors.append("Missing house " + id)
				continue
			var views: Dictionary = ATRIUM_VIEWS if id == "AtriumHouse" else VIEWS
			var floor_height := 0.065 if id == "AtriumHouse" else Layout.HOUSE_FLOOR
			for view: String in views:
				var eye: Vector3 = views[view][0] + Vector3.UP * floor_height
				var target: Vector3 = views[view][1] + Vector3.UP * floor_height
				camera.global_position = house.to_global(eye)
				camera.look_at(house.to_global(target), Vector3.UP)
				for i in 6:
					await process_frame
				await _settle()
				var stats := await _measure()
				var key := "%s/%s/%s" % [id, view, profile]
				report.houses[key] = stats
				_capture("%s_%s_%s_%s_%dx%d" % [label, id, view, profile, output_size.x, output_size.y])
	report.errors = errors
	var file := FileAccess.open(output.path_join("%s_%dx%d.json" % [label, output_size.x, output_size.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("INTERIOR_REVIEW ", label, " ", JSON.stringify(errors))
	world.free()
	quit(0 if errors.is_empty() else 1)


func _find_house(id: String) -> Node3D:
	for node: Node in world.find_children(id, "Node3D", true, false):
		return node as Node3D
	return null


func _apply(profile: String) -> void:
	var settings: Dictionary = PROFILE_DATA.data.profiles[profile]
	var viewport := root
	viewport.mesh_lod_threshold = float(settings.mesh_lod_threshold)
	viewport.msaa_3d = Viewport.MSAA_4X if int(settings.msaa_samples) == 4 else (Viewport.MSAA_2X if int(settings.msaa_samples) == 2 else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(int(settings.shadow_atlas_size), true)
	# Balanced is the Fold7 phone budget; very_high is the desktop budget.
	var budget: float = settings.max_3d_pixels if profile != "very_high" else settings.get("desktop_max_3d_pixels", settings.max_3d_pixels)
	viewport.scaling_3d_scale = clampf(sqrt(budget / maxf(float(root.size.x * root.size.y), 1.0)), 0.25, 1.0)
	world.set_quality(profile)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _settle() -> void:
	for i in 4:
		await RenderingServer.frame_post_draw


func _measure() -> Dictionary:
	var calls := []
	var primitives := []
	var objects := []
	for i in 6:
		await RenderingServer.frame_post_draw
		calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		objects.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	calls.sort()
	primitives.sort()
	objects.sort()
	var lights := 0
	for light: Light3D in world.find_children("*", "Light3D", true, false):
		if light.is_visible_in_tree():
			lights += 1
	return {"draw_calls": calls[calls.size() / 2], "primitives": primitives[primitives.size() / 2],
		"objects": objects[objects.size() / 2], "visible_lights": lights, "scale_3d": root.scaling_3d_scale}


func _capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(name + ".png")) != OK:
		errors.append("Empty viewport capture: " + name)
