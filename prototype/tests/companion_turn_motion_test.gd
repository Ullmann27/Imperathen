extends SceneTree
## A live companion must settle its heading before using its full running pace.
## Keep physical movement, the imported Marcus rig and the actual pose driver.

const Follow := preload("res://scripts/story/companion_follow.gd")
const Person := preload("res://scripts/visuals/village_person.gd")
const Measurement := preload("res://tests/motion_world_measurement.gd")
var checks := 0
var failures: Array[String] = []
var metrics: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _run() -> void:
	for hz: int in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		for sign: float in [-1.0, 1.0]:
			await _turn_and_retarget(hz, sign)
	print("COMPANION_TURN_MOTION_METRICS ", JSON.stringify(metrics))
	print("Companion turn motion: %d checks, %d failures" % [checks, failures.size()])
	print("COMPANION_TURN_MOTION_PASS" if failures.is_empty() else "COMPANION_TURN_MOTION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _turn_and_retarget(hz: int, sign: float) -> void:
	var dt := 1.0 / float(hz)
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.5
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80, 1, 80)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)
	var actor := CharacterBody3D.new()
	actor.name = "Marcus"
	actor.collision_mask = 1
	actor.floor_snap_length = 0.35
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = 0.9
	actor.add_child(shape)
	stage.add_child(actor)
	var figure := Person.new()
	figure.name = "Figure"
	figure.position.y = 0.9
	actor.add_child(figure)
	figure.set_process(false)
	figure.configure("companion", "italia", 12)
	figure._check_lod = 10000.0
	var nav := Follow.new()
	var observer := Measurement.new()
	var sample := observer._observer()
	var target := Vector3(12.0 * sign, 0.0, 10.0)
	var backwards_samples := 0
	var backwards_running := 0
	var backward_speed := 0.0
	var aligned_speed := 0.0
	var max_turn := 0.0
	var max_step := 0.0
	var previous_speed := 0.0
	var maximum_acceleration := 0.0
	await physics_frame
	await physics_frame
	for frame in hz * 8:
		await physics_frame
		if frame == hz * 2:
			# Change the real path destination while the actor is already running.
			target = actor.global_position - Vector3(8.0 * sign, 0.0, 9.0)
		var before := actor.global_position
		var old_yaw := actor.rotation.y
		nav.move(actor, target, dt, 4.1, 0.18)
		var travel := actor.global_position - before
		var speed := Vector2(travel.x, travel.z).length() / dt
		maximum_acceleration = maxf(maximum_acceleration,(speed-previous_speed)/dt)
		previous_speed = speed
		figure.drive(speed)
		figure._process(dt)
		observer._observe_person(sample, actor, figure)
		for metric: String in sample.worst:
			if int(sample.worst[metric].frame) == frame + 1:
				sample.worst[metric]["animation_phase"] = figure.phase
		max_turn = maxf(max_turn, absf(angle_difference(old_yaw, actor.rotation.y)))
		max_step = maxf(max_step, Vector2(travel.x, travel.z).length())
		var toward := Vector3(target.x - before.x, 0.0, target.z - before.z).normalized()
		var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.rotation.y)
		var alignment := forward.dot(toward)
		if alignment < 0.0:
			backwards_samples += 1
			backward_speed = maxf(backward_speed, speed)
			if figure.clip == "run":
				backwards_running += 1
		if alignment > 0.999:
			aligned_speed = maxf(aligned_speed, speed)
	var label := "%d Hz, turn %+.0f: " % [hz, sign]
	_check(figure.active_model_path == "res://assets/village_characters/villager_0.glb", label + "uses the actual Marcus model")
	_check(backwards_samples > 0, label + "observes a destination behind the body")
	_check(backward_speed <= 0.001, label + "a rearward destination turns on the spot before forward travel")
	_check(backwards_running == 0, label + "the actual pose driver leaves running for the grounded turn")
	_check(aligned_speed >= 4.09, label + "aligned travel retains the full requested running speed")
	_check(maximum_acceleration <= 8.1, label + "a start or retarget uses the existing player running acceleration")
	_check(max_turn <= Follow.MAX_TURN_RATE * dt + 0.00001, label + "keeps the existing angular limit")
	_check(max_step <= 4.1 * dt + 0.0001, label + "turns and retargets never teleport the body")
	_check(nav.status == "arrived" and Vector2(actor.position.x - target.x, actor.position.z - target.z).length() <= 0.185, label + "reaches the changed destination through physics")
	_check(sample.finite and sample.contact_samples > hz, label + "samples finite actual bones and planted feet")
	_check(float(sample.metrics.max_support_slip_m) <= 0.015, label + "turning and starting retain the strict planted-foot limit")
	metrics.append({"hz":hz, "turn":sign, "backward_speed_m_s":backward_speed,
		"backwards_running_frames":backwards_running, "aligned_speed_m_s":aligned_speed,
		"maximum_acceleration_m_s2":maximum_acceleration, "maximum_root_turn_deg":rad_to_deg(max_turn), "world_motion":sample.metrics,
		"world_worst":sample.worst})
	stage.free()
	await physics_frame
	await physics_frame
