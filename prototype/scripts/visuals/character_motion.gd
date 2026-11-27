extends RefCounted
## Own deterministic poses on the imported skin. Directions are solved in the
## actual skeleton rest space; Blender bone roll is never treated as world axes.

const TECHNIQUES := ["jab_left", "jab_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right", "headbutt", "front_kick", "side_kick", "high_kick"]
const ARMED_ATTACKS := ["cut_inward", "cut_outward", "thrust", "overhead", "turn_cut"]
const SHIELD_GUARDS := ["guard_front", "guard_high", "guard_low", "guard_left", "guard_right"]
const TIMING := {
	"jab_left": Vector3(0.18, 0.14, 0.62), "jab_right": Vector3(0.21, 0.14, 0.68),
	"hook_left": Vector3(0.27, 0.16, 0.82), "hook_right": Vector3(0.27, 0.16, 0.82),
	"uppercut_left": Vector3(0.30, 0.17, 0.90), "uppercut_right": Vector3(0.30, 0.17, 0.90),
	"headbutt": Vector3(0.23, 0.14, 0.76), "front_kick": Vector3(0.34, 0.20, 1.05),
	"side_kick": Vector3(0.40, 0.22, 1.20), "high_kick": Vector3(0.44, 0.24, 1.30),
}
const CC0Gestures := preload("res://scripts/visuals/cc0_gestures.gd")
static var _playback_variants: Dictionary = {}
var external_gestures := false

var skeleton: Skeleton3D
var available := false
var civilian := false
var _ids := {}
var _rest: Array[Transform3D] = []
var _global_rest: Array[Transform3D] = []
var _pose: Array[Transform3D] = []
var _parent := PackedInt32Array()
var _height := 1.5
var _pelvis := Vector3.ZERO
var _feet := {}
var _transition_positions: Array[Vector3] = []
var _transition_rotations: Array[Quaternion] = []
var _transition_remaining := 0.0
var _transition_duration := 0.0
var _style_phase := 0.0
var _world_contacts := {}
var _world_supported := {}
var _world_swings := {}
var _world_previous := Transform3D.IDENTITY
var _world_initialized := false
var _world_action := ""
var _turn_step_side := ""
var _turn_step_time := 0.0
var _turn_step_from := Transform3D.IDENTITY


static func playback_animation(source: Animation, mode: Animation.LoopMode) -> Animation:
	# One immutable variant per live source/mode, shared by both actor drivers.
	# Weak references let unused LOD tracks unload; IDs alone are not enough
	# to identify a source after its resource has been freed and replaced.
	if source.loop_mode == mode:
		return source
	var key := str(source.get_instance_id()) + "/" + str(mode)
	var cached: Dictionary = _playback_variants.get(key, {})
	if not cached.is_empty() and (cached.source as WeakRef).get_ref() == source:
		var animation := (cached.animation as WeakRef).get_ref() as Animation
		if animation and animation.loop_mode == mode:
			return animation
	# Sweep only on a cache miss, never per-frame on the normal shared path.
	for prior_key: String in _playback_variants.keys():
		var prior: Dictionary = _playback_variants[prior_key]
		if (prior.source as WeakRef).get_ref() == null or (prior.animation as WeakRef).get_ref() == null:
			_playback_variants.erase(prior_key)
	var variant := source.duplicate() as Animation
	variant.loop_mode = mode
	_playback_variants[key] = {"source":weakref(source), "animation":weakref(variant)}
	return variant


func bind(model: Node3D, is_civilian: bool, actor_identity: String = "") -> void:
	available = false
	skeleton = null
	civilian = is_civilian
	# Stable individuality across LOD replacement and independent actors.
	_style_phase = float(posmod(actor_identity.hash(), 997)) / 997.0
	_ids.clear()
	_rest.clear()
	_global_rest.clear()
	_pose.clear()
	_parent.clear()
	_feet.clear()
	_transition_remaining = 0.0
	reset_world_contacts()
	var found := model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	skeleton = found[0] as Skeleton3D
	for index in skeleton.get_bone_count():
		_ids[skeleton.get_bone_name(index)] = index
		_rest.append(skeleton.get_bone_rest(index))
		_global_rest.append(skeleton.get_bone_global_rest(index))
		_pose.append(skeleton.get_bone_global_rest(index))
		_parent.append(skeleton.get_bone_parent(index))
	for required: String in ["Pelvis", "Spine", "Head", "Arm_L", "Forearm_L", "Hand_L", "Arm_R", "Forearm_R", "Hand_R", "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"]:
		if not _ids.has(required):
			return
	_pelvis = _origin("Pelvis")
	_height = _origin("Head").y / 0.845
	_feet.L = _origin("Foot_L")
	_feet.R = _origin("Foot_R")
	available = true


func capture_transition(seconds: float) -> void:
	_transition_remaining = 0.0
	if not available or seconds <= 0.0:
		return
	_transition_positions.clear()
	_transition_rotations.clear()
	for bone in skeleton.get_bone_count():
		_transition_positions.append(skeleton.get_bone_pose_position(bone))
		_transition_rotations.append(skeleton.get_bone_pose_rotation(bone))
	_transition_duration = seconds
	_transition_remaining = seconds


func advance(delta: float) -> void:
	_transition_remaining = maxf(0.0, _transition_remaining - maxf(0.0, delta))


