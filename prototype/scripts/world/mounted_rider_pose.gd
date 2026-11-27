extends "res://scripts/visuals/character_motion.gd"
## Seated overlay on the imported person. Uses the same rest-space, limb-length
## solver as the character on foot, and keeps the actual saddle as the anchor.

var _figure: Node3D
var _figure_processed := false
var _figure_physics_processed := false
var _animators: Dictionary = {}


func start(figure: Node3D) -> bool:
	if not is_instance_valid(figure) or is_instance_valid(_figure):
		return false
	bind(figure, false, "mounted_rider")
	if not available:
		return false
	_figure = figure
	_figure_processed = figure.is_processing()
	_figure_physics_processed = figure.is_physics_processing()
	_figure.set_process(false)
	# VillagePerson's physics gaze driver can turn the same figure root while
	# the mounted controller owns heading and the seated rig.
	_figure.set_physics_process(false)
	_mute_animators()
	return true


func _mute_animators() -> void:
	for identity: int in _animators.keys():
		var saved: Array = _animators[identity]
		if not is_instance_valid((saved[0] as WeakRef).get_ref()):
			_animators.erase(identity)
	for node in _figure.find_children("*", "AnimationPlayer", true, false):
		var mixer := node as AnimationPlayer
		var identity := mixer.get_instance_id()
		if not _animators.has(identity):
			_animators[identity] = [weakref(mixer), mixer.active]
			mixer.active = false


func seated(lean: float) -> bool:
	if not is_instance_valid(_figure):
		return false
	# Profile/LOD code may replace the real rig from outside its idle callback.
	if not is_instance_valid(skeleton) or not _figure.is_ancestor_of(skeleton):
		bind(_figure, false, "mounted_rider")
		if not available:
			return false
		_mute_animators()
	if not available:
		return false
	_figure.set_process(false)
	_figure.set_physics_process(false)
	_reset()
	var size := clampf(_height / 1.5, 0.72, 1.38)
	var pitch := deg_to_rad(4.0 + 7.0 * clampf(lean, 0.0, 1.0))
	_orient("Spine", Basis(Vector3.RIGHT, pitch) * _global_rest[_ids.Spine].basis)
	_orient("Head", _global_rest[_ids.Head].basis)
	for side: String in ["L", "R"]:
		var lateral := signf(_origin("Thigh_" + side).x - _pelvis.x)
		# +Z is forward in our person's imported rest skeleton. VillagePerson
		# already rotates that model to the gameplay convention of -Z.
		var ankle := _pelvis + Vector3(lateral * 0.305, -0.51 * size, -0.025)
		_leg(side, ankle, Vector3(lateral * 0.75, 0.1, 0.88))
		var shoulder := _point("Arm_" + side)
		var wrist := _pelvis + Vector3(lateral * 0.143, 0.265 * size, 0.295 * size)
		_arm(side, shoulder + Vector3(lateral * 0.09, -0.21, 0.11) * size, wrist)
		_orient("Hand_" + side, Basis(Vector3.RIGHT, deg_to_rad(-15.0)) * _global_rest[_ids["Hand_" + side]].basis)
	skeleton.force_update_all_bone_transforms()
	return true


func pelvis_world() -> Vector3:
	return skeleton.to_global(_pelvis)


func stop() -> void:
	# Reset the temporary joint positions before returning to the original clips.
	if is_instance_valid(skeleton) and available:
		_reset()
		skeleton.force_update_all_bone_transforms()
	for saved: Array in _animators.values():
		var mixer := (saved[0] as WeakRef).get_ref() as AnimationPlayer
		if is_instance_valid(mixer):
			mixer.active = bool(saved[1])
	_animators.clear()
	if is_instance_valid(_figure):
		if _figure.has_method("reset_motion"):
			_figure.call("reset_motion")
		_figure.set_process(_figure_processed)
		_figure.set_physics_process(_figure_physics_processed)
	_figure = null
