extends Control
## Compact compass ribbon: the direction the camera faces, the cardinal
## points (N, O, S, W) and the current objective as a gilded marker with its
## distance. It replaces the permanent north map; the map itself (LocalMap)
## opens on demand from a tap on the ribbon and closes again by itself.
## `view` and `update_view` keep the contract of the previous north map.

signal map_requested

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const HALF_FIELD := deg_to_rad(80.0)

var view: Dictionary = {}
var place_name := "Valdora"
## Highlight after a new objective (seconds left), set by the HUD director.
var announce := 0.0
var _shown_heading := 0.0
var _heading_ready := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
	tooltip_text = "Antippen: Ortskarte öffnen"


func update_view(value: Dictionary) -> void:
	if view == value:
		return
	var had_target := bool(view.get("has_target", false))
	var old_target: Variant = view.get("target")
	view = value
	if bool(value.get("has_target", false)) and (not had_target or old_target != value.get("target")):
		announce = 3.0
	queue_redraw()


## Clockwise compass heading in radians (0 = north, -z in the world).
func target_heading() -> float:
	if view.has("camera_yaw"):
		return wrapf(-float(view.camera_yaw), -PI, PI)
	return wrapf(-float(view.get("heading", 0.0)), -PI, PI)


static func bearing(from: Vector2, to: Vector2) -> float:
	var delta := to - from
	return atan2(delta.x, -delta.y)


## Objective direction relative to the facing; positive is to the right.
func relative_bearing() -> float:
	if not bool(view.get("has_target", false)):
		return 0.0
	var player: Vector2 = view.get("player", Vector2.ZERO)
	var target: Vector2 = view.get("target", Vector2.ZERO)
	return wrapf(bearing(player, target) - _shown_heading, -PI, PI)


