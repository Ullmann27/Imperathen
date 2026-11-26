extends SceneTree
## Walkable routes and solid obstacles of the ACTUAL RomanCity GLB with its
## imported collision, in every graphics profile (collision must not depend on
## the profile):
## - a body the size of the player passes along the whole east-west and
##   north-south main street, across the forum, along the market row and
##   through all four gates;
## - the city wall stops it everywhere else along the complete perimeter;
## - every market stall, street detail and tree stops it;
## - the production controller steps onto and over the main-street kerbs and is
##   stopped by a market counter and by a tree trunk.
## Headless physics on real imported assets. Not an FPS or device measurement.
const City = preload("res://scripts/world/city_exploration.gd")
const PROFILES := ["low", "balanced", "high", "very_high"]
const BODY_RADIUS := 0.24
# The sweep body spans 0.30-1.50 m above the ground: everything the player
# cannot step over (step limit 0.25 m) up to head height.
const SWEEP_LOW := 0.30
const SWEEP_HIGH := 1.50
const SWEEP_LEG := 8.0
const WALL_X := 410.0
const WALL_Z := 320.0
const ARCH_HALF_WIDTH := 5.25
const KERB_TOP := 0.16
const STREET_TOP := 0.11
# Godot metres: x east, z south. Blender y = -z.
const ROUTES := {
	"main_street_east_west_centre":[Vector3(-400.0, 0.0, 65.0), Vector3(400.0, 0.0, 65.0)],
	"main_street_east_west_north_lane":[Vector3(-400.0, 0.0, 60.0), Vector3(400.0, 0.0, 60.0)],
	"main_street_east_west_south_lane":[Vector3(-400.0, 0.0, 70.0), Vector3(400.0, 0.0, 70.0)],
	"main_street_north_south_centre":[Vector3(-100.0, 0.0, -310.0), Vector3(-100.0, 0.0, 310.0)],
	"main_street_north_south_west_lane":[Vector3(-104.5, 0.0, -310.0), Vector3(-104.5, 0.0, 310.0)],
	"main_street_north_south_east_lane":[Vector3(-95.5, 0.0, -310.0), Vector3(-95.5, 0.0, 310.0)],
	"west_gate_through":[Vector3(-380.0, 0.0, 65.0), Vector3(-440.0, 0.0, 65.0)],
	"east_gate_through":[Vector3(380.0, 0.0, 65.0), Vector3(440.0, 0.0, 65.0)],
	"north_gate_through":[Vector3(-100.0, 0.0, -290.0), Vector3(-100.0, 0.0, -350.0)],
	"south_gate_through":[Vector3(-100.0, 0.0, 290.0), Vector3(-100.0, 0.0, 350.0)],
	"forum_piazza_east_west":[Vector3(-72.0, 0.0, -10.0), Vector3(50.0, 0.0, -10.0)],
	"forum_piazza_to_main_street":[Vector3(-30.0, 0.0, -30.0), Vector3(-30.0, 0.0, 65.0)],
	"forum_to_north_south_street":[Vector3(-13.0, 0.0, 40.0), Vector3(-100.0, 0.0, 40.0)],
	"market_row_front_west":[Vector3(-392.0, 0.0, 51.5), Vector3(-108.0, 0.0, 51.5)],
	"market_row_front_east":[Vector3(-92.0, 0.0, 51.5), Vector3(400.0, 0.0, 51.5)],
	"market_row_to_main_street":[Vector3(0.0, 0.0, 51.5), Vector3(0.0, 0.0, 65.0)],
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


func _body() -> CapsuleShape3D:
	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = SWEEP_HIGH-SWEEP_LOW
	return shape


## Fraction of the way from `from` to `to` (ground points) the body can travel.
func _sweep(scene: Node3D, shape: Shape3D, from: Vector3, to: Vector3) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [scene.player.get_rid()]
	query.margin = 0.0
	var centre := (SWEEP_LOW+SWEEP_HIGH)*0.5
	query.transform = Transform3D(Basis.IDENTITY, from+Vector3.UP*centre)
	query.motion = to-from
	var space := scene.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return 0.0
	# Short legs keep the engine's motion bisection precise on 800 m routes.
	var length := from.distance_to(to)
	var legs := maxi(1, int(ceil(length/SWEEP_LEG)))
	for leg in legs:
		var a := from.lerp(to, float(leg)/legs)
		var b := from.lerp(to, float(leg+1)/legs)
		query.transform = Transform3D(Basis.IDENTITY, a+Vector3.UP*centre)
		query.motion = b-a
		var safe := float(space.cast_motion(query)[0])
		if safe < 1.0:
			return (leg+safe)/legs
	return 1.0


func _floor_y(scene: Node3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 3.0, at.z), Vector3(at.x, -2.0, at.z), 1, [scene.player.get_rid()])
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN


