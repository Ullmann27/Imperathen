extends Node3D
## A real-time review scene for the shared art kit, not the campaign implementation.

const QualityController = preload("res://scripts/quality_controller.gd")
const CharacterMaterials = preload("res://scripts/character_materials.gd")
const EnvironmentBuilder = preload("res://scripts/environment_builder.gd")
var quality = QualityController.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var environment := Environment.new()
var vegetation := MultiMeshInstance3D.new()
var caption := Label.new()
var target := Vector3(0, 1.6, 0)
var orbit := Vector2(0.70, 0.33)
var distance := 20.0
var current_view := 0
var ui: CanvasLayer
var last_profile: Dictionary = {}
var essential_assets: Array[Node3D] = []
var capture_path := ""
var verification := false
var frames := 0
var neutral := false
var spin := false
var quality_buttons: Dictionary = {}
var view_buttons: Array[Button] = []
var scenery_report: Dictionary = {}

func _ready() -> void:
	_build_environment()
	scenery_report["terrain"] = EnvironmentBuilder.build_ground(self)
	_add_asset("architecture/frontier_house", Vector3(-5.0, 0, -3.0), 0.12)
	_add_asset("architecture/frontier_house", Vector3(5.8, 0, -5.5), -0.28)
	_add_asset("architecture/village_well", Vector3(1.5, 0, 2.2), 0.0)
	_add_asset("architecture/house_foundation", Vector3(-9.2, 0, 8.0), 0.08)
	_add_asset("characters/civilian_youth", Vector3(-2.0, 0.01, 3.2), -0.2)
	_add_asset("characters/frontier_guard", Vector3(-0.6, 0.01, 3.0), -0.5)
	_build_vegetation()
	scenery_report["trees"] = EnvironmentBuilder.build_trees(self)
	add_child(camera)
	camera.fov = 48.0
	camera.far = 250.0
	camera.current = true
	_build_ui()
	_set_view(0)
	_read_arguments()
	if not verification:
		_load_preference()
	_apply_quality(quality.active_id, false)
	get_viewport().size_changed.connect(func(): _apply_quality(quality.active_id, false))
	_update_camera()
	if verification:
		_verify_invariants()

func _read_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			var chosen := arg.trim_prefix("--profile=")
			if quality.profiles.has(chosen): quality.active_id = chosen
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg == "--verify": verification = true
		elif arg == "--neutral": neutral = true; _set_light()
		elif arg.begins_with("--view="): _set_view(int(arg.trim_prefix("--view=")))

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("55778b")
	sky_material.sky_horizon_color = Color("c5c7b7")
	sky_material.ground_bottom_color = Color("434238")
	sky_material.ground_horizon_color = Color("b4b4a4")
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b0bfd1")
	environment.ambient_light_energy = 0.48
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.002
	environment.fog_light_color = Color("b2b9a9")
	environment.glow_intensity = 0.18
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 0.7
	add_child(sun)
	_set_light()

func _set_light() -> void:
	sun.rotation_degrees = Vector3(-52, -32, 0) if neutral else Vector3(-30, -28, 0)
	sun.light_color = Color("fff6e5") if neutral else Color("ffe2bd")
	sun.light_energy = 1.0 if neutral else 1.12
	environment.ambient_light_energy = 0.48 if neutral else 0.38

func _add_asset(id: String, at: Vector3, angle: float) -> void:
	var path := "res://assets/" + id + ".glb"
	if not ResourceLoader.exists(path):
		push_error("Missing art asset: " + path)
		return
	var asset := load(path) as PackedScene
	var instance := asset.instantiate() as Node3D
	CharacterMaterials.apply_to(instance)
	_preserve_essential_detail(instance)
	instance.position = at
	instance.rotation.y = angle
	instance.set_meta("essential", true)
	add_child(instance)
	essential_assets.append(instance)

func _preserve_essential_detail(node: Node) -> void:
	# Real low-profile review showed automatic LOD dropping thin window/roof parts.
	# Keep important silhouettes longer; save decoration and fill-rate first.
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).lod_bias = 8.0
	for child in node.get_children():
		_preserve_essential_detail(child)

