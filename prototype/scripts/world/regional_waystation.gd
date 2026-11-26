extends Node3D
## Weidenhof, a fictional inhabited stop alongside the existing quarry road.
## The cart phase comes from campaign seconds. Sector reloads do not restart it.
const Region = preload("res://scripts/world/world_stream_plan.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const ASSETS := "res://assets/world/waystation/"
const HORSE := "res://assets/horse/valdora_horse_rig.glb"
const COUNTER := Vector2(241,119)
const NEAR := 128.0
var _installed := false
var _height: Callable
var _wagon: AnimatableBody3D
var _wheels: Array[Node3D] = []
var _last_second := -1.0
var _subsecond := 0.0

static func at_counter(player: Vector3) -> bool:
	return Vector2(player.x,player.z).distance_to(COUNTER) <= 2.8

func setup(height: Callable) -> void:
	_height = height
	position = Vector3(COUNTER.x,height.call(COUNTER),COUNTER.y)

func update_nearby(player: Vector3, seconds: float, delta: float) -> void:
	var distance := Vector2(player.x,player.z).distance_to(COUNTER)
	visible = distance < NEAR
	if not visible:
		if _installed and distance > NEAR + 60.0:
			for child: Node in get_children():
				child.free()
			_wheels.clear()
			_installed = false
		return
	if not _installed:
		_build()
		_installed = true
	if seconds != _last_second:
		_last_second = seconds
		_subsecond = 0.0
	else:
		_subsecond = minf(0.24,_subsecond + delta)
	_drive(seconds + _subsecond)

func _ground(offset: Vector2) -> Vector3:
	return Vector3(offset.x,float(_height.call(COUNTER + offset))-position.y,offset.y)

func _asset(path: String, parent: Node3D) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(node)
	return node

func _place(asset: String, offset: Vector2, angle: float, solid := false) -> Node3D:
	var model := _asset(ASSETS + asset + ".glb",self)
	model.name = asset
	model.position = _ground(offset)
	model.rotation.y = angle
	if solid:
		for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			part.create_trimesh_collision()
	return model

func _build() -> void:
	_place("road_inn",Vector2(-10,1),PI/2,true)
	_place("storehouse",Vector2(6,4),-PI/2,true)
	_place("storehouse",Vector2(-4,10),PI,true)
	_place("stall",Vector2(0,2.4),PI,true)
	_place("trough",Vector2(8,-1),PI/2,true)
	for prop: Array in [["ancestor_bust",Vector2(-4,3)],["transport_amphora",Vector2(2.2,2.4)]]:
		var path := "res://assets/legio/" + str(prop[0]) + ".glb"
		if ResourceLoader.exists(path,"PackedScene"):
			var art := _asset(path,self)
			art.position = _ground(prop[1])
	var vendor := Person.new()
	vendor.name = "Tertia"
	vendor.set_meta("actor_uid","road:weidenhof_tertia")
	add_child(vendor)
	vendor.position = _ground(Vector2(0,3.1))
	vendor.configure_resident("italia",39,"civilian_woman",7,null,"road:weidenhof_tertia")
	_build_grove()
	_build_spring()
	_wagon = AnimatableBody3D.new()
	_wagon.name = "AmphoraWagon"
	_wagon.sync_to_physics = false
	add_child(_wagon)
	_asset(ASSETS+"cart.glb",_wagon)
	_box(_wagon,Vector3(1.52,1.12,1.9),Vector3(0,.72,0))
	for sign_x: int in [-1,1]:
		var wheel := _asset(ASSETS+"cart_wheel.glb",_wagon)
		wheel.position = Vector3(sign_x*.77,.53,-.16)
		_wheels.append(wheel)
	var horse := _asset(HORSE,_wagon)
	horse.position.z = 2.4
	horse.rotation.y = PI
	_box(_wagon,Vector3(.76,1.5,1.9),Vector3(0,.75,2.4))
	var animator := horse.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	animator.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
	animator.play("walk")

func _box(parent: CollisionObject3D, dimensions: Vector3, at: Vector3) -> void:
	var node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	node.shape = box
	node.position = at
	parent.add_child(node)

func _build_grove() -> void:
	var template := (load(ASSETS+"willow.glb") as PackedScene).instantiate()
	var mesh: Mesh = (template.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D).mesh
	template.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5894
	var transforms: Array[Transform3D] = []
	for i in 94:
		var center := Vector2(-29,-25) if i < 42 else Vector2(29,12)
		var offset := center + Vector2(rng.randfn(0,5.2),rng.randfn(0,9.1))
		var world_point := COUNTER + offset
		var clear := true
		for j in range(1,Footpath.WAYPOINTS.size()):
			if Geometry2D.get_closest_point_to_segment(world_point,Footpath.WAYPOINTS[j-1],Footpath.WAYPOINTS[j]).distance_to(world_point) < 5.0:
				clear = false
				break
		if clear and offset.length() > 16:
			var scale_factor := rng.randf_range(.66,1.32)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*scale_factor),_ground(offset)))
	var trees := MultiMesh.new()
	trees.transform_format = MultiMesh.TRANSFORM_3D
	trees.mesh = mesh
	trees.instance_count = transforms.size()
	for i in transforms.size():
		trees.set_instance_transform(i,transforms[i])
	var stand := MultiMeshInstance3D.new()
	stand.name = "WillowGroves"
	stand.multimesh = trees
	add_child(stand)

func _drive(seconds: float) -> void:
	# Smooth turns through a staging yard north of the houses. No turn-around
	# jump; pulling direction and wheel rotation are derived from one phase.
	var phase := fposmod(seconds,52.0)*TAU/52.0
	var offset := Vector2(8.4*cos(phase),-9.0+4.2*sin(phase))
	var direction := Vector2(-8.4*sin(phase),4.2*cos(phase)).normalized()
	_wagon.position = _ground(offset)
	_wagon.rotation.y = atan2(direction.x,direction.y)
	for wheel in _wheels:
		wheel.rotation.x = seconds*1.50

func _build_spring() -> void:
	# The water plane intersects the depressed terrain. The existing solid
	# lakebed remains shallow enough to wade across using the normal controller.
	var water := MeshInstance3D.new()
	water.name = "WillowSpring"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.008
	disc.radial_segments = 56
	disc.rings = 0
	water.mesh = disc
	water.scale = Vector3(Region.SPRING_RADII.x,1,Region.SPRING_RADII.y)
	water.position = Vector3(Region.SPRING.x,Region.WATER_LEVEL,Region.SPRING.y) - position
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode cull_back, blend_mix;
varying vec2 metres;
void vertex() { metres = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	float ripples = sin(metres.x*0.85 + metres.y*1.36 + TIME*0.70)
		* sin(metres.y*2.7 - TIME*0.54);
	ALBEDO = mix(vec3(0.09,0.20,0.17),vec3(0.28,0.40,0.34),ripples*0.5+0.5);
	ROUGHNESS = 0.22;
	ALPHA = 0.63;
}
"""
	var surface := ShaderMaterial.new()
	surface.shader = water_shader
	water.material_override = surface
	add_child(water)