func capture_lod_transition() -> Dictionary:
	# An LOD change is not an animation event. Keep an active crossfade and
	# its displayed local pose, not merely the destination clip and phase.
	if not available or _transition_remaining <= 0.0:
		return {}
	var joints: Array[Dictionary] = []
	for bone in skeleton.get_bone_count():
		joints.append({
			"name":skeleton.get_bone_name(bone),
			"parent":skeleton.get_bone_parent(bone),
			"rest":skeleton.get_bone_rest(bone),
			"position":skeleton.get_bone_pose_position(bone),
			"rotation":skeleton.get_bone_pose_rotation(bone),
			"scale":skeleton.get_bone_pose_scale(bone)
		})
	return {"joints":joints,"positions":_transition_positions.duplicate(),
		"rotations":_transition_rotations.duplicate(),
		"remaining":_transition_remaining,"duration":_transition_duration}


func restore_lod_transition(state: Dictionary) -> bool:
	if not available or state.is_empty():
		return false
	var joints: Array = state.joints
	var count := skeleton.get_bone_count()
	if joints.size()!=count or state.positions.size()!=count or state.rotations.size()!=count:
		return false
	# Do not transfer local poses onto a different rig or anatomical rest
	# shape. A failed compatibility check leaves its own sampled pose intact.
	for bone in count:
		var joint: Dictionary = joints[bone]
		var rest: Transform3D = joint.rest
		if joint.name!=skeleton.get_bone_name(bone) or int(joint.parent)!=skeleton.get_bone_parent(bone) or not rest.is_equal_approx(skeleton.get_bone_rest(bone)):
			return false
	_transition_positions.clear()
	_transition_rotations.clear()
	for bone in count:
		var joint: Dictionary = joints[bone]
		_transition_positions.append(state.positions[bone])
		_transition_rotations.append(state.rotations[bone])
		skeleton.set_bone_pose_position(bone,joint.position)
		skeleton.set_bone_pose_rotation(bone,joint.rotation)
		skeleton.set_bone_pose_scale(bone,joint.scale)
	_transition_duration = float(state.duration)
	_transition_remaining = float(state.remaining)
	skeleton.force_update_all_bone_transforms()
	return true


func reset_world_contacts() -> void:
	_world_contacts.clear()
	_world_supported.clear()
	_world_swings.clear()
	_world_initialized = false
	_world_action = ""
	_turn_step_side = ""
	_turn_step_time = 0.0


func world_foot_supported(side: String) -> bool:
	return bool(_world_supported.get(side, false))


func capture_world_contacts() -> Dictionary:
	if not available or not _world_initialized:
		return {}
	return {"contacts":_world_contacts.duplicate(true),"supported":_world_supported.duplicate(),
		"swings":_world_swings.duplicate(true),"previous":_world_previous,"action":_world_action,
		"turn_side":_turn_step_side,"turn_time":_turn_step_time,"turn_from":_turn_step_from}


func restore_world_contacts(state: Dictionary) -> void:
	# Transient presentation continuity across an LOD swap, never saved game
	# state. Bone names/rest lengths are rebound to the actual replacement.
	if not available or state.is_empty():
		return
	_world_contacts = state.contacts.duplicate(true)
	_world_supported = state.supported.duplicate()
	_world_swings = state.swings.duplicate(true)
	_world_previous = state.previous
	_world_action = state.action
	_turn_step_side = state.turn_side
	_turn_step_time = state.turn_time
	_turn_step_from = state.turn_from
	_world_initialized = true


