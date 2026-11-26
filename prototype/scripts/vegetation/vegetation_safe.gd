extends RefCounted
## Android graphics recovery: use native static geometry, never a world-space
## vertex displacement or a packed custom-data instance buffer.
## The desktop vegetation path remains available for visual A/B comparisons.
const BARK := preload("res://scripts/vegetation/safe_bark.gdshader")
const LEAF := preload("res://scripts/vegetation/safe_leaf.gdshader")
const CARD := preload("res://scripts/vegetation/safe_card.gdshader")
const GRASS := preload("res://scripts/vegetation/safe_grass.gdshader")
const IMPOSTOR := preload("res://scripts/vegetation/safe_impostor.gdshader")
const STRIDE := 16

static func active() -> bool:
	# Always use this path on Android, regardless of profile or renderer.
	# A separate process can exercise the identical path on desktop CI.
	return OS.has_feature("android") or OS.get_environment("IMPERATHEN_VEGETATION_SAFE") == "1"


static func read_transform(data: PackedFloat32Array, offset: int) -> Transform3D:
	# RenderingServer documents these 12 transform floats in row-major order.
	return Transform3D(Basis(
		Vector3(data[offset],data[offset+4],data[offset+8]),
		Vector3(data[offset+1],data[offset+5],data[offset+9]),
		Vector3(data[offset+2],data[offset+6],data[offset+10])),
		Vector3(data[offset+3],data[offset+7],data[offset+11]))


static func valid_transform(t: Transform3D) -> bool:
	if not t.is_finite() or t.origin.abs().length() > 2000.0:
		return false
	var scale := t.basis.get_scale()
	if not scale.is_finite() or scale.x < .001 or scale.y < .001 or scale.z < .001 or maxf(scale.x,maxf(scale.y,scale.z)) > 12.0:
		return false
	if t.basis.determinant() <= .000000001:
		return false
	var x := t.basis.x.normalized()
	var y := t.basis.y.normalized()
	var z := t.basis.z.normalized()
	return absf(x.dot(y)) < .001 and absf(x.dot(z)) < .001 and absf(y.dot(z)) < .001


static func transforms(data: PackedFloat32Array, count: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if count < 0 or data.size() != count * STRIDE:
		return result
	result.resize(count)
	for i in count:
		var t := read_transform(data,i*STRIDE)
		if not valid_transform(t):
			result.clear()
			return result
		result[i] = t
	return result


static func new_multimesh(mesh: Mesh, capacity: int, bounds: AABB) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# No INSTANCE_CUSTOM, packed half-floats, or colour instance attributes.
	mm.use_custom_data = false
	mm.use_colors = false
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.custom_aabb = bounds
	mm.visible_instance_count = 0
	return mm


static func upload(mm: MultiMesh, data: PackedFloat32Array, count: int) -> bool:
	mm.visible_instance_count = 0
	if mm.use_custom_data or mm.use_colors or count > mm.instance_count:
		push_error("VEGETATION_SAFE_INVALID_BATCH: unexpected instance format")
		return false
	var decoded := transforms(data,count)
	if decoded.size() != count or data.size() != count*STRIDE:
		push_error("VEGETATION_SAFE_INVALID_BATCH: invalid vegetation transform")
		return false
	for i in count:
		# The public transform API handles the renderer's native buffer layout.
		mm.set_instance_transform(i,decoded[i])
	mm.visible_instance_count = count
	return true


static func copy_uncompressed(source: Mesh) -> ArrayMesh:
	# Recreate the static imported vertex/index arrays with flags=0. No
	# compressed position attribute, inherited glTF LOD index table or skin.
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},0)
		mesh.surface_set_material(surface,source.surface_get_material(surface))
	return mesh


