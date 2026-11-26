extends SceneTree
## Exercise the production terrain adapter with real meshes and physics.

const Terrain := preload("res://scripts/world/regional_terrain.gd")
const Plan := preload("res://scripts/world/world_stream_plan.gd")
var checks := 0
var failures := 0
var timings: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ",label)


func _follow(terrain: Node3D, position: Vector3, quality: String) -> void:
	var before_meshes := {}
	var before_colliders := {}
	for sector: Node3D in terrain.sectors.values():
		before_meshes[sector.get_instance_id()] = true
		if sector.has_node("GroundCollision"):
			before_colliders[sector.get_node("GroundCollision").get_instance_id()] = true
	var started := Time.get_ticks_usec()
	terrain.follow(position,quality)
	var elapsed_ms := float(Time.get_ticks_usec()-started)/1000.0
	var report: Dictionary = terrain.report()
	var actual_mesh_builds := 0
	var actual_collider_builds := 0
	var retained_meshes := 0
	for sector: Node3D in terrain.sectors.values():
		actual_mesh_builds += int(not before_meshes.has(sector.get_instance_id()))
		retained_meshes += int(before_meshes.has(sector.get_instance_id()))
		if sector.has_node("GroundCollision"):
			actual_collider_builds += int(not before_colliders.has(sector.get_node("GroundCollision").get_instance_id()))
	_check(actual_mesh_builds <= Terrain.MESH_BUILD_BUDGET and actual_collider_builds <= Terrain.COLLIDER_BUILD_BUDGET, "Observed mesh and collider instances obey their separate budgets")
	_check(before_meshes.size()-retained_meshes <= Terrain.UNLOAD_BUDGET, "Observed removed sector instances obey retirement budget")
	if position.is_finite():
		_check(report.last_mesh_builds == actual_mesh_builds and report.last_collider_builds == actual_collider_builds and report.last_unloads == before_meshes.size()-retained_meshes, "Diagnostics agree with actual instance changes")
	_check(report.last_mesh_builds <= Terrain.MESH_BUILD_BUDGET, "Mesh builds stay within the per-follow budget")
	_check(report.last_collider_builds <= Terrain.COLLIDER_BUILD_BUDGET, "Collider builds, including promotions, stay within the per-follow budget")
	_check(report.last_unloads <= Terrain.UNLOAD_BUDGET, "Mesh retirements stay within the per-follow budget")
	_check(report.loaded_sectors <= report.resident_limit and report.collision_sectors <= report.collision_limit, "Transitional residency and live physics remain bounded")
	timings.append({"quality":quality,"elapsed_ms":elapsed_ms,
		"loaded":terrain.report().loaded_sectors})


func _drain(terrain: Node3D, position: Vector3, quality: String) -> void:
	var count := 0
	while terrain.report().pending_work > 0 and count < 100:
		var before: int = terrain.report().loaded_sectors
		_follow(terrain,position,quality)
		_check(terrain.report().loaded_sectors-before <= 2,"Each continuation creates at most two sectors")
		count += 1
	_check(terrain.report().pending_work == 0,"Bounded demand finishes loading, collider upgrades and retirement")


func _ray(stage: Node3D, position: Vector3, down: bool = true) -> Dictionary:
	var start := Vector3(position.x,600.0,position.z)
	var finish := Vector3(position.x,-100.0,position.z)
	var query := PhysicsRayQueryParameters3D.create(start if down else finish,finish if down else start)
	query.hit_back_faces = false
	return stage.get_world_3d().direct_space_state.intersect_ray(query)


