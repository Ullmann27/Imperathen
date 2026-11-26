extends SceneTree
## Runs the real city and input path with the separately staged animated horse.

const City := preload("res://scripts/world/city_exploration.gd")
var failures := 0
var checks := 0
var _capture_directory := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 1 and DisplayServer.get_name() != "headless":
		_capture_directory = args[0]
		DirAccess.make_dir_recursive_absolute(_capture_directory)
	_run.call_deferred()


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", text)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _capture(city: Node3D, filename: String, offset: Vector3) -> void:
	if _capture_directory.is_empty():
		return
	city.set_physics_process(false)
	var horse_at: Vector3 = city.riding_trial.horse.global_position
	city.camera.position = horse_at + offset
	city.camera.look_at(horse_at + Vector3.UP * 1.15)
	city.camera.fov = 58.0
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(_capture_directory.path_join(filename)) == OK,
		"Godot writes the actual ride screenshot")
	city.set_physics_process(true)


func _run() -> void:
	var city := City.new()
	city.persist = false
	city.enable_riding_trial = true
	root.add_child(city)
	await _frames(16)
	_check(city.city_available and city.riding_trial != null, "Real city enters with the rigged horse fixture")
	if city.riding_trial == null:
		city.free()
		quit(1)
		return
	var trial := city.riding_trial
	_check(trial.animation.current_animation == "idle" and city._trade_button.text == "Aufsteigen",
		"Normal HUD exposes mount interaction at the shoulder")
	await _capture(city, "01-Pferd-im-Stallhof.png", Vector3(-2.7, 1.85, 2.45))
	var rider_rid: RID = city.player.get_rid()
	city._trade_button.pressed.emit()
	await _frames(20)
	_check(trial.controller.is_mounted(), "Pressing the existing action button mounts the animated horse")
	_check(city.player.get_rid() == rider_rid and city.camera.current, "Riding keeps the same player and current camera")
	if trial.controller.is_mounted():
		var initial: Vector3 = trial.horse.position
		city._running = true
		city._touch_move = Vector2.LEFT
		await _frames(84)
		_check(trial.horse.position.x < initial.x - 2.35, "Horse moved through the stable gate using the normal movement input")
		_check(trial.animation.current_animation in ["trot", "canter"], "The matching real animal locomotion animation is playing")
		_check(city.player.position.distance_to(trial.horse.position) < 2.2,
			"The existing player is attached to the advancing saddle")
		await _capture(city, "02-Reitpruefung-ausserhalb.png", Vector3(-2.6, 1.95, -3.2))
		city._touch_move = Vector2.ZERO
		await _frames(80)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		city._unhandled_input(key)
		await _frames(26)
		_check(not trial.controller.is_mounted() and city.player.is_on_floor(),
			"Keyboard action dismounts on real city ground after the horse stops")
		_check(city.player.collision_layer == 2 and city.player.collision_mask == 1,
			"Normal player collisions are restored on dismount")
		_check(trial.animation.current_animation == "idle", "Horse returns to idle once stopped")
	city.free()
	await _frames(3)
	print("CITY_RIDING_TRIAL_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
