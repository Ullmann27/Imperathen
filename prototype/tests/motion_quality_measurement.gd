extends SceneTree
## Sample real imported rigs and the production hero solver at 60 Hz.
## Report measured maxima even when quality limits are exceeded; the separate
## fail-closed release gate decides acceptance and never treats this as a pass.

const Person = preload("res://scripts/visuals/village_person.gd")
const Motion = preload("res://scripts/visuals/character_motion.gd")
const HZ := 60.0
const LOOPS := ["idle","march","run","talk","work","retreat","wall","testudo","block"]
const MOTION_REQUIRED := ["idle","march","run","talk","work","gather","train","attack","hit","death","shoot","retreat"]
const HUMAN_JOINTS := ["Pelvis","Spine","Head","Arm_L","Forearm_L","Hand_L","Arm_R","Forearm_R","Hand_R","Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]
var records: Dictionary = {}
var family_metrics: Dictionary = {}
var fatal: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _metrics() -> Dictionary:
	return {"max_segment_error_m":0.0,"max_linear_speed_m_s":0.0,"max_angular_speed_deg_s":0.0,
		"max_loop_seam_m":0.0,"max_loop_seam_deg":0.0,"frozen_required_clips":0}


func _merge(into: Dictionary, values: Dictionary) -> void:
	for key: String in values:
		if key == "frozen_required_clips":
			into[key] = int(into.get(key,0)) + int(values[key])
		else:
			into[key] = maxf(float(into.get(key,0.0)),float(values[key]))


func _pose(rig: Skeleton3D) -> Array[Transform3D]:
	rig.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for i in rig.get_bone_count():
		result.append(rig.get_bone_global_pose(i))
	return result


func _sample(rig: Skeleton3D, sampler: Callable, name: String, seconds: float, loop: bool, must_move: bool) -> Dictionary:
	var m := _metrics()
	var count := maxi(1,ceili(seconds*HZ))
	var first: Array[Transform3D] = []
	var previous: Array[Transform3D] = []
	var last: Array[Transform3D] = []
	var changed := 0.0
	var angle_changed := 0.0
	var finite := true
	var dt := seconds/float(count)
	for frame in range(count+1):
		sampler.call(float(frame)/float(count))
		var pose := _pose(rig)
		if frame == 0:
			first = pose
		for bone in pose.size():
			var transform := pose[bone]
			if not transform.is_finite() or absf(transform.basis.determinant()) < .000001:
				finite = false
				continue
			var q := transform.basis.orthonormalized().get_rotation_quaternion()
			if not q.is_finite():
				finite = false
				continue
			var parent := rig.get_bone_parent(bone)
			# Extra mechanical bow-string bones may intentionally translate;
			# anatomical human bone lengths may not.
			if parent >= 0 and rig.get_bone_name(bone) in HUMAN_JOINTS and pose[parent].is_finite():
				var length := transform.origin.distance_to(pose[parent].origin)
				m.max_segment_error_m = maxf(m.max_segment_error_m,absf(length-rig.get_bone_rest(bone).origin.length()))
			if first[bone].is_finite():
				changed = maxf(changed,transform.origin.distance_to(first[bone].origin))
				angle_changed = maxf(angle_changed,rad_to_deg(q.angle_to(first[bone].basis.orthonormalized().get_rotation_quaternion())))
			if frame > 0 and previous[bone].is_finite():
				var old_q := previous[bone].basis.orthonormalized().get_rotation_quaternion()
				m.max_linear_speed_m_s = maxf(m.max_linear_speed_m_s,transform.origin.distance_to(previous[bone].origin)/dt)
				m.max_angular_speed_deg_s = maxf(m.max_angular_speed_deg_s,rad_to_deg(q.angle_to(old_q))/dt)
		previous = pose
		last = pose
	if loop and finite:
		for i in last.size():
			m.max_loop_seam_m = maxf(m.max_loop_seam_m,last[i].origin.distance_to(first[i].origin))
			m.max_loop_seam_deg = maxf(m.max_loop_seam_deg,rad_to_deg(last[i].basis.orthonormalized().get_rotation_quaternion().angle_to(first[i].basis.orthonormalized().get_rotation_quaternion())))
	if must_move and changed < .003 and angle_changed < 1.0:
		m.frozen_required_clips = 1
	return {"name":name,"sample_count":count+1,"duration_s":seconds,"finite":finite,"metrics":m}


func _raw_asset(path: String) -> void:
	var entry := {"finite":true,"sample_count":0,"metrics":_metrics(),"clips":[],"errors":[]}
	records[path] = entry
	var packed := load("res://"+path) as PackedScene
	if packed == null:
		entry.errors.append("PackedScene import missing")
		entry.finite=false
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var rigs := scene.find_children("*","Skeleton3D",true,false)
	var players := scene.find_children("*","AnimationPlayer",true,false)
	if rigs.size()!=1 or players.is_empty():
		entry.errors.append("Expected one actual rig and at least one animation player")
		entry.finite=false
		scene.free()
		return
	var rig := rigs[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if not player.has_animation("idle") or not player.has_animation("march"):
		entry.errors.append("Required idle/march clips are absent")
	for clip_name: String in player.get_animation_list():
		if clip_name == "RESET":
			continue
		var clip := player.get_animation(clip_name)
		var seconds := clip.length
		if not is_finite(seconds) or seconds <= .01 or seconds > 30.0:
			entry.errors.append("Invalid clip duration "+clip_name)
			continue
		var original_loop := clip.loop_mode
		clip.loop_mode=Animation.LOOP_NONE
		player.play(clip_name)
		var sampler := func(phase: float) -> void:
			player.seek(phase*seconds,true)
			player.advance(0)
		var data := _sample(rig,sampler,clip_name,seconds,clip_name in LOOPS,clip_name in MOTION_REQUIRED)
		clip.loop_mode=original_loop
		entry.clips.append(data)
		entry.sample_count+=int(data.sample_count)
		entry.finite=entry.finite and data.finite
		_merge(entry.metrics,data.metrics)
		player.stop()
	scene.free()


func _hero_solver(paths: Array) -> void:
	# Exercise the actual running presentation adapter, not just its source clips.
	# Foot support is measured in world-space equivalent travel during known
	# stance intervals. This is ankle contact, NOT a mesh sole penetration test.
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player","italia",12)
	var measured := {"subjects":paths.duplicate(),"sample_hz":60,"sample_count":0,
		"scenarios":["idle_talk","walk_run_stop","attack_guard_reaction"],
		"metrics":{"max_support_slip_m":0.0},"actual_runtime_clips":[]}
	for level in 4:
		actor._reload(level)
		var rig := actor._motion.skeleton
		if not is_instance_valid(rig):
			fatal.append("Hero runtime rig missing at LOD "+str(level))
			continue
		for action: String in ["idle","talk","march","run"]:
			var seconds := actor.animator.get_animation(action).length
			var sampler := func(phase: float) -> void:
				actor.sample_pose(action,phase)
			var result := _sample(rig,sampler,action,seconds,true,true)
			result["lod"]=level
			measured.actual_runtime_clips.append(result)
			measured.sample_count+=int(result.sample_count)
			if action in ["march","run"]:
				var steps := maxi(1,ceili(seconds*HZ))
				var stance := .53 if action=="march" else .32
				var stride := actor._motion.gait_stride(action,-1.0)
				for side: String in ["L","R"]:
					var foot := rig.find_bone("Foot_"+side)
					var anchor := Vector3.ZERO
					var planted := false
					for i in range(steps+1):
						var phase := float(i)/float(steps)
						actor.sample_pose(action,phase)
						var u := fposmod(phase+(0.0 if side=="R" else .5),1.0)
						var at := rig.get_bone_global_pose(foot).origin+Vector3(0,0,phase*stride)
						if u<stance:
							if not planted:
								anchor=at
							else:
								measured.metrics.max_support_slip_m=maxf(measured.metrics.max_support_slip_m,Vector2(at.x-anchor.x,at.z-anchor.z).length())
							planted=true
						else:
							planted=false
		for action: String in Motion.TECHNIQUES:
			var duration: float = Motion.TIMING[action].z
			var sampler := func(phase: float) -> void:
				actor.sample_combat(action,phase)
			var result := _sample(rig,sampler,action,duration,false,true)
			result["lod"]=level
			measured.actual_runtime_clips.append(result)
			measured.sample_count+=int(result.sample_count)
		actor.cancel_action()
	actor.free()
	family_metrics["hero"]=measured


func _run() -> void:
	var contract_path := OS.get_environment("IMPERATHEN_MOTION_CONTRACT")
	var report_path := OS.get_environment("IMPERATHEN_MOTION_REPORT")
	var fingerprint := OS.get_environment("IMPERATHEN_MOTION_SOURCE")
	if contract_path.is_empty() or report_path.is_empty() or fingerprint.is_empty():
		push_error("Motion measurement needs explicit source-bound output paths")
		quit(2)
		return
	var contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(contract_path))
	if typeof(contract)!=TYPE_DICTIONARY:
		push_error("Missing motion contract")
		quit(2)
		return
	for family: Dictionary in contract.families:
		if family.status=="active" and family.profile in ["human","animal"]:
			for path: String in family.resources:
				_raw_asset(path)
		if family.id=="hero":
			_hero_solver(family.resources)
	var handle := FileAccess.open(report_path,FileAccess.WRITE)
	if handle==null:
		push_error("Cannot write motion measurement")
		quit(2)
		return
	handle.store_string(JSON.stringify({"schema_version":1,"source_fingerprint":fingerprint,
		"sample_hz":60,"assets":records,"family_metrics":family_metrics,"fatal":fatal},"  ")+"\n")
	handle.close()
	print("MOTION_MEASURED ",records.size()," real assets; ",fatal.size()," fatal fixture errors; numerical acceptance is separate")
	quit(0 if fatal.is_empty() else 1)
