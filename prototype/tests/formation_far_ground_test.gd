extends SceneTree
## Actual imported Roman far meshes, no fabricated sole positions.
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FORMATION_FAR_GROUND_FAIL ", label)

func _run() -> void:
	for role: String in Soldier.ROLES:
		var template: Node3D = Soldier._scene(role, 2).instantiate() as Node3D
		var instance: MeshInstance3D = template as MeshInstance3D
		if instance == null:
			var found: Array[Node] = template.find_children("*", "MeshInstance3D", true, false)
			if not found.is_empty():
				instance = found[0] as MeshInstance3D
		if instance == null or instance.mesh == null:
			_check(false, role + " imported static mesh exists")
			template.free()
			continue
		var source: Mesh = instance.mesh
		var grounded: Mesh = Soldier.far_mesh(role)
		_check(source.get_surface_count() == 1 and grounded != null and grounded.get_surface_count() == 1, role + " one authored surface")
		if grounded == null or source.get_surface_count() != 1 or grounded.get_surface_count() != 1:
			template.free()
			continue
		var raw: Array = source.surface_get_arrays(0)
		var fixed: Array = grounded.surface_get_arrays(0)
		var original: PackedVector3Array = raw[Mesh.ARRAY_VERTEX]
		var moved: PackedVector3Array = fixed[Mesh.ARRAY_VERTEX]
		var min_original: float = INF
		var min_moved: float = INF
		for point: Vector3 in original:
			min_original = minf(min_original, point.y)
		for point: Vector3 in moved:
			min_moved = minf(min_moved, point.y)
		_check(is_finite(min_original) and min_original > 0.000001, role + " actual source has a raised sole")
		_check(is_finite(min_moved) and absf(min_moved) <= 0.00001, role + " actual far mesh is grounded")
		_check(original.size() == moved.size() and not moved.is_empty(), role + " vertex count preserved")
		var max_delta_error: float = 0.0
		if original.size() != moved.size() or moved.is_empty():
			max_delta_error = INF
		else:
			for i: int in original.size():
				max_delta_error = maxf(max_delta_error, (original[i] - Vector3.UP * min_original).distance_to(moved[i]))
		_check(max_delta_error <= 0.00001, role + " only the measured uniform ground translation")
		_check(raw[Mesh.ARRAY_INDEX] == fixed[Mesh.ARRAY_INDEX], role + " exact triangle index order")
		_check(raw[Mesh.ARRAY_NORMAL] == fixed[Mesh.ARRAY_NORMAL] and raw[Mesh.ARRAY_TEX_UV] == fixed[Mesh.ARRAY_TEX_UV], role + " normals and UVs preserved")
		_check(source.surface_get_material(0) == grounded.surface_get_material(0), role + " original material retained")
		_check(grounded == Soldier.far_mesh(role), role + " one cached mesh for all instances")
		print("FORMATION_FAR_GROUND_CASE ", JSON.stringify({"role":role,"source_floor_m":min_original,"grounded_floor_m":min_moved,"max_translation_error_m":max_delta_error}))
		template.free()
	print("FORMATION_FAR_GROUND_RESULT checks=%d failures=%d" % [checks, failures])
	print("FORMATION_FAR_GROUND_PASS" if failures == 0 else "FORMATION_FAR_GROUND_FAIL")
	quit(0 if failures == 0 else 1)
