extends RefCounted
## Roman HUD design system ("Tabula & Velum"): tokens, density-independent
## scale, type, motion and the procedural materials every in-game component
## shares. All shapes are original vector drawing; the only shipped font is
## Cinzel (SIL OFL 1.1, licence beside the file in assets/ui/fonts). Body text
## uses the platform serif, so no further font file is redistributed.
##
## Layout in the HUD is written in dp. One dp is one logical unit on desktop
## and in the headless tests; on Android it follows the display density, so
## 48 dp is the same physical finger size on the Fold7 inner and cover screen.

const RomanStyle = preload("res://scripts/ui/roman_style.gd")

# --- Palette: gilded bronze on ink, parchment text, cinnabar and verdigris.
const AURUM := Color("e3c27a")
const AURUM_LIGHT := Color("fff0c8")
const BRONZE := Color("a8824e")
const BRONZE_DEEP := Color("5e4526")
const ATRAMENTUM := Color(0.047, 0.036, 0.027)
const CHARTA := Color("efe4cc")
const CHARTA_MUTED := Color("c8bda5")
const CHARTA_FAINT := Color(0.94, 0.89, 0.8, 0.55)
const MINIUM := Color("c0493a")
const AERUGO := Color("86bdaa")
const STONE := Color("8a867b")

# --- Metrics (dp).
const TOUCH_MIN := 48.0
const TOUCH_COMFORT := 56.0
const GUTTER := 16.0
const GAP := 8.0

# --- Type scale (dp).
const TYPE_MICRO := 10
const TYPE_CAPTION := 12
const TYPE_BODY := 15
const TYPE_LEAD := 17
const TYPE_TITLE := 20
const TYPE_DISPLAY := 30

# --- Motion (s). Reduced motion keeps only short opacity changes.
const MOTION_FAST := 0.14
const MOTION_BASE := 0.22
const MOTION_SLOW := 0.42

const ROMAN_NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

static var _body_font: Font
static var _display_cache: Dictionary = {}


## Logical units per dp. Desktop and the headless tests use one unit per dp.
## On a phone the canvas is stretched from the 1280 x 720 design size, so a
## unit covers a different number of physical pixels on every display.
static func units_per_dp(viewport: Viewport) -> float:
	if viewport == null or not OS.has_feature("mobile"):
		return 1.0
	var dpi := float(DisplayServer.screen_get_dpi())
	var pixels_per_unit := absf(viewport.get_screen_transform().get_scale().x)
	if dpi <= 0.0 or pixels_per_unit <= 0.0:
		return 1.0
	return clampf((dpi / 160.0) / pixels_per_unit, 0.8, 3.5)


static func numeral(index: int) -> String:
	return ROMAN_NUMERALS[index] if index >= 0 and index < ROMAN_NUMERALS.size() else str(index + 1)


static func display_font(weight := 600, spacing := 1) -> Font:
	var key := "%d:%d" % [weight, spacing]
	if not _display_cache.has(key):
		_display_cache[key] = RomanStyle.font(weight, spacing)
	return _display_cache[key]


static func body_font() -> Font:
	if _body_font == null:
		var serif := SystemFont.new()
		serif.font_names = PackedStringArray(["Noto Serif", "DejaVu Serif", "Liberation Serif", "Droid Serif", "serif"])
		serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_body_font = serif
	return _body_font


## Label in the HUD type system. Sizes are dp; the parent carries the scale.
static func label(text: String, size := TYPE_BODY, color := CHARTA, display := false, spacing := 1) -> Label:
	var item := Label.new()
	item.text = text
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_override("font", display_font(600, spacing) if display else body_font())
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 1)
	item.add_theme_constant_override("shadow_outline_size", 3 if display else 2)
	return item


static func kicker(text: String, size := TYPE_MICRO, color := AURUM) -> Label:
	var item := label(text, size, color, true, 3)
	item.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.8))
	item.add_theme_constant_override("outline_size", 2)
	return item


## Fade (and optionally slide) a control; reduced motion only fades briefly.
static func reveal(control: CanvasItem, reduce_motion: bool, delay := 0.0, slide := Vector2(0, 8)) -> Tween:
	if not is_instance_valid(control):
		return null
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var wait := 0.0 if reduce_motion else delay
	# Containers re-sort their children, so only free-standing controls slide.
	var free_standing: bool = control is Control and not (control.get_parent() is Container)
	if free_standing and not reduce_motion and slide != Vector2.ZERO:
		var home: Vector2 = (control as Control).position
		(control as Control).position = home + slide
		tween.tween_property(control, "position", home, MOTION_SLOW).set_delay(wait)
	tween.tween_property(control, "modulate:a", 1.0, MOTION_FAST if reduce_motion else MOTION_BASE).set_delay(wait)
	return tween


# --- Procedural materials -------------------------------------------------

