extends SceneTree
## Import the Godot project first, then run with --script and --path prototype.

const MODEL := "res://assets/roman_quarter/tablet/wax_tablet.glb"
const EXPECTED_SPAN := Vector2(0.295, 0.190)
const EXPECTED_MATERIALS := 6


func _initialize() -> void:
	_inspect.call_deferred()


func _inspect() -> void:
	var pack := load(MODEL) as PackedScene
	if pack == null:
		printerr("Wachstafel kann nicht geladen werden: ", MODEL)
		quit(1)
		return
	var prop := pack.instantiate() as Node3D
	root.add_child(prop)
	var meshes := prop.find_children("*", "MeshInstance3D", true, false)
	if prop is MeshInstance3D:
		meshes.append(prop)
	if meshes.size() != 1:
		printerr("Wachstafel erwartet ein zusammengefasstes Laufzeitmesh.")
		prop.free()
		quit(1)
		return
	var instance := meshes[0] as MeshInstance3D
	var extent: AABB = instance.global_transform * instance.mesh.get_aabb()
	var triangle_count := 0
	var textured := 0
	var normal_mapped := 0
	for index in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(index)
		triangle_count += int(arrays[Mesh.ARRAY_INDEX].size() / 3.0)
		var material := instance.mesh.surface_get_material(index) as StandardMaterial3D
		if material != null and material.albedo_texture != null:
			textured += 1
		if material != null and material.normal_enabled and material.normal_texture != null:
			normal_mapped += 1
	var dimensions := Vector2(extent.size.x, extent.size.z)
	var region_ok := (dimensions - EXPECTED_SPAN).length() <= .0002
	var support_ok := absf(extent.position.y) < .0002 and extent.size.y <= .019
	var materials_ok := instance.mesh.get_surface_count() == EXPECTED_MATERIALS and textured == 3 and normal_mapped == 3
	var geometry_ok := triangle_count > 1400 and triangle_count < 2500
	var passed := region_ok and support_ok and materials_ok and geometry_ok
	print("WAX_TABLET_%s basis_m=%s größe_m=%s dreiecke=%d materialien=%d farbtexturen=%d normalmaps=%d" %
		["PASS" if passed else "FAIL", extent.position, extent.size, triangle_count, instance.mesh.get_surface_count(), textured, normal_mapped])
	prop.free()
	quit(0 if passed else 1)
