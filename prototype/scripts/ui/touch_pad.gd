extends Control
## A fixed analog pad owns exactly one pointer, including drags outside its bounds.

signal axis_changed(axis: Vector2)

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const DEAD_ZONE := 0.12
var touch_index := -1
var axis := Vector2.ZERO
var _mouse_captured := false
var _knob := Vector2.ZERO
var _ignore_mouse_until := 0
## Eased 0..1 while a finger holds the pad; at rest the pad recedes so the
## world stays visible (it never stops accepting a new contact).
var _engaged := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			reset()
	)
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# The engine may deliver a synthetic mouse copy after a long render frame.
	# Its device identity is reliable; a short wall-clock suppression is not.
	if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
		if _contains(event.position) or touch_index!=-1:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.canceled and event.index == touch_index:
			get_viewport().set_input_as_handled()
			reset()
		elif event.pressed and not event.canceled and _contains(event.position):
			get_viewport().set_input_as_handled()
			_ignore_mouse_until = Time.get_ticks_msec() + 180
			if touch_index == -1 and not _mouse_captured:
				touch_index = event.index
				_update_axis(event.position)
		elif not event.pressed and event.index == touch_index:
			get_viewport().set_input_as_handled()
			_ignore_mouse_until = Time.get_ticks_msec() + 180
			reset()
	elif event is InputEventScreenDrag and event.index == touch_index:
		get_viewport().set_input_as_handled()
		_update_axis(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Time.get_ticks_msec() < _ignore_mouse_until and _contains(event.position):
			get_viewport().set_input_as_handled()
			return
		if event.pressed and _contains(event.position) and touch_index == -1:
			_mouse_captured = true
			get_viewport().set_input_as_handled()
			_update_axis(event.position)
		elif not event.pressed and _mouse_captured:
			get_viewport().set_input_as_handled()
			reset()
	elif event is InputEventMouseMotion and _mouse_captured:
		get_viewport().set_input_as_handled()
		_update_axis(event.position)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		reset()


func _exit_tree() -> void:
	reset()


func reset() -> void:
	var was_active := touch_index != -1 or _mouse_captured or not axis.is_zero_approx()
	touch_index = -1
	_mouse_captured = false
	axis = Vector2.ZERO
	_knob = Vector2.ZERO
	queue_redraw()
	if was_active:
		axis_changed.emit(Vector2.ZERO)


func _contains(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)


func _update_axis(point: Vector2) -> void:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	var radius := maxf(24.0, minf(size.x, size.y) * 0.5 - 35.0)
	var raw := (local - size * 0.5) / radius
	_knob = raw.limit_length(1.0)
	if raw.length() <= DEAD_ZONE:
		axis = Vector2.ZERO
	else:
		axis = raw.normalized() * clampf((raw.length() - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
	axis_changed.emit(axis)
	queue_redraw()


func _process(delta: float) -> void:
	var held := touch_index != -1 or _mouse_captured
	var next := move_toward(_engaged, 1.0 if held else 0.0, delta / (0.08 if held else 0.35))
	if not is_equal_approx(next, _engaged):
		_engaged = next
		queue_redraw()


func _draw() -> void:
	# Roman bronze ring: four gilded diamonds mark the axes, the knob is a coin.
	var center := size * 0.5
	var radius := maxf(24.0, minf(size.x, size.y) * 0.5 - 19.0)
	var presence := lerpf(0.5, 1.0, _engaged)
	draw_circle(center, radius, Color(0.045, 0.034, 0.025, 0.2 + 0.25 * _engaged))
	draw_arc(center, radius, 0, TAU, 80, Color(Style.BRONZE, 0.78 * presence), 1.8, true)
	draw_arc(center, radius - 5.0, 0, TAU, 80, Color(Style.AURUM, 0.22 * presence), 1.0, true)
	draw_arc(center, radius * 0.62, 0, TAU, 64, Color(Style.BRONZE, 0.14 + 0.12 * _engaged), 1.0, true)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		Style.draw_diamond(self, center + direction * (radius - 2.5), 4.5, Color(Style.AURUM, 0.8 * presence))
	var knob_center := center + _knob * (radius - 25)
	Style.draw_medallion(self, knob_center, radius * 0.29, _engaged, false, _engaged > 0.5)
