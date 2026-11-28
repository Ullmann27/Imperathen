extends SceneTree

const Kit = preload("res://scripts/world/village/interior_kit.gd")
const Designs = preload("res://scripts/world/village/household_designs.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Interiors = preload("res://scripts/world/village/house_interiors.gd")
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
	_check(Kit.materials.has("prima_bread_board") and Kit.materials.has("prima_bread_loaf")
		and Kit.materials.has("prima_bread_cut"), "All three authored PBR materials are profile-managed")
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
		_check(Kit.material_for(mesh.surface_get_material(0)) == Kit.materials["prima_bread_board"],
			"Board uses its dedicated wood material instead of unrelated atlas UVs")
		_check(Kit.material_for(mesh.surface_get_material(1)) == Kit.materials["prima_bread_loaf"],
			"Loaf uses its dedicated bread material instead of unrelated atlas UVs")
		_check(Kit.material_for(mesh.surface_get_material(2)) == Kit.materials["prima_bread_cut"],
			"Scoring uses its dedicated toasted-crust material")
		for name: String in ["prima_bread_board", "prima_bread_loaf", "prima_bread_cut"]:
			_check((Kit.materials[name] as StandardMaterial3D).albedo_texture == null,
				"%s avoids sampling unrelated packed material atlases" % name)
		_check(_mean_normal_y(mesh, 0) > 0.35, "Serving board faces have outward lit normals")
		_check(_mean_normal_y(mesh, 2) > 0.80, "Scored crust faces point toward the camera and lights")
		triangle_count = _triangle_count(mesh)
		_check(triangle_count <= int(Kit.info["table_bread"]["triangles"]),
			"Authored geometry stays within the existing table_bread triangle budget")
	var family_id: String = Designs.FAMILY
	var family_layout: Dictionary = {}
	for home: Dictionary in Layout.HOMES:
		if String(home.get("id", "")) == family_id:
			family_layout = home
	_check(family_id == "baker_home" and family_layout.size() > 0,
		"The I-01 family identifier resolves to a production village home")
	var layout_home_origin := Vector3.ZERO
	if not family_layout.is_empty():
		layout_home_origin = (family_layout.get("at", Vector3.ZERO) as Vector3) + Vector3.UP * Layout.HOUSE_FLOOR
	_check(layout_home_origin.distance_to(I01.HOME_ORIGIN) <= 0.001,
		"The production house origin matches the I-01 world-space anchor")
	var production_items: Array = Designs.items(family_id)
	var bread_placement_count := 0
	var bread_local_position := Vector2.ZERO
	for item: Dictionary in production_items:
		if item.get("prop", "") == "table_bread" and item.get("on", "") == "glb_table":
			bread_placement_count += 1
			bread_local_position = item.get("at", Vector2.ZERO)
	_check(bread_placement_count == 1, "The production family breakfast has one table bread placement")
	var builder := Interiors.new()
	var resolved: Array = builder.resolve(production_items, family_id)
	builder.free()
	var bread_world_position := Vector3.INF
	var resolved_bread_count := 0
	for record: Dictionary in resolved:
		if record.get("prop", "") == "table_bread":
			resolved_bread_count += 1
			bread_world_position = I01.HOME_ORIGIN + (record["transform"] as Transform3D).origin
	var expected_bread_world := layout_home_origin + Vector3(bread_local_position.x, Designs.GLB_TABLE.top, bread_local_position.y)
	_check(resolved_bread_count == 1 and bread_world_position.distance_to(expected_bread_world) <= 0.002,
		"The single bread mesh resolves to the I-01 family table at its production world coordinates")
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


func _mean_normal_y(mesh: ArrayMesh, surface: int) -> float:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var total_y := 0.0
	for normal in normals:
		total_y += normal.y
	return total_y / maxf(1.0, float(normals.size()))
