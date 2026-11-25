extends Node3D
## Actual 3D asset review. No campaign, commerce, or save game access.
const Detail := preload("res://scripts/rendering/city_character_detail.gd")
const Controller := preload("res://scripts/world_expansion/environment_controller.gd")
const Library := preload("res://scripts/world_expansion/asset_library.gd")
const PROP := "res://assets/viva_roma/props/"
const ARCH := "res://assets/world_expansion/architecture/"
const PEOPLE := "res://assets/characters/"
var controller: Node3D
var library: RefCounted
var camera: Camera3D
var shots: Array[Dictionary] = []
var sources: Dictionary = {}
var out := "user://viva_roma_review"
var expected := ""
var seconds := 4.0
var failure := ""
var last_capture := ""
var character_changes := 0

func _ready() -> void:
	call_deferred("_run")

func _arg(key: String, fallback: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--" + key + "="):
			return value.trim_prefix("--" + key + "=")
	return fallback

func _model(path: String, pos: Vector3) -> Node3D:
	var packed := load(path) as PackedScene if ResourceLoader.exists(path, "PackedScene") else null
	if packed == null:
		failure = "Missing actual 3D model: " + path
		return null
	var node := packed.instantiate() as Node3D
	if node == null:
		failure = "Not a Node3D: " + path
		return null
	add_child(node)
	node.position = pos
	sources[path] = FileAccess.get_sha256(path)
	return node

func _stone_block(size: Vector3, at: Vector3) -> void:
	# Only a neutral review pedestal, never substituted for a missing model.
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("776e60")
	mat.roughness = 0.87
	instance.material_override = mat
	add_child(instance)
	instance.position = at

func _finish_prop(node: Node3D) -> void:
	if node == null:
		return
	for item: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		if item.mesh == null:
			continue
		for i in item.mesh.get_surface_count():
			var original := item.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			var tex_path := ""
			var rough_path := ""
			var rough_channel := BaseMaterial3D.TEXTURE_CHANNEL_RED
			if original.resource_name in ["Hammered_Bronze","Burnished_Bronze","Interior_Bronze","Bronze_Stud"]:
				tex_path = "res://assets/weapons/gladius_lod0_bronze_normal.png"
				rough_path = "res://assets/weapons/gladius_lod0_bronze_roughness.png"
			elif original.resource_name in ["Oak_Dark","Oak_Light"]:
				tex_path = "res://assets/roman_material_lab/oak_worked_normal.png"
				rough_path = "res://assets/roman_material_lab/oak_worked_orm.png"
				rough_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			elif original.resource_name == "Forged_Iron":
				tex_path = "res://assets/roman_material_lab/iron_service_normal.png"
				rough_path = "res://assets/roman_material_lab/iron_service_orm.png"
				rough_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			if tex_path.is_empty() or not Detail.has_normal_basis(item.mesh.surface_get_arrays(i)):
				continue
			var mat := original.duplicate() as StandardMaterial3D
			var normal := load(tex_path) as Texture2D
			var rough := load(rough_path) as Texture2D
			if normal == null or rough == null:
				failure = "Missing PBR prop surface: " + tex_path
				continue
			mat.normal_enabled = true
			mat.normal_texture = normal
			mat.normal_scale = 0.62
			mat.roughness_texture = rough
			mat.roughness_texture_channel = rough_channel
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			item.set_surface_override_material(i,mat)
			sources[tex_path] = FileAccess.get_sha256(tex_path)
			sources[rough_path] = FileAccess.get_sha256(rough_path)

func _person(path: String, pos: Vector3) -> void:
	var node := _model(path,pos)
	if node == null:
		return
	character_changes += Detail.apply_to(node,"very_high",0)
	for animator: AnimationPlayer in node.find_children("*","AnimationPlayer",true,false):
		var idle := ""
		for clip: String in animator.get_animation_list():
			if clip.to_lower().ends_with("idle"):
				idle = clip
				break
		if not idle.is_empty():
			animator.play(idle)
			animator.seek(0.33,true)
			animator.pause()

func _build() -> bool:
	controller = Controller.new()
	add_child(controller)
	controller.set_quality("high")
	controller.set_time_of_day(14.0)
	controller.set_wind(0.75)
	camera = Camera3D.new()
	camera.near = 0.045
	camera.far = 250
	camera.fov = 53
	add_child(camera)
	camera.current = true
	_stone_block(Vector3(105,0.2,70),Vector3(30,-0.12,0))
	_model(ARCH+"taberna_lod0.glb",Vector3(0,0,-5))
	_model(ARCH+"insula_lod0.glb",Vector3(-13,0,-9))
	for i in [-1,0,1]:
		_model(ARCH+"basalt_road_lod0.glb",Vector3(i*8,0,4))
	_finish_prop(_model(PROP+"portal_lod0.glb",Vector3(5.6,0,0.4)))
	shots.append({"id":"architecture","eye":Vector3(6.6,1.66,9),"target":Vector3(1.8,1.65,-0.8),"fov":53.0})
	shots.append({"id":"portal","eye":Vector3(7.7,1.62,4.8),"target":Vector3(5.6,1.60,0.4),"fov":45.0})
	_person(PEOPLE+"frontier_civilian_man_0.glb",Vector3(24.0,0,0))
	_person(PEOPLE+"frontier_civilian_woman_0.glb",Vector3(25.35,0,0))
	_person(PEOPLE+"frontier_elder_0.glb",Vector3(26.7,0,0))
	shots.append({"id":"faces_hair_cloth","eye":Vector3(25.35,1.57,3.3),"target":Vector3(25.35,1.30,0),"fov":49.0})
	_stone_block(Vector3(0.82,1.04,0.82),Vector3(38,0.52,0))
	_finish_prop(_model(PROP+"helmet_lod0.glb",Vector3(38,1.17,0)))
	_person(PEOPLE+"frontier_legionary_0.glb",Vector3(39.6,0,-0.8))
	shots.append({"id":"bronze_helmet","eye":Vector3(37.62,1.45,-0.66),"target":Vector3(38,1.24,0),"fov":40.0})
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_expansion/manifest.json"))
	if not manifest is Dictionary:
		failure = "Missing vegetation manifest"
		return false
	library = Library.new()
	if not library.load_manifest_assets({"building_assets":[],"road_assets":[],"vegetation_assets":manifest["vegetation_assets"]}):
		failure = str(library.errors)
		return false
	for material: ShaderMaterial in library.wind_materials:
		controller.bind_material(material)
	for row: Array in [["field_elm",Vector3(55,0,0)],["cypress",Vector3(60,0,-3)],["laurel",Vector3(52,0,2)]]:
		var data: Dictionary = library.assets[row[0]]
		var item := MeshInstance3D.new()
		item.mesh = data["meshes"][0]
		item.extra_cull_margin = 0.6
		add_child(item)
		item.position = row[1]
		for path: String in data["definition"]["lods"]:
			sources[path] = FileAccess.get_sha256(path)
	shots.append({"id":"vegetation","eye":Vector3(53,1.66,13),"target":Vector3(56,3.2,0),"fov":52.0})
	if character_changes <= 0:
		failure = "No supported original character surface received the review pass"
	return failure.is_empty()

func _percentile(values: Array[float], q: float) -> float:
	var ordered := values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(q*ordered.size())-1,0,ordered.size()-1)] if not ordered.is_empty() else 0.0

