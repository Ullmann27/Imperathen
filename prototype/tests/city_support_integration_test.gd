extends SceneTree
## Real scene, pointer events, UI commands and shared WorldModel persistence.
## Positions are deliberate test fixtures, not a recorded human playthrough.
const District = preload("res://scripts/city_support_district.gd")
const Trade = preload("res://scripts/city_trade.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var scene
var pictures: Array[Dictionary] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated test account is required.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			output = arg
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)


func _frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame


func _pointer(point: Vector2, pressed: bool, id := 17) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(button: Button) -> void:
	_check(is_instance_valid(button) and not button.disabled, "Requested visible button is usable")
	if not is_instance_valid(button) or button.disabled:
		return
	var point := button.get_global_rect().get_center()
	_pointer(point, true)
	await _frames(1)
	_pointer(point, false)
	await _frames(2)


func _find_button(text: String) -> Button:
	for button: Button in scene.ui.modal.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	seed(20261125)
	scene = District.new()
	scene.auto_load = false
	scene.save_path = "user://city_support_test.json"
	root.add_child(scene)
	await _frames(8)
	print("CITY_SUPPORT_CHECKPOINT ready")
	_check(scene.model._validate_state(scene.model.data).is_empty(), "Scene begins with valid existing WorldModel")
	_check(Trade.enabled(scene.model.data), "Optional city trade is active")
	_check(scene.model.data.player.age == 12, "Free exploration preserves the child")
	_check(scene._shop_anchors.size() == 6, "All six shop anchors exist in the rendered district")
	_check(scene._actors.size() == 7, "Six merchants and the actual player model exist")
	_check(scene._architecture_root.get_child_count() >= 20, "Architecture is actually attached to scene")
	_check(scene.player.is_on_floor(), "Actual CharacterBody rests on physical ground")
	_check(absf(scene.player.position.y) < 0.01, "Player feet meet the visible paving surface")
	var table_ray := PhysicsRayQueryParameters3D.create(Vector3(-9.05, 1.4, -8.25), Vector3(-9.05, 0.1, -8.25), 1)
	var table_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(table_ray)
	_check(not table_hit.is_empty() and absf(float(table_hit.position.y) - 0.85) < 0.01, "Bread has a real table with a matching physical top")
	var curb_ray := PhysicsRayQueryParameters3D.create(Vector3(-18.82, 1.0, 1.0), Vector3(-18.82, -0.1, 1.0), 1)
	var curb_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(curb_ray)
	_check(not curb_hit.is_empty() and absf(float(curb_hit.position.y) - 0.20) < 0.01, "Continuous outer curb has a matching raised surface")
	var start: Vector3 = scene.player.position
	var pad: Control = scene.ui.pad
	var movement_point := pad.get_global_rect().get_center() + Vector2(0, -62)
	_pointer(movement_point, true, 3)
	await _frames(42)
	_check(Vector2(scene.player.position.x - start.x, scene.player.position.z - start.z).length() > 0.30, "A real touch on the movement pad moves the player")
	_check(scene.figure.speed <= 1.46, "Walking stays within the explicit walking speed")
	_pointer(movement_point, false, 3)
	await _frames(24)
	_check(scene._touch_axis.is_zero_approx() and scene.player.velocity.length() < 0.5, "Touch release stops walking")
	_check(scene.player.position.y >= -0.05, "Walking does not fall through the paving")
	print("CITY_SUPPORT_CHECKPOINT movement")
	scene.player.position = Vector3(-10, 0.04, -5.6)
	scene.player.velocity = Vector3.ZERO
	await _frames(8)
	_check(scene._nearest == "bakery", "Nearest real shop is the bakery")
	scene.interact()
	await _frames(3)
	_check(scene.ui.is_open() and scene.ui.shop_id == "bakery", "Interaction opens the actual bakery panel")
	var money_before := int(scene.model.data.resources.denarii)
	var buy: Button = _find_button("Kaufen")
	await _tap(buy)
	_check(int(scene.model.data.resources.denarii) == money_before - 2, "Real UI purchase pays the catalog price")
	_check(int(scene.model.data.village.city_trade.inventory.bread) == 1, "Real UI purchase transfers one bread")
	_check(FileAccess.file_exists(scene.save_path), "Successful UI transaction writes a real separate save")
	print("CITY_SUPPORT_CHECKPOINT purchase")
	var purchases: Dictionary = scene.model.data.village.city_trade.duplicate(true)
	scene.ui.open_inventory()
	await _frames(3)
	_check(scene.ui.inventory_open, "Inventory panel opens")
	var bread_present := false
	for label: Label in scene.ui.contents.find_children("*", "Label", true, false):
		if label.text.contains("Brot"):
			bread_present = true
	_check(bread_present, "Purchased goods are displayed in the inventory")
	scene.ui.close()
	var position_before: Vector3 = scene.player.position
	scene.player.position = Vector3(0, 0.04, 10)
	scene.load_visit()
	await _frames(5)
	_check(scene.model.data.village.city_trade == purchases, "UI load restores the exact saved inventory and receipts")
	_check(Vector2(scene.player.position.x, scene.player.position.z).distance_to(Vector2(position_before.x, position_before.z)) < 0.02, "Load restores the saved location")
	scene.player.position = Vector3(10, 0.04, 6.2)
	scene.player.velocity = Vector3.ZERO
	await _frames(8)
	scene.interact()
	await _frames(2)
	var service: Button = _find_button("Grundausrüstung erhalten · kostenlos")
	_check(is_instance_valid(service) and service.disabled, "Soldier issue stays visibly unavailable for the child")
	print("CITY_SUPPORT_CHECKPOINT saved_inventory")
	var state_before := JSON.stringify(scene.model.data.village.city_trade)
	for profile: String in ["low", "balanced", "high", "very_high"]:
		scene._apply_quality(profile)
		await _frames(2)
		print("CITY_SUPPORT_CHECKPOINT profile=" + profile)
		_check(scene.quality_profile == profile and scene._actors.size() == 7, "Quality keeps all figures: " + profile)
		_check(JSON.stringify(scene.model.data.village.city_trade) == state_before, "Quality cannot change inventory: " + profile)
	scene.ui.close()
	# The open doorway must remain usable after furnishing, not just in an isolated asset.
	var query := PhysicsRayQueryParameters3D.create(Vector3(-10, 0.85, -6.2), Vector3(-10, 0.85, -10.0), 1)
	var doorway: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	_check(doorway.is_empty(), "Integrated bakery entrance is physically unobstructed")
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(2)
	_check(scene._suspended and scene._touch_axis.is_zero_approx(), "Focus loss releases all movement and suspends scene")
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not scene._suspended, "Focus return resumes with no held input")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(output)
		scene.active = false
		scene.ui.hide()
		scene.camera.position = Vector3(18, 12, 18)
		scene.camera.look_at(Vector3(0, 0.8, -2))
		await _capture("01_market_district", "overview", scene.camera)
		scene.camera.position = Vector3(-5, 2.4, -2.1)
		scene.camera.look_at(Vector3(2.4, 1.15, -8.8))
		await _capture("02_shopfront_materials", "eye_level", scene.camera)
		scene.player.position = Vector3(-10, 0.04, -5.6)
		scene.model.set_player_position(scene.player.position)
		scene._nearest = "bakery"
		scene.ui.show()
		scene.ui.update_state(scene.model.data)
		scene.ui.set_nearest("Bäckerei", 2.4)
		scene.interact()
		scene.camera.position = Vector3(-5.7, 3.8, -2.0)
		scene.camera.look_at(Vector3(-10, 1.0, -8.8))
		await _frames(2)
		await _capture("03_real_trade_panel", "purchased_bread", scene.camera)
		scene.ui.close()
		scene.ui.hide()
		scene.camera.position = Vector3(8.8, 1.5, -6.9)
		scene.camera.look_at(Vector3(6.2, 0.65, -8))
		await _capture("04_dolia_and_paving", "material_closeup", scene.camera)
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"pictures":pictures,
		"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"android_device_test":false,
		"test_script_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scene_sha256":FileAccess.get_sha256("res://scripts/city_support_district.gd"),
		"source_note":"Test positioning is explicit; touch movement and purchase use actual input events."}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var file := FileAccess.open(output.path_join("city-support-review.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	var path := ProjectSettings.globalize_path(scene.save_path)
	scene.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	await process_frame
	print("CITY_SUPPORT_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("CITY_SUPPORT_PASS" if failures.is_empty() else "CITY_SUPPORT_FAIL")
	quit(0 if failures.is_empty() else 1)


func _capture(id: String, scenario: String, camera: Camera3D) -> void:
	for index in 3:
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
	var picture: Image = root.get_texture().get_image()
	var filename := id + ".png"
	var saved := picture != null and not picture.is_empty() and picture.save_png(output.path_join(filename)) == OK
	_check(saved, "Real viewport captured: " + id)
	pictures.append({"id":id,"scenario":scenario,"camera":str(camera.global_transform),"fov":camera.fov,
		"image":filename,"sha256":FileAccess.get_sha256(output.path_join(filename)) if saved else "",
		"quality":scene.quality_profile,"pixels":[root.size.x,root.size.y]})

