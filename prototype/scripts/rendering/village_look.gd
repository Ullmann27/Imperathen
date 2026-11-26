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
		"ambient":.52, "exposure":.88, "fog":.0019, "fog_height":.006,
		"zenith":Color("#3a73ab"), "horizon":Color("#a9c2cc"), "clouds":Color("#f3ebdc"), "haze":Color("#ffcf96"),
		"ground":Color("#4d4f33"), "coverage":.43},
	{"sun_angle":Vector2(-34,-31), "sun":Color("#ffd6a0"), "sun_energy":2.2,
		"ambient":.48, "exposure":.86, "fog":.0023, "fog_height":.008,
		"zenith":Color("#467eae"), "horizon":Color("#bccad0"), "clouds":Color("#f4e6cf"), "haze":Color("#ffc584"),
		"ground":Color("#5a5232"), "coverage":.30},
	{"sun_angle":Vector2(-24,-47), "sun":Color("#f2ddc4"), "sun_energy":1.25,
		"ambient":.66, "exposure":.95, "fog":.0048, "fog_height":.02,
		"zenith":Color("#66808f"), "horizon":Color("#a9b2b1"), "clouds":Color("#c3c9c4"), "haze":Color("#e6cfae"),
		"ground":Color("#443f30"), "coverage":.86},
	{"sun_angle":Vector2(-19,-39), "sun":Color("#f6e6d2"), "sun_energy":1.45,
		"ambient":.62, "exposure":.92, "fog":.0036, "fog_height":.015,
		"zenith":Color("#5f84a0"), "horizon":Color("#b4c5cd"), "clouds":Color("#dde2df"), "haze":Color("#f2d6b4"),
		"ground":Color("#56585a"), "coverage":.61},
]
# Sun path for Valdora (about 45.6 N): sunrise and sunset in local solar hours
# and the noon elevation per season. Used only when a time of day is set.
const DAYLIGHT := [Vector3(6.3, 18.5, 50.0), Vector3(5.3, 19.6, 64.0), Vector3(6.6, 17.4, 36.0), Vector3(7.6, 16.4, 22.0)]
const NIGHT_SKY := {"zenith":Color("#070d1a"), "horizon":Color("#1a2638"), "clouds":Color("#262d3a"), "haze":Color("#3d4a66"), "ground":Color("#0e1014")}
const MOON := {"color":Color("#9fb4e6"), "energy":.14, "angle":Vector2(-48, 150)}
# Fire light kinds: colour, energy, range, flicker depth.
const FIRE := {"candle":[Color("#ffb066"), .55, 2.6, .10], "torch":[Color("#ff9a48"), 1.6, 7.0, .16], "hearth":[Color("#ff8a3c"), 2.2, 5.0, .20]}
# Weather on top of season and time of day: cloud cover, direct and sky
# light, haze. Rain and mist also darken and cool the horizon.
const WEATHER := {
	"clear": {"coverage":-1.0, "sun":1.0, "ambient":1.0, "fog":1.0, "height":1.0, "grey":0.0},
	"overcast": {"coverage":.9, "sun":.35, "ambient":1.25, "fog":1.8, "height":1.4, "grey":.45},
	"rain": {"coverage":1.0, "sun":.18, "ambient":1.12, "fog":2.6, "height":2.2, "grey":.6},
	"mist": {"coverage":.7, "sun":.55, "ambient":1.15, "fog":4.0, "height":3.5, "grey":.3},
}
# Inside a home the open sky no longer lights the room: ambient becomes the
# warm, dimmer bounce from floor and walls, and the eye adapts upwards. Two
# unshadowed lights follow the camera's home: warm light bounced off the sunlit
# threshold just inside the door, and cool skylight from the rear window.
# frontier_house.glb has one small high rear window (x -0.35..0.55,
# y 1.8..2.4, inner face z -2.17); door and two windows face +z.
const BOUNCE_LOCAL := Vector3(0.0, .55, 1.55)
# Front openings (x0, x1, y0, y1 at the inner wall face z = 2.17) for sunbeams.
const OPENINGS := [Vector4(-.65, .55, .45, 2.55), Vector4(-2.3, -1.4, 1.65, 2.4), Vector4(1.3, 2.2, 1.65, 2.4)]
const SHAFT_SHADER := preload("res://scripts/rendering/sun_shaft.gdshader")
const WINDOW_LOCAL := Vector3(0.1, 2.25, -1.55)
var interior_ambient := Color("#4a433b")
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
var _shafts_allowed := false
var _shafts: MeshInstance3D
var _home := -1
## Local solar hours; negative keeps the season's afternoon preset.
var time_of_day := -1.0
## "clear" keeps the season preset; see WEATHER.
var weather := "clear"
## 0 by day, 1 in full night; drives the interior fire light.
var night := 0.0
var _fires: Array[Dictionary] = []
var _clock := 0.0


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
	# Sunbeams through door and front windows (high and very high profiles).
	_shafts = MeshInstance3D.new()
	_shafts.name = "SunShafts"
	_shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shafts.material_override = ShaderMaterial.new()
	_shafts.material_override.shader = SHAFT_SHADER
	_shafts.visible = false
	add_child(_shafts)
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
	env.ambient_light_color = Color("#4a433b")
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	# The tonemapper and the light carry the image; no blanket contrast or
	# saturation boost on top (owner directive: natural, not just punchier).
	env.adjustment_enabled = false
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
		sky.set_shader_parameter("haze_strength", .38)
		sky.set_shader_parameter("ground_color", preset.ground)


