extends RefCounted
## Materials of the shared Valdora ground (land_surface.gdshaderinc): village
## ground, streamed terrain, backdrop hills and far relief. One list of these
## materials receives the season and the environment's haze together.

const TERRAIN_SHADER = preload("res://scripts/world/land/terrain.gdshader")
const FAR_SHADER = preload("res://scripts/world/land/far_relief.gdshader")
const SHARED := ["road_color", "road_relief", "verge_color", "verge_relief"]
## Snow line of the far mountains per season (spring, summer, autumn, winter), metres.
const SNOWLINE_M := [1750.0, 2350.0, 2050.0, 700.0]
## Share of the haze that high, distant relief keeps at most: thicker air
## hides more of the mountains (cap = base + density * slope, clamped).
const HAZE_CAP_BASE := 0.46
const HAZE_CAP_PER_DENSITY := 95.0


static func _dress(material: ShaderMaterial) -> ShaderMaterial:
	material.set_shader_parameter("road_color", preload("res://assets/village/track_color.png"))
	material.set_shader_parameter("verge_color", preload("res://assets/village/verge_color.png"))
	material.set_shader_parameter("road_relief", preload("res://assets/village/track_relief.png"))
	material.set_shader_parameter("verge_relief", preload("res://assets/village/verge_relief.png"))
	material.set_shader_parameter("macro_field", preload("res://assets/landscape/terrain_macro.png"))
	return material


## Streamed terrain and backdrop hills.
static func make_terrain() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("scree_color", preload("res://assets/landscape/scree_color.png"))
	return _dress(material)


static func make_far() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FAR_SHADER
	return _dress(material)


## Adds the shared inputs to the village ground material.
static func dress_village_ground(material: ShaderMaterial) -> void:
	material.set_shader_parameter("macro_field", preload("res://assets/landscape/terrain_macro.png"))
	material.set_shader_parameter("bed_color", preload("res://assets/landscape/brook_bed.png"))


## The village ground decides the turf and earth textures; the other land
## materials follow it, including the turf's mean colour for the distance.
static func follow_village_ground(ground: ShaderMaterial, others: Array) -> void:
	var verge := ground.get_shader_parameter("verge_color") as Texture2D
	var mean := Color(0.389, 0.386, 0.242)
	if verge != null and verge.get_image() != null:
		var image := verge.get_image()
		if image.is_compressed():
			image.decompress()
		image.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		mean = image.get_pixel(0, 0)
	var all: Array = [ground]
	all.append_array(others)
	for material: ShaderMaterial in all:
		material.set_shader_parameter("verge_mean", mean)
		if material != ground:
			for key: String in SHARED:
				material.set_shader_parameter(key, ground.get_shader_parameter(key))


static func apply_season(materials: Array, season: int, tint: Color) -> void:
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("season_tint", tint)
		material.set_shader_parameter("snowline", SNOWLINE_M[posmod(season, 4)])


## Copies the environment's fog into the shader haze. horizon is the sky
## colour at the horizon (aerial perspective blends the fog towards it).
static func sync_haze(materials: Array, environment: Environment, horizon: Color) -> void:
	var density := 0.0
	var color := Color.BLACK
	var height := 0.0
	var height_density := 0.0
	if environment != null and environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_EXPONENTIAL:
		density = environment.fog_density
		color = (environment.fog_light_color.srgb_to_linear() * environment.fog_light_energy) \
			.lerp(horizon.srgb_to_linear(), clampf(environment.fog_aerial_perspective, 0.0, 1.0))
		height = environment.fog_height
		height_density = environment.fog_height_density
	var cap := clampf(HAZE_CAP_BASE + density * HAZE_CAP_PER_DENSITY, 0.0, 1.0)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("haze_color", Vector3(color.r, color.g, color.b))
		material.set_shader_parameter("haze_density", density)
		material.set_shader_parameter("haze_height", height)
		material.set_shader_parameter("haze_height_density", height_density)
		material.set_shader_parameter("haze_cap", cap)
