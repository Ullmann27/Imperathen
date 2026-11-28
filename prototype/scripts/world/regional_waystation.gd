extends Node3D
## Weidenhof, a fictional inhabited stop alongside the existing quarry road.
## The village economy owns the shipment, grain and payment. Rendering follows its route.
const Freight = preload("res://scripts/domain/regional_freight.gd")
const Region = preload("res://scripts/world/world_stream_plan.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const WorkshopLibrary = preload("res://scripts/world_expansion/asset_library.gd")
const WorkshopView = preload("res://scripts/world_expansion/settlement_view.gd")
const WORKSHOP_MANIFEST := "res://assets/world_expansion/manifest.json"
# One of each authored plant, not a second settlement or autonomous simulation.
const WORKSHOP_PLANTS := ["field_elm", "cypress", "laurel"]
const WORKSHOP_CLEARANCE_M: float = 7.0
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
var _workshop_grove: Node3D
var _workshop_wind_tick: float = 0.0


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
	_box(solid, Vector3(Freight.TABLE_FOOTPRINT.x, 0.8, Freight.TABLE_FOOTPRINT.y), Vector3(0, 0.4, 0))

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
	# Replace three existing safe tree sites, rather than adding geometry to
	# the cart circuit or covering the historically authored shop entrance.
	var replaced: Array[int] = _build_workshop_grove(transforms)
	var remaining: Array[Transform3D] = []
	for index: int in transforms.size():
		if index not in replaced:
			remaining.append(transforms[index])
	transforms = remaining
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

# Preserve the same physical waypoint and freight graph. Only use sites
# already selected by the original seeded willow placement.
func _workshop_site_clear(at: Vector2, occupied: Array[Vector2]) -> bool:
	var links: Array = []
	for i: int in range(1,Footpath.WAYPOINTS.size()):
		links.append([Footpath.WAYPOINTS[i-1],Footpath.WAYPOINTS[i]])
	links.append([Footpath.WAYPOINTS[2],COUNTER])
	for i: int in range(1,Freight.POINTS.size()):
		links.append([Freight.POINTS[i-1],Freight.POINTS[i]])
	for segment: Array in links:
		if Geometry2D.get_closest_point_to_segment(at,segment[0],segment[1]).distance_to(at) < WORKSHOP_CLEARANCE_M:
			return false
	if at.distance_to(COUNTER) < 20.0:
		return false
	if ((at-Region.SPRING)/Region.SPRING_RADII).length() < 1.25:
		return false
	for other: Vector2 in occupied:
		if other.distance_to(at) < 10.0:
			return false
	return true


# Actual lower woody vertices from the original mesh, not a collision box
# around the foliage. Bake the instance basis into the convex trunk.
func _workshop_trunk(mesh: Mesh, basis: Basis, radius: float) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		if colors.size() != vertices.size():
			continue
		for index: int in vertices.size():
			var v: Vector3 = vertices[index]
			# Source authoring defines elm base 0.53 m / cypress 0.30 m.
			# Exclude canopy, leaf flutter vertices and far root tips.
			if v.y >= -0.001 and v.y <= 1.65 and Vector2(v.x,v.z).length() <= radius and colors[index].g <= 0.00001:
				points.append(basis*v)
	if points.size() < 12:
		return null
	var lo: Vector3 = points[0]
	var hi: Vector3 = points[0]
	for point: Vector3 in points:
		lo = lo.min(point)
		hi = hi.max(point)
	if hi.y-lo.y < 0.7 or hi.x-lo.x < 0.12 or hi.z-lo.z < 0.12:
		return null
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


func _build_workshop_grove(transforms: Array[Transform3D]) -> Array[int]:
	var selected: Array[int] = []
	var occupied: Array[Vector2] = []
	# Keep the existing willow grove and its normal runtime test >35 trees.
	if transforms.size() < 39:
		return selected
	for index: int in transforms.size():
		var p: Vector3 = transforms[index].origin
		var at: Vector2 = COUNTER + Vector2(p.x,p.z)
		if _workshop_site_clear(at,occupied):
			selected.append(index)
			occupied.append(at)
		if selected.size() == WORKSHOP_PLANTS.size():
			break
	if selected.size() != WORKSHOP_PLANTS.size():
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WORKSHOP_MANIFEST))
	if not parsed is Dictionary:
		push_warning("WorldWorkshop source manifest unavailable at Weidenhof")
		return []
	var definitions: Array = []
	for definition: Dictionary in parsed.get("vegetation_assets",[]):
		if str(definition.get("id","")) in WORKSHOP_PLANTS:
			definitions.append(definition)
	if definitions.size() != WORKSHOP_PLANTS.size():
		return []
	var library: RefCounted = WorkshopLibrary.new()
	if not library.load_manifest_assets({"building_assets":[],"road_assets":[],"vegetation_assets":definitions}):
		push_warning("Weidenhof workshop plant import failed")
		return []
	var plan: Dictionary = {"ok":true,"buildings":[],"roads":[],"vegetation":[],"building_count":0,"unique_building_modules":0}
	var colliders: Array[CollisionShape3D] = []
	for i: int in selected.size():
		var id: String = WORKSHOP_PLANTS[i]
		var original: Transform3D = transforms[selected[i]]
		var scale_factor: float = clampf(original.basis.x.length(),0.65,0.95)
		var yaw: float = original.basis.orthonormalized().get_euler().y
		var pose_basis: Basis = Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_factor)
		plan.vegetation.append({"asset":id,"position":original.origin,"yaw":yaw,"scale":scale_factor})
		if id == "laurel":
			# Low flexible brush, like the existing roadside herbs: no solid wall.
			continue
		var near_mesh: Mesh = library.assets[id].meshes[0]
		var shape: ConvexPolygonShape3D = _workshop_trunk(near_mesh,pose_basis,0.62 if id=="field_elm" else 0.38)
		if shape == null:
			for previous: CollisionShape3D in colliders:
				previous.free()
			push_warning("Weidenhof workshop trunk could not be derived: "+id)
			return []
		var collision := CollisionShape3D.new()
		collision.name = id + "_Trunk"
		collision.shape = shape
		collision.position = original.origin
		collision.set_meta("workshop_asset",id)
		colliders.append(collision)
	var view: Node3D = WorkshopView.new()
	view.name = "WorkshopGrove"
	_yard.add_child(view)
	var result: Dictionary = view.populate(plan,library)
	if not bool(result.get("ok",false)):
		view.free()
		for collision: CollisionShape3D in colliders:
			collision.free()
		return []
	var solid := StaticBody3D.new()
	solid.name = "WorkshopTreeTrunks"
	solid.collision_layer = 1
	solid.collision_mask = 0
	_yard.add_child(solid)
	for collision: CollisionShape3D in colliders:
		solid.add_child(collision)
	_workshop_grove = view
	_workshop_wind_tick = 0.0
	return selected


func _update_workshop_grove(player: Vector3, profile: String, phase: float, wind: float, delta: float) -> void:
	if not is_instance_valid(_workshop_grove) or not player.is_finite() or not is_finite(phase) or not is_finite(wind):
		return
	if profile != _workshop_grove.profile:
		_workshop_grove.set_quality(profile)
		_workshop_grove.refresh_all(to_local(player))
	_workshop_wind_tick -= maxf(delta,0.0)
	if _workshop_wind_tick > 0.0:
		return
	_workshop_wind_tick = 0.05
	_workshop_grove.refresh_budgeted(to_local(player))
	# Existing world presentation clock and local weather remain authoritative.
	for material: ShaderMaterial in _workshop_grove.asset_library.wind_materials:
		material.set_shader_parameter("wind_time",phase)
		material.set_shader_parameter("wind_strength",clampf(wind*0.6,0.0,2.0))


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
