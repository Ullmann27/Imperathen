extends SceneTree
## Sample real imported rigs and the production hero solver at 60 Hz.
## Report measured maxima even when quality limits are exceeded; the separate
## fail-closed release gate decides acceptance and never treats this as a pass.

const Person = preload("res://scripts/visuals/village_person.gd")
const Motion = preload("res://scripts/visuals/character_motion.gd")
const SkinMeasurement = preload("res://tests/motion_skin_measurement.gd")
const EquipmentMeasurement = preload("res://tests/motion_equipment_measurement.gd")
const WorldMeasurement = preload("res://tests/motion_world_measurement.gd")
const HZ := 60.0
const LOOPS := ["idle","march","run","talk","work","retreat","wall","testudo","block"]
const MOTION_REQUIRED := ["idle","march","run","talk","work","gather","train","attack","hit","death","shoot","retreat"]
const HUMAN_JOINTS := ["Pelvis","Spine","Head","Arm_L","Forearm_L","Hand_L","Arm_R","Forearm_R","Hand_R","Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]
var records: Dictionary = {}
var family_metrics: Dictionary = {}
var fatal: Array[String] = []
var _output_path := ""
var _source_fingerprint := ""

class SourcePerson extends Person:
	# Only source selection is overridden. Binding, morphs, equipment,
	# playback, solver and transitions remain the production implementation.
	var exact_source := ""
	func _path(_level: int) -> String:
		return exact_source


func _initialize() -> void:
	_run.call_deferred()


func _metrics() -> Dictionary:
	return {"max_segment_error_m":0.0,"max_linear_speed_m_s":0.0,"max_angular_speed_deg_s":0.0,
		"max_loop_seam_m":0.0,"max_loop_seam_deg":0.0,"frozen_required_clips":0}


func _merge(into: Dictionary, values: Dictionary) -> void:
	for key: String in values:
		if key in ["frozen_required_clips","skin_edge_violations"]:
			into[key] = int(into.get(key,0)) + int(values[key])
		else:
			into[key] = maxf(float(into.get(key,0.0)),float(values[key]))


func _pose(rig: Skeleton3D) -> Array[Transform3D]:
	rig.force_update_all_bone_transforms()
	var result: Array[Transform3D] = []
	for i in rig.get_bone_count():
		result.append(rig.get_bone_global_pose(i))
	return result


func _sample(rig: Skeleton3D, sampler: Callable, name: String, seconds: float, loop: bool, must_move: bool, skin: RefCounted = null, contact: Dictionary = {}) -> Dictionary:
	var m := _metrics()
	var count := maxi(1,ceili(seconds*HZ))
	var first: Array[Transform3D] = []
	var previous: Array[Transform3D] = []
	var last: Array[Transform3D] = []
	var changed := 0.0
	var angle_changed := 0.0
	var finite := true
	var dt := seconds/float(count)
	var worst := {}
	var surface_metrics := {}
	var anchors := {}
	if skin != null:
		surface_metrics = {"max_sole_penetration_m":0.0,"skin_edge_violations":0}
	if not contact.is_empty():
		surface_metrics["max_support_slip_m"] = 0.0
	for frame in range(count+1):
		sampler.call(float(frame)/float(count))
		var pose := _pose(rig)
		if frame == 0:
			first = pose
		for bone in pose.size():
			var transform := pose[bone]
			# A shooting archer legitimately scales its Arrow bone to 0.001
			# while the arrow is released. Its determinant is 1e-9, not a
			# singular or non-finite anatomical pose. Check actual singularity.
			if not transform.is_finite() or transform.basis.determinant() == 0.0:
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
				var linear_speed := transform.origin.distance_to(previous[bone].origin)/dt
				var angular_speed := rad_to_deg(q.angle_to(old_q))/dt
				if linear_speed > float(m.max_linear_speed_m_s):
					worst["linear"] = {"bone":rig.get_bone_name(bone),"frame":frame,"phase":float(frame)/float(count)}
				if angular_speed > float(m.max_angular_speed_deg_s):
					worst["angular"] = {"bone":rig.get_bone_name(bone),"frame":frame,"phase":float(frame)/float(count)}
				m.max_linear_speed_m_s = maxf(m.max_linear_speed_m_s,linear_speed)
				m.max_angular_speed_deg_s = maxf(m.max_angular_speed_deg_s,angular_speed)
		previous = pose
		last = pose
		if skin != null:
			var observed: Dictionary = skin.sample()
			finite = finite and bool(observed.finite)
			if observed.max_sole_penetration_m != null:
				if float(observed.max_sole_penetration_m)>float(surface_metrics.max_sole_penetration_m):
					worst["sole"] = observed.lowest_sole_vertex.duplicate()
					worst.sole["phase"] = float(frame)/float(count)
				surface_metrics.max_sole_penetration_m = maxf(float(surface_metrics.max_sole_penetration_m),float(observed.max_sole_penetration_m))
			surface_metrics.skin_edge_violations += int(observed.skin_edge_violations)
			if not contact.is_empty():
				var next_anchors := {}
				for key: int in observed.contact_points:
					var phase := float(frame)/float(count)
					var u := fposmod(phase+(0.0 if key%2==1 else .5),1.0)
					if bool(contact.get("gait",false)) and u>=float(contact.stance): continue
					var at: Vector3 = observed.contact_points[key]
					var anchor: Vector3 = anchors.get(key,at)
					surface_metrics.max_support_slip_m=maxf(float(surface_metrics.max_support_slip_m),Vector2(at.x-anchor.x,at.z-anchor.z).length())
					next_anchors[key]=anchor
				anchors=next_anchors
		elif not contact.is_empty():
			for side: String in ["L","R"]:
				var bone := rig.find_bone("Foot_"+side)
				if bone < 0:
					finite = false
					continue
				var phase := float(frame)/float(count)
				var u := fposmod(phase+(0.0 if side=="R" else .5),1.0)
				var supported := not bool(contact.get("gait",false)) or u < float(contact.stance)
				var at := rig.global_transform*pose[bone].origin
				if supported:
					if anchors.has(side):
						var anchor: Vector3 = anchors[side]
						surface_metrics.max_support_slip_m = maxf(float(surface_metrics.max_support_slip_m),Vector2(at.x-anchor.x,at.z-anchor.z).length())
					else:
						anchors[side]=at
				else:
					anchors.erase(side)
	if loop and finite:
		for i in last.size():
			m.max_loop_seam_m = maxf(m.max_loop_seam_m,last[i].origin.distance_to(first[i].origin))
			m.max_loop_seam_deg = maxf(m.max_loop_seam_deg,rad_to_deg(last[i].basis.orthonormalized().get_rotation_quaternion().angle_to(first[i].basis.orthonormalized().get_rotation_quaternion())))
	if must_move and changed < .003 and angle_changed < 1.0:
		m.frozen_required_clips = 1
	return {"name":name,"sample_hz":60,"sample_count":count+1,"duration_s":seconds,
		"finite":finite,"metrics":m,"surface_metrics":surface_metrics,"worst":worst}


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


func _new_family() -> Dictionary:
	return {"subjects":[],"sample_hz":60,"sample_count":0,"scenarios":[],
		"metrics":{},"runtime_rig_metrics":_metrics(),"actual_runtime_clips":[],
		"scenario_samples":[],"errors":[]}


func _observe(measured: Dictionary, subject: String, scenario: String, count: int, finite: bool, metrics: Dictionary) -> void:
	var record: Dictionary = {}
	for prior: Dictionary in measured.scenario_samples:
		if prior.subject == subject and prior.scenario == scenario:
			record = prior
			break
	if record.is_empty():
		record = {"subject":subject,"scenario":scenario,"sample_hz":60,
			"sample_count":0,"finite":true,"metrics":{}}
		measured.scenario_samples.append(record)
	record.sample_count += count
	record.finite = bool(record.finite) and finite
	_merge(record.metrics,metrics)
	# Top-level totals are reconstructed from the scenario observations once
	# sampling finishes, so repeated classifications cannot conceal a failure.
	if scenario not in measured.scenarios: measured.scenarios.append(scenario)


func _record_clip(measured: Dictionary, subject: String, clip: Dictionary) -> void:
	clip["subject"] = subject
	measured.actual_runtime_clips.append(clip)
	_merge(measured.runtime_rig_metrics,clip.metrics)
	if subject not in measured.subjects: measured.subjects.append(subject)


func _configure_source(actor: SourcePerson, path: String) -> void:
	actor.exact_source = "res://"+path
	actor.position = Vector3(0,.9,0)
	actor.set_process(false)
	actor._check_lod = 100000.0
	if path.contains("hero_quality_"):
		actor.configure("player","italia",12)
	elif path.contains("frontier_"):
		var identity := path.get_file().trim_prefix("frontier_").get_basename()
		identity = identity.substr(0,identity.length()-2)
		actor.configure_resident("italia",32,identity,0)
	elif path.contains("meshy/characters/"):
		var identity := path.get_file().get_basename()
		identity = identity.substr(0,identity.length()-2)
		actor.configure_resident("germania" if "germanic" in identity else "italia",32,
			"spearman" if "germanic" in identity else "legionary",0)
		if not actor.configure_meshy(identity):
			fatal.append("Production Meshy routing rejected registered source "+path)
	elif path.contains("assets/landscape/"):
		actor.configure("regional_worker","han" if "han_" in path else ("wa" if "wa_" in path else "germania"),32)
	else:
		var role := "companion" if "villager_" in path else ("mentor" if "/officer_" in path else ("recruit" if "/spear_" in path else "enemy"))
		actor.configure(role,"germania",32 if role!="companion" else 12)
	actor._check_lod = 100000.0
	actor.set_process(false)


func _discontinuity(before: Array[Transform3D], after: Array[Transform3D]) -> Dictionary:
	var result := {"max_transition_position_jump_m":0.0,"max_transition_rotation_jump_deg":0.0}
	for bone in mini(before.size(),after.size()):
		result.max_transition_position_jump_m = maxf(result.max_transition_position_jump_m,before[bone].origin.distance_to(after[bone].origin))
		result.max_transition_rotation_jump_deg = maxf(result.max_transition_rotation_jump_deg,
			rad_to_deg(before[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(after[bone].basis.orthonormalized().get_rotation_quaternion())))
	return result


func _world_pose(rig: Skeleton3D) -> Array[Transform3D]:
	var result := _pose(rig)
	for bone in result.size(): result[bone] = rig.global_transform*result[bone]
	return result


func _runtime_transitions(actor: Person, measured: Dictionary, subject: String) -> void:
	var rig: Skeleton3D = actor._motion.skeleton
	actor.reset_motion()
	actor.position = Vector3(0,.9,0)
	var metrics := {"max_transition_position_jump_m":0.0,"max_transition_rotation_jump_deg":0.0}
	var finite := true
	var samples := 0
	# Observe the zero-time boundary separately from legitimate per-frame
	# travel. The full clips independently measure speed and angular speed.
	for command: String in ["idle","march","run","idle","talk","march","work","idle"]:
		var source_clip: String = actor.clip
		var before := _world_pose(rig)
		if command in ["work","talk"]:
			actor.drive(0.0)
			actor.cue(command)
		else:
			if actor.clip in ["work","talk"]: actor.cancel_action()
			actor.drive(3.6 if command=="run" else (1.45 if command=="march" else 0.0))
			actor._process(0.0)
		var boundary := _discontinuity(before,_world_pose(rig))
		if not measured.has("transition_boundaries"): measured["transition_boundaries"] = []
		measured.transition_boundaries.append({"subject":subject,"from":source_clip,"to":command,"metrics":boundary})
		_merge(metrics,boundary)
		for frame in 30:
			actor._process(1.0/HZ)
			for pose: Transform3D in _pose(rig): finite = finite and pose.is_finite()
			samples += 1
	_observe(measured,subject,"walk_run_stop",samples,finite,metrics)
	_observe(measured,subject,"idle_talk",samples,finite,metrics)
	_observe(measured,subject,"work_interact",samples,finite,metrics)
	actor.reset_motion()


func _person_family(family: Dictionary) -> void:
	var measured := _new_family()
	family_metrics[family.id] = measured
	var lod_poses := {}
	for path: String in family.resources:
		var actor := SourcePerson.new()
		root.add_child(actor)
		_configure_source(actor,path)
		await process_frame
		var rig: Skeleton3D = actor._motion.skeleton
		if not is_instance_valid(rig) or actor.animator == null:
			fatal.append("Runtime rig or animation player missing: "+path)
			actor.free()
			continue
		var skin := SkinMeasurement.new()
		skin.bind(actor.body)
		for error: String in skin.errors: measured.errors.append(path+": "+error)
		var applicable: Array = family.get("subject_scenarios",{}).get(path,family.review_scope)
		var kit := actor.body.find_child("FrontierRomanKit",true,false) as MeshInstance3D
		if "military_equipment" in applicable and (kit==null or kit.skin==null or not kit.is_visible_in_tree()):
			measured.errors.append(path+": actual embedded military kit is absent or unbound")
		var actions: Array[String] = []
		for action: String in actor.animator.get_animation_list():
			if action != "RESET": actions.append(action)
		if "talk" not in actions: actions.append("talk")
		if "work" not in actions and "work_interact" in family.review_scope:
			actions.append("work")
		for action: String in actions:
			var source_clip := action if actor.animator.has_animation(action) else "idle"
			var seconds: float = actor.animator.get_animation(source_clip).length
			var walking := action in ["march","run"]
			actor.drive(1.45 if action=="march" else (3.6 if action=="run" else 0.0))
			var stride := actor.locomotion_stride(action) if walking else 0.0
			# sample_pose selects the full civilian gait for reviews. Use the
			# production live-speed solver explicitly for measured live contact.
			var sampler := func(phase: float) -> void:
				actor.sample_pose(action,phase)
				if walking and actor._motion.civilian:
					actor._motion.locomotion(action,phase,actor.speed/actor.body.scale.y)
				actor.position.z = -phase*stride if walking else 0.0
			var stance := (.53 if action=="march" else .32) if actor._motion.civilian else (.56 if action=="march" and path.contains("/meshy/") else (.58 if action=="march" else .40))
			var contact := {"gait":walking,"stance":stance}
			var clip := _sample(rig,sampler,action,seconds,action in LOOPS,action in MOTION_REQUIRED,skin,contact)
			clip["base_animation"] = source_clip
			_record_clip(measured,path,clip)
			var metrics: Dictionary = clip.surface_metrics.duplicate()
			var combat_scenario := "combat_fallback" if family.id=="legacy_people" else "attack_guard_reaction"
			var scenario := "idle_talk" if action in ["idle","talk"] else ("walk_run_stop" if walking else ("work_interact" if action in ["work","gather"] else combat_scenario))
			_observe(measured,path,scenario,int(clip.sample_count),bool(clip.finite),metrics)
			if not contact.is_empty():
				_observe(measured,path,"contact_and_weight",int(clip.sample_count),bool(clip.finite),metrics)
			if family.id=="meshy_people":
				_observe(measured,path,"skin_deformation",int(clip.sample_count),bool(clip.finite),{"skin_edge_violations":metrics.skin_edge_violations})
			if "military_equipment" in applicable and kit!=null and kit.skin!=null:
				# The skin fixture includes this real embedded skinned kit in
				# every pose, so its worst-case tearing bound is also observed.
				_observe(measured,path,"military_equipment",int(clip.sample_count),bool(clip.finite),{"skin_edge_violations":metrics.skin_edge_violations})
		if family.id=="hero":
			for action: String in Motion.TECHNIQUES:
				var duration: float = Motion.TIMING[action].z
				var sampler := func(phase: float) -> void:
					actor.position = Vector3(0,.9,0)
					actor.sample_combat(action,phase)
				var clip := _sample(rig,sampler,"unarmed:"+action,duration,false,true,skin,{"gait":false})
				_record_clip(measured,path,clip)
				_observe(measured,path,"attack_guard_reaction",int(clip.sample_count),bool(clip.finite),clip.surface_metrics)
		_runtime_transitions(actor,measured,path)
		var poses: Array = []
		actor.position = Vector3(0,.9,0)
		for action: String in ["idle","march","run","attack"]:
			for frame in range(61):
				actor.sample_pose(action,float(frame)/HZ)
				poses.append(_world_pose(rig))
		lod_poses[path] = {"poses":poses,"bones":rig.get_bone_count()}
		actor.free()
		print("MOTION_RUNTIME_SUBJECT ",path)
		_refresh_family(measured)
		_checkpoint()
	for path: String in lod_poses:
		var stem := path.get_basename()
		stem = stem.substr(0,stem.length()-2)
		var comparison := ""
		for other: String in lod_poses:
			if other != path and other.get_basename().begins_with(stem+"_"):
				comparison=other
				break
		if comparison.is_empty(): continue
		var metrics := {"max_transition_position_jump_m":0.0,"max_transition_rotation_jump_deg":0.0}
		var finite := int(lod_poses[path].bones)==int(lod_poses[comparison].bones)
		for frame in lod_poses[path].poses.size():
			_merge(metrics,_discontinuity(lod_poses[path].poses[frame],lod_poses[comparison].poses[frame]))
		_observe(measured,path,"lod_transition",lod_poses[path].poses.size(),finite,metrics)
	_refresh_family(measured)


func _refresh_family(measured: Dictionary) -> void:
	measured.sample_count=0
	measured.metrics={}
	for record: Dictionary in measured.scenario_samples:
		measured.sample_count+=int(record.sample_count)
		_merge(measured.metrics,record.metrics)


func _checkpoint(complete: bool=false) -> void:
	if _output_path.is_empty(): return
	var pending := _output_path+".partial"
	var handle := FileAccess.open(pending,FileAccess.WRITE)
	if handle==null:
		fatal.append("Cannot write motion measurement checkpoint")
		return
	handle.store_string(JSON.stringify({"schema_version":1,"source_fingerprint":_source_fingerprint,
		"sample_hz":60,"complete":complete,"assets":records,"family_metrics":family_metrics,"fatal":fatal},"  ")+"\n")
	handle.close()
	if DirAccess.rename_absolute(pending,_output_path)!=OK:
		fatal.append("Cannot promote motion measurement checkpoint")


func _run() -> void:
	var contract_path := OS.get_environment("IMPERATHEN_MOTION_CONTRACT")
	var report_path := OS.get_environment("IMPERATHEN_MOTION_REPORT")
	var fingerprint := OS.get_environment("IMPERATHEN_MOTION_SOURCE")
	if contract_path.is_empty() or report_path.is_empty() or fingerprint.is_empty():
		push_error("Motion measurement needs explicit source-bound output paths")
		quit(2)
		return
	_output_path=report_path
	_source_fingerprint=fingerprint
	var contract: Variant = JSON.parse_string(FileAccess.get_file_as_string(contract_path))
	if typeof(contract)!=TYPE_DICTIONARY:
		push_error("Missing motion contract")
		quit(2)
		return
	var only_subject := OS.get_environment("IMPERATHEN_MOTION_ONLY_SUBJECT")
	for source_family: Dictionary in contract.families:
		var family: Dictionary = source_family.duplicate(true)
		if not only_subject.is_empty():
			if only_subject not in family.resources: continue
			family.resources = [only_subject]
		if family.status=="active" and family.profile in ["human","animal"]:
			for path: String in family.resources:
				_raw_asset(path)
		if family.id in ["hero","frontier_people","legacy_people","meshy_people","regional_workers"]:
			await _person_family(family)
		_checkpoint()
	var equipment: Dictionary = await EquipmentMeasurement.new().measure(self,contract,only_subject)
	family_metrics.merge(equipment)
	_checkpoint()
	if only_subject.is_empty():
		var world: Dictionary = await WorldMeasurement.new().measure(self,contract)
		family_metrics.merge(world)
	_checkpoint(only_subject.is_empty())
	print("MOTION_MEASURED ",records.size()," real assets; ",fatal.size()," fatal fixture errors; numerical acceptance is separate")
	quit(0 if fatal.is_empty() else 1)
