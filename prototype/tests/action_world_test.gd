extends SceneTree
## Production scene, real CharacterBody motion, physics obstruction and saves.

const Entry = preload("res://main.tscn")
const Art = preload("res://scripts/world/village_art.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
var game
var checks := 0
var failures: Array[String] = []
var metrics := {}


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated XDG data directory is required for the real save path.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	_check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "Production New Life reaches the I-00 Aquileia cold open")
	game._opening_skip()
	game._opening_next()
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_home", "I-00 hands the same saved life to the family opening")
	game._opening_skip()
	game._opening_next()
	_check(game.screen == "playing" and game.model.data.player.age == 12 and Combat.enabled(game.model.data), "The actual new child receives movement and combat controls after both authored openings")
	await _frames(3)

	# Clear existing terrain allows a measured straight-line pace comparison.
	_place(Vector3(63, 0.92, 40))
	game.world._camera_yaw = 0.0
	game.world._figure.rotation.y = 0.0
	game.ui.action_requested.emit("move_axis", {"x":0.0, "y":-1.0})
	await _frames(120)
	var walk_speed: float = Vector2(game.world._player.get_real_velocity().x, game.world._player.get_real_velocity().z).length()
	var walk_distance := 40.0 - float(game.world._player.position.z)
	_check(absf(walk_speed - 1.45) < 0.04 and walk_distance > 2.4 and walk_distance < 3.0, "Full walking input produces a controlled 1.45 m/s pace")
	game.ui.action_requested.emit("movement_pace", {"running":true})
	await _frames(90)
	var run_speed: float = Vector2(game.world._player.get_real_velocity().x, game.world._player.get_real_velocity().z).length()
	_check(absf(run_speed - 3.8) < 0.04 and run_speed > walk_speed * 2.0, "Run is a separate child pace at 3.8 m/s")
	game.ui.action_requested.emit("move_axis", {"x":0.0, "y":0.0})
	await _frames(45)
	_check(Vector2(game.world._player.get_real_velocity().x, game.world._player.get_real_velocity().z).length() < 0.01, "Releasing the stick brakes to a real stationary body")
	metrics.walk_speed_m_s = walk_speed
	metrics.run_speed_m_s = run_speed
	metrics.walk_distance_in_2_seconds_m = walk_distance

	# A deliberate wall fixture catches the old requested-velocity skating bug.
	Art.box_collider(game.world, Vector3(4, 2.2, 0.2), Vector3(63, 1.1, 35))
	_place(Vector3(63, 0.92, 37))
	game.world.set_running(false)
	game.world.set_touch_move(Vector2(0, -1))
	await _frames(180)
	_check(game.world._player.position.z > 35.35, "The player cannot walk through the wall")
	_check(game.world._figure.speed < 0.03, "A blocked player stops the locomotion pose instead of walking on the spot")
	_check(not game.world.combat_sight_clear(Vector2(63, 36), Vector2(63, 34)), "A real wall blocks the combat ray")
	var stopped: Vector2 = game.world.combat_safe_motion(Vector2(63, 35.6), Vector2(63, 34.6))
	_check(stopped.y > 35.35, "The actual swept capsule prevents a moving raider from crossing a wall")

	# Walk through the existing atrium entrance, not a fabricated door asset.
	_place(Vector3(14, 0.92, -23.0))
	game.world.set_touch_move(Vector2(0, -1))
	await _frames(250)
	_check(game.world._player.position.z < -27.0 and absf(game.world._player.position.x - 14.0) < 0.15, "The real atrium doorway admits the player capsule into the courtyard")
	metrics.atrium_end_position = _xyz(game.world._player.position)

	# Existing named residents now have collision, including work assignments.
	var resident: Node3D = game.world.village_life_world.actors.aelia
	var resident_at := resident.global_position
	var personal_space := resident as CollisionObject3D
	_check(personal_space != null and personal_space.collision_layer == 8 and resident.get_node_or_null("PersonalSpace") is CollisionShape3D, "A living named resident retains its native civilian body and shape")
	_place(Vector3(resident_at.x, 0.92, resident_at.z + 1.7))
	game.world.set_touch_move(Vector2(0, -1))
	await _frames(120)
	var resident_distance := Vector2(game.world._player.position.x - resident_at.x, game.world._player.position.z - resident_at.z).length()
	_check(resident_distance > 0.53, "Walking toward the resident cannot merge the two bodies")

	# All ten techniques are earned by actual contacts with the real practice post.
	_place(Vector3(0, 0.92, -6.3))
	await _frames(2)
	var practice_count := int(game.model.data.village.unarmed.practice_hits)
	game.ui.action_requested.emit("attack", {"technique":"jab_left"})
	_check(game.model.data.village.unarmed.practice_hits == practice_count, "The real attack button grants no immediate contact")
	await _frames(10)
	_check(game.model.data.village.unarmed.practice_hits == practice_count, "Preparation remains harmless before its active window")
	await _frames(31)
	_check(game.model.data.village.unarmed.practice_hits == practice_count + 1, "One later contact with the actual post grants one practice hit")
	for index in 13:
		game.ui.action_requested.emit("attack", {"technique":"jab_left" if index % 2 == 0 else "jab_right"})
		await _frames(46)
	_check(int(game.model.data.village.unarmed.practice_hits) == practice_count + 14, "Controlled repeated contacts earn the full technique catalogue")
	for id: String in Combat.TECHNIQUES:
		await _frames(100)
		var before := int(game.model.data.village.unarmed.practice_hits)
		game.ui.action_requested.emit("attack", {"technique":id})
		if Combat.is_armed(id):
			_check(not Combat.available(game.model.data,id) and not Combat.busy(game.model.data), "Child touch command cannot start a locked weapon or substitute a fist: " + id)
			_check(int(game.model.data.village.unarmed.practice_hits)==before, "Rejected weapon command leaves practice unchanged: " + id)
			continue
		_check(game.model.data.village.unarmed.technique == id, "UI selects and starts the requested technique: " + id)
		await _frames(ceili(float(Combat.TECHNIQUES[id].duration) * 60.0) + 2)
		_check(int(game.model.data.village.unarmed.practice_hits) == before + 1, "Exactly one world contact for " + id)
	_check(game.model.data.player.age == 12 and game.model.data.progress.training_hits == 0, "Childhood practice neither ages the child nor awards adult certification")

	# A real inserted wall between hand and post rejects practice as well as damage.
	var blocker := Art.box_collider(game.world, Vector3(1.8, 1.8, 0.12), Vector3(0, 0.9, -6.65))
	await _frames(2)
	var before_wall := int(game.model.data.village.unarmed.practice_hits)
	game.ui.action_requested.emit("attack", {"technique":"jab_left"})
	await _frames(42)
	_check(game.model.data.village.unarmed.practice_hits == before_wall, "The real post grants no credit through an intervening wall")
	blocker.queue_free()
	await _frames(2)

	# Pause/background interrupts both the body input and the accepted pending hit.
	await _frames(60)
	game.ui.action_requested.emit("attack", {"technique":"jab_left"})
	game.ui.action_requested.emit("move_axis", {"x":1.0, "y":0.0})
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var paused_count := int(game.model.data.village.unarmed.practice_hits)
	await _frames(90)
	_check(game.screen == "paused" and not Combat.busy(game.model.data) and game.world._touch_move == Vector2.ZERO, "Application background cancels accepted attack, movement and gesture state")
	_check(game.model.data.village.unarmed.practice_hits == paused_count, "A paused pending attack cannot turn into a hit")
	var saved: Dictionary = game._save(false)
	_check(saved.ok, "The completed combined section writes a validated real campaign")
	game.queue_free()
	await process_frame
	await process_frame
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("continue", {})
	_check(game.screen == "playing" and game.model.data.village.unarmed.practice_hits == paused_count, "A recreated production session resumes the actual saved practice state")
	_check(not Combat.busy(game.model.data) and game.world._touch_move == Vector2.ZERO, "Restart does not revive an interrupted hit or held finger")
	metrics.practice_hits_after_restart = paused_count
	metrics.engine = Engine.get_version_info().string
	metrics.android_device_test = false
	metrics.physics_step_hz = 60
	metrics.test_scenario = "Actual main scene; controlled placements isolate terrain, atrium, residents and practice. No claim of a continuous manual walk between fixtures."
	var report_path := OS.get_environment("IMPERATHEN_ACTION_REPORT")
	if not report_path.is_empty():
		metrics.checks = checks
		metrics.failures = failures
		var report := FileAccess.open(report_path, FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify(metrics, "  ") + "\n")
	game.queue_free()
	await process_frame
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("ACTION_WORLD_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("ACTION_WORLD_PASS" if failures.is_empty() else "ACTION_WORLD_FAIL")
	quit(0 if failures.is_empty() else 1)


func _place(at: Vector3) -> void:
	game.model.interrupt_combat()
	game.world._player.position = at
	game.world._player.velocity = Vector3.ZERO
	game.world._figure.rotation.y = 0.0
	game.world._camera_yaw = 0.0
	game.world.set_touch_move(Vector2.ZERO)
	game.model.set_player_position(at)
	game.world.sync_state(game.model.data)


func _frames(number: int) -> void:
	for frame in number:
		await physics_frame
		game._physics_process(1.0 / 60.0)
		game.world._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)


func _xyz(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
