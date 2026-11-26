extends RefCounted
## Pedestrian street graph of the city (baked by tools/world/bake_city_layout.gd).
##
## The life simulation moves residents along graph routes as a pure function
## of time, so a resident's position never depends on whether a visible actor
## exists for it. Routes are found with the engine's native AStar3D; lengths
## are cached per node pair because the same commutes repeat every day.

const PATH := "res://assets/city/street_graph.json"
const FORMAT := "imperathen-city-street-graph"
const MAX_ROUTE_CACHE := 384

var ok := false
var error := ""
var node_count := 0
var anchor_nodes := {}
var _astar := AStar3D.new()
var _lengths := {}
var _routes := {}
var _route_order: Array[Vector2i] = []


func load_graph(path: String = PATH) -> bool:
	ok = false
	if not FileAccess.file_exists(path):
		error = "street graph missing: " + path
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("format") != FORMAT or not parsed.get("nodes") is Array or not parsed.get("edges") is Array:
		error = "street graph has an unknown format"
		return false
	_astar.clear()
	_lengths.clear()
	_routes.clear()
	_route_order.clear()
	_astar.reserve_space(parsed.nodes.size())
	for index in parsed.nodes.size():
		var at: Array = parsed.nodes[index]
		_astar.add_point(index, Vector3(float(at[0]), float(at[1]), float(at[2])))
	for pair: Array in parsed.edges:
		_astar.connect_points(int(pair[0]), int(pair[1]), true)
	node_count = parsed.nodes.size()
	anchor_nodes.clear()
	for id: String in parsed.get("anchor_nodes", {}):
		anchor_nodes[id] = int(parsed.anchor_nodes[id])
	ok = node_count > 1
	return ok


func node_position(index: int) -> Vector3:
	return _astar.get_point_position(index)


func closest_node(position: Vector3) -> int:
	return int(_astar.get_closest_point(position))


## One drawing batch from the pedestrian survey. Diagonal shortcuts are useful
## to walkers; cardinal links describe the street surface on the chart.
func survey_lines() -> PackedVector2Array:
	var lines := PackedVector2Array()
	for a in node_count:
		var start := node_position(a)
		for b in _astar.get_point_connections(a):
			if a < b:
				var end := node_position(b)
				if absf(start.x-end.x) < .1 or absf(start.z-end.z) < .1:
					lines.append(Vector2(start.x,start.z))
					lines.append(Vector2(end.x,end.z))
	return lines


## Street node used to reach an anchor; anchors from other packages that are
## not part of the bake attach to the closest node.
func node_for(anchor_id: String, position: Vector3) -> int:
	if anchor_nodes.has(anchor_id):
		return anchor_nodes[anchor_id]
	var nearest := closest_node(position)
	anchor_nodes[anchor_id] = nearest
	return nearest


## Walking distance in metres between two street nodes, -1 when unreachable.
func length(from: int, to: int) -> float:
	if from == to:
		return 0.0
	var key := Vector2i(mini(from, to), maxi(from, to))
	if _lengths.has(key):
		return _lengths[key]
	var points := _astar.get_point_path(from, to)
	var total := -1.0
	if points.size() >= 2:
		total = 0.0
		for index in range(1, points.size()):
			total += points[index - 1].distance_to(points[index])
	_lengths[key] = total
	return total


## Polyline of the route (street nodes only). Cached for the visible few.
func route(from: int, to: int) -> PackedVector3Array:
	var key := Vector2i(from, to)
	if _routes.has(key):
		return _routes[key]
	var points := _astar.get_point_path(from, to)
	_routes[key] = points
	_route_order.append(key)
	if _route_order.size() > MAX_ROUTE_CACHE:
		_routes.erase(_route_order.pop_front())
	return points


## Point at `distance` metres along a polyline, plus the walking direction.
static func along(points: PackedVector3Array, distance: float) -> Array:
	if points.is_empty():
		return [Vector3.ZERO, Vector3.FORWARD]
	if points.size() == 1 or distance <= 0.0:
		var heading := (points[1] - points[0]) if points.size() > 1 else Vector3.FORWARD
		return [points[0], heading.normalized()]
	var left := distance
	for index in range(1, points.size()):
		var segment := points[index] - points[index - 1]
		var size := segment.length()
		if left <= size and size > 0.0001:
			return [points[index - 1] + segment * (left / size), segment / size]
		left -= size
	var last := points[points.size() - 1] - points[points.size() - 2]
	return [points[points.size() - 1], last.normalized() if last.length() > 0.0001 else Vector3.FORWARD]


static func polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	return total