func plant_world_feet(action: String, phase: float, delta: float, stance: float, preserve_authored_roll: bool = false) -> void:
	# Root translation and turning are owned by the collision body. A local
	# animation alone cannot keep a planted sole at its world contact while the
	# body turns or changes speed. Solve those same, unstretched leg lengths to
	# the saved contact after every authored pose and crossfade has been applied.
	if not available or not skeleton.is_inside_tree():
		return
	var walking := action in ["march", "run", "retreat"]
	var standing := action in ["idle", "talk", "work", "block", "attack", "train", "shoot", "wall", "testudo", "hit"]
	if not walking and not standing:
		reset_world_contacts()
		return
	var current := skeleton.global_transform
	if _world_initialized and current.origin.distance_to(_world_previous.origin) > 0.75:
		reset_world_contacts()
	if action != _world_action:
		_world_contacts.clear()
		_world_swings.clear()
		_turn_step_side = ""
		_turn_step_time = 0.0
	_world_action = action
	_world_previous = current
	_world_initialized = true
	skeleton.force_update_all_bone_transforms()
	for bone in skeleton.get_bone_count():
		_pose[bone] = skeleton.get_bone_global_pose(bone)
	var desired := {}
	var targets := {}
	var local_from_world := current.affine_inverse()
	for side: String in ["L", "R"]:
		var u := fposmod(phase + (0.5 if side == "L" else 0.0), 1.0)
		var supported := standing or u <= stance
		var foot: Transform3D = current * _pose[_ids["Foot_" + side]]
		desired[side] = foot
		var contact: Dictionary = _world_contacts.get(side, {})
		if walking and preserve_authored_roll:
			# Capture only central stance. The recorded heel strike, toe-off,
			# vertical arc and ankle roll are part of the human gait; freezing
			# them would turn the captured walk back into a mechanical march.
			var central_stance := u >= 0.08 and u <= stance - 0.05
			var corrected := foot
			if central_stance:
				if contact.is_empty() or u + 0.00001 < float(contact.phase):
					contact = {"transform":foot,"phase":u}
				contact.phase = u
				var correction := Transform3D(contact.transform).origin - foot.origin
				correction.y = 0.0
				var envelope := smoothstep(0.08,0.17,u) * (1.0-smoothstep(stance-0.13,stance-0.05,u))
				corrected.origin += correction.limit_length(0.075*current.basis.get_scale().y)*envelope
				_world_contacts[side] = contact
			else:
				_world_contacts.erase(side)
			_world_swings.erase(side)
			targets[side] = corrected
			_world_supported[side] = central_stance
			continue
		if supported:
			_world_swings.erase(side)
			if contact.is_empty() or (walking and u + 0.00001 < float(contact.phase)):
				contact = {"transform": foot, "phase": u}
			contact.phase = u
			# Preserve only the correction made while this foot was planted.
			# Measuring it after lift-off would also cancel the first authored
			# swing displacement, introducing a frame-rate-dependent delay.
			contact.offset = Transform3D(contact.transform).origin - foot.origin
			_world_contacts[side] = contact
			targets[side] = contact.transform
		else:
			# Releasing a planted foot must not snap its world-locked rotation
			# to the now-turned body. Retain the real release transform and
			# dissipate its positional correction over the lifted swing arc.
			var swing: Dictionary = _world_swings.get(side,{})
			if swing.is_empty():
				var release: Transform3D = contact.get("transform",foot)
				swing = {"from":release,"offset":contact.get("offset",Vector3.ZERO),"phase":u}
				_world_swings[side] = swing
			var progress := clampf((u-float(swing.phase))/maxf(.0001,1.0-float(swing.phase)),0.0,1.0)
			var released: Transform3D = swing.from
			var stepping := released.interpolate_with(foot,smoothstep(0.0,1.0,progress))
			stepping.origin = foot.origin+Vector3(swing.offset)*(1.0-smoothstep(0.0,.65,progress))
			targets[side] = stepping
			_world_contacts.erase(side)
		_world_supported[side] = supported
	# A stationary actor turns with short alternating steps. Keeping both feet
	# glued through an arbitrarily large turn would cross the legs. These are
	# real lifted swing arcs, while the other foot remains at its saved contact.
	if standing:
		if _turn_step_side.is_empty():
			var largest := 0.0
			for side: String in ["L", "R"]:
				var anchor: Transform3D = targets[side]
				var wanted: Transform3D = desired[side]
				var horizontal := Vector2(wanted.origin.x-anchor.origin.x, wanted.origin.z-anchor.origin.z).length()
				var turn := anchor.basis.orthonormalized().get_rotation_quaternion().angle_to(wanted.basis.orthonormalized().get_rotation_quaternion())
				var demand := maxf(horizontal / 0.09, turn / 0.32)
				if demand > 1.0 and demand > largest:
					largest = demand
					_turn_step_side = side
			if not _turn_step_side.is_empty():
				_turn_step_time = 0.0
				_turn_step_from = targets[_turn_step_side]
		if not _turn_step_side.is_empty():
			_turn_step_time += maxf(0.0, delta)
			var t := minf(1.0, _turn_step_time / 0.24)
			var wanted: Transform3D = desired[_turn_step_side]
			var step := _turn_step_from.interpolate_with(wanted, smoothstep(0.0, 1.0, t))
			step.origin.y += sin(t * PI) * 0.065 * current.basis.get_scale().y
			targets[_turn_step_side] = step
			_world_supported[_turn_step_side] = t >= 1.0
			if t >= 1.0:
				_world_contacts[_turn_step_side] = {"transform": wanted, "phase": phase}
				_turn_step_side = ""
	# Lower the pelvis only as far as a saved contact requires. This keeps both
	# the upper and lower leg at their actual rest lengths during a hard stop.
	var lower_pelvis := 0.0
	for side: String in targets:
		if walking and preserve_authored_roll and Transform3D(targets[side]).origin.distance_to(Transform3D(desired[side]).origin)<0.001:
			continue
		var target: Vector3 = local_from_world * Transform3D(targets[side]).origin
		var hip := _point("Thigh_" + side)
		var reach := _rest[_ids["Shin_" + side]].origin.length() + _rest[_ids["Foot_" + side]].origin.length() - 0.001
		var horizontal := Vector2(target.x-hip.x, target.z-hip.z).length()
		var vertical := sqrt(maxf(0.0001, reach*reach-horizontal*horizontal))
		lower_pelvis = maxf(lower_pelvis, hip.y-target.y-vertical)
	if lower_pelvis > 0.0:
		var pelvis_pose: Transform3D = _pose[_ids.Pelvis]
		_place("Pelvis", pelvis_pose.basis, pelvis_pose.origin-Vector3.UP*minf(lower_pelvis,0.16))
		# Preserve the authored local upper body after its parent has moved.
		skeleton.force_update_all_bone_transforms()
		for bone in skeleton.get_bone_count():
			_pose[bone] = skeleton.get_bone_global_pose(bone)
	for side: String in targets:
		var world_target: Transform3D = targets[side]
		if walking and preserve_authored_roll and world_target.origin.distance_to(Transform3D(desired[side]).origin)<0.001 and lower_pelvis<=0.0:
			continue
		var local_target := local_from_world * world_target
		# Keep the authored knee's bend plane. Forcing every imported rig to
		# the same model-space pole can flip a knee while its sole is already
		# at the correct contact, especially during a fast turning stride.
		var hip := _point("Thigh_"+side)
		var axis := (_pose[_ids["Foot_"+side]].origin-hip).normalized()
		var bend := _pose[_ids["Shin_"+side]].origin-hip
		bend -= axis*bend.dot(axis)
		bend = bend.normalized() if bend.length_squared()>.00000001 else Vector3.BACK
		_leg(side, local_target.origin, bend)
		_orient("Foot_" + side, local_target.basis)
	skeleton.force_update_all_bone_transforms()


