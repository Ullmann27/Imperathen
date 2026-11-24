extends RefCounted
## Observe actual production attachments and actual posed meshes at 60 Hz.
const Person = preload("res://scripts/visuals/village_person.gd")
const Motion = preload("res://scripts/visuals/character_motion.gd")
const SkinMeasurement = preload("res://tests/motion_skin_measurement.gd")
const Clearance = preload("res://tests/motion_mesh_clearance.gd")
const MeshyEquipment = preload("res://scripts/visuals/meshy_equipment.gd")
const HZ := 60.0


func _family() -> Dictionary:
	return {"subjects":[],"sample_hz":60,"sample_count":0,"scenarios":[],"metrics":{},
		"scenario_samples":[],"errors":[],"clearance_method":"Actual triangle intersections and signed closed-mesh containment; conservative AABB separation upper bound on detected overlap; only actual hand grip radius 0.08 m excluded", "clearance_observations":[]}


func _observe(family: Dictionary, subject: String, scenario: String, finite: bool, metrics: Dictionary) -> void:
	var record: Dictionary = {}
	for item: Dictionary in family.scenario_samples:
		if item.subject==subject and item.scenario==scenario:
			record=item
			break
	if record.is_empty():
		record={"subject":subject,"scenario":scenario,"sample_hz":60,"sample_count":0,"finite":true,"metrics":{}}
		family.scenario_samples.append(record)
	if subject not in family.subjects: family.subjects.append(subject)
	if scenario not in family.scenarios: family.scenarios.append(scenario)
	record.sample_count+=1
	record.finite=bool(record.finite) and finite
	for key: String in metrics: record.metrics[key]=maxf(float(record.metrics.get(key,0.0)),float(metrics[key]))


func _attachments(actor: Person) -> Array[BoneAttachment3D]:
	var result: Array[BoneAttachment3D] = []
	for node: Node in actor.body.find_children("*","BoneAttachment3D",true,false):
		if node.has_meta("model_path") and node.is_visible_in_tree(): result.append(node as BoneAttachment3D)
	return result


func _socket(attachment: BoneAttachment3D, rig: Skeleton3D) -> Dictionary:
	var bone := rig.find_bone(attachment.bone_name)
	if bone<0: return {"finite":false,"error":"Missing actual hand bone"}
	var expected := rig.global_transform*rig.get_bone_global_pose(bone)
	var actual := attachment.global_transform
	var point_error := actual.origin.distance_to(expected.origin)
	var socket_name := "SOCKET_RIGHT_HAND" if attachment.bone_name=="Hand_R" else "SOCKET_LEFT_HAND"
	var marker := attachment.find_child(socket_name,true,false) as Node3D
	if marker==null: return {"finite":false,"error":"Missing actual model grip marker"}
	# A BoneAttachment follows its bone even when a child prop is displaced
	# or rotated. Compare the actual exported marker against the declared
	# equipment grip frame, not only that automatically-following wrapper.
	var rest:=rig.get_bone_global_rest(bone).basis
	var grip_basis:=rest.orthonormalized().inverse()
	var grip_offset:=Vector3.ZERO
	if attachment.get_meta("meshy_equipment",false):
		var definition:=MeshyEquipment.definition_for(str(attachment.get_meta("asset_id","")))
		if definition.is_empty() or definition.bone!=attachment.bone_name or definition.socket!=socket_name:
			return {"finite":false,"error":"No declared grip frame for this Meshy model"}
		grip_basis=rest.inverse()*Basis(Vector3.UP,float(definition.yaw))
		grip_offset=rest.inverse()*Vector3(definition.offset)
	var expected_marker:=expected*Transform3D(grip_basis,grip_offset)
	var marker_transform:=marker.global_transform
	point_error=maxf(point_error,marker_transform.origin.distance_to(expected_marker.origin))
	var wrapper_angle:=actual.basis.orthonormalized().get_rotation_quaternion().angle_to(expected.basis.orthonormalized().get_rotation_quaternion())
	var marker_angle:=marker_transform.basis.orthonormalized().get_rotation_quaternion().angle_to(expected_marker.basis.orthonormalized().get_rotation_quaternion())
	return {"finite":actual.is_finite() and expected.is_finite() and marker_transform.is_finite() and expected_marker.is_finite(),
		"max_socket_drift_m":point_error,
		"max_socket_orientation_error_deg":rad_to_deg(maxf(wrapper_angle,marker_angle)),
		"grip_position":marker_transform.origin}


