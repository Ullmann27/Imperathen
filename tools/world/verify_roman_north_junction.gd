extends SceneTree
## Import the whole crossing at its authored world position and walk each arm.

const VIEW := preload("res://assets/roman_quarter/north_junction/roman_north_junction.glb")
const PHYSICS := preload("res://assets/roman_quarter/north_junction/roman_north_junction_collision.glb")
const NAMES := "res://assets/roman_quarter/street_names.json"
const ORIGIN := Vector3(28.0, .125, -17.0)
var checks := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failed += 1
		printerr("ROMAN_NORTH_JUNCTION_FAIL " + note)


func _blocked(player: CharacterBody3D, x: float, z: float, travel: Vector3) -> bool:
	return player.test_move(Transform3D(Basis.IDENTITY, Vector3(x, 1.102, z)), travel)


func _run() -> void:
	var parcel := Node3D.new()
	root.add_child(parcel)
	parcel.position = ORIGIN
	var junction := VIEW.instantiate() as Node3D
	parcel.add_child(junction)
	var imported := PHYSICS.instantiate() as Node3D
	parcel.add_child(imported)
	var hulls := imported.find_children("*", "MeshInstance3D", true, false)
	_check(hulls.size() == 44, "separate street and building collision hulls")
	for source: MeshInstance3D in hulls:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = source.mesh.create_trimesh_shape()
		body.add_child(shape)
		root.add_child(body)
		body.global_transform = source.global_transform
	imported.free()
	var walker := CharacterBody3D.new()
	root.add_child(walker)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.55
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	walker.add_child(shape)
	walker.collision_layer = 2
	await physics_frame
	await physics_frame
	_check(not _blocked(walker,28,-12.78,Vector3(0,0,-11.60)),"through the existing street join toward the north")
	_check(not _blocked(walker,28,-17,Vector3(-11.5,0,0)),"unblocked west arm")
	_check(not _blocked(walker,28,-17,Vector3(11.5,0,0)),"unblocked east arm")
	for p: Vector2 in [Vector2(16.5,-17),Vector2(39.5,-17),Vector2(28,-14),Vector2(28,-23.7),Vector2(28,-25.76)]:
		_check(_blocked(walker,p.x,p.y,Vector3(0,-.24,0)),"road floor at " + str(p))
	for point: Vector2 in [Vector2(-3.98,-5.31),Vector2(3.98,-5.20),Vector2(-3.98,5.12),Vector2(3.98,5.29)]:
		var side := signf(point.x)
		var street_z := ORIGIN.z + point.y
		_check(not _blocked(walker,ORIGIN.x,street_z,Vector3(side*5.4,0,0)),
			"open ground-floor doorway at " + str(point))
		_check(_blocked(walker,ORIGIN.x+side*5.4,street_z,Vector3(0,-.21,0)),
			"shop floor at " + str(point))
		_check(_blocked(walker,ORIGIN.x+side*5.4,street_z,Vector3(side*4.8,0,0)),
			"shop back wall at " + str(point))
	for label in ["Kreuzung_Pflaster_und_Gehwege","Figlina","Lanificium","Apotheca","TabernaSeptentrionalis"]:
		var part := junction.find_child(label) as MeshInstance3D
		_check(part != null, label + " geometry imported")
		if part != null:
			var paint := part.get_active_material(0) as StandardMaterial3D
			_check(paint != null and paint.albedo_texture != null and paint.normal_texture != null
				and paint.roughness_texture != null, label + " retains baked PBR maps")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NAMES))
	_check(index.schema_version == 1 and index.streets.size() == 3, "three named street rectangles")
	_check(index.streets[0].id == "vicus_figulorum", "crossing precedence belongs to the transverse street")
	for street: Dictionary in index.streets:
		_check(street.status == "fiktiv" and not str(street.name_de).is_empty()
			and street.width > 0 and street.depth > 0, "named, marked fictional street " + str(street.id))
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture()
	print("ROMAN_NORTH_JUNCTION_%s checks=%d failures=%d" % ["PASS" if failed == 0 else "FAIL",checks,failed])
	quit(0 if failed == 0 else 1)


func _capture() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.fov = 48
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 26, 0)
	sun.light_energy = .95
	sun.shadow_enabled = true
	root.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9ab0ba")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ddd5c7")
	environment.ambient_light_energy = .64
	camera.environment = environment
	for shot: Array in [
			["gasse",Vector3(28.4,2.65,-9.36),Vector3(28.5,1.79,-20.4)],
			["kreuzung",Vector3(38.6,10.2,-10.7),Vector3(26.7,0.31,-17.75)],
			["schild",Vector3(26.5,1.84,-16.3),Vector3(22.23,2.54,-19.59)],
	]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for frame in range(3):
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png("/tmp/roman-north-" + String(shot[0]) + ".png") == OK,
			String(shot[0]) + " viewport image written")