func gait_stride(action: String, metres_per_second: float) -> float:
	return (1.04 if action == "march" else 2.0) * _height / 1.5 * _gait_amount(action, metres_per_second)


func _gait_amount(action: String, metres_per_second: float) -> float:
	if metres_per_second < 0.0:
		return 1.0
	return sqrt(clampf(metres_per_second / (3.8 if action == "run" else 1.45), 0.0, 1.0))


func locomotion(action: String, phase: float, metres_per_second: float, turn_rate: float = 0.0) -> void:
	if not available or not civilian:
		return
	_reset()
	var scale := _height / 1.5
	var walking := action in ["march", "run"]
	var running := action == "run"
	var cycle := fposmod(phase, 1.0)
	var wave := sin(cycle * TAU)
	var roll := sin(cycle * TAU * 2.0)
	var intensity := _gait_amount(action, metres_per_second) if walking else 0.0
	# A posed review uses the clip's full gait when no live speed is supplied.
	if walking and metres_per_second < 0.0:
		intensity = 1.0
	# Standing is a grounded posture, not a frozen animation frame. The pelvis
	# shifts over the supporting legs while the head counterbalances the chest.
	var talking := action == "talk"
	var personal := (cycle + _style_phase) * TAU
	var weight_shift := sin(personal)
	var breath := sin(personal * 2.0)
	var gesture := (0.5 - 0.5 * cos(cycle * TAU)) if talking else 0.0
	var sway := (0.008 * wave if walking else (0.022 if talking else 0.016) * weight_shift) * scale
	var lift := ((-0.078 if running else -0.062) + 0.005 * cos(cycle * TAU * 2.0)) * scale * intensity
	var pelvis_basis := Basis(Vector3.UP, deg_to_rad(3.0 * wave * intensity)) * _global_rest[_ids.Pelvis].basis
	if not walking:
		lift = (-0.018 + 0.004 * breath) * scale
		pelvis_basis = Basis(Vector3.FORWARD, deg_to_rad(1.8 * weight_shift)) * Basis(Vector3.UP, deg_to_rad(2.0 * weight_shift)) * _global_rest[_ids.Pelvis].basis
	_place("Pelvis", pelvis_basis, _pelvis + Vector3(sway, lift, 0))
	var lean := (4.0 if running else 1.0) * intensity
	var spine_basis := Basis(Vector3.RIGHT, deg_to_rad(lean)) * Basis(Vector3.UP, deg_to_rad(-5.0 * wave * intensity)) * Basis(Vector3.FORWARD, deg_to_rad(clampf(turn_rate, -2.0, 2.0) * 3.0 + roll * 0.6 * intensity)) * _global_rest[_ids.Spine].basis
	var head_basis := Basis(Vector3.UP, deg_to_rad(clampf(turn_rate, -2.0, 2.0) * 7.0)) * _global_rest[_ids.Head].basis
	if not walking:
		spine_basis = Basis(Vector3.RIGHT, deg_to_rad(0.7 * breath + 2.5 * gesture)) * Basis(Vector3.UP, deg_to_rad(-3.0 * weight_shift + 3.0 * gesture)) * Basis(Vector3.FORWARD, deg_to_rad(-1.6 * weight_shift)) * _global_rest[_ids.Spine].basis
		head_basis = Basis(Vector3.UP, deg_to_rad((8.0 if talking else 4.0) * sin(personal))) * Basis(Vector3.RIGHT, deg_to_rad(1.2 * breath + 4.0 * gesture)) * Basis(Vector3.FORWARD, deg_to_rad(-2.0 * weight_shift)) * _global_rest[_ids.Head].basis
	# Retargeted motion may add bounded local torso/head gestures. Feet,
	# pelvis and root translation still come exclusively from this solver.
	if external_gestures and not walking and action in ["idle","talk"]:
		spine_basis *= Basis(CC0Gestures.delta(action,"Spine",cycle))
		head_basis *= Basis(CC0Gestures.delta(action,"Head",cycle))
	_orient("Spine", spine_basis)
	_orient("Head", head_basis)
	for side: String in ["L", "R"]:
		var sign := 1.0 if side == "L" else -1.0
		var u := fposmod(cycle + (0.0 if side == "R" else 0.5), 1.0)
		var offset := Vector3.ZERO
		if walking:
			var stride := (2.0 if running else 1.04) * scale
			var stance := 0.32 if running else 0.53
			var travel: float
			if u < stance:
				travel = 0.5 - u / stance
			else:
				var swing := (u - stance) / (1.0 - stance)
				travel = -0.5 + smoothstep(0.0, 1.0, swing)
				offset.y = sin(swing * PI) * (0.13 if running else 0.065) * scale
			offset.z = travel * stride * stance * intensity
			# Small inward shift keeps feet under hips, without crossing them.
			offset.x = -sign * 0.018 * scale
		_leg(side, _feet[side] + offset, Vector3.FORWARD * -1.0)
		var arm_swing := -cos(u * TAU) * (0.24 if running else 0.13) * scale * intensity
		var shoulder := _point("Arm_" + side)
		var elbow := shoulder + Vector3(sign * 0.040, -0.201, arm_swing) * scale
		var wrist := elbow + Vector3(sign * 0.010, -0.201 if not running else -0.165, 0.026 + (0.09 if running else 0.0)) * scale
		if talking:
			var primary := "L" if _style_phase < 0.5 else "R"
			var express := gesture * (1.0 if side == primary else 0.28)
			elbow += Vector3(sign * 0.045, 0.055, 0.085) * scale * express
			wrist += Vector3(sign * 0.045, 0.205, 0.185) * scale * express
		_arm(side, elbow, wrist)
		# The hand follows the forearm, with a small anatomically relaxed angle.
		var lower := _pose[_ids["Forearm_" + side]].basis
		var local_rest: Basis = _rest[_ids["Hand_" + side]].basis
		_orient("Hand_" + side, lower * local_rest)
	skeleton.force_update_all_bone_transforms()


