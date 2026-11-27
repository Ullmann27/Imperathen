extends SceneTree
## Contract fixture with the existing Godot youth rig, real physics sweeps and
## a horse collision envelope. The animal mesh and animation are an integration
## check for the owner scene. The fixture doesn't stand in for the model.

const Controller := preload("res://scripts/world/mount_controller.gd")
const Person := preload("res://scripts/visuals/village_person.gd")
const DT := 1.0 / 60.0
const ORIGINAL_LAYER := 2
const ORIGINAL_MASK := 1 | 4 | 8
const START := Vector3(-1.39, .925, .04)

var _scene := Node3D.new()
var _rider := CharacterBody3D.new()
var _horse := CharacterBody3D.new()
var _figure := Person.new()
var _saddle := Marker3D.new()
var _controller := Controller.new()
var _changes: Array[bool] = []
var _messages: Array[String] = []
var _checks := 0
var _failed := 0
var _reboard_origin := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(message)


func _box(size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	_box_shape(body, size, Vector3.ZERO)
	_scene.add_child(body)
	return body


func _box_shape(body: CollisionObject3D, size: Vector3, center: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	shape.shape = volume
	shape.position = center
	body.add_child(shape)


func _setup() -> void:
	root.add_child(_scene)
	_box(Vector3(32, .30, 40), Vector3(0, -.15, 0))
	_rider.collision_layer = ORIGINAL_LAYER
	_rider.collision_mask = ORIGINAL_MASK
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	shape.shape = capsule
	_rider.add_child(shape)
	_rider.add_child(_figure)
	_figure.configure("player", "italia", 12)
	_figure._check_lod = 10000.0
	_rider.position = START
	_scene.add_child(_rider)
	_horse.collision_layer = 1
	_horse.collision_mask = 1 | 2
	_horse.safe_margin = .003
	_horse.floor_snap_length = .26
	_box_shape(_horse, Vector3(.71, 1.47, 1.90), Vector3(0, .735, -.17))
	_horse.add_child(_saddle)
	_saddle.position = Vector3(0, 1.30535, .08078)
	_scene.add_child(_horse)
	_scene.add_child(_controller)
	_controller.state_changed.connect(func(mounted: bool): _changes.append(mounted))
	_controller.action_feedback.connect(func(text: String): _messages.append(text))
	_check(_controller.configure(_rider, _figure, _horse, _saddle), "Live bodies and their socket bind once.")
	await physics_frame


func _tick(axis := Vector2.ZERO, yaw := 0.0, faster := false) -> bool:
	await physics_frame
	return _controller.advance(DT, axis, yaw, faster)


func _palms() -> Dictionary:
	var rig: Skeleton3D = _figure.body.find_children("*", "Skeleton3D", true, false)[0]
	var result := {}
	for name: String in ["Pelvis", "Foot_L", "Foot_R", "Hand_L", "Hand_R", "Shin_L", "Shin_R"]:
		result[name] = rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
	return result


func _run() -> void:
	await _setup()
	_rider.position = Vector3(-5.0, START.y, START.z)
	_check(not _controller.request_interact(), "Out-of-range input falls through to normal world interaction.")
	_rider.position = Vector3(0.0, START.y, -1.3)
	_check(not _controller.request_interact(), "Approaches down the horse's centre line do not offer a lateral ascent.")
	_rider.position = START
	_controller.request_interact()
	_controller.clear_pending()
	_check(not await _tick() and not _controller.is_mounted(), "Losing input focus cancels a queued action.")
	# Active social body turning is a competing physics pose owner.
	_figure.set_ambient_gaze(true)
	_check(_figure.is_physics_processing(),"On-foot gaze has its actual physics callback enabled.")
	var barricade := _box(Vector3(.16, 2.75, 2.10), Vector3(-.57, 1.37, .08))
	await physics_frame
	_check(_controller.request_interact(), "Reach offers the interaction before physics checks.")
	await _tick()
	_check(_changes.is_empty() and not _controller.is_mounted() and _rider.position.is_equal_approx(START), "Solid wall refuses boarding without moving the player.")
	_check(_rider.collision_layer == ORIGINAL_LAYER and _figure.is_processing() and _figure.is_physics_processing(), "Rejected ascent preserves walking and both process states.")
	barricade.free()
	await physics_frame
	var before := _palms()
	_check(_controller.request_interact() and _controller.request_interact(), "Two UI inputs can enter the same queue.")
	_check(await _tick() and _controller.is_mounted() and _changes == [true], "One physics tick boards exactly once.")
	var seated := _palms()
	_check(Vector3(seated.Pelvis).distance_to(_saddle.global_position) < .001, "Imported pelvis is on the real socket.")
	_check(Vector3(seated.Shin_L).distance_to(seated.Shin_R) > .32, "The seated knees separate either side of the horse.")
	_check(Vector3(seated.Hand_L).distance_to(before.Hand_L + Vector3(seated.Pelvis) - Vector3(before.Pelvis)) > .08, "The arms adopt a real bent rein pose.")
	_check(_rider.collision_layer == 0 and _rider.collision_mask == 0 and not _figure.is_processing() and not _figure.is_physics_processing(), "The rider stays in the original scene tree without competing locomotion or physics gaze.")
	_check(_controller.camera_exclusions().has(_horse.get_rid()) and _controller.camera_exclusions().has(_rider.get_rid()), "Camera solver can exclude the moving horse and rider.")
	_saddle.position.y += .046
	await _tick()
	_check(Vector3(_palms().Pelvis).distance_to(_saddle.global_position) < .001, "The pelvis follows a changing rig socket.")
	_figure.refresh_lod(_camera_far())
	await _tick()
	_check(Vector3(_palms().Pelvis).distance_to(_saddle.global_position) < .001, "A real LOD transition rebinds the seated position.")
	_check(not _figure.is_processing() and not _figure.is_physics_processing(),"LOD rebind does not resume a competing callback.")
	# A fresh external gaze assignment may re-enable processing. The seated
	# solver must reclaim both drivers at the next owner tick.
	_figure.set_ambient_gaze(true)
	await _tick()
	_check(not _figure.is_physics_processing(),"Seated owner reclaims externally re-enabled gaze callback.")
	var arch := _box(Vector3(3.0, .20, .17), Vector3(0.0, 2.01, -1.55))
	await physics_frame
	for _frame in 85:
		await _tick(Vector2(0, -1), 0.0, true)
	_check(_horse.position.z > -1.30 and _horse.position.z < -.75 and _controller.riding_gait() == &"idle",
		"The mounted rider prevents entry into a low arch that clears the horse body.")
	arch.free()
	await physics_frame
	var starting_horse := _horse.position
	for _frame in 105:
		await _tick(Vector2(0, -1), 0.0, true)
	_check(_horse.position.z < starting_horse.z - 1.1, "The shared analog axis moves the horse through actual physics.")
	_check(_controller.riding_gait() == &"canter" and _controller.riding_speed() > 2.85, "The hoof animation receives measured speed, not only the input intent.")
	_check(Vector3(_palms().Pelvis).distance_to(_saddle.global_position) < .001, "The saddle retains its pelvis anchor during travel.")
	_controller.request_interact()
	await _tick()
	_check(_controller.is_mounted() and not _messages.is_empty() and _messages.back().contains("zuerst an"), "A moving horse cannot be dismounted.")
	for _frame in 57:
		await _tick()
	_check(_controller.riding_gait() == &"idle", "Releasing movement settles the actual body.")
	var left := _box(Vector3(.15, 2.60, 2.30), _horse.position + Vector3(-.64, 1.30, 0))
	var right := _box(Vector3(.15, 2.60, 2.30), _horse.position + Vector3(.64, 1.30, 0))
	await physics_frame
	_controller.request_interact()
	await _tick()
	_check(_controller.is_mounted() and _changes == [true] and _rider.collision_layer == 0, "Both swept sides blocked keeps the rider attached.")
	right.free()
	await physics_frame
	_controller.request_interact()
	_check(await _tick() and not _controller.is_mounted() and _changes == [true, false], "The free alternate side dismounts in one accepted tick.")
	_check(_rider.position.x > _horse.position.x + .9 and is_equal_approx(_rider.position.y, .925), "Dismount ends on the probed floor, clear of the horse.")
	_check(_rider.collision_layer == ORIGINAL_LAYER and _rider.collision_mask == ORIGINAL_MASK and _figure.is_processing() and _figure.is_physics_processing(), "The original walker physics, gaze and clip driver are restored.")
	_check(not _controller.camera_exclusions().has(_horse.get_rid()), "Past mount bodies block the camera normally again.")
	left.free()
	await physics_frame
	_figure.set_ambient_gaze(false)
	_check(not _figure.is_physics_processing(),"Disabled on-foot gaze is also a valid original state.")
	_check(await _board_again(), "The same mount can be used again after dismount.")
	_horse.position = Vector3(15.6, 0, -7.0)
	await _tick()
	_box(Vector3(.15, 2.60, 2.30), _horse.position + Vector3(-.64, 1.30, 0))
	await physics_frame
	_controller.request_interact()
	await _tick()
	_check(_controller.is_mounted(), "A clear-looking exit over a ledge is rejected without a supporting floor.")
	_controller.free()
	_check(_figure.is_processing() and not _figure.is_physics_processing() and _rider.collision_layer == ORIGINAL_LAYER and _rider.position.is_equal_approx(_reboard_origin),
		"Removing the mount controller safely restores an on-foot rider.")
	_scene.free()
	print("MOUNT_CONTROLLER_%s checks=%d failures=%d" % ["PASS" if _failed == 0 else "FAIL", _checks, _failed])
	quit(0 if _failed == 0 else 1)


func _board_again() -> bool:
	_reboard_origin = _rider.position
	return _controller.request_interact() and await _tick() and _controller.is_mounted()


func _camera_far() -> Camera3D:
	var camera := Camera3D.new()
	camera.position = Vector3(65.0, 2.0, 0.0)
	_scene.add_child(camera)
	return camera
