extends RefCounted
## Candidate-only long dress solver. The authored GLB must actually contain
## the complete calibrated shape family and a pelvis-only garment skin.
## No CPU deformation of the character body and no per-frame scene searches.
const POSE_NAMES := ["ClothRestClearance","ClothKneeFront","ClothKneeBack","ClothHemFront","ClothHemBack","ClothSideClearance"]
const FLOOR_NAMES := ["ClothFloorXPos","ClothFloorXNeg","ClothFloorYPos","ClothFloorYNeg","ClothFloorZPos","ClothFloorZNeg"]
const JOINTS := ["Shin_L","Shin_R","Foot_L","Foot_R"]
const DRIVE := 2.8
const MAX_LIFT := 0.16
var mesh: MeshInstance3D
var rig: Skeleton3D
var pelvis := -1
var slots := PackedInt32Array()
var floor_slots := PackedInt32Array()
var joints := PackedInt32Array()
var rest_z := PackedFloat32Array()
var base := PackedVector3Array()
var deltas: Array[PackedVector3Array] = []
var mask := PackedFloat32Array()
var bind_pose := Transform3D.IDENTITY
var last_floor_residual_m := 0.0
var last_lift_world_m := 0.0


func clear() -> void:
	mesh = null
	rig = null
	pelvis = -1
	slots.clear()
	floor_slots.clear()
	joints.clear()
	rest_z.clear()
	base.clear()
	deltas.clear()
	mask.clear()
	last_floor_residual_m = 0.0
	last_lift_world_m = 0.0


func bound() -> bool:
	return is_instance_valid(mesh) and is_instance_valid(rig) and pelvis >= 0 and slots.size() == POSE_NAMES.size() and floor_slots.size() == FLOOR_NAMES.size()


func bind(model: Node3D) -> bool:
	clear()
	if not is_instance_valid(model):
		return false
	var garment := model.find_child("HeroTunicSkirt",true,false) as MeshInstance3D
	if garment == null or not garment.mesh is ArrayMesh or garment.skin == null or garment.mesh.get_surface_count() != 1:
		return false
	var skeleton := garment.get_node_or_null(garment.skeleton) as Skeleton3D
	if skeleton == null:
		return false
	for name: String in POSE_NAMES + FLOOR_NAMES:
		var slot := garment.find_blend_shape_by_name(name)
		if slot < 0:
			clear()
			return false
		if name in POSE_NAMES:
			slots.append(slot)
		else:
			floor_slots.append(slot)
	pelvis = skeleton.find_bone("Pelvis")
	if pelvis < 0:
		clear()
		return false
	var rest_inverse := skeleton.get_bone_global_rest(pelvis).affine_inverse()
	for name: String in JOINTS:
		var bone := skeleton.find_bone(name)
		if bone < 0:
			clear()
			return false
		joints.append(bone)
		rest_z.append((rest_inverse * skeleton.get_bone_global_rest(bone)).origin.z)
	var skin_index := -1
	for i in garment.skin.get_bind_count():
		var name := String(garment.skin.get_bind_name(i))
		var bone := skeleton.find_bone(name) if not name.is_empty() else garment.skin.get_bind_bone(i)
		if bone == pelvis:
			skin_index = i
			break
	if skin_index < 0:
		clear()
		return false
	bind_pose = garment.skin.get_bind_pose(skin_index)
	var arrays: Array = garment.mesh.surface_get_arrays(0)
	base = arrays[Mesh.ARRAY_VERTEX]
	var skin_joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var skin_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if base.is_empty() or skin_joints.size() != skin_weights.size() or skin_joints.size() % base.size() != 0:
		clear()
		return false
	var influences := skin_joints.size() / base.size()
	for vertex in base.size():
		var total := 0.0
		for i in influences:
			var at := vertex*influences+i
			var w := skin_weights[at]
			if not is_finite(w) or w < 0.0 or (w > 0.00001 and skin_joints[at] != skin_index):
				clear()
				return false
			total += w
		if absf(total-1.0)>0.002:
			clear()
			return false
	var shape_arrays: Array = garment.mesh.surface_get_blend_shape_arrays(0)
	var relative := (garment.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	if shape_arrays.size() != garment.mesh.get_blend_shape_count():
		clear()
		return false
	for shape: Array in shape_arrays:
		var vertices: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
		if vertices.size() != base.size():
			clear()
			return false
		if not relative:
			for i in vertices.size():
				vertices[i] -= base[i]
		deltas.append(vertices)
	mask.resize(base.size())
	var lift_delta: PackedVector3Array = deltas[floor_slots[2]]
	for i in base.size():
		mask[i] = clampf(lift_delta[i].y/MAX_LIFT,0.0,1.0)
		if not is_finite(mask[i]):
			clear()
			return false
	mesh = garment
	rig = skeleton
	return true


func apply(floor_y: float) -> bool:
	if not bound() or not is_finite(floor_y):
		return false
	rig.force_update_all_bone_transforms()
	var pelvis_pose := rig.get_bone_global_pose(pelvis)
	var inverse := pelvis_pose.affine_inverse()
	var dz := PackedFloat32Array()
	for i in joints.size():
		dz.append((inverse*rig.get_bone_global_pose(joints[i])).origin.z-rest_z[i])
	var maximum := 0.0
	for v: float in dz:
		maximum=maxf(maximum,absf(v))
	var drives := PackedFloat32Array([1.0,maxf(dz[0],dz[1])*DRIVE,-minf(dz[0],dz[1])*DRIVE,
		maxf(dz[2],dz[3])*DRIVE,-minf(dz[2],dz[3])*DRIVE,maximum*3.0])
	for i in slots.size():
		mesh.set_blend_shape_value(slots[i],clampf(drives[i],0.0,1.0))
	for i in floor_slots:
		mesh.set_blend_shape_value(i,0.0)
	var world := rig.global_transform*pelvis_pose*bind_pose
	var local_up := world.basis.inverse()*Vector3.UP
	var points := base.duplicate()
	for shape in deltas.size():
		if shape in floor_slots:
			continue
		var amount := mesh.get_blend_shape_value(shape)
		if absf(amount) <= 0.000001:
			continue
		var change: PackedVector3Array = deltas[shape]
		for i in points.size():
			points[i] += change[i]*amount
	var required := 0.0
	last_floor_residual_m = 0.0
	for i in points.size():
		var need := maxf(0.0,floor_y-(world*points[i]).y)
		if mask[i]>0.00001:
			required=maxf(required,need/mask[i])
		else:
			last_floor_residual_m=maxf(last_floor_residual_m,need)
	# Cap the vector magnitude in garment units, not each world component.
	var local_lift := local_up*required
	if local_lift.length()>MAX_LIFT:
		local_lift=local_lift.limit_length(MAX_LIFT)
	last_lift_world_m=(world.basis*local_lift).length()
	var relative_lift := local_lift/MAX_LIFT
	for axis in 3:
		mesh.set_blend_shape_value(floor_slots[axis*2],clampf(relative_lift[axis],0.0,1.0))
		mesh.set_blend_shape_value(floor_slots[axis*2+1],clampf(-relative_lift[axis],0.0,1.0))
	for i in points.size():
		last_floor_residual_m=maxf(last_floor_residual_m,floor_y-(world*(points[i]+local_lift*mask[i])).y)
	return last_floor_residual_m<=0.002
