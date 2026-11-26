extends RefCounted
## Drives authored glTF face shapes on individual instances. This is expressive
## motion for the existing silent dialogue clips, not audio-derived lip sync.
## Rigs with `Eye_L`/`Eye_R` joints also get a living gaze: short saccades
## around the rest direction, or toward a target the owner sets. No clip keys
## those joints, so the gaze holds between updates.

const SHAPES := ["Blink_L", "Blink_R", "JawOpen", "Smile", "BrowDown"]
var _targets: Array[Dictionary] = []
var _values := PackedFloat32Array([0, 0, 0, 0, 0])
var _random := RandomNumberGenerator.new()
var _identity := ""
var _clock := 0.0
var _elapsed := 0.0
var _blink_at := -1.0
var _blink_duration := 0.18
var _next_blink := 2.0
const GAZE_YAW := deg_to_rad(24.0)
const GAZE_PITCH := deg_to_rad(14.0)
var _rig: Skeleton3D
var _eyes := PackedInt32Array()
var _gaze := Vector2.ZERO
var _gaze_from := Vector2.ZERO
var _gaze_to := Vector2.ZERO
var _gaze_at := 0.0
var _next_gaze := 1.0
var _gaze_target := Vector3.INF


func bind(model: Node3D, actor_identity: String) -> void:
	_targets.clear()
	if _identity != actor_identity:
		_identity = actor_identity
		_random.seed = actor_identity.hash()
		_clock = 0.0
		_blink_at = -1.0
		_next_blink = _random.randf_range(1.2, 3.8)
		_values.fill(0.0)
	_elapsed = 0.0
	_rig = null
	_eyes = PackedInt32Array()
	for rig: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		var left := rig.find_bone("Eye_L")
		var right := rig.find_bone("Eye_R")
		if left >= 0 and right >= 0:
			_rig = rig
			_eyes = PackedInt32Array([left, right])
			break
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.mesh:
			continue
		var slots := PackedInt32Array()
		var available := false
		for shape: String in SHAPES:
			var slot := mesh.find_blend_shape_by_name(shape)
			slots.append(slot)
			available = available or slot >= 0
		if available:
			_targets.append({"mesh": mesh, "slots": slots})
	_apply()


func advance(delta: float, action: String, detail: int) -> void:
	if _targets.is_empty() or not is_finite(delta) or delta < 0.0:
		return
	_clock += delta
	_elapsed += delta
	if detail < 2:
		_advance_gaze(action)
	if _clock >= _next_blink:
		_blink_at = _clock
		_blink_duration = _random.randf_range(0.16, 0.21)
		_next_blink = _clock + _random.randf_range(2.4, 5.6)
	# No per-frame face uploads for distant silhouettes. The bind/pose path clears
	# the outgoing weights immediately, so an actor cannot remain half blinking.
	if detail >= 2:
		return
	var interval := 1.0 / (30.0 if detail == 0 else 15.0)
	if _elapsed < interval:
		return
	var desired := _expression(action, _clock)
	desired[0] = _blink(0.0)
	desired[1] = _blink(0.012)
	if action == "death":
		desired[0] = 1.0
		desired[1] = 1.0
	var follow := 1.0 - exp(-14.0 * _elapsed)
	for i in SHAPES.size():
		_values[i] = desired[i] if i < 2 else lerpf(_values[i], desired[i], follow)
	_elapsed = 0.0
	_apply()


func pose(action: String, normalized: float, detail: int) -> void:
	# A posed review frame is reproducible and keeps the eyes open unless dead.
	_values = _expression(action, clampf(normalized, 0.0, 1.0) * 1.35)
	if action == "death":
		_values[0] = 1.0
		_values[1] = 1.0
	if detail >= 2:
		_values.fill(0.0)
	_gaze = Vector2.ZERO
	_gaze_from = Vector2.ZERO
	_gaze_to = Vector2.ZERO
	_apply_gaze()
	_apply()


## World-space point the eyes should hold; `Vector3.INF` returns to idle saccades.
func set_gaze_target(point: Vector3) -> void:
	_gaze_target = point


func has_eyes() -> bool:
	return _rig != null and is_instance_valid(_rig)


## Current eye direction as yaw and pitch in radians, relative to the head.
func gaze() -> Vector2:
	return _gaze


