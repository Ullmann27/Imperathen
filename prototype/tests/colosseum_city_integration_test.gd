extends SceneTree
const City = preload("res://scripts/world/city_exploration.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
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
	print("COLOSSEUM_CITY_INTEGRATION_PASS" if failures.is_empty() else "COLOSSEUM_CITY_INTEGRATION_FAIL")
	quit(0 if failures.is_empty() else 1)
