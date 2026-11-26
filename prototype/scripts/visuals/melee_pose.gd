extends RefCounted
## Level-A melee presentation: strikes, shield guards, dodges and directional
## hit reactions on the shared fifteen-bone rigs (hero, Meshy, battle soldier).
##
## Presentation only. The melee domain owns time, contact and damage; it asks
## for a pose at an exact clip time. Contact frames are NOT authored here: the
## bake (tests/melee_strike_bake.gd) measures the displayed weapon geometry of
## these poses frame by frame and the domain uses those measurements.
##
## Authoring space ("fighter space"): +X right, +Y up, +Z forward, metres on a
## reference adult whose Head bone rests 1.46 m above the ground; each rig is
## scaled by its own head height. Hands are directions from the shoulder with a
## reach fraction of the actual arm length. Feet are planted exactly unless a
## step interval moves them through the air, so supports never slide.

const REF_HEAD := 1.46
const Core = preload("res://scripts/domain/melee/melee_core.gd")
const KITS := {
	"youth_unarmed": {"stance":"unarmed", "weapon_axis":Vector3.ZERO, "weapon_edge":Vector3.ZERO, "shield_normal":Vector3.ZERO},
	"legionary": {"stance":"roman", "weapon_axis":Vector3.UP, "weapon_edge":Vector3.RIGHT, "shield_normal":Vector3.BACK},
	"axe_fighter": {"stance":"germanic", "weapon_axis":Vector3.UP, "weapon_edge":Vector3.BACK, "shield_normal":Vector3.BACK},
	"spearman": {"stance":"roman", "weapon_axis":Vector3.ZERO, "weapon_edge":Vector3.RIGHT, "shield_normal":Vector3.BACK},
}
const STANCES := {
	"roman": {"pelvis":Vector3(0.0, -0.05, 0.02), "pyaw":-14.0, "syaw":-8.0, "lean":4.0,
		"r":[Vector3(0.10, -1.0, 0.75), 0.86], "w":Vector3(0.0, 0.30, 1.0), "e":Vector3.RIGHT,
		"l":[Vector3(0.20, -0.45, 1.0), 0.78], "s":Vector3(0.05, 0.0, 1.0),
		"foot_l":Vector3(-0.12, 0.0, 0.17), "foot_r":Vector3(0.13, 0.0, -0.13)},
	"unarmed": {"pelvis":Vector3(0.0, -0.03, 0.0), "pyaw":-10.0, "syaw":-6.0, "lean":5.0,
		"r":[Vector3(-0.15, -0.30, 1.0), 0.62], "w":Vector3(0.0, 1.0, 0.0), "e":Vector3.RIGHT,
		"l":[Vector3(0.15, -0.20, 1.0), 0.66], "s":Vector3(0.0, 0.0, 1.0),
		"foot_l":Vector3(-0.12, 0.0, 0.12), "foot_r":Vector3(0.13, 0.0, -0.10)},
	"germanic": {"pelvis":Vector3(0.0, -0.045, 0.02), "pyaw":-12.0, "syaw":-6.0, "lean":5.0,
		"r":[Vector3(0.45, -0.55, 0.65), 0.80], "w":Vector3(0.15, 0.85, 0.35), "e":Vector3(0.0, 0.1, 1.0),
		"l":[Vector3(0.15, -0.50, 1.0), 0.76], "s":Vector3(0.05, 0.0, 1.0),
		"foot_l":Vector3(-0.12, 0.0, 0.17), "foot_r":Vector3(0.14, 0.0, -0.13)},
}
## Strike programs: normalized keys; "step" lifts the named foot along an arc.
const MOVES := {
	"thrust": {"keys":[
		{"t":0.24, "pelvis":Vector3(0.02, -0.065, -0.04), "pyaw":-22.0, "syaw":-22.0, "lean":0.0, "r":[Vector3(0.30, -0.85, -0.20), 0.80], "w":Vector3(0.0, 0.10, 1.0), "e":Vector3.RIGHT},
		{"t":0.47, "pelvis":Vector3(-0.02, -0.095, 0.13), "pyaw":4.0, "syaw":16.0, "lean":12.0, "r":[Vector3(-0.10, -0.28, 1.0), 0.985], "w":Vector3(-0.06, -0.04, 1.0), "e":Vector3.RIGHT, "l":[Vector3(0.40, -0.60, 1.0), 0.70], "s":Vector3(0.30, 0.0, 1.0)},
		{"t":0.61, "pelvis":Vector3(-0.02, -0.09, 0.12), "pyaw":2.0, "syaw":13.0, "lean":10.0, "r":[Vector3(-0.08, -0.30, 1.0), 0.95], "w":Vector3(-0.05, -0.06, 1.0), "e":Vector3.RIGHT, "l":[Vector3(0.38, -0.58, 1.0), 0.72], "s":Vector3(0.25, 0.0, 1.0)}],
		"steps":[["l", 0.24, 0.45, Vector3(0.0, 0.0, 0.17), 0.07], ["l", 0.67, 0.87, Vector3(0.0, 0.0, -0.17), 0.05]]},
	"cut_inward": {"keys":[
		{"t":0.27, "pelvis":Vector3(0.02, -0.06, -0.02), "pyaw":-26.0, "syaw":-38.0, "lean":0.0, "r":[Vector3(0.90, 0.55, -0.25), 0.86], "w":Vector3(0.55, 0.65, -0.50), "e":Vector3(-0.60, -0.20, 0.70)},
		{"t":0.50, "pelvis":Vector3(-0.02, -0.085, 0.09), "pyaw":0.0, "syaw":18.0, "lean":10.0, "r":[Vector3(0.12, -0.12, 1.0), 0.97], "w":Vector3(-0.60, -0.18, 1.0), "e":Vector3(-1.0, -0.30, 0.0)},
		{"t":0.65, "pelvis":Vector3(-0.03, -0.08, 0.06), "pyaw":10.0, "syaw":38.0, "lean":8.0, "r":[Vector3(-0.70, -0.65, 0.55), 0.86], "w":Vector3(-0.90, -0.45, 0.15), "e":Vector3(-0.30, -1.0, 0.0)}],
		"steps":[["l", 0.30, 0.46, Vector3(0.0, 0.0, 0.11), 0.06], ["l", 0.70, 0.88, Vector3(0.0, 0.0, -0.11), 0.05]]},
	"cut_outward": {"keys":[
		{"t":0.27, "pelvis":Vector3(-0.01, -0.06, -0.02), "pyaw":10.0, "syaw":30.0, "lean":2.0, "r":[Vector3(-0.60, 0.25, 0.60), 0.72], "w":Vector3(-0.85, 0.50, -0.05), "e":Vector3(1.0, 0.0, 0.30)},
		{"t":0.50, "pelvis":Vector3(0.02, -0.085, 0.09), "pyaw":-12.0, "syaw":-16.0, "lean":10.0, "r":[Vector3(0.28, -0.15, 1.0), 0.97], "w":Vector3(0.55, -0.10, 1.0), "e":Vector3(1.0, 0.10, 0.0)},
		{"t":0.65, "pelvis":Vector3(0.03, -0.08, 0.05), "pyaw":-20.0, "syaw":-36.0, "lean":7.0, "r":[Vector3(0.95, -0.35, 0.30), 0.90], "w":Vector3(1.0, -0.20, -0.20), "e":Vector3(0.30, 0.0, -1.0)}],
		"steps":[["l", 0.30, 0.46, Vector3(0.0, 0.0, 0.11), 0.06], ["l", 0.70, 0.88, Vector3(0.0, 0.0, -0.11), 0.05]]},
	"overhead": {"keys":[
		{"t":0.27, "pelvis":Vector3(0.0, -0.035, -0.04), "pyaw":-16.0, "syaw":-14.0, "lean":-6.0, "r":[Vector3(0.18, 1.0, -0.20), 0.92], "w":Vector3(0.05, 0.60, -0.80), "e":Vector3(0.0, 0.80, 0.60)},
		{"t":0.38, "pelvis":Vector3(0.0, -0.06, 0.03), "pyaw":-8.0, "syaw":-4.0, "lean":4.0, "r":[Vector3(0.10, 0.90, 0.45), 0.93], "w":Vector3(0.02, 1.0, 0.05), "e":Vector3(0.0, 0.20, 1.0)},
		{"t":0.585, "pelvis":Vector3(0.0, -0.10, 0.11), "pyaw":0.0, "syaw":8.0, "lean":16.0, "r":[Vector3(0.0, -0.20, 1.0), 0.97], "w":Vector3(0.0, -0.28, 1.0), "e":Vector3(0.0, -1.0, 0.0)},
		{"t":0.72, "pelvis":Vector3(0.0, -0.10, 0.10), "pyaw":2.0, "syaw":12.0, "lean":18.0, "r":[Vector3(0.10, -0.85, 0.55), 0.86], "w":Vector3(0.05, -0.90, 0.40), "e":Vector3(0.0, -0.40, -1.0)}],
		"steps":[["l", 0.34, 0.56, Vector3(0.0, 0.0, 0.14), 0.07], ["l", 0.76, 0.93, Vector3(0.0, 0.0, -0.14), 0.05]]},
	"turn_cut": {"keys":[
		{"t":0.31, "pelvis":Vector3(0.03, -0.07, -0.03), "pyaw":-34.0, "syaw":-58.0, "lean":0.0, "r":[Vector3(1.0, 0.15, -0.50), 0.90], "w":Vector3(0.85, 0.25, -0.60), "e":Vector3(-0.40, 0.0, 0.90)},
		{"t":0.42, "pelvis":Vector3(0.01, -0.08, 0.02), "pyaw":-16.0, "syaw":-24.0, "lean":4.0, "r":[Vector3(0.85, 0.0, 0.50), 0.95], "w":Vector3(1.0, 0.10, 0.30), "e":Vector3(-0.20, 0.0, 1.0)},
		{"t":0.54, "pelvis":Vector3(-0.02, -0.09, 0.08), "pyaw":4.0, "syaw":12.0, "lean":8.0, "r":[Vector3(0.0, -0.05, 1.0), 0.97], "w":Vector3(-0.45, 0.0, 1.0), "e":Vector3(-1.0, 0.0, -0.20)},
		{"t":0.69, "pelvis":Vector3(-0.03, -0.085, 0.05), "pyaw":18.0, "syaw":52.0, "lean":6.0, "r":[Vector3(-0.90, -0.20, 0.40), 0.90], "w":Vector3(-1.0, -0.10, 0.10), "e":Vector3(0.0, 0.0, -1.0)}],
		"steps":[["l", 0.34, 0.50, Vector3(0.02, 0.0, 0.09), 0.06], ["l", 0.72, 0.90, Vector3(-0.02, 0.0, -0.09), 0.05]]},
	"axe_overhead": {"keys":[
		{"t":0.30, "pelvis":Vector3(0.0, -0.035, -0.05), "pyaw":-18.0, "syaw":-16.0, "lean":-8.0, "r":[Vector3(0.22, 1.0, -0.35), 0.93], "w":Vector3(0.05, 0.55, -0.85), "e":Vector3(0.0, 0.85, 0.55)},
		{"t":0.42, "pelvis":Vector3(0.0, -0.065, 0.04), "pyaw":-9.0, "syaw":-5.0, "lean":5.0, "r":[Vector3(0.12, 1.0, 0.30), 0.96], "w":Vector3(0.02, 1.0, 0.05), "e":Vector3(0.0, 0.20, 1.0)},
		{"t":0.56, "pelvis":Vector3(0.0, -0.11, 0.13), "pyaw":0.0, "syaw":8.0, "lean":18.0, "r":[Vector3(0.0, -0.25, 1.0), 0.98], "w":Vector3(0.0, -0.30, 1.0), "e":Vector3(0.0, -1.0, 0.0)},
		{"t":0.71, "pelvis":Vector3(0.0, -0.11, 0.12), "pyaw":3.0, "syaw":14.0, "lean":20.0, "r":[Vector3(-0.15, -0.85, 0.50), 0.88], "w":Vector3(-0.10, -0.95, 0.30), "e":Vector3(0.0, -0.30, -1.0)},
		{"t":0.84, "pelvis":Vector3(0.0, -0.07, 0.06), "pyaw":-6.0, "syaw":2.0, "lean":10.0, "r":[Vector3(0.30, -0.70, 0.70), 0.84], "w":Vector3(0.10, 0.0, 1.0), "e":Vector3(0.0, -1.0, 0.0)}],
		"steps":[["l", 0.34, 0.54, Vector3(0.0, 0.0, 0.16), 0.08], ["l", 0.76, 0.94, Vector3(0.0, 0.0, -0.16), 0.05]]},
	"axe_cut_inward": {"keys":[
		{"t":0.27, "pelvis":Vector3(0.02, -0.06, -0.03), "pyaw":-26.0, "syaw":-40.0, "lean":0.0, "r":[Vector3(0.95, 0.40, -0.30), 0.86], "w":Vector3(0.70, 0.60, -0.40), "e":Vector3(-0.50, 0.0, 0.85)},
		{"t":0.51, "pelvis":Vector3(-0.02, -0.09, 0.10), "pyaw":0.0, "syaw":18.0, "lean":10.0, "r":[Vector3(0.10, -0.10, 1.0), 0.97], "w":Vector3(-0.50, -0.05, 1.0), "e":Vector3(-1.0, -0.20, 0.0)},
		{"t":0.66, "pelvis":Vector3(-0.03, -0.085, 0.07), "pyaw":10.0, "syaw":38.0, "lean":8.0, "r":[Vector3(-0.75, -0.50, 0.50), 0.86], "w":Vector3(-0.95, -0.30, 0.10), "e":Vector3(-0.80, -0.20, -0.50)},
		{"t":0.84, "pelvis":Vector3(-0.01, -0.06, 0.04), "pyaw":-4.0, "syaw":6.0, "lean":7.0, "r":[Vector3(0.20, -0.60, 0.70), 0.82], "w":Vector3(0.10, 0.50, 0.85), "e":Vector3(-0.60, 0.0, 0.60)}],
		"steps":[["l", 0.30, 0.47, Vector3(0.0, 0.0, 0.12), 0.06], ["l", 0.70, 0.88, Vector3(0.0, 0.0, -0.12), 0.05]]},
	"axe_cut_outward": {"keys":[
		{"t":0.27, "pelvis":Vector3(-0.01, -0.06, -0.02), "pyaw":10.0, "syaw":30.0, "lean":2.0, "r":[Vector3(-0.60, 0.30, 0.60), 0.72], "w":Vector3(-0.85, 0.50, 0.0), "e":Vector3(1.0, 0.0, 0.30)},
		{"t":0.51, "pelvis":Vector3(0.02, -0.09, 0.10), "pyaw":-12.0, "syaw":-16.0, "lean":10.0, "r":[Vector3(0.30, -0.12, 1.0), 0.97], "w":Vector3(0.55, -0.05, 1.0), "e":Vector3(1.0, 0.10, 0.0)},
		{"t":0.66, "pelvis":Vector3(0.03, -0.085, 0.06), "pyaw":-20.0, "syaw":-36.0, "lean":7.0, "r":[Vector3(0.95, -0.35, 0.30), 0.90], "w":Vector3(1.0, -0.20, -0.20), "e":Vector3(0.30, 0.0, -1.0)},
		{"t":0.84, "pelvis":Vector3(0.01, -0.06, 0.04), "pyaw":-16.0, "syaw":-14.0, "lean":6.0, "r":[Vector3(0.60, -0.55, 0.60), 0.82], "w":Vector3(0.40, 0.55, 0.70), "e":Vector3(0.80, 0.0, 0.60)}],
		"steps":[["l", 0.30, 0.47, Vector3(0.0, 0.0, 0.12), 0.06], ["l", 0.70, 0.88, Vector3(0.0, 0.0, -0.12), 0.05]]},
	"spear_thrust": {"keys":[
		{"t":0.24, "pelvis":Vector3(0.02, -0.06, -0.05), "pyaw":-24.0, "syaw":-22.0, "lean":-2.0, "r":[Vector3(0.40, -0.70, -0.55), 0.86], "w":Vector3(0.0, 0.06, 1.0), "e":Vector3.RIGHT},
		{"t":0.50, "pelvis":Vector3(-0.02, -0.10, 0.14), "pyaw":4.0, "syaw":14.0, "lean":12.0, "r":[Vector3(-0.06, -0.30, 1.0), 0.985], "w":Vector3(-0.03, 0.0, 1.0), "e":Vector3.RIGHT},
		{"t":0.64, "pelvis":Vector3(-0.02, -0.095, 0.13), "pyaw":2.0, "syaw":11.0, "lean":10.0, "r":[Vector3(-0.05, -0.32, 1.0), 0.95], "w":Vector3(-0.03, -0.02, 1.0), "e":Vector3.RIGHT}],
		"steps":[["l", 0.24, 0.47, Vector3(0.0, 0.0, 0.18), 0.07], ["l", 0.70, 0.90, Vector3(0.0, 0.0, -0.18), 0.05]]},
}
## Shield guards: [shield hand direction, reach, shield face normal, spine
## yaw]. A high guard turns the face up toward a descending blow; a low guard
## turns it down toward a low one.
const GUARDS := {
	"guard_front":[Vector3(0.22, -0.38, 1.0), 0.80, Vector3(0.03, 0.0, 1.0), -4.0],
	"guard_high":[Vector3(0.20, 0.55, 1.0), 0.82, Vector3(0.0, 0.45, 1.0), -4.0],
	"guard_low":[Vector3(0.22, -0.95, 0.75), 0.82, Vector3(0.0, -0.30, 1.0), -2.0],
	"guard_left":[Vector3(-0.55, -0.35, 0.80), 0.80, Vector3(-0.75, 0.0, 0.70), 10.0],
	"guard_right":[Vector3(0.95, -0.35, 0.75), 0.86, Vector3(0.70, 0.0, 0.72), -24.0],
}
const GUARD_RAISE := 0.14
var skeleton: Skeleton3D
var available := false
var kit := ""
var _model: Node3D
var _ids := {}
var _rest: Array[Transform3D] = []
var _global_rest: Array[Transform3D] = []
var _pose: Array[Transform3D] = []
var _parent := PackedInt32Array()
var _k := 1.0
var _arm_len := {}
var _leg_len := {}
var _weapon_axis := Vector3.UP
var _weapon_edge := Vector3.RIGHT
var _shield_normal := Vector3.BACK
var _world_scale := 1.0
var _from_position: Array[Vector3] = []
var _from_rotation: Array[Quaternion] = []
var _blend_left := 0.0
var _blend_total := 0.0


