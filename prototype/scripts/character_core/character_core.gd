class_name CharacterCore
extends CharacterBody3D
## Stable gameplay-facing contract. No camera, combat, inventory, or NPC
## authority is owned by this component. All motion is collision-resolved.
signal rig_bound(skeleton: Skeleton3D)
signal motion_state_changed(previous: int, current: int)
signal grounded_changed(grounded: bool)
signal movement_sampled(world_velocity: Vector3, grounded: bool)
signal animation_intent_sampled(world_velocity: Vector3, speed: float, yaw_rate: float, grounded: bool)
signal command_rejected(reason: String)

enum Gait { IDLE, WALK, RUN, SPRINT, TURN, AIRBORNE }
const LocomotionGraph = preload("res://scripts/character_core/locomotion_graph.gd")
const FootPlacement = preload("res://scripts/character_core/foot_placement.gd")
const Ground = preload("res://scripts/visuals/authored_ground.gd")
@export var walk_speed: float = 1.45
@export var run_speed: float = 3.8
@export var sprint_speed: float = 5.4
@export var acceleration: float = 5.5
@export var braking: float = 8.0
@export var response: float = 8.0
@export var turn_speed: float = 5.0
@export var gravity: float = 19.6
@export_range(0.0,0.4,0.01) var step_height: float = 0.25
@export var pelvis_name: StringName = &"Pelvis"
@export var spine_name: StringName = &"Spine"
@export var head_name: StringName = &"Head"
@export var leg_names: Array[StringName] = [&"Thigh_L",&"Shin_L",&"Foot_L",&"Thigh_R",&"Shin_R",&"Foot_R"]
@onready var _rig_root: Node3D = $RigRoot
@onready var _tree: AnimationTree = $AnimationTree
@onready var _feet: FootPlacement = $FootPlacement
var _graph: LocomotionGraph = LocomotionGraph.new()
var _skeleton: Skeleton3D
var _animator: AnimationPlayer
var _valid: bool = false
var _motion_allowed: bool = true
var _direction: Vector3 = Vector3.ZERO
var _amount: float = 0.0
var _requested_gait: int = Gait.WALK
var _state: int = Gait.IDLE
var _grounded: bool = false
var _facing: Vector3 = Vector3.ZERO
var _explicit_facing: bool = false
var _planar_speed: float = 0.0
var _yaw_rate: float = 0.0
var _speed_multiplier: float = 1.0
var _step_remaining: float = 0.0
var _step_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	_valid = _bind_rig()
	if not _valid:
		set_physics_process(false)
		command_rejected.emit("Original character rig, animation or bone contract invalid")
		push_error("CharacterCore: original rig contract invalid")
		return
	rig_bound.emit(_skeleton)

func _bind_rig() -> bool:
	if _rig_root.get_child_count() != 1 or not (walk_speed>0.0 and run_speed>walk_speed and sprint_speed>run_speed):
		return false
	var model: Node3D = _rig_root.get_child(0) as Node3D
	if model == null:
		return false
	var skeletons: Array[Node] = model.find_children("*","Skeleton3D",true,false)
	var animators: Array[Node] = model.find_children("*","AnimationPlayer",true,false)
	if skeletons.size()!=1 or animators.size()!=1:
		return false
	_skeleton = skeletons[0] as Skeleton3D
	_animator = animators[0] as AnimationPlayer
	var pelvis: int = _skeleton.find_bone(String(pelvis_name))
	var spine: int = _skeleton.find_bone(String(spine_name))
	var head: int = _skeleton.find_bone(String(head_name))
	if mini(pelvis,mini(spine,head))<0:
		return false
	var lift: float = Ground.sole_lift(model.scene_file_path,model)
	model.position.y -= lift*model.scale.y
	if not _graph.configure(_tree,_animator,_skeleton,spine,walk_speed,run_speed,sprint_speed):
		return false
	if not _feet.bind(self,_skeleton,pelvis,spine,head,leg_names):
		_tree.active = false
		return false
	return true

func is_character_ready() -> bool:
	return _valid

func request_motion(world_direction: Vector3, amount: float, gait: int = Gait.WALK) -> bool:
	if not world_direction.is_finite() or not is_finite(amount) or gait not in [Gait.WALK,Gait.RUN,Gait.SPRINT]:
		command_rejected.emit("Invalid movement request")
		return false
	world_direction.y = 0.0
	_direction = world_direction.normalized() if world_direction.length_squared()>0.000001 else Vector3.ZERO
	_amount = clampf(amount,0.0,1.0)
	_requested_gait = gait
	return true

