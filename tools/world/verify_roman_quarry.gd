extends SceneTree
## Import the actual GLBs. The fixture plane matches the agreed terrain tangent.

const VISUAL := preload("res://assets/world/road_landmarks/old_quarry.glb")
const PHYSICS := preload("res://assets/world/road_landmarks/old_quarry_collision.glb")
var checks := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, lesson: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("ROMAN_QUARRY_FAIL " + lesson)


func _terrain_vertex(x: float, z: float) -> Vector3:
	return Vector3(x, .029 * x + .057 * z - .04, z)


func _body(shape: Shape3D, basis: Transform3D) -> void:
	var stone := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	stone.add_child(collider)
	root.add_child(stone)
	stone.global_transform = basis


func _ground() -> void:
	var floor_points := PackedVector3Array([
		_terrain_vertex(-14,-17), _terrain_vertex(-14,17), _terrain_vertex(25,-17),
		_terrain_vertex(-14,17), _terrain_vertex(25,17), _terrain_vertex(25,-17),
	])
	var floor_mesh := SurfaceTool.new()
	floor_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in floor_points:
		floor_mesh.add_vertex(point)
	floor_mesh.generate_normals()
	var existing_surface := MeshInstance3D.new()
	existing_surface.mesh = floor_mesh.commit()
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("#6f6c45")
	earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	existing_surface.material_override = earth
	root.add_child(existing_surface)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(floor_points)
	_body(shape,Transform3D.IDENTITY)


func _blocked(walker: CharacterBody3D, x: float, z: float, travel: Vector3) -> bool:
	var start := _terrain_vertex(x,z) + Vector3.UP * .87
	return walker.test_move(Transform3D(Basis.IDENTITY, start), travel)


func _run() -> void:
	_ground()
	var quarry := VISUAL.instantiate() as Node3D
	root.add_child(quarry)
	var imported := PHYSICS.instantiate() as Node3D
	root.add_child(imported)
	var hulls := imported.find_children("*","MeshInstance3D",true,false)
	_check(hulls.size() == 15, "separate physical objects without a footprint blocker")
	for source: MeshInstance3D in hulls:
		_body(source.mesh.create_trimesh_shape(), source.global_transform)
	imported.free()
	var player := CharacterBody3D.new()
	root.add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.55
	collider.shape = capsule
	player.add_child(collider)
	player.collision_layer = 2
	await physics_frame
	await physics_frame
	for lane: float in [-2.25,0.,2.25]:
		_check(not _blocked(player,-4,lane,Vector3(14.85,.029*14.85,0)),
			"arrival and quarry work area stay open across lane " + str(lane))
	_check(_blocked(player,10.2,0,Vector3(4.6,.029*4.6,0)),"main limestone face blocks the capsule")
	_check(_blocked(player,2.00,-5.54,Vector3(2.2,.029*2.2,0)),"a dressed limestone block is solid")
	_check(not _blocked(player,4.1,7.20,Vector3(4.6,.029*4.6,0)),
		"open-front shelter is accessible past its posts")
	_check(_blocked(player,9.2,7.20,Vector3(2.0,.029*2.0,0)),"shelter rear planks block the capsule")
	for name in ["Quarry_RockBenches","Quarry_DressedStone","Quarry_Shelter","Quarry_Rubble"]:
		var part := quarry.find_child(name) as MeshInstance3D
		_check(part != null, name + " imported")
		if part == null:
			continue
		var material := part.get_active_material(0) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null
			and material.normal_texture != null and material.roughness_texture != null,
			name + " uses embedded PBR textures")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture()
	print("ROMAN_QUARRY_%s checks=%d failures=%d" % ["PASS" if failed == 0 else "FAIL",checks,failed])
	quit(0 if failed == 0 else 1)


func _capture() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(-9.4,4.2,-7.25)
	camera.look_at(Vector3(9.22,1.35,.4))
	camera.current = true
	camera.fov = 49
	var sunrise := DirectionalLight3D.new()
	sunrise.rotation_degrees = Vector3(-47, -77, 0)
	sunrise.light_energy = 1.04
	sunrise.shadow_enabled = true
	root.add_child(sunrise)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#a8c0c9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d6ded0")
	environment.ambient_light_energy = .68
	camera.environment = environment
	for frame in range(3):
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image.save_png("/tmp/roman-old-quarry.png") == OK,"local viewport image written")