## `weapon_axis_in_hand` overrides the kit axis with a measured hand-space
## axis (battle spear skinned to Hand_R), expressed in the bone's rest space.
func bind(model: Node3D, kit_id: String, weapon_axis_in_hand: Vector3 = Vector3.ZERO) -> bool:
	available = false
	kit = kit_id
	_model = model
	_ids.clear(); _rest.clear(); _global_rest.clear(); _pose.clear(); _parent.clear()
	if model == null or not KITS.has(kit_id):
		return false
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return false
	skeleton = found[0] as Skeleton3D
	for index in skeleton.get_bone_count():
		_ids[skeleton.get_bone_name(index)] = index
		_rest.append(skeleton.get_bone_rest(index))
		_global_rest.append(skeleton.get_bone_global_rest(index))
		_pose.append(skeleton.get_bone_global_rest(index))
		_parent.append(skeleton.get_bone_parent(index))
	for required: String in ["Pelvis", "Spine", "Head", "Arm_L", "Forearm_L", "Hand_L", "Arm_R", "Forearm_R", "Hand_R", "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"]:
		if not _ids.has(required):
			return false
	# Root motion is authored in world metres; the actor body may be scaled.
	_world_scale = maxf(0.01, model.scale.y)
	_k = _origin("Head").y / REF_HEAD
	for side: String in ["L", "R"]:
		_arm_len[side] = _rest[_ids["Forearm_" + side]].origin.length() + _rest[_ids["Hand_" + side]].origin.length()
		_leg_len[side] = _rest[_ids["Shin_" + side]].origin.length() + _rest[_ids["Foot_" + side]].origin.length()
	var spec: Dictionary = KITS[kit_id]
	_weapon_axis = spec.weapon_axis
	_weapon_edge = spec.weapon_edge
	_shield_normal = spec.shield_normal
	if weapon_axis_in_hand.length_squared() > 0.0:
		_weapon_axis = (_global_rest[_ids.Hand_R].basis * weapon_axis_in_hand).normalized()
		_weapon_edge = _weapon_axis.cross(Vector3.BACK).normalized()
	available = true
	return true


