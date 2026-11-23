extends SceneTree
const Person = preload("res://scripts/visuals/village_person.gd")
const Motion = preload("res://scripts/visuals/natural_motion.gd")
class TrackedResident extends Person:
	var loaded_paths: Array[String] = []
	func _instantiate(path: String) -> Node3D:
		loaded_paths.append(path)
		return super._instantiate(path)

var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func rig(person: Person) -> Skeleton3D:
	return person.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

func joint(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin

func clip_fingerprint(animation: Animation) -> PackedByteArray:
	var tracks := []
	for track in animation.get_track_count():
		var values := []
		for key in animation.track_get_key_count(track):
			values.append([animation.track_get_key_time(track,key),animation.track_get_key_value(track,key)])
		tracks.append([animation.track_get_type(track),animation.track_get_path(track),values])
	return var_to_bytes([animation.length,tracks])

func run() -> void:
	var original := load("res://assets/characters/hero_quality_0.glb").instantiate() as Node3D
	var original_player := original.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var original_idle := original_player.get_animation("idle")
	var fingerprint := clip_fingerprint(original_idle)
	var person := Person.new()
	root.add_child(person)
	person.set_process(false)
	person.configure("player", "italia", 12)
	check(person.animator.get_animation("idle") != original_idle, "Corrected clips do not mutate the imported shared animation")
	for action: String in ["idle", "march", "run"]:
		var old_clip := original_player.get_animation(action)
		var new_clip := person.animator.get_animation(action)
		var preserved := old_clip.length == new_clip.length and old_clip.get_track_count() == new_clip.get_track_count()
		for track in old_clip.get_track_count():
			var path := old_clip.track_get_path(track)
			if old_clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(path.get_subname(0)) in Motion.ARM_BONES: continue
			for key in old_clip.track_get_key_count(track):
				preserved = preserved and old_clip.track_get_key_time(track, key) == new_clip.track_get_key_time(track, key)
				preserved = preserved and old_clip.track_get_key_value(track, key) == new_clip.track_get_key_value(track, key)
		check(preserved, action+" keeps all original leg, pelvis, spine and head tracks and their timing")
	for origin: String in ["italia", "germania", "han", "wa", "vistula"]:
		person.configure("player", origin, 12)
		for level in [0, 3]:
			person._reload(level)
			var skeleton := rig(person)
			person.sample_pose("idle", .25)
			for side: String in ["L", "R"]:
				var shoulder := joint(skeleton, "Arm_"+side)
				var elbow := joint(skeleton, "Forearm_"+side)
				var wrist := joint(skeleton, "Hand_"+side)
				var length := shoulder.distance_to(elbow)+elbow.distance_to(wrist)
				check(wrist.y < shoulder.y-length*.85 and absf(wrist.z-shoulder.z)<length*.2, "%s LOD%d idle %s wrist hangs beside the torso" % [origin, level, side])
			for phase: float in [0, .5]:
				person.sample_pose("march", phase)
				var left := joint(skeleton,"Hand_L").z-joint(skeleton,"Arm_L").z
				var right := joint(skeleton,"Hand_R").z-joint(skeleton,"Arm_R").z
				check(left*right<-.002 and (left>0)==(phase==0), "%s LOD%d real arm swing alternates around the torso" % [origin, level])
	person.configure("player", "italia", 12)
	person._reload(0)
	var skeleton := rig(person)
	person.sample_pose("march", 0)
	var spine_before := skeleton.get_bone_pose_rotation(skeleton.find_bone("Spine"))
	var head_before := skeleton.get_bone_pose_rotation(skeleton.find_bone("Head"))
	person.sample_pose("march", .25)
	check(spine_before.angle_to(skeleton.get_bone_pose_rotation(skeleton.find_bone("Spine")))>.01, "Walking retains actual spine counter-motion")
	check(head_before.angle_to(skeleton.get_bone_pose_rotation(skeleton.find_bone("Head")))>.01, "Walking retains actual head counter-motion")
	var signatures := {}
	var foot_heights := {}
	for action: String in Motion.DURATIONS:
		check(person.cue_unarmed(action), action+" is an available actual animation cue")
		check(is_equal_approx(person.animator.current_animation_length, float(Motion.DURATIONS[action])), action+" duration matches the gameplay recovery contract")
		person.sample_pose(action, .4)
		var pose := []
		for bone: String in ["Hand_L", "Hand_R", "Foot_R", "Head"]:
			pose.append(joint(skeleton,bone))
		signatures[var_to_str(pose)] = true
		foot_heights[action] = joint(skeleton,"Foot_R").y
		check(not person.body.find_child("PracticeBlade",true,false).visible, action+" remains unarmed")
		person._reload(3)
		check(person.clip==action and is_equal_approx(person.phase,.4) and person.animator.current_animation==action, action+" keeps its impact pose across LOD changes")
		person._reload(0)
		skeleton = rig(person)
	check(signatures.size()==Motion.DURATIONS.size(), "All ten techniques have distinct actual skeletal impact poses")
	check(float(foot_heights.high_kick)>float(foot_heights.front_kick)+.20, "High kick raises the actual foot above the front-kick height")
	person.cue_unarmed("jab_left")
	person._process(.8)
	check(person.clip=="idle", "Completed technique returns to normal locomotion")
	var previous := person.clip
	check(not person.cue_unarmed("invalid") and person.clip==previous, "Unknown actions do not replace a valid pose")
	var neighbour := Person.new()
	root.add_child(neighbour)
	neighbour.set_process(false)
	neighbour.configure("player", "italia", 12)
	check(person.animator.get_animation("idle")==neighbour.animator.get_animation("idle"), "Live actors share generated clips rather than rebaking per instance")
	check(fingerprint==clip_fingerprint(original_idle), "Original source idle animation remains unchanged")
	person.set_loaned_gear(true)
	var helmet := person.body.find_child("LoanedPracticeHelmet", true, false) as BoneAttachment3D
	var shield := person.body.find_child("LoanedPracticeShield", true, false) as BoneAttachment3D
	check(helmet!=null and shield!=null and helmet.bone_name=="Head" and shield.bone_name=="Hand_L", "Borrowed helmet and practice shield follow actual named bones")
	check(helmet.visible and shield.visible and not helmet.override_pose and not shield.override_pose, "Borrowed props do not override the actor's pose")
	var props := person.body.find_children("LoanedPractice*", "BoneAttachment3D", true, false).size()
	person.set_loaned_gear(true)
	check(person.body.find_children("LoanedPractice*", "BoneAttachment3D", true, false).size()==props, "Repeated state sync does not duplicate borrowed props")
	person.sample_pose("jab_right", .4)
	person._reload(3)
	helmet = person.body.find_child("LoanedPracticeHelmet", true, false) as BoneAttachment3D
	shield = person.body.find_child("LoanedPracticeShield", true, false) as BoneAttachment3D
	check(helmet!=null and shield!=null and helmet.visible and shield.visible and person.clip=="jab_right", "LOD reload retains the loaned props and active motion")
	person.set_loaned_gear(false)
	check(not helmet.visible and not shield.visible, "Returning loaned gear removes it from the actual scene")
	check(not person.body.find_child("PracticeBlade",true,false).visible, "Loaned practice gear does not expose a blade")
	var resident := TrackedResident.new()
	root.add_child(resident)
	resident.set_process(false)
	resident.profile = "low"
	resident.position = Vector3(0, 0, 12)
	var camera := Camera3D.new()
	root.add_child(camera)
	resident.configure_resident("italia", 42, "civilian_woman", 5, camera)
	check(resident.loaded_paths == ["res://assets/characters/frontier_civilian_woman_2.glb"] and resident.detail == 2, "Resident construction loads only the correct appearance and camera/profile LOD")
	check(resident.identity == "resident_civilian_woman_5" and resident.age == 42 and resident.profile == "low", "Atomic resident construction retains its complete identity and profile")
	resident.configure_resident("italia", 42, "civilian_woman", 5, camera)
	check(resident.loaded_paths.size() == 1, "Repeated resident configuration does not load another body")
	resident.sample_pose("march", .25)
	camera.position = resident.position + Vector3(0, 0, 1)
	resident.refresh_lod(camera)
	check(resident.detail == 0 and resident.clip == "march" and is_equal_approx(resident.phase, .25), "A nearby resident still upgrades normally without losing animation phase")
	resident.free()
	camera.free()
	neighbour.free()
	person.free()
	original.free()
	print("NATURAL_MOTION_TEST ", checks, " checks, ", failures, " failed")
	quit(0 if failures==0 else 1)
