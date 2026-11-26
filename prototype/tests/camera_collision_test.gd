extends SceneTree
## Real GameWorld camera method with deliberately small, deterministic physics fixtures.
## These placements test collision geometry, not a claimed player walkthrough.

const WorldScene = preload("res://scripts/world/game_world.gd")
const BODY_RADIUS := 0.24
var checks := 0
var failures: Array[String] = []
var world
var walls: Array[StaticBody3D] = []
var _review_output := OS.get_environment("IMPERATHEN_CAMERA_REVIEW_OUTPUT")
var _review_label: Label

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
	_setup_review_geometry()
	await physics_frame
	await _test_shoulder_wall()
	await _test_near_plane_corner()
	await _test_smoothed_position()
	await _test_dialogue_wall()
	await _test_overlapping_anchor()
	await _test_cold_start_overlap()
	await _test_cold_start_corner()
	await _test_invalid_input_history()
	await _test_unresolved_overlap()
	await _test_blocked_overview_restore()
	await _test_retraction_and_recovery()
	_test_map_and_city()
	_clear_walls()
	# The minimal harness deliberately skips the full world builder; release the
	# builder-owned nodes that consequently never acquired a scene-tree parent.
	for node: Node in [world.population,world.regional,world.grove,world.scenery,world.look,world.opening_props,world.crops]:
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
	world._camera_obstruction.reset()
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
	if not _review_output.is_empty():
		_review_box(wall,size,Vector3.ZERO,Color(0.56,0.30,0.20))
	wall.position = center
	world.add_child(wall)
	walls.append(wall)
	return wall


func _clear_walls() -> void:
	for wall: StaticBody3D in walls:
		wall.free()
	walls.clear()


func _camera_free() -> bool:
	return _position_free(world._camera.global_position)


