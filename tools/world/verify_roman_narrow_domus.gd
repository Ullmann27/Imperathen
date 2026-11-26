extends SceneTree
## Verify the paired glTF exports rotated as in the street assembly.

const VIEW := preload("res://assets/roman_quarter/workshop/roman_narrow_domus.glb")
const PHYSICS := preload("res://assets/roman_quarter/workshop/roman_narrow_domus_collision.glb")
var checks := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		printerr("ROMAN_DOMUS_FAIL " + note)


func _run() -> void:
	var parcel := Node3D.new()
	root.add_child(parcel)
	parcel.position = Vector3(23.5, .285, 2.9)
	parcel.rotation.y = PI
	var house := VIEW.instantiate() as Node3D
	parcel.add_child(house)
	var imported := PHYSICS.instantiate() as Node3D
	parcel.add_child(imported)
	var meshes := imported.find_children("*","MeshInstance3D",true,false)
	_check(meshes.size() == 12, "12 compact physical hulls")
	for proxy: MeshInstance3D in meshes:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = proxy.mesh.create_trimesh_shape()
		body.add_child(collider)
		root.add_child(body)
		body.global_transform = proxy.global_transform
	imported.free()
	var player := CharacterBody3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.55
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	player.add_child(shape)
	player.collision_layer = 2
	root.add_child(player)
	await physics_frame
	await physics_frame
	for z: float in [4.9, .8]:
		var street := Transform3D(Basis.IDENTITY, Vector3(24.40,1.085,z))
		_check(not player.test_move(street,Vector3(-4.60,0,0)), "street entrance passable at Z " + str(z))
		var inside := Transform3D(Basis.IDENTITY, Vector3(19.80,1.085,z))
		_check(player.test_move(inside,Vector3(0,-.25,0)), "interior floor solid")
		_check(player.test_move(inside,Vector3(-2,0,0)), "rear wall solid")
	var blocked := Transform3D(Basis.IDENTITY, Vector3(24.40,1.085,2.9))
	_check(player.test_move(blocked,Vector3(-2.2,0,0)), "middle facade solid")
	for label in ["Domus_StreetFront","Domus_UpperFloor","Domus_Enclosure","Domus_Roof","Domus_ShopandVestibule"]:
		var piece := house.find_child(label) as MeshInstance3D
		_check(piece != null, label + " present")
		if piece != null:
			var material := piece.get_active_material(0) as StandardMaterial3D
			_check(material != null and material.albedo_texture != null
				and material.normal_texture != null and material.roughness_texture != null,
				label + " has imported PBR textures")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.fov = 49
		camera.position = Vector3(33.5,5.2,8.9)
		camera.look_at(Vector3(22.65,3.0,2.9))
		camera.current = true
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-44,100,0)
		sun.light_energy = 1.09
		sun.shadow_enabled = true
		root.add_child(sun)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("#8aaaba")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("#dbd2bf")
		environment.ambient_light_energy = .62
		camera.environment = environment
		for frame in range(3):
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png("/tmp/roman-narrow-domus.png") == OK,"viewport image saved")
	print("ROMAN_DOMUS_%s checks=%d failures=%d" % ["PASS" if failed == 0 else "FAIL",checks,failed])
	quit(0 if failed == 0 else 1)
