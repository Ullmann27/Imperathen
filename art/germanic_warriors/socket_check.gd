extends SceneTree
## Engine check: every baked Gear_* mesh of every figure matches the
## grip-centred library GLB placed through its SOCKET_* frame, and the 15
## bones/11 clips import with the company names.
##
## godot --headless --path prototype --script "$PWD/art/germanic_warriors/socket_check.gd"

const BONES := ["Pelvis","Spine","Head","Arm_L","Forearm_L","Hand_L","Arm_R","Forearm_R","Hand_R","Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]
const CLIPS := ["idle","march","run","attack","shoot","block","wall","testudo","hit","retreat","death"]


var _elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > 600.0:
		push_error("GERMANIC_SOCKET_CHECK_TIMEOUT")
		quit(3)
	return false


func _gltf(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _aabb(node: Node3D, relative_to: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		var box := relative_to.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _run() -> void:
	var art := ProjectSettings.globalize_path("res://").path_join("../art/germanic_warriors").simplify_path()
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(art.path_join("registry.json")))
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(art.path_join("build_report.json")))
	var failures: Array[String] = []
	var checks := 0
	var worst := 0.0
	for figure: Dictionary in registry.figures:
		var info: Dictionary = report.figures[figure.id]
		for lod in 4:
			var model := _gltf(art.path_join("export/figures/germanic_%s_%d.glb" % [figure.id, lod]))
			if model == null:
				failures.append("load %s %d" % [figure.id, lod])
				continue
			root.add_child(model)
			var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			for bone: String in BONES:
				checks += 1
				if skeleton.find_bone(bone) < 0:
					failures.append("%s_%d missing bone %s" % [figure.id, lod, bone])
			if skeleton.get_bone_count() != BONES.size():
				failures.append("%s_%d has %d bones" % [figure.id, lod, skeleton.get_bone_count()])
			var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			for clip: String in CLIPS:
				checks += 1
				if player == null or not player.has_animation(clip):
					failures.append("%s_%d missing clip %s" % [figure.id, lod, clip])
			if lod == 0:
				for item_id: String in figure.loadout.values():
					if not info.get("attachments", {}).has(item_id):
						failures.append("no attachment record " + item_id)
						continue
					var attach: Dictionary = info.attachments[item_id]
					var basis := Basis(Vector3(attach.basis_columns[0][0], attach.basis_columns[0][1], attach.basis_columns[0][2]),
						Vector3(attach.basis_columns[1][0], attach.basis_columns[1][1], attach.basis_columns[1][2]),
						Vector3(attach.basis_columns[2][0], attach.basis_columns[2][1], attach.basis_columns[2][2]))
					var rest := Transform3D(basis, Vector3(attach.origin[0], attach.origin[1], attach.origin[2]))
					var baked := model.find_child("Gear_" + item_id, true, false) as Node3D
					var library := _gltf(art.path_join("export/equipment/%s_0.glb" % item_id))
					if baked == null or library == null:
						failures.append("missing baked or library " + item_id)
						continue
					var socket := library.find_child("SOCKET_*", true, false) as Node3D
					# Runtime path: BoneAttachment3D on the bone, item at
					# bone_rest^-1 * rest so the socket sits on the grip frame.
					var holder := BoneAttachment3D.new()
					holder.bone_name = attach.bone
					skeleton.add_child(holder)
					var bone_rest := skeleton.get_bone_global_rest(skeleton.find_bone(attach.bone))
					library.transform = bone_rest.affine_inverse() * rest
					holder.add_child(library)
					skeleton.force_update_all_bone_transforms()
					await process_frame
					await process_frame
					# BoneAttachment3D follows the bone pose once the skeleton has
					# updated; compare against the explicit bone pose as well.
					var expected := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(attach.bone))
					var follow_error := (holder.global_transform.origin - expected.origin).length()
					if follow_error > 0.001:
						failures.append("%s %s BoneAttachment3D not on bone (%.4f m)" % [figure.id, item_id, follow_error])
					var a := _aabb(baked, model)
					var b := _aabb(library, model)
					var error := maxf((a.position - b.position).length(), (a.end - b.end).length())
					worst = maxf(worst, error)
					checks += 1
					if socket == null or error > 0.004:
						failures.append("%s %s socket error %.4f m" % [figure.id, item_id, error])
					holder.queue_free()
			model.queue_free()
			await process_frame
	print("GERMANIC_SOCKET_CHECK checks=", checks, " worst_socket_error_m=", snappedf(worst, 0.0001), " failures=", failures)
	quit(0 if failures.is_empty() else 1)