## Start a crossfade from the pose currently on the skeleton (state changes
## such as strike -> recoil or guard -> stance never pop).
func capture_transition(seconds: float) -> void:
	_blend_left = 0.0
	if not available or seconds <= 0.0:
		return
	_from_position.clear()
	_from_rotation.clear()
	for bone in skeleton.get_bone_count():
		_from_position.append(skeleton.get_bone_pose_position(bone))
		_from_rotation.append(skeleton.get_bone_pose_rotation(bone))
	_blend_left = seconds
	_blend_total = seconds


func advance(delta: float) -> void:
	_blend_left = maxf(0.0, _blend_left - maxf(0.0, delta))


## Strike pose at normalized clip time. Returns false for unknown moves.
func strike(move: String, normalized: float) -> bool:
	if not available or not MOVES.has(move) or not is_finite(normalized):
		return false
	var program: Dictionary = MOVES[move]
	var stance: Dictionary = STANCES[KITS[kit].stance]
	var keys: Array = [_stance_key(stance, 0.0)]
	keys.append_array(program.keys)
	keys.append(_stance_key(stance, 1.0))
	var at := clampf(normalized, 0.0, 1.0)
	var feet := _feet_at(stance, program.get("steps", []), at)
	_apply(_sample(keys, at, stance), feet)
	return true


