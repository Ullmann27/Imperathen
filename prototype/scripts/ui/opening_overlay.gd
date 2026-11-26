extends CanvasLayer
## Presentation only: the entry point owns the cinematic clock and game state.
## Resizing retains the current cue, focus, reading mode, and pause state.

signal advance_requested
signal pause_requested
signal skip_requested
signal reading_mode_changed(enabled: bool)
## AwaitChoice: the player picks an option inside the film. The overlay only
## reports the authored action id; Main commits it through the checked model.
signal choice_requested(action_id: String)

const SafeArea = preload("res://scripts/ui/safe_area.gd")
const TouchAction = preload("res://scripts/ui/touch_action.gd")
const IVORY := Color("f3e8d4")
const MUTED := Color("c2bbae")
const BRONZE := Color("c2a06b")
const WINE := Color("642d32")

class FilmShade extends Control:

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Soft edge gradients retain the live scene instead of a full-screen modal.
		var clear := Color(0.025, 0.025, 0.03, 0.0)
		var top := Color(0.025, 0.025, 0.03, 0.66)
		var bottom := Color(0.025, 0.025, 0.03, 0.72)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x,0), Vector2(size.x,size.y*0.24), Vector2(0,size.y*0.24)]), PackedColorArray([top,top,clear,clear]))
		draw_polygon(PackedVector2Array([Vector2(0,size.y*0.59), Vector2(size.x,size.y*0.59), size, Vector2(0,size.y)]), PackedColorArray([clear,clear,bottom,bottom]))

class StoryLine extends Control:
	var cue := 0
	var count := 1
	var progress := 0.0

	func _ready() -> void:
		custom_minimum_size.y = 3
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var gap := 8.0
		var width := maxf(1.0, (size.x - gap * (count - 1)) / count)
		for index in count:
			var rect := Rect2(index * (width + gap), 0, width, 2)
			draw_rect(rect, Color(0.76, 0.63, 0.42, 0.19))
			var fill := 1.0 if index < cue else progress if index == cue else 0.0
			if fill > 0:
				rect.size.x *= fill
				draw_rect(rect, Color(0.76, 0.63, 0.42, 0.8))

var _root: Control
var _safe: Control
var _metadata: VBoxContainer
var _chapter: Label
var _location: Label
var _toolbar: HFlowContainer
var _reading_button: Button
var _pause_button: Button
var _skip_button: Button
var _panel: PanelContainer
var _stack: VBoxContainer
var _speaker: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _text: Label
var _objective_heading: Label
var _objective_text: Label
var _choices: VBoxContainer
var _choice_open := false
var _story_line: StoryLine
var _footer: HBoxContainer
var _hint: Label
var _advance_button: Button
var _serif: SystemFont
var _active := false
var _paused := false
var _manual_reading := false
var _reduce_motion := false
var _touch_enabled := false
var _ui_scale := 1.0
var _final := false
var _advance_pending := false
var _skip_pending := false
var _layout_pending := false
var _beat: Dictionary = {}
var _fade: Tween
var _safe_override := Rect2()


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["DejaVu Serif", "Noto Serif", "Liberation Serif"])
	_root = Control.new()
	_root.name = "OpeningPresentation"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := FilmShade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_safe = Control.new()
	_safe.name = "OpeningSafeArea"
	_safe.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_safe)
	_metadata = VBoxContainer.new()
	_metadata.add_theme_constant_override("separation", 6)
	_metadata.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_metadata)
	_chapter = _label("", 24, IVORY, true)
	_chapter.name = "OpeningChapter"
	_metadata.add_child(_chapter)
	_location = _label("", 13, MUTED)
	_location.name = "OpeningLocation"
	_metadata.add_child(_location)
	_toolbar = HFlowContainer.new()
	_toolbar.alignment = FlowContainer.ALIGNMENT_END
	_toolbar.add_theme_constant_override("h_separation", 8)
	_toolbar.add_theme_constant_override("v_separation", 6)
	_safe.add_child(_toolbar)
	_reading_button = _button("Lesemodus", "OpeningReading", _toggle_reading)
	_reading_button.tooltip_text = "Du entscheidest selbst, wann die nächste Zeile beginnt."
	_toolbar.add_child(_reading_button)
	_pause_button = _button("Pause", "OpeningPause", _request_pause)
	_toolbar.add_child(_pause_button)
	_skip_button = _button("Überspringen", "OpeningSkip", _request_skip)
	_skip_button.tooltip_text = "Zur ersten Aufgabe springen. Keine Entscheidung wird für dich getroffen."
	_toolbar.add_child(_skip_button)
	_panel = PanelContainer.new()
	_panel.name = "OpeningSubtitlePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.041, 0.045, 0.9)
	style.border_width_top = 2
	style.border_color = Color(BRONZE, 0.7)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 17
	style.content_margin_bottom = 16
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	_safe.add_child(_panel)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 12)
	_panel.add_child(_stack)
	_speaker = _label("", 13, BRONZE)
	_speaker.name = "OpeningSpeaker"
	_stack.add_child(_speaker)
	_scroll = ScrollContainer.new()
	_scroll.name = "OpeningTextScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_stack.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)
	_text = _label("", 22, IVORY)
	_text.name = "OpeningSubtitle"
	_content.add_child(_text)
	_objective_heading = _label("", 26, IVORY, true)
	_objective_heading.name = "OpeningObjectiveTitle"
	_content.add_child(_objective_heading)
	_objective_text = _label("", 20, IVORY)
	_objective_text.name = "OpeningObjectiveText"
	_content.add_child(_objective_text)
	_choices = VBoxContainer.new()
	_choices.name = "OpeningChoices"
	_choices.add_theme_constant_override("separation", 8)
	_content.add_child(_choices)
	_story_line = StoryLine.new()
	_stack.add_child(_story_line)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 16)
	_stack.add_child(_footer)
	_hint = _label("", 12, MUTED)
	_hint.name = "OpeningInputHint"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_footer.add_child(_hint)
	_advance_button = _button("Weiter", "OpeningAdvance", _request_advance, true)
	_advance_button.custom_minimum_size.x = 148
	_footer.add_child(_advance_button)
	_content.minimum_size_changed.connect(_queue_layout)
	_metadata.minimum_size_changed.connect(_queue_layout)
	_toolbar.minimum_size_changed.connect(_queue_layout)
	get_viewport().size_changed.connect(_queue_layout)
	_refresh_preferences()
	hide()


