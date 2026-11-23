extends SceneTree
## The saved escort route must be traversable and stop at real dynamic obstacles.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const Neighborhood = preload("res://scripts/world/village/childhood_neighborhood.gd")
const Art = preload("res://scripts/world/village_art.gd")
var checks := 0
var failures: Array[String] = []
var probe: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(false)
	world.set_physics_process(false)
	var data: Dictionary = model.data.duplicate(true)
	# Geometry fixture only. Story tests separately build this state by receipts.
	data.village.childhood.scene_id = "night_escort"
	data.village.childhood.phase = "night"
	data.village.childhood.escort = {"progress":0.0,"position":[-4.0,24.9]}
	world.sync_state(data)
	var village: Node3D = world.village_life_world
	var player: CharacterBody3D = world.get_node("Player")
	player.position = Vector3(0,1,8)
	await physics_frame
	await physics_frame
	var length := Childhood._escort_length()
	var clear: float = village.escort_progress_limit(data,100.0)
	print("ESCORT_CLEAR_PROGRESS %0.4f / %0.4f at %s"%[clear,length,Childhood._escort_point(clear)])
	_check(absf(clear-length)<.001,"The full saved route clears actual houses, furniture and all residents")
	var one_step: float = village.escort_progress_limit(data,.1)
	_check(absf(one_step-Childhood.ESCORT_SPEED*.1)<.001,"Physics grants at most the domain's walking speed per elapsed step")
	var blocker := Node3D.new()
	blocker.name = "TemporaryLaneObstacle"
	world.add_child(blocker)
	Art.box_collider(blocker,Vector3(.8,2,.6),Vector3(-9,1,28.2))
	await physics_frame
	await physics_frame
	var stopped: float = village.escort_progress_limit(data,100.0)
	var stopped_at := Childhood._escort_point(stopped)
	_check(stopped>3.0 and stopped<length-3.0,"A real obstacle limits saved escort progress before the refuge")
	_check(stopped_at.x> -8.33,"Julia's full capsule stops before the lane obstacle")
	blocker.free()
	await physics_frame
	player.position = Vector3(-4,Neighborhood.FLOOR_HEIGHT+.9,24.9)
	await physics_frame
	await physics_frame
	_check(village.escort_progress_limit(data,.1)==0.0,"An overlapping player blocks progression instead of Julia passing through")
	player.position = Vector3(0,1,8)
	await physics_frame
	await physics_frame
	_check(absf(village.escort_progress_limit(data,100.0)-length)<.001,"Removing an obstacle reopens the same route without changing saved identity")
	# Walk the complete same route with the resident's real capsule, including
	# the two door thresholds and both changes between the raised floor and lane.
	village.actors.julia.get_node("ResidentBody").collision_layer = 0
	probe = CharacterBody3D.new()
	probe.name = "JuliaCapsuleRouteProbe"
	probe.collision_layer = 2
	probe.collision_mask = 1
	probe.floor_snap_length = .25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .29
	capsule.height = 1.72
	shape.shape = capsule
	probe.add_child(shape)
	world.add_child(probe)
	probe.position = Vector3(-4,Neighborhood.FLOOR_HEIGHT+.89,24.9)
	await physics_frame
	for i in range(1,Childhood.ESCORT_ROUTE.size()):
		var target: Vector2 = Childhood.ESCORT_ROUTE[i]
		_check(await _walk_to(target,700),"The real body traverses escort segment %d through the authored route"%i)
		_check(absf(probe.position.y-.86-Neighborhood.floor_height_at(target))<.075,"The escorted person's feet follow the floor/ramp at segment %d"%i)
	_check(Neighborhood.house_at(Vector2(probe.position.x,probe.position.z))=="neighbors","The physical escort finishes inside the actual neighbor house")
	probe.free()
	await physics_frame
	data.village.childhood.escort.progress = length-.75
	var saved := Childhood._escort_point(length-.75)
	data.village.childhood.escort.position = [saved.x,saved.y]
	world.sync_state(data)
	village.set_active(true)
	village.sync_escort(data,.1)
	_check(Vector2(village.actors.julia.position.x,village.actors.julia.position.z).is_equal_approx(saved),"The displayed person uses the exact saved route position")
	var same_id: int = village.actors.julia.get_instance_id()
	world.sync_state(data.duplicate(true))
	_check(village.actors.julia.get_instance_id()==same_id,"Restoring an escort snapshot preserves the same person node")
	_check(Vector2(village.actors.julia.position.x,village.actors.julia.position.z).is_equal_approx(saved),"Restoring a saved escort never recomputes Julia as a player offset")
	world.free()
	await process_frame
	print("CHILDHOOD_ESCORT_PHYSICS_RESULT checks=%d failures=%d"%[checks,failures.size()])
	for message: String in failures: printerr("FAIL: "+message)
	quit(0 if failures.is_empty() else 1)


func _walk_to(target: Vector2,frames: int) -> bool:
	for frame in frames:
		var offset := target-Vector2(probe.position.x,probe.position.z)
		if offset.length()<.045:
			probe.velocity.x = 0.0
			probe.velocity.z = 0.0
			return true
		probe.velocity.x = offset.normalized().x*Childhood.ESCORT_SPEED
		probe.velocity.z = offset.normalized().y*Childhood.ESCORT_SPEED
		probe.velocity.y = -.3 if probe.is_on_floor() else probe.velocity.y-19.6/60.0
		probe.move_and_slide()
		await physics_frame
	return false


func _check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