func imported_ambient(action: String, phase: float) -> void:
	# Military and imported Meshy rigs retain their authored limbs, foot
	# contacts and attached props. Only subtle torso/head turns are supplied
	# here, in their real rest axes, without accumulating frame-to-frame.
	if not available or civilian or action not in ["idle", "talk"]:
		return
	var at := (fposmod(phase, 1.0) + _style_phase) * TAU
	var talking := action == "talk"
	var nod := (1.0 - cos(at * 2.0)) * 0.5
	_rest_turn("Spine", 1.8 * sin(at), 0.7 * sin(at * 2.0), 1.2 * sin(at))
	_rest_turn("Head", (7.0 if talking else 4.0) * sin(at), (3.5 if talking else 1.0) * nod, -1.6 * sin(at))
	skeleton.force_update_all_bone_transforms()


func imported_work(phase: float) -> void:
	# Legacy military rigs have idle/march/combat clips but no authored work
	# track. A real, bounded upper-body working cycle replaces the former
	# motionless idle fallback; legs and planted equipment feet are untouched.
	if not available:
		return
	var effort := sin(clampf(phase, 0.0, 1.0) * PI)
	effort *= effort
	_rest_turn("Spine", 0.0, 4.0 * effort, 0.0)
	_rest_turn("Head", 0.0, 5.0 * effort, 0.0)
	_rest_turn("Arm_R", 0.0, -18.0 * effort, -3.0 * effort)
	_rest_turn("Forearm_R", 0.0, -24.0 * effort, 0.0)
	_rest_turn("Hand_R", 0.0, 8.0 * effort, 0.0)
	skeleton.force_update_all_bone_transforms()


func _rest_turn(name: String, yaw: float, pitch: float, roll_angle: float) -> void:
	var bone: int = _ids[name]
	var global_basis := _global_rest[bone].basis.orthonormalized()
	var turn := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch)) * Basis(Vector3.FORWARD, deg_to_rad(roll_angle))
	var local_turn := global_basis.inverse() * turn * global_basis
	var rotation := _rest[bone].basis.get_rotation_quaternion() * local_turn.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, rotation.normalized())


