extends SceneTree

const City := preload("res://scripts/world/city_exploration.gd")
const Quarter := preload("res://scripts/world/roman_quarter.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _walk(city: Node3D, start: Vector3, axis: Vector2, count: int) -> Vector3:
	city.teleport(start)
	await _frames(14)
	city._touch_move = axis
	await _frames(count)
	city._touch_move = Vector2.ZERO
	return city.player.position


func _run() -> void:
	var city := City.new()
	city.persist = false
	city.profile = "balanced"
	root.add_child(city)
	await _frames(12)
	_check(city.city_available and is_instance_valid(city.quarter), "Normal city entry loads the installed quarter")
	if not is_instance_valid(city.quarter):
		quit(1)
		return
	var quarter := city.quarter
	for name_in_scene: String in ["Paving", "WorkshopAndTavern", "StreetDomus", "StreetFountain", "WaxTablet", "NorthJunction", "StableYard"]:
		_check(quarter.has_node(name_in_scene), name_in_scene + " is present in the playing city")
	var street := await _walk(city, Vector3(28.0, 1.1, 15.5), Vector2(0, -1), 200)
	_check(street.z < 12.0 and street.y > 1.07, "Player walks onto the crowned road from the forum")
	_check(quarter.street_at(street) == "Handwerksgasse · Vicus Fabrum", "Street has its in-world location name")
	var north := await _walk(city, Vector3(28.0, 1.15, -10.5), Vector2(0, -1), 500)
	_check(north.z < -21.0 and city._street_caption.begins_with("Zum Nordmarkt"),
		"Player crosses the new physical junction towards the north market: %s" % north)
	for side: float in [-1.0, 1.0]:
		var turn := await _walk(city, Vector3(28.0, 1.16, -17.0), Vector2(side, 0), 245)
		_check((turn.x - 28.0) * side > 5.1 and city._street_caption.begins_with("Töpfergasse"),
			"Player can enter the east and west arms of the named cross street: %s" % turn)
	_check(quarter.street_at(Vector3(0.0, 1.0, 0.0)).is_empty(), "Unauthored ground has no fabricated street name")
	var stable := quarter.get_node("StableYard") as Node3D
	var courtyard := await _walk(city, stable.to_global(Vector3(0.0, 1.05, 1.3)), Vector2.RIGHT, 265)
	_check(stable.to_local(courtyard).z < -2.7 and courtyard.y > 0.99,
		"Actual stable gate opens into the yard up to the central post: %s" % courtyard)
	var stall := await _walk(city, stable.to_global(Vector3(-1.72, 1.04, -2.65)), Vector2.RIGHT, 130)
	_check(stable.to_local(stall).z < -5.1, "Walk alongside the post and reach an individual horse stall: %s" % stall)
	city.teleport(quarter.stable_trader.global_position)
	await _frames(14)
	_check(city._trade_button.text == "Pferdehandel" and city.market.nearest().id == "equarius",
		"Seller anchor is reachable inside the physical stable yard")
	city._trade_button.pressed.emit()
	await _frames(2)
	_check(city.market.is_open() and city.market.panel.shop_id == "equarius",
		"Normal trade input opens the same authoritative market at the yard")
	var denied: Dictionary = city.market.execute("city_buy", {"shop_id": "equarius", "item_id": "horse_fara", "quantity": 1})
	_check(not denied.get("ok", false) and city.market.model.data.player.age == 12,
		"Childhood does not unlock independent purchase")
	city.market.close()
	for door_z: float in [-2.4, 2.4]:
		var inside := await _walk(city, Vector3(30.05, 1.15, door_z), Vector2.RIGHT, 180)
		_check(inside.x > 33.5 and absf(inside.y - 1.184) < 0.045, "Player climbs the curb and walks through door at %.1f: %s" % [door_z, inside])
	for door_z: float in [0.8, 4.9]:
		var inside := await _walk(city, Vector3(25.9, 1.15, door_z), Vector2.LEFT, 155)
		_check(inside.x < 22.7 and absf(inside.y - 1.184) < 0.075, "Player crosses the opposite sidewalk through the house at %.1f: %s" % [door_z, inside])
	var blocked := await _walk(city, Vector3(31.1, 1.2, 0.0), Vector2.RIGHT, 90)
	_check(blocked.x < 32.5 and blocked.x > 31.7, "Same movement is blocked by the facade between doors")
	var fountain := await _walk(city, Vector3(25.1, 1.17, -4.3), Vector2.LEFT, 120)
	_check(fountain.x > 23.37 and fountain.x < 24.1, "Fountain basin physically blocks character movement: %s" % fountain)
	_check(not quarter.tablet_reachable(city.player), "Tablet cannot be read from the street")
	city.teleport(Quarter.ORIGIN + Quarter.TABLET_APPROACH)
	await _frames(12)
	_check(quarter.tablet_reachable(city.player) and city._trade_button.text == "Tafel lesen", "Physical interaction reaches the tablet from in front of the counter")
	city._trade_button.pressed.emit()
	_check(city._tablet_dialog.visible and not city.market.is_open(), "Touch interaction reads the tablet in the real city HUD")
	var stationary := city.player.position
	await _frames(8)
	_check(city.player.position == stationary, "Reading preserves character position")
	city._tablet_dialog.hide()
	await _frames(2)
	_check(not city._tablet_dialog.visible and city.quarter == quarter, "Dismiss returns to the same city")
	var structure_count := quarter.find_children("*", "StaticBody3D", true, false).size()
	var workshop_hulls := city.find_children("QuarterCollision_WorkshopAndTavern_*", "StaticBody3D", false, false).size()
	_check(workshop_hulls == 18, "All 18 authored workshop and furniture hulls are live")
	var domus_hulls := city.find_children("QuarterCollision_StreetDomus_*", "StaticBody3D", false, false).size()
	_check(domus_hulls > 8, "Street domus has a floor and walls rather than empty facade")
	var junction_hulls := city.find_children("QuarterCollision_NorthJunction_*", "StaticBody3D", false, false).size()
	_check(junction_hulls > 25, "Contiguous junction has real streets and collidable corner houses")
	var stable_hulls := city.find_children("QuarterCollision_StableYard_*", "StaticBody3D", false, false).size()
	_check(stable_hulls > 0, "Stable installation includes the authored physical envelope")
	city.free()

	for profile: String in ["low", "high", "very_high"]:
		city = City.new()
		city.persist = false
		city.profile = profile
		root.add_child(city)
		await _frames(8)
		var gravel := city.quarter.find_child("Kiesel_am_Rinnstein", true, false) as GeometryInstance3D
		var cosmetic_distance := {"low": 0.0, "high": 29.0, "very_high": 0.0}
		_check(gravel != null and gravel.visible == (profile != "low") and
			is_equal_approx(gravel.visibility_range_end, cosmetic_distance[profile]),
			"Profile %s controls cosmetic pebbles" % profile)
		_check(city.quarter.find_children("*", "StaticBody3D", true, false).size() == structure_count and
			city.find_children("QuarterCollision_*", "StaticBody3D", false, false).size() == workshop_hulls + domus_hulls + junction_hulls + stable_hulls,
			"Profile %s preserves every traversable structure and physical hull" % profile)
		city.free()
	await _frames(2)
	print("ROMAN_QUARTER_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
