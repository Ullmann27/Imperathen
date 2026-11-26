extends Node3D
## Weidenhof, a fictional inhabited stop alongside the existing quarry road.
## The village economy owns the shipment, grain and payment. Rendering follows its route.
const Freight = preload("res://scripts/domain/regional_freight.gd")
const Region = preload("res://scripts/world/world_stream_plan.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const ASSETS := "res://assets/world/waystation/"
const HORSE := "res://assets/horse/valdora_horse_rig.glb"
const COUNTER := Vector2(241,119)
const NEAR := 128.0
var _yard: Node3D
var _depot: Node3D
var _load: Node3D
var _animator: AnimationPlayer
var _height: Callable
var _wagon: AnimatableBody3D
var _wheels: Array[Node3D] = []


static func at_counter(player: Vector3) -> bool:
	return Vector2(player.x,player.z).distance_to(COUNTER) <= 2.8

func setup(height: Callable) -> void:
	_height = height
	position = Vector3(COUNTER.x,height.call(COUNTER),COUNTER.y)

func update_nearby(player: Vector3, receipt: Dictionary, delta := 1.0) -> void:
	var p := Vector2(player.x,player.z)
	if p.distance_to(COUNTER) < NEAR and not is_instance_valid(_yard):
		_yard = Node3D.new()
		_yard.name = "Yard"
		add_child(_yard)
		_build()
	elif p.distance_to(COUNTER) > NEAR+60.0 and is_instance_valid(_yard):
		_yard.free()
	if p.distance_to(Freight.DEPOT) < NEAR and not is_instance_valid(_depot):
		_depot = _asset(ASSETS+"freight_table.glb",self)
		_depot.name = "EastGateReceivingDesk"
		_depot.position = _ground(Freight.DEPOT-COUNTER)
		_block_table(_depot)
	elif p.distance_to(Freight.DEPOT) > NEAR+60.0 and is_instance_valid(_depot):
		_depot.free()
	var pose := Freight.pose(receipt)
	var here: Vector2 = pose.position
	if p.distance_to(here) < NEAR:
		var spawned := not is_instance_valid(_wagon)
		if spawned:
			_build_wagon()
		_drive(pose,receipt,delta,spawned)
	elif is_instance_valid(_wagon) and p.distance_to(here) > NEAR+60.0:
		_wagon.free()
		_wheels.clear()


func _block_table(table: Node3D) -> void:
	var solid := StaticBody3D.new()
	table.add_child(solid)
	_box(solid,Vector3(1.65,.8,.81),Vector3(0,.4,0))

func _ground(offset: Vector2) -> Vector3:
	return Vector3(offset.x,float(_height.call(COUNTER + offset))-position.y,offset.y)

func _asset(path: String, parent: Node3D) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(node)
	return node

func _place(asset: String, offset: Vector2, angle: float, solid := false) -> Node3D:
	var model := _asset(ASSETS + asset + ".glb",_yard)
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
			var art := _asset(path,_yard)
			art.position = _ground(prop[1])
	var vendor := Person.new()
	vendor.name = "Tertia"
	vendor.set_meta("actor_uid","road:weidenhof_tertia")
	_yard.add_child(vendor)
	vendor.position = _ground(Vector2(0,3.1))
	vendor.configure_resident("italia",39,"civilian_woman",7,null,"road:weidenhof_tertia")
	var desk := _place("freight_table",Freight.DESK-COUNTER,0)
	_block_table(desk)
	_build_grove()
	_build_spring()
	_build_verge()

func _build_wagon() -> void:
	_wagon = AnimatableBody3D.new()
	_wagon.name = "FreightWagon"
	_wagon.sync_to_physics = false
	add_child(_wagon)
	_asset(ASSETS+"cart.glb",_wagon)
	_load = _asset(ASSETS+"grain_load.glb",_wagon)
	_load.name = "SixGrainSacks"
	_box(_wagon,Vector3(1.52,1.12,1.9),Vector3(0,.72,0))
	for sign_x: int in [-1,1]:
		var wheel := _asset(ASSETS+"cart_wheel.glb",_wagon)
		wheel.position = Vector3(sign_x*.77,.53,-.16)
		_wheels.append(wheel)
	var horse := _asset(HORSE,_wagon)
	horse.position.z = 2.4
	horse.rotation.y = PI
	_box(_wagon,Vector3(.76,1.5,1.9),Vector3(0,.75,2.4))
	_animator = horse.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	_animator.get_animation("walk").loop_mode = Animation.LOOP_LINEAR
	_animator.play("walk")

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
	var trunks := StaticBody3D.new()
	trunks.name = "WillowTrunks"
	_yard.add_child(trunks)
	var trunk := CylinderShape3D.new()
	trunk.height = 2.0
	trunk.radius = .19
	for t in transforms:
		var solid := CollisionShape3D.new()
		solid.shape = trunk
		solid.position = t.origin + Vector3.UP
		trunks.add_child(solid)
	var stand := MultiMeshInstance3D.new()
	stand.name = "WillowGroves"
	stand.multimesh = trees
	_yard.add_child(stand)

func _drive(pose: Dictionary, receipt: Dictionary, delta: float, spawned: bool) -> void:
	var here: Vector2 = pose.position
	var direction: Vector2 = pose.direction
	var ground := _ground(here-COUNTER)
	_wagon.position = ground if spawned else _wagon.position.move_toward(ground,Freight.SPEED * 1.25 * delta)
	_wagon.rotation.y = atan2(direction.x,direction.y)
	var grade := float(_height.call(here + direction)) - float(_height.call(here-direction))
	_wagon.rotation.x = -atan2(grade,2.0)
	_load.visible = pose.loaded
	_animator.speed_scale = 1.0 if pose.moving else 0.0
	var metres := float(receipt.get("metres",0.0))
	for wheel in _wheels:
		wheel.rotation.x = metres/.52


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
	_yard.add_child(water)

func _build_verge() -> void:
	var template := (load(ASSETS+"verge.glb") as PackedScene).instantiate()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = (template.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D).mesh
	template.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12732
	var patches: Array[Transform3D] = []
	for i in 550:
		var offset := Vector2(rng.randf_range(-21,23),rng.randf_range(-22,24))
		# Keep the approach to the shop, cart circuit and buildings clear.
		if absf(offset.x) < 12 and offset.y > -15.0 and offset.y < 13.0:
			continue
		var size_factor := rng.randf_range(.7,1.5)
		patches.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*size_factor),_ground(offset)))
	batch.instance_count = patches.size()
	for i in patches.size():
		batch.set_instance_transform(i,patches[i])
	var verge := MultiMeshInstance3D.new()
	verge.name = "RoadsideHerbs"
	verge.multimesh = batch
	verge.visibility_range_end = 74.0
	_yard.add_child(verge)
