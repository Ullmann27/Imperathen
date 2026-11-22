extends RefCounted

const LIMIT := Vector2(28.0, 22.0)
const ROCKS := [
	{"x": -12.0, "z": -2.0, "radius": 2.4},
	{"x": 11.0, "z": 1.0, "radius": 2.1},
	{"x": -21.0, "z": 10.0, "radius": 2.8},
	{"x": 21.0, "z": -10.0, "radius": 2.6},
]
const MARGIN := 0.3
var grid := AStarGrid2D.new()


func _init() -> void:
	grid.region = Rect2i(-28, -22, 57, 45)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for rock in ROCKS:
		var center := Vector2(rock.x, rock.z)
		var radius := ceili(rock.radius + 1.5)
		for x in range(int(center.x) - radius, int(center.x) + radius + 1):
			for z in range(int(center.y) - radius, int(center.y) + radius + 1):
				if Vector2(x, z).distance_to(center) < float(rock.radius) + 1.05:
					grid.set_point_solid(Vector2i(x, z))


static func height(x: float, z: float) -> float:
	return 0.0016 * x * x + 0.2 * sin(z * 0.14) + 0.09 * sin(x * 0.28 + z * 0.13)


static func clear_segment(a: Vector2, b: Vector2) -> bool:
	if not a.is_finite() or a.abs().x > LIMIT.x or a.abs().y > LIMIT.y:
		return false
	if not b.is_finite() or absf(b.x) > LIMIT.x or absf(b.y) > LIMIT.y:
		return false
	for rock in ROCKS:
		var center := Vector2(rock.x, rock.z)
		var closest := a if a == b else Geometry2D.get_closest_point_to_segment(center, a, b)
		if closest.distance_to(center) < float(rock.radius) + MARGIN:
			return false
	return true


static func project(p: Vector2) -> Vector2:
	p = p.clamp(-LIMIT, LIMIT)
	for rock in ROCKS:
		var center := Vector2(rock.x, rock.z)
		var radius := float(rock.radius) + MARGIN + 0.01
		if p.distance_to(center) < radius:
			var normal := center.direction_to(p) if p != center else Vector2.RIGHT
			p = center + normal * radius
	return p


# Connect arbitrary endpoints to the navigable grid with a collision-free segment.
func _cell(p: Vector2) -> Vector2i:
	var rounded := Vector2i(p.round())
	var best := rounded
	var distance := INF
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var candidate := rounded + Vector2i(dx, dz)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
				continue
			var d := p.distance_squared_to(Vector2(candidate))
			if d < distance and clear_segment(p, Vector2(candidate)):
				distance = d
				best = candidate
	return best


func next_position(p: Vector2, dest: Vector2, distance: float) -> Vector2:
	if clear_segment(p, dest):
		return p.move_toward(dest, distance)
	var path := grid.get_id_path(_cell(p), _cell(dest))
	# The furthest visible waypoint smooths grid corners and avoids oscillation
	# when a point still rounds to its previous cell.
	for i in range(path.size() - 1, -1, -1):
		var waypoint := Vector2(path[i])
		if clear_segment(p, waypoint):
			return p.move_toward(waypoint, distance)
	return p