func _position_free(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	var shape := SphereShape3D.new()
	shape.radius = BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.015
	query.transform = Transform3D(Basis.IDENTITY,point)
	query.collision_mask = 1
	query.collide_with_areas = false
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



func _test_cold_start_overlap() -> void:
	_reset_camera()
	var anchor := _anchor()
	# The center is outside the wall, while the complete camera volume overlaps.
	_wall(anchor+Vector3(-0.10,0,0),Vector3(0.12,4.0,8.0))
	await physics_frame
	_check(not _position_free(anchor),"CAMERA_OVERLAP_COLD_FIXTURE: anchor volume really overlaps")
	_check(_position_free(_desired()),"CAMERA_OVERLAP_COLD_ENDPOINT: requested endpoint is free")
	world._update_camera(0.0)
	_check(_camera_free(),"CAMERA_OVERLAP_COLD_START: first placement without history leaves the wall")
	_check(world._camera_initialized and world._camera.cull_mask != 0,"CAMERA_OVERLAP_COLD_VISIBLE: recoverable placement keeps geometry visible")
	_check(not world._camera.global_position.is_equal_approx(anchor) and _line_free(anchor,world._camera.global_position),"CAMERA_OVERLAP_COLD_SIGHT: recovery preserves sight of the anchor")
	await _capture_review("cold-start","Erster Kameraframe an einer Wand")


func _test_cold_start_corner() -> void:
	_reset_camera()
	var anchor := _anchor()
	_wall(anchor+Vector3(-0.10,0,0),Vector3(0.12,4.0,8.0))
	_wall(anchor+Vector3(0,0,-0.10),Vector3(8.0,4.0,0.12))
	_wall(Vector3(0,2.0,1.6),Vector3(5.0,4.0,0.12))
	await physics_frame
	_check(not _position_free(anchor),"CAMERA_OVERLAP_CORNER_FIXTURE: camera volume overlaps the corner")
	world._update_camera(0.0)
	_check(_camera_free(),"CAMERA_OVERLAP_CORNER_CLEAR: recovery clears both intersecting walls")
	_check(world._camera.position.z < 1.6-0.06-BODY_RADIUS,"CAMERA_OVERLAP_CORNER_BOOM: recovered origin still sweeps against a separate wall")
	_check(not world._camera.global_position.is_equal_approx(anchor) and _line_free(anchor,world._camera.global_position),"CAMERA_OVERLAP_CORNER_SIGHT: recovery does not cross a separating wall")


func _test_invalid_input_history() -> void:
	_reset_camera()
	var anchor := _anchor()
	_wall(anchor+Vector3(-0.10,0,0),Vector3(0.12,4.0,8.0))
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var blocked: Vector3 = world._camera_obstruction.place(space,Vector3.INF,_desired(),anchor,0.0)
	_check(not blocked.is_finite(),"CAMERA_OVERLAP_INVALID_BLOCKED: invalid input cannot return colliding history")
	var previous := _desired()
	var preserved: Vector3 = world._camera_obstruction.place(space,Vector3.INF,Vector3.INF,previous,0.0)
	_check(preserved.is_equal_approx(previous) and _position_free(preserved),"CAMERA_OVERLAP_INVALID_CLEAR: invalid input can retain verified free history")


func _test_unresolved_overlap() -> void:
	for original_mask: int in [0x5A3,0]:
		_reset_camera()
		world._camera.cull_mask = original_mask
		var other_camera := Camera3D.new()
		world.add_child(other_camera)
		other_camera.make_current()
		_wall(_anchor(),Vector3(20,20,20))
		await physics_frame
		var original_transform: Transform3D = world._camera.global_transform
		var blocked: Vector3 = world._camera_obstruction.place(world.get_world_3d().direct_space_state,
			_anchor(),_desired(),Vector3.INF,0.0)
		_check(not blocked.is_finite(),"CAMERA_OVERLAP_SEALED_RESULT: sealed local search reports failure")
		world._update_camera(0.0)
		world._update_camera(1.0/60.0)
		_check(world._camera.global_transform.is_equal_approx(original_transform),"CAMERA_OVERLAP_SEALED_TRANSFORM: unresolved placement preserves the finite transform")
		_check(not world._camera_initialized and world._camera.cull_mask == 0,"CAMERA_OVERLAP_SEALED_HIDDEN: unresolved geometry is hidden without claiming initialization")
		_check(world.get_viewport().get_camera_3d() == other_camera,"CAMERA_OVERLAP_SEALED_OWNER: another camera keeps ownership")
		if original_mask != 0:
			await _capture_review("sealed-volume","Vollstaendig eingeschlossen: keine freie lokale Position")
		_clear_walls()
		await physics_frame
		world._update_camera(0.0)
		_check(world._camera_initialized and _camera_free(),"CAMERA_OVERLAP_RECOVERED_CLEAR: camera recovers when sealed geometry is removed")
		_check(world._camera.cull_mask == original_mask,"CAMERA_OVERLAP_RECOVERED_MASK: exact original mask is restored, including zero")
		_check(world.get_viewport().get_camera_3d() == other_camera,"CAMERA_OVERLAP_RECOVERED_OWNER: recovery preserves another camera's ownership")
		if original_mask != 0:
			await _capture_review("recovered","Hindernis entfernt: freie Kamera und urspruengliche Sichtmaske")
		other_camera.free()
	world._camera.cull_mask = 0xFFFFF


func _test_blocked_overview_restore() -> void:
	for overview: String in ["city","map"]:
		_reset_camera()
		world._camera.cull_mask = 0x5A3
		_wall(_anchor(),Vector3(20,20,20))
		await physics_frame
		world._update_camera(0.0)
		_check(world._camera.cull_mask == 0,"CAMERA_OVERLAP_OVERVIEW_FIXTURE: blocked person camera suppresses geometry")
		world._mode = overview
		world._city_focus = Vector3(7,0,1)
		world._map_focus = Vector3(-7,0,-7)
		world._update_camera(0.0)
		_check(world._camera.cull_mask == 0x5A3 and world._camera_initialized,"CAMERA_OVERLAP_OVERVIEW_MASK: overview restores the original mask")
		var expected := Vector3(17,38,29) if overview == "city" else Vector3(-7,104,11)
		_check(world._camera.position.is_equal_approx(expected),"CAMERA_OVERLAP_OVERVIEW_POSITION: blocked person camera does not alter overview placement")
		world._camera.cull_mask = 0xFFFFF


func _setup_review_geometry() -> void:
	if _review_output.is_empty():
		return
	_check(DirAccess.make_dir_recursive_absolute(_review_output) == OK,"Camera review output directory can be created")
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.09,0.12,0.17)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.85,0.90,1.0)
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	world.add_child(sun)
	_review_box(world,Vector3(18,0.10,18),Vector3(0,-0.05,0),Color(0.25,0.32,0.28))
	_review_box(world._player,Vector3(0.30,0.70,0.22),Vector3(0,-0.15,0),Color(0.20,0.50,0.78))
	_review_box(world._player,Vector3(0.23,0.23,0.23),Vector3(0,0.34,0),Color(0.80,0.65,0.48))
	for x in range(-4,5):
		_review_box(world,Vector3(0.015,0.01,12),Vector3(x,0.01,0),Color(0.43,0.48,0.44))
	for z in range(-5,6):
		_review_box(world,Vector3(10,0.01,0.015),Vector3(0,0.01,z),Color(0.43,0.48,0.44))
	var overlay := CanvasLayer.new()
	world.add_child(overlay)
	var panel := Panel.new()
	panel.position = Vector2(12,12)
	panel.size = Vector2(936,130)
	overlay.add_child(panel)
	_review_label = Label.new()
	_review_label.position = Vector2(12,8)
	_review_label.add_theme_font_size_override("font_size",18)
	panel.add_child(_review_label)
	world._camera.make_current()


func _review_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	parent.add_child(instance)


func _capture_review(name: String, caption: String) -> void:
	if _review_output.is_empty():
		return
	var owner_before: Camera3D = world.get_viewport().get_camera_3d()
	world._camera.make_current()
	_review_label.text = "KAMERAPRUEFUNG | TESTGEOMETRIE | " + OS.get_environment("IMPERATHEN_CAMERA_REVIEW_LABEL")
	_review_label.text += "\n" + caption
	_review_label.text += "\nKameravolumen frei: %s | Sichtmaske: %d | Initialisiert: %s" % [
		str(_camera_free()),world._camera.cull_mask,str(world._camera_initialized)]
	_review_label.text += "\nPosition: " + str(world._camera.global_position)
	await process_frame
	await RenderingServer.frame_post_draw
	var captured := root.get_texture().get_image()
	_check(captured != null and not captured.is_empty(),"Camera review captures a real viewport image")
	if captured != null and not captured.is_empty():
		_check(captured.save_jpg(_review_output.path_join(name+".jpg"),0.88) == OK,"Camera review JPEG is written")
	if is_instance_valid(owner_before):
		owner_before.make_current()
	else:
		world._camera.clear_current(false)

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