func apply_season(index: int) -> void:
	season = posmod(index, SEASONS.size())
	apply_season_light(season, sun, environment, sky_material)
	night = 0.0
	if time_of_day >= 0.0:
		_apply_time(time_of_day)
	_apply_weather()
	if _home >= 0:
		_build_shafts(_home)
	_apply_interior(interior)


## Dynamic time of day in local solar hours (sunrise, day, sunset, night with
## moonlight). A negative value returns to the season's afternoon preset.
func set_time_of_day(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0) if hours >= 0.0 else -1.0
	apply_season(season)


func _apply_time(hours: float) -> void:
	var preset: Dictionary = SEASONS[season]
	var path: Vector3 = DAYLIGHT[season]
	var day := (hours - path.x) / (path.y - path.x)
	# Elevation follows a sine arc between sunrise and sunset and keeps
	# sinking after sunset so the twilight fades in a believable order.
	var elevation := path.z * sin(PI * clampf(day, 0.0, 1.0))
	if day < 0.0:
		elevation = -day * (path.y - path.x) * -15.0
	elif day > 1.0:
		elevation = (day - 1.0) * (path.y - path.x) * -15.0
	var azimuth := lerpf(-105.0, 105.0, clampf(day, 0.0, 1.0))
	var low := 1.0 - smoothstep(2.0, 24.0, elevation)
	night = smoothstep(1.0, -7.0, elevation)
	var warm := Color("#ff8a46").lerp(Color("#ffc58e"), smoothstep(1.0, 12.0, elevation)).lerp(preset.sun, smoothstep(12.0, 40.0, elevation))
	if elevation > 0.0:
		sun.rotation_degrees = Vector3(-maxf(elevation, 1.5), -azimuth, 0)
		sun.light_color = warm
		# Extinction through more air near the horizon.
		sun.light_energy = float(preset.sun_energy) * smoothstep(0.0, 8.0, elevation) * lerpf(.55, 1.0, smoothstep(8.0, 40.0, elevation))
	else:
		sun.rotation_degrees = Vector3(MOON.angle.x, MOON.angle.y, 0)
		sun.light_color = MOON.color
		sun.light_energy = MOON.energy * night
	environment.ambient_light_energy = float(preset.ambient) * lerpf(1.0, .22, night) * lerpf(1.0, .75, low * (1.0 - night))
	var exposure := float(preset.exposure) * lerpf(1.0, 1.7, night) * lerpf(1.0, 1.12, low * (1.0 - night))
	environment.set_meta("look_exposure", exposure)
	environment.tonemap_exposure = exposure
	var twilight := low * (1.0 - night)
	var zenith: Color = (preset.zenith as Color).lerp(Color("#2c4775"), twilight * .6).lerp(NIGHT_SKY.zenith, night)
	var horizon: Color = (preset.horizon as Color).lerp(Color("#e8a070"), twilight * .7).lerp(NIGHT_SKY.horizon, night)
	var haze: Color = (preset.haze as Color).lerp(Color("#ff8c4a"), twilight).lerp(NIGHT_SKY.haze, night)
	environment.fog_light_color = horizon.lerp(haze, .3)
	environment.fog_density = float(preset.fog) * lerpf(1.0, 1.35, twilight)
	if sky_material != null:
		sky_material.set_shader_parameter("zenith", zenith)
		sky_material.set_shader_parameter("horizon", horizon)
		sky_material.set_shader_parameter("sun_haze", haze)
		sky_material.set_shader_parameter("haze_strength", lerpf(.38, .8, twilight))
		sky_material.set_shader_parameter("cloud_color", (preset.clouds as Color).lerp(Color("#f2b48a"), twilight * .6).lerp(NIGHT_SKY.clouds, night))
		sky_material.set_shader_parameter("ground_color", (preset.ground as Color).lerp(NIGHT_SKY.ground, night))


## Weather-dependent light: "clear", "overcast", "rain" or "mist".
func set_weather(kind: String) -> void:
	weather = kind if WEATHER.has(kind) else "clear"
	apply_season(season)


