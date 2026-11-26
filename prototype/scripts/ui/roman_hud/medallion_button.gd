extends "res://scripts/ui/touch_action.gd"
## Round bronze touch medallion with an engraved glyph and a short caption.
## Input ownership (multitouch, cancellation, synthetic mouse copies) comes
## unchanged from the shared touch action; only the presentation is new.
## `text` keeps the readable action name for tests, diagnostics and
## accessibility; the medallion draws it itself as the caption.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Icons = preload("res://scripts/ui/roman_hud/hud_icons.gd")

var glyph := "interact"
var radius := 28.0
var primary := false
var show_caption := true
## 0..1: gilded ring when the action is meaningful right now (context).
var lit := 0.0:
	set(value):
		lit = clampf(value, 0.0, 1.0)
		queue_redraw()
var caption_size := 11
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color", "font_outline_color"]:
		add_theme_color_override(color, Color(0, 0, 0, 0))
	clip_text = true
	autowrap_mode = TextServer.AUTOWRAP_OFF
	icon = null
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool): queue_redraw())


## Size of the hit rectangle for a coin radius (dp), caption included.
static func box_size(coin_radius: float, caption := true) -> Vector2:
	return Vector2(coin_radius * 2.0 + 20.0, coin_radius * 2.0 + (34.0 if caption else 4.0))


func configure(kind: String, coin_radius: float, is_primary := false, caption := true) -> void:
	glyph = kind
	radius = coin_radius
	primary = is_primary
	show_caption = caption
	custom_minimum_size = box_size(coin_radius, caption)
	queue_redraw()


func set_action_icon(kind: String) -> void:
	# Same entry point as the plain touch action, rendered as an engraved glyph.
	glyph = {"attack": "attack", "techniques": "techniques"}.get(kind, kind)
	icon = null
	queue_redraw()


func reset() -> void:
	super.reset()
	queue_redraw()


func _process(delta: float) -> void:
	if lit > 0.01 and is_visible_in_tree():
		_pulse = fmod(_pulse + delta * 0.9, 1.0)
		queue_redraw()


func coin_center() -> Vector2:
	return Vector2(size.x * 0.5, radius + 2.0)


func _draw() -> void:
	var center := coin_center()
	var hover := is_hovered() and not disabled
	var held := touch_index != -1 or (button_pressed and toggle_mode)
	var light := maxf(lit, 0.35 if hover else 0.0)
	if lit > 0.01:
		# Context halo: a slow gilded breath so the eye finds the action.
		var breath := 0.5 + 0.5 * sin(_pulse * TAU)
		draw_arc(center, radius + 4.0 + breath * 2.5, 0, TAU, 64, Color(Style.AURUM, 0.18 + 0.32 * lit * (1.0 - breath * 0.5)), 2.0, true)
	Style.draw_medallion(self, center, radius, light, primary, held, disabled)
	var glyph_px := roundi(radius * 1.08 * _pixel_scale())
	var texture := Icons.texture(glyph, glyph_px, 1.7)
	if texture != null:
		var extent := Vector2.ONE * radius * 1.08
		var tint := Style.AURUM_LIGHT if primary or lit > 0.5 else Style.CHARTA
		if disabled:
			tint = Color(0.62, 0.6, 0.55, 0.7)
		draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false, tint)
	if has_focus() and focus_mode != Control.FOCUS_NONE and not held:
		draw_arc(center, radius + 3.0, 0, TAU, 64, Style.AURUM_LIGHT, 1.5, true)
	if show_caption and not text.is_empty():
		_draw_caption(center.y + radius + 4.0)


func _draw_caption(top: float) -> void:
	var font := Style.display_font(700 if primary else 600, 0)
	var lines := text.split("\n", false)
	var width := size.x + 6.0
	var y := top + caption_size
	for index in range(mini(2, lines.size())):
		var line := lines[index]
		var fitted := line
		var measured := font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
		while measured > width and fitted.length() > 3:
			fitted = fitted.substr(0, fitted.length() - 2) + "…"
			measured = font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
		var x := (size.x - measured) * 0.5
		var color := Style.CHARTA if index == 0 else Style.CHARTA_MUTED
		if disabled:
			color = Color(0.62, 0.6, 0.55, 0.75)
		draw_string_outline(font, Vector2(x, y), fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, 3, Color(0.03, 0.02, 0.01, 0.8))
		draw_string(font, Vector2(x, y), fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, color)
		y += caption_size + 2.0


func _pixel_scale() -> float:
	return maxf(1.0, get_global_transform_with_canvas().get_scale().x)
