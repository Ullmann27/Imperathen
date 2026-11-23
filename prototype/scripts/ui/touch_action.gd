extends Button
## Standard button styling and focus, with independent native multitouch capture.

static var _icons: Dictionary = {}

var touch_index := -1
var _ignore_mouse_until := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			reset()
	)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.canceled and event.index == touch_index:
			get_viewport().set_input_as_handled()
			reset()
		elif event.pressed and not event.canceled and _contains(event.position):
			get_viewport().set_input_as_handled()
			_ignore_mouse_until = Time.get_ticks_msec() + 180
			if touch_index == -1 and not disabled:
				touch_index = event.index
				self_modulate = Color(1.22, 1.16, 1.02)
				pressed.emit()
		elif not event.pressed and event.index == touch_index:
			get_viewport().set_input_as_handled()
			_ignore_mouse_until = Time.get_ticks_msec() + 180
			reset()
	elif event is InputEventScreenDrag and event.index == touch_index:
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton or event is InputEventMouseMotion) and Time.get_ticks_msec() < _ignore_mouse_until:
		if _contains(event.position) or touch_index != -1:
			get_viewport().set_input_as_handled()


func reset() -> void:
	touch_index = -1
	self_modulate = Color.WHITE


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset()


func _exit_tree() -> void:
	reset()


func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)


func set_action_icon(kind: String) -> void:
	# Original vector marks: shape and short caption communicate the same action.
	if not _icons.has(kind):
		var paths := {
			"interact": '<path d="M5 11V8a1.4 1.4 0 0 1 2.8 0V4a1.4 1.4 0 0 1 2.8 0v5-4a1.4 1.4 0 0 1 2.8 0v4-2a1.4 1.4 0 0 1 2.8 0v5c0 4-2 6-5 6H9c-2 0-4-3-5-5-1-2 0-3 1-2Z"/>',
			"attack": '<path d="M3 8h8l3-3 4 4-4 4-3-3H3m3 5h7m-7 3h4"/>',
			"guard": '<path d="M10 2 17 5v5c0 4-3 7-7 9-4-2-7-5-7-9V5Z"/>',
			"dodge": '<path d="M4 15c0-6 4-10 11-10m-4-3 4 3-3 4M7 14l3 4 5-4"/>',
			"techniques": '<path d="M8 4h9M8 10h9M8 16h9M3 4h1M3 10h1M3 16h1"/>',
			"pace": '<circle cx="11" cy="3" r="1.5"/><path d="m8 7 3-1 2 5 4 1M11 6l-1 7-4 5m4-5 4 5M8 7l-3 5"/>',
			"run": '<circle cx="13" cy="3" r="1.5"/><path d="m5 8 4-2 4 3 4-2m-6 1-3 5-4 1m4-1 5 1 1 4M2 4h4M1 7h3"/>'
		}
		if not paths.has(kind):
			return
		var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 20 20"><g fill="none" stroke="#eadfc9" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">' + str(paths[kind]) + '</g></svg>'
		var picture := Image.new()
		if picture.load_svg_from_string(svg) != OK:
			return
		_icons[kind] = ImageTexture.create_from_image(picture)
	icon = _icons[kind]
	add_theme_constant_override("h_separation", 4)
