extends SceneTree
const Person = preload("res://scripts/visuals/village_person.gd")
const Gestures = preload("res://scripts/visuals/cc0_gestures.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	var library := Gestures.library()
	if library == null:
		push_error("Missing generated CC0 library")
		quit(1)
		return
	check(library.get_animation_list().size()==36,"35 motion clips plus shared reference")
	for name: StringName in library.get_animation_list():
		var clip := library.get_animation(name)
		check(clip.get_track_count()==15,"All real target rotation tracks: "+str(name))
		for track in clip.get_track_count():
			check(clip.track_get_type(track)==Animation.TYPE_ROTATION_3D,"No root translation or scale")
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player","italia",12)
	for level: int in [0,1,2,3]:
		actor._reload(level)
		check(actor._motion.external_gestures,"Hero family enabled after LOD reload")
		var rig := actor._motion.skeleton
		var head := rig.find_bone("Head")
		var spine := rig.find_bone("Spine")
		var foot_l := rig.find_bone("Foot_L")
		var foot_r := rig.find_bone("Foot_R")
		for action: String in ["idle","talk"]:
			var changed := false
			for phase: float in [0.0,.125,.25,.375,.5,.625,.75,.875]:
				actor._motion.external_gestures = false
				actor.sample_pose(action,phase)
				var head_base := rig.get_bone_global_pose(head).basis.get_rotation_quaternion()
				var spine_base := rig.get_bone_global_pose(spine).basis.get_rotation_quaternion()
				var left := rig.get_bone_global_pose(foot_l).origin
				var right := rig.get_bone_global_pose(foot_r).origin
				actor._motion.external_gestures = true
				actor.sample_pose(action,phase)
				var head_diff := head_base.angle_to(rig.get_bone_global_pose(head).basis.get_rotation_quaternion())
				var spine_diff := spine_base.angle_to(rig.get_bone_global_pose(spine).basis.get_rotation_quaternion())
				changed = changed or maxf(head_diff,spine_diff)>.0005
				check(is_finite(head_diff) and is_finite(spine_diff) and maxf(head_diff,spine_diff)<=Gestures.MAX_ANGLE+.002,"Bounded external gesture")
				check(left.distance_to(rig.get_bone_global_pose(foot_l).origin)<.0001 and right.distance_to(rig.get_bone_global_pose(foot_r).origin)<.0001,"No external foot movement")
				for i in rig.get_bone_count():
					var parent := rig.get_bone_parent(i)
					if parent>=0:
						check(absf(rig.get_bone_global_pose(i).origin.distance_to(rig.get_bone_global_pose(parent).origin)-rig.get_bone_rest(i).origin.length())<.005,"Preserved segment length")
			check(changed,"Actual imported gesture affects "+action+" LOD"+str(level))
		actor._motion.external_gestures = false
		actor.sample_pose("march",.375)
		var before := rig.get_bone_global_pose(head)
		actor._motion.external_gestures = true
		actor.sample_pose("march",.375)
		check(before.is_equal_approx(rig.get_bone_global_pose(head)),"Existing walking untouched")
	actor.configure("player","germania",12)
	check(not actor._motion.external_gestures,"Other model family never receives unapproved tracks")
	actor.free()
	print("CC0_GESTURES_RESULT ",checks," checks, ",failures," failed")
	if failures==0:
		print("CC0_GESTURES_PASS")
	quit(0 if failures==0 else 1)
