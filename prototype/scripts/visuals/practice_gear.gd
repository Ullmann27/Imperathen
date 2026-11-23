extends RefCounted
## Original lightweight borrowed practice props. Cosmetic; no combat authority.
const Art = preload("res://scripts/world/village_art.gd")
static var _cap: SphereMesh
static var _metal: StandardMaterial3D
static var _wood: StandardMaterial3D
static var _strap: StandardMaterial3D

static func attach(model: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return result
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.find_bone("Head")<0 or skeleton.find_bone("Hand_L")<0: return result
	if not _cap:
		_cap = SphereMesh.new()
		_cap.radius = .111
		_cap.height = .102
		_cap.is_hemisphere = true
		_cap.radial_segments = 16
		_cap.rings = 6
		_metal = Art.material(Color("857d60"), .67)
		_metal.metallic = .4
		_wood = Art.material(Color("8e6541"))
		_strap = Art.material(Color("4a3425"))
	var helmet := _attachment(skeleton, "Head", "LoanedPracticeHelmet")
	var crown := MeshInstance3D.new()
	crown.mesh = _cap
	crown.material_override = _metal
	crown.position = Vector3(0, .174, -.005)
	helmet.add_child(crown)
	Art.box(helmet, Vector3(.18, .055, .024), Vector3(0, .147, -.091), _metal)
	result.append(helmet.get_parent() as Node3D)
	var shield := _attachment(skeleton, "Hand_L", "LoanedPracticeShield")
	for index in 3:
		Art.box(shield, Vector3(.088, .40, .025), Vector3(-.094+index*.094, .11, .045), _wood)
	for height: float in [.01, .20]:
		Art.box(shield, Vector3(.28, .035, .016), Vector3(0, height, .022), _strap)
	var boss := Art.cylinder(shield, .035, .025, Vector3(0, .11, .068), _metal, .025)
	boss.rotation.x = PI/2
	result.append(shield.get_parent() as Node3D)
	return result

static func _attachment(skeleton: Skeleton3D, bone: String, label: String) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = bone
	attachment.override_pose = false
	skeleton.add_child(attachment)
	var shapes := Node3D.new()
	shapes.name = "PracticeProps"
	shapes.basis = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).basis.inverse()
	attachment.add_child(shapes)
	return shapes
