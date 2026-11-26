extends RefCounted
## Six rigidly weighted pieces share a leather surface in the frontier civilian
## exports. Retain the original bone indices, skin, style and actor identity.
const PARTS := [&"HeroSandal_L", &"HeroSandal_R", &"HeroSandalStrap_L", &"HeroSandalStrap_L_001",
	&"HeroSandalStrap_R", &"HeroSandalStrap_R_001"]
# One weak entry per civilian family and authored LOD. A retired actor keeps
# neither the new mesh nor its material alive.
static var cached := {}

static func apply(body: Node3D, asset_path: String) -> bool:
	var parts: Array[MeshInstance3D] = []
	var names := {}
	for node in body.find_children("HeroSandal*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var normalized := StringName(String(part.name).replace(".", "_"))
		if normalized not in PARTS or names.has(normalized) or not _supported(part):
			return false
		if not parts.is_empty() and not _compatible(parts[0], part):
			return false
		names[normalized] = true
		parts.append(part)
	if parts.size() != PARTS.size():
		return false
	var first := parts[0]
	var source_id := first.mesh.get_instance_id()
	var entry: Dictionary = cached.get(asset_path, {})
	var merged: ArrayMesh
	if entry.get("source", 0) == source_id:
		merged = entry.mesh.get_ref() as ArrayMesh
	if not merged:
		merged = _join_arrays(parts)
		if not merged:
			return false
		cached[asset_path] = {"source":source_id, "mesh":weakref(merged)}
	var override := first.get_surface_override_material(0)
	first.mesh = merged
	first.set_surface_override_material(0, override)
	for index in range(1, parts.size()):
		parts[index].hide()
	return true

static func _join_arrays(parts: Array[MeshInstance3D]) -> ArrayMesh:
	var combined: Array = []
	combined.resize(Mesh.ARRAY_MAX)
	var indices := PackedInt32Array()
	var base := 0
	for part in parts:
		var arrays := part.mesh.surface_get_arrays(0)
		for slot in range(Mesh.ARRAY_INDEX):
			if arrays[slot] == null:
				continue
			if combined[slot] == null:
				combined[slot] = arrays[slot]
			else:
				combined[slot].append_array(arrays[slot])
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(base + int(index))
		base += arrays[Mesh.ARRAY_VERTEX].size()
	combined[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
	result.surface_set_material(0, parts[0].mesh.surface_get_material(0))
	return result

static func _supported(part: MeshInstance3D) -> bool:
	var mesh := part.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1 or mesh.get_blend_shape_count() != 0 or part.skin == null:
		return false
	if not part.visible or part.get_active_material(0) == null or not part.get_node_or_null(part.skeleton) is Skeleton3D:
		return false
	var expected := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FORMAT_INDEX
	var channels := (1 << Mesh.ARRAY_MAX) - 1
	return mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES \
		and (mesh.surface_get_format(0) & channels) == expected \
		and not (mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)

static func _compatible(first: MeshInstance3D, other: MeshInstance3D) -> bool:
	return first.get_parent() == other.get_parent() and first.transform.is_equal_approx(other.transform) \
		and first.skin == other.skin and first.skeleton == other.skeleton \
		and first.get_active_material(0) == other.get_active_material(0) \
		and first.mesh.surface_get_format(0) == other.mesh.surface_get_format(0) \
		and first.layers == other.layers and first.cast_shadow == other.cast_shadow \
		and first.visibility_range_begin == other.visibility_range_begin \
		and first.visibility_range_end == other.visibility_range_end
