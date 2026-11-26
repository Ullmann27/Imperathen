extends SceneTree
## Interior review stage: the real Valdora houses (regional_village.gd, with
## their dressing and interiors) under the game's village atmosphere and season
## light (copied from game_world.gd _create_atmosphere and village_scenery
## apply_season), without terrain streaming, people or the rest of the world,
## so every house can be captured on a CPU rasteriser. Same views as
## interior_review_capture.gd. Draw calls here are the house and its
## neighbours only, not a full game frame.
## Usage: godot --path prototype --resolution WxH --script res://tests/interior_stage_capture.gd -- <out_dir> <label> [profiles] [houses]

const Regional = preload("res://scripts/world/regional_village.gd")
const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const PROFILE_DATA = preload("res://assets/quality_profiles.json")
const VIEWS := {
	# Just inside the door, past the open leaf, looking at the west wall and table.
	"entry": [Vector3(0.95, 1.55, 1.15), Vector3(-1.15, 0.62, -1.25)],
	# From the north-west corner towards hearth, wall bench and door.
	"back": [Vector3(-2.05, 1.58, -1.55), Vector3(1.25, 0.55, 1.05)],
}
const ATRIUM_VIEWS := {
	"entry": [Vector3(1.0, 1.65, 3.0), Vector3(-2.2, 0.7, -2.4)],
	"back": [Vector3(-3.8, 1.7, -3.9), Vector3(3.0, 0.7, 1.5)],
}
# Open sites, in village coordinates (identical in every source tree).
const SITE_VIEWS := {
	"VillageForge": {"entry": [Vector3(30.9, 1.62, -24.3), Vector3(34.7, 0.85, -26.9)], "back": [Vector3(33.55, 1.62, -23.2), Vector3(34.85, 0.80, -28.6)]},
	"ValdoraMarket": {"entry": [Vector3(25.0, 1.65, 29.2), Vector3(25.0, 0.85, 24.0)], "back": [Vector3(20.6, 1.9, 21.6), Vector3(25.6, 0.7, 24.4)]},
	"EasternClothMarket": {"entry": [Vector3(30.4, 1.65, 19.6), Vector3(34.0, 0.9, 18.0)], "back": [Vector3(36.2, 1.9, 14.6), Vector3(34.0, 0.8, 18.2)]},
}
var output := ""
var label := ""
var profiles: Array = ["balanced", "very_high"]
var houses: Array = []
var views: Array = ["entry", "back"]
var report := {}
var errors: Array[String] = []
var region: Node3D
var scenery: Node3D
var sun: DirectionalLight3D
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
	if args.size() > 4 and args[4] != "":
		views = Array(args[4].split(","))
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	scenery = Scenery.new()
	scenery.name = "VillageScenery"
	stage.add_child(scenery)
	scenery.create_land()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.sky_material = scenery.sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.69, 0.77, 0.85)
	environment.ambient_light_energy = 0.58
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_sky_affect = 0.06
	environment.fog_sun_scatter = 0.04
	environment.fog_density = 0.0015
	environment.fog_light_color = Color(0.63, 0.69, 0.66)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.light_energy = 0.46
	sun.shadow_enabled = true
	stage.add_child(sun)
	scenery.apply_season(0, sun, environment)
	scenery.set_presentation_time(4.0)
	region = Regional.new()
	stage.add_child(region)
	var started := Time.get_ticks_usec()
	region.show_origin("italia")
	var build_ms := (Time.get_ticks_usec() - started) / 1000.0
	for i in 3:
		await RenderingServer.frame_post_draw
	camera = Camera3D.new()
	camera.near = 0.08
	stage.add_child(camera)
	camera.make_current()
	var output_size := root.size
	var portrait := output_size.y > output_size.x
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.fov = 72.0 if portrait else 60.0
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "label": label, "output_pixels": [output_size.x, output_size.y],
		"stage": "regional_village + scenery + game atmosphere (season 0)", "region_build_ms": build_ms, "houses": {},
		"buffer_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"texture_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		# D-038 provenance: source state, loaded models/textures, light setup.
		"source_commit": OS.get_environment("IMPERATHEN_SOURCE_COMMIT"), "source_dirty_files": OS.get_environment("IMPERATHEN_SOURCE_DIRTY"),
		"driver": RenderingServer.get_current_rendering_driver_name(), "assets_sha256": _asset_hashes(),
		"lighting": {"sun_rotation_deg": str(sun.rotation_degrees), "sun_energy": sun.light_energy, "sun_color": sun.light_color.to_html(false),
			"ambient": environment.ambient_light_color.to_html(false), "ambient_energy": environment.ambient_light_energy,
			"tonemap": "linear", "season": 0, "presentation_time": 4.0}}
	for profile: String in profiles:
		_apply(profile)
		for id: String in houses:
			var house := region.get_node_or_null(id) as Node3D
			if house == null and not SITE_VIEWS.has(id):
				errors.append("Missing house " + id)
				continue
			var table: Dictionary = SITE_VIEWS[id] if SITE_VIEWS.has(id) else (ATRIUM_VIEWS if id == "AtriumHouse" else VIEWS)
			var floor_height := 0.0 if SITE_VIEWS.has(id) else (0.065 if id == "AtriumHouse" else Layout.HOUSE_FLOOR)
			for view: String in views:
				var eye: Vector3 = table[view][0] + Vector3.UP * floor_height
				var target: Vector3 = table[view][1] + Vector3.UP * floor_height
				camera.global_position = region.to_global(eye) if SITE_VIEWS.has(id) else house.to_global(eye)
				camera.look_at(region.to_global(target) if SITE_VIEWS.has(id) else house.to_global(target), Vector3.UP)
				# No temporal effects to settle: one frame applies the camera and
				# light selection, two measured frames follow.
				await RenderingServer.frame_post_draw
				var stats := await _measure()
				report.houses["%s/%s/%s" % [id, view, profile]] = stats
				_capture("%s_%s_%s_%s_%dx%d" % [label, id, view, profile, output_size.x, output_size.y])
	report.errors = errors
	var file := FileAccess.open(output.path_join("%s_%dx%d.json" % [label, output_size.x, output_size.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("INTERIOR_STAGE ", label, " ", JSON.stringify(errors))
	stage.free()
	quit(0 if errors.is_empty() else 1)


func _asset_hashes() -> Dictionary:
	var hashes := {}
	var files := ["res://assets/architecture/frontier_house.glb", "res://assets/architecture/atrium_house.glb",
		"res://assets/interiors/interior_kit.glb", "res://assets/interiors/kit_manifest.json"]
	var folder := DirAccess.open("res://assets/interiors/textures")
	if folder:
		for name: String in folder.get_files():
			if name.ends_with(".png"):
				files.append("res://assets/interiors/textures/" + name)
	for path: String in files:
		if FileAccess.file_exists(path):
			hashes[path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return hashes


func _apply(profile: String) -> void:
	var settings: Dictionary = PROFILE_DATA.data.profiles[profile]
	root.mesh_lod_threshold = float(settings.mesh_lod_threshold)
	root.msaa_3d = Viewport.MSAA_4X if int(settings.msaa_samples) == 4 else (Viewport.MSAA_2X if int(settings.msaa_samples) == 2 else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(int(settings.shadow_atlas_size), true)
	sun.directional_shadow_max_distance = float(settings.shadow_distance_metres)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if profile == "low" else \
		(DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if profile == "balanced" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	var budget: float = settings.max_3d_pixels if profile != "very_high" else settings.get("desktop_max_3d_pixels", settings.max_3d_pixels)
	root.scaling_3d_scale = clampf(sqrt(budget / maxf(float(root.size.x * root.size.y), 1.0)), 0.25, 1.0)
	scenery.set_quality(profile)
	region.set_quality(profile)


func _measure() -> Dictionary:
	var calls := []
	var primitives := []
	var frame_ms := []
	var previous := Time.get_ticks_usec()
	for i in 2:
		await RenderingServer.frame_post_draw
		frame_ms.append((Time.get_ticks_usec() - previous) / 1000.0)
		previous = Time.get_ticks_usec()
		calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	calls.sort()
	primitives.sort()
	var lights := 0
	for light: Light3D in region.find_children("*", "Light3D", true, false):
		lights += 1 if light.is_visible_in_tree() else 0
	frame_ms.sort()
	# Frame time on a shared CPU rasteriser: relative only, not a device figure.
	return {"draw_calls": calls[1], "primitives": primitives[1], "interior_lights_visible": lights, "scale_3d": root.scaling_3d_scale,
		"llvmpipe_frame_ms_max": frame_ms[1], "msaa": root.msaa_3d}


func _capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_jpg(output.path_join(name + ".jpg"), .9) != OK:
		errors.append("Empty viewport capture: " + name)
