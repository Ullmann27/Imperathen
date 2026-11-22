extends SceneTree
## Run after import with --headless --script res://tests/soldier_visual_test.gd.

const Actor = preload("res://scripts/visuals/soldier_visual.gd")
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
