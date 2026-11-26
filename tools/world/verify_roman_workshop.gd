extends SceneTree
## Load the exported GLBs. Test clear doorways and solid walls with a city capsule.
## Use -- --capture for optional local Godot viewport photos.

const VISUAL := preload("res://assets/roman_quarter/workshop/roman_workshop.glb")
const COLLISION := preload("res://assets/roman_quarter/workshop/roman_workshop_collision.glb")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(state: bool, note: String) -> void:
	checks += 1
	if not state:
		failures += 1
		printerr("ROMAN_WORKSHOP_FAIL " + note)


func _run() -> void:
	var view := VISUAL.instantiate() as Node3D
	root.add_child(view)
	var imported := COLLISION.instantiate() as Node3D
	root.add_child(imported)
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	_expect(meshes.size() == 18, "18 separate collision hulls")
	for record: MeshInstance3D in meshes:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = record.mesh.create_trimesh_shape()
		body.add_child(collider)
		root.add_child(body)
		body.global_transform = record.global_transform
	imported.free()
	var player := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.55
	collider.shape = capsule
	player.add_child(collider)
	player.collision_layer = 2
	root.add_child(player)
	await physics_frame
	await physics_frame
	var room_x := 3.62
	for z: float in [-2.4, 2.4]:
		var approach := Transform3D(Basis.IDENTITY, Vector3(-.8, .80, z))
		_expect(not player.test_move(approach, Vector3(4.42,0,0)), "open street entrance Z=%s" % z)
		var inside := Transform3D(Basis.IDENTITY, Vector3(room_x,.81,z))
		_expect(player.test_move(inside, Vector3(0,-.3,0)), "both rooms have floor collision")
	var sealed := Transform3D(Basis.IDENTITY, Vector3(-.8,.80,0))
	_expect(player.test_move(sealed, Vector3(1.5,0,0)), "central street wall is solid")
	var forge := Transform3D(Basis.IDENTITY, Vector3(3.85,.81,-3.36))
	_expect(player.test_move(forge, Vector3(1.5,0,0)), "forge hearth blocks the capsule")
	var counter := Transform3D(Basis.IDENTITY, Vector3(3.66,.81,2.80))
	_expect(player.test_move(counter, Vector3(1.5,0,0)), "wine counter blocks the capsule")
	for label in ["Workshop_Front","Workshop_Enclosure","Workshop_Tegulae","Blacksmith","Taverna"]:
		var piece := view.find_child(label) as MeshInstance3D
		_expect(piece != null, label + " has a visible mesh")
		if piece == null:
			continue
		var material := piece.get_active_material(0) as StandardMaterial3D
		_expect(material != null and material.albedo_texture != null
			and material.normal_texture != null and material.roughness_texture != null,
			label + " has imported embedded base, normal and roughness PBR maps")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		camera.fov = 50
		camera.current = true
		root.add_child(camera)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, -78, 0)
		light.light_energy = 1.38
		light.shadow_enabled = true
		root.add_child(light)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("#93b8cc")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("#b8cadd")
		environment.ambient_light_energy = .73
		camera.environment = environment
		for shot: Array in [
			["front",Vector3(-8.4,4.15,-4.1),Vector3(.31,1.95,0)],
			["blacksmith",Vector3(.22,1.58,-2.05),Vector3(4.50,1.03,-2.76)],
			["taverna",Vector3(.42,1.61,2.09),Vector3(4.66,1.05,3.30)],
		]:
			camera.position = shot[1]
			camera.look_at(shot[2])
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			_expect(capture.save_png("/tmp/roman-workshop-%s.png" % shot[0]) == OK,
				String(shot[0]) + " capture written")
	print("ROMAN_WORKSHOP_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
