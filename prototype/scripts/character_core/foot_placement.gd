extends Node3D
## Animation-driven ground IK and short-lived planted-foot constraints.
## Two native TwoBoneIK3D nodes solve the leg chains; the custom modifiers
## only apply pelvis/bank and foot normal alignment.
const BodyPose = preload("res://scripts/character_core/body_pose_modifier.gd")
const FootAlign = preload("res://scripts/character_core/foot_alignment_modifier.gd")
class Leg extends RefCounted:
	var thigh: int = -1
	var shin: int = -1
	var foot: int = -1
	var ray: RayCast3D
	var target: Marker3D
	var pole: Marker3D
	var solver: TwoBoneIK3D
	var aligner: SkeletonModifier3D
	var ankle_height: float = 0.10
	var max_reach: float = 0.8
	var grounded: bool = false
	var locked: bool = false
	var lock_point: Vector3 = Vector3.ZERO
	var lock_normal: Vector3 = Vector3.UP
	var lock_surface: Node3D
	var local_lock: Vector3 = Vector3.ZERO
	var local_normal: Vector3 = Vector3.UP
	var weight: float = 0.0
	var normal: Vector3 = Vector3.UP
	var solved_ankle: Vector3 = Vector3.INF

@export_range(0.05,0.5,0.01) var probe_up: float = 0.32
@export_range(0.1,1.0,0.01) var probe_down: float = 0.48
@export_range(0.01,0.3,0.01) var maximum_pelvis_drop: float = 0.18
@export_range(0.05,0.5,0.01) var maximum_plant_drift: float = 0.24
@export_range(0.01,0.15,0.005) var swing_threshold: float = 0.055
@export_range(0.01,0.2,0.005) var turn_step_height: float = 0.085
var _body: CharacterBody3D
var _skeleton: Skeleton3D
var _pose: SkeletonModifier3D
var _legs: Array[Leg] = []
var _head_look: LookAtModifier3D
var _head_target: Marker3D
var _head_bone: int = -1
var _look_world: Vector3 = Vector3.INF
var _look_smoothed: Vector3 = Vector3.INF
var _phase: float = 0.0
var _hip: float = 0.0
var _enabled: bool = true

func bind(body: CharacterBody3D, skeleton: Skeleton3D, pelvis: int, spine: int, head: int,
		leg_names: Array[StringName]) -> bool:
	if leg_names.size() != 6 or not is_instance_valid(body) or not is_instance_valid(skeleton):
		return false
	_body = body
	_skeleton = skeleton
	_head_bone = head
	var left: Leg = _make_leg(leg_names[0],leg_names[1],leg_names[2],$LeftRay,$LeftTarget,$LeftPole)
	var right: Leg = _make_leg(leg_names[3],leg_names[4],leg_names[5],$RightRay,$RightTarget,$RightPole)
	if left == null or right == null:
		return false
	_legs = [left,right]
	_pose = BodyPose.new()
	_pose.name = "BodyPoseModifier"
	_pose.set("pelvis_bone",pelvis)
	_pose.set("spine_bone",spine)
	skeleton.add_child(_pose)
	for leg: Leg in _legs:
		leg.solver = TwoBoneIK3D.new()
		leg.solver.name = "LeftLegIK" if leg == left else "RightLegIK"
		leg.solver.influence = 0.0
		skeleton.add_child(leg.solver)
		leg.solver.setting_count = 1
		leg.solver.set_root_bone(0,leg.thigh)
		leg.solver.set_middle_bone(0,leg.shin)
		leg.solver.set_end_bone(0,leg.foot)
		leg.solver.set_use_virtual_end(0,false)
		leg.solver.set_extend_end_bone(0,false)
		leg.solver.set_target_node(0,leg.solver.get_path_to(leg.target))
		leg.solver.set_pole_node(0,leg.solver.get_path_to(leg.pole))
		# Choose pole twist from the actual imported knee bone axes.
		var rest: Basis = skeleton.global_basis*skeleton.get_bone_global_rest(leg.shin).basis
		var forward: Vector3 = -body.global_basis.z.normalized()
		leg.solver.set_pole_direction(0,SkeletonModifier3D.SECONDARY_DIRECTION_CUSTOM)
		leg.solver.set_pole_direction_vector(0,(rest.inverse()*forward).normalized())
	for leg: Leg in _legs:
		leg.aligner = FootAlign.new()
		leg.aligner.name = "LeftFootNormal" if leg == left else "RightFootNormal"
		leg.aligner.influence = 0.0
		leg.aligner.set("foot_bone",leg.foot)
		var rest: Basis = skeleton.global_basis*skeleton.get_bone_global_rest(leg.foot).basis
		leg.aligner.set("rest_up_local",(rest.inverse()*Vector3.UP).normalized())
		skeleton.add_child(leg.aligner)
	_head_target = $HeadTarget
	_head_look = LookAtModifier3D.new()
	_head_look.name = "HeadLook"
	_head_look.bone = head
	_head_look.duration = 0.18
	_head_look.use_angle_limitation = true
	_head_look.symmetry_limitation = true
	_head_look.primary_limit_angle = deg_to_rad(55.0)
	_head_look.secondary_limit_angle = deg_to_rad(30.0)
	_head_look.primary_damp_threshold = 0.75
	_head_look.secondary_damp_threshold = 0.75
	_head_look.influence = 0.0
	skeleton.add_child(_head_look)
	_head_look.target_node = _head_look.get_path_to(_head_target)
	var head_rest: Basis = skeleton.global_basis*skeleton.get_bone_global_rest(head).basis
	var facing: Vector3 = (head_rest.inverse()*-body.global_basis.z).normalized()
	var up: Vector3 = (head_rest.inverse()*Vector3.UP).normalized()
	_head_look.forward_axis = _axis_for(facing) as SkeletonModifier3D.BoneAxis
	var primary: int = floori(float(_axis_for(up))*0.5)
	if primary == floori(float(_head_look.forward_axis)*0.5):
		primary = (primary+1)%3
	_head_look.primary_rotation_axis = primary as Vector3.Axis
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	skeleton.skeleton_updated.connect(_capture_solved)
	return true

