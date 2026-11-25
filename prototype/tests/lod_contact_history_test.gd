extends SceneTree
## Reload a real LOD after root travel, immediately before the first swing.
## Its presentation-only solve must not consume another stance correction.

const Person := preload("res://scripts/visuals/village_person.gd")
var checks := 0
var failures: Array[String] = []
var results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _person(kind: String) -> Node3D:
	var person := Person.new()
	root.add_child(person)
	person.position.y = 0.9
	person.set_process(false)
	if kind == "resident":
		person.configure_resident("italia", 32, "civilian_man", 0)
	else:
		person.configure(kind, "italia", 12)
	person._reload(1)
	person._check_lod = 10000.0
	person.reset_motion()
	return person


func _run() -> void:
	for kind: String in ["player", "companion", "resident"]:
		for action: String in ["march", "run"]:
			for side: String in ["L", "R"]:
				for hz: float in [30.0, 60.0, 120.0]:
					_lift_boundary(kind, action, side, hz)
	print("LOD_CONTACT_HISTORY_METRICS ", JSON.stringify(results))
	print("LOD contact history: %d checks, %d failures" % [checks, failures.size()])
	print("LOD_CONTACT_HISTORY_PASS" if failures.is_empty() else "LOD_CONTACT_HISTORY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _lift_boundary(kind: String, action: String, side: String, hz: float) -> void:
	var subject := _person(kind)
	var control := _person(kind)
	var dt := 1.0 / hz
	var speed := 4.1 if action == "run" else 1.45
	var stance := 0.32 if action == "run" else 0.53
	subject.drive(speed)
	control.drive(speed)
	var phase_step: float = speed * dt / subject.locomotion_stride(action)
	# Four completed real ticks end just before this foot leaves the floor.
	var phase := fposmod(stance - 4.4 * phase_step - (0.5 if side == "L" else 0.0), 1.0)
	for person: Node3D in [subject, control]:
		person.drive(speed)
		person._play(action, phase, 0.0)
		person._process(0.0)
	for frame in 4:
		for person: Node3D in [subject, control]:
			person.position.z -= speed * dt
			person._process(dt)
	var history: Dictionary = subject._motion.capture_world_contacts()
	var label := "%s %s %s %.0f Hz: " % [kind, action, side, hz]
	_check(history.get("contacts", {}).has(side), label + "starts on the last actual stance frame")
	if not history.get("contacts", {}).has(side):
		subject.free()
		control.free()
		return
	var old_offset: Vector3 = history.contacts[side].offset
	var anchor: Transform3D = history.contacts[side].transform
	# Production moves the collision root before VillagePerson checks its LOD.
	for person: Node3D in [subject, control]:
		person.position.z -= speed * dt
	subject._reload(0)
	subject._check_lod = 10000.0
	var after_reload: Dictionary = subject._motion.capture_world_contacts()
	var history_change: float = Vector3(after_reload.contacts[side].offset).distance_to(old_offset)
	_check(history_change <= 0.000001, label + "a zero-time LOD solve preserves the last stance correction")
	var rig: Skeleton3D = subject._motion.skeleton
	var foot := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Foot_" + side))
	_check(foot.origin.distance_to(anchor.origin) <= 0.001, label + "the replacement LOD is actually posed at the planted contact")
	for person: Node3D in [subject, control]:
		person._process(dt)
	var released: Dictionary = subject._motion.capture_world_contacts()
	_check(not subject.world_foot_supported(side) and released.swings.has(side), label + "the next real tick lifts the intended foot")
	var release_error := INF
	if released.swings.has(side):
		release_error = Vector3(released.swings[side].offset).distance_to(old_offset)
	_check(release_error <= 0.000001, label + "the first swing retains exactly the last real stance correction")
	rig = subject._motion.skeleton
	var other: Skeleton3D = control._motion.skeleton
	rig.force_update_all_bone_transforms()
	other.force_update_all_bone_transforms()
	var maximum_position := 0.0
	var maximum_angle := 0.0
	for bone in rig.get_bone_count():
		var at := rig.global_transform * rig.get_bone_global_pose(bone)
		var expected := other.global_transform * other.get_bone_global_pose(other.find_bone(rig.get_bone_name(bone)))
		maximum_position = maxf(maximum_position, at.origin.distance_to(expected.origin))
		maximum_angle = maxf(maximum_angle, rad_to_deg(at.basis.orthonormalized().get_rotation_quaternion().angle_to(expected.basis.orthonormalized().get_rotation_quaternion())))
	_check(maximum_position <= 0.001 and maximum_angle <= 0.1, label + "the actual first-swing pose matches the continuously simulated control")
	results.append({"kind":kind, "action":action, "side":side, "hz":hz,
		"history_change_m":history_change, "release_error_m":release_error,
		"pose_difference_m":maximum_position, "pose_difference_deg":maximum_angle})
	subject.free()
	control.free()
