extends RefCounted
## A skin-space hand grip for the existing fifteen-bone actor. Adds one local
## morph; original face/age shapes and the shared source meshes stay intact.

static var _cache := {}
var _targets: Array[Dictionary] = []


func bind(model: Node3D, asset_path: String) -> void:
	_targets.clear()
	if not asset_path.begins_with("res://assets/characters/hero_quality_"):
		return
	var level := asset_path.get_file().trim_prefix("hero_quality_").trim_suffix(".glb")
	var path := "res://assets/characters/hero_hand_grip_%s.res" % level
	if not ResourceLoader.exists(path):
		return
	var authored := load(path)
	for instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(instance.name) != "HeroBody" or not instance.mesh is ArrayMesh:
			continue
		var source := instance.mesh as ArrayMesh
		var key := source.get_instance_id()
		var mesh: ArrayMesh
		if _cache.has(key):
			mesh = (_cache[key] as WeakRef).get_ref() as ArrayMesh
		if mesh == null:
			mesh = _with_grip(source, authored)
			_cache[key] = weakref(mesh)
		var weights := PackedFloat32Array()
		for shape in source.get_blend_shape_count():
			weights.append(instance.get_blend_shape_value(shape))
		instance.mesh = mesh
		for shape in weights.size():
			instance.set_blend_shape_value(shape, weights[shape])
		_targets.append({"mesh": instance, "index": mesh.get_blend_shape_count() - 1})
	set_grip(0.18)


func set_grip(amount: float) -> void:
	for target: Dictionary in _targets:
		if is_instance_valid(target.mesh):
			target.mesh.set_blend_shape_value(target.index, clampf(amount, 0.0, 1.0))


func _key(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x * 100000.0), roundi(point.y * 100000.0), roundi(point.z * 100000.0))


func _with_grip(source: ArrayMesh, authored: Resource) -> ArrayMesh:
	var positions: PackedVector3Array = authored.get_meta("positions")
	var deltas: PackedVector3Array = authored.get_meta("deltas")
	var rotations: PackedColorArray = authored.get_meta("rotations")
	var lookup := {}
	for index in positions.size():
		lookup[_key(positions[index])] = index
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = source.blend_shape_mode
	for shape in source.get_blend_shape_count():
		mesh.add_blend_shape(source.get_blend_shape_name(shape))
	mesh.add_blend_shape("HandGrip")
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var posed := vertices.duplicate()
		var posed_normals := normals.duplicate()
		var posed_tangents := tangents.duplicate()
		for index in vertices.size():
			var key := _key(vertices[index])
			if not lookup.has(key):
				continue
			var target: int = lookup[key]
			posed[index] += deltas[target]
			var encoded := rotations[target]
			var rotation := Basis(Quaternion(encoded.r, encoded.g, encoded.b, encoded.a))
			if not normals.is_empty():
				posed_normals[index] = (rotation * normals[index]).normalized()
			if not tangents.is_empty():
				var tangent := rotation * Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
				tangent = tangent.normalized()
				posed_tangents[index * 4] = tangent.x
				posed_tangents[index * 4 + 1] = tangent.y
				posed_tangents[index * 4 + 2] = tangent.z
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		if source.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
			for index in vertices.size():
				posed[index] -= vertices[index]
				if not normals.is_empty():
					posed_normals[index] -= normals[index]
			for index in tangents.size():
				posed_tangents[index] -= tangents[index]
		shape[Mesh.ARRAY_VERTEX] = posed
		if not normals.is_empty():
			shape[Mesh.ARRAY_NORMAL] = posed_normals
		if not tangents.is_empty():
			shape[Mesh.ARRAY_TANGENT] = posed_tangents
		var blends := source.surface_get_blend_shape_arrays(surface)
		blends.append(shape)
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, blends)
		mesh.surface_set_material(surface, source.surface_get_material(surface))
		mesh.surface_set_name(surface, source.surface_get_name(surface))
	return mesh
