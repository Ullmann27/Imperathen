extends SceneTree
## Walk-through of the amphitheatre against the real collision: enters through
## an arch, climbs the dog-leg stair, follows the level-2 corridor and passage,
## climbs the scalaria to a seat block and looks into the arena.
## A second route reaches the podium terrace; a third proves walls are solid.
const ColosseumScript := preload("res://scripts/monuments/colosseum.gd")
const SPEED := 3.0
var failures: Array[String] = []
var building: Node3D
var body: CharacterBody3D


func check(condition: bool, text: String) -> void:
	if not condition:
		failures.append(text)
		printerr("FAIL: " + text)


func _initialize() -> void:
	_run.call_deferred()


func _point(bay: int, u: float, r: float) -> Vector3:
	return ColosseumScript.bay_point(building.layout, bay, u, r)


func _walk(route: Array, label: String) -> bool:
	for index in route.size():
		var target: Vector3 = _point(route[index][0], route[index][1], route[index][2])
		var frames := 0
		var limit := int(Vector2(body.position.x - target.x, body.position.z - target.z).length() / SPEED * 60.0 * 2.5) + 240
		while frames < limit:
			var flat := Vector3(target.x - body.position.x, 0.0, target.z - body.position.z)
			if flat.length() < 0.25:
				break
			var direction := flat.normalized()
			body.velocity = Vector3(direction.x * SPEED, body.velocity.y - 9.8 / 60.0, direction.z * SPEED)
			body.move_and_slide()
			if body.is_on_floor():
				body.velocity.y = 0.0
			await physics_frame
			frames += 1
		if frames >= limit:
			check(false, "%s: stuck before waypoint %d at %s (target %s)" % [label, index, body.position, target])
			return false
		if route[index].size() > 3:
			check(absf(body.position.y - float(route[index][3])) < 0.45, "%s: waypoint %d height %.2f, expected %.2f" % [label, index, body.position.y, route[index][3]])
		check(body.position.y > -0.6, "%s: fell through the floor at waypoint %d" % [label, index])
	return true


func _place(bay: int, u: float, r: float, height: float) -> void:
	body.position = _point(bay, u, r) + Vector3(0, height + 0.05, 0)
	body.velocity = Vector3.ZERO


func _run() -> void:
	building = ColosseumScript.new()
	building.set("profile", "low")
	root.add_child(building)
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	plane.shape = box
	plane.position.y = -0.5
	ground.add_child(plane)
	root.add_child(ground)
	body = CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	body.add_child(shape)
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_snap_length = 0.24
	root.add_child(body)
	for i in 4:
		await physics_frame
	check(int(building.stats.collision_faces) > 20000, "collision mesh loaded")
	var layout: Dictionary = building.layout
	check(absf(float(layout.dimensions_m.major_axis) - 188.0) < 0.01 and absf(float(layout.dimensions_m.minor_axis) - 156.0) < 0.01 and absf(float(layout.dimensions_m.height) - 48.5) < 0.01, "real dimensions 188 x 156 x 48.5 m")
	# Route 1: arch -> dog-leg stair -> level-2 corridor -> passage -> scalaria -> seat block.
	_place(22, 0.5, -6.0, 0.0)
	var route := [
		[22, 0.5, 1.3, 0.0], [22, 0.5, 8.6, 0.0], [22, 0.27, 13.0, 0.0], [22, 0.27, 15.6], [22, 0.27, 23.4, 5.25], [22, 0.27, 24.4, 5.25],
		[22, 0.73, 24.4, 5.25], [22, 0.73, 15.4, 10.5], [22, 0.73, 12.0, 10.5], [23, 0.5, 12.0, 10.5], [23, 0.5, 15.0, 10.5],
		[23, 0.5, 31.5, 10.5], [23, 0.5, 34.8, 10.5], [23, 0.5, 36.0, 10.5], [23, 0.12, 36.0, 10.5], [23, 0.12, 33.6], [23, 0.12, 29.8], [23, 0.7, 29.8]]
	var arrived: bool = await _walk(route, "seat route")
	if arrived:
		check(absf(body.position.y - 14.4) < 0.6, "seat block height in the maenianum secundum, got %.2f" % body.position.y)
		var eye := body.position + Vector3(0, 1.55, 0)
		var query := PhysicsRayQueryParameters3D.create(eye, Vector3(0, 0.02, 0), 0xFFFFFFFF, [body.get_rid()])
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.is_empty() or (hit.position as Vector3).y < 0.3, "clear sight line from the seat to the arena floor, hit %s" % [hit.get("position", "none")])
		print("COLOSSEUM_WALK seat=%s" % body.position)
	# continue: up to level 3 by the second dog-leg and out onto the upper praecinctio
	_place(22, 0.27, 14.4, 10.5)
	arrived = await _walk([[22, 0.27, 15.6], [22, 0.27, 23.4, 15.6], [22, 0.27, 24.4, 15.6], [22, 0.73, 24.4, 15.6], [22, 0.73, 11.6, 22.35],
		[22, 0.73, 10.6, 22.35], [23, 0.5, 11.5, 22.35], [23, 0.5, 17.7, 22.35]], "level 3 route")
	# Route 2: ground passage to the podium terrace.
	_place(27, 0.5, -6.0, 0.0)
	arrived = await _walk([[27, 0.5, 1.3, 0.0], [27, 0.5, 12.0, 0.0], [27, 0.5, 37.5, 0.0], [27, 0.5, 48.0, 3.8], [27, 0.5, 50.6, 3.8]], "podium route")
	if arrived:
		print("COLOSSEUM_WALK podium=%s" % body.position)
	# Route 3: the processional axis into the arena.
	_place(40, 0.5, -6.0, 0.0)
	arrived = await _walk([[40, 0.5, 1.3, 0.0], [40, 0.5, 30.0, 0.0], [40, 0.5, 56.0, 0.0]], "Porta Triumphalis route")
	# Route 4: gallery stair to the wooden tier.
	_place(8, 0.5, 6.0, 22.35)
	arrived = await _walk([[8, 0.5, 3.5, 22.35], [9, 0.5, 3.5], [10, 0.5, 3.5], [11, 0.95, 3.5], [12, 0.3, 3.5, 33.95], [12, 0.5, 6.5, 33.95], [12, 0.5, 9.5]], "gallery route")
	# Solid walls: a flank bay has no ground passage behind wall 3.
	_place(1, 0.5, 12.0, 0.0)
	var blocked_target := _point(1, 0.5, 20.0)
	for i in 240:
		var flat := Vector3(blocked_target.x - body.position.x, 0.0, blocked_target.z - body.position.z).normalized()
		body.velocity = Vector3(flat.x * SPEED, -1.0, flat.z * SPEED)
		body.move_and_slide()
		await physics_frame
	check(body.position.distance_to(_point(1, 0.5, 12.0)) < 2.4, "wall 3 is solid in a flank bay")
	# and the podium wall keeps a spectator out of the arena
	_place(27, 0.5, 51.0, 3.8)
	var arena_target := _point(27, 0.5, 60.0)
	for i in 240:
		var flat := Vector3(arena_target.x - body.position.x, 0.0, arena_target.z - body.position.z).normalized()
		body.velocity = Vector3(flat.x * SPEED, -1.0, flat.z * SPEED)
		body.move_and_slide()
		await physics_frame
	check(body.position.y > 3.5, "podium parapet holds, height %.2f" % body.position.y)
	print("COLOSSEUM_WALKTHROUGH %d failures" % failures.size())
	if failures.is_empty():
		print("COLOSSEUM_WALKTHROUGH_PASS")
	quit(0 if failures.is_empty() else 1)
