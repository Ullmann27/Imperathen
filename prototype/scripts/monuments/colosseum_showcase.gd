extends Node3D
## Dedicated showcase / test scene for the amphitheatre and its piazza (D-053).
## It never runs inside the 58 BC campaign city; the world date defaults to AD 100.
const ColosseumScript := preload("res://scripts/monuments/colosseum.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")

@export var profile := "balanced"
@export var year := 100
@export var external_lighting := false
@export var spawn_people := false
@export var velarium := false
@export var night := false
var colosseum: Node3D
var piazza: Node3D
var harness: Node


func _ready() -> void:
	var jdn := Calendar.to_jdn(year, 6, 1)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 1400)
	ground.mesh = plane
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.46, 0.42, 0.34)
	soil.roughness = 1.0
	ground.material_override = soil
	ground.position.y = -0.06
	ground.name = "Soil"
	add_child(ground)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1400, 1, 1400)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	floor_body.name = "GroundCollision"
	add_child(floor_body)
	if ColosseumScript.available_at(jdn):
		colosseum = ColosseumScript.new()
		colosseum.set("profile", profile)
		colosseum.set("velarium", velarium)
		colosseum.set("night", night)
		colosseum.set("world_jdn", jdn)
		colosseum.name = "Colosseum"
		add_child(colosseum)
	var piazza_script := "res://scripts/monuments/colosseum_piazza.gd"
	if ResourceLoader.exists(piazza_script):
		piazza = (load(piazza_script) as GDScript).new()
		piazza.set("profile", profile)
		piazza.set("world_jdn", jdn)
		piazza.name = "Piazza"
		add_child(piazza)
	if not external_lighting:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
		sun.shadow_enabled = profile != "low"
		sun.directional_shadow_max_distance = 220.0
		add_child(sun)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_SKY
		environment.sky = Sky.new()
		environment.sky.sky_material = ProceduralSkyMaterial.new()
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var world := WorldEnvironment.new()
		world.environment = environment
		add_child(world)
	var harness_script := "res://scripts/monuments/colosseum_visitor_harness.gd"
	if spawn_people and ResourceLoader.exists(harness_script):
		harness = (load(harness_script) as GDScript).new()
		harness.name = "VisitorHarness"
		add_child(harness)