func _axis_for(direction: Vector3) -> int:
	var best: int = 0
	var score: float = -INF
	var axes: Array[Vector3] = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for index: int in range(axes.size()):
		var dot: float = axes[index].dot(direction)
		if dot > score:
			score = dot
			best = index
	return best

func _make_leg(thigh: StringName, shin: StringName, foot: StringName,
		ray: RayCast3D,target: Marker3D,pole: Marker3D) -> Leg:
	var leg: Leg = Leg.new()
	leg.thigh = _skeleton.find_bone(String(thigh))
	leg.shin = _skeleton.find_bone(String(shin))
	leg.foot = _skeleton.find_bone(String(foot))
	if mini(leg.thigh,mini(leg.shin,leg.foot)) < 0:
		return null
	if _skeleton.get_bone_parent(leg.shin) != leg.thigh or _skeleton.get_bone_parent(leg.foot) != leg.shin:
		return null
	var thigh_position: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_rest(leg.thigh).origin)
	var shin_position: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_rest(leg.shin).origin)
	var ankle_position: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_rest(leg.foot).origin)
	leg.max_reach = thigh_position.distance_to(shin_position)+shin_position.distance_to(ankle_position)
	leg.ankle_height = maxf(0.025,ankle_position.y-_body.global_position.y)
	leg.ray = ray
	leg.target = target
	leg.pole = pole
	ray.add_exception(_body)
	ray.enabled = true
	ray.target_position = Vector3.DOWN*(probe_up+probe_down+leg.ankle_height)
	target.global_position = ankle_position
	pole.global_position = shin_position-_body.global_basis.z.normalized()*0.5
	return leg

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		for leg: Leg in _legs:
			leg.locked = false
			leg.weight = 0.0
			leg.solver.influence = 0.0
			leg.aligner.influence = 0.0
		_hip = 0.0

func set_look_target(world_point: Vector3) -> void:
	_look_world = world_point if world_point.is_finite() else Vector3.INF

func clear_look_target() -> void:
	_look_world = Vector3.INF

