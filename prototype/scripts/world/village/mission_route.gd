extends RefCounted
## The static grid is baked by querying actual walls, doorways, fences and
## furniture in Godot. NPCs keep moving independently. No walk order is issued.
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const GRID_PATH := "res://assets/world/waystation/valdora_walk_grid.json"
const EAST_GATE := Vector2(46,-13)
static var _grid: AStarGrid2D
static var _bounds: Rect2
var _from := Vector2.INF
var _to := Vector2.INF
var _route := PackedVector2Array()

static func _prepare() -> void:
	if _grid != null:
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GRID_PATH))
	var rows: Array = source.rows
	var cell := float(source.cell)
	var origin := Vector2(source.origin[0],source.origin[1])
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0,0,str(rows[0]).length(),rows.size())
	_grid.cell_size = Vector2.ONE * cell
	_grid.offset = origin
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	_bounds = Rect2(origin,Vector2(_grid.region.size) * cell)
	for z in rows.size():
		var line: String = rows[z]
		for x in line.length():
			if line.unicode_at(x) == 35:
				_grid.set_point_solid(Vector2i(x,z))

static func _nearby_cell(point: Vector2) -> Vector2i:
	var centre := Vector2i(((point-_grid.offset)/_grid.cell_size).round())
	for r in range(0,7):
		var best := Vector2i(-1,-1)
		var best_distance := INF
		for dz in range(-r,r+1):
			for dx in range(-r,r+1):
				if maxi(absi(dx),absi(dz)) != r:
					continue
				var cell := centre + Vector2i(dx,dz)
				if not _grid.region.has_point(cell) or _grid.is_point_solid(cell):
					continue
				var distance := point.distance_squared_to(_grid.get_point_position(cell))
				if distance < best_distance:
					best_distance = distance
					best = cell
		if best.x >= 0:
			return best
	return Vector2i(-1,-1)

static func local_path(start: Vector2, goal: Vector2) -> PackedVector2Array:
	_prepare()
	var a := _nearby_cell(start)
	var b := _nearby_cell(goal)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var path := _grid.get_point_path(a,b)
	if path.size() < 3:
		return path
	var bends := PackedVector2Array([path[0]])
	for i in range(1,path.size()-1):
		if (path[i]-path[i-1]) != (path[i+1]-path[i]):
			bends.append(path[i])
	bends.append(path[-1])
	return bends

func route(start: Vector2, goal: Vector2) -> PackedVector2Array:
	if _from.distance_squared_to(start) < 1.44 and _to.distance_squared_to(goal) < 0.36:
		return _route
	_from = start
	_to = goal
	_prepare()
	if _bounds.has_point(start) and _bounds.has_point(goal):
		_route = local_path(start,goal)
	elif _bounds.has_point(start):
		_route = local_path(start,EAST_GATE)
		_route.append_array(Footpath.route_between(EAST_GATE,goal))
	elif _bounds.has_point(goal):
		_route = Footpath.route_between(start,EAST_GATE)
		_route.append_array(local_path(EAST_GATE,goal))
	else:
		_route = Footpath.route_between(start,goal)
	return _route
