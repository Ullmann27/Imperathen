extends RefCounted
## Stateless raider route through the authored village enclosure.
##
## next_waypoint(position, goal) depends only on those two points and on the
## fixed village layout. Saved raiders therefore keep their exact v1 entries
## (id, x, z, health, max_health, attack_timer, loot_timer); no path, node or
## route index is stored. The authoritative rules (VillageLife) and the visible
## swept bodies (VillageLifeWorld) ask the same function, so both follow the
## same corridor: from the northern field through the north gate (|x| < 1.6 m
## between the watch-post uprights) and along the main street to the granary.
##
## The obstacle model is the static village plan: the outer palisade
## (GameWorld._create_outer_palisade), the watch-post uprights, every house
## footprint and the walled yards (VillageLayout). Small props are handled by
## the bodies' swept slide; the corridor edges are checked against the real
## physics world in tests/raid_route_world_test.gd.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const HouseFamily = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
const Freight = preload("res://scripts/domain/regional_freight.gd")
const LOOT := Vector2(5.0, 5.0)
const LOOT_RADIUS := 2.0
const RADIUS := 0.28
const CLEARANCE := 0.15
const EDGE_RANGE := 30.0
const GOAL_CACHE_LIMIT := 32
const START_CANDIDATES := 8
## Outer palisade, 0.5 m thick boxes around the centre lines used by GameWorld.
const WALLS := [
	Rect2(-21.0, -49.25, 18.0, 0.5), Rect2(3.0, -49.25, 45.0, 0.5),
	Rect2(-21.0, 29.75, 18.0, 0.5), Rect2(3.0, 29.75, 45.0, 0.5),
	Rect2(-21.25, -49.0, 0.5, 50.0), Rect2(-21.25, 7.0, 0.5, 23.0),
	Rect2(47.75, -49.0, 0.5, 33.0), Rect2(47.75, -10.0, 0.5, 40.0),
]
## Watch-post uprights in the north gate (VillageLifeWorld workplace at (0,-48)).
const POSTS := [
	Rect2(-2.18, -49.38, 0.16, 0.16), Rect2(2.02, -49.38, 0.16, 0.16),
	Rect2(-2.18, -46.78, 0.16, 0.16), Rect2(2.02, -46.78, 0.16, 0.16),
]
## Walled or furnished yards from VillageLayout.reserved(). The watch-post yard
## (-3.5,-50.5,7,7) is the open gate itself and deliberately not an obstacle.
const YARDS := [
	Rect2(8.0, -35.5, 12.0, 11.0), Rect2(31.5, -30.0, 4.0, 8.0), Rect2(-17.0, 13.0, 5.0, 5.0),
	Rect2(20.5, -33.0, 7.0, 6.5), Rect2(-46.5, 11.0, 7.0, 7.0), Rect2(44.5, -15.0, 7.0, 8.0),
	Rect2(21.5, 20.5, 7.0, 7.0),
]
## Solid props on the street level (trees, wells, stalls, benches, the wagon,
## the training post, bridge rails). Measured from the GameWorld colliders;
## tests/raid_route_world_test.gd fails if a real prop is not covered.
const PROPS := [
	Rect2(Freight.DEPOT - Freight.TABLE_FOOTPRINT * 0.5, Freight.TABLE_FOOTPRINT),
	Rect2(-32.8, 2.38, 9.6, 0.13), Rect2(-32.8, 5.49, 9.6, 0.13),
	Rect2(-19.21, 14.79, 0.42, 0.42), Rect2(-18.21, 7.79, 0.42, 0.42), Rect2(1.21, -41.9, 0.44, 0.44),
	Rect2(5.79, -12.21, 0.42, 0.42), Rect2(25.79, 15.79, 0.42, 0.42),
	Rect2(-12.48, 14.32, 3.85, 2.58), Rect2(-11.62, -8.93, 4.83, 3.15), Rect2(-10.95, -35.34, 1.9, 0.48),
	Rect2(-10.5, -0.6, 3.0, 1.2), Rect2(-7.97, 5.07, 1.94, 1.86), Rect2(-3.17, 26.53, 0.54, 0.54),
	Rect2(-3.11, 17.89, 0.22, 0.22), Rect2(2.89, 17.89, 0.22, 0.22), Rect2(-0.16, -7.16, 0.32, 0.32),
	Rect2(4.96, -28.25, 0.48, 1.9), Rect2(6.25, 22.4, 2.3, 5.6), Rect2(13.16, -24.74, 1.68, 0.71),
	Rect2(14.95, -23.68, 1.5, 0.76), Rect2(32.34, 0.61, 1.32, 1.58), Rect2(33.4, 16.5, 1.2, 3.0),
]
## All current authored house variants have an entrance ramp.
## Street waypoints. Index 0/1 are the outer and inner point of the north gate.
const NODES := [
	Vector2(0.0, -52.5), Vector2(0.0, -45.2), Vector2(0.0, -40.6), Vector2(2.6, -36.6),
	Vector2(3.4, -26.0), Vector2(3.4, -12.0), Vector2(3.4, 1.0),
	Vector2(-8.0, -36.0), Vector2(-18.85, -35.0), Vector2(-18.85, -20.0), Vector2(-18.85, -3.0),
	Vector2(-18.85, 4.0), Vector2(-22.5, 4.0), Vector2(-18.85, 18.0),
	Vector2(-9.5, -23.5), Vector2(-8.0, -13.0),
	Vector2(13.0, -38.0), Vector2(29.5, -38.0), Vector2(29.5, -22.0), Vector2(29.5, -3.0), Vector2(29.5, 12.0),
	Vector2(12.0, -21.5), Vector2(12.0, -3.0), Vector2(12.0, 11.0), Vector2(0.0, 12.0), Vector2(-9.0, 18.5),
	Vector2(0.0, 27.5), Vector2(0.0, 32.5), Vector2(19.7, 24.0),
	# Field ring outside the palisade towards the gates.
	Vector2(-22.5, -52.5), Vector2(25.0, -52.5), Vector2(53.0, -52.5), Vector2(53.0, -30.0),
	Vector2(53.0, -8.0), Vector2(53.0, 14.0), Vector2(53.0, 33.0), Vector2(25.0, 33.0),
	Vector2(-22.5, 33.0), Vector2(-22.5, 16.0), Vector2(-22.5, -11.0), Vector2(-22.5, -32.0),
]
## Distinct looting places around the granary point; all lie inside LOOT_RADIUS.
const LOOT_SLOTS := [
	Vector2(-0.78, -0.78), Vector2(0.0, -1.1), Vector2(-1.1, 0.0),
	Vector2(0.78, -0.78), Vector2(-0.78, 0.78), Vector2(1.1, 0.0),
]
static var _obstacles: Array[Rect2] = []
static var _sight_blockers: Array[Rect2] = []
static var _distance: Array = []
static var _goal_costs: Dictionary = {}