func _advance_gaze(action: String) -> void:
	if not has_eyes():
		return
	if action == "death":
		_gaze = Vector2(0.0, -0.5 * GAZE_PITCH)
		_apply_gaze()
		return
	if _clock >= _next_gaze:
		_gaze_from = _gaze
		_gaze_at = _clock
		if _gaze_target.is_finite():
			_gaze_to = _toward(_gaze_target)
			_next_gaze = _clock + _random.randf_range(0.25, 0.6)
		else:
			# Mostly small corrections around the front, now and then a real glance.
			var wide := _random.randf() < 0.22
			var reach := 1.0 if wide else 0.3
			_gaze_to = Vector2(_random.randf_range(-GAZE_YAW, GAZE_YAW) * reach,
				_random.randf_range(-GAZE_PITCH, GAZE_PITCH * 0.6) * reach)
			if action in ["attack", "train", "block", "work", "gather"]:
				_gaze_to *= 0.35
			_next_gaze = _clock + (_random.randf_range(0.5, 1.4) if wide else _random.randf_range(1.2, 3.6))
	# A saccade covers its way in about 50 ms, a glance in about 90 ms.
	var span := 0.05 + 0.04 * minf(1.0, _gaze_from.distance_to(_gaze_to) / GAZE_YAW)
	_gaze = _gaze_from.lerp(_gaze_to, smoothstep(0.0, 1.0, (_clock - _gaze_at) / span))
	_apply_gaze()


func _toward(point: Vector3) -> Vector2:
	var result := Vector2.ZERO
	var centre := Vector3.ZERO
	for eye in _eyes:
		centre += _rig.get_bone_global_rest(eye).origin * 0.5
	var forward := _rig.get_bone_global_rest(_eyes[0]).basis.y.normalized()
	var head := _rig.get_bone_parent(_eyes[0])
	# Express the target in the head's rest frame, so head motion is respected.
	var head_now := _rig.global_transform * _rig.get_bone_global_pose(head)
	var head_rest := _rig.get_bone_global_rest(head)
	var local := head_rest * (head_now.affine_inverse() * point) - centre
	if local.length() < 0.05:
		return result
	local = local.normalized()
	var side := Vector3.UP.cross(forward).normalized()
	result.x = clampf(atan2(local.dot(side), local.dot(forward)), -GAZE_YAW, GAZE_YAW)
	result.y = clampf(asin(clampf(local.dot(Vector3.UP), -1.0, 1.0)), -GAZE_PITCH, GAZE_PITCH)
	return result


func _apply_gaze() -> void:
	if not has_eyes():
		return
	for eye in _eyes:
		var rest_global := _rig.get_bone_global_rest(eye).basis.orthonormalized()
		var forward := rest_global.y
		var side := Vector3.UP.cross(forward).normalized()
		var turn := Basis(Vector3.UP, _gaze.x) * Basis(side, -_gaze.y)
		var local := _rig.get_bone_rest(eye).basis.orthonormalized() * (rest_global.inverse() * turn * rest_global)
		_rig.set_bone_pose_rotation(eye, local.get_rotation_quaternion())


func _blink(offset: float) -> float:
	if _blink_at < 0.0:
		return 0.0
	var progress := (_clock - _blink_at - offset) / _blink_duration
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	if progress < 0.34:
		return smoothstep(0.0, 0.34, progress)
	return 1.0 - smoothstep(0.34, 1.0, progress)


func _expression(action: String, at_time: float) -> PackedFloat32Array:
	var result := PackedFloat32Array([0, 0, 0, 0, 0])
	match action:
		"talk":
			var syllable := maxf(0.0, sin(at_time * TAU * 3.7))
			result[2] = 0.06 + 0.25 * syllable * syllable
			result[3] = 0.08
		"attack", "train", "block":
			result[2] = 0.08
			result[4] = 0.30
		"hit":
			result[2] = 0.28
			result[4] = 0.65
		"work", "gather":
			result[4] = 0.12
		"run":
			result[2] = 0.08
			result[4] = 0.08
		"death":
			result[2] = 0.10
	return result


func _apply() -> void:
	for target: Dictionary in _targets:
		var mesh := target.mesh as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		var slots: PackedInt32Array = target.slots
		for i in SHAPES.size():
			if slots[i] >= 0:
				mesh.set_blend_shape_value(slots[i], clampf(_values[i], 0.0, 1.0))
