extends SceneTree
## Engine-level graphics profile regression (D-034): the four profiles differ
## in shadows, lights, geometry detail, texture filtering, post-processing and
## density hooks; Ausgewogen keeps today's defaults; switches really reach the
## viewport, the positional light budget and the active Environment, in a
## renderer-aware way. Data and engine state only, no performance claim.

const RenderProfile = preload("res://scripts/rendering/render_profile.gd")
const ORDER := ["low", "balanced", "high", "very_high"]
const FILTER_RANK := {"hard": 0, "soft_very_low": 1, "soft_low": 2, "soft_medium": 3, "soft_high": 4, "soft_ultra": 5}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Render profile regression needs an isolated test account")
		quit(2)
		return
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _value(profile: String, path: String) -> Variant:
	var node: Variant = RenderProfile.settings(profile)
	for part in path.split("/"):
		node = node.get(part) if typeof(node) == TYPE_DICTIONARY else null
	return node


func _run() -> void:
	var profiles := RenderProfile.profiles()
	_check(profiles.keys() == ORDER, "Exactly the four profiles in order")
	_check([profiles.low.label, profiles.balanced.label, profiles.high.label, profiles.very_high.label]
		== ["Leicht", "Ausgewogen", "Hoch", "Sehr hoch"], "German profile labels")
	# Monotonic quality ladders per D-034 dimension.
	var rising := ["shadow_atlas_size", "render/positional_shadow_atlas", "shadow_distance_metres", "max_3d_pixels",
		"render/light_fade_begin", "render/light_shadow_fade", "render/anisotropic_samples", "density/vegetation",
		"density/crowd", "density/props_range"]
	for key in rising:
		for i in 3:
			_check(float(_value(ORDER[i], key)) < float(_value(ORDER[i + 1], key)),
				"%s rises from %s to %s" % [key, ORDER[i], ORDER[i + 1]])
	for i in 3:
		_check(float(_value(ORDER[i], "mesh_lod_threshold")) > float(_value(ORDER[i + 1], "mesh_lod_threshold")),
			"Geometry LOD keeps more detail from %s to %s" % [ORDER[i], ORDER[i + 1]])
		_check(FILTER_RANK[_value(ORDER[i], "render/directional_shadow_filter")] < FILTER_RANK[_value(ORDER[i + 1], "render/directional_shadow_filter")],
			"Sun shadow filter improves from %s to %s" % [ORDER[i], ORDER[i + 1]])
		_check(FILTER_RANK[_value(ORDER[i], "render/positional_shadow_filter")] < FILTER_RANK[_value(ORDER[i + 1], "render/positional_shadow_filter")],
			"Torch shadow filter improves from %s to %s" % [ORDER[i], ORDER[i + 1]])
		_check(int(_value(ORDER[i], "msaa_samples")) <= int(_value(ORDER[i + 1], "msaa_samples")), "MSAA never drops with a higher profile")
	# Every neighbouring pair differs in many engine dimensions, not one label.
	var dimensions := ["shadow_atlas_size", "shadow_distance_metres", "mesh_lod_threshold", "max_3d_pixels", "msaa_samples",
		"decoration_fraction", "glow", "render/directional_shadow_filter", "render/positional_shadow_atlas",
		"render/positional_shadow_filter", "render/light_fade_begin", "render/anisotropic_samples",
		"render/ssao/enabled", "render/ssao/quality", "density/vegetation", "density/crowd", "density/props_range"]
	for i in 3:
		var differing := dimensions.filter(func(key: String) -> bool: return _value(ORDER[i], key) != _value(ORDER[i + 1], key))
		_check(differing.size() >= 9, "%s and %s differ in %d engine dimensions" % [ORDER[i], ORDER[i + 1], differing.size()])
	# Ausgewogen (Fold7 sustained profile) keeps the defaults it had before the
	# render study: nothing in it may get worse.
	var balanced := RenderProfile.settings("balanced")
	_check(int(balanced.shadow_atlas_size) == 2048 and int(balanced.msaa_samples) == 2 and is_equal_approx(float(balanced.mesh_lod_threshold), 1.5)
		and is_equal_approx(float(balanced.decoration_fraction), 0.6) and int(balanced.shadow_distance_metres) == 48
		and not bool(balanced.glow) and int(balanced.max_3d_pixels) == 2073600, "Ausgewogen keeps its previous defaults")
	_check(balanced.render.directional_shadow_filter == "soft_low" and int(balanced.render.anisotropic_samples) == 4,
		"Ausgewogen keeps the engine default sun filter and 4x anisotropy")
	_check(is_equal_approx(float(balanced.density.vegetation), float(balanced.decoration_fraction)),
		"Vegetation density hook matches the existing decoration fraction")
	# Switches reach the root viewport.
	for profile: String in ORDER:
		var applied := RenderProfile.apply_viewport(root, profile)
		var r := RenderProfile.render(profile)
		_check(root.positional_shadow_atlas_size == int(r.positional_shadow_atlas), profile + " sets the torch shadow atlas")
		_check(is_equal_approx(root.mesh_lod_threshold, float(RenderProfile.settings(profile).mesh_lod_threshold)), profile + " sets mesh LOD")
		_check(root.anisotropic_filtering_level == {2: Viewport.ANISOTROPY_2X, 4: Viewport.ANISOTROPY_4X, 8: Viewport.ANISOTROPY_8X, 16: Viewport.ANISOTROPY_16X}[int(r.anisotropic_samples)],
			profile + " sets anisotropy")
		for q in 4:
			_check(int(root.get_positional_shadow_atlas_quadrant_subdiv(q)) == int(r.positional_shadow_quadrants[q]), "%s quadrant %d" % [profile, q])
		_check(applied.profile == profile and RenderProfile.current_profile() == profile, profile + " is reported as applied")
	_check(RenderProfile._slots([2, 2, 0, 0]) == 8 and RenderProfile._slots([2, 2, 3, 4]) == 88, "Shadow slot count follows the quadrant subdivision")
	# Positional light budget.
	var torch := OmniLight3D.new()
	RenderProfile.configure_light(torch, "low")
	_check(not torch.shadow_enabled and torch.distance_fade_enabled and is_equal_approx(torch.distance_fade_begin, 18.0), "Leicht torches fade early and cast no shadow")
	RenderProfile.configure_light(torch, "very_high")
	_check(torch.shadow_enabled and is_equal_approx(torch.distance_fade_begin, 70.0) and is_equal_approx(torch.distance_fade_shadow, 45.0), "Sehr hoch torches reach far with shadows")
	torch.set_meta("no_shadow", true)
	RenderProfile.configure_light(torch, "very_high")
	_check(not torch.shadow_enabled, "A light can refuse shadows")
	torch.free()
	# Ambient occlusion is renderer-aware and never removes a scene's own AO.
	var environment := Environment.new()
	_check(RenderProfile.apply_environment(environment, "high", "gl_compatibility") and environment.ssao_enabled, "Hoch enables AO in Compatibility")
	_check(not RenderProfile.apply_environment(environment, "balanced", "gl_compatibility") and not environment.ssao_enabled, "Ausgewogen switches profile AO off again")
	_check(not RenderProfile.apply_environment(environment, "very_high", "mobile") and not environment.ssao_enabled, "Mobile renderer never gets AO it cannot draw")
	var authored := Environment.new()
	authored.ssao_enabled = true
	RenderProfile.apply_environment(authored, "balanced", "gl_compatibility")
	_check(authored.ssao_enabled, "A scene's own AO survives a profile without AO")
	authored.set_meta(RenderProfile.AO_LOOK_META, {"intensity": 0.7, "radius": 1.4})
	RenderProfile.apply_environment(authored, "very_high", "forward_plus")
	_check(is_equal_approx(authored.ssao_intensity, 0.7) and is_equal_approx(authored.ssao_radius, 1.4), "Scene AO look parameters are respected")
	var lab := Environment.new()
	lab.set_meta(RenderProfile.UNMANAGED_META, true)
	_check(not RenderProfile.apply_environment(lab, "very_high", "forward_plus") and not lab.ssao_enabled, "Unmanaged environments are left alone")
	_check(RenderProfile.supports("sdfgi", "forward_plus") and not RenderProfile.supports("sdfgi", "mobile") and not RenderProfile.supports("sdfgi", "gl_compatibility"),
		"SDFGI is Forward+ only")
	_check(RenderProfile.supports("ssao", "gl_compatibility") and not RenderProfile.supports("ssao", "mobile"), "AO: Compatibility and Forward+, not Mobile")
	_check(is_equal_approx(RenderProfile.density("very_high", "vegetation"), 1.4) and is_equal_approx(RenderProfile.density("nope", "crowd"), 0.67),
		"Density hook reads the profile and falls back to Ausgewogen")
	# The global RuntimeDisplay applies the same switches and configures lights added later.
	var display := root.get_node_or_null("RuntimeDisplay")
	_check(is_instance_valid(display), "RuntimeDisplay autoload is present")
	if is_instance_valid(display):
		display.apply_quality("very_high")
		var report: Dictionary = display.quality_report()
		_check(int(report.engine_switches.positional_shadow_atlas) == 8192 and int(report.engine_switches.directional_shadow_atlas) == 8192,
			"Sehr hoch report shows its shadow atlases")
		var late := OmniLight3D.new()
		late.add_to_group(RenderProfile.LIGHT_GROUP)
		root.add_child(late)
		_check(late.shadow_enabled and is_equal_approx(late.distance_fade_begin, 70.0), "A torch spawned later receives the active budget")
		display.apply_quality("low")
		_check(not late.shadow_enabled and is_equal_approx(late.distance_fade_begin, 18.0), "Changing the profile updates existing torches")
		late.free()
		display.apply_quality("balanced")
		_check(root.positional_shadow_atlas_size == 2048, "Back to Ausgewogen")
	if failures.is_empty():
		print("RENDER_PROFILE_PASS checks=%d; engine switches and data only, not a performance claim" % checks)
	else:
		print("RENDER_PROFILE_FAIL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