## Next point a raider at `from` should walk straight towards to reach `goal`.
static func next_waypoint(from: Vector2, goal: Vector2) -> Vector2:
	if not from.is_finite() or not goal.is_finite():
		return from
	_ensure()
	var from_house := _house_index(from)
	var goal_house := _house_index(goal)
	if from_house >= 0 and from_house != goal_house:
		return _leave_house(from_house, from)
	if from_house >= 0:
		return goal
	if goal_house >= 0:
		var doorstep := _door_point(goal_house, true)
		if from.distance_to(doorstep) < 0.6:
			return _door_point(goal_house, false)
		goal = doorstep
	if clear(from, goal):
		return goal
	var goal_cost := _goal_cost(goal)
	var order := range(NODES.size())
	order.sort_custom(func(a: int, b: int) -> bool: return from.distance_squared_to(NODES[a]) < from.distance_squared_to(NODES[b]))
	var best := INF
	var best_node := -1
	var checked := 0
	for index: int in order:
		if checked >= START_CANDIDATES:
			break
		var node: Vector2 = NODES[index]
		# Standing on a street point: the next leg starts there, never a
		# zero-length leg that would hold the raider in place.
		if from.distance_to(node) < 0.25 or not clear(from, node):
			continue
		checked += 1
		var through := from.distance_to(node) + _via(index, goal_cost)
		if through < best:
			best = through
			best_node = index
	if best_node < 0:
		# Pressed into an unmodelled corner: head for the closest street point
		# and let the swept slide find the way out.
		best_node = _nearest_node(from)
	return NODES[best_node]


