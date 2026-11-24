extends SceneTree
## Gleiche externe Prüfszene auf Basis und Team-B-Stand. Die sozialen Begegnungen
## sind dokumentierte Eingabe-Fixtures; die Bilder stammen aus produktiver Welt/UI.

const Model = preload("res://scripts/domain/world_model.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const World = preload("res://scripts/world/game_world.gd")
const UI = preload("res://scripts/ui/game_ui.gd")
var output := ""
var check_only := false
var shots: Array[Dictionary] = []
var errors: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--check-only":
			check_only = true
	if output.is_empty() or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	if not check_only and DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	seed(20261124)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var model := Model.new()
	model.new_game("italia", true, true)
	model.set_player_position(Vector3(22.0, 0.9, 27.1))
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_quality("balanced")
	world.set_active(true)
	_freeze(world)
	world.set_presentation_time(4.0)
	var camera: Camera3D = world._camera
	camera.position = Vector3(28.5, 3.2, 32.5)
	camera.look_at(Vector3(24.8, 1.0, 25.4))
	camera.fov = 58.0
	camera.current = true
	for figure: Node in get_nodes_in_group("village_people"):
		if world.is_ancestor_of(figure):
			if figure.has_method("refresh_lod"):
				figure.call("refresh_lod", camera)
			if figure.has_method("sample_pose"):
				figure.call("sample_pose", "idle", 0.25)
	world.village_life_world._update_nameplates()
	var ui := UI.new()
	root.add_child(ui)
	ui.set_quality("balanced")
	ui.hide()
	for index in 3:
		await physics_frame
	await _capture("01_market_staff", model.data, camera, "new_childhood_market", ui, world)
	ui.show()
	ui.show_village_panel(model.data, "work")
	await _capture("02_work_panel", model.data, camera, "new_childhood_work_panel", ui, world)
	# Identical reciprocal conversation inputs on both source revisions. No
	# story choice, relationship score or social-memory record is granted by hand.
	model.set_player_position(Vector3(70, 0.9, 70))
	for tick in 16:
		Behavior.observe(model.data, {"julia":{"position":[-12.0,0.0,12.0]},"silvanus":{"position":[-11.0,0.0,12.0]}}, true)
		for id: String in ["julia", "silvanus"]:
			var person: Dictionary = model.data.village.behavior.people[id]
			person.activity = "socialize"
			person.reason = "company"
			person.partner = "silvanus" if id == "julia" else "julia"
			person.social_need = 100.0
			person.fatigue = 5.0
			person.next_decision = float(model.data.world_seconds) + 4.0
		model.advance(0.5)
	ui.show_village_panel(model.data, "people")
	await process_frame
	var scrolls := ui._screen.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		var scroll := scrolls[0] as ScrollContainer
		for label: Label in ui._screen.find_children("*", "Label", true, false):
			if label.text.begins_with("Julia ·"):
				scroll.scroll_vertical = maxi(0, roundi(label.global_position.y - scroll.global_position.y) - 8)
				break
	await _capture("03_social_panel", model.data, camera, "sixteen_mutual_half_second_inputs", ui, world)
	var report := {"passed":errors.is_empty(), "errors":errors, "shots":shots,
		"engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(), "android_device_test":false,
		"review_script_sha256":FileAccess.get_sha256(get_script().resource_path)}
	var file := FileAccess.open(output.path_join("living-world-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	ui.free()
	world.free()
	print("LIVING_WORLD_REVIEW_PASS" if errors.is_empty() else "LIVING_WORLD_REVIEW_FAIL")
	quit(0 if errors.is_empty() else 1)


func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)


func _capture(id: String, data: Dictionary, camera: Camera3D, scenario: String, ui: CanvasLayer, world: Node3D) -> void:
	var labels: PackedStringArray = []
	if ui.visible and is_instance_valid(ui._screen):
		for label: Label in ui._screen.find_children("*", "Label", true, false):
			labels.append(label.text)
	var market_staff: Array[String] = []
	for person: Dictionary in data.village.economy.people:
		if person.assignment == "trade":
			market_staff.append(person.id)
	var record := {"id":id, "scenario":scenario, "quality":"balanced", "presentation_time":4.0,
		"output_pixels":[1280,720], "camera":str(camera.global_transform), "fov":camera.fov,
		"fixture_player_position":data.player.position.duplicate(), "pose":"idle@0.25",
		"market_staff":market_staff, "social_history":data.village.behavior.get("social",{}),
		"antonia_position":str(world.village_life_world.actors.antonia.global_position),
		"all_panel_text_including_scrolled_content": "\n".join(labels), "state_sha256":JSON.stringify(data).sha256_text()}
	if not check_only:
		for frame in 3:
			await process_frame
			RenderingServer.force_draw(true, 1.0 / 60.0)
		var picture := root.get_texture().get_image()
		var filename := id + ".png"
		var path := output.path_join(filename)
		if picture == null or picture.is_empty() or picture.get_size() != Vector2i(1280,720) or picture.save_png(path) != OK:
			errors.append("Bild fehlgeschlagen: " + filename)
		else:
			record.image = filename
			record.image_sha256 = FileAccess.get_sha256(path)
	shots.append(record)
