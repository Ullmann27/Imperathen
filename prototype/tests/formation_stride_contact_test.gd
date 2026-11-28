extends SceneTree
## Independent static counterpart of the production LOD switch gate.
## Never changes a rig, mesh, shader, existing test, or its 40 mm limit.
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const Tribal = preload("res://scripts/visuals/valley_tribal_soldier.gd")
const Ranks = preload("res://scripts/visuals/far_ranks.gd")
const SkinFixture = preload("res://tests/motion_skin_measurement.gd")
const LIMIT := 0.04
const PHASES := [0.0, 0.125, 0.15, 1.0/6.0, 0.25, 0.29, 0.30555554, 0.4,
	0.5, 0.58, 0.625, 0.75, 0.853556589983631, 0.859454060518625,
	0.876738182739873, 0.894078019259369, 0.931037830504859, 0.958021960138087, 0.999]
const POSES := ["march", "run", "retreat"]
var checks := 0
var failures := 0
var samples := 0
var exceeding := 0
var max_jump := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("STRIDE_FAIL ", label)

func _xyz(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _nearest(point: Vector3, cloud: Array) -> Dictionary:
	var distance := INF
	var nearest := Vector3.ZERO
	for vertex: Vector3 in cloud:
		var candidate := point.distance_to(vertex)
		if candidate < distance:
			distance = candidate
			nearest = vertex
	return {"distance_m": distance, "point": _xyz(point), "nearest": _xyz(nearest)}

func _proxy_points(actor: Node3D, rig: Skeleton3D, side: String) -> Array:
	var index := rig.find_bone("Foot_" + side)
	if index < 0:
		return []
	var to_root := actor.global_transform.affine_inverse() * rig.global_transform
	var binding := rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()
	var x := -.126 if side == "R" else .126
	return [to_root * (binding * Vector3(x, .011, -.065)),
		to_root * (binding * Vector3(x, .011, .175))]

func _far_feet(mesh: Mesh) -> Dictionary:
	var result := {"L": [], "R": []}
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		if vertex.y <= .10 and absf(vertex.x) <= .205:
			result["R" if vertex.x < 0 else "L"].append(vertex)
	return result

func _deformed(feet: Dictionary, side: String, gait: Color) -> Array:
	var result := []
	for vertex: Vector3 in feet[side]:
		result.append(Ranks.deformed_vertex(vertex, gait, 1.0))
	return result

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
	return points.filter(func(point): return point.y <= minimum + .03)

func _sample(actor, rig: Skeleton3D, pose: String, phase: float) -> float:
	actor.reset_presentation()
	actor.present(pose, phase, 0.0)
	rig.force_update_all_bone_transforms()
	var length: float = actor.player.current_animation_length
	if length <= 0.0 or actor.player.assigned_animation != pose:
		return INF
	return float(actor.player.current_animation_position) / length

func _skin_diagnostic(actor, rig: Skeleton3D, skin, far_feet: Dictionary, pose: String, phase: float) -> Dictionary:
	var actual_phase := _sample(actor, rig, pose, phase)
	var phase_valid := is_finite(actual_phase) and absf(wrapf(actual_phase-phase, -.5, .5)) <= .0001
	_check(phase_valid, "Worst sample reproduced at requested phase")
	if not phase_valid:
		return {"valid": false}
	var observed: Dictionary = skin.sample()
	_check(bool(observed.get("finite", false)), "Actual imported skin is finite at worst sample")
	var result := {}
	var gait := Ranks.gait_data(pose, phase, phase)
	for side: String in ["R", "L"]:
		var near := _actual_foot_cloud(actor, skin, side)
		var far := _deformed(far_feet, side, gait)
		var proxy := _proxy_points(actor, rig, side)
		var valid: bool = not near.is_empty() and not far.is_empty() and proxy.size() == 2
		_check(valid, "Actual and far sole clouds exist for " + side)
		if not valid:
			continue
		var actual_far := 0.0
		for point: Vector3 in near:
			actual_far = maxf(actual_far, float(_nearest(point, far).distance_m))
		result[side] = {"near_count": near.size(), "far_count": far.size(),
			"actual_to_far_max_m": actual_far,
			"heel_to_actual": _nearest(proxy[0], near), "toe_to_actual": _nearest(proxy[1], near)}
	return result

func _run() -> void:
	var families: Array = Soldier.ROLES + Tribal.FAMILIES.values()
	for family: String in families:
		var roman: bool = family in Soldier.ROLES
		var mesh: Mesh = Soldier.far_mesh(family) if roman else Tribal.silhouette(family)
		_check(mesh != null and mesh.get_surface_count() > 0, "Original far mesh " + family)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var far_feet := _far_feet(mesh)
		_check(not far_feet.R.is_empty() and not far_feet.L.is_empty(), "Far sole vertices " + family)
		if far_feet.R.is_empty() or far_feet.L.is_empty():
			continue
		for lod: int in [0, 1]:
			var actor = Soldier.new() if roman else Tribal.new()
			if not roman:
				actor.family = family
			actor.role = family if roman else "spear"
			actor.detail = lod
			root.add_child(actor)
			actor.position = Vector3(3.0, 0.0, -2.0)
			actor.rotation.y = .72
			var expected: String = Soldier._scene(family, lod).resource_path if roman else "res://assets/germanic_warriors/%s_%d.glb" % [family, lod]
			var rigs: Array[Node] = actor.find_children("*", "Skeleton3D", true, false)
			var valid: bool = actor._body != null and actor._body.scene_file_path == expected and rigs.size() == 1 and actor.player != null
			_check(valid, "Exact production near/mid rig " + expected)
			if not valid:
				actor.free()
				continue
			var rig := rigs[0] as Skeleton3D
			var skin := SkinFixture.new()
			skin.bind(actor._body)
			_check(skin.errors.is_empty(), "Actual skin binds " + expected)
			for pose: String in POSES:
				_check(actor.player.has_animation(pose), "Production clip %s %s" % [expected, pose])
				if not actor.player.has_animation(pose):
					continue
				var worst := {"jump_m": -1.0}
				for phase: float in PHASES:
					var actual_phase := _sample(actor, rig, pose, phase)
					var phase_valid := is_finite(actual_phase) and absf(wrapf(actual_phase-phase, -.5, .5)) <= .0001
					_check(phase_valid, "%s %s %.9f actual phase" % [expected, pose, phase])
					if not phase_valid:
						continue
					var row := {"family": family, "lod": lod, "pose": pose, "phase": phase,
						"actual_phase": actual_phase, "jump_m": 0.0, "feet": {}}
					var gait := Ranks.gait_data(pose, phase, phase)
					for side: String in ["R", "L"]:
						var proxy := _proxy_points(actor, rig, side)
						var far := _deformed(far_feet, side, gait)
						_check(proxy.size() == 2 and not far.is_empty(), "Sole probes " + side)
						if proxy.size() != 2 or far.is_empty():
							continue
						var heel := _nearest(proxy[0], far)
						var toe := _nearest(proxy[1], far)
						row.feet[side] = {"heel": heel, "toe": toe}
						row.jump_m = maxf(float(row.jump_m), maxf(float(heel.distance_m), float(toe.distance_m)))
					if row.feet.size() != 2:
						continue
					samples += 1
					var jump: float = row.jump_m
					max_jump = maxf(max_jump, jump)
					if jump > LIMIT:
						exceeding += 1
					_check(jump <= LIMIT, "%s LOD%d %s %.9f: %.6f m exceeds original 40mm limit" % [family,lod,pose,phase,jump])
					if jump > float(worst.jump_m):
						worst = row
					print("STRIDE_CASE ", JSON.stringify(row))
				if float(worst.jump_m) >= 0.0:
					worst["actual_skin"] = _skin_diagnostic(actor, rig, skin, far_feet, pose, float(worst.phase))
					print("STRIDE_WORST ", JSON.stringify(worst))
			actor.free()
	var expected_samples := families.size() * 2 * POSES.size() * PHASES.size()
	_check(samples == expected_samples, "All %d static production samples measured" % expected_samples)
	print("FORMATION_STRIDE_RESULT ", JSON.stringify({"checks": checks, "failures": failures,
		"samples": samples, "expected_samples": expected_samples, "exceeding": exceeding, "max_proxy_jump_m": max_jump}))
	print("FORMATION_STRIDE_PASS" if failures == 0 else "FORMATION_STRIDE_FAIL")
	quit(0 if failures == 0 else 1)
