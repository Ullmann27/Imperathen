extends SceneTree
## Production village world: the landscape around Valdora is one consistent
## ground. Tracks leave the gates on walkable, unobstructed ground; the brook
## is a sunk bed whose collision is its visible surface, with water standing
## in it and the bridge deck carrying a walker; the far relief stays under the
## streamed terrain and inside its budget. Heights come from the built meshes
## and the physics server, not from the generator formulas alone.

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Hills = preload("res://scripts/world/village/backdrop_hills.gd")
const Land = preload("res://scripts/world/village/valdora_land.gd")
const Brook = preload("res://scripts/world/village/brook.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const FarRelief = preload("res://scripts/world/land/far_relief.gd")
const PROFILES = preload("res://assets/quality_profiles.json")
var checks := 0
var failures: Array[String] = []
var world
var scenery: Node3D
var source := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _space() -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


func _floor(x: float, z: float) -> Dictionary:
	return _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -30, z), 1))


func _mesh_height(faces: PackedVector3Array, p: Vector2) -> float:
	var best := -INF
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		if p.x < minf(a.x, minf(b.x, c.x)) or p.x > maxf(a.x, maxf(b.x, c.x)) or p.y < minf(a.z, minf(b.z, c.z)) or p.y > maxf(a.z, maxf(b.z, c.z)):
			continue
		var hit = Geometry3D.ray_intersects_triangle(Vector3(p.x, 100, p.y), Vector3.DOWN, a, b, c)
		if hit == null:
			hit = Geometry3D.ray_intersects_triangle(Vector3(p.x, 100, p.y), Vector3.DOWN, a, c, b)
		if hit != null:
			best = maxf(best, hit.y)
	return best