func _run() -> void:
	root.size = Vector2i(1280, 720)
	# Optional subset for slow machines (comma-separated); default: all four.
	var wanted := OS.get_environment("IMPERATHEN_CITY_ROUTE_PROFILES")
	var profiles: Array = PROFILES if wanted.is_empty() else Array(wanted.split(",", false))
	for profile: String in profiles:
		_check(profile in PROFILES, "known profile: "+profile)
		var scene := City.new()
		scene.persist = false
		scene.profile = profile
		root.add_child(scene)
		await _frames(8)
		_check(scene.city_available, profile+": actual RomanCity GLB and collision are loaded")
		if scene.city_available:
			var entry := {}
			entry["routes"] = _routes(scene, profile)
			entry["wall"] = _wall(scene, profile)
			entry["obstacles"] = _obstacles(scene, profile)
			entry["kerbs"] = _kerb_profile(scene, profile)
			if profile == "balanced":
				entry["controller"] = await _controller(scene)
			report[profile] = entry
		scene.free()
		await process_frame
	var identical := true
	var first: String = profiles[0]
	for profile: String in profiles:
		for key in ["routes", "wall", "obstacles", "kerbs"]:
			if report.has(profile) and report.has(first) and JSON.stringify(report[profile][key]) != JSON.stringify(report[first][key]):
				identical = false
	_check(identical, "routes, wall, obstacles and kerbs are identical in all tested profiles")
	print("ROMAN_CITY_ROUTES_RESULT "+JSON.stringify({"checks":checks, "failures":failures.slice(0, 20),
		"failure_count":failures.size(), "passed":failures.is_empty(), "profiles_tested":profiles, "profiles":report,
		"sweep_body_m":{"radius":BODY_RADIUS, "from":SWEEP_LOW, "to":SWEEP_HIGH}, "android_device":false, "fps_measured":false}))
	print("ROMAN_CITY_ROUTES_PASS" if failures.is_empty() else "ROMAN_CITY_ROUTES_FAIL")
	quit(0 if failures.is_empty() else 1)


func _routes(scene: Node3D, profile: String) -> Dictionary:
	var shape := _body()
	var result := {}
	for route: String in ROUTES:
		var from: Vector3 = ROUTES[route][0]
		var to: Vector3 = ROUTES[route][1]
		var free := _sweep(scene, shape, from, to)
		var blocked_at := from.lerp(to, free)
		_check(free >= 1.0, "%s: %s is free for a walking body (blocked after %.1f m at x %.1f z %.1f)" % [
			profile, route, free*from.distance_to(to), blocked_at.x, blocked_at.z])
		# The floor under the route is continuous: no hole and no riser above the step limit.
		var length := from.distance_to(to)
		var previous := NAN
		var worst := 0.0
		var holes := 0
		var samples := int(ceil(length/0.05))
		for i in samples+1:
			var y := _floor_y(scene, from.lerp(to, float(i)/samples))
			if is_nan(y):
				holes += 1
				continue
			if not is_nan(previous):
				worst = maxf(worst, absf(y-previous))
			previous = y
		_check(holes == 0, "%s: %s has floor collision along its whole length (%d of %d samples without floor)" % [profile, route, holes, samples+1])
		_check(worst <= City.MAX_STEP, "%s: %s has no riser above the %.2f m step limit (max %.3f m)" % [profile, route, City.MAX_STEP, worst])
		result[route] = {"length_m":snappedf(length, 0.1), "free":free >= 1.0, "max_riser_m":snappedf(worst, 0.001), "floor_holes":holes}
	return result


