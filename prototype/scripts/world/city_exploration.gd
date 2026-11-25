extends Node3D
## Independent free walk: no mission, economy or campaign simulation is started.
signal leave_requested
const Person := preload("res://scripts/visuals/village_person.gd")
const State := preload("res://scripts/world/city_exploration_state.gd")
const CameraObstruction := preload("res://scripts/world/camera_obstruction.gd")
const CityDetailAdapter := preload("res://scripts/rendering/city_exploration_detail_adapter.gd")
const TouchPad := preload("res://scripts/ui/touch_pad.gd")
const TouchLook := preload("res://scripts/ui/touch_look.gd")
const TouchAction := preload("res://scripts/ui/touch_action.gd")
const SafeArea := preload("res://scripts/ui/safe_area.gd")
const CITY_PATH := "res://assets/world/roman_city_test.glb"
const CITY_COLLISION := "res://assets/world/roman_city_collision.glb"
const TEMPLE_PATH := "res://assets/world/meshy_roman_temple.glb"
const CATALOG_PATH := "res://assets/world/city_catalog.json"
const CATALOG_ORIGIN := Vector3(475,0,90)
const WALK_SPEED := 1.45
const RUN_SPEED := 3.8
var profile := "balanced"
var persist := true
var save_path := State.PATH
var paused := false
var player := CharacterBody3D.new()
var figure := Person.new()
var camera := Camera3D.new()
var city_available := false
var youth_available := false
var catalog: Array[Dictionary] = []
var _catalog_nodes: Dictionary = {}
var _catalog_pending := ""
var _catalog_pending_index := -1
var _catalog_elapsed := 0.0
var _catalog_status := ""
var _touch_move := Vector2.ZERO
var _yaw := 0.0
var _pitch := -0.18
var _distance := 4.2
var _running := false
var _camera_solver := CameraObstruction.new()
var _camera_previous := Vector3.INF
var _action_left := 0.0
var _save_elapsed := 0.0
var _hud := CanvasLayer.new()
var _safe := Control.new()
var _status := Label.new()
var _pace: Button
var _pause_panel := PanelContainer.new()
var _pad: Control
var _look: Control
var _toolbar: HBoxContainer
var _actions: HBoxContainer

func _ready() -> void:
	name = "CityExploration"
	_build_ground()
	_load_city()
	_build_player()
	_build_camera()
	_read_catalog()
	_build_ui()
	_restore(State.read(save_path) if persist else State.defaults())
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	_update_status()
	print("IMPERATHEN_CITY_READY "+JSON.stringify({"city":city_available,"meshy_youth":youth_available,"catalog_families":catalog.size(),"campaign_started":false}))

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "ExplorationGround"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1400,1400)
	ground.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("777d55")
	material.roughness = 0.96
	ground.material_override = material
	ground.position.y = -0.025
	add_child(ground)
	_box_collision(self,Vector3(1400,0.2,1400),Vector3(0,-0.125,0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-24,0)
	sun.light_color = Color(1.0,0.88,0.72)
	sun.light_energy = 1.05
	sun.shadow_enabled = profile!="low"
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func _scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path,"PackedScene"):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed!=null else null

func _load_city() -> void:
	var city := _scene(CITY_PATH)
	if city!=null:
		city.name = "RomanCity"
		add_child(city)
		city_available = true
		for mesh: MeshInstance3D in city.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_end = 270.0 if profile in ["low","balanced"] else 450.0
			mesh.visibility_range_end_margin = 20.0
	var collision := _scene(CITY_COLLISION)
	if collision!=null:
		add_child(collision)
		for mesh: MeshInstance3D in collision.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null:
				continue
			var body := StaticBody3D.new()
			body.name = "CityCollision_"+str(mesh.name)
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			add_child(body)
			body.global_transform = mesh.global_transform
		collision.queue_free()
	var temple := _scene(TEMPLE_PATH)
	if temple!=null:
		temple.name = "MeshyTemple"
		temple.position = Vector3(0,0,-55)
		add_child(temple)
	print("IMPERATHEN_CITY_DETAIL " + JSON.stringify(CityDetailAdapter.install(city, profile)))

