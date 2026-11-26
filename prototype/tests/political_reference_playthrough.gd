extends SceneTree
## Both Valdora recommendations through Main, physical movement, the world
## interaction and the rendered dialogue's buttons. Starts from the existing
## migrated I-02 fixture so I-01 need not be replayed for each independent case.
## IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 \
##   --script res://tests/political_reference_playthrough.gd
## Optional: -- --capture-dir=/absolute/path (requires a graphical viewport).

const Main = preload("res://main.tscn")
const Life = preload("res://scripts/story/village_life.gd")
const Clock = preload("res://scripts/domain/world_clock.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
const SAVE := "user://imperathen_campaign.json"
const WOOD_COST := 4
const SOUTH_PATH := Vector2(0, 17)
const DECIMUS := Vector2(0, 9)
const TIMBER := Vector2(-8.0, 2.0)
var game
var checks := 0
var failures: Array[String] = []
var captures: Array[String] = []
var cases: Dictionary = {}
var capture_dir := ""


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Der Dialogtest benötigt isolierte Einstellungen und Spielstände.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			RenderingServer.render_loop_enabled = false
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	game = Main.instantiate()
	root.add_child(game)
	await _frames()
	game.ui._finish_intro()
	await _frames()
	for route: String in ["road", "wood"]:
		if await _load_start():
			await _play(route)
	print("POLITICAL_REFERENCE_PLAYTHROUGH ", JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "captures": captures}))
	if not capture_dir.is_empty():
		RenderingServer.render_loop_enabled = true
	game.free()
	quit(0 if failures.is_empty() else 1)


func _load_start() -> bool:
	game._show_menu()
	var fixture := FileAccess.get_file_as_string(FIXTURE)
	if not check(not fixture.is_empty(), "Existing I-02 save fixture is available"):
		return false
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	if not check(file != null, "The isolated user save can be prepared"):
		return false
	file.store_string(fixture)
	file.close()
	game.ui.action_requested.emit("continue", {})
	await _frames()
	if not check(game.screen == "playing" and Clock.year(game.model.data) == -58 and game.model.data.player.age == 12,
			"Main loads the actual Valdora campaign, age twelve, 58 BC"):
		return false
	game.ui.action_requested.emit("quality_changed", {"profile": "low"})
	var village: Node3D = game.world.village_life_world
	var room := village.get_node_or_null("ValdoraCouncilRoom") as Node3D
	check(room != null and room.is_visible_in_tree() and not room.find_children("*", "StaticBody3D", true, false).is_empty(),
		"The playable village has the visible council room and its imported collision")
	check(village.get_node_or_null("LooseSouthRoadBoards") != null, "Broken boards exist at the actual south road")
	var actor: Node3D = village.actors.get("decimus")
	return check(actor != null and actor.is_visible_in_tree(), "Decimus has a visible actor in the playable village")


func _play(route: String) -> void:
	var context := {"walked_m": 0.0}
	if not await _walk([Vector2(4, 17), Vector2(0, 13), DECIMUS], context) or not await _open_decimus():
		return
	check(Life.relationship(game.model.data, "decimus").met, "The first conversation is recorded in Valdora")
	check(game.world.get("_village_focus") == "decimus", "The 3D conversation camera focuses the existing Decimus actor")
	check(_dialog_choice("politics_audience", {}) == null or _dialog_choice("politics_audience", {}).disabled,
		"Decimus cannot offer an active public audience to a child")
	check(game.model.politics_view().recommendation.is_empty(), "An introduction alone does not grant a recommendation")
	await _capture(route + "-01-decimus")
	if not await _close_dialog():
		return

	if route == "road":
		if not await _walk([Vector2(0, 13), SOUTH_PATH], context):
			return
		var before := _events().size()
		await _interact()
		check(_events().size() == before + 1 and _events().back().id == "valdora.road.survey",
			"The in-world survey at the south path records its observation")
		await _capture(route + "-02-suedweg")
		if not await _walk([Vector2(0, 13), DECIMUS], context):
			return
	else:
		var before := int(game.model.data.resources.wood)
		if not await _walk([Vector2(0, 6.5), Vector2(-4.0, 5.2), Vector2(-5.5, 2.5), TIMBER], context):
			return
		await _interact()
		check(int(game.model.data.resources.wood) == before + WOOD_COST, "The four pieces of wood are collected with the ordinary world interaction")
		if not await _walk([Vector2(-5.5, 2.5), Vector2(-4.0, 5.2), Vector2(0, 6.5), DECIMUS], context):
			return
	if not await _open_decimus():
		return

	var cost_before := int(game.model.data.resources.wood)
	var event_count := _events().size()
	var button := _dialog_choice("politics_help", {"route":route})
	if not check(button != null and not button.disabled, "A visible and enabled answer offers the route " + route):
		return
	await _capture(route + "-03-auswahl")
	button.pressed.emit()
	await _frames()
	var signature := JSON.stringify(JSON.parse_string(JSON.stringify(_events())))
	check(_events().size() == event_count + 1 and _events().back().id == "valdora.decimus." + route + "_help",
		"The real dialogue answer records the one matching recommendation event")
	var recommendation: Dictionary = game.model.politics_view().recommendation
	check(recommendation.get("route") == route and recommendation.get("issuer") == "vil:decimus" and not recommendation.get("audience", true),
		"The result is Decimus's local recommendation and carries no granted audience")
	check(int(game.model.data.resources.wood) == cost_before - (WOOD_COST if route == "wood" else 0),
		"Only the materials route consumes wood")
	var alternative := _dialog_choice("politics_help", {"route":"road" if route == "wood" else "wood"})
	check(alternative == null or alternative.disabled, "The other route cannot duplicate the recommendation")
	await _capture(route + "-04-empfehlung")
	if not await _close_dialog():
		return
	game.ui.action_requested.emit("save", {})
	await _frames()
	game._show_menu()
	await _frames()
	game.ui.action_requested.emit("continue", {})
	await _frames()
	check(game.screen == "playing" and JSON.stringify(JSON.parse_string(JSON.stringify(_events()))) == signature and _events().size() == event_count + 1,
		"The unique local recommendation survives a real save and Continue")
	cases[route] = {"walked_m": snappedf(float(context.walked_m), 0.01), "recommendation": recommendation, "events": _events().duplicate(true)}
	var planks := game.world.village_life_world.get_node_or_null("SuppliedSouthRoadBoards") as Node3D
	check(planks != null and planks.is_visible_in_tree() == (route == "wood"),
		"Only the committed materials route places replacement wood beside the road after reload")
	if not await _walk([Vector2(7, 11), Vector2(13.9, 9.5), Vector2(17.2, 9.5), Vector2(19.1, 9.5), Vector2(19.45, 11.44)], context):
		return
	await _interact()
	var text := str(game.ui.get("_frontier_dialog_data").get("text", ""))
	check(game.screen == "village_dialog" and game.village_npc.is_empty() and
		text.contains(str(recommendation.date)) and text.contains("Empfehlung von Decimus") and
		text.contains(str(game.model.politics_view().learning)),
		"The player's actual world interaction reads the dated authoritative entry at the council desk")
	await _capture(route + "-05-amtstafel")
	await _close_dialog()


