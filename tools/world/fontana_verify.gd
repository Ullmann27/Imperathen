extends SceneTree
## Import the project first. Pass -- --review=/absolute/file.png with a graphical renderer to save the close view.

func _initialize() -> void:
	inspect.call_deferred()

func inspect() -> void:
	var scene := load("res://assets/roman_quarter/fountain/fontana.glb") as PackedScene
	var asset := scene.instantiate()
	root.add_child(asset)
	var meshes := asset.find_children("*","MeshInstance3D",true,false)
	if asset is MeshInstance3D:
		meshes.append(asset)
	var mesh: ArrayMesh = meshes[0].mesh
	var bounds := mesh.get_aabb()
	var errors: Array[String] = []
	if meshes.size()!=1 or mesh.get_surface_count()!=3:
		errors.append("Expected single batched mesh with stone, the spout and water")
	if not bounds.size.is_equal_approx(Vector3(2.644,1.67,1.695)):
		errors.append("Asset dimensions changed")
	var lods := []
	var tris := []
	for i in mesh.get_surface_count():
		var data: Dictionary = mesh.get("_surfaces")[i]
		var m := (meshes[0] as MeshInstance3D).get_active_material(i) as StandardMaterial3D
		var is_water := m.resource_name.begins_with("Acqua")
		if not is_water and (m.albedo_texture==null or m.normal_texture==null or m.roughness_texture==null):
			errors.append("Missing PBR channel on "+m.resource_name)
		var layers: Array=data.get("lods",[])
		tris.append(int(data.index_count)/3)
		lods.append(layers.size()/2)
		if layers.size()<2:
			errors.append("Missing mesh LOD on "+m.resource_name)
		print("Fountain material ",m.resource_name," vertex_color=",m.vertex_color_use_as_albedo)
		if not m.vertex_color_use_as_albedo:
			errors.append("Missing vertex finish on "+m.resource_name)
	print("FONTANA_GEOMETRY bounds=",bounds," triangles=",tris," lods=",lods)
	if not errors.is_empty():
		printerr(errors)
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review="):
			await capture(arg.trim_prefix("--review="))
	asset.free()
	print("FONTANA_PASS")
	quit()

func capture(path: String) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size=Vector2(1000,1000)
	ground.mesh=plane
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("#7b7569")
	paint.roughness=.94
	ground.material_override=paint
	ground.position.y=-.003
	root.add_child(ground)
	var world:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky:=Sky.new()
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("#758fa3")
	sky_mat.sky_horizon_color=Color("#bdc7c8")
	sky_mat.ground_horizon_color=Color("#c1bbaf")
	sky.sky_material=sky_mat
	env.sky=sky
	env.background_color=Color("#9dadb4")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#ccd8e0")
	env.ambient_light_energy=.57
	env.ambient_light_sky_contribution=0
	world.environment=env
	root.add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.light_color=Color("#ffefdc")
	sun.light_energy=.58
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=11
	sun.rotation_degrees=Vector3(-41,-32,0)
	root.add_child(sun)
	root.msaa_3d=Viewport.MSAA_4X
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.position=Vector3(2.53,2.13,4.04)
	camera.look_at(Vector3(0,.74,-.03))
	camera.fov=35
	for i in 6:
		await process_frame
		await RenderingServer.frame_post_draw
	var photo:=root.get_texture().get_image()
	photo.save_png(path)