## The body starts 6 m inside the wall axis (clear of the gate towers) and tries to leave the city.
func _wall(scene: Node3D, profile: String) -> Dictionary:
	var shape := _body()
	var gates := {}
	for gate: Node in scene.get_node("RomanCity").find_children("Porta_*", "MeshInstance3D", true, false):
		gates[str(gate.name)] = (gate as Node3D).global_position
	_check(gates.size() == 4, profile+": four gates found")
	var probes := 0
	var leaks: Array[String] = []
	var passable := {}
	var sides := [
		["west", Vector3(-WALL_X, 0, 0), Vector3(0, 0, 1), WALL_Z, Vector3(-1, 0, 0)],
		["east", Vector3(WALL_X, 0, 0), Vector3(0, 0, 1), WALL_Z, Vector3(1, 0, 0)],
		["north", Vector3(0, 0, -WALL_Z), Vector3(1, 0, 0), WALL_X, Vector3(0, 0, -1)],
		["south", Vector3(0, 0, WALL_Z), Vector3(1, 0, 0), WALL_X, Vector3(0, 0, 1)],
	]
	for side: Array in sides:
		var gate: Vector3 = gates.get("Porta_"+str(side[0]), Vector3.INF)
		var along: Vector3 = side[2]
		var out: Vector3 = side[4]
		var half: float = side[3]
		var open_from := INF
		var open_to := -INF
		var offset := -half+1.0
		while offset <= half-1.0:
			var base: Vector3 = side[1]+along*offset
			var free := _sweep(scene, shape, base-out*6.0, base+out*8.0)
			probes += 1
			var from_gate := absf((base-gate).dot(along))
			if free >= 1.0:
				open_from = minf(open_from, offset)
				open_to = maxf(open_to, offset)
				if from_gate > ARCH_HALF_WIDTH:
					leaks.append("%s wall at %.2f m along (%.1f m from the gate axis)" % [side[0], offset, from_gate])
			elif from_gate <= ARCH_HALF_WIDTH-BODY_RADIUS-0.3:
				_check(false, "%s: %s gate arch is blocked %.2f m from its axis" % [profile, side[0], from_gate])
			offset += 0.25
		passable[side[0]] = snappedf(open_to-open_from, 0.01) if open_to >= open_from else 0.0
		_check(open_to-open_from >= 2.0*(ARCH_HALF_WIDTH-BODY_RADIUS)-1.0, "%s: %s gate arch is passable over its width (%.2f m)" % [profile, side[0], open_to-open_from])
	_check(leaks.is_empty(), "%s: the city wall is closed outside the four gate arches (%d leaks, first: %s)" % [
		profile, leaks.size(), leaks[0] if not leaks.is_empty() else "none"])
	return {"probes":probes, "leaks":leaks.size(), "gate_passable_width_m":passable}


