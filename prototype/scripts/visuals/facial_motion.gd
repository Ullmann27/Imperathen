extends RefCounted
## Drives authored glTF face shapes on individual instances. This is expressive
## motion for the existing silent dialogue clips, not audio-derived lip sync.

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
var _distant := false
# The recorded dialogue clock owns JawOpen while a voice is bound. Other
# expressions (including both eyelids) continue to use this actor's motion.
var _audio_jaw_owned: bool = false


func _set_audio_jaw_owner(owned: bool) -> void:
	if owned == _audio_jaw_owned:
		return
	# Clear the old expressive jaw before transfer, and reset it on release.
	_audio_jaw_owned = false
	_values[2] = 0.0
	_apply()
	_audio_jaw_owned = owned


func bind(model: Node3D, actor_identity: String) -> void:
	_targets.clear()
	if _identity != actor_identity:
		_identity = actor_identity
		_random.seed = actor_identity.hash()
		_clock = 0.0
		_blink_at = -1.0
		_next_blink = _random.randf_range(1.2, 3.8)
		_values.fill(0.0)
		_distant = false
	_elapsed = 0.0
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for mesh: MeshInstance3D in meshes:
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
	if _clock >= _next_blink:
		_blink_at = _clock
		_blink_duration = _random.randf_range(0.16, 0.21)
		_next_blink = _clock + _random.randf_range(2.4, 5.6)
	# Clear exactly once on entry, including distance changes without a rebind.
	# Do not accumulate near-face interpolation time while distant.
	if detail >= 2:
		if not _distant:
			_values.fill(0.0)
			_apply()
		_distant = true
		_elapsed = 0.0
		return
	_distant = false
	_elapsed += delta
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
	_distant = detail >= 2
	if _distant:
		_values.fill(0.0)
		_elapsed = 0.0
	_apply()


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
			if slots[i] >= 0 and not (i == 2 and _audio_jaw_owned):
				mesh.set_blend_shape_value(slots[i], clampf(_values[i], 0.0, 1.0))
