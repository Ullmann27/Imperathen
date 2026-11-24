extends SceneTree
const Person := preload("res://scripts/visuals/village_person.gd")
var checks := 0
var failed := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(label)


func run() -> void:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player","italia",12)
	actor.set_service_gear(true)
	check(actor._service_nodes.is_empty(),"Child has no service equipment even if a presentation caller requests it")
	actor.configure("player","italia",18)
	actor.set_service_gear(true)
	check(actor._service_nodes.size()==2,"Adult receives both real imported models")
	if actor._service_nodes.size()==2:
		check(actor.sample_service_combat("thrust",.56),"Adult sword uses authoritative sampled pose")
		var rig := actor._motion.skeleton
		var before := rig.get_bone_pose_rotation(rig.find_bone("Hand_R"))
		actor.drive(0.0)
		actor._process(.1)
		check(actor._service_external and is_equal_approx(actor.phase,.56),"Render clock cannot advance authority-owned sword pose")
		check(before.angle_to(rig.get_bone_pose_rotation(rig.find_bone("Hand_R")))<.001,"Skeletal pose stays on domain sample")
		await process_frame
		for node in actor._service_nodes:
			var attachment := node as BoneAttachment3D
			check(attachment!=null and attachment.visible,"Actual service prop is visible during combat")
			var socket_name := "SOCKET_RIGHT_HAND" if attachment.bone_name=="Hand_R" else "SOCKET_LEFT_HAND"
			var socket := attachment.find_child(socket_name,true,false) as Node3D
			check(socket!=null and socket.global_position.distance_to(attachment.global_position)<.002,"Authored grip socket coincides with animated hand")
		actor._reload(3)
		check(actor._service_nodes.size()==2 and actor._service_external and is_equal_approx(actor.phase,.56),"LOD switch retains both weapons and sampled phase")
		actor.cancel_action()
		check(not actor._service_external and actor.clip=="idle","Cancel releases action and sheathes props")
		actor.cue("block","guard_high")
		check(actor._armed_style=="guard_high","Service shield selects upper guard pose")
	actor.set_service_gear(false)
	check(not actor.sample_service_combat("thrust",.56),"No sword pose after removing service authority")
	actor.free()
	print("SERVICE_GEAR_PASS" if failed==0 else "SERVICE_GEAR_FAIL"," ",checks," checks, ",failed," failed")
	quit(0 if failed==0 else 1)
