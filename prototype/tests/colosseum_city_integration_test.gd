extends SceneTree
const City = preload("res://scripts/world/city_exploration.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Entry = preload("res://main.tscn")
const Monument = preload("res://scripts/monuments/colosseum.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	# The build contains the actual generated city; missing assets are a failure.
	var city = City.new()
	city.profile = "low"
	city.persist = false
	city.use_flavian_kit = true
	city.world_jdn = Calendar.to_jdn(100, 6, 1)
	root.add_child(city)
	await process_frame
	check(city.city_available, "Actual Roman city loaded")
	var amph = city.get_node_or_null("FlavianAmphitheatre")
	check(amph != null, "New Flavian kit attached to actual city")
	if amph != null:
		check(amph.stats.sectors == 16 and amph.stats.collision_faces > 0, "Real interior sectors and physical collision")
		check(amph.position.is_equal_approx(Vector3(181, 0, -42)), "Placed at original city anchor")
	var legacy = city.get_node_or_null("RomanCity")
	check(legacy != null and legacy.find_children("Colosseum*", "", true, false).is_empty(), "No old amphitheatre mesh duplicated")
	check(not city.persist and city.campaign == null, "Imperial sandbox does not write campaign")
	city.free()
	await process_frame
	# Exercise the actual installed game's menu route, not just City.new().
	var game = Entry.instantiate()
	root.add_child(game)
	for frame in 4:
		await process_frame
	game.ui._finish_intro()
	await process_frame
	for button_id: String in ["FreeCityExploration", "ImperialCityExploration"]:
		var button := game.ui.find_child(button_id, true, false) as Button
		check(is_instance_valid(button) and not button.disabled and button.is_visible_in_tree(), button_id + " is a visible real main menu control")
		if not is_instance_valid(button):
			continue
		button.pressed.emit()
		for frame in 4:
			await process_frame
		var visit = game.city_exploration
		check(is_instance_valid(visit), button_id + " actually opens city")
		if not is_instance_valid(visit):
			continue
		check(visit.city_available and visit.world_jdn == Calendar.to_jdn(100, 6, 1), button_id + " loads the complete dated city")
		var monument = visit.get_node_or_null("FlavianAmphitheatre")
		check(is_instance_valid(monument) and visit.campaign == null, button_id + " loads the real monument without campaign mutation")
		if is_instance_valid(monument):
			check(int(monument.stats.collision_faces) > 0, button_id + " monument has real colliders")
			if button_id == "ImperialCityExploration":
				var entrance: Vector3 = monument.to_global(Monument.bay_point(monument.layout, 40, 0.5, -6.0, 0.92))
				check(visit.player.global_position.distance_to(entrance) < 0.5, "Direct entry spawns outside the verified processional entrance")
				check(not visit.persist, "Direct monument tour is disposable")
		game._leave_city_exploration()
		for frame in 3:
			await process_frame
	game.free()
	await process_frame
	print("COLOSSEUM_CITY_INTEGRATION_PASS" if failures.is_empty() else "COLOSSEUM_CITY_INTEGRATION_FAIL")
	quit(0 if failures.is_empty() else 1)
