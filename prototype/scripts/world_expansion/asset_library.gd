extends RefCounted
## Imported meshes are shared across spatial MultiMesh batches.
## Every GLB must import successfully; missing models are not replaced by primitives.
const WindController = preload("res://scripts/world_expansion/environment_controller.gd")
var assets: Dictionary = {}
var errors: Array[String] = []
var wind_materials: Array[ShaderMaterial] = []


func load_manifest_assets(manifest: Dictionary) -> bool:
	assets.clear()
	errors.clear()
	wind_materials.clear()
	var ids := {}
	for key in ["building_assets", "road_assets", "vegetation_assets"]:
		var values = manifest.get(key, [])
		if not values is Array:
			errors.append("Ungültige Assetliste: " + key)
			continue
		for value in values:
			if not value is Dictionary:
				errors.append("Ungültiger Asseteintrag: " + key)
				continue
			var definition: Dictionary = value
			var id := str(definition.get("id", ""))
			var lods: Array = definition.get("lods", [])
			if id.is_empty() or ids.has(id) or lods.size() != 3:
				errors.append("Asset-ID doppelt/leer oder LOD0–2 fehlen: " + id)
				continue
			ids[id] = true
			var meshes: Array[Mesh] = []
			var triangles: Array[int] = []
			var wind: bool = key == "vegetation_assets"
			for path_value in lods:
				var path := str(path_value)
				if not path.begins_with("res://assets/world_expansion/") or not path.ends_with(".glb"):
					errors.append("Assetpfad außerhalb des Weltpakets: " + path)
					break
				var mesh := _import_mesh(path, wind)
				if mesh == null:
					break
				meshes.append(mesh)
				triangles.append(_triangle_count(mesh))
			if meshes.size() == 3:
				assets[id] = {"definition": definition, "meshes": meshes, "triangles": triangles,
					"wind": wind, "category": str(definition.get("category", key))}
	return errors.is_empty() and not assets.is_empty()


func _import_mesh(path: String, wind: bool) -> Mesh:
	if not ResourceLoader.exists(path):
		errors.append("Modell oder Godot-Import fehlt: " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		errors.append("GLB konnte nicht als Szene geladen werden: " + path)
		return null
	var root := packed.instantiate()
	var pieces: Array[Dictionary] = []
	_collect_meshes(root, Transform3D.IDENTITY, pieces)
	var combined := ArrayMesh.new()
	for piece in pieces:
		var mesh: Mesh = piece.mesh
		var pose: Transform3D = piece.pose
		if absf(pose.basis.determinant()) < 0.00001:
			errors.append("Degenerierte Modelltransformation: " + path)
			root.free()
			return null
		var normal_basis := pose.basis.inverse().transposed()
		for surface in mesh.get_surface_count():
			if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				errors.append("Modelloberfläche enthält keine Dreiecke: " + path)
				root.free()
				return null
			var arrays: Array = mesh.surface_get_arrays(surface).duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in vertices.size():
				vertices[index] = pose * vertices[index]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for index in normals.size():
				normals[index] = (normal_basis * normals[index]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			for index in range(0, tangents.size(), 4):
				var tangent := (pose.basis * Vector3(tangents[index], tangents[index + 1], tangents[index + 2])).normalized()
				tangents[index] = tangent.x
				tangents[index + 1] = tangent.y
				tangents[index + 2] = tangent.z
				tangents[index + 3] *= signf(pose.basis.determinant())
			arrays[Mesh.ARRAY_TANGENT] = tangents
			if pose.basis.determinant() < 0.0:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if indices.is_empty():
					indices.resize(vertices.size())
					for index in vertices.size():
						indices[index] = index
				for index in range(0, indices.size(), 3):
					var second := indices[index + 1]
					indices[index + 1] = indices[index + 2]
					indices[index + 2] = second
				arrays[Mesh.ARRAY_INDEX] = indices
			if wind:
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				if colors.size() != vertices.size():
					errors.append("Windgewichte fehlen auf einer Vegetationsoberfläche: " + path)
					root.free()
					return null
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var material: Material = mesh.surface_get_material(surface)
			if wind:
				material = _wind_material(material)
			combined.surface_set_material(combined.get_surface_count() - 1, material)
	root.free()
	if combined.get_surface_count() == 0:
		errors.append("GLB enthält keine darstellbaren Meshes: " + path)
		return null
	return combined


func _collect_meshes(node: Node, parent_pose: Transform3D, pieces: Array[Dictionary]) -> void:
	var pose := parent_pose
	if node is Node3D:
		pose = parent_pose * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		pieces.append({"mesh": (node as MeshInstance3D).mesh, "pose": pose})
	for child in node.get_children():
		_collect_meshes(child, pose, pieces)


func _wind_material(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WindController.WIND_SHADER
	if source is BaseMaterial3D:
		var original := source as BaseMaterial3D
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("roughness_factor", original.roughness)
		material.set_shader_parameter("metallic_factor", original.metallic)
		material.set_shader_parameter("specular_factor", original.metallic_specular)
		material.set_shader_parameter("normal_scale", original.normal_scale)
		material.set_shader_parameter("uv_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
		material.set_shader_parameter("uv_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
		if original.albedo_texture != null:
			material.set_shader_parameter("has_albedo_texture", true)
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
		if original.normal_enabled and original.normal_texture != null:
			material.set_shader_parameter("has_normal_texture", true)
			material.set_shader_parameter("normal_texture", original.normal_texture)
		if original.roughness_texture != null:
			material.set_shader_parameter("has_roughness_texture", true)
			material.set_shader_parameter("roughness_texture", original.roughness_texture)
			var channels := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0.333333, 0.333333, 0.333333, 0)]
			var index := clampi(int(original.roughness_texture_channel), 0, channels.size() - 1)
			material.set_shader_parameter("roughness_channel", channels[index])
	wind_materials.append(material)
	return material


static func _triangle_count(mesh: Mesh) -> int:
	var result := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		result += int(float(indices.size() if not indices.is_empty() else vertices.size()) / 3.0)
	return result
