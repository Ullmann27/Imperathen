extends RefCounted
## Roman presentation kit for the title screens: Cinzel lettering (SIL OFL 1.1),
## tabula-ansata buttons, meander bands and laurel sprays. Everything is drawn as
## vectors so it stays sharp from small phones to 4K monitors.

const FONT_PATH := "res://assets/ui/fonts/Cinzel-Variable.ttf"
const AQUILA_PATH := "res://assets/ui/aquila.svg"
const GLADIUS_PATH := "res://assets/ui/gladius.svg"
const MUSIC_PATH := "res://assets/ui/menu_theme.ogg"

const GOLD := Color("e8c77e")
const GOLD_LIGHT := Color("fff0c2")
const GOLD_DEEP := Color("9c7339")
const PARCHMENT := Color("efe4cc")
const CRIMSON_TOP := Color("8f2c31")
const CRIMSON_BOTTOM := Color("45110f")
const BRONZE_TOP := Color("3d3022")
const BRONZE_BOTTOM := Color("1b1510")
const STONE_TOP := Color("3a3934")
const STONE_BOTTOM := Color("262521")
const SHADOW := Color(0.04, 0.02, 0.01, 0.85)

static var _fonts: Dictionary = {}


static func font(weight := 600, spacing := 0) -> Font:
	var key := "%d:%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var variation := FontVariation.new()
	var base: Font = load(FONT_PATH)
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = spacing
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["DejaVu Serif", "Noto Serif", "Liberation Serif"])
	variation.fallbacks = [fallback]
	_fonts[key] = variation
	return variation


## Headless checks have no audio device and the dummy driver would keep playback
## queued. Movie Maker mode also uses the dummy driver but records its mix.
static func audio_available() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return AudioServer.get_driver_name() != "Dummy" or OS.has_feature("movie")


static func button_styles(primary: bool) -> Dictionary:
	return {
		"normal": TabulaBox.make("primary" if primary else "secondary"),
		"hover": TabulaBox.make("primary_hover" if primary else "secondary_hover"),
		"pressed": TabulaBox.make("pressed"),
		"disabled": TabulaBox.make("disabled"),
		"focus": TabulaBox.make("focus"),
	}


static func style_button(button: Button, primary: bool, font_size: int) -> void:
	for state: String in button_styles(primary).keys():
		button.add_theme_stylebox_override(state, button_styles(primary)[state])
	button.add_theme_font_override("font", font(700 if primary else 600, 1))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", GOLD_LIGHT if primary else PARCHMENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD_LIGHT if primary else PARCHMENT)
	button.add_theme_color_override("font_disabled_color", Color("8a867b"))
	button.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 0.9))
	button.add_theme_constant_override("outline_size", 3)


static func style_title(label: Label, font_size: int) -> void:
	label.add_theme_font_override("font", font(800, 4))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color("2a1607"))
	label.add_theme_constant_override("outline_size", maxi(3, font_size / 14))
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", maxi(2, font_size / 18))
	label.add_theme_constant_override("shadow_outline_size", maxi(4, font_size / 9))


static func style_caps(label: Label, font_size: int, color := GOLD, spacing := 3) -> void:
	label.add_theme_font_override("font", font(600, spacing))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.85))
	label.add_theme_constant_override("outline_size", 2)


