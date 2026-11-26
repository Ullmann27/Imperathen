extends SceneTree
## Which rendering features change pixels, and at what relative cost, in the
## renderer that runs this script? Each feature is switched on alone on top of
## the Ausgewogen game state of a fixed Valdora view (day lane or the harness
## night with torches), captured, measured and switched back. A repeated base
## capture at the end gives the noise floor (wind, clouds, temporal effects).
## tools/render/compare_renderers.py turns the PNGs into pixel differences.
## Run once per renderer (see tests/render_comparison.gd for the switches).
## Usage: --script res://tests/render_feature_probe.gd ++ <out_dir> <label> [measure frames] [feature ids csv]

const Bench = preload("res://scripts/rendering/render_bench.gd")
const RenderProfile = preload("res://scripts/rendering/render_profile.gd")
const BASE_PROFILE := "balanced"

var output: String
var label := "probe"
var frames := 4
var only: Array = []
var game: Node
var world: Node3D
var start: Dictionary
var report := {}
var errors: Array[String] = []
var _added: Array[Node] = []
var _saved_attributes: CameraAttributes


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.size() < 2 or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory, output path and label are required.")
		quit(2)
		return
	output = args[0]
	label = args[1]
	if args.size() > 2:
		frames = clampi(args[2].to_int(), 2, 60)
	if args.size() > 3 and not args[3].is_empty():
		only = Array(args[3].split(",", false))
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _env() -> Environment:
	return RenderProfile.active_environment(root)


func _sun() -> DirectionalLight3D:
	return world._sun


func _torches() -> Array:
	var lights := []
	if world.has_node(Bench.TORCH_NODE):
		lights = world.get_node(Bench.TORCH_NODE).find_children("*", "OmniLight3D", true, false)
	return lights


## Property feature: sets `values` on the object returned by `target`, restores afterwards.
func _prop(id: String, view: String, target: Callable, values: Dictionary, settle := 3, doc := "") -> Dictionary:
	var saved := {}
	var apply := func() -> void:
		var object: Object = target.call()
		for key: String in values:
			saved[key] = object.get(key)
			object.set(key, values[key])
	var revert := func() -> void:
		var object: Object = target.call()
		for key: String in saved:
			object.set(key, saved[key])
	return {"id": id, "view": view, "settle": settle, "apply": apply, "revert": revert, "doc": doc}


func _call(id: String, view: String, apply: Callable, revert: Callable, settle := 3, doc := "") -> Dictionary:
	return {"id": id, "view": view, "settle": settle, "apply": apply, "revert": revert, "doc": doc}


