extends SceneTree
## Actual CityLife routes and streamed production residents on a physical floor.
## The schedule reproduces the sixty-second loading wait from CityLife._haul_step;
## fixture placement is explicit, not a claim that a whole delivery was simulated.
const Life := preload("res://scripts/domain/city_life.gd")
const View := preload("res://scripts/world/city_resident_view.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("CITY_RESIDENT_DEPARTURE_FAIL ", label)
	return condition

func _horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _run() -> void:
	var life := Life.new()
	if not _check(life.found(20261126,Calendar.campaign_start_jdn(),4*3600), "Actual city population and authored route graph load"):
		_finish()
		return
	var person := -1
	for id in life.state.residents.size():
		if life.state.residents[id].role == "porter" and life.age(life.state.residents[id]) >= 18:
			person = id
			break
	if not _check(person >= 0,"Actual adult porter from the city roster"):
		_finish()
		return
	var resident: Dictionary = life.state.residents[person]
	var origin: String = resident.at
	var source: Vector3 = life.index.anchors[origin].position
	var destination := ""
	for business: Dictionary in life.state.businesses:
		var candidate: String = business.queue
		var point: Vector3 = life.index.anchors[candidate].position
		if _horizontal(source,point) > 18.0:
			destination = candidate
			break
	if not _check(not destination.is_empty(),"Existing distant business queue, not fabricated coordinates"):
		_finish()
		return
	var start_time := int(life.state.t)
	resident.prev = origin
	resident.at = destination
	resident.slot = 0
	resident.act = "haul"
	resident.dep = start_time+60
	resident.arr = int(resident.dep)+120
	resident.until = int(resident.arr)+120
	resident.with = -1
	resident.bag = {"oil":1}

	var stage := Node3D.new()
	root.add_child(stage)
	stage.position = Vector3(250.0,0.0,-210.0)
	stage.rotation.y = .6
	var view := View.new()
	stage.add_child(view)
	view.set_physics_process(false)
	var observer_parent := Node3D.new()
	root.add_child(observer_parent)
	observer_parent.position = Vector3(-300.0,0.0,260.0)
	var observer := CharacterBody3D.new()
	observer_parent.add_child(observer)
	view.setup(life,observer,null,"low")
	var start: Vector3 = life.position_of(person,start_time)
	var finish: Vector3 = life.slot_position(destination,0)
	_check(start.is_equal_approx(source),"Domain route stays at source during loading")
	_check(_horizontal(start,finish)>18.0,"Premature destination would exceed the six-metre re-stream guard")
	for offset in [0,1,30,58,59]:
		var now := start_time+offset
		_check(not life.is_walking(person,now),"Loading is not walking at %ds" % offset)
		_check(view._target(person,now).is_equal_approx(start),"Presentation remains at actual source at %ds" % offset)
	var departure := int(resident.dep)
	var arrival := int(resident.arr)
	_check(life.is_walking(person,departure),"Authoritative departure opens the route")
	_check(view._target(person,departure).is_equal_approx(life.position_of(person,departure+1)),"Next route sample starts only after departure")
	_check(view._target(person,departure+1).is_equal_approx(life.position_of(person,departure+2)),"Walking follows the existing street route")
	_check(view._target(person,arrival-1).is_equal_approx(finish),"Final walking sample is the actual destination")
	_check(view._target(person,arrival).is_equal_approx(finish),"Arrival uses the existing slot")
	_check(view._target(person,arrival+1).is_equal_approx(finish),"Standing stays at destination")

	var world_start := view.to_global(start)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50.0,.2,50.0)
	collider.shape = box
	floor.add_child(collider)
	root.add_child(floor)
	floor.global_position = world_start-Vector3.UP*.1
	observer.global_position = world_start+Vector3(0,0,3)
	await physics_frame
	await physics_frame
	if not _check(view._materialize(person,resident,start),"Actual floor ray and capsule fit work in a translated, rotated city"):
		stage.free()
		observer_parent.free()
		floor.free()
		_finish()
		return
	var actor: CharacterBody3D = view.actors[person]
	var identity := actor.get_instance_id()
	_check(_horizontal(actor.global_position,world_start)<.005,"Spawn applies the city transform exactly once")
	_check(absf(actor.global_position.y-world_start.y)<.01,"Physical feet stand on the measured floor")
	_check(actor.get_node("Figure").body != null,"Real imported resident figure exists")
	var world_before := actor.global_position
	for offset in [0,30,59]:
		life.state.t = start_time+offset
		var snapshot := JSON.stringify(life.state)
		await physics_frame
		view._physics_process(1.0/60.0)
		if not _check(view.actors.has(person) and is_instance_valid(actor) and actor.get_instance_id()==identity,"Loading does not retire or respawn the actual actor"):
			stage.free()
			observer_parent.free()
			floor.free()
			_finish()
			return
		_check(_horizontal(actor.global_position,world_before)<.01,"No premature travel while cargo is being loaded")
		_check(JSON.stringify(life.state)==snapshot,"Presentation never writes the authoritative city ledger")
	life.state.t = departure
	var snapshot := JSON.stringify(life.state)
	var target_world := view.to_global(view._target(person,departure))
	var before := actor.global_position
	await physics_frame
	view._physics_process(1.0/60.0)
	_check(view.actors.has(person) and actor.get_instance_id()==identity,"Departure keeps the same actor")
	var moved := Vector2(actor.global_position.x-before.x,actor.global_position.z-before.z)
	var toward := Vector2(target_world.x-before.x,target_world.z-before.z)
	_check(moved.length()>0.0001 and moved.dot(toward)>0.0,"Actual body moves along the world-transformed route after departure")
	_check(moved.length()<=float(life.walk_speed_cm(person))/100.0/60.0+.005,"Existing gait speed cap is unchanged")
	_check(JSON.stringify(life.state)==snapshot,"Physical movement remains a read-only projection")
	stage.free()
	observer_parent.free()
	floor.free()
	_finish()

func _finish() -> void:
	print("CITY_RESIDENT_DEPARTURE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_RESIDENT_DEPARTURE_PASS" if failures.is_empty() else "CITY_RESIDENT_DEPARTURE_FAIL")
	quit(0 if failures.is_empty() else 1)
