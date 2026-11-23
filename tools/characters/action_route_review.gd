extends SceneTree
## Continuous automated route in the actual Main. No player placement, canonical
## state injection, replacement colliders or direct technique unlocks are used.

const Entry := preload("res://main.tscn")
const Combat := preload("res://scripts/domain/combat_actions.gd")
const Childhood := preload("res://scripts/story/village_childhood.gd")
const Life := preload("res://scripts/story/village_life.gd")
const STEP := 1.0 / 60.0
var game
var output := ""
var frame := 0
var path_length := 0.0
var maximum_step := 0.0
var trajectory: Array = []
var stations: Array = []
var actions: Array = []
var checks: Array = []
var resident_visit: Dictionary = {}
var failed := false
var previous := Vector2.ZERO
var touch_at := Vector2.ZERO
var touch_down := false
var phase := "start"
var started_at := 0
var requested_quality := "balanced"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated data directory and output folder are required")
		quit(2)
		return
	output = args[0]
	for option in args.slice(1):
		if option.begins_with("--quality="):
			requested_quality = option.trim_prefix("--quality=")
	if requested_quality not in ["low", "balanced"]:
		printerr("Route review supports the existing low and balanced profiles")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	started_at = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	await _create_session()
	game.ui._finish_intro()
	if requested_quality != "balanced":
		_press_named("Einstellungen")
		await process_frame
		var picker := game.ui.find_child("QualitySetting", true, false) as OptionButton
		_check(picker != null, "The actual quality settings control exists")
		if picker == null:
			_finish()
			return
		picker.select(0)
		picker.item_selected.emit(0)
		actions.append({"kind":"actual_settings_option_signal", "quality":"low", "frame":frame})
		_press_named("Zurück")
		await process_frame
	_press_named("Neues Leben")
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_home", "New Life opens the actual family chapter")
	_check(Childhood.enabled(game.model.data), "The real new game contains the optional childhood contract")
	_check(game.world.get_quality_profile() == requested_quality, "The actual game applies the requested quality setting")
	if failed:
		_finish()
		return
	await _station("01_family_opening")
	game.opening_overlay.skip_requested.emit()
	game.opening_overlay.advance_requested.emit()
	await _frames(8)
	_check(game.screen == "playing" and int(game.model.data.player.age) == 12, "The family beginning hands control to the twelve-year-old")
	_check(_at().distance_to(Vector2(-12, 11.7)) < 0.25 and game.world._player.position.y > 1.2, "The player starts on the actual raised family floor")
	var house: Node3D = game.world.regional.get_node_or_null("baker_home")
	_check(house != null and house.get_node_or_null("FamilyHome") != null, "The actual furnished family home is present")
	previous = _at()
	trajectory.append(_sample())
	await _station("02_family_room")
	if not await _travel(Vector2(-13, 12.1), false, "family_room_to_door") or not await _travel(Vector2(-13, 15.2), false, "family_door_exit"):
		_finish()
		return
	_check(_at().y > 14.9 and absf(_at().x + 13.0) < 0.20, "Walking crosses the actual narrow family door and ramp")
	await _look_north()
	await _station("03_family_door_outside")
	if not await _visit_mother():
		_finish()
		return
	if not await _travel(Vector2(-13, 12.1), false, "return_through_family_door") or not await _travel(Vector2(-12, 11.7), false, "family_water_table"):
		_finish()
		return
	_check(game.world._player.position.y > 1.2, "Returning through the door reaches the physical interior floor")
	_tap_action("interact")
	await _frames(6)
	_check(game.model.data.village.childhood.completed == ["mother_morning", "fill_water"], "Only the two actual family actions have advanced the chapter")
	_check(game.model.data.village.childhood.carried.has("water_jug"), "Real interaction at the water point supplies the carried jug")
	await _station("05_family_water")
	if failed:
		_finish()
		return
	await _frames(60)
	# ProvisionStore occupies x=-12.57..-8.63, z=14.30..16.90.
	# Clear its southern corner before turning east; include the .28 m capsule.
	if not await _travel(Vector2(-13, 12.1), false, "family_room_departure") or not await _travel(Vector2(-13, 15.2), false, "family_door_departure") or not await _travel(Vector2(-13, 17.6), false, "clear_store_corner") or not await _travel(Vector2(-7, 18), false, "walk_from_home"):
		_finish()
		return
	await _station("06_walk_from_home")
	if not await _travel(Vector2(0, 15.5), true, "run_south_street") or not await _travel(Vector2(0, 3.5), true, "run_village_square") or not await _travel(Vector2(7, 1), true, "run_across_square") or not await _travel(Vector2(7, -3.5), true, "run_to_training_street"):
		_finish()
		return
	await _station("07_run_square")
	if not await _travel(Vector2(0, -4.5), false, "practice_approach") or not await _travel(Vector2(0, -6.3), false, "practice_contact_distance"):
		_finish()
		return
	await _look_north()
	await _station("08_practice_arrival")
	var initial_hits := int(game.model.data.village.unarmed.practice_hits)
	_check(initial_hits == 0, "The continuous walk grants no invented practice progress")
	for index in 14:
		phase = "earn_techniques_by_contact"
		var before := int(game.model.data.village.unarmed.practice_hits)
		_tap_action("attack")
		await _frames(45)
		_check(int(game.model.data.village.unarmed.practice_hits) == before + 1, "Actual practice contact " + str(index + 1))
		if failed:
			await _station("blocked_practice")
			_finish()
			return
	_check(Combat.available(game.model.data, "high_kick"), "Fourteen actual contacts unlock the final technique")
	for technique: String in ["jab_right", "hook_left", "uppercut_right", "headbutt", "front_kick", "side_kick", "high_kick"]:
		phase = "practice_" + technique
		await _frames(75)
		await _choose_technique(technique)
		var before := int(game.model.data.village.unarmed.practice_hits)
		_tap_action("attack")
		_check(game.model.data.village.unarmed.technique == technique, "The actual UI starts " + technique)
		await _frames(ceili(float(Combat.TECHNIQUES[technique].duration) * 60.0) + 3)
		_check(int(game.model.data.village.unarmed.practice_hits) == before + 1, "Exactly one continuous-session contact for " + technique)
		if failed:
			_finish()
			return
	await _station("09_practice_complete")
	var earned := int(game.model.data.village.unarmed.practice_hits)
	var saved_at := _at()
	var saved_world_id: String = game.model.data.world_id
	var saved_family: Dictionary = game.model.data.village.childhood.duplicate(true)
	phase = "pause_and_save"
	_press_named("Pause")
	await _frames(3)
	_check(game.screen == "paused" and game.world._touch_move == Vector2.ZERO, "Pause releases the actual touch input")
	_press_named("Spiel speichern")
	await _frames(3)
	_check(FileAccess.file_exists(game.SAVE_PATH), "The real pause-menu save creates the campaign file")
	await _station("10_saved_pause")
	game.queue_free()
	await process_frame
	await process_frame
	phase = "restart"
	await _create_session()
	game.ui._finish_intro()
	_press_named("Fortsetzen")
	await _frames(8)
	_check(game.screen == "playing" and int(game.model.data.village.unarmed.practice_hits) == earned, "A new Main instance resumes the earned practice state")
	_check(game.world.get_quality_profile() == requested_quality, "The existing settings save restores the same quality profile")
	_check(game.model.data.world_id == saved_world_id and game.model.data.village.childhood == saved_family, "Restart retains the actual family progress, carried items and world identity")
	_check(_at().distance_to(saved_at) < 0.05, "Restart restores the reached position without another placement")
	_check(game.world._touch_move == Vector2.ZERO and not Combat.busy(game.model.data), "Restart retains no held finger or unfinished strike")
	await _station("11_resumed")
	if not await _travel(Vector2(0, -4.5), false, "walk_after_restart"):
		_finish()
		return
	_check(int(game.model.data.village.unarmed.practice_hits) == earned, "Earned practice survives movement after the restart")
	_check(maximum_step <= 3.8 / 60.0 + 0.02, "Recorded movement contains no horizontal jump beyond the configured running step")
	await _station("12_continued_walk")
	_finish()


