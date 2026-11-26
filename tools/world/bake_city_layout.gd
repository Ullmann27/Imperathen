extends SceneTree
## Bakes the city's activity anchors and pedestrian street graph from the
## built Roman city (manifest + collision). Run after the city build:
##
##   godot --headless --path prototype --script ../tools/world/bake_city_layout.gd
##
## Everything is derived from prototype/assets/world/roman_city_manifest.json
## and physics queries against roman_city_collision.glb, so a changed city
## (new walls, moved houses) is picked up by baking again. Output is
## deterministic for identical inputs:
##   prototype/assets/city/activity_anchors/{market_street,forum,residential}.json
##   prototype/assets/city/street_graph.json

const Anchors = preload("res://scripts/domain/city_anchors.gd")
const MANIFEST := "res://assets/world/roman_city_manifest.json"
const COLLISION := "res://assets/world/roman_city_collision.glb"
const SHOPS := "res://assets/city_detail/shops/city_market_anchors.json"
const OUT_ANCHORS := "res://assets/city/activity_anchors"
const OUT_GRAPH := "res://assets/city/street_graph.json"
const ALL := ["poor", "common", "prosperous", "elite"]
const STALL_TYPES := ["produce", "fish", "bakery", "pottery", "textiles", "metalware", "cookshop"]
const FRONT_EXTENT := {"insula": 12.0, "domus": 15.5, "artisan": 10.0, "atrium": 14.0, "villa": 15.5}
const HOUSE_TIERS := {"insula": ["poor", "common"], "domus": ["prosperous"], "artisan": ["common"],
	"atrium": ["prosperous", "elite"], "villa": ["elite"]}
const ARTISAN_TRADES := ["carpenter", "cobbler", "weaver", "smith", "potter", "fuller"]
const RAY_HEIGHTS := [0.45, 1.0, 1.6]
const MAX_EDGE := 22.5
const MAX_DEGREE := 8

var space: PhysicsDirectSpaceState3D
var nodes: Array[Vector3] = []
var node_keys := {}
var files := {"market_street": [], "forum": [], "residential": []}
var anchor_node := {}
var approach := {}
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists(MANIFEST) or not ResourceLoader.exists(COLLISION, "PackedScene"):
		push_error("CITY_LAYOUT_BAKE_FAIL built city missing; run tools/world/build_roman_test_city.py first")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var holder := Node3D.new()
	root.add_child(holder)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1400, 0.2, 1400)
	ground_shape.shape = box
	ground.add_child(ground_shape)
	ground.position.y = -0.125
	holder.add_child(ground)
	var scene := (load(COLLISION) as PackedScene).instantiate() as Node3D
	holder.add_child(scene)
	var bodies := scene.find_children("*", "StaticBody3D", true, false)
	if bodies.is_empty():
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			holder.add_child(body)
			body.global_transform = mesh.global_transform
	for frame in 3:
		await physics_frame
	space = holder.get_world_3d().direct_space_state
	_market(manifest)
	_forum(manifest)
	_residential(manifest)
	_street_nodes()
	var graph := _build_graph()
	if not failures.is_empty():
		for line: String in failures:
			push_error("CITY_LAYOUT_BAKE_FAIL " + line)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ANCHORS))
	var total := 0
	for area: String in files:
		var payload := {"format": Anchors.FORMAT, "schema": Anchors.SCHEMA, "area": area,
			"source": "tools/world/bake_city_layout.gd from roman_city_manifest.json (city seed %d)" % int(manifest.seed),
			"anchors": files[area]}
		var check := Anchors.parse_file(payload, area)
		if not check.errors.is_empty():
			push_error("CITY_LAYOUT_BAKE_FAIL " + str(check.errors.slice(0, 5)))
			quit(1)
			return
		total += files[area].size()
		_write(OUT_ANCHORS.path_join(area + ".json"), payload)
	_write(OUT_GRAPH, graph)
	print("CITY_LAYOUT_BAKED " + JSON.stringify({"anchors": total, "nodes": graph.nodes.size(), "edges": graph.edges.size(),
		"market": files.market_street.size(), "forum": files.forum.size(), "residential": files.residential.size()}))
	quit(0)


func _write(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t", false) + "\n")
	file.close()


# --- geometry helpers -------------------------------------------------------

func _ground(x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 2.6, z), Vector3(x, -1.0, z), 1)
	var hit := space.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else INF