func _build_player() -> void:
	player.name = "ExplorationPlayer"
	player.collision_layer = 2
	player.collision_mask = 1
	player.safe_margin = 0.002
	player.floor_snap_length = 0.24
	player.floor_max_angle = deg_to_rad(46.0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.5
	capsule.radius = 0.24
	collider.shape = capsule
	collider.position.y = -0.15
	player.add_child(collider)
	add_child(player)
	figure.name = "Youth"
	figure.profile = profile
	player.add_child(figure)
	figure.configure("player","italia",12)
	youth_available = figure.configure_meshy_youth()
	figure._reload(2 if profile=="low" else (1 if profile=="balanced" else 0))
	figure._check_lod = 10000.0

func _build_camera() -> void:
	add_child(camera)
	camera.name = "ExplorationCamera"
	camera.current = true
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 1200.0
	var environment := Environment.new()
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color("638caf")
	atmosphere.sky_horizon_color = Color("c4d3d3")
	atmosphere.ground_bottom_color = Color("80775d")
	atmosphere.ground_horizon_color = Color("c4d3d3")
	sky.sky_material = atmosphere
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4c0ce")
	environment.ambient_light_energy = 0.62
	environment.ambient_light_sky_contribution = 0.0
	environment.fog_enabled = true
	environment.fog_density = 0.0013
	environment.fog_light_color = Color("c3c9bf")
	camera.environment = environment

func _read_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not data is Dictionary or data.get("format","")!="imperathen-city-catalog":
		return
	for value: Variant in data.get("families",[]):
		if value is Dictionary and value.get("tiers") is Array and not value.tiers.is_empty():
			catalog.append(value)
	var label := Label3D.new()
	label.text = "MODELLSAMMLUNG\n%d vorhandene Modellfamilien" % catalog.size()
	label.font_size = 50
	label.pixel_size = 0.015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = CATALOG_ORIGIN+Vector3(0,4,8)
	label.visibility_range_end = 110
	add_child(label)

func _catalog_position(index: int) -> Vector3:
	return CATALOG_ORIGIN+Vector3(float(index%4)*26,0,-float(index/4)*22)

func _catalog_path(entry: Dictionary) -> String:
	var target := 2 if profile=="low" else 1
	var closest := 100
	var path := ""
	for tier: Dictionary in entry.tiers:
		var difference := absi(int(tier.level)-target)
		if difference<closest and ResourceLoader.exists(str(tier.path),"PackedScene"):
			closest = difference
			path = str(tier.path)
	return path

func _stream_catalog() -> void:
	if not _catalog_pending.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_catalog_pending)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_catalog_pending) as PackedScene
			if packed!=null:
				_add_catalog_model(_catalog_pending_index,packed)
			_catalog_pending = ""
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
			_catalog_status = "Ein Sammlungsmodell konnte nicht geladen werden."
			_catalog_pending = ""
			_update_status()
		return
	for index: int in _catalog_nodes.keys():
		if player.position.distance_to(_catalog_position(index))>95:
			var node: Node3D = _catalog_nodes[index]
			node.queue_free()
			_catalog_nodes.erase(index)
	var nearest := -1
	var nearest_distance := 70.0
	for index in catalog.size():
		if _catalog_nodes.has(index):
			continue
		var distance := player.position.distance_to(_catalog_position(index))
		if distance<nearest_distance:
			nearest = index
			nearest_distance = distance
	if nearest<0:
		return
	var path := _catalog_path(catalog[nearest])
	if not path.is_empty() and ResourceLoader.load_threaded_request(path,"PackedScene",false)==OK:
		_catalog_pending = path
		_catalog_pending_index = nearest

