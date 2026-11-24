extends SceneTree
## Real GameWorld camera method with deliberately small, deterministic physics fixtures.
## These placements test collision geometry, not a claimed player walkthrough.

const WorldScene = preload("res://scripts/world/game_world.gd")
const BODY_RADIUS := 0.24
var checks := 0
var failures: Array[String] = []
var world
var walls: Array[StaticBody3D] = []

class CameraWorld extends WorldScene:
	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass

class TalkTargets extends Node3D:
	var actors: Dictionary = {}

	func actor_position(id: String) -> Vector3:
		return actors[id].global_position


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	world = CameraWorld.new()
	root.add_child(world)
	world._camera = Camera3D.new()
	world.add_child(world._camera)
	world._camera.near = 0.12
	world._camera.fov = 54.0
	world._player = CharacterBody3D.new()
	world._player.collision_layer = 2
	world.add_child(world._player)
	world.village_life_world = TalkTargets.new()
	world.add_child(world.village_life_world)
	var speaker := Node3D.new()
	world.village_life_world.add_child(speaker)
	world.village_life_world.actors["speaker"] = speaker
	await physics_frame
	await _test_shoulder_wall()
	await _test_near_plane_corner()
	await _test_smoothed_position()
	await _test_dialogue_wall()
	await _test_overlapping_anchor()
	await _test_retraction_and_recovery()
	_test_map_and_city()
	_clear_walls()
	# The minimal harness deliberately skips the full world builder; release the
	# builder-owned nodes that consequently never acquired a scene-tree parent.
	for node: Node in [world.population,world.regional,world.grove,world.scenery,world.opening_props,world.crops]:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()
	world.free()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("CAMERA_COLLISION_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CAMERA_COLLISION_PASS" if failures.is_empty() else "CAMERA_COLLISION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _reset_camera() -> void:
	_clear_walls()
	world._player.position = Vector3(0.0,1.0,0.0)
	world._mode = "person"
	world._village_focus = ""
	world._frontier_focus = ""
	world._camera_yaw = 0.0
	world._camera_pitch = 0.18
	world._person_zoom = 3.05
	world._camera_initialized = false
	world._camera.position = Vector3.ZERO
	world._frontier_camera_direction = Vector3.BACK
	world._menu_flight = false


func _anchor() -> Vector3:
	return world._player.global_position + Vector3(0,0.4,0)


func _desired() -> Vector3:
	return _anchor() + Vector3(0.36,sin(world._camera_pitch)*world._person_zoom+0.22,cos(world._camera_pitch)*world._person_zoom)


func _wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = center
	world.add_child(wall)
	walls.append(wall)
	return wall


func _clear_walls() -> void:
	for wall: StaticBody3D in walls:
		wall.free()
	walls.clear()


func _camera_free() -> bool:
	var shape := SphereShape3D.new()
	shape.radius = BODY_RADIUS - 0.001
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,world._camera.global_position)
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()


func _line_free(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	query.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _test_shoulder_wall() -> void:
	_reset_camera()
	_wall(Vector3(0,2,1.6),Vector3(5,4,0.12))
	await physics_frame
	world._update_camera(0.0)
	_check(world._camera.position.z < 1.6-0.06-BODY_RADIUS,"Shoulder camera retracts its entire collision volume before a wall")
	_check(_camera_free() and _line_free(_anchor(),world._camera.global_position),"Retracted camera stays free with a clear route to the player")


func _test_near_plane_corner() -> void:
	_reset_camera()
	var wanted := _desired()
	# The center ray misses this narrow edge, but the near-plane volume overlaps.
	_wall(wanted+Vector3(0.18,0,0),Vector3(0.08,2.0,0.8))
	await physics_frame
	_check(_line_free(_anchor(),wanted),"Corner fixture really is invisible to the old center ray")
	world._update_camera(0.0)
	_check(_camera_free(),"A near-plane corner cannot enter the camera volume even when its center ray misses")
	_check(world._camera.position.distance_to(wanted) > 0.1,"Corner contact actually retracts the shoulder camera")


func _test_smoothed_position() -> void:
	_reset_camera()
	var wanted := _desired()
	var previous := Vector3(-2.0,wanted.y,2.1)
	var blended := previous.lerp(wanted,0.5)
	_wall(blended,Vector3(0.22,2.0,0.22))
	await physics_frame
	_check(_line_free(_anchor(),wanted),"Smoothing fixture leaves the requested boom endpoint unobstructed")
	world._camera.position = previous
	world._camera_initialized = true
	world._update_camera(log(2.0)/12.0)
	_check(_camera_free(),"The actual smoothed camera position is checked against geometry")
	_check(_line_free(_anchor(),world._camera.global_position),"Smoothing cannot move the camera behind a corner between two safe endpoints")


func _test_dialogue_wall() -> void:
	_reset_camera()
	world._village_focus = "speaker"
	_wall(Vector3(0,1.6,1.2),Vector3(3,3,0.10))
	await physics_frame
	world._update_camera(0.0)
	_check(world._camera.position.z < 1.2-0.05-BODY_RADIUS,"Named village dialogue uses the same obstruction protection as the shoulder camera")
	_check(_camera_free(),"Dialogue camera volume stays outside the wall")


func _test_overlapping_anchor() -> void:
	_reset_camera()
	var previous := Vector3(-1.0,1.8,0.0)
	world._camera.position = previous
	world._camera_initialized = true
	# cast_motion ignores shapes already overlapping its origin. An inserted
	# world obstacle must not silently allow a sweep through that same obstacle.
	_wall(_anchor(),Vector3(0.12,1.0,0.12))
	await physics_frame
	world._update_camera(1.0/60.0)
	_check(_camera_free(),"A newly overlapping anchor preserves a verified free camera position")
	_check(world._camera.position.is_equal_approx(previous),"Initial overlap cannot bypass collision by ignoring the offending shape")


func _test_retraction_and_recovery() -> void:
	_reset_camera()
	world._update_camera(0.0)
	var wanted: Vector3 = world._camera.position
	_wall(Vector3(0,2,1.6),Vector3(5,4,0.12))
	await physics_frame
	world._update_camera(1.0/60.0)
	var retracted: Vector3 = world._camera.position
	_check(retracted.z < 1.6-0.06-BODY_RADIUS and _camera_free(),"New obstruction retracts immediately despite smoothing from the previous distant camera")
	_clear_walls()
	await physics_frame
	world._update_camera(1.0/60.0)
	_check(world._camera.position.z > retracted.z and world._camera.position.z < wanted.z,"Removing the obstruction restores distance smoothly")
	for frame in 60:
		world._update_camera(1.0/60.0)
	_check(world._camera.position.distance_to(wanted) < 0.001,"Free camera returns to its requested distance without sticking")


func _test_map_and_city() -> void:
	_reset_camera()
	world._mode = "city"
	world._city_focus = Vector3(7,0,1)
	world._camera_initialized = false
	world._update_camera(0.0)
	_check(world._camera.position.is_equal_approx(Vector3(17,38,29)),"City camera keeps its existing overview placement")
	world._mode = "map"
	world._map_focus = Vector3(-7,0,-7)
	world._camera_initialized = false
	world._update_camera(0.0)
	_check(world._camera.position.is_equal_approx(Vector3(-7,104,11)),"Map camera keeps its existing overview placement")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