func _standable(x: float, z: float) -> bool:
	var y := _ground(x, z)
	if y > 0.62:
		return false
	for step in 8:
		var direction := Vector3(cos(step * TAU / 8.0), 0, sin(step * TAU / 8.0))
		for height: float in [0.5, 1.4]:
			var from := Vector3(x, y + height, z)
			var query := PhysicsRayQueryParameters3D.create(from, from + direction * 0.42, 1)
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty():
				return false
	return true


func _clear(a: Vector3, b: Vector3, half_width: float = 0.38) -> bool:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	if flat.length() < 0.05:
		return true
	var side := Vector3(-flat.z, 0, flat.x).normalized() * half_width
	for height: float in RAY_HEIGHTS:
		for offset: Vector3 in [Vector3.ZERO, side, -side]:
			for pair: Array in [[a, b], [b, a]]:
				var from: Vector3 = pair[0] + offset + Vector3.UP * height
				var to: Vector3 = pair[1] + offset + Vector3.UP * height
				if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty():
					return false
	return true


func _travel(from: Vector3, direction: Vector3, limit: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + direction * limit, 1))
	return limit if hit.is_empty() else from.distance_to(hit.position)


func _node(x: float, z: float) -> int:
	var key := "%d:%d" % [roundi(x * 4.0), roundi(z * 4.0)]
	if node_keys.has(key):
		return node_keys[key]
	if not _standable(x, z):
		return -1
	nodes.append(Vector3(snappedf(x, 0.01), snappedf(_ground(x, z), 0.01), snappedf(z, 0.01)))
	node_keys[key] = nodes.size() - 1
	return nodes.size() - 1


func _anchor(area: String, id: String, kind: String, at: Vector3, facing: float, capacity: int, hours: Array,
		from_year: Variant, tiers: Array, tags: Array, approach_at: Variant = null) -> bool:
	var y := _ground(at.x, at.z)
	if y == INF:
		failures.append("anchor %s has no ground" % id)
		return false
	var road: Vector3 = approach_at if approach_at != null else at
	if kind == "fountain":
		# The anchor sits in the basin centre; people stand at street level.
		y = _ground(road.x, road.z)
	var index := _node(road.x, road.z)
	if index < 0:
		return false
	files[area].append({"id": id, "kind": kind, "position": [snappedf(at.x, 0.01), snappedf(y, 0.01), snappedf(at.z, 0.01)],
		"facing_deg": snappedf(facing, 0.1), "capacity": capacity, "hours": hours,
		"era": {"from_year": from_year, "to_year": null}, "wealth_tiers": tiers, "tags": tags})
	anchor_node[id] = index
	return true


static func _year(era_min_ce: Variant) -> Variant:
	## The manifest counts "CE" with -100 meaning 100 BC; map 0 to 1 BC.
	var year := int(era_min_ce)
	if year <= -1000:
		return null
	return year if year != 0 else -1


# --- areas ------------------------------------------------------------------