## Tabula ansata: the Roman inscription plaque with dovetail handles and nail holes.
class TabulaBox extends StyleBox:
	var top := BRONZE_TOP
	var bottom := BRONZE_BOTTOM
	var border := Color("9c7a45")
	var engraving := Color(0.95, 0.78, 0.45, 0.32)
	var glow := Color(0, 0, 0, 0)
	var outline_only := false
	var inset := 0.0

	static func make(kind: String) -> TabulaBox:
		var box := TabulaBox.new()
		match kind:
			"primary":
				box.top = CRIMSON_TOP
				box.bottom = CRIMSON_BOTTOM
				box.border = Color("d8b06a")
				box.engraving = Color(1.0, 0.86, 0.55, 0.45)
			"primary_hover":
				box.top = Color("a8383c")
				box.bottom = Color("561716")
				box.border = Color("f6d68e")
				box.engraving = Color(1.0, 0.9, 0.62, 0.6)
				box.glow = Color(1.0, 0.8, 0.4, 0.28)
			"secondary_hover":
				box.top = Color("54412c")
				box.bottom = Color("261d14")
				box.border = Color("e2bd78")
				box.engraving = Color(1.0, 0.86, 0.55, 0.48)
				box.glow = Color(1.0, 0.8, 0.4, 0.2)
			"pressed":
				box.top = Color("1c140e")
				box.bottom = Color("4a2a1a")
				box.border = Color("c99c55")
				box.inset = 1.0
			"disabled":
				box.top = STONE_TOP
				box.bottom = STONE_BOTTOM
				box.border = Color("5f5c53")
				box.engraving = Color(0.8, 0.78, 0.7, 0.14)
			"focus":
				box.outline_only = true
				box.border = GOLD_LIGHT
		box.content_margin_left = 30
		box.content_margin_right = 30
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		return box

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		var shape := silhouette(rect)
		if outline_only:
			var focus_ring := silhouette(rect.grow(3.0))
			focus_ring.append(focus_ring[0])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, focus_ring, [border], 2.0, true)
			return
		if glow.a > 0.0:
			for step in range(3):
				var halo := silhouette(rect.grow(2.0 + step * 2.0))
				halo.append(halo[0])
				RenderingServer.canvas_item_add_polyline(to_canvas_item, halo, [Color(glow, glow.a * (1.0 - step / 3.0))], 2.0, true)
		var colors := PackedColorArray()
		for point in shape:
			var t := clampf((point.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)
			colors.append(top.lerp(bottom, t))
		var triangles := Geometry2D.triangulate_polygon(shape)
		if not triangles.is_empty():
			RenderingServer.canvas_item_add_triangle_array(to_canvas_item, triangles, shape, colors)
		# Upper sheen: polished bronze catches light along the top third.
		var body := _body(rect)
		var sheen := Rect2(body.position + Vector2(2, 2), Vector2(body.size.x - 4, body.size.y * 0.38))
		RenderingServer.canvas_item_add_rect(to_canvas_item, sheen, Color(1, 0.92, 0.75, 0.07))
		var outline := shape.duplicate()
		outline.append(outline[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, outline, [border], 2.0, true)
		# Engraved inner frame (light edge below a dark cut).
		var frame := body.grow(-4.0 - inset)
		if frame.size.x > 8 and frame.size.y > 8:
			var cut := PackedVector2Array([frame.position, Vector2(frame.end.x, frame.position.y), frame.end,
				Vector2(frame.position.x, frame.end.y), frame.position])
			RenderingServer.canvas_item_add_polyline(to_canvas_item, cut, [Color(0, 0, 0, 0.45)], 1.0, true)
			var light := PackedVector2Array()
			for point in cut:
				light.append(point + Vector2(0.0, 1.0))
			RenderingServer.canvas_item_add_polyline(to_canvas_item, light, [engraving], 1.0, true)
		# Nail holes in the ansae, as on real bronze tablets.
		var ansa := _ansa(rect)
		var radius := clampf(rect.size.y * 0.055, 1.6, 3.2)
		for x in [rect.position.x + ansa * 0.42, rect.end.x - ansa * 0.42]:
			var center := Vector2(x, rect.position.y + rect.size.y * 0.5)
			RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius + 0.8, Color(border, 0.9))
			RenderingServer.canvas_item_add_circle(to_canvas_item, center, radius, Color(0.05, 0.03, 0.02))

	func _ansa(rect: Rect2) -> float:
		return clampf(rect.size.y * 0.42, 10.0, 24.0)

	func _body(rect: Rect2) -> Rect2:
		var ansa := _ansa(rect)
		return Rect2(rect.position + Vector2(ansa, 0), Vector2(maxf(0.0, rect.size.x - ansa * 2.0), rect.size.y))

	func silhouette(rect: Rect2) -> PackedVector2Array:
		var a := _ansa(rect)
		var x0 := rect.position.x
		var x1 := rect.end.x
		var y0 := rect.position.y
		var y1 := rect.end.y
		var h := rect.size.y
		var mid := y0 + h * 0.5
		var neck := h * 0.14
		var flare := h * 0.1
		return PackedVector2Array([
			Vector2(x0 + a, y0), Vector2(x1 - a, y0), Vector2(x1 - a, mid - neck),
			Vector2(x1, y0 + flare), Vector2(x1, y1 - flare), Vector2(x1 - a, mid + neck),
			Vector2(x1 - a, y1), Vector2(x0 + a, y1), Vector2(x0 + a, mid + neck),
			Vector2(x0, y1 - flare), Vector2(x0, y0 + flare), Vector2(x0 + a, mid - neck),
		])


## Running Greek-key band (meander), common on Roman mosaics and friezes.
class MeanderBand extends Control:
	var color := Color(GOLD_DEEP, 0.85)
	var accent := Color(GOLD, 0.45)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var h := size.y
		if h < 4 or size.x < h:
			return
		var unit := h
		var line := maxf(1.0, h / 7.0)
		draw_line(Vector2(0, line * 0.5), Vector2(size.x, line * 0.5), accent, line * 0.6, true)
		draw_line(Vector2(0, h - line * 0.5), Vector2(size.x, h - line * 0.5), accent, line * 0.6, true)
		var count := floori(size.x / unit)
		var offset := (size.x - count * unit) * 0.5
		for index in range(count):
			var x := offset + index * unit
			var s := unit
			var points := PackedVector2Array([
				Vector2(x + s * 0.15, h * 0.82), Vector2(x + s * 0.15, h * 0.22), Vector2(x + s * 0.82, h * 0.22),
				Vector2(x + s * 0.82, h * 0.66), Vector2(x + s * 0.40, h * 0.66), Vector2(x + s * 0.40, h * 0.42),
				Vector2(x + s * 0.60, h * 0.42),
			])
			draw_polyline(points, color, line, true)
			draw_line(Vector2(x + s * 0.15, h * 0.82), Vector2(x + s * 1.15, h * 0.82), color, line, true)


## Laurel spray: paired leaves along a curved stem (a victor's wreath half).
class LaurelSpray extends Control:
	var mirrored := false
	var color := Color(GOLD, 0.92)
	var vein := Color("5c3d14")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 8 or h < 8:
			return
		# Stem arcs from the lower inner corner up and outwards, like half a wreath.
		var stem := PackedVector2Array()
		for index in range(21):
			var t := index / 20.0
			var angle := lerpf(PI * 0.62, PI * 1.32, t)
			stem.append(_m(Vector2(w * 1.02 + cos(angle) * w * 0.92, h * 0.98 + sin(angle) * h * 0.82)))
		draw_polyline(stem, color.darkened(0.3), maxf(1.2, h / 48.0), true)
		var pairs := 7
		for index in range(pairs):
			var t := 0.1 + 0.86 * index / float(pairs - 1)
			var at := int(t * 19)
			var a := stem[at]
			var direction := (stem[at + 1] - a).normalized()
			var normal := Vector2(-direction.y, direction.x)
			var length := h * (0.3 - 0.11 * t)
			for side in [-1.0, 1.0]:
				var axis: Vector2 = (direction * 0.8 + normal * side * 0.62).normalized()
				_leaf(a, axis, length, length * 0.42)
		var tip := stem[20]
		_leaf(tip, (stem[20] - stem[19]).normalized(), h * 0.2, h * 0.08)

	func _leaf(base: Vector2, axis: Vector2, length: float, width: float) -> void:
		var normal := Vector2(-axis.y, axis.x)
		var points := PackedVector2Array()
		for index in range(9):
			var t := index / 8.0
			points.append(base + axis * length * t + normal * sin(t * PI) * width * 0.5)
		for index in range(7, 0, -1):
			var t := index / 8.0
			points.append(base + axis * length * t - normal * sin(t * PI) * width * 0.5)
		draw_colored_polygon(points, color)
		draw_line(base, base + axis * length * 0.85, vein, maxf(1.0, width / 6.0), true)

	func _m(point: Vector2) -> Vector2:
		return Vector2(size.x - point.x, point.y) if mirrored else point
