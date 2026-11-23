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
	var started := Time.get_ticks_usec()
	terrain.follow(position,quality)
	timings.append({"quality":quality,"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"loaded":terrain.report().loaded_sectors})


func _drain(terrain: Node3D, position: Vector3, quality: String) -> void:
	var count := 0
	while terrain.report().pending_sectors > 0 and count < 100:
		var before: int = terrain.report().loaded_sectors
		_follow(terrain,position,quality)
		_check(terrain.report().loaded_sectors-before <= 2,"Each continuation creates at most two sectors")
		count += 1
	_check(terrain.report().pending_sectors == 0,"Bounded demand finishes loading")


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
	_check(ground.material_override.vertex_color_use_as_albedo and ground.material_override.cull_mode == BaseMaterial3D.CULL_BACK,"Production material renders colored front faces")
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
	_check(report.triangles == desired.size()*Terrain.GRID*Terrain.GRID*2,"Triangle report matches created geometry")


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


func _walk_boundary(stage: Node3D, terrain: Node3D) -> void:
	var start := Vector3(248.0,0.0,14.0)
	_follow(terrain,start,"balanced")
	_drain(terrain,start,"balanced")
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
		body.velocity.x = 0.0 if frame < 25 else 4.0
		body.velocity.y -= 20.0*delta
		_follow(terrain,body.global_position,"balanced")
		body.move_and_slide()
		if frame == 24:
			grounded_before = body.is_on_floor()
		if frame > 25:
			stays_supported = stays_supported and body.is_on_floor()
		if body.global_position.x > 251.0 and body.is_on_floor():
			grounded_after = true
	_check(grounded_before,"Actual CharacterBody settles on generated terrain")
	_check(body.global_position.x > 252.0 and grounded_after and stays_supported,"Actual CharacterBody walks across sector boundary without losing ground")
	_check(body.global_position.is_finite() and body.global_position.y > Plan.terrain_height(Vector2(body.global_position.x,body.global_position.z))+0.7,"Walking body stays above streamed collision")
	body.free()


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
	_check(not terrain.sectors.has(stale_id) and not is_instance_id_valid(stale_instance),"Removed distant sector is freed rather than detached")
	_drain(terrain,far,"balanced")
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
	await _walk_boundary(stage,terrain)
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