## Loot place for one raider. Derived from the saved id only ("raid_<n>_<i>").
static func loot_point(enemy_id: String) -> Vector2:
	var suffix := enemy_id.get_slice("_", enemy_id.get_slice_count("_") - 1)
	var index := int(suffix) if suffix.is_valid_int() else absi(hash(enemy_id))
	return LOOT + (LOOT_SLOTS[posmod(index, LOOT_SLOTS.size())] as Vector2)


## True when a raider capsule can walk the straight segment without touching
## the static plan. Obstacles that already contain an endpoint are shrunk to
## that endpoint's actual clearance, so a body sliding along a wall can still
## see the open side.
static func clear(a: Vector2, b: Vector2) -> bool:
	_ensure()
	var margin := RADIUS + CLEARANCE
	for rect: Rect2 in _obstacles:
		var grown := rect.grow(margin)
		# Cheap rejection first: most of the plan is far from any segment.
		if maxf(a.x, b.x) < grown.position.x or minf(a.x, b.x) > grown.end.x or maxf(a.y, b.y) < grown.position.y or minf(a.y, b.y) > grown.end.y:
			continue
		if rect.has_point(a) or rect.has_point(b):
			# A body already inside a yard walks out by sliding; a house is
			# left through its door before this test is reached.
			continue
		var inflate := margin
		for point: Vector2 in [a, b]:
			var gap := _distance_to_rect(point, rect)
			if gap < inflate:
				inflate = maxf(0.0, gap - 0.02)
		if _segment_hits(a, b, rect.grow(inflate)):
			return false
	return true


## Line of sight across the village plan for the abstract guard support: the
## palisade, every house and the walled atrium block it; the open gates,
## yards, props and people do not.
static func sight_clear(a: Vector2, b: Vector2) -> bool:
	_ensure()
	if not a.is_finite() or not b.is_finite():
		return false
	for rect: Rect2 in _sight_blockers:
		if _segment_hits(a, b, rect):
			return false
	return true


static func obstacles() -> Array[Rect2]:
	_ensure()
	return _obstacles


static func edge(a: int, b: int) -> bool:
	_ensure()
	return a != b and is_finite(float(_distance[a][b])) and _adjacent(a, b)


static func _adjacent(a: int, b: int) -> bool:
	var first: Vector2 = NODES[a]
	var second: Vector2 = NODES[b]
	return first.distance_to(second) <= EDGE_RANGE and clear(first, second)


static func _goal_cost(goal: Vector2) -> Array[float]:
	# Loot places are fixed goals; their visibility is computed once per run.
	if _goal_costs.has(goal):
		return _goal_costs[goal]
	var goal_cost: Array[float] = []
	var goal_any := false
	for index in NODES.size():
		var node: Vector2 = NODES[index]
		var cost := INF
		if node.distance_to(goal) <= EDGE_RANGE * 2.0 and clear(node, goal):
			cost = node.distance_to(goal)
			goal_any = true
		goal_cost.append(cost)
	if not goal_any:
		var nearest := _nearest_node(goal)
		goal_cost[nearest] = (NODES[nearest] as Vector2).distance_to(goal)
	if _goal_costs.size() >= GOAL_CACHE_LIMIT:
		_goal_costs.clear()
	_goal_costs[goal] = goal_cost
	return goal_cost


static func _via(start: int, goal_cost: Array[float]) -> float:
	var best := INF
	for index in NODES.size():
		if is_finite(goal_cost[index]):
			best = minf(best, float(_distance[start][index]) + goal_cost[index])
	return best


