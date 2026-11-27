extends Control
## Original north-up cartography of the actual regional plan. Planned places
## and roads are explicitly different from playable landmarks. Selecting a
## destination only changes navigation; it cannot move the player.
signal destination_selected(id: String)
signal close_requested
signal atlas_requested
const Plan := preload("res://scripts/world/world_stream_plan.gd")
const Footpath := preload("res://scripts/world/regional_footpath.gd")
const Layout := preload("res://scripts/world/village/village_layout.gd")
const SPANS := [90.0,360.0,1800.0,8000.0,32000.0]
var canvas: MapCanvas
var details: Label
var route_button: Button
var selected := ""
var view := {}

func _ready() -> void:
	name = "RegionalMap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("1e2926")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",6)
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,Control.PRESET_MODE_MINSIZE,10)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "IMPERATHEN  /  REGION"
	title.add_theme_font_size_override("font_size",19)
	title.add_theme_color_override("font_color",Color("e7d5ae"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header,"−",func(): canvas.zoom(1))
	_button(header,"+",func(): canvas.zoom(-1))
	_button(header,"Ort",func(): canvas.focus_player())
	_button(header,"Atlas",func(): atlas_requested.emit())
	_button(header,"Zurück",func(): close_requested.emit())
	canvas = MapCanvas.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(canvas)
	canvas.place_selected.connect(_select)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	details = Label.new()
	details.text = "Ort wählen · Gold = begehbarer Weg · Grau = geplant"
	details.add_theme_color_override("font_color",Color("e1d9bc"))
	details.add_theme_font_size_override("font_size",13)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.clip_text = true
	footer.add_child(details)
	route_button = _button(footer,"Route setzen",_route)
	route_button.disabled = true
	update_view(view)
	canvas.focus_player()

func _button(parent: Control, caption: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(46,44)
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button

func update_view(next: Dictionary) -> void:
	view = next
	if is_instance_valid(canvas):
		canvas.update_view(view)

func _select(id: String) -> void:
	selected = id
	route_button.disabled = not Footpath.DESTINATIONS.has(id)
	for point: Dictionary in Plan.POIS:
		if point.id==id:
			var player: Vector2 = view.get("player",Vector2.ZERO)
			var pos := Vector2(point.position[0],point.position[2])
			var status := "begehbarer Zielort" if not route_button.disabled else "noch im Ausbau"
			details.text = "%s · %.2f km Luftlinie · %s" % [point.name,player.distance_to(pos)/1000.0,status]
			return

func _route() -> void:
	if Footpath.DESTINATIONS.has(selected):
		destination_selected.emit(selected)

class MapCanvas extends Control:
	signal place_selected(id: String)
	var view := {}
	var center := Vector2.ZERO
	var level := 1
	var selected := ""
	static var _cached_terrain: Texture2D
	var terrain: Texture2D
	var _dragged := false
	var _press := Vector2.ZERO
	var _touch_id := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		resized.connect(queue_redraw)
		if _cached_terrain==null:
			_cached_terrain = _terrain_texture()
		terrain = _cached_terrain

	func update_view(next: Dictionary) -> void:
		if view!=next:
			view = next
			queue_redraw()

	func focus_player() -> void:
		center = view.get("player",Vector2.ZERO)
		level = 1
		queue_redraw()

	func zoom(direction: int) -> void:
		level = clampi(level+direction,0,SPANS.size()-1)
		_clamp_center()
		queue_redraw()

	func pixels_per_m() -> float:
		return maxf(1.0,minf(size.x,size.y)-20.0)/float(SPANS[level])

	func project(point: Vector2) -> Vector2:
		return size*.5+(point-center)*pixels_per_m()

	func unproject(pixel: Vector2) -> Vector2:
		return center+(pixel-size*.5)/pixels_per_m()

	func _clamp_center() -> void:
		center = center.clamp(Vector2.ONE*-Plan.WORLD_HALF_M,Vector2.ONE*Plan.WORLD_HALF_M)

	func _pan(delta: Vector2) -> void:
		center -= delta/pixels_per_m()
		_clamp_center()
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
				zoom(-1)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				zoom(1)
			elif event.button_index==MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press=event.position
					_dragged=false
				elif not _dragged:
					_pick(event.position)
			accept_event()
		elif event is InputEventMouseMotion and (event.button_mask&MOUSE_BUTTON_MASK_LEFT)!=0:
			_dragged = _dragged or event.position.distance_to(_press)>5
			if _dragged:
				_pan(event.relative)
			accept_event()
		elif event is InputEventScreenTouch:
			if event.pressed and _touch_id<0:
				_touch_id=event.index
				_press=event.position
				_dragged=false
			elif event.index==_touch_id and not event.pressed:
				if not event.canceled and not _dragged:
					_pick(event.position)
				_touch_id=-1
			accept_event()
		elif event is InputEventScreenDrag and event.index==_touch_id:
			_dragged = _dragged or event.position.distance_to(_press)>5
			if _dragged:
				_pan(event.relative)
			accept_event()

	func _pick(pixel: Vector2) -> void:
		var best := 23.0
		var found := ""
		for point: Dictionary in Plan.POIS:
			var pos := project(Vector2(point.position[0],point.position[2]))
			var distance := pos.distance_to(pixel)
			if distance<best:
				best=distance
				found=point.id
		if not found.is_empty():
			selected=found
			place_selected.emit(found)
			queue_redraw()

	func _terrain_texture() -> Texture2D:
		var image := Image.create(192,192,false,Image.FORMAT_RGB8)
		var spacing := Plan.WORLD_SIZE_M/192.0
		for y in 192:
			for x in 192:
				var at := Vector2(-Plan.WORLD_HALF_M+(x+.5)*spacing,-Plan.WORLD_HALF_M+(y+.5)*spacing)
				var height := Plan.terrain_height(at)
				var gradient := Plan.terrain_height(at+Vector2(spacing,0))-height
				var biome := str(Plan.region_at(Vector3(at.x,0,at.y)).biome)
				var tones := {"forest":Color("58664c"),"highland":Color("8b8267"),"farmland":Color("a09a70"),"valley":Color("92936c"),"quarry":Color("a49b82"),"river":Color("708e83"),"wetland":Color("778c75"),"coast":Color("82988f")}
				var base: Color = tones.get(biome,Color("92936c"))
				base = base.lightened(clampf(height/900.0,0,.32)).darkened(clampf(gradient/160.0,0,.2))
				if posmod(floori(height/25.0),2)==0:
					base = base.darkened(.035)
				image.set_pixel(x,y,base)
		return ImageTexture.create_from_image(image)

	func _line(points: PackedVector2Array, color: Color, width: float, dashed: bool = false) -> void:
		if points.size()<2:
			return
		var polygon := PackedVector2Array([Vector2.ZERO,Vector2(size.x,0),size,Vector2(0,size.y)])
		for clipped: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(points,polygon):
			if clipped.size()<2:
				continue
			if dashed:
				for i in range(1,clipped.size()):
					draw_dashed_line(clipped[i-1],clipped[i],color,width,7.0,true)
			else:
				draw_polyline(clipped,color,width,true)

	# All current kilometre rulers are whole numbers. Avoid unsupported %g,
	# which raised a Godot runtime error while the graphical test still passed.
	func scale_caption() -> String:
		var ruler := int([20,100,500,2000,8000][level])
		return "%d km" % int(float(ruler) / 1000.0) if ruler >= 1000 else "%d m" % ruler

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("34443c"))
		var scale := pixels_per_m()
		var bounds := Rect2(project(Vector2.ONE*-Plan.WORLD_HALF_M),Vector2.ONE*Plan.WORLD_SIZE_M*scale)
		var visible_map := bounds.intersection(Rect2(Vector2.ZERO,size))
		if terrain!=null and visible_map.has_area():
			var ratio := Vector2(terrain.get_size())/bounds.size
			var source := Rect2((visible_map.position-bounds.position)*ratio,visible_map.size*ratio)
			draw_texture_rect_region(terrain,visible_map,source)
		# Actual trail is the authored polyline, not a straight planner link.
		for road: Dictionary in Plan.roads():
			if road.content_status=="walkable_track":
				continue
			var a: Array = road.start
			var b: Array = road.end
			_line(PackedVector2Array([project(Vector2(a[0],a[2])),project(Vector2(b[0],b[2]))]),Color(.2,.24,.2,.56),1.4,true)
		var actual := PackedVector2Array()
		for point: Vector2 in Footpath.WAYPOINTS:
			actual.append(project(point))
		_line(actual,Color("433929"),4.5)
		_line(actual,Color("e4c388"),2.4)
		_line(PackedVector2Array([project(Footpath.WAYPOINTS[2]),project(Footpath.HAMLET)]),Color("e4c388"),2.4)
		if level<=1:
			_line(PackedVector2Array([project(Vector2(0,-49)),project(Vector2(0,28))]),Color("d8c397"),3)
			for home: Dictionary in Layout.HOMES:
				var footprint: Rect2=Layout.house_footprint(home)
				var box:=Rect2(project(footprint.position),footprint.size*scale).intersection(Rect2(Vector2.ZERO,size))
				if box.has_area():
					draw_rect(box,Color("6b4f3a"))
					draw_rect(box,Color("e0cda2"),false,1)
		var route := PackedVector2Array()
		for waypoint: Vector2 in view.get("route",PackedVector2Array()):
			route.append(project(waypoint))
		_line(route,Color("3a3327"),5)
		_line(route,Color("ffe3a0"),2.5)
		var font := ThemeDB.fallback_font
		var occupied: Array[Rect2] = []
		for place: Dictionary in Plan.POIS:
			var at := project(Vector2(place.position[0],place.position[2]))
			if not Rect2(Vector2(12,12),size-Vector2(24,24)).has_point(at):
				continue
			var live := Footpath.DESTINATIONS.has(place.id)
			var marker_color := Color("ffe4aa") if live else Color("b4b9ac")
			draw_circle(at,8.0 if place.id==selected else 6.0,Color("26332e"))
			draw_circle(at,4.0,marker_color)
			var caption := str(place.name)
			var label_size := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			var label_rect := Rect2(at+Vector2(10,-12),label_size+Vector2(5,4))
			var collision := false
			for previous: Rect2 in occupied:
				collision = collision or previous.intersects(label_rect)
			if not collision and Rect2(Vector2.ZERO,size).encloses(label_rect):
				occupied.append(label_rect)
				draw_rect(label_rect,Color(.08,.12,.10,.82))
				draw_string(font,label_rect.position+Vector2(2,13),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,marker_color)
		var player: Vector2 = view.get("player",Vector2.ZERO)
		var player_at := project(player)
		if Rect2(Vector2.ZERO,size).has_point(player_at):
			var heading := -float(view.get("heading",0.0))
			var direction := Vector2(sin(heading),-cos(heading))
			draw_circle(player_at,11,Color(.08,.12,.10,.8))
			draw_colored_polygon(PackedVector2Array([player_at+direction*10,player_at-direction*6+direction.orthogonal()*6,player_at-direction*3,player_at-direction*6-direction.orthogonal()*6]),Color("ffffff"))
		draw_string(font,Vector2(14,23),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff0cf"))
		var ruler := float([20.0,100.0,500.0,2000.0,8000.0][level])
		var start := Vector2(14,size.y-20)
		draw_line(start,start+Vector2(ruler*scale,0),Color("fff0cf"),2.0)
		draw_string(font,start+Vector2(0,-5),scale_caption(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("fff0cf"))
