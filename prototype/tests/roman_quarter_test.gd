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
	for name_in_scene: String in ["Paving", "WorkshopAndTavern", "StreetFountain", "WaxTablet"]:
		_check(quarter.has_node(name_in_scene), name_in_scene + " is present in the playing city")
	var street := await _walk(city, Vector3(28.0, 1.1, 15.5), Vector2(0, -1), 200)
	_check(street.z < 12.0 and street.y > 1.07, "Player walks onto the crowned road from the forum")
	for door_z: float in [-2.4, 2.4]:
		var inside := await _walk(city, Vector3(30.05, 1.15, door_z), Vector2.RIGHT, 180)
		_check(inside.x > 33.5 and absf(inside.y - 1.184) < 0.045, "Player climbs the curb and walks through door at %.1f: %s" % [door_z, inside])
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
	var workshop_hulls := city.find_children("QuarterCollision_*", "StaticBody3D", false, false).size()
	_check(workshop_hulls == 18, "All 18 authored workshop and furniture hulls are live")
	city.free()

	city = City.new()
	city.persist = false
	city.profile = "low"
	root.add_child(city)
	await _frames(8)
	var gravel := city.quarter.find_child("Kiesel_am_Rinnstein", true, false) as GeometryInstance3D
	_check(gravel != null and not gravel.visible, "Light profile omits cosmetic pebbles")
	_check(city.quarter.find_children("*", "StaticBody3D", true, false).size() == structure_count and
		city.find_children("QuarterCollision_*", "StaticBody3D", false, false).size() == workshop_hulls,
		"Light profile preserves every traversable structure and physical hull")
	city.free()
	await _frames(2)
	print("ROMAN_QUARTER_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
