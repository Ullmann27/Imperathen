extends SceneTree
const Fires := preload("res://scripts/rendering/route_fire_lights.gd")
const Look := preload("res://scripts/rendering/village_look.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(180,0.2,180)
	collision.shape = box
	floor.add_child(collision)
	world.add_child(floor)
	floor.position.y = -0.1
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,2,0)
	camera.current = true
	var fire := Fires.new()
	world.add_child(fire)
	var points: Array[Vector3] = [Vector3(0,0,-4),Vector3(10,0,-4),Vector3(-10,0,-4),Vector3(0,0,8)]
	fire.configure(points, "balanced")
	for i in 4:
		await physics_frame
	check(fire.sites.size() == 4,"All four grounded road fixtures are instantiated")
	check(fire.find_children("*","CollisionObject3D",true,false).is_empty(),"No road fixture changes collision authority")
	check(Fires.village_candidates().size() >= 12,"Valdora has distributed route candidates")
	check(Fires.city_candidates().size() >= 20,"Rome uses authored street anchors")
	fire.set_darkness(1.0)
	fire._process(0.25)
	check(fire._flames != null and fire._flames.visible,"Night flame geometry visible")
	var count := 0
	for light: OmniLight3D in fire._pool:
		if light.visible and light.light_energy > 0.0:
			count += 1
	check(count == 2,"Balanced profile limits actual illuminating lights")
	fire.set_darkness(0.0)
	check(not fire._flames.visible,"Flames disappear during day")
	for light: OmniLight3D in fire._pool:
		check(not light.visible,"Day does not waste point lights")
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	var env := Environment.new()
	var night := Look.apply_solar_time(22.0,0,sun,env,null)
	check(night > .95 and env.ambient_light_energy >= .14,"Night retains restrained readable fill")
	world.free()
	print("ROUTE_FIRE_PASS" if failures == 0 else "ROUTE_FIRE_FAIL")
	quit(0 if failures == 0 else 1)
