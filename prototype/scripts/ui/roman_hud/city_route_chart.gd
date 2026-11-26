extends PopupPanel
## Read-only itinerarium over the street survey shared with resident commutes.
const Streets = preload("res://scripts/domain/city_streets.gd")
const Trade = preload("res://scripts/city_trade_catalog.gd")
var streets: Streets
var sites: Dictionary
var player: CharacterBody3D
var _chooser := OptionButton.new()
var _map := Diagram.new()
var _distance := Label.new()
var _cooldown := 0.0
var _last := Vector3.INF
var destination := ""
var route := PackedVector3Array()

func _ready() -> void:
	title = "Stadtplan"
	var column := VBoxContainer.new()
	add_child(column)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	controls.add_child(_chooser)
	_chooser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chooser.custom_minimum_size.y = 46
	_chooser.item_selected.connect(func(index: int): select(str(_chooser.get_item_metadata(index))))
	var close := Button.new()
	close.text = "Schließen"
	close.custom_minimum_size.y = 46
	close.pressed.connect(hide)
	controls.add_child(close)
	column.add_child(_map)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_distance)
	visibility_changed.connect(func(): set_process(visible))
	set_process(false)

func open_chart(actor: CharacterBody3D, locations: Dictionary, shared: Streets) -> void:
	player = actor
	sites = locations
	if streets == null:
		streets = shared
		if streets == null:
			streets = Streets.new()
			if not streets.load_graph():
				return
		_map.roads = streets.survey_lines()
		for id: String in sites:
			_chooser.add_item(str(Trade.SHOPS[id].name))
			_chooser.set_item_metadata(_chooser.item_count-1,id)
		_map.shops = sites.values()
	if destination.is_empty():
		select(str(_chooser.get_item_metadata(0)))
	else:
		_update_route()
	popup_centered(Vector2i(Vector2(get_viewport().get_visible_rect().size) * Vector2(.86,.74)).min(Vector2i(780,490)))

func select(id: String) -> void:
	if sites.has(id):
		destination = id
		for i in _chooser.item_count:
			if str(_chooser.get_item_metadata(i)) == id:
				_chooser.select(i)
				break
		_update_route()

func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = .35
		if player.global_position.distance_squared_to(_last) >= 1.0:
			_update_route()

func _update_route() -> void:
	_last = player.global_position
	var target: Vector3 = sites[destination]
	var start := streets.closest_node(_last)
	var finish := streets.node_for("counter." + destination,target)
	route = streets.route(start,finish).duplicate()
	if route.is_empty():
		_distance.text = "Kein passierbarer Weg zum Ziel."
	else:
		route.insert(0,_last)
		route.append(target)
		_distance.text = "Marktstraße · %s · Wegstrecke %d m" % [Trade.SHOPS[destination].name,roundi(Streets.polyline_length(route))]
	_map.path = route
	_map.player = _last
	_map.target = target
	_map.queue_redraw()

class Diagram extends Control:
	var roads := PackedVector2Array()
	var path := PackedVector3Array()
	var shops: Array = []
	var player := Vector3.ZERO
	var target := Vector3.ZERO

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _xz(p: Vector3) -> Vector2:
		return Vector2(p.x,p.z)

	func _draw() -> void:
		if size.x < 10 or size.y < 10:
			return
		draw_rect(Rect2(Vector2.ZERO,size),Color("352d22"))
		var survey := Rect2(_xz(player),Vector2.ZERO).expand(_xz(target))
		for point: Vector3 in path:
			survey = survey.expand(_xz(point))
		survey = survey.grow(22.0)
		var scale_factor := minf(size.x/survey.size.x,size.y/survey.size.y)
		var origin := size*.5 - survey.get_center()*scale_factor
		draw_set_transform(origin,0,Vector2.ONE*scale_factor)
		if roads.size() > 1:
			draw_multiline(roads,Color("61523b"),1.0/scale_factor)
		for site: Vector3 in shops:
			draw_circle(_xz(site),3.0/scale_factor,Color("b29a69"))
		var points := PackedVector2Array()
		for point: Vector3 in path:
			points.append(_xz(point))
		if points.size() >= 2:
			draw_polyline(points,Color("21190f"),6.0/scale_factor,true)
			draw_polyline(points,Color("ead18b"),3.0/scale_factor,true)
		draw_circle(_xz(target),5.5/scale_factor,Color("d8ac55"))
		draw_circle(_xz(player),5.5/scale_factor,Color("e5eee0"))
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		draw_string(ThemeDB.fallback_font,Vector2(10,19),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1d89b"))