## Guard held for `seconds` (raise over GUARD_RAISE, then hold).
func guard(style: String, seconds: float) -> bool:
	if not available or not GUARDS.has(style) or not is_finite(seconds):
		return false
	var stance: Dictionary = STANCES[KITS[kit].stance]
	var g: Array = GUARDS[style]
	var target := _stance_key(stance, 1.0)
	target.l = [g[0], g[1]]
	target.s = g[2]
	target.syaw = float(stance.syaw) + float(g[3])
	var keys: Array = [_stance_key(stance, 0.0), target]
	var raise := clampf(seconds / GUARD_RAISE, 0.0, 1.0)
	_apply(_sample(keys, smoothstep(0.0, 1.0, raise), stance), {"l":stance.foot_l, "r":stance.foot_r, "lift_l":0.0, "lift_r":0.0})
	return true


func stance_pose() -> bool:
	if not available:
		return false
	var stance: Dictionary = STANCES[KITS[kit].stance]
	_apply(_stance_key(stance, 0.0), {"l":stance.foot_l, "r":stance.foot_r, "lift_l":0.0, "lift_r":0.0})
	return true


## Root displacement of a dodge at clip seconds in fighter space (metres),
## taken from the melee domain so presentation and authority cannot differ.
static func dodge_root(style: String, seconds: float, root_scale: float = 1.0) -> Vector3:
	var local := Core.dodge_offset(style, seconds) * root_scale
	return Vector3(local.x, local.y, -local.z)


