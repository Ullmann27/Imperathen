extends SceneTree
## Checks the released .glb and the actual Godot box collision scene. Optional -- --shots=/tmp/stable

func _initialize() -> void:
	check.call_deferred()

func check() -> void:
	var visual: Node3D = load("res://assets/roman_quarter/stable/stable.glb").instantiate()
	root.add_child(visual)
	var body: StaticBody3D = load("res://assets/roman_quarter/stable/stable_collision.tscn").instantiate()
	root.add_child(body)
	var instances:=visual.find_children("*","MeshInstance3D",true,false)
	if visual is MeshInstance3D:
		instances.append(visual)
	var mesh: ArrayMesh=instances[0].mesh
	var errors: Array[String]=[]
	if instances.size()!=1 or mesh.get_surface_count()!=3:
		errors.append("Expected a batched mesh with three surfaces")
	var lods: Array=[]
	var triangles: Array=[]
	var found_shared_atlas:=false
	for i in mesh.get_surface_count():
		var material:=mesh.surface_get_material(i) as StandardMaterial3D
		if material.normal_enabled and material.normal_texture and material.roughness_texture and material.albedo_texture:
			found_shared_atlas=material.albedo_texture.resource_path=="res://assets/village/valdorf_color.png"
		if material.resource_name=="Terra battuta":
			var arrays:=mesh.surface_get_arrays(i)
			var coords: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var extent:=Rect2(coords[0],Vector2.ZERO)
			for coord in coords:
				extent=extent.expand(coord)
			if extent.size.x<3.0 or extent.size.y<3.0:
				errors.append("Ground UVs lost during joining")
		var s: Dictionary=mesh.get("_surfaces")[i]
		triangles.append(int(s.get("index_count",s.vertex_count))/3)
		lods.append(s.get("lods",[]).size()/2)
	if not found_shared_atlas:
		errors.append("Missing shared color, normal or packed roughness map")
	await physics_frame
	await physics_frame
	var space:=root.world_3d.direct_space_state
	var horse:=BoxShape3D.new()
	horse.size=Vector3(.95,1.85,2.05)
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=horse
	query.collision_mask=1
	for side in [-1,1]:
		var points: Array[Vector2] = [Vector2(0,.60),Vector2(0,-.95),Vector2(side*.88,-2.31),Vector2(side*1.72,-3.03),Vector2(side*1.72,-5.28)]
		for i in range(1,points.size()):
			for j in range(17):
				var at:=points[i-1].lerp(points[i],j/16.0)
				query.transform=Transform3D(Basis.IDENTITY,Vector3(at.x,1.0,at.y))
				if not space.intersect_shape(query,1).is_empty():
					errors.append("Horse approach obstructed at "+str(at))
					break
		var cross:=PhysicsRayQueryParameters3D.create(Vector3(side*1.72,1.1,-5.28),Vector3(-side*.19,1.1,-5.28),1)
		if space.intersect_ray(cross).is_empty():
			errors.append("Missing divider between stalls")
	var native:=mesh.generate_triangle_mesh()
	for x: float in [-1.24,-.52,0,.52,1.24]:
		for h: float in [.22,1.0,1.96,2.40]:
			if not native.intersect_segment(Vector3(x,h,.65),Vector3(x,h,-.65)).is_empty():
				errors.append("Visible entrance obstructed")
	for x: float in [-1.72,1.72]:
		for dx: float in [-.43,0,.43]:
			for h: float in [.29,1.27,2.20]:
				if not native.intersect_segment(Vector3(x+dx,h,-2.8),Vector3(x+dx,h,-6.0)).is_empty():
					errors.append("Visible horse entrance obstructed")
	print("STABLE_GEOMETRY ",mesh.get_aabb()," triangles ",triangles," extra_lods ",lods," collision_boxes ",body.get_child_count())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			await photograph(arg.trim_prefix("--shots="))
	print("STABLE_RESULT ",errors)
	quit(0 if errors.is_empty() else 1)

func photograph(prefix: String) -> void:
	var plane:=MeshInstance3D.new()
	plane.mesh=PlaneMesh.new()
	plane.mesh.size=Vector2(350,350)
	plane.position.y=-.05
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("#857b68")
	plane.material_override=paint
	root.add_child(plane)
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#afbec2")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#dfdfd5")
	env.ambient_light_energy=.62
	env.ambient_light_sky_contribution=0
	var environment:=WorldEnvironment.new()
	environment.environment=env
	root.add_child(environment)
	var sun:=DirectionalLight3D.new()
	sun.light_color=Color("#ffefdc")
	sun.light_energy=.53
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=32
	sun.rotation_degrees=Vector3(-37,-25,0)
	root.add_child(sun)
	var camera:=Camera3D.new()
	root.add_child(camera)
	root.msaa_3d=Viewport.MSAA_4X
	var views: Array=[[Vector3(8.0,6.55,8.8),Vector3(0,1.1,-3.67),38,"yard"],
		[Vector3(.70,1.69,-.65),Vector3(-.2,1.34,-5.52),64,"stalls"]]
	for pose in views:
		camera.position=pose[0]
		camera.look_at(pose[1])
		camera.fov=pose[2]
		for i in 5:
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(prefix+"-"+pose[3]+".png")