func stop_motion() -> void:
	_direction = Vector3.ZERO
	_amount = 0.0

func request_facing(world_direction: Vector3) -> bool:
	if not world_direction.is_finite():
		return false
	world_direction.y = 0.0
	if world_direction.length_squared() < 0.000001:
		return false
	_facing = world_direction.normalized()
	_explicit_facing = true
	return true

func clear_facing() -> void:
	_explicit_facing = false

func set_movement_enabled(value: bool) -> void:
	_motion_allowed = value
	if not value:
		stop_motion()

func set_speed_multiplier(value: float) -> bool:
	if not is_finite(value) or value<0.0 or value>1.0:
		return false
	_speed_multiplier = value
	return true

func set_ik_enabled(value: bool) -> void:
	if is_instance_valid(_feet):
		_feet.set_enabled(value)

func set_look_target(world_point: Vector3) -> void:
	_feet.set_look_target(world_point)

func clear_look_target() -> void:
	_feet.clear_look_target()

func set_upper_body_clip(clip: StringName, weight: float) -> bool:
	return _graph.set_upper_body_clip(clip,weight)

func clear_upper_body() -> void:
	_graph.clear_upper_body()

func get_character_skeleton() -> Skeleton3D:
	return _skeleton

func get_animation_tree() -> AnimationTree:
	return _tree

func get_motion_state() -> int:
	return _state

func get_planar_speed() -> float:
	return _planar_speed

func get_yaw_rate() -> float:
	return _yaw_rate

func get_foot_contact(side: int) -> Dictionary:
	return _feet.get_contact(side)

func get_pelvis_offset() -> float:
	return _feet.get_pelvis_offset()

func get_upper_filter_paths() -> Array[NodePath]:
	return _graph.get_upper_filter_paths()

func get_bone_world_transform(bone_name: StringName) -> Transform3D:
	if not is_instance_valid(_skeleton):
		return Transform3D(Basis.IDENTITY,Vector3.INF)
	var bone: int = _skeleton.find_bone(String(bone_name))
	if bone < 0:
		return Transform3D(Basis.IDENTITY,Vector3.INF)
	return _skeleton.global_transform*_skeleton.get_bone_global_pose(bone)

func _gait_speed() -> float:
	match _requested_gait:
		Gait.RUN: return run_speed
		Gait.SPRINT: return sprint_speed
		_: return walk_speed

## A capsule first meets a stair on its curved lower edge. A downward
## sweep at that same x/z hits the edge, not the top. Validate the complete
## lifted corridor and the walkable top ahead of the capsule; advance only
## the normal per-tick displacement, never the full look-ahead distance.
func _step_probe_distance() -> float:
	var collider: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collider.shape as CapsuleShape3D
		return capsule.radius * maxf(absf(collider.global_basis.x.length()),absf(collider.global_basis.z.length())) + 0.025
	return 0.0

func _walkable_landing(from: Transform3D, distance: float, hit: KinematicCollision3D) -> bool:
	return test_move(from,Vector3.DOWN*distance,hit,safe_margin,false) and hit.get_normal().dot(Vector3.UP)>=cos(floor_max_angle)

func _continue_step(horizontal: Vector3) -> bool:
	if horizontal.length_squared()<0.000001 or horizontal.normalized().dot(_step_direction)<0.95:
		_step_remaining = 0.0
		return false
	var origin: Transform3D = global_transform
	if test_move(origin,horizontal,null,safe_margin,false):
		_step_remaining = 0.0
		return false
	var next: Transform3D = origin
	next.origin += horizontal
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	if _walkable_landing(next,0.045,landing):
		next.origin += landing.get_travel()
		global_position = next.origin
		_step_remaining = 0.0
		return true
	# The body is still entering the verified stair. Revalidate the top
	# and entire forward corridor each tick, including dynamic obstacles.
	var look: Vector3 = horizontal.normalized()*_step_remaining
	var ahead: Transform3D = next
	if _step_remaining<=0.0 or test_move(next,look,null,safe_margin,false):
		_step_remaining = 0.0
		return false
	ahead.origin += look
	if not _walkable_landing(ahead,0.045,landing):
		_step_remaining = 0.0
		return false
	global_position = next.origin
	_step_remaining = maxf(0.0,_step_remaining-horizontal.length())
	return true

