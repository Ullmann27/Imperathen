extends SceneTree
## Headless contract of rendering/village_look.gd: season presets, time of
## day, weather, interior light and profiles. Presentation only, so it also
## checks that no physics body is created and the sun keeps its node name.

const Look = preload("res://scripts/rendering/village_look.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://scripts/world/village/clouds.gdshader")
	var env := Environment.new()
	var look = Look.new()
	world.add_child(look)
	var sun: DirectionalLight3D = look.setup(world, env, sky)
	_check(world.get_node_or_null("AfternoonSun") == sun, "Sun stays the world's AfternoonSun")
	_check(not world.find_children("*", "WorldEnvironment", true, false).is_empty(), "WorldEnvironment is discoverable")
	_check(env.tonemap_mode in [Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_FILMIC], "Filmic tonemapper")
	_check(env.ambient_light_source == Environment.AMBIENT_SOURCE_BG and env.fog_enabled and env.fog_aerial_perspective > 0.0, "Sky ambient and aerial haze")
	_check(not env.adjustment_enabled, "No blanket contrast/saturation grade")
	_check(Look.SEASONS.size() == 4 and Look.SEASONS[0].sun is Color and Look.DAYLIGHT[1] is Vector3 and Look.OPENINGS[0] is Vector4, "Look values decoded from look_values.json")
	_check(Look.VALUES.cameras.overview.eye is Vector3 and Look.VALUES.cameras.resolutions.size() == 2, "Shared camera set present")
	_check(world.find_children("*", "CollisionObject3D", true, false).is_empty(), "Look adds no physics bodies")
	for profile in ["low", "balanced", "high", "very_high"]:
		look.apply_quality(profile)
		var distance: float = Look.PROFILE_DATA.data.profiles[profile].shadow_distance_metres
		_check(sun.shadow_enabled and is_equal_approx(sun.directional_shadow_max_distance, distance), profile + " shadow range from the profile")
		_check(env.glow_enabled == bool(Look.PROFILE_DATA.data.profiles[profile].glow), profile + " glow from the profile")
		_check(look._bounce_allowed == (profile != "low"), profile + " interior lights")
	look.apply_quality("balanced")
	var afternoon_energy := sun.light_energy
	for season in 4:
		look.apply_season(season)
		_check(sun.light_energy > .9 and sun.rotation_degrees.x < -10.0 and sun.rotation_degrees.x > -45.0, "Season %d: sun up, low afternoon angle" % season)
	look.apply_season(0)
	look.set_time_of_day(6.7)
	var dawn_color := sun.light_color
	_check(look.night < .2 and sun.light_energy < afternoon_energy * .6 and dawn_color.r > dawn_color.b * 1.3, "Sunrise: weak, warm, low sun")
	look.set_time_of_day(13.0)
	_check(sun.rotation_degrees.x < -40.0 and absf(sun.rotation_degrees.y) < 25.0, "Midday: high southern sun")
	look.set_time_of_day(22.5)
	_check(look.night > .95 and sun.light_energy < .2 and sun.light_color.b > sun.light_color.r, "Night: cool moonlight")
	_check(env.ambient_light_energy < .2 and env.tonemap_exposure > 1.2, "Night: dark ambient, adapted exposure")
	look.set_time_of_day(-1.0)
	_check(look.night == 0.0 and is_equal_approx(sun.light_energy, afternoon_energy), "Clearing the time restores the afternoon preset")
	look.set_weather("rain")
	_check(sun.light_energy < afternoon_energy * .3 and env.fog_density > float(Look.SEASONS[0].fog) * 2.0, "Rain dims the sun and thickens haze")
	look.set_weather("clear")
	_check(is_equal_approx(sun.light_energy, afternoon_energy), "Clear weather restores the preset")
	# Interior: a camera inside a home switches to the room light and back.
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var home: Dictionary = Layout.HOMES[0]
	camera.global_position = (home.at as Vector3) + Vector3(0.4, 1.6, 0.2)
	look._process(0.0)
	_check(is_equal_approx(look.interior, 1.0) and look._bounce.visible and look._window.visible, "Inside a home: interior lights on")
	_check(env.ambient_light_sky_contribution < .5, "Inside a home: less open-sky ambient")
	camera.global_position = (home.at as Vector3) + Vector3(0, 1.6, 9.0)
	look._process(0.0)
	_check(look.interior == 0.0 and not look._bounce.visible and is_equal_approx(env.ambient_light_sky_contribution, 1.0), "Outside: open-sky ambient, lights off")
	var torch: OmniLight3D = look.add_fire_light(world, Vector3(0, 2, 0), "torch")
	look._process(.05)
	var first := torch.light_energy
	look._process(.05)
	_check(not torch.shadow_enabled and torch.light_energy > 0.0 and not is_equal_approx(first, torch.light_energy), "Fire light flickers, unshadowed")
	world.free()
	print("VILLAGE_LOOK_TEST %d checks, %d failed %s" % [checks, failures.size(), failures])
	if failures.is_empty():
		print("VILLAGE_LOOK_PASS")
	quit(0 if failures.is_empty() else 1)