func _run() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	world = World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	scenery = world.get_node("Landscape/VillageScenery")
	source = scenery.brook_source_z
	var terrain: Node3D = world.regional_terrain
	for i in 400:
		terrain.follow(Vector3.ZERO, "very_high")
		if terrain.report().pending_work == 0:
			break
	world.far_relief.follow(Vector3.ZERO, "balanced")
	await physics_frame
	await physics_frame
	_test_mask()
	_test_tracks()
	_test_brook_ground()
	await _test_wading()
	_test_far_relief()
	_test_materials()
	print("VILLAGE_LANDSCAPE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		print("VILLAGE_LANDSCAPE_FAIL ", failure)
	if failures.is_empty():
		print("VILLAGE_LANDSCAPE_PASS")
	world.free()
	quit(0 if failures.is_empty() else 1)


func _test_mask() -> void:
	# The four tracks start at the real openings of the outer palisade.
	_check(absf(Land.north_track_x(Land.NORTH_GATE_Z)) < 1.0 and absf(Land.south_track_x(Land.SOUTH_GATE_Z)) < 1.0, "North and south tracks start in the 6 m gate openings at x = 0")
	_check(absf(Land.east_track_z(Land.EAST_TRACK_START_X) - Land.EAST_GATE_Z) < 1.0 and absf(Land.west_track_z(Land.WEST_BRIDGE_X) - Land.BRIDGE_Z) < .5, "East track starts at the east gate, west track at the bridge end")
	var reserved := 0
	var samples := 0
	# Sampled from 3 m outside each gate (the gate plots themselves are reserved).
	for offset in range(0, 380, 2):
		for p: Vector2 in [Vector2(Land.north_track_x(-53.0 - offset), -53.0 - offset), Vector2(Land.south_track_x(33.0 + offset), 33.0 + offset),
				Vector2(56.0 + offset, Land.east_track_z(56.0 + offset)), Vector2(-36.0 - offset, Land.west_track_z(-36.0 - offset))]:
			samples += 1
			if offset % 60 == 0:
				_check(Land.in_track(p) and Land.track_distance(p) < .01, "Track centre lines lie on their own mask at %s" % p)
			reserved += int(Layout.reserved(p, 1.0))
	_check(reserved == 0, "No landscape track runs through a reserved village plot (%d of %d samples)" % [reserved, samples])
	_check(Land.track_wear(Vector2(Land.south_track_x(100), 100)) > .99 and Land.track_wear(Vector2(40, 100)) == 0.0 and Land.track_wear(Vector2(Land.south_track_x(419), 419)) < .05, "Wear is full on the tread, none beside it and fades out before the track's reach")
	# Water: none north of the spring, full width along the village, narrowing into the fen.
	_check(Land.water_half_width(source - .1, source) == 0.0 and Land.water_half_width(0.0, source) > 3.5 and Land.water_half_width(100.0, source) < 2.0 and Land.water_half_width(Land.FEN_END_Z, source) == 0.0, "Water begins at the spring and narrows to nothing in the fen")
	var lowest := 0.0
	var highest := -INF
	for zi in range(int(source) - 4, 124):
		for xi in range(-420, 1, 2):
			var p := Vector2(xi * .1, zi)
			var offset := Land.bed_offset(p, source)
			lowest = minf(lowest, offset)
			highest = maxf(highest, offset)
			if Land.water_distance(p, source) < 0.0 and offset > Land.WATER_SURFACE_Y + .0001:
				_check(false, "Bed under water lies below the water surface at %s" % p)
	_check(highest <= 0.0 and absf(lowest + Land.BED_DEPTH_M) < .01, "The bed is never above the ground and reaches its full depth of %.2f m (deepest %.3f)" % [Land.BED_DEPTH_M, lowest])
	print("VILLAGE_LANDSCAPE mask track_samples=%d reserved=%d bed_deepest_m=%.3f" % [samples, reserved, lowest])


func _test_tracks() -> void:
	# Every track is walkable ground with collision: no obstacle stands on the
	# tread and the ground under it is the visible terrain, hill or village ground.
	var hill_body := scenery.get_node("Foothills/FoothillsCollision") as StaticBody3D
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.7
	var blocked: Array[String] = []
	var unsupported: Array[String] = []
	var steepest := 0.0
	var probes := 0
	var hill_supported := 0
	for label: String in ["north", "south", "east", "west"]:
		var previous := Vector3.INF
		for offset in range(1, 300, 2):
			var p: Vector2
			match label:
				"north": p = Vector2(Land.north_track_x(-49.5 - offset), -49.5 - offset)
				"south": p = Vector2(Land.south_track_x(30.5 + offset), 30.5 + offset)
				"east": p = Vector2(52.5 + offset, Land.east_track_z(52.5 + offset))
				_: p = Vector2(-33.5 - offset, Land.west_track_z(-33.5 - offset))
			var hit := _floor(p.x, p.y)
			probes += 1
			if hit.is_empty():
				unsupported.append("%s %s" % [label, p])
				continue
			var visible: float = maxf(Terrain.surface_height(p), Hills.surface_height(p))
			if Brook.PLANE.has_point(p):
				visible = maxf(visible, Brook.COLLISION_Y)
			if absf(hit.position.y - visible) > .02:
				unsupported.append("%s %s collision %.3f visible %.3f" % [label, p, hit.position.y, visible])
			hill_supported += int(hit.collider == hill_body)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY, hit.position + Vector3.UP * (capsule.height * .5 + .12))
			for other: Dictionary in _space().intersect_shape(query, 4):
				if other.collider != hit.collider and not (other.collider as Node).name.begins_with("Ground"):
					blocked.append("%s %s by %s" % [label, p, (other.collider as Node).get_path()])
			if previous != Vector3.INF:
				steepest = maxf(steepest, rad_to_deg(atan(absf(hit.position.y - previous.y) / Vector2(hit.position.x - previous.x, hit.position.z - previous.z).length())))
			previous = hit.position
	print("VILLAGE_LANDSCAPE tracks probes=%d unsupported=%d blocked=%d on_hill=%d steepest_along_deg=%.1f" % [probes, unsupported.size(), blocked.size(), hill_supported, steepest])
	_check(unsupported.is_empty(), "Track ground has collision at the visible surface: %s" % [unsupported.slice(0, 5)])
	_check(blocked.is_empty(), "No collider stands on a track tread: %s" % [blocked.slice(0, 5)])
	_check(hill_supported > 20 and steepest < 24.0, "The north track crosses the hills in a hollow way no steeper than 24 degrees along its line (%.1f)" % steepest)
	# Across the tread of the hollow way the ground is level.
	var cross := 0.0
	for z in range(-76, -140, -4):
		var centre := Land.north_track_x(z)
		cross = maxf(cross, absf(Hills.surface_height(Vector2(centre - 1.5, z)) - Hills.surface_height(Vector2(centre + 1.5, z))))
	_check(cross < .45, "The tread of the hill path is level across (largest difference over 3 m: %.2f m)" % cross)
	# The notch gives a sight line from the gate to the land beyond the hills.
	var saddle := 0.0
	var beside := 0.0
	for z in range(-70, -150, -2):
		saddle = maxf(saddle, Hills.relief(Vector2(Land.north_track_x(z), z)))
		beside = maxf(beside, Hills.relief(Vector2(Land.north_track_x(z) + 40.0, z)))
	print("VILLAGE_LANDSCAPE hollow_way crest_on_track_m=%.2f crest_40m_east_m=%.2f cross_fall_m=%.2f" % [saddle, beside, cross])
	_check(saddle < beside * .75 and saddle > 3.0, "The track crosses a saddle lower than the ridge beside it, still a real climb")


