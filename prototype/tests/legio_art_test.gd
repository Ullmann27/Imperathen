extends "res://tests/i04_slice_test.gd"
## Reads real mesh target data and uses the production message route and reader.
## Set LEGIO_CAPTURE_DIR on a display-capable runner for real engine images.
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
const Faces := preload("res://scripts/visuals/roman_faces.gd")
const Documents := preload("res://scripts/story/mission_documents.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")
var capture_dir := OS.get_environment("LEGIO_CAPTURE_DIR")

func _initialize() -> void:
	call_deferred("_run_art")

func _run_art() -> void:
	var types := ["civilian_man","civilian_woman","elder","legionary","spearman","archer","officer"]
	for kind in types:
		for level in [0,1]:
			var figure := (load("res://assets/characters/frontier_%s_%d.glb" % [kind,level]) as PackedScene).instantiate()
			var body: MeshInstance3D = figure.find_child("HeroBody",true,false)
			Faces.apply(figure,4567)
			_check(body.material_override != null and body.material_override.albedo_texture == body.mesh.surface_get_material(0).albedo_texture,"Tint retains the original skin atlas")
			var values := []
			for feature in Faces.FEATURES.slice(0,3):
				var slot := body.find_blend_shape_by_name(feature)
				if _check(slot >= 0, "%s LOD %d exports %s" % [kind,level,feature]):
					values.append(body.get_blend_shape_value(slot))
					var arr: Array = body.mesh.surface_get_blend_shape_arrays(0)[slot]
					var sculpt: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var basis: PackedVector3Array = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var relative := (body.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
					var displacement := 0.0
					for index in sculpt.size():
						var offset := sculpt[index] if relative else sculpt[index]-basis[index]
						displacement = maxf(displacement,offset.length())
					_check(displacement > .002 and displacement < .035,"%s anatomically local offset, maximum %.4f m" % [feature,displacement])
			Faces.apply(figure,9137)
			var slot := body.find_blend_shape_by_name("CastJaw")
			if slot >= 0:
				_check(not is_equal_approx(values[0],body.get_blend_shape_value(slot)), "Different UID changes the rendered jaw")
				Faces.apply(figure,4567)
				_check(is_equal_approx(values[0],body.get_blend_shape_value(slot)), "Shape returns with the same UID")
			var hair: MeshInstance3D = figure.find_child("HeroHair",true,false)
			if hair:
				_check(hair.find_blend_shape_by_name("CastHair") >= 0,"Real hair geometry can sweep separately")
			figure.free()
	var model = _at_forge()
	_check(Documents.held(model.data).is_empty(),"The note cannot be opened before Sextus hands it over")
	_check(_play(model,"i04_message").ok and Documents.held(model.data) == ["sextus_note"],"The real I-04 message route authorises the reading view")
	var ui := GameUI.new()
	root.add_child(ui)
	ui.show_village_panel(model.data)
	var toggle: Button = ui.find_child("ReadDocument",true,false)
	_check(is_instance_valid(toggle),"Found held tablet in village inventory")
	toggle.button_pressed = true
	var transcription: Label = ui.find_child("Transcription",true,false)
	_check(is_instance_valid(transcription) and transcription.text.contains("zwei Körbe Kohle"),"The reader shows the delivery quantity and recipient")
	if not capture_dir.is_empty():
		for frame in 3:
			await process_frame
		var scroll: ScrollContainer = ui.find_children("*","ScrollContainer",true,false)[0]
		scroll.ensure_control_visible(transcription)
		await _capture("schmiedetafel")
	ui.free()
	_check(_play(model).ok and Documents.held(model.data).is_empty(),"Fabius receives the only tablet")
	if not capture_dir.is_empty():
		await _faces_capture()
		await _props_capture()
	print("LEGIO_ART_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:
		printerr("FAIL: ",failure)
	quit(0 if failures.is_empty() else 1)

func _studio() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("332f28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ede7dc")
	env.ambient_light_energy = .67
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	for angle in [Vector3(-35,23,0),Vector3(-16,149,0)]:
		var lamp := DirectionalLight3D.new()
		lamp.rotation_degrees = angle
		lamp.light_energy = 1.05 if angle.y == 23 else .52
		stage.add_child(lamp)
	return stage

func _camera(stage: Node3D, at: Vector3, point: Vector3, size_m: float) -> void:
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size_m
	camera.near = .01
	camera.position = at
	camera.look_at(point,Vector3.UP)
	camera.current = true

func _faces_capture() -> void:
	var stage := _studio()
	for i in 3:
		var shape := Soldier.new()
		shape.role = ["spear","heavy","officer"][i]
		shape.face_seed = [369,693,155][i]
		stage.add_child(shape)
		shape.position.x = (i-1)*.42
		shape.rotation.y = .25 - i*.18
		shape.present("idle",.15,0.0)
	_camera(stage,Vector3(.01,1.57,1.75),Vector3(0,1.54,0),.68)
	await _capture("roemische-gesichter")
	stage.free()

func _props_capture() -> void:
	var stage := _studio()
	for entry in [["ancestor_bust",-.39,1.0],["transport_amphora",.18,1.0],["gate_letter",.67,1.95],["sextus_tablet",1.12,1.65]]:
		var prop := (load("res://assets/legio/%s.glb" % entry[0]) as PackedScene).instantiate() as Node3D
		stage.add_child(prop)
		prop.scale *= float(entry[2])
		prop.position.x = float(entry[1])
		if entry[2] > 1:
			prop.rotation.x = deg_to_rad(65)
			prop.position.y = .40
		else:
			prop.rotation.y = -.22
	_camera(stage,Vector3(.72,1.05,3.4),Vector3(.33,.61,0),1.45)
	await _capture("bildnis-und-missionsobjekte")
	stage.free()

func _capture(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var target := capture_dir.path_join(label+".webp")
	_check(root.get_texture().get_image().save_webp(target,true,.90) == OK,"Save real viewport "+label)
