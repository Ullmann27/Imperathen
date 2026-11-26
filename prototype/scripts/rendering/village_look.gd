extends Node3D
## Valdora light, sky, haze, grade and interior light for the Compatibility
## renderer. Presentation only: it never changes collision, cover, sight
## lines, navigation, simulation or saved state, in any quality profile.

const PROFILE_DATA = preload("res://assets/quality_profiles.json")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Surfaces = preload("res://scripts/rendering/village_surfaces.gd")
const SUN_NAME := "AfternoonSun"
# Spring, summer, autumn (wet, overcast) and winter. Sun angles are pitch/yaw
# in degrees; a low afternoon sun gives long, readable shadows.
const SEASONS := [
	{"sun_angle":Vector2(-29,-38), "sun":Color("#ffdcb0"), "sun_energy":2.0,
		"ambient":.52, "exposure":.94, "fog":.0019, "fog_height":.006,
		"zenith":Color("#3a73ab"), "horizon":Color("#a9c2cc"), "clouds":Color("#f3ebdc"), "haze":Color("#ffcf96"),
		"ground":Color("#4d4f33"), "coverage":.43},
	{"sun_angle":Vector2(-34,-31), "sun":Color("#ffd6a0"), "sun_energy":2.2,
		"ambient":.48, "exposure":.92, "fog":.0023, "fog_height":.008,
		"zenith":Color("#467eae"), "horizon":Color("#bccad0"), "clouds":Color("#f4e6cf"), "haze":Color("#ffc584"),
		"ground":Color("#5a5232"), "coverage":.30},
	{"sun_angle":Vector2(-24,-47), "sun":Color("#f2ddc4"), "sun_energy":1.25,
		"ambient":.66, "exposure":1.0, "fog":.0048, "fog_height":.02,
		"zenith":Color("#66808f"), "horizon":Color("#a9b2b1"), "clouds":Color("#c3c9c4"), "haze":Color("#e6cfae"),
		"ground":Color("#443f30"), "coverage":.86},
	{"sun_angle":Vector2(-19,-39), "sun":Color("#f6e6d2"), "sun_energy":1.45,
		"ambient":.62, "exposure":.98, "fog":.0036, "fog_height":.015,
		"zenith":Color("#5f84a0"), "horizon":Color("#b4c5cd"), "clouds":Color("#dde2df"), "haze":Color("#f2d6b4"),
		"ground":Color("#56585a"), "coverage":.61},
]
# Inside a home the open sky no longer lights the room: ambient becomes the
# warm, dimmer bounce from floor and walls, and the eye adapts upwards. Two
# unshadowed lights follow the camera's home: warm light bounced off the sunlit
# threshold just inside the door, and cool skylight from the rear window.
# frontier_house.glb has one small high rear window (x -0.35..0.55,
# y 1.8..2.4, inner face z -2.17); door and two windows face +z.
const BOUNCE_LOCAL := Vector3(0.0, .55, 1.55)
const WINDOW_LOCAL := Vector3(0.1, 2.25, -1.55)
var interior_ambient := Color("#3c362f")
var interior_sky_share := .28
var interior_exposure := 1.3
var bounce_energy := 2.4
var window_energy := 3.0

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial
var profile := "balanced"
var season := 0
var interior := 0.0
var _bounce: OmniLight3D
var _window: SpotLight3D
var _bounce_allowed := true
var _home := -1


## Builds the WorldEnvironment and the sun as children of `world` and returns the sun.
func setup(world: Node3D, target: Environment, sky: ShaderMaterial) -> DirectionalLight3D:
	environment = target
	sky_material = sky
	var world_environment := WorldEnvironment.new()
	world_environment.name = "VillageEnvironment"
	configure_environment(environment, sky_material)
	world_environment.environment = environment
	world.add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = SUN_NAME
	sun.shadow_enabled = true
	world.add_child(sun)
	_bounce = OmniLight3D.new()
	_bounce.name = "InteriorBounce"
	_bounce.light_color = Color("#ffc995")
	_bounce.omni_range = 3.8
	_bounce.omni_attenuation = 1.8
	_bounce.shadow_enabled = false
	_bounce.light_specular = 0.15
	_bounce.visible = false
	add_child(_bounce)
	# Cool skylight falling in through the rear window onto floor and table.
	_window = SpotLight3D.new()
	_window.name = "WindowSkylight"
	_window.light_color = Color("#c9dcff")
	_window.spot_range = 3.8
	_window.spot_angle = 64.0
	_window.spot_angle_attenuation = 2.0
	_window.spot_attenuation = 1.2
	_window.shadow_enabled = false
	_window.light_specular = .1
	_window.visible = false
	add_child(_window)
	apply_season_light(season, sun, environment, sky_material)
	return sun


static func configure_environment(env: Environment, sky: ShaderMaterial) -> void:
	env.background_mode = Environment.BG_SKY
	if env.sky == null:
		env.sky = Sky.new()
	env.sky.sky_material = sky
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64
	# Ambient light from the sky (blue from above, land colour from below)
	# instead of one flat colour; the share drops indoors.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_color = Color("#3c362f")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.08
	# Aerial perspective takes the fog colour from the sky behind each pixel, so
	# distant hills fade into the horizon colour; height fog settles in the valley.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_aerial_perspective = .5
	env.fog_sky_affect = .08
	env.fog_sun_scatter = .18  # no effect in Compatibility; kept for Mobile/Forward+ A/B
	env.fog_height = 1.2
	env.glow_enabled = false
	env.glow_normalized = true
	env.glow_intensity = .55
	env.glow_strength = .9
	env.glow_bloom = .035
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT


