extends SceneTree
## Renderer comparison harness (D-033): identical scenes and cameras for
## Compatibility, Mobile and Forward+. Run once per renderer, e.g.
##   --rendering-method gl_compatibility --rendering-driver opengl3
##   --rendering-method mobile           --rendering-driver vulkan
##   --rendering-method forward_plus     --rendering-driver vulkan
## Scenes: "village" goes through the real game path (main.tscn -> new life ->
## Valdora) and frames scripts/rendering/render_bench.gd VILLAGE_VIEWS;
## "city" builds scripts/world/city_exploration.gd once per profile.
## Variants: "base" renders exactly what the game sets for the profile;
## "fx" additionally enables every advanced feature the running renderer
## supports (AO, SSIL, SDFGI, volumetric fog, SSR, glow) with engine default
## parameters, as a capability showcase, never as a look proposal.
## Writes <label>-<view>-<profile>-<variant>.png and <label>-report.json.
## Frame times belong to the renderer/driver that ran this script; software
## renderers (llvmpipe/lavapipe) give relative indicators only.
## Usage: --script res://tests/render_comparison.gd ++ <out_dir> <village|city> <label>
##        [profiles csv] [variants csv] [measure frames] [fx profiles csv] [views csv]

const Bench = preload("res://scripts/rendering/render_bench.gd")
const RenderProfile = preload("res://scripts/rendering/render_profile.gd")
const City = preload("res://scripts/world/city_exploration.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Architecture = preload("res://scripts/rendering/city_architecture_detail.gd")
const SETTLE_FRAMES := 5
const FX_SETTLE_FRAMES := 18
const ULTRA_SETTLE_FRAMES := 24
## D-050 Ultra prototype, applied on top of the Sehr-hoch/Ultra profile: per
## renderer everything that measurably adds image quality there (feature probe
## in docs/39_rendering). Engine-level parameters chosen for the prototype; the
## look (exposure, tonemapper, grade, sun, sky, fog colour) is untouched.
## A physically plausible sun disc (0.53 degrees) drives contact-hardening
## shadows where PCSS exists.
const ULTRA := {
	"forward_plus": {
		"env": {"ssao_enabled": true, "ssao_radius": 1.2, "ssao_intensity": 1.4, "ssil_enabled": true,
			"sdfgi_enabled": true, "sdfgi_use_occlusion": true, "sdfgi_cascades": 4, "sdfgi_min_cell_size": 0.15,
			"sdfgi_bounce_feedback": 0.5, "volumetric_fog_enabled": true, "volumetric_fog_density": 0.006,
			"volumetric_fog_length": 96.0, "volumetric_fog_gi_inject": 1.0, "glow_enabled": true},
		"viewport": {"use_taa": true}, "sun": {"light_angular_distance": 0.53}, "torch": {"light_size": 0.08},
		"filter": "soft_ultra", "voxel_gi_interior": true},
	"mobile": {
		"env": {"glow_enabled": true},
		"viewport": {"screen_space_aa": Viewport.SCREEN_SPACE_AA_SMAA}, "sun": {}, "torch": {"light_size": 0.08},
		"filter": "soft_ultra", "voxel_gi_interior": false},
	"gl_compatibility": {
		"env": {"ssao_enabled": true, "ssao_radius": 1.2, "ssao_intensity": 1.4, "glow_enabled": true},
		"viewport": {}, "sun": {}, "torch": {}, "filter": "soft_ultra", "voxel_gi_interior": false},
}

var output: String
var scene_kind := "village"
var label := "cmp"
var profiles: Array = ["low", "balanced", "high", "very_high"]
var variants: Array = ["base"]
var fx_profiles: Array = ["balanced"]
var views: Array = []
var frames := 5
var report := {}
var errors: Array[String] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.size() < 3 or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory, output path, scene and label are required.")
		quit(2)
		return
	output = args[0]
	scene_kind = args[1]
	label = args[2]
	if args.size() > 3 and not args[3].is_empty():
		profiles = Array(args[3].split(",", false))
	if args.size() > 4 and not args[4].is_empty():
		variants = Array(args[4].split(",", false))
	if args.size() > 5:
		frames = clampi(args[5].to_int(), 2, 120)
	if args.size() > 6 and not args[6].is_empty():
		fx_profiles = Array(args[6].split(",", false))
	if args.size() > 7 and not args[7].is_empty():
		views = Array(args[7].split(",", false))
	if scene_kind not in ["village", "city"]:
		printerr("Unknown scene " + scene_kind)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _header() -> void:
	report = {"harness": "tests/render_comparison.gd", "scene": scene_kind, "label": label,
		"source_commit": OS.get_environment("IMPERATHEN_SOURCE_COMMIT"),
		"renderer": Bench.renderer_info(), "output_pixels": [root.size.x, root.size.y],
		"measure_frames": frames, "profiles": profiles, "variants": variants, "fx_profiles": fx_profiles,
		"note": "Software renderer images and timings on a shared, loaded 4-core cloud machine: visual and relative indicators only, never mobile-GPU or Fold7 performance.",
		"shots": {}}


func _run() -> void:
	_header()
	# Texture package comparison: mount before any scene loads its textures.
	var tier := OS.get_environment("IMPERATHEN_TEXTURE_TIER")
	if not tier.is_empty():
		report.texture_package = RenderProfile.mount_texture_package(tier)
		if not bool(report.texture_package.mounted):
			errors.append("Texture package %s is not installed" % tier)
	else:
		report.texture_package = RenderProfile.texture_package()
	if scene_kind == "village":
		await _run_village()
	else:
		await _run_city()
	report.errors = errors
	var file := FileAccess.open(output.path_join(label + "-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("RENDER_COMPARISON ", JSON.stringify({"label": label, "renderer": report.renderer.method, "errors": errors}))
	Engine.time_scale = 1
	quit(0 if errors.is_empty() else 1)


func _run_village() -> void:
	var game: Node = await Bench.boot_village(root, errors)
	var world = game.world
	var start := Bench.village_start(world)
	var snapshot: String = JSON.stringify(game.model.data)
	report.start_state = {"world_sha256": snapshot.sha256_text(), "player": str(start.player), "camera": str(start.camera)}
	world.set_presentation_time(4.0)
	Engine.time_scale = 0
	var shot_views: Array = views if not views.is_empty() else Bench.VILLAGE_VIEWS
	for profile: String in profiles:
		game.ui.set_quality(profile)
		for view: String in shot_views:
			if not Bench.stage_village(world, view, start):
				errors.append("Unknown village view " + view)
				continue
			await _shoot(view, profile, world)
			Bench.restore_village(world, start)
		var now: String = JSON.stringify(game.model.data)
		if _without_revision(snapshot) != _without_revision(now):
			errors.append("World state changed in " + profile)
	report.loaded_assets = Bench.loaded_assets(world)
	game.ui.set_quality("balanced")
	game.free()


func _run_city() -> void:
	var display := root.get_node_or_null("RuntimeDisplay")
	var shot_views: Array = views if not views.is_empty() else Bench.CITY_VIEWS
	for profile: String in profiles:
		if display:
			display.apply_quality(profile)
		var city := City.new()
		city.persist = false
		city.profile = profile
		root.add_child(city)
		for i in 9:
			await process_frame
			await physics_frame
		if not city.city_available:
			errors.append("No original full city GLB; city views skipped")
			city.free()
			return
		city.set_physics_process(false)
		city._touch_move = Vector2.ZERO
		city._running = false
		city.camera.current = true
		Engine.time_scale = 0
		for view: String in shot_views:
			if not Bench.stage_city(city, view):
				errors.append("Unknown city view " + view)
				continue
			await _shoot(view, profile, city)
		Engine.time_scale = 1
		if profile == profiles[-1]:
			report.loaded_assets = Bench.loaded_assets(city)
		city.process_mode = Node.PROCESS_MODE_DISABLED
		city.camera.environment = null
		for frame in 2:
			await process_frame
			await RenderingServer.frame_post_draw
		city.queue_free()
		await process_frame
		await process_frame
	Person.scenes.clear()
	Person.materials.clear()
	Architecture._meshes.clear()
	if display:
		display.apply_quality("balanced")
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw


func _shoot(view: String, profile: String, scene: Node) -> void:
	for variant: String in variants:
		if variant == "fx" and profile not in fx_profiles:
			continue
		if variant == "ultra" and profile != "very_high":
			continue
		var restore := {}
		if variant == "fx":
			restore = _apply_fx()
		elif variant == "ultra":
			restore = _apply_ultra(view, scene)
		for i in {"fx": FX_SETTLE_FRAMES, "ultra": ULTRA_SETTLE_FRAMES}.get(variant, SETTLE_FRAMES):
			await RenderingServer.frame_post_draw
		var stats: Dictionary = await Bench.measure(root, frames)
		var name := "%s-%s-%s-%s" % [label, view, profile, variant]
		stats.image = name + ".png"
		stats.engine = Bench.engine_state(root, scene)
		if variant == "fx":
			stats.fx_enabled = restore.get("enabled", [])
		elif variant == "ultra":
			stats.ultra = restore.get("applied", {})
		_capture(name)
		if not report.shots.has(view):
			report.shots[view] = {}
		if not report.shots[view].has(profile):
			report.shots[view][profile] = {}
		report.shots[view][profile][variant] = stats
		if variant == "fx":
			_revert_fx(restore)
		elif variant == "ultra":
			_revert_ultra(restore)


## Every advanced post-process/GI feature the running renderer supports, with
## engine default parameters. Returns the previous values for _revert_fx().
func _apply_fx() -> Dictionary:
	var environment: Environment = RenderProfile.active_environment(root)
	if environment == null:
		return {}
	var keys := []
	var enabled := []
	for feature: String in ["ssao", "ssil", "sdfgi", "ssr", "volumetric_fog", "glow"]:
		if RenderProfile.supports(feature):
			keys.append(feature + "_enabled")
			enabled.append(feature)
	var previous := {}
	for key: String in keys + ["volumetric_fog_density", "sdfgi_use_occlusion"]:
		previous[key] = environment.get(key)
	for key: String in keys:
		environment.set(key, true)
	if RenderProfile.supports("volumetric_fog"):
		environment.volumetric_fog_density = 0.01
	if RenderProfile.supports("sdfgi"):
		environment.sdfgi_use_occlusion = true
	return {"environment": environment, "previous": previous, "enabled": enabled}


func _revert_fx(restore: Dictionary) -> void:
	if restore.is_empty():
		return
	var environment: Environment = restore.environment
	for key: String in restore.previous:
		environment.set(key, restore.previous[key])


func _apply_ultra(view: String, scene: Node) -> Dictionary:
	var preset: Dictionary = ULTRA.get(RenderProfile.renderer(), {})
	var environment: Environment = RenderProfile.active_environment(root)
	var saved := {"env": {}, "viewport": {}, "sun": {}, "torch": [], "added": []}
	if environment != null:
		for key: String in preset.get("env", {}):
			saved.env[key] = environment.get(key)
			environment.set(key, preset.env[key])
	for key: String in preset.get("viewport", {}):
		saved.viewport[key] = root.get(key)
		root.set(key, preset.viewport[key])
	var sun: DirectionalLight3D = null
	for light: DirectionalLight3D in scene.find_children("*", "DirectionalLight3D", true, false):
		if light.is_visible_in_tree():
			sun = light
			break
	if sun != null:
		for key: String in preset.get("sun", {}):
			saved.sun[key] = sun.get(key)
			sun.set(key, preset.sun[key])
	for light: Light3D in scene.find_children("*", "OmniLight3D", true, false):
		if light.is_in_group(RenderProfile.LIGHT_GROUP):
			for key: String in preset.get("torch", {}):
				saved.torch.append([light, key, light.get(key)])
				light.set(key, preset.torch[key])
	var filter: int = RenderProfile.FILTERS.get(str(preset.get("filter", "")), -1)
	if filter >= 0:
		RenderingServer.directional_soft_shadow_filter_set_quality(filter)
		RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	var baked_ms := 0
	if view == "house_interior" and bool(preset.get("voxel_gi_interior", false)):
		# Real-time bounce light in the home from a VoxelGI baked at run time.
		var gi := VoxelGI.new()
		gi.name = "UltraInteriorVoxelGI"
		gi.size = Vector3(12, 7, 12)
		gi.subdiv = VoxelGI.SUBDIV_128
		scene.add_child(gi)
		gi.global_position = root.get_camera_3d().global_position + Vector3(0, 0.5, 0)
		var started := Time.get_ticks_msec()
		gi.bake(scene, false)
		baked_ms = Time.get_ticks_msec() - started
		saved.added.append(gi)
	return {"saved": saved, "environment": environment, "sun": sun, "filter": filter,
		"applied": {"renderer": RenderProfile.renderer(), "env": preset.get("env", {}).keys(), "viewport": preset.get("viewport", {}).keys(),
			"sun": preset.get("sun", {}), "torch": preset.get("torch", {}), "filter": preset.get("filter", ""),
			"voxel_gi_bake_ms": baked_ms if baked_ms > 0 else null}}


func _revert_ultra(restore: Dictionary) -> void:
	var saved: Dictionary = restore.saved
	var environment: Environment = restore.environment
	if environment != null:
		for key: String in saved.env:
			environment.set(key, saved.env[key])
	for key: String in saved.viewport:
		root.set(key, saved.viewport[key])
	if restore.sun != null:
		for key: String in saved.sun:
			(restore.sun as Light3D).set(key, saved.sun[key])
	for entry: Array in saved.torch:
		(entry[0] as Light3D).set(entry[1], entry[2])
	for node: Node in saved.added:
		node.get_parent().remove_child(node)
		node.free()
	# Profile filters back (Ultra profile values).
	RenderProfile.apply_viewport(root, RenderProfile.current_profile())


func _capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(name + ".png")) != OK:
		errors.append("Empty viewport capture: " + name)


## "revision" counts model notifications (e.g. the quality setting), not world content.
func _without_revision(json: String) -> String:
	var data: Dictionary = JSON.parse_string(json)
	data.erase("revision")
	return JSON.stringify(data)