func _apply_weather() -> void:
	var w: Dictionary = WEATHER[weather]
	if weather == "clear":
		return
	sun.light_energy *= float(w.sun)
	environment.ambient_light_energy *= float(w.ambient)
	environment.fog_density *= float(w.fog)
	environment.fog_height_density *= float(w.height)
	var grey := Color("#9aa3a6").lerp(Color("#1c222b"), night)
	environment.fog_light_color = environment.fog_light_color.lerp(grey, float(w.grey))
	if sky_material != null:
		sky_material.set_shader_parameter("coverage", maxf(float(w.coverage), float(sky_material.get_shader_parameter("coverage"))))
		for key in ["zenith", "horizon", "sun_haze"]:
			var tone: Color = sky_material.get_shader_parameter(key)
			sky_material.set_shader_parameter(key, tone.lerp(grey, float(w.grey)))


## A warm, flickering fire light (candle, torch or hearth) under `parent`.
## Unshadowed; the look node animates all of them from one clock.
func add_fire_light(parent: Node3D, at: Vector3, kind := "torch") -> OmniLight3D:
	var spec: Array = FIRE.get(kind, FIRE.torch)
	var light := OmniLight3D.new()
	light.name = "Fire_" + kind
	light.light_color = spec[0]
	light.light_energy = spec[1]
	light.omni_range = spec[2]
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position = at
	parent.add_child(light)
	_fires.append({"light":light, "energy":spec[1], "depth":spec[3], "phase":randf() * TAU})
	return light


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
	_shafts_allowed = bool(look.get("light_shafts", false))
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
	_clock += delta
	if night > .01 and _bounce.visible:
		_bounce.light_energy = _fire_energy(bounce_energy * interior, .18, 0.0)
	var alive: Array[Dictionary] = []
	for fire in _fires:
		if is_instance_valid(fire.light):
			fire.light.light_energy = _fire_energy(fire.energy, fire.depth, fire.phase)
			alive.append(fire)
	_fires = alive


func _fire_energy(base: float, depth: float, phase: float) -> float:
	var t := _clock * 9.0 + phase
	var flicker := sin(t) * .5 + sin(t * 2.31 + 1.7) * .3 + sin(t * 5.13 + .4) * .2
	return base * (1.0 + depth * flicker)


func _apply_interior(value: float) -> void:
	interior = value
	# Without the interior lights (low profile) rooms only take half of the warm
	# ambient shift and no exposure change, so they stay readable.
	var amount := interior if _bounce_allowed else interior * .5
	environment.ambient_light_color = interior_ambient if _bounce_allowed else interior_ambient * 2.2
	environment.ambient_light_sky_contribution = lerpf(1.0, interior_sky_share, amount)
	environment.tonemap_exposure = float(environment.get_meta("look_exposure", 1.0)) * lerpf(1.0, interior_exposure, interior if _bounce_allowed else 0.0)
	_bounce.visible = _bounce_allowed and interior > .01
	# By night the threshold bounce becomes the hearth and the window only
	# lets in a little cool moonlight.
	_bounce.light_color = Color("#ffc995").lerp(FIRE.hearth[0], night)
	_bounce.light_energy = bounce_energy * interior * (1.25 if season in [2, 3] else 1.0) * lerpf(1.0, .75, night)
	_window.visible = _bounce.visible
	_window.light_color = Color("#c9dcff").lerp(MOON.color, night)
	_window.light_energy = window_energy * interior * lerpf(1.0, .08, night)
	_shafts.visible = _shafts_allowed and interior > .5 and night < .5 and _shafts.mesh != null
	var beam: ShaderMaterial = _shafts.material_override
	beam.set_shader_parameter("beam_color", sun.light_color)
	beam.set_shader_parameter("strength", .16 * clampf(sun.light_energy / 2.0, 0.0, 1.2) * (1.0 - night))


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
	_build_shafts(index)


## Additive prisms from the door and front windows along the sunlight, only
## when the sun actually shines in through them.
func _build_shafts(index: int) -> void:
	_shafts.mesh = null
	if index < 0 or night > .5 or sun.light_energy < .2:
		return
	var home: Dictionary = Layout.HOMES[index]
	var yaw := float(home.yaw)
	var travel := (-sun.global_basis.z).rotated(Vector3.UP, -yaw)
	if travel.z > -.15 or travel.y > -.05:
		return
	var reach := travel * 3.4
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for opening: Vector4 in OPENINGS:
		var corners := [Vector3(opening.x, opening.z, 2.17), Vector3(opening.y, opening.z, 2.17),
			Vector3(opening.y, opening.w, 2.17), Vector3(opening.x, opening.w, 2.17)]
		for side in 4:
			var a: Vector3 = corners[side]
			var b: Vector3 = corners[(side + 1) % 4]
			var normal := (b - a).cross(travel).normalized()
			for v in [[a, 0.0, 0.0], [b, 1.0, 0.0], [b + reach, 1.0, 1.0], [a, 0.0, 0.0], [b + reach, 1.0, 1.0], [a + reach, 0.0, 1.0]]:
				mesh.set_normal(normal)
				mesh.set_uv(Vector2(v[1], v[2]))
				mesh.add_vertex(v[0])
	_shafts.mesh = mesh.commit()
	_shafts.global_transform = Transform3D(Basis(Vector3.UP, yaw), home.at)
