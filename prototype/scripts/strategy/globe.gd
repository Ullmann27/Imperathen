extends SubViewportContainer
signal region_selected(id: String)
const Atlas = preload("res://scripts/strategy/atlas_data.gd")
var viewport := SubViewport.new()
var planet := Node3D.new()
var camera := Camera3D.new()
var pins := {}
var arcs := MeshInstance3D.new()
var selected := "italia"
var yaw := 0.0
var pitch := 0.6
var zoom := 3.0
var pointer := -10
var fingers := {}
var start := Vector2.ZERO
var dragged := false

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	add_child(viewport)
	var universe := Node3D.new()
	viewport.add_child(universe)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10232b")
	camera.environment = env
	universe.add_child(camera)
	universe.add_child(planet)
	camera.fov = 51
	camera.current = true
	var sphere := MeshInstance3D.new()
	sphere.mesh = _earth()
	planet.add_child(sphere)
	planet.add_child(arcs)
	var dot := SphereMesh.new()
	dot.radius = 0.016
	dot.height = 0.032
	dot.radial_segments = 8
	dot.rings = 4
	for id in Atlas.REGIONS:
		var pin := MeshInstance3D.new()
		pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pin.mesh = dot
		pin.position = _normal(Atlas.REGIONS[id]) * 1.012
		pin.material_override = _ink(Color("#fff0c1"))
		planet.add_child(pin)
		pins[id] = pin
	focus_region(selected)

func _normal(region: Dictionary) -> Vector3:
	return _direction(deg_to_rad(region.lat),deg_to_rad(region.lon))

func _direction(lat: float,lon: float) -> Vector3:
	return Vector3(cos(lat)*sin(lon),sin(lat),cos(lat)*cos(lon))

func _earth() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(65):
		for i in range(129):
			var uv := Vector2(i/128.0,j/64.0)
			var n := _direction(PI*(0.5-uv.y),TAU*(uv.x-0.5))
			surface.set_uv(uv)
			surface.set_normal(n)
			surface.add_vertex(n)
	for j in 64:
		for i in 128:
			var first := j*129+i
			for offset in [0,1,130,0,130,129]:
				surface.add_index(first+offset)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	render_mode unshaded, cull_disabled;
	uniform sampler2D earth : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
	void fragment() {
		vec3 ink = texture(earth,UV).rgb;
		float light = max(dot(normalize(NORMAL), normalize(vec3(-0.38,0.55,0.77))),0.0);
		float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.5);
		ALBEDO = ink * (0.49 + 0.58 * light) + vec3(0.06,0.17,0.23) * rim;
	}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("earth",preload("res://assets/atlas/earth.jpg"))
	surface.set_material(mat)
	return surface.commit()

func _ink(color: Color) -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = color
	return ink

func _rotate() -> void:
	planet.basis = Basis(Vector3.RIGHT,pitch)*Basis(Vector3.UP,-yaw)
	camera.position = Vector3(0,0,zoom)

func focus_region(id: String) -> void:
	selected = id
	var region: Dictionary = Atlas.REGIONS[id]
	yaw = deg_to_rad(region.lon)
	pitch = deg_to_rad(region.lat)
	_rotate()

func show_routes(id: String,owned: Array) -> void:
	selected = id
	var area: Dictionary = Atlas.REGIONS[id]
	var routes := ImmediateMesh.new()
	routes.surface_begin(Mesh.PRIMITIVE_LINES,_ink(Color("#f5cd7e")))
	for other in Atlas.REGIONS:
		var connected: bool = other in area.links or id in Atlas.REGIONS[other].links
		var chosen: bool = other == id
		var color := Color("#efac45") if chosen else (Color("#55d5bf") if other in owned else Color("#e7ded4"))
		pins[other].material_override.albedo_color = color
		pins[other].scale = Vector3.ONE * (1.65 if chosen else 1.0)
		if connected:
			var a := _normal(area)
			var b := _normal(Atlas.REGIONS[other])
			for i in 36:
				routes.surface_add_vertex(a.slerp(b,i/36.0)*1.006)
				routes.surface_add_vertex(a.slerp(b,(i+1.0)/36.0)*1.006)
	routes.surface_end()
	arcs.mesh = routes

func _pick(pixel: Vector2) -> void:
	var best := ""
	var threshold := 26.0
	for id in pins:
		var p: Vector3 = pins[id].global_position
		if p.dot(camera.position-p) < 0.0:
			continue
		var d := camera.unproject_position(p).distance_to(pixel)
		if d < threshold:
			best = id
			threshold = d
	if best != "":
		region_selected.emit(best)

func _drag(delta: Vector2) -> void:
	yaw -= delta.x*0.006
	pitch = clampf(pitch+delta.y*0.006,-PI/2.0,PI/2.0)
	_rotate()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			if fingers.size() == 1:
				start = event.position
				dragged = false
			else:
				dragged = true
		else:
			if fingers.has(event.index) and fingers.size() == 1 and not dragged:
				_pick(event.position)
			fingers.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var old: Vector2 = fingers[event.index]
		fingers[event.index] = event.position
		if fingers.size() == 2:
			var ids := fingers.keys()
			var other: Vector2 = fingers[ids[1] if ids[0]==event.index else ids[0]]
			zoom = clampf(zoom*old.distance_to(other)/maxf(1.0,event.position.distance_to(other)),1.65,4.2)
			_rotate()
		else:
			_drag(event.position-old)
		dragged = dragged or start.distance_to(event.position)>6.0
		accept_event()
	elif event.device != InputEvent.DEVICE_ID_EMULATION and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer = 0
				start = event.position
				dragged = false
			elif pointer == 0:
				if not dragged:
					_pick(event.position)
				pointer = -10
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
			zoom = clampf(zoom*(1.10 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0.91),1.65,4.2)
			_rotate()
		accept_event()
	elif event is InputEventMouseMotion and pointer == 0:
		dragged = dragged or start.distance_to(event.position)>6.0
		_drag(event.relative)
		accept_event()
