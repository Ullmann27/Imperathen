extends RefCounted
## Original baked animation alternative from the childhood branch.
## Production VillagePerson uses CharacterMotion and never installs this second
## library: locomotion and sampled combat must have one skeletal pose owner.

const DURATIONS := {"jab_left":.62, "jab_right":.68, "hook_left":.82, "hook_right":.82,
	"uppercut_left":.90, "uppercut_right":.90, "headbutt":.76,
	"front_kick":1.05, "side_kick":1.20, "high_kick":1.30}
const ARM_BONES := ["Arm_L", "Arm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R"]
static var _libraries: Dictionary = {}

static func install(model: Node3D, player: AnimationPlayer, model_path: String, relax_arms: bool = true) -> bool:
	if not player or not player.has_animation_library(""):
		return false
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return false
	var skeleton := skeletons[0] as Skeleton3D
	var rig := _rig(skeleton)
	for bone: String in ARM_BONES:
		if not rig.has(bone): return false
	var cache_key := model_path+"/"+str(relax_arms)
	var library: AnimationLibrary
	if _libraries.has(cache_key):
		library = (_libraries[cache_key] as WeakRef).get_ref() as AnimationLibrary
	if not library:
		var source := player.get_animation_library("")
		library = AnimationLibrary.new()
		for name: StringName in source.get_animation_list():
			var animation: Animation = source.get_animation(name)
			if relax_arms and name in ["idle", "march", "run"]:
				animation = _locomotion(animation, str(name), rig)
			library.add_animation(name, animation)
		var idle: Animation = source.get_animation("idle")
		for action: String in DURATIONS:
			library.add_animation(action, _practice_clip(idle, action, rig))
		_libraries[cache_key] = weakref(library)
	player.remove_animation_library("")
	player.add_animation_library("", library)
	return true

static func _rig(skeleton: Skeleton3D) -> Dictionary:
	var result := {}
	for index in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(index)
		result[skeleton.get_bone_name(index)] = {"rest":skeleton.get_bone_rest(index),
			"global":skeleton.get_bone_global_rest(index),
			"parent":skeleton.get_bone_global_rest(parent) if parent >= 0 else Transform3D.IDENTITY}
	return result

static func _bone(path: NodePath) -> String:
	return str(path.get_subname(0)) if path.get_subname_count() > 0 else ""

static func _locomotion(original: Animation, action: String, rig: Dictionary) -> Animation:
	var animation := original.duplicate() as Animation
	var poses := {}
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var bone := _bone(animation.track_get_path(track))
		if bone not in ARM_BONES: continue
		for key in animation.track_get_key_count(track):
			var at := animation.track_get_key_time(track, key) / animation.length
			if not poses.has(at): poses[at] = _arms(rig, action, at)
			animation.track_set_key_value(track, key, poses[at][bone])
	return animation

static func _aligned(rest: Basis, direction: Vector3) -> Basis:
	return Basis(Quaternion(rest.y.normalized(), direction.normalized())) * rest

static func _arms(rig: Dictionary, action: String, phase: float) -> Dictionary:
	var result := {}
	var impact := smoothstep(0.0, .4, phase) * (1.0-smoothstep(.4, 1.0, phase))
	var guard := sin(PI*phase) if DURATIONS.has(action) else 0.0
	for side: String in ["L", "R"]:
		var sign_value := 1.0 if side == "L" else -1.0
		var swing := 0.025*sin(TAU*phase)
		var elbow := deg_to_rad(7.0)
		if action in ["march", "run"]:
			swing = deg_to_rad(23.0 if action == "march" else 39.0) * cos(TAU*phase) * sign_value
			elbow = deg_to_rad(11.0 if action == "march" else 65.0)
		var upper := Vector3(sign_value*.14, -cos(swing), sin(swing))
		var lower := Vector3(sign_value*.04, -cos(swing+elbow), sin(swing+elbow))
		if DURATIONS.has(action):
			upper = upper.lerp(Vector3(sign_value*.24, -.85, .48), guard*.70)
			lower = lower.lerp(Vector3(-sign_value*.12, .70, .70), guard*.92)
			var lead := (side == "L") == action.ends_with("_left")
			if lead and action.begins_with("jab_"):
				upper = upper.lerp(Vector3(sign_value*.10, .02, 1), impact)
				lower = lower.lerp(Vector3(-sign_value*.04, -.02, 1), impact)
			elif lead and action.begins_with("hook_"):
				upper = upper.lerp(Vector3(sign_value*.68, -.12, .72), impact)
				lower = lower.lerp(Vector3(-sign_value*.85, .08, .53), impact)
			elif lead and action.begins_with("uppercut_"):
				upper = upper.lerp(Vector3(sign_value*.15, -.55, .82), impact)
				lower = lower.lerp(Vector3(-sign_value*.04, .82, .57), impact)
		var arm: Dictionary = rig["Arm_"+side]
		var forearm: Dictionary = rig["Forearm_"+side]
		var upper_basis := _aligned((arm.global as Transform3D).basis, upper)
		var lower_basis := _aligned((forearm.global as Transform3D).basis, lower)
		result["Arm_"+side] = ((arm.parent as Transform3D).basis.inverse()*upper_basis).get_rotation_quaternion()
		result["Forearm_"+side] = (upper_basis.inverse()*lower_basis).get_rotation_quaternion()
		result["Hand_"+side] = (rig["Hand_"+side].rest as Transform3D).basis.get_rotation_quaternion()
	return result

