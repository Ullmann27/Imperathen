extends SceneTree
## The valley HUD offers the new orders and issues them through the real menu and tap paths.

const Valley := preload("res://scripts/tactics/valley_scene.gd")
const NEW_ORDERS := ["follow", "advance", "fall_back", "face", "charge", "pila", "fire_at_will"]

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _menus(v) -> Dictionary:
	var menus := {}
	for child in v.hud.command_row.get_children():
		if child is MenuButton:
			menus[child.text] = child
	return menus


func _ids(menu: MenuButton) -> Array:
	var ids := []
	var popup := menu.get_popup()
	for i in popup.item_count:
		ids.append(popup.get_item_metadata(i))
	return ids


func _pixel(v, id: String) -> Vector2:
	var s: Dictionary = v.model.squads[id]
	return v.camera.unproject_position(v._surface(Vector2(s.x, s.z)) + Vector3.UP * 0.65)


func _run() -> void:
	var v := Valley.new()
	root.add_child(v)
	v.set_process(false)
	await process_frame
	await process_frame
	var menus := _menus(v)
	check(menus.has("Bewegung ▾") and menus.has("Kampf ▾") and menus.has("Formation ▾"), "Movement, combat and formation menus exist")
	var offered := []
	for menu: MenuButton in menus.values():
		offered.append_array(_ids(menu))
	for order in NEW_ORDERS + ["orbis", "testudo", "hold", "rally", "cease_fire", "focus_fire"]:
		check(order in offered, "The HUD offers " + order)
	var smallest := INF
	for menu: MenuButton in menus.values():
		var popup := menu.get_popup()
		var content := popup.get_contents_minimum_size().y
		smallest = minf(smallest, content / maxi(1, popup.item_count))
		check(menu.custom_minimum_size.y >= 40, "Menu button keeps the 40 px touch height: " + menu.text)
	check(smallest >= 40.0, "Every menu row is at least 40 px tall (%.1f px)" % smallest)
	var model = v.model
	v._select("valley_guard", false)
	v._action("command", "fall_back")
	check(model.squads.valley_guard.command == "fall_back", "Choosing fall back issues it to the selected company")
	v._action("command", "hold")
	v._action("command", "charge")
	check(v.pending == "charge" and model.squads.valley_guard.command == "hold", "Charge waits for a target")
	v._tap(_pixel(v, "ridge_guard"), false, false)
	check(model.squads.valley_guard.command == "charge" and model.squads.valley_guard.target == "ridge_guard" and v.pending == "", "Tapping an enemy company charges it")
	v._select("valley_spears", false)
	v._action("command", "follow")
	v._tap(_pixel(v, "valley_guard"), false, false)
	check(model.squads.valley_spears.command == "follow" and model.squads.valley_spears.target == "valley_guard", "Tapping a friendly company makes the selection follow it")
	v._select("valley_guard", false)
	v._action("command", "hold")
	v._action("command", "face")
	var east: Vector2 = v.camera.unproject_position(v._surface(Vector2(model.squads.valley_guard.x + 8, model.squads.valley_guard.z)))
	v._tap(east, false, false)
	check(model.squads.valley_guard.command == "face", "Tapping the ground turns the company to face it")
	v._action("command", "pila")
	v._tap(_pixel(v, "ridge_guard"), false, false)
	check(model.squads.valley_guard.command == "pila", "Pila are thrown at a tapped enemy")
	v._select("valley_bows", false)
	v._action("command", "cease_fire")
	v._action("command", "fire_at_will")
	check(model.squads.valley_bows.fire, "Fire at will resumes free shooting")
	v._select("valley_guard", false)
	v._action("form", "orbis")
	model.tick(2.0)
	v._select("valley_guard", false)
	check(model.squads.valley_guard.formation == "orbis" and v.message.contains("Kreis"), "The orbis is formed from the formation menu and named in the status line")
	v._action("command", "advance")
	check(not v.message.is_empty() and model.squads.valley_guard.command != "advance", "A refused order reports why instead of acting")
	print("VALLEY_ORDERS_RESULT checks=%d failures=%d smallest_row_px=%.1f" % [checks, failures, smallest])
	v.free()
	quit(1 if failures else 0)
