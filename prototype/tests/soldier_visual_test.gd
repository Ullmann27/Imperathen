extends SceneTree
## Run after import with --headless --script res://tests/soldier_visual_test.gd.

const Actor = preload("res://scripts/visuals/soldier_visual.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Ranks = preload("res://scripts/visuals/far_ranks.gd")
const CLIPS := ["idle", "march", "run", "attack", "shoot", "block", "wall", "testudo", "hit", "retreat", "death"]

var failures := 0
var checked := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checked += 1
	if not value:
		failures += 1
		printerr("FAIL ", message)

func _run() -> void:
	_test_animation_isolation()
	for role: String in Actor.ROLES:
		var actor := Actor.new()
		actor.configure(role, 1)
		root.add_child(actor)
		for level in [0, 1]:
			actor.set_detail(level)
			var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var attrs := mesh.mesh.surface_get_arrays(0)
			_check(skeleton.get_bone_count() == (17 if role == "archer" else 15) and mesh.skin != null, role + " skeleton and skin")
			_check(attrs[Mesh.ARRAY_WEIGHTS].size() == 4 * attrs[Mesh.ARRAY_VERTEX].size(), role + " skin weights")
			_check(mesh.mesh.get_surface_count() == 1 and mesh.material_override != null, role + " atlas and variant")
			for clip: String in CLIPS:
				_check(actor.player.has_animation(clip), role + " clip " + clip)
				actor.play_state(clip, .41)
				actor.player.advance(0)
				_check(actor.player.current_animation == clip, role + " playback " + clip)
				var bone_name := "Spine"
				match clip:
					"march", "run", "retreat": bone_name = "Thigh_R"
					"block", "testudo", "wall", "shoot": bone_name = "Arm_L"
					"attack": bone_name = "Arm_R"
					"death": bone_name = "Pelvis"
				var index := skeleton.find_bone(bone_name)
				var rotation := skeleton.get_bone_pose_rotation(index)
				var rest := skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
				# Imported bones retain their glTF rest rotation in Godot.
				if clip == "idle":
					actor.player.seek(.37, true)
					actor.player.advance(0)
					rotation = skeleton.get_bone_pose_rotation(index)
				_check(absf(rotation.dot(rest)) < .999999, role + " actual bone pose " + clip)
			actor.play_state("march", .3)
			var limb := skeleton.find_bone("Hand_R")
			var before := skeleton.get_bone_global_pose(limb)
			actor.player.advance(.19)
			var after := skeleton.get_bone_global_pose(limb)
			_check(before.origin.distance_to(after.origin) > .008, role + " animated hand attachment")
		actor.set_detail(2)
		var far := Actor.far_mesh(role)
		_check(far == Actor.far_mesh(role) and far.get_surface_count() == 1, role + " shared instanced mesh")
		_check(actor.player == null and actor.find_children("*","Skeleton3D",true,false).is_empty(), role + " static far")
		actor.set_detail(0)
		_check(actor.state == "march" and actor.player.is_playing(), role + " LOD roundtrip")
		actor.free()
	await _test_batches()
	print("Soldier visuals: ", checked, " checks, ", failures, " failed")
	quit(1 if failures else 0)


func _test_animation_isolation() -> void:
	for level in [0, 1]:
		var source := load("res://assets/characters/frontier_legionary_%d.glb" % level) as PackedScene
		var template := source.instantiate()
		var original := template.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var original_loops := {}
		for clip: String in original.get_animation_list():
			original_loops[clip] = original.get_animation(clip).loop_mode
		var person := Person.new()
		var neighbour := Person.new()
		for resident: Person in [person, neighbour]:
			root.add_child(resident)
			resident.detail = level
			resident.configure_resident("italia", 32, "legionary")
			resident.set_process(false)
			resident._check_lod = 10000.0
		var soldier := Actor.new()
		soldier.detail = level
		root.add_child(soldier)
		soldier.set_process(false)
		soldier.play_state("block", .7)
		person.cue("block")
		var soldier_block := soldier.player.get_animation("block")
		_check(soldier_block.loop_mode == Animation.LOOP_LINEAR, "Person block leaves soldier loop independent at LOD " + str(level))
		soldier.player.advance(soldier_block.length * 1.5)
		_check(soldier.player.is_playing() and soldier.player.current_animation == "block", "Soldier keeps blocking beyond one cycle at LOD " + str(level))
		soldier.present("block", .2, .1)
		_check(person.animator.get_animation("block").loop_mode == Animation.LOOP_NONE, "Soldier block leaves person one-shot independent at LOD " + str(level))
		person.animator.advance(person.animator.current_animation_length * 1.5)
		_check(not person.animator.is_playing(), "Person one-shot still ends while soldier loops at LOD " + str(level))
		# An unsupported one-shot uses idle as its visual fallback. It must not
		# stop the shared idle animation of a different, live resident.
		neighbour.reset_motion()
		person.cue("unavailable_one_shot")
		var idle_length := neighbour.animator.current_animation_length
		neighbour._process(idle_length * 2.5)
		_check(neighbour.clip == "idle" and neighbour.animator.is_playing(), "Fallback cue leaves neighbour idle running at LOD " + str(level))
		person.reset_motion()
		_check(person.animator.get_animation("idle") == neighbour.animator.get_animation("idle"), "Returning from one-shot shares the same resident idle resource at LOD " + str(level))
		soldier.present("idle", .2, .1)
		_check(person.animator.get_animation("idle") == soldier.player.get_animation("idle"), "Both drivers share the same immutable idle variant at LOD " + str(level))
		_check(person.animator.get_animation_list() == original.get_animation_list() and soldier.player.get_animation_list() == original.get_animation_list(), "Private playback preserves every imported clip at LOD " + str(level))
		var unchanged := true
		for clip: String in original_loops:
			unchanged = unchanged and original.get_animation(clip).loop_mode == original_loops[clip]
		_check(unchanged, "Playback leaves the imported source animation modes unchanged at LOD " + str(level))
		person.free()
		neighbour.free()
		soldier.free()
		template.free()


func _test_batches() -> void:
	var ranks := Ranks.new()
	root.add_child(ranks)
	var groups := {}
	for i in Actor.ROLES.size():
		var transforms: Array[Transform3D] = []
		for j in 16:
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(i*1.2-1.8, 0, -j*1.0)))
		groups[Actor.ROLES[i]] = transforms
	ranks.sync(groups)
	_check(ranks.get_child_count() == 4, "four roles, four persistent batches")
	for batch: MultiMeshInstance3D in ranks.get_children():
		var group := batch.multimesh
		_check(group.visible_instance_count == 16 and group.instance_count == 16, "visible instances")
		_check(group.mesh.get_surface_count() == 1, "one surface per batch")
		ranks.sync({})
		_check(not batch.visible and group.visible_instance_count == 0, "missing role hidden")
		ranks.sync(groups)
		_check(group == batch.multimesh and batch.visible, "persistent batch and storage")
	if "--render-stats" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.position = Vector3(0, 5, 10)
		camera.look_at(Vector3(0, 0, -3))
		ranks.sync({})
		await _drawn()
		var empty := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		ranks.sync(groups)
		await _drawn()
		var populated := root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		print("Visible-pass draw calls for 64 distant soldiers: ", populated, " (empty viewport ", empty, ")")
		_check(populated - empty == 4, "four actual GPU draw submissions")
		camera.free()
	ranks.free()

func _drawn() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