static func dodge_duration(style: String) -> float:
	return float(Core.DODGES.get(style, {}).get("duration", 0.0))


## Dodge pose. The actor root must already be displaced by dodge_root(); the
## supporting foot stays fixed in the world while the other steps.
func dodge(style: String, seconds: float, root_scale: float = 1.0) -> bool:
	if not available or not Core.DODGES.has(style) or not is_finite(seconds):
		return false
	var duration := dodge_duration(style)
	var stance: Dictionary = STANCES[KITS[kit].stance]
	var at := clampf(seconds / duration, 0.0, 1.0)
	var root := dodge_root(style, seconds, root_scale)
	var total := dodge_root(style, duration, root_scale)
	# The trailing foot (away from the motion) leaves first.
	var first := "r" if total.z < 0.0 or total.x > 0.0 else "l"
	if style == "dodge_left":
		first = "l"
	var second := "l" if first == "r" else "r"
	var feet := {"lift_l":0.0, "lift_r":0.0}
	for side: String in [first, second]:
		var window: Vector2 = Vector2(0.02, 0.48) if side == first else Vector2(0.42, 0.92)
		var progress := smoothstep(window.x, window.y, at)
		var base: Vector3 = stance["foot_" + side]
		# World-fixed while planted, then carried by the full root motion.
		feet[side] = base + _units(total * progress - root)
		feet["lift_" + side] = sin(progress * PI) * 0.07 if progress > 0.0 and progress < 1.0 else 0.0
	var key := _stance_key(stance, at)
	var crouch := sin(at * PI)
	key.pelvis = Vector3(stance.pelvis) + Vector3(0.0, -0.05 * crouch, 0.0) + _units(total * smoothstep(0.0, 0.5, at) - root) * 0.35
	key.lean = float(stance.lean) + (-8.0 if style == "dodge_back" else 2.0) * crouch
	_apply(key, feet)
	return true