## Every stall, street detail and tree must stop a body that walks into it.
func _obstacles(scene: Node3D, profile: String) -> Dictionary:
	var shape := _body()
	var city := scene.get_node("RomanCity") as Node3D
	var result := {}
	var families := {"market_stall":"Market_*", "street_detail":"Street_Detail_*", "courtyard_tree":"Courtyard_Tree_*",
		"avenue_tree":"Avenue_Tree_*", "garden_pine":"Garden_Pine_*"}
	var expected := {"market_stall":63, "street_detail":120, "courtyard_tree":22, "avenue_tree":50, "garden_pine":14}
	for family: String in families:
		var walked_through: Array[String] = []
		var nodes := city.find_children(families[family], "MeshInstance3D", true, false)
		for node: Node in nodes:
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			var centre := Vector3(box.get_center().x, 0.0, box.get_center().z)
			# The trunk or the counter is at the object's origin / centre: a
			# body that crosses the object through that point must be stopped.
			var target := Vector3(mesh.global_position.x, 0.0, mesh.global_position.z) if family != "market_stall" and family != "street_detail" else centre
			var blocked := 0
			var directions := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
			for direction: Vector3 in directions:
				var reach: float = maxf(box.size.x, box.size.z)*0.5+1.0
				if _sweep(scene, shape, target-direction*reach, target+direction*reach) < 1.0:
					blocked += 1
			if blocked < 4:
				walked_through.append("%s (%d of 4 crossings blocked)" % [mesh.name, blocked])
		_check(nodes.size() == expected[family], "%s: %d %s objects found (expected %d)" % [profile, nodes.size(), family, expected[family]])
		_check(walked_through.is_empty(), "%s: every %s stops a walking body (%d can be crossed, first: %s)" % [
			profile, family, walked_through.size(), walked_through[0] if not walked_through.is_empty() else "none"])
		result[family] = {"objects":nodes.size(), "can_be_walked_through":walked_through.size()}
	return result


## Collision profile across both kerbs of the east-west street at several places.
func _kerb_profile(scene: Node3D, profile: String) -> Dictionary:
	var tops: Array[float] = []
	var worst := 0.0
	for x: float in [-380.0, -250.0, -130.0, -60.0, 0.0, 150.0, 300.0, 390.0]:
		for kerb_z: float in [57.6, 72.4]:
			var previous := NAN
			var top := -INF
			for i in 301:
				var y := _floor_y(scene, Vector3(x, 0.0, kerb_z-1.5+i*0.01))
				if is_nan(y):
					continue
				top = maxf(top, y)
				if not is_nan(previous):
					worst = maxf(worst, absf(y-previous))
				previous = y
			tops.append(top)
	var lowest: float = tops.min()
	var highest: float = tops.max()
	_check(is_equal_approx(snappedf(lowest, 0.001), KERB_TOP) and is_equal_approx(snappedf(highest, 0.001), KERB_TOP),
		"%s: both kerbs are solid with their top at %.2f m (measured %.3f-%.3f m)" % [profile, KERB_TOP, lowest, highest])
	_check(worst <= City.MAX_STEP, "%s: every kerb riser is within the %.2f m step limit (max %.3f m)" % [profile, City.MAX_STEP, worst])
	# The kerbs end at the north-south street instead of crossing it.
	var crossing_top := -INF
	for i in 257:
		for kerb_z: float in [57.6, 72.4]:
			var y := _floor_y(scene, Vector3(-106.4+i*0.05, 0.0, kerb_z))
			if not is_nan(y):
				crossing_top = maxf(crossing_top, y)
	_check(crossing_top <= STREET_TOP+0.001, "%s: no kerb crosses the north-south street (highest floor there %.3f m)" % [profile, crossing_top])
	return {"kerb_top_m":snappedf(highest, 0.001), "max_riser_m":snappedf(worst, 0.001), "crossing_top_m":snappedf(crossing_top, 0.001)}


func _walk(scene: Node3D, start: Vector3, axis: Vector2, frames: int, stop: Callable) -> Dictionary:
	scene.teleport(start)
	scene._yaw = 0.0
	scene.figure.rotation.y = atan2(-axis.x, -axis.y)
	await _frames(20)
	var highest_floor := -INF
	var largest_lift := 0.0
	var last_y: float = scene.player.global_position.y
	scene._touch_move = axis
	for frame in frames:
		await physics_frame
		var position: Vector3 = scene.player.global_position
		largest_lift = maxf(largest_lift, position.y-last_y)
		last_y = position.y
		var floor_y := _floor_y(scene, position)
		if not is_nan(floor_y):
			highest_floor = maxf(highest_floor, floor_y)
		if stop.call(position):
			break
	scene._touch_move = Vector2.ZERO
	await _frames(30)
	return {"end":scene.player.global_position, "highest_floor":highest_floor, "largest_lift":largest_lift}


