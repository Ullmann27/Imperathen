extends SceneTree
## Godot physics route replay. The controlled second pass exercises the
## terrain at reference riding speed with the same capsule, since the campaign
## has no mount controller. Time is elapsed physics time, independent of FPS.

const World = preload("res://scripts/world/game_world.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const RIDING_REFERENCE_SPEED := 2.90
const WAYPOINT_RADIUS := 0.20
const PHYSICS_HZ := 60
const DELTA := 1.0 / PHYSICS_HZ
var failures: Array[String] = []


func _initialize() -> void:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	_run.call_deferred()


func _run() -> void:
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	var calendar_before: Dictionary = model.data.calendar.clock.duplicate()
	model.advance(1.0)
	_check(is_equal_approx(float(model.data.world_seconds), 1.0), "Running gameplay accrues one technical world second per simulated second.")
	_check(model.data.calendar.clock == calendar_before, "The childhood historical calendar keeps its existing narrated passage of time.")
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	# Freeze the rest of the scene without disabling its collision bodies.
	_stop_scene_updates(world)
	world.set_quality("low")
	var terrain: Node3D = world.regional_terrain
	var body: CharacterBody3D = world.get_node("Player")
	var first: Vector2 = Footpath.WAYPOINTS[0]
	var goal: Vector2 = Footpath.WAYPOINTS[-1]
	var stone_quarry := {}
	for place: Dictionary in Plan.points_of_interest():
		if place.id == "stone_quarry":
			stone_quarry = place
			break
	_check(not stone_quarry.is_empty() and goal == _flat(Vector3(stone_quarry.position[0], 0, stone_quarry.position[2])) and stone_quarry.content_status == "planned",
		"The route ends at the planned quarry's actual atlas position.")
	_check(Footpath.map_points()[0] == [46.0, 0.0, -13.0] and first.x < 48 and Footpath.WAYPOINTS[1].x > 48,
		"The drawn route crosses the authored eastern gate from inside Valdora.")
	var foot: Dictionary = await _replay(world, body, terrain, World.WALK_SPEED, true)
	print("REGIONAL_TRAVERSE_WALK ", JSON.stringify(foot))
	var mounted_reference: Dictionary = await _replay(world, body, terrain, RIDING_REFERENCE_SPEED, false)
	_check(float(foot.elapsed_seconds) >= 1200.0 and float(foot.elapsed_seconds) <= 1250.0, "Player walk stays near 20 minutes.")
	_check(float(mounted_reference.elapsed_seconds) >= 600.0 and float(mounted_reference.elapsed_seconds) <= 625.0, "Faster capsule stays near the 10-minute riding target.")
	_check(absf(float(foot.elapsed_seconds) - float(mounted_reference.elapsed_seconds) * 2.0) <= 6.0,
		"Both passes follow the same physical route.")
	var entrance_cells := terrain.find_children("EastGateFootpath", "MeshInstance3D", true, false)
	_check(entrance_cells.is_empty(), "The entrance retires with its terrain cell.")
	print("REGIONAL_FOOTPATH ", JSON.stringify({
		"waypoint_length_m": Footpath.length_m(),
		"physics_hz": PHYSICS_HZ,
		"walk": foot,
		"riding_speed_capsule_only": mounted_reference,
		"rendered_entrance_m": Footpath.WAYPOINTS[0].distance_to(Footpath.WAYPOINTS[1]),
		"failures": failures,
	}))
	world.free()
	quit(0 if failures.is_empty() else 1)


func _replay(world: Node3D, body: CharacterBody3D, terrain: Node3D, speed: float, use_player_walk: bool) -> Dictionary:
	var start: Vector2 = Footpath.WAYPOINTS[0]
	var finish: Vector2 = Footpath.WAYPOINTS[-1]
	body.position = Vector3(start.x, 1.1, start.y)
	body.velocity = Vector3.ZERO
	world.set_touch_move(Vector2.ZERO)
	world._camera_yaw = 0.0
	for frame in 55:
		await physics_frame
		terrain.follow(body.position, "low")
		body.velocity = Vector3(0, body.velocity.y - 19.6 * DELTA, 0)
		body.move_and_slide()
	_check(body.is_on_floor(), "The real player capsule settles on the village's original footpath floor.")
	var sector_id: String = Plan.sector_id(Plan.sector_for_position(body.position))
	_check(terrain.sectors[sector_id].has_node("EastGateFootpath"), "The new entrance mesh is actually streamed at the east gate.")
	var floor_losses := 0
	var traversed := {}
	var crossings := 0
	var travelled := 0.0
	var elapsed := 0.0
	var next_waypoint := 1
	var crossed_gate := false
	var max_grid_height_error := 0.0
	var step_limit := ceili((Footpath.length_m() / speed + 50.0) * PHYSICS_HZ)
	for frame in step_limit:
		await physics_frame
		var before := _flat(body.position)
		var direction: Vector2 = before.direction_to(Footpath.WAYPOINTS[next_waypoint])
		terrain.follow(body.position, "low")
		if use_player_walk:
			world.set_touch_move(direction)
			world._move_player(DELTA)
		else:
			var vertical_speed := body.velocity.y - 19.6 * DELTA if not body.is_on_floor() else -0.3
			body.velocity = Vector3(direction.x * speed, vertical_speed, direction.y * speed)
			body.move_and_slide()
		elapsed += DELTA
		var after := _flat(body.position)
		travelled += before.distance_to(after)
		floor_losses += int(not body.is_on_floor())
		var id: String = Plan.sector_id(Plan.sector_for_position(body.position))
		traversed[id] = true
		if id != sector_id:
			crossings += 1
			sector_id = id
		if after.x > 48.5 and absf(after.y + 13.0) < 1.0:
			crossed_gate = true
		if after.x > 120.0 and frame % PHYSICS_HZ == 0:
			# The player's 1.8 m capsule centre sits about 0.9 m above contact.
			var offset := body.position.y - Terrain.surface_height(after)
			max_grid_height_error = maxf(max_grid_height_error, absf(offset - 0.9))
		if after.distance_to(Footpath.WAYPOINTS[next_waypoint]) <= WAYPOINT_RADIUS:
			next_waypoint += 1
			if next_waypoint == Footpath.WAYPOINTS.size():
				break
	_check(crossed_gate, "The capsule crosses the physical eastern gate opening.")
	_check(next_waypoint == Footpath.WAYPOINTS.size() and _flat(body.position).distance_to(finish) <= WAYPOINT_RADIUS,
		"The capsule reaches the planned quarry anchor through every route waypoint.")
	_check(floor_losses == 0 and max_grid_height_error < 0.08,
		"The capsule remains grounded on streamed terrain (lost contact=%d, greatest height delta=%.3f m)." % [floor_losses, max_grid_height_error])
	_check(traversed.size() >= 8 and crossings >= 8, "The route crosses actual streamed sector boundaries.")
	_check(absf(travelled - Footpath.length_m()) < 8.0, "Traced travel distance agrees with the designed waypoints.")
	return {"speed_m_s": speed, "elapsed_seconds": snappedf(elapsed, 0.01),
		"distance_m": snappedf(travelled, 0.01), "sector_crossings": crossings, "sectors": traversed.size(),
		"ungrounded_frames": floor_losses, "max_ground_offset_error_m": snappedf(max_grid_height_error, 0.001),
		"end_xz_m": [body.position.x, body.position.z]}


func _stop_scene_updates(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_stop_scene_updates(child)


func _flat(position: Vector3) -> Vector2:
	return Vector2(position.x, position.z)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("FAIL ", label)