## Directional hit reaction on top of the stance. `push` is the impulse
## direction in fighter space (e.g. (0,0,-1) = pushed backwards), strength
## 0..1+ scales the bend; seconds/duration drive the recovery envelope. The
## domain applies the matching root displacement (stagger step).
func reaction(push: Vector3, strength: float, seconds: float, duration: float, root_step: Vector3 = Vector3.ZERO) -> bool:
	if not available or duration <= 0.0 or not is_finite(seconds):
		return false
	var stance: Dictionary = STANCES[KITS[kit].stance]
	var at := clampf(seconds / duration, 0.0, 1.0)
	var envelope := smoothstep(0.0, 0.12, at) * (1.0 - smoothstep(0.45, 1.0, at))
	var dir := Vector3(push.x, 0.0, push.z)
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.BACK * -1.0
	var amount := clampf(strength, 0.0, 1.6) * envelope
	var key := _stance_key(stance, 0.0)
	key.lean = float(stance.lean) + dir.z * 26.0 * amount
	key.syaw = float(stance.syaw) - dir.x * 30.0 * amount
	key.pelvis = Vector3(stance.pelvis) + Vector3(dir.x * 0.05, -0.06, dir.z * 0.05) * amount
	key.head_pitch = dir.z * 22.0 * amount
	key.head_roll = -dir.x * 18.0 * amount
	key.r = [Vector3(0.35, -0.7, 0.4).lerp(Vector3(0.6, -0.2, -0.2), amount * 0.6), 0.84]
	key.l = [Vector3(0.20, -0.45, 1.0).lerp(Vector3(-0.5, -0.4, 0.2), amount * 0.5), 0.76]
	# Stagger step: the foot on the push side steps with the root displacement.
	var feet := {"l":stance.foot_l, "r":stance.foot_r, "lift_l":0.0, "lift_r":0.0}
	if root_step.length() > 0.01:
		var stepping := "r" if dir.z < 0.0 or dir.x > 0.0 else "l"
		var travelled := smoothstep(0.05, 0.40, at)
		var planted := "l" if stepping == "r" else "r"
		var root_now := root_step * travelled
		feet[planted] = Vector3(stance["foot_" + planted]) - _units(root_now)
		var progress := smoothstep(0.08, 0.45, at)
		feet[stepping] = Vector3(stance["foot_" + stepping]) + _units(root_step * progress - root_now)
		feet["lift_" + stepping] = sin(progress * PI) * 0.06 if progress > 0.0 and progress < 1.0 else 0.0
	_apply(key, feet)
	return true


func _stance_key(stance: Dictionary, t: float) -> Dictionary:
	return {"t":t, "pelvis":stance.pelvis, "pyaw":stance.pyaw, "syaw":stance.syaw, "lean":stance.lean,
		"r":stance.r, "w":stance.w, "e":stance.e, "l":stance.l, "s":stance.s}


## Cubic Hermite through the keys (finite-difference tangents, zero at the
## ends): velocity stays continuous through a contact key instead of stopping.
func _sample(keys: Array, at: float, stance: Dictionary) -> Dictionary:
	var filled: Array = []
	var last: Dictionary = keys[0]
	for key: Dictionary in keys:
		var merged := last.duplicate()
		merged.merge(key, true)
		filled.append(merged)
		last = merged
	var i := 0
	while i < filled.size() - 2 and at > float(filled[i + 1].t):
		i += 1
	var a: Dictionary = filled[i]
	var b: Dictionary = filled[mini(i + 1, filled.size() - 1)]
	var span := maxf(0.0001, float(b.t) - float(a.t))
	var u := clampf((at - float(a.t)) / span, 0.0, 1.0)
	var result := {}
	for field: String in ["pelvis", "pyaw", "syaw", "lean", "r_vec", "l_vec"]:
		result[field] = _hermite(filled, i, u, field)
	# Hands travel on the Cartesian path between shoulder-relative targets, so
	# the arm folds when a weapon passes the shoulder instead of the hand
	# sweeping around a sphere at full reach.
	for side: String in ["r", "l"]:
		var v: Vector3 = result[side + "_vec"]
		result[side] = [v if v.length_squared() > 0.0001 else Vector3.FORWARD * -0.1, clampf(v.length(), 0.25, 1.0)]
	# Tool and shield directions travel along great circles; interpolating
	# their components would collapse through zero between opposed keys.
	for field: String in ["w", "e", "s"]:
		result[field] = _slerp_dir(_value(a, field), _value(b, field), smoothstep(0.0, 1.0, u) * 0.35 + u * 0.65)
	return result


static func _slerp_dir(a: Vector3, b: Vector3, u: float) -> Vector3:
	var dot := clampf(a.dot(b), -1.0, 1.0)
	if dot > 0.9995:
		return a.lerp(b, u).normalized()
	var axis := a.cross(b)
	if axis.length_squared() < 0.000001:
		axis = Vector3.UP.cross(a) if absf(a.y) < 0.9 else Vector3.RIGHT.cross(a)
	return a.rotated(axis.normalized(), acos(dot) * u)


func _value(key: Dictionary, field: String) -> Variant:
	match field:
		"r_vec": return (key.r[0] as Vector3).normalized() * float(key.r[1])
		"l_vec": return (key.l[0] as Vector3).normalized() * float(key.l[1])
		"w", "e", "s": return (key[field] as Vector3).normalized()
	return key[field]


