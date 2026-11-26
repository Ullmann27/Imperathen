extends RefCounted
## Cinematic conversation layout: film bars, the world (and the focused
## speaker) in the middle of the frame, a nameplate and the spoken line in
## the lower third, answers as numbered plaques. One builder serves the story
## decisions and the village/frontier conversations. Node names, scroll
## behaviour and button captions stay those the game and its tests use.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Kit = preload("res://scripts/ui/roman_hud/menu_kit.gd")


## spec keys: name, scroll_name, kicker, speaker, role, text, feedback, note,
## portrait (Texture2D), portrait_name, choices [{caption, callback, enabled,
## reason, name, meta}], close {caption, callback, name}, area (dp Vector2),
## reduce_motion, pause_note.
static func build(screen: Control, spec: Dictionary) -> Dictionary:
	var area: Vector2 = spec.get("area", screen.size)
	var reduce_motion := bool(spec.get("reduce_motion", false))
	var letterbox := Kit.Letterbox.new()
	letterbox.name = "DialogueLetterbox"
	letterbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letterbox.bar = 0.06 if area.y < 560 else 0.085
	screen.add_child(letterbox)
	letterbox.animate(reduce_motion)
	var wide := area.x >= 860.0 and area.x >= area.y * 1.2
	var portrait_layout := area.y > area.x * 1.15
	var margin := clampf(area.x * 0.04, 12.0, 48.0)
	var panel := PanelContainer.new()
	panel.name = str(spec.get("name", "DialogueStage"))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := Style.velum(3, Vector4(margin, 26, margin, 14), 0.9, false)
	panel.add_theme_stylebox_override("panel", shade)
	screen.add_child(panel)
	var max_height := area.y * (0.56 if portrait_layout else 0.5 if wide else 0.62)
	var bottom_bar := area.y * letterbox.bar
	panel.position = Vector2(0, area.y - max_height - bottom_bar * 0.25)
	panel.size = Vector2(area.x, max_height)
	var scroll := ScrollContainer.new()
	scroll.name = str(spec.get("scroll_name", "DialogueScroll"))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var body: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	body.add_theme_constant_override("separation", 36 if wide else 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body)
	# Left: nameplate and spoken text.
	var speech := VBoxContainer.new()
	speech.mouse_filter = Control.MOUSE_FILTER_PASS
	speech.add_theme_constant_override("separation", 8)
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.size_flags_stretch_ratio = 1.15
	body.add_child(speech)
	var plate := HBoxContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_constant_override("separation", 14)
	speech.add_child(plate)
	var portrait: Texture2D = spec.get("portrait")
	if portrait != null:
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", Style.plaque(false, Vector4(3, 3, 3, 3), 0.85))
		plate.add_child(frame)
		var image := TextureRect.new()
		image.name = str(spec.get("portrait_name", "Speaker"))
		image.texture = portrait
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(72, 92) if area.y < 600 else Vector2(88, 112)
		frame.add_child(image)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_END
	plate.add_child(names)
	var kicker := str(spec.get("kicker", ""))
	if not kicker.is_empty():
		names.add_child(Style.kicker(kicker.to_upper(), Style.TYPE_MICRO))
	var speaker := Style.label(str(spec.get("speaker", "")), 26 if area.y >= 600 else 21, Style.AURUM_LIGHT, true, 2)
	speaker.name = "DialogueSpeaker"
	speaker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(speaker)
	var role := str(spec.get("role", ""))
	if not role.is_empty():
		names.add_child(Style.label(role, Style.TYPE_CAPTION + 1, Style.CHARTA_MUTED, true, 1))
	var rule := ColorRect.new()
	rule.color = Color(Style.AURUM, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech.add_child(rule)
	var line := Style.label(str(spec.get("text", "")), 19 if area.y >= 600 else 17, Style.CHARTA)
	line.name = "DialogueLine"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_constant_override("line_spacing", 3)
	speech.add_child(line)
	var feedback_text := str(spec.get("feedback", ""))
	if not feedback_text.is_empty():
		var feedback := Style.label(feedback_text, Style.TYPE_BODY, Style.AERUGO.lightened(0.15))
		feedback.name = "ConversationFeedback"
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		speech.add_child(feedback)
	var note := str(spec.get("note", ""))
	if not note.is_empty():
		var note_label := Style.label(note, Style.TYPE_CAPTION, Style.CHARTA_FAINT)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		speech.add_child(note_label)
	# Right (or below): answers as numbered plaques, then the explicit exit.
	var answers := VBoxContainer.new()
	answers.name = "DialogueChoices"
	answers.mouse_filter = Control.MOUSE_FILTER_PASS
	answers.add_theme_constant_override("separation", 6)
	answers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers.alignment = BoxContainer.ALIGNMENT_END if wide else BoxContainer.ALIGNMENT_BEGIN
	body.add_child(answers)
	var first: Button
	var choices: Array = spec.get("choices", [])
	var index := 0
	for entry: Dictionary in choices:
		var enabled := bool(entry.get("enabled", true))
		var button := Kit.choice(str(entry.get("caption", "")), index, first == null and enabled)
		if not str(entry.get("name", "")).is_empty():
			button.name = str(entry.name)
		for key: String in entry.get("meta", {}):
			button.set_meta(key, entry.meta[key])
		button.disabled = not enabled
		button.tooltip_text = str(entry.get("reason", ""))
		var callback: Callable = entry.get("callback", Callable())
		if callback.is_valid():
			button.pressed.connect(callback)
		answers.add_child(button)
		if not enabled and not str(entry.get("reason", "")).is_empty():
			var reason := Style.label(str(entry.reason), Style.TYPE_CAPTION, Style.CHARTA_MUTED)
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			reason.add_theme_constant_override("line_spacing", 1)
			var indent := MarginContainer.new()
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indent.add_theme_constant_override("margin_left", 52)
			indent.add_child(reason)
			answers.add_child(indent)
		if first == null and enabled:
			first = button
		index += 1
	var close: Dictionary = spec.get("close", {})
	var close_button: Button
	if not close.is_empty():
		close_button = Button.new()
		close_button.text = str(close.get("caption", "Zurück"))
		close_button.name = str(close.get("name", "DialogueClose"))
		Style.style_plaque_button(close_button, false, Style.TYPE_CAPTION + 1)
		close_button.custom_minimum_size = Vector2(0, Style.TOUCH_MIN)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END if wide else Control.SIZE_FILL
		var close_callback: Callable = close.get("callback", Callable())
		if close_callback.is_valid():
			close_button.pressed.connect(close_callback)
		answers.add_child(close_button)
	# The panel hugs its content up to the lower-third limit; longer text scrolls.
	var fit := func():
		if not is_instance_valid(panel) or not is_instance_valid(body):
			return
		var needed := body.get_combined_minimum_size().y + shade.content_margin_top + shade.content_margin_bottom
		var height := clampf(needed, minf(160.0, max_height), max_height)
		panel.size = Vector2(area.x, height)
		panel.position = Vector2(0, area.y - height - bottom_bar * 0.25)
	body.minimum_size_changed.connect(fit)
	fit.call_deferred()
	Style.reveal(panel, reduce_motion, 0.06, Vector2.ZERO)
	var stagger := 0.12
	for child: Node in answers.get_children():
		if child is Control:
			Style.reveal(child as Control, reduce_motion, stagger, Vector2.ZERO)
			stagger += 0.04
	return {"panel": panel, "scroll": scroll, "first": first if first != null else close_button, "close": close_button, "answers": answers}