func _test_mesh(terrain: Node3D, position: Vector3) -> void:
	var cell: Vector2i = Plan.sector_for_position(position)
	var sector: Node3D = terrain.sectors[Plan.sector_id(cell)]
	var ground: MeshInstance3D = sector.get_node("Ground")
	var mesh: ArrayMesh = ground.mesh
	_check(mesh.get_surface_count() == 1,"Terrain uses one mesh surface")
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(vertices.size() == Terrain.GRID*Terrain.GRID*6 and normals.size() == vertices.size(),"Actual mesh contains the expected triangles and normals")
	_check(colors.size() == vertices.size() and uv.size() == vertices.size(),"Every terrain vertex has material color and UV")
	var all_up := true
	var clockwise := true
	var finite := true
	var height_correct := true
	for i in vertices.size():
		all_up = all_up and normals[i].y > 0.8
		finite = finite and vertices[i].is_finite() and normals[i].is_finite()
		var global_position: Vector3 = vertices[i]+sector.position
		height_correct = height_correct and absf(global_position.y-(Plan.terrain_height(Vector2(global_position.x,global_position.z))-0.06)) < 0.001
	for i in range(0,vertices.size(),3):
		var face := (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
		clockwise = clockwise and face.y > 0.8 and face.dot(normals[i]) > 0.98
	_check(all_up,"Generated normals point above terrain")
	_check(clockwise,"Godot clockwise front faces match upward normals")
	_check(finite and height_correct,"All mesh vertices match finite global terrain heights")
	# The land shader takes its colours from source_color textures and
	# uniforms; vertex colours are weights (open ground: no scrub, no stone),
	# so no renderer has to guess the colour space of vertex data.
	var material := ground.material_override as ShaderMaterial
	_check(material != null and material == terrain.ground_material and material.shader == Terrain.LandSurface.TERRAIN_SHADER,"Production material is the shared land shader")
	_check(material.shader.code.contains("cull_back") and not material.shader.code.contains("unshaded"),"Land shader renders lit front faces")
	var open_ground := true
	for color in colors:
		open_ground = open_ground and color == Terrain.OPEN_GROUND
	_check(open_ground,"Every open terrain vertex carries zero scrub and stone weights")
	for key: String in ["verge_color","road_color","verge_relief","road_relief","macro_field","scree_color"]:
		_check(material.get_shader_parameter(key) is Texture2D,"Land shader input %s is set" % key)
	# The static surface helper (used by grid-aligned scenery) reproduces the
	# actual triangles, including the diagonal split.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	var step := Plan.SECTOR_SIZE_M/float(Terrain.GRID)
	var helper_error := 0.0
	for sample in 300:
		var local := Vector2(rng.randf_range(0.0,Plan.SECTOR_SIZE_M-.001),rng.randf_range(0.0,Plan.SECTOR_SIZE_M-.001))
		var ix := floori(local.x/step)
		var iz := floori(local.y/step)
		var fx := local.x/step-ix
		var fz := local.y/step-iz
		var base := (iz*Terrain.GRID+ix)*6
		var a: Vector3 = vertices[base]
		var b: Vector3 = vertices[base+1]
		var c: Vector3 = vertices[base+2]
		var d: Vector3 = vertices[base+4]
		var mesh_height := a.y+(b.y-a.y)*fx+(c.y-a.y)*fz if fx+fz <= 1.0 else d.y+(c.y-d.y)*(1.0-fx)+(b.y-d.y)*(1.0-fz)
		helper_error = maxf(helper_error,absf(Terrain.surface_height(Vector2(sector.position.x+local.x,sector.position.z+local.y))-mesh_height))
	_check(helper_error < .001,"Terrain.surface_height matches the generated triangles (%.6f m)" % helper_error)
	_check(sector.has_node("GroundCollision"),"Player sector owns a real collision body")


func _check_residency(terrain: Node3D, position: Vector3, quality: String) -> void:
	var demand: Dictionary = Plan.plan(position,quality)
	var desired := {}
	var collisions := 0
	for entry in demand.sectors:
		desired[entry.id] = entry
		collisions += int(entry.collision)
	_check(terrain.sectors.size() == desired.size() and terrain.get_child_count() == desired.size(),"No stale sector nodes remain after stream settles")
	for id in terrain.sectors:
		_check(desired.has(id),"Loaded sector belongs to current demand")
		_check(terrain.sectors[id].has_node("GroundCollision") == desired[id].collision,"Physics follows current near ring")
	var report: Dictionary = terrain.report()
	_check(report.loaded_sectors <= report.active_limit and report.collision_sectors == collisions,"Actual nodes obey active and collision budgets")
	var built := 0
	var open_cells := 0
	for id in terrain.sectors:
		var faces: int = (terrain.sectors[id].get_node("Ground") as MeshInstance3D).mesh.get_faces().size()/3
		built += faces
		open_cells += Terrain.GRID*Terrain.GRID-faces/2
	_check(report.triangles == built and built == (desired.size()*Terrain.GRID*Terrain.GRID-open_cells)*2,"Triangle report matches created geometry")
	# Only the cells that authored ground replaces (the sunk brook bed) are open.
	var expected_open := 0
	for id in terrain.sectors:
		var origin: Vector3 = terrain.sectors[id].position
		var step := Plan.SECTOR_SIZE_M/float(Terrain.GRID)
		for z in Terrain.GRID:
			for x in Terrain.GRID:
				expected_open += int(Terrain.AuthoredGround.replaces_terrain(Vector2(origin.x+(x+.5)*step,origin.z+(z+.5)*step)))
	_check(open_cells == expected_open and open_cells <= 13,"Terrain is open only under authored ground (%d cells)" % open_cells)


func _test_shared_edge(terrain: Node3D) -> void:
	var left: Node3D = terrain.sectors[Plan.sector_id(Vector2i(64,64))]
	var right: Node3D = terrain.sectors[Plan.sector_id(Vector2i(65,64))]
	var edge := {}
	var compared := 0
	var equal := true
	var left_vertices: PackedVector3Array = left.get_node("Ground").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var right_vertices: PackedVector3Array = right.get_node("Ground").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in left_vertices:
		if is_equal_approx(vertex.x,250.0):
			edge[snappedf(vertex.z,0.001)] = vertex.y
	for vertex in right_vertices:
		if is_zero_approx(vertex.x):
			var key := snappedf(vertex.z,0.001)
			compared += 1
			equal = equal and edge.has(key) and absf(float(edge.get(key,INF))-vertex.y) < 0.0001
	_check(edge.size() == Terrain.GRID+1 and compared > 0 and equal,"Actual adjacent meshes share every edge height without a geometric gap")


func _walk_boundary(stage: Node3D, terrain: Node3D, quality: String, start: Vector3, direction: Vector3) -> void:
	_follow(terrain,start,quality)
	_drain(terrain,start,quality)
	var initial_sector: Vector2i = Plan.sector_for_position(start)
	var body := CharacterBody3D.new()
	body.name = "TerrainWalkingProbe"
	body.floor_snap_length = 0.4
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	body.add_child(collision)
	stage.add_child(body)
	body.global_position = Vector3(start.x,Plan.terrain_height(Vector2(start.x,start.z))+1.1,start.z)
	var grounded_before := false
	var grounded_after := false
	var stays_supported := true
	for frame in 100:
		await physics_frame
		var delta := 1.0/float(Engine.physics_ticks_per_second)
		body.velocity.x = 0.0 if frame < 25 else direction.x * 4.0
		body.velocity.z = 0.0 if frame < 25 else direction.z * 4.0
		body.velocity.y -= 20.0*delta
		_follow(terrain,body.global_position,quality)
		body.move_and_slide()
		if frame == 24:
			grounded_before = body.is_on_floor()
		if frame > 25:
			stays_supported = stays_supported and body.is_on_floor()
		if Plan.sector_for_position(body.global_position) != initial_sector and body.is_on_floor():
			grounded_after = true
	_check(grounded_before,"Actual CharacterBody settles on generated terrain " + quality)
	_check((body.global_position-start).dot(direction) > 4.0 and grounded_after and stays_supported,"Actual CharacterBody walks across sector boundary without losing ground " + quality)
	_check(body.global_position.is_finite() and body.global_position.y > Plan.terrain_height(Vector2(body.global_position.x,body.global_position.z))+0.7,"Walking body stays above streamed collision")
	body.free()


func _test_stream_lifecycle(stage: Node3D, terrain: Node3D) -> void:
	var point := Vector3(2137,0,2427)
	_follow(terrain,point,"balanced")
	_drain(terrain,point,"balanced")
	var center_id: String = Plan.sector_id(Plan.sector_for_position(point))
	var center: Node3D = terrain.sectors[center_id]
	var center_instance := center.get_instance_id()
	var ground_instance: int = center.get_node("Ground").mesh.get_instance_id()
	var collision_instance := center.get_node("GroundCollision").get_instance_id()
	for _repeat in 6:
		_follow(terrain,point,"balanced")
		_check(terrain.report().last_mesh_builds == 0 and terrain.report().last_collider_builds == 0 and terrain.report().last_unloads == 0,"A settled stationary stream creates and retires nothing")
	_follow(terrain,point,"unrecognized")
	_check(terrain.report().quality == "balanced" and terrain.report().pending_work == 0,"Unknown quality resolves to the existing balanced demand")
	_follow(terrain,point,"another_unknown")
	_check(terrain.sectors[center_id].get_instance_id() == center_instance and center.get_node("Ground").mesh.get_instance_id() == ground_instance and center.get_node("GroundCollision").get_instance_id() == collision_instance,"Unchanged support reuses actual node, mesh and collider instances")
	_follow(terrain,point,"low")
	_drain(terrain,point,"low")
	_check(terrain.report().collision_sectors == 1,"Low quality retains one ground collider away from borders")
	_follow(terrain,point,"very_high")
	_check(terrain.report().last_collider_builds == 2 and terrain.report().pending_collisions > 0,"A large quality increase queues collider promotions after the first budgeted pair")
	_check(center.get_node("GroundCollision").get_instance_id() == collision_instance,"Player support is never rebuilt during quality upgrades")
	_drain(terrain,point,"very_high")
	_check_residency(terrain,point,"very_high")
	_check(Terrain.MAX_RESIDENT_SECTORS == int(Plan.plan(Vector3.ZERO,"very_high").active_limit),"Transition cap matches the largest configured residency")
	_follow(terrain,point,"low")
	_check(terrain.report().loaded_sectors > terrain.report().active_limit and terrain.report().retiring_sectors > 0,"Profile downgrade explicitly reports the unfinished retirement instead of claiming the lower cap")
	_check(terrain.report().collision_sectors == 1,"Old visual sectors do not retain obsolete collision during retirement")
	_drain(terrain,point,"low")
	_check_residency(terrain,point,"low")
	_check(terrain.sectors[center_id].get_instance_id() == center_instance,"The resident player sector survives upgrade and downgrade")
	_follow(terrain,Vector3(-6000,0,-6000),"very_high")
	_follow(terrain,Vector3(6000,0,6000),"high")
	_follow(terrain,point,"balanced")
	_drain(terrain,point,"balanced")
	_check_residency(terrain,point,"balanced")
	_check(terrain.report().pending_work == 0,"Relocation during loading cancels obsolete requests and converges on the last position")
	# Verify the physical floor ahead of the body center on the low profile.
	var near_edge := Vector3(1249.5,0,1014)
	_follow(terrain,near_edge,"low")
	_drain(terrain,near_edge,"low")
	var next_id: String = Plan.sector_id(Plan.sector_for_position(near_edge+Vector3.RIGHT))
	var next_sector: Node3D = terrain.sectors[next_id]
	var next_instance := next_sector.get_instance_id()
	await physics_frame
	await physics_frame
	_check(terrain.report().collision_sectors == 2 and not _ray(stage,near_edge+Vector3.RIGHT).is_empty(),"Low profile has real neighboring ground before the player center crosses an edge")
	_follow(terrain,near_edge-Vector3.RIGHT*2,"low")
	_drain(terrain,near_edge-Vector3.RIGHT*2,"low")
	_check(terrain.report().collision_sectors == 1 and terrain.sectors[next_id].get_instance_id() == next_instance,"Leaving the support margin releases neighbor physics without regenerating its mesh")
	var corner := Vector3(1249.5,0,1249.5)
	_follow(terrain,corner,"low")
	_drain(terrain,corner,"low")
	await physics_frame
	await physics_frame
	_check(terrain.report().collision_sectors == 4 and terrain.report().collision_limit == 4,"A low-profile corner has at most four physically supported cells")
	for offset: Vector3 in [Vector3.ZERO,Vector3(1,0,0),Vector3(0,0,1),Vector3(1,0,1)]:
		_check(not _ray(stage,corner+offset).is_empty(),"Actual collision covers each side of a sector corner")


func _run() -> void:
	var nodes_before := get_node_count()
	var orphans_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var stage := Node3D.new()
	root.add_child(stage)
	var terrain := Terrain.new()
	stage.add_child(terrain)
	var home := Vector3(12,0,8)
	_follow(terrain,home,"balanced")
	_check(terrain.report().loaded_sectors == 2,"First follow creates exactly two sectors")
	_check(terrain.sectors.has(Plan.sector_id(Plan.sector_for_position(home))),"First batch contains player sector")
	_drain(terrain,home,"balanced")
	_check_residency(terrain,home,"balanced")
	_test_mesh(terrain,home)
	_test_shared_edge(terrain)
	await physics_frame
	await physics_frame
	var hit := _ray(stage,home)
	_check(not hit.is_empty(),"Real downward physics ray reaches village terrain")
	if not hit.is_empty():
		_check(absf(hit.position.y+0.06) < 0.002 and hit.normal.y > 0.99,"Village collision is flat and faces upward")
	_check(_ray(stage,home,false).is_empty(),"Backface-disabled ray cannot hit underside")
	var stale_id := Plan.sector_id(Plan.sector_for_position(home))
	var stale_instance := int(terrain.sectors[stale_id].get_instance_id())
	var far := Vector3(2137,0,2427)
	_follow(terrain,far,"balanced")
	_check(terrain.report().retiring_sectors > 0, "A long relocation retires the old visual region incrementally")
	_check(not terrain.sectors.has(stale_id) or not terrain.sectors[stale_id].has_node("GroundCollision"), "Obsolete terrain collision stops immediately")
	_drain(terrain,far,"balanced")
	_check(not terrain.sectors.has(stale_id) and not is_instance_id_valid(stale_instance),"Removed distant sector is freed rather than detached")
	_check_residency(terrain,far,"balanced")
	_test_mesh(terrain,far)
	await physics_frame
	await physics_frame
	hit = _ray(stage,far)
	_check(not hit.is_empty(),"Real physics ray reaches positive-coordinate distant terrain")
	if not hit.is_empty():
		_check(absf(hit.position.y-(Plan.terrain_height(Vector2(far.x,far.z))-0.06)) < 0.15 and hit.normal.y > 0.8,"Distant collision height matches generated triangulation")
	for point in [Vector3(-2137,0,-2427),Vector3(249.9,0,8),Vector3(250.1,0,8),Vector3(-0.1,0,8),Vector3(-250.1,0,8)]:
		_follow(terrain,point,"balanced")
		await physics_frame
		await physics_frame
		hit = _ray(stage,point)
		_check(not hit.is_empty() and hit.normal.y > 0.8,"Player collision is available immediately across positive and negative sector edges")
	far = Vector3(-2137,0,-2427)
	_follow(terrain,far,"very_high")
	_drain(terrain,far,"very_high")
	_check_residency(terrain,far,"very_high")
	_check(terrain.report().loaded_sectors == 145,"Very-high profile reaches only its permitted demand")
	_follow(terrain,far,"low")
	_drain(terrain,far,"low")
	_check_residency(terrain,far,"low")
	_check(terrain.report().loaded_sectors == 33 and terrain.report().collision_sectors == 1,"Lowering quality removes excess meshes and bodies")
	var before_invalid: Dictionary = terrain.report()
	_follow(terrain,Vector3(NAN,0,0),"very_high")
	_check(terrain.report() == before_invalid,"Invalid follow leaves the live terrain intact")
	_follow(terrain,Vector3(15999,0,15999),"balanced")
	_drain(terrain,Vector3(15999,0,15999),"balanced")
	_check_residency(terrain,Vector3(15999,0,15999),"balanced")
	await physics_frame
	await physics_frame
	hit = _ray(stage,Vector3(15999,0,15999))
	_check(not hit.is_empty(),"Physics reaches the modeled world corner")
	await _test_stream_lifecycle(stage,terrain)
	for quality: String in ["low", "balanced", "high", "very_high"]:
		await _walk_boundary(stage,terrain,quality,Vector3(248,0,14),Vector3.RIGHT)
	await _walk_boundary(stage,terrain,"low",Vector3(-248,0,-14),Vector3.LEFT)
	await _walk_boundary(stage,terrain,"low",Vector3(248,0,248),Vector3(1,0,1).normalized())
	stage.free()
	await physics_frame
	await process_frame
	_check(get_node_count() == nodes_before,"Freeing streamed world returns node count to baseline")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans_before,"Stream lifecycle leaves no orphan nodes")
	var maximum_ms := 0.0
	var total_ms := 0.0
	for timing in timings:
		maximum_ms = maxf(maximum_ms,float(timing.elapsed_ms))
		total_ms += float(timing.elapsed_ms)
	print("REGIONAL_TERRAIN_TIMING calls=%d total_ms=%.3f maximum_call_ms=%.3f environment=headless_cpu_not_device_fps" % [timings.size(),total_ms,maximum_ms])
	print("REGIONAL_TERRAIN_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