func _hermite(keys: Array, i: int, u: float, field: String) -> Variant:
	var n := keys.size()
	var j := mini(i + 1, n - 1)
	var p0: Variant = _value(keys[i], field)
	var p1: Variant = _value(keys[j], field)
	var t0 := float(keys[i].t)
	var t1 := float(keys[j].t)
	var span := maxf(0.0001, t1 - t0)
	var m0: Variant = p0 * 0.0
	var m1: Variant = p1 * 0.0
	if i > 0 and j < n:
		m0 = (_value(keys[j], field) - _value(keys[i - 1], field)) / maxf(0.0001, t1 - float(keys[i - 1].t)) * span
	if j < n - 1:
		m1 = (_value(keys[j + 1], field) - _value(keys[i], field)) / maxf(0.0001, float(keys[j + 1].t) - t0) * span
	var u2 := u * u
	var u3 := u2 * u
	return p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (u3 - 2.0 * u2 + u) + p1 * (-2.0 * u3 + 3.0 * u2) + m1 * (u3 - u2)


func _feet_at(stance: Dictionary, steps: Array, at: float) -> Dictionary:
	var feet := {"l":Vector3(stance.foot_l), "r":Vector3(stance.foot_r), "lift_l":0.0, "lift_r":0.0}
	for step: Array in steps:
		var side: String = step[0]
		var progress := smoothstep(float(step[1]), float(step[2]), at)
		feet[side] = Vector3(feet[side]) + Vector3(step[3]) * progress
		if progress > 0.0 and progress < 1.0:
			feet["lift_" + side] = maxf(float(feet["lift_" + side]), sin(progress * PI) * float(step[4]))
	return feet


## World metres (fighter space) to authoring units of this rig.
func _units(v: Vector3) -> Vector3:
	return v / (REF_HEAD * _k * _world_scale)


static func _m(v: Vector3) -> Vector3:
	# Fighter space (+X right, +Z forward) to the rig's model space, whose
	# right side is -X and forward is +Z.
	return Vector3(-v.x, v.y, v.z)


func _apply(key: Dictionary, feet: Dictionary) -> void:
	_reset()
	var pelvis_offset: Vector3 = _m(Vector3(key.pelvis) * REF_HEAD) * _k
	var pyaw := deg_to_rad(float(key.pyaw))
	var syaw := deg_to_rad(float(key.syaw)) - pyaw
	var lean := deg_to_rad(float(key.lean))
	var pelvis_point := _origin("Pelvis") + pelvis_offset
	# Keep both planted soles reachable: lower the pelvis instead of letting a
	# clamped leg solve drag a support foot across the ground.
	for iteration in 6:
		var deficit := 0.0
		for side: String in ["L", "R"]:
			var foot_target := _foot_target(side, feet)
			var hip := pelvis_point + Basis(Vector3.UP, pyaw) * (_origin("Thigh_" + side) - _origin("Pelvis"))
			var excess := hip.distance_to(foot_target) - float(_leg_len[side]) * 0.985
			deficit = maxf(deficit, excess)
		if deficit <= 0.0:
			break
		pelvis_point.y -= deficit + 0.002
	_place("Pelvis", Basis(Vector3.UP, pyaw) * _global_rest[_ids.Pelvis].basis, pelvis_point)
	var spine_basis := Basis(Vector3.UP, pyaw + syaw) * Basis(Vector3.RIGHT, lean) * _global_rest[_ids.Spine].basis
	_orient("Spine", spine_basis)
	# The head keeps the opponent in view: most of the torso turn is undone.
	var head_basis := Basis(Vector3.UP, deg_to_rad(float(key.syaw)) * 0.25) * Basis(Vector3.RIGHT, deg_to_rad(float(key.get("head_pitch", 0.0)) - float(key.lean) * 0.5)) * Basis(Vector3.BACK, deg_to_rad(float(key.get("head_roll", 0.0))))
	_orient("Head", head_basis * _global_rest[_ids.Head].basis)
	# Weapon arm and weapon orientation.
	var r: Array = key.r
	var shoulder_r := _point("Arm_R")
	var wrist_r: Vector3 = shoulder_r + _m(Vector3(r[0]).normalized()) * float(_arm_len.R) * float(r[1])
	_arm("R", wrist_r, _m(Vector3(0.55, -1.0, -0.35)))
	_orient_tool("Hand_R", _m(Vector3(key.w)), _m(Vector3(key.e)), _weapon_axis, _weapon_edge)
	# Shield arm: the shield face follows the authored normal, rim kept upright.
	var l: Array = key.l
	var shoulder_l := _point("Arm_L")
	var wrist_l: Vector3 = shoulder_l + _m(Vector3(l[0]).normalized()) * float(_arm_len.L) * float(l[1])
	_arm("L", wrist_l, _m(Vector3(-0.75, -1.0, -0.15)))
	_orient_tool("Hand_L", _m(Vector3(key.s)), Vector3.UP, _shield_normal, Vector3.UP)
	for side: String in ["L", "R"]:
		_leg(side, _foot_target(side, feet), _m(Vector3(0.0, 0.0, 1.0)))
	if _blend_left > 0.0 and _from_position.size() == skeleton.get_bone_count():
		var w := smoothstep(0.0, 1.0, 1.0 - _blend_left / _blend_total)
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_position(bone, _from_position[bone].lerp(skeleton.get_bone_pose_position(bone), w))
			skeleton.set_bone_pose_rotation(bone, _from_rotation[bone].slerp(skeleton.get_bone_pose_rotation(bone), w))
	skeleton.force_update_all_bone_transforms()


