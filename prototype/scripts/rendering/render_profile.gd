extends RefCounted
## Engine-level switches of the four graphics profiles (D-034), read from the
## "render" block of res://assets/quality_profiles.json and applied in a
## renderer-aware way. Presentation only: no profile changes collision,
## navigation, actors, simulation or saved state.
##
## Ownership: this module owns renderer capabilities, shadow atlases and
## filters, positional light budgets, ambient-occlusion enablement and the
## density/texture hooks. Look values (exposure, tonemapper, grading, sun, sky
## and torch colours) stay with the scenes that own them.

const DATA = preload("res://assets/quality_profiles.json")
const LIGHT_GROUP := "profile_lights"
## Environments can opt out of profile post-processing (e.g. a look lab) with
## env.set_meta(UNMANAGED_META, true).
const UNMANAGED_META := "render_profile_unmanaged"
## A scene may provide its own ambient-occlusion look parameters as a
## Dictionary in this Environment meta; otherwise engine defaults are used.
const AO_LOOK_META := "ssao_look"
const AO_OWNED_META := "ssao_from_profile"
const FILTERS := {"hard": RenderingServer.SHADOW_QUALITY_HARD, "soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
	"soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "soft_medium": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
	"soft_high": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "soft_ultra": RenderingServer.SHADOW_QUALITY_SOFT_ULTRA}
const AO_QUALITY := {"very_low": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "low": RenderingServer.ENV_SSAO_QUALITY_LOW,
	"medium": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "high": RenderingServer.ENV_SSAO_QUALITY_HIGH,
	"ultra": RenderingServer.ENV_SSAO_QUALITY_ULTRA}
## Renderer support in Godot 4.7.2. Source: the engine class reference of the
## 4.7.2-stable tag; every entry is also exercised by tests/render_feature_probe.gd,
## whose measured pixel changes per renderer are in docs/39_rendering.
const SUPPORT := {
	"ssao": ["forward_plus", "gl_compatibility"],
	"ssil": ["forward_plus"],
	"sdfgi": ["forward_plus"],
	"voxel_gi": ["forward_plus"],
	"ssr": ["forward_plus"],
	"volumetric_fog": ["forward_plus"],
	"glow": ["forward_plus", "mobile", "gl_compatibility"],
	"decals": ["forward_plus", "mobile"],
	"light_projectors": ["forward_plus", "mobile"],
	"positional_pcss": ["forward_plus", "mobile"],
	"directional_pcss": ["forward_plus"],
	"msaa_3d": ["forward_plus", "mobile", "gl_compatibility"],
	"screen_space_aa": ["forward_plus", "mobile"],
	"taa": ["forward_plus"],
	"fsr": ["forward_plus"],
	"texture_mipmap_bias": ["forward_plus", "mobile"],
	"depth_of_field": ["forward_plus", "mobile"],
	"auto_exposure": ["forward_plus"],
	"debanding": ["forward_plus", "mobile"],
}

static var _current := "balanced"
static var _applied := {}
static var _texture_package := {"tier": "base", "mounted": false, "path": ""}


static func profiles() -> Dictionary:
	return DATA.data.profiles


static func settings(profile: String) -> Dictionary:
	return profiles().get(profile, profiles().balanced)


static func render(profile: String) -> Dictionary:
	return settings(profile).get("render", {})


static func current_profile() -> String:
	return _current


static func last_applied() -> Dictionary:
	return _applied.duplicate(true)


static func renderer() -> String:
	return RenderingServer.get_current_rendering_method()


static func supports(feature: String, method: String = "") -> bool:
	return (method if not method.is_empty() else renderer()) in SUPPORT.get(feature, [])


## Density hook in [0, n]: fraction of authored instances a system may show
## (vegetation, props, crowds). Values above 1.0 require authored extra content.
static func density(profile: String, key: String, fallback := 1.0) -> float:
	return float(settings(profile).get("density", {}).get(key, fallback))


## Texture package tier named by the profile ("base" = the imported originals).
static func texture_tier(profile: String) -> String:
	return str(render(profile).get("texture_tier", "base"))


## Mounts a separate texture package (tools/render/build_texture_package.py)
## over the imported textures. It must run before the textures are loaded,
## i.e. at start; a tier change therefore applies after the next start.
## A missing package is reported, never faked: the originals stay in use.
static func mount_texture_package(tier: String) -> Dictionary:
	if tier == "base" or tier.is_empty():
		_texture_package = {"tier": "base", "mounted": false, "path": ""}
		return _texture_package
	if _texture_package.get("mounted", false):
		return _texture_package
	var file := "textures_%s.pck" % tier
	for folder in ["res://packages", "user://packages", OS.get_executable_path().get_base_dir().path_join("packages")]:
		var path: String = folder.path_join(file)
		if FileAccess.file_exists(path):
			var mounted := ProjectSettings.load_resource_pack(path, true)
			_texture_package = {"tier": tier, "mounted": mounted, "path": path}
			return _texture_package
	_texture_package = {"tier": tier, "mounted": false, "path": "", "status": "package_not_installed"}
	return _texture_package


static func texture_package() -> Dictionary:
	return _texture_package.duplicate()


