extends SkeletonModifier3D
## After TwoBoneIK3D: rotate the actual ankle toward the measured surface normal.
## Preserve the authored yaw and the unmodified swing pose when influence is zero.
var foot_bone: int = -1
var rest_up_local: Vector3 = Vector3.UP
var surface_normal: Vector3 = Vector3.UP

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if skeleton == null or foot_bone < 0 or not surface_normal.is_finite():
		return
	var pose: Transform3D = skeleton.get_bone_global_pose(foot_bone)
	var world_basis: Basis = skeleton.global_basis.orthonormalized()*pose.basis
	var current_up: Vector3 = (world_basis*rest_up_local).normalized()
	var wanted_up: Vector3 = surface_normal.normalized()
	if current_up.length_squared() < 0.5 or wanted_up.dot(Vector3.UP) < 0.45:
		return
	var correction: Quaternion = Quaternion(current_up,wanted_up)
	var to_local: Basis = skeleton.global_basis.orthonormalized().inverse()
	pose.basis = to_local*Basis(correction)*world_basis
	skeleton.set_bone_global_pose(foot_bone,pose)
