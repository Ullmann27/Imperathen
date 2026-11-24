extends SceneTree
## Actual imported rigs: contact, anatomically directed poses, LOD and grip.

const Person := preload("res://scripts/visuals/village_person.gd")
const Motion := preload("res://scripts/visuals/character_motion.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player", "italia", 12)
	actor._check_lod = 10000.0
	var skeleton: Skeleton3D = actor.body.find_children("*", "Skeleton3D", true, false)[0]
	actor.sample_pose("idle", 0.25)
	for side: String in ["L", "R"]:
		var wrist := _point(skeleton, "Hand_" + side)
		var elbow := _point(skeleton, "Forearm_" + side)
		var shoulder := _point(skeleton, "Arm_" + side)
		_check(absf(wrist.z - elbow.z) < 0.055, "Idle wrist stays beside the body: " + side)
		_check(shoulder.y - wrist.y > 0.35, "Relaxed arms extend down from the shoulder: " + side)
	var grip: MeshInstance3D = actor.body.find_child("HeroBody", true, false)
	var grip_index := grip.find_blend_shape_by_name("HandGrip")
	_check(grip_index >= 0 and is_equal_approx(grip.get_blend_shape_value(grip_index), 0.18), "Standing hands use a relaxed partial grip")
	var max_stance_error := 0.0
	for frame in 120:
		var phase := float(frame) / 120.0
		actor.sample_pose("march", phase)
		for side: String in ["L", "R"]:
			var offset := 0.0 if side == "R" else 0.5
			if fposmod(phase + offset, 1.0) < 0.53:
				var foot := skeleton.find_bone("Foot_" + side)
				max_stance_error = maxf(max_stance_error, absf(skeleton.get_bone_global_pose(foot).origin.y - skeleton.get_bone_global_rest(foot).origin.y))
	_check(max_stance_error < 0.008, "Planted walking feet retain their measured rest sole height; max error " + str(max_stance_error))
	# The planted foot recedes exactly as far as actual translation advances.
	for metres_per_second: float in [0.45, 1.0, 1.45]:
		var step := 0.005
		actor._motion.locomotion("march", 0.18, metres_per_second)
		var first := _point(skeleton, "Foot_R")
		var phase_delta: float = step * metres_per_second / actor._motion.gait_stride("march", metres_per_second)
		actor._motion.locomotion("march", 0.18 + phase_delta, metres_per_second)
		var second := _point(skeleton, "Foot_R")
		_check(absf((first.z - second.z) - metres_per_second * step) < 0.0004, "Contact displacement matches analog speed " + str(metres_per_second))
	actor.sample_pose("march", 0.03)
	var front_foot := _point(skeleton, "Foot_R").z
	var back_hand := _point(skeleton, "Hand_R").z - _point(skeleton, "Arm_R").z
	_check(front_foot > 0.15 and back_hand < -0.05, "Right hand counters the forward right leg")
	var signatures := {}
	for technique: String in Motion.TECHNIQUES:
		actor.sample_combat(technique, 0.42)
		var signature := ""
		for bone in skeleton.get_bone_count():
			var position := skeleton.get_bone_global_pose(bone).origin
			_check(position.is_finite(), technique + " finite bone " + skeleton.get_bone_name(bone))
			var parent := skeleton.get_bone_parent(bone)
			if parent >= 0:
				var length := position.distance_to(skeleton.get_bone_global_pose(parent).origin)
				_check(absf(length - skeleton.get_bone_rest(bone).origin.length()) < 0.0001, technique + " preserves limb length " + skeleton.get_bone_name(bone))
			if skeleton.get_bone_name(bone) in ["Hand_L", "Hand_R", "Foot_L", "Foot_R", "Head"]:
				signature += str(position.snapped(Vector3.ONE * 0.005))
		_check(not signatures.has(signature), technique + " has a distinct measured pose")
		signatures[signature] = true
		_check(grip.get_blend_shape_value(grip_index) > 0.98, technique + " closes the authored hand morph")
		if technique.ends_with("kick"):
			_check(_point(skeleton, "Foot_R").z > 0.45, technique + " extends toward the authoritative forward target")
		else:
			_check(absf(_point(skeleton, "Foot_L").y - skeleton.get_bone_global_rest(skeleton.find_bone("Foot_L")).origin.y) < 0.008, technique + " support foot stays planted")
	actor.sample_combat("uppercut_left", 0.42)
	var reference := _point(skeleton, "Hand_L")
	for level in 4:
		actor._reload(level)
		skeleton = actor.body.find_children("*", "Skeleton3D", true, false)[0]
		_check(_point(skeleton, "Hand_L").distance_to(reference) < 0.0001, "Combat contact pose survives LOD " + str(level))
		var body: MeshInstance3D = actor.body.find_child("HeroBody", true, false)
		_check(body.get_blend_shape_value(body.find_blend_shape_by_name("HandGrip")) > 0.98, "Grip survives LOD " + str(level))
	actor.cancel_action()
	_check(actor._combat_id.is_empty() and actor.clip == "idle", "Pause/interruption removes the controlled combat pose")
	actor.configure("player", "italia", 22)
	actor.sample_pose("train", 0.40)
	_check(not actor.body.find_child("PracticeBlade", true, false).visible, "Age alone never grants a weapon")
	actor.set_equipment(true)
	actor.sample_pose("train", 0.40)
	_check(actor.body.find_child("PracticeBlade", true, false).visible, "Explicit equipment controls the existing blade")
	# Real adult blade authorization and borrowed shield are separate from
	# animation selection. The visual solver must never grant either item.
	var attack_poses := {}
	for style: String in Motion.ARMED_ATTACKS:
		_check(actor.sample_armed_pose(style,.56),style+" can animate the explicitly equipped adult")
		skeleton = actor.body.find_children("*","Skeleton3D",true,false)[0]
		var wrist := _point(skeleton,"Hand_R")
		attack_poses[str(wrist.snapped(Vector3.ONE*.01))] = true
		for bone in skeleton.get_bone_count():
			var parent := skeleton.get_bone_parent(bone)
			var pos := skeleton.get_bone_global_pose(bone).origin
			_check(pos.is_finite(),style+" has finite skeletal coordinates")
			if parent >= 0:
				_check(absf(pos.distance_to(skeleton.get_bone_global_pose(parent).origin)-skeleton.get_bone_rest(bone).origin.length()) < .0002,style+" keeps segment lengths")
	_check(attack_poses.size() == Motion.ARMED_ATTACKS.size(),"All armed moves produce distinct hand paths")
	actor.set_equipment(false)
	_check(not actor.sample_armed_pose("thrust",.56),"An unequipped actor cannot select a blade pose")
	actor.set_loaned_gear(true)
	var guard_poses := {}
	for style: String in Motion.SHIELD_GUARDS:
		_check(actor.sample_armed_pose(style,.5),style+" uses the actual attached shield")
		var shield_hand := _point(skeleton,"Hand_L")
		guard_poses[str(shield_hand.snapped(Vector3.ONE*.01))] = true
		_check(shield_hand.z > .08,style+" keeps the shield hand in front")
	_check(guard_poses.size() == Motion.SHIELD_GUARDS.size(),"Five shield directions have distinct positions")
	actor.sample_armed_pose("guard_high",.5)
	var shield_before := _point(skeleton,"Hand_L")
	actor._reload(3)
	skeleton = actor.body.find_children("*","Skeleton3D",true,false)[0]
	_check(actor._armed_style == "guard_high" and _point(skeleton,"Hand_L").distance_to(shield_before)<.001,"Shield pose survives LOD replacement")
	actor.set_loaned_gear(false)
	_check(not actor.sample_armed_pose("guard_front",.5),"An absent shield cannot be visually equipped by a pose")
	actor.cancel_action()
	actor.drive(1.45)
	actor._process(0.10)
	_check(actor.clip == "march", "Normal movement selects walking")
	actor.drive(3.8)
	actor._process(0.20)
	_check(actor.clip == "run", "Fast movement selects running")
	actor.drive(0.0)
	actor._process(0.20)
	_check(actor.clip == "idle", "Zero actual displacement settles into idle")
	actor.free()
	print("CHARACTER_MOTION_TEST ", checks, " checks; ", failures.size(), " failed; stance_error_m=", max_stance_error)
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _point(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
