extends Control
## A drawn route graph from authored metre coordinates; no geographical claims.
signal settlement_selected(settlement_id: String, region_id: String)
var regions: Array = []
var routes: Array = []
var _world_rect := Rect2(-1000, -1000, 2000, 2000)
var _last_choice := ""
var _last_choice_time := -1000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	queue_redraw()


func configure(manifest: Dictionary) -> void:
	regions = manifest.get("regions", []).duplicate(true)
	routes = manifest.get("trade_routes", []).duplicate(true)
	var points := PackedVector2Array()
	for region: Dictionary in regions:
		var at: Array = region.get("position", [])
		if at.size() == 2:
			points.append(Vector2(float(at[0]), float(at[1])))
	if not points.is_empty():
		_world_rect = Rect2(points[0], Vector2.ONE)
		for at in points:
			_world_rect = _world_rect.expand(at)
		_world_rect = _world_rect.grow(maxf(_world_rect.size.x, _world_rect.size.y) * 0.13 + 100.0)
	queue_redraw()


func map_point(at: Vector2) -> Vector2:
	var usable := size - Vector2(72, 110)
	var scale := minf(usable.x / _world_rect.size.x, usable.y / _world_rect.size.y)
	var origin := (size - _world_rect.size * scale) * 0.5 + Vector2(0, 10)
	return origin + (at - _world_rect.position) * scale


func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 34), "Handelsrouten", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#efdfba"))
	draw_string(font, Vector2(24, 57), "Ort antippen, um seine Siedlung zu öffnen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c1c9bd"))
	for index in range(1, 9):
		var x := float(index) * size.x / 9.0
		draw_line(Vector2(x, 75), Vector2(x, size.y - 24), Color(0.7, 0.8, 0.6, 0.08), 1.0)
	for route: Dictionary in routes:
		var points := PackedVector2Array()
		for value: Array in route.get("waypoints", []):
			if value.size() == 2:
				points.append(map_point(Vector2(float(value[0]), float(value[1]))))
		if points.size() >= 2:
			draw_polyline(points, Color("#4a4230"), 8.0, true)
			draw_polyline(points, Color("#c9ad70"), 3.0, true)
	for region: Dictionary in regions:
		var at: Array = region.get("position", [])
		if at.size() != 2:
			continue
		var point := map_point(Vector2(float(at[0]), float(at[1])))
		var seat := bool(region.get("government_seat", false))
		draw_circle(point, 13 if seat else 10, Color("#ddbd78") if seat else Color("#aebf8e"))
		draw_circle(point, 5, Color("#30372d"))
		var label := str(region.get("label", "Ort"))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var label_at := Vector2(clampf(point.x - width * 0.5, 15, maxf(15, size.x - width - 15)), point.y + 29)
		draw_string(font, label_at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f2ead5"))


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#24332b")
	style.border_color = Color("#ad9569")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		position = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		position = event.position
	if not pressed:
		return
	for region: Dictionary in regions:
		var at: Array = region.get("position", [])
		if at.size() != 2:
			continue
		if position.distance_to(map_point(Vector2(float(at[0]), float(at[1])))) <= 32.0:
			var id := str(region.get("id", ""))
			var now := Time.get_ticks_msec()
			if id != _last_choice or now - _last_choice_time > 350:
				_last_choice = id
				_last_choice_time = now
				settlement_selected.emit(str(region.get("settlement", "")), id)
			accept_event()
			return


func route_report() -> Dictionary:
	var result: Array[Dictionary] = []
	for route: Dictionary in routes:
		var distance := 0.0
		var points: Array = route.get("waypoints", [])
		for index in range(1, points.size()):
			var a := Vector2(float(points[index - 1][0]), float(points[index - 1][1]))
			var b := Vector2(float(points[index][0]), float(points[index][1]))
			distance += a.distance_to(b)
		result.append({"id": str(route.get("id", "")), "length_m": distance,
			"from": str(route.get("from", "")), "to": str(route.get("to", ""))})
	return {"region_count": regions.size(), "route_count": routes.size(), "routes": result}
