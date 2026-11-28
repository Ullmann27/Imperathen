extends SkeletonModifier3D
## Runs before both native leg solvers. Offsets are additive to this frame's
## authored animation, never cumulative and never a gameplay body translation.
var pelvis_bone: int = -1
var spine_bone: int = -1
var pelvis_offset_m: float = 0.0
var bank_angle_rad: float = 0.0
var forward_world: Vector3 = Vector3.FORWARD

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or pelvis_bone < 0 or spine_bone < 0:
		return
	var pelvis: Transform3D = skeleton.get_bone_global_pose(pelvis_bone)
	pelvis.origin += skeleton.global_basis.inverse()*Vector3.UP*pelvis_offset_m
	skeleton.set_bone_global_pose(pelvis_bone,pelvis)
	var spine: Transform3D = skeleton.get_bone_global_pose(spine_bone)
	var axis: Vector3 = (skeleton.global_basis.inverse()*forward_world).normalized()
	if axis.length_squared() > 0.5:
		spine.basis = Basis(axis,bank_angle_rad)*spine.basis
		skeleton.set_bone_global_pose(spine_bone,spine)