static func _ensure() -> void:
	if not _obstacles.is_empty():
		return
	var rects: Array[Rect2] = []
	for rect: Rect2 in WALLS:
		rects.append(rect)
	for rect: Rect2 in POSTS:
		rects.append(rect)
	for rect: Rect2 in YARDS:
		rects.append(rect)
	for rect: Rect2 in PROPS:
		rects.append(rect)
	for index in Layout.HOMES.size():
		rects.append_array(HouseFamily.navigation_footprints(Layout.HOMES[index]))
		rects.append(_entrance(index))
	_obstacles = rects
	var blockers: Array[Rect2] = []
	for rect: Rect2 in WALLS:
		blockers.append(rect)
	blockers.append(YARDS[0])
	for home: Dictionary in Layout.HOMES:
		blockers.append(Layout.house_footprint(home))
	_sight_blockers = blockers
	# All-pairs street distances (Floyd-Warshall over the fixed graph).
	var count := NODES.size()
	var table: Array = []
	for a in count:
		var row: Array[float] = []
		for b in count:
			row.append(0.0 if a == b else INF)
		table.append(row)
	for a in count:
		for b in range(a + 1, count):
			if _adjacent(a, b):
				var length := (NODES[a] as Vector2).distance_to(NODES[b])
				table[a][b] = length
				table[b][a] = length
	for k in count:
		for a in count:
			var through: float = table[a][k]
			if not is_finite(through):
				continue
			for b in count:
				var candidate: float = through + float(table[k][b])
				if candidate < float(table[a][b]):
					table[a][b] = candidate
	_distance = table


static func _nearest_node(point: Vector2) -> int:
	var best := 0
	for index in NODES.size():
		if point.distance_squared_to(NODES[index]) < point.distance_squared_to(NODES[best]):
			best = index
	return best


static func _house_index(point: Vector2) -> int:
	for index in Layout.HOMES.size():
		if Layout.house_footprint(Layout.HOMES[index]).has_point(point):
			return index
	return -1


static func _door_direction(house: int) -> Vector2:
	var yaw := float(Layout.HOMES[house].yaw)
	return Vector2(sin(yaw), cos(yaw))


static func _entrance(house: int) -> Rect2:
	# The landing and ramp are shared with the actual variant's collision.
	var home: Dictionary = Layout.HOMES[house]
	var entry: Dictionary = HouseFamily.variant_data(HouseFamily.variant_for(str(home.id))).get("metadata", {}).get("entry", {})
	var center := Vector2(home.at.x, home.at.z)
	var direction := _door_direction(house)
	var inner := center + direction * 2.05
	var outer := center + direction * (float(entry.get("ramp_start_z", 2.95)) + float(entry.get("ramp_run", 1.05)))
	var side := Vector2(direction.y, -direction.x) * float(entry.get("width", 1.25)) * .5
	var rect := Rect2(inner - side, Vector2.ZERO).expand(inner + side).expand(outer - side).expand(outer + side)
	return rect


static func _door_point(house: int, outside: bool) -> Vector2:
	var home: Dictionary = Layout.HOMES[house]
	var center := Vector2(home.at.x, home.at.z)
	# The door is centred in the 5.9 m front wall; the house is 4.9 m deep.
	return center + _door_direction(house) * (4.7 if outside else 1.55)


static func _leave_house(house: int, from: Vector2) -> Vector2:
	var home: Dictionary = Layout.HOMES[house]
	var center := Vector2(home.at.x, home.at.z)
	var direction := _door_direction(house)
	var offset := from - center
	var lateral := offset - direction * offset.dot(direction)
	if lateral.length() > 0.35:
		return _door_point(house, false)
	return _door_point(house, true)


static func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var nearest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	return point.distance_to(nearest)


static func _segment_hits(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# Liang-Barsky clipping of the segment against an axis-aligned rectangle.
	if maxf(a.x, b.x) < rect.position.x or minf(a.x, b.x) > rect.end.x or maxf(a.y, b.y) < rect.position.y or minf(a.y, b.y) > rect.end.y:
		return false
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var start := a.x if axis == 0 else a.y
		var delta := d.x if axis == 0 else d.y
		var low := rect.position.x if axis == 0 else rect.position.y
		var high := rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0000001:
			if start < low or start > high:
				return false
			continue
		var enter := (low - start) / delta
		var leave := (high - start) / delta
		if enter > leave:
			var swap := enter
			enter = leave
			leave = swap
		t0 = maxf(t0, enter)
		t1 = minf(t1, leave)
		if t0 > t1:
			return false
	return true
