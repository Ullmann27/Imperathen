extends SceneTree
const Person = preload("res://scripts/visuals/village_person.gd")
const SkinSampler = preload("res://tests/motion_skin_measurement.gd")
const Clearance = preload("res://tests/motion_mesh_clearance.gd")
const Equipment = preload("res://tests/motion_equipment_measurement.gd")

func _fresh(surfaces: Array) -> Dictionary:
	var saved: Dictionary = Clearance._topology_cache
	Clearance._topology_cache = {}
	var result := Clearance.geometry(surfaces)
	Clearance._topology_cache = saved
	return result

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.position = Vector3(0,.9,0)
	actor.configure("player","italia",18)
	actor.set_service_gear(true)
	actor._reload(0)
	actor._check_lod = 100000.0
	var rig: Skeleton3D = actor._motion.skeleton
	var skin := SkinSampler.new()
	skin.bind(actor.body)
	var sampler := Equipment.new()
	Clearance._topology_cache.clear()
	for phase: float in [0.0,4.0/49.0,8.0/49.0,0.5,1.0]:
		actor.sample_service_combat("cut_inward",phase)
		rig.force_update_all_bone_transforms()
		await process_frame
		var actual: Dictionary = skin.sample()
		var surfaces := skin.world_surfaces()
		var body := Clearance.geometry(surfaces)
		var body_fresh := _fresh(surfaces)
		var report := {"phase":phase,"body_closed":body.get("closed"),"body_fresh_closed":body_fresh.get("closed"),"body_errors":skin.errors,"skin_finite":actual.get("finite"),"props":[],"components":[]}
		for attachment: BoneAttachment3D in sampler._attachments(actor):
			var prop_surfaces := Clearance.rigid_surfaces(attachment)
			var prop := Clearance.geometry(prop_surfaces)
			var prop_fresh := _fresh(prop_surfaces)
			var socket: Dictionary = sampler._socket(attachment,rig)
			var grips: Array[Dictionary] = [{"position":socket.grip_position,"radius":.08}]
			report.props.append({"asset":attachment.get_meta("model_path"),"closed":prop.get("closed"),"fresh_closed":prop_fresh.get("closed"),"cached_result":Clearance.compare(body,prop,grips),"fresh_result":Clearance.compare(body_fresh,prop_fresh,grips)})
		if phase == 4.0/49.0:
			var grouped := {}
			for i in surfaces.size():
				var mesh: MeshInstance3D = skin.surfaces[i].mesh
				var key := str(mesh.get_instance_id())
				if not grouped.has(key): grouped[key]={"node":str(mesh.get_path()),"surfaces":[]}
				grouped[key].surfaces.append(surfaces[i])
			for group: Dictionary in grouped.values():
				var geometry := _fresh(group.surfaces)
				report.components.append({"node":group.node,"closed":geometry.get("closed"),"error":geometry.get("error"),"surfaces":group.surfaces.size()})
		print("GEAR_POSE_DIAGNOSTIC ",JSON.stringify(report))
	actor.free()
	quit(0)
