extends SceneTree
## Standalone world integration checks; does not replace domain or visual tests.

const WorldScript = preload("res://scripts/world/game_world.gd")

var failures: Array[String] = []
var actions: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world = WorldScript.new()
	scene.add_child(world)
	var initial := _state()
	world.setup(initial)
	world.action_requested.connect(func(action: String, payload: Dictionary): actions.append({"action": action, "payload": payload}))
	world.set_active(true)
	for frame in range(4):
		await physics_frame
	_check(world.get_player_position().y > 0.7, "Player capsule must remain above ground")
	var position: Vector3 = world.get_player_position()
	world.set_mode("city")
	world.set_mode("map")
	world.set_mode("person")
	_check(world.get_player_position().is_equal_approx(position), "Camera mode changes must preserve player location")
	var movement_key := InputEventKey.new()
	movement_key.physical_keycode = KEY_W
	movement_key.keycode = KEY_W
	movement_key.pressed = true
	Input.parse_input_event(movement_key.duplicate())
	for frame in range(18):
		await physics_frame
	movement_key.pressed = false
	Input.parse_input_event(movement_key.duplicate())
	_check(world.get_player_position().z < position.z - 0.4, "Actual physical W input must move the character")
	world.get_node("Player").position = Vector3(12, 1, 16.8)
	world.get_node("Player").velocity = Vector3.ZERO
	movement_key.physical_keycode = KEY_S
	movement_key.keycode = KEY_S
	movement_key.pressed = true
	Input.parse_input_event(movement_key.duplicate())
	for frame in range(24):
		await physics_frame
	movement_key.pressed = false
	Input.parse_input_event(movement_key.duplicate())
	_check(world.get_player_position().z < 17.6, "Palisade must block the moving capsule outside the gate")
	world.get_node("Player").position = Vector3(0, 1, 8)
	world.get_node("Player").velocity = Vector3.ZERO
	world.set_touch_move(Vector2(0, -0.5))
	var before_touch: Vector3 = world.get_player_position()
	for frame in range(18):
		await physics_frame
	_check(world.get_player_position().z < before_touch.z - 0.25, "Analog touch axis must move the real character")
	_check(absf(world.get_node("Player").velocity.z) < 3.0, "Half touch axis must preserve analog speed")
	world.set_touch_move(Vector2(8, 8))
	_check(world._touch_move.length() <= 1.001, "Touch input must not exceed full movement speed")
	world.set_active(false)
	_check(world._touch_move == Vector2.ZERO, "Pausing must clear a held touch axis")
	world.set_active(true)
	world.set_touch_move(Vector2.RIGHT)
	world.setup(initial)
	_check(world._touch_move == Vector2.ZERO, "Loading or new game must clear touch input")
	var first := InputEventScreenTouch.new()
	first.index = 81
	first.pressed = true
	first.position = Vector2(300, 175)
	world._unhandled_input(first)
	var second := first.duplicate() as InputEventScreenTouch
	second.index = 82
	second.position = Vector2(420, 175)
	world._unhandled_input(second)
	var drag := InputEventScreenDrag.new()
	drag.index = 82
	drag.position = Vector2(540, 175)
	drag.relative = Vector2(120, 0)
	var zoom: float = world._person_zoom
	var yaw: float = world._camera_yaw
	world._unhandled_input(drag)
	_check(is_equal_approx(world._person_zoom, zoom * 0.5) and world._camera_yaw == yaw, "Spreading two free world fingers halves distance without rotating")
	first.pressed = false
	world._unhandled_input(first)
	drag.position.x += 10
	drag.relative = Vector2(10, 0)
	world._unhandled_input(drag)
	_check(world._camera_yaw != yaw and is_equal_approx(world._person_zoom, zoom * 0.5), "Remaining finger resumes orbit without a zoom jump")
	world.set_active(false)
	_check(world._camera_contacts.is_empty(), "Pausing cancels both camera fingers")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	world.set_active(false)
	world._unhandled_input(key)
	_check(actions.is_empty(), "Paused world must not emit interactions")
	world.set_active(true)
	world.get_node("Player").position = Vector3(-8, 1, 2)
	world._unhandled_input(key)
	_check(actions.size() == 1 and actions[0]["action"] == "gather" and actions[0]["payload"]["node_id"] == "timber_0", "Nearby interaction must request the correct finite wood stock")
	actions.clear()
	world.get_node("Player").position = Vector3(24, 1, 12)
	world._unhandled_input(key)
	_check(actions.is_empty(), "Distant interaction must not gather resources")
	var constructed: Dictionary = initial.duplicate(true)
	constructed["buildings"] = [{"id": "hut_1", "x": 8.0, "z": 5.0, "progress": 1.0, "completed": true}]
	world.sync_state(constructed)
	_check(world.get_node("PlayerBuildings/hut_1").has_node("FinishedCollision"), "Completed huts must have wall collision")
	var building: Node3D = world.get_node("PlayerBuildings/hut_1")
	if building.get_meta("visual_source", "") == "res://assets/frontier_hut.glb":
		var bounds := _visual_bounds(building.get_node("Shell"))
		_check(bounds.size.x > 3.5 and bounds.size.x < 5.0 and bounds.size.z > 3.5 and bounds.size.z < 5.0, "Imported hut must fit the declared plot footprint")
		_check(bounds.size.y > 2.5 and bounds.size.y < 4.5, "Imported hut must use metre-scale height")
		print("WORLD_ASSET_IMPORT: frontier_hut.glb bounds ", bounds.size)
	constructed["buildings"][0]["progress"] = 0.2
	constructed["buildings"][0]["completed"] = false
	world.setup(constructed)
	_check(not world.get_node("PlayerBuildings/hut_1").has_node("FinishedCollision"), "Loading unfinished state must remove prior completed collision")
	world.setup(initial)
	await process_frame
	_check(world.get_node("PlayerBuildings").get_child_count() == 0, "A fresh game must remove buildings from a previous game")
	_check(world.get_node("WoodStocks").get_child_count() == 3, "Repeated setup must not duplicate resource nodes")
	_check(initial["resources"]["wood"] == 0, "World presentation must not mutate supplied canonical data")
	var build_state: Dictionary = initial.duplicate(true)
	build_state["resources"]["wood"] = 16
	world.sync_state(build_state)
	world.set_active(true)
	world.set_build_mode(true)
	_check(world.is_build_active(), "Touch build UI must have a reliable mode getter")
	world._update_camera(0.016)
	actions.clear()
	var build_pixel: Vector2 = world.get_node("WorldCamera").unproject_position(Vector3(12, 0.04, 5))
	_touch_tap(world, build_pixel)
	_check(actions.size() == 1 and actions[0]["action"] == "build", "A valid touch tap must request actual construction")
	if actions.size() == 1 and actions[0]["action"] == "build":
		_check(absf(float(actions[0]["payload"].get("x", 0)) - 12.0) < 0.1 and absf(float(actions[0]["payload"].get("z", 0)) - 5.0) < 0.1, "Touch construction must use the tapped ground position")
	actions.clear()
	var invalid_pixel: Vector2 = world.get_node("WorldCamera").unproject_position(Vector3(-12, 0.04, 5))
	_touch_tap(world, invalid_pixel)
	_check(actions.is_empty(), "Touch taps outside allowed plots must not request construction")
	world.set_mode("person")
	_check(not world.is_build_active(), "Leaving city mode must clear building UI state")
	actions.clear()
	world.set_active(false)
	world.perform_interaction()
	world.perform_attack()
	_check(actions.is_empty(), "Touch action buttons must respect the same paused-world boundary")
	var state_before_quality: Dictionary = world._state.duplicate(true)
	var bodies_before_quality := _count_collision_bodies(world)
	var sun: DirectionalLight3D = world.get_node("AfternoonSun")
	world.set_quality("low")
	_check(root.msaa_3d == Viewport.MSAA_DISABLED and sun.directional_shadow_max_distance <= 24.0, "Low quality must really disable MSAA and limit distant shadows")
	world.set_quality("balanced")
	_check(root.msaa_3d == Viewport.MSAA_2X and sun.directional_shadow_max_distance > 24.0 and sun.directional_shadow_max_distance <= 55.0, "Balanced quality must apply 2x MSAA and an intermediate shadow range")
	world.set_quality("high")
	_check(root.msaa_3d == Viewport.MSAA_4X and sun.directional_shadow_max_distance > 55.0, "High quality must apply 4x MSAA and a larger shadow range")
	_check(world._state == state_before_quality and _count_collision_bodies(world) == bodies_before_quality, "Graphics quality must preserve canonical state and collision bodies")
	world.set_quality("balanced")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("WORLD_SMOKE_PASS: keyboard/touch movement, analog limits/reset, touch build placement, collision, camera continuity, pause, interaction range, reload, quality settings, and presentation isolation")
		quit(0)
	else:
		for message: String in failures:
			push_error(message)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _touch_tap(world: Node3D, position: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 41
	press.position = position
	press.pressed = true
	world._unhandled_input(press)
	var release := InputEventScreenTouch.new()
	release.index = 41
	release.position = position
	release.pressed = false
	world._unhandled_input(release)


func _count_collision_bodies(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child: Node in node.get_children():
		count += _count_collision_bodies(child)
	return count


func _visual_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	if node is MeshInstance3D:
		bounds = node.global_transform * node.get_aabb()
		has_bounds = true
	for child: Node in node.get_children():
		if child is Node3D:
			var child_bounds := _visual_bounds(child)
			if child_bounds.size.length_squared() > 0.0:
				bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
				has_bounds = true
	return bounds


func _state() -> Dictionary:
	return {
		"schema_version": 1, "revision": 0, "world_seconds": 0.0,
		"resources": {"wood": 0, "grain": 12, "denarii": 30},
		"player": {"position": [0, 1, 8], "health": 100, "age": 12},
		"companion": {"met": false, "choice": "", "trust": 0},
		"progress": {"stage": "arrival", "training_hits": 0, "training_complete": false, "skirmish_won": false},
		"buildings": [],
		"resource_nodes": [
			{"id": "timber_0", "x": -8.0, "z": 2.0, "amount": 16},
			{"id": "timber_1", "x": -11.0, "z": -3.0, "amount": 16},
			{"id": "timber_2", "x": -5.0, "z": -7.0, "amount": 16}
		],
		"squad": {"recruits": 0, "alive": 0, "morale": 70},
		"encounter": {"active": false, "enemies": []},
		"chronicle": [], "story": {}
	}