func _foot_target(side: String, feet: Dictionary) -> Vector3:
	var key := side.to_lower()
	var rest := _origin("Foot_" + side)
	var authored: Vector3 = feet[key]
	var neutral := Vector3(0.11 if side == "R" else -0.11, 0.0, 0.0)
	# Authored positions are offsets from the reference neutral stance, so the
	# rig's own rest ankle height and width are preserved exactly.
	var offset := _m((authored - neutral) * REF_HEAD) * _k
	return rest + offset + Vector3(0.0, float(feet["lift_" + key]) * REF_HEAD * _k, 0.0)


func _orient_tool(bone: String, axis_target: Vector3, edge_target: Vector3, axis_rest: Vector3, edge_rest: Vector3) -> void:
	# Hand rotation that carries the rest tool axis onto the target and then
	# rolls the edge/rim toward its target around that axis.
	var source: Basis = _global_rest[_ids[bone]].basis
	var target := axis_target.normalized()
	var from := axis_rest.normalized()
	if target.length_squared() < 0.5 or from.length_squared() < 0.5:
		return
	var swing := Basis(Quaternion(from, target)) if from.dot(target) > -0.9999 else Basis(Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.UP, PI)
	var edge_now := swing * edge_rest
	var desired := edge_target - target * edge_target.dot(target)
	edge_now = edge_now - target * edge_now.dot(target)
	var twist := Basis.IDENTITY
	if desired.length_squared() > 0.0001 and edge_now.length_squared() > 0.0001:
		desired = desired.normalized()
		edge_now = edge_now.normalized()
		var angle := atan2(target.dot(edge_now.cross(desired)), edge_now.dot(desired))
		twist = Basis(target, angle)
	_orient(bone, twist * swing * source)


func _reset() -> void:
	for bone in _rest.size():
		skeleton.set_bone_pose_position(bone, _rest[bone].origin)
		skeleton.set_bone_pose_rotation(bone, _rest[bone].basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, Vector3.ONE)
		_pose[bone] = _global_rest[bone]


func _origin(name: String) -> Vector3:
	return _global_rest[_ids[name]].origin


func _point(name: String) -> Vector3:
	var bone: int = _ids[name]
	var parent := _parent[bone]
	return _pose[parent] * _rest[bone].origin if parent >= 0 else _rest[bone].origin


func _place(name: String, basis: Basis, point: Vector3) -> void:
	var bone: int = _ids[name]
	var parent := _parent[bone]
	var transform := Transform3D(basis.orthonormalized(), point)
	var local := _pose[parent].affine_inverse() * transform if parent >= 0 else transform
	skeleton.set_bone_pose_position(bone, local.origin)
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())
	_pose[bone] = transform


func _orient(name: String, basis: Basis) -> void:
	_place(name, basis, _point(name))


func _aim(name: String, toward: Vector3, child: String) -> void:
	var source: Basis = _global_rest[_ids[name]].basis
	var direction := toward.normalized()
	if direction.length_squared() < 0.5:
		return
	var segment := source * _rest[_ids[child]].origin
	var rest_axis := segment.normalized() if segment.length_squared() > 0.00000001 else source.y.normalized()
	_orient(name, Basis(Quaternion(rest_axis, direction)) * source)


func _arm(side: String, wrist: Vector3, pole: Vector3) -> void:
	var shoulder := _point("Arm_" + side)
	var upper := _rest[_ids["Forearm_" + side]].origin.length()
	var lower := _rest[_ids["Hand_" + side]].origin.length()
	var elbow := _joint(shoulder, wrist, upper, lower, pole)
	_aim("Arm_" + side, elbow - shoulder, "Forearm_" + side)
	_aim("Forearm_" + side, wrist - _point("Forearm_" + side), "Hand_" + side)


func _leg(side: String, foot: Vector3, bend: Vector3) -> void:
	var hip := _point("Thigh_" + side)
	var upper := _rest[_ids["Shin_" + side]].origin.length()
	var lower := _rest[_ids["Foot_" + side]].origin.length()
	var knee := _joint(hip, foot, upper, lower, bend)
	_aim("Thigh_" + side, knee - hip, "Shin_" + side)
	_aim("Shin_" + side, foot - _point("Shin_" + side), "Foot_" + side)
	_orient("Foot_" + side, _global_rest[_ids["Foot_" + side]].basis)


static func _joint(start: Vector3, finish: Vector3, upper: float, lower: float, bend: Vector3) -> Vector3:
	var delta := finish - start
	var distance := clampf(delta.length(), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var direction := delta.normalized() if delta.length_squared() > 0.000000000001 else Vector3.BACK
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var normal := bend - direction * bend.dot(direction)
	if normal.length_squared() < 0.0001:
		var axis := Vector3.RIGHT if absf(direction.x) < 0.9 else Vector3.UP
		normal = axis - direction * direction.dot(axis)
	return start + direction * along + normal.normalized() * sqrt(maxf(0.0, upper * upper - along * along))
