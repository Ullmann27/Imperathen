extends VBoxContainer
## View-only inspection of one actually carried, handled or borrowed mission object.
const Documents := preload("res://scripts/story/mission_documents.gd")
const Kit := preload("res://scripts/ui/roman_hud/menu_kit.gd")
const Style := preload("res://scripts/ui/roman_hud/hud_style.gd")

func build(id: String) -> void:
	set_meta("story_object",id)
	var entry: Dictionary = Documents.ENTRIES[id]
	var action := " lesen" if entry.get("document",false) else " ansehen"
	var toggle := Kit.choice(str(entry.title) + action, 1)
	toggle.name = "ReadDocument" if entry.get("document",false) else "InspectObject"
	toggle.toggle_mode = true
	add_child(toggle)
	toggle.toggled.connect(func(open: bool):
		toggle.text = str(entry.title) + (" schließen" if open else action)
		if open:
			_open(entry)
		else:
			var content := get_node_or_null("DocumentContent")
			if content:
				remove_child(content)
				content.queue_free()
	)

func _open(entry: Dictionary) -> void:
	var frame := PanelContainer.new()
	frame.name = "DocumentContent"
	var box := StyleBoxFlat.new()
	box.bg_color = Style.ATRAMENTUM
	box.border_color = Style.BRONZE_DEEP
	box.set_border_width_all(1)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel",box)
	add_child(frame)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation",8)
	frame.add_child(panel)
	var image := SubViewportContainer.new()
	image.stretch = true
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.custom_minimum_size = Vector2(160,212)
	panel.add_child(image)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(320,168)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	image.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var scene := load(entry.model) as PackedScene
	var model := scene.instantiate() as Node3D
	stage.add_child(model)
	var lighting := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("211d17")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f2dfbb")
	environment.ambient_light_energy = .85
	lighting.environment = environment
	stage.add_child(lighting)
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-67,-18,-12)
	lamp.light_energy = 1.3
	stage.add_child(lamp)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var bounds := model_bounds(model)
	var centre := bounds.get_center()
	var extent := maxf(bounds.size.length(),.02)
	camera.size = extent * .90
	camera.near = extent * .012
	stage.add_child(camera)
	var angle := Vector3(.08,.96,.38) if entry.get("view","") == "flat" else Vector3(.48,.45,.89)
	camera.position = centre + extent*1.7*angle.normalized()
	camera.look_at(centre,Vector3.UP)
	camera.current = true
	image.resized.connect(func(): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	var text := Style.label(str(entry.text),20,Style.CHARTA,false,1)
	text.name = "Transcription"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text)
	panel.add_child(Style.label(str(entry.mission) + (" · Kreative Ausgestaltung des Schriftstücks" if entry.get("document",false) else " · Gestalterische Ausarbeitung"),14,Style.CHARTA_MUTED,false,1))

static func model_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var measured := false
	var shapes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D:
		shapes.append(model)
	for part: MeshInstance3D in shapes:
		if part.mesh:
			var box_in_world := part.global_transform * part.get_aabb()
			bounds = bounds.merge(box_in_world) if measured else box_in_world
			measured = true
	return bounds
