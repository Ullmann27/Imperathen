extends SceneTree
## Production village world: the north backdrop hills are a closed, solid
## landform on the streamed regional ground, the brook ends at their foot and
## the raider approach to the north gate and the childhood patrol stay clear.
## Heights are read from the actual built meshes and the physics server.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Hills = preload("res://scripts/world/village/backdrop_hills.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const Land = preload("res://scripts/world/village/valdora_land.gd")
const VegetationField = preload("res://scripts/vegetation/vegetation_field.gd")
## Village ground plane (VillageScenery.create_land) and its collider top.
const PLANE := Rect2(-90, -100, 180, 170)
const PLANE_Y := -.008
const RAIDER_SPAWNS := [Vector2(-5,-62), Vector2(0,-64), Vector2(5,-62), Vector2(10,-64), Vector2(15,-62), Vector2(20,-64)]
const GATE := Vector2(0,-49.5)
var checks := 0
var failures: Array[String] = []
var world
var hill_body: StaticBody3D
var hills: FaceField
var ground: FaceField
var vegetation: VegetationField
var vegetation_ray_hits := 0
var vegetation_ray_faults: Array[String] = []


class FaceField:
	## Height lookup from actual mesh triangles; no generator formula involved.
	var cell := 2.0
	var buckets := {}

	func add_faces(faces: PackedVector3Array, offset: Vector3) -> void:
		for i in range(0, faces.size(), 3):
			var a := faces[i] + offset
			var b := faces[i + 1] + offset
			var c := faces[i + 2] + offset
			for gx in range(floori(minf(a.x, minf(b.x, c.x)) / cell), floori(maxf(a.x, maxf(b.x, c.x)) / cell) + 1):
				for gz in range(floori(minf(a.z, minf(b.z, c.z)) / cell), floori(maxf(a.z, maxf(b.z, c.z)) / cell) + 1):
					var key := Vector2i(gx, gz)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append([a, b, c])

	func height(x: float, z: float) -> float:
		var best := -INF
		for triangle: Array in buckets.get(Vector2i(floori(x / cell), floori(z / cell)), []):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 1000, z), Vector3.DOWN, triangle[0], triangle[1], triangle[2])
			if hit == null:
				hit = Geometry3D.ray_intersects_triangle(Vector3(x, 1000, z), Vector3.DOWN, triangle[0], triangle[2], triangle[1])
			if hit != null:
				best = maxf(best, hit.y)
		return best


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _visible(x: float, z: float) -> float:
	var top := maxf(hills.height(x, z), ground.height(x, z))
	if PLANE.has_point(Vector2(x, z)):
		top = maxf(top, PLANE_Y)
	return top


func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


func _capsule_hits(at: Vector3, radius: float, height: float) -> Array:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	query.shape = capsule
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, at)
	var colliders := []
	for hit: Dictionary in _space().intersect_shape(query, 8):
		colliders.append(hit.collider)
	return colliders


func _run() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	world = World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	var terrain: Node3D = world.regional_terrain
	for i in 200:
		terrain.follow(Vector3(0, 0, -50), "balanced")
		if terrain.report().pending_work == 0:
			break
	await physics_frame
	await physics_frame
	var ridge := world.get_node("Landscape/VillageScenery/Foothills") as MeshInstance3D
	hill_body = ridge.get_node_or_null("FoothillsCollision") as StaticBody3D
	_check(hill_body != null and hill_body.collision_layer == 1 and hill_body.collision_mask == 0, "The hills own a static body on the world layer")
	if hill_body == null:
		_finish()
		return
	var shape := hill_body.get_child(0).shape as ConcavePolygonShape3D
	var faces := ridge.mesh.get_faces()
	_check(shape != null and shape.get_faces() == faces and ridge.global_transform == hill_body.global_transform, "Hill collision consists of exactly the visible triangles")
	hills = FaceField.new()
	hills.add_faces(faces, ridge.global_position)
	ground = FaceField.new()
	ground.cell = 4.0
	for sector: Node3D in terrain.sectors.values():
		ground.add_faces((sector.get_node("Ground") as MeshInstance3D).mesh.get_faces(), sector.global_position)
	print("VILLAGE_BACKDROP mesh triangles=%d collision_faces=%d" % [faces.size() / 3, shape.get_faces().size() / 3])
	_test_on_terrain()
	_test_closed_rim(ridge)
	vegetation = world.get_node_or_null("Landscape/Vegetation") as VegetationField
	await _test_physics_surface()
	print("BACKDROP_VEGETATION_RAYS hits=%d faults=%s" % [vegetation_ray_hits, vegetation_ray_faults])
	_check(vegetation != null and vegetation_ray_hits > 0, "The unchanged world ray actually encounters authored vegetation colliders")
	_check(vegetation_ray_faults.is_empty(), "Every intercepted vegetation ray matches its physical trunk and planted mesh; no unknown body is excluded")
	await _test_walk()
	_test_corridor()
	_test_brook()
	_test_slopes(faces)
	_test_colors(ridge)
	_finish()


