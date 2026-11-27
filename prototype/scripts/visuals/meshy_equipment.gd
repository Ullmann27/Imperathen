extends RefCounted
## Existing Meshy props fitted to live hand bones. Presentation only: this
## helper never grants inventory, attack permissions, damage or quest progress.

const PATH := "res://assets/meshy/equipment/%s_%d.glb"
const LOADOUTS := {
	# Civilian apprenticeships must not grant military equipment.
	"unit_legacy_blacksmith": [],
	"unit_germanic_axe_fighter":[
		{"asset":"weap_germanic_hand_axe", "bone":"Hand_R", "socket":"SOCKET_RIGHT_HAND", "offset":Vector3(0.02,-0.055,0.095), "yaw":PI/2},
		{"asset":"gear_germanic_round_shield", "bone":"Hand_L", "socket":"SOCKET_LEFT_HAND", "offset":Vector3(-0.02,-0.055,0.095), "yaw":0.0}],
	"unit_roman_signifer":[
		{"asset":"gear_roman_signum", "bone":"Hand_R", "socket":"SOCKET_RIGHT_HAND", "offset":Vector3(0.02,-0.055,0.095), "yaw":0.0}]
}
static var _scenes: Dictionary = {}


static func definition_for(asset_id: String) -> Dictionary:
	for items: Array in LOADOUTS.values():
		for item: Dictionary in items:
			if item.asset == asset_id:
				return item.duplicate()
	return {}


static func has_complete_set(identity: String) -> bool:
	if not LOADOUTS.has(identity):
		return false
	for item: Dictionary in LOADOUTS[identity]:
		for tier in 2:
			if not ResourceLoader.exists(PATH % [item.asset, tier], "PackedScene"):
				return false
	return true


static func attach(model: Node3D, identity: String, detail: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if model == null or not LOADOUTS.has(identity):
		return result
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return result
	var skeleton := skeletons[0] as Skeleton3D
	var tier := 0 if detail <= 1 else 1
	# Resolve the whole loadout before attaching anything. Partial equipment is
	# not a successful replacement for the original armed frontier character.
	var prepared: Array[Node3D] = []
	for item: Dictionary in LOADOUTS[identity]:
		if skeleton.find_bone(item.bone) < 0:
			_release(prepared)
			return result
		var path := PATH % [item.asset, tier]
		if not _scenes.has(path):
			if not ResourceLoader.exists(path, "PackedScene"):
				_release(prepared)
				return result
			_scenes[path] = load(path) as PackedScene
		if not _scenes[path] is PackedScene:
			_release(prepared)
			return result
		var prop := (_scenes[path] as PackedScene).instantiate() as Node3D
		if prop == null:
			_release(prepared)
			return result
		var socket := prop.find_child(str(item.socket), true, false) as Node3D
		if socket == null:
			prop.free()
			_release(prepared)
			return result
		prepared.append(prop)
	# Reload normally frees the previous Model and all its attachments. This
	# guard also makes an explicit second attach idempotent on one live rig.
	for child: Node in skeleton.get_children():
		if child.get_meta("meshy_equipment", false):
			skeleton.remove_child(child)
			child.free()
	for index in prepared.size():
		var item: Dictionary = LOADOUTS[identity][index]
		var attachment := BoneAttachment3D.new()
		attachment.name = "MeshyEquipment_" + str(item.asset)
		attachment.bone_name = str(item.bone)
		attachment.override_pose = false
		attachment.set_meta("meshy_equipment", true)
		attachment.set_meta("asset_id", str(item.asset))
		attachment.set_meta("model_path", PATH % [item.asset, tier])
		skeleton.add_child(attachment)
		var grip := Node3D.new()
		grip.name = "Grip"
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone(item.bone))
		var inverse := rest.basis.inverse()
		grip.basis = inverse * Basis(Vector3.UP, float(item.yaw))
		grip.position = inverse * Vector3(item.offset)
		attachment.add_child(grip)
		var prop := prepared[index]
		prop.name = "Prop"
		grip.add_child(prop)
		result.append(attachment)
	return result


static func _release(nodes: Array[Node3D]) -> void:
	for node: Node3D in nodes:
		node.free()