func _build_vegetation() -> void:
	var blades := SurfaceTool.new()
	blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(5):
		var angle := blade*2.399
		var centre := Vector3(cos(angle)*0.1, 0, sin(angle)*0.1)
		var side := Vector3(cos(angle), 0, sin(angle))*0.035
		for point in [centre-side, centre+Vector3(0.05,0.27+blade*0.035,0.02), centre+side]:
			blades.add_vertex(point)
	blades.generate_normals()
	var grass_shader := Shader.new()
	grass_shader.code = "shader_type spatial; render_mode cull_disabled; void vertex(){ VERTEX.x += sin(TIME * 1.8 + MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z) * VERTEX.y * 0.10; } void fragment(){ ALBEDO=vec3(0.22,0.28,0.105); ROUGHNESS=0.95; }"
	var grass_material := ShaderMaterial.new()
	grass_material.shader = grass_shader
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = blades.commit()
	multi.instance_count = 1600
	var rng := RandomNumberGenerator.new()
	rng.seed = 36119
	for i in range(multi.instance_count):
		var x := rng.randf_range(-20,20)
		var z := rng.randf_range(-20,22)
		# Keep the centre path and all buildings free of decorative grass.
		if absf(x+0.3)<2.2: x += 4.3 if x>=-0.3 else -4.3
		if (absf(x+5.0)<3.8 and absf(z+3.0)<3.5) or (absf(x-5.8)<4.1 and absf(z+5.5)<4.0): z += 12
		var basis := Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*rng.randf_range(0.6,1.4))
		multi.set_instance_transform(i,Transform3D(basis,Vector3(x,0,z)))
	vegetation.multimesh = multi
	vegetation.material_override = grass_material
	vegetation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(vegetation)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "IMPERATHEN"
	title.position = Vector2(30,22)
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("efd39b"))
	title.add_theme_color_override("font_shadow_color",Color(0.03,0.025,0.02,0.9))
	title.add_theme_constant_override("shadow_offset_x",1)
	title.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "D I E   G R E N Z P R O V I N Z"
	subtitle.position = Vector2(32,60)
	subtitle.add_theme_font_size_override("font_size",12)
	subtitle.add_theme_color_override("font_shadow_color",Color(0.03,0.025,0.02,0.9))
	subtitle.add_theme_constant_override("shadow_offset_x",1)
	subtitle.add_theme_constant_override("shadow_offset_y",1)
	ui.add_child(subtitle)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -112
	panel.offset_left = 22
	panel.offset_right = -22
	panel.offset_bottom = -18
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.055,0.055,0.91)
	style.border_color = Color("8d7751")
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	var theme := Theme.new()
	theme.set_font_size("font_size","Button",16)
	for state in ["normal","hover","pressed","focus"]:
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color("292b29") if state == "pressed" else Color(0.11,0.12,0.11,0.65)
		button_style.border_color = Color("d0ae70") if state in ["pressed","focus"] else Color("555348")
		button_style.set_border_width_all(1 if state in ["pressed","hover","focus"] else 0)
		button_style.set_corner_radius_all(3)
		theme.set_stylebox(state,"Button",button_style)
	panel.theme = theme
	ui.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",10)
	row.add_theme_constant_override("v_separation",8)
	column.add_child(row)
	var quality_group := ButtonGroup.new()
	for entry in [["Leicht","low"],["Ausgewogen","balanced"],["Hoch","high"],["Sehr hoch","very_high"]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(125,44)
		button.toggle_mode = true
		button.button_group = quality_group
		quality_buttons[entry[1]] = button
		button.pressed.connect(_apply_quality.bind(entry[1],true))
		row.add_child(button)
	var view_group := ButtonGroup.new()
	for index in range(4):
		var button := Button.new()
		button.text = ["Dorf","Haus","Figuren","Übersicht"][index]
		button.custom_minimum_size = Vector2(95,44)
		button.toggle_mode = true
		button.button_group = view_group
		view_buttons.append(button)
		button.pressed.connect(_set_view.bind(index))
		row.add_child(button)
	var light_button := Button.new()
	light_button.text = "Licht wechseln"
	light_button.custom_minimum_size = Vector2(130,44)
	light_button.pressed.connect(func(): neutral = not neutral; _set_light())
	row.add_child(light_button)
	for zoom in [["−",1.15],["+",0.87]]:
		var button := Button.new()
		button.text = zoom[0]
		button.custom_minimum_size = Vector2(44,44)
		button.pressed.connect(func(): distance=clampf(distance*float(zoom[1]),2,45); _update_camera())
		row.add_child(button)
	caption.add_theme_font_size_override("font_size",13)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color",Color("c7c5b9"))
	column.add_child(caption)

func _apply_quality(id: String, persist: bool = true) -> void:
	last_profile = quality.apply(id,get_viewport(),sun,environment,vegetation)
	for key in quality_buttons:
		(quality_buttons[key] as Button).set_pressed_no_signal(key == id)
	caption.text = str(last_profile.get("label",id)) + "  ·  Ziehen: Kamera drehen  ·  Zwei Finger / Mausrad: Abstand  ·  Alle Figuren und Gebäude bleiben erhalten"
	if persist:
		var config := ConfigFile.new()
		config.set_value("graphics","profile",id)
		config.save("user://art_review_graphics.cfg")

func _load_preference() -> void:
	# Explicit capture arguments take precedence over an interactive preference.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): return
	var config := ConfigFile.new()
	if config.load("user://art_review_graphics.cfg") == OK:
		var chosen: String = str(config.get_value("graphics","profile","balanced"))
		if quality.profiles.has(chosen): quality.active_id = chosen

func _set_view(index: int) -> void:
	current_view = clampi(index,0,3)
	for button_index in range(view_buttons.size()):
		view_buttons[button_index].set_pressed_no_signal(button_index == current_view)
	match current_view:
		0: target=Vector3(0,1.8,-0.5); orbit=Vector2(0.67,0.28); distance=22.0
		1: target=Vector3(-5,2.0,-3); orbit=Vector2(-0.72,0.23); distance=11.8
		2: target=Vector3(-1.3,0.93,3.1); orbit=Vector2(0.22,0.07); distance=3.5
		3: target=Vector3(0,0.8,0); orbit=Vector2(0.55,0.85); distance=34
	_update_camera()

func _update_camera() -> void:
	if not camera.is_inside_tree(): return
	camera.position = target + Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		orbit += Vector2(-event.relative.x,event.relative.y)*0.004
	elif event is InputEventScreenDrag:
		orbit += Vector2(-event.relative.x,event.relative.y)*0.004
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance/event.factor,2.0,45.0)
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(2,distance*0.92)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(45,distance*1.08)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE: spin = not spin
		elif event.keycode == KEY_ESCAPE: get_tree().quit()
		elif event.keycode == KEY_P: _save_evidence()
	orbit.y = clampf(orbit.y,0.05,1.25)
	_update_camera()

