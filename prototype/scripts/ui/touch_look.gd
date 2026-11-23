extends Control
## Claims only unhandled world contacts; an owned finger stays owned over HUD controls.

signal look_changed(delta: Vector2)
signal zoom_changed(factor: float)

var contacts: Dictionary[int, Vector2] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			reset()
	)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch and contacts.has(event.index):
		if not event.pressed or event.canceled:
			contacts.erase(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and contacts.has(event.index):
		var previous: Vector2 = contacts[event.index]
		contacts[event.index] = event.position
		if contacts.size() == 2:
			var other: int = contacts.keys()[0]
			if other == event.index:
				other = contacts.keys()[1]
			var before: float = previous.distance_to(contacts[other])
			var after: float = event.position.distance_to(contacts[other])
			if minf(before, after) >= 12.0:
				zoom_changed.emit(clampf(before / after, 0.5, 2.0))
		else:
			# Stored contact positions avoid a stale delta when a pinch becomes a look.
			look_changed.emit(event.position - previous)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event is not InputEventScreenTouch:
		return
	if event.pressed and not event.canceled and _contains(event.position):
		if contacts.size() < 2:
			contacts[event.index] = event.position
		get_viewport().set_input_as_handled()


func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)


func reset() -> void:
	contacts.clear()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset()


func _exit_tree() -> void:
	reset()
