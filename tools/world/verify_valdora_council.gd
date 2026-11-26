extends SceneTree
## Verify the authored walk-in model and the collision shapes at the same origin.

const VISUAL := preload("res://assets/politics/council/valdora_council.glb")
const PHYSICS := preload("res://assets/politics/council/valdora_council_collision.glb")
var count := 0
var failed := 0


func _initialize() -> void:
	_play.call_deferred()


func _check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed += 1
		printerr("VALDORA_COUNCIL_FAIL " + label)


func _blocked(actor: CharacterBody3D, at: Vector3, delta: Vector3) -> bool:
	return actor.test_move(Transform3D(Basis.IDENTITY, at), delta)


func _play() -> void:
	var scene := VISUAL.instantiate() as Node3D
	root.add_child(scene)
	var imported := PHYSICS.instantiate() as Node3D
	root.add_child(imported)
	var proxies := imported.find_children("*", "MeshInstance3D", true, false)
	_check(proxies.size() == 17, "separate collision hulls imported")
	for proxy: MeshInstance3D in proxies:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = proxy.mesh.create_trimesh_shape()
		body.add_child(collider)
		root.add_child(body)
		body.global_transform = proxy.global_transform
	imported.free()
	var actor := CharacterBody3D.new()
	root.add_child(actor)
	actor.collision_layer = 2
	var capsule := CapsuleShape3D.new()
	capsule.radius = .24
	capsule.height = 1.55
	var capsule_shape := CollisionShape3D.new()
	capsule_shape.shape = capsule
	actor.add_child(capsule_shape)
	await physics_frame
	await physics_frame
	_check(not _blocked(actor,Vector3(-.9,.815,0),Vector3(6.20,0,0)),"open entrance and central room remain passable")
	_check(_blocked(actor,Vector3(2.8,.815,0),Vector3(0,-.27,0)),"interior has a solid floor")
	_check(_blocked(actor,Vector3(-.9,.815,1.83),Vector3(2.0,0,0)),"front wall beside doorway is solid")
	_check(_blocked(actor,Vector3(3.4,.815,1.93),Vector3(1.6,0,0)),"record table is solid")
	_check(_blocked(actor,Vector3(3.2,.815,-2.01),Vector3(0,0,-1.5)),"waiting bench is solid")
	for side: float in [-1.,1.]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(2.27,1.91,side*4.16),
			Vector3(2.27,1.91,side*2.67),1)
		_check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),
			"side window is a real opening on "+str(side))
	var open_door := scene.find_child("CouncilDoorLeaf_Open") as Node3D
	_check(open_door != null and open_door.position.distance_to(Vector3(.19,.032,-.818)) < .002
		and open_door.basis.z.normalized().dot(Vector3.RIGHT) > .99,
		"hinge and 90 degree open-door transform are preserved")
	for label in ["CouncilFacade","CouncilRoom","CouncilTileRoof","CouncilFurnishings","CouncilDoorLeaf_Open"]:
		var part := scene.find_child(label) as MeshInstance3D
		_check(part != null, label + " visible in Godot")
		if part == null:
			continue
		var material := part.get_active_material(0) as StandardMaterial3D
		_check(material != null and material.albedo_texture != null
			and material.normal_texture != null and material.roughness_texture != null, label + " has PBR maps")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await _capture()
	print("VALDORA_COUNCIL_%s checks=%d failures=%d" % ["PASS" if failed == 0 else "FAIL",count,failed])
	quit(0 if failed == 0 else 1)


func _capture() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 46
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32,-64,0)
	sun.light_energy = .91
	sun.shadow_enabled = true
	root.add_child(sun)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9cb4bf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d8d2b8")
	environment.ambient_light_energy = .81
	camera.environment = environment
	for shot: Array in [
		["vorne",Vector3(-7.9,3.30,5.8),Vector3(2.11,1.65,0.0)],
		["innen",Vector3(2.08,1.80,.25),Vector3(4.28,1.15,1.18)],
	]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		for frame in range(3):
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png("/tmp/valdora-council-" + String(shot[0]) + ".png") == OK,
			String(shot[0]) + " capture written")