func _test_brook_ground() -> void:
	var ground := scenery.get_node("TrackAndVerge") as MeshInstance3D
	var faces := ground.mesh.get_faces()
	var bed := scenery.get_node("BrookBedCollision") as StaticBody3D
	var water := (scenery.get_node("Stream") as MeshInstance3D).mesh.get_faces()
	var worst := 0.0
	var worst_formula := 0.0
	var wrong_body := 0
	var probes := 0
	var wet := 0
	var deepest := 0.0
	for zi in range(int(source) - 3, 124, 3):
		var centre := Land.channel_x(zi)
		for step in range(-14, 15):
			var p := Vector2(centre + step * .5, zi + .37)
			# Not probed here: the bridge with its approach ramps (checked below)
			# and the half metre beside the palisade that stands on x = -21.
			if Brook.DECK.grow(2.3).has_point(p) or p.x <= Brook.APRON.position.x + .1 or p.x >= Brook.APRON.end.x - .1:
				continue
			if p.y <= Brook.PLANE.end.y and (p.x <= Brook.STRIP_WEST_X or p.x >= Brook.STRIP_EAST_X - .5):
				continue
			var hit := _floor(p.x, p.y)
			probes += 1
			if hit.is_empty() or hit.collider != bed:
				wrong_body += 1
				continue
			var visible := _mesh_height(faces, p)
			worst = maxf(worst, absf(hit.position.y - visible))
			var depth := Land.water_depth(p, source)
			if depth > .05:
				wet += 1
				deepest = maxf(deepest, Land.WATER_SURFACE_Y - hit.position.y)
				worst_formula = maxf(worst_formula, absf((Land.WATER_SURFACE_Y - hit.position.y) - depth))
	print("VILLAGE_LANDSCAPE brook probes=%d not_bed_body=%d max_collision_to_visible_m=%.4f wet=%d deepest_walkable_m=%.3f max_depth_vs_mask_m=%.3f" % [probes, wrong_body, worst, wet, deepest, worst_formula])
	_check(probes > 400 and wrong_body == 0, "Across the brook the first surface a foot meets is the bed (the terrain is open beneath it)")
	_check(worst <= .012, "Bed collision lies on the drawn bed within 12 mm (%.4f)" % worst)
	_check(wet > 150 and deepest > .40 and worst_formula < .06, "The walkable bed is really under water and follows the shared mask (deepest %.2f m)" % deepest)
	# Water sheet: level, between the waterlines, over a bed that is below it.
	var level := true
	var dry := 0
	for v in water:
		level = level and absf(v.y - Land.WATER_SURFACE_Y) < .0001
		dry += int(Land.water_distance(Vector2(v.x, v.z), source) > .06)
	_check(level and dry == 0 and water.size() > 600, "The water surface is level and stays between its waterlines (%d vertices beyond)" % dry)
	# Bridge: the deck carries the walker; the rails keep him on it.
	var deck_low := INF
	var deck_high := -INF
	for x in range(-32, -23):
		var hit := _floor(x + .2, Land.BRIDGE_Z)
		deck_low = minf(deck_low, hit.position.y)
		deck_high = maxf(deck_high, hit.position.y)
	_check(absf(deck_low - Brook.DECK_TOP_Y) < .005 and absf(deck_high - Brook.DECK_TOP_Y) < .005, "On the bridge the walkable surface is the plank top (%.3f..%.3f m)" % [deck_low, deck_high])
	# The terrain keeps every other cell: openings are whole cells under this ground.
	for opening in Brook.TERRAIN_OPENINGS:
		_check(is_equal_approx(opening.position.x / Brook.CELL_M, round(opening.position.x / Brook.CELL_M)) and is_equal_approx(opening.end.y / Brook.CELL_M, round(opening.end.y / Brook.CELL_M)) and Rect2(Brook.APRON.position.x, Brook.PLANE.position.y, -Brook.APRON.position.x, Brook.APRON.end.y - Brook.PLANE.position.y).encloses(opening), "Terrain opening %s is cell aligned and covered by the village ground" % opening)