func _add_catalog_model(index: int,packed: PackedScene) -> void:
	var model := packed.instantiate() as Node3D
	if model==null:
		return
	var station := Node3D.new()
	station.name = "Catalog_%02d" % index
	station.position = _catalog_position(index)
	add_child(station)
	station.add_child(model)
	var bounds := _bounds(model)
	model.position.y = -bounds.position.y
	if catalog[index].category=="equipment":
		model.position.y += 1.0
		_box_visual(station,Vector3(2,0.8,2),Vector3(0,0.4,0),Color("ad9d7d"))
		_box_collision(station,Vector3(2,0.8,2),Vector3(0,0.4,0))
	var label := Label3D.new()
	label.text = str(catalog[index].name)
	label.font_size = 34
	label.pixel_size = 0.008
	label.position = Vector3(0,maxf(2,bounds.size.y+0.4),0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 38
	station.add_child(label)
	_catalog_nodes[index] = station

func _build_ui() -> void:
	_hud.layer = 20
	add_child(_hud)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_safe)
	_look = TouchLook.new()
	_look.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look.look_changed.connect(_look_by)
	_look.zoom_changed.connect(func(factor: float): _distance=clampf(_distance*factor,1.6,8.0))
	_safe.add_child(_look)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "IMPERATHEN · FREIE STADTERKUNDUNG"
	heading.add_theme_font_size_override("font_size",21)
	heading.add_theme_color_override("font_color",Color("f1dfb4"))
	heading.add_theme_color_override("font_shadow_color",Color.BLACK)
	heading.add_theme_constant_override("shadow_offset_x",1)
	heading.add_theme_constant_override("shadow_offset_y",2)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(heading)
	_status.add_theme_font_size_override("font_size",15)
	_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x",1)
	_status.add_theme_constant_override("shadow_offset_y",2)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_status)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation",8)
	_toolbar.add_child(_button("Stadt",func(): teleport(State.SPAWN)))
	_toolbar.add_child(_button("Modelle",func(): teleport(CATALOG_ORIGIN+Vector3(0,0.92,12))))
	_toolbar.add_child(_button("Pause",func(): set_paused(not paused)))
	_safe.add_child(_toolbar)
	_pad = TouchPad.new()
	_pad.axis_changed.connect(func(axis: Vector2): _touch_move=axis)
	_safe.add_child(_pad)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation",8)
	_pace = _button("Gehen",_toggle_pace)
	_actions.add_child(_pace)
	_actions.add_child(_button("Hieb",func(): perform_action("attack")))
	_actions.add_child(_button("Abwehr",func(): perform_action("block")))
	_safe.add_child(_actions)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.08,0.08,0.96)
	style.set_content_margin_all(22)
	style.border_color = Color("b89862")
	style.set_border_width_all(1)
	_pause_panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	var description := Label.new()
	description.text = "Freie Testrunde\n\nWASD / linker Stick: bewegen\nShift / Gehen: Tempo wechseln\nRechte Maustaste / Wischen: umsehen\nLeertaste: Hieb · Q: Abwehr\n\nDiese Stadt startet keine Mission."
	description.add_theme_font_size_override("font_size",17)
	column.add_child(description)
	column.add_child(_button("Weiter erkunden",func(): set_paused(false)))
	column.add_child(_button("Zum Hauptmenü",_request_leave))
	_pause_panel.add_child(column)
	_safe.add_child(_pause_panel)
	_pause_panel.hide()

func _button(caption: String,callback: Callable) -> Button:
	var button := TouchAction.new()
	button.text = caption
	button.custom_minimum_size = Vector2(104,56)
	button.add_theme_font_size_override("font_size",18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _layout_ui() -> void:
	var safe := SafeArea.for_viewport(get_viewport())
	_safe.position = safe.position+Vector2(12,12)
	_safe.size = safe.size-Vector2(24,24)
	var portrait := _safe.size.x<760
	_safe.get_node("Heading").position = Vector2(2,0)
	_safe.get_node("Heading").add_theme_font_size_override("font_size",16 if portrait else 21)
	_status.position = Vector2(2,31)
	_status.size = Vector2(_safe.size.x-8,54)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toolbar.position = Vector2(0,90 if portrait else 71)
	_pad.size = Vector2(178,178)
	_pad.position = Vector2(0,_safe.size.y-182)
	_actions.position = Vector2(maxf(0,_safe.size.x-328),_safe.size.y-(250 if portrait else 82))
	_pause_panel.size = Vector2(minf(430,_safe.size.x),350)
	_pause_panel.position = (_safe.size-_pause_panel.size)*0.5

func _physics_process(delta: float) -> void:
	if paused:
		return
	_action_left = maxf(0,_action_left-delta)
	var axis := _touch_move
	axis.x += float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	axis.y += float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	axis = axis.limit_length(1)
	var direction := Vector3(axis.x,0,axis.y).rotated(Vector3.UP,_yaw)
	var running := _running or Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := RUN_SPEED if running else WALK_SPEED
	var previous_yaw := figure.rotation.y
	if direction.length_squared()>0.01 and _action_left<=0:
		figure.rotation.y = rotate_toward(figure.rotation.y,atan2(-direction.x,-direction.z),delta*4.5)
		var alignment := maxf(0,Vector3.FORWARD.rotated(Vector3.UP,figure.rotation.y).dot(direction))
		speed *= lerpf(0.3,1,alignment)
	var desired := direction*speed if _action_left<=0 else Vector3.ZERO
	var acceleration := 8.0 if running else 5.0
	player.velocity.x = move_toward(player.velocity.x,desired.x,delta*acceleration)
	player.velocity.z = move_toward(player.velocity.z,desired.z,delta*acceleration)
	player.velocity.y = -0.3 if player.is_on_floor() else player.velocity.y-19.6*delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x,-State.LIMIT+1,State.LIMIT-1)
	player.position.z = clampf(player.position.z,-State.LIMIT+1,State.LIMIT-1)
	if player.position.y < -8:
		teleport(State.SPAWN)
	var actual := player.get_real_velocity()
	figure.drive(Vector2(actual.x,actual.z).length(),angle_difference(previous_yaw,figure.rotation.y)/maxf(delta,0.000001))
	_place_camera(delta)

