extends "res://tests/village_childhood_test.gd"
## Exercise the inventory after earning the keepsake on the existing I-01 to I-14 route.
const Objects := preload("res://scripts/story/mission_documents.gd")
const Reader := preload("res://scripts/ui/document_reader.gd")
const UI := preload("res://scripts/ui/game_ui.gd")
var output_dir := OS.get_environment("LEGIO_CAPTURE_DIR")

func _initialize() -> void:
	call_deferred("_run_objects")

func _run_objects() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var models := {}
	for id: String in Childhood.ITEM_NAMES:
		_check(Objects.ENTRIES.has(id),"Every saved carried ID has a physical inspection model: "+id)
	for id: String in Objects.ENTRIES:
		var entry: Dictionary = Objects.ENTRIES[id]
		var scene := load(entry.model) as PackedScene
		_check(scene != null,"Model imports for "+id)
		if scene:
			var instance := scene.instantiate() as Node3D
			root.add_child(instance)
			var dimensions := Reader.model_bounds(instance).size
			_check(dimensions.length() > .01 and dimensions.length() < 1.6,"Object measured in plausible metres: %s %s" % [id,dimensions])
			instance.free()
		if not models.has(entry.model):
			models[entry.model] = id
	_check(Objects.ENTRIES.size() == 18 and models.size() == 15,"18 presentations reuse 15 distinct physical models")
	_test_full_journey_and_guard()
	var restored = WorldModel.new()
	var loaded: Dictionary = restored.load_game(_path("oath-defend"))
	_check(loaded.ok,"Open the real save after earning I-14")
	if loaded.ok:
		var state_before := _snapshot(restored.data)
		_check(Objects.held(restored.data) == ["memory_token"],"Only the actual keepsake remains after deliveries and duty")
		var ui := UI.new()
		root.add_child(ui)
		ui.show_village_panel(restored.data)
		await process_frame
		var button := ui.find_child("InspectObject",true,false) as Button
		_check(button != null and button.get_parent().get_meta("story_object") == "memory_token","Village inventory offers the recovered keepsake")
		if button:
			button.button_pressed = true
			var writing := ui.find_child("Transcription",true,false) as Label
			_check(writing != null and writing.text.contains("keine Inschrift"),"The keepsake view identifies an uninscribed object")
			for i in 3:
				await process_frame
			var scroll: ScrollContainer = ui.find_children("*","ScrollContainer",true,false)[0]
			scroll.ensure_control_visible(writing)
			await _image("erinnerungsstueck")
			button.button_pressed = false
			_check(button.get_parent().get_node_or_null("DocumentContent") == null,"Closing frees its 3D inspection")
		_check(_snapshot(restored.data) == state_before,"Inspection preserves the entire loaded campaign")
		ui.free()
	if not output_dir.is_empty():
		await _catalogue(models)
	_cleanup()
	print("LEGIO_OBJECTS_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:
		printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)

func _catalogue(models: Dictionary) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("26221f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e9ddc4")
	env.ambient_light_energy = .65
	var world := WorldEnvironment.new()
	world.environment = env
	stage.add_child(world)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-41,29,0)
	lamp.light_energy = 1.2
	stage.add_child(lamp)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position.z = 4
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.42
	camera.current = true
	var index := 0
	for path: String in models:
		var id: String = models[path]
		var entry: Dictionary = Objects.ENTRIES[id]
		var model := (load(path) as PackedScene).instantiate() as Node3D
		stage.add_child(model)
		model.rotation_degrees = Vector3(67 if entry.get("view","") == "flat" else 11,12,0)
		var bounds := Reader.model_bounds(model)
		model.scale = Vector3.ONE*minf(.39/maxf(.001,bounds.size.x),.28/maxf(.001,bounds.size.y))
		var x := (index%5-2)*.49
		var y := (.99-floorf(float(index)/5))*.445
		model.position = Vector3(x,y+.035,0)-Reader.model_bounds(model).get_center()
		var label := Label3D.new()
		label.text = str(entry.title)
		label.font_size = 36
		label.pixel_size = .00066
		label.outline_size = 0
		label.modulate = Color("e5d6bb")
		stage.add_child(label)
		label.position = Vector3(x,y-.17,.50)
		index += 1
	await _image("gegenstaende-valdora")
	stage.free()

func _image(name: String) -> void:
	if output_dir.is_empty():
		return
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(output_dir.path_join(name+".webp"),true,.9) == OK,"Real viewport saved: "+name)
