extends Node
## Speech-driven mouth animation from phoneme-aligned viseme tracks.
##
## Sampling: every viseme segment contributes a weight that ramps in over
## COART_IN seconds centred on its start and out over COART_OUT centred on its
## end (smoothstep). The ramp crosses 0.5 exactly at the aligned phoneme
## boundary, so the measurable mouth onset coincides with the audio onset while
## neighbouring shapes still overlap (coarticulation).
##
## Outputs, all optional and discovered at bind time:
##   * Jaw bone rotation on a Skeleton3D bone named "Jaw" (youth rig).
##   * Blend shapes "viseme_<name>" (15-viseme set) if a mesh has them.
##   * ARKit-style shapes (jawOpen, mouthFunnel, mouthPucker, mouthClose,
##     mouthStretchLeft/Right, mouthRollLower, mouthPressLeft/Right).
##   * Generic articulation shapes jaw_open, lip_round, lip_wide, lip_close,
##     lip_tuck (procedural test head and future custom heads).
##   * The existing character morphs JawOpen, Blink_L, Blink_R (frontier and
##     hero GLBs, see scripts/visuals/facial_motion.gd). Other morphs on those
##     meshes (Smile, BrowDown, Mature, Companion) are left untouched.
## Blink and breathing are layered on when the matching shapes/bones exist.

const VISEMES := ["sil", "PP", "FF", "TH", "DD", "kk", "CH", "SS", "nn", "RR", "aa", "E", "ih", "oh", "ou"]
## Articulation parameters per viseme: jaw opening, lip rounding/protrusion,
## lip spreading, lip closure/press, lower-lip tuck (labiodental).
const POSE := {
	"sil": [0.0, 0.0, 0.0, 0.0, 0.0],
	"PP": [0.03, 0.0, 0.0, 1.0, 0.0],
	"FF": [0.12, 0.0, 0.1, 0.0, 1.0],
	"TH": [0.18, 0.0, 0.25, 0.0, 0.0],
	"DD": [0.22, 0.0, 0.25, 0.0, 0.0],
	"kk": [0.28, 0.0, 0.15, 0.0, 0.0],
	"CH": [0.16, 0.65, 0.0, 0.0, 0.0],
	"SS": [0.08, 0.0, 0.55, 0.0, 0.0],
	"nn": [0.16, 0.0, 0.25, 0.0, 0.0],
	"RR": [0.22, 0.35, 0.05, 0.0, 0.0],
	"aa": [1.0, 0.0, 0.2, 0.0, 0.0],
	"E": [0.5, 0.0, 0.6, 0.0, 0.0],
	"ih": [0.28, 0.0, 0.85, 0.0, 0.0],
	"oh": [0.62, 0.8, 0.0, 0.0, 0.0],
	"ou": [0.26, 1.0, 0.0, 0.0, 0.0],
}
const PARAMS := ["jaw_open", "lip_round", "lip_wide", "lip_close", "lip_tuck"]
const COART_IN := 0.06
const COART_OUT := 0.08
const ACTIVITY_SIL := 0

## Maximum jaw rotation in radians for a fully open "aa" (speech range 5-15 deg).
@export var jaw_max_angle := deg_to_rad(13.0)
@export var jaw_axis := Vector3(1.0, 0.0, 0.0)
@export var jaw_bone_name := "Jaw"
@export var blink_enabled := true

var track: Dictionary = {}
## Callable returning the dialogue clock in seconds since line start.
var clock := Callable()
var params := {"jaw_open": 0.0, "lip_round": 0.0, "lip_wide": 0.0, "lip_close": 0.0, "lip_tuck": 0.0}
var viseme_weights: PackedFloat32Array = PackedFloat32Array()
## Sum of non-silence viseme weights; >= 0.5 means the mouth is articulating.
var activity := 0.0

var _skeleton: Skeleton3D
var _jaw := -1
var _jaw_rest := Quaternion.IDENTITY
var _meshes: Array[MeshInstance3D] = []
var _rng := RandomNumberGenerator.new()
var _blink_t := 0.5
var _next_blink := 3.0


func _init() -> void:
	viseme_weights.resize(VISEMES.size())


## Binds every Skeleton3D/MeshInstance3D under root. Returns a description of
## the outputs found, which tests use to prove what was actually driven.
func bind(root: Node) -> Dictionary:
	_meshes.clear()
	_skeleton = null
	_jaw = -1
	_collect(root)
	var shapes := 0
	for mesh in _meshes:
		shapes += mesh.mesh.get_blend_shape_count() if mesh.mesh is ArrayMesh else 0
	return {"jaw_bone": _jaw != -1, "meshes": _meshes.size(), "blend_shapes": shapes}


