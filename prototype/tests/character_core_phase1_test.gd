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
		print("CHARACTER_PHASE1_CONTACT ",label," side=",side," error_m=",point.distance_to(solved)," normal=",receipt.normal)

func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
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
	actor.set_ik_enabled(false)
	await _frames(30)
	_check(float(actor.get_foot_contact(0).weight)<0.02 and float(actor.get_foot_contact(1).weight)<0.02,"IK can be switched off for later LOD budgeting")
	actor.set_ik_enabled(true)
	await _frames(60)
	_check_feet(actor,"Re-enabled IK")
	actor.free()

	# One real step and a tall wall: only the swept small obstacle may be climbed.
	_body_box(Vector3(0,0.09,2.0),Vector3(2.4,0.18,2.0))
	_body_box(Vector3(0,1.0,-0.1),Vector3(3.0,2.0,0.2))
	var walker: CharacterCore = _new_actor(Vector3(0,0.05,4.0))
	await _frames(60)
	walker.request_motion(Vector3.FORWARD,1.0,CharacterCore.Gait.WALK)
	var max_y: float = walker.global_position.y
	for frame: int in range(240):
		await physics_frame
		await process_frame
		max_y = maxf(max_y,walker.global_position.y)
	_check(max_y>0.13,"Physical body climbs an actual 18 cm step using volume sweeps")
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
