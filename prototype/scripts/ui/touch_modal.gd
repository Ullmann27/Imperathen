extends Control
## Native scroll/list input runs first; all unused contacts remain inside this overlay.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse):
		get_viewport().set_input_as_handled()
