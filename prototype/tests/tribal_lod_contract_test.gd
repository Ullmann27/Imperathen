extends SceneTree
## Static counterpart to the original formation transition regression.
## Compare the very same proxy points, real imported skin and the production
## far shader CPU mirror at identical phases. No runtime or asset mutation.
const Tribal := preload("res://scripts/visuals/valley_tribal_soldier.gd")
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
const Ranks := preload("res://scripts/visuals/far_ranks.gd")
const SkinFixture := preload("res://tests/motion_skin_measurement.gd")
const FAMILY := "forest_spear"
const LOD_JUMP_LIMIT := 0.04
const PHASES := [0.0, 0.15, 1.0/6.0, 0.29, 0.30555554, 0.5, 0.75, 0.999]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)

func _distance(point: Vector3, cloud: Array) -> float:
	var nearest := INF
	for vertex: Vector3 in cloud:
		nearest = minf(nearest, point.distance_to(vertex))
	return nearest

func _proxy_points(actor: Node3D, rig: Skeleton3D, side: String) -> Array:
	var index := rig.find_bone("Foot_" + side)
	if index < 0:
		return []
	var to_root := actor.global_transform.affine_inverse() * rig.global_transform
	var binding := rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()
	var x := -.126 if side == "R" else .126
	return [to_root * (binding * Vector3(x, .011, -.065)), to_root * (binding * Vector3(x, .011, .175))]

func _actual_foot_cloud(actor: Node3D, skin: RefCounted, side: String) -> Array:
	var points := []
	var minimum := INF
	var foot := 2 if side == "R" else 1
	for surface: Dictionary in skin.surfaces:
		var posed: PackedVector3Array = surface.get("last_posed", PackedVector3Array())
		var rig := surface.rig as Skeleton3D
		var feet: PackedInt32Array = surface.feet
		if posed.size() != feet.size():
			continue
		for i in feet.size():
			if feet[i] != foot:
				continue
			var point := actor.to_local(rig.global_transform * posed[i])
			if point.is_finite():
				minimum = minf(minimum, point.y)
				points.append(point)
	return points.filter(func(point): return point.y <= minimum + 0.03)

func _run() -> void:
	var far := Tribal.silhouette(FAMILY)
	check(far != null, "Actual authored far silhouette exists")
	if far == null:
		quit(1)
		return
	var vertices: PackedVector3Array = far.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var soles := {"R": [], "L": []}
	for vertex in vertices:
		if vertex.y <= .10 and absf(vertex.x) <= .205:
			soles["R" if vertex.x < 0 else "L"].append(vertex)
	check(not soles.R.is_empty() and not soles.L.is_empty(), "Original far sole regions both contain actual vertices")
	var report := []
	var maximum := 0.0
	for lod: int in [0, 1]:
		var actor := Tribal.new()
		actor.family = FAMILY
		actor.role = "spear"
		actor.detail = lod
		root.add_child(actor)
		# Use a rotated, translated production actor; every comparison is in
		# its local root coordinates, not mistaken skeleton/world coordinates.
		actor.position = Vector3(3.0, 0.0, -2.0)
		actor.rotation.y = 0.72
		var expected := "res://assets/germanic_warriors/%s_%d.glb" % [FAMILY, lod]
		check(actor._body != null and actor._body.scene_file_path == expected, "LOD %d loads exact source %s" % [lod, expected])
		var rigs: Array[Node] = actor.find_children("*", "Skeleton3D", true, false)
		check(rigs.size() == 1 and actor.player != null, "LOD %d real rig and animator exist" % lod)
		if rigs.size() != 1 or actor.player == null:
			actor.free()
			continue
		var rig := rigs[0] as Skeleton3D
		var skin := SkinFixture.new()
		skin.bind(actor._body)
		check(skin.errors.is_empty(), "LOD %d actual skin is bound: %s" % [lod, str(skin.errors)])
		for pose: String in ["idle", "block"]:
			check(actor.player.has_animation(pose), "LOD %d actual %s clip exists" % [lod, pose])
			if not actor.player.has_animation(pose):
				continue
			for phase: float in PHASES:
				actor.reset_presentation()
				actor.present(pose, phase, 0.0)
				rig.force_update_all_bone_transforms()
				var actual_phase := actor.player.current_animation_position / maxf(.00001, actor.player.current_animation_length)
				check(actor.player.assigned_animation == pose and absf(actual_phase-phase) <= .0001, "LOD %d %s %.6f samples requested phase" % [lod,pose,phase])
				var observed: Dictionary = skin.sample()
				check(bool(observed.finite), "LOD %d %s %.6f finite actual skin" % [lod,pose,phase])
				var gait := Ranks.gait_data(pose, phase, phase)
				var row := {"lod":lod,"pose":pose,"phase":phase,"actual_phase":actual_phase,"feet":{}}
				var worst := 0.0
				for side: String in ["R","L"]:
					var proxy := _proxy_points(actor,rig,side)
					var near := _actual_foot_cloud(actor,skin,side)
					var deformed := []
					for vertex: Vector3 in soles[side]:
						deformed.append(Ranks.deformed_vertex(vertex,gait,1.0))
					check(proxy.size() == 2 and not near.is_empty() and not deformed.is_empty(), "LOD %d %s %.6f %s samples real feet" % [lod,pose,phase,side])
					if proxy.size()!=2 or near.is_empty() or deformed.is_empty():
						continue
					if pose == "block":
						var x := -.126 if side == "R" else .126
						var guard_error := maxf((proxy[0] as Vector3).distance_to(Ranks.guard_vertex(Vector3(x,.011,-.065))), (proxy[1] as Vector3).distance_to(Ranks.guard_vertex(Vector3(x,.011,.175))))
						check(guard_error <= .002, "LOD %d %s %.6f %s authored guard hinge agrees with real rig %.6f m" % [lod,pose,phase,side,guard_error])
						row["guard_transform_error_" + side + "_m"] = guard_error
					var proxy_far := 0.0
					var proxy_near := 0.0
					var skin_far := 0.0
					for point: Vector3 in proxy:
						proxy_far = maxf(proxy_far,_distance(point,deformed))
						proxy_near = maxf(proxy_near,_distance(point,near))
					for point: Vector3 in near:
						skin_far = maxf(skin_far,_distance(point,deformed))
					worst = maxf(worst,proxy_far)
					row.feet[side] = {"proxy_to_far_m":proxy_far,"proxy_to_actual_sole_m":proxy_near,
						"actual_sole_to_far_m":skin_far,"actual_sole_vertices":near.size(),"far_sole_vertices":deformed.size()}
				maximum = maxf(maximum,worst)
				row["original_proxy_jump_m"] = worst
				report.append(row)
				check(worst <= LOD_JUMP_LIMIT, "LOD %d %s %.6f original sole jump %.6f <= 0.04 m" % [lod,pose,phase,worst])
		actor.free()
	check(report.size() == 32, "All 32 required LOD/pose/phase samples completed")
	for row: Dictionary in report:
		print("TRIBAL_LOD_CASE ", JSON.stringify(row))
	print("TRIBAL_LOD_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"max_proxy_jump_m":maximum,"samples":report.size()}))
	print("TRIBAL_LOD_PASS" if failures == 0 else "TRIBAL_LOD_FAIL")
	quit(0 if failures == 0 else 1)