func _controller(scene: Node3D) -> Dictionary:
	var result := {}
	var city := scene.get_node("RomanCity") as Node3D
	# 1. From the main street over the north kerb to the market side and back.
	var out: Dictionary = await _walk(scene, Vector3(20.0, 1.05, 61.0), Vector2(0, -1), 600, func(p: Vector3) -> bool: return p.z <= 54.5)
	_check(out.end.z <= 54.8, "controller: player walks from the street over the kerb to the market side (z %.2f)" % out.end.z)
	_check(absf(out.highest_floor-KERB_TOP) < 0.01, "controller: the player stood on the %.2f m kerb on the way (highest floor %.3f m)" % [KERB_TOP, out.highest_floor])
	_check(out.largest_lift <= City.MAX_STEP+0.01, "controller: no frame lifts the body above the step limit on the kerb (%.3f m)" % out.largest_lift)
	var back: Dictionary = await _walk(scene, out.end, Vector2(0, 1), 600, func(p: Vector3) -> bool: return p.z >= 61.0)
	_check(back.end.z >= 60.7, "controller: player walks back over the kerb onto the street (z %.2f)" % back.end.z)
	result["kerb"] = {"out_z":snappedf(out.end.z, 0.01), "back_z":snappedf(back.end.z, 0.01), "highest_floor_m":snappedf(out.highest_floor, 0.001),
		"largest_frame_lift_m":snappedf(maxf(out.largest_lift, back.largest_lift), 0.001)}
	# 2. Straight at the counter of a market anchor stall.
	var stalls := city.find_children("Market_29_*", "MeshInstance3D", true, false)
	_check(stalls.size() == 1, "controller: market anchor stall 29 exists")
	if stalls.size() == 1:
		var stall := stalls[0] as MeshInstance3D
		var origin := stall.global_position
		var scale := stall.global_transform.basis.get_scale().x
		var counter_front := origin.z+1.15*scale   # Blender local y -1.15 is Godot +z
		var hit: Dictionary = await _walk(scene, Vector3(origin.x, 1.05, origin.z+4.5), Vector2(0, -1), 500, func(_p: Vector3) -> bool: return false)
		_check(hit.end.z >= counter_front+BODY_RADIUS-0.05, "controller: the market counter stops the player (z %.2f, counter front %.2f)" % [hit.end.z, counter_front])
		_check(hit.end.z <= counter_front+BODY_RADIUS+0.35, "controller: the player reaches the counter (z %.2f, counter front %.2f)" % [hit.end.z, counter_front])
		result["counter"] = {"stall":str(stall.name), "counter_front_z":snappedf(counter_front, 0.01), "player_z":snappedf(hit.end.z, 0.01)}
	# 3. Straight at a stone-pine trunk in the forum garden.
	var pines := city.find_children("Garden_Pine_0", "MeshInstance3D", true, false)
	_check(pines.size() == 1, "controller: Garden_Pine_0 exists")
	if pines.size() == 1:
		var pine := pines[0] as MeshInstance3D
		var trunk := pine.global_position
		var hit: Dictionary = await _walk(scene, Vector3(trunk.x-3.0, 1.05, trunk.z), Vector2(1, 0), 500, func(_p: Vector3) -> bool: return false)
		_check(hit.end.x < trunk.x, "controller: the pine trunk stops the player (x %.2f, trunk %.2f)" % [hit.end.x, trunk.x])
		_check(hit.end.x > trunk.x-1.2, "controller: the player reaches the trunk (x %.2f, trunk %.2f)" % [hit.end.x, trunk.x])
		result["trunk"] = {"trunk_x":snappedf(trunk.x, 0.01), "player_x":snappedf(hit.end.x, 0.01)}
	return result