func combat(technique: String, progress: float) -> void:
	if not available or not technique in TECHNIQUES:
		return
	_reset()
	var timing: Vector3 = TIMING[technique]
	var peak := (timing.x + timing.y * 0.50) / timing.z
	var at := clampf(progress, 0.0, 1.0)
	var extension := smoothstep(0.0, peak, at) if at <= peak else 1.0 - smoothstep(peak, 1.0, at)
	var prepare := sin(clampf(at / peak, 0.0, 1.0) * PI) if at < peak else 0.0
	# Raising relaxed hands into guard needs time of its own. The former
	# 12%-of-clip ramp snapped the forearms through >60 degrees in one frame
	# during short jabs. Guard is established before the contact window and
	# settles over the recovery; authoritative hit timings stay unchanged.
	var guard := smoothstep(0.0, 0.28, at) * (1.0 - smoothstep(0.72, 1.0, at))
	var scale := _height / 1.5
	var sign := 1.0 if technique.ends_with("left") else -1.0
	var twist := 0.0
	if technique.begins_with("hook"):
		twist = sign * lerpf(-18.0 * prepare, 32.0 * extension, extension)
	elif technique.begins_with("jab") or technique.begins_with("uppercut"):
		twist = sign * (16.0 * extension - 7.0 * prepare)
	elif technique == "side_kick":
		twist = 72.0 * extension
	var dip := -0.020 * guard - (0.045 * prepare if technique.begins_with("uppercut") else 0.0)
	var shift := Vector3(-sign * 0.020 * extension, dip, 0.020 * extension) * scale
	_place("Pelvis", Basis(Vector3.UP, deg_to_rad(twist * (0.8 if technique == "side_kick" else 0.35))) * _global_rest[_ids.Pelvis].basis, _pelvis + shift)
	var lean := 0.0
	if technique == "headbutt":
		lean = 22.0 * extension - 8.0 * prepare
	elif technique.ends_with("kick"):
		lean = -8.0 * extension
	_orient("Spine", Basis(Vector3.RIGHT, deg_to_rad(lean)) * Basis(Vector3.UP, deg_to_rad(twist)) * _global_rest[_ids.Spine].basis)
	_orient("Head", Basis(Vector3.RIGHT, deg_to_rad((18.0 if technique == "headbutt" else -3.0) * extension)) * _global_rest[_ids.Head].basis)
	for side: String in ["L", "R"]:
		var side_sign := 1.0 if side == "L" else -1.0
		var shoulder := _point("Arm_" + side)
		var relaxed_wrist := shoulder + Vector3(side_sign * 0.055, -0.403, 0.027) * scale
		var guarded_wrist := Vector3(side_sign * 0.14, _origin("Head").y - 0.07, 0.22) * scale
		# The scaled head height is already in model units.
		guarded_wrist.y = _origin("Head").y - 0.07 * scale
		if technique == "side_kick":
			guarded_wrist = guarded_wrist.rotated(Vector3.UP, deg_to_rad(twist))
		var wrist := relaxed_wrist.lerp(guarded_wrist, guard)
		var elbow := shoulder + Vector3(side_sign * 0.055, -0.20, 0.12 * guard) * scale
		if side_sign == sign and (technique.begins_with("jab") or technique.begins_with("hook") or technique.begins_with("uppercut")):
			if technique.begins_with("jab"):
				wrist = wrist.lerp(shoulder + Vector3(-side_sign * 0.035, -0.025, 0.405) * scale, extension)
				elbow = elbow.lerp(shoulder + Vector3(side_sign * 0.020, -0.030, 0.20) * scale, extension)
			elif technique.begins_with("hook"):
				var arc := lerpf(side_sign * 0.34, -side_sign * 0.13, extension)
				wrist = wrist.lerp(Vector3(arc, _origin("Head").y - 0.10, 0.30 * scale), guard)
				elbow = shoulder + Vector3(side_sign * 0.18, -0.025, 0.10 + 0.07 * extension) * scale
			else:
				wrist = wrist.lerp(shoulder + Vector3(-side_sign * 0.10, -0.17 + 0.30 * extension, 0.20 + 0.11 * extension) * scale, guard)
				elbow = shoulder + Vector3(side_sign * 0.055, -0.19, 0.04 + 0.09 * extension) * scale
		_arm(side, elbow, wrist)
		_aim("Hand_" + side, _pose[_ids["Forearm_" + side]].basis.y)
		var foot: Vector3 = _feet[side]
		# Weight transfer comes from pelvis/knee flexion. Sliding both soles
		# seven centimetres along the floor to enter guard was not a step.
		# The support feet remain fixed; only the authored kicking leg lifts.
		var bend := Vector3.BACK
		if technique.ends_with("kick") and side == "R":
			# The kicking foot leaves and re-enters its floor contact vertically.
			# Extending along a straight line from the rest contact slid the
			# landing sole about 2 cm over the floor inside the contact band.
			var reach := extension * smoothstep(0.03, 0.15, extension)
			if technique == "front_kick":
				foot += Vector3(0.02 * reach, 0.55 * extension + 0.15 * prepare, 0.57 * reach) * scale
			elif technique == "side_kick":
				foot += Vector3(-0.01 * reach, 0.65 * extension + 0.12 * prepare, 0.67 * reach) * scale
				bend = Vector3(-0.8, 0.0, 0.6)
			else:
				foot += Vector3(-0.04 * reach, 1.15 * extension, 0.63 * reach) * scale
		_leg(side, foot, bend)
		if technique.ends_with("kick") and side == "R":
			var angle := -55.0 if technique == "side_kick" else (-25.0 if technique == "front_kick" else 14.0)
			var pitch := extension * smoothstep(0.03, 0.15, extension)
			_orient("Foot_R", Basis(Vector3.RIGHT, deg_to_rad(angle * pitch)) * _global_rest[_ids.Foot_R].basis)
	skeleton.force_update_all_bone_transforms()