func _test_wading() -> void:
	var player: CharacterBody3D = world.get_node("Player")
	var terrain: Node3D = world.regional_terrain
	world._camera_yaw = 0.0
	world._figure.rotation.y = 0.0
	for run: Dictionary in [{"label":"wade_west", "z":-22.0}, {"label":"bridge_west", "z":Land.BRIDGE_Z}]:
		player.position = Vector3(-21.9, 1.0, run.z)
		player.velocity = Vector3.ZERO
		world._touch_move = Vector2.ZERO
		world._running = false
		for frame in 30:
			await physics_frame
			world._move_player(1.0 / 60.0)
		world._touch_move = Vector2(-1, 0)
		var lowest := INF
		var highest := -INF
		var floor_frames := 0
		var frames := 0
		for frame in 900:
			await physics_frame
			world._move_player(1.0 / 60.0)
			terrain.follow(player.global_position, "balanced")
			frames += 1
			var foot := player.global_position.y - .9
			if absf(player.global_position.x - Land.brook_x(run.z)) < 3.0:
				lowest = minf(lowest, foot)
				highest = maxf(highest, foot)
			floor_frames += int(player.is_on_floor())
			if player.global_position.x < -36.5:
				break
		world._touch_move = Vector2.ZERO
		print("VILLAGE_LANDSCAPE %s end=%s frames=%d on_floor=%d lowest_foot_m=%.3f highest_foot_m=%.3f" % [run.label, player.global_position, frames, floor_frames, lowest, highest])
		_check(player.global_position.x < -36.5 and floor_frames >= frames * .95, "%s: the walker reaches the west bank on solid footing" % run.label)
		if run.label == "wade_west":
			_check(lowest < Land.WATER_SURFACE_Y - .35 and lowest > -Land.BED_DEPTH_M - .03, "Wading: the feet go down to the bed, %.2f m under the water surface" % (Land.WATER_SURFACE_Y - lowest))
		else:
			_check(lowest > Brook.DECK_TOP_Y - .03 and highest < Brook.DECK_TOP_Y + .03, "Bridge: the feet stay on the deck (%.3f..%.3f m)" % [lowest, highest])


func _test_far_relief() -> void:
	var relief: Node3D = world.far_relief
	_check(relief.get_child_count() == 2 and relief.find_children("*", "CollisionObject3D", true, false).is_empty(), "The far relief is two meshes without collision")
	var camera: Camera3D = world.get_node("WorldCamera")
	var reach := 0.0
	var highest := 0.0
	var steepest_view := 0.0
	var inside := 0.0
	var massif := (relief.get_node("Massif") as MeshInstance3D).mesh.get_faces()
	for v in massif:
		reach = maxf(reach, Vector2(v.x, v.z).length())
		highest = maxf(highest, v.y)
		steepest_view = maxf(steepest_view, rad_to_deg(atan(v.y / Vector2(v.x, v.z).length())))
	for i in 4000:
		var p := Vector2(-Plan.WORLD_HALF_M + Plan.WORLD_SIZE_M * (i % 63) / 62.0, -Plan.WORLD_HALF_M + Plan.WORLD_SIZE_M * (i / 63) / 63.0)
		inside = maxf(inside, FarRelief.massif_height(p))
	print("VILLAGE_LANDSCAPE far_relief camera_far_m=%.0f farthest_vertex_m=%.0f highest_m=%.0f max_elevation_from_village_deg=%.2f massif_inside_region_m=%.3f" % [camera.far, reach, highest, steepest_view, inside])
	_check(camera.far > reach + 500.0, "The world camera reaches the farthest vertex of the range")
	_check(inside == 0.0, "The range adds nothing inside the 32 km region or to its south")
	_check(highest > 1500.0 and steepest_view > 2.0 and steepest_view < 9.0, "The range stands %.1f degrees above the horizon seen from Valdora" % steepest_view)
	# Every coarser grid must stay below the finer surface above it, and the
	# finest below the streamed terrain, or coarse ground would show through.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5812
	var near_faces := (relief.get_node("Near") as MeshInstance3D).mesh.get_faces()
	var buckets := {}
	for i in range(0, near_faces.size(), 3):
		var mid := (near_faces[i] + near_faces[i + 1] + near_faces[i + 2]) / 3.0
		var size := absf(near_faces[i + 1].x - near_faces[i].x) + absf(near_faces[i + 1].z - near_faces[i].z)
		var level := roundi(log(maxf(size, 1.0) / 250.0) / log(2.0))
		if not buckets.has(level):
			buckets[level] = PackedVector3Array()
		var list: PackedVector3Array = buckets[level]
		list.append_array([near_faces[i], near_faces[i + 1], near_faces[i + 2]])
		buckets[level] = list
	var smallest_gap := INF
	var compared := 0
	for sample in 500:
		var radius := rng.randf_range(0.0, 15500.0)
		var angle := rng.randf_range(0.0, TAU)
		var p := Vector2(cos(angle), sin(angle)) * radius
		var heights := []
		if radius < 1200.0:
			heights.append(Terrain.surface_height(p))
		for level in FarRelief.LEVELS:
			var h := _mesh_height(buckets.get(level, PackedVector3Array()), p)
			if h > -INF:
				heights.append(h)
		for i in heights.size() - 1:
			compared += 1
			smallest_gap = minf(smallest_gap, heights[i] - heights[i + 1])
	print("VILLAGE_LANDSCAPE far_relief levels=%d overlap_samples=%d smallest_gap_finer_above_coarser_m=%.2f" % [buckets.size(), compared, smallest_gap])
	_check(buckets.size() == FarRelief.LEVELS and compared > 150 and smallest_gap > .25, "Finer ground always lies above the coarser grid beneath it (smallest gap %.2f m)" % smallest_gap)
	# Budget: the whole far relief is two draw calls and a small share of the
	# visible primitives each profile may show.
	for profile: String in ["low", "balanced", "high", "very_high"]:
		relief.follow(Vector3.ZERO, profile)
		var limit := int(PROFILES.data.profiles[profile].review_limits.visible_primitives)
		print("VILLAGE_LANDSCAPE far_relief profile=%s triangles=%d share_of_visible_primitives=%.1f%%" % [profile, relief.triangles, relief.triangles * 100.0 / limit])
		_check(relief.triangles * 20 <= limit, "%s: far relief stays under 5 %% of the profile's visible primitives (%d of %d)" % [profile, relief.triangles, limit])
	relief.follow(Vector3.ZERO, "balanced")
	var before := (relief.get_node("Near") as MeshInstance3D).mesh
	relief.follow(Vector3(120, 0, -160), "balanced")
	_check((relief.get_node("Near") as MeshInstance3D).mesh == before, "Walking around the village never rebuilds the far relief")
	relief.follow(Vector3(700, 0, 0), "balanced")
	_check((relief.get_node("Near") as MeshInstance3D).mesh != before, "Leaving the village's 500 m cell re-centres the near grids")
	relief.follow(Vector3.ZERO, "balanced")


