extends SceneTree

const Kit = preload("res://scripts/world/village/interior_kit.gd")
const Designs = preload("res://scripts/world/village/household_designs.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	Kit.release_meshes()
	Kit.ensure()
	var mesh: Mesh = Kit.meshes.get("table_bread")
	var expected_bounds: AABB = Kit.aabb("table_bread")
	var triangle_count := 0
	_check(mesh is ArrayMesh, "The production table_bread prop uses the authored ArrayMesh")
	_check(Kit.info.has("table_bread"), "The original table_bread manifest entry remains authoritative")
	_check(Kit.materials.has("bread_cut"), "The scored crust material is profile-managed")
	if mesh is ArrayMesh:
		var actual: AABB = mesh.get_aabb()
		var expected_max := expected_bounds.position + expected_bounds.size
		var actual_max := actual.position + actual.size
		_check(actual.position.x >= expected_bounds.position.x - 0.001 and actual_max.x <= expected_max.x + 0.001,
			"Serving-board geometry stays within the saved prop footprint on X")
		_check(actual.position.y >= expected_bounds.position.y - 0.001 and actual_max.y <= expected_max.y + 0.001,
			"Bread geometry stays within the saved prop height")
		_check(actual.position.z >= expected_bounds.position.z - 0.001 and actual_max.z <= expected_max.z + 0.001,
			"Serving-board geometry stays within the saved prop footprint on Z")
		_check(mesh.get_surface_count() == 3, "Board, loaf and scoring use three batched material surfaces")
		_check(Kit.material_for(mesh.surface_get_material(0)) == Kit.materials["oak"], "Board uses the existing oak PBR material")
		_check(Kit.material_for(mesh.surface_get_material(1)) == Kit.materials["food"], "Loaf uses the existing food PBR material")
		_check(Kit.material_for(mesh.surface_get_material(2)) == Kit.materials["bread_cut"], "Scoring uses the profile-managed cut material")
		triangle_count = _triangle_count(mesh)
		_check(triangle_count <= int(Kit.info["table_bread"]["triangles"]),
			"Authored geometry stays within the existing table_bread triangle budget")
	var placement_found := false
	for item: Dictionary in Designs.items("baker_home"):
		if item.get("prop", "") == "table_bread" and item.get("on", "") == "glb_table":
			placement_found = true
	_check(placement_found, "The production family breakfast still places bread on its table")
	var collision: Array = Kit.collision("table_bread")
	var collision_matches_manifest := false
	if collision.size() == 1:
		var shape: Shape3D = collision[0]["shape"]
		if shape is BoxShape3D:
			var box: BoxShape3D = shape
			var offset: Vector3 = collision[0]["offset"]
			collision_matches_manifest = box.size.distance_to(expected_bounds.size) <= 0.001 \
				and offset.distance_to(expected_bounds.get_center()) <= 0.001
	_check(collision_matches_manifest, "The existing footprint collider remains generated from the unchanged manifest")
	if failures.is_empty():
		print("OPERATION_PRIMA_ART_RESULT checks=%d failures=0 triangles=%d" % [checks, triangle_count])
		quit(0)
	else:
		printerr("OPERATION_PRIMA_ART_RESULT checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _triangle_count(mesh: ArrayMesh) -> int:
	var count := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			count += vertices.size() / 3
		else:
			count += indices.size() / 3
	return count
