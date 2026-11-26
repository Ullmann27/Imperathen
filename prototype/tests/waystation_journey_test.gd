extends "res://tests/campaign_market_visit_test.gd"
## Test fixture opens the saved I-02 campaign and places the player at the gate.
## From there the production capsule walks the trail and a cross-country detour.
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const VillageRoute = preload("res://scripts/world/village/mission_route.gd")
const Profile = preload("res://scripts/world/world_stream_plan.gd")
const DT := 1.0/60.0

func _visit() -> void:
	var world: Node3D = game.world
	var body := world.get_node("Player") as CharacterBody3D
	game.ui.action_requested.emit("village_panel",{"tab":"map"})
	var choose := button(game.ui,"Route · Weidenhof")
	if not expect(choose != null, "Ziel im regulären Regionalmenü wählbar"):
		return
	choose.pressed.emit()
	expect(game.screen == "playing" and world.navigation_view().target == Footpath.HAMLET,"Wegpunkt ist auf dem Kompass aktiv")
	if not capture_dir.is_empty():
		game.ui._navigation.update_view(world.navigation_view())
		game.ui._toggle_local_map()
		for frame in 35:
			await process_frame
		world.look.set_time_of_day(12)
		await capture("valdora-wegkarte")
		game.ui._toggle_local_map()
	var inside := VillageRoute.local_path(Vector2(-13,10),Vector2(32.8,-25))
	expect(inside.size() >= 5 and inside[0].distance_to(Vector2(-13,10)) < 2 and inside[-1].distance_to(Vector2(32.8,-25)) < 2,"Missionsroute vom Familienhaus zur Schmiede enthält begehbare Abzweige")
	var terrain: Node3D = world.regional_terrain
	var start: Vector2 = Footpath.WAYPOINTS[0]
	body.position = Vector3(start.x,1.08,start.y)
	body.velocity = Vector3.ZERO
	world._camera_yaw = 0
	world.set_running(true)
	# Isolate the world controller and terrain; narrative days remain untouched.
	game.set_process(false)
	world.set_physics_process(false)
	for tick in 25:
		terrain.follow(body.position,"low")
		await physics_frame
		world._move_player(DT)
	var distance := 0.0
	var off_road_distance := 0.0
	var support_lost := 0
	var sectors := {}
	var max_route_gap := 0.0
	var stops := [Vector2(90,-13),Vector2(144,25),Vector2(180,8),Vector2(225,60),Vector2(250,100),Footpath.HAMLET]
	for goal: Vector2 in stops:
		var ticks := 0
		while ticks < 4200:
			var before := Vector2(body.position.x,body.position.z)
			if before.distance_to(goal) < .30:
				break
			world.set_touch_move(before.direction_to(goal))
			terrain.follow(body.position,"low")
			terrain.waystation.update_nearby(body.position,game.model.data.village.economy.get("freight",{}))
			await physics_frame
			world._move_player(DT)
			var after := Vector2(body.position.x,body.position.z)
			var step := before.distance_to(after)
			distance += step
			var gap := after.distance_to(Geometry2D.get_closest_point_to_segment(after,Footpath.WAYPOINTS[1],Footpath.WAYPOINTS[2]))
			if after.x > 100 and after.x < 240:
				max_route_gap = maxf(max_route_gap,gap)
				if gap > 6:
					off_road_distance += step
			sectors[Profile.sector_for_position(body.position)] = true
			support_lost += int(not body.is_on_floor())
			ticks += 1
		if not expect(ticks < 4200,"Laufziel zu Fuß erreicht %s bei %s" % [goal,body.position]):
			return
	expect(off_road_distance > 30 and sectors.size() >= 3 and support_lost < 6,"Abseits der Straße über Sektorgrenzen auf begehbarem Boden")
	var stop: Node3D = terrain.waystation
	var spring: Node3D = stop.get_node("Yard/WillowSpring")
	var water_depth: float = spring.global_position.y - terrain.surface_height(Profile.SPRING)
	expect(water_depth > .6 and water_depth < 1.0,"Quelle liegt über der passierbaren Senke")
	var wagon := stop.get_node("FreightWagon") as AnimatableBody3D
	var wagon_start := wagon.position
	stop.update_nearby(body.position,{})
	expect(wagon.position.is_equal_approx(wagon_start) and not wagon.get_node("SixGrainSacks").visible and wagon.find_children("*","AnimationPlayer",true,false).size() > 0,"Leerer bespannter Wagen wartet auf Fracht")
	expect(stop.get_node("Yard/WillowGroves").multimesh.instance_count > 35 and world.at_waystation(),"Weidenhaine, Laden und begehbarer Tresen erreicht")
	print("WEIDENHOF_PHYSICS ",JSON.stringify({"weg_m":snappedf(distance,.01),"abseits_m":snappedf(off_road_distance,.01),"abstand_zur_trasse_max_m":snappedf(max_route_gap,.01),"sektoren":sectors.size(),"kontaktlose_ticks":support_lost,"kartenknicke":inside.size()}))
	if not capture_dir.is_empty():
		var city_camera := Camera3D.new()
		root.add_child(city_camera)
		city_camera.global_position = stop.global_position + Vector3(15,10,-19)
		city_camera.look_at(stop.global_position + Vector3(-1,1,0))
		city_camera.fov = 53
		city_camera.current = true
		game.ui.hide()
		world.look.set_time_of_day(12)
		await capture("weidenhof")
		world._sync_world_light(game.model.data)
		game.ui.show()
		city_camera.free()
		world.get_node("WorldCamera").current = true
	world._update_context_hint()
	world.perform_interaction()
	var city = game.city_exploration
	if not expect(city != null and city.market.available and city.market.model == game.model,"Tresen öffnet denselben gespeicherten Stadtmarkt"):
		return
	var chart_button := button(city._safe,"Stadtplan")
	chart_button.pressed.emit()
	city.street_chart.select("foodstall")
	expect(city.street_chart.visible and city.street_chart.route.size() >= 3 and city.street_chart.route[-1] == city.market.sites.foodstall,"Stadtplan führt über denselben Straßengraphen zum Laden")
	if not capture_dir.is_empty():
		await capture("rom-stadtplan")
	city.street_chart.hide()
	var before_clock: Dictionary = game.model.data.calendar.clock.duplicate()
	city._request_leave()
	expect(game.screen == "playing" and world.at_waystation() and game.model.data.calendar.clock == before_clock,"Rückweg behält Standort und Kampagnenuhr")
