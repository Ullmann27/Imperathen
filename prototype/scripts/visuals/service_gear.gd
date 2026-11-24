extends RefCounted
## Project-authored GLB service equipment. Both source sockets must resolve
## before attaching anything. The renderer cannot grant an inventory item.

const ITEMS := [
	{"path":"res://assets/weapons/gladius_lod0.glb","socket":"SOCKET_RIGHT_HAND","bone":"Hand_R","name":"ServiceGladius"},
	{"path":"res://assets/weapons/scutum_lod0.glb","socket":"SOCKET_LEFT_HAND","bone":"Hand_L","name":"ServiceScutum"}
]
static var _scenes: Dictionary = {}


static func attach(model: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var rigs := model.find_children("*","Skeleton3D",true,false)
	if rigs.is_empty():
		return result
	var rig := rigs[0] as Skeleton3D
	var prepared: Array[Node3D] = []
	var sockets: Array[Transform3D] = []
	for item: Dictionary in ITEMS:
		var path: String = item.path
		if rig.find_bone(item.bone) < 0 or not ResourceLoader.exists(path,"PackedScene"):
			_release(prepared)
			return result
		if not _scenes.has(path):
			_scenes[path] = load(path) as PackedScene
		if not _scenes[path] is PackedScene:
			_release(prepared)
			return result
		var prop := (_scenes[path] as PackedScene).instantiate() as Node3D
		if prop == null:
			_release(prepared)
			return result
		var marker := prop.find_child(item.socket,true,false) as Node3D
		if marker == null:
			prop.free()
			_release(prepared)
			return result
		var relative := marker.transform
		var parent := marker.get_parent() as Node3D
		while parent != null and parent != prop:
			relative = parent.transform * relative
			parent = parent.get_parent() as Node3D
		relative = prop.transform * relative
		prepared.append(prop)
		sockets.append(relative)
	for index in prepared.size():
		var item: Dictionary = ITEMS[index]
		var bone := rig.find_bone(item.bone)
		var attachment := BoneAttachment3D.new()
		attachment.name = item.name
		attachment.bone_name = item.bone
		attachment.override_pose = false
		rig.add_child(attachment)
		var grip := Node3D.new()
		grip.name = "Grip"
		var rest := rig.get_bone_global_rest(bone).basis.orthonormalized()
		grip.basis = rest.inverse()
		attachment.add_child(grip)
		var align := Node3D.new()
		align.name = "SocketAlignment"
		align.transform = sockets[index].affine_inverse()
		grip.add_child(align)
		align.add_child(prepared[index])
		attachment.visible = false
		attachment.set_meta("model_path", item.path)
		result.append(attachment)
	return result


static func _release(nodes: Array[Node3D]) -> void:
	for node in nodes:
		node.free()
