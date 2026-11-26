extends SceneTree
## Follow the baked A* routes with the actual city player's collision,
## acceleration, steps and movement input. Teleport only at the public start.

const City := preload("res://scripts/world/city_exploration.gd")
const Streets := preload("res://scripts/domain/city_streets.gd")
const DESTINATIONS := ["smith", "taberna", "domus", "west", "crossing", "east", "stable"]

func _initialize() -> void:
	_run.call_deferred()

## Expansion across node 16384 used to alias (0,16386) with (1,2) in
## both distance and route caches. Use the normal serialized graph loader.
func _distinct_routes() -> bool:
	var graph_path := OS.get_temp_dir().path_join("imperathen-street-pairs-%d.json" % OS.get_process_id())
	var nodes := []
	for i in 16387:
		nodes.append([i, 0, 0])
	var file := FileAccess.open(graph_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"format": Streets.FORMAT, "nodes": nodes, "edges": [[0, 16386], [1, 2]]}))
	file.close()
	var graph := Streets.new()
	var loaded := graph.load_graph(graph_path)
	DirAccess.remove_absolute(graph_path)
	if not loaded:
		return false
	return graph.length(0, 16386) == 16386.0 and graph.length(1, 2) == 1.0 \
		and graph.route(0, 16386)[1] == Vector3(16386, 0, 0) and graph.route(1, 2)[1] == Vector3(2, 0, 0) \
		and graph.route(2, 1)[1] == Vector3(1, 0, 0)


func _run() -> void:
	if not _distinct_routes():
		printerr("QUARTER_STREET_WALK_FAIL aliased route keys")
		quit(1)
		return
	var city := City.new()
	city.persist = false
	city.profile = "low"
	root.add_child(city)
	var graph := Streets.new()
	if not is_instance_valid(city.quarter) or not graph.load_graph() or not graph.anchor_nodes.has("quarter.south"):
		printerr("QUARTER_STREET_WALK_FAIL missing authored district graph")
		quit(1)
		return
	var from := int(graph.anchor_nodes["quarter.south"])
	city.teleport(graph.node_position(from) + Vector3.UP * City.SOLE_OFFSET)
	for settle in 16:
		await physics_frame
	var total := 0.0
	var off_floor := 0
	var legs := []
	for id: String in DESTINATIONS:
		var to := int(graph.anchor_nodes.get("quarter." + id, -1))
		if to < 0:
			printerr("QUARTER_STREET_WALK_FAIL missing destination ", id)
			quit(1)
			return
		var route := graph.route(from, to)
		if route.size() < 2:
			printerr("QUARTER_STREET_WALK_FAIL no route to ", id)
			quit(1)
			return
		for index in range(1, route.size()):
			var at := route[index - 1]
			var target := route[index]
			var distance := at.distance_to(target)
			var max_frames := ceili((distance / City.WALK_SPEED + 4.0) * Engine.physics_ticks_per_second)
			var reached := false
			for tick in max_frames:
				var delta := Vector2(target.x - city.player.position.x, target.z - city.player.position.z)
				if delta.length() < 0.18:
					reached = true
					break
				city._touch_move = delta.normalized().rotated(city._yaw)
				await physics_frame
				if not city.player.is_on_floor():
					off_floor += 1

			if not reached:
				printerr("QUARTER_STREET_WALK_FAIL route ", id, " segment ", at, " -> ", target, " blocked at ", city.player.position)
				city.free()
				quit(1)
				return
		var metres := Streets.polyline_length(route)
		total += metres
		legs.append({"ziel": id, "wegpunkte": route.size(), "weg_m": snappedf(metres, 0.01)})
		from = to
	city._touch_move = Vector2.ZERO
	var near_seller := city.player.global_position.distance_to(city.quarter.stable_trader.global_position) < 0.45
	var ok := near_seller and off_floor == 0
	print("QUARTER_STREET_WALK_%s " % ("PASS" if ok else "FAIL"), JSON.stringify({
		"ziele": legs, "weg_m": snappedf(total, 0.01), "schritte_ohne_bodenkontakt": off_floor, "haendler_erreicht": near_seller}))
	city.free()
	await process_frame
	quit(0 if ok else 1)
