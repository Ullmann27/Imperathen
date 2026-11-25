extends RefCounted
## One sun, shared scene state, no renderer migration and no camera changes.
const Ground := preload("res://shaders/viva_roma_ground.gdshader")
const DISTANCE := {"low":24.0,"balanced":48.0,"high":85.0,"very_high":110.0}

static func ground_material(profile: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = Ground
	mat.set_shader_parameter("detail_strength", 0.35 if profile == "low" else (0.7 if profile == "balanced" else 1.0))
	return mat

static func configure_sun(sun: DirectionalLight3D, profile: String) -> void:
	sun.rotation_degrees = Vector3(-36.0,-37.0,0.0)
	sun.light_color = Color(1.0,0.91,0.80)
	sun.light_energy = 1.35
	sun.shadow_enabled = profile != "low"
	sun.directional_shadow_max_distance = float(DISTANCE.get(profile,48.0))
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true

static func environment(profile: String) -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("4b7baf")
	atmosphere.sky_horizon_color = Color("c4d1d4")
	atmosphere.ground_bottom_color = Color("61563f")
	atmosphere.ground_horizon_color = Color("bec4bb")
	atmosphere.sky_curve = 0.22
	atmosphere.ground_curve = 0.15
	sky.sky_material = atmosphere
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if profile in ["high","very_high"] else Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c1cce0")
	env.ambient_light_energy = 0.40
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_density = 0.0016
	env.fog_light_color = Color("c5c6b9")
	return env
