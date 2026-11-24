extends SceneTree
## Authoring-only rotation retargeter: actual GLB animations -> original hero rig.
## Preserves target rest offsets; omits locomotion root translation. Outputs a
## review library, not an automatically enabled runtime asset.

const TARGET := "res://assets/characters/hero_quality_0.glb"
const REQUIRED := ["Pelvis","Spine","Head","Arm_L","Forearm_L","Hand_L","Arm_R","Forearm_R","Hand_R","Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]
const NEXT := {"Pelvis":"Spine","Spine":"Head","Arm_L":"Forearm_L","Arm_R":"Forearm_R","Forearm_L":"Hand_L","Forearm_R":"Hand_R","Thigh_L":"Shin_L","Thigh_R":"Shin_R","Shin_L":"Foot_L","Shin_R":"Foot_R"}
const ALIASES := {
	"Pelvis":["hips","pelvis","hip"],
	"Spine":["spine","spine01","spine1","chest","upperchest","spine02","spine2","spine03"],
	"Head":["head"],
	"Arm_L":["upperarml","leftupperarm","leftarm","arml","lupperarm","larm"],
	"Forearm_L":["lowerarml","leftlowerarm","leftforearm","forearml","lforearm","elbowleft"],
	"Hand_L":["handl","lefthand","lhand","wristl"],
	"Arm_R":["upperarmr","rightupperarm","rightarm","armr","rupperarm","rarm"],
	"Forearm_R":["lowerarmr","rightlowerarm","rightforearm","forearmr","rforearm","elbowright"],
	"Hand_R":["handr","righthand","rhand","wristr"],
	"Thigh_L":["thighl","leftupleg","leftupperleg","leftthigh","lthigh","upperlegl"],
	"Shin_L":["calfl","shinl","leftleg","leftlowerleg","leftshin","lowerlegl","lcalf"],
	"Foot_L":["footl","leftfoot","lfoot","anklel"],
	"Thigh_R":["thighr","rightupleg","rightupperleg","rightthigh","rthigh","upperlegr"],
	"Shin_R":["calfr","shinr","rightleg","rightlowerleg","rightshin","lowerlegr","rcalf"],
	"Foot_R":["footr","rightfoot","rfoot","ankler"]
}


func _initialize() -> void:
	_run.call_deferred()


func _key(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-z0-9]")
	var clean := regex.sub(value.to_lower(),"",true)
	for prefix: String in ["mixamorig","armature","bip001","bip01","bip","def","rig"]:
		if clean.begins_with(prefix):
			clean = clean.substr(prefix.length())
	return clean


func _bone_map(rig: Skeleton3D) -> Dictionary:
	var names := {}
	for i in rig.get_bone_count():
		var key := _key(rig.get_bone_name(i))
		if not names.has(key):
			names[key] = i
	var mapping := {}
	for role: String in REQUIRED:
		for alias: String in ALIASES[role]:
			if names.has(alias) and not mapping.values().has(names[alias]):
				mapping[role] = names[alias]
				break
	return mapping


func _body_frame(rig: Skeleton3D, mapping: Dictionary) -> Basis:
	var left := rig.get_bone_global_rest(mapping.Thigh_L).origin-rig.get_bone_global_rest(mapping.Thigh_R).origin
	var up := rig.get_bone_global_rest(mapping.Head).origin-rig.get_bone_global_rest(mapping.Pelvis).origin
	if left.length()<.00001 or up.length()<.00001:
		return Basis()
	left = left.normalized()
	up = (up-left*up.dot(left)).normalized()
	var forward := left.cross(up).normalized()
	return Basis(left,up,forward).orthonormalized()


func _retarget(source: Skeleton3D, target: Skeleton3D, mapping: Dictionary, ids: Dictionary, alignment: Basis, out: Animation, tracks: Dictionary, at: float) -> bool:
	source.force_update_all_bone_transforms()
	var desired := {}
	for bone in target.get_bone_count():
		var rest := target.get_bone_global_rest(bone)
		var parent := target.get_bone_parent(bone)
		var parent_basis: Basis = desired.get(parent,Basis())
		var local := target.get_bone_rest(bone).basis.orthonormalized()
		var rotation := parent_basis*local
		var role := target.get_bone_name(bone)
		if mapping.has(role):
			var src := source.get_bone_global_pose(mapping[role])
			var src_rest := source.get_bone_global_rest(mapping[role])
			var delta := alignment*src.basis.orthonormalized()*src_rest.basis.orthonormalized().inverse()*alignment.inverse()
			rotation = (delta*rest.basis).orthonormalized()
			if NEXT.has(role):
				var next: String = NEXT[role]
				var from_dir := target.get_bone_global_rest(ids[next]).origin-rest.origin
				var to_dir := alignment*(source.get_bone_global_pose(mapping[next]).origin-src.origin)
				if from_dir.length()>.00001 and to_dir.length()>.00001:
					# Keep source swing direction in the aligned body frame.
					# Correct the transferred roll without changing target length.
					var moved := delta*from_dir
					rotation = (Basis(Quaternion(moved.normalized(),to_dir.normalized()))*rotation).orthonormalized()
		desired[bone] = rotation
		var q := (parent_basis.inverse()*rotation).get_rotation_quaternion().normalized()
		if not q.is_finite():
			return false
		if tracks.has(bone):
			out.rotation_track_insert_key(tracks[bone],at,q)
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2:
		push_error("Expected source-directory and output-directory")
		quit(2)
		return
	var source_dir := args[0]
	var output_dir := args[1]
	DirAccess.make_dir_recursive_absolute(output_dir)
	var packed := load(TARGET) as PackedScene
	var target := packed.instantiate() as Node3D
	root.add_child(target)
	var target_rigs := target.find_children("*","Skeleton3D",true,false)
	if target_rigs.size()!=1:
		push_error("Unexpected hero skeleton count")
		quit(2)
		return
	var rig := target_rigs[0] as Skeleton3D
	var ids := {}
	for role: String in REQUIRED:
		var bone := rig.find_bone(role)
		if bone<0:
			push_error("Missing actual hero bone: "+role)
			quit(2)
			return
		ids[role] = bone
	for existing: Node in target.find_children("*","AnimationPlayer",true,false):
		(existing as AnimationPlayer).stop()
		(existing as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var player := AnimationPlayer.new()
	player.name = "CC0ReviewPlayer"
	target.add_child(player)
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	player.add_animation_library("cc0",library)
	var records: Array[Dictionary] = []
	var accepted := 0
	var rejected := 0
	var failures: Array[String] = []
	var files := DirAccess.get_files_at(source_dir)
	files.sort()
	for file: String in files:
		if not file.to_lower().ends_with(".glb"):
			continue
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var error := doc.append_from_file(source_dir.path_join(file),state)
		if error != OK:
			records.append({"file":file,"reason":"import failed","code":error})
			rejected+=1
			continue
		var scene := doc.generate_scene(state)
		if scene==null:
			rejected+=1
			continue
		root.add_child(scene)
		var rigs := scene.find_children("*","Skeleton3D",true,false)
		var players := scene.find_children("*","AnimationPlayer",true,false)
		if rigs.size()!=1 or players.size()!=1:
			records.append({"file":file,"reason":"not a single animated skeleton"})
			rejected+=1
			scene.free()
			continue
		var source := rigs[0] as Skeleton3D
		var source_player := players[0] as AnimationPlayer
		source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var mapping := _bone_map(source)
		if mapping.size()!=REQUIRED.size():
			var missing: Array[String] = []
			for role: String in REQUIRED:
				if not mapping.has(role):
					missing.append(role)
			records.append({"file":file,"reason":"incomplete source bone map","missing":missing})
			rejected+=1
			scene.free()
			continue
		var alignment := _body_frame(rig,ids)*_body_frame(source,mapping).inverse()
		for clip: String in source_player.get_animation_list():
			if clip=="RESET":
				continue
			var src_anim := source_player.get_animation(clip)
			if src_anim.length<=.01 or src_anim.length>30.0:
				rejected+=1
				continue
			var anim := Animation.new()
			anim.length=src_anim.length
			anim.step=1.0/30.0
			var tracks := {}
			for role: String in REQUIRED:
				var bone: int = ids[role]
				var track := anim.add_track(Animation.TYPE_ROTATION_3D)
				anim.track_set_path(track,NodePath(str(target.get_path_to(rig))+":"+role))
				tracks[bone]=track
			source_player.play(clip)
			var frames := ceili(src_anim.length*30.0)
			var finite := true
			for frame in range(frames+1):
				var at := minf(float(frame)/30.0,src_anim.length)
				source_player.seek(at,true)
				source_player.advance(0)
				if not _retarget(source,rig,mapping,ids,alignment,anim,tracks,at):
					finite=false
					break
			var key := _key(file.get_basename()+"_"+clip)
			if not finite or key.is_empty() or library.has_animation(key):
				rejected+=1
				continue
			library.add_animation(key,anim)
			player.play("cc0/"+key)
			var valid := true
			for sample: float in [0.0,.25,.5,.75,.999]:
				player.seek(sample*anim.length,true)
				player.advance(0)
				rig.force_update_all_bone_transforms()
				for bone in rig.get_bone_count():
					var pose := rig.get_bone_global_pose(bone)
					if not pose.is_finite():
						valid=false
						break
					var parent := rig.get_bone_parent(bone)
					if parent>=0 and absf(pose.origin.distance_to(rig.get_bone_global_pose(parent).origin)-rig.get_bone_rest(bone).origin.length())>.005:
						valid=false
						break
			player.stop()
			if not valid:
				library.remove_animation(key)
				failures.append(file+":"+clip+" invalid target segments")
				rejected+=1
				continue
			accepted+=1
			records.append({"file":file,"clip":clip,"retargeted":key,"seconds":anim.length,"sample_frames":frames+1,"rotation_tracks":tracks.size()})
		scene.free()
	if accepted < 36 or rejected != 0:
		failures.append("Incomplete retarget: expected 35 motion files plus the mannequin reference")
	for key_file: String in ["Idle_relaxed.glb","Idle_talking.glb","Walk_forwards.glb","Sword_slash.glb","Block_with_the_sword.glb"]:
		var found := false
		for record: Dictionary in records:
			if record.get("file","")==key_file and record.has("retargeted"):
				found=true
		if not found:
			failures.append("Missing core source motion: "+key_file)
	var report := {"source":"CC0 KinemIQ v1.0","target":TARGET,"accepted_clips":accepted,"rejected":rejected,"records":records,"failures":failures,"runtime_approved":false,"root_motion":false,"visual_skin_gate":"not run"}
	var handle := FileAccess.open(output_dir.path_join("retarget-review.json"),FileAccess.WRITE)
	handle.store_string(JSON.stringify(report,"  ")+"\n")
	handle.close()
	if accepted>0:
		var saved := ResourceSaver.save(library,output_dir.path_join("hero_cc0_review.tres"))
		if saved!=OK:
			failures.append("ResourceSaver error "+str(saved))
	print("CC0_RETARGET_REVIEW ",accepted," clips, ",rejected," rejected, ",failures.size()," failures")
	target.free()
	quit(0 if accepted>0 and failures.is_empty() else 1)
