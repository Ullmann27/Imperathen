extends Node3D
## Procedural test head for lip-sync verification (not a game character).
## It exercises BOTH runtime output paths of face_driver.gd:
##   * a Skeleton3D with bones Head and Jaw; the chin/lower-jaw mesh follows
##     the Jaw bone through a BoneAttachment3D (youth-rig path);
##   * a lip mesh with blend shapes jaw_open, lip_round, lip_wide, lip_close,
##     lip_tuck (adult/custom-head path).
## Units are metres; the head is ~0.22 m tall.

const MOUTH_HALF_WIDTH := 0.026
const MOUTH_GAP := 0.0015
const LIP_RADIUS := 0.0055
const RING := 64
const TUBE := 10
const MOUTH_Z := 0.093
const MOUTH_Y := -0.035

var skeleton: Skeleton3D
var lips: MeshInstance3D


func _ready() -> void:
	if skeleton == null:
		build()


func build() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.80, 0.62, 0.52)
	skin.roughness = 0.65
	var lip_mat := StandardMaterial3D.new()
	lip_mat.albedo_color = Color(0.66, 0.33, 0.33)
	lip_mat.roughness = 0.45
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.03, 0.03)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	var head := skeleton.add_bone("Head")
	skeleton.set_bone_rest(head, Transform3D.IDENTITY)
	var jaw := skeleton.add_bone("Jaw")
	skeleton.set_bone_parent(jaw, head)
	# Jaw pivot near the temporomandibular joint, behind and above the mouth.
	skeleton.set_bone_rest(jaw, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.005, 0.01)))
	skeleton.reset_bone_poses()
	var head_attach := BoneAttachment3D.new()
	head_attach.bone_name = "Head"
	skeleton.add_child(head_attach)
	var jaw_attach := BoneAttachment3D.new()
	jaw_attach.bone_name = "Jaw"
	skeleton.add_child(jaw_attach)
	# Cranium and upper face.
	var cranium := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	cranium.mesh = sphere
	cranium.material_override = skin
	cranium.scale = Vector3(0.82, 1.15, 0.9)
	cranium.position = Vector3(0.0, 0.035, 0.0)
	head_attach.add_child(cranium)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.012
		em.height = 0.024
		eye.mesh = em
		eye.material_override = dark
		eye.position = Vector3(0.03 * side, 0.05, 0.078)
		head_attach.add_child(eye)
	# Mouth cavity, visible when the lips part.
	var cavity := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.022
	cm.height = 0.03
	cavity.mesh = cm
	cavity.material_override = dark
	cavity.scale = Vector3(1.0, 1.0, 0.45)
	cavity.position = Vector3(0.0, MOUTH_Y - 0.006, MOUTH_Z - 0.019)
	head_attach.add_child(cavity)
	# Lower jaw / chin, rigidly bound to the Jaw bone.
	var chin := MeshInstance3D.new()
	var chm := SphereMesh.new()
	chm.radius = 0.05
	chm.height = 0.06
	chin.mesh = chm
	chin.material_override = skin
	chin.scale = Vector3(1.0, 0.9, 1.05)
	chin.position = Vector3(0.0, -0.068, 0.036)
	jaw_attach.add_child(chin)
	lips = MeshInstance3D.new()
	lips.name = "Lips"
	lips.mesh = _lip_mesh()
	lip_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	lips.material_override = lip_mat
	head_attach.add_child(lips)


## Lip centre line: an ellipse in the mouth plane. Each blend shape is a full
## target position array (Mesh.BLEND_SHAPE_MODE_NORMALIZED).
func _lip_point(theta: float, shape: String) -> Vector3:
	var s := sin(theta)
	var c := cos(theta)
	var half_w := MOUTH_HALF_WIDTH
	var half_h := LIP_RADIUS + MOUTH_GAP
	var y := half_h * s
	var z := MOUTH_Z - 0.012 * c * c  # lips wrap around the face curvature
	var lower := clampf(-s, 0.0, 1.0)
	var upper := clampf(s, 0.0, 1.0)
	match shape:
		"jaw_open":
			# Lower lip travels with the jaw: ~18 mm at full opening.
			y -= 0.018 * pow(lower, 0.8)
			z -= 0.004 * lower
		"lip_round":
			half_w *= 0.62
			y += 0.004 * s
			z += 0.009
		"lip_wide":
			half_w *= 1.28
			y *= 0.8
			z -= 0.003
		"lip_close":
			y = (LIP_RADIUS * 0.85) * s
			z += 0.001
		"lip_tuck":
			# Lower lip rolls up and back under the upper incisors (f/v).
			y += 0.0045 * lower
			z -= 0.007 * lower
			y += 0.0005 * upper
	return Vector3(half_w * c, MOUTH_Y + y, z)


func _tube(shape: String) -> PackedVector3Array:
	var verts := PackedVector3Array()
	for i in RING + 1:
		var theta := TAU * float(i) / RING
		var p := _lip_point(theta, shape)
		var p2 := _lip_point(theta + 0.01, shape)
		var tangent := (p2 - p).normalized()
		var out := Vector3(cos(theta), sin(theta), 0.0)
		var normal := (out - tangent * out.dot(tangent)).normalized()
		var binormal := tangent.cross(normal).normalized()
		# Lips are thinner at the corners.
		var r := LIP_RADIUS * (0.55 + 0.45 * absf(sin(theta)))
		for j in TUBE + 1:
			var phi := TAU * float(j) / TUBE
			verts.append(p + (normal * cos(phi) + binormal * sin(phi)) * r)
	return verts


func _normals(verts: PackedVector3Array, shape: String) -> PackedVector3Array:
	var normals := PackedVector3Array()
	for i in RING + 1:
		var theta := TAU * float(i) / RING
		var centre := _lip_point(theta, shape)
		for j in TUBE + 1:
			normals.append((verts[i * (TUBE + 1) + j] - centre).normalized())
	return normals


func _lip_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	var names := ["jaw_open", "lip_round", "lip_wide", "lip_close", "lip_tuck"]
	for n in names:
		mesh.add_blend_shape(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var base := _tube("")
	arrays[Mesh.ARRAY_VERTEX] = base
	arrays[Mesh.ARRAY_NORMAL] = _normals(base, "")
	var indices := PackedInt32Array()
	for i in RING:
		for j in TUBE:
			var a := i * (TUBE + 1) + j
			var b := (i + 1) * (TUBE + 1) + j
			indices.append_array([a, b, a + 1, a + 1, b, b + 1])
	arrays[Mesh.ARRAY_INDEX] = indices
	var blends := []
	for n in names:
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		var v := _tube(n)
		shape[Mesh.ARRAY_VERTEX] = v
		shape[Mesh.ARRAY_NORMAL] = _normals(v, n)
		blends.append(shape)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends)
	return mesh