func _save_evidence() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var stem: String = "res://evidence/engine_" + str(quality.active_id) + "_view" + str(current_view) + ("_neutral" if neutral else "_morning")
	var result := get_viewport().get_texture().get_image().save_png(stem + ".png")
	var receipt := {"kind":"actual_godot_viewport_capture","engine":Engine.get_version_info(),
		"created_at_utc":Time.get_datetime_string_from_system(true),
		"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),
		"profile":last_profile,"camera":current_view,"light":"neutral" if neutral else "morning",
		"camera_position":[camera.position.x,camera.position.y,camera.position.z],
		"essential_assets_visible":essential_assets.filter(func(node): return node.visible).size(),
		"scenery":scenery_report,
		"android_hardware":OS.get_name()=="Android","png_result":result}
	var file := FileAccess.open(stem+".json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(receipt,"\t")+"\n")
	print("VISUAL_CAPTURE ",JSON.stringify(receipt))

func _process(delta: float) -> void:
	frames += 1
	if spin:
		orbit.x += delta*0.08
		_update_camera()
	if capture_path != "" and frames == 45:
		if DisplayServer.get_name() == "headless":
			push_error("A real rendering display is required for screenshot evidence.")
			get_tree().quit(2)
			return
		await RenderingServer.frame_post_draw
		var screenshot := get_viewport().get_texture().get_image()
		var result := screenshot.save_png(capture_path)
		print("VISUAL_CAPTURE ",JSON.stringify({"path":capture_path,"result":result,"profile":last_profile,"view":current_view,"light":"neutral" if neutral else "morning"}))
		get_tree().quit(0 if result == OK else 2)

func _verify_invariants() -> void:
	var original: Array = []
	for node in essential_assets:
		original.append({"id":node.get_instance_id(),"transform":node.transform})
	var failures: Array[String] = []
	if essential_assets.size()!=6: failures.append("Expected six essential placed assets")
	var runs: Array = []
	for id in ["low","balanced","high","very_high","low","balanced"]:
		_apply_quality(id,false)
		runs.append(last_profile.duplicate(true))
		for index in range(essential_assets.size()):
			var node := essential_assets[index]
			if not node.visible or node.get_instance_id()!=original[index]["id"] or node.transform!=original[index]["transform"]:
				failures.append("Profile changed an essential asset: "+id)
	if not is_equal_approx(quality.resolution_scale(Vector2i(2560,1440),"balanced"),0.75):
		failures.append("Balanced 1440p must render 1920x1080")
	if not is_equal_approx(quality.resolution_scale(Vector2i(1280,720),"high"),1.0):
		failures.append("No wasteful supersampling on a smaller display")
	print("VISUAL_INVARIANTS ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"essential_assets":essential_assets.size(),"profile_runs":runs,"render_proof":false}))
	get_tree().quit(0 if failures.is_empty() else 1)