func _process(delta: float) -> void:
	var wanted := target_heading()
	if not _heading_ready:
		_shown_heading = wanted
		_heading_ready = true
		queue_redraw()
	var next := lerp_angle(_shown_heading, wanted, clampf(delta * 9.0, 0.0, 1.0))
	if absf(angle_difference(next, _shown_heading)) > 0.0005:
		_shown_heading = next
		queue_redraw()
	if announce > 0.0:
		announce = maxf(0.0, announce - delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		map_requested.emit()
		accept_event()


func _x_for(relative: float) -> float:
	return size.x * 0.5 + relative / HALF_FIELD * size.x * 0.46


func _fade(relative: float) -> float:
	var t := absf(relative) / HALF_FIELD
	return clampf(1.0 - t * t, 0.0, 1.0)


func _draw() -> void:
	var band_top := 3.0
	var band := minf(26.0, size.y * 0.6)
	var mid := band_top + band * 0.5
	# Velum behind the ribbon, open at both ends.
	var ink := Color(Style.ATRAMENTUM, 0.58)
	var clear := Color(Style.ATRAMENTUM, 0.0)
	var a := size.x * 0.16
	var b := size.x * 0.84
	draw_polygon(PackedVector2Array([Vector2(0, band_top), Vector2(a, band_top), Vector2(a, band_top + band), Vector2(0, band_top + band)]), PackedColorArray([clear, ink, ink, clear]))
	draw_rect(Rect2(a, band_top, b - a, band), ink)
	draw_polygon(PackedVector2Array([Vector2(b, band_top), Vector2(size.x, band_top), Vector2(size.x, band_top + band), Vector2(b, band_top + band)]), PackedColorArray([ink, clear, clear, ink]))
	# Gilded rules above and below, fading towards the ends.
	for y in [band_top + 0.5, band_top + band - 0.5]:
		var segments := 24
		for index in range(segments):
			var x0 := size.x * float(index) / segments
			var x1 := size.x * float(index + 1) / segments
			var fade := _fade((x0 + x1 - size.x) / size.x * HALF_FIELD * 1.08)
			draw_line(Vector2(x0, y), Vector2(x1, y), Color(Style.AURUM, 0.55 * fade), 1.0, true)
	var font := Style.display_font(700, 1)
	var small := Style.display_font(600, 0)
	# Ticks every 15 degrees, cardinal letters in Cinzel.
	for step in range(0, 360, 15):
		var angle := deg_to_rad(float(step))
		var relative := wrapf(angle - _shown_heading, -PI, PI)
		if absf(relative) > HALF_FIELD:
			continue
		var x := _x_for(relative)
		var fade := _fade(relative)
		if step % 90 == 0:
			var letter: String = {0: "N", 90: "O", 180: "S", 270: "W"}[step]
			var font_size := 15
			var width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var color := Style.AURUM_LIGHT if step == 0 else Style.CHARTA
			draw_string_outline(font, Vector2(x - width * 0.5, mid + 5.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.03, 0.02, 0.01, 0.75 * fade))
			draw_string(font, Vector2(x - width * 0.5, mid + 5.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, fade))
		elif step % 45 == 0:
			var pair: String = {45: "NO", 135: "SO", 225: "SW", 315: "NW"}[step]
			var width := small.get_string_size(pair, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(small, Vector2(x - width * 0.5, mid + 3.5), pair, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Style.CHARTA_MUTED, 0.85 * fade))
		else:
			draw_line(Vector2(x, band_top + 4.0), Vector2(x, band_top + 8.0), Color(Style.BRONZE, 0.8 * fade), 1.0, true)
			draw_line(Vector2(x, band_top + band - 8.0), Vector2(x, band_top + band - 4.0), Color(Style.BRONZE, 0.8 * fade), 1.0, true)
	# Facing index: a small gilded wedge on the upper rule.
	var cx := size.x * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4.5, band_top - 1.0), Vector2(cx + 4.5, band_top - 1.0), Vector2(cx, band_top + 5.0)]), Style.AURUM)
	var caption := place_name
	var caption_x := cx
	var caption_color := Color(Style.CHARTA_MUTED, 0.9)
	if bool(view.get("has_target", false)):
		var relative := relative_bearing()
		var player: Vector2 = view.get("player", Vector2.ZERO)
		var target: Vector2 = view.get("target", Vector2.ZERO)
		var distance := player.distance_to(target)
		var inside := absf(relative) <= HALF_FIELD * 0.94
		var x := _x_for(clampf(relative, -HALF_FIELD * 0.94, HALF_FIELD * 0.94))
		var glow := clampf(announce / 3.0, 0.0, 1.0)
		var near := distance < 4.0
		if glow > 0.0 or near:
			draw_circle(Vector2(x, mid), 11.0 + glow * 4.0, Color(Style.AURUM, 0.16 + glow * 0.2))
		if inside:
			Style.draw_diamond(self, Vector2(x, mid), 7.5, Color(0.08, 0.05, 0.02, 0.9))
			Style.draw_diamond(self, Vector2(x, mid), 6.0, Style.AURUM)
			Style.draw_diamond(self, Vector2(x, mid), 2.4, Color(0.25, 0.12, 0.05))
		else:
			# Objective behind: a chevron on the edge it is closest to.
			var side := signf(relative)
			var tip := Vector2(x + side * 5.0, mid)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-side * 9.0, -7.0), tip + Vector2(-side * 9.0, 7.0)]), Style.AURUM)
		caption = "Hier" if near else "%d m" % roundi(distance)
		caption_x = clampf(x, 24.0, size.x - 24.0)
		caption_color = Style.AURUM_LIGHT
	var caption_size := 11
	var width := small.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	var y := band_top + band + 13.0
	if y <= size.y + 2.0:
		draw_string_outline(small, Vector2(caption_x - width * 0.5, y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, 3, Color(0.03, 0.02, 0.01, 0.85))
		draw_string(small, Vector2(caption_x - width * 0.5, y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, caption_color)


## Round local map ("Ortskarte") of the authored village houses, north up,
## centred on the player. Shown on demand from the compass.
class LocalMap extends Control:
	var view: Dictionary = {}
	var span := 46.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		resized.connect(queue_redraw)

	func update_view(value: Dictionary) -> void:
		if view == value:
			return
		view = value
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			hide()
			accept_event()

	func _to_map(point: Vector2, center: Vector2, radius: float) -> Vector2:
		var player: Vector2 = view.get("player", Vector2.ZERO)
		return center + (point - player) / span * radius

	func _draw() -> void:
		var radius := minf(size.x, size.y) * 0.5 - 3.0
		var center := size * 0.5
		draw_circle(center + Vector2(0, 3), radius + 3.0, Color(0, 0, 0, 0.35))
		draw_circle(center, radius, Color(0.16, 0.12, 0.08, 0.94))
		draw_circle(center, radius * 0.97, Color(0.29, 0.23, 0.16, 0.94))
		# Roads and houses of the real village layout (clipped to the disc).
		var road := [Vector2(0, -49), Vector2(0, 28)]
		var a := _to_map(road[0], center, radius)
		var b := _to_map(road[1], center, radius)
		var clipped := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]), _disc(center, radius * 0.94))
		for piece: PackedVector2Array in clipped:
			draw_polyline(piece, Color(0.62, 0.53, 0.38, 0.8), 3.0, true)
		for home: Dictionary in Layout.HOMES:
			var rect: Rect2 = Layout.house_footprint(home)
			var p0 := _to_map(rect.position, center, radius)
			var p1 := _to_map(rect.end, center, radius)
			var box := Rect2(p0, p1 - p0).abs()
			if box.get_center().distance_to(center) + box.size.length() * 0.5 > radius * 0.95:
				continue
			draw_rect(box, Color(0.66, 0.55, 0.4, 0.95))
			draw_rect(box, Color(0.18, 0.12, 0.07, 0.9), false, 1.0)
		# Objective.
		var player: Vector2 = view.get("player", Vector2.ZERO)
		if bool(view.get("has_target", false)):
			var target: Vector2 = view.get("target", Vector2.ZERO)
			var at := _to_map(target, center, radius)
			if at.distance_to(center) > radius * 0.86:
				at = center + (at - center).normalized() * radius * 0.86
			draw_line(center, at, Color(Style.AURUM, 0.55), 1.5, true)
			Style.draw_diamond(self, at, 7.0, Color(0.1, 0.06, 0.02))
			Style.draw_diamond(self, at, 5.5, Style.AURUM)
		# Player arrow along the camera facing.
		var heading := -float(view.get("camera_yaw", view.get("heading", 0.0)))
		var direction := Vector2(sin(heading), -cos(heading))
		var side := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([center + direction * 9.0, center - direction * 5.0 + side * 6.0, center - direction * 2.0, center - direction * 5.0 - side * 6.0]), Style.CHARTA)
		# Bronze rim with north mark.
		draw_arc(center, radius, 0, TAU, 96, Style.BRONZE, 3.0, true)
		draw_arc(center, radius - 5.0, 0, TAU, 96, Color(Style.AURUM, 0.35), 1.0, true)
		var font := Style.display_font(700, 1)
		var north := center + Vector2(0, -radius + 14.0)
		draw_string_outline(font, north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 3, Color(0.05, 0.03, 0.02))
		draw_string(font, north + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.AURUM_LIGHT)
		var label := "Ortskarte · %d m" % roundi(span)
		var small := Style.display_font(600, 1)
		var width := small.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(small, center + Vector2(-width * 0.5, radius - 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Style.CHARTA_MUTED)

	func _disc(center: Vector2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(48):
			var angle := TAU * index / 48.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		return points
