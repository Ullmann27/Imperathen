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
	# The nearest player light is guaranteed, even when route samples rank another.
	fire.set_route_context(Vector3(0,0,-4),PackedVector2Array([Vector2(10,-4)]))
	fire._process(0.25)
	check(fire._pool[0].global_position.is_equal_approx(Vector3(0,1.46,-4)),"Closest player fixture remains the first light")
	check(fire._pool[1].global_position.is_equal_approx(Vector3(10,1.46,-4)),"Second light follows the actual route")
	fire.set_route_context(Vector3.INF,PackedVector2Array())
	check(not fire._route_player.is_finite() and fire._route_samples.is_empty(),"Invalid route clears its previous player anchor and samples")
	fire._process(0.25)
	check(fire._pool[0].global_position.is_equal_approx(Vector3(0,1.46,-4)),"Invalid route restores camera-nearest fixture")
	fire.set_quality("low")
	check(not fire._pool[1].visible,"Lower quality immediately disables excess lights")
	var previous_holder: WeakRef = weakref(fire._holders)
	var previous_flames: WeakRef = weakref(fire._flames)
	var previous_light: WeakRef = weakref(fire._pool[0])
	check(previous_holder.get_ref() == fire._holders and previous_flames.get_ref() == fire._flames and previous_light.get_ref() == fire._pool[0],"Weak references identify the original live visual nodes before replacement")
	var replacement: Array[Vector3] = [Vector3(20,0,0),Vector3(30,0,0)]
	fire.configure(replacement,"high")
	check(previous_holder.get_ref() == null and previous_flames.get_ref() == null and previous_light.get_ref() == null,"Reconfiguration releases previous batches and light pool")
	check(fire.sites.is_empty() and not fire._installed,"Reconfiguration clears old fixture locations")
	for i in 4:
		await physics_frame
	check(fire.sites.size() == 2 and fire._pool.size() == Fires.MAX_LIGHTS,"Replacement installation has exactly two grounded fixtures and bounded pool")
	check(fire.get_child_count() == Fires.MAX_LIGHTS+2,"Reconfiguration does not duplicate visual nodes")
	check(fire._flames.visible,"Night state survives replacement installation")
	fire.set_route_context(Vector3(20,0,0),PackedVector2Array([Vector2(30,0)]))
	fire._process(0.25)
	check(fire._pool[0].global_position.is_equal_approx(Vector3(20,1.46,0)),"New installation lights the replacement sites")
	fire.set_darkness(0.0)
	check(not fire._flames.visible,"Flames disappear during day")
	for light: OmniLight3D in fire._pool:
		check(not light.visible,"Day does not waste point lights")
	var empty: Array[Vector3] = []
	fire.configure(empty,"balanced")
	for i in 4:
		await physics_frame
	check(fire.sites.is_empty() and fire._pool.is_empty() and fire.get_child_count() == 0,"Empty replacement removes all former visuals")
	var detached := Fires.new()
	detached.configure(points,"balanced")
	detached._physics_process(0.016)
	check(not detached._installed and detached.sites.is_empty(),"Detached installation waits for a real physics world")
	detached.free()
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	var env := Environment.new()
	var night := Look.apply_solar_time(22.0,0,sun,env,null)
	check(night > .95 and env.ambient_light_energy >= .14,"Night retains restrained readable fill")
	world.free()
	print("ROUTE_FIRE_PASS" if failures == 0 else "ROUTE_FIRE_FAIL")
	quit(0 if failures == 0 else 1)