static func merge_cards(source: Mesh, data: PackedFloat32Array, count: int, centre: Vector3) -> ArrayMesh:
	# The herb atlas requires per-clump tile and colour. Bake these into UV2
	# and geometry on the CPU, rather than using INSTANCE_CUSTOM.
	# Each chunk has only one material/draw submission and local coordinates.
	if source == null or source.get_surface_count() != 1 or count <= 0 or count*STRIDE > data.size():
		return null
	var records := data.slice(0,count*STRIDE)
	var decoded := transforms(records,count)
	if decoded.size() != count:
		push_error("VEGETATION_SAFE_INVALID_CARDS: invalid chunk transform")
		return null
	var arrays := source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n := points.size()
	if n == 0 or normals.size() != n or colors.size() != n or uvs.size() != n:
		push_error("VEGETATION_SAFE_INVALID_CARDS: incomplete mesh attributes")
		return null
	if indices.is_empty():
		indices.resize(n)
		for i in n:
			indices[i] = i
	var vertices := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var tex := PackedVector2Array()
	var atlas_data := PackedVector2Array()
	var ids := PackedInt32Array()
	vertices.resize(n*count)
	ns.resize(n*count)
	cs.resize(n*count)
	tex.resize(n*count)
	atlas_data.resize(n*count)
	ids.resize(indices.size()*count)
	for i in count:
		var t := decoded[i]
		var normal_basis := t.basis.inverse().transposed()
		var tile := records[i*STRIDE+12]
		var variation := records[i*STRIDE+14]
		if not is_finite(tile) or not is_finite(variation) or tile < 0.0 or tile > .9375:
			push_error("VEGETATION_SAFE_INVALID_CARDS: atlas data outside bounds")
			return null
		for j in n:
			var dst := i*n+j
			vertices[dst] = t*points[j]-centre
			ns[dst] = (normal_basis*normals[j]).normalized()
			# UV2 carries exact atlas indices independently of any vertex
			# colour quantization or gamma conversion in the renderer.
			cs[dst] = colors[j]
			tex[dst] = uvs[j]
			atlas_data[dst] = Vector2(tile,clampf(variation,0.0,1.0))
		for j in indices.size():
			ids[i*indices.size()+j] = i*n+indices[j]
	var result_arrays := []
	result_arrays.resize(Mesh.ARRAY_MAX)
	result_arrays[Mesh.ARRAY_VERTEX] = vertices
	result_arrays[Mesh.ARRAY_NORMAL] = ns
	result_arrays[Mesh.ARRAY_COLOR] = cs
	result_arrays[Mesh.ARRAY_TEX_UV] = tex
	result_arrays[Mesh.ARRAY_TEX_UV2] = atlas_data
	result_arrays[Mesh.ARRAY_INDEX] = ids
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result_arrays,[],{},0)
	result.surface_set_material(0,source.surface_get_material(0))
	return result


static func crossed_impostor(size: float, bottom: float, views: int, material: Material) -> ArrayMesh:
	# Two real intersecting quads use orthogonal frames of the original atlas.
	# No camera-facing vertex reconstruction or world-space displacement.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var width := size*.5
	var total_views := maxi(1,views)
	for i in 2:
		var right := Vector3.RIGHT if i == 0 else Vector3.BACK
		var normal := Vector3.BACK if i == 0 else Vector3.LEFT
		var start := vertices.size()
		var frame := 0 if i == 0 else roundi(total_views*.25)%total_views
		vertices.append_array([-right*width+Vector3.UP*bottom,right*width+Vector3.UP*bottom,
			right*width+Vector3.UP*(bottom+size),-right*width+Vector3.UP*(bottom+size)])
		normals.append_array([normal,normal,normal,normal])
		# Inset inside each atlas frame avoids neighbouring frame bleed.
		var u0 := (float(frame)+.002)/float(total_views)
		var u1 := (float(frame)+.998)/float(total_views)
		uvs.append_array([Vector2(u0,1),Vector2(u1,1),Vector2(u1,0),Vector2(u0,0)])
		indices.append_array([start,start+1,start+2,start,start+2,start+3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},0)
	mesh.surface_set_material(0,material)
	return mesh