func _create_session() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui.set("_touch_enabled", true)


func _travel(goal: Vector2, running: bool, label: String) -> bool:
	phase = label
	if bool(game.ui._running) != running:
		_tap_action("pace")
	var start := _at()
	var recent := start
	var stalled := 0
	var limit := ceili((start.distance_to(goal) / (1.45 if not running else 3.8) + 12.0) * 60.0)
	actions.append({"kind":"travel", "label":label, "from":[start.x,start.y], "goal":[goal.x,goal.y], "running":running, "frame":frame})
	for step in limit:
		var offset := goal - _at()
		if offset.length() < 0.085:
			_release_stick()
			await _frames(12)
			_check(_at().distance_to(goal) < 0.20, "Reached continuous waypoint " + label)
			return not failed
		var amount := clampf(offset.length() / (0.80 if running else 0.36), 0.18, 1.0)
		_stick(offset.normalized() * amount)
		await _frames(1)
		if step % 60 == 59:
			stalled = stalled + 1 if _at().distance_to(recent) < 0.08 else 0
			recent = _at()
			if stalled >= 3:
				_release_stick()
				_check(false, "Physical obstruction on " + label + " at " + str(_at()))
				await _station("blocked_" + label)
				return false
	_release_stick()
	_check(false, "Timed out reaching " + label + " at " + str(_at()))
	await _station("blocked_" + label)
	return false


