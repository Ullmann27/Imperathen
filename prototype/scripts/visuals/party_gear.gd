extends RefCounted
## Draw the equipment owned by this person on the current model, including after a LOD swap.

const Art = preload("res://scripts/world/village_art.gd")
const BONES := {"walking_staff":"Hand_R", "leather_belt":"Pelvis", "wool_cloak":"Spine", "linen_tunic":"Spine", "bronze_brooch":"Spine"}
static var garments: Dictionary = {}


static func sync(figure: Node3D, equipment: Dictionary) -> void:
	if not is_instance_valid(figure):
		return
	var model := figure.get_node_or_null("Model") as Node3D
	if model == null:
		return
	if figure.get_meta("party_equipment", {}) != equipment:
		figure.set_meta("party_equipment", equipment.duplicate(true))
	if model.get_meta("displayed_party_gear", {}) == equipment:
		return
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return
	var skeleton := rigs[0] as Skeleton3D
	for child in skeleton.get_children():
		if child.has_meta("party_gear_item"):
			skeleton.remove_child(child)
			child.free()
	for value in equipment.values():
		var item := str(value.get("item_id", "")) if value is Dictionary else str(value)
		if not BONES.has(item):
			continue
		var bone := str(BONES[item])
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var socket := BoneAttachment3D.new()
		socket.name = "Party_" + item
		socket.bone_name = bone
		socket.set_meta("party_gear_item", item)
		skeleton.add_child(socket)
		var prop := Node3D.new()
		prop.basis = skeleton.get_bone_global_rest(index).basis.inverse()
		socket.add_child(prop)
		match item:
			"walking_staff":
				Art.cylinder(prop, 0.019, 1.22, Vector3(0, -0.12, 0.038), Art.material(Color("775038")), 0.014)
				Art.cylinder(prop, 0.021, 0.12, Vector3(0, 0.018, 0.038), Art.material(Color("3e301f")), 0.019)
			"bronze_brooch":
				var clasp := Art.cylinder(prop, 0.031, 0.01, Vector3(-.105, .215, .132), Art.material(Color("aa9156")))
				clasp.rotation.x = PI/2
			"leather_belt":
				var belt := Art.cylinder(prop, 0.183, 0.046, Vector3(0, 0.075, 0), Art.material(Color("674531")))
				belt.scale.z = 0.83
				Art.box(prop, Vector3(.047, .037, .018), Vector3(0, .075, .151), Art.material(Color("aa9156")))
			"wool_cloak", "linen_tunic":
				var cloth := MeshInstance3D.new()
				if not garments.has(item):
					garments[item] = _cloth(item == "wool_cloak")
				cloth.mesh = garments[item]
				prop.add_child(cloth)
	model.set_meta("displayed_party_gear", equipment.duplicate(true))


## An open shoulder wrap and a closed undertunic, cut on three elliptical rings.
static func _cloth(cloak: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fabric := Art.material(Color("695344") if cloak else Color("d7c7a3")).duplicate() as StandardMaterial3D
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(fabric)
	var rings: Array[PackedVector3Array] = []
	for layer in 3:
		var ring := PackedVector3Array()
		for index in 25:
			var t := index / 24.0
			var angle := lerpf(0.65, TAU - 0.65, t) if cloak else t * TAU
			var pleat := 1.0 + 0.035 * cos(angle * 12.0) * layer
			var rx: float = [0.115, 0.228, 0.27][layer] * pleat
			var rz: float = [0.095, 0.163, 0.208][layer] * pleat
			ring.append(Vector3(sin(angle) * rx, [0.28, 0.18, -0.43 if cloak else -0.34][layer], cos(angle) * rz))
		rings.append(ring)
	for layer in 2:
		for index in 24:
			for point in [rings[layer][index], rings[layer+1][index], rings[layer+1][index+1], rings[layer][index], rings[layer+1][index+1], rings[layer][index+1]]:
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()