## Translucent ink "velum": a gradient scrim that keeps the world readable
## behind text without the hard rectangle of a technical panel.
class VelumBox extends StyleBox:
	## 0 = fades to the right, 1 = to the left, 2 = to both sides, 3 = vertical (down).
	var direction := 0
	var strength := 0.62
	var rule := true
	var rule_color := Color(0.89, 0.76, 0.48, 0.75)
	var corner := 0.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var ink := Color(0.047, 0.036, 0.027, strength)
		var clear := Color(0.047, 0.036, 0.027, 0.0)
		var ci := to_canvas_item
		match direction:
			0:
				var split := rect.position.x + rect.size.x * 0.62
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([rect.position, Vector2(split, rect.position.y), Vector2(split, rect.end.y), Vector2(rect.position.x, rect.end.y)]), PackedColorArray([ink, ink, ink, ink]))
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(split, rect.position.y), Vector2(rect.end.x, rect.position.y), rect.end, Vector2(split, rect.end.y)]), PackedColorArray([ink, clear, clear, ink]))
			1:
				var split := rect.position.x + rect.size.x * 0.38
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([rect.position, Vector2(split, rect.position.y), Vector2(split, rect.end.y), Vector2(rect.position.x, rect.end.y)]), PackedColorArray([clear, ink, ink, clear]))
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(split, rect.position.y), Vector2(rect.end.x, rect.position.y), rect.end, Vector2(split, rect.end.y)]), PackedColorArray([ink, ink, ink, ink]))
			2:
				var a := rect.position.x + rect.size.x * 0.22
				var b := rect.position.x + rect.size.x * 0.78
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([rect.position, Vector2(a, rect.position.y), Vector2(a, rect.end.y), Vector2(rect.position.x, rect.end.y)]), PackedColorArray([clear, ink, ink, clear]))
				RenderingServer.canvas_item_add_rect(ci, Rect2(a, rect.position.y, b - a, rect.size.y), ink)
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([Vector2(b, rect.position.y), Vector2(rect.end.x, rect.position.y), rect.end, Vector2(b, rect.end.y)]), PackedColorArray([ink, clear, clear, ink]))
			_:
				RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([clear, clear, ink, ink]))
		if rule and direction in [0, 1]:
			# A gilded inscription rule with a diamond terminal on the open edge.
			var x := rect.position.x + 1.0 if direction == 0 else rect.end.x - 1.0
			RenderingServer.canvas_item_add_line(ci, Vector2(x, rect.position.y + 6.0), Vector2(x, rect.end.y - 2.0), rule_color, 1.5, true)
			var tip := Vector2(x, rect.position.y + 3.0)
			RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([tip + Vector2(0, -3.5), tip + Vector2(3.0, 0), tip + Vector2(0, 3.5), tip + Vector2(-3.0, 0)]), PackedColorArray([rule_color, rule_color, rule_color, rule_color]))


## Framed bronze tablet for menus: dark stone, thin gilded hairline, corner
## studs. Lighter than the title-screen TabletBox so it suits the game view.
class PlaqueBox extends StyleBox:
	var fill := Color(0.06, 0.047, 0.036, 0.9)
	var fill_bottom := Color(0.035, 0.027, 0.02, 0.94)
	var frame := Color(0.66, 0.51, 0.3, 0.95)
	var hairline := Color(0.89, 0.76, 0.48, 0.42)
	var studs := true
	var shadow := true
	var accent_top := false

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var ci := to_canvas_item
		if shadow:
			for step in range(4):
				var grow := 3.0 + step * 4.0
				RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position + Vector2(-grow * 0.5, grow * 0.35), rect.size + Vector2(grow, grow)), Color(0, 0, 0, 0.07))
		RenderingServer.canvas_item_add_polygon(ci, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([fill, fill, fill_bottom, fill_bottom]))
		var outline := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
		RenderingServer.canvas_item_add_polyline(ci, outline, [frame], 1.5, true)
		var inner := rect.grow(-4.0)
		if inner.size.x > 8.0 and inner.size.y > 8.0:
			var line := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y), inner.position])
			RenderingServer.canvas_item_add_polyline(ci, line, [hairline], 1.0, true)
		if accent_top:
			RenderingServer.canvas_item_add_rect(ci, Rect2(rect.position + Vector2(10, 0), Vector2(rect.size.x - 20, 2)), Color(0.89, 0.76, 0.48, 0.9))
		if studs:
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				RenderingServer.canvas_item_add_circle(ci, corner, 3.2, Color(0.18, 0.11, 0.05))
				RenderingServer.canvas_item_add_circle(ci, corner, 2.3, frame)


static func plaque(accent := false, margin := Vector4(18, 14, 18, 14), opacity := 0.9) -> PlaqueBox:
	var box := PlaqueBox.new()
	box.accent_top = accent
	box.fill.a = opacity
	box.fill_bottom.a = minf(1.0, opacity + 0.04)
	box.content_margin_left = margin.x
	box.content_margin_top = margin.y
	box.content_margin_right = margin.z
	box.content_margin_bottom = margin.w
	return box