func _finish() -> void:
	world.free()
	await process_frame
	print("VILLAGE_BACKDROP_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("VILLAGE_BACKDROP_PASS" if failures.is_empty() else "VILLAGE_BACKDROP_FAIL")
	quit(0 if failures.is_empty() else 1)


## Every metre of the former backdrop footprint and of the new one.
func _test_on_terrain() -> void:
	for grid: Rect2 in [Rect2(-163, -106, 324, 50), Rect2(-208, -152, 416, 86)]:
		var samples := 0
		var exposed := 0
		var lowest := INF
		var helper_error := 0.0
		for zi in int(grid.size.y) + 1:
			for xi in int(grid.size.x) + 1:
				var x := grid.position.x + xi
				var z := grid.position.y + zi
				var hill := hills.height(x, z)
				if hill == -INF:
					continue
				var base := ground.height(x, z)
				samples += 1
				lowest = minf(lowest, hill - base)
				exposed += int(base > hill + .001)
				helper_error = maxf(helper_error, absf(Hills.surface_height(Vector2(x, z)) - hill))
		print("VILLAGE_BACKDROP terrain_check grid=%s hill_samples=%d terrain_above_hill=%d min_clearance_m=%.6f helper_error_m=%.6f" % [grid, samples, exposed, lowest, helper_error])
		_check(samples > 10000 and exposed == 0 and lowest > -.001, "Regional terrain never rises through the hills: %s" % grid)
		_check(helper_error < .001, "Hill height helper reproduces the built triangles")


## Mesh boundary edges (used by one triangle) must lie on the terrain.
func _test_closed_rim(ridge: MeshInstance3D) -> void:
	var arrays := ridge.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uses := {}
	for i in range(0, indices.size(), 3):
		for edge in [[indices[i], indices[i + 1]], [indices[i + 1], indices[i + 2]], [indices[i + 2], indices[i]]]:
			var key := Vector2i(mini(edge[0], edge[1]), maxi(edge[0], edge[1]))
			uses[key] = int(uses.get(key, 0)) + 1
	var rim := {}
	for key: Vector2i in uses:
		if uses[key] == 1:
			rim[key.x] = true
			rim[key.y] = true
	var worst := 0.0
	var span := Rect2()
	for index: int in rim:
		var v := vertices[index] + ridge.global_position
		var base := ground.height(v.x, v.z)
		if base == -INF:
			# The terrain is open under the village's sunk brook bed; there the
			# rim lies on the terrain surface the open cells would have had.
			base = Terrain.surface_height(Vector2(v.x, v.z))
		worst = maxf(worst, absf(v.y - base))
		span = Rect2(v.x, v.z, 0, 0) if span.size == Vector2.ZERO and span.position == Vector2.ZERO else span.expand(Vector2(v.x, v.z))
	print("VILLAGE_BACKDROP rim vertices=%d extent=%s max_gap_to_terrain_m=%.6f" % [rim.size(), span, worst])
	_check(rim.size() > 100 and worst <= .002, "The open edge of the hill surface lies on the terrain all round (no floating back or ends)")
	_check(span.position.x < -200 and span.end.x > 200 and span.position.y < -145 and span.end.y > -72, "The rim runs round the back, both ends and the foot")


## A raw world ray may legitimately hit an authored trunk before the terrain.
## Verify that first hit independently, then measure the actual terrain on
## the identical segment excluding ONLY the single known vegetation RID.
## No collision body is removed, no movement query is changed, and all
## existing terrain tolerances and assertions remain in force.
func _surface_ray(query: PhysicsRayQueryParameters3D) -> Dictionary:
	var raw := _space().intersect_ray(query)
	if raw.is_empty() or vegetation == null or raw.get("collider") != vegetation:
		return raw
	vegetation_ray_hits += 1
	var rid: RID = raw.get("rid", RID())
	var index := int(raw.get("shape", -1))
	if not _verified_trunk(rid, index, raw.position):
		vegetation_ray_faults.append("unverified trunk %d at %s" % [index, raw.position])
		return raw
	var surface := PhysicsRayQueryParameters3D.create(query.from, query.to, query.collision_mask, [rid])
	return _space().intersect_ray(surface)


func _verified_trunk(rid: RID, index: int, hit: Vector3) -> bool:
	if not rid.is_valid() or rid != vegetation._body or vegetation.ecology == null:
		return false
	var entries: Array = vegetation.ecology.colliders
	if index < 0 or index >= entries.size() or PhysicsServer3D.body_get_shape_count(rid) != entries.size():
		return false
	if PhysicsServer3D.body_get_collision_layer(rid) != 1:
		return false
	var entry: Array = entries[index]
	var base: Vector3 = entry[0]
	var radius := snappedf(float(entry[1]), .05)
	var shape := PhysicsServer3D.body_get_shape(rid, index)
	if PhysicsServer3D.shape_get_type(shape) != PhysicsServer3D.SHAPE_BOX:
		return false
	var half: Vector3 = PhysicsServer3D.shape_get_data(shape)
	var transform := PhysicsServer3D.body_get_shape_transform(rid, index)
	var body_transform: Transform3D = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	var centre := base + Vector3.UP * 1.6
	if not half.is_equal_approx(Vector3(radius * .85, 1.6, radius * .85)) or not (body_transform * transform).origin.is_equal_approx(centre):
		return false
	if not AABB(centre - half, half * 2.0).grow(.02).has_point(hit):
		return false
	# Match the ecology record to the actual render batch input, not a
	# collider name alone. An invisible or orphaned trunk still fails.
	var cell := Vector2i(floori(base.x / VegetationField.CELL), floori(base.z / VegetationField.CELL))
	var positions: Dictionary = vegetation._cells.get(cell, {}).get("positions", {})
	for tree: Dictionary in vegetation.ecology.trees:
		if not tree.collider or tree.legacy or tree.position != base:
			continue
		var asset: String = tree.asset
		var placed: PackedVector3Array = positions.get(asset, PackedVector3Array())
		var lods: Array = vegetation._assets.get(asset, {}).get("lods", [])
		if placed.has(base) and not lods.is_empty():
			return true
	return false


## Retain exact collision provenance for any remaining terrain failure.
func _ray_fault(kind: String, start: Vector3, finish: Vector3, hit: Dictionary, expected: Vector3) -> void:
	var collider: Object = hit.get("collider")
	var actual: Vector3 = hit.get("position", Vector3.INF)
	print("BACKDROP_RAY_FAULT ", JSON.stringify({
		"kind": kind, "start": str(start), "end": str(finish),
		"expected": str(expected), "actual": str(actual),
		"collider": str((collider as Node).get_path()) if collider is Node else str(collider),
		"is_hill": collider == hill_body,
		"shape": int(hit.get("shape", -1)), "face": int(hit.get("face_index", -1)),
		"normal": str(hit.get("normal", Vector3.ZERO)),
		"expected_hill": str(hills.height(expected.x, expected.z)) if expected.is_finite() else "none",
		"expected_ground": str(ground.height(expected.x, expected.z)) if expected.is_finite() else "none",
		"actual_hill": str(hills.height(actual.x, actual.z)) if actual.is_finite() else "none",
		"actual_ground": str(ground.height(actual.x, actual.z)) if actual.is_finite() else "none",
	}))


func _test_physics_surface() -> void:
	var worst := 0.0
	var probes := 0
	var wrong := 0
	for xi in range(-200, 201, 10):
		for zi in range(-150, -67, 4):
			var visible := hills.height(xi, zi)
			if visible <= PLANE_Y + .02:
				continue
			var query := PhysicsRayQueryParameters3D.create(Vector3(xi, 80, zi), Vector3(xi, -20, zi), 1)
			var hit := _surface_ray(query)
			probes += 1
			if hit.is_empty() or hit.collider != hill_body:
				wrong += 1
				_ray_fault("down_other", query.from, query.to, hit, Vector3(xi, visible, zi))
				continue
			if absf(hit.position.y - visible) > .02:
				_ray_fault("down_height", query.from, query.to, hit, Vector3(xi, visible, zi))
			worst = maxf(worst, absf(hit.position.y - visible))
	print("VILLAGE_BACKDROP downward_rays=%d not_hill=%d max_difference_m=%.6f" % [probes, wrong, worst])
	_check(probes > 500 and wrong == 0 and worst <= .02, "Downward rays meet the hill collision at the visible surface")
	# Horizontal sight lines from outside, 0.3/1/3 m above the outer ground.
	# Where the visible hill rises above a line, physics must stop the line at
	# that same place; a line may only pass where it runs over the low tail.
	var faults: Array[String] = []
	var blocked := 0
	var terrain_stops := 0
	var passed_over: Array[String] = []
	var lines: Array = []
	for x in range(-200, 201, 10):
		lines.append(["north x=%d" % x, Vector3(x, 0, -158), Vector3(x, 0, -60), absi(x) <= 150])
	for side: int in [-1, 1]:
		for z in range(-70, -151, -5):
			lines.append(["side %d z=%d" % [side, z], Vector3(side * 214, 0, z), Vector3(0, 0, z), z <= -80 and z >= -130])
	for line: Array in lines:
		for lift: float in [.3, 1.0, 3.0]:
			var start: Vector3 = line[1]
			var finish: Vector3 = line[2]
			start.y = ground.height(start.x, start.z) + lift
			finish.y = start.y
			var result := _sight_line(start, finish)
			if result == "fault":
				faults.append("%s +%.1f" % [line[0], lift])
			elif result == "blocked":
				blocked += 1
			elif result == "terrain":
				terrain_stops += 1
			elif lift <= 1.0 and line[3]:
				passed_over.append("%s +%.1f" % [line[0], lift])
	print("VILLAGE_BACKDROP horizontal_lines=%d stopped_by_hill=%d stopped_by_rising_terrain=%d faults=%s core_lines_not_stopped_by_hill=%s" % [lines.size() * 3, blocked, terrain_stops, faults, passed_over])
	_check(faults.is_empty(), "Every horizontal line that meets the visible hill is stopped by its collision at that place")
	_check(passed_over.is_empty(), "From the north (|x| <= 150) and both ends (z -80..-130) low lines run into the hill, not under it")


## "blocked": physics stops where the line first meets the visible hill or
## ground, on the body of that surface; "clear": the line meets neither and
## physics agrees; anything else is a "fault". Only hill stops count as blocked.
func _sight_line(start: Vector3, finish: Vector3) -> String:
	var hit := _surface_ray(PhysicsRayQueryParameters3D.create(start, finish, 1))
	var crossing := -1.0
	var on_hill := false
	var shared := false
	for step in 801:
		var p := start.lerp(finish, step / 800.0)
		var hill := hills.height(p.x, p.z)
		var base := ground.height(p.x, p.z)
		if maxf(hill, base) >= start.y:
			crossing = step / 800.0
			on_hill = hill >= base
			# At the rim the hill lies on the terrain; either body may answer.
			shared = absf(hill - base) < .001
			break
	if crossing < 0.0:
		if not hit.is_empty():
			_ray_fault("horizontal_unexpected", start, finish, hit, Vector3.INF)
		return "clear" if hit.is_empty() else "fault"
	if hit.is_empty() or start.lerp(finish, crossing).distance_to(hit.position) > (finish - start).length() / 800.0 + .05:
		_ray_fault("horizontal_surface", start, finish, hit, start.lerp(finish, crossing))
		return "fault"
	if shared:
		return "blocked" if hit.collider == hill_body else "terrain"
	if on_hill:
		if hit.collider != hill_body:
			_ray_fault("horizontal_expected_hill", start, finish, hit, start.lerp(finish, crossing))
		return "blocked" if hit.collider == hill_body else "fault"
	if hit.collider == hill_body:
		_ray_fault("horizontal_expected_terrain", start, finish, hit, start.lerp(finish, crossing))
	return "terrain" if hit.collider != hill_body else "fault"


## The production player and its physics, driven by the movement axis.
func _test_walk() -> void:
	var player: CharacterBody3D = world.get_node("Player")
	var terrain: Node3D = world.regional_terrain
	world._camera_yaw = 0.0
	world._figure.rotation.y = 0.0
	for run: Dictionary in [{"label":"walk_10s", "running":false, "frames":600},
			{"label":"run_10s", "running":true, "frames":600},
			{"label":"run_over_crest", "running":true, "frames":3600}]:
		player.position = Vector3(0, 1.0, -50)
		player.velocity = Vector3.ZERO
		world._touch_move = Vector2.ZERO
		world._running = false
		for frame in 30:
			await physics_frame
			world._move_player(1.0 / 60.0)
		world._running = run.running
		world._touch_move = Vector2(0, -1)
		var worst := 0.0
		var sunk := 0.0
		var hill_frames := 0
		var floor_frames := 0
		var frames := 0
		var crest := -INF
		for frame in int(run.frames):
			await physics_frame
			world._move_player(1.0 / 60.0)
			terrain.follow(player.global_position, "balanced")
			frames += 1
			var foot := player.global_position.y - .9
			sunk = maxf(sunk, _visible(player.global_position.x, player.global_position.z) - foot)
			crest = maxf(crest, foot)
			if player.is_on_floor():
				floor_frames += 1
				for i in player.get_slide_collision_count():
					var contact := player.get_slide_collision(i)
					if contact.get_normal().y < cos(player.floor_max_angle) - .001:
						continue
					var point := contact.get_position()
					worst = maxf(worst, absf(point.y - _visible(point.x, point.z)))
					hill_frames += int(contact.get_collider() == hill_body)
			if run.label == "run_over_crest" and player.global_position.z < -165.0:
				break
		world._touch_move = Vector2.ZERO
		world._running = false
		print("VILLAGE_BACKDROP %s end=%s frames=%d on_floor=%d hill_contacts=%d max_contact_to_visible_m=%.4f max_feet_below_visible_m=%.4f highest_foot_m=%.2f" % [run.label, player.global_position, frames, floor_frames, hill_frames, worst, sunk, crest])
		_check(worst <= .02, "%s: floor contacts lie on the visible surface within 2 cm" % run.label)
		_check(sunk <= .02, "%s: the feet never sink into the visible ground or hill" % run.label)
		if run.label == "run_10s":
			_check(hill_frames > 120 and player.global_position.z < -80.0 and foot_on(player) > 2.0, "Running north from the gate for 10 s climbs the hill on its collision")
		if run.label == "run_over_crest":
			# The north track crosses the ridge in a hollow way (saddle about 5 m
			# on the track, 11-19 m beside it), so the crossing climbs less than
			# the former 9.7 m over the open crest.
			_check(player.global_position.z < -165.0 and crest > 4.0 and floor_frames >= frames * .95, "The hill can be crossed on foot: up the front, over the crest and down onto the terrain")


func foot_on(player: CharacterBody3D) -> float:
	return player.global_position.y - .9


## Raiders (village_life_world: capsule r=.28, h=1.8 on y=0, horizontal moves only).
func _test_corridor() -> void:
	var blocked: Array[String] = []
	for spawn: Vector2 in RAIDER_SPAWNS:
		if _capsule_hits(Vector3(spawn.x, .9, spawn.y), .28, 1.8).has(hill_body):
			blocked.append("spawn %s" % spawn)
		if hills.height(spawn.x, spawn.y) > PLANE_Y:
			blocked.append("raider stands in hill at %s" % spawn)
		var target := Vector2(clampf(spawn.x, -2.5, 2.5), GATE.y)
		for step in 41:
			var p := spawn.lerp(target, step / 40.0)
			if _capsule_hits(Vector3(p.x, .9, p.y), .28, 1.8).has(hill_body):
				blocked.append("path %s at %s" % [spawn, p])
				break
		var walker := CharacterBody3D.new()
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .28
		capsule.height = 1.8
		collision.shape = capsule
		collision.position.y = .9
		walker.add_child(collision)
		walker.collision_mask = 1
		walker.safe_margin = .006
		world.add_child(walker)
		walker.global_position = Vector3(spawn.x, 0, spawn.y)
		var hit := walker.move_and_collide(Vector3(target.x - spawn.x, 0, target.y - spawn.y))
		if hit != null and hit.get_collider() == hill_body:
			blocked.append("swept move from %s" % spawn)
		walker.free()
	# Southern limit of anything a raider capsule (bottom y = 0) could touch.
	var free_to := -INF
	for x in range(-8, 24):
		var found := false
		for zi in 1000:
			var z := -49.0 - zi * .05
			if hills.height(x, z) > 0.0:
				free_to = maxf(free_to, z)
				found = true
				break
		_check(found, "The hill does rise north of the corridor at x=%d" % x)
	print("VILLAGE_BACKDROP raider_corridor clear_from_gate_z=-49 to_z=%.2f (hill rises above raider feet north of this line for x=-8..23) blocked=%s" % [free_to, blocked])
	_check(blocked.is_empty(), "Raider spawn points and their corridor to the north gate stay free of the hill")
	_check(free_to < -68.0, "The hill foot leaves at least 4 m of meadow north of the raider spawn rows")
	var patrol: Array[String] = []
	for id: String in ["patrol_inner", "patrol_road", "patrol_gate"]:
		var point: Vector2 = Childhood.POINTS[id]
		if _capsule_hits(Vector3(point.x, 1.02, point.y), .29, 1.7).has(hill_body):
			patrol.append(id)
	for guard: Vector2 in [Vector2(-1.2, -45.9), Vector2(0, -48)]:
		if _capsule_hits(Vector3(guard.x, 1.02, guard.y), .29, 1.7).has(hill_body):
			patrol.append(str(guard))
	_check(patrol.is_empty(), "Childhood patrol points, gate guard and watch post are untouched by the hill: %s" % [patrol])


func _test_brook() -> void:
	var scenery: Node3D = world.get_node("Landscape/VillageScenery")
	var stream := scenery.get_node("Stream") as MeshInstance3D
	var water := stream.mesh.get_faces()
	var submerged := 0
	var tip := INF
	for v in water:
		tip = minf(tip, v.z)
		# A lifted hill triangle over the water or its banks would roof the brook.
		for side in [-1.2, 0.0, 1.2]:
			if hills.height(v.x + side, v.z) > Terrain.surface_height(Vector2(v.x + side, v.z)) + .0005:
				submerged += 1
	var centre := Land.brook_x(tip)
	var rises := INF
	for step in 400:
		var z := tip - step * .02
		if hills.height(centre, z) > Terrain.surface_height(Vector2(centre, z)) + .01:
			rises = tip - z
			break
	print("VILLAGE_BACKDROP brook water_vertices=%d under_hill=%d spring_z=%.2f hill_rises_after_m=%.2f" % [water.size(), submerged, tip, rises])
	_check(submerged == 0, "No hill triangle reaches over the brook water or its banks")
	_check(is_equal_approx(tip, scenery.brook_source_z) and rises <= 6.0, "The brook ends at the hill foot (the hill rises within 6 m of the spring)")


func _test_slopes(faces: PackedVector3Array) -> void:
	var area := [0.0, 0.0, 0.0]
	var steepest := 0.0
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var centre := (a + b + c) / 3.0
		if centre.y - Terrain.surface_height(Vector2(centre.x, centre.z)) < .05:
			continue
		var normal := (c - a).cross(b - a)
		var size := normal.length() * .5
		var angle := rad_to_deg(acos(clampf(normal.normalized().y, -1, 1)))
		steepest = maxf(steepest, angle)
		area[0 if angle < 30.0 else (1 if angle <= 45.0 else 2)] += size
	var total: float = area[0] + area[1] + area[2]
	print("VILLAGE_BACKDROP slopes area_m2=%.0f below_30deg=%.1f%% 30_to_45deg=%.1f%% above_45deg=%.1f%% steepest_deg=%.1f (player floor_max_angle=45)" % [total, area[0] / total * 100.0, area[1] / total * 100.0, area[2] / total * 100.0, steepest])
	_check(area[0] / total > .6, "Most of the hill is walkable ground below 30 degrees")


func _test_colors(ridge: MeshInstance3D) -> void:
	# The hills use the terrain's land shader; vertex colours are weights
	# (r scrub, g stone, b shade), so no colour space is implied by vertex data.
	var material := ridge.material_override as ShaderMaterial
	_check(material != null and material.shader == Terrain.LandSurface.TERRAIN_SHADER, "The hills use the same land shader as the regional terrain")
	var arrays := ridge.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var rim_weight := 0.0
	var rim := 0
	var raised := 0
	for i in vertices.size():
		var v := vertices[i] + ridge.global_position
		var above := v.y - Terrain.surface_height(Vector2(v.x, v.z))
		if absf(above) < .0005:
			rim += 1
			rim_weight = maxf(rim_weight, maxf(colors[i].r, colors[i].g))
		elif above > Hills.COLOR_BLEND_M and colors[i].r > .999:
			raised += 1
	_check(rim > 100 and rim_weight <= 1.0 / 255.0, "Where the hill meets the terrain it is plain terrain ground (no scrub or stone weight)")
	_check(raised > 500, "Raised relief carries full scrub cover")