## Global and root-viewport switches. Returns what was actually applied.
static func apply_viewport(viewport: Viewport, profile: String) -> Dictionary:
	_current = profile if profiles().has(profile) else "balanced"
	var top := settings(_current)
	var r := render(_current)
	var method := renderer()
	var applied := {"profile": _current, "renderer": method}
	RenderingServer.directional_shadow_atlas_set_size(int(top.shadow_atlas_size), bool(r.get("directional_shadow_16_bits", true)))
	applied.directional_shadow_atlas = int(top.shadow_atlas_size)
	var filter := str(r.get("directional_shadow_filter", "soft_low"))
	RenderingServer.directional_soft_shadow_filter_set_quality(FILTERS.get(filter, RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	applied.directional_shadow_filter = filter
	var positional := int(r.get("positional_shadow_atlas", 2048))
	viewport.positional_shadow_atlas_size = positional
	viewport.positional_shadow_atlas_16_bits = bool(r.get("positional_shadow_16_bits", true))
	var quadrants: Array = r.get("positional_shadow_quadrants", [2, 2, 3, 4])
	for index in 4:
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index, int(quadrants[index]) as Viewport.PositionalShadowAtlasQuadrantSubdiv)
	applied.positional_shadow_atlas = positional
	applied.positional_shadow_slots = _slots(quadrants) if positional > 0 else 0
	var positional_filter := str(r.get("positional_shadow_filter", "soft_low"))
	RenderingServer.positional_soft_shadow_filter_set_quality(FILTERS.get(positional_filter, RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	applied.positional_shadow_filter = positional_filter
	viewport.mesh_lod_threshold = float(top.mesh_lod_threshold)
	applied.mesh_lod_threshold = float(top.mesh_lod_threshold)
	# Samples 1/2/4/8/16 -> Viewport.ANISOTROPY_DISABLED.._16X. Only materials and
	# shaders that request anisotropic filtering (the village ground) use it.
	var samples := int(r.get("anisotropic_samples", 4))
	viewport.anisotropic_filtering_level = clampi(int(round(log(maxf(samples, 1)) / log(2.0))), 0, 4) as Viewport.AnisotropicFiltering
	applied.anisotropic_samples = samples
	var ao: Dictionary = r.get("ssao", {})
	if supports("ssao", method) and bool(ao.get("enabled", false)):
		RenderingServer.environment_set_ssao_quality(AO_QUALITY.get(str(ao.get("quality", "medium")), RenderingServer.ENV_SSAO_QUALITY_MEDIUM),
			bool(ao.get("half_size", true)), 0.5, 2, 50.0, 300.0)
	applied.ssao = bool(ao.get("enabled", false)) and supports("ssao", method)
	applied.ssao_quality = str(ao.get("quality", "")) if applied.ssao else ""
	applied.texture_tier = texture_tier(_current)
	applied.texture_package = _texture_package.duplicate()
	var lights := 0
	if viewport.is_inside_tree():
		for light in viewport.get_tree().get_nodes_in_group(LIGHT_GROUP):
			if light is Light3D:
				configure_light(light, _current)
				lights += 1
	applied.profile_lights = lights
	_applied = applied
	return applied


## Ambient occlusion on whichever Environment the viewport currently renders.
## Unsupported renderers (Mobile) keep it off instead of failing silently.
static func apply_environment(environment: Environment, profile: String, method: String = "") -> bool:
	if environment == null or bool(environment.get_meta(UNMANAGED_META, false)):
		return false
	var ao: Dictionary = render(profile).get("ssao", {})
	var enabled := bool(ao.get("enabled", false)) and supports("ssao", method)
	# Only switch off what a profile switched on; a scene's own AO stays.
	if enabled or bool(environment.get_meta(AO_OWNED_META, false)):
		environment.ssao_enabled = enabled
		environment.set_meta(AO_OWNED_META, enabled)
	if enabled:
		var look: Dictionary = environment.get_meta(AO_LOOK_META, {})
		for key in ["radius", "intensity", "power", "detail", "horizon", "sharpness", "light_affect", "ao_channel_affect"]:
			if look.has(key):
				environment.set("ssao_" + key, float(look[key]))
	return enabled


## Positional light budget (torches, lamps, hearths). Lights in LIGHT_GROUP
## fade out with camera distance and cast shadows only where the profile has
## a positional shadow atlas. A light may refuse shadows with meta "no_shadow".
static func configure_light(light: Light3D, profile: String) -> void:
	var r := render(profile)
	light.distance_fade_enabled = true
	light.distance_fade_begin = float(r.get("light_fade_begin", 30.0))
	light.distance_fade_length = float(r.get("light_fade_length", 10.0))
	light.distance_fade_shadow = float(r.get("light_shadow_fade", 18.0))
	light.shadow_enabled = int(r.get("positional_shadow_atlas", 2048)) > 0 and not bool(light.get_meta("no_shadow", false))


## The Environment the viewport's 3D world currently renders with.
static func active_environment(viewport: Viewport) -> Environment:
	var camera := viewport.get_camera_3d()
	if camera != null and camera.environment != null:
		return camera.environment
	var world := viewport.find_world_3d()
	return world.environment if world != null else null


static func _slots(quadrants: Array) -> int:
	var total := 0
	for value in quadrants:
		total += 0 if int(value) <= 0 else int(pow(4, int(value) - 1))
	return total