func configure(options: Dictionary = {}) -> void:
	_ui_scale = clampf(float(options.get("ui_scale", 1.0)), 0.85, 1.25)
	_reduce_motion = bool(options.get("reduce_motion", false))
	_touch_enabled = bool(options.get("touch_enabled", OS.has_feature("mobile")))
	_manual_reading = bool(options.get("manual_reading", false))
	if is_instance_valid(_root):
		_refresh_preferences()


func present(beat: Dictionary, index: int, total: int) -> void:
	_beat = beat.duplicate(true)
	_active = true
	_final = bool(beat.get("final", false)) or bool(beat.get("objective", false))
	_advance_pending = false
	_skip_pending = false
	_chapter.text = str(beat.get("chapter", "Ein neues Leben"))
	_location.text = str(beat.get("location", ""))
	_location.visible = not _location.text.is_empty()
	var who := str(beat.get("speaker", ""))
	var role := str(beat.get("role", ""))
	_speaker.text = "DEIN ERSTER SCHRITT" if _final else who.to_upper() + ("  ·  " + role if not role.is_empty() else "")
	_speaker.visible = not _speaker.text.is_empty()
	_text.text = str(beat.get("text", ""))
	_text.visible = not _final and not _text.text.is_empty()
	_objective_heading.text = str(beat.get("objective_title", "Ein Dach für die Nacht"))
	_objective_text.text = str(beat.get("objective_text", beat.get("text", "")))
	_objective_heading.visible = _final
	_objective_text.visible = _final
	for old_choice: Node in _choices.get_children():
		_choices.remove_child(old_choice)
		old_choice.queue_free()
	_choice_open = bool(beat.get("choice_open", false)) and not beat.get("choices", []).is_empty()
	if _choice_open:
		for choice_index in beat.choices.size():
			var option: Dictionary = beat.choices[choice_index]
			var action_id := str(option.get("action_id", ""))
			var choice := _button(str(option.get("label", "")), "OpeningChoice_" + action_id, func(): _request_choice(action_id), choice_index == 0)
			choice.set_meta("choice_action", action_id)
			_choices.add_child(choice)
	_choices.visible = _choice_open
	_skip_button.visible = not _final and not _choice_open
	_advance_button.visible = not _choice_open
	_advance_button.text = str(beat.get("advance_label", "Ins Dorf" if _final else "Weiter"))
	_story_line.count = maxi(1, total)
	_story_line.cue = clampi(index, 0, _story_line.count - 1)
	_story_line.progress = 1.0 if _final else 0.0
	_story_line.queue_redraw()
	_scroll.scroll_vertical = 0
	show()
	_update_status()
	_queue_layout()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_panel.modulate.a = 1.0
	if not _reduce_motion:
		_panel.modulate.a = 0.3
		_fade = create_tween()
		_fade.tween_property(_panel, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	if _choice_open:
		_choices.get_child(0).grab_focus.call_deferred()
	else:
		_advance_button.grab_focus.call_deferred()


func show_choice_feedback(message: String) -> void:
	if is_instance_valid(_hint) and not message.is_empty():
		_hint.text = message


func _request_choice(action_id: String) -> void:
	if not _active or _paused or not _choice_open or action_id.is_empty():
		return
	choice_requested.emit(action_id)


func set_paused(paused: bool) -> void:
	_paused = paused
	if is_instance_valid(_root):
		_advance_button.disabled = paused
		_update_status()
		if _active:
			(_pause_button if paused else _advance_button).grab_focus.call_deferred()


func set_manual_reading(enabled: bool) -> void:
	_manual_reading = enabled
	if is_instance_valid(_root):
		_update_status()


func set_progress(fraction: float) -> void:
	if not is_instance_valid(_story_line):
		return
	_story_line.progress = 1.0 if _final else clampf(fraction, 0.0, 1.0)
	_story_line.queue_redraw()


func finish() -> void:
	_active = false
	_reset_touch()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	hide()


func handle_back() -> bool:
	if not _active:
		return false
	_request_pause()
	return true


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_request_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]:
		_request_pause()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		_request_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_request_advance()
		get_viewport().set_input_as_handled()