func _process(delta: float) -> void:
	_catalog_elapsed += delta
	if _catalog_elapsed>=0.15:
		_catalog_elapsed = 0
		_stream_catalog()
	if paused:
		return
	_save_elapsed += delta
	if _save_elapsed>=30:
		_save_elapsed = 0
		save_state()

func _place_camera(delta: float) -> void:
	var anchor := player.position+Vector3(0,0.4,0)
	var wanted := anchor+Vector3(0,0,_distance).rotated(Vector3.RIGHT,_pitch).rotated(Vector3.UP,_yaw)
	var placed := _camera_solver.place(get_world_3d().direct_space_state,anchor,wanted,_camera_previous,1-exp(-12*delta),[player.get_rid()])
	if placed.is_finite():
		camera.position = placed
		_camera_previous = placed
		if camera.position.distance_squared_to(anchor)>0.001:
			camera.look_at(anchor,Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_look_by(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_SPACE:
			perform_action("attack")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_Q:
			perform_action("block")
			get_viewport().set_input_as_handled()

func _look_by(delta: Vector2) -> void:
	if not paused:
		_yaw = wrapf(_yaw-delta.x*0.004,-PI,PI)
		_pitch = clampf(_pitch-delta.y*0.003,-0.75,0.65)

func _toggle_pace() -> void:
	_running = not _running
	_pace.text = "Rennen" if _running else "Gehen"

func perform_action(action: String) -> void:
	if paused or _action_left>0 or action not in ["attack","block"]:
		return
	_action_left = 0.8
	figure.cue(action)

func set_paused(value: bool) -> void:
	paused = value
	_touch_move = Vector2.ZERO
	_pad.reset()
	_look.reset()
	player.velocity = Vector3.ZERO
	figure.drive(0)
	figure.set_process(not paused)
	_pause_panel.visible = paused
	_pad.visible = not paused
	_actions.visible = not paused
	_toolbar.visible = not paused
	if paused:
		save_state()

func teleport(point: Vector3) -> void:
	if not point.is_finite():
		return
	player.position = point
	player.velocity = Vector3.ZERO
	figure.reset_motion()
	_action_left = 0
	_camera_previous = Vector3.INF
	_camera_solver.reset()

func snapshot() -> Dictionary:
	return {"position":player.position,"heading":figure.rotation.y,"yaw":_yaw,"pitch":_pitch,"distance":_distance,"running":_running}

func _restore(state: Dictionary) -> void:
	teleport(state.position)
	figure.rotation.y = state.heading
	_yaw = state.yaw
	_pitch = state.pitch
	_distance = state.distance
	_running = state.running
	_pace.text = "Rennen" if _running else "Gehen"

func save_state() -> Error:
	if not persist:
		return OK
	var error := State.write(snapshot(),save_path)
	if error!=OK:
		_catalog_status = "Die Position konnte nicht gespeichert werden."
		_update_status()
	return error

func _request_leave() -> void:
	if save_state()==OK:
		leave_requested.emit()

func _update_status() -> void:
	var description := "Stadt · Modellpark · Gehen · Rennen · Kampfübungen"
	if not city_available:
		description = "Stadtmodell ist noch nicht importiert."
	elif not youth_available:
		description += " · Bisherige Figur als Rückfallmodell"
	if not _catalog_status.is_empty():
		description += "\n"+_catalog_status
	_status.text = description

static func _box_collision(parent: Node3D,size: Vector3,at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body

static func _box_visual(parent: Node3D,size: Vector3,at: Vector3,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	parent.add_child(mesh)

static func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:
			continue
		var transform := model.global_transform.affine_inverse()*mesh.global_transform
		var box: AABB = transform*mesh.get_aabb()
		result = result.merge(box) if found else box
		found = true
	return result
