extends Node3D
## Independent presentation clock. It never mutates the story or saved world time.
## The 24-hour path is art direction for the workshop, not an astronomical model.

const WIND_SHADER = preload("res://shaders/world_expansion/vegetation_wind.gdshader")
const LIGHT_UPDATE_SECONDS := 0.10
const SHADOW_RANGES := {"low": 24.0, "balanced": 48.0, "high": 85.0, "very_high": 110.0}
var time_of_day := 14.0
var day_duration_seconds := 1200.0
var auto_cycle := false
var wind_strength := 0.6
var wind_direction := Vector2(2.0, 1.0).normalized()
var wind_time := 0.0
var motion_paused := false
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var _sky_material: ProceduralSkyMaterial
var _wind_materials: Array[ShaderMaterial] = []
var _light_accumulator := 0.0


func _ready() -> void:
	create_rig()


func create_rig() -> void:
	if sun != null:
		return
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 10.0
	sky.sky_material = _sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_sky_affect = 0.16
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorkshopEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color("#a9bddb")
	moon.shadow_enabled = false
	add_child(moon)
	_update_light()


func _process(delta: float) -> void:
	advance_presentation(delta)


func advance_presentation(delta: float) -> void:
	if motion_paused or not is_finite(delta) or delta <= 0.0:
		return
	wind_time += delta
	if auto_cycle:
		time_of_day = fposmod(time_of_day + delta * 24.0 / day_duration_seconds, 24.0)
	_light_accumulator += delta
	if _light_accumulator >= LIGHT_UPDATE_SECONDS:
		_light_accumulator = fmod(_light_accumulator, LIGHT_UPDATE_SECONDS)
		_update_light()
	_update_wind_materials()


func set_time_of_day(hours: float) -> bool:
	if not is_finite(hours):
		return false
	time_of_day = fposmod(hours, 24.0)
	_update_light()
	return true


func set_cycle_duration(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 10.0 or seconds > 86400.0:
		return false
	day_duration_seconds = seconds
	return true


func set_wind(strength: float, direction: Vector2 = Vector2(2.0, 1.0)) -> bool:
	if not is_finite(strength) or not direction.is_finite():
		return false
	wind_strength = clampf(strength, 0.0, 2.0)
	if not direction.is_zero_approx():
		wind_direction = direction.normalized()
	_update_wind_materials()
	return true


func set_wind_time(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0.0:
		return false
	wind_time = seconds
	_update_wind_materials()
	return true


func set_quality(profile: String) -> void:
	if sun == null:
		create_rig()
	var selected := profile if SHADOW_RANGES.has(profile) else "balanced"
	sun.directional_shadow_max_distance = SHADOW_RANGES[selected]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if selected == "low" else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func bind_material(material: ShaderMaterial) -> void:
	if material == null or _wind_materials.has(material):
		return
	_wind_materials.append(material)
	_apply_wind(material)


func unbind_materials() -> void:
	_wind_materials.clear()


func _apply_wind(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wind_time", wind_time)
	material.set_shader_parameter("wind_strength", wind_strength)
	material.set_shader_parameter("wind_direction", wind_direction)


func _update_wind_materials() -> void:
	for material in _wind_materials:
		_apply_wind(material)


func _update_light() -> void:
	if sun == null or environment == null:
		return
	var angle := TAU * (time_of_day - 6.0) / 24.0
	var elevation := sin(angle)
	var day := smoothstep(-0.10, 0.30, elevation)
	var twilight := 1.0 - smoothstep(0.0, 0.32, absf(elevation))
	sun.rotation_degrees = Vector3(-rad_to_deg(angle), -32.0, 0.0)
	sun.light_energy = smoothstep(-0.01, 0.24, elevation) * 1.35
	sun.light_color = Color("#ffe8ce").lerp(Color("#ffc089"), twilight * 0.86)
	moon.rotation_degrees = Vector3(-rad_to_deg(angle + PI), -32.0, 0.0)
	moon.light_energy = smoothstep(0.05, 0.55, -elevation) * 0.12
	environment.ambient_light_color = Color("#7e94b6").lerp(Color("#b9cbd4"), day)
	environment.ambient_light_energy = lerpf(0.075, 0.38, day)
	environment.fog_light_color = Color("#17273f").lerp(Color("#aab9b6"), day)
	_sky_material.sky_top_color = Color("#050d22").lerp(Color("#527fa7"), day)
	_sky_material.sky_horizon_color = Color("#18233b").lerp(Color("#c4ccc8"), day).lerp(Color("#bf825d"), twilight * 0.62)
	_sky_material.ground_bottom_color = Color("#11171b").lerp(Color("#555b47"), day)
	_sky_material.ground_horizon_color = _sky_material.sky_horizon_color


func snapshot() -> Dictionary:
	return {
		"time_of_day": time_of_day, "day_duration_seconds": day_duration_seconds,
		"auto_cycle": auto_cycle, "motion_paused": motion_paused,
		"wind_time": wind_time, "wind_strength": wind_strength,
		"wind_direction": [wind_direction.x, wind_direction.y],
		"sun_energy": sun.light_energy if sun != null else 0.0,
		"moon_energy": moon.light_energy if moon != null else 0.0,
		"wind_material_count": _wind_materials.size()
	}