func armed_pose(action: String, progress: float, has_shield: bool) -> bool:
	# Presentation only. Existing authoritative attack/defence clocks still
	# determine damage, contact and stamina. Never award an item or a hit here.
	var guarding := action in SHIELD_GUARDS
	if not available or (not guarding and action not in ARMED_ATTACKS) or (guarding and not has_shield):
		return false
	if not is_finite(progress):
		return false
	_reset()
	var at := clampf(progress, 0.0, 1.0)
	var scale := _height / 1.5
	var brace := smoothstep(0.0, 0.13, at) * (1.0 - smoothstep(0.84, 1.0, at))
	var windup := sin(clampf(at / 0.30, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.30, 0.56, at))
	var sweep := smoothstep(0.27, 0.56, at) * (1.0 - smoothstep(0.70, 1.0, at))
	var turn := float({"cut_inward":28.0, "cut_outward":-25.0, "thrust":12.0, "overhead":4.0, "turn_cut":48.0,
		"guard_front":0.0, "guard_high":0.0, "guard_low":0.0, "guard_left":12.0, "guard_right":-12.0}.get(action,0.0))
	var twist := turn * (brace if guarding else sweep - 0.55 * windup)
	var crouch := (0.065 if action == "guard_low" else 0.038) * brace
	_place("Pelvis", Basis(Vector3.UP, deg_to_rad(twist * 0.30)) * _global_rest[_ids.Pelvis].basis,
		_pelvis + Vector3(-0.012 * brace, -crouch, 0.012 * brace) * scale)
	_orient("Spine", Basis(Vector3.UP,deg_to_rad(twist)) * Basis(Vector3.RIGHT,deg_to_rad(4.0 * brace)) * _global_rest[_ids.Spine].basis)
	_orient("Head", Basis(Vector3.UP,deg_to_rad(twist * 0.18)) * _global_rest[_ids.Head].basis)
	# Targets are relative to the actual rig's shoulders. The same two-bone
	# solver clamps to each person's limb lengths and retains both support feet.
	var right := _point("Arm_R")
	var left := _point("Arm_L")
	var relaxed_r := Vector3(-0.055,-0.36,0.04)
	var ready_r := Vector3(-0.10,-0.22,0.16)
	var right_target := relaxed_r.lerp(ready_r,brace)
	var hand_yaw := 0.0
	var hand_pitch := 0.0
	if not guarding:
		var chamber := Vector3(-0.24,-0.10,-0.07)
		var contact := Vector3(0.17,-0.09,0.28)
		var follow := Vector3(0.12,-0.20,0.13)
		match action:
			"cut_outward":
				chamber = Vector3(0.12,-0.11,0.22)
				contact = Vector3(-0.28,-0.09,0.22)
				follow = Vector3(-0.20,-0.21,0.08)
			"thrust":
				chamber = Vector3(-0.10,-0.20,-0.04)
				contact = Vector3(-0.01,-0.05,0.38)
				follow = Vector3(-0.06,-0.16,0.27)
			"overhead":
				chamber = Vector3(-0.08,0.19,0.04)
				contact = Vector3(-0.02,-0.08,0.33)
				follow = Vector3(-0.07,-0.28,0.21)
			"turn_cut":
				chamber = Vector3(-0.26,-0.13,-0.08)
				contact = Vector3(0.20,-0.06,0.25)
				follow = Vector3(0.15,-0.19,0.12)
		right_target = _armed_arc(relaxed_r,chamber,contact,follow,at)
		hand_yaw = twist * 0.75
		hand_pitch = (-35.0 * windup + 22.0 * sweep) if action == "overhead" else -12.0 * sweep
	_arm("R",right + Vector3(-0.15,-0.16,0.06)*scale,right + right_target*scale)
	_orient("Hand_R",Basis(Vector3.UP,deg_to_rad(hand_yaw))*Basis(Vector3.RIGHT,deg_to_rad(hand_pitch))*_global_rest[_ids.Hand_R].basis)
	var relaxed_l := Vector3(0.055,-0.36,0.04)
	var guard_l := Vector3(-0.11,-0.18,0.25) if has_shield else Vector3(0.07,-0.19,0.14)
	var shield_yaw := 0.0
	var shield_pitch := 0.0
	match action:
		"guard_high":
			guard_l = Vector3(-0.10,0.07,0.24)
			shield_pitch = -18.0
		"guard_low":
			guard_l = Vector3(-0.09,-0.34,0.20)
			shield_pitch = 18.0
		"guard_left":
			guard_l = Vector3(0.17,-0.13,0.23)
			shield_yaw = 25.0
		"guard_right":
			guard_l = Vector3(-0.24,-0.13,0.25)
			shield_yaw = -25.0
	_arm("L",left + Vector3(0.13,-0.17,0.04)*scale,left + relaxed_l.lerp(guard_l,brace)*scale)
	_orient("Hand_L",Basis(Vector3.UP,deg_to_rad(shield_yaw*brace))*Basis(Vector3.RIGHT,deg_to_rad(shield_pitch*brace))*_global_rest[_ids.Hand_L].basis)
	for side: String in ["L","R"]:
		_leg(side,_feet[side],Vector3.BACK)
	skeleton.force_update_all_bone_transforms()
	return true


func _armed_arc(start: Vector3, chamber: Vector3, contact: Vector3, follow: Vector3, phase: float) -> Vector3:
	# Continuous, ease-in/ease-out key pose interpolation; no frame teleport.
	if phase < 0.30:
		return start.lerp(chamber,smoothstep(0.0,0.30,phase))
	if phase < 0.56:
		return chamber.lerp(contact,smoothstep(0.30,0.56,phase))
	if phase < 0.72:
		return contact.lerp(follow,smoothstep(0.56,0.72,phase))
	return follow.lerp(start,smoothstep(0.72,1.0,phase))


func _blend_transition() -> void:
	if _transition_remaining <= 0.0:
		return
	var weight := smoothstep(0.0, 1.0, 1.0 - _transition_remaining / _transition_duration)
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(bone, _transition_positions[bone].lerp(skeleton.get_bone_pose_position(bone), weight))
		skeleton.set_bone_pose_rotation(bone, _transition_rotations[bone].slerp(skeleton.get_bone_pose_rotation(bone), weight))
	skeleton.force_update_all_bone_transforms()


func blend_transition() -> void:
	# The actor calls this after its final pose owner (imported work/attack,
	# military idle or procedural locomotion). Otherwise entering a raw work
	# clip bypasses the captured transition and visibly teleports the limbs.
	if available:
		_blend_transition()


