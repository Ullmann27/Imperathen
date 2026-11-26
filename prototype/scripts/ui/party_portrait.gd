extends SubViewportContainer
## A presentation-only copy of the visible mesh. It holds no gameplay actor or collision.

var stage := SubViewport.new()
var pivot := Node3D.new()
var touch := -1
var dragging := false


func build(source: Node3D) -> void:
	stretch = true
	custom_minimum_size = Vector2(164, 202)
	tooltip_text = "Figur zum Drehen ziehen"
	stage.own_world_3d = true
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE
	stage.size = Vector2i(164, 202)
	add_child(stage)
	stage.add_child(pivot)
	var figure: Node3D = source.get_node_or_null("Model") if is_instance_valid(source) else null
	if not figure:
		return
	var replica := figure.duplicate(0) as Node3D
	pivot.add_child(replica)
	replica.position = Vector3.ZERO
	pivot.rotation.y = PI + 0.18
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("272923")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f2dfbe")
	env.ambient_light_energy = 0.96
	environment.environment = env
	stage.add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-28, -24, 0)
	sunlight.light_energy = 1.5
	stage.add_child(sunlight)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 0.96, 2.55)
	camera.look_at(Vector3(0, 0.80, 0))
	camera.fov = 35
	camera.current = true
	resized.connect(_redraw)


func _redraw() -> void:
	stage.render_target_update_mode = SubViewport.UPDATE_ONCE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch == -1:
			touch = event.index
		elif not event.pressed and touch == event.index:
			touch = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch:
		_turn(event.relative.x)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and dragging and touch == -1:
		_turn(event.relative.x)


func _turn(distance: float) -> void:
	pivot.rotation.y += distance * 0.018
	_redraw()
	accept_event()
