extends "res://tests/city_support_integration_test.gd"
## Fresh graphical review. Full behavior and all profile changes are tested
## separately by city_support_integration_test.gd; this is no Android benchmark.


func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		printerr("This review requires a real graphics backend and an output directory.")
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	seed(20261125)
	scene = District.new()
	scene.auto_load = false
	scene.quality_profile = "very_high"
	scene.save_path = "user://city_support_graphics_test.json"
	root.add_child(scene)
	await _frames(4)
	scene.active = false
	_check(scene.model._validate_state(scene.model.data).is_empty(), "Rendered district uses a valid WorldModel")
	_check(scene.model.data.player.age == 12, "Graphical review preserves the child")
	_check(scene._actors.size() == 7, "Actual player and six merchants are attached")
	_check(scene.quality_profile == "very_high", "Review uses the declared quality profile")
	scene.player.position = Vector3(-10, 0.04, -5.6)
	scene.model.set_player_position(scene.player.position)
	scene._nearest = "bakery"
	scene.ui.set_nearest("Bäckerei", 2.4)
	scene.interact()
	await _frames(2)
	var money_before: int = scene.model.data.resources.denarii
	await _tap(_find_button("Kaufen"))
	_check(scene.model.data.resources.denarii == money_before - 2, "Graphical touch purchase transfers real money")
	_check(scene.model.data.village.city_trade.inventory.get("bread", 0) == 1, "Graphical touch purchase transfers real bread")
	_check(FileAccess.file_exists(scene.save_path), "Graphical transaction creates its isolated save")
	scene.ui.close()
	scene.ui.hide()
	DirAccess.make_dir_recursive_absolute(output)
	var requested := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			requested = arg.trim_prefix("--view=")
	var views: Array[Dictionary] = [
		{"id":"01_market_district", "scenario":"overview", "from":Vector3(18,12,18), "to":Vector3(0,0.8,-2)},
		{"id":"02_shopfront_materials", "scenario":"eye_level", "from":Vector3(-5,2.4,-2.1), "to":Vector3(2.4,1.15,-8.8)},
		{"id":"03_real_trade_panel", "scenario":"purchased_bread", "from":Vector3(-5.7,3.8,-2), "to":Vector3(-10,1,-8.8)},
		{"id":"04_dolia_and_paving", "scenario":"material_closeup", "from":Vector3(8.8,1.5,-6.9), "to":Vector3(6.2,0.65,-8)},
	]
	for view: Dictionary in views:
		if not requested.is_empty() and view.id != requested:
			continue
		if view.id == "03_real_trade_panel":
			scene.ui.show()
			scene.ui.update_state(scene.model.data)
			scene.interact()
		else:
			scene.ui.close()
			scene.ui.hide()
		scene.camera.position = view.from
		scene.camera.look_at(view.to)
		await _capture(view.id, view.scenario, scene.camera)
		print("CITY_SUPPORT_GRAPHICS_CAPTURE " + str(view.id))
	_check(not pictures.is_empty(), "At least one requested real viewport was captured")
	var report := {
		"passed":failures.is_empty(), "checks":checks, "failures":failures, "pictures":pictures,
		"engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(), "android_device_test":false,
		"test_script_sha256":FileAccess.get_sha256(get_script().resource_path),
		"scene_sha256":FileAccess.get_sha256("res://scripts/city_support_district.gd"),
		"scope":"Fresh graphical scene and actual touch purchase. Full behavior and quality transitions are verified in the separate integration test.",
		"source_note":"Camera and shop positions are explicit review fixtures. Images come from the actual Godot viewport.",
	}
	var file := FileAccess.open(output.path_join("city-support-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	var save := ProjectSettings.globalize_path(scene.save_path)
	scene.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save + suffix):
			DirAccess.remove_absolute(save + suffix)
	await process_frame
	print("CITY_SUPPORT_GRAPHICS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("CITY_SUPPORT_GRAPHICS_PASS" if failures.is_empty() else "CITY_SUPPORT_GRAPHICS_FAIL")
	quit(0 if failures.is_empty() else 1)