func _market(manifest: Dictionary) -> void:
	var shop_by_node := {}
	if FileAccess.file_exists(SHOPS):
		var shops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHOPS))
		for row: Dictionary in shops.shops:
			shop_by_node[str(row.stand_node)] = str(row.shop_id)
	var stalls: Array[Dictionary] = []
	for entry: Dictionary in manifest.entries:
		if entry.category == "market_stall":
			stalls.append(entry)
	for index in stalls.size():
		var entry: Dictionary = stalls[index]
		var x := float(entry.position_blender_m[0])
		var z := -float(entry.position_blender_m[1])
		var scale := float(entry.scale)
		var label := "%02d" % (index + 1)
		var kind := int(str(entry.name).get_slice("_Type", 1).substr(0, 1))
		var tags := ["business:" + STALL_TYPES[kind], "stall_node:" + str(entry.name), "district:market"]
		if shop_by_node.has(entry.name):
			tags.append("shop:" + shop_by_node[entry.name])
		var customer := Vector3(x, 0, z + 1.15 * scale + 1.55)
		# The vendor serves from behind the counter, facing the street (+Z).
		if not _anchor("market_street", "market.stall_" + label, "stall", Vector3(x, 0, z - 0.95 * scale), 180.0, 1,
				[6.0, 18.0], _year(entry.era_min_ce), ALL, tags, customer + Vector3(0, 0, 1.6)):
			failures.append("stall %s has no free approach" % entry.name)
			continue
		_anchor("market_street", "market.queue_" + label, "queue", customer, 0.0, 3, [6.0, 18.0],
			_year(entry.era_min_ce), ALL, ["stall:market.stall_" + label, "district:market"])
		if kind == 6:
			_anchor("market_street", "market.tavern_" + label, "tavern_seat", customer + Vector3(1.5 * scale, 0, 0.1), 0.0, 3,
				[10.0, 22.0], _year(entry.era_min_ce), ["poor", "common", "prosperous"], ["stall:market.stall_" + label, "district:market"])
		if index % 7 == 3:
			_anchor("market_street", "market.cart_stop_" + label, "cart_stop", Vector3(x + 6.2, 0, 59.6), 90.0, 4,
				[4.0, 20.0], -100, ALL, ["district:market"])
		if index % 4 == 1:
			_anchor("market_street", "market.gossip_" + label, "gossip_spot", Vector3(x + 6.2, 0, 55.2), 0.0, 4,
				[7.0, 20.0], -100, ALL, ["district:market"])
		if index % 9 == 4:
			_anchor("market_street", "market.beggar_" + label, "beggar_spot", Vector3(x + 6.2, 0, 51.4), 180.0, 1,
				[7.0, 19.0], -100, ["poor"], ["district:market"])
		if index % 10 == 5:
			_anchor("market_street", "market.guard_" + label, "guard_post", Vector3(x + 6.2, 0, 57.0), 180.0, 2,
				[0.0, 24.0], -100, ALL, ["district:market", "patrol:market"])
		if index % 6 == 2:
			_anchor("market_street", "market.play_" + label, "play_spot", Vector3(x + 6.2, 0, 40.5), 0.0, 4,
				[8.0, 18.5], -100, ["poor", "common"], ["district:market"])


	# Where people leave the city for the fields and return in the evening.
	for exit: Array in [["west", -384.0, 65.0], ["east", 384.0, 65.0], ["north", -100.0, -312.0], ["south", -100.0, 312.0]]:
		_anchor("market_street", "city.exit_" + str(exit[0]), "entrance", Vector3(float(exit[1]), 0, float(exit[2])), 0.0, 64,
			[0.0, 24.0], -100, ALL, ["city_exit", "district:market"])


func _forum(manifest: Dictionary) -> void:
	for entry: Dictionary in manifest.entries:
		var x := float(entry.position_blender_m[0])
		var z := -float(entry.position_blender_m[1])
		if entry.category == "fountain":
			var id := "forum.fountain" if entry.name == "Forum_Fountain" else "residential.fountain_north"
			var area := "forum" if entry.name == "Forum_Fountain" else "residential"
			# Users stand on a ring around the 3.4 m basin; approach from the south side.
			_anchor(area, id, "fountain", Vector3(x, 0, z), 0.0, 8, [5.0, 21.0], _year(entry.era_min_ce), ALL,
				["ring:4.2", "district:" + area], Vector3(x, 0, z + 4.6))
		elif entry.category == "portico":
			var side := "west" if x < 0 else "east"
			for slot in 4:
				var along := z - 24.0 + slot * 16.0
				_anchor("forum", "forum.portico_%s_%d" % [side, slot], "gossip_spot", Vector3(x, 0, along), 90.0 if x < 0 else -90.0, 4,
					[6.0, 21.0], _year(entry.era_min_ce), ALL, ["shelter", "district:forum"],
					Vector3(x + (5.2 if x < 0 else -5.2), 0, along))
	for index in 6:
		var at := Vector3(-48.0 + (index % 3) * 34.0, 0, -22.0 + (index / 3) * 40.0)
		_anchor("forum", "forum.gossip_%d" % index, "gossip_spot", at, 0.0, 5, [7.0, 20.0], -100, ALL, ["district:forum"])
	for index in 4:
		var at := Vector3(-70.0 if index % 2 == 0 else 46.0, 0, -52.0 if index < 2 else 36.0)
		_anchor("forum", "forum.guard_%d" % index, "guard_post", at, 0.0, 2, [0.0, 24.0], -100, ALL, ["district:forum", "patrol:forum"])
	_anchor("forum", "forum.beggar_0", "beggar_spot", Vector3(-8.0, 0, 41.0), 0.0, 1, [7.0, 19.0], -100, ["poor"], ["district:forum"])
	_anchor("forum", "forum.beggar_1", "beggar_spot", Vector3(-60.0, 0, -40.0), 0.0, 1, [7.0, 19.0], -100, ["poor"], ["district:forum"])
	_anchor("forum", "forum.play_0", "play_spot", Vector3(30.0, 0, 20.0), 0.0, 5, [8.0, 18.5], -100, ALL, ["district:forum"])
	var temple: Array = manifest.temple_anchor_godot_m
	# The temple model is optional (privately supplied); worshippers only use
	# the forecourt when the scene really contains it.
	_anchor("forum", "forum.shrine_temple", "shrine", Vector3(float(temple[0]), 0, float(temple[2]) + 17.0), 0.0, 8,
		[5.0, 20.0], -100, ALL, ["requires_node:MeshyTemple", "district:forum"])


