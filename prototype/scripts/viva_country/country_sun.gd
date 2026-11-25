extends Node3D
## Local art-directed daylight. Azimuth measured clockwise from world north (-Z).
const TIMES := {
	"morning":[110.0,31.0,Color(1.0,0.86,0.68),1.22,0.40],
	"noon":[180.0,63.0,Color(1.0,0.96,0.87),1.38,0.43],
	"afternoon":[246.0,26.0,Color(1.0,0.79,0.57),1.20,0.37]
}
var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var direction := Vector3.UP
var selected := "afternoon"

func _ready() -> void:
	sun=DirectionalLight3D.new()
	sun.name="CountrySun"
	sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits=true
	sun.directional_shadow_max_distance=45.0
	add_child(sun)
	environment=Environment.new()
	sky_material=ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("4775a5")
	sky_material.sky_horizon_color=Color("c0ccd0")
	sky_material.ground_bottom_color=Color("554d3a")
	sky_material.ground_horizon_color=Color("b7bba6")
	sky_material.sun_angle_max=7.5
	var sky:=Sky.new()
	sky.sky_material=sky_material
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	environment.sky=sky
	environment.background_mode=Environment.BG_SKY
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("c4d3e4")
	environment.ambient_light_sky_contribution=0.0
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled=true
	environment.fog_density=0.005
	environment.fog_light_color=Color("bdc8c6")
	var world:=WorldEnvironment.new()
	world.environment=environment
	add_child(world)
	set_daylight(selected)

func set_daylight(id: String) -> bool:
	if not TIMES.has(id) or sun==null:
		return false
	selected=id
	var values: Array=TIMES[id]
	var az:=deg_to_rad(float(values[0]))
	var el:=deg_to_rad(float(values[1]))
	direction=Vector3(sin(az)*cos(el),sin(el),-cos(az)*cos(el)).normalized()
	# DirectionalLight emits along local -Z, away from the sun toward the ground.
	sun.look_at(sun.global_position-direction,Vector3.UP)
	sun.light_color=values[2]
	sun.light_energy=float(values[3])
	environment.ambient_light_energy=float(values[4])
	return true

func set_quality(id: String) -> void:
	sun.shadow_enabled=id!="low"
	sun.directional_shadow_max_distance=30.0 if id=="balanced" else 45.0
