extends SceneTree
## Real touch capture, world physics and imported skeletal gait during UI refresh.
## Fixture placements isolate the work station and a clear walking area.

const Entry := preload("res://main.tscn")
const Childhood := preload("res://scripts/story/village_childhood.gd")
const Life := preload("res://scripts/story/village_life.gd")
var game
var checks := 0
var failures: Array[String] = []
var metrics := {}


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Locomotion regression requires disposable user directories.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui._touch_enabled = true
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	game._opening_skip()
	game._opening_next()
	game._opening_skip()
	# I-01 VID-A waits for the player's morning choice (screenplay v4).
	game.opening_overlay.choice_requested.emit("i01_yard")
	game._opening_skip()
	game._opening_next()
	await _frames(5)
	_check(game.screen == "playing" and Childhood.enabled(game.model.data), "Production openings hand a new child to the actual game")

	# A single down event must continue to drive the body and the animated skin.
	_place(Vector3(63, 0.92, 40))
	await _frames(5)
	var pad: Control = game.ui._touch_pad
	var held := pad.get_global_rect().get_center() + Vector2(0, -pad.size.y * 0.38)
	_touch(held, 3, true)
	await _frames(120)
	var walking_speed := _speed()
	var walking_distance := 40.0 - float(game.world._player.position.z)
	_check(pad.touch_index == 3 and game.world._touch_move.y < -0.99, "Held native finger survives repeated model and HUD refreshes without drag events")
	_check(absf(walking_speed - 1.45) < 0.04 and walking_distance > 2.4, "Held touch moves the actual CharacterBody at walking speed")
	_check(game.world._figure.clip == "march", "Actual displacement selects the walking clip")
	var rig: Skeleton3D = game.world._figure._motion.skeleton
	var foot: int = rig.find_bone("Foot_R")
	var before_foot: Vector3 = rig.get_bone_global_pose(foot).origin
	await _frames(13)
	_check(rig.get_bone_global_pose(foot).origin.distance_to(before_foot) > 0.035, "Imported foot bones change throughout the held walk")
	var run_button := _action_button("pace")
	_check(run_button != null, "Running has a real touch control")
	if run_button != null:
		_touch(run_button.get_global_rect().get_center(), 4, true)
		_touch(run_button.get_global_rect().get_center(), 4, false)
	await _frames(90)
	var running_speed := _speed()
	_check(game.world.is_running() and running_speed > walking_speed * 2.0 and absf(running_speed - 3.8) < 0.04, "A second finger selects the actual separate running pace")
	_check(pad.touch_index == 3 and game.world._figure.clip == "run", "Running neither loses the movement finger nor keeps the walk clip")
	_touch(held, 3, false)
	await _frames(40)
	_check(game.world._touch_move == Vector2.ZERO and _speed() < 0.01 and game.world._figure.clip == "idle", "Finger release brakes the body and returns the skin to idle")
	metrics.walk_speed_m_s = walking_speed
	metrics.run_speed_m_s = running_speed
	metrics.held_walk_distance_m = walking_distance

	# Reach the real work contract through its legal actions rather than forging
	# completed steps, inventory, relationship or apprenticeship fields.
	_check(_reach_first_work(), "The first supervised smith task is reachable through accepted domain actions")
	_place(Vector3(Childhood.POINTS.bellows.x - 0.4, 0.92, Childhood.POINTS.bellows.y))
	game.world.set_running(false)
	game.world._figure.reset_motion()
	_check(game.model.execute("village_childhood_action", {"action_id":"begin_forge_bellows"}).ok, "The actual station accepts an explicit work start")
	game._refresh()
	await _frames(36)
	_check(game.world._figure.clip == "work" and float(game.model.data.village.childhood.work_seconds) > 0.25, "Stationary nearby work advances and displays its own pose")

	# A live combat pose has priority over the saved work activity.
	game.ui.action_requested.emit("attack", {"technique":"jab_left"})
	await _frames(8)
	_check(game.model.data.village.unarmed.technique == "jab_left" and game.world._figure._combat_id == "jab_left", "A station work hint cannot erase an accepted combat pose")
	await _frames(50)
	_check(game.world._figure.clip == "work", "After combat recovery nearby unfinished work can resume")

	pad = game.ui._touch_pad
	held = pad.get_global_rect().get_center() + Vector2(-pad.size.x * 0.38, 0)
	_touch(held, 5, true)
	await _frames(45)
	metrics.work_exit_after_45_frames = {"position":str(game.world._player.position), "speed":_speed(), "clip":game.world._figure.clip, "axis":str(game.world._touch_move), "finger":pad.touch_index}
	_check(_speed() > 0.5 and game.world._figure.clip == "march", "Walking away interrupts the work loop promptly while the domain task remains saved")
	await _frames(100)
	_touch(held, 5, false)
	await _frames(35)
	var station := Vector2(Childhood.POINTS.bellows)
	var location: Vector2 = Vector2(game.world._player.position.x, game.world._player.position.z)
	metrics.work_exit_position = str(location)
	_check(location.distance_to(station) > Childhood.POINT_RANGE, "Native held movement actually leaves the station radius")
	_check(game.model.data.village.childhood.active_work == "forge_bellows" and game.world._figure.clip == "idle", "Saved unfinished work does not make an idle character work at a remote location")
	var paused_work := float(game.model.data.village.childhood.work_seconds)
	await _frames(40)
	_check(is_equal_approx(float(game.model.data.village.childhood.work_seconds), paused_work), "Station time remains frozen after leaving")
	metrics.work_seconds_after_leaving = paused_work

	_place(Vector3(station.x - 0.4, 0.92, station.y))
	await _frames(35)
	_check(game.world._figure.clip == "work" and float(game.model.data.village.childhood.work_seconds) > paused_work, "Returning stationary to the unfinished station resumes the existing task")
	await _frames(600)
	_check(float(game.model.data.village.childhood.work_seconds) == 8.0 and game.world._figure.clip == "idle", "Completed station time waits for deliberate handover without an endless work pose")
	_check(game.model.data.village.childhood.active_work == "forge_bellows", "Presentation never auto-completes the authoritative handover")

	# Reactions and death must retain priority even if a stale work hint arrives.
	var figure: Node3D = game.world._figure
	figure.cue("hit")
	figure.keep_working()
	_check(figure.clip == "hit", "Work hints preserve a current hit reaction")
	figure.cue("death")
	figure.keep_working()
	_check(figure.clip == "death", "Work hints never resurrect a dead visual actor")
	figure.reset_motion()
	game._pause()
	await _frames(10)
	_check(game.world._touch_move == Vector2.ZERO and _speed() < 0.01, "Pausing clears locomotion after work and touch transitions")
	metrics.checks = checks
	metrics.failures = failures
	metrics.engine = Engine.get_version_info().string
	metrics.android_device_test = false
	metrics.fixture_note = "Actual scene and native touch events; controlled placements isolate stations and terrain. Not a continuous manual playthrough."
	var report_path := OS.get_environment("IMPERATHEN_LOCOMOTION_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(metrics, "  ") + "\n")
	game.queue_free()
	await process_frame
	for failure: String in failures:
		printerr("LOCOMOTION_FAIL: " + failure)
	print("LOCOMOTION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("LOCOMOTION_PASS" if failures.is_empty() else "LOCOMOTION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _reach_first_work() -> bool:
	for index in 40:
		var view: Dictionary = Childhood.view(game.model.data)
		if view.get("stage", "") == "forge_bellows":
			return true
		if view.is_empty():
			return false
		if str(view.get("stage", "")).begins_with("i03_"):
			# I-03 errand: real commands with Marcus placed where he stands.
			if not bool(preload("res://tests/i03_support.gd").play_stage(game.model).get("ok", false)):
				return false
			continue
		var at: Vector2 = view.point
		game.model.set_player_position(Vector3(at.x, 0.92, at.y))
		var npc := str(view.get("target_npc", ""))
		if not npc.is_empty() and not Life.relationship(game.model.data, npc).get("met", false):
			if not game.model.execute("village_talk", {"npc_id":npc, "choice":"meet"}).ok:
				return false
		view = Childhood.view(game.model.data)
		var choices: Array = view.actions
		if choices.is_empty() or not choices[0].enabled:
			return false
		if not game.model.execute(str(choices[0].command), choices[0].payload).ok:
			return false
	return false


func _action_button(action: String) -> Button:
	for control: Button in game.ui._screen.find_children("*", "Button", true, false):
		if control.get_meta("touch_action", "") == action and control.is_visible_in_tree():
			return control
	return null


func _touch(at: Vector2, index: int, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = index
	event.pressed = pressed
	root.push_input(event, true)


func _place(at: Vector3) -> void:
	game.model.interrupt_combat()
	game.world._player.position = at
	game.world._player.velocity = Vector3.ZERO
	game.world._figure.rotation.y = 0.0
	game.world._camera_yaw = 0.0
	game.world.set_touch_move(Vector2.ZERO)
	game.model.set_player_position(at)
	game.world.sync_state(game.model.data)


func _speed() -> float:
	var actual: Vector3 = game.world._player.get_real_velocity()
	return Vector2(actual.x, actual.z).length()


func _frames(number: int) -> void:
	for frame in number:
		await physics_frame
		game._physics_process(1.0 / 60.0)
		game.world._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
