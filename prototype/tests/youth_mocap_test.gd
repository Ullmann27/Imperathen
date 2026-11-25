extends SceneTree
## Source-specific integration: actual imported original model and runtime
## playback route, not a substitute skin or a synthetic Skeleton3D.
const Person = preload("res://scripts/visuals/village_person.gd")
const CLIPS := ["march","run","jab_left","jab_right","hook_left","hook_right","uppercut_left","uppercut_right","front_kick","side_kick","block"]
const FISTS := ["jab_left","jab_right","hook_left","hook_right","uppercut_left","uppercut_right","front_kick","side_kick"]
var failures: Array[String] = []
var checks: int = 0
var max_segment_error: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("YOUTH_MOCAP_FAIL: "+label)


func _sample(rig: Skeleton3D) -> Array[Transform3D]:
	rig.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for index in rig.get_bone_count():
		var pose: Transform3D = rig.get_bone_global_pose(index)
		result.append(pose)
		_check(pose.is_finite(),"Finite pose "+rig.get_bone_name(index))
		var parent: int = rig.get_bone_parent(index)
		if parent >= 0:
			var actual: float = pose.origin.distance_to(rig.get_bone_global_pose(parent).origin)
			var expected: float = rig.get_bone_rest(index).origin.length()
			max_segment_error = maxf(max_segment_error,absf(actual-expected))
	return result


func _run() -> void:
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/accad_youth_motion.json"))
	_check(proof is Dictionary and int(proof.get("rig_joints",0))==35,"Actual motion source manifest")
	if not proof is Dictionary:
		quit(1)
		return
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player","italia",12)
	_check(actor.configure_meshy_youth(true),"Original youth complete")
	for level in 4:
		actor._reload(level)
		actor.set_process(false)
		_check(actor.active_model_path=="res://assets/characters/hero_meshy_italia_%d.glb"%level,"Exact LOD %d"%level)
		_check(actor._uses_youth_mocap(),"Original mocap route active")
		var rig: Skeleton3D = actor._motion.skeleton
		if not is_instance_valid(rig) or not is_instance_valid(actor.animator):
			_check(false,"Real skin and animation player available")
			continue
		_check(rig.get_bone_count()==35,"35 real joints at LOD %d"%level)
		for action: String in CLIPS:
			_check(actor.animator.has_animation(action),"Imported "+action)
			if not actor.animator.has_animation(action):
				continue
			var anim: Animation = actor.animator.get_animation(action)
			var samples: int = maxi(2,ceili(anim.length*60.0))
			var first: Array[Transform3D] = []
			var last: Array[Transform3D] = []
			var moved: float = 0.0
			for index in range(samples+1):
				var phase: float = float(index)/float(samples)
				if action in FISTS:
					actor.sample_combat(action,phase)
				else:
					actor.sample_pose(action,phase)
				var current: Array[Transform3D] = _sample(rig)
				if index==0:
					first=current
				else:
					for joint in current.size():
						moved=maxf(moved,current[joint].origin.distance_to(first[joint].origin))
				last=current
			_check(moved>0.025,"Real non-frozen motion: "+action)
			if action in FISTS:
				_check(actor.animator.current_animation==action,"Domain selects actual captured action: "+action)
				actor.cancel_action()
			if action in ["march","run"]:
				_check(absf(actor.locomotion_stride(action)-float(proof.gaits[action].stride_m))<0.001,"Measured stride synchronized")
				var seam: float = 0.0
				for joint in first.size():
					seam=maxf(seam,first[joint].origin.distance_to(last[joint].origin))
				_check(seam<0.03,"Closed gait cycle "+action)
	_check(max_segment_error<=0.005,"Unchanged anatomical joint lengths")
	actor.free()
	print("YOUTH_MOCAP_RUNTIME_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"max_segment_error_m":max_segment_error,"visual_quality_approved":false,"physical_fold7":false}))
	print("YOUTH_MOCAP_RUNTIME_PASS" if failures.is_empty() else "YOUTH_MOCAP_RUNTIME_FAIL")
	quit(0 if failures.is_empty() else 1)
