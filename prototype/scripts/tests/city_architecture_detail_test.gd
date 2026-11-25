extends SceneTree
## Exercises exported resources and real physics openings in an isolated scene.

const Detail := preload("res://scripts/rendering/city_architecture_detail.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func verify(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)


func _run() -> void:
	verify(Detail.module_ids().size() == 7, "Seven architecture modules are available")
	for id in Detail.module_ids():
		var previous_triangles := 2147483647
		for lod in 3:
			var module := Detail.create_module(id, lod, true)
			verify(module != null, id + " loads at LOD " + str(lod))
			if module == null:
				continue
			var visual := module.get_node("Visual") as MeshInstance3D
			var mesh := visual.mesh as ArrayMesh
			var triangles := 0
			var complete_pbr := true
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				triangles += int((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)
				var mat := mesh.surface_get_material(surface) as BaseMaterial3D
				complete_pbr = complete_pbr and mat != null and mat.albedo_texture != null and mat.normal_enabled
				complete_pbr = complete_pbr and mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			verify(triangles > 0 and triangles < previous_triangles, id + " LOD strictly reduces actual triangles")
			verify(complete_pbr, id + " retains PBR maps and mipmapped anisotropic filtering")
			previous_triangles = triangles
			var same := Detail.create_module(id, lod)
			verify((same.get_node("Visual") as MeshInstance3D).mesh == mesh, id + " instances share the cached mesh")
			same.free()
			module.free()
	var batch := Detail.create_multimesh("basoli_4m", [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(4, 0, 0))])
	verify(batch != null and batch.multimesh.instance_count == 2, "Repeated paving uses MultiMesh")
	print("MULTIMESH_READBACK ", batch.multimesh.get_instance_transform(1), " renderer=", RenderingServer.get_current_rendering_method())
	verify(batch.multimesh.get_instance_transform(1).origin == Vector3(4, 0, 0), "MultiMesh placement is preserved")
	batch.free()
	verify(Detail.lod_for_distance(0, 0) == 2, "Light quality requests the least expensive mesh")
	verify(Detail.lod_for_distance(10, 2) == 0 and Detail.lod_for_distance(60, 2) == 2, "High quality has bounded distance detail")
	var world := Node3D.new()
	root.add_child(world)
	var shop := Detail.create_module("taberna_4m", 0, true)
	world.add_child(shop)
	var counter := Detail.create_module("dolia_counter", 0)
	counter.position.x = 10.0
	world.add_child(counter)
	# Test true GLB openings using a temporary triangle shape, never the runtime collider.
	(counter.get_node("Visual") as MeshInstance3D).create_trimesh_collision()
	await physics_frame
	await physics_frame
	var space := world.get_world_3d().direct_space_state
	var doorway := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1, 2), Vector3(0, 1, .6)))
	verify(doorway.is_empty(), "Shop entrance has no invisible blocking box")
	var jamb := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.65, 1, 2), Vector3(1.65, 1, .6)))
	verify(not jamb.is_empty(), "The wall beside the doorway blocks a ray")
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, .5, 0), Vector3(0, -.5, 0)))
	var floor_position: Vector3 = floor_hit.get("position", Vector3.ONE)
	verify(not floor_hit.is_empty() and absf(floor_position.y) < .001, "Shop floor matches nominal ground")
	var dolium_hole := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10, 1.3, 0), Vector3(10, .5, 0)))
	verify(dolium_hole.is_empty(), "Dolium opening is actual geometry, not a painted dark circle")
	var counter_top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(10.32, 1.3, 0), Vector3(10.32, .5, 0)))
	verify(not counter_top.is_empty(), "Stone worktop surrounds the opening")
	world.free()
	print("CITY_ARCHITECTURE_DETAIL_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