func _try_step_up(horizontal: Vector3) -> bool:
	if _step_remaining>0.0:
		return _continue_step(horizontal)
	if not _grounded or step_height<=0.0 or horizontal.length_squared()<0.000001:
		return false
	var origin: Transform3D = global_transform
	var obstruction: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(origin,horizontal,obstruction,safe_margin,false):
		return false
	if obstruction.get_normal().dot(Vector3.UP)>=cos(floor_max_angle):
		return false
	var probe: float = _step_probe_distance()
	if probe<=0.0:
		return false
	var lift: Vector3 = Vector3.UP*(step_height+safe_margin*3.0)
	if test_move(origin,lift,null,safe_margin,false):
		return false
	var raised: Transform3D = origin
	raised.origin += lift
	var look: Vector3 = horizontal+horizontal.normalized()*probe
	if test_move(raised,look,null,safe_margin,false):
		return false
	var ahead: Transform3D = raised
	ahead.origin += look
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	if not _walkable_landing(ahead,step_height+floor_snap_length,landing):
		return false
	var end: Vector3 = ahead.origin+landing.get_travel()
	var rise: float = end.y-origin.origin.y
	if rise<0.015 or rise>step_height+0.002:
		return false
	var actual_lift: Vector3 = Vector3.UP*(rise+safe_margin*3.0)
	if test_move(origin,actual_lift,null,safe_margin,false):
		return false
	var entry: Transform3D = origin
	entry.origin += actual_lift
	if test_move(entry,horizontal,null,safe_margin,false):
		return false
	global_position = entry.origin+horizontal
	_step_remaining = probe
	_step_direction = horizontal.normalized()
	return true

func _physics_process(delta: float) -> void:
	if not _valid or not is_finite(delta) or delta<=0.0:
		return
	var direction: Vector3 = _direction if _motion_allowed else Vector3.ZERO
	var amount: float = _amount if _motion_allowed else 0.0
	var target: Vector3 = direction*amount*_gait_speed()*_speed_multiplier
	var current: Vector3 = Vector3(velocity.x,0.0,velocity.z)
	var maximum: float = braking if target.length_squared()<current.length_squared() else acceleration
	var smoothed: Vector3 = current.lerp(target,1.0-exp(-response*delta))
	current = current.move_toward(smoothed,maximum*delta)
	if target.length_squared()<0.000001 and current.length()<0.01:
		current = Vector3.ZERO
	var want: Vector3 = _facing if _explicit_facing else direction
	var old_yaw: float = global_rotation.y
	if want.length_squared()>0.000001 and _motion_allowed:
		var wanted_yaw: float = atan2(-want.x,-want.z)
		var yaw: float = rotate_toward(old_yaw,wanted_yaw,turn_speed*delta)
		global_rotation = Vector3(0.0,yaw,0.0)
	_yaw_rate = wrapf(global_rotation.y-old_yaw,-PI,PI)/delta
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = -0.5 if _grounded else velocity.y-gravity*delta
	var before: Vector3 = global_position
	var stepped: bool = _try_step_up(current*delta)
	if stepped:
		# The validated volume sweeps already resolved this tick's motion.
		# A second move_and_slide would pull the capsule back off the edge.
		velocity.y = 0.0
	else:
		move_and_slide()
	var real: Vector3 = (global_position-before)/delta
	_planar_speed = Vector2(real.x,real.z).length()
	var grounded: bool = stepped or is_on_floor()
	if grounded != _grounded:
		_grounded = grounded
		grounded_changed.emit(grounded)
	var next: int = Gait.IDLE
	if not grounded:
		next = Gait.AIRBORNE
	elif _planar_speed<0.10:
		next = Gait.TURN if absf(_yaw_rate)>0.22 else Gait.IDLE
	elif _planar_speed>(run_speed+sprint_speed)*0.5:
		next = Gait.SPRINT
	elif _planar_speed>(walk_speed+run_speed)*0.5:
		next = Gait.RUN
	else:
		next = Gait.WALK
	if next != _state:
		var previous: int = _state
		_state = next
		motion_state_changed.emit(previous,next)
	_graph.advance(delta,_planar_speed,_yaw_rate/maxf(0.01,turn_speed),grounded)
	_feet.update_pose(delta,grounded,_planar_speed,_yaw_rate)
	movement_sampled.emit(real,grounded)
	animation_intent_sampled.emit(real,_planar_speed,_yaw_rate,grounded)