func _open_decimus() -> bool:
	await _interact()
	return check(game.screen == "village_dialog" and game.village_npc == "decimus",
		"The actual world interaction opens Decimus' conversation")


func _interact() -> void:
	game.ui.action_requested.emit("interact", {})
	await _frames()


func _close_dialog() -> bool:
	var close := game.ui.find_child("FrontierConversationClose", true, false) as Button
	if not check(close != null and close.is_visible_in_tree(), "The conversation has a visible close button"):
		return false
	close.pressed.emit()
	await _frames()
	return check(game.screen == "playing", "The dialogue hands back to the player camera")


func _dialog_choice(command: String, args: Dictionary) -> Button:
	for child: Node in game.ui.find_children("*", "Button", true, false):
		var button := child as Button
		if button.is_visible_in_tree() and button.get_meta("village_command", "") == command and button.get_meta("village_args", {}) == args:
			return button
	return null


func _events() -> Array:
	return game.model.data.get("world_state", {}).get("politics", {}).get("events", [])


func _walk(waypoints: Array, stats: Dictionary) -> bool:
	var player := game.world.get_node("Player") as CharacterBody3D
	for point: Vector2 in waypoints:
		var last := Vector2(player.global_position.x, player.global_position.z)
		var sidestep := 0
		var stopped := 0
		var side := 1.0
		for frame in 60 * 24:
			var offset := point - last
			if offset.length() <= 0.22:
				break
			var direction := Vector3(offset.x, 0.0, offset.y).normalized()
			if sidestep > 0:
				direction = direction.rotated(Vector3.UP, side * deg_to_rad(67.0))
				sidestep -= 1
			var axis := direction.rotated(Vector3.UP, -float(game.world.get("_camera_yaw")))
			game.ui.action_requested.emit("move_axis", {"x":axis.x, "y":axis.z})
			await physics_frame
			var now := Vector2(player.global_position.x, player.global_position.z)
			var travelled := now.distance_to(last)
			stats.walked_m = float(stats.walked_m) + travelled
			stopped = stopped + 1 if travelled < 0.003 else 0
			last = now
			if stopped > 22 and sidestep == 0:
				sidestep = 44
				stopped = 0
				side = -side
		if not check(last.distance_to(point) <= 0.22, "The physical route reaches %s from %s" % [point, last]):
			game.ui.action_requested.emit("move_axis", {"x":0.0, "y":0.0})
			return false
	game.ui.action_requested.emit("move_axis", {"x":0.0, "y":0.0})
	for frame in 20:
		await physics_frame
	return true


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	RenderingServer.render_loop_enabled = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if check(image != null and not image.is_empty() and image.save_png(capture_dir.path_join(label + ".png")) == OK, "Engine capture " + label):
		captures.append(label + ".png")
	RenderingServer.render_loop_enabled = false


func _frames() -> void:
	for frame in 6:
		await process_frame


func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		printerr("POLITICAL_REFERENCE_FAIL ", message)
	return value
