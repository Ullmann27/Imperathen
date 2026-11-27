extends RefCounted
## A reversible, final skeletal layer. Imported and procedural animation own
## the base pose. Rest-space axes describe the *mesh*, not Blender bone roll.
## The supported character families face +Z in skeleton rest space.
const HEAD_YAW := deg_to_rad(60.0)
const HEAD_PITCH := deg_to_rad(25.0)
const EYE_YAW := deg_to_rad(14.0)
const EYE_PITCH := deg_to_rad(8.0)
var skeleton: Skeleton3D
var head := -1
var neck := -1
var eyes: Array[int] = []
var _saved: Dictionary = {}
var _written: Dictionary = {}
var _head_angles := Vector2.ZERO
var _eye_angles := Vector2.ZERO
var _initialized := false
var _time := 0.0

func bind(rig: Skeleton3D) -> void:
	restore()
	skeleton = rig
	head = -1
	neck = -1
	eyes.clear()
	_initialized = false
	if not is_instance_valid(rig):
		return
	head = rig.find_bone("Head")
	neck = rig.find_bone("Neck")
	# Only complete, independently deforming eye pairs are eligible. Current
	# Marcus and the original youth use the head-only fallback.
	for names: Array in [["Eye_L", "Eye_R"], ["LeftEye", "RightEye"]]:
		var left := rig.find_bone(names[0])
		var right := rig.find_bone(names[1])
		if left >= 0 and right >= 0:
			eyes.assign([left, right])
			break

func available() -> bool:
	return is_instance_valid(skeleton) and head >= 0

func restore() -> void:
	# Do not restore over a new externally sampled pose. Restore only our own
	# last write, before the animation/transition pipeline reads the skeleton.
	if is_instance_valid(skeleton) and not _saved.is_empty():
		for index: int in _saved:
			var last: Quaternion = _written[index]
			if absf(skeleton.get_bone_pose_rotation(index).dot(last)) > 0.999999:
				skeleton.set_bone_pose_rotation(index, _saved[index])
		skeleton.force_update_all_bone_transforms()
	_saved.clear()
	_written.clear()

func suspend() -> void:
	restore()
	_initialized = false

func direction_world(bone: int = -1) -> Vector3:
	if not available():
		return Vector3.ZERO
	var index := head if bone < 0 else bone
	var rest := skeleton.get_bone_global_rest(index).basis.orthonormalized()
	var posed := skeleton.get_bone_global_pose(index).basis.orthonormalized()
	return (skeleton.global_basis * (posed * (rest.inverse() * Vector3.BACK))).normalized()

func anchor_world() -> Vector3:
	if not available():
		return Vector3.INF
	if eyes.size() == 2:
		return skeleton.to_global((skeleton.get_bone_global_pose(eyes[0]).origin + skeleton.get_bone_global_pose(eyes[1]).origin) * 0.5)
	var rest := skeleton.get_bone_global_rest(head)
	var posed := skeleton.get_bone_global_pose(head)
	# Estimate the eye line from the head joint, scaled to the authored rig.
	# No independent eyes are invented on a fused Meshy face.
	var size := clampf(absf(rest.origin.y) / 1.27, 0.7, 1.4)
	var offset := rest.basis.orthonormalized().inverse() * Vector3(0, 0.115 * size, 0.065 * size)
	return skeleton.to_global(posed * offset)

static func angles_for(direction: Vector3, actor_basis: Basis) -> Vector2:
	var local := actor_basis.orthonormalized().inverse() * direction.normalized()
	return Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))

static func direction_for(angles: Vector2, actor_basis: Basis) -> Vector3:
	return actor_basis.orthonormalized() * Vector3(-sin(angles.x) * cos(angles.y), sin(angles.y), -cos(angles.x) * cos(angles.y))

static func damp(current: Vector2, goal: Vector2, rate: float, delta: float) -> Vector2:
	var weight := 1.0 - exp(-rate * maxf(delta, 0.0))
	return Vector2(lerp_angle(current.x, goal.x, weight), lerpf(current.y, goal.y, weight))

func _aim(index: int, world_direction: Vector3, weight: float = 1.0) -> void:
	var current := skeleton.get_bone_global_pose(index).basis.orthonormalized()
	var rest := skeleton.get_bone_global_rest(index).basis.orthonormalized()
	var current_forward := (current * (rest.inverse() * Vector3.BACK)).normalized()
	var desired := (skeleton.global_basis.inverse() * world_direction).normalized()
	if current_forward.is_zero_approx() or desired.is_zero_approx():
		return
	# Minimal swing retains the animation's twist/roll. Translation, scale,
	# root, spine, limbs, weapon sockets and foot contact are never authored here.
	var correction := Quaternion(current_forward, desired)
	var target := Basis(Quaternion.IDENTITY.slerp(correction, weight)) * current
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		target = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * target
	var rotation := target.get_rotation_quaternion().normalized()
	_saved[index] = skeleton.get_bone_pose_rotation(index)
	_written[index] = rotation
	skeleton.set_bone_pose_rotation(index, rotation)
	skeleton.force_update_all_bone_transforms()

func apply(delta: float, actor_basis: Basis, point: Vector3, action: String, enabled: bool) -> void:
	restore()
	if not available() or not enabled or action not in ["idle", "march", "talk"] or not is_finite(delta) or delta < 0.0:
		_initialized = false
		return
	_time += delta
	if not _initialized:
		_head_angles = angles_for(direction_world(), actor_basis)
		_eye_angles = _head_angles
		_initialized = true
	var goal := Vector2(deg_to_rad(1.2) * sin(_time * 0.83), deg_to_rad(0.7) * sin(_time * 1.11))
	var anchor := anchor_world()
	if point.is_finite() and anchor.is_finite() and point.distance_squared_to(anchor) > 0.01:
		goal = angles_for(point - anchor, actor_basis)
	var yaw_limit := HEAD_YAW if action != "march" else deg_to_rad(40.0)
	var pitch_limit := HEAD_PITCH if action != "march" else deg_to_rad(18.0)
	var head_goal := Vector2(clampf(goal.x, -yaw_limit, yaw_limit), clampf(goal.y, -pitch_limit, pitch_limit))
	_head_angles = damp(_head_angles, head_goal, 5.5 if point.is_finite() else 7.0, delta)
	_eye_angles = damp(_eye_angles, goal, 20.0, delta)
	var desired := direction_for(_head_angles, actor_basis)
	# The youth Neck is a weighted sibling rather than a parent of Head.
	# Use a small shared correction on either topology, then solve Head in
	# the resulting parent space. No reparenting or bind-matrix changes.
	if neck >= 0:
		_aim(neck, desired, 0.18)
	_aim(head, desired)
	if eyes.size() == 2:
		var eye_goal := _head_angles + Vector2(
			clampf(angle_difference(_head_angles.x, _eye_angles.x), -EYE_YAW, EYE_YAW),
			clampf(_eye_angles.y - _head_angles.y, -EYE_PITCH, EYE_PITCH))
		for eye: int in eyes:
			_aim(eye, direction_for(eye_goal, actor_basis))