static func _practice_pose(rig: Dictionary, action: String, phase: float) -> Dictionary:
	var result := {}
	for bone: String in rig:
		result[bone] = (rig[bone].rest as Transform3D).basis.get_rotation_quaternion()
	result.merge(_arms(rig, action, phase), true)
	var impact := smoothstep(0.0, .4, phase) * (1.0-smoothstep(.4, 1.0, phase))
	var sign_value := 1.0 if action.ends_with("_left") else -1.0
	var lean := 4.0
	var turn := sign_value*8.0
	if action.begins_with("hook_"): turn = sign_value*24.0
	if action.begins_with("uppercut_"): lean = -5.0; turn = sign_value*13.0
	if action == "headbutt": lean = 10.0; turn = 0.0
	if action.ends_with("kick"):
		lean = -9.0
		turn = -35.0 if action == "side_kick" else -8.0
		var thigh_direction := Vector3(.06, -.12, 1.0)
		var shin_direction := Vector3(.03, -.08, 1.0)
		if action == "side_kick": thigh_direction = Vector3(.35, -.05, .94); shin_direction = Vector3(-.12, -.06, .99)
		if action == "high_kick": thigh_direction = Vector3(.08, .48, .87); shin_direction = Vector3(.03, .48, .88)
		var thigh: Dictionary = rig["Thigh_R"]
		var shin: Dictionary = rig["Shin_R"]
		var thigh_rest := (thigh.global as Transform3D).basis
		var shin_rest := (shin.global as Transform3D).basis
		var thigh_basis := _aligned(thigh_rest, thigh_rest.y.lerp(thigh_direction, impact))
		# A flexed chamber before extension; the supporting leg remains planted.
		var chamber := sin(PI*clampf(phase/.4, 0.0, 1.0))*.55 if phase < .4 else 0.0
		var shin_target := shin_rest.y.lerp(shin_direction, impact).lerp(Vector3(0, -.55, -.83), chamber)
		var shin_basis := _aligned(shin_rest, shin_target)
		result.Thigh_R = ((thigh.parent as Transform3D).basis.inverse()*thigh_basis).get_rotation_quaternion()
		result.Shin_R = (thigh_basis.inverse()*shin_basis).get_rotation_quaternion()
		var foot_rest := (rig.Foot_R.global as Transform3D).basis
		result.Foot_R = (shin_basis.inverse()*foot_rest).get_rotation_quaternion()
	for bone: String in ["Spine", "Head"]:
		var item: Dictionary = rig[bone]
		var angle := lean if bone == "Spine" else (22.0 if action == "headbutt" else -lean*.35)
		var yaw := turn if bone == "Spine" else -turn*.35
		var basis := Basis.from_euler(Vector3(deg_to_rad(angle), deg_to_rad(yaw), 0)*impact) * (item.global as Transform3D).basis
		result[bone] = ((item.parent as Transform3D).basis.inverse()*basis).get_rotation_quaternion()
	return result

static func _practice_clip(template: Animation, action: String, rig: Dictionary) -> Animation:
	var result := Animation.new()
	result.length = float(DURATIONS[action])
	result.loop_mode = Animation.LOOP_NONE
	var fractions: Array[float] = [.4]
	for index in 17: fractions.append(float(index)/16.0)
	fractions.sort()
	var poses := {}
	for fraction: float in fractions: poses[fraction] = _practice_pose(rig, action, fraction)
	for track in template.get_track_count():
		var type := template.track_get_type(track)
		var bone := _bone(template.track_get_path(track))
		if not rig.has(bone): continue
		if type != Animation.TYPE_ROTATION_3D and not (bone == "Pelvis" and type == Animation.TYPE_POSITION_3D): continue
		var destination := result.add_track(type)
		result.track_set_path(destination, template.track_get_path(track))
		for fraction: float in fractions:
			var value: Variant = poses[fraction][bone] if type == Animation.TYPE_ROTATION_3D else (rig[bone].rest as Transform3D).origin
			result.track_insert_key(destination, fraction*result.length, value)
	return result