func update_pose(delta: float, on_floor: bool, speed: float, yaw_rate: float) -> void:
	if not is_instance_valid(_skeleton) or _legs.size() != 2:
		return
	_skeleton.force_update_all_bone_transforms()
	var forward: Vector3 = -_body.global_basis.z.normalized()
	var moving_turn: bool = speed < 0.12 and absf(yaw_rate) > 0.22
	if moving_turn:
		_phase = fposmod(_phase+delta*(1.0+minf(absf(yaw_rate),3.0)*0.45),1.0)
	else:
		_phase = 0.0
	var drop: float = 0.0
	for index: int in range(_legs.size()):
		var leg: Leg = _legs[index]
		var ankle: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(leg.foot).origin)
		var knee: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(leg.shin).origin)
		leg.pole.global_position = knee+forward*0.5
		var swing: float = maxf(0.0,ankle.y-(_body.global_position.y+leg.ankle_height))
		var stepping: bool = false
		if moving_turn:
			var cycle: float = fposmod(_phase+float(index)*0.5,1.0)
			stepping = cycle > 0.58
			if stepping:
				swing = maxf(swing,turn_step_height*sin(PI*(cycle-0.58)/0.42))
		leg.ray.global_transform = Transform3D(Basis.IDENTITY,ankle+Vector3.UP*probe_up)
		leg.ray.force_raycast_update()
		var valid: bool = _enabled and on_floor and leg.ray.is_colliding()
		var point: Vector3 = ankle
		var normal: Vector3 = Vector3.UP
		if valid:
			point = leg.ray.get_collision_point()
			normal = leg.ray.get_collision_normal().normalized()
			valid = point.is_finite() and normal.is_finite() and normal.dot(Vector3.UP) >= cos(deg_to_rad(48.0))
		leg.grounded = valid
		var target_weight: float = 0.0
		var target: Vector3 = ankle
		if valid:
			var planted: bool = not stepping and swing <= swing_threshold
			if leg.locked and is_instance_valid(leg.lock_surface):
				leg.lock_point = leg.lock_surface.to_global(leg.local_lock)
				leg.lock_normal = (leg.lock_surface.global_basis*leg.local_normal).normalized()
			if planted:
				var collider: Node3D = leg.ray.get_collider() as Node3D
				if not leg.locked or collider != leg.lock_surface or absf(point.y-leg.lock_point.y)>0.12 or Vector2(point.x-leg.lock_point.x,point.z-leg.lock_point.z).length() > maximum_plant_drift:
					leg.lock_point = point
					leg.lock_normal = normal
					leg.lock_surface = collider
					if is_instance_valid(leg.lock_surface):
						leg.local_lock = leg.lock_surface.to_local(point)
						leg.local_normal = (leg.lock_surface.global_basis.inverse()*normal).normalized()
					leg.locked = true
				point = leg.lock_point
				normal = leg.lock_normal
			else:
				leg.locked = false
				leg.lock_surface = null
			target = point+normal*leg.ankle_height+Vector3.UP*(0.0 if planted else swing)
			target_weight = 1.0 if planted or moving_turn else 0.65
			if planted:
				drop = minf(drop,target.y-ankle.y)
		else:
			leg.locked = false
			leg.lock_surface = null
		var hip_world: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(leg.thigh).origin)
		var reach: Vector3 = target-hip_world
		target = hip_world+reach.limit_length(maxf(0.05,leg.max_reach-0.005))
		var alpha: float = 1.0-exp(-18.0*delta)
		leg.target.global_position = leg.target.global_position.lerp(target,alpha) if leg.weight > 0.01 else target
		leg.normal = leg.normal.lerp(normal,alpha).normalized()
		leg.weight = lerpf(leg.weight,target_weight,alpha)
		leg.solver.influence = leg.weight
		leg.aligner.set("surface_normal",leg.normal)
		leg.aligner.influence = leg.weight if leg.locked else 0.0
	_hip = lerpf(_hip,clampf(drop,-maximum_pelvis_drop,0.0) if _enabled and on_floor else 0.0,1.0-exp(-12.0*delta))
	_pose.set("pelvis_offset_m",_hip)
	_pose.set("bank_angle_rad",clampf(-yaw_rate*speed*0.035,-deg_to_rad(12.0),deg_to_rad(12.0)))
	_pose.set("forward_world",forward)
	var head: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(_head_bone).origin)
	var desired_look: Vector3 = _look_world if _look_world.is_finite() else head+forward*4.0
	if not _look_smoothed.is_finite():
		_look_smoothed = desired_look
	_look_smoothed = _look_smoothed.lerp(desired_look,1.0-exp(-7.0*delta))
	_head_target.global_position = _look_smoothed
	_head_look.influence = 0.65 if _enabled else 0.0
	_skeleton.advance(delta)

func _capture_solved() -> void:
	for leg: Leg in _legs:
		leg.solved_ankle = _skeleton.to_global(_skeleton.get_bone_global_pose(leg.foot).origin)

func get_contact(side: int) -> Dictionary:
	if side < 0 or side >= _legs.size():
		return {}
	var leg: Leg = _legs[side]
	return {"grounded":leg.grounded,"locked":leg.locked,"weight":leg.weight,
		"normal":leg.normal,"target":leg.target.global_position,"solved_ankle":leg.solved_ankle,
		"ankle_height":leg.ankle_height,"max_reach":leg.max_reach}

func get_pelvis_offset() -> float:
	return _hip
