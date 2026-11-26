extends RefCounted
## Building blocks for in-game menus, codex and cinematic dialogue: backdrop
## grade, letterbox, Roman-numeral choice plaques, gilded rules, item cards
## and a paper-doll silhouette. Every piece is original procedural drawing.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")
const BackdropShader = preload("res://shaders/roman_backdrop.gdshader")


## Live world behind a menu: graded, darkened and vignetted instead of an
## opaque technical overlay. `amount` animates in.
class Backdrop extends ColorRect:
	var darkness := 0.5
	var desaturate := 0.7

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		color = Color(0.03, 0.022, 0.016, 0.62)
		var material_ := ShaderMaterial.new()
		material_.shader = BackdropShader
		material_.set_shader_parameter("darkness", darkness)
		material_.set_shader_parameter("desaturate", desaturate)
		material_.set_shader_parameter("amount", 0.0)
		material = material_

	func animate(reduce_motion: bool) -> void:
		var target := 1.0
		if reduce_motion:
			(material as ShaderMaterial).set_shader_parameter("amount", target)
			return
		var tween := create_tween()
		tween.tween_method(func(value: float): (material as ShaderMaterial).set_shader_parameter("amount", value), 0.0, target, Style.MOTION_SLOW).set_trans(Tween.TRANS_SINE)


## Film bars for conversations; the middle of the frame stays the world.
class Letterbox extends Control:
	var bar := 0.085
	var amount := 1.0:
		set(value):
			amount = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func animate(reduce_motion: bool) -> void:
		if reduce_motion:
			amount = 1.0
			return
		amount = 0.0
		create_tween().tween_property(self, "amount", 1.0, Style.MOTION_SLOW).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var height := size.y * bar * amount
		if height < 0.5:
			return
		var ink := Color(0.012, 0.009, 0.007, 0.96)
		var soft := Color(0.012, 0.009, 0.007, 0.0)
		draw_rect(Rect2(0, 0, size.x, height), ink)
		draw_polygon(PackedVector2Array([Vector2(0, height), Vector2(size.x, height), Vector2(size.x, height + 26), Vector2(0, height + 26)]), PackedColorArray([ink, ink, soft, soft]))
		draw_rect(Rect2(0, size.y - height, size.x, height), ink)
		draw_polygon(PackedVector2Array([Vector2(0, size.y - height - 40), Vector2(size.x, size.y - height - 40), Vector2(size.x, size.y - height), Vector2(0, size.y - height)]), PackedColorArray([soft, soft, ink, ink]))


## Horizontal gilded rule with a central diamond, as on an inscription.
class Rule extends Control:
	var color := Color(0.89, 0.76, 0.48, 0.7)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size.y = 10
		resized.connect(queue_redraw)

	func _draw() -> void:
		var y := size.y * 0.5
		var center := size.x * 0.5
		draw_line(Vector2(0, y), Vector2(center - 8, y), color, 1.0, true)
		draw_line(Vector2(center + 8, y), Vector2(size.x, y), color, 1.0, true)
		Style.draw_diamond(self, Vector2(center, y), 4.0, color)


## Conversation answer with an engraved Roman numeral; `text` stays the
## exact answer so tests and accessibility read the real wording.
class ChoicePlaque extends Button:
	var numeral := "I"
	var badge := 30.0

	func _ready() -> void:
		resized.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var center := Vector2(10.0 + badge * 0.5, size.y * 0.5)
		var lit := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
		draw_circle(center, badge * 0.5, Color(0.05, 0.035, 0.025, 0.95) if not disabled else Color(0.1, 0.1, 0.09, 0.8))
		draw_arc(center, badge * 0.5, 0, TAU, 48, Style.AURUM if lit > 0.0 else Style.BRONZE if not disabled else Style.STONE, 1.5, true)
		var font := Style.display_font(700, 0)
		var font_size := 13 if numeral.length() < 3 else 11
		var width := font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-width * 0.5, font_size * 0.36), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Style.AURUM_LIGHT if not disabled else Style.STONE)
		if disabled:
			var lock := Icons.texture("lock", 16, 1.6)
			if lock != null:
				draw_texture_rect(lock, Rect2(Vector2(size.x - 26, size.y * 0.5 - 8), Vector2(16, 16)), false, Style.STONE)


static func choice(caption: String, index: int, primary := false) -> ChoicePlaque:
	var button := ChoicePlaque.new()
	button.text = caption
	button.numeral = Style.numeral(index)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = Style.TOUCH_COMFORT
	# Answers sit in a scroll: a swipe that starts on one scrolls and cancels it.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var states := {"normal": _choice_box(primary, false), "hover": _choice_box(primary, true), "pressed": _choice_box(true, true),
		"disabled": _choice_box(false, false, true), "focus": _choice_focus()}
	for key: String in states:
		button.add_theme_stylebox_override(key, states[key])
	button.add_theme_font_override("font", Style.body_font())
	button.add_theme_font_size_override("font_size", Style.TYPE_LEAD)
	button.add_theme_color_override("font_color", Style.CHARTA)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Style.AURUM_LIGHT)
	button.add_theme_color_override("font_pressed_color", Style.AURUM)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.6, 0.55, 0.85))
	return button