static func velum(direction := 0, margin := Vector4(14, 8, 26, 8), strength := 0.62, rule := true) -> VelumBox:
	var box := VelumBox.new()
	box.direction = direction
	box.strength = strength
	box.rule = rule
	box.content_margin_left = margin.x
	box.content_margin_top = margin.y
	box.content_margin_right = margin.z
	box.content_margin_bottom = margin.w
	return box


## A small tabula-styled plaque for compact HUD and menu commands.
static func style_plaque_button(button: Button, primary := false, size := TYPE_CAPTION, active := false) -> void:
	var states := {"normal": _plaque_state(primary, active, false), "hover": _plaque_state(primary, active, true),
		"pressed": _plaque_state(true, true, true), "disabled": _plaque_disabled(), "focus": _plaque_focus()}
	for key: String in states:
		button.add_theme_stylebox_override(key, states[key])
	button.add_theme_font_override("font", display_font(700 if primary or active else 600, 1))
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", AURUM_LIGHT if primary or active else CHARTA)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", AURUM)
	button.add_theme_color_override("font_focus_color", AURUM_LIGHT if primary or active else CHARTA)
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.58, 0.52, 0.8))
	button.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.85))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("icon_normal_color", CHARTA)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", AURUM)
	button.add_theme_constant_override("h_separation", 6)


static func _plaque_state(primary: bool, active: bool, hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	if primary:
		box.bg_color = Color("7a2a2c") if not hover else Color("923437")
	elif active:
		box.bg_color = Color(0.25, 0.19, 0.12, 0.92) if not hover else Color(0.32, 0.24, 0.15, 0.95)
	else:
		box.bg_color = Color(0.07, 0.055, 0.04, 0.78) if not hover else Color(0.16, 0.12, 0.08, 0.88)
	box.border_color = AURUM if (active or hover) else Color(0.62, 0.48, 0.28, 0.85) if primary else Color(0.52, 0.41, 0.25, 0.75)
	box.set_border_width_all(1)
	box.border_width_bottom = 2 if active else 1
	box.set_corner_radius_all(2)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.anti_aliasing = true
	return box


static func _plaque_disabled() -> StyleBoxFlat:
	var box := _plaque_state(false, false, false)
	box.bg_color = Color(0.1, 0.1, 0.09, 0.62)
	box.border_color = Color(0.4, 0.39, 0.35, 0.6)
	return box


static func _plaque_focus() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = AURUM_LIGHT
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.expand_margin_left = 2
	box.expand_margin_right = 2
	box.expand_margin_top = 2
	box.expand_margin_bottom = 2
	return box


# --- Drawing helpers for custom controls ----------------------------------

static func draw_diamond(item: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	item.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.8, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.8, 0)]), color)


## Bronze coin with a beaded rim (a Roman medallion), used by touch actions.
static func draw_medallion(item: CanvasItem, center: Vector2, radius: float, lit: float, primary := false, pressed := false, disabled := false) -> void:
	var rim := Color(0.74, 0.57, 0.33).lerp(Color(0.93, 0.8, 0.52), lit)
	var face_top := Color(0.12, 0.085, 0.06, 0.82)
	var face_bottom := Color(0.05, 0.035, 0.025, 0.88)
	if primary:
		face_top = Color(0.36, 0.11, 0.1, 0.86)
		face_bottom = Color(0.17, 0.05, 0.04, 0.9)
	if pressed:
		face_top = face_top.lightened(0.18)
	if disabled:
		rim = Color(0.45, 0.44, 0.4, 0.7)
		face_top = Color(0.1, 0.1, 0.09, 0.6)
		face_bottom = Color(0.06, 0.06, 0.055, 0.64)
	item.draw_circle(center + Vector2(0, radius * 0.06), radius + 2.0, Color(0, 0, 0, 0.32))
	# Vertical face gradient from stacked discs (cheap and smooth at HUD sizes).
	var steps := 6
	for index in range(steps):
		var t := float(index) / float(steps - 1)
		item.draw_circle(center + Vector2(0, (t - 0.5) * radius * 0.18), radius * (1.0 - t * 0.06), face_top.lerp(face_bottom, t))
	item.draw_arc(center, radius, 0, TAU, 72, rim, maxf(1.6, radius * 0.07), true)
	item.draw_arc(center, radius * 0.84, 0, TAU, 64, Color(rim, 0.45), 1.0, true)
	# Beaded rim: small pearls like the edge of a struck coin.
	var beads := clampi(int(radius * 0.9), 18, 44)
	for index in range(beads):
		var angle := TAU * float(index) / float(beads)
		item.draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.92, maxf(0.7, radius * 0.028), Color(rim, 0.7))
	# Upper sheen.
	item.draw_arc(center, radius * 0.74, PI * 1.12, PI * 1.88, 24, Color(1, 0.94, 0.78, 0.16 + lit * 0.12), maxf(1.0, radius * 0.08), true)