func _stick(world_axis: Vector2) -> void:
	var pad: Control = game.ui._touch_pad
	var local := Vector3(world_axis.x, 0, world_axis.y).rotated(Vector3.UP, -float(game.world._camera_yaw))
	var axis := Vector2(local.x, local.z)
	var radius := maxf(24.0, minf(pad.size.x, pad.size.y) * 0.5 - 35.0)
	var magnitude := 0.12 + axis.length() * 0.88
	var point := pad.get_global_transform_with_canvas() * (pad.size * 0.5 + axis.normalized() * radius * magnitude)
	if not touch_down:
		_touch(51, true, pad.get_global_rect().get_center())
		touch_down = true
		touch_at = pad.get_global_rect().get_center()
	var event := InputEventScreenDrag.new()
	event.index = 51
	event.position = point
	event.relative = point - touch_at
	root.push_input(event, true)
	touch_at = point


func _release_stick() -> void:
	if touch_down:
		_touch(51, false, touch_at)
		touch_down = false


func _tap_action(action: String) -> void:
	for button: Button in game.ui._touch_actions:
		if str(button.get_meta("touch_action", "")) == action and button.is_visible_in_tree():
			var point := button.get_global_rect().get_center()
			_touch(52, true, point)
			_touch(52, false, point)
			actions.append({"kind":"native_touch_action", "action":action, "frame":frame})
			return
	_check(false, "Visible touch action missing: " + action)


func _press_named(prefix: String) -> void:
	for button: Button in game.ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled and button.text.begins_with(prefix):
			button.pressed.emit()
			actions.append({"kind":"actual_menu_button_signal", "button":button.text, "frame":frame})
			return
	_check(false, "Visible menu button missing: " + prefix)


func _choose_technique(id: String) -> void:
	_tap_action("techniques")
	await _frames(3)
	var button := game.ui._technique_menu_layer.find_child("Technique_" + id, true, false) as Button
	_check(button != null and not button.disabled, "The actual menu enables earned technique " + id)
	if button != null and not button.disabled:
		button.pressed.emit()
		actions.append({"kind":"actual_technique_button_signal", "technique":id, "frame":frame})
	await _frames(2)


func _visit_mother() -> bool:
	phase = "mother_conversation"
	var position: Vector2 = Life.actor_position(game.model.data, "antonia")
	var resident: Node3D = game.world.village_life_world.actors.get("antonia")
	var distance := _at().distance_to(position)
	_check(resident != null and resident.visible and distance <= Childhood.NPC_RANGE, "The real mother is present within the reached conversation range")
	resident_visit = {"npc_id":"antonia", "position":[position.x,position.y], "player_position":_sample().position, "horizontal_distance_m":distance, "house":"baker_home/FamilyHome", "house_interior_visited":true, "occupancy_scope":"Authored family home, actual mother and father in the shared roster; no invented household assignment field."}
	if failed:
		return false
	_tap_action("interact")
	await _frames(3)
	_check(game.screen == "village_dialog" and game.village_npc == "antonia", "Native interaction opens the actual Antonia conversation")
	if failed:
		return false
	await _native_press_named("Mit Mutter den Morgen besprechen")
	await _frames(6)
	_check(game.model.data.village.childhood.completed == ["mother_morning"], "The native dialogue choice advances exactly the first family action")
	_check(game.model.data.village.childhood.carried.has("household_coin"), "The genuine mother conversation supplies the reserved household coin")
	await _station("04_mother_conversation")
	if failed:
		return false
	_press_named("Gespräch beenden")
	await _frames(3)
	_check(game.screen == "playing", "Closing the actual conversation returns to the same continuous route")
	return not failed