static func _choice_box(primary: bool, hover: bool, disabled := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.045, 0.032, 0.72)
	if hover:
		box.bg_color = Color(0.2, 0.14, 0.08, 0.86)
	if primary and not hover:
		box.bg_color = Color(0.13, 0.08, 0.05, 0.8)
	if disabled:
		box.bg_color = Color(0.07, 0.07, 0.065, 0.55)
	box.border_color = Style.AURUM if hover else Color(0.6, 0.46, 0.27, 0.75) if not disabled else Color(0.36, 0.35, 0.32, 0.6)
	box.border_width_left = 0
	box.border_width_right = 0
	box.border_width_top = 0
	box.border_width_bottom = 1
	box.content_margin_left = 52
	box.content_margin_right = 36 if disabled else 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func _choice_focus() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Style.AURUM_LIGHT
	box.set_border_width_all(0)
	box.border_width_left = 3
	return box


## Section heading: small gilded capitals over a fine rule.
static func heading(text: String, size := Style.TYPE_CAPTION) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	column.add_child(Style.kicker(text.to_upper(), size))
	var rule := ColorRect.new()
	rule.color = Color(Style.AURUM, 0.4)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	return column


## Equipment or inventory card: engraved item glyph, name and quantity.
class ItemCard extends PanelContainer:
	var glyph := "item"
	var empty := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		resized.connect(queue_redraw)

	func _draw() -> void:
		var tile := Rect2(Vector2(10, (size.y - 40.0) * 0.5), Vector2(40, 40))
		draw_rect(tile, Color(0.03, 0.022, 0.016, 0.85))
		draw_rect(tile, Color(Style.BRONZE, 0.55 if empty else 0.9), false, 1.0)
		var texture := Icons.texture(glyph, roundi(30 * maxf(1.0, get_global_transform_with_canvas().get_scale().x)), 1.5)
		if texture != null:
			draw_texture_rect(texture, Rect2(tile.position + Vector2(5, 5), Vector2(30, 30)), false, Color(Style.CHARTA, 0.35) if empty else Style.AURUM_LIGHT)


static func item_card(title: String, detail: String, glyph: String, empty := false, quantity := 0) -> ItemCard:
	var card := ItemCard.new()
	card.glyph = glyph
	card.empty = empty
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.054, 0.04, 0.82) if not empty else Color(0.05, 0.045, 0.04, 0.5)
	box.border_color = Color(0.6, 0.46, 0.27, 0.7) if not empty else Color(0.45, 0.4, 0.33, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 62
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size.y = 58
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 1)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	var name_label := Style.label(title + ("  × %d" % quantity if quantity > 1 else ""), Style.TYPE_BODY, Style.CHARTA_MUTED if empty else Style.CHARTA)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	if not detail.is_empty():
		var detail_label := Style.label(detail, Style.TYPE_CAPTION, Style.CHARTA_MUTED)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(detail_label)
	return card


## Line drawing of a figure for the equipment view; slots sit around it.
class PaperDoll extends Control:
	var child := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		var cx := size.x * 0.5
		var scale_ := h / 300.0 * (0.86 if child else 1.0)
		var top := h - 296.0 * scale_ - 2.0
		var line := Color(Style.AURUM, 0.75)
		var shade := Color(0.95, 0.85, 0.65, 0.07)
		var p := func(x: float, y: float) -> Vector2: return Vector2(cx + x * scale_, top + y * scale_)
		# Tunic body (filled very faintly), head, arms and legs.
		var tunic := PackedVector2Array([p.call(-30, 62), p.call(30, 62), p.call(44, 84), p.call(36, 98), p.call(30, 92), p.call(34, 182), p.call(-34, 182), p.call(-30, 92), p.call(-36, 98), p.call(-44, 84)])
		draw_colored_polygon(tunic, shade)
		var outline := tunic.duplicate()
		outline.append(tunic[0])
		draw_polyline(outline, line, 1.5, true)
		draw_circle(p.call(0, 34), 21.0 * scale_, shade)
		draw_arc(p.call(0, 34), 21.0 * scale_, 0, TAU, 48, line, 1.5, true)
		draw_line(p.call(-10, 55), p.call(-8, 62), line, 1.5, true)
		draw_line(p.call(10, 55), p.call(8, 62), line, 1.5, true)
		for side in [-1.0, 1.0]:
			draw_polyline(PackedVector2Array([p.call(40 * side, 92), p.call(46 * side, 140), p.call(42 * side, 172)]), line, 1.5, true)
			draw_polyline(PackedVector2Array([p.call(18 * side, 182), p.call(20 * side, 236), p.call(18 * side, 288), p.call(30 * side, 292)]), line, 1.5, true)
		# Belt line.
		draw_line(p.call(-32, 128), p.call(32, 128), Color(Style.BRONZE, 0.7), 2.0, true)
		# Laurel under the feet.
		var laurel := Icons.texture("laurel", roundi(48 * maxf(1.0, get_global_transform_with_canvas().get_scale().x)), 1.4)
		if laurel != null:
			draw_texture_rect(laurel, Rect2(Vector2(cx - 24, h - 50), Vector2(48, 48)), false, Color(Style.AURUM, 0.25))