func _collect(node: Node) -> void:
	if node is Skeleton3D and _jaw == -1:
		var bone := (node as Skeleton3D).find_bone(jaw_bone_name)
		if bone != -1:
			_skeleton = node
			_jaw = bone
			_jaw_rest = _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh and (node as MeshInstance3D).mesh.get_blend_shape_count() > 0:
		_meshes.append(node)
	for child in node.get_children():
		_collect(child)


func set_track(new_track: Dictionary, new_clock: Callable) -> void:
	track = new_track
	clock = new_clock


func clear() -> void:
	track = {}
	clock = Callable()
	sample(0.0)
	_apply()


## Pure function of time: fills viseme_weights, params and activity.
func sample(t: float) -> void:
	for i in viseme_weights.size():
		viseme_weights[i] = 0.0
	var segments: Array = track.get("segments", [])
	for seg: Array in segments:
		var s := float(seg[0])
		var e := float(seg[1])
		if t < s - COART_IN * 0.5 or t > e + COART_OUT * 0.5:
			continue
		var w_in := smoothstep(s - COART_IN * 0.5, s + COART_IN * 0.5, t)
		var w_out := 1.0 - smoothstep(e - COART_OUT * 0.5, e + COART_OUT * 0.5, t)
		var idx := int(seg[2])
		viseme_weights[idx] = maxf(viseme_weights[idx], minf(w_in, w_out))
	activity = 0.0
	var total := 0.0
	for i in viseme_weights.size():
		total += viseme_weights[i]
		if i != ACTIVITY_SIL:
			activity += viseme_weights[i]
	for p in PARAMS:
		params[p] = 0.0
	if total <= 0.0:
		return
	# Weighted average of poses, scaled by the overall articulation so the
	# mouth relaxes towards neutral between phrases.
	var scale := minf(1.0, activity)
	for i in viseme_weights.size():
		var w := viseme_weights[i]
		if w <= 0.0:
			continue
		var pose: Array = POSE[VISEMES[i]]
		for k in PARAMS.size():
			params[PARAMS[k]] += pose[k] * w / total * scale


func _process(delta: float) -> void:
	if clock.is_valid() and not track.is_empty():
		sample(float(clock.call()))
	else:
		sample(-1.0)
	_update_blink(delta)
	_apply()


func _update_blink(delta: float) -> void:
	if not blink_enabled:
		return
	_blink_t += delta
	if _blink_t >= _next_blink:
		_blink_t = 0.0
		# Bentivoglio et al. 1997: ~17 blinks/min at rest, ~26/min in conversation.
		_next_blink = _rng.randf_range(1.6, 3.0) if activity > 0.5 else _rng.randf_range(2.3, 4.6)


func blink_weight() -> float:
	# 150 ms blink: fast close, slower open.
	var t := _blink_t
	if t < 0.06:
		return t / 0.06
	if t < 0.15:
		return 1.0 - (t - 0.06) / 0.09
	return 0.0


func _apply() -> void:
	if _jaw != -1:
		var q := Quaternion(jaw_axis.normalized(), jaw_max_angle * float(params.jaw_open))
		_skeleton.set_bone_pose_rotation(_jaw, _jaw_rest * q)
	for mesh in _meshes:
		_apply_mesh(mesh)


func _apply_mesh(mesh: MeshInstance3D) -> void:
	var m: ArrayMesh = mesh.mesh
	for i in m.get_blend_shape_count():
		var name := String(m.get_blend_shape_name(i))
		var w := _shape_weight(name)
		if w >= 0.0:
			mesh.set_blend_shape_value(i, clampf(w, 0.0, 1.0))


## Returns the weight for a known shape name, or -1 when the name is unknown.
func _shape_weight(name: String) -> float:
	if name.begins_with("viseme_"):
		var idx := VISEMES.find(name.trim_prefix("viseme_"))
		return viseme_weights[idx] if idx != -1 else -1.0
	match name:
		"jaw_open", "jawOpen", "JawOpen":
			# Rigs with a Jaw bone open the mouth through the bone; a mesh-level
			# jaw morph on the same face would double the opening.
			return float(params.jaw_open) * (0.0 if _jaw != -1 and name != "jaw_open" else 1.0)
		"lip_round":
			return float(params.lip_round)
		"mouthFunnel":
			return float(params.lip_round) * float(params.jaw_open)
		"mouthPucker":
			return float(params.lip_round) * (1.0 - float(params.jaw_open))
		"lip_wide", "mouthStretchLeft", "mouthStretchRight":
			return float(params.lip_wide)
		"lip_close", "mouthClose", "mouthPressLeft", "mouthPressRight":
			return float(params.lip_close)
		"lip_tuck", "mouthRollLower":
			return float(params.lip_tuck)
		"blink", "eyeBlinkLeft", "eyeBlinkRight", "eyes_closed", "Blink_L", "Blink_R":
			return blink_weight() if blink_enabled else 0.0
	return -1.0
