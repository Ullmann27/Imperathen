extends RefCounted
## Per-instance AnimationTree graph over the original imported animation library.
## X = signed turn, Y = actual ground speed (m/s). No gameplay state in the graph.
var _tree: AnimationTree
var _player: AnimationPlayer
var _playback: AnimationNodeStateMachinePlayback
var _upper: AnimationNodeAnimation
var _filter: AnimationNodeBlend2
var _upper_tracks: Array[NodePath] = []
var _upper_weight: float = 0.0
var _last_state: StringName = &"Locomotion"
var _sprint_speed: float = 5.4
var blend_position: Vector2 = Vector2.ZERO

func configure(tree: AnimationTree, player: AnimationPlayer, skeleton: Skeleton3D,
		spine: int, walk: float, run: float, sprint: float) -> bool:
	if not is_instance_valid(tree) or not is_instance_valid(player) or not is_instance_valid(skeleton):
		return false
	for clip: StringName in [&"idle",&"march",&"run"]:
		if not player.has_animation(clip):
			return false
	if not (walk > 0.0 and run > walk and sprint > run):
		return false
	_tree = tree
	_player = player
	_sprint_speed = sprint
	var anim_root: Node = player.get_node_or_null(player.root_node)
	if anim_root == null:
		return false
	player.stop()
	tree.active = false
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(anim_root)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var space: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	space.min_space = Vector2(-1.0,0.0)
	space.max_space = Vector2(1.0,sprint)
	space.x_label = "Turn"
	space.y_label = "Ground speed m/s"
	# Stationary left/right use the real idle pose plus alternating procedural
	# IK steps. Moving curves blend the same authored march/run family.
	# Sprint is the original run retimed, not a purported new mocap take.
	for turn: float in [-1.0,0.0,1.0]:
		space.add_blend_point(_clip(&"idle",1.0,true),Vector2(turn,0.0))
		space.add_blend_point(_clip(&"march",1.0,true),Vector2(turn,walk))
		space.add_blend_point(_clip(&"run",1.0,true),Vector2(turn,run))
		space.add_blend_point(_clip(&"run",sprint/run,true),Vector2(turn,sprint))
	var machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()
	machine.add_node(&"Locomotion",space,Vector2(120,100))
	machine.add_node(&"Airborne",_clip(&"idle",1.0,true),Vector2(350,100))
	var leave: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	leave.xfade_time = 0.12
	var land: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
	land.xfade_time = 0.16
	machine.add_transition(&"Locomotion",&"Airborne",leave)
	machine.add_transition(&"Airborne",&"Locomotion",land)
	var graph: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	_upper = _clip(&"idle",1.0,true)
	_filter = AnimationNodeBlend2.new()
	_filter.filter_enabled = true
	_upper_tracks.clear()
	# Derive masks from actual track paths, not guessed Skeleton3D names.
	for name: StringName in player.get_animation_list():
		var anim: Animation = player.get_animation(name)
		for index: int in range(anim.get_track_count()):
			var path: NodePath = anim.track_get_path(index)
			if path.get_subname_count() != 1:
				continue
			var track_node: Node = anim_root.get_node_or_null(NodePath(String(path.get_concatenated_names())))
			if track_node != skeleton:
				continue
			var bone: int = skeleton.find_bone(String(path.get_subname(0)))
			if bone < 0:
				continue
			var cursor: int = bone
			while cursor >= 0 and cursor != spine:
				cursor = skeleton.get_bone_parent(cursor)
			if cursor == spine and not _upper_tracks.has(path):
				_upper_tracks.append(path)
				_filter.set_filter_path(path,true)
	if _upper_tracks.is_empty():
		return false
	graph.add_node(&"Base",machine,Vector2(20,80))
	graph.add_node(&"UpperClip",_upper,Vector2(20,240))
	graph.add_node(&"UpperBody",_filter,Vector2(300,100))
	graph.connect_node(&"UpperBody",0,&"Base")
	graph.connect_node(&"UpperBody",1,&"UpperClip")
	graph.connect_node(&"output",0,&"UpperBody")
	tree.tree_root = graph
	tree.set("parameters/UpperBody/blend_amount",0.0)
	tree.set("parameters/Base/Locomotion/blend_position",Vector2.ZERO)
	tree.active = true
	_playback = tree.get("parameters/Base/playback") as AnimationNodeStateMachinePlayback
	if _playback == null:
		tree.active = false
		return false
	_playback.start(&"Locomotion")
	tree.advance(0.0)
	return true

func _clip(name: StringName, rate: float, looped: bool) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = name
	node.use_custom_timeline = true
	node.timeline_length = maxf(0.01,_player.get_animation(name).length/maxf(0.01,rate))
	node.stretch_time_scale = true
	node.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
	return node

func set_upper_body_clip(clip: StringName, weight: float) -> bool:
	if not is_instance_valid(_player) or _upper == null or not _player.has_animation(clip) or not is_finite(weight):
		return false
	_upper.animation = clip
	_upper.timeline_length = maxf(0.01,_player.get_animation(clip).length)
	_upper.loop_mode = _player.get_animation(clip).loop_mode
	_upper_weight = clampf(weight,0.0,1.0)
	return true

func clear_upper_body() -> void:
	_upper_weight = 0.0

func advance(delta: float, speed: float, signed_turn: float, grounded: bool) -> void:
	if not is_instance_valid(_tree) or _playback == null:
		return
	var state: StringName = &"Locomotion" if grounded else &"Airborne"
	if state != _last_state:
		_playback.travel(state)
		_last_state = state
	var desired: Vector2 = Vector2(clampf(signed_turn,-1.0,1.0),clampf(speed,0.0,_sprint_speed))
	blend_position = blend_position.lerp(desired,1.0-exp(-12.0*delta))
	_tree.set("parameters/Base/Locomotion/blend_position",blend_position)
	var weight: float = float(_tree.get("parameters/UpperBody/blend_amount"))
	_tree.set("parameters/UpperBody/blend_amount",lerpf(weight,_upper_weight,1.0-exp(-12.0*delta)))
	_tree.advance(delta)

func get_upper_filter_paths() -> Array[NodePath]:
	return _upper_tracks.duplicate()
