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
				# Advance the same blend clock as production; a manually sampled
				# headless actor does not receive its ordinary _process callback.
				actor._motion.advance(1.0/60.0)
				if action in FISTS:
					actor.sample_combat(action,phase)
					if index==int(samples/2):
						_check(actor.animator.current_animation==action,"Domain selects actual captured action: "+action)
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
				actor.cancel_action()
			if action in ["march","run"]:
				_check(absf(actor.locomotion_stride(action)-float(proof.gaits[action].stride_m))<0.001,"Measured stride synchronized")
				var seam: float = 0.0
				for joint in first.size():
					seam=maxf(seam,first[joint].origin.distance_to(last[joint].origin))
				_check(seam<0.03,"Closed gait cycle "+action)
		# Evaluate the actual skinned sandals after a known floor correction.
		# The renderer must not change the CharacterBody or erase run flight.
		var skin_review: Dictionary = proof.lods[level].get("surface_review",{})
		_check(int(skin_review.get("pose_samples",0))>0,"Actual surface-edge audit present at LOD %d"%level)
		_check(not actor._youth_soles.samples.is_empty(),"Real skinned sole samples at LOD %d"%level)
		for action: String in ["idle","march","run","block"]:
			for f in [0.0,.25,.5,.75]:
				actor.sample_pose(action,f)
				var lowest: float=actor._youth_soles.measure_lowest()
				_check(is_finite(lowest),"Finite rendered sole "+action)
				if not is_finite(lowest):
					continue
				var airborne: float=actor._youth_soles.clearance(action,f)
				var root_position := actor.global_position
				# Deliberately offset the support plane by 3 cm to exercise
				# the corrective path independently of the clip's baseline.
				var ground := lowest-.03-airborne
				actor._youth_soles.apply_to_floor(ground,action,f)
				_check(absf(actor._youth_soles.measure_lowest()-(ground+.003+airborne))<.002,"Sole target including recorded flight "+action)
				_check(actor.global_position.is_equal_approx(root_position),"Sole correction does not move actor root")
				actor._motion.skeleton.force_update_all_bone_transforms()
				_sample(actor._motion.skeleton)
	_check(max_segment_error<=0.005,"Unchanged anatomical joint lengths")
	actor.free()
	print("YOUTH_MOCAP_RUNTIME_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"max_segment_error_m":max_segment_error,"visual_quality_approved":false,"physical_fold7":false}))
	print("YOUTH_MOCAP_RUNTIME_PASS" if failures.is_empty() else "YOUTH_MOCAP_RUNTIME_FAIL")
	quit(0 if failures.is_empty() else 1)
