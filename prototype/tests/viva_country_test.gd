extends SceneTree
const WALK := preload("res://scenes/viva_country/country_walk.tscn")
var errors: Array[String]=[]
var checks:=0

func _initialize() -> void:
	call_deferred("_run")

func require(condition: bool,message: String) -> void:
	checks+=1
	if not condition:
		errors.append(message)
		printerr(message)

func _capture_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return arg.trim_prefix("--capture=")
	return ""

func _run() -> void:
	var lab = WALK.instantiate()
	lab.interactive=false
	root.add_child(lab)
	require(lab.built,"3D resources failed to build")
	if not lab.built:
		quit(1)
		return
	await physics_frame
	await physics_frame
	var field = lab.field
	var space: PhysicsDirectSpaceState3D=field.get_world_3d().direct_space_state
	for row: Array in field.manifest.probes:
		var start:=Vector3(row[0],5.0,row[2])
		var end:=Vector3(row[0],-5.0,row[2])
		var query:=PhysicsRayQueryParameters3D.create(start,end,1)
		var hit:=space.intersect_ray(query)
		require(not hit.is_empty(),"Missing physical ground at "+str(row))
		if not hit.is_empty():
			require(absf(float(hit.position.y)-float(row[1]))<0.015,"Ground differs from generated geometry: "+str(row))
	require(field.groups.size()==24,"Expected three spatial sectors with eight groups")
	var all_grass:=0
	var all_stones:=0
	for group: Dictionary in field.groups:
		if group.grass:
			all_grass+=int(group.total)
		else:
			all_stones+=int(group.total)
	require(all_grass==int(field.manifest.stats.grass) and all_stones==int(field.manifest.stats.stone),"Scatter manifest counts")
	for item: MeshInstance3D in field.terrain:
		var arrays:=item.mesh.surface_get_arrays(0)
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		require(colors.size()>0,"Terrain vertex colours absent")
		var minimum:=1.0
		var maximum:=0.0
		for color: Color in colors:
			minimum=minf(minimum,color.a)
			maximum=maxf(maximum,color.a)
		require(minimum<0.05 and maximum>0.95,"Road/grass blending channel lost on import")
	var previous:=0
	for id: String in ["low","balanced","high","very_high"]:
		field.set_detail(id,Vector3(0,0,13),true)
		require(int(field.counts.triangles)>previous,"Quality must retain increasing 3D detail")
		previous=int(field.counts.triangles)
		require(int(field.counts.grass)<=all_grass and int(field.counts.stones)<=all_stones,"Scatter budget exceeds allocated count")
	var prior:=Vector3.ZERO
	for id: String in ["morning","noon","afternoon"]:
		require(lab.daylight.set_daylight(id),"Invalid time")
		var direction: Vector3=lab.daylight.direction
		var actual: Vector3=lab.daylight.sun.global_transform.basis.z.normalized()
		require(direction.y>0.0 and actual.dot(direction)>0.9999,"Sun direction and shadow vector inconsistent")
		require(prior.distance_to(direction)>0.2,"Sun position did not move")
		prior=direction
	field.wind_paused=true
	field.set_wind_time(3.0)
	require(is_equal_approx(float(field.blade_mat.get_shader_parameter("wind_time")),3.0),"Wind phase not propagated")
	var dir:=_capture_dir()
	if not dir.is_empty() and errors.is_empty():
		if DisplayServer.get_name()=="headless":
			require(false,"Graphical evidence cannot be headless")
		else:
			DirAccess.make_dir_recursive_absolute(dir)
			root.size=Vector2i(1280,720)
			lab._apply_quality("high")
			lab.camera.global_position=Vector3(field.center(4.0)+0.14,1.90,4.0)
			lab.camera.look_at(Vector3(field.center(16.0),0.8,16.0),Vector3.UP)
			field.set_detail("high",lab.camera.global_position,true)
			var captures: Array[Dictionary]=[]
			for id: String in ["morning","noon","afternoon","edge","hoof"]:
				if id in ["morning","noon","afternoon"]:
					lab.daylight.set_daylight(id)
				elif id=="edge":
					lab.camera.global_position=Vector3(field.center(10.0)+0.9,0.85,9.5)
					lab.camera.look_at(Vector3(field.center(11.5)+1.95,0.18,11.5),Vector3.UP)
				else:
					var hoof: Dictionary=field.manifest.hoofprints[8]
					var point:=Vector3(field.center(float(hoof.z))+float(hoof.u),0.0,float(hoof.z))
					lab.camera.global_position=point+Vector3(0.4,0.93,-0.65)
					lab.camera.look_at(point,Vector3.UP)
				field.set_detail("high",lab.camera.global_position,true)
				await process_frame
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				var img:=root.get_texture().get_image()
				var path:=dir.path_join(id+".png")
				require(img!=null and not img.is_empty() and img.save_png(path)==OK,"No actual viewport capture: "+id)
				if FileAccess.file_exists(path):
					captures.append({"id":id,"sha256":FileAccess.get_sha256(path),"size":[img.get_width(),img.get_height()]})
			var report:=FileAccess.open(dir.path_join("review.json"),FileAccess.WRITE)
			if report!=null:
				report.store_string(JSON.stringify({"checks":checks,"errors":errors,"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"captures":captures,"visual_review_required":true}, "  "))
				report.close()
			else:
				require(false,"Missing capture report")
	print("VIVA_COUNTRY_%s %d checks, %d failures"%["PASS" if errors.is_empty() else "FAIL",checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