func _native_press_named(prefix: String) -> void:
	for button: Button in game.ui.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled and button.text.begins_with(prefix):
			var point := button.get_global_rect().get_center()
			var down := InputEventScreenTouch.new()
			down.index = 54
			down.pressed = true
			down.position = point
			Input.parse_input_event(down)
			await process_frame
			var up := InputEventScreenTouch.new()
			up.index = 54
			up.pressed = false
			up.position = point
			Input.parse_input_event(up)
			actions.append({"kind":"native_dialogue_touch", "button":prefix, "frame":frame})
			await process_frame
			return
	_check(false, "Visible native dialogue choice missing: " + prefix)


func _look_north() -> void:
	var point := Vector2(860, 250)
	_touch(53, true, point)
	var event := InputEventScreenDrag.new()
	event.index = 53
	event.relative = Vector2(wrapf(float(game.world._camera_yaw), -PI, PI) / 0.006, 0)
	event.position = point + event.relative
	root.push_input(event, true)
	_touch(53, false, event.position)
	await _frames(10)


func _touch(index: int, down: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = down
	event.position = at
	root.push_input(event, true)


func _frames(count: int) -> void:
	for step in count:
		await physics_frame
		game._physics_process(STEP)
		game.world._physics_process(STEP)
		game._process(STEP)
		frame += 1
		var at := _at()
		if frame > 8:
			var distance := at.distance_to(previous)
			path_length += distance
			maximum_step = maxf(maximum_step, distance)
		previous = at
		if frame % 6 == 0:
			trajectory.append(_sample())


func _at() -> Vector2:
	return Vector2(game.world._player.position.x, game.world._player.position.z)


func _sample() -> Dictionary:
	var at := _at()
	var velocity: Vector3 = game.world._player.get_real_velocity()
	return {"frame":frame, "simulation_seconds":frame * STEP, "phase":phase, "position":[at.x, game.world._player.position.y, at.y], "real_velocity":[velocity.x,velocity.y,velocity.z], "touch_axis":[game.world._touch_move.x,game.world._touch_move.y], "running":bool(game.ui._running), "screen":game.screen, "practice_hits":game.model.data.village.get("unarmed", {}).get("practice_hits", 0)}


func _station(label: String) -> void:
	var result := _sample()
	result.label = label
	if DisplayServer.get_name() != "headless":
		for draw in 3:
			await process_frame
			RenderingServer.force_draw(true, STEP)
		var picture := root.get_texture().get_image()
		var filename := label + ".png"
		_check(picture != null and not picture.is_empty() and picture.save_png(output.path_join(filename)) == OK, "Actual route image " + label)
		result.image = filename
	stations.append(result)
	_write_report(false)
	print("ROUTE_STATION ", JSON.stringify(result))


func _check(ok: bool, message: String) -> void:
	checks.append({"ok":ok, "message":message})
	if not ok:
		failed = true
		printerr("FAIL: " + message)


func _finish() -> void:
	_release_stick()
	_write_report(true)
	game.queue_free()
	print("ACTION_ROUTE_REVIEW_FAIL" if failed else "ACTION_ROUTE_REVIEW_PASS")
	quit(1 if failed else 0)


func _write_report(completed: bool) -> void:
	var report := {"engine":Engine.get_version_info().string, "renderer":RenderingServer.get_current_rendering_method(), "adapter":RenderingServer.get_video_adapter_name(), "android_device_test":false, "automated_route":true, "teleport_fixtures":false, "state_injection":false, "fixed_physics_step_seconds":STEP, "simulation_seconds":frame * STEP, "wall_seconds":float(Time.get_ticks_msec()-started_at)/1000.0, "path_length_m":path_length, "maximum_horizontal_step_m":maximum_step, "checks":checks, "completed":completed, "passed":completed and not failed, "stations":stations, "actions":actions, "trajectory":trajectory, "resident_visit":resident_visit, "house_scope":"Actual family home interior, narrow doorway and ramp, Antonia conversation and a real water errand. No household assignment schema is invented."}
	report.route_version = "family_continuous_v1"
	report.childhood_progress = game.model.data.village.get("childhood", {}).duplicate(true)
	report.capture_mode = "actual_engine_station_frames" if DisplayServer.get_name() != "headless" else "headless"
	report.continuous_render_loop = RenderingServer.is_render_loop_enabled()
	report.quality_profile = game.world.get_quality_profile()
	var file := FileAccess.open(output.path_join("action-route-review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