func _record_actor(tree: SceneTree, actor: Person, family: Dictionary, identity: String, only_subject: String) -> void:
	for level in 4:
		actor._reload(level)
		actor._check_lod=100000.0
		var rig: Skeleton3D=actor._motion.skeleton
		var skin:=SkinMeasurement.new()
		skin.bind(actor.body)
		for error: String in skin.errors: family.errors.append(identity+" LOD"+str(level)+": "+error)
		var actions: Array[String]=[]
		if identity=="service":
			for action: String in Motion.ARMED_ATTACKS+Motion.SHIELD_GUARDS: actions.append(action)
		elif identity=="unit_germanic_axe_fighter":
			for action: String in ["cut_inward","cut_outward","overhead","turn_cut"]+Motion.SHIELD_GUARDS: actions.append(action)
		else:
			for action: String in ["idle","march","run","talk","work","hit"]: actions.append(action)
		for action: String in actions:
			var armed := action in Motion.ARMED_ATTACKS or action in Motion.SHIELD_GUARDS
			if identity=="service": actor.sample_service_combat(action,0.0)
			elif armed: actor.sample_armed_pose(action,0.0)
			else: actor.sample_pose(action,0.0)
			var seconds := actor.animator.current_animation_length
			var count:=maxi(1,ceili(seconds*HZ))
			for frame in range(count+1):
				var phase:=float(frame)/float(count)
				if identity=="service": actor.sample_service_combat(action,phase)
				elif armed: actor.sample_armed_pose(action,phase)
				else: actor.sample_pose(action,phase)
				rig.force_update_all_bone_transforms()
				await tree.process_frame
				var actual_skin: Dictionary=skin.sample()
				var body:=Clearance.geometry(skin.world_surfaces())
				for attachment: BoneAttachment3D in _attachments(actor):
					var subject:=str(attachment.get_meta("model_path")).trim_prefix("res://")
					if not only_subject.is_empty() and only_subject!=subject: continue
					var socket:=_socket(attachment,rig)
					var valid:=bool(socket.finite) and bool(actual_skin.finite)
					if not socket.finite:
						family.errors.append(subject+": "+str(socket.get("error","Socket has no finite production hand binding")))
						continue
					var socket_metrics: Dictionary=socket.duplicate()
					socket_metrics.erase("finite")
					socket_metrics.erase("grip_position")
					_observe(family,subject,"grip_socket",valid,socket_metrics)
					_observe(family,subject,"attack_guard_reaction",valid,socket_metrics)
					# The same 8 cm region follows the actual authored physical
					# grip. The wrist root is not the palm/shaft contact point.
					var grip: Array[Dictionary]=[{"position":socket.grip_position,"radius":.08}]
					var prop:=Clearance.geometry(Clearance.rigid_surfaces(attachment))
					var observed:=Clearance.compare(body,prop,grip)
					if bool(observed.finite):
						_observe(family,subject,"clearance",valid,{"max_unintended_penetration_m":float(observed.upper_bound_m)})
					else:
						_observe(family,subject,"clearance",false,{})
						var error:=subject+": "+str(observed.get("error","Invalid mesh clearance"))
						if error not in family.errors: family.errors.append(error)
					if (not bool(observed.finite) or bool(observed.get("intersection",false))) and family.clearance_observations.size()<24:
						family.clearance_observations.append({"subject":subject,"body_lod":level,"action":action,"phase":phase,"observed":observed})
			print("MOTION_EQUIPMENT_CLIP ",identity," LOD",level," ",action)
		# Every LOD change is made through the real production reload, at 61
		# phases. No comparison of two independently invented socket formulas.
		for frame in range(61):
			var phase:=float(frame)/HZ
			if identity=="service": actor.sample_service_combat("thrust",phase)
			elif identity=="unit_germanic_axe_fighter": actor.sample_armed_pose("guard_front",phase)
			else: actor.sample_pose("march",phase)
			rig.force_update_all_bone_transforms()
			await tree.process_frame
			var before: Dictionary={}
			for attachment: BoneAttachment3D in _attachments(actor):
				before[attachment.bone_name]={"transform":attachment.global_transform,"subject":str(attachment.get_meta("model_path")).trim_prefix("res://")}
			actor._reload((level+1)%4)
			rig=actor._motion.skeleton
			rig.force_update_all_bone_transforms()
			await tree.process_frame
			for attachment: BoneAttachment3D in _attachments(actor):
				if not before.has(attachment.bone_name): continue
				var prior: Dictionary=before[attachment.bone_name]
				var subject: String=prior.subject
				if not only_subject.is_empty() and subject!=only_subject: continue
				var difference:=attachment.global_position.distance_to((prior.transform as Transform3D).origin)
				_observe(family,subject,"lod_transition",attachment.global_transform.is_finite(),{"max_transition_position_jump_m":difference})
			actor._reload(level)
			rig=actor._motion.skeleton
			actor._check_lod=100000.0


func measure(tree: SceneTree, contract: Dictionary, only_subject: String="") -> Dictionary:
	var result: Dictionary={}
	for definition: Dictionary in contract.families:
		if definition.id not in ["service_gear","meshy_gear"]: continue
		if not only_subject.is_empty() and only_subject not in definition.resources: continue
		var family:=_family()
		result[definition.id]=family
		var identities: Array[String]=["service"] if definition.id=="service_gear" else ["unit_roman_signifer","unit_germanic_axe_fighter"]
		for identity: String in identities:
			var actor:=Person.new()
			tree.root.add_child(actor)
			actor.set_process(false)
			actor.position=Vector3(0,.9,0)
			if identity=="service":
				actor.configure("player","italia",18)
				actor.set_service_gear(true)
			else:
				actor.configure_resident("germania" if "germanic" in identity else "italia",32,"spearman" if "germanic" in identity else "legionary")
				if not actor.configure_meshy(identity): family.errors.append("Rejected actual Meshy identity "+identity)
			actor._check_lod=100000.0
			await _record_actor(tree,actor,family,identity,only_subject)
			actor.free()
		for record: Dictionary in family.scenario_samples:
			family.sample_count+=int(record.sample_count)
			for key: String in record.metrics:
				family.metrics[key]=maxf(float(family.metrics.get(key,0.0)),float(record.metrics[key]))
	return result