func _test_materials() -> void:
	# Sector normals come from the height field, so shading continues across
	# sector borders.
	var terrain: Node3D = world.regional_terrain
	var worst := 0.0
	var shared := 0
	var a: Node3D = terrain.sectors[Plan.sector_id(Plan.sector_for_position(Vector3(300, 0, 300)))]
	var b: Node3D = terrain.sectors[Plan.sector_id(Plan.sector_for_position(Vector3(600, 0, 300)))]
	var arrays_a := (a.get_node("Ground") as MeshInstance3D).mesh.surface_get_arrays(0)
	var arrays_b := (b.get_node("Ground") as MeshInstance3D).mesh.surface_get_arrays(0)
	var border := {}
	for i in (arrays_a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = arrays_a[Mesh.ARRAY_VERTEX][i] + a.position
		if absf(v.x - 500.0) < .001:
			border[roundi(v.z * 100.0)] = arrays_a[Mesh.ARRAY_NORMAL][i]
	for i in (arrays_b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		var v: Vector3 = arrays_b[Mesh.ARRAY_VERTEX][i] + b.position
		if absf(v.x - 500.0) < .001 and border.has(roundi(v.z * 100.0)):
			shared += 1
			worst = maxf(worst, (border[roundi(v.z * 100.0)] as Vector3).angle_to(arrays_b[Mesh.ARRAY_NORMAL][i]))
	_check(shared >= 13 and worst < .0005, "Normals agree on a shared sector border (%d vertices, %.5f rad)" % [shared, worst])
	# One list of land materials follows season and haze together.
	var materials: Array = scenery.land_materials
	_check(materials.size() == 4 and materials.has(terrain.ground_material) and materials.has(world.far_relief.material), "Village ground, hills, terrain and far relief share one land material list")
	scenery._sync_atmosphere()
	var environment: Environment = world.get_world_3d().environment
	var same := true
	for material: ShaderMaterial in materials:
		same = same and is_equal_approx(float(material.get_shader_parameter("haze_density")), environment.fog_density) \
			and material.get_shader_parameter("season_tint") == materials[0].get_shader_parameter("season_tint") \
			and material.get_shader_parameter("verge_color") == materials[0].get_shader_parameter("verge_color")
	_check(environment.fog_enabled and same, "All land materials carry the environment's haze, the season tint and the village turf")
