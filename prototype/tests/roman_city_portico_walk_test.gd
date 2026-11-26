extends SceneTree
## Walks the production CityExploration player from the 0.09 m forum piazza
## onto both 0.36 m forum portico stylobates of the ACTUAL RomanCity GLB, using
## its imported collision and the unchanged step limit. No teleport onto the
## platform. Not an FPS, Android or physical Fold7 measurement.
const City = preload("res://scripts/world/city_exploration.gd")
const PIAZZA_TOP := 0.09
const STYLOBATE_TOP := 0.36
const EXPECTED_MAX_STEP := 0.25
const STEP_LIMIT := 0.18
# Godot start on the piazza, walk direction (touch axis with yaw 0), platform centre x.
const ROUTES := {
	"Forum_Portico_West":[Vector3(-70.0, 1.05, -10.0), Vector2(-1.0, 0.0), -80.0],
	"Forum_Portico_East":[Vector3(49.0, 1.05, -10.0), Vector2(1.0, 0.0), 59.0],
}
var checks := 0
var failures: Array[String] = []
var report := {}


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated test profile required")
		quit(2)
		return
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: "+label)


func _frames(amount: int) -> void:
	for i in amount:
		await physics_frame
		await process_frame


func _floor(scene: Node3D, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*2.0, at+Vector3.DOWN*2.0, 1, [scene.player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query)


func _run() -> void:
	root.size = Vector2i(1280,720)
	var scene := City.new()
	scene.persist = false
	scene.profile = "balanced"
	root.add_child(scene)
	await _frames(8)
	_check(scene.city_available, "Actual RomanCity GLB and collision are loaded")
	_check(is_equal_approx(City.MAX_STEP, EXPECTED_MAX_STEP), "Player step limit stays %.2f m" % EXPECTED_MAX_STEP)
	for portico: String in ROUTES:
		var route: Array = ROUTES[portico]
		var start: Vector3 = route[0]
		var axis: Vector2 = route[1]
		var target_x: float = route[2]
		# Collision profile from the piazza to the platform centre, 1 cm samples.
		var previous := NAN
		var max_rise := 0.0
		var steps := 0
		var x := start.x
		while (target_x-x)*signf(axis.x) > 0.0:
			var hit := _floor(scene, Vector3(x, 0.0, start.z))
			if not hit.is_empty():
				var y := float(hit.position.y)
				if not is_nan(previous) and y-previous > 0.005:
					max_rise = maxf(max_rise, y-previous)
					steps += 1
				previous = y
			x += 0.01*signf(axis.x)
		_check(max_rise <= STEP_LIMIT+0.001, "%s: every riser from the piazza is <= %.2f m (max %.3f m)" % [portico, STEP_LIMIT, max_rise])
		_check(is_equal_approx(snappedf(previous, 0.001), STYLOBATE_TOP), "%s: platform top is %.2f m (measured %.3f m)" % [portico, STYLOBATE_TOP, previous])
		# Real walk with the production controller.
		scene.teleport(start)
		scene._yaw = 0.0
		scene.figure.rotation.y = atan2(-axis.x, 0.0)
		await _frames(20)
		var floor_start := float(_floor(scene, scene.player.global_position).get("position", Vector3.INF).y)
		_check(absf(floor_start-PIAZZA_TOP) < 0.01, "%s: walk starts on the 0.09 m piazza (%.3f m)" % [portico, floor_start])
		var largest_jump := 0.0
		var last_y := scene.player.global_position.y
		scene._touch_move = axis
		for frame in 900:
			await physics_frame
			largest_jump = maxf(largest_jump, scene.player.global_position.y-last_y)
			last_y = scene.player.global_position.y
			if (target_x-scene.player.global_position.x)*signf(axis.x) <= 0.0:
				break
		scene._touch_move = Vector2.ZERO
		await _frames(40)
		var position: Vector3 = scene.player.global_position
		var floor_hit := _floor(scene, position)
		var floor_end := float(floor_hit.get("position", Vector3.INF).y)
		var collider := floor_hit.get("collider") as Node
		var reached := (target_x-position.x)*signf(axis.x) <= 0.3
		_check(reached, "%s: player walks from the piazza onto the platform centre (x %.2f, target %.1f)" % [portico, position.x, target_x])
		_check(absf(floor_end-STYLOBATE_TOP) < 0.01, "%s: player stands on the 0.36 m stylobate (%.3f m)" % [portico, floor_end])
		_check(absf((floor_end-floor_start)-(STYLOBATE_TOP-PIAZZA_TOP)) < 0.01,
			"%s: player ends 0.27 m higher than on the piazza (%.3f m)" % [portico, floor_end-floor_start])
		_check(collider != null and str(collider.name).contains(portico),
			"%s: the floor under the player is the portico collider (%s)" % [portico, str(collider.name) if collider else "none"])
		_check(largest_jump <= EXPECTED_MAX_STEP+0.01, "%s: no single physics frame lifts the body more than the step limit (%.3f m)" % [portico, largest_jump])
		report[portico] = {"risers_on_profile":steps, "max_riser_m":snappedf(max_rise, 0.001), "start_floor_m":snappedf(floor_start, 0.001),
			"end_floor_m":snappedf(floor_end, 0.001), "rise_m":snappedf(floor_end-floor_start, 0.001), "end_x":snappedf(position.x, 0.01),
			"largest_frame_lift_m":snappedf(largest_jump, 0.001)}
	scene.free()
	await process_frame
	print("ROMAN_CITY_PORTICO_WALK_RESULT "+JSON.stringify({"checks":checks, "failures":failures, "passed":failures.is_empty(),
		"routes":report, "max_step_m":City.MAX_STEP, "android_device":false, "fps_measured":false}))
	print("ROMAN_CITY_PORTICO_WALK_PASS" if failures.is_empty() else "ROMAN_CITY_PORTICO_WALK_FAIL")
	quit(0 if failures.is_empty() else 1)