func _residential(manifest: Dictionary) -> void:
	var count := 0
	var artisan := 0
	for entry: Dictionary in manifest.entries:
		var category := str(entry.category)
		if category != "residential" and category != "craft_shop":
			continue
		var x := float(entry.position_blender_m[0])
		var z := -float(entry.position_blender_m[1])
		# Unrotated houses face Blender -Y, which is Godot +Z.
		var front := Vector3(0, 0, 1) if absf(float(entry.rotation_z)) < 0.1 else Vector3(0, 0, -1)
		var right := Vector3(front.z, 0, -front.x)
		var facing := 180.0 if front.z > 0 else 0.0
		var house := str(entry.name).get_slice("_", 2) if category == "residential" else "craft"
		var extent := float(FRONT_EXTENT.get(house, 8.6))
		var lane := Vector3(x, 0, z) + front * (extent + 1.0)
		# Find the real door: the lateral offset where a chest-high ray from the
		# lane reaches deepest into the building shell.
		var best_offset := INF
		var best_depth := 0.0
		for step in 65:
			var offset := (step - 32) * 0.25
			var origin := lane + right * offset + Vector3.UP * 1.0
			var depth := minf(_travel(origin, -front, 9.0), minf(
				_travel(origin + right * 0.3, -front, 9.0), _travel(origin - right * 0.3, -front, 9.0)))
			if depth > best_depth + 0.4 or (absf(depth - best_depth) <= 0.4 and absf(offset) < absf(best_offset)):
				best_depth = depth
				best_offset = offset
		if best_depth < 2.2 or best_offset == INF:
			failures.append("no door opening found for %s (depth %.2f)" % [entry.name, best_depth])
			continue
		var door_lane := lane + right * best_offset
		var threshold := door_lane - front * minf(best_depth - 0.7, extent - 5.0 if house != "craft" else 3.0)
		var number := str(entry.name).get_slice("_", 1) if category == "residential" else str(entry.name).to_lower()
		var tags := ["building:" + str(entry.name), "house:" + house, "district:residential"]
		if category == "craft_shop":
			var trade: String = {"Pistrinum_Bakery": "bakery_oven", "Fabrica_Blacksmith": "smith", "Mercator_Store": "merchant"}[entry.name]
			_anchor("residential", "workshop." + str(entry.name).to_lower(), "workshop", threshold, facing, 4, [6.0, 18.0],
				_year(entry.era_min_ce), ALL, ["business:" + trade, "building:" + str(entry.name), "district:residential"], door_lane)
			continue
		if _anchor("residential", "home." + number, "doorway", threshold, facing, 12 if house == "insula" else 6, [0.0, 24.0],
				_year(entry.era_min_ce), HOUSE_TIERS[house], tags, door_lane):
			count += 1
		if house == "artisan":
			_anchor("residential", "workshop.artisan_" + number, "workshop", door_lane - front * 0.4 + right * 1.6, facing, 2, [6.5, 17.5],
				_year(entry.era_min_ce), ALL, ["business:" + ARTISAN_TRADES[artisan % ARTISAN_TRADES.size()], "building:" + str(entry.name), "district:residential"], door_lane)
			artisan += 1
		var serial := int(number)
		if serial % 5 == 0:
			_anchor("residential", "residential.gossip_" + number, "gossip_spot", lane + right * 7.0 + front * 1.6, facing, 4,
				[7.0, 20.5], -100, ALL, ["district:residential"])
		if serial % 7 == 3:
			_anchor("residential", "residential.play_" + number, "play_spot", lane - right * 7.0 + front * 1.4, facing, 4,
				[8.0, 18.5], -100, ALL, ["district:residential"])
	if count < 200:
		failures.append("only %d doorways found" % count)