## Carrying is a local two-bone presentation overlay, not a replacement
## locomotion clip. The spine, root, legs and authored arm lengths stay intact.
func carry_left() -> void:
	if not available or not is_instance_valid(skeleton):
		return
	for name: String in ["Arm_L","Forearm_L","Hand_L"]:
		if not _ids.has(name):
			return
	var arm: int = _ids.Arm_L
	var fore: int = _ids.Forearm_L
	var hand: int = _ids.Hand_L
	skeleton.force_update_all_bone_transforms()
	var shoulder := skeleton.get_bone_global_pose(arm).origin
	var upper := _rest[fore].origin.length()
	var lower := _rest[hand].origin.length()
	var reach := upper+lower
	if reach < .05 or not is_finite(reach):
		return
	var side := 1.0 if _global_rest[arm].origin.x >= 0.0 else -1.0
	# Both imported character families face +Z in skeleton rest space.
	var wrist := shoulder+Vector3(side*.10,-.60,.47)*reach
	var elbow := _joint(shoulder,wrist,upper,lower,Vector3(side*.7,-1.0,-.2))
	_aim_live_segment(arm,fore,elbow-shoulder)
	_aim_live_segment(fore,hand,wrist-skeleton.get_bone_global_pose(fore).origin)
	# An upright jug requires a wrist orientation independent of arm swing.
	var parent_basis := skeleton.get_bone_global_pose(fore).basis.orthonormalized()
	var upright := _global_rest[hand].basis.orthonormalized()
	skeleton.set_bone_pose_rotation(hand,(parent_basis.inverse()*upright).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()


## Target a wrist in world metres without changing the imported bone lengths.
## Returns residual distance; unreachable contacts are not claimed to be exact.
func reach_world_wrist(side: String, target: Vector3, world_basis: Basis) -> float:
	if not available or not is_instance_valid(skeleton) or not target.is_finite():
		return INF
	var arm: int = _ids["Arm_"+side]
	var fore: int = _ids["Forearm_"+side]
	var hand: int = _ids["Hand_"+side]
	skeleton.force_update_all_bone_transforms()
	var shoulder := skeleton.get_bone_global_pose(arm).origin
	var wrist := skeleton.to_local(target)
	var upper := _rest[fore].origin.length()
	var lower := _rest[hand].origin.length()
	if upper+lower < .05:
		return INF
	var axis := wrist-shoulder
	if axis.length() < .001:
		axis = Vector3.BACK*.001
	var distance := clampf(axis.length(),absf(upper-lower)+.001,upper+lower-.001)
	var reachable := shoulder+axis.normalized()*distance
	var sign_side := 1.0 if _global_rest[arm].origin.x>=0.0 else -1.0
	var elbow := _joint(shoulder,reachable,upper,lower,Vector3(sign_side*.8,-1.0,-.2))
	_aim_live_segment(arm,fore,elbow-shoulder)
	_aim_live_segment(fore,hand,reachable-skeleton.get_bone_global_pose(fore).origin)
	var local_basis := skeleton.global_basis.orthonormalized().inverse()*world_basis.orthonormalized()*_global_rest[hand].basis.orthonormalized()
	var parent_basis := skeleton.get_bone_global_pose(fore).basis.orthonormalized()
	skeleton.set_bone_pose_rotation(hand,(parent_basis.inverse()*local_basis).get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()
	return skeleton.to_global(skeleton.get_bone_global_pose(hand).origin).distance_to(target)


func _aim_live_segment(bone: int,child: int,toward: Vector3) -> void:
	var current := skeleton.get_bone_global_pose(bone)
	var segment := skeleton.get_bone_global_pose(child).origin-current.origin
	if segment.length_squared() < .000001 or toward.length_squared() < .000001:
		return
	var rotation := Quaternion(segment.normalized(),toward.normalized())
	var basis := Basis(rotation)*current.basis.orthonormalized()
	var parent := skeleton.get_bone_parent(bone)
	if parent >= 0:
		basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse()*basis
	skeleton.set_bone_pose_rotation(bone,basis.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()


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


func _aim(name: String, toward: Vector3, child: String = "") -> void:
	var source: Basis = _global_rest[_ids[name]].basis
	var direction := toward.normalized()
	if direction.length_squared() < 0.5:
		return
	# Imported rigs need not place their next joint on local +Y.
	# Align the actual rest segment, not an assumed bone axis. End
	# effectors with no anatomical child retain their authored Y convention.
	var rest_axis := source.y.normalized()
	if not child.is_empty():
		var child_rest: Transform3D = _rest[_ids[child]]
		var segment := source * child_rest.origin
		if segment.length_squared() > 0.00000001:
			rest_axis = segment.normalized()
	_orient(name, Basis(Quaternion(rest_axis, direction)) * source)


func _arm(side: String, elbow: Vector3, wrist: Vector3) -> void:
	# Solve lengths first; aiming independently would visually stretch a punch.
	var shoulder := _point("Arm_" + side)
	var upper := _rest[_ids["Forearm_" + side]].origin.length()
	var lower := _rest[_ids["Hand_" + side]].origin.length()
	var solved := _joint(shoulder, wrist, upper, lower, elbow - shoulder)
	_aim("Arm_" + side, solved - shoulder, "Forearm_" + side)
	_aim("Forearm_" + side, wrist - _point("Forearm_" + side), "Hand_" + side)


func _leg(side: String, foot: Vector3, bend: Vector3) -> void:
	var hip := _point("Thigh_" + side)
	var upper := _rest[_ids["Shin_" + side]].origin.length()
	var lower := _rest[_ids["Foot_" + side]].origin.length()
	var knee := _joint(hip, foot, upper, lower, bend)
	_aim("Thigh_" + side, knee - hip, "Shin_" + side)
	_aim("Shin_" + side, foot - _point("Shin_" + side), "Foot_" + side)
	_orient("Foot_" + side, _global_rest[_ids["Foot_" + side]].basis)


func _joint(start: Vector3, finish: Vector3, upper: float, lower: float, bend: Vector3) -> Vector3:
	var delta := finish - start
	var distance := clampf(delta.length(), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	# Coincident endpoints still need a finite, nonzero solve axis.
	var direction := delta.normalized() if delta.length_squared() > 0.000000000001 else Vector3.BACK
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var normal := bend - direction * bend.dot(direction)
	if normal.length_squared() < 0.0001:
		# Choose the least-aligned cardinal axis; a fixed RIGHT fallback
		# degenerates for a horizontal +X/-X limb with a parallel pole.
		var axis := Vector3.RIGHT
		if absf(direction.y) < absf(direction.x):
			axis = Vector3.UP
		if absf(direction.z) < absf(direction.dot(axis)):
			axis = Vector3.BACK
		normal = axis - direction * direction.dot(axis)
	return start + direction * along + normal.normalized() * sqrt(maxf(0.0, upper * upper - along * along))
