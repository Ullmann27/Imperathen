extends SceneTree
## Follow the baked A* routes with the actual city player's collision,
## acceleration, steps and movement input. Teleport only at the public start.

const City := preload("res://scripts/world/city_exploration.gd")
const Streets := preload("res://scripts/domain/city_streets.gd")
const DESTINATIONS := ["smith", "taberna", "domus", "west", "crossing", "east", "stable"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
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
