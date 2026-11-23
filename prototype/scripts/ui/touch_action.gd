extends Button
## Standard button styling and focus, with independent native multitouch capture.

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
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
		if _contains(event.position) or touch_index!=-1:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _contains(event.position):
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


func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)
