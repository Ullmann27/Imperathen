class_name CityArchitectureDetail
extends RefCounted
## Reusable meshes for the separate city review. No campaign or economy authority.
## Assets are in metres, front +Z, local ground y=0. LODs are explicit (0..2).

const LIBRARY_PATH := "res://assets/city_detail/architecture/city_architecture_library.glb"
const MANIFEST_PATH := "res://assets/city_detail/architecture/architecture_manifest.json"
const MODULE_IDS: Array[String] = [
	"basoli_4m", "curb_4m", "taberna_4m", "dolia_counter",
	"market_canopy", "amphora_pair", "bread_display",
]

static var _meshes: Dictionary = {}
static var _manifest: Dictionary = {}


static func module_ids() -> Array[String]:
	return MODULE_IDS.duplicate()


static func create_module(module_id: String, lod: int = 0, with_collision: bool = false) -> Node3D:
	var record: Dictionary = _mesh_record(module_id, lod)
	if record.is_empty():
		return null
	var root := Node3D.new()
	root.name = module_id
	root.set_meta("city_detail_lod", clampi(lod, 0, 2))
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = record["mesh"] as Mesh
	visual.basis = record["basis"]
	root.add_child(visual)
	if with_collision:
		_add_colliders(root, module_id)
	return root


static func create_multimesh(module_id: String, transforms: Array, lod: int = 0) -> MultiMeshInstance3D:
	var record: Dictionary = _mesh_record(module_id, lod)
	if record.is_empty():
		return null
	for transform in transforms:
		if not transform is Transform3D:
			push_error("City architecture requires Transform3D instances")
			return null
	var batch := MultiMeshInstance3D.new()
	batch.name = module_id + "_batch"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = record["mesh"] as Mesh
	mm.instance_count = transforms.size()
	var source_transform := Transform3D(record["basis"], Vector3.ZERO)
	for index in transforms.size():
		mm.set_instance_transform(index, transforms[index] * source_transform)
	batch.multimesh = mm
	return batch


static func module_info(module_id: String) -> Dictionary:
	_load_manifest()
	return (_manifest.get("modules", {}).get(module_id, {}) as Dictionary).duplicate(true)


static func lod_for_distance(distance_metres: float, quality_index: int = 2) -> int:
	if quality_index <= 0:
		return 2
	if quality_index == 1:
		return 1 if distance_metres < 24.0 else 2
	var near_limit: float = 30.0 if quality_index >= 3 else 20.0
	var far_limit: float = 75.0 if quality_index >= 3 else 55.0
	return 0 if distance_metres < near_limit else (1 if distance_metres < far_limit else 2)


static func _mesh_record(module_id: String, lod: int) -> Dictionary:
	if not MODULE_IDS.has(module_id):
		push_error("Unknown city architecture module: " + module_id)
		return {}
	_load_meshes()
	return _meshes.get(module_id + "_lod" + str(clampi(lod, 0, 2)), {})


static func _load_meshes() -> void:
	if not _meshes.is_empty():
		return
	var packed := load(LIBRARY_PATH) as PackedScene
	if packed == null:
		push_error("City architecture GLB is missing or not imported")
		return
	var source: Node = packed.instantiate()
	var material_cache: Dictionary = {}
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var exported_mesh := instance.mesh.duplicate() as ArrayMesh
		for surface in exported_mesh.get_surface_count():
			var original := exported_mesh.surface_get_material(surface) as BaseMaterial3D
			if original == null:
				continue
			var key: int = original.get_instance_id()
			if not material_cache.has(key):
				var filtered := original.duplicate() as BaseMaterial3D
				filtered.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				material_cache[key] = filtered
			exported_mesh.surface_set_material(surface, material_cache[key])
		# Ignore the library's grid arrangement. Preserve any importer axis basis.
		var asset_basis: Basis = instance.basis
		var parent: Node = instance.get_parent()
		while parent != null and parent != source:
			if parent is Node3D:
				asset_basis = (parent as Node3D).basis * asset_basis
			parent = parent.get_parent()
		_meshes[String(instance.name)] = {"mesh": exported_mesh, "basis": asset_basis}
	source.free()


static func _load_manifest() -> void:
	if not _manifest.is_empty():
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("City architecture manifest is missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		_manifest = parsed


static func _add_colliders(root: Node3D, module_id: String) -> void:
	var info := module_info(module_id)
	var boxes: Array = info.get("collision_boxes_godot", [])
	if boxes.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "SimpleCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for box_data in boxes:
		var center: Array = box_data["center"]
		var size_values: Array = box_data["size"]
		var shape := BoxShape3D.new()
		shape.size = Vector3(float(size_values[0]), float(size_values[1]), float(size_values[2]))
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(float(center[0]), float(center[1]), float(center[2]))
		body.add_child(collision)