func _features() -> Array:
	var balanced := RenderProfile.render(BASE_PROFILE)
	var base_filter: int = RenderProfile.FILTERS[balanced.directional_shadow_filter]
	var base_positional_filter: int = RenderProfile.FILTERS[balanced.positional_shadow_filter]
	var base_atlas := int(RenderProfile.settings(BASE_PROFILE).shadow_atlas_size)
	var env := _env
	var vp := func() -> Object: return root
	var sun := _sun
	var lane := "village_lane"
	var night := "night_torch"
	var list := [
		# Screen-space and global illumination
		_prop("ssao", lane, env, {"ssao_enabled": true}, 3, "ssao"),
		_prop("ssil", lane, env, {"ssil_enabled": true}, 4, "ssil"),
		_prop("sdfgi", lane, env, {"sdfgi_enabled": true, "sdfgi_use_occlusion": true}, 24, "sdfgi"),
		_call("voxel_gi", lane, _add_voxel_gi, _remove_added, 4, "voxel_gi"),
		_prop("ssr", lane, env, {"ssr_enabled": true}, 4, "ssr"),
		_call("reflection_probe", lane, _add_reflection_probe, _remove_added, 4),
		# Atmosphere and post-processing
		_prop("volumetric_fog", lane, env, {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.01}, 16, "volumetric_fog"),
		_prop("fog_sun_scatter", lane, env, {"fog_sun_scatter": 0.6}),
		_prop("fog_aerial_perspective", lane, env, {"fog_aerial_perspective": 1.0}),
		_prop("fog_height", lane, env, {"fog_height": 0.5, "fog_height_density": 0.4}),
		_prop("glow", lane, env, {"glow_enabled": true, "glow_intensity": 0.8, "glow_hdr_threshold": 0.9}, 3, "glow"),
		_prop("adjustments", lane, env, {"adjustment_enabled": true, "adjustment_contrast": 1.15, "adjustment_saturation": 1.2}),
		_prop("tonemap_reinhard", lane, env, {"tonemap_mode": Environment.TONE_MAPPER_REINHARDT}),
		_prop("tonemap_filmic", lane, env, {"tonemap_mode": Environment.TONE_MAPPER_FILMIC}),
		_prop("tonemap_aces", lane, env, {"tonemap_mode": Environment.TONE_MAPPER_ACES}),
		_prop("tonemap_agx", lane, env, {"tonemap_mode": Environment.TONE_MAPPER_AGX}),
		_call("depth_of_field", lane, _add_dof, _remove_attributes, 3, "depth_of_field"),
		_call("auto_exposure", lane, _add_auto_exposure, _remove_attributes, 16, "auto_exposure"),
		# Anti-aliasing and scaling (Ausgewogen base: MSAA 2x, native scale)
		_prop("msaa_off", lane, vp, {"msaa_3d": Viewport.MSAA_DISABLED}, 3, "msaa_3d"),
		_prop("msaa_4x", lane, vp, {"msaa_3d": Viewport.MSAA_4X}, 3, "msaa_3d"),
		_prop("msaa_8x", lane, vp, {"msaa_3d": Viewport.MSAA_8X}, 3, "msaa_3d"),
		_prop("fxaa", lane, vp, {"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA}, 3, "screen_space_aa"),
		_prop("smaa", lane, vp, {"screen_space_aa": Viewport.SCREEN_SPACE_AA_SMAA}, 3, "screen_space_aa"),
		_prop("taa", lane, vp, {"use_taa": true}, 8, "taa"),
		_prop("bilinear_67", lane, vp, {"scaling_3d_mode": Viewport.SCALING_3D_MODE_BILINEAR, "scaling_3d_scale": 0.67}),
		_prop("fsr1_67", lane, vp, {"scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR, "scaling_3d_scale": 0.67}, 3, "fsr"),
		_prop("fsr2_67", lane, vp, {"scaling_3d_mode": Viewport.SCALING_3D_MODE_FSR2, "scaling_3d_scale": 0.67}, 8, "fsr"),
		_prop("debanding", lane, vp, {"use_debanding": true}, 3, "debanding"),
		# Geometry and texture detail
		_prop("mesh_lod_off", lane, vp, {"mesh_lod_threshold": 0.0}),
		_prop("mesh_lod_coarse", lane, vp, {"mesh_lod_threshold": 8.0}),
		_prop("mip_bias_minus1", lane, vp, {"texture_mipmap_bias": -1.0}, 3, "texture_mipmap_bias"),
		_prop("anisotropic_off", lane, vp, {"anisotropic_filtering_level": Viewport.ANISOTROPY_DISABLED}),
		_prop("anisotropic_16x", lane, vp, {"anisotropic_filtering_level": Viewport.ANISOTROPY_16X}),
		_call("decal", lane, _add_decal, _remove_added, 3, "decals"),
		# Directional shadows (Ausgewogen base: 2048 atlas, soft_low, 2 splits)
		_call("shadow_filter_hard", lane, func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD),
			func(): RenderingServer.directional_soft_shadow_filter_set_quality(base_filter)),
		_call("shadow_filter_soft_high", lane, func(): RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH),
			func(): RenderingServer.directional_soft_shadow_filter_set_quality(base_filter)),
		_call("shadow_atlas_1024", lane, func(): RenderingServer.directional_shadow_atlas_set_size(1024, true),
			func(): RenderingServer.directional_shadow_atlas_set_size(base_atlas, true)),
		_call("shadow_atlas_8192", lane, func(): RenderingServer.directional_shadow_atlas_set_size(8192, true),
			func(): RenderingServer.directional_shadow_atlas_set_size(base_atlas, true)),
		_prop("shadow_4_splits", lane, sun, {"directional_shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "directional_shadow_blend_splits": true}),
		_prop("shadow_distance_110", lane, sun, {"directional_shadow_max_distance": 110.0}),
		_prop("directional_pcss", lane, sun, {"light_angular_distance": 1.5}, 3, "directional_pcss"),
		# Night: torches (OmniLight3D) with the Ausgewogen positional shadow atlas
		_prop("positional_shadows_off", night, vp, {"positional_shadow_atlas_size": 0}),
		_prop("positional_atlas_8192", night, vp, {"positional_shadow_atlas_size": 8192}),
		_call("positional_filter_soft_high", night, func(): RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH),
			func(): RenderingServer.positional_soft_shadow_filter_set_quality(base_positional_filter)),
		_call("positional_pcss", night, func(): _set_torches("light_size", 0.25), func(): _set_torches("light_size", 0.0), 3, "positional_pcss"),
		_call("light_budget_low", night, func(): _torch_profile("low"), func(): _torch_profile(BASE_PROFILE)),
		_call("light_budget_very_high", night, func(): _torch_profile("very_high"), func(): _torch_profile(BASE_PROFILE)),
		_call("light_projector", night, _add_projector, _remove_added, 3, "light_projectors"),
		_prop("volumetric_fog_night", night, env, {"volumetric_fog_enabled": true, "volumetric_fog_density": 0.02}, 16, "volumetric_fog"),
		_prop("glow_night", night, env, {"glow_enabled": true, "glow_intensity": 0.8, "glow_hdr_threshold": 0.9}, 3, "glow"),
		_prop("ssao_night", night, env, {"ssao_enabled": true}, 3, "ssao"),
	]
	if only.is_empty():
		return list
	return list.filter(func(feature: Dictionary) -> bool: return feature.id in only)


func _run() -> void:
	game = await Bench.boot_village(root, errors)
	world = game.world
	start = Bench.village_start(world)
	game.ui.set_quality(BASE_PROFILE)
	world.set_presentation_time(4.0)
	Engine.time_scale = 0
	report = {"harness": "tests/render_feature_probe.gd", "label": label, "base_profile": BASE_PROFILE,
		"source_commit": OS.get_environment("IMPERATHEN_SOURCE_COMMIT"),
		"renderer": Bench.renderer_info(), "output_pixels": [root.size.x, root.size.y], "measure_frames": frames,
		"note": "Software renderer on a shared, loaded cloud machine: pixel changes are valid, costs are relative indicators only, never mobile-GPU or Fold7 performance.",
		"views": {}, "features": []}
	var features := _features()
	for view: String in ["village_lane", "night_torch"]:
		var in_view := features.filter(func(feature: Dictionary) -> bool: return feature.view == view)
		if in_view.is_empty():
			continue
		Bench.stage_village(world, view, start)
		report.views[view] = {"base": await _shot("base-" + view, 6), "engine": Bench.engine_state(root, world)}
		for feature: Dictionary in in_view:
			var started := Time.get_ticks_msec()
			feature.apply.call()
			var setup_ms := Time.get_ticks_msec() - started
			var stats: Dictionary = await _shot(feature.id, int(feature.settle))
			stats.setup_ms = setup_ms
			feature.revert.call()
			report.features.append({"id": feature.id, "view": view, "settle_frames": feature.settle,
				"documented_feature": feature.doc,
				"documented_support": RenderProfile.supports(feature.doc) if not str(feature.doc).is_empty() else null,
				"stats": stats})
			for i in 2:
				await RenderingServer.frame_post_draw
		report.views[view].base_repeat = await _shot("base_repeat-" + view, 3)
		Bench.restore_village(world, start)
	report.errors = errors
	var file := FileAccess.open(output.path_join(label + "-features.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("RENDER_FEATURE_PROBE ", JSON.stringify({"label": label, "renderer": report.renderer.method, "features": report.features.size(), "errors": errors}))
	Engine.time_scale = 1
	game.free()
	quit(0 if errors.is_empty() else 1)


func _shot(name: String, settle: int) -> Dictionary:
	for i in settle:
		await RenderingServer.frame_post_draw
	var stats: Dictionary = await Bench.measure(root, frames)
	var image := root.get_texture().get_image()
	var file := "%s-%s.png" % [label, name]
	if image == null or image.is_empty() or image.save_png(output.path_join(file)) != OK:
		errors.append("Empty capture " + name)
	stats.image = file
	return stats


func _set_torches(key: String, value: Variant) -> void:
	for light: Light3D in _torches():
		light.set(key, value)


func _torch_profile(profile: String) -> void:
	for light: Light3D in _torches():
		RenderProfile.configure_light(light, profile)


func _camera() -> Camera3D:
	return world._camera


func _ahead(distance: float) -> Vector3:
	var camera := _camera()
	var forward := -camera.global_basis.z
	forward.y = 0.0
	var at := camera.global_position + forward.normalized() * distance
	at.y = Bench.floor_height(world, at + Vector3.UP * 3.0)
	return at


func _keep(node: Node) -> void:
	world.add_child(node)
	_added.append(node)


func _remove_added() -> void:
	for node in _added:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_added.clear()


func _add_voxel_gi() -> void:
	var gi := VoxelGI.new()
	gi.size = Vector3(48, 16, 48)
	gi.subdiv = VoxelGI.SUBDIV_128
	_keep(gi)
	gi.global_position = _ahead(14.0) + Vector3.UP * 6.0
	gi.bake(world, false)


func _add_reflection_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.size = Vector3(40, 18, 40)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = false
	_keep(probe)
	probe.global_position = _ahead(10.0) + Vector3.UP * 4.0


func _add_decal() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			image.set_pixel(x, y, Color(0.18, 0.11, 0.06, clampf(1.0 - d, 0.0, 1.0)))
	var decal := Decal.new()
	decal.size = Vector3(3.0, 1.0, 3.0)
	decal.texture_albedo = ImageTexture.create_from_image(image)
	_keep(decal)
	decal.global_position = _ahead(5.0)


func _add_projector() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			image.set_pixel(x, y, Color.WHITE if (x / 8 + y / 8) % 2 == 0 else Color(0.2, 0.2, 0.2))
	var spot := SpotLight3D.new()
	spot.light_projector = ImageTexture.create_from_image(image)
	spot.light_energy = 3.0
	spot.spot_range = 12.0
	spot.spot_angle = 30.0
	_keep(spot)
	spot.global_position = _ahead(6.0) + Vector3.UP * 4.0
	spot.look_at(_ahead(6.0), Vector3.FORWARD)


func _add_dof() -> void:
	_saved_attributes = _camera().attributes
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 12.0
	attributes.dof_blur_far_transition = 6.0
	attributes.dof_blur_amount = 0.12
	_camera().attributes = attributes


func _add_auto_exposure() -> void:
	_saved_attributes = _camera().attributes
	var attributes := CameraAttributesPractical.new()
	attributes.auto_exposure_enabled = true
	attributes.auto_exposure_speed = 4.0
	_camera().attributes = attributes


func _remove_attributes() -> void:
	_camera().attributes = _saved_attributes