func _run() -> void:
	expected = _arg("renderer",RenderingServer.get_current_rendering_method())
	out = _arg("out",out)
	seconds = clampf(float(_arg("seconds","240" if OS.has_feature("android") else "4")),1.0,600.0)
	if DisplayServer.get_name()=="headless" or RenderingServer.get_current_rendering_method()!=expected:
		_abort("Renderer fallback or no real display")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = 1.0
	get_viewport().msaa_3d = Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(2048,true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	if not _build():
		_abort(failure)
		return
	var results: Array[Dictionary] = []
	for shot: Dictionary in shots:
		camera.position = shot.eye
		camera.look_at(shot.target,Vector3.UP)
		camera.fov = shot.fov
		controller.motion_paused = true
		controller.set_wind_time(3.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var file := out.path_join(str(shot.id)+".png")
		var image := get_viewport().get_texture().get_image()
		if image == null or image.is_empty() or image.save_png(file)!=OK:
			_abort("Screenshot missing: "+str(shot.id))
			return
		controller.motion_paused = false
		await get_tree().create_timer(2.0).timeout
		var frames: Array[float] = []
		var cpu: Array[float] = []
		var gpu: Array[float] = []
		var started := Time.get_ticks_usec()
		var previous := started
		while Time.get_ticks_usec()-started < int(seconds*1000000):
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frames.append((now-previous)*0.001)
			previous = now
			var rid := get_viewport().get_viewport_rid()
			var c := RenderingServer.viewport_get_measured_render_time_cpu(rid)
			var g := RenderingServer.viewport_get_measured_render_time_gpu(rid)
			if c>0: cpu.append(c)
			if g>0: gpu.append(g)
		var total := (previous-started)*0.001
		if frames.size()<2 or total<=0:
			_abort("Insufficient rendered frames: "+str(shot.id))
			return
		results.append({"shot":shot.id,"frames":frames.size(),"duration_ms":total,"mean_fps":1000.0*frames.size()/total,
			"p50_ms":_percentile(frames,0.50),"p95_ms":_percentile(frames,0.95),"p99_ms":_percentile(frames,0.99),
			"cpu_p95_ms":_percentile(cpu,0.95) if not cpu.is_empty() else null,
			"gpu_p95_ms":_percentile(gpu,0.95) if not gpu.is_empty() else null,
			"draw_calls":get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"visible_triangles":get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"png_sha256":FileAccess.get_sha256(file),"image_size":[image.get_width(),image.get_height()]})
		print("VIVA_SHOT ",JSON.stringify(results.back()))
	var report := {"status":"rendered","renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"os":OS.get_name(),"duration_requested_per_shot":seconds,"sources":sources,
		"character_material_overrides":character_changes,"shots":results,"device_thermal_evidence":null}
	var f := FileAccess.open(out.path_join("report.json"),FileAccess.WRITE)
	if f==null:
		_abort("Cannot write report")
		return
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	print("VIVA_ROMA_REVIEW_PASS")
	get_tree().quit()

func _abort(reason: String) -> void:
	printerr("VIVA_ROMA_REVIEW_FAIL "+reason)
	get_tree().quit(1)