func _request_advance() -> void:
	if not _active or _paused or _advance_pending:
		return
	_advance_pending = true
	advance_requested.emit()


func _request_pause() -> void:
	if _active:
		pause_requested.emit()


func _request_skip() -> void:
	if not _active or _final or _skip_pending:
		return
	_skip_pending = true
	skip_requested.emit()


func _toggle_reading() -> void:
	if not _active:
		return
	_manual_reading = not _manual_reading
	_update_status()
	reading_mode_changed.emit(_manual_reading)


func _update_status() -> void:
	_reading_button.text = "Lesemodus ✓" if _manual_reading else "Lesemodus"
	_pause_button.text = "Fortfahren" if _paused else "Pause"
	_hint.text = "Die Szene wartet auf dich." if _paused else "Dein Weg beginnt hier." if _final else "Die Szene wartet auf deine Entscheidung." if _choice_open else "Du bestimmst das Tempo." if _manual_reading else "In deinem Tempo weiterlesen."
	if not _touch_enabled and not _final and not _choice_open:
		_hint.text += "  Enter · weiter"
	_queue_layout()


func _refresh_preferences() -> void:
	for node in _root.find_children("*", "Control", true, false):
		if node.has_meta("opening_font_size"):
			node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("opening_font_size")) * _ui_scale))
		if node is Button:
			node.custom_minimum_size.y = maxf(48, 46 * _ui_scale)
	_update_status()


func _queue_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_fit_layout.call_deferred()


func _fit_layout() -> void:
	_layout_pending = false
	var bounds := _safe_override if _safe_override.has_area() else SafeArea.for_viewport(get_viewport())
	_safe.position = bounds.position
	_safe.size = bounds.size
	var extent := bounds.size
	var margin := 28.0 if extent.x >= 1000 else 18.0
	var width := maxf(200.0, extent.x - 2 * margin)
	var toolbar_width := 0.0
	var button_count := 0
	for button in [_reading_button, _pause_button, _skip_button]:
		if button.visible:
			toolbar_width += button.get_combined_minimum_size().x
			button_count += 1
	toolbar_width += 8.0 * maxi(0, button_count - 1)
	var wide := width >= toolbar_width + 360 and extent.y >= 400
	_metadata.position = Vector2(margin, margin)
	_metadata.size.x = width - toolbar_width - 24 if wide else width
	_metadata.size.y = _metadata.get_combined_minimum_size().y
	_toolbar.size.x = toolbar_width if wide else width
	_toolbar.position = Vector2(extent.x - margin - toolbar_width, margin) if wide else Vector2(margin, _metadata.position.y + _metadata.size.y + 12)
	_toolbar.size.y = _toolbar.get_combined_minimum_size().y
	var header_end := maxf(_metadata.position.y + _metadata.size.y, _toolbar.position.y + _toolbar.size.y)
	var panel_width := minf(960.0, width)
	_panel.size.x = panel_width
	_content.custom_minimum_size.x = maxf(120.0, panel_width - 60)
	var available_height := maxf(132.0, extent.y - header_end - margin - 20)
	var content_height := _content.get_combined_minimum_size().y
	var reserved := 33.0 + _speaker.get_combined_minimum_size().y + maxf(48, 46 * _ui_scale) + 3.0 + 36.0
	_scroll.custom_minimum_size.y = minf(content_height, maxf(45.0, available_height - reserved))
	_panel.size.y = _panel.get_combined_minimum_size().y
	_panel.position = Vector2((extent.x - panel_width) * 0.5, extent.y - margin - _panel.size.y)
	# The focusable reading area permits keyboard/controller scrolling when needed.
	_scroll.focus_mode = Control.FOCUS_ALL if content_height > _scroll.custom_minimum_size.y + 1 else Control.FOCUS_NONE


func _label(value: String, pixels: int, color: Color, serif := false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("opening_font_size", pixels)
	label.add_theme_font_size_override("font_size", roundi(pixels * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 3)
	if serif:
		label.add_theme_font_override("font", _serif)
	return label


func _button(caption: String, node_name: String, callback: Callable, primary := false) -> Button:
	var button: Button = TouchAction.new()
	button.name = node_name
	button.text = caption
	button.set_meta("opening_font_size", 14)
	button.add_theme_font_size_override("font_size", roundi(14 * _ui_scale))
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.custom_minimum_size.y = maxf(48, 46 * _ui_scale)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(WINE, 0.94) if primary else Color(0.05, 0.055, 0.06, 0.74)
		style.border_color = Color(BRONZE, 0.9 if state in ["hover", "focus"] else 0.4)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(3)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	return button


func _reset_touch() -> void:
	for button in [_reading_button, _pause_button, _skip_button, _advance_button]:
		if is_instance_valid(button):
			button.reset()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_reset_touch()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_queue_layout()


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
