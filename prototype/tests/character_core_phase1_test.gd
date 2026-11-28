extends SceneTree
## Real production GLB, AnimationTree, physical floor and native modifiers.
## This does not certify full campaign, original youth, visuals or Fold7.
const Scene: PackedScene = preload("res://scenes/character_core/imperathen_character.tscn")
var checks: int = 0
var failures: Array[String] = []
var states: Dictionary = {}
var stage: Node3D

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("CHARACTER_PHASE1_FAIL ",label)
	return condition

func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame

func _body_box(at: Vector3, dimensions: Vector3, angle: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.rotation = angle
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	stage.add_child(body)
	return body

func _new_actor(at: Vector3) -> CharacterCore:
	var actor: CharacterCore = Scene.instantiate() as CharacterCore
	actor.position = at
	stage.add_child(actor)
	actor.motion_state_changed.connect(func(_previous: int,current: int) -> void: states[current] = true)
	return actor

func _check_feet(actor: CharacterCore, label: String) -> void:
	for side: int in [0,1]:
		var receipt: Dictionary = actor.get_foot_contact(side)
		if not _check(not receipt.is_empty(),label+": contact receipt exists"):
			continue
		var point: Vector3 = receipt.target
		var solved: Vector3 = receipt.solved_ankle
		_check(bool(receipt.grounded) and bool(receipt.locked) and float(receipt.weight)>0.90,label+": real ray and planted native IK")
		_check(point.is_finite() and solved.is_finite(),label+": finite actual ankle and target")
		_check(point.distance_to(solved)<0.04,label+": actual final ankle within 40 mm of target (%.6f)" % point.distance_to(solved))
		var surface: Vector3 = receipt.surface_point
		var desired: Vector3 = receipt.desired_target
		_check(surface.is_finite() and desired.is_finite(),label+": real ground sample and unclamped target")
		_check(point.distance_to(desired)<0.04,label+": target reaches desired ground placement within 40 mm")
		print("CHARACTER_PHASE1_CONTACT ",label," side=",side," error_m=",point.distance_to(solved)," normal=",receipt.normal," surface=",surface," animated=",receipt.animated_ankle," desired=",desired," target=",point," hip_offset=",actor.get_pelvis_offset())

func _check_unbound_contract(actor: CharacterCore, label: String) -> void:
	_check(not actor.is_character_ready(),label+": adapter not ready")
	_check(actor.get_character_skeleton()==null and actor.get_animation_tree()==null,label+": no partially bound rig exposed")
	_check(actor.get_foot_contact(0).is_empty() and actor.get_foot_contact(1).is_empty(),label+": no phantom foot contacts")
	_check(is_zero_approx(actor.get_pelvis_offset()) and actor.get_upper_filter_paths().is_empty(),label+": neutral read receipts")
	_check(not actor.get_bone_world_transform(&"Head").is_finite(),label+": unavailable bone remains explicit")
	_check(not actor.set_upper_body_clip(&"block",1.0),label+": no upper clip on unbound graph")
	actor.set_ik_enabled(false)
	actor.set_look_target(Vector3(0,1,-1))
	actor.clear_look_target()
	actor.clear_upper_body()

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var bare: CharacterCore = CharacterCore.new()
	_check_unbound_contract(bare,"Before ready")
	var rejections: Array[String] = []
	bare.command_rejected.connect(func(reason: String) -> void: rejections.append(reason))
	stage.add_child(bare)
	_check_unbound_contract(bare,"Missing core children")
	_check(rejections.size()==1 and not bare.is_physics_processing(),"Missing core children reject once and stop physics")
	bare.free()
	var incomplete: CharacterCore = Scene.instantiate() as CharacterCore
	incomplete.get_node("FootPlacement/LeftRay").free()
	incomplete.command_rejected.connect(func(reason: String) -> void: rejections.append(reason))
	stage.add_child(incomplete)
	_check_unbound_contract(incomplete,"Missing required foot ray")
	_check(rejections.size()==2 and not incomplete.is_physics_processing(),"Incomplete foot adapter rejects once and stops physics")
	var inactive_tree: AnimationTree = incomplete.get_node("AnimationTree") as AnimationTree
	_check(not inactive_tree.active,"Failed foot binding deactivates the graph")
	var rejected_rig: Node = incomplete.get_node("RigRoot/OriginalRig")
	var rejected_skeletons: Array[Node] = rejected_rig.find_children("*","Skeleton3D",true,false)
	_check(rejected_skeletons.size()==1 and rejected_skeletons[0].get_node_or_null("LeftLegIK")==null,"No partial native IK nodes on rejected adapter")
	incomplete.free()
	var missing_capsule: CharacterCore = Scene.instantiate() as CharacterCore
	missing_capsule.get_node("CollisionShape3D").free()
	stage.add_child(missing_capsule)
	_check_unbound_contract(missing_capsule,"Missing collision capsule")
	_check(not missing_capsule.is_physics_processing(),"Missing physical shape cannot enter locomotion")
	missing_capsule.free()
	var duplicate_chain: CharacterCore = Scene.instantiate() as CharacterCore
	for index: int in range(3):
		duplicate_chain.leg_names[index+3] = duplicate_chain.leg_names[index]
	stage.add_child(duplicate_chain)
	_check_unbound_contract(duplicate_chain,"Duplicate leg chain")
	var duplicate_skeletons: Array[Node] = duplicate_chain.get_node("RigRoot/OriginalRig").find_children("*","Skeleton3D",true,false)
	_check(duplicate_skeletons.size()==1 and duplicate_skeletons[0].get_node_or_null("LeftLegIK")==null,"Overlapping bone chains rejected before native solver creation")
	var duplicate_ray: RayCast3D = duplicate_chain.get_node("FootPlacement/LeftRay") as RayCast3D
	_check(not duplicate_ray.enabled,"Rejected adapter leaves automatic physics queries off")
	duplicate_chain.free()
	_body_box(Vector3(0,-0.1,0),Vector3(80,0.2,80))
	var actor: CharacterCore = _new_actor(Vector3(0,0.05,0))
	if not _check(actor.is_character_ready(),"Actual original frontier rig and typed graph bind"):
		_finish()
		return
	await _frames(90)
	var skeleton: Skeleton3D = actor.get_character_skeleton()
	_check(skeleton != null and skeleton.get_bone_count()>10,"Actual imported skeleton")
	_check(actor.get_node("RigRoot/OriginalRig").scene_file_path=="res://assets/characters/frontier_legionary_0.glb","No substitute character")
	_check(skeleton.get_node_or_null("LeftLegIK") is TwoBoneIK3D and skeleton.get_node_or_null("RightLegIK") is TwoBoneIK3D,"Both native leg solvers attached")
	_check(skeleton.get_node_or_null("HeadLook") is LookAtModifier3D,"Native gaze modifier attached")
	_check(actor.get_animation_tree().active and actor.get_animation_tree().tree_root is AnimationNodeBlendTree,"Live AnimationTree")
	var graph: AnimationNodeBlendTree = actor.get_animation_tree().tree_root as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = graph.get_node(&"Base") as AnimationNodeStateMachine
	var blend: AnimationNodeBlendSpace2D = machine.get_node(&"Locomotion") as AnimationNodeBlendSpace2D
	_check(blend.get_blend_point_count()==12,"All twelve speed/turn blend points")
	var mask: Array[NodePath] = actor.get_upper_filter_paths()
	_check(not mask.is_empty(),"Upper-body filter uses actual imported tracks")
	for path: NodePath in mask:
		var name: String = String(path.get_subname(0))
		_check(not name.begins_with("Thigh") and not name.begins_with("Shin") and not name.begins_with("Foot") and name!="Pelvis","Upper filter excludes leg and pelvis: "+name)
	_check(actor.is_on_floor(),"Collision body is on actual floor")
	_check_feet(actor,"Flat floor")
	_check(not actor.request_motion(Vector3.INF,1.0,CharacterCore.Gait.WALK),"Non-finite command rejected")
	_check(not actor.request_motion(Vector3.FORWARD,1.0,99),"Unknown gait rejected")
	_check(actor.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.WALK),"Walk accepted")
	var before: Vector3 = actor.global_position
	await _frames(120)
	_check(actor.get_planar_speed()>1.1 and actor.get_planar_speed()<=1.50,"Actual walk speed matches bounded physical movement")
	_check(actor.global_position.distance_to(before)>1.5,"Real body translates")
	actor.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.RUN)
	await _frames(120)
	_check(actor.get_planar_speed()>3.3 and actor.get_planar_speed()<=3.85,"Actual run speed")
	actor.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.SPRINT)
	await _frames(120)
	_check(actor.get_planar_speed()>4.8 and actor.get_planar_speed()<=5.45,"Actual sprint using retimed original run")
	actor.stop_motion()
	await _frames(120)
	_check(actor.get_planar_speed()<0.03,"Damped braking reaches a standstill")
	_check(states.has(CharacterCore.Gait.WALK) and states.has(CharacterCore.Gait.RUN) and states.has(CharacterCore.Gait.SPRINT),"Public state transitions emitted")
	var old: Vector3 = actor.global_position
	var yaw: float = actor.global_rotation.y
	actor.request_facing(Vector3.RIGHT)
	await _frames(60)
	_check(absf(wrapf(actor.global_rotation.y-yaw,-PI,PI))>1.3 and actor.global_position.distance_to(old)<0.06,"Stationary turn without root drift")
	_check(states.has(CharacterCore.Gait.TURN),"Turn state emitted")
	actor.clear_facing()
	_check(actor.set_upper_body_clip(&"block",0.75),"Existing authored block is an actual filtered upper-body layer")
	await _frames(45)
	_check(float(actor.get_animation_tree().get("parameters/UpperBody/blend_amount"))>0.70,"Upper-body layer blends")
	actor.clear_upper_body()
	await _frames(45)
	_check(float(actor.get_animation_tree().get("parameters/UpperBody/blend_amount"))<0.03,"Layer clears")
	actor.set_look_target(actor.global_position+Vector3(2,1.5,-1))
	await _frames(30)
	_check(actor.get_bone_world_transform(&"Head").is_finite(),"Native head tracking has a finite real pose")
	var left_ray: RayCast3D = actor.get_node("FootPlacement/LeftRay") as RayCast3D
	var right_ray: RayCast3D = actor.get_node("FootPlacement/RightRay") as RayCast3D
	_check(left_ray.enabled and right_ray.enabled,"Active IK uses both actual ground rays")
	actor.set_ik_enabled(false)
	_check(not left_ray.enabled and not right_ray.enabled,"LOD disables both automatic physics ray updates immediately")
	for side: int in [0,1]:
		var receipt: Dictionary = actor.get_foot_contact(side)
		_check(not bool(receipt.grounded) and not bool(receipt.locked) and not (receipt.surface_point as Vector3).is_finite(),"Disabled IK immediately invalidates the planted contact")
	await _frames(30)
	_check(float(actor.get_foot_contact(0).weight)<0.02 and float(actor.get_foot_contact(1).weight)<0.02,"IK can be switched off for later LOD budgeting")
	var lod_before: Vector3 = actor.global_position
	actor.request_motion(Vector3.RIGHT,1.0,CharacterCore.Gait.WALK)
	await _frames(60)
	_check(actor.get_planar_speed()>1.1 and actor.global_position.distance_to(lod_before)>0.5,"Disabled IK preserves actual locomotion")
	_check(not left_ray.enabled and not right_ray.enabled,"No automatic ray queries while moving with IK disabled")
	for side: int in [0,1]:
		var receipt: Dictionary = actor.get_foot_contact(side)
		_check(not bool(receipt.grounded) and not (receipt.surface_point as Vector3).is_finite(),"Moving disabled IK has no stale ground receipt")
	actor.stop_motion()
	await _frames(90)
	actor.set_ik_enabled(true)
	_check(left_ray.enabled and right_ray.enabled,"Re-enabled IK restores both actual ground rays")
	await _frames(60)
	_check_feet(actor,"Re-enabled IK")
	actor.free()

	# Real airborne interval above the actual floor, followed by landing.
	var falling: CharacterCore = _new_actor(Vector3(6,3,0))
	var air_left: RayCast3D = falling.get_node("FootPlacement/LeftRay") as RayCast3D
	var air_right: RayCast3D = falling.get_node("FootPlacement/RightRay") as RayCast3D
	await _frames(6)
	_check(falling.is_character_ready() and not falling.is_on_floor(),"Actual character is airborne during fall")
	_check(not air_left.enabled and not air_right.enabled,"Airborne actor disables both automatic ray updates")
	falling.set_ik_enabled(false)
	falling.set_ik_enabled(true)
	_check(not air_left.enabled and not air_right.enabled,"Re-enabling IK in air does not start ray queries")
	await _frames(120)
	_check(falling.is_on_floor() and air_left.enabled and air_right.enabled,"Physical landing restores ray updates")
	_check_feet(falling,"After airborne landing")
	falling.free()

	# Removing one live dependency after successful binding must not leave
	# active ground queries, native modifiers, or misleading public receipts.
	var damaged: CharacterCore = _new_actor(Vector3(6,0.05,0))
	await _frames(60)
	_check(damaged.is_character_ready(),"Runtime-removal fixture initially ready")
	var damaged_tree: AnimationTree = damaged.get_animation_tree()
	var damaged_skeleton: Skeleton3D = damaged.get_character_skeleton()
	var remaining_ray: RayCast3D = damaged.get_node("FootPlacement/RightRay") as RayCast3D
	var remaining_solver: TwoBoneIK3D = damaged_skeleton.get_node("RightLegIK") as TwoBoneIK3D
	var lost_ray: RayCast3D = damaged.get_node("FootPlacement/LeftRay") as RayCast3D
	var lost_rejections: Array[String] = []
	damaged.command_rejected.connect(func(reason: String) -> void: lost_rejections.append(reason))
	lost_ray.free()
	_check_unbound_contract(damaged,"Freed live ray")
	await _frames(3)
	_check(lost_rejections.size()==1 and not damaged.is_physics_processing(),"Dependency loss stops physics exactly once")
	_check(not damaged_tree.active and not remaining_ray.enabled and is_zero_approx(remaining_solver.influence),"Dependency loss stops surviving graph, ray and solver")
	damaged.free()

	var detached: CharacterCore = _new_actor(Vector3(6,0.05,0))
	await _frames(60)
	_check(detached.is_character_ready(),"Detached-target fixture initially ready")
	var target_node: Node = detached.get_node("FootPlacement/LeftTarget")
	target_node.get_parent().remove_child(target_node)
	_check_unbound_contract(detached,"Detached but not freed target")
	await _frames(3)
	_check(not detached.is_physics_processing(),"Detached target cannot continue physics")
	target_node.free()
	detached.free()

	var disabled_body: CharacterCore = _new_actor(Vector3(6,0.05,0))
	await _frames(60)
	_check(disabled_body.is_character_ready(),"Disabled-capsule fixture initially ready")
	var live_capsule: CollisionShape3D = disabled_body.get_node("CollisionShape3D") as CollisionShape3D
	live_capsule.disabled = true
	_check_unbound_contract(disabled_body,"Disabled live capsule")
	await _frames(3)
	_check(not disabled_body.is_physics_processing(),"Loss of collision authority stops physical movement")
	disabled_body.free()

	# Dependency loss from a synchronous signal must stop the SAME tick,
	# not merely be detected by the next frame's initial readiness check.
	var landing_listener: CharacterCore = _new_actor(Vector3(6,1.5,0))
	var landing_tree: AnimationTree = landing_listener.get_animation_tree()
	var landing_feet: Node3D = landing_listener.get_node("FootPlacement") as Node3D
	var landing_target: Node3D = landing_feet.get_node("LeftTarget") as Node3D
	var landing_receipts: Array[String] = []
	landing_listener.grounded_changed.connect(func(value: bool) -> void:
		if value:
			landing_receipts.append("ground")
			landing_feet.remove_child(landing_target)
	)
	landing_listener.command_rejected.connect(func(_reason: String) -> void: landing_receipts.append("reject"))
	landing_listener.movement_sampled.connect(func(_velocity: Vector3, grounded: bool) -> void:
		if grounded:
			landing_receipts.append("movement")
	)
	landing_listener.animation_intent_sampled.connect(func(_velocity: Vector3, _speed: float, _yaw: float, grounded: bool) -> void:
		if grounded:
			landing_receipts.append("animation")
	)
	await _frames(90)
	_check(landing_receipts==["ground","reject"],"Landing listener invalidation rejects within the same tick before sample publication")
	_check(not landing_listener.is_physics_processing() and not landing_tree.active,"Signal-driven dependency loss shuts down the graph and physics")
	_check_unbound_contract(landing_listener,"Landing listener detaches target")
	landing_target.free()
	landing_listener.free()

	var state_listener: CharacterCore = _new_actor(Vector3(6,0.05,0))
	await _frames(60)
	var state_tree: AnimationTree = state_listener.get_animation_tree()
	var state_receipts: Array[String] = []
	state_listener.motion_state_changed.connect(func(_previous: int, current: int) -> void:
		if current==CharacterCore.Gait.WALK:
			state_receipts.append("walk")
			state_listener.remove_child(state_tree)
	)
	state_listener.command_rejected.connect(func(_reason: String) -> void: state_receipts.append("reject"))
	state_listener.movement_sampled.connect(func(_velocity: Vector3, _grounded: bool) -> void:
		if state_listener.get_motion_state()==CharacterCore.Gait.WALK:
			state_receipts.append("movement")
	)
	state_listener.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.WALK)
	await _frames(90)
	_check(state_receipts==["walk","reject"],"State listener invalidation stops before animation evaluation or movement receipt")
	_check(not state_listener.is_physics_processing() and not state_tree.active,"Detached live graph is deactivated in its invalidating tick")
	state_tree.free()
	state_listener.free()

	var sample_listener: CharacterCore = _new_actor(Vector3(6,0.05,0))
	await _frames(60)
	var sample_feet: Node3D = sample_listener.get_node("FootPlacement") as Node3D
	var sample_target: Node3D = sample_feet.get_node("LeftTarget") as Node3D
	var sample_receipts: Array[String] = []
	sample_listener.movement_sampled.connect(func(_velocity: Vector3, _grounded: bool) -> void:
		sample_receipts.append("movement")
		sample_feet.remove_child(sample_target)
	)
	sample_listener.command_rejected.connect(func(_reason: String) -> void: sample_receipts.append("reject"))
	sample_listener.animation_intent_sampled.connect(func(_velocity: Vector3, _speed: float, _yaw: float, _grounded: bool) -> void: sample_receipts.append("animation"))
	await _frames(3)
	_check(sample_receipts==["movement","reject"],"Invalidation in movement receipt suppresses stale animation intent")
	_check(not sample_listener.is_physics_processing(),"Movement listener invalidation stops further ticks")
	sample_target.free()
	sample_listener.free()

	# One real step and a tall wall: only the swept small obstacle may be climbed.
	_body_box(Vector3(0,0.09,2.0),Vector3(2.4,0.18,2.0))
	_body_box(Vector3(0,1.0,-0.1),Vector3(3.0,2.0,0.2))
	var walker: CharacterCore = _new_actor(Vector3(0,0.05,4.0))
	await _frames(60)
	walker.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.WALK)
	var max_y: float = walker.global_position.y
	var max_planar: float = 0.0
	for frame: int in range(240):
		await physics_frame
		await process_frame
		max_y = maxf(max_y,walker.global_position.y)
		max_planar = maxf(max_planar,walker.get_planar_speed())
	print("CHARACTER_PHASE1_STAIR max_y=",max_y," final=",walker.global_position," max_speed=",max_planar)
	_check(max_y>0.13,"Physical body climbs an actual 18 cm step using volume sweeps")
	_check(walker.global_position.z<0.6,"Character crosses the step and reaches the wall, not just stands at the step")
	_check(max_planar<=1.50,"Swept step does not teleport the capsule forward")
	_check(walker.global_position.z>0.15,"Tall wall is not bypassed")
	_check(walker.get_planar_speed()<0.12,"Blocked motion cannot fake running animation")
	walker.free()

	# Actual 12-degree lateral slope; feet sample different surface heights.
	_body_box(Vector3(12.0,0.4,0),Vector3(5.0,0.3,5.0),Vector3(0,0,deg_to_rad(12.0)))
	var slope_actor: CharacterCore = _new_actor(Vector3(12.0,0.9,0))
	await _frames(120)
	_check(slope_actor.is_on_floor(),"Physical slope is walkable")
	_check_feet(slope_actor,"Slope")
	var left: Dictionary = slope_actor.get_foot_contact(0)
	var right: Dictionary = slope_actor.get_foot_contact(1)
	if not left.is_empty() and not right.is_empty():
		var normal: Vector3 = left.normal
		_check(normal.dot(Vector3.UP)>0.95 and normal.dot(Vector3.UP)<0.995,"Ray samples actual non-horizontal ground normal")
		_check(absf((left.surface_point as Vector3).y-(right.surface_point as Vector3).y)>0.015,"Distinct independently measured ray heights on slope")
		_check(absf((left.target as Vector3).y-(right.target as Vector3).y)>0.015,"Distinct foot heights on slope")
	_check(slope_actor.get_pelvis_offset()<=0.001 and slope_actor.get_pelvis_offset()>=-0.181,"Hip offset remains bounded")
	slope_actor.free()
	_finish()

func _finish() -> void:
	if is_instance_valid(stage):
		stage.free()
	print("CHARACTER_PHASE1_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CHARACTER_PHASE1_PASS" if failures.is_empty() else "CHARACTER_PHASE1_FAIL")
	quit(0 if failures.is_empty() else 1)