static func apply_season_light(index: int, light: DirectionalLight3D, env: Environment, sky: ShaderMaterial) -> void:
	var preset: Dictionary = SEASONS[posmod(index, SEASONS.size())]
	light.rotation_degrees = Vector3(preset.sun_angle.x, preset.sun_angle.y, 0)
	light.light_color = preset.sun
	light.light_energy = preset.sun_energy
	env.ambient_light_energy = preset.ambient
	env.fog_density = preset.fog
	env.fog_height_density = preset.fog_height
	env.fog_light_color = (preset.horizon as Color).lerp(preset.haze, .25)
	env.set_meta("look_exposure", preset.exposure)
	env.tonemap_exposure = preset.exposure
	if sky != null:
		sky.set_shader_parameter("coverage", preset.coverage)
		sky.set_shader_parameter("zenith", preset.zenith)
		sky.set_shader_parameter("horizon", preset.horizon)
		sky.set_shader_parameter("cloud_color", preset.clouds)
		sky.set_shader_parameter("sun_haze", preset.haze)
		sky.set_shader_parameter("ground_color", preset.ground)


func apply_season(index: int) -> void:
	season = posmod(index, SEASONS.size())
	apply_season_light(season, sun, environment, sky_material)
	_apply_interior(interior)


## Shadow range, splits, filtering, glow and sky resolution. MSAA stays with the caller.
func apply_quality(next_profile: String) -> void:
	profile = next_profile if PROFILE_DATA.data.profiles.has(next_profile) else "balanced"
	var look: Dictionary = PROFILE_DATA.data.profiles[profile].get("look", {})
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(PROFILE_DATA.data.profiles[profile].shadow_distance_metres)
	sun.directional_shadow_mode = {1:DirectionalLight3D.SHADOW_ORTHOGONAL, 2:DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS}.get(int(look.get("shadow_splits", 4)), DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	sun.directional_shadow_blend_splits = int(look.get("shadow_splits", 4)) == 4
	sun.directional_shadow_fade_start = .82
	sun.shadow_bias = .06
	sun.shadow_normal_bias = 1.4
	RenderingServer.directional_soft_shadow_filter_set_quality({"hard":RenderingServer.SHADOW_QUALITY_HARD,
		"soft_low":RenderingServer.SHADOW_QUALITY_SOFT_LOW, "soft_medium":RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		"soft_high":RenderingServer.SHADOW_QUALITY_SOFT_HIGH}.get(str(look.get("shadow_filter", "soft_low")), RenderingServer.SHADOW_QUALITY_SOFT_LOW))
	environment.glow_enabled = bool(PROFILE_DATA.data.profiles[profile].get("glow", false))
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_128 if int(look.get("sky_radiance", 64)) >= 128 else Sky.RADIANCE_SIZE_64
	environment.fog_aerial_perspective = float(look.get("aerial_perspective", .62))
	_bounce_allowed = bool(look.get("interior_bounce", true))
	Surfaces.set_profile(profile)
	_apply_interior(interior)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or environment == null:
		return
	var home := _home_at(camera.global_position)
	var target := 1.0 if home >= 0 else 0.0
	if home >= 0 and home != _home:
		_place_bounce(home)
	_home = home if home >= 0 else _home
	# A teleport or a paused clock snaps; walking through a door blends.
	var next := target if delta <= 0.0 else move_toward(interior, target, delta * 2.6)
	if not is_equal_approx(next, interior):
		_apply_interior(next)


func _apply_interior(value: float) -> void:
	interior = value
	# Without the interior lights (low profile) rooms only take half of the warm
	# ambient shift and no exposure change, so they stay readable.
	var amount := interior if _bounce_allowed else interior * .5
	environment.ambient_light_color = interior_ambient if _bounce_allowed else interior_ambient * 2.2
	environment.ambient_light_sky_contribution = lerpf(1.0, interior_sky_share, amount)
	environment.tonemap_exposure = float(environment.get_meta("look_exposure", 1.0)) * lerpf(1.0, interior_exposure, interior if _bounce_allowed else 0.0)
	_bounce.visible = _bounce_allowed and interior > .01
	_bounce.light_energy = bounce_energy * interior * (1.25 if season in [2, 3] else 1.0)
	_window.visible = _bounce.visible
	_window.light_energy = window_energy * interior


func _home_at(point: Vector3) -> int:
	if point.y > 3.4:
		return -1
	for index in Layout.HOMES.size():
		if Layout.house_footprint(Layout.HOMES[index], -.3).has_point(Vector2(point.x, point.z)):
			return index
	return -1


func _place_bounce(index: int) -> void:
	var home: Dictionary = Layout.HOMES[index]
	var yaw := float(home.yaw)
	_bounce.global_position = (home.at as Vector3) + BOUNCE_LOCAL.rotated(Vector3.UP, yaw)
	_window.global_position = (home.at as Vector3) + WINDOW_LOCAL.rotated(Vector3.UP, yaw)
	# Point into the room (+z local) and down toward the floor.
	_window.global_basis = Basis.from_euler(Vector3(deg_to_rad(-60.0), yaw + PI, 0.0))
