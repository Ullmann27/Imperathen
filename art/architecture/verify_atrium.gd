extends SceneTree
## After import, pass -- before or -- after with a graphical driver to save matched views.

const Village = preload("res://scripts/world/regional_village.gd")
const LOCATION := Vector3(14,0,-30)
const SHOTS := {
	"strasse": [Vector3(-3.5,2.38,12.6), Vector3(-0.15,1.67,4.25), 48.0],
	"dach": [Vector3(2.75,5.91,6.44),Vector3(0.10,2.73,-0.66),58.0],
	"hof": [Vector3(0.28,1.67,3.31), Vector3(-0.82,1.77,-0.91), 72.0]
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1200,750)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var village := Village.new()
	view.add_child(village)
	village.show_origin("italia")
	var house: Node3D
	for child in village.get_children():
		if child is Node3D and child.position.is_equal_approx(LOCATION):
			house = child
	if house == null:
		printerr("Atrium missing at its playable village location")
		quit(1)
		return
	var mesh_node = house.find_children("*","MeshInstance3D",true,false)[0]
	var mesh: ArrayMesh = mesh_node.mesh
	var array := mesh.surface_get_arrays(0)
	var tri_count: int = array[Mesh.ARRAY_INDEX].size()/3
	var surface: Dictionary = mesh.get("_surfaces")[0]
	var lod_data: Array = surface.get("lods",[])
	var lod_triangles: Array[int] = []
	var index_stride := 2 if int(surface.vertex_count) < 65536 else 4
	for i in range(1,lod_data.size(),2):
		var indices: PackedByteArray = lod_data[i]
		lod_triangles.append(indices.size() / (3*index_stride))
	var geometry := {"vertices":array[Mesh.ARRAY_VERTEX].size(),"triangles":tri_count,
		"surfaces":mesh.get_surface_count(), "bounds_min_m":[mesh.get_aabb().position.x,mesh.get_aabb().position.y,mesh.get_aabb().position.z],
		"bounds_size_m":[mesh.get_aabb().size.x,mesh.get_aabb().size.y,mesh.get_aabb().size.z],"imported_lod_triangles":lod_triangles}
	print("ATR_VISUAL geometry ",JSON.stringify(geometry))
	var error_list: Array[String] = []
	if mesh.get_surface_count() != 1:
		error_list.append("expected single batched surface")
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	var baseline := "--before" in OS.get_cmdline_user_args()
	if baseline and (tri_count != 4912 or surface.vertex_count != 8640):
		error_list.append("before requires the original eb0d6b2 mesh")
	if not baseline:
		if material == null or material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null or material.roughness_texture == null:
			error_list.append("missing packed PBR maps on imported material")
		var previous_count := tri_count
		for count in lod_triangles:
			if count >= previous_count:
				error_list.append("import LOD is not a reduction")
			previous_count = count
		if lod_triangles.is_empty():
			error_list.append("import generated no mesh LODs")
		if tri_count > 22000:
			error_list.append("triangle budget exceeded")
	await physics_frame
	await physics_frame
	var space := view.find_world_3d().direct_space_state
	var triangles := mesh.generate_triangle_mesh()
	for x in [-0.78,-0.54,0,0.54,0.78]:
		for height in [0.17,0.4,1.1,1.87,2.19]:
			var query := PhysicsRayQueryParameters3D.create(LOCATION+Vector3(x,height,6.1),LOCATION+Vector3(x,height,2.1))
			if not triangles.intersect_segment(Vector3(x,height,6.1),Vector3(x,height,2.1)).is_empty():
				error_list.append("render geometry crosses the open entrance")
			if not space.intersect_ray(query).is_empty():
				error_list.append("obstructed street entrance")
	for x in [-2.8,2.8]:
		var query := PhysicsRayQueryParameters3D.create(LOCATION+Vector3(x,1.45,6.1),LOCATION+Vector3(x,1.45,4.1))
		if space.intersect_ray(query).is_empty():
			error_list.append("facade lost collision")
	if "--after" in OS.get_cmdline_user_args() or baseline:
		if DisplayServer.get_name() == "headless":
			error_list.append("graphical driver needed for the render comparison")
		elif error_list.is_empty():
			await _capture(view,"before" if baseline else "after",error_list)
			geometry["rendered_lod_probe"] = await _probe_lods(mesh,error_list,not baseline)
	if ("--after" in OS.get_cmdline_user_args() or baseline) and error_list.is_empty():
		var report := FileAccess.open("res://../art/architecture/review/%s.json" % ("before" if baseline else "after"), FileAccess.WRITE)
		if report:
			report.store_string(JSON.stringify(geometry,"  ")+"\n")
		else:
			error_list.append("could not write comparison metrics")
	view.free()
	print("ATR_VISUAL errors ",error_list)
	quit(1 if not error_list.is_empty() else 0)

func _capture(view: SubViewport, suffix: String, errors: Array[String]) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#becad2")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#e1d9c8")
	world.environment.ambient_light_energy = 0.55
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	view.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47,-30,0)
	sun.light_energy = 0.52
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 34
	view.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(130,130)
	ground.position.y = -.035
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("#a18e71")
	ground.material_override = ground_material
	view.add_child(ground)
	var camera := Camera3D.new()
	view.add_child(camera)
	for label_text in SHOTS:
		var shot: Array = SHOTS[label_text]
		camera.position = LOCATION + shot[0]
		camera.look_at(LOCATION + shot[1])
		camera.fov = shot[2]
		for i in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://../art/architecture/review/%s_%s.png" % [label_text,suffix])
		var result := image.save_png(path)
		if result != OK:
			errors.append("Failed to save " + path)

func _probe_lods(mesh: Mesh, errors: Array[String], require_reduction: bool) -> Dictionary:
	# One drawable, no shadows or ground: viewport primitive counts measure the
	# mesh actually submitted by Compatibility, including its selected index LOD.
	var probe := SubViewport.new()
	probe.size = Vector2i(480,320)
	probe.own_world_3d = true
	probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(probe)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	probe.add_child(instance)
	var camera := Camera3D.new()
	camera.far = 800
	probe.add_child(camera)
	var counts := {}
	for distance in [12,70,150,330]:
		camera.position = Vector3(0,2.0,distance)
		camera.look_at(Vector3(0,1.7,0))
		for i in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		counts[str(distance)] = probe.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	if (require_reduction and counts["12"] <= counts["330"]) or counts["330"] <= 0:
		errors.append("visible-pass primitives do not fall at distance")
	print("ATR_LOD submission counts by distance: ",counts)
	probe.free()
	return counts