func _street_nodes() -> void:
	# Main east-west street: two walking lanes, the market pavement, the strip
	# behind the stalls and the gaps between stalls.
	for step in 125:
		var x := -385.0 + step * 6.2096774
		for z: float in [41.0, 53.4, 55.6, 62.0, 68.0, 76.0]:
			_node(x, z)
	# North-south street.
	for step in 99:
		var z := -318.5 + step * 6.5
		for x: float in [-103.0, -97.0]:
			_node(x, z)
	# Forum piazza.
	for column in 19:
		for row in 15:
			_node(-78.0 + column * 7.0, -58.0 + row * 7.0)
	# Residential lanes: plot boundaries every 34 m (x) and 39 m (z), sampled
	# densely enough that every edge stays inside one straight lane.
	for column in 25:
		var x := -408.0 + 34.0 * column
		for step in 97:
			_node(x, 311.5 - step * 6.5)
	for row in 17:
		var z := 311.5 - 39.0 * row
		for step in 145:
			_node(-408.0 + step * 5.6666667, z)


func _build_graph() -> Dictionary:
	# Spatial hash so candidate search stays linear.
	var cells := {}
	for index in nodes.size():
		var key := Vector2i(floori(nodes[index].x / MAX_EDGE), floori(nodes[index].z / MAX_EDGE))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(index)
	var edge_set := {}
	var degree: Array[int] = []
	degree.resize(nodes.size())
	for index in nodes.size():
		var at := nodes[index]
		var key := Vector2i(floori(at.x / MAX_EDGE), floori(at.z / MAX_EDGE))
		var candidates: Array[Array] = []
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				for other: int in cells.get(key + Vector2i(dx, dz), []):
					if other != index:
						var distance := Vector2(at.x, at.z).distance_to(Vector2(nodes[other].x, nodes[other].z))
						if distance <= MAX_EDGE:
							candidates.append([distance, other])
		candidates.sort_custom(func(a: Array, b: Array) -> bool:
			return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
		var kept := 0
		for candidate: Array in candidates:
			if kept >= MAX_DEGREE:
				break
			var other := int(candidate[1])
			var pair := Vector2i(mini(index, other), maxi(index, other))
			if edge_set.has(pair):
				kept += 1
				continue
			if _clear(at, nodes[other]):
				edge_set[pair] = true
				kept += 1
	# Keep the largest connected component; every anchor must be inside it.
	var neighbours := {}
	for pair: Vector2i in edge_set:
		for end: Array in [[pair.x, pair.y], [pair.y, pair.x]]:
			if not neighbours.has(end[0]):
				neighbours[end[0]] = []
			neighbours[end[0]].append(end[1])
	var component: Array[int] = []
	component.resize(nodes.size())
	component.fill(-1)
	var sizes: Array[int] = []
	for start in nodes.size():
		if component[start] != -1:
			continue
		var label := sizes.size()
		var stack: Array[int] = [start]
		component[start] = label
		var size := 0
		while not stack.is_empty():
			var current: int = stack.pop_back()
			size += 1
			for next: int in neighbours.get(current, []):
				if component[next] == -1:
					component[next] = label
					stack.append(next)
		sizes.append(size)
	var main := sizes.find(sizes.max())
	var remap := {}
	var out_nodes: Array = []
	for index in nodes.size():
		if component[index] == main:
			remap[index] = out_nodes.size()
			out_nodes.append([nodes[index].x, nodes[index].y, nodes[index].z])
	var out_edges: Array = []
	for pair: Vector2i in edge_set:
		if remap.has(pair.x) and remap.has(pair.y):
			out_edges.append([remap[pair.x], remap[pair.y]])
	out_edges.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var out_anchor_nodes := {}
	var dropped: Array[String] = []
	for area: String in files:
		var kept_entries: Array = []
		for entry: Dictionary in files[area]:
			var index: int = anchor_node[entry.id]
			if remap.has(index):
				out_anchor_nodes[entry.id] = remap[index]
				kept_entries.append(entry)
			else:
				dropped.append(entry.id)
		files[area] = kept_entries
	# Optional decorative anchors may fall on blocked ground; homes, stalls and
	# their queues must never be lost.
	for id: String in dropped:
		if id.begins_with("home.") or id.begins_with("market.stall_") or id.begins_with("market.queue_") or id.begins_with("workshop."):
			failures.append("anchor %s is not connected to the street graph" % id)
	print("CITY_LAYOUT_DROPPED " + JSON.stringify(dropped))
	return {"format": "imperathen-city-street-graph", "schema": 1,
		"source": "tools/world/bake_city_layout.gd; edges verified by ray casts at 0.45/1.0/1.6 m, 0.76 m wide",
		"nodes": out_nodes, "edges": out_edges, "anchor_nodes": out_anchor_nodes}
